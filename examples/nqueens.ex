defmodule NQueens do
  @moduledoc """
    Example: N-queens solver.
  """

  import MinizincResults
  require Logger

  @nqueens_model "mzn/nqueens.mzn"
  @queen_symbol "Q"

  # N queens puzzle
  # Async solving
  def solve(n) do
    MinizincSolver.solve(@nqueens_model, %{n: n}, [solution_handler: &print_solutions/2])
  end

  def solve_sync(n) do
    results = MinizincSolver.solve_sync(@nqueens_model, %{n: n})
    Enum.each(results,
      fn {:solver_stats, stats} ->
            Logger.info "Solver stats:\n #{inspect stats}"
        {:solution, solution} ->
            Logger.info print_board(solution["q"]) <> "\n-----------------------"
      end)
  end

  ## Printing solver stats
  defp print_solutions(:final,
        results_rec(
          solver_stats: stats
        ) = results
      )
    do
    Logger.info "Solution status: #{MinizincResults.get_status(results)}"
    Logger.info "Solver stats:\n #{inspect stats}"
  end

  ## Printing solutions
  defp print_solutions(:solution, results_rec(
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
