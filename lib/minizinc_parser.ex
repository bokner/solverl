defmodule MinizincParser do
  @moduledoc false
  require Logger
  import MinizincUtils

  @solution_separator      "----------"

  @status_optimal          "=========="
  @status_unsatisfiable    "=====UNSATISFIABLE====="
  @status_unknown          "=====UNKNOWN====="
  @status_error            "=====ERROR====="
  @status_unsatOrUnbounded "=====UNSATorUNBOUNDED====="
  @status_unbounded        "=====UNBOUNDED====="



  def handle_output(instance_rec(solution_count: sc) = instance_record, @solution_separator) do
    {:satisfied,
      instance_rec(instance_record,
        timestamp: DateTime.to_unix(DateTime.utc_now, :microsecond),
        solution_count: sc + 1
      )}
  end

  ## TODO: parsing/capturing status
  def handle_output(instance_record, @status_optimal) do
    {:optimal, instance_record}
  end

  def handle_output(instance_record, @status_unsatisfiable) do
    {:unsatisfiable, instance_record}
  end

  def handle_output(instance_record, @status_unknown) do
    {:unknown, instance_record}
  end

  def handle_output(instance_record, @status_error) do
    {:error, instance_record}
  end

  def handle_output(instance_record, @status_unsatOrUnbounded) do
    {:unsatOrUnbounded, instance_record}
  end

  def handle_output(instance_record, @status_unbounded) do
    {:ubounded, instance_record}
  end

  def handle_output(instance_record, new_line) do
    #Logger.info "Data: #{inspect new_line}"
    {nil, update_instance(instance_record, new_line)}
  end

  def update_instance(instance_record, "% time elapsed: " <> rest) do
    instance_rec(instance_record, time_elapsed: rest)
  end

  # solution stats
  def update_instance(instance_rec(mzn_stats: stats) = instance_record, "%%%mzn-stat " <> rest) do
    instance_rec(instance_record, mzn_stats: process_stats(stats, rest))
  end

  # fzn and/or solver stats
  def update_instance(instance_rec(solver_stats: stats) = instance_record, "%%%mzn-stat: " <> rest) do
    instance_rec(instance_record, solver_stats: process_stats(stats, rest))
  end

  # JSON-formatted solution data
  ## Opening of JSON
  def update_instance(instance_record, "{") do
    instance_rec(instance_record, json_buffer: "{")
  end

  ## Closing of JSON
  def update_instance(instance_rec(json_buffer: "{" <> _jbuffer = buff) = instance_record, "}") do
    {:ok, solution_data} = Jason.decode(
      buff <> "}"
    )
    instance_rec(
      instance_record, json_buffer: "",
      solution_data: MinizincData.output_to_elixir(solution_data))
  end

  ## Collecting JSON data
  def update_instance(instance_rec(json_buffer: "{" <> _jbuffer = buff) = instance_record, json_chunk) do
    instance_rec(instance_record, json_buffer: buff <> json_chunk)
  end


  def update_instance(instance_record, "%%%mzn-stat-end" <> _rest) do
    instance_record
  end

  def update_instance(instance_rec(unhandled_output: u) = solution, unhandled) do
    instance_rec(solution, unhandled_output: u <> "\n" <> unhandled)
  end

  def process_stats(stats, key_value_txt) do
    [stats_key, stats_value] = String.split(key_value_txt, "=")
    Map.put(stats, stats_key, stats_value)
  end

  def reset_instance(instance_record) do
    instance_rec(
      instance_record,
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

  def update_status(instance_record, status) do
    instance_rec(instance_record, status: status)
  end

  def merge_solver_stats(instance_rec(solver_stats: stats1) = solution, instance_rec(solver_stats: stats2)) do
    instance_rec(solution, solver_stats: Map.merge(stats1, stats2))
  end

end
