defmodule MinizincInstance do
  @moduledoc false
  def build_command_args(args) do
    "-a -s --output-mode json --output-output-item --output-time --output-objective #{args[:model]}"
  end

  # minizinc --solver org.minizinc.mip.cplex
  # --allow-multiple-assignments --output-mode json --output-time --output-objective
  # --output-output-item -s -a -p 1 --time-limit 10800000 --workmem 12 --mipfocus 1
  # vrp-mip.mzn /var/folders/rn/_39sx1c12ws1x5k66n_cjjh00000gn/T/mzn_data7jzlpy8s.json


end
