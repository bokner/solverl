defmodule ReindeerOrdering do
  alias MinizincSolver, as: Solver

  import MinizincUtils

  @reindeer_model resource_file("mzn/reindeer.mzn")

  def solve() do
    {:ok, solutions} = Solver.solve_sync(@reindeer_model, %{})
    solutions
    |> MinizincResults.get_last_solution()
    |> Map.get(:data)
    |> Enum.sort_by(fn {_reindeer, position} -> position end)
    |> Enum.map_join(", ", fn {reindeer, _pos} -> reindeer end)
  end
end

defmodule ReindeerOrdering.Handler do

end
