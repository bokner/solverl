defmodule MinizincPort do
  @moduledoc false

  # Port server for Minizinc solver executable.

  use GenServer
  require Logger

  # GenServer API
  def start_link(model_info, solver, solver_opts, opts) do
    GenServer.start_link(__MODULE__, [model_info, solver, solver_opts], opts)
  end

  def init([model_info, solver, solver_opts]) do
    {:ok, pid, ospid} = run_minizinc(solver, model_info, solver_opts)
    Logger.debug("Minizinc started (OS PID: #{ospid})")

    {
      :ok,
      %{
        pid: pid,
        ospid: ospid,
        solver: solver,
        started_at: MinizincUtils.now(:microsecond),
        parser_state: MinizincParser.initial_state(),
        solution_handler: solver_opts[:solution_handler],
        model: model_info,
        solution_timeout: solver_opts[:solution_timeout],
        fzn_timeout: solver_opts[:fzn_timeout],
        fzn_timer: MinizincUtils.send_after(:fzn_timeout, solver_opts[:fzn_timeout]),
        sync_to: solver_opts[:sync_to],
        log_output: solver_opts[:log_output]
      }
    }
  end

  def terminate(reason, %{ospid: ospid} = _state) do
    Logger.debug("** TERMINATE: OS PID: #{ospid}, reason: #{inspect(reason)}")
    reason
  end

  # Handle incoming stream from the command's STDOUT
  def handle_info(
        {out_stream, _ospid, data},
        state
      )
      when out_stream in [:stdout, :stderr] do
    try do
      lines = String.split(data, "\n")

      res =
        Enum.reduce_while(
          lines,
          state,
          fn text_line, acc_state ->
            log_output(text_line, state.log_output)
            {action, s} = parse_minizinc_data(out_stream, text_line, acc_state)

            case action do
              :break ->
                {:halt, {:break, s}}

              :continue ->
                ## There was a new solution, update a solution timer
                {:cont, add_solution_timer(s)}

              :ok ->
                {:cont, s}
            end
          end
        )

      case res do
        {:break, new_state} ->
          finalize(:normal, new_state)

        new_state ->
          {:noreply, new_state}
      end
    catch
      handler_exception ->
        Logger.error("Solution handler error: #{inspect(handler_exception)}")
        sync(state[:sync_to], :handler_exception, handler_exception)
        finalize(:by_exception, state)
    end
  end

  # Handle process exits
  #
  ## Normal exit

  def handle_info(
        {:DOWN, _ospid, :process, _pid, status_info},
        state
      ) do
    finalize(status_info, state)
  end

  def handle_info(
        {:EXIT, _pid, status_info},
        state
      ) do
    finalize(status_info, state)
  end

  ## Solution timeout (references have to match to avoid race conditions
  def handle_info(
        {:solution_timeout, ref},
        %{solution_timer: {_timer, ref}, solution_timeout: timeout} = state
      ) do
    Logger.debug("No new solutions for #{timeout} ms...")
    ## Shut down the solver
    ## TODO: maybe another solution handler callback?
    finalize(:by_solution_timeout, state)
  end

  def handle_info({:fzn_timeout, ref}, %{fzn_timer: {_timer, ref}, fzn_timeout: timeout} = state) do
    Logger.debug("Flattening hasn't finished in #{timeout} ms...")
    ## Shut down the solver
    finalize(:by_fzn_timeout, state)
  end

  def handle_info(msg, state) do
    unhandled_message(msg, state)
  end

  ## Retrieve current solver status
  def handle_call(:solver_status, _from, state) do
    {:reply, {:ok, get_solver_status(state)}, state}
  end

  ## To support Exexec ops on OS pid
  def handle_call(:ospid, _from, %{ospid: ospid} = state) do
    {:reply, ospid, state}
  end

  def handle_call(msg, _from, state) do
    unhandled_message(msg, state)
  end

  ## Same as above, but stop the solver
  def handle_cast(
        :stop_solver,
        state
      ) do
    finalize(:by_request, state)
  end

  ## Update solution handler
  def handle_cast(
        {:update_handler, handler},
        state
      ) do
    {:noreply, Map.put(state, :solution_handler, handler)}
  end

  def handle_cast(msg, _from, state) do
    unhandled_message(msg, state)
  end

  ##############################################################################

  ## Helpers
  ##
  ## Stop solver
  def stop(pid) do
    GenServer.cast(pid, :stop_solver)
  end

  ## Get OS pid of solving process
  def ospid(pid) do
    GenServer.call(pid, :ospid)
  end

  def update_solution_handler(pid, handler) do
    GenServer.cast(pid, {:update_handler, handler})
  end

  defp log_output("", _log_cfg) do
    :ok
  end

  defp log_output(line, func) when is_function(func) do
    func.(line)
  end

  defp log_output(_line, _other) do
  end

  defp run_minizinc(solver, model_info, opts) do
    model_str = model_info[:model_file]
    checker_str = model_info[:checker_file]
    solver_str = "--solver #{solver["id"]}"
    time_limit = opts[:time_limit]
    time_limit_str = if time_limit, do: "--time-limit #{time_limit}", else: ""
    extra_flags = Keyword.get(opts, :extra_flags, "")

    command =
      Enum.join(
        [
          opts[:minizinc_executable],
          "--allow-multiple-assignments --output-mode json --output-time --output-objective --output-output-item -s -a ",
          " #{solver_str} #{time_limit_str} #{extra_flags} #{model_str} #{checker_str}"
        ],
        " "
      )

    Logger.debug("Minizinc command: #{command}")
    Process.flag(:trap_exit, true)

    ## Enable erlexec debugging, if requested
    case opts[:debug_exec] do
      nil -> :ok
      debug_level -> :exec.debug(debug_level)
    end

    {:ok, _pid, _id} =
      :exec.run_link(
        command,
        [:stdout, :stderr, :monitor] ++ opts[:cmd_opts]
      )
  end

  defp finalize(
         {:exit_status, abnormal_exit},
         state
       ) do
    decoded_exit = :exec.status(abnormal_exit)
    Logger.debug("Abnormal Minizinc execution: #{inspect(decoded_exit)}")
    handle_minizinc_error(state)
    new_state = Map.put(state, :exit_status, decoded_exit)
    {:stop, :normal, new_state}
  end

  defp finalize(
         :normal,
         state
       ) do
    new_state =
      state
      |> Map.put(:exit_status, :normal)

    handle_summary(new_state)
    {:stop, :normal, new_state}
  end

  ## Finalizing on timeouts or explicit requests
  defp finalize(
         stop_reason,
         %{ospid: ospid} = state
       ) do
    new_state = Map.put(state, :exit_status, stop_reason)
    handle_summary(new_state)
    Logger.debug("Stopping #{ospid}...")
    {:stop, :normal, new_state}
  end

  defp handle_solver_event(false, _state) do
    false
  end

  defp handle_solver_event(:solution, state) do
    handle_solution(state)
  end

  defp handle_solver_event(:compiled, state) do
    handle_compiled(state)
  end

  defp handle_solution(
         %{
           solution_handler: solution_handler,
           parser_state: parser_state,
           sync_to: caller
         } = _state
       ) do
    sync(
      caller,
      :solution,
      MinizincHandler.handle_solution(
        MinizincParser.solution(parser_state),
        solution_handler
      )
    )
  end

  defp handle_summary(
         %{
           solution_handler: solution_handler,
           parser_state: parser_state,
           solver: solver,
           model: model_info,
           exit_status: exit_status,
           sync_to: caller
         } = _state
       ) do
    sync(
      caller,
      :summary,
      MinizincHandler.handle_summary(
        MinizincParser.summary(parser_state, model_info)
        |> Map.put(:exit_reason, exit_status)
        |> Map.put(:solver, solver["id"]),
        solution_handler
      )
    )
  end

  defp handle_minizinc_error(
         %{
           solution_handler: solution_handler,
           parser_state: parser_state,
           sync_to: caller
         } = _state
       ) do
    sync(
      caller,
      :minizinc_error,
      MinizincHandler.handle_minizinc_error(
        MinizincParser.minizinc_error(parser_state),
        solution_handler
      )
    )
  end

  defp handle_compiled(
         %{solution_handler: solution_handler, parser_state: parser_state, sync_to: caller} =
           _state
       ) do
    sync(
      caller,
      :compiled,
      MinizincHandler.on_compiled(
        MinizincParser.compilation_info(parser_state),
        solution_handler
      )
    )
  end

  ## Parse data from external Minizinc process
  defp parse_minizinc_data(
         out_stream,
         data,
         %{
           parser_state: parser_state
         } = state
       ) do
    {parser_event, new_parser_state} = MinizincParser.parse_output(out_stream, data, parser_state)

    new_state =
      Map.put(state, :last_event_timestamp, MinizincUtils.now(:microsecond))
      |> Map.put(:parser_state, new_parser_state)

    solver_event =
      case parser_event do
        {:status, :satisfied} -> :solution
        :compiled -> :compiled
        _other -> false
      end

    event_res = handle_solver_event(solver_event, new_state)
    ## Deciding if the solver is to be stopped...
    next_action =
      case event_res do
        false ->
          :ok

        :break ->
          :break

        {:break, _data} ->
          :break

        _keep_solving ->
          :continue
      end

    {next_action, new_state}
  end

  defp get_solver_status(%{started_at: started_at, parser_state: parser_state} = _state) do
    summary = MinizincParser.summary(parser_state)
    now_ts = MinizincUtils.now(:microsecond)
    running_time = DateTime.diff(now_ts, started_at, :microsecond)

    {stage, solving_time} =
      if summary[:compiled] do
        {:solving, DateTime.diff(now_ts, summary[:compilation_timestamp], :microsecond)}
      else
        {:compiling, nil}
      end

    solution_count = summary[:solution_count]

    time_since_last_solution =
      case solution_count do
        0 ->
          nil

        _cnt ->
          DateTime.diff(now_ts, summary[:last_solution][:timestamp], :microsecond)
      end

    %{
      running_time: running_time,
      stage: stage,
      solving_time: solving_time,
      time_since_last_solution: time_since_last_solution,
      solution_count: solution_count
    }
  end

  ## Unhandled port messages
  defp unhandled_message(msg, state) do
    Logger.info("Unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  ## Add/update a solution timer
  defp add_solution_timer(%{solution_timeout: timeout} = state) do
    ## Cancel existing solution timer
    case Map.get(state, :solution_timer) do
      {timer, _timer_ref} ->
        Process.cancel_timer(timer)

      nil ->
        :ok
    end

    ## Set up a new one.
    case timeout do
      :infinity ->
        state

      t when t >= 0 ->
        Map.put(state, :solution_timer, MinizincUtils.send_after(:solution_timeout, t))
    end
  end

  ## If the caller is present, send the solver event back to it.
  defp sync(caller, event, data) do
    if caller do
      send_to_caller(caller, event, data)
    end

    data
  end

  defp send_to_caller(_caller, _event, data) when data in [:break, :skip] do
    false
  end

  defp send_to_caller(caller, event, {:break, data}) do
    send_event(caller, event, data)
  end

  defp send_to_caller(caller, event, data) do
    send_event(caller, event, data)
  end

  defp send_event(pid, event, data) do
    send(pid, %{solver_results: {event, data}, from: self()})
  end
end
