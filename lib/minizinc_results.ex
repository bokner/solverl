defmodule MinizincResults do
  @moduledoc """
    Functions and data structures for working with data produced by Minizinc during runtime.
  """

  require Logger
  require Record
  @doc false
  Record.defrecord(:parser_rec,
                     status: nil,
                     fzn_stats: %{} ,
                     solver_stats: %{} ,
                     mzn_stats: %{} ,
                     solution_data: %{},
                     time_elapsed: nil,
                     minizinc_output: "",
                     timestamp: nil,
                     solution_count: 0,
                     json_buffer: "",
                     final_stats_flag: false # Flags first occurrence of "%%%mzn-stat-end".
                                             # which triggers parsing of final block of "%%%mzn-stat:"
                                             # as solver stats.
  )

  @type parser_rec :: record(:parser_rec,
                             status: atom(),
                             fzn_stats: map(),
                             solver_stats: map(),
                             mzn_stats: map(),
                             solution_data: map(),
                             time_elapsed: any(),
                             minizinc_output: binary(),
                             timestamp: DateTime.t(),
                             solution_count: integer(),
                             json_buffer: binary(),
                             final_stats_flag: boolean()
                                         )



  @doc false
  # Update parser with the line produced by Minizinc port.
  def update_results(parser_rec(solution_count: sc) =  results, {:status, :satisfied}) do
    parser_rec(results,
      status: :satisfied,
      timestamp: DateTime.to_unix(DateTime.utc_now, :microsecond),
      solution_count: sc + 1
    )
  end

  def update_results(results, {:status, status}) do
    parser_rec(results, status: status)
  end

  # Solution status update
  def update_results(parser_rec(mzn_stats: stats) = results,
        {:solution_stats, {key, val} }) do
    parser_rec(results, mzn_stats: Map.put(stats, key, val))
  end

  ## Time elapsed
  def update_results(results, {:time_elapsed, time}) do
    parser_rec(results, time_elapsed: time)
  end
  ## Statistics
  ##
  # FlatZinc stats
  def update_results(parser_rec(fzn_stats: stats, final_stats_flag: false) = results,
        {:solver_stats, {key, val} }) do
    parser_rec(results, fzn_stats: Map.put(stats, key, val))
  end

  # Solver stats (occurs only after solver outputs its last solution).
  def update_results(parser_rec(solver_stats: stats) = results,
        {:solver_stats, {key, val} }) do
    parser_rec(results, solver_stats: Map.put(stats, key, val))
  end

  def update_results(results, :stats_end) do
    parser_rec(results, final_stats_flag: true)
  end

  # JSON-formatted solution data
  ## Opening of JSON
  def update_results(results, :solution_json_start) do
    parser_rec(results, json_buffer: "{", solution_data: nil)
  end

  ## Closing of JSON
  def update_results(parser_rec(json_buffer: "{" <> _jbuffer = buff) = results, :solution_json_end) do
    {:ok, solution_data} = Jason.decode(
      buff <> "}"
    )
    parser_rec(
      results, json_buffer: "",
      solution_data: MinizincData.output_to_elixir(solution_data))
  end

  ## Collecting JSON data
  def update_results(
        parser_rec(json_buffer: "{" <> _jbuffer = buff) = results, json_chunk) when is_binary(json_chunk) do
    parser_rec(results, json_buffer: buff <> json_chunk)
  end

  # Drop empty lines
  def update_results(results, "") do
    results
  end

  ## Unclassified, likely Minizinc stderr.
  def update_results(parser_rec(minizinc_output: u) = solution, new_line) when is_binary(new_line) do
    parser_rec(solution, minizinc_output: u <> "\n" <> new_line)
  end


  defp get_status(%{status: :all_solutions} = summary) do
      if MinizincModel.model_method(summary) == :satisfy do
        :all_solutions
      else
        :optimal
      end
  end

  defp get_status(%{status: status} = _summary) do
    status |> Atom.to_string |> String.to_atom
  end

  def solution(parser_rec(solution_data: data, timestamp: timestamp, mzn_stats: stats, solution_count: count)) do
    %{data: data, timestamp: timestamp, index: count, stats: stats}
  end

  def summary(parser_rec(
    status: status, solution_count: solution_count,
    solver_stats: solver_stats, fzn_stats: fzn_stats,
    minizinc_output: minizinc_output, time_elapsed: time_elapsed
  ) = results) do
    raw_summary = %{status: status,
      fzn_stats: fzn_stats,
      solver_stats: solver_stats,
      solution_count: solution_count,
      last_solution: solution(results),
      minizinc_output: minizinc_output,
      time_elapsed: time_elapsed}
    ## Update status
    Map.put(raw_summary, :status, get_status(raw_summary))
  end

  ## This function is not intended to be called explicitly.
  ## Rather, it's being used by solution handlers.
  ## For now, we just take the unclassified output as an error message.
  ## TODO: actually parse in order to give more details on the error.
  def minizinc_error(parser_rec(minizinc_output: error)) do
    %{error: error}
  end

  ############### Events and solver results ##################
  def get_objective(solution) do
    solution[:data]["_objective"]
  end


end
