defmodule NQueens do
  @moduledoc """
    Example: N-queens solver.
  """

  import MinizincResults
  require Logger

  @nqueens_model "mzn/nqueens.mzn"
  @queen_symbol "\u2655"

  # N queens puzzle
  # Async solving
  def solve(n, opts \\ [solution_handler: &solution_handler/2]) do
    MinizincSolver.solve(@nqueens_model, %{n: n}, opts)
  end

  def solve_sync(n, opts \\ [solution_handler: NQueens.SyncHandler]) do
    MinizincSolver.solve_sync(@nqueens_model, %{n: n}, opts)
  end

  ## Printing solver stats
  def solution_handler(:final,
        results_rec(
          solver_stats: stats
        ) = results
      )
    do
    Logger.info "Solution status: #{MinizincResults.get_status(results)}"
    Logger.info "Solver stats:\n #{inspect stats}"
  end

  ## Printing solutions
  def solution_handler(:solution, results_rec(
              status: _status,
              solution_count: _count,
              solution_data: data) = _results) do
    Logger.info print_board(data["q"]) <> "\n-----------------------"
  end

  ## quuens[i] = j <=> row i has a queen in position j.
  def print_board(queens) do
    n = length(queens)
    "\n" <> Enum.join(
    for i <- 1..n do
      Enum.join(
      for j <- 1..n do
        if Enum.at(queens, i - 1) == j, do: @queen_symbol, else: "."
      end, " ")
    end, "\n")
  end

end

defmodule NQueens.SyncHandler do
  require Logger
  import NQueens

  @doc false
  def handle_solution(solution, _stats, _timestamp, _count)  do
    Logger.info print_board(solution["q"]) <> "\n-----------------------"
    {:solution, solution}
  end

  @doc false
  def handle_final(status, last_solution, solver_stats, fzn_stats) do
    Logger.info "Solver stats:\n #{inspect solver_stats}"
    MinizincHandler.DefaultSync.handle_final(status, last_solution, solver_stats, fzn_stats)
  end

  @doc false
  def handle_minizinc_error(error) do
    Logger.info "Minizinc error: #{error}"
    {:error, error}
  end

end
