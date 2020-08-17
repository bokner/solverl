defmodule LNS.GraphColoring do
  @moduledoc false

  require Logger

  import MinizincSearch

  @gc_model "mzn/graph_coloring.mzn"

  ## Find optimal solution for Graph Coloring instance using Randomized LNS.
  ## 'destruction_rate' is a fraction of the vertex coloring (represented in the model
  ## by 'colors' var) that will be 'destroyed' for the next iteration.
  ##
  def do_lns(data, iterations, destruction_rate, solver_opts \\ [], opts \\ []) do
    instance = MinizincInstance.new(@gc_model, data, solver_opts, opts)
    result = lns(instance, iterations,
      fn solution, method, iteration ->
        Logger.info "Iteration #{iteration}: #{MinizincResults.get_solution_objective(solution)}-coloring"
        [lns_objective_constraint(solution, "chromatic", method),
          destroy_colors(solution[:data]["colors"],
            destruction_rate)]
      end)

    Logger.info "LNS final: #{get_objective(result)}-coloring"
  end

  ## Find optimal solution for Graph Coloring instance using adaptive LNS.
  ## It's the same as Randomized LNS, but the destruction rate gets increased by 'delta' with every iteration.
  ##
  def do_adaptive_lns(data, iterations, initial_rate, delta, solver_opts \\ [], opts \\ []) do
    instance = MinizincInstance.new(@gc_model, data, solver_opts, opts)
    result = lns(instance, iterations,
     fn solution, method, iteration ->
       destruction_rate = initial_rate + (iteration - 1 ) * delta
      Logger.info "Iteration #{iteration}: #{MinizincResults.get_solution_objective(solution)}-coloring, rate: #{destruction_rate}"
      [lns_objective_constraint(solution, "chromatic", method),
        destroy_colors(solution[:data]["colors"],
          destruction_rate)]
    end)

    Logger.info "LNS final: #{get_objective(result)}-coloring"
  end



  defp get_objective(result) do
    MinizincResults.get_solution_objective(
      MinizincResults.get_last_solution(result))
  end

  def destroy_colors(coloring, rate) do
    vertices = destroy(coloring, rate)
    ## Normalize colors
    new_colors = normalize_colors(Enum.map(vertices, fn {c, _v} -> c end))
    ## Update reduced coloring with new colors
    {_old_colors, v} = Enum.unzip(vertices)

    new_coloring = Enum.zip(new_colors, v)
    ## Generate constraints for the partial coloring
    list_to_lns_constraints("colors", new_coloring)

  end

  ## Because of the way the model we use works,
  ## the colors assigned to vertices are not sequentially enumerated.
  ## For example, the only 2 colors could have numbers 6 and 11.
  ## To avoid clashes with model's objective, we will relabel colors,
  ## i.e., [6, 11] -> [0, 1]
  def normalize_colors(colors) do
    color_set = MapSet.new(colors) |> MapSet.to_list
    Enum.map(colors, fn c -> Enum.find_index(color_set, fn x -> x == c end)  end)
  end

end


