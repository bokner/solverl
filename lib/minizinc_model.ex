defmodule MinizincModel do
  @moduledoc """
    Functions to construct and access Minizinc model.
  """
  require Logger

  import MinizincUtils

  @type model_chunk :: Path.t() | {:model_text, binary()}
  @type mzn_model :: model_chunk() | list(model_chunk())


  @submodel_header "%%%%% START OF SUBMODEL %%%%%"
  @submodel_footer "%%%%% END OF SUBMODEL %%%%%\n\n"


  ## Build model from multiple files and/or textual chunks.
  ##

  def make_model([]) do
    throw :model_is_missing
  end

  ## Multiple models
  def make_model(model) when is_list(model) do
    Enum.reduce(model, "",
        fn m, acc -> acc <> Enum.join(
          [
            @submodel_header,
            read_model(m),
            @submodel_footer
          ],
          "\n"
        ) end
      )
    end

  ## Single model
  def make_model(data) do
    make_model([data])
  end


  ## Model as text
  defp read_model({:model_text, model_text}) when is_binary(model_text) do
    model_text
  end

  ## Model as file
  defp read_model(model_file) when is_binary(model_file) do
    File.read!(model_file)
  end

  ## Merge 2 models
  def merge(model1, model2) do
    MinizincUtils.merge_lists_or_elements(model1, model2)
  end

  ## Model + DZN info.
  @dzn_header      "%%%%% DZN START"
  @dzn_footer      "%%%%% DZN END"

  def mzn_dzn_info(model, data, minizinc_executable \\ MinizincUtils.default_executable()) do
    ## Create a temporary file for the joint model
    target_file = String.replace_suffix(
                    String.trim(MinizincUtils.cmd("mktemp")),
                    ".mzn", "") <> ".mzn"
    model_body = MinizincModel.make_model(model)
    dzn_body = MinizincData.to_dzn(data)
    File.write(target_file,
      Enum.join(
        [model_body, @dzn_header, dzn_body, @dzn_footer], "\n"))
    MinizincModel.model_info(target_file, minizinc_executable)
  end


  def model_info(model_file, minizinc_executable \\ default_executable()) when is_binary(model_file) do
    mzn_output = cmd("#{minizinc_executable} #{model_file} --model-interface-only --allow-multiple-assignments")
    case Jason.decode(mzn_output) do
      {:ok, model_info} ->
        [
          {:model_file, model_file} |
          Enum.map(
            model_info,
            fn
              {"input", v} -> {:pars, v};
              {"output", v} -> {:vars, v};
              {"method", method_name} -> {:method, translate_method(method_name)};
              {k, v} -> {String.to_atom(k), v}
            end
          )
        ]
      {:error, _jason_error} ->
        ## TODO : parse error
        {:error, mzn_output}
      end
  end


  defp translate_method("sat") do
    :satisfy
  end

  defp translate_method("max") do
    :maximize
  end

  defp translate_method("min") do
    :minimize
  end


  def method(model) do
    model[:method]
  end

  ## Add constraints to the model.
  ## 'constraints' is a list of strings that are bodies of Minizinc 'constraint' expressions.
  ## Example: "x[0] < 1"
  ## Note: no "constraint" keyword, and no terminators.
  ## 'model' is a string representation of a model, i.e. text, and NOT a model file.
  ##
  def add_constraints(model, constraints) when is_binary(model) and is_list(constraints) do
    Enum.reduce(
      constraints,
      model,
      fn c, acc ->
        acc <> constraint(c)
      end
    )
  end

end
