defmodule SolverlTest do
  use ExUnit.Case
  doctest Solverl


  test "Runs the proper solver CMD" do
    test_arr = [ [ [1,2,3], [2,3,1], [3,4,5] ], [ [1,2,3], [2,3,1], [3,4,5] ] ]
    assert {:ok, _pid} = Minizinc.solve(
               "mzn/test1.mzn",
               [
                 %{
                 test_data1: 100,
                 test_arr: test_arr,
                 test_base_arr: {[0, 1, 0], test_arr},
                 test_set: MapSet.new([1,2,3]),
                 test_enum: MapSet.new([:red, :blue, :white]) },
                 "mzn/test_data2.dzn"],
               [solver: "gecode"])

  end

  test "The same as above, but with multiple models either as a text or a file" do
    test_arr = [ [ [1,2,3], [2,3,1], [3,4,5] ], [ [1,2,3], [2,3,1], [3,4,5] ] ]
    models = [{:text, "int: test_model = true;"}, "mzn/test1.mzn"]
    assert {:ok, _pid} = Minizinc.solve(
               models,
               [
                 %{
                   test_data1: 100,
                   test_arr: test_arr,
                   test_base_arr: {[0, 1, 0], test_arr},
                   test_set: MapSet.new([1,2,3]),
                   test_enum: MapSet.new([:red, :blue, :white]) },
                 "mzn/test_data2.dzn"],
               [solver: "gecode"])
  end

  test "Minizinc error" do
    ## Improper data key - should be %{n: 2}
    %{minizinc_error: %{error: _error}} = Minizinc.solve_sync("mzn/nqueens.mzn", %{m: 2})
  end

  test "Unsatisfiable sync" do
    unsat_res = Minizinc.solve_sync("mzn/nqueens.mzn", %{n: 2})
    assert unsat_res[:summary][:status] == :unsatisfiable
  end

  test "Solving with timeout sync" do
    ## Final record for sync solving results is in position 0.
    final_data  = Minizinc.solve_sync("mzn/nqueens.mzn", %{n: 50}, [time_limit: 500])
    assert final_data[:summary][:status] == :satisfied
  end

  test "Getting all solutions" do
    results = Minizinc.solve_sync("mzn/nqueens.mzn", %{n: 8})

    assert results[:summary][:status] == :all_solutions
    ## 92 results for the nqueens.mzn model.
    assert length(results[:solutions]) == 92
  end

  test "Sync solving: solution handler that interrupts the solver after first 100 solutions have been found" do
    final_data  = Minizinc.solve_sync("mzn/nqueens.mzn", %{n: 50}, [solution_handler: SolverTest.LimitSolutionsSync])

    assert final_data[:summary][:status] == :satisfied
  end

  test "Sync solving: solution handler that skips every other solution" do
    results = Minizinc.solve_sync("mzn/nqueens.mzn", %{n: 8}, [solution_handler: SolverTest.EveryOtherSync])
    ## 92 results for the nqueens.mzn model, but we drop every other one...
    assert length(results[:solutions]) == div(92, 2)
  end

  test "Checks dimensions of a regular array " do
    good_arr = [ [ [1,2,3], [2,3,1], [3,4,5] ], [ [1,2,3], [2,3,1], [3,4,5] ] ]
    assert MinizincData.dimensions(good_arr) == [2, 3, 3]
  end

  test "Model with boolean vars" do
    conjunction_model = "var bool: x;\nvar bool: y;\nconstraint x /\\ y;\n"
    results = Minizinc.solve_sync({:text, conjunction_model})
    data = Enum.at(results[:solutions], 0)[:data]
    assert data["x"] and data["y"] == true
  end

  test "Model with 2d array of vars" do
    array_model = """
      array[1..4, 1..5] of var 0..1: arr;

      constraint forall(i in 1..4)(
      forall(j in 1..4)(
        arr[i, j] != arr[i, j+1]
        )
    );
  """
    results = Minizinc.solve_sync({:text, array_model})
    assert MinizincData.dimensions(results[:summary][:last_solution][:data]["arr"]) == [4, 5]
  end

  test "Model with set vars" do
    set_model = """
      var set of 0..5: var_set;
      constraint 1 in var_set;
      constraint 2 in var_set;
      constraint card(var_set) == 2;
    """
    results = Minizinc.solve_sync({:text, set_model})
    assert Enum.at(results[:solutions], 0)[:data]["var_set"] == MapSet.new([1,2])
  end

  test "Model with enums" do
    enum_model = """
      enum COLOR;
      var COLOR: color;
      constraint color = max(COLOR);
    """
    results = Minizinc.solve_sync({:text, enum_model}, %{'COLOR': {"White", "Black", "Red", "BLue", "Green"}})
    assert Enum.at(results[:solutions], 0)[:data]["color"] == "Green"
  end

  test "Get last solution from summary, drop other solutions" do
    results = Minizinc.solve_sync("mzn/nqueens.mzn", %{n: 8}, [solution_handler: SolverTest.SummaryOnlySync])
    ## We dropped all solutions...
    assert length(results[:solutions]) == 0
    ## ... but the solution count is still correct...
    assert results[:summary][:last_solution][:index] == 92
    ## ... and the last solution is there
    assert length(results[:summary][:last_solution][:data]["q"]) == 8
  end

end

defmodule LimitSolutionsSync do
  use MinizincHandler

  @doc false
  def handle_solution(%{index: count, data: data})  do
    if count < 100, do: data, else: {:stop, data}
  end

  @doc false
  def handle_summary(summary) do
    summary
  end

end


defmodule SolverTest.LimitSolutionsSync do
  use MinizincHandler

  @doc false
  def handle_solution(%{index: count, data: data})  do
    if count < 100, do: data, else: {:stop, data}
  end

  @doc false
  def handle_summary(summary) do
    summary
  end

end

defmodule SolverTest.EveryOtherSync do
  use MinizincHandler

  @doc false
  def handle_solution(%{index: count, data: data})  do
    if rem(count, 2) == 0 do
      :skip
    else
      data
    end
  end

  @doc false
  def handle_summary(summary) do
    summary
  end

end

defmodule SolverTest.SummaryOnlySync do
  use MinizincHandler

  @doc false
  def handle_solution(_solution)  do
    :skip
  end

  @doc false
  def handle_summary(summary) do
    summary
  end

end



