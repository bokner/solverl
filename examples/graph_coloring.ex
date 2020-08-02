defmodule GraphColoring do
  @moduledoc """
  Example: Graph Coloring
"""
  require Logger

  @gc_model "mzn/graph_coloring.mzn"

  def optimal_coloring(data, opts \\ [])

  def optimal_coloring(dzn_file, opts) when is_binary(dzn_file) do
    solve_sync(dzn_file, opts)
  end

  def optimal_coloring({vertices, edges}, opts) when is_integer(vertices) and is_list(edges) do
    solve_sync(%{edges: edges, n: vertices, n_edges: length(edges)},
      opts)
  end

  defp solve_sync(data, opts) do
    MinizincSolver.solve_sync(@gc_model, data, Keyword.put_new(opts, :solution_handler, GraphColoring.SyncHandler))
  end

  def show_results(gc_results) do
     last_solution = MinizincResults.get_last_solution(gc_results)
     color_classes = MinizincResults.get_solution_value(last_solution, "vertex_sets")
     Logger.info "Best coloring found: #{MinizincResults.get_solution_objective(last_solution)} colors"
     solution_status = gc_results[:summary][:status]
     Logger.info "Optimal? #{if solution_status == :optimal, do: "Yes", else: "No"}"
     Enum.each(Enum.with_index(
          ## Model-specific: there are empty color classes, which will be dropped
          Enum.filter(color_classes, fn c -> MapSet.size(c) > 0 end)),
            fn {class, idx} ->
              Logger.info "Color #{idx + 1} -> vertices: #{Enum.join(class, ", ")}"
            end)
  end

  def do_coloring(data, opts) do
    optimal_coloring(data, opts) |> show_results
  end

end


defmodule  GraphColoring.SyncHandler do

  @moduledoc false

  require Logger

  use MinizincHandler

  def handle_solution(solution) do
    Logger.info "Found coloring to #{MinizincResults.get_solution_objective(solution)} colors"
    solution
  end

  def handle_summary(summary) do
    summary
  end

end