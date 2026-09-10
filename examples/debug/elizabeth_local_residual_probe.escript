#!/usr/bin/env escript
%% Independent local sampling: distinguishes absent representable candidates
%% from candidates simply not selected by Elizabeth. Not an exhaustive proof.
-mode(compile).
main(_) ->
    code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
    M=svg_path_intersections_test,
    F="build/dev/erlang/svg_path/_gleam_artefacts/svg_path_intersections_test.erl",
    {ok,M,Bin}=compile:file(F,[binary,export_all]),{module,M}=code:load_binary(M,F,Bin),
    P=fun(X,Y)->{point,X+100.0,Y+100.0} end,
    D=-0.2*0.21*0.22,C=0.2*0.21+0.2*0.22+0.21*0.22,B=-0.63,
    A={cubic_bezier,P(0.0,D),P(1.0/3,D+C/3),P(2.0/3,D+2*C/3+B/3),P(1.0,D+C+B+1)},
    Q={quadratic_bezier,P(0.0,0.0),P(0.5,0.0),P(1.0,0.0)},
    lists:foreach(fun(Root)->
      Samples=[{residual(A,Q,Root+I*1.0e-11,Root+I*1.0e-11),Root+I*1.0e-11}||I<-lists:seq(-1000,1000)],
      io:format("translated root ~p local minimum {residual,t}: ~p~n",[Root,lists:min(Samples)])
    end,[0.2,0.21,0.22]),
    {ArcA,ArcB}=M:arc_pair(),
    {ok,Hits}='svg_path@intersections':segment(ArcA,ArcB),
    lists:foreach(fun({segment_intersection,T,U,_})->
      Samples=[{residual(ArcA,ArcB,T+I*1.0e-15,U+J*1.0e-15),T+I*1.0e-15,U+J*1.0e-15}||I<-lists:seq(-32,32),J<-lists:seq(-32,32)],
      io:format("loop8 arc local minimum {residual,t,u}: ~p~n",[lists:min(Samples)])
    end,Hits).
residual(A,B,T,U)->
    {ok,{point,X,Y}}=svg_path:segment_point(A,T),
    {ok,{point,V,W}}=svg_path:segment_point(B,U),
    math:sqrt((X-V)*(X-V)+(Y-W)*(Y-W)).
