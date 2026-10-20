#!/usr/bin/env escript
-mode(compile).
main(Args) ->
 code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
 case Args of [Override] -> code:add_patha(Override); [] -> ok end,
 {ok, Svg}=file:read_file("examples/debug/package_title.svg"),
 [_,Tail|_]=binary:split(Svg, <<" d=\"">>, [global]),
 [Data|_]=binary:split(Tail, <<"\"">>, [global]),
 {ok, Path}='svg_path@parse':path(Data),
 run(Path,1).
run(_,10)->ok;
run(Path,N)->
 Start=erlang:monotonic_time(millisecond),
 Result='svg_path@offset':path_with(Path,1.04,{miter,4.0},butt,'svg_path@offset':default_options(),'svg_path@offset':default_single_offset_trimming()),
 io:format("level=~p elapsed_ms=~p result=~p~n",[N,erlang:monotonic_time(millisecond)-Start,case Result of {ok,_}->ok; E->E end]),
 case Result of {ok,Next}->run(Next,N+1);_->halt(1) end.
