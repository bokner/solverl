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
-export([solve/1, solve/2, solve/3]).
-export([solve_sync/1, solve_sync/2, solve_sync/3]).
-export([stop_solver/1, get_solvers/0, get_solverids/0, lookup/1, get_executable/0]).

% Asynch solving
solve(Model) ->
    solve(Model, [], []).

solve(Model, Data) ->
    solve(Model, Data, []).

solve(Model, Data, Opts) ->
    ?MINIZINC:solve(Model, Data, Opts).

% Sync solving
solve_sync(Model) ->
    solve_sync(Model, [], []).

solve_sync(Model, Data) ->
    solve_sync(Model, Data, []).

solve_sync(Model, Data, Opts) ->
    ?MINIZINC:solve_sync(Model, Data, Opts).


stop_solver(Pid) ->
    ?MINIZINC:stop_solver(Pid).

get_solvers() ->
    ?MINIZINC:get_solvers().

get_solverids() ->
    ?MINIZINC:get_solverids().

lookup(SolverId) when is_binary(SolverId) ->
    ?MINIZINC:lookup(SolverId).

get_executable() ->
    ?MINIZINC:get_executable().

