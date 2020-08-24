defmodule SolverRace do
  @moduledoc false

  require Logger

  @model "mzn/golomb_mybab.mzn" ##"mzn/graph_coloring.mzn"
  @data  []                      ##"mzn/gc_1000.dzn"

  @time_limit 60 * 1000

  def run(solvers) do
    parent = self()

    Enum.each(
      solvers,
      fn s ->
        MinizincSolver.solve(
          @model,
          @data,
          [
            solver: s,
            solution_handler:
              fn (event, data) ->
                callback_fun(s, event, data, parent)
              end,
            time_limit: @time_limit
          ],
          [name: solver_process_name(s)]
        )
        Logger.info "#{s} started as #{inspect :erlang.whereis(solver_process_name(s))}..."

      end
    )

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
        still_running = List.delete(solvers, solver)
        Enum.each(
          still_running,
          fn s ->
            Logger.info "Shutting down #{s}..."
            MinizincSolver.stop_solver(solver_process_name(s))
          end
        )
        receive_results(still_running, [{solver, objective} | standing])
      {solver, :compiled, _info} ->
        Logger.info "#{solver}: Compiled!"
        receive_results(solvers, standing)
      {solver, error, error_msg} ->
        Logger.info "Solver #{solver} failed with #{error}. Message: #{error_msg}"
        receive_results(List.delete(solvers, solver), standing)
    end
  end

  defp solver_process_name(solver) do
    String.to_atom(solver)
  end

  #  defp solver_process_name("chuffed") do
  #    Chuffed
  #  end

end
