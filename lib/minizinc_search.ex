defmodule MinizincSearch do
  @moduledoc false

  import MinizincUtils

  ## Given a function that 'destructs' parts of values
  ## of the solution's decision variables obtained in a previous iteration;
  ## run the solver on a
  def lns(solver_instance, iterations, destruction_fun) when iterations > 0 do
    last_iteration_instance = Enum.reduce(:lists.seq(1, iterations - 1),
      solver_instance,
      fn _i, instance ->
        results = MinizincInstance.run(instance)
        ## TODO: take 'method' from instance
        method = MinizincResults.get_method(results)
        last_solution = MinizincResults.get_last_solution(results)
        updated_model = add_lns_constraints(solver_instance[:model], destruction_fun, last_solution, method)
        Map.put(instance, :model, updated_model)
      end
    )
    ## Last iteration
    MinizincInstance.run(last_iteration_instance)
  end

  ## Apply destruction function and add the resulting model chunk to the model
  def add_lns_constraints(model, destruction_fun, solution, method) do
    MinizincModel.merge(model,
      Enum.map(destruction_fun.(solution, method),
        fn c -> {:model_text, c} end))
  end

  def lns_objective_constraint(solution, objective_var, method) when method in [:maximize, :minimize] do
      objective_value = MinizincResults.get_solution_value(solution, objective_var)
      inequality = if method == :maximize, do: ">", else: "<"
      constraint("#{objective_var} #{inequality} #{objective_value}")
  end

  ## Randomly choose (1 - rate)th part of values
  ## and return them keyed with their indices.
  ##
  def destruct(values, rate, offset) when is_list(values) do
    Enum.take_random(Enum.with_index(values, offset),
      round(length(values) * (1 - rate)))
  end

  ## Takes the name and solution for an array of decision variables and
  ## creates the list of constraints for variables that will be fixed for the next iteration of solving.
  ## The destruction_rate (a value between 0 and 1) states the percentage of the variables in the
  ## the array that should be 'dropped'.
  ##
  def destruct_var(solution, varname, destruction_rate, offset \\0) when is_binary(varname) do
    ## Randomly choose (1 - destruction_rate)th part of vardata to fix...
    vardata = MinizincResults.get_solution_value(solution, varname)
    fixed_data = destruct(vardata, destruction_rate, offset)
    ## Generate constraints
    Enum.join(
      Enum.map(fixed_data,
              fn {d, idx} -> lns_constraint(varname, idx, d) end))
  end


  defp lns_constraint(varname, idx, val) do
    constraint("#{varname}[#{idx}] = #{val}")
  end



end
