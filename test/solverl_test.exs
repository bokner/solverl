defmodule SolverlTest do
  use ExUnit.Case
  doctest Solverl


  test "Runs the proper solver CMD" do
    test_arr = [ [ [1,2,3], [2,3,1], [3,4,5] ], [ [1,2,3], [2,3,1], [3,4,5] ] ]
    assert {:ok, _pid} = MinizincSolver.solve(
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
    assert {:ok, _pid} = MinizincSolver.solve(
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
    [error: _] = MinizincSolver.solve_sync("mzn/nqueens.mzn", %{m: 2})
  end

  test "Unsatisfiable sync" do
    unsat_res = MinizincSolver.solve_sync("mzn/nqueens.mzn", %{n: 2})
    assert unsat_res[:final][:status] == :unsatisfiable
  end

  test "Solving with timeout sync" do
    ## Final record for sync solving results is in position 0.
    final_data  = Enum.at(MinizincSolver.solve_sync(
      "mzn/nqueens.mzn", %{n: 50}, [time_limit: 500]),
      0)
    assert {:final, %{status: :satisfied}} = final_data
  end

  test "Getting all solutions" do
    results = MinizincSolver.solve_sync("mzn/nqueens.mzn", %{n: 8})

    assert {:final, %{status: :all_solutions}} = Enum.at(results, 0)
    ## 92 results for the nqueens.mzn model plus the final record.
    assert length(results) == 1 + 92
  end

  test "Solution handlers which interrupt the solver within (async)" do
    :todo
  end

  test "Solution handlers which interrupt the solver from outside (sync)" do
    :todo
  end

  test "Checks dimensions of a regular array " do
    good_arr = [ [ [1,2,3], [2,3,1], [3,4,5] ], [ [1,2,3], [2,3,1], [3,4,5] ] ]
    assert MinizincData.dimensions(good_arr) == [2, 3, 3]
  end

end
