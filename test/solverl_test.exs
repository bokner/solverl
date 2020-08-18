defmodule SolverlTest do
  use ExUnit.Case
  doctest Solverl


  test "Runs the proper solver CMD" do
    test_arr = [[[1, 2, 3], [2, 3, 1], [3, 4, 5]], [[1, 2, 3], [2, 3, 1], [3, 4, 5]]]
    assert {:ok, _pid} = MinizincSolver.solve(
             "mzn/test1.mzn",
             [
               %{
                 test_data1: 100,
                 test_arr: test_arr,
                 test_base_arr: {[0, 1, 0], test_arr},
                 test_set: MapSet.new([1, 2, 3]),
                 test_enum: MapSet.new([:red, :blue, :white])
               },
               "mzn/test_data2.dzn"
             ],
             [solver: "gecode"]
           )

  end

  test "The same as above, but with multiple models either as a text or a file" do
    test_arr = [[[1, 2, 3], [2, 3, 1], [3, 4, 5]], [[1, 2, 3], [2, 3, 1], [3, 4, 5]]]
    models = [{:model_text, "int: test_model = true;"}, "mzn/test1.mzn"]
    assert {:ok, _pid} = MinizincSolver.solve(
             models,
             [
               %{
                 test_data1: 100,
                 test_arr: test_arr,
                 test_base_arr: {[0, 1, 0], test_arr},
                 test_set: MapSet.new([1, 2, 3]),
                 test_enum: MapSet.new([:red, :blue, :white])
               },
               "mzn/test_data2.dzn"
             ],
             [solver: "gecode"]
           )
  end

  test "Minizinc error" do
    ## Unrecognized Minizinc option
    assert %{
             minizinc_error: %{
               error: _error
             }
           } = MinizincSolver.solve_sync("mzn/nqueens.mzn", %{n: 2}, extra_flags: "--fake-flag")
  end

  test "Checking dzn against the model: mismatch between declared and factual input parameter names" do
    ## The model expects to have 'n' par as input, but gets 'm' par instead.
    dzn = MinizincData.make_dzn(%{m: 4})
    model_info = MinizincModel.make_model("mzn/nqueens.mzn")
    assert MinizincData.check_dzn(model_info, dzn) ==
             {:error, {:mismatch, [{"m", :not_in_model}, {"n", :not_in_dzn}]}}  end

  test "Unsatisfiable sync" do
    unsat_res = MinizincSolver.solve_sync("mzn/nqueens.mzn", %{n: 2})
    assert MinizincResults.get_status(unsat_res) == :unsatisfiable
  end

  test "Solving with timeout sync" do
    ## Final record for sync solving results is in position 0.
    final_data = MinizincSolver.solve_sync("mzn/nqueens.mzn", %{n: 50}, [time_limit: 500])
    assert MinizincResults.get_status(final_data) == :satisfied
  end

  test "Getting all solutions" do
    results = MinizincSolver.solve_sync("mzn/nqueens.mzn", %{n: 8})

    assert MinizincResults.get_status(results) == :all_solutions
    ## 92 results for the nqueens.mzn model.
    assert length(results[:solutions]) == 92
  end

  test "Sync solving: solution handler that interrupts the solver after first 100 solutions have been found" do
    final_data = MinizincSolver.solve_sync(
      "mzn/nqueens.mzn",
      %{n: 50},
      [solution_handler: MinizincSearch.find_k_handler(100, MinizincHandler.Default)]
    )
    assert length(MinizincResults.get_solutions(final_data)) == 100
    assert MinizincResults.get_status(final_data) == :satisfied
  end

  test "Sync solving: solution handler that skips every other solution" do
    results = MinizincSolver.solve_sync("mzn/nqueens.mzn", %{n: 8}, [solution_handler: SolverTest.EveryOther])
    ## 92 results for the nqueens.mzn model, but we drop every other one...
    assert length(MinizincResults.get_solutions(results)) == div(92, 2)
  end

  test "Sync solving: solution handler throws an exception" do
    results = MinizincSolver.solve_sync("mzn/nqueens.mzn", %{n: 9}, [solution_handler: SolverTest.ThrowAfter100])
    ## Should get 100 solutions
    assert length(MinizincResults.get_solutions(results)) == 100
    ## The exception is stored with :handler_exception key
    assert results[:handler_exception] == :throw_after_100
  end


  test "Checks dimensions of a regular array " do
    good_arr = [[[1, 2, 3], [2, 3, 1], [3, 4, 5]], [[1, 2, 3], [2, 3, 1], [3, 4, 5]]]
    assert MinizincData.dimensions(good_arr) == [2, 3, 3]
  end

  test "Throws exception if the array is not regular" do
    bad_arr = [1, [2, 3]]
    assert catch_throw(MinizincData.elixir_to_dzn(bad_arr)) == {:irregular_array, bad_arr}
  end

  test "Model with boolean vars" do
    conjunction_model = "var bool: x;\nvar bool: y;\nconstraint x /\\ y;\n"
    results = MinizincSolver.solve_sync({:model_text, conjunction_model})
    solution = Enum.at(MinizincResults.get_solutions(results), 0)
    assert MinizincResults.get_solution_value(solution, "x") and
           MinizincResults.get_solution_value(solution, "y") == true
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
    results = MinizincSolver.solve_sync({:model_text, array_model})
    assert MinizincResults.get_last_solution(results)
           |> MinizincResults.get_solution_value("arr")
           |> MinizincData.dimensions == [4, 5]
  end

  test "Model with set vars" do
    set_model = """
      var set of 0..5: var_set;
      constraint 1 in var_set;
      constraint 2 in var_set;
      constraint card(var_set) == 2;
    """
    results = MinizincSolver.solve_sync({:model_text, set_model})
    solution = Enum.at(MinizincResults.get_solutions(results), 0)

    assert MinizincResults.get_solution_value(solution, "var_set") == MapSet.new([1, 2])
  end

  test "Model with enums" do
    enum_model = """
      enum COLOR;
      COLOR: some_color;
      var COLOR: bigger_color;
      constraint bigger_color > some_color;
    """
    results = MinizincSolver.solve_sync(
      {:model_text, enum_model},
      %{
        'COLOR': {"White", "Black", "Red", "Blue", "Green"},
        some_color: "Blue"
      }
    )
    solution = Enum.at(MinizincResults.get_solutions(results), 0)
    assert MinizincResults.get_solution_value(solution, "bigger_color") == "Green"
  end

  test "Get last solution from summary, drop other solutions" do
    results = MinizincSolver.solve_sync("mzn/nqueens.mzn", %{n: 8}, [solution_handler: SolverTest.SummaryOnly])
    ## We dropped all solutions...
    assert length(MinizincResults.get_solutions(results)) == 0
    ## ... but the solution count is still correct...
    last_solution = MinizincResults.get_last_solution(results)
    assert MinizincResults.get_solution_index(last_solution) == 92
    ## ... and the last solution is there
    assert length(MinizincResults.get_solution_value(last_solution, "q")) == 8
  end

  test "Fix decision variable (used for LNS)" do
    ## Randomly destruct values of "var1" variable by 50%
    assert MinizincSearch.destroy_var("var1", [1, 2], 0.5, 2)
           in ["constraint var1[2] = 1;\n", "constraint var1[3] = 2;\n"]
  end

  test "Get model info" do
    model_info = MinizincModel.model_info("mzn/sudoku.mzn")
    ## Model has "start" parameter
    assert model_info[:pars]["start"] == %{"dim" => 2, "type" => "int"}
    ## Model has "puzzle" variable
    assert model_info[:vars]["puzzle"] == %{"dim" => 2, "type" => "int"}
  end
end

####################
## Helper modules ##
####################
defmodule SolverTest.EveryOther do
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

defmodule SolverTest.SummaryOnly do
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

## For testing throws within a solution handler
#
defmodule SolverTest.ThrowAfter100 do
  use MinizincHandler

  @doc false
  def handle_solution(%{index: index, data: data} = _solution)  do
    if index > 100, do: throw :throw_after_100
    data
  end

  @doc false
  def handle_summary(summary) do
    summary
  end
end



