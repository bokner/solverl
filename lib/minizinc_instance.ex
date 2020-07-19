defmodule MinizincInstance do
  @moduledoc false

  require Record
  Record.defrecord :instance_rec,
                   [
                     status: nil,
                     fzn_stats: %{},
                     solver_stats: %{},
                     mzn_stats: %{},
                     solution_data: %{},
                     time_elapsed: nil,
                     misc: %{},
                     json_buffer: "",
                     unhandled_output: "",
                     timestamp: nil,
                     solution_count: 0,
                     final_stats_flag: false # Flags first occurrence of "%%%mzn-stat-end".
                                             # which triggers parsing of final block of "%%%mzn-stat:" as solver stats.
                   ]

  def update_instance(instance, "% time elapsed: " <> rest) do
    instance_rec(instance, time_elapsed: rest)
  end

  # solution stats
  def update_instance(instance_rec(mzn_stats: stats) = instance, "%%%mzn-stat " <> rest) do
    instance_rec(instance, mzn_stats: process_stats(stats, rest))
  end


  # FlatZinc stats
  def update_instance(instance_rec(fzn_stats: stats, final_stats_flag: false) = instance, "%%%mzn-stat: " <> rest) do
    instance_rec(instance, fzn_stats: process_stats(stats, rest))
  end

  # Solver stats (occurs only after solver outputs it's last solution.
  def update_instance(instance_rec(solver_stats: stats) = instance, "%%%mzn-stat: " <> rest) do
    instance_rec(instance, solver_stats: process_stats(stats, rest))
  end


  # JSON-formatted solution data
  ## Opening of JSON
  def update_instance(instance, "{") do
    instance_rec(instance, json_buffer: "{")
  end

  ## Closing of JSON
  def update_instance(instance_rec(json_buffer: "{" <> _jbuffer = buff) = instance, "}") do
    {:ok, solution_data} = Jason.decode(
      buff <> "}"
    )
    instance_rec(
      instance, json_buffer: "",
      solution_data: MinizincData.output_to_elixir(solution_data))
  end

  ## Collecting JSON data
  def update_instance(instance_rec(json_buffer: "{" <> _jbuffer = buff) = instance, json_chunk) do
    instance_rec(instance, json_buffer: buff <> json_chunk)
  end


  def update_instance(instance, "%%%mzn-stat-end" <> _rest) do
    instance_rec(instance, final_stats_flag: true)
  end

  def update_instance(instance_rec(unhandled_output: u) = solution, unhandled) do
    instance_rec(solution, unhandled_output: u <> "\n" <> unhandled)
  end

  def process_stats(stats, key_value_txt) do
    [stats_key, stats_value] = String.split(key_value_txt, "=")
    Map.put(stats, stats_key, stats_value)
  end

  def reset_instance(instance) do
    instance_rec(
      instance,
      status: nil,
      solution_data: %{},
      time_elapsed: nil,
      misc: %{},
      json_buffer: ""
    )
  end

  def update_status(nil, status) do
    instance_rec(status: status)
  end

  def update_status(instance, status) do
    instance_rec(instance, status: status)
  end

  def get_status(instance_rec(status: :all_solutions) = instance) do
      if MinizincModel.model_method(instance) == :satisfy do
        :'ALL_SOLUTIONS'
      else
        :'OPTIMAL'
      end
  end

  def get_status(instance_rec(status: status)) do
    status |> Atom.to_string |> String.upcase |> String.to_atom
  end

  def adjust_status(instance_rec(status: nil, solution_count: count) = instance) when count > 0 do
     instance_rec(instance, status: :satisfied)
  end

  def adjust_status(instance_rec(status: nil, solution_count: count) = instance) when count == 0 do
    instance_rec(instance, status: :unsatisfiable)
  end

  def adjust_status(instance) do
    instance
  end

end
