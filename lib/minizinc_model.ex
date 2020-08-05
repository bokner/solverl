defmodule MinizincModel do
  @moduledoc """
    Functions to construct and access Minizinc model.
  """
  require Logger



  @type model_chunk :: Path.t() | {:model_text, binary()}
  @type mzn_model :: model_chunk() | list(model_chunk())


  @submodel_header "%%%%% START OF SUBMODEL %%%%%"
  @submodel_footer "%%%%% END OF SUBMODEL %%%%%\n\n"

  def make_model(model, target \\ nil)

  def make_model([], _) do
    throw :model_is_missing
  end

  def make_model(model, nil) do
    make_model(model, String.trim(to_string(:os.cmd('mktemp'))))
  end

  ## Multiple models
  def make_model(model, target) when is_list(model) do
    target_file = String.replace_suffix(target, ".mzn", "") <> ".mzn"
    for m <- model do
      File.write(target_file, @submodel_header <> "\n", [:append])
      File.write(target_file, read_model(m) <> "\n", [:append])
      File.write(target_file, @submodel_footer <> "\n", [:append])
    end
    target_file
  end

  ## Single model
  def make_model(data, target) do
    make_model([data], target)
  end


  ## Model as text
  defp read_model({:model_text, model_text}) when is_binary(model_text) do
    model_text
  end

  ## Model as file
  defp read_model(model_file) when is_binary(model_file) do
    File.read!(model_file)
  end

  ## Model info
  def model_method(%{fzn_stats: stats} = _summary) do
    Map.get(stats, :method, "undefined")
    |> String.to_atom()
  end

end
