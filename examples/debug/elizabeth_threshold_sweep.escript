#!/usr/bin/env escript
%% Read-only experiments: options.tolerance controls Elizabeth's residual cap.
-mode(compile).
main(Args) ->
    code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
    Resolution=case lists:member("fine",Args) of true->1.0e-11;false->1.0e-9 end,
    Newton=not lists:member("no_newton",Args),
    Alternating=not lists:member("newton_only",Args),
    Beam=lists:member("beam",Args),
    Thresholds=case Beam of true->[5.0e-14]; false->case lists:member("compare",Args) of
      true->[1.0e-13,5.0e-14];
      false->[1.0e-12,1.0e-13,1.0e-14,1.0e-15,1.0e-16] end end,
    instrument(Resolution,Newton,Alternating),
    M=svg_path_intersections_test,
    F="build/dev/erlang/svg_path/_gleam_artefacts/svg_path_intersections_test.erl",
    {ok,M,Binary}=compile:file(F,[binary,export_all]),
    {module,M}=code:load_binary(M,F,Binary),
    {ArcA,ArcB}=M:arc_pair(),
    CA=lists:last(svg_path:segment_arcs_to_cubic_beziers(ArcA)),
    [CB|_]=svg_path:segment_arcs_to_cubic_beziers(ArcB),
    {ok,ArcHits}='svg_path@intersections':segment(ArcA,ArcB),
    {ok,CubicHits}='svg_path@intersections':segment(CA,CB),
    P=fun(X,Y)->{point,X,Y} end,
    Flat={quadratic_bezier,P(0.0,0.0),P(0.5,0.0),P(1.0,0.0)},
    D=-0.2*0.21*0.22,C=0.2*0.21+0.2*0.22+0.21*0.22,B=-0.63,
    Cluster={cubic_bezier,P(0.0,D),P(1.0/3,D+C/3),P(2.0/3,D+2*C/3+B/3),P(1.0,D+C+B+1)},
    Kiss={quadratic_bezier,P(0.0,0.25),P(0.5,-0.25),P(1.0,0.25)},
    OffA={quadratic_bezier,P(0.0,0.1369),P(0.5,-0.2331),P(1.0,0.3969)},
    OffB={quadratic_bezier,P(-0.26,-0.3969),P(0.24,0.2331),P(0.74,-0.1369)},
    Close={quadratic_bezier,P(0.0,0.24999999),P(0.5,-0.25000001),P(1.0,0.24999999)},
    FlatCubic={cubic_bezier,P(0.0,-0.125),P(1.0/3,0.125),P(2.0/3,-0.125),P(1.0,0.125)},
    {ok,[{Join,Line,_}]}=file:consult("examples/debug/join_line_missing_endpoint.term"),
    {ok,JoinHits}='svg_path@intersections':segment_with(Join,Line,{intersection_options,1.0e-9,48,no_parameter_snap}),
    Cases=[{"cluster",Cluster,Flat,[{0.2,0.2},{0.21,0.21},{0.22,0.22}]},
      {"cluster translated",move(Cluster,100.0,100.0),move(Flat,100.0,100.0),[{0.2,0.2},{0.21,0.21},{0.22,0.22}]},
      {"center kiss",Kiss,Flat,[{0.5,0.5}]},
      {"off-center kiss",OffA,OffB,[{0.37,0.63}]},
      {"two close crossings",Close,Flat,[{0.4999,0.4999},{0.5001,0.5001}]},
      {"flat cubic",FlatCubic,Flat,[{0.5,0.5}]},
      {"loop8 arcs",ArcA,ArcB,addresses(ArcHits)},
      {"loop8 cubics",CA,CB,addresses(CubicHits)},
      {"join and endpoint",Join,Line,addresses(JoinHits)}],
    io:format("resolution=~p; Newton=~p; alternating=~p; beam=~p; DFS budget=100000; beam live cap=1000; coverage radius=1e-5 in both parameters~n",[Resolution,Newton,Alternating,Beam]),
    io:format("case | residual | candidates | expected-neighborhoods-hit | max-residual | milliseconds | windows~n"),
    lists:foreach(fun({Label,A,Q,Expected})->
      lists:foreach(fun(Tol)->
        {Time,R}=timer:tc(fun()->case Beam of
          false->'svg_path@intersections':experimental_curve_intersections(
            A,Q,elizabeth,{intersection_options,Tol,48,no_parameter_snap},100000);
          true->case 'svg_path@intersections':elizabeth_beam_intersections(A,Q,{intersection_options,Tol,48,no_parameter_snap}) of
            {ok,{elizabeth_beam_report,H,E,DC,DO,Peak,LostCandidates}}->
              put(elizabeth_examined,E),put(beam_stats,{DC,DO,Peak,LostCandidates}),{ok,H};
            Err->Err end end end),
        case Beam of true->io:format("beam discarded crossing/other, peak retained, discarded candidates: ~p~n",[get(beam_stats)]);false->ok end,
        case R of
          {ok,Hits}->
            Covered=length([E||E<-Expected,lists:any(fun(H)->near(E,H) end,Hits)]),
            Max=lists:foldl(fun({segment_intersection,T,U,_},Acc)->
              {ok,{point,X,Y}}=svg_path:segment_point(A,T),
              {ok,{point,V,W}}=svg_path:segment_point(Q,U),
              max(Acc,math:sqrt((X-V)*(X-V)+(Y-W)*(Y-W))) end,0.0,Hits),
            io:format("~s | ~p | ~p | ~p/~p | ~p | ~p | ~p~n",[Label,Tol,length(Hits),Covered,length(Expected),Max,Time div 1000,get(elizabeth_examined)]);
          Error->io:format("~s | ~p | ~p | ~pms | ~p~n",[Label,Tol,Error,Time div 1000,get(elizabeth_examined)])
        end
      end,Thresholds)
    end,Cases),
    lists:foreach(fun({Label,A,Q,_})->
      case 'svg_path@intersections':experimental_curve_intersections(A,Q,elizabeth,{intersection_options,1.0e-12,48,no_parameter_snap},100000) of
        {ok,Hits}->
          Refined=['svg_path@intersections':window_preserving_refine_tangent_crossing(A,Q,T,U,1.0e-16,20)||{segment_intersection,T,U,_}<-Hits],
          io:format("Newton from 1e-12 candidates, ~s: ~p~n",[Label,Refined]);
        _->ok
      end
    end,[Case||Case={Name,_,_,_}<-Cases,lists:member(Name,["cluster translated","loop8 arcs","loop8 cubics"])]).

