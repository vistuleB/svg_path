#!/usr/bin/env escript
%% Calls production private sweep helpers; does not reimplement intersections.
-mode(compile).
main(_) ->
    code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
    lists:foreach(fun(Name) ->
        File = "build/dev/erlang/svg_path/_gleam_artefacts/" ++ Name ++ ".erl",
        {ok, M, B} = compile:file(File, [binary, export_all, return_errors]),
        {module, M} = code:load_binary(M, File, B)
    end, ["svg_path@arrangement", "svg_path_arrangement_graph_test"]),
    A = svg_path@arrangement, T = svg_path_arrangement_graph_test,
    {ok,G} = T:build_graph([T:square(0.0,0.0,10.0)],1.0e-6,1.0e-5),
    {ok,W} = A:dual_face_walks(G),
    Edges = element(3,G), Vertices = element(2,G),
    Components = A:dual_components(Edges, []),
    {ok,E} = A:dual_sweep_edges(Edges,Components,W),
    Tol = A:dual_sweep_tolerance(G),
    L = {dual_sweep_line,{point,5.0,5.0},{point,1.0,0.0}},
    {ok,H} = A:dual_sweep_intersections(E,Vertices,L,Tol),
    2 = length(H),
    {ok,[Ext]} = A:dual_line_exteriors(H),
    States = [{element(2,Ext),element(3,Ext)}],
    {ok,P} = A:dual_line_placements(H,States,[Ext],W,[]),
    true = lists:all(fun(X)->element(4,X)==1 end,P),
    {ok,P2} = A:dual_merge_placements(P,P,true),
    true = lists:all(fun(X)->element(4,X)==2 end,P2),
    Bad = {dual_placement,element(2,hd(P)),[true,true],1},
    {error,{internal_dual_sweep_contradiction,_}} = A:dual_merge_placements([Bad],P,true),
    {error,{internal_dual_sweep_exhausted,1}} = A:dual_find_exteriors(E,Vertices,Tol,1,[],1729,0),
    %% Vertex and coincident-edge lines are rejected before conclusions.
    {error,nil} = A:dual_sweep_intersections(E,Vertices,
        {dual_sweep_line,{point,0.0,0.0},{point,1.0,0.0}},Tol),
    {error,nil} = A:dual_sweep_intersections(E,Vertices,
        {dual_sweep_line,{point,0.0,0.0},{point,0.6,0.8}},Tol),
    %% A repeated root is rejected even though the API returns its contact.
    Q = {quadratic_bezier,{point,-1.0,1.0},{point,0.0,-1.0},{point,1.0,1.0}},
    {ok,Box} = svg_path:segment_bounding_box(Q),
    QE = {dual_sweep_edge,0,0,0,1,Q,Box},
    {error,nil} = A:dual_sweep_edge_hits(QE,
        {dual_sweep_line,{point,0.0,0.0},{point,1.0,0.0}},1.0e-9),
    %% Close but separately returned crossings cannot be safely ordered.
    {error,nil} = A:dual_check_hit_separation([
        {dual_sweep_hit,0,0.0,1.0e-8,0,0,1},
        {dual_sweep_hit,1,1.0e-9,1.0e-8,0,1,0}],1.0e-9),
    io:format("Sweep acceptance, confirmation, contradiction and exhaustion checks passed.~n").
