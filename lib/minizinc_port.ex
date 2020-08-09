defmodule MinizincPort do
  @moduledoc false

  # Port server for Minizinc solver executable.

  use GenServer
  require Logger


  # GenServer API
  def start_link(solver_opts, opts \\ []) do
    GenServer.start_link(__MODULE__, solver_opts, opts)
  end

  def init(solver_opts \\ []) do

    {:ok, solver} = MinizincSolver.lookup(solver_opts[:solver])
    model_file = MinizincModel.make_model(solver_opts[:model])
    dzn_file = MinizincData.make_dzn(solver_opts[:data])
    model_info = MinizincModel.model_info(model_file)
    case MinizincData.check_dzn(model_info, dzn_file) do
      :ok -> :ok
      dzn_error ->
        Logger.debug "dzn error: #{inspect dzn_error}"
        throw dzn_error
    end

    {:ok, pid, ospid} = run_minizinc(solver, model_file, dzn_file, solver_opts)

    {
      :ok,
      %{
        pid: pid,
        ospid: ospid,
        started_at: MinizincUtils.now(:microsecond),
        parser_state: MinizincParser.initial_state(),
        solution_handler: solver_opts[:solution_handler],
        model: model_file,
        dzn: dzn_file
      }
    }
  end

  def terminate(reason, _state) do
    Logger.debug "** TERMINATE: #{inspect reason}"
    #Logger.info "in state: #{inspect state}"

    :normal
  end

  # Handle incoming stream from the command's STDOUT
  def handle_info(
        {out_stream, _ospid, data},
        %{
          solution_handler: solution_handler
        } = state
      ) when out_stream in [:stdout, :stderr] do

    ##TODO: handle data chunks that are not terminated by newline.
    lines = String.split(data, "\n")

    res = Enum.reduce_while(
      lines,
      state,
      fn text_line, acc ->
        {action, s} = parse_minizinc_data(out_stream, text_line, acc, solution_handler)
        case action do
          :break ->
            {:halt, {:break, s}}
          :ok ->
            {:cont, s}
        end
      end
    )

    case res do
      {:break, new_state} ->
        {:stop, :normal, new_state}
      new_state ->
        {:noreply, new_state}
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
    Logger.debug "Request to stop the solver..."
    finalize(:normal, state)
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

  defp run_minizinc(solver, model_str, dzn_str, opts) do
    solver_str = "--solver #{solver["id"]}"
    time_limit = opts[:time_limit]
    time_limit_str = if time_limit, do: "--time-limit #{time_limit}", else: ""
    extra_flags = Keyword.get(opts, :extra_flags, "")
    command = Enum.join(
      [
        opts[:minizinc_executable],
        "--allow-multiple-assignments --output-mode json --output-time --output-objective --output-output-item -s -a ",
        " #{solver_str} #{time_limit_str} #{extra_flags} #{model_str} #{dzn_str}"
      ],
      " "
    )
    Logger.debug "Minizinc command: #{command}"
    Process.flag(:trap_exit, true)
    {:ok, _pid, _id} = Exexec.run_link(command, stdout: true, stderr: true, monitor: true)
  end


  defp finalize(
         exit_status,
         %{solution_handler: solution_handler, parser_state: parser_state} = state
       )
       when exit_status == :normal do
    handle_summary(solution_handler, parser_state)
    new_state = state
                |> Map.put(:exit_status, 0)
    {:stop, :normal, new_state}
  end

  defp finalize(
         {:exit_status, abnormal_exit},
         %{solution_handler: solution_handler, parser_state: parser_state} = state
       ) do
    Logger.debug "Abnormal Minizinc execution: #{abnormal_exit}"
    handle_minizinc_error(solution_handler, parser_state)
    new_state = Map.put(state, :exit_status, abnormal_exit)
    {:stop, :normal, new_state}
  end



  defp handle_solution(solution_handler, parser_state) do
    MinizincHandler.handle_solution(
      MinizincParser.solution(parser_state),
      solution_handler
    )
  end

  defp handle_summary(solution_handler, parser_state) do
    MinizincHandler.handle_summary(
      MinizincParser.summary(parser_state),
      solution_handler
    )
  end

  defp handle_minizinc_error(solution_handler, parser_state) do
    MinizincHandler.handle_minizinc_error(
      MinizincParser.minizinc_error(parser_state),
      solution_handler
    )
  end

  def handle_compiled(_solution_handler, _parser_state) do
    :todo
    :ok
  end

  ## Parse data from external Minizinc process
  defp parse_minizinc_data(out_stream, data, %{parser_state: parser_state} = state, solution_handler) do
    {parser_event, new_parser_state} = MinizincParser.parse_output(out_stream, data, parser_state)

    next_action =
      case parser_event do
        {:status, :satisfied} ->
          # Solution handler can force the termination of solver process
          solution_res = handle_solution(solution_handler, new_parser_state)
          ## Deciding if the solver is to be stopped...
          case solution_res do
            :break ->
              handle_summary(solution_handler, new_parser_state)
              :break
            {:break, _data} ->
              handle_summary(solution_handler, new_parser_state)
              :break
            _other ->
              :ok
          end
        :compiled ->
            handle_compiled(solution_handler, new_parser_state)
            :ok
        _other ->
          :ok
      end
    {next_action, Map.put(state, :last_event_timestamp, MinizincUtils.now(:microsecond)) |>
                                 Map.put(:parser_state, new_parser_state)}
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
        0 -> nil
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
    Logger.info "Unhandled message: #{inspect msg}"
    {:noreply, state}
  end
end