defmodule MinizincSolver do
  @moduledoc false

  import Jason

  def solve(model, data, solver, timeout, solution_handler, opts) do
    nil
  end

  ## Get list of registered solvers
  def get_solvers do
    {solvers_json, _} = System.cmd("minizinc", ["--solvers-json"])
    {:ok, solvers} = Jason.decode(solvers_json)
    solvers
  end

  def get_solverids do
    for solver <- get_solvers, do: solver["id"]
  end

  ## Lookup a solver by (possibly partial) id;
  ## for instance, it could be 'cplex' or 'org.minizinc.mip.cplex'
  def lookup(solver_id) do
    solvers = Enum.filter(get_solvers,
      fn s ->
        s["id"] == solver_id or
        List.last(String.split(s["id"], ".")) == solver_id
      end)
    case solvers do
      [] ->
        {:solver_not_found, solver_id}
      [solver] ->
        {:ok, solver}
      [_ | _rest] ->
        {:solver_id_ambiguous, (for solver <- solvers, do: solver["id"])}
    end
  end

end
