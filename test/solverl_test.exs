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
    [error: _] = Minizinc.solve_sync("mzn/nqueens.mzn", %{m: 2})
  end

  test "Unsatisfiable sync" do
    unsat_res = Minizinc.solve_sync("mzn/nqueens.mzn", %{n: 2})
    assert unsat_res[:summary][:status] == :unsatisfiable
  end

  test "Solving with timeout sync" do
    ## Final record for sync solving results is in position 0.
    final_data  = Enum.at(Minizinc.solve_sync(
      "mzn/nqueens.mzn", %{n: 50}, [time_limit: 500]),
      0)
    assert {:summary, %{status: :satisfied}} = final_data
  end

  test "Getting all solutions" do
    results = Minizinc.solve_sync("mzn/nqueens.mzn", %{n: 8})

    assert {:summary, %{status: :all_solutions}} = Enum.at(results, 0)
    ## 92 results for the nqueens.mzn model plus the final record.
    assert length(results) == 1 + 92
  end

  test "Sync solving: solution handler that interrupts the solver after 100 solutions found" do
    final_data  = Enum.at(Minizinc.solve_sync(
      "mzn/nqueens.mzn", %{n: 50}, [solution_handler: NQueens.LimitSolutionsSync]),
      0)
    {:summary, summary} = final_data
    assert %{status: :satisfied} = summary
  end

  test "Checks dimensions of a regular array " do
    good_arr = [ [ [1,2,3], [2,3,1], [3,4,5] ], [ [1,2,3], [2,3,1], [3,4,5] ] ]
    assert MinizincData.dimensions(good_arr) == [2, 3, 3]
  end

  test "Model with boolean vars" do
    conjunction_model = "var bool: x;\nvar bool: y;\nconstraint x /\\ y;\n"
    results = Minizinc.solve_sync({:text, conjunction_model})
    assert results[:solution][:data]["x"] and results[:solution][:data]["x"] == true
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
    assert results[:solution][:data]["var_set"] == MapSet.new([1,2])
  end

  test "Using enums" do
    enum_model = """
      enum COLOR;
      var COLOR: color;
      constraint color = max(COLOR);
    """
    results = Minizinc.solve_sync({:text, enum_model}, %{'COLOR': {"White", "Black", "Red", "BLue", "Green"}})
    assert results[:solution][:data]["color"] == "Green"
  end

end

defmodule NQueens.LimitSolutionsSync do
  use MinizincHandler

  @doc false
  def handle_solution(%{index: count, data: data})  do
    solution_rec = {:solution, data}
    if count < 100, do: solution_rec, else: {:stop, solution_rec}
  end

  @doc false
  def handle_summary(summary) do
    {:summary, summary}
  end

end


