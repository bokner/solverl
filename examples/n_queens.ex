defmodule NQueens do
  @moduledoc false

  import MinizincInstance
  require Logger

  @nqueens_model "mzn/nqueens.mzn"
  @queen_symbol "Q"

  # N queens puzzle
  # Async solving
  def solve(n) do
    MinizincSolver.solve(@nqueens_model, %{n: n}, [solution_handler: &NQueens.print_solutions/2])
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
  def print_solutions(true,
        instance_rec(
          solver_stats: stats
        ) = instance
      )
    do
    Logger.info "Solution status: #{MinizincInstance.get_status(instance)}"
    Logger.info "Solver stats:\n #{inspect stats}"
  end

  ## Printing solutions
  def print_solutions(false, instance_rec(
              status: _status,
              solution_count: _count,
              solution_data: data) = _instance) do
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
