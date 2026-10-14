#!/usr/bin/env escript
-mode(compile).
main([Module,Function,Repeats,Output]) ->
 code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
 erlang:system_flag(backtrace_depth,64),
 M=list_to_atom(Module),F=list_to_atom(Function),N=list_to_integer(Repeats),
 Parent=self(),Start=erlang:monotonic_time(millisecond),
 Pid=spawn(fun()-> lists:foreach(fun(_)->apply(M,F,[]) end,lists:seq(1,N)),Parent!done end),
 {Count,Leaf,Stack}=sample(Pid,0,#{},#{}),
 {ok,Out}=file:open(Output,[write]),
 io:format(Out,"samples ~p elapsed_ms ~p~n",[Count,erlang:monotonic_time(millisecond)-Start]),
 lists:foreach(fun({Label,Map})->io:format(Out,"~s~n",[Label]),
  lists:foreach(fun({Key,C})->io:format(Out,"~p\t~s~n",[C,Key]) end,lists:sort(fun({_,A},{_,B})->A>B end,maps:to_list(Map))) end,[{"LEAF",Leaf},{"STACK",Stack}]),file:close(Out).
key({M,F,A,_})->lists:flatten(io_lib:format("~s:~s/~p",[M,F,A])).
inc(K,M)->maps:update_with(K,fun(N)->N+1 end,1,M).
sample(Pid,N,Leaf,Stack)->
 receive done->{N,Leaf,Stack}
 after 1 -> case process_info(Pid,current_stacktrace) of
  {current_stacktrace,[H|T]} -> sample(Pid,N+1,inc(key(H),Leaf),lists:foldl(fun inc/2,Stack,lists:usort([key(X)||X<-[H|T]])));
  _ -> sample(Pid,N,Leaf,Stack)
 end end.
