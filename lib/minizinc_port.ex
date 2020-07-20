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
    command = MinizincSolver.prepare_solver_cmd(args)
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
          solution_handler: handlerFun} = state) do
    ##TODO: handle long lines
    {_eol, text_line} = line
    new_results = MinizincParser.handle_output(current_results, text_line)
    case results_rec(new_results, :status) do
      nil ->
        {:noreply, %{state | current_results: new_results}}
      :satisfied ->
        # 'false' signifies non-final solution
        new_state = %{state | current_results: MinizincResults.reset_results(new_results)}
        # Solution handler can force the termination of solver process
        case handlerFun.(:solution, new_results) do
          :stop ->
            {:stop, :normal, new_state}
          _other ->
           {:noreply, new_state}
        end
      _terminal_status ->
        {:noreply, %{state | current_results: new_results} }

    end
  end

  # Handle process exits
  def handle_info(
      {port, {:exit_status, port_status}},
        %{port: port,
          current_results: current_results,
          solution_handler: handlerFun} = state) do
    Logger.debug "Port exit: :exit_status: #{port_status}"

    ## Adjust final solution status.
    ## Normally, the solver output has a terminating line (see MinizincParser.@terminating_separators),
    ## which forces line parser to set up appropriate solution status.
    ## However, when the solver terminates by a timeout, parser has no way to update the status (no terminating line
    ## comes from Minizinc. The easiest way then to set status to SATISFIED in case there were any solutions.
    results = MinizincResults.adjust_status(current_results)

    handlerFun.(:final, results
               #MinizincResults.merge_solver_stats(current_results, results)
               )
    new_state = %{state | exit_status: port_status, current_results: results}

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
  def handle_call(:get_results,  {from, _ref}, state) do
    Logger.debug "#{:erlang.pid_to_list(from)} asks for the results..."
    {:reply, {:ok, state[:current_results]}, state}
  end

  ## Same as above, but stop the solver
  def handle_call(:get_results_and_stop,  _from, state) do
    {:stop, :normal, {:ok, state[:current_results]}, state}
  end

  ## Helpers
  def get_results(pid) do
    GenServer.call(pid, :get_results)
  end

  def get_results_and_stop(pid) do
    GenServer.call(pid, :get_results_and_stop)
  end

end