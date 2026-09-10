%% Development-only scheduler. Job descriptions and geometry live in Gleam.
-module(gallery_jobs).
-export([run/2, traced_arrangement/0]).

run(Jobs, Directory) ->
    Names = [N || {N, _, _} <- Jobs],
    true = length(Names) =:= length(lists:usort(Names)),
    true = Jobs =/= [],
    ok = filelib:ensure_dir(filename:join(Directory, <<"README.md">>)),
    ok = file:write_file(filename:join(Directory, <<"timings.tsv">>),
                        "filename\tstatus\telapsed_ms\treductions\n"),
    ok = file:write_file(filename:join(Directory, <<"README.md">>),
                        "# Generated Gallery Figures\n\nGeneration in progress; see timings.tsv and runner output.\n"),
    Parent = self(),
    Pending = lists:foldl(fun({Name, Title, Generate}, Acc) ->
        Start = erlang:monotonic_time(millisecond),
        {Pid, Ref} = spawn_monitor(fun() ->
            {reductions, Before} = process_info(self(), reductions),
            Outcome = try
                Svg = Generate(),
                true = is_binary(Svg) andalso byte_size(Svg) > 0,
                ok = file:write_file(filename:join(Directory, Name), Svg),
                ok
            catch Class:Reason:Stack -> {error, Class, Reason, Stack} end,
            {reductions, After} = process_info(self(), reductions),
            Parent ! {gallery_done, self(), Outcome,
                      erlang:monotonic_time(millisecond) - Start, After - Before}
        end),
        io:format("START ~s pid=~p~n", [Name, Pid]),
        maps:put(Pid, {Ref, Name, Title, Start}, Acc)
    end, #{}, Jobs),
    collect(Pending, [], Directory, Jobs).

collect(Pending, Results, Directory, Jobs) when map_size(Pending) =:= 0 ->
    Failed = length([bad || {_, _, Status, _, _} <- Results, Status =/= ok]),
    io:format("Gallery: ~p succeeded, ~p failed.~n", [length(Results)-Failed, Failed]),
    %% Registry order, independent of completion order. Failed stale SVGs are
    %% deliberately not linked; the per-run status file remains authoritative.
    Entries = [io_lib:format("- [~s](~s)~n", [Title, Name]) ||
        {Name, Title, _} <- Jobs,
        lists:any(fun({N, _, S, _, _}) -> N =:= Name andalso S =:= ok end, Results)],
    ok = file:write_file(filename:join(Directory, <<"README.md">>),
                        ["# Generated Gallery Figures\n\n", Entries]),
    Failed =:= 0;
collect(Pending, Results, Directory, Jobs) ->
    receive
        {gallery_done, Pid, Outcome, Millis, Reductions} ->
            {Ref, Name, Title, _} = maps:get(Pid, Pending),
            erlang:demonitor(Ref, [flush]),
            finish(Pid, Name, Title, Outcome, Millis, Reductions,
                   Pending, Results, Directory, Jobs);
        {'DOWN', Ref, process, Pid, Reason} ->
            {Ref, Name, Title, Start} = maps:get(Pid, Pending),
            finish(Pid, Name, Title, {error, exit, Reason, []},
                   erlang:monotonic_time(millisecond)-Start, 0,
                   Pending, Results, Directory, Jobs)
    after 10000 ->
        Now = erlang:monotonic_time(millisecond),
        lists:foreach(fun({Pid, {_, Name, _, Start}}) ->
            Work = case process_info(Pid, reductions) of
                {reductions, N} -> N;
                undefined -> finished
            end,
            io:format("RUNNING ~s elapsed=~.2fs reductions=~p pid=~p~n",
                      [Name, (Now-Start)/1000, Work, Pid])
        end, lists:sort(maps:to_list(Pending))),
        collect(Pending, Results, Directory, Jobs)
    end.

finish(Pid, Name, Title, Outcome, Millis, Reductions, Pending, Results, Directory, Jobs) ->
    Status = case Outcome of
        ok ->
            io:format("DONE ~s elapsed=~.2fs reductions=~p~n", [Name, Millis/1000, Reductions]),
            ok;
        _ ->
            ErrorFile = filename:join(Directory, <<Name/binary, ".error.txt">>),
            ok = file:write_file(ErrorFile, io_lib:format("~p~n", [Outcome])),
            io:format("FAILED ~s elapsed=~.2fs reductions=~p error=~P (see ~s)~n",
                      [Name, Millis/1000, Reductions, Outcome, 8, ErrorFile]),
            failed
    end,
    Next = [{Name, Title, Status, Millis, Reductions}|Results],
    ok = file:write_file(filename:join(Directory, <<"timings.tsv">>),
        ["filename\tstatus\telapsed_ms\treductions\n",
         [io_lib:format("~s\t~p\t~p\t~p~n", [N,S,T,R]) || {N,_,S,T,R} <- lists:reverse(Next)]]),
    collect(maps:remove(Pid, Pending), Next, Directory, Jobs).

traced_arrangement() ->
    %% This existing tracer needs its own VM so trace patterns cannot affect
    %% other figures. Its CPU work is not included in the wrapper's reductions.
    Escript = os:find_executable("escript"),
    Port = open_port({spawn_executable, Escript},
                     [binary, exit_status, stderr_to_stdout, use_stdio,
                      {args, ["scripts/gallery/package_title_arrangement.escript"]}]),
    Log = port_output(Port, []),
    ok = file:write_file("test/generated/gallery/package-title-arrangement.log", Log),
    {ok, Svg} = file:read_file("test/generated/gallery/gallery-package-title-second-offset-arrangement.svg"),
    Svg.

port_output(Port, Acc) ->
    receive
        {Port, {data, Data}} -> port_output(Port, [Data|Acc]);
        {Port, {exit_status, 0}} -> lists:reverse(Acc);
        {Port, {exit_status, Code}} -> error({arrangement_generator_failed, Code, lists:reverse(Acc)})
    end.
