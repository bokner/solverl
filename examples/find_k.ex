defmodule FindK do
  @moduledoc false

  import MinizincHandler
  require Logger

  ## Mirror of the 'find_k_solution' Minizinc example:
  ## https://github.com/MiniZinc/libminizinc/blob/feature/minisearch/tests/minisearch/regression_tests/queen_k_sols.mzn
  ##
  def run(k, model, data, solver_opts) do
    ## Get the original solution handler
    solution_handler = Keyword.get(solver_opts, :solution_handler, MinizincHandler.DefaultSync)
    wrapper_handler = fn(event, data) ->
                    find_k_handler(k, solution_handler, event, data)
                    end
    MinizincSolver.solve(model, data,
      Keyword.put(solver_opts, :solution_handler, wrapper_handler))
  end

  ## Intercept the solution handler and force no more than k solutions.
  def find_k_handler(k, _handler, :solution, %{index: count} = _solution) when count > k do
    :break
  end

  ## Catch-all
  def find_k_handler(_k, handler, event, data)  do
    handle_solver_event(event, data, handler)
  end

  #####


end
