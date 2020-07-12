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
    {:ok, dzn_str} = make_dzn(args[:dzn])
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

  ## Merges list of dzn files and/or maps and writes the result to a (temporary by default) target file.
  ## TODO: validate content?
  def make_dzn(data, target \\ nil)

  def make_dzn([], _) do
    {:ok, ""}
  end

  def make_dzn(data, nil) do
    make_dzn(data, String.trim(to_string(:os.cmd('mktemp'))))
  end


  def make_dzn(data, target) when is_list(data) do
    target_file = String.replace_suffix(target, ".dzn", "") <> ".dzn"
    for d <- data do
      {:ok, content} = read_dzn(d)
      File.write(target_file, content <> "\n", [:append])
    end
    {:ok, target_file}
  end

  def make_dzn(data, target) when is_binary(data) or is_map(data) do
    make_dzn([data], target)
  end


  # Dzn as filename
  def read_dzn(data) when is_binary(data) do
    {:ok, _dzn} = File.read(data)
  end

  # Dzn as dict/map
  def read_dzn(data) when is_map(data) do
    {:ok, map_to_dzn(data)}
  end

  # Convert map to the list of strings in .dzn format
  def map_to_dzn(data) do
    Enum.reduce(data, "",
      fn({k, v}, acc) ->
        "#{k} = #{elixir_to_dzn(v)};\n" <> acc
      end)
  end

  def output_to_elixir(data_dict) do
    Enum.reduce(data_dict, %{},
      fn({k, v}, acc) ->
        Map.put(acc, k, mzn_to_elixir(v))
      end)
  end

  def mzn_to_elixir(el) when is_map(el) do
    s = el["set"]
    if s == [], do: MapSet.new(s), else: MapSet.new(hd(s))
  end

  def mzn_to_elixir(el) do
    el
  end

  # Convert element to .dzn string
  # TODO
  def elixir_to_dzn(el) do
    el
  end

end
