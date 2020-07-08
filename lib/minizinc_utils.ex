defmodule MinizincUtils do
  @moduledoc false

  require Logger

  @solution_status_reg  ~r/^-{10}|={5}(ERROR|UNKNOWN|UNSATISFIABLE|UNSATorUNBOUNDED|UNBOUNDED|)?={5}/
  @json_reg ~r/\{[^\}]+\}/
  @solution_delimiter_reg ~r/-{10}/
  @solution_optimal_delimiter_reg ~r/={10}/

  @default_args [solver: "gecode", time_limit: 60*5*1000, solution_handler: &__MODULE__.default_solution_handler/1]

  def build_command_args(args) do

    solver_str = "--solver #{args[:solver]}"
    time_limit_str = "--time-limit #{args[:time_limit]}"
    model_str = "#{args[:model]}"
    "--allow-multiple-assignments --output-mode json --output-time --output-objective --output-output-item -s -a #{solver_str} #{time_limit_str} #{model_str}"
  end

  def parse_solution(solution_raw) do
    Regex.split(@solution_status_reg, solution_raw, multiline: true, include_captures: true, trim: true)
  end
  # minizinc --solver org.minizinc.mip.cplex
  # --allow-multiple-assignments --output-mode json --output-time --output-objective
  # --output-output-item -s -a -p 1 --time-limit 10800000 --workmem 12 --mipfocus 1
  # vrp-mip.mzn /var/folders/rn/_39sx1c12ws1x5k66n_cjjh00000gn/T/mzn_data7jzlpy8s.json


  ## Default solution handler: prints the solution.
  def default_solution_handler(solution) do
    Logger.info "Solution: #{inspect solution}"
  end

  def default_args, do: @default_args
end
