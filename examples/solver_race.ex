defmodule SolverRace do
  @moduledoc false

  require Logger

  @model "mzn/golomb_mybab.mzn"
  @time_limit 60*1000

  def run(solvers) do
    parent = self()

    for s <- solvers do
      MinizincSolver.solve(@model, [],
           solver: s,
           solution_handler:
            fn(event, data) ->
              callback_fun(s, event, data, parent)
            end,
            time_limit: @time_limit)
      Logger.info "#{s} started..."
    end

    receive_results(solvers, [])
  end

  defp callback_fun(solver, event, data, to) do
      send(to, {solver, event, data})
  end

  defp receive_results([], standing) do
    Logger.info "Race results: #{inspect Enum.reverse(standing)}"
  end

  defp receive_results(solvers, standing) do
    receive do
      {solver, :solution, solution} ->
        Logger.info "#{solver}: #{MinizincResults.get_solution_objective(solution)}"
        receive_results(solvers, standing)
      {solver, :summary, summary} ->
        solution = summary[:last_solution]
        objective = MinizincResults.get_solution_objective(solution)
        status = summary[:status]
        Logger.info "Solver #{solver} finished with objective #{objective}, status: #{status}"
        receive_results(List.delete(solvers, solver), [{solver, objective} | standing])
      {solver, error, error_msg} ->
        Logger.info "Solver #{solver} failed with #{error}. Message: #{error_msg}"
        receive_results(List.delete(solvers, solver), standing)
    end
  end

end
