defmodule MinizincModel do
  @moduledoc false
  require Logger

  ## Model as text
  def make_model({:text, model_text}) when is_binary(model_text) do
    model_file = String.trim(to_string(:os.cmd('mktemp'))) <> ".mzn"
    :ok = File.write(model_file, model_text <> "\n", [:append])
    model_file
  end

  def make_model(model_file) when is_binary(model_file) do
    model_file
  end
end
