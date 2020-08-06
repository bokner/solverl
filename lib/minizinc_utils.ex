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

  def now(timeunit) do
    DateTime.to_unix(DateTime.utc_now, timeunit)
  end

  @doc """
  Default Minizinc executable.
  """
  def default_executable() do
    System.find_executable("minizinc")
  end


end
