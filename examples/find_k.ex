defmodule FindK do
  @moduledoc false

  require Logger

  ## Mirror of the 'find_k_solution' Minizinc example:
  ## https://github.com/MiniZinc/libminizinc/blob/feature/minisearch/tests/minisearch/regression_tests/queen_k_sols.mzn
  ##
  def run(k, model, data, solver_opts) do
    ## Get the original solution handler
    solution_handler = Keyword.get(solver_opts, :solution_handler, MinizincHandler.DefaultSync)
    ## Use find_k_handler for solving
    MinizincSolver.solve(model, data,
      Keyword.put(solver_opts, :solution_handler,
        MinizincSearch.find_k_handler(k, solution_handler)))
  end




end
