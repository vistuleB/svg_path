#!/usr/bin/env escript
%% Draw only captured final-orientation input and its actual arrangement edges.
-mode(compile).
main(_) ->
    code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
    {ok,[[{Path={path,Loops},{error,{internal_band_orientation_conflict,22}}}]]}=
        file:consult("examples/debug/orientation-square-outer-cusps.term"),
    Indexed=lists:append([[{S,I}||S<-svg_path:subpath_segments(L)]||{L,I}<-lists:zip(Loops,lists:seq(0,length(Loops)-1))]),
    {ok,{arrangement_segment_build,G,_,_,Images}}='svg_path@arrangement':build_with([S||{S,_}<-Indexed],2.0e-9,2.0e-9,0.0001),
    {arrangement_graph,Vertices,Edges,_}=G,
    {ok,D={dual_arrangement_graph,Faces,EF}}='svg_path@arrangement':dual(G),
    Owners=maps:from_list(lists:zip(lists:seq(0,length(Indexed)-1),[I||{_,I}<-Indexed])),
    Changes=[{edge_winding_change,Id,lists:sum([case Rev of true->-1;false->1 end||{arrangement_edge_source_image,SI,_,_,Rev}<-Sources,maps:get(SI,Owners)=:=0])}||{arrangement_edge_image,Id,Sources}<-Images],
    io:format("Contour 0 signed face winding: ~p~n",['svg_path@arrangement':face_windings(D,Changes)]),
    lists:foreach(fun(Id)->
        io:format("Edge ~p: ~p; faces ~p; sources ~p~n",[Id,lists:keyfind(Id,2,Edges),lists:keyfind(Id,2,EF),lists:keyfind(Id,2,Images)])
    end,[23,22]),
    {ok,{bounding_box,{point,X0,Y0},{point,X1,Y1}}}=svg_path:path_bounding_box(Path),
    W=X1-X0,H=Y1-Y0,P=0.15*max(W,H),BX=X0-P,BY=Y0-P,BW=W+2*P,BH=H+2*P,
    Svg=["<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"850\" height=\"850\" viewBox=\"",nums([BX,BY,BW,BH]),"\">",
         "<rect x=\"",n(BX),"\" y=\"",n(BY),"\" width=\"",n(BW),"\" height=\"",n(BH),"\" fill=\"white\"/>",
         "<text x=\"",n(BX+0.15),"\" y=\"",n(BY+0.3),"\" font-size=\"0.18\" font-family=\"sans-serif\">Final orientation: inner_cusps False, outer_cusps True</text>",
         %% Face 6 is the lobe whose direction contradicts the main contour.
         [face(F,Edges)||F={arrangement_face,6,_,_}<-Faces],
         [draw_loop(L,I)||{L,I}<-lists:zip(Loops,lists:seq(0,length(Loops)-1))],
         [draw_edge(E)||E<-Edges],
         [["<circle cx=\"",n(X),"\" cy=\"",n(Y),"\" r=\"0.017\" fill=\"black\"/>"]||{arrangement_vertex,_,{point,X,Y},_}<-Vertices],
         "<text x=\"",n(BX+0.15),"\" y=\"",n(BY+BH-0.25),"\" font-size=\"0.16\" font-family=\"sans-serif\">Blue: contour 0. Grey: contour 1. Green 23: reverse; red 22: keep.</text></svg>"],
    ok=file:write_file("examples/debug/final-orientation-square-conflict.svg",Svg).
n(X)->io_lib:format("~.12g",[float(X)]).
nums(X)->lists:join(" ",[n(V)||V<-X]).
draw_loop(L,I)->["<path d=\"",'svg_path@serialize':subpath(L),"\" fill=\"none\" stroke=\"",case I of 0->"#2475b5";_->"#bbb" end,"\" stroke-width=\"0.014\"/>"] .
draw_edge({arrangement_edge,Id,S,_,_,_,_,_})->
    case Id=:=22 orelse Id=:=23 of
        false->[];
        true->
            {ok,{point,X,Y}}=svg_path:segment_point(S,0.5),
            C=case Id of 22->"#d22";_->"#198b39" end,
            ["<path d=\"",'svg_path@serialize':segment(S),"\" fill=\"none\" stroke=\"",C,"\" stroke-width=\"0.032\"/>",
             "<text x=\"",n(X+0.05),"\" y=\"",n(Y-0.06),"\" font-family=\"sans-serif\" font-size=\"0.2\" fill=\"",C,"\">",integer_to_list(Id),"</text>"]
    end.
face({arrangement_face,_,_,Walks},Edges)->
    Parts=[[case Left of true->S;false->svg_path:segment_reverse(S) end||{arrangement_face_edge,Id,Left}<-Es,{arrangement_edge,_,S,_,_,_,_,_}<-[lists:keyfind(Id,2,Edges)]]||{arrangement_face_walk,_,Es}<-Walks],
    %% Display the exact graph segments in walk order; do not rebuild/heal them.
    [["<path d=\"",'svg_path@serialize':subpath({subpath,svg_path:segment_start(hd(Segments)),Segments,true}),"\" fill=\"#ffe9a6\" stroke=\"none\"/>"]||Segments<-Parts].
