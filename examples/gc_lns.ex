defmodule LNS.GraphColoring do
  @moduledoc false

  require Logger

  import MinizincSearch

  @gc_model "mzn/graph_coloring.mzn"

  def do_lns(data, iterations, destruction_rate, opts \\ []) do
    instance = MinizincInstance.new(@gc_model, data, Keyword.put(opts, :solution_handler, GraphColoring.LNSHandler))
    lns(instance, iterations,
      fn solution, method ->
        [lns_objective_constraint(solution, "chromatic", method),
          destroy_colors(solution[:data]["colors"],
            destruction_rate)]
      end)
  end

  def destroy_colors(coloring, rate) do
    vertices = destroy(coloring, rate)
    ## Normalize colors
    new_colors = normalize_colors(Enum.map(vertices, fn {c, _v} -> c end))
    ## Update reduced coloring with new colors
    {_old_colors, v} = Enum.unzip(vertices)

    new_coloring = Enum.zip(new_colors, v)
    ## Generate constraints for the partial coloring

    Logger.debug "Original coloring: #{length(coloring)}, fixed coloring: #{length(vertices)}"
    Logger.debug "Normalized coloring: #{Enum.max(new_colors)} colors"
    Logger.debug "New coloring constraints: #{length(new_coloring)}"
    list_to_lns_constraints("colors", new_coloring)

  end

  ## Due to how the model we use works,
  ## the colors assigned to vertices are not sequentially enumerated.
  ## For example, the only 2 colors could have numbers 6 and 11.
  ## To avoid clashes with model's objective, we will renumerate colors
  ## [6, 11] -> [0, 1]
  def normalize_colors(colors) do
    color_set = MapSet.new(colors) |> MapSet.to_list
    Enum.map(colors, fn c -> Enum.find_index(color_set, fn x -> x == c end)  end)
  end

end


defmodule GraphColoring.LNSHandler do
  @moduledoc false

  require Logger

  use MinizincHandler

  def handle_solution(%{index: _count} = solution)  do
    Logger.info "Found #{MinizincResults.get_solution_objective(solution)}-coloring"
    ## Break after first found solution
    #if count > 10, do: {:break, solution}, else: solution
    solution
  end


  def handle_summary(%{last_solution: solution, status: status} = summary) do

    Logger.info "Objective: #{MinizincResults.get_solution_objective(solution)}"
    Logger.info "Status: #{status}"
    summary
  end


end