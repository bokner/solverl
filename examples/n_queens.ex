defmodule NQueens do
  @moduledoc false

  # N queens puzzle
  def solve(n, args \\ []) do
    MinizincSolver.solve("mzn/nqueens.mzn", %{n: n}, args)
  end
end
