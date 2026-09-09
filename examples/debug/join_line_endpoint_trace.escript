#!/usr/bin/env escript
%% Inspect the analytic arc/line path without changing production functions.
-mode(compile).
main(_) ->
    code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
    M=svg_path,F="build/dev/erlang/svg_path/_gleam_artefacts/svg_path.erl",
    {ok,M,B}=compile:file(F,[binary,export_all]),{module,M}=code:load_binary(M,F,B),
    {ok,[{Arc,{line,Start,End},_}]}=file:consult("examples/debug/join_line_missing_endpoint.term"),
    Dir='svg_path@point':subtract(End,Start),
    Normal=M:ray_supporting_line_normal(Dir),
    {ok,C}=M:arc_center_data(Arc),
    Alpha=M:dot(Normal,M:arc_x_axis(C)),Beta=M:dot(Normal,M:arc_y_axis(C)),
    {ellipse_point,CX,CY}=element(2,C),{point,SX,SY}=Start,
    K=M:dot({point,CX-SX,CY-SY},Normal),R=math:sqrt(Alpha*Alpha+Beta*Beta),
    Phase='svg_path@trig':atan2_degrees(Beta,Alpha),
    {ok,Aperture}='svg_path@trig':acos_degrees(-K/R),
    io:format("Center arc: ~p~ncosine: ~p; aperture: ~p; phase: ~p~n",[C,-K/R,Aperture,Phase]),
    StartAngle=element(5,C),Delta=element(6,C),
    lists:foreach(fun(Angle)->
        T=M:arc_angle_progress(Angle,StartAngle,Delta)/abs(Delta),
        io:format("Unclamped angle candidate ~p: parameter ~p; in sweep ~p~n",[Angle,T,M:arc_angle_in_sweep(Angle,StartAngle,Delta)])
    end,[Phase+Aperture,Phase-Aperture]),
    io:format("Arc roots: ~p~n",[M:arc_line_classified_roots(Arc,Start,Normal,1.0e-9,192)]),
    io:format("Exact endpoint: ~p~n",[M:segment_point(Arc,1.0)]).
