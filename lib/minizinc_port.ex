defmodule MinizincPort do

  use GenServer
  require Logger

  import MinizincInstance

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

    {:ok, %{port: port, current_instance: instance_rec(),
      completed_instance: nil,
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
        %{current_instance: instance,
          completed_instance: last_instance,
          solution_handler: handlerFun} = state) do
    ##TODO: handle long lines
    {_eol, text_line} = line
    {status, instance} = MinizincParser.handle_output(instance, text_line)
    instance = MinizincInstance.update_status(instance, status)
    case status do
      nil ->
        {:noreply, %{state | current_instance: instance}}
      :satisfied ->
        # 'false' signifies non-final solution

        new_state = %{state | current_instance: MinizincInstance.reset_instance(instance), completed_instance: instance}
        # Solution handler can force the termination of solver process
        case handlerFun.(false, instance) do
          :stop ->
            {:stop, :normal, new_state}
          _other ->
           {:noreply, new_state}
        end
      _terminal_status ->
        last_instance = MinizincInstance.update_status(last_instance, status)
        {:noreply, %{state | current_instance: instance, completed_instance: last_instance}}

    end
  end

  # Handle process exits
  def handle_info(
      {port, {:exit_status, status}},
        %{port: port,
          current_instance: instance,
          completed_instance: last_instance,
          solution_handler: handlerFun} = state) do
    Logger.debug "Port exit: :exit_status: #{status}"
    handlerFun.(true, MinizincInstance.merge_solver_stats(last_instance, instance))
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

  ## Retrieve completed solver instance
  def handle_call(:get_instance,  {from, _ref}, state) do
    Logger.debug "#{:erlang.pid_to_list(from)} asks for the instance..."
    {:reply, {:ok, state[:completed_instance]}, state}
  end

  ## Same as above, but stop the solver
  def handle_call(:get_instance_and_stop,  _from, state) do
    {:stop, :normal, {:ok, state[:completed_instance]}, state}
  end

  ## Helpers


end