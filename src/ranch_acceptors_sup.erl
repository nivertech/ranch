%% Copyright (c) 2011-2012, Loïc Hoguin <essen@ninenines.eu>
%%
%% Permission to use, copy, modify, and/or distribute this software for any
%% purpose with or without fee is hereby granted, provided that the above
%% copyright notice and this permission notice appear in all copies.
%%
%% THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
%% WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
%% MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
%% ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
%% WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
%% ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
%% OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

%% @private
-module(ranch_acceptors_sup).
-behaviour(supervisor).

%% API.
-export([start_link/7]).

%% supervisor.
-export([init/1]).

%% API.

-spec start_link(any(), non_neg_integer(), module(), any(),
	module(), pid(), pid()) -> {ok, pid()}.
start_link(Ref, NbAcceptors, Transport, TransOpts,
		Protocol, ListenerPid, ConnsPid) ->
	supervisor:start_link(?MODULE, [Ref, NbAcceptors, Transport, TransOpts,
		Protocol, ListenerPid, ConnsPid]).

%% supervisor.

init([Ref, NbAcceptors, Transport, TransOpts,
		Protocol, ListenerPid, ConnsPid]) ->
	{ok, LSocket} = Transport:listen(TransOpts),
    MaxConns = proplists:get_value(max_connections, TransOpts, 1024),
    MaxConnPerPeriod = proplists:get_value(max_connections_per_period, TransOpts, 0),
    ConnPeriodMilliSec = proplists:get_value(connection_period_ms, TransOpts, 0),
	{ok, {_, Port}} = Transport:sockname(LSocket),
	ranch_listener:set_port(ListenerPid, Port),
	Procs = [
		{{acceptor, self(), N}, {ranch_acceptor, start_link, [
			Ref, LSocket, Transport, Protocol, 
            MaxConns, int_ceil(MaxConnPerPeriod / NbAcceptors), ConnPeriodMilliSec,
            ListenerPid, ConnsPid
		]}, permanent, brutal_kill, worker, []}
			|| N <- lists:seq(1, NbAcceptors)],
	{ok, {{one_for_one, 10, 10}, Procs}}.


-spec int_ceil(X::number()) -> integer(). 
int_ceil(X) when is_integer(X) -> X;
int_ceil(X) ->
    T = trunc(X),
    if X > T -> T + 1;
       true  -> T
    end.
