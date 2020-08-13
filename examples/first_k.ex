defmodule FirstK do
  @moduledoc false

  import MinizincHandler
  require Logger

  def run(model, data, solver_opts, k) do
    ## Get the original solution handler
    solution_handler = Keyword.get(solver_opts, :solution_handler, MinizincHandler.DefaultSync)
    wrapper_handler = fn(event, data) ->
                    first_k_handler(k, solution_handler, event, data)
                    end
    MinizincSolver.solve(model, data,
      Keyword.put(solver_opts, :solution_handler, wrapper_handler))
  end

  def first_k_handler(k, _handler, :solution, %{index: count} = _solution) when count > k do
    :break
  end

  def first_k_handler(_k, handler, :summary, summary)  do
    Logger.info "No more solutions"
    handle_summary(summary, handler)
  end

  def first_k_handler(_k, handler, event, data)  do
    handle_solver_event(event, data, handler)
  end

  #####


end
