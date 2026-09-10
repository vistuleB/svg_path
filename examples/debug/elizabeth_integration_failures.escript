#!/usr/bin/env escript
%% Trace the actual production helper calls without changing solver behavior.
-mode(compile).
main(_) ->
    code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
    M='svg_path@intersections',F="build/dev/erlang/svg_path/_gleam_artefacts/svg_path@intersections.erl",
    {ok,M,Bin}=compile:file(F,[binary,export_all]),{module,M}=code:load_binary(M,F,Bin),
    P=fun(X,Y)->{point,X,Y} end,
    A={cubic_bezier,P(2.8150000000000004,2.8350002),P(2.8150000000000004,2.893157324236443),P(2.8236048558813205,2.9152343073348637),P(2.8236048558813205,2.9152343073348637)},
    B={cubic_bezier,P(2.8236048558813205,2.9152343073348637),P(2.823382761239994,2.914671758602366),P(2.816706698732441,2.9041808032333547),P(2.8162911593757998,2.903741355683332)},
    C={quadratic_bezier,P(0.0,0.1369),P(0.5,-0.2331),P(1.0,0.3969)},
    D={quadratic_bezier,P(-0.26,-0.3969),P(0.24,0.2331),P(0.74,-0.1369)},
    E={cubic_bezier,P(0.0,-0.125),P(1.0/3,0.125),P(2.0/3,-0.125),P(1.0,0.125)},
    G={cubic_bezier,P(0.0,0.125),P(1.0/3,-0.125),P(2.0/3,0.125),P(1.0,-0.125)},
    lists:foreach(fun({Name,L,R,Depth})->
      io:format("~n~s~n",[Name]),
      Collector=spawn(fun()->collect([],[]) end),
      lists:foreach(fun({N,Arity})->erlang:trace_pattern({M,N,Arity},[{'_',[],[{return_trace}]}],[local]) end,
        [{window_bounds_overlap,5},{elizabeth_beam_select,5},{elizabeth_finish_candidates,3},{elizabeth_select_candidates,3}]),
      erlang:trace(self(),true,[call,{tracer,Collector}]),
      Result=M:elizabeth_beam_intersections(L,R,{intersection_options,1.0e-9,Depth,no_parameter_snap}),
      erlang:trace(self(),false,[call]),Ref=erlang:trace_delivered(self()),receive {trace_delivered,_,Ref}->ok end,
      Collector!{get,self()},Events=receive {data,X}->X end,
      lists:foreach(fun(Event)->io:format("~w~n",[Event]) end,Events),
      io:format("beam: ~w~n",[Result]),
      io:format("old production: ~w~n",[M:edward_then_henry_intersections(L,R,{intersection_options,1.0e-9,Depth,no_parameter_snap})])
    end,[{"shared endpoint",A,B,64},{"off-center kiss",C,D,48},{"flat cubic pair",E,G,48}]).
endpoint({window_preserving_window,_,B,C,_})->B=:=1.0 andalso C==0.0.
has_endpoint(Items)->lists:any(fun({W,_})->endpoint(W) end,Items).
summary(Hits)->{length(Hits),[{T,U}||{segment_intersection,T,U,_}<-Hits]}.
collect(Stack,Events)->receive
  {trace,_,call,{'svg_path@intersections',window_bounds_overlap,[_,_,W,_,_]}}->collect([{bounds,W}|Stack],Events);
  {trace,_,return_from,{'svg_path@intersections',window_bounds_overlap,5},R}->
    [{bounds,W}|Rest]=Stack,collect(Rest,case endpoint(W) of true->[{endpoint_bounds,W,R}|Events];false->Events end);
  {trace,_,call,{'svg_path@intersections',elizabeth_beam_select,[_,_,Ws,_,_]}}->collect([{selection,length(Ws),has_endpoint(Ws)}|Stack],Events);
  {trace,_,return_from,{'svg_path@intersections',elizabeth_beam_select,5},{ok,{Kept,DC,DO,_}}}->
    [{selection,N,Has}|Rest]=Stack,collect(Rest,[{beam_selection,N,length(Kept),DC,DO,Has,has_endpoint(Kept)}|Events]);
  {trace,_,call,{'svg_path@intersections',elizabeth_finish_candidates,[_,_,Hs]}}->collect(Stack,[{raw_candidates,length(Hs),lists:any(fun({segment_intersection,T,U,_})->T=:=1.0 andalso U==0.0 end,Hs)}|Events]);
  {trace,_,return_from,{'svg_path@intersections',elizabeth_finish_candidates,3},{ok,Hs}}->collect(Stack,[{deduplicated,summary(Hs)}|Events]);
  {trace,_,return_from,{'svg_path@intersections',elizabeth_select_candidates,3},{ok,Hs}}->collect(Stack,[{selected,summary(Hs)}|Events]);
  {get,P}->P!{data,lists:reverse(Events)};
  _->collect(Stack,Events)
end.
