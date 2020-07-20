defmodule NQueens do
  @moduledoc false

  import MinizincInstance
  require Logger

  @queen_symbol "Q"

  # N queens puzzle
  def solve(n) do
    MinizincSolver.solve("mzn/nqueens.mzn", %{n: n}, [solution_handler: &NQueens.print_solutions/2])
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
