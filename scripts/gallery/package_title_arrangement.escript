#!/usr/bin/env escript
%% Capture actual calls/returns in the compiled production offset pipeline.
%% Run from repository root after `gleam build`. No solver is reimplemented.
-mode(compile).

main(_) ->
    code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
    {ok, Input} = file:read_file("examples/debug/package_title.svg"),
    {match, [D]} = re:run(Input, <<" d=\"([^\"]+)\"">>, [{capture, [1], binary}]),
    {ok, Source} = 'svg_path@parse':path(D),
    Options = 'svg_path@offset':default_options(),
    %% Only the second diagnostic bypasses offside trimming. The first offset
    %% remains the ordinary public result used as the next source.
    {single_offset_trimming, _, Finish} = element(6, Options),
    DiagnosticOptions = setelement(6, Options, {single_offset_trimming, false, Finish}),
    Join = {miter, 4.0},
    {ok, First} = 'svg_path@offset':path_with(Source, 1.05, Join, butt, Options),
    io:format("First offset succeeded.~n"),
    Collector = spawn(fun() -> collect([]) end),
    Functions = [{delete_winding_mismatched_edges, 2},
                 {forced_parity_reduce_trim_graph, 2}],
    [erlang:trace_pattern({'svg_path@offset', F, A},
                         [{'_', [], [{return_trace}]}], [local]) || {F,A} <- Functions],
    erlang:trace(self(), true, [call, {tracer, Collector}]),
    Second = 'svg_path@offset':path_with(First, 1.05, Join, butt, DiagnosticOptions),
    erlang:trace(self(), false, [call]),
    Ref = erlang:trace_delivered(self()),
    receive {trace_delivered, _, Ref} -> ok end,
    Collector ! {get, self()},
    Events = receive {events, Captured} -> Captured end,
    [erlang:trace_pattern({'svg_path@offset', F, A}, false, [local]) || {F,A} <- Functions],
    {ok, _} = Second,
    [{Build, Eligible}] = [{B,G} || {trace,_,call,{'svg_path@offset',delete_winding_mismatched_edges,[B,G]}} <- Events],
    [Retained] = [G || {trace,_,return_from,{'svg_path@offset',delete_winding_mismatched_edges,2},{ok,G}} <- Events],
    [Reduced] = [G || {trace,_,return_from,{'svg_path@offset',forced_parity_reduce_trim_graph,2},{ok,G}} <- Events],
    {offset_arrangement_build, {arrangement_graph,Vertices,Edges,_},_,_,_} = Build,
    EligibleIds = ids(Eligible), RetainedIds = ids(Retained), SurvivorIds = ids(Reduced),
    %% Match the historical figure's first-round meaning: degree-one edges
    %% immediately after submerged deletion, not merely the first serial
    %% capacity decrement. Require actual deletion by production pruning.
    RetainedEdges = element(3, Retained),
    Incidences = lists:append([[element(5,E),element(6,E)] || E <- RetainedEdges]),
    FirstDeleted = [element(2,E) || E <- RetainedEdges,
        not lists:member(element(2,E), SurvivorIds),
        lists:any(fun(V) -> length([I || I <- Incidences, I == V]) == 1 end,
                  [element(5,E),element(6,E)])],
    %% Keep the established Gallery framing; generation never reads the archive.
    Box = <<"-5.1 -5.1 99.06998 23.565">>,
    [X,Y,W,H] = binary:split(Box, <<" ">>, [global]),
    Svg = ["<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1800\" height=\"420\" viewBox=\"",Box,"\">",
           "<rect x=\"",X,"\" y=\"",Y,"\" width=\"",W,"\" height=\"",H,"\" fill=\"white\"/>",
           layer('svg_path@serialize':path(Source), "fill: #111827; stroke: none; opacity: 0.16"),
           layer('svg_path@serialize':path(First), "fill: none; stroke: #2563eb; stroke-width: 0.07; stroke-linecap: round; stroke-linejoin: round"),
           %% Preserve the old renderer's compositing, not just its styles:
           %% every offset edge has a pale underlay and a red/green base;
           %% yellow and purple are separate translucent overlay passes.
           [edge_svg(E,"#cbd5e1") || E <- Edges],
           [edge_svg(E,case lists:member(element(2,E),RetainedIds) of
                          true -> "#16a34a"; false -> "#dc2626" end)
              || E <- Edges, lists:member(element(2,E),EligibleIds)],
           [edge_svg(E,"#facc15") || E <- Edges, lists:member(element(2,E),FirstDeleted)],
           [edge_svg(E,"#7c3aed") || E <- Edges, lists:member(element(2,E),SurvivorIds)],
           [edge_label(E) || E <- Edges, lists:member(element(2,E),RetainedIds)],
           %% Match the original: one dot at each eligible edge endpoint,
           %% including repeated dots where endpoints coincide.
           [[vertex_dot(svg_path:segment_start(element(3,E))),
             vertex_dot(svg_path:segment_end(element(3,E)))]
              || E <- Edges, lists:member(element(2,E),EligibleIds)],
           "</svg>"],
    Output = "test/generated/gallery/gallery-package-title-second-offset-arrangement.svg",
    ok = filelib:ensure_dir(Output),
    ok = file:write_file(Output, Svg),
    Summary = io_lib:format("Offset 1.05 twice; Miter(4); second offset offside=false.~nVertices: ~p~nGraph edges: ~p~nEligible offset edges: ~p~nInitially submerged: ~p~nInitially retained: ~p~nPositive final capacity: ~p~nInitially dangling deleted edge IDs: ~p~n", [length(Vertices),length(Edges),length(EligibleIds),length(EligibleIds)-length(RetainedIds),length(RetainedIds),length(SurvivorIds),FirstDeleted]),
    ok = file:write_file("test/generated/gallery/package-title-second-offset-arrangement-capture.txt", Summary),
    io:put_chars(Summary).

