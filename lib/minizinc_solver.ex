defmodule MinizincSolver do
  @moduledoc """
    Minizinc solver API.
  """

  require Logger

  @type solver_opt() :: {:minizinc_executable, binary()} |
                        {:solver, binary()} |
                        {:time_limit, integer()} |
                        {:solution_handler, function()} |
                        {:extra_flags, binary()}

  @type solver_opts() :: list(solver_opt() )

  @default_args [
    minizinc_executable: System.find_executable("minizinc"),
    solver: "gecode",
    time_limit: 60*5*1000,
    solution_handler: MinizincHandler.DefaultAsync]


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

      # Solve Sudoku puzzle with "mzn/sudoku.mzn" model, "mzn/sudoku.dzn" data,
      # and custom solution handler Sudoku.solution_handler/2.
      #
      MinizincSolver.solve("mzn/sudoku.mzn", "mzn/sudoku.dzn", [solution_handler: &Sudoku.solution_handler/2])

    Check out `Sudoku` module in `examples/sudoku.ex` for more details on handling solutions.
  """

  @spec solve(MinizincModel.mzn_model(), MinizincData.mzn_data(), solver_opts()) :: {:ok, pid()}

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

      # Solve N-queens puzzle with n = 4.
      # Use Gecode solver, solve within 1000 ms.
      #
      results = MinizincSolver.solve_sync("mzn/nqueens.mzn", %{n: 4}, [solver: "gecode", time_limit: 1000])

    Check out `NQueens` module in `examples/nqueens.ex` for more details on handling solutions.

  """
  @spec solve_sync(MinizincModel.mzn_model(), MinizincData.mzn_data(), solver_opts()) :: [any()]

  def solve_sync(model, data, opts \\ []) do
    solution_handler = Keyword.get(opts, :solution_handler, MinizincHandler.DefaultSync)
    # Plug sync_handler to have solver send the results back to us
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
     fn(event, results) ->
        send(caller,  %{solver_results: {event, results}, from: self()}) end
  end

  defp receive_solutions(solution_handler, solver_pid) do
    receive_solutions(solution_handler, solver_pid, [])
  end

  defp receive_solutions(solution_handler, solver_pid, acc) do
    receive do
      %{from: pid, solver_results: {event, results}} when pid == solver_pid ->
        handler_res = MinizincHandler.handle_solver_event(event, results, solution_handler)
        case handler_res do
          {:stop, data} ->
            stop_solver(pid)
            [data | acc]
          _res when event in [:final, :minizinc_error] ->
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
    {:ok, _results} = MinizincPort.get_results_and_stop(pid)
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
  for results, it could be 'cplex' or 'org.minizinc.mip.cplex'
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
