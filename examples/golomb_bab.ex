defmodule GolombBAB do

  import MinizincSearch
  import MinizincUtils

  require Logger

  @moduledoc false

  @objective_var "obj"
  @model "mzn/golomb_mybab.mzn"

  def solve(opts \\ []) do
    instance = MinizincInstance.new(resource_file(@model), [], opts)

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
    Logger.info "#{MinizincResults.get_solution_output(last_solution)}"
    
  end
end
