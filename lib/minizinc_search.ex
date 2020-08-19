defmodule MinizincSearch do
  @moduledoc """
    Meta-search, such as LNS, find_k_solutions, BAB (todo)...
  """

  import MinizincUtils
  import MinizincHandler

  require Logger

  @doc """
  Make a handler that breaks after k solutions found by a given solution handler.
"""
  def find_k_handler(k,  solution_handler \\ MinizincHandler.Default)

  def find_k_handler(k, nil) do
    ## No solution handler to wrap, use default as a base.
    find_k_handler(k, MinizincHandler.Default)
  end

  def find_k_handler(k, solution_handler) do
    fn
      ## Intercept the solution handler and force no more than k solutions.
      (:solution, %{index: count} = solution) when count == k ->
        sol = handle_solver_event(:solution, solution, solution_handler)
        {:break, sol}

      ## Use the original handler for processing otherwise
      (event, data) ->
        handle_solver_event(event, data, solution_handler)
    end
  end

  @doc """
  Run for a given number of iterations. 'step_fun' is a function that
  controls the execution.
  """
  def iterative(instance, iterations, step_fun) do
    {_final_instance, _final_results} = Enum.reduce_while(
      :lists.seq(1, iterations),
      {instance, nil},
      fn i, {prev_instance, prev_results} ->
        iteration_results = MinizincInstance.run(prev_instance)
        results = if MinizincResults.has_solution(iteration_results) do
          iteration_results
        else
          prev_results
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

  def repeat(instance, step_fun) do
    repeat_impl(instance, step_fun, 1, nil)
  end

  defp repeat_impl(instance, step_fun, iteration, prev_results) do
    iteration_results = MinizincInstance.run(instance)
    case step_fun.(instance, iteration_results, iteration) do
      :break ->
        {instance, prev_results}
      {:ok, updated_instance} ->
        repeat_impl(updated_instance, step_fun, iteration + 1, iteration_results)
    end
  end

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
          lns_constraints = add_constraints(results, destruction_fun, iter_number)
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

@doc """
Branch-and-bound
"""
  def bab(%{model: model, solver_opts: solver_opts} = instance, branch_fun) do
    ## Force solver to have no more than 1 solution on each iteration
    solver_opts = Keyword.put(solver_opts, :solution_handler, find_k_handler(1, solver_opts[:solution_handler]))

    {_final_instance, final_results} = repeat(
      %{instance | solver_opts: solver_opts},
      fn _instance, nil, _iteration ->
          :break
         instance, results, iteration ->
           if MinizincResults.has_solution(results) do
             bab_constraints = add_constraints(results, branch_fun, iteration)
             {:ok, Map.put(instance, :model, MinizincModel.merge(bab_constraints, model))}
           else
             ## BAB will stop if no solutions were found
            :break
           end
      end
    )

    final_results
  end



## Helpers ###
###############################################################################
  defp add_constraints(results, constraint_generator, iteration) do
    ## Add constraints
    solution = MinizincResults.get_last_solution(results)
    method = MinizincResults.get_method(results)
    Enum.map(
      constraint_generator.(solution, method, iteration),
      fn c -> {:model_text, c} end
    )
  end

  def better_objective_constraint(solution, objective_var, method) do
    objective_value = MinizincResults.get_solution_value(solution, objective_var)
    constraint("#{objective_var} #{objective_predicate(method)} #{objective_value}")
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
