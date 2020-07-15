defmodule SolverlTest do
  use ExUnit.Case
  doctest Solverl


  test "Runs the proper solver CMD" do
    good_arr = [ [ [1,2,3], [2,3,1], [3,4,5] ], [ [1,2,3], [2,3,1], [3,4,5] ] ]
    assert {:ok, _pid} = MinizincPort.start_link(
             [
               model: "mzn/test1.mzn",
               dzn: [
                 %{
                 test_data1: 100,
                 test_arr: good_arr,
                 test_base_arr: {[0, 1, 0], good_arr},
                 test_set: MapSet.new([1,2,3]),
                 test_enum: MapSet.new([:red, :blue, :white]) },
                 "mzn/test_data2.dzn"],
               solver: "gecode"])

  end

  test "The same as above, but with multiple models either as a text or a file" do
    good_arr = [ [ [1,2,3], [2,3,1], [3,4,5] ], [ [1,2,3], [2,3,1], [3,4,5] ] ]
    models = [{:text, "int: test_model = true;"}, "mzn/test1.mzn"]
    assert {:ok, _pid} = MinizincPort.start_link(
             [
               model: models,
               dzn: [
                 %{
                   test_data1: 100,
                   test_arr: good_arr,
                   test_base_arr: {[0, 1, 0], good_arr},
                   test_set: MapSet.new([1,2,3]),
                   test_enum: MapSet.new([:red, :blue, :white]) },
                 "mzn/test_data2.dzn"],
               solver: "gecode"])
  end



  test "Checks dimensions of a regular array " do
    good_arr = [ [ [1,2,3], [2,3,1], [3,4,5] ], [ [1,2,3], [2,3,1], [3,4,5] ] ]
    assert MinizincData.dimensions(good_arr) == [2, 3, 3]
  end

end
