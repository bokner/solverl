defmodule MinizincSearch do
  @moduledoc """
    Meta-search, such as LNS, find_k_solutions, BAB (todo)...
  """

  import MinizincUtils
  import MinizincHandler

  ## Run LNS on the problem instance for given number of iterations;
  ## 'destruction_fun' produces additional constraints based on the obtained solutions and a model method.
  def lns(%{model: model} = instance, iterations, destruction_fun)
      when is_integer(iterations) and is_function(destruction_fun) do

    {_final_instance, final_results} = iterative(
      instance,
      iterations,
      fn
        _instance, nil, _iter_number ->
          :break
        _instance, results, iter_number ->
          lns_constraints = add_lns_constraints(results, destruction_fun, iter_number)
          ## Add LNS constraints to the initial model
          {:ok, Map.put(instance, :model, MinizincModel.merge(lns_constraints, model))}
      end
    )

    final_results
  end


  def lns(model, data \\ [], solver_opts \\ [], server_opts \\ [], iterations, destruction_fun) do
    lns(
      MinizincInstance.new(model, data, solver_opts, server_opts),
      iterations,
      destruction_fun
    )
  end

  defp add_lns_constraints(results, destruction_fun, iteration) do
    ## Add LNS constraints
    solution = MinizincResults.get_last_solution(results)
    method = MinizincResults.get_method(results)
    Enum.map(
      destruction_fun.(solution, method, iteration),
      fn c -> {:model_text, c} end
    )
  end

  def iterative(instance, iterations, step_fun) do
    {_final_instance, _final_results} = Enum.reduce_while(
      :lists.seq(1, iterations),
      {instance, nil},
      fn i, {prev_instance, prev_results} ->
        iteration_results = MinizincInstance.run(prev_instance)
        results = case MinizincResults.get_solution_count(iteration_results) do
          0 -> prev_results
          _solution_count -> iteration_results
        end
        case step_fun.(prev_instance, results, i) do
          :break ->
            {:halt, {prev_instance, results}}
          {:ok, updated_instance} ->
            {:cont, {updated_instance, results}}
        end

      end
    )
  end




  def lns_objective_constraint(solution, objective_var, method) when method in [:maximize, :minimize] do
    objective_value = MinizincResults.get_solution_value(solution, objective_var)
    constraint("#{objective_var} #{objective_predicate(method)} #{objective_value}")
  end

  def find_k_handler(k, solution_handler \\ MinizincHandler.Default) do
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
    Enum.take_random(
      Enum.with_index(values, offset),
      round(length(values) * (1 - rate))
    )
  end

  ## Takes the name and solution for an array of decision variables and
  ## creates the list of constraints for variables that will be fixed for the next iteration of solving.
  ## The destruction_rate (a value between 0 and 1) states the percentage of the variables in the
  ## the array that should be 'dropped'.
  ##
  def destroy_var(variable_name, values, destruction_rate, offset \\ 0) when is_binary(variable_name) do
    ## Randomly choose (1 - destruction_rate)th part of values to fix...
    ## Generate constraints
    list_to_lns_constraints(variable_name, destroy(values, destruction_rate, offset))
  end

  def list_to_lns_constraints(variable_name, values) do
    Enum.join(
      Enum.map(
        values,
        fn {d, idx} -> lns_constraint(variable_name, idx, d) end
      )
    )
  end

  defp lns_constraint(varname, idx, val) do
    constraint("#{varname}[#{idx}] = #{val}")
  end



end
