defmodule MinizincPort do

  use GenServer
  require Logger

  # GenServer API
  def start_link(args \\ [], opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  def init(args \\ []) do
    Process.flag(:trap_exit, true)
    # Locate minizinc executable
    command = System.find_executable("minizinc")
    port = Port.open({:spawn, command}, [:binary, :exit_status])
    Port.monitor(port)

    {:ok, %{port: port, last_output: nil, exit_status: nil} }
  end

  def terminate(reason, %{port: port} = state) do
    Logger.info "** TERMINATE: #{inspect reason}"
    Logger.info "in state: #{inspect state}"

    port_info = Port.info(port)
    os_pid = port_info[:os_pid]

    if os_pid, do:  Logger.warn "Orphaned OS process: #{os_pid}"

    :normal
  end

  # Handle data coming from the command's STDOUT
  def handle_info({port, {:data, text_line}}, %{port: port} = state) do
    Logger.info "Data: #{inspect text_line}"
    {:noreply, %{state | last_output: String.trim(text_line)}}
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

  def handle_info({:EXIT, port, :normal}, state) do
    Logger.info "handle_info: EXIT"
    {:stop, :normal, state}
  end

  def handle_info(msg, state) do
    Logger.info "Unhandled message: #{inspect msg}"
    {:noreply, state}
  end

end