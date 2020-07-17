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



  def handle_output(instance_rec(solution_count: sc) = instance, @solution_separator) do
    {:satisfied,
      instance_rec(instance,
        timestamp: DateTime.to_unix(DateTime.utc_now, :microsecond),
        solution_count: sc + 1
      )}
  end

  ## TODO: parsing/capturing status
  def handle_output(instance, @status_completed) do
    {:completed, instance}
  end

  def handle_output(instance, @status_unsatisfiable) do
    {:unsatisfiable, instance}
  end

  def handle_output(instance, @status_unknown) do
    {:unknown, instance}
  end

  def handle_output(instance, @status_error) do
    {:error, instance}
  end

  def handle_output(instance, @status_unsatOrUnbounded) do
    {:unsatOrUnbounded, instance}
  end

  def handle_output(instance, @status_unbounded) do
    {:ubounded, instance}
  end

  def handle_output(instance, new_line) do
    #Logger.info "Data: #{inspect new_line}"
    {nil, MinizincInstance.update_instance(instance, new_line)}
  end


end
