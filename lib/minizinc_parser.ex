defmodule MinizincParser do
  @moduledoc false
  require Logger

  require Record
  Record.defrecord :solution_rec,
                   [
                     status: nil,
                     solver_stats: %{},
                     mzn_stats: %{},
                     solution_data: %{},
                     time_elapsed: nil,
                     misc: %{},
                     json_buffer: ""
                   ]

  @solution_separator      "----------"

  @status_optimal          "=========="
  @status_unsatisfiable    "=====UNSATISFIABLE====="
  @status_unknown          "=====UNKNOWN====="
  @status_error            "=====ERROR====="
  @status_unsatOrUnbounded "=====UNSATorUNBOUNDED====="
  @status_unbounded        "=====UNBOUNDED====="



  def read_solution(solution_record, @solution_separator) do
    {:satisfied, solution_record}
  end

  ## TODO: parsing/capturing status
  def read_solution(solution_record, @status_optimal) do
    {:optimal, solution_record}
  end

  def read_solution(solution_record, @status_unsatisfiable) do
    {:unsatisfiable, solution_record}
  end

  def read_solution(solution_record, @status_unknown) do
    {:unknown, solution_record}
  end

  def read_solution(solution_record, @status_error) do
    {:error, solution_record}
  end

  def read_solution(solution_record, @status_unsatOrUnbounded) do
    {:unsatOrUnbounded, solution_record}
  end

  def read_solution(solution_record, @status_unbounded) do
    {:ubounded, solution_record}
  end

  def read_solution(solution_record, new_line) do
    #Logger.info "Data: #{inspect new_line}"
    {nil, update_solution(solution_record, new_line)}
  end

  def update_solution(solution_record, "% time elapsed: " <> rest) do
    solution_rec(solution_record, time_elapsed: rest)
  end

  # solution stats
  def update_solution(solution_rec(mzn_stats: stats) = solution_record, "%%%mzn-stat " <> rest) do
    solution_rec(solution_record, mzn_stats: process_stats(stats, rest))
  end

  # fzn and/or solver stats
  def update_solution(solution_rec(solver_stats: stats) = solution_record, "%%%mzn-stat: " <> rest) do
    solution_rec(solution_record, solver_stats: process_stats(stats, rest))
  end

  # JSON-formatted solution data
  ## Opening of JSON
  def update_solution(solution_record, "{") do
    solution_rec(solution_record, json_buffer: "{")
  end

  ## Closing of JSON
  def update_solution(solution_rec(json_buffer: "{" <> _jbuffer = buff) = solution_record, "}") do
    {:ok, solution_data} = Jason.decode(
      buff <> "}"
    )
    solution_rec(
      solution_record, json_buffer: "",
      solution_data: MinizincData.output_to_elixir(solution_data))
  end

  ## Collecting JSON data
  def update_solution(solution_rec(json_buffer: "{" <> _jbuffer = buff) = solution_record, json_chunk) do
    solution_rec(solution_record, json_buffer: buff <> json_chunk)
  end


  def update_solution(solution_record, "%%%mzn-stat-end " <> _rest) do
    solution_record
  end

  def update_solution(solution_record, _unhandled) do
    solution_record
  end

  def process_stats(stats, key_value_txt) do
    [stats_key, stats_value] = String.split(key_value_txt, "=")
    Map.put(stats, stats_key, stats_value)
  end

  def reset_solution(solution_record) do
    solution_rec(
      solution_record,
      status: nil,
      solution_data: %{},
      time_elapsed: nil,
      misc: %{},
      json_buffer: ""
    )
  end

  def update_status(nil, status) do
    solution_rec(status: status)
  end

  def update_status(solution_record, status) do
    solution_rec(solution_record, status: status)
  end

  def merge_solver_stats(solution_rec(solver_stats: stats1) = solution, solution_rec(solver_stats: stats2)) do
    solution_rec(solution, solver_stats: Map.merge(stats1, stats2))
  end

end
