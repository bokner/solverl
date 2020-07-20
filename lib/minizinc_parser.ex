defmodule MinizincParser do
  @moduledoc """
    Functions for parsing a stream of text produced by Minizinc process.
  """
  require Logger
  import MinizincResults

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

  def handle_output(results_rec(solution_count: sc) = results, @solution_separator) do
    MinizincResults.update_status(
        results_rec(results,
        timestamp: DateTime.to_unix(DateTime.utc_now, :microsecond),
        solution_count: sc + 1
      ), :satisfied)
  end

  ## TODO: parsing/capturing status
  def handle_output(results, @status_completed) do
      MinizincResults.update_status(results, :all_solutions)
  end

  def handle_output(results, @status_unsatisfiable) do
    MinizincResults.update_status(results, :unsatisfiable)
  end

  def handle_output(results, @status_unknown) do
    MinizincResults.update_status(results, :unknown)
  end

  def handle_output(results, @status_error) do
    MinizincResults.update_status(results, :error)
  end

  def handle_output(results, @status_unsatOrUnbounded) do
    MinizincResults.update_status(results, :unsatOrUnbounded)
  end

  def handle_output(results, @status_unbounded) do
    MinizincResults.update_status(results, :ubounded)
  end

  def handle_output(results, new_line) do
    MinizincResults.update_results(results, new_line)
  end


end
