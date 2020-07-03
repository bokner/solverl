defmodule MinizincInstance do
  @moduledoc false
  def build_command_args(args) do
    "-a #{args[:model]}"
  end
end
