defmodule Sudoku do
  @moduledoc """
    Example: Sudoku solver.
  """

  require Logger
  import MinizincResults

  @sample_sudoku_1_solution  "85...24..72......9..4.........1.7..23.5...9...4...........8..7..17..........36.4."
  @sample_sudoku_5_solutions "8..6..9.5.............2.31...7318.6.24.....73...........279.1..5...8..36..3......"

  # Sudoku puzzle is a string
  # with elements of the puzzle in row-major order, where a blank entry is represented by "."
  def solve(puzzle, args \\ [])  do
    # Turn a string into 9x9 grid
    sudoku_array = sudoku_string_to_grid(puzzle)
    Logger.info "Sudoku puzzle:"
    Logger.info print_grid(sudoku_array)

    opts = Keyword.put(args, :solution_handler, &solution_handler/2)
    {:ok, _pid} = MinizincSolver.solve(
      "mzn/sudoku.mzn",
      %{"S": 3, start: sudoku_array},
      opts)
  end

  ## Solve synchronously
  ## Example (prints all solutions):
  ##
  ## Enum.each(Sudoku.solve_sync(
  ##    "8..6..9.5.............2.31...7318.6.24.....73...........279.1..5...8..36..3......"),
  ##    fn sol -> Logger.info Sudoku.print_grid(sol["puzzle"]) end)
  ##
  ##
  def solve_sync(puzzle) do
    # Turn a string into 9x9 grid
    sudoku_array = sudoku_string_to_grid(puzzle)
    Logger.info "Sudoku puzzle (solved synchronously)"
    Logger.info print_grid(sudoku_array)
    MinizincSolver.solve_sync("mzn/sudoku.mzn",
      %{"S": 3, start: sudoku_array}, [])
  end


  ## Handle no more than 3 solutions, print the final one.
  defp solution_handler(:solution,
        results_rec(
          status: status,
          solution_count: count,
          solution_data: data
        ) = _results
      ) when status in [:satisfied, :all_solutions] and
            count <= 3
    do
        print_solution(data, count)
        if count == 3, do: :stop
  end

  defp solution_handler(:final,
        results_rec(
          solver_stats: stats
        ) = _results
      )
    do
      Logger.info "Solver stats:\n #{inspect stats}"
  end


  defp solution_handler(_event, _solution) do
    :noop
  end

  defp sudoku_string_to_grid(sudoku_str) do
    str0 = String.replace(sudoku_str, ".", "0")
    for i <- 1..9, do: for j <- 1..9, do: String.to_integer(String.at(str0, (i-1)*9 + (j-1)))
  end

  def print_solution(data, count) do
    Logger.info "Sudoku solved!"
    Logger.info "Last solution: #{print_grid(data["puzzle"])}"
    #Logger.info "Grid: #{data["puzzle"]}"
    Logger.info "Solutions found: #{count}"
  end

  def print_grid(grid) do
    gridline = "+-------+-------+-------+\n"
    gridcol = "| "

    ["\n" |
    for i <- 0..8 do
      [(if rem(i, 3) == 0, do: gridline, else: "")] ++
      (for j <- 0..8 do
        "#{if rem(j, 3) == 0, do: gridcol, else: ""}" <>
        "#{print_cell(Enum.at(Enum.at(grid, i), j))} "
      end) ++ ["#{gridcol}\n"]
    end
    ] ++ [gridline]
  end

  defp print_cell(0) do
    "."
  end

  defp print_cell(cell) do
    cell
  end

  def sudoku_samples() do
    [
      @sample_sudoku_1_solution,
      @sample_sudoku_5_solutions
    ]
  end

end
