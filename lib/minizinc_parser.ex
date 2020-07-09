defmodule MinizincParser do
  @moduledoc false
  require Logger
  import Jason

  require Record
  Record.defrecord :solution_rec,
                   [status: nil, solver_stats: %{}, mzn_stats: %{},
                     solution_data: %{}, time_elapsed: nil, misc: %{},
                     json_buffer: ""
                   ]

  @solution_separator "----------"
  @optimal       "=========="
  @unsatisfiable "=====UNSATISFIABLE====="

  @solution_status_reg  ~r/^-{10}|={5}(ERROR|UNKNOWN|UNSATISFIABLE|UNSATorUNBOUNDED|UNBOUNDED|)?={5}/


  def read_solution(solution_record, @solution_separator) do
    {:ok, solution_rec(solution_record, status: :satisfied)}
  end

  def read_solution(solution_record, new_line) do
    Logger.info "Data: #{inspect new_line}"
    {:incomplete, update_solution(solution_record, new_line)}
  end

  def update_solution(solution_record, "% time elapsed: "<> rest) do
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
  def update_solution(solution_rec(json_buffer: "{"<> jbuffer = buff) = solution_record, "}") do
    {:ok, solution_data} = Jason.decode(
        buff <> "}")
    solution_rec(solution_record, json_buffer: "", solution_data: solution_data)
  end

  ## Collecting JSON data
  def update_solution(solution_rec(json_buffer: "{"<> jbuffer = buff) = solution_record, json_chunk) do
    solution_rec(solution_record, json_buffer: buff <> json_chunk)
  end


  def update_solution(solution_record, "%%%mzn-stat-end "<> rest) do
    solution_record
  end

  ## TODO: parsing/capturing status
  def update_solution(solution_record, @optimal) do
    solution_rec(solution_record, status: :optimal)
  end

  def update_solution(solution_record, @unsatisfiable) do
    solution_rec(solution_record, status: :unsatisfiable)
  end

  def update_solution(solution_record, _unhandled) do
    solution_record
  end

  def process_stats(stats, key_value_txt) do
    [stats_key, stats_value] = String.split(key_value_txt, "=")
    Map.put(stats, stats_key, stats_value)
  end

  def reset_solution(solution_record) do
    solution_rec(solution_record, solution_data: %{}, time_elapsed: nil, misc: %{},
                                      json_buffer: "")
  end
end
