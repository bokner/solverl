defmodule MinizincSearch do
  @moduledoc false

  import MinizincUtils
  import MinizincHandler

  ## Run LNS on the problem instance for given number of iterations;
  ## 'destruction_fun' produces additional constraints based on the obtained solutions and a model method.
  def lns(instance, iterations, destruction_fun) when is_integer(iterations) and is_function(destruction_fun) do
    lns_impl(Map.put(instance, :lns_constraints, []), iterations, 0, destruction_fun, nil)
  end


  def lns(model, data \\ [], solver_opts \\ [], server_opts \\ [], iterations, destruction_fun) do
    lns(
      MinizincInstance.new(model, data, solver_opts, server_opts),
      iterations, destruction_fun)
  end


  def lns_impl(_instance, 0, _iterations, _destruction_fun, acc_results) do
    acc_results
  end

  def lns_impl(%{model: model, lns_constraints: constraints} = instance, iterations, iter_number, destruction_fun, acc_results) when iterations > 0 do
    ## Run iteration
    iter_number = iter_number + 1
    lns_model = MinizincModel.merge(model, constraints)
    iteration_results = MinizincInstance.run(%{instance | model: lns_model})
    case MinizincResults.get_status(iteration_results) do
      status when status in [:satisfied, :optimal] ->
        ## Add LNS constraints
        constraints = lns_constraints(
                      destruction_fun,
                      MinizincResults.get_last_solution(iteration_results),
                      MinizincResults.get_method(iteration_results),
                      iter_number
                   )
        updated_instance = Map.put(instance, :lns_constraints, constraints)
        lns_impl(updated_instance, iterations - 1, iter_number, destruction_fun, iteration_results)
      _no_solution ->
        acc_results
    end
  end




  ## Apply destruction function and create a text representation of LNS constraints
  def lns_constraints(destruction_fun, solution, method, iteration \\ nil) do
      Enum.map(destruction_fun.(solution, method, iteration),
        fn c -> {:model_text, c} end)
  end

  def lns_objective_constraint(solution, objective_var, method) when method in [:maximize, :minimize] do
      objective_value = MinizincResults.get_solution_value(solution, objective_var)
      constraint("#{objective_var} #{objective_predicate(method)} #{objective_value}")
  end

  def find_k_handler(k, solution_handler \\ MinizincHandler.DefaultSync) do
    fn
      ## Intercept the solution handler and force no more than k solutions.
      (:solution, %{index: count} = _solution) when count > k ->
        :break;

      ## Use the original handler for processing otherwise
      (event, data) ->
        handle_solver_event(event, data, solution_handler)
    end
  end



  defp objective_predicate(:maximize) do
    ">"
  end

  defp objective_predicate(:minimize) do
    "<"
  end

  defp objective_predicate(other) do
    throw {:non_optimization_method, other}
  end

  ## Randomly choose (1 - rate)th part of values
  ## and return them keyed with their indices.
  ##
  def destroy(values, rate, offset \\ 0) when is_list(values) do
    Enum.take_random(Enum.with_index(values, offset),
      round(length(values) * (1 - rate)))
  end

  ## Takes the name and solution for an array of decision variables and
  ## creates the list of constraints for variables that will be fixed for the next iteration of solving.
  ## The destruction_rate (a value between 0 and 1) states the percentage of the variables in the
  ## the array that should be 'dropped'.
  ##
  def destroy_var(variable_name, values, destruction_rate, offset \\0) when is_binary(variable_name) do
    ## Randomly choose (1 - destruction_rate)th part of values to fix...
    ## Generate constraints
    list_to_lns_constraints(variable_name, destroy(values, destruction_rate, offset))
  end

  def list_to_lns_constraints(variable_name, values) do
    Enum.join(
      Enum.map(values,
        fn {d, idx} -> lns_constraint(variable_name, idx, d) end))
  end

  defp lns_constraint(varname, idx, val) do
    constraint("#{varname}[#{idx}] = #{val}")
  end



end
