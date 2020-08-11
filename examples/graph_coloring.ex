defmodule GraphColoring do
  @moduledoc false

  require Logger

  import MinizincSearch

  ## Example: Graph Coloring
  @gc_model "mzn/graph_coloring.mzn"

  def optimal_coloring(data, opts \\ [])

  def optimal_coloring(dzn_file, opts) when is_binary(dzn_file) do
    solve_sync(dzn_file, opts)
  end

  def optimal_coloring({vertices, edges}, opts) when is_integer(vertices) and is_list(edges) do
    solve_sync(
      %{edges: edges, n: vertices, n_edges: length(edges)},
      opts
    )
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
    Enum.each(
      Enum.with_index(
        ## Model-specific: there are empty color classes, which will be dropped
        Enum.filter(color_classes, fn c -> MapSet.size(c) > 0 end)
      ),
      fn {class, idx} ->
        Logger.info "Color #{idx + 1} -> vertices: #{Enum.join(class, ", ")}"
      end
    )
  end

  def do_coloring(data, opts \\ []) do
    optimal_coloring(data, opts)
    |> show_results
  end

  def do_lns(data, iterations, destruction_rate, opts \\ []) do
    instance = MinizincInstance.new(@gc_model, data, Keyword.put(opts, :solution_handler, GraphColoring.LNSHandler))
    lns(instance, iterations,
       fn solution, method ->
         [lns_objective_constraint(solution, "chromatic", method),
         destruct_colors(solution[:data]["colors"],
           destruction_rate)]
        end)
  end

  def destruct_colors(coloring, rate) do
    vertices = destruct(coloring, rate)
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
  ## To avoid clashes with model's objective, we will renumerate colors as
  ## [6, 11] -> [0, 1]
  def normalize_colors(colors) do
    color_set = MapSet.new(colors) |> MapSet.to_list
    Enum.map(colors, fn c -> Enum.find_index(color_set, fn x -> x == c end)  end)
  end

end


defmodule  GraphColoring.SyncHandler do

  @moduledoc false

  require Logger

  use MinizincHandler

  def handle_solution(solution) do
    Logger.info "Found #{MinizincResults.get_solution_objective(solution)}-coloring"
    solution
  end


end

defmodule GraphColoring.LNSHandler do
  @moduledoc false

  require Logger

  use MinizincHandler

  def handle_solution(%{index: count} = solution)  do
    Logger.info "Found #{MinizincResults.get_solution_objective(solution)}-coloring"
    ## Break after first found solution
    if count > 10, do: {:break, solution}, else: solution
  end


  def handle_summary(%{last_solution: solution, status: status} = summary) do

    Logger.info "Objective: #{MinizincResults.get_solution_objective(solution)}"
    Logger.info "Status: #{status}"
    summary
  end


end