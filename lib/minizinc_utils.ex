defmodule MinizincUtils do
  @moduledoc false

  require Logger

  import MinizincParser

  @default_args [solver: "gecode", time_limit: 60*5*1000, dzn: [], solution_handler: &__MODULE__.default_solution_handler/1]

  def prepare_solver_cmd(args) do
    {:ok, solver} = MinizincSolver.lookup(args[:solver])
    solver_str = "--solver #{solver["id"]}"
    time_limit_str = "--time-limit #{args[:time_limit]}"
    model_str = "#{args[:model]}"
    {:ok, dzn_str} = MinizincData.make_dzn(args[:dzn])
    String.trim(
    "--allow-multiple-assignments --output-mode json --output-time --output-objective --output-output-item -s -a " <>
    "#{solver_str} #{time_limit_str} #{model_str} #{dzn_str}"
    )
  end

  # minizinc --solver org.minizinc.mip.cplex
  # --allow-multiple-assignments --output-mode json --output-time --output-objective
  # --output-output-item -s -a -p 1 --time-limit 10800000 --workmem 12 --mipfocus 1
  # vrp-mip.mzn /var/folders/rn/_39sx1c12ws1x5k66n_cjjh00000gn/T/mzn_data7jzlpy8s.json


  ## Default solution handler: prints the solution.
  def default_solution_handler(solution_rec(status: nil) = _solution) do
    Logger.error "Incomplete solution shouldn't be handled here!"
    throw {:handle_incomplete_solution}
  end

  def default_solution_handler(solution_rec(status: _status) = solution) do
    Logger.info "Solution: #{inspect solution}"
  end


  def default_args, do: @default_args

end