addresses(Hits)->[{T,U}||{segment_intersection,T,U,_}<-Hits].
near({A,B},{segment_intersection,T,U,_})->abs(A-T)=<1.0e-5 andalso abs(B-U)=<1.0e-5.
move({point,X,Y},Dx,Dy)->{point,X+Dx,Y+Dy};
move(S,Dx,Dy)->list_to_tuple([case V of {point,_,_}->move(V,Dx,Dy);_->V end||V<-tuple_to_list(S)]).

%% Change only this VM's compiled helper: add a counter and optionally tighten
%% the two terminal width comparisons. No source/build files are modified.
instrument(Resolution,Newton,Alternating)->
    F="build/dev/erlang/svg_path/_gleam_artefacts/svg_path@intersections.erl",
    {ok,Forms}=epp:parse_file(F,[],[]),
    Patched=[case Form of
      {function,L,elizabeth_search,7,Clauses}->
        {function,L,elizabeth_search,7,[begin
          {clause,CL,Ps,Gs,Body}=C,
          Count={call,CL,{remote,CL,{atom,CL,erlang},{atom,CL,put}},[{atom,CL,elizabeth_examined},{var,CL,'Examined'}]},
          {clause,CL,Ps,Gs,[Count|rewrite(Body,Resolution)]}
        end||C<-Clauses]};
      {function,L,elizabeth_terminal_alternating,Arity,_} when not Alternating->
        %% Disable only this VM's experimental alternating retry. The normal
        %% eight-step Newton attempt and all terminal seeds remain unchanged.
        {function,L,elizabeth_terminal_alternating,Arity,
          [{clause,L,lists:duplicate(Arity,{var,L,'_'}),[],
            [{tuple,L,[{atom,L,ok},{atom,L,none}]}]}]};
      {function,_,elizabeth_terminal_candidates,_,_} when not Newton->without_newton(Form);
      _->Form end||Form<-Forms],
    {ok,M,B}=compile:forms(Patched,[binary,export_all,report_errors]),
    {module,M}=code:load_binary(M,F,B).
rewrite({float,L,V},R) when V=:=1.0e-9->{float,L,R};
rewrite(T,R) when is_tuple(T)->list_to_tuple([rewrite(V,R)||V<-tuple_to_list(T)]);
rewrite(T,R) when is_list(T)->[rewrite(V,R)||V<-T];
rewrite(T,_)->T.

without_newton({integer,L,8})->{integer,L,0};
without_newton(T) when is_tuple(T)->list_to_tuple([without_newton(V)||V<-tuple_to_list(T)]);
without_newton(T) when is_list(T)->[without_newton(V)||V<-T];
without_newton(T)->T.
