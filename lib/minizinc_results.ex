defmodule MinizincResults do
  @moduledoc """
    Functions and data structures for working with data produced by Minizinc during runtime.
  """

  require Logger
  require Record
  Record.defrecord :results_rec,
                   [
                     status: nil,
                     fzn_stats: %{},
                     solver_stats: %{},
                     mzn_stats: %{},
                     solution_data: %{},
                     time_elapsed: nil,
                     misc: %{},
                     json_buffer: "",
                     minizinc_output: "",
                     timestamp: nil,
                     solution_count: 0,
                     final_stats_flag: false # Flags first occurrence of "%%%mzn-stat-end".
                                             # which triggers parsing of final block of "%%%mzn-stat:"
                                             # as solver stats.
                   ]

  def update_results(results, "% time elapsed: " <> rest) do
    results_rec(results, time_elapsed: rest)
  end

  # solution stats
  def update_results(results_rec(mzn_stats: stats) = results, "%%%mzn-stat " <> rest) do
    results_rec(results, mzn_stats: process_stats(stats, rest))
  end


  # FlatZinc stats
  def update_results(results_rec(fzn_stats: stats, final_stats_flag: false) = results, "%%%mzn-stat: " <> rest) do
    results_rec(results, fzn_stats: process_stats(stats, rest))
  end

  # Solver stats (occurs only after solver outputs it's last solution.
  def update_results(results_rec(solver_stats: stats) = results, "%%%mzn-stat: " <> rest) do
    results_rec(results, solver_stats: process_stats(stats, rest))
  end


  # JSON-formatted solution data
  ## Opening of JSON
  def update_results(results, "{") do
    results_rec(results, json_buffer: "{")
  end

  ## Closing of JSON
  def update_results(results_rec(json_buffer: "{" <> _jbuffer = buff) = results, "}") do
    {:ok, solution_data} = Jason.decode(
      buff <> "}"
    )
    results_rec(
      results, json_buffer: "",
      solution_data: MinizincData.output_to_elixir(solution_data))
  end

  ## Collecting JSON data
  def update_results(results_rec(json_buffer: "{" <> _jbuffer = buff) = results, json_chunk) do
    results_rec(results, json_buffer: buff <> json_chunk)
  end


  def update_results(results, "%%%mzn-stat-end" <> _rest) do
    results_rec(results, final_stats_flag: true)
  end

  # Drop empty lines
  def update_results(results, "") do
    results
  end

  def update_results(results_rec(minizinc_output: u) = solution, unhandled) do
    results_rec(solution, minizinc_output: u <> "\n" <> unhandled)
  end

  def process_stats(stats, key_value_txt) do
    [stats_key, stats_value] = String.split(key_value_txt, "=")
    Map.put(stats, stats_key, stats_value)
  end

  def reset_results(results) do
    results_rec(
      results,
      status: nil,
      solution_data: %{},
      time_elapsed: nil,
      misc: %{},
      json_buffer: ""
    )
  end

  def update_status(nil, status) do
    results_rec(status: status)
  end

  def update_status(results, status) do
    results_rec(results, status: status)
  end

  def get_status(results_rec(status: :all_solutions) = results) do
      if MinizincModel.model_method(results) == :satisfy do
        :'ALL_SOLUTIONS'
      else
        :'OPTIMAL'
      end
  end

  def get_status(results_rec(status: status)) do
    status |> Atom.to_string |> String.upcase |> String.to_atom
  end

  def adjust_final_status(results_rec(status: nil, solution_count: count) = results) when count > 0 do
     results_rec(results, status: :satisfied)
  end

  def adjust_final_status(results_rec(status: nil, solution_count: count) = results) when count == 0 do
    results_rec(results, status: :unsatisfiable)
  end

  def adjust_final_status(results) do
    results
  end

end
