defmodule MinizincPort do

  use GenServer
  require Logger
  import MinizincParser

  # GenServer API
  def start_link(args \\ [], opts \\ []) do
    defaults = [solver: "gecode", time_limit: 60*5*1000, solution_handler: &__MODULE__.default_solution_handler/1]
    args = Keyword.merge(defaults, args)
    GenServer.start_link(__MODULE__, args, opts)
  end

  def init(args \\ []) do
    Process.flag(:trap_exit, true)
    # Locate minizinc executable and run it with args converted to CLI params.
    command = "#{System.find_executable("minizinc")} #{MinizincUtils.build_command_args(args)}"
    Logger.warn "Command: #{command}"
    port = Port.open({:spawn, command}, [:binary, :exit_status, :stderr_to_stdout, line: 64*1024  ])
    Port.monitor(port)

    {:ok, %{port: port, solution: solution_rec(),
      solution_handler: args[:solution_handler],
      exit_status: nil} }
  end

  def terminate(reason, %{port: port} = state) do
    Logger.info "** TERMINATE: #{inspect reason}"
    Logger.info "in state: #{inspect state}"

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
  def handle_info({port, {:data, line}}, %{solution: solution, solution_handler: handlerFun} = state) do
    ##TODO: handle long lines
    {_eol, text_line} = line
    {parse_status, solution} = MinizincParser.read_solution(solution, text_line)
    case parse_status do
      :ok ->
        handlerFun.(solution)
        {:noreply, %{state | solution: MinizincParser.reset_solution(solution)}}
      _ ->
        {:noreply, %{state | solution: solution}}
    end
  end

  # Handle process exits
  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    Logger.info "Port exit: :exit_status: #{status}"

    new_state = %{state | exit_status: status}

    {:noreply, new_state}
  end

  def handle_info({:DOWN, _ref, :port, port, :normal}, state) do
    Logger.info ":DOWN message from port: #{inspect port}"
    {:stop, :normal, state}
  end

  def handle_info({:EXIT, _port, :normal}, state) do
    Logger.info "handle_info: EXIT"
    {:stop, :normal, state}
  end

  def handle_info(msg, state) do
    Logger.info "Unhandled message: #{inspect msg}"
    {:noreply, state}
  end

  ## Default solution handler: prints the solution.
  def default_solution_handler(solution) do
    Logger.info "Solution: #{inspect solution}"
  end

  ## Helpers
  ## Parse incoming line from the port.
  ## TODO
  def parse_line(text) do
    Logger.info "Data: #{inspect text}"
    :todo
  end

end