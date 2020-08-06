defmodule MinizincPort do
  @moduledoc false

  # Port server for Minizinc solver executable.

  use GenServer
  require Logger

  import MinizincUtils

  # GenServer API
  def start_link(args, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  def init(args \\ []) do
    Process.flag(:trap_exit, true)
    # Locate minizinc executable and run it with args converted to CLI params.
    model_file = MinizincModel.make_model(args[:model])
    dzn_file = MinizincData.make_dzn(args[:data])
    command = prepare_solver_cmd(model_file, dzn_file, args)
    Logger.debug "Command: #{command}"

    {:ok, pid, ospid} = run_minizinc(command)

    {
      :ok,
      %{
        pid: pid,
        ospid: ospid,
        parser_state: MinizincParser.initial_state(),
        solution_handler: args[:solution_handler],
        model: model_file,
        dzn: dzn_file,
        exit_status: nil
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
          parser_state: parser_state,
          solution_handler: solution_handler
        } = state
      ) when out_stream in [:stdout, :stderr] do

    ##TODO: handle data chunks that are not terminated by newline.
    lines = String.split(data, "\n")

    res = Enum.reduce_while(
      lines,
      parser_state,
      fn text_line, acc ->
        {action, s} = parse_minizinc_data(out_stream, text_line, acc, solution_handler)
        case action do
          :stop ->
            {:halt, {:stop, s}}
          :ok ->
            {:cont, s}
        end
      end
    )

    case res do
      {:stop, new_parser_state} ->
        {:stop, :normal, Map.put(state, :parser_state, new_parser_state)}
      new_parser_state ->
        {:noreply, Map.put(state, :parser_state, new_parser_state)}
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
    Logger.info "Unhandled message: #{inspect msg}"
    {:noreply, state}
  end

  ## Retrieve current solver results
  def handle_call(:get_results, _from, state) do
    {:reply, {:ok, state[:parser_state]}, state}
  end

  ## Same as above, but stop the solver
  def handle_cast(
        :stop_solver,
        state
      ) do
    Logger.debug "Request to stop the solver..."
    finalize(:normal, state)
  end

  ## Branching on the model
  def handle_cast(
        {:branch, constraints},
        %{model: model_file} = state
      ) do
    Logger.debug "Request to branch..."
    new_model = MinizincModel.make_model([model_file |
                             Enum.map(constraints, fn c -> {:model_text, constraint(c)} end)])
    branch(new_model)
    {:noreply, state}
  end


  ## Helpers
  def branch(pid, constraint_specs) do
    GenServer.cast(pid, {:branch, constraint_specs})
  end

  def branch(_model) do
    :todo
  end

  def get_results(pid) do
    GenServer.call(pid, :get_results)
  end

  def stop(pid) do
    GenServer.cast(pid, :stop_solver)
  end

  defp prepare_solver_cmd(model_str, dzn_str, opts) do
    {:ok, solver} = MinizincSolver.lookup(opts[:solver])
    solver_str = "--solver #{solver["id"]}"
    time_limit = opts[:time_limit]
    time_limit_str = if time_limit, do: "--time-limit #{time_limit}", else: ""
    extra_flags = Keyword.get(opts, :extra_flags, "")
    Enum.join(
      [
        opts[:minizinc_executable],
        "--allow-multiple-assignments --output-mode json --output-time --output-objective --output-output-item -s -a ",
        " #{solver_str} #{time_limit_str} #{extra_flags} #{model_str} #{dzn_str}"
      ],
      " "
    )
  end


  defp finalize(
         exit_status,
         %{solution_handler: solution_handler, parser_state: results} = state
       )
       when exit_status == :normal do
    handle_summary(solution_handler, results)
    new_state = state
                |> Map.put(:exit_status, 0)
    {:stop, :normal, new_state}
  end

  defp finalize(
         {:exit_status, abnormal_exit},
         %{solution_handler: solution_handler, parser_state: results} = state
       ) do
    Logger.debug "Abnormal Minizinc execution: #{abnormal_exit}"
    handle_minizinc_error(solution_handler, results)
    new_state = Map.put(state, :exit_status, abnormal_exit)
    {:stop, :normal, new_state}
  end

  defp run_minizinc(command) do
    {:ok, _pid, _id} = Exexec.run_link(command, stdout: true, stderr: true, monitor: true)
  end

  defp handle_solution(solution_handler, results) do
    MinizincHandler.handle_solution(
      MinizincParser.solution(results),
      solution_handler
    )
  end

  defp handle_summary(solution_handler, results) do
    MinizincHandler.handle_summary(
      MinizincParser.summary(results),
      solution_handler
    )
  end

  defp handle_minizinc_error(solution_handler, results) do
    MinizincHandler.handle_minizinc_error(
      MinizincParser.minizinc_error(results),
      solution_handler
    )
  end

  def handle_compiled(_solution_handler, _parser_state) do
    :todo
    :ok
  end

  ## Parse data from external Minizinc process
  defp parse_minizinc_data(out_stream, data, parser_state, solution_handler) do
    {parser_event, new_parser_state} = MinizincParser.parse_output(out_stream, data, parser_state)

    next_action =
      case parser_event do
        {:status, :satisfied} ->
          # Solution handler can force the termination of solver process
          solution_res = handle_solution(solution_handler, new_parser_state)
          ## Deciding if the solver is to be stopped...
          case solution_res do
            :stop ->
              handle_summary(solution_handler, new_parser_state)
              :stop
            {:stop, _data} ->
              handle_summary(solution_handler, new_parser_state)
              :stop
            _other ->
              :ok
          end
        :compiled ->
            handle_compiled(solution_handler, new_parser_state)
            :ok
        _other ->
          :ok
      end
    {next_action, new_parser_state}
  end

end