collect(Acc) ->
    receive
        {get, From} -> From ! {events, lists:reverse(Acc)};
        Event -> collect([Event|Acc])
    end.
ids({offset_trim_graph,_,Edges,_}) -> [element(2,E) || E <- Edges].
edge_svg(E, Color) ->
    {ok, Subpath} = svg_path:subpath([element(3,E)]),
    {Width, Opacity} = case Color of
        "#facc15" -> {"0.22", "; opacity: 0.98"};
        "#7c3aed" -> {"0.16", "; opacity: 0.95"};
        "#cbd5e1" -> {"0.05", ""};
        _ -> {"0.09", "; opacity: 0.82"}
    end,
    ["<g><title>edge ", integer_to_list(element(2,E)), "</title>",
     layer('svg_path@serialize':subpath(Subpath),
           ["fill: none; stroke: ",Color,"; stroke-width: ",Width,"; stroke-linecap: round; stroke-linejoin: round",Opacity]), "</g>"].
edge_label(E) ->
    {ok,{bounding_box,{point,X0,Y0},{point,X1,Y1}}} =
        svg_path:segment_bounding_box(element(3,E)),
    ["<text x=\"",float_to_binary((X0+X1)/2,[short]),
     "\" y=\"",float_to_binary((Y0+Y1)/2,[short]),
     "\" font-size=\"0.3\" style=\"fill: #1e3a8a; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; text-anchor: middle; dominant-baseline: central\">",
     integer_to_list(element(2,E)),"</text>"].
vertex_dot({point,X,Y}) ->
    ["<circle cx=\"",float_to_binary(X,[short]),"\" cy=\"",float_to_binary(Y,[short]),
     "\" r=\"0.035\" style=\"fill: #111827; stroke: none; opacity: 0.8\"/>"] .
layer(D, Style) -> ["<path d=\"",D,"\" style=\"",Style,"\"/>"].
