defmodule SudokuExample do
  @moduledoc false

  require Logger
  import MinizincUtils

  # Sudoku puzzle is a string
  # with elements of the puzzle in row-major order, where a blank entry is represented by "."
  def solve(puzzle) do
    # Turn a string into 9x9 grid
    sudoku_array = sudoku_string_to_grid(puzzle)
    Logger.info "Sudoku puzzle:"
    Logger.info print_grid(sudoku_array)
    {:ok, _pid} = MinizincPort.start_link(
      [
        model: "mzn/sudoku.mzn",
        data: %{"S": 3, start: sudoku_array},
        solver: "gecode",
        time_limit: 1000,
        solution_handler: &SudokuExample.solution_handler/2])
  end


  ## Only handle a final solution...
  def solution_handler(true,
        instance_rec(
          status: status,
          solution_count: count,
          solution_data: data
        ) = _solution
      ) when status in [:satisfied, :optimal]
    do
      print_solution(data, count)
      :ok
  end

  ## ...but stop after a 3rd solution.
  def solution_handler(false,
        instance_rec(
          status: status,
          solution_count: count,
          solution_data: data
        ) = _solution
      ) when status in [:satisfied, :optimal]
          and count == 3
    do
      print_solution(data, count)
      :stop
  end

  def solution_handler(false, _solution) do
    :noop
  end

  def sudoku_string_to_grid(sudoku_str) do
    str0 = String.replace(sudoku_str, ".", "0")
    for i <- 1..9, do: for j <- 1..9, do: String.to_integer(String.at(str0, (i-1)*9 + (j-1)))
  end

  def print_solution(data, count) do
    Logger.info "Sudoku solved!"
    Logger.info "Last solution: #{print_grid(data["puzzle"])}"
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

  def print_cell(0) do
    "."
  end

  def print_cell(cell) do
    cell
  end

end
