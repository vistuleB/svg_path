#!/usr/bin/env escript
%% Trace actual solver calls; replay only scalar diagnostics, not search logic.
-mode(compile).
main(_) ->
    code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
    M='svg_path@intersections',F="build/dev/erlang/svg_path/_gleam_artefacts/svg_path@intersections.erl",
    {ok,M,Bin}=compile:file(F,[binary,export_all]),{module,M}=code:load_binary(M,F,Bin),
    P=fun(X,Y)->{point,X+100.0,Y+100.0} end,
    D=-0.2*0.21*0.22,C=0.2*0.21+0.2*0.22+0.21*0.22,B=-0.63,
    A={cubic_bezier,P(0.0,D),P(1.0/3,D+C/3),P(2.0/3,D+2*C/3+B/3),P(1.0,D+C+B+1)},
    Q={quadratic_bezier,P(0.0,0.0),P(0.5,0.0),P(1.0,0.0)},
    Collector=spawn(fun()->collect([]) end),
    erlang:trace_pattern({M,elizabeth_terminal_alternating,9},true,[local]),
    erlang:trace(self(),true,[call,{tracer,Collector}]),
    R=M:experimental_curve_intersections(A,Q,elizabeth,{intersection_options,1.0e-14,48,no_parameter_snap},10000),
    erlang:trace(self(),false,[call]),
    Ref=erlang:trace_delivered(self()),receive {trace_delivered,_,Ref}->ok end,
    Collector!{get,self()},
    Steps=receive {data,Ss}->Ss end,
    Target={window_preserving_window,0.21999999914821233,0.22000000011615287,0.21999999914821233,0.22000000011615287},
    Relevant=[Args||Args=[_,_,W,_,_,_,_,_,_]<-Steps,W=:=Target],
    io:format("Result: ~p~n",[R]),
    lists:foreach(fun(Args)->io:format("Step: ~p~n",[diagnose(Args)]) end,Relevant),
    Seeds=[Args||Args=[_,_,_,_,_,none,false,_,8]<-Relevant],
    io:format("64-step retries: ~p~n",[[M:elizabeth_terminal_alternating(SA,SB,W,T,U,none,false,Tol,64)||[SA,SB,W,T,U,_,_,Tol,_]<-Seeds]]).
collect(Steps)->receive
  {trace,_,call,{'svg_path@intersections',elizabeth_terminal_alternating,Args}}->collect([Args|Steps]);
  {get,P}->P!{data,lists:reverse(Steps)};
  _->collect(Steps)
end.
diagnose([A,B,_,T,U,Prev,Chord,_,N])->
    {ok,P}=svg_path:segment_point(A,T),{ok,Q}=svg_path:segment_point(B,U),
    Kind=case {Prev,Chord} of
      {{some,{OldT,OldU}},true} when OldT=/=T,OldU=/=U->
        {ok,OldP}=svg_path:segment_point(A,OldT),{ok,OldQ}=svg_path:segment_point(B,OldU),
        V=sub(P,OldP),W=sub(Q,OldQ),
        case 'svg_path@intersections':directions_are_independent(V,W) of
          true->chord;false->{fallback_parallel_or_zero,V,W} end;
      {_,true}->fallback_unchanged_parameter;
      _->newton end,
    {Kind,T,U,Prev,sub(Q,P),N}.
sub({point,X,Y},{point,V,W})->{point,X-V,Y-W}.
