defmodule MinizincParser do
  @moduledoc false
  require Logger
  require Record
  Record.defrecord :solution_rec,
                   [status: nil, fzn_stats: %{}, mzn_stats: %{},
                     solution: %{}, time_elapsed: nil, misc: %{},
                     json_buffer: ""
                   ]

  @solution_separator "----------"

  def read_solution(solution_record, @solution_separator) do
    {:ok, solution_record}
  end

  def read_solution(solution_record, new_line) do
    Logger.info "Data: #{inspect new_line}"
    {:incomplete, update_solution(solution_record, new_line)}
  end

  def update_solution(solution_record, "% time elapsed: "<> rest) do

  end

  def update_solution(solution_record, "%%%mzn-stat "<> rest) do

  end

  def update_solution(solution_record, "%%%mzn-stat-end "<> rest) do

  end

  def update_solution(solution_record, _unhandled) do
    solution_record
  end
end
