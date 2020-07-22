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

  def solve_sync(n, opts \\ [solution_handler: &solution_handler/2]) do
    results = MinizincSolver.solve_sync(@nqueens_model, %{n: n}, opts)
    Enum.each(results,
      fn {:solver_stats, stats} ->
            Logger.info "Solver stats:\n #{inspect stats}"
        {:solution, solution} ->
            Logger.info print_board(solution["q"]) <> "\n-----------------------"
      end)
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
