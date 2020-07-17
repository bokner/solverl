defmodule MinizincParser do
  @moduledoc false
  require Logger
  import MinizincUtils

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
    {nil, update_instance(instance, new_line)}
  end

  def update_instance(instance, "% time elapsed: " <> rest) do
    instance_rec(instance, time_elapsed: rest)
  end

  # solution stats
  def update_instance(instance_rec(mzn_stats: stats) = instance, "%%%mzn-stat " <> rest) do
    instance_rec(instance, mzn_stats: process_stats(stats, rest))
  end

  # fzn and/or solver stats
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
    instance
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

  def merge_solver_stats(instance_rec(solver_stats: stats1) = solution, instance_rec(solver_stats: stats2)) do
    instance_rec(solution, solver_stats: Map.merge(stats1, stats2))
  end

end
