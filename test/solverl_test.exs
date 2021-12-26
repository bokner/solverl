defmodule SolverlTest do
  use ExUnit.Case
  doctest Solverl

  import MinizincUtils

  @nqueens_model resource_file("mzn/nqueens.mzn")
  @sudoku_model resource_file("mzn/sudoku.mzn")
  @aust_model resource_file("mzn/aust.mzn")

  @test1_model resource_file("mzn/test1.mzn")
  @test_data2 resource_file("mzn/test_data2.dzn")

  test "Runs the proper solver CMD" do
    test_arr = [[[1, 2, 3], [2, 3, 1], [3, 4, 5]], [[1, 2, 3], [2, 3, 1], [3, 4, 5]]]

    assert {:ok, _pid} =
             MinizincSolver.solve(
               @test1_model,
               [
                 %{
                   test_data1: 100,
                   test_arr: test_arr,
                   test_base_arr: {[0, 1, 0], test_arr},
                   test_set: MapSet.new([1, 2, 3]),
                   test_enum: MapSet.new([:red, :blue, :white])
                 },
                 @test_data2
               ],
               solver: "gecode"
             )
  end

  test "The same as above, but with multiple models either as a text or a file" do
    test_arr = [[[1, 2, 3], [2, 3, 1], [3, 4, 5]], [[1, 2, 3], [2, 3, 1], [3, 4, 5]]]
    models = [{:model_text, "int: test_model = true;"}, @test1_model]

    assert {:ok, _pid} =
             MinizincSolver.solve(
               models,
               [
                 %{
                   test_data1: 100,
                   test_arr: test_arr,
                   test_base_arr: {[0, 1, 0], test_arr},
                   test_set: MapSet.new([1, 2, 3]),
                   test_enum: MapSet.new([:red, :blue, :white])
                 },
                 @test_data2
               ],
               solver: "gecode"
             )
  end

  test "Minizinc error" do
    ## Unrecognized Minizinc option
    {:error, invalid_option_or_bad_format} = MinizincSolver.solve_sync(@nqueens_model, %{n: 2}, extra_flags: "--fake-flag")
    assert String.starts_with?(invalid_option_or_bad_format, "minizinc: Unrecognized option or bad format `--fake-flag'")
  end

  test "Checking dzn against the model: undefined identifier" do
    ## The model expects to have 'n' par as input, but gets 'm' par instead.
    dzn = %{m: 4}
    {:error, error} = MinizincModel.mzn_dzn_info(@nqueens_model, dzn)
    assert String.contains?(error, "type error: undefined identifier `m'")
  end

  test "Checking dzn against the model: unassigned parameter" do
    ## Add new par description to the model
    par_descr = "int: k;"
    model_info = MinizincModel.mzn_dzn_info([@nqueens_model, {:model_text, par_descr}], %{n: 4})
    assert MinizincData.check_dzn(model_info) == {:error, {:unassigned_pars, MapSet.new(["k"])}}
  end

  test "Unsatisfiable sync" do
    {:ok, unsat_res} = MinizincSolver.solve_sync(@nqueens_model, %{n: 2})
    assert MinizincResults.get_status(unsat_res) == :unsatisfiable
  end

  test "Solving with timeout sync" do
    ## Final record for sync solving results is in position 0.
    {:ok, final_data} = MinizincSolver.solve_sync(@nqueens_model, %{n: 50}, time_limit: 500)
    assert MinizincResults.get_status(final_data) == :satisfied
  end

  test "Getting all solutions" do
    {:ok, results} = MinizincSolver.solve_sync(@nqueens_model, %{n: 8})

    assert MinizincResults.get_status(results) == :all_solutions
    ## 92 results for the nqueens.mzn model.
    assert length(results[:solutions]) == 92
  end

  test "Sync solving: solution handler that interrupts the solver after first 100 solutions have been found" do
    {:ok, final_data} =
      MinizincSolver.solve_sync(
        @nqueens_model,
        %{n: 50},
        solution_handler: MinizincSearch.find_k_handler(100, MinizincHandler.Default)
      )

    assert length(MinizincResults.get_solutions(final_data)) == 100
    assert MinizincResults.get_status(final_data) == :satisfied
  end

  test "Sync solving: solution handler that skips every other solution" do
    {:ok, results} =
      MinizincSolver.solve_sync(
        @nqueens_model,
        %{n: 8},
        solution_handler: SolverTest.EveryOther
      )

    ## 92 results for the nqueens.mzn model, but we drop every other one...
    assert length(MinizincResults.get_solutions(results)) == div(92, 2)
  end

  test "Sync solving: solution handler throws an exception" do
    {:ok, results} =
      MinizincSolver.solve_sync(
        @nqueens_model,
        %{n: 9},
        solution_handler: SolverTest.ThrowAfter100
      )

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
    bad_array = [1, [2, 3]]
    data = %{bad_arr: bad_array}
    assert catch_throw(MinizincData.to_dzn(data)) == {:irregular_array, bad_array}
  end

  test "Model with boolean vars" do
    conjunction_model = "var bool: x;\nvar bool: y;\nconstraint x /\\ y;\n"
    {:ok, results} = MinizincSolver.solve_sync({:model_text, conjunction_model})
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

    {:ok, results} = MinizincSolver.solve_sync({:model_text, array_model})

    assert MinizincResults.get_last_solution(results)
           |> MinizincResults.get_solution_value("arr")
           |> MinizincData.dimensions() == [4, 5]
  end

  test "Model with set vars" do
    set_model = """
      var set of 0..5: var_set;
      constraint 1 in var_set;
      constraint 2 in var_set;
      constraint card(var_set) == 2;
    """

    {:ok, results} = MinizincSolver.solve_sync({:model_text, set_model})
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

    {:ok, results} =
      MinizincSolver.solve_sync(
        {:model_text, enum_model},
        %{
          COLOR: {"White", "Black", "Red", "Blue", "Green"},
          some_color: "Blue"
        }
      )

    solution = Enum.at(MinizincResults.get_solutions(results), 0)
    assert MinizincResults.get_solution_value(solution, "bigger_color") == "Green"
  end

  test "Get last solution from summary, drop intermediate solutions" do
    {:ok, results} =
      MinizincSolver.solve_sync(
        @nqueens_model,
        %{n: 8},
        solution_handler: SolverTest.SummaryOnly
      )

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
    assert MinizincSearch.destroy_var("var1", [1, 2], 0.5, 2) in [
             "constraint var1[2] = 1;\n",
             "constraint var1[3] = 2;\n"
           ]
  end

  test "Get model info" do
    model_info = MinizincModel.model_info(@sudoku_model)
    ## Model has "start" parameter
    assert model_info[:pars]["start"] == %{"dim" => 2, "type" => "int"}
    ## Model has "puzzle" variable
    assert model_info[:vars]["puzzle"] == %{"dim" => 2, "type" => "int"}
  end

  test "Run model with checker" do
    {:ok, results} =
      MinizincSolver.solve_sync(
        @aust_model,
        nil,
        checker: resource_file("mzn/aust.mzc.mzn")
      )

    assert String.trim(
             MinizincResults.get_checker_output(MinizincResults.get_last_solution(results))
           ) == "CORRECT"
  end

  test "Shut down on 'no new solution' timeout" do
    ## Give it a very little time to wait for a solution...
    {:ok, results} = MinizincSolver.solve_sync(@aust_model, nil, solution_timeout: 1)
    ## No solutions...
    ## ...but it did compile...
    ## ...and the exit reason indicates a solution timeout
    assert not MinizincResults.has_solution(results) and
             results[:summary][:compiled] and
             results[:summary][:exit_reason] == :by_solution_timeout
  end

  test "Shut down on compilation timeout" do
    ## Give it a very little time to compile...
    {:ok, results} = MinizincSolver.solve_sync(@aust_model, nil, fzn_timeout: 10)
    ## No solutions...
    ## ...and it didn't compile...
    ## ...and the exit reason indicates a FZN timeout
    assert not MinizincResults.has_solution(results) and
             not results[:summary][:compiled] and
             results[:summary][:exit_reason] == :by_fzn_timeout
  end
end

####################
## Helper modules ##
####################
defmodule SolverTest.EveryOther do
  use MinizincHandler

  @doc false
  def handle_solution(%{index: count, data: data}) do
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
  def handle_solution(_solution) do
    :skip
  end
end

## For testing throws within a solution handler
#
defmodule SolverTest.ThrowAfter100 do
  use MinizincHandler

  @doc false
  def handle_solution(%{index: index, data: data} = _solution) do
    if index > 100, do: throw(:throw_after_100)
    data
  end
end
