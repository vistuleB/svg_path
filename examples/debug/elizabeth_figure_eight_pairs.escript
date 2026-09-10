#!/usr/bin/env escript
-mode(compile).
main(_) ->
    code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
    M='svg_path@intersections',
    F="build/dev/erlang/svg_path/_gleam_artefacts/svg_path@intersections.erl",
    {ok,M,Bin}=compile:file(F,[binary,export_all]),
    {module,M}=code:load_binary(M,F,Bin),
    {ok,[{Build,_}]}=file:consult("examples/debug/elizabeth-figure-eight-winding.term"),
    Indexed=element(3,Build),
    Source=element(4,lists:nth(33,Indexed)),
    lists:foreach(fun({I,Item})->
      Segment=element(4,Item),
      Old=M:edward_then_henry_intersections(Source,Segment,M:default_options()),
      case Old of
        {ok,[]}->ok;
        _->
          New=M:elizabeth_beam_intersections(Source,Segment,M:default_options()),
          io:format("Source 32 vs ~p~nold ~p~nnew ~p~ngeometry ~p~n",[I,Old,New,{Source,Segment}])
      end
    end,lists:zip(lists:seq(0,31),lists:sublist(Indexed,32))).
