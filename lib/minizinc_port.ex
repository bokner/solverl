defmodule MinizincPort do
  @moduledoc """
    Port server for Minizinc solver executable.
  """
  use GenServer
  require Logger

  import MinizincResults

  # GenServer API
  def start_link(args, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  def init(args \\ []) do
    Process.flag(:trap_exit, true)
    # Locate minizinc executable and run it with args converted to CLI params.
    command = prepare_solver_cmd(args)
    Logger.warn "Command: #{command}"
    port = Port.open({:spawn, command}, [:binary, :exit_status, :stderr_to_stdout, line: 64*1024  ])
    Port.monitor(port)

    {:ok, %{port: port, current_results: results_rec(),
      solution_handler: args[:solution_handler],
      exit_status: nil} }
  end

  def terminate(reason, %{port: port} = _state) do
    Logger.debug "** TERMINATE: #{inspect reason}"
    #Logger.info "in state: #{inspect state}"

    port_info = Port.info(port)
    os_pid = port_info[:os_pid]

    if os_pid do
      true = Port.close(port)
    end

    :normal
  end

  # Handle incoming stream from the command's STDOUT
  # Note: the stream messages are split to lines by 'line: L' option in Port.open/2.
  def handle_info({_port, {:data, line}},
        %{current_results: current_results,
          solution_handler: solution_handler} = state) do

    ##TODO: handle long lines
    {_eol, text_line} = line
    parser_event = MinizincParser.parse_output(text_line)
    updated_results =
      MinizincResults.update_results(current_results, parser_event)
    updated_state = Map.put(state, :current_results, updated_results)
    case parser_event do
      {:status, :satisfied} ->
        # Solution handler can force the termination of solver process

        solution_res = MinizincHandler.handle_solver_event(:solution, updated_results, solution_handler)
        ## Deciding if the solver is to be stopped...
        case solution_res do
          :stop ->
            {:stop, :normal, updated_state}
          _other ->
           {:noreply, updated_state}
        end
      _event ->
        {:noreply, updated_state}

    end
  end

  # Handle process exits
  #
  ## Normal exit
  def handle_info(
      {port, {:exit_status, 0}},
        %{port: port,
          current_results: results,
          solution_handler: solution_handler} = state) do
    #Logger.debug "Port exit: :exit_status: #{port_status}"
    MinizincHandler.handle_solver_event(:final, results, solution_handler)
    new_state = state |> Map.put(:exit_status, 0)

    {:noreply, new_state}
  end

  def handle_info(
        {port, {:exit_status, abnormal_exit}},
        %{port: port,
          current_results: results,
          solution_handler: solution_handler} = state) do
    Logger.debug "Abnormal Minizinc execution: #{abnormal_exit}"
    MinizincHandler.handle_solver_event(:minizinc_error, results, solution_handler)
    new_state = Map.put(state, :exit_status, abnormal_exit)
    {:noreply, new_state}
  end

    def handle_info({:DOWN, _ref, :port, port, :normal}, state) do
    Logger.info ":DOWN message from port: #{inspect port}"
    {:stop, :normal, state}
  end

  def handle_info({:EXIT, _port, :normal}, state) do
    #Logger.info "handle_info: EXIT"
    {:stop, :normal, state}
  end

  def handle_info(msg, state) do
    Logger.info "Unhandled message: #{inspect msg}"
    {:noreply, state}
  end

  ## Retrieve current solver results
  def handle_call(:get_results,  _from, state) do
    {:reply, {:ok, state[:current_results]}, state}
  end

  ## Same as above, but stop the solver
  def handle_cast(:stop_solver, state) do
    Logger.debug "Request to stop the solver..."
    {:stop, :normal, state}
  end

  ## Helpers
  def get_results(pid) do
    GenServer.call(pid, :get_results)
  end

  def stop(pid) do
    GenServer.cast(pid, :stop_solver)
  end

  defp prepare_solver_cmd(args) do
    {:ok, solver} = MinizincSolver.lookup(args[:solver])
    solver_str = "--solver #{solver["id"]}"
    time_limit_str = "--time-limit #{args[:time_limit]}"
    extra_flags = Keyword.get(args, :extra_flags, "")
    {:ok, model_str} = MinizincModel.make_model(args[:model])
    {:ok, dzn_str} = MinizincData.make_dzn(args[:data])
    args[:minizinc_executable] <> " " <>
                                  String.trim(
                                    "--allow-multiple-assignments --output-mode json --output-time --output-objective --output-output-item -s -a " <>
                                    extra_flags <>
                                    " #{solver_str} #{time_limit_str} #{model_str} #{dzn_str}"
                                  )
  end

end