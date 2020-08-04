defmodule MinizincParser do
  @moduledoc false

  # Functions for parsing a stream of text produced by Minizinc process.
  require Logger

  @solution_separator      "----------"

  @status_completed          "=========="
  @status_unsatisfiable    "=====UNSATISFIABLE====="
  @status_unknown          "=====UNKNOWN====="
  @status_error            "=====ERROR====="
  @status_unsatOrUnbounded "=====UNSATorUNBOUNDED====="
  @status_unbounded        "=====UNBOUNDED====="

  @terminating_separators [
    @status_completed,
    @status_unsatisfiable,
    @status_unknown,
    @status_error,
    @status_unsatOrUnbounded,
    @status_unbounded
  ]

  require Record
  @doc false
  Record.defrecord(
    :parser_rec,
    status: nil,
    fzn_stats: %{},
    solver_stats: %{},
    mzn_stats: %{},
    solution_data: %{},
    time_elapsed: nil,
    fzn_output: "",
    minizinc_stderr: "",
    unclassified_output: "",
    timestamp: nil,
    solution_count: 0,
    json_buffer: "",
    compiled: false
    # Flags first occurrence of "%%%mzn-stat-end".
    # which triggers parsing of final block of "%%%mzn-stat:"
    # as solver stats.
  )

  @type parser_rec :: record(
                        :parser_rec,
                        status: atom(),
                        fzn_stats: map(),
                        solver_stats: map(),
                        mzn_stats: map(),
                        solution_data: map(),
                        time_elapsed: any(),
                        fzn_output: binary(),
                        minizinc_stderr: binary(),
                        unclassified_output: binary(),
                        timestamp: DateTime.t(),
                        solution_count: integer(),
                        json_buffer: binary(),
                        compiled: boolean()
                      )



  ## Parser interface
  def parse_output(:stderr, data) do
    {:stderr, data}
  end

  def parse_output(:stdout, data) do
    parse_output(data)
  end

  ## Status events
  def parse_output(@solution_separator) do
    {:status, :satisfied}
  end

  ## TODO: parsing/capturing status
  def parse_output(@status_completed) do
    {:status, :all_solutions}
  end

  def parse_output(@status_unsatisfiable) do
    {:status, :unsatisfiable}
  end

  def parse_output(@status_unknown) do
    {:status, :unknown}
  end

  def parse_output(@status_error) do
    {:status, :error}
  end

  def parse_output(@status_unsatOrUnbounded) do
    {:status, :unsatOrUnbounded}
  end

  def parse_output(@status_unbounded) do
    {:status, :ubounded}
  end

  ## Solution body events
  def parse_output("{") do
    :solution_json_start
  end

  def parse_output("}") do
    :solution_json_end
  end

  ## Time elapsed
  def parse_output("% time elapsed: " <> rest) do
    {:time_elapsed, rest}
  end

  ## Solution stat record
  def parse_output("%%%mzn-stat " <> rest) do
    [stats_key, stats_value] = String.split(rest, "=")
    {:solution_stats, key_value(stats_key, stats_value)}
  end

  ## Solver (fzn or post-solving) stat record
  def parse_output("%%%mzn-stat: " <> rest) do
    [stats_key, stats_value] = String.split(rest, "=")
    {:solver_stats, key_value(stats_key, stats_value)}
  end


  def parse_output("%%%mzn-stat-end" <> _rest) do
    :stats_end
  end

  def parse_output(new_line) do
    new_line
  end


  @doc false
  # Update parser with the line produced by Minizinc port.
  def update_state(parser_rec(solution_count: sc) = results, {:status, :satisfied}) do
    parser_rec(
      results,
      status: :satisfied,
      timestamp: DateTime.to_unix(DateTime.utc_now, :microsecond),
      solution_count: sc + 1
    )
  end

  def update_state(results, {:status, status}) do
    parser_rec(results, status: status)
  end

  # Solution status update
  def update_state(
        parser_rec(mzn_stats: stats) = results,
        {:solution_stats, {key, val}}
      ) do
    parser_rec(results, mzn_stats: Map.put(stats, key, val))
  end

  ## Time elapsed
  def update_state(results, {:time_elapsed, time}) do
    parser_rec(results, time_elapsed: time)
  end

  ## Statistics
  ##
  # FlatZinc stats
  def update_state(
        parser_rec(fzn_stats: stats, compiled: false) = results,
        {:solver_stats, {key, val}}
      ) do
    parser_rec(results, fzn_stats: Map.put(stats, key, val))
  end

  # Solver stats (occurs only after solver outputs its last solution).
  def update_state(
        parser_rec(solver_stats: stats) = results,
        {:solver_stats, {key, val}}
      ) do
    parser_rec(results, solver_stats: Map.put(stats, key, val))
  end

  ## The end of compilation
  def update_state(parser_rec(compiled: false) = results, :stats_end) do
    ## flag the completion of compilation and make output to be FZN output
    parser_rec(results, compiled: true)
  end

  def update_state(parser_rec(compiled: true) = results, :stats_end) do
    results
  end

  # JSON-formatted solution data
  ## Opening of JSON
  def update_state(results, :solution_json_start) do
    parser_rec(results, json_buffer: "{", solution_data: nil)
  end

  ## Closing of JSON
  def update_state(parser_rec(json_buffer: "{" <> _jbuffer = buff) = results, :solution_json_end) do
    {:ok, solution_data} = Jason.decode(
      buff <> "}"
    )
    parser_rec(
      results,
      json_buffer: "",
      solution_data: MinizincData.output_to_elixir(solution_data)
    )
  end

  ## Collecting JSON data
  def update_state(
        parser_rec(json_buffer: "{" <> _jbuffer = buff) = results,
        json_chunk
      ) when is_binary(json_chunk) do
    parser_rec(results, json_buffer: buff <> json_chunk)
  end

  # Drop empty lines
  def update_state(results, "") do
    results
  end

  ## Minizinc stderr.
  def update_state(parser_rec(minizinc_stderr: u) = results, {:stderr, new_line}) when is_binary(new_line) do
    parser_rec(results, minizinc_stderr: u <> "\n" <> new_line)
  end

  ## Compilation in progress...
  def update_state(parser_rec(fzn_output: u, compiled: false) = results, new_line) when is_binary(new_line) do
    parser_rec(results, fzn_output: u <> "\n" <> new_line)
  end

 # Unclassified
  def update_state(parser_rec(unclassified_output: u, compiled: true) = results, new_line) when is_binary(new_line) do
    parser_rec(results, unclassified_output: u <> "\n" <> new_line)
  end



  ## Data for solver events
  def solution(parser_rec(solution_data: data, timestamp: timestamp, mzn_stats: stats, solution_count: count)) do
    %{data: data, timestamp: timestamp, index: count, stats: stats}
  end

  def summary(
        parser_rec(
          status: status,
          solution_count: solution_count,
          solver_stats: solver_stats,
          fzn_stats: fzn_stats,
          fzn_output: fzn_output,
          minizinc_stderr: minizinc_stderr,
          unclassified_output: unclassified,
          time_elapsed: time_elapsed
        ) = results
      ) do
    raw_summary = %{
      status: status,
      fzn_stats: fzn_stats,
      solver_stats: solver_stats,
      solution_count: solution_count,
      last_solution: solution(results),
      fzn_output: fzn_output,
      minizinc_stderr: minizinc_stderr,
      unclassified_output: unclassified,
      time_elapsed: time_elapsed
    }
    ## Update status
    Map.put(raw_summary, :status, get_status(raw_summary))
  end

  ## This function is not intended to be called explicitly.
  ## Rather, it's being used by solution handlers.
  ## For now, we just take the unclassified output as an error message.
  ## TODO: actually parse in order to give more details on the error.
  def minizinc_error(parser_rec(minizinc_stderr: error)) do
    %{error: error}
  end


  ## Helpers

  defp get_status(%{status: :all_solutions} = summary) do
    if MinizincModel.model_method(summary) == :satisfy do
      :all_solutions
    else
      :optimal
    end
  end

  defp get_status(%{status: status} = _summary) do
    status
    |> Atom.to_string
    |> String.to_atom
  end



  defp key_value(key, value) do
    {String.to_atom(key), parse_value(value)}
  end

  @doc false
  def parse_value(value) do
    case Integer.parse(value) do
      :error -> ## Must be a string
        String.replace(value, "\"", "")
      {int_value, ""} ->
        int_value
      {_rounded, _tail} -> ## Not integer, try float
        {float_value, ""} = Float.parse(value)
        float_value
    end
  end

end
