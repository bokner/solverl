%%%-------------------------------------------------------------------
%%% @author bokner
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 28. Jul 2020 16:55
%%%-------------------------------------------------------------------
-module(minizinc).
-author("bokner").

-define(MINIZINC, 'Elixir.MinizincSolver').

%% API
-export([solve/1, solve/2, solve/3, solve/4]).
-export([solve_sync/1, solve_sync/2, solve_sync/3, solve_sync/4]).
-export([get_solvers/0, get_solverids/0, lookup/1]).
-export([stop_solver/1, solver_status/1]).

% Asynch solving
solve(Model) ->
    solve(Model, [], []).

solve(Model, Data) ->
    solve(Model, Data, []).

solve(Model, Data, SolverOpts) ->
    ?MINIZINC:solve(Model, Data, SolverOpts).

solve(Model, Data, SolverOpts, ServerOpts) ->
    ?MINIZINC:solve(Model, Data, SolverOpts, ServerOpts).

% Sync solving
solve_sync(Model) ->
    solve_sync(Model, [], []).

solve_sync(Model, Data) ->
    solve_sync(Model, Data, []).

solve_sync(Model, Data, SolverOpts) ->
    ?MINIZINC:solve_sync(Model, Data, SolverOpts).

solve_sync(Model, Data, SolverOpts, ServerOpts) ->
    ?MINIZINC:solve_sync(Model, Data, SolverOpts, ServerOpts).

stop_solver(Pid) ->
    ?MINIZINC:stop_solver(Pid).

solver_status(Pid) ->
    ?MINIZINC:solver_status(Pid).

get_solvers() ->
    ?MINIZINC:get_solvers().

get_solverids() ->
    ?MINIZINC:get_solverids().

lookup(SolverId) when is_binary(SolverId) ->
    ?MINIZINC:lookup(SolverId).


