defmodule MinizincUtils do
  @moduledoc """
    Helpers
  """

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

end
