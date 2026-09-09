#!/usr/bin/env escript
%% Read-only reproduction. Requires a current Gleam Erlang build.
-mode(compile).
main(_) ->
    code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
    {ok,[{Join,Line,Options}]} = file:consult("examples/debug/join_line_missing_endpoint.term"),
    true = svg_path:segment_end(Join) =:= svg_path:segment_start(Line),
    io:format("Exact shared endpoint (join t=1, line t=0): ~p~n",
        [svg_path:segment_end(Join)]),
    io:format("Intersection options: ~p~nResult: ~p~n",[Options,
        'svg_path@intersections':segment_with(Join,Line,Options)]).
