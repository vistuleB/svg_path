#!/usr/bin/env escript
%% Inspect actual -5/+25 enumeration/orientation calls from the gallery fixture.
-mode(compile).
main(_) ->
    code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
    M=svg_path_gallery_test,
    F="build/dev/erlang/svg_path/_gleam_artefacts/svg_path_gallery_test.erl",
    {ok,M,B}=compile:file(F,[binary,export_all]),{module,M}=code:load_binary(M,F,B),
    {module,'svg_path@offset'}=code:ensure_loaded('svg_path@offset'),
    Collector=spawn(fun()->collect(#{},[]) end),
    lists:foreach(fun(Name)->
        1=erlang:trace_pattern({'svg_path@offset',Name,1},[{'_',[],[{return_trace}]}],[local])
    end,[enumerate_band_face_loops,orient_band_path]),
    erlang:trace(self(),true,[call,{tracer,Collector}]),
    _=M:symmetric_figure_eight_bands(),
    erlang:trace(self(),false,[call]),
    Ref=erlang:trace_delivered(self()),receive {trace_delivered,_,Ref}->ok end,
    Collector!{get,self()},Calls=receive {calls,C}->C end,
    [{enumerate_band_face_loops,Input,{ok,Enumerated}}|_]=Calls,
    []=[Call||Call={orient_band_path,_,_}<-Calls],
    ok=file:write_file("examples/debug/loop8-minus5-plus25-direct-enumeration.term",io_lib:format("~p.~n",[{Input,Enumerated}])),
    inspect("Before enumeration",Input),
    inspect("After filled-on-right enumeration (no old orientator)",Enumerated).

collect(Inputs,Calls)->
    receive
        {trace,_,call,{'svg_path@offset',Name,[Path]}}->collect(maps:put(Name,Path,Inputs),Calls);
        {trace,_,return_from,{'svg_path@offset',Name,1},Result}->
            collect(Inputs,[{Name,maps:get(Name,Inputs),Result}|Calls]);
        {get,P}->P!{calls,lists:reverse(Calls)}
    end.

inspect(Label,Path={path,Loops})->
    Indexed=lists:append([[{S,I}||S<-svg_path:subpath_segments(L)]||{L,I}<-lists:zip(Loops,lists:seq(0,length(Loops)-1))]),
    Owners=maps:from_list(lists:zip(lists:seq(0,length(Indexed)-1),[I||{_,I}<-Indexed])),
    {ok,{arrangement_segment_build,G,_,_,Images}}='svg_path@arrangement':build_with([S||{S,_}<-Indexed],2.0e-9,2.0e-9,0.0001),
    {arrangement_graph,_,Edges,_}=G,
    {ok,D={dual_arrangement_graph,_,EF}}='svg_path@arrangement':dual(G),
    {ok,W}='svg_path@arrangement':face_windings(D,[{edge_winding_change,Id,F-R}||{arrangement_edge,Id,_,_,_,_,F,R}<-Edges]),
    WV=maps:from_list([{Id,V}||{face_winding,Id,V}<-W]),
    Multi=[E||E={arrangement_edge,_,_,_,_,_,F,R}<-Edges,F+R>1],
    io:format("~s: ~p contours, ~p segment occurrences, ~p graph edges, ~p multiply-traced edges~n",[Label,length(Loops),length(Indexed),length(Edges),length(Multi)]),
    lists:foreach(fun({arrangement_edge,Id,S,_,_,_,Forward,Reverse})->
        {arrangement_edge_image,Id,Sources}=lists:keyfind(Id,2,Images),
        {arrangement_edge_faces,Id,L,R}=lists:keyfind(Id,2,EF),
        Preimages=[{maps:get(SI,Owners),SI,Rev}||{arrangement_edge_source_image,SI,_,_,Rev}<-Sources],
        io:format("  edge ~p counts ~p/~p: ~p -> ~p; faces ~p/~p, windings ~p/~p; owners {loop,segment,reversed}=~p~n",[Id,Forward,Reverse,svg_path:segment_start(S),svg_path:segment_end(S),L,R,maps:get(L,WV),maps:get(R,WV),Preimages])
    end,Multi),
    io:format("  public winding at center: ~p~n",[svg_path:path_winding({point,250.0,250.0},Path)]).
