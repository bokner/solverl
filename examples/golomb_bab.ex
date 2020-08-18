defmodule GolombBAB do

  import MinizincSearch

  require Logger

  @moduledoc false

  @objective_var "obj"
  @model "mzn/golomb_mybab.mzn"

  def solve(opts \\ []) do
    instance = MinizincInstance.new(@model, [], opts)

    results = bab(
      instance,
      fn solution, method, _iteration ->
        objective = MinizincResults.get_solution_objective(solution)
        Logger.info "Intermediate solution with objective #{objective}"
        ## Post new constraint for the objective
        [better_objective_constraint(solution, @objective_var, method)]
      end
    )

    last_solution = MinizincResults.get_last_solution(results)
    Logger.info "golomb #{MinizincResults.get_solution_objective(last_solution)}"
    Logger.info "#{inspect MinizincResults.get_solution_value(last_solution, "mark")}"
#  results

  end
end
