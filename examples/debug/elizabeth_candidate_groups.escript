#!/usr/bin/env escript
%% Inspect returned candidates; do not alter the solver or deduplicate again.
-mode(compile).
main(_) ->
    code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
    P=fun(X,Y)->{point,X,Y} end,
    A={cubic_bezier,P(0.0,-0.125),P(1.0/3,0.125),P(2.0/3,-0.125),P(1.0,0.125)},
    B={quadratic_bezier,P(0.0,0.0),P(0.5,0.0),P(1.0,0.0)},
    {ok,[{Join,Line,_}]}=file:consult("examples/debug/join_line_missing_endpoint.term"),
    lists:foreach(fun({Name,L,R})->inspect(Name,L,R) end,
      [{"flat cubic",A,B},{"join / line",Join,Line}]).
inspect(Name,A,B)->
    {ok,{elizabeth_beam_report,Hits,E,DC,DO,Peak,LostCandidates}}=
      'svg_path@intersections':elizabeth_beam_intersections(A,B,{intersection_options,5.0e-14,48,no_parameter_snap}),
    io:format("~n~s: ~w candidates; examined ~w; discarded ~w/~w; peak ~w; candidates discarded ~w~n",[Name,length(Hits),E,DC,DO,Peak,LostCandidates]),
    Rows=[begin
      {ok,{point,X,Y}}=svg_path:segment_point(A,T),
      {ok,{point,V,W}}=svg_path:segment_point(B,U),
      {T,U,math:sqrt((X-V)*(X-V)+(Y-W)*(Y-W)),X,Y}
    end||{segment_intersection,T,U,_}<-Hits],
    io:format("t | u | residual | source x | source y | Chebyshev gap from previous~n"),
    lists:foldl(fun(Row,Prev)->io:format("~w | gap ~w~n",[Row,case Prev of none->none;_->gap(Row,Prev) end]),Row end,none,Rows),
    io:format("spans t/u/x/y: ~w~n",[[span(I,Rows)||I<-[1,2,4,5]]]),
    io:format("five lowest residuals: ~w~n",[lists:sublist(lists:sort(fun(X,Y)->element(3,X)<element(3,Y) end,Rows),5)]),
    lists:foreach(fun(D)->
      Groups=components(Rows,D),
      io:format("single-link threshold ~w: sizes ~w; t/u spans ~w~n",[D,[length(G)||G<-Groups],[[span(1,G),span(2,G)]||G<-Groups]])
    end,[1.0e-7,2.0e-7,5.0e-7,1.0e-6,2.0e-6,5.0e-6,1.0e-5,2.0e-5,5.0e-5,2.0e-4]),
    io:format("ordinary solver at 1e-9 (independent route for Line): ~w~n",['svg_path@intersections':segment_with(A,B,{intersection_options,1.0e-9,48,no_parameter_snap})]).
span(I,Rows)->Vs=[element(I,R)||R<-Rows],{lists:min(Vs),lists:max(Vs),lists:max(Vs)-lists:min(Vs)}.
gap(A,B)->max(abs(element(1,A)-element(1,B)),abs(element(2,A)-element(2,B))).
components([],_) -> [];
components([X|Xs],D)->{G,Rest}=grow([X],Xs,D),[G|components(Rest,D)].
grow(G,Rest,D)->
    {Near,Far}=lists:partition(fun(R)->lists:any(fun(Q)->gap(R,Q)=<D end,G) end,Rest),
    case Near of []->{G,Far};_->grow(G++Near,Far,D) end.
