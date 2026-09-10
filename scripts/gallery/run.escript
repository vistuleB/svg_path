#!/usr/bin/env escript
%% Build both projects first. All geometry jobs then share one read-only build.
-mode(compile).
main(Names) ->
    code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
    code:add_patha("examples/readme_arrangement_figures/build/dev/erlang/readme_arrangement_figures/ebin"),
    Jobs = svg_path_gallery_test:gallery_jobs() ++ arrangement_csg_figures:gallery_jobs(),
    Selected = case Names of
        [] -> Jobs;
        _ ->
            Requested = [list_to_binary(N) || N <- Names],
            Unknown = Requested -- [N || {N,_,_} <- Jobs],
            case Unknown of [] -> ok; _ -> io:format("Unknown figures: ~p~n",[Unknown]),halt(1) end,
            [J || J={N,_,_} <- Jobs,lists:member(N,Requested)]
    end,
    case gallery_jobs:run(Selected, <<"test/generated/gallery">>) of
        true -> ok;
        false -> halt(1)
    end.
