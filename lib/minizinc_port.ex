defmodule MinizincPort do
  @moduledoc false

  # Port server for Minizinc solver executable.

  use GenServer
  require Logger

  import MinizincParser

  # GenServer API
  def start_link(args, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  def init(args \\ []) do
    Process.flag(:trap_exit, true)
    # Locate minizinc executable and run it with args converted to CLI params.
    {:ok, model_text} = MinizincModel.make_model(args[:model])
    {:ok, dzn_text} = MinizincData.make_dzn(args[:data])
    command = prepare_solver_cmd(model_text, dzn_text, args)
    Logger.warn "Command: #{command}"

    {:ok, pid, ospid} = run_minizinc(command)

    {:ok, %{pid: pid, ospid: ospid, parser_state: parser_rec(),
      solution_handler: args[:solution_handler],
      model: model_text, dzn: dzn_text,
      exit_status: nil} }
  end

  def terminate(reason, _state) do
    Logger.debug "** TERMINATE: #{inspect reason}"
    #Logger.info "in state: #{inspect state}"

    :normal
  end

  # Handle incoming stream from the command's STDOUT
  def handle_info({:stdout, _processid, data},
        %{parser_state: parser_state,
          solution_handler: solution_handler} = state) do

    ##TODO: handle data chunks that are not terminated by newline.
    lines = String.split(data, "\n")

    res = Enum.reduce_while(lines, parser_state,
        fn text_line, acc ->
          {action, s} = parse_minizinc_data(text_line, acc, solution_handler)
          case action do
            :stop ->
              {:halt, {:stop, s}}
            :ok ->
              {:cont, s}
          end
        end)

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
        {:DOWN, _process_id, :process, _pid, status_info},
        %{
          parser_state: results,
          solution_handler: solution_handler} = state) do
    finalize(status_info, solution_handler, results, state)
  end

  def handle_info({:EXIT, _pid, status_info}, %{
    parser_state: results,
    solution_handler: solution_handler} = state) do
    finalize(status_info, solution_handler, results, state)
  end

  def handle_info(msg, state) do
    Logger.info "Unhandled message: #{inspect msg}"
    {:noreply, state}
  end

  ## Retrieve current solver results
  def handle_call(:get_results,  _from, state) do
    {:reply, {:ok, state[:parser_state]}, state}
  end

  ## Same as above, but stop the solver
  def handle_cast(:stop_solver,
          %{parser_state: results,
            solution_handler: solution_handler} = state) do
    Logger.debug "Request to stop the solver..."
    handle_summary(solution_handler, results)
    {:stop, :normal, state}
  end

  ## Helpers
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
    opts[:minizinc_executable] <> " " <>
      String.trim(
        "--allow-multiple-assignments --output-mode json --output-time --output-objective --output-output-item -s -a "
         <>
        " #{solver_str} #{time_limit_str} #{extra_flags} #{model_str} #{dzn_str}"
      )
  end


  defp finalize(exit_status, solution_handler, results, state) when exit_status == :normal do
    handle_summary(solution_handler, results)
    new_state = state |> Map.put(:exit_status, 0)
    {:stop, :normal, new_state}
  end

  defp finalize({:exit_status, abnormal_exit}, solution_handler, results, state) do
    Logger.debug "Abnormal Minizinc execution: #{abnormal_exit}"
    handle_minizinc_error(solution_handler, results)
    new_state = Map.put(state, :exit_status, abnormal_exit)
    {:stop, :normal, new_state}
  end

  defp run_minizinc(command) do
  {:ok, _pid, _id} = Exexec.run_link(command, stdout: true, stderr: false, monitor: true)
  end

  defp handle_solution(solution_handler, results) do
    MinizincHandler.handle_solution(
      MinizincParser.solution(results), solution_handler)
  end

  defp handle_summary(solution_handler, results) do
    MinizincHandler.handle_summary(
      MinizincParser.summary(results), solution_handler)
  end

  defp handle_minizinc_error(solution_handler, results) do
    MinizincHandler.handle_minizinc_error(
      MinizincParser.minizinc_error(results), solution_handler)
  end

  ## Parse data from external Minizinc process
  def parse_minizinc_data(data, parser_state, solution_handler) do
    parser_event = MinizincParser.parse_output(data)
    parser_state =
      MinizincParser.update_state(parser_state, parser_event)
    #updated_state = Map.put(state, :parser_state, updated_results)
    next_action =
      case parser_event do
      {:status, :satisfied} ->
        # Solution handler can force the termination of solver process
        solution_res = handle_solution(solution_handler, parser_state)
        ## Deciding if the solver is to be stopped...
        case solution_res do
          :stop ->
            handle_summary(solution_handler, parser_state)
            :stop
          {:stop, _data} ->
            handle_summary(solution_handler, parser_state)
            :stop
          _other ->
            :ok
        end
      _event ->
        :ok
  end
    {next_action, parser_state}
end

end