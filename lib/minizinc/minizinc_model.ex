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
    ""
  end

  ## Multiple models
  def make_model(model) when is_list(model) do
    Enum.reduce(
      model,
      "",
      fn m, acc ->
        acc <>
          Enum.join(
            [
              @submodel_header,
              read_model(m),
              @submodel_footer
            ],
            "\n"
          )
      end
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
  @dzn_header "%%%%% DZN START"
  @dzn_footer "%%%%% DZN END"

  def mzn_dzn_info(model, data, solver_opts \\ []) do
    ## Create a temporary file for the joint model
    model_file =
      String.replace_suffix(
        String.trim(MinizincUtils.cmd("mktemp")),
        ".mzn",
        ""
      ) <> ".mzn"

    model_body = MinizincModel.make_model(model)
    dzn_body = MinizincData.to_dzn(data)

    File.write(
      model_file,
      Enum.join(
        [model_body, @dzn_header, dzn_body, @dzn_footer],
        "\n"
      )
    )

    MinizincModel.model_info(model_file, solver_opts)
  end

  def model_info(model_file, solver_opts \\ [])
      when is_binary(model_file) do
    solver_opts = Keyword.merge(MinizincSolver.default_solver_opts(), solver_opts)

    model_info_cmd =
      "#{solver_opts[:minizinc_executable]} #{model_file} --solver #{solver_opts[:solver]} --model-interface-only --allow-multiple-assignments #{solver_opts[:extra_flags]}"

    mzn_output = cmd(model_info_cmd)

    case decode_model_info(mzn_output) do
      {:ok, model_info} ->
        [
          {:model_file, model_file}
          | Enum.map(
              model_info,
              fn
                {"input", v} -> {:pars, v}
                {"output", v} -> {:vars, v}
                {"method", method_name} -> {:method, translate_method(method_name)}
                {k, v} -> {String.to_atom(k), v}
              end
            )
        ]

      {:error, _jason_error} ->
        ## TODO : parse error
        {:error, mzn_output}
    end
  end

  def decode_model_info(model_output) do
    case Jason.decode(model_output) do
      {:ok, model_info} ->
        {:ok, model_info}

      {:error, %{data: data, position: position}} ->
        ## Try to re-parse the "valid" part of the output
        json_part = String.slice(data, 0..(position - 1))
        Jason.decode(json_part)
    end
  end

  ## Add checker model to the existing model info.
  def add_checker(checker_model, model_info) do
    if MinizincUtils.undefined(checker_model) do
      model_info
    else
      checker_file = String.replace(model_info[:model_file], ".mzn", ".mzc.mzn")
      checker_body = make_model(checker_model)
      File.write(checker_file, checker_body)
      Keyword.put(model_info, :checker_file, checker_file)
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
