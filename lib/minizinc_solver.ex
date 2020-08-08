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

  @type solver_opts() :: list(solver_opt())

  @type server_opts() :: GenServer.options()

  @default_solver_opts [
    minizinc_executable: MinizincUtils.default_executable(),
    solver: "gecode",
    time_limit: 60 * 5 * 1000,
    solution_handler: MinizincHandler.DefaultAsync
  ]

  ## How long to wait after :stop_solver message had been sent to a solver port, and
  ## nothing came from the port.

  @stop_timeout 5000

  @doc false
  def default_solver_opts, do: @default_solver_opts

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

  @spec solve(MinizincModel.mzn_model(), MinizincData.mzn_data(), solver_opts(), server_opts()) :: {:ok, pid()}


  def solve(model, data, solver_opts \\ [], opts \\ []) do
    solver_opts = [model: model, data: data] ++
           Keyword.merge(MinizincSolver.default_solver_opts, solver_opts)
    {:ok, _pid} = MinizincPort.start_link(solver_opts, opts)
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
  @spec solve_sync(MinizincModel.mzn_model(), MinizincData.mzn_data(), solver_opts(), server_opts()) :: [any()]

  def solve_sync(model, data, solver_opts \\ [], opts \\ []) do
    solution_handler = Keyword.get(solver_opts, :solution_handler, MinizincHandler.DefaultSync)
    # Plug sync_handler to have solver send the results back to us
    caller = self()
    sync_solver_opts = Keyword.put(
      solver_opts,
      :solution_handler,
      sync_handler(caller)
    )
    {:ok, solver_pid} = solve(model, data, sync_solver_opts, opts)
    receive_events(solution_handler, solver_pid)
  end

  ####################################################
  # Support for synchronous handling of results.
  ####################################################
  defp sync_handler(caller) do
    fn (event, results) ->
      send(caller, %{solver_results: {event, results}, from: self()})
    end
  end

  defp receive_events(solution_handler, solver_pid) do
    results = receive_events(solution_handler, solver_pid, %{})
    # Reverse list of solutions (as they are being added in reverse order)
    {nil, updated_results} = Map.get_and_update(
      results,
      :solutions,
      fn
        nil -> {nil, []};
        solutions -> {nil, Enum.reverse(solutions)}
      end
    )
    updated_results
  end



  defp stop_solving(solution_handler, solver_pid, acc) do
    stop_solver(solver_pid)
    final = completion_loop(solution_handler, solver_pid)
    ## Clean up message mailbox, just in case.
    MinizincUtils.flush()
    if final do
      {event, results} = final
      add_solver_event(event, results, acc)
    else
      acc
    end
  end

  defp completion_loop(solution_handler, solver_pid) do
    receive do
      %{from: pid, solver_results: {:solution, _results}} when pid == solver_pid ->
        ## Ignore new solutions
        completion_loop(solution_handler, solver_pid)
      %{from: pid, solver_results: {event, results}} when pid == solver_pid
                                                          and event in [:summary, :minizinc_error] ->
        {event, MinizincHandler.handle_solver_event(event, results, solution_handler)}
    after @stop_timeout ->
      Logger.debug "The solver has been silent after requesting a stop for #{@stop_timeout} msecs"
      nil
    end

  end


  defp receive_events(solution_handler, solver_pid, acc) do
    receive do
      %{from: pid, solver_results: {event, results}} when pid == solver_pid ->
        try do
          case MinizincHandler.handle_solver_event(event, results, solution_handler) do
            :skip ->
              receive_events(solution_handler, pid, acc)
            {:stop, data} ->
              stop_solving(solution_handler, pid, add_solver_event(event, data, acc))
            :stop ->
              stop_solving(solution_handler, pid, acc)
            result when event in [:summary, :minizinc_error] ->
              add_solver_event(event, result, acc)
            result ->
              receive_events(solution_handler, pid, add_solver_event(event, result, acc))
          end
        catch
          handler_exception ->
            Logger.error "Solution handler error: #{inspect handler_exception}"

            stop_solving(solution_handler, pid, Map.put(acc, :handler_exception, handler_exception))
        end
      unexpected ->
        Logger.error("Unexpected message from the solver sync handler (#{inspect solver_pid}): #{inspect unexpected}")
    end
  end

  defp add_solver_event(event, data, acc) when event in [:summary, :minizinc_error] do
    Map.put(acc, event, data)
  end

  defp add_solver_event(:solution, data, acc) do
    {nil, newacc} = Map.get_and_update(
      acc,
      :solutions,
      fn
        nil -> {nil, [data]};
        current -> {nil, [data | current]} end
    )
    newacc
  end
  ####################################################



  @doc """
    Get solver status
  """
  ## Solver status
  def solver_status(solver_pid) do
    GenServer.call(solver_pid, :solver_status)
  end

  @doc """
  Stop solver process.
  """
  def stop_solver(pid) do
    MinizincPort.stop(pid)
  end


  @doc """
  Get list of descriptions for solvers available to MinizincSolver.
  """
  def get_solvers(minizinc_executable \\ MinizincUtils.default_executable()) do
    solvers_json = MinizincUtils.cmd("#{minizinc_executable} --solvers-json")
    {:ok, solvers} = Jason.decode(solvers_json)
    solvers
  end

  @doc """
  Get list of solver ids for solvers available to MinizincSolver.
  """
  def get_solverids do
    for solver <- get_solvers(), do: solver["id"]
  end

  @doc """
  Lookup a solver by (possibly partial) id;
  for results, it could be 'cplex' or 'org.minizinc.mip.cplex'
  """

  def lookup(solver_id) do
    solvers = Enum.filter(
      get_solvers(),
      fn s ->
        s["id"] == solver_id or
        List.last(String.split(s["id"], ".")) == solver_id
      end
    )
    case solvers do
      [] ->
        {:solver_not_found, solver_id}
      [solver] ->
        {:ok, solver}
      [_ | _rest] ->
        {:solver_id_ambiguous, (for solver <- solvers, do: solver["id"])}
    end
  end


end
