defmodule MinizincUtils do
  @moduledoc false

  require Logger

  import MinizincParser

  @default_args [solver: "gecode", time_limit: 60*5*1000, dzn: [], solution_handler: &__MODULE__.default_solution_handler/1]

  def prepare_solver_cmd(args) do
    {:ok, solver} = MinizincSolver.lookup(args[:solver])
    solver_str = "--solver #{solver["id"]}"
    time_limit_str = "--time-limit #{args[:time_limit]}"
    model_str = "#{make_model(args[:model])}"
    {:ok, dzn_str} = MinizincData.make_dzn(args[:dzn])
    String.trim(
    "--allow-multiple-assignments --output-mode json --output-time --output-objective --output-output-item -s -a " <>
    "#{solver_str} #{time_limit_str} #{model_str} #{dzn_str}"
    )
  end

  ## Default solution handler: prints the solution.
  def default_solution_handler(solution_rec(status: nil) = _solution) do
    Logger.error "Incomplete solution shouldn't be handled here!"
    throw {:handle_incomplete_solution}
  end

  def default_solution_handler(solution_rec(status: _status) = solution) do
    Logger.info "Solution: #{inspect solution}"
  end


  def default_args, do: @default_args

  ## Model as text
  def make_model({:text, model_text}) when is_binary(model_text) do
    model_file = String.trim(to_string(:os.cmd('mktemp'))) <> ".mzn"
    :ok = File.write(model_file, model_text <> "\n", [:append])
    model_file
  end

  def make_model(model_file) when is_binary(model_file) do
    model_file
  end


end
