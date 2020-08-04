defmodule MinizincSearch do
  @moduledoc false


  ## Takes the name and solution for an array of decision variables and
  ## creates the list of constraints for variables that will be fixed for the next iteration of solving.
  ## The destruction_rate (a value between 0 and 1) states the percentage of the variables in the
  ## the array that should be 'dropped'.
  ##
  def lns_fix(varname, vardata, destruction_rate, offset \\0) when is_binary(varname) and is_list(vardata) do
    ## Randomly choose (1 - destruction_rate)th part of vardata to fix...
    fixed_data = Enum.take_random(vardata, round(length(vardata) * (1 - destruction_rate)))
    ## Generate constraints
    Enum.join(
      Enum.map(
        Enum.with_index(fixed_data, offset),
              fn {d, idx} -> make_constraint(varname, idx, d) end))
  end

  defp make_constraint(varname, idx, val) do
    "constraint #{varname}[#{idx}] = #{val};\n"
  end

end
