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

## Example

```elixir
import Sudoku
## Asynchronously solve Sudoku puzzle, using the solution handler Sudoku.solution_handler/2:
Sudoku.solve("8..6..9.5.............2.31...7318.6.24.....73...........279.1..5...8..36..3......")
```
The output:
```
20:07:05.932 [info]  Sudoku puzzle:
 
20:07:05.932 [info]  
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

 
20:07:05.996 [warn]  Command: /Applications/MiniZincIDE.app/Contents/Resources/minizinc --allow-multiple-assignments --output-mode json --output-time --output-objective --output-output-item -s -a  --solver org.gecode.gecode --time-limit 1000 /var/folders/rn/_39sx1c12ws1x5k66n_cjjh00000gn/T/tmp.sbvIAUVJ.mzn /var/folders/rn/_39sx1c12ws1x5k66n_cjjh00000gn/T/tmp.yoyn7SUQ.dzn
{:ok, #PID<0.9218.0>}
iex(14)> 
20:07:06.095 [info]  Sudoku solved!
 
20:07:06.095 [info]  Last solution: 
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

 
20:07:06.095 [info]  Solutions found: 1
 
20:07:06.101 [debug] Port exit: :exit_status: 0
 
20:07:06.101 [info]  Solver stats:
 %{"failures" => "11", "initTime" => "0.007296", "nSolutions" => "1", "nodes" => "23", "peakDepth" => "5", "propagations" => "685", "propagators" => "27", "restarts" => "0", "solutions" => "1", "solveTime" => "0.002918", "variables" => "147"}

20:07:06.101 [debug] ** TERMINATE: :normal
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

TODO:
```
  Explain solver arguments;
  Solution handler;
  Using sync/async;
```
## Roadmap
TODO:
```
  Support LNS
  Support Branch-and-Bound
```  
