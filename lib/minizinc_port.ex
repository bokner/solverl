defmodule MinizincPort do

  use GenServer
  require Logger

  import MinizincUtils

  # GenServer API
  def start_link(args \\ [], opts \\ []) do
    defaults = MinizincSolver.default_args
    args = Keyword.merge(defaults, args)
    GenServer.start_link(__MODULE__, args, opts)
  end

  def init(args \\ []) do
    Process.flag(:trap_exit, true)
    # Locate minizinc executable and run it with args converted to CLI params.
    command = MinizincSolver.prepare_solver_cmd(args)
    Logger.warn "Command: #{command}"
    port = Port.open({:spawn, command}, [:binary, :exit_status, :stderr_to_stdout, line: 64*1024  ])
    Port.monitor(port)

    {:ok, %{port: port, current_solution: solution_rec(),
      last_solution: nil,
      solution_handler: args[:solution_handler],
      exit_status: nil} }
  end

  def terminate(reason, %{port: port} = _state) do
    Logger.debug "** TERMINATE: #{inspect reason}"
    #Logger.info "in state: #{inspect state}"

    port_info = Port.info(port)
    os_pid = port_info[:os_pid]

    if os_pid do
      Logger.warn "Orphaned OS process: #{os_pid}"
      Port.close(port)
    end

    :normal
  end

  # Handle incoming stream from the command's STDOUT
  # Note: the stream messages are split to lines by 'line: L' option in Port.open/2.
  def handle_info({_port, {:data, line}},
        %{current_solution: solution,
          last_solution: last_solution,
          solution_handler: handlerFun} = state) do
    ##TODO: handle long lines
    {_eol, text_line} = line
    {status, solution} = MinizincParser.read_solution(solution, text_line)
    solution = MinizincParser.update_status(solution, status)
    case status do
      nil ->
        {:noreply, %{state | current_solution: solution}}
      :satisfied ->
        # 'false' signifies non-final solution

        new_state = %{state | current_solution: MinizincParser.reset_solution(solution), last_solution: solution}
        # Solution handler can force the termination of solver process
        case handlerFun.(false, solution) do
          :stop ->
            {:stop, :normal, new_state}
          _other ->
           {:noreply, new_state}
        end
      _terminal_status ->
        last_solution = MinizincParser.update_status(last_solution, status)
        {:noreply, %{state | current_solution: solution, last_solution: last_solution}}

    end
  end

  # Handle process exits
  def handle_info(
      {port, {:exit_status, status}},
        %{port: port,
          current_solution: solution,
          last_solution: last_solution,
          solution_handler: handlerFun} = state) do
    Logger.debug "Port exit: :exit_status: #{status}"
    handlerFun.(true, MinizincParser.merge_solver_stats(last_solution, solution))
    new_state = %{state | exit_status: status}

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



  ## Helpers


end