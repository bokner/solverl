defmodule MinizincDataTest do
  use ExUnit.Case

  describe "elixir_to_dzn/1" do
    test "can create an array of arrays without specifying the bases" do
      array = [
        [1, 2, 3],
        [3, 4, 5]
      ]

      expected = "[|1, 2, 3 | 3, 4, 5|]"
      actual = MinizincData.elixir_to_dzn(array)

      assert expected == actual
    end
  end
end
