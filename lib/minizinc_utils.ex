defmodule MinizincUtils do
  @moduledoc false

  # Helpers
  require Logger
  def flush() do
    receive do
      msg ->
        Logger.debug "Residual from solver: #{inspect msg}"
        flush()
    after 0 ->
      :ok
    end
  end

  def constraint(body) do
    "constraint #{body};\n"
  end

  def now(_timeunit) do
    DateTime.utc_now()
  end

  @doc """
  Default Minizinc executable.
  """
  def default_executable() do
    System.find_executable("minizinc")
  end

  def cmd(os_command) do
    to_string(:os.cmd(to_charlist(os_command)))
  end

  ## Symmetric difference of 2 sets
  def sym_diff(a, b) do
    MapSet.difference(MapSet.union(a,b), MapSet.intersection(a,b))
  end

  ## Details on symmetric difference
  def sym_diff_details(a, b) do
    diff = sym_diff(a, b)
    Enum.map(diff, fn el -> {el, MapSet.member?(a, el)} end)
  end

  ## Merge 2 elements and or lists into a flat list
  def merge_lists_or_elements(thing1, thing2)  do
    List.flatten([thing1, thing2])
  end

end
