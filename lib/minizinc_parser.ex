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
    @status_completed, @status_unsatisfiable,
    @status_unknown, @status_error,
    @status_unsatOrUnbounded, @status_unbounded
  ]


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

  def parse_output( @status_unknown) do
    {:status, :unknown}
  end

  def parse_output( @status_error) do
    {:status, :error}
  end

  def parse_output( @status_unsatOrUnbounded) do
    {:status, :unsatOrUnbounded}
  end

  def parse_output( @status_unbounded) do
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

  ## Helpers
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
