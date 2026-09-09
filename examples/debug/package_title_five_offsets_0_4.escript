#!/usr/bin/env escript
%% Public production offsets; reuse the maintained fixture's SVG renderer.
-mode(compile).

main(_) ->
    code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
    Fixture = svg_path_package_title_three_offsets_fixture,
    {ok, Fixture, Binary} = compile:file(
        "build/dev/erlang/svg_path/_gleam_artefacts/svg_path_package_title_three_offsets_fixture.erl",
        [binary, export_all]),
    {module, Fixture} = code:load_binary(Fixture, "fixture-renderer", Binary),
    {ok, Input} = file:read_file("examples/debug/package_title.svg"),
    {ok, Source} = 'svg_path@parse':path(Fixture:first_path_data(Input)),
    Options = 'svg_path@offset':default_options(),
    Levels = offsets(Source, Options, 1, []),
    Output = "examples/debug/package_title_five_offsets_0_4_no_final_orientation.svg",
    ok = file:write_file(Output, Fixture:render(Source, Levels)),
    io:format("Rendered ~p completed offsets: ~s~n", [length(Levels), Output]).

offsets(_, _, 6, Completed) -> lists:reverse(Completed);
offsets(Current, Options, Level, Completed) ->
    Started = erlang:monotonic_time(millisecond),
    case 'svg_path@offset':path_with(Current, 0.4, {miter, 4.0}, butt, Options) of
        {ok, Next} ->
            {path, Subpaths} = Next,
            io:format("Offset ~p succeeded: ~p subpaths, ~p ms~n",
                [Level, length(Subpaths), erlang:monotonic_time(millisecond) - Started]),
            offsets(Next, Options, Level + 1, [Next | Completed]);
        {error, Error} ->
            io:format("Offset ~p failed: ~p~n", [Level, Error]),
            lists:reverse(Completed)
    end.
