# Solverl

Erlang/Elixir interface to [Minizinc](https://www.minizinc.org).

## Installation

Installation of [Minizinc](https://www.minizinc.org) is required on your system. Please refer to https://www.minizinc.org/software.html for details.

The package can be installed by adding `solverl` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:solverl, "~> 0.1.0"}
  ]
end
```

The docs can be found at [https://hexdocs.pm/solverl](https://hexdocs.pm/solverl).

## N-Queens example

   The following code uses Minizinc model `mzn/nqueens.mzn` to solve [N-queens](https://developers.google.com/optimization/cp/queens) puzzle for N = 4:
   
   ```elixir
    MinizincSolver.solve("mzn/nqueens.mzn", %{n: 4}, [solution_handler: &NQueens.solution_handler/2])
   ```
   Output: 
   ``` 
   iex(4)> 
   23:30:21.094 [warn]  Command: /Applications/MiniZincIDE.app/Contents/Resources/minizinc --allow-multiple-assignments --output-mode json --output-time --output-objective --output-output-item -s -a  --solver org.gecode.gecode --time-limit 300000 /var/folders/rn/_39sx1c12ws1x5k66n_cjjh00000gn/T/tmp.7NABDxEp.mzn /var/folders/rn/_39sx1c12ws1x5k66n_cjjh00000gn/T/tmp.JEV4UXP5.dzn
   {:ok, #PID<0.2115.0>}
   iex(73)> 
   23:30:21.216 [info]  
   . . ♕ .
   ♕ . . .
   . . . ♕
   . ♕ . .
   -----------------------
    
   23:30:21.216 [info]  
   . ♕ . .
   . . . ♕
   ♕ . . .
   . . ♕ .
   -----------------------
    
   23:30:21.221 [info]  Solution status: ALL_SOLUTIONS
    
   23:30:21.221 [info]  Solver stats:
    %{"failures" => "4", "initTime" => "0.010053", "nSolutions" => "2", "nodes" => "11", "peakDepth" => "2", "propagations" => "163", "propagators" => "11", "restarts" => "0", "solutions" => "2", "solveTime" => "0.002834", "variables" => "12"}
    
   23:30:21.221 [debug] ** TERMINATE: :normal
   ```

## Sudoku example

```elixir

## Asynchronously solve Sudoku puzzle, using the solution handler Sudoku.solution_handler/2:
## (the source code for Sudoku module is examples/sudoku.ex)

Sudoku.solve("85...24..72......9..4.........1.7..23.5...9...4...........8..7..17..........36.4.")
```
The output:
```
23:54:34.018 [info]  Sudoku puzzle:
 
23:54:34.018 [info]  
+-------+-------+-------+
| 8 5 . | . . 2 | 4 . . | 
| 7 2 . | . . . | . . 9 | 
| . . 4 | . . . | . . . | 
+-------+-------+-------+
| . . . | 1 . 7 | . . 2 | 
| 3 . 5 | . . . | 9 . . | 
| . 4 . | . . . | . . . | 
+-------+-------+-------+
| . . . | . 8 . | . 7 . | 
| . 1 7 | . . . | . . . | 
| . . . | . 3 6 | . 4 . | 
+-------+-------+-------+

 
23:54:34.067 [warn]  Command: /Applications/MiniZincIDE.app/Contents/Resources/minizinc --allow-multiple-assignments --output-mode json --output-time --output-objective --output-output-item -s -a  --solver org.gecode.gecode --time-limit 300000 /var/folders/rn/_39sx1c12ws1x5k66n_cjjh00000gn/T/tmp.ntx0ThIr.mzn /var/folders/rn/_39sx1c12ws1x5k66n_cjjh00000gn/T/tmp.yUorqedH.dzn
{:ok, #PID<0.2146.0>}
iex(79)> 
23:54:34.124 [info]  
+-------+-------+-------+
| 8 5 9 | 6 1 2 | 4 3 7 | 
| 7 2 3 | 8 5 4 | 1 6 9 | 
| 1 6 4 | 3 7 9 | 5 2 8 | 
+-------+-------+-------+
| 9 8 6 | 1 4 7 | 3 5 2 | 
| 3 7 5 | 2 6 8 | 9 1 4 | 
| 2 4 1 | 5 9 3 | 7 8 6 | 
+-------+-------+-------+
| 4 3 2 | 9 8 1 | 6 7 5 | 
| 6 1 7 | 4 2 5 | 8 9 3 | 
| 5 9 8 | 7 3 6 | 2 4 1 | 
+-------+-------+-------+

 
23:54:34.124 [info]  Solutions found: 1
 
23:54:34.129 [info]  Solver stats:
 %{"failures" => "11", "initTime" => "0.000879", "nSolutions" => "1", "nodes" => "23", "peakDepth" => "5", "propagations" => "685", "propagators" => "27", "restarts" => "0", "solutions" => "1", "solveTime" => "0.000605", "variables" => "147"}
 
23:54:34.129 [debug] ** TERMINATE: :normal
```
## Usage
```elixir
# Asynchronous solving.
# Creates a solver process. 
# Handling of solutions is done by the pluggable solution handler (explained in Configuration section). 
{:ok, solver_pid} = Minizinc.solve(model, data, opts)

# Synchronous solving.
# Starts the solver and gets the results (solutions and/or solver stats) once the solver finishes.
# The solution handler can customize the results, such as format/filter/limit the number of solutions, conditionally interrupt solver process etc.
solver_results = Minizinc.solve_sync(model, data, opts)

```
, where 
```model``` is a specification of the Minizinc model,
```data``` - specification of data passed to ```model```,
```opts``` - various solver options, such as ```solver id```, ```time limit```, ```compilation flags```, ```solution handler```.

## Solver options
```
  TODO
```  
## Solution handlers
```
  TODO
```

## Roadmap
TODO:
```
  Support LNS
  Support Branch-and-Bound
```  
