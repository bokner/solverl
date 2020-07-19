defmodule MinizincParser do
  @moduledoc false
  require Logger
  import MinizincInstance

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

  def handle_output(instance_rec(solution_count: sc) = instance, @solution_separator) do
    MinizincInstance.update_status(
        instance_rec(instance,
        timestamp: DateTime.to_unix(DateTime.utc_now, :microsecond),
        solution_count: sc + 1
      ), :satisfied)
  end

  ## TODO: parsing/capturing status
  def handle_output(instance, @status_completed) do
      MinizincInstance.update_status(instance, :all_solutions)
  end

  def handle_output(instance, @status_unsatisfiable) do
    MinizincInstance.update_status(instance, :unsatisfiable)
  end

  def handle_output(instance, @status_unknown) do
    MinizincInstance.update_status(instance, :unknown)
  end

  def handle_output(instance, @status_error) do
    MinizincInstance.update_status(instance, :error)
  end

  def handle_output(instance, @status_unsatOrUnbounded) do
    MinizincInstance.update_status(instance, :unsatOrUnbounded)
  end

  def handle_output(instance, @status_unbounded) do
    MinizincInstance.update_status(instance, :ubounded)
  end

  def handle_output(instance, new_line) do
    MinizincInstance.update_instance(instance, new_line)
  end


end
