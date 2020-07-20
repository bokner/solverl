defmodule MinizincSolver do
  @moduledoc """
    Minizinc solver API.
  """

  import MinizincInstance
  require Logger

  @type solver_opt() :: {:minizinc_executable, binary()} |
                        {:solver, binary()} |
                        {:time_limit, integer()} |
                        {:solution_handler, function()} |
                        {:extra_flags, binary()} |
                        {:model, MinizincModel.mzn_model()} |
                        {:data, MinizincData.mzn_data()}

  @type solver_opts() :: list(solver_opt() )

  @default_args [
    minizinc_executable: System.find_executable("minizinc"),
    solver: "gecode",
    time_limit: 60*5*1000,
    solution_handler: &__MODULE__.default_async_handler/2]

  @doc """
  Default solution handler for solve/2,3
  """
  def default_async_handler(_isFinal, instance_rec(status: _status) = instance) do
    Logger.info "Model info: method = #{MinizincModel.model_method(instance)}"
    Logger.info "Solution status: #{MinizincInstance.get_status(instance)}"
    Logger.info "Solution: #{inspect instance}"
  end

  @doc """
  Default solution handler for solve_sync/2,3
  """
  def default_sync_handler(false, instance_rec(status: _status, solution_data: data) = _instance) do
    {:solution, data}
  end

  def default_sync_handler(true, instance_rec(status: _status, solver_stats: stats) = _instance) do
    {:solver_stats, stats}
  end

  @doc """
  Default solver arguments.
  """
  def default_args, do: @default_args

  @doc """
  Shortcut for solve/2.
  """
  def solve(model) do
    solve(model, [])
  end



  @doc """
  Solve (asynchronously) with model, data and options.

  ## Example:

      MinizincSolver.solve("mzn/sudoku.mzn", "mzn/sudoku.dzn", [solution_handler: &Sudoku.solution_handler/2])
  """

  def solve(model, data, opts \\ []) do
    args = [model: model, data: data] ++
           Keyword.merge(MinizincSolver.default_args, opts)
    {:ok, _pid} = MinizincPort.start_link(args)
  end

  @doc """
  Shortcut for solve_sync/2.
  """
  def solve_sync(model) do
    solve_sync(model, [])
  end

  @doc """

  Solve (synchronously) with model, data and options.

  ## Example:

      # Solves N-queens puzzle with n = 4
      # Check out examples/n_queens.ex for more details on handling solutions.
      results = MinizincSolver.solve_sync("mzn/nqueens.mzn", %{n: 4})

  """
  def solve_sync(model, data, opts \\ []) do
    solution_handler = Keyword.get(opts, :solution_handler, &__MODULE__.default_sync_handler/2)
    # Plug sync_handler to have solver send the instance back to us
    caller = self()
    sync_opts = Keyword.put(opts,
      :solution_handler, sync_handler(caller))
    {:ok, solver_pid} = solve(model, data, sync_opts)
    receive_solutions(solution_handler, solver_pid)
  end

  ####################################################
  # Support for synchronous handling of results.
  ####################################################
  defp sync_handler(caller) do
     Logger.debug("Synch handler")
     fn(isFinal, instance) ->
        send(caller,  %{solver_instance: {isFinal, instance}, from: self()}) end
  end

  defp receive_solutions(solution_handler, solver_pid) do
    receive_solutions(solution_handler, solver_pid, [])
  end

  defp receive_solutions(solution_handler, solver_pid, acc) do
    receive do
      %{from: pid, solver_instance: {isFinal, instance}} when pid == solver_pid ->
        handler_res = solution_handler.(isFinal, instance)
        case handler_res do
          {:stop, data} ->
            stop_solver(pid)
            [data | acc]
          _res when isFinal ->
            [handler_res | acc]
          _res ->
            receive_solutions(solution_handler, pid, [handler_res | acc])
        end
      unexpected ->
        Logger.error("Unexpected message while receiving solutions: #{inspect unexpected}")
    end
  end
  ####################################################

  @doc """
  Stop solver process.
  """
  def stop_solver(pid) do
    {:ok, _instance} = MinizincPort.get_instance_and_stop(pid)
  end

  def prepare_solver_cmd(args) do
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

  @doc """
  Get list of descriptions for solvers available to Minizinc.
  """
  def get_solvers do
    solvers_json = to_string(:os.cmd('#{get_executable()} --solvers-json'))
    {:ok, solvers} = Jason.decode(solvers_json)
    solvers
  end

  @doc """
  Get list of solver ids for solvers available to Minizinc.
  """
  def get_solverids do
    for solver <- get_solvers(), do: solver["id"]
  end

  @doc """
  Lookup a solver by (possibly partial) id;
  for instance, it could be 'cplex' or 'org.minizinc.mip.cplex'
  """

  def lookup(solver_id) do
    solvers = Enum.filter(get_solvers(),
      fn s ->
        s["id"] == solver_id or
        List.last(String.split(s["id"], ".")) == solver_id
      end)
    case solvers do
      [] ->
        {:solver_not_found, solver_id}
      [solver] ->
        {:ok, solver}
      [_ | _rest] ->
        {:solver_id_ambiguous, (for solver <- solvers, do: solver["id"])}
    end
  end

  @doc """
  Default Minizinc executable.
  """
  def get_executable do
    default_args()[:minizinc_executable]
  end


end
