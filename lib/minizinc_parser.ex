defmodule ParserState do
  @moduledoc false

  defstruct status: nil,
            fzn_stats: %{},
            fzn_output: "",
            compiled: false,
            compilation_timestamp: nil,
            solver: nil,
            solver_stats: %{},
            mzn_stats: %{},
            solution_data: %{},
            time_elapsed: nil,
            minizinc_stderr: "",
            unclassified_output: "",
            timestamp: nil,
            solution_count: 0,
            json_buffer: ""
end

defmodule MinizincParser do
  @moduledoc false

  import ParserState

  # Functions for parsing a stream of text produced by Minizinc process.
  require Logger

  @solution_separator "----------"

  @status_completed "=========="
  @status_unsatisfiable "=====UNSATISFIABLE====="
  @status_unknown "=====UNKNOWN====="
  @status_error "=====ERROR====="
  @status_unsatOrUnbounded "=====UNSATorUNBOUNDED====="
  @status_unbounded "=====UNBOUNDED====="

  def initial_state do
    %ParserState{}
  end

  ## Parser interface
  def parse_output(stream, data, parser_state) do
    parser_event = parse_output(stream, data)

    case update_state(parser_state, parser_event) do
      {extended_parser_event, new_parser_state} ->
        {extended_parser_event, new_parser_state}

      new_parser_state ->
        {parser_event, new_parser_state}
        # when is_record()
    end
  end

  defp parse_output(:stderr, data) do
    {:stderr, data}
  end

  defp parse_output(:stdout, data) do
    parse_output(data)
  end

  ## Status events
  defp parse_output(@solution_separator) do
    {:status, :satisfied}
  end

  ## TODO: parsing/capturing status
  defp parse_output(@status_completed) do
    {:status, :all_solutions}
  end

  defp parse_output(@status_unsatisfiable) do
    {:status, :unsatisfiable}
  end

  defp parse_output(@status_unknown) do
    {:status, :unknown}
  end

  defp parse_output(@status_error) do
    {:status, :error}
  end

  defp parse_output(@status_unsatOrUnbounded) do
    {:status, :unsatOrUnbounded}
  end

  defp parse_output(@status_unbounded) do
    {:status, :ubounded}
  end

  ## Solution body events
  defp parse_output("{") do
    :solution_json_start
  end

  defp parse_output("}") do
    :solution_json_end
  end

  ## Time elapsed
  defp parse_output("% time elapsed: " <> rest) do
    {:time_elapsed, rest}
  end

  ## Solution stat record
  defp parse_output("%%%mzn-stat " <> rest) do
    [stats_key, stats_value] = String.split(rest, "=")
    {:solution_stats, key_value(stats_key, stats_value)}
  end

  ## Solver (fzn or post-solving) stat record
  defp parse_output("%%%mzn-stat: " <> rest) do
    [stats_key, stats_value] = String.split(rest, "=")
    {:solver_stats, key_value(stats_key, stats_value)}
  end

  defp parse_output("%%%mzn-stat-end" <> _rest) do
    :stats_end
  end

  defp parse_output(new_line) do
    new_line
  end

  defp map_to_elixir(map) do
    Enum.reduce(
      map,
      %{},
      fn {k, v}, acc ->
        Map.put(acc, k, MinizincData.to_elixir(v))
      end
    )
  end

  @doc false
  # Update parser with the line produced by Minizinc port.
  defp update_state(%ParserState{solution_count: sc} = results, {:status, :satisfied}) do
    %{
      results
      | status: :satisfied,
        timestamp: MinizincUtils.now(:microsecond),
        solution_count: sc + 1
    }
  end

  defp update_state(results, {:status, status}) do
    %{results | status: status}
  end

  # Solution status update
  defp update_state(
         %ParserState{mzn_stats: stats} = results,
         {:solution_stats, {key, val}}
       ) do
    %{results | mzn_stats: add_key_value(stats, key, val)}
  end

  ## Time elapsed
  defp update_state(results, {:time_elapsed, time}) do
    %{results | time_elapsed: time}
  end

  ## Statistics
  ##
  # FlatZinc stats
  defp update_state(
         %ParserState{fzn_stats: stats, compiled: false} = results,
         {:solver_stats, {key, val}}
       ) do
    %{results | fzn_stats: add_key_value(stats, key, val)}
  end

  # Solver stats (occurs only after solver outputs its last solution).
  defp update_state(
         %ParserState{solver_stats: stats} = results,
         {:solver_stats, {key, val}}
       ) do
    %{results | solver_stats: add_key_value(stats, key, val)}
  end

  ## The end of compilation
  defp update_state(%ParserState{compiled: false} = results, :stats_end) do
    ## flag the completion of compilation and make output to be FZN output
    ## Return extended event and a parser state
    {
      :compiled,
      %{results | compiled: true, compilation_timestamp: MinizincUtils.now(:microsecond)}
    }
  end

  defp update_state(%ParserState{compiled: true} = results, :stats_end) do
    results
  end

  # JSON-formatted solution data
  ## Opening of JSON
  defp update_state(results, :solution_json_start) do
    %{results | json_buffer: "{", solution_data: nil}
  end

  ## Closing of JSON
  defp update_state(
         %ParserState{json_buffer: "{" <> _jbuffer = buff} = results,
         :solution_json_end
       ) do
    {:ok, solution_data} = Jason.decode(buff <> "}")

    %{
      results
      | json_buffer: "",
        solution_data: map_to_elixir(solution_data)
    }
  end

  ## Collecting JSON data
  defp update_state(
         %ParserState{json_buffer: "{" <> _jbuffer = buff} = results,
         json_chunk
       )
       when is_binary(json_chunk) do
    %{results | json_buffer: buff <> json_chunk}
  end

  # Drop empty lines
  defp update_state(results, "") do
    results
  end

  ## Minizinc stderr.
  defp update_state(%ParserState{minizinc_stderr: u} = results, {:stderr, new_line})
       when is_binary(new_line) do
    %{results | minizinc_stderr: u <> "\n" <> new_line}
  end

  ## Compilation in progress...
  defp update_state(%ParserState{fzn_output: u, compiled: false} = results, new_line)
       when is_binary(new_line) do
    %{results | fzn_output: u <> "\n" <> new_line}
  end

  # Unclassified
  defp update_state(%ParserState{unclassified_output: u, compiled: true} = results, new_line)
       when is_binary(new_line) do
    %{results | unclassified_output: u <> "\n" <> new_line}
  end

  ## 'Parser -> solver events' mapping

  #  @summary_fields [
  #    :status,           # Solver status (one of :satisfied, :unsatisfiable etc)
  #    :fzn_stats,        # Map of FlatZinc statistics values keyed with the field names
  #    :solver,           # solver MiniZinc id
  #    :solver_stats,     # Map of solver statistics values keyed with the field names
  #    :solution_count,   # Total number of solutions found
  #    :last_solution,    # Data for last :solution event (see above)
  #    :minizinc_output,  # MiniZinc errors and warnings
  #    :time_elapsed      # Time elapsed, verbatim as reported by MiniZinc
  #  ]
  #
  #  @solution_fields [
  #    :data,       # Map of values keyed with their variable names
  #    :timestamp,  # Timestamp of the moment solution was parsed
  #    :index,      # Sequential number of the solution
  #    :stats       # Map of solution statistics values keyed with the field names
  #  ]
  #
  #  @minizinc_error_fields [
  #    :error       # MiniZinc output generated by runtime error
  #  ]

  ## Data for solver events
  def solution(%ParserState{
        solution_data: data,
        timestamp: timestamp,
        mzn_stats: stats,
        solution_count: count
      }) do
    %{data: data, timestamp: timestamp, index: count, stats: stats}
  end

  def summary(
        %ParserState{} = results,
        model_info \\ nil
      ) do
    raw_summary =
      results
      |> Map.take([
        :status,
        :solution_count,
        :fzn_stats,
        :fzn_output,
        :compiled,
        :compilation_timestamp,
        :solver,
        :solver_stats,
        :minizinc_stderr,
        :unclassified_input,
        :time_elapsed
      ])
      |> Map.put(:last_solution, solution(results))

    ## Update status and add model info
    case model_info do
      _info when is_list(model_info) ->
        raw_summary
        |> Map.put(:status, MinizincResults.status(model_info[:method], results.status))
        |> Map.put(:model_info, model_info)

      _no_model_info ->
        raw_summary
    end
  end

  ## This function is not intended to be called explicitly.
  ## Rather, it's being used by solution handlers.
  ## For now, we just take the unclassified output as an error message.
  ## TODO: actually parse in order to give more details on the error.
  def minizinc_error(%ParserState{minizinc_stderr: error}) do
    %{error: error}
  end

  def compilation_info(%ParserState{} = state) do
    Map.take(state, [:fzn_stats, :fzn_output, :compiled, :compilation_timestamp])
  end

  defp key_value(key, value) do
    {String.to_atom(key), MinizincUtils.parse_value(value)}
  end

  defp add_key_value(map, key, value) when is_map(map) do
    {nil, new_map} =
      Map.get_and_update(
        map,
        key,
        fn
          nil -> {nil, value}
          current when is_list(current) -> {nil, [value | current]}
          current -> {nil, [value, current]}
        end
      )

    new_map
  end
end
