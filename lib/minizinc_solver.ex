defmodule MinizincSolver do
  @moduledoc false

  import MinizincInstance
  require Logger

  @default_args [
    minizinc_executable: System.find_executable("minizinc"),
    solver: "gecode",
    time_limit: 60*5*1000,
    data: [],
    solution_handler: &__MODULE__.default_solution_handler/2]


  ## Default solution handler: prints the solution.
  def default_solution_handler(_isFinal, instance_rec(status: nil) = _instance) do
    Logger.error "Incomplete instance shouldn't be handled here!"
    throw {:handle_incomplete_instance}
  end

  def default_solution_handler(_isFinal, instance_rec(status: _status) = instance) do
    Logger.info "Model info: method = #{MinizincModel.model_method(instance)}"
    Logger.info "Solution status: #{MinizincInstance.get_status(instance)}"
    Logger.info "Solution: #{inspect instance}"
  end


  def default_args, do: @default_args


  ## Solve with model, data and options.
  ##
  ## Example:
  ## MinizincSolver.solve("mzn/sudoku.mzn", "mzn/sudoku.dzn", [solution_handler: &Sudoku.solution_handler/2])
  ##
  def solve(model) do
    solve(model, [], [])
  end

  def solve(model, data) do
    solve(model, data, [])
  end

  def solve(model, data, opts) do
    args = [model: model, data: data] ++ opts
    {:ok, _pid} = MinizincPort.start_link(args)
  end

  def prepare_solver_cmd(args) do
    {:ok, solver} = MinizincSolver.lookup(args[:solver])
    solver_str = "--solver #{solver["id"]}"
    time_limit_str = "--time-limit #{args[:time_limit]}"
    extra_flags = Keyword.get(args, :extra_flags, "")
    {:ok, model_str} = MinizincModel.make_model(args[:model])
    {:ok, dzn_str} = MinizincData.make_dzn(args[:data])
    args[:minizinc_executable] <> " " <>
    String.trim(
      "--allow-multiple-assignments --output-mode json --output-time --output-objective --output-output-item -s -a " <>
      extra_flags <>
      " #{solver_str} #{time_limit_str} #{model_str} #{dzn_str}"
    )
  end

  ## Get list of registered solvers
  def get_solvers do
    solvers_json = to_string(:os.cmd('#{get_executable()} --solvers-json'))
    {:ok, solvers} = Jason.decode(solvers_json)
    solvers
  end

  def get_solverids do
    for solver <- get_solvers(), do: solver["id"]
  end

  ## Lookup a solver by (possibly partial) id;
  ## for instance, it could be 'cplex' or 'org.minizinc.mip.cplex'
  def lookup(solver_id) do
    solvers = Enum.filter(get_solvers(),
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

  def get_executable do
    default_args()[:minizinc_executable]
  end


end
