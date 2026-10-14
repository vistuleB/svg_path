#!/usr/bin/env escript
-mode(compile).
main([Output]) ->
 code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
 Files=lists:sort(filelib:wildcard("test/*.gleam")),
 Tests=lists:append([begin M=list_to_atom(filename:basename(P,".gleam")),
  [{M,F} || {F,0} <- M:module_info(exports), lists:suffix("_test",atom_to_list(F))]
 end || P <- Files]),
 {ok,Out}=file:open(Output,[write]),
 io:format(Out,"module\tfunction\trun\tmicroseconds\treductions\tstatus~n",[]),
 lists:foreach(fun(Run) -> lists:foreach(fun({M,F}) ->
  Parent=self(), {Pid,Ref}=spawn_monitor(fun() ->
   {reductions,R0}=process_info(self(),reductions), T0=erlang:monotonic_time(microsecond),
   Status=try apply(M,F,[]) of _ -> ok catch C:E:S -> {failed,C,E,S} end,
   Elapsed=erlang:monotonic_time(microsecond)-T0,
   {reductions,R1}=process_info(self(),reductions),
   Parent ! {self(),Elapsed,R1-R0,Status}
  end),
  receive
   {Pid,Elapsed,Reductions,Status} ->
    receive {'DOWN',Ref,process,Pid,_}->ok end,
    io:format(Out,"~s\t~s\t~B\t~B\t~B\t~p~n",[M,F,Run,Elapsed,Reductions,Status]);
   {'DOWN',Ref,process,Pid,Reason} -> io:format("CRASH ~p ~p ~p~n",[M,F,Reason]),halt(1)
  after 180000 -> io:format("TIMEOUT ~p ~p~n",[M,F]),halt(1)
  end
 end,Tests),io:format("Completed run ~B: ~B tests~n",[Run,length(Tests)]) end,lists:seq(1,3)),
 file:close(Out).
