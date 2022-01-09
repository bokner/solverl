defmodule MinizincSolver do
  @moduledoc """
    Minizinc solver API.
  """

  require Logger
  import MinizincUtils

  @type solver_opt() ::
          {:minizinc_executable, binary()}
          | {:solver, binary()}
          | {:checker, MinizincModel.mzn_model()}
          | {:time_limit, integer()}
          | {:solution_handler, function()}
          | {:solution_timeout, timeout()}
          | {:fzn_timeout, timeout()}
          | {:sync_to, pid() | nil}
          | {:extra_flags, binary()}
          | {:debug_exec, integer()}
          | {:cmd_opts, list()}

  @type solver_opts() :: list(solver_opt())

  @type server_opts() :: GenServer.options()

  @default_solver_opts [
    solver: "gecode",
    checker: [],
    time_limit: 60 * 5 * 1000,
    solution_handler: MinizincHandler.Default,
    solution_timeout: :infinity,
    fzn_timeout: :infinity,
    sync_to: nil,
    cmd_opts: []
  ]

  @doc false
  def default_solver_opts do
    [{:minizinc_executable, MinizincUtils.default_executable()} | @default_solver_opts]
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

  @spec solve(MinizincModel.mzn_model(), MinizincData.mzn_data(), solver_opts(), server_opts()) ::
          {:ok, pid()}
          | {
              :error,
              any()
            }

  def solve(model, data \\ [], solver_opts \\ [], server_opts \\ []) do
    ## Merge with defaults
    solver_opts = build_solver_opts(solver_opts)
    case MinizincModel.mzn_dzn_info(
           model,
           data,
           solver_opts
         ) do
      {:error, error} ->
        {:error, error}

      model_info ->
        case MinizincData.check_dzn(model_info) do
          :ok ->
            ## Lookup the solver
            case MinizincSolver.lookup(solver_opts[:solver]) do
              {:ok, solver} ->
                ## Add solution checker, if any
                model_info = MinizincModel.add_checker(solver_opts[:checker], model_info)
                ## Run the instance
                {:ok, _pid} =
                  MinizincPort.start_link(model_info, solver, solver_opts, server_opts)

              lookup_error ->
                Logger.debug("Solver lookup error: #{inspect(lookup_error)}")
                lookup_error
            end

          dzn_error ->
            Logger.debug("model/dzn error: #{inspect(dzn_error)}")
            dzn_error
        end
    end
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
  @spec solve_sync(
          model :: MinizincModel.mzn_model(),
          data :: MinizincData.mzn_data(),
          solver_opts :: solver_opts(),
          server_opts :: server_opts()
        ) :: {:ok, any()} | {:error, any()}

  def solve_sync(model, data \\ [], solver_opts \\ [], opts \\ []) do
    solution_handler = Keyword.get(solver_opts, :solution_handler, MinizincHandler.Default)

    sync_solver_opts =
      Keyword.put(
        solver_opts,
        :sync_to,
        self()
        ## The solver process will send results back to the caller
      )

    case solve(model, data, sync_solver_opts, opts) do
      {:ok, solver_pid} ->
        result = receive_events(solution_handler, solver_pid)
        build_result(result)
      {:error, error} ->
        {:error, error}
    end
  end

  defp build_result(%{minizinc_error: _error} = error_event) do
    {:error, error_event}
  end

  defp build_result(events) do
    (events && {:ok, events}) || {:error, :unexpected}
  end

  defp receive_events(solution_handler, solver_pid) do
    results = receive_events(solution_handler, solver_pid, %{})
    # Reverse list of solutions (as they are being added in reverse order)
    results &&
    Map.update(
        results,
        :solutions,
        [],
        fn
          solutions -> Enum.reverse(solutions)
        end
      )
  end

  defp receive_events(solution_handler, solver_pid, acc) do
    receive do
      %{from: pid, solver_results: {event, data}} when pid == solver_pid ->
        if event in [:summary, :minizinc_error] do
          add_solver_event(event, data, acc)
        else
          receive_events(solution_handler, pid, add_solver_event(event, data, acc))
        end

      unexpected ->
        Logger.error(
          "Unexpected message from the solver sync handler (#{inspect(solver_pid)}): #{
            inspect(unexpected)
          }"
        )
        nil
    end
  end

  defp add_solver_event(:solution, data, acc) do
      Map.update(
        acc,
        :solutions,
        [data],
        fn
          current -> [data | current]
        end
      )
  end

  defp add_solver_event(event, data, acc) do
    Map.put(acc, data_key(event), data)
  end

  defp data_key(:compiled) do
    :compilation_info
  end

  defp data_key(event) do
    event
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

  def update_solution_handler(pid, handler) do
    MinizincPort.update_solution_handler(pid, handler)
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
    solvers =
      Enum.filter(
        get_solvers(),
        fn s ->
          s["id"] == solver_id or
            List.last(String.split(s["id"], ".")) == solver_id
        end
      )

    case solvers do
      [] ->
        {:error, {:solver_not_found, solver_id}}

      [solver] ->
        {:ok, solver}

      [_ | _rest] ->
        {:error, {:solver_id_ambiguous, for(solver <- solvers, do: solver["id"])}}
    end
  end
end
