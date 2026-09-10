#!/usr/bin/env escript
%% VM-local instrumentation; production files and compiled artifacts unchanged.
-mode(compile).
main([Mode]) when Mode =:= "polygons"; Mode =:= "boxes_polygons" ->
    code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
    M='svg_path@intersections',
    F="build/dev/erlang/svg_path/_gleam_artefacts/svg_path@intersections.erl",
    {ok,Forms}=epp:parse_file(F,[],[]),
    Base=case Mode of
      "polygons"->Forms;
      "boxes_polygons"->replace(Forms,elizabeth_window_overlaps,3,parse(
        "elizabeth_window_overlaps(A,B,W) -> "
        "{window_preserving_window,U,V,S,T}=W, "
        "case window_segment_bounding_box(A,U,V) of "
        "{error,_}=E -> E; {ok,AB} -> "
        "case window_segment_bounding_box(B,S,T) of "
        "{error,_}=E -> E; {ok,BB} -> window_bounds_overlap(A,B,W,AB,BB) end end."))
    end,
    Instrumented=[instrument(X)||X<-Base],
    Helpers=[parse(S)||S<-[
      "bench_count(K,N) -> case erlang:get(K) of undefined -> erlang:put(K,N); V -> erlang:put(K,V+N) end, ok.",
      "bench_begin(G,Pending) -> case G of 1 -> bench_count(solves,1), bench_count(created,erlang:length(Pending)); _ -> ok end.",
      "bench_split(W) -> X=window_preserving_split_window_nine(W), bench_count(created,erlang:length(X)), X.",
      "elizabeth_window_overlaps(A,B,W) -> bench_count(examined,1), R=bench_original_overlaps(A,B,W), case R of {ok,false} -> bench_count(geometric_rejections,1); _ -> ok end, R.",
      "elizabeth_beam_select(A,B,W,Budget,Cache) -> R=bench_original_select(A,B,W,Budget,Cache), case R of {ok,{_,C,O,_}} -> bench_count(budget_discards,C+O); _ -> ok end, R."
    ]],
    {ok,M,Bin}=compile:forms(Instrumented++Helpers,[binary,export_all,report_errors]),
    {module,M}=code:load_binary(M,F,Bin),
    [{Name,Title,Generate}]=[J||J={<<"gallery-package-title-nine-offsets.svg">>,_,_}<-svg_path_gallery_test:gallery_jobs()],
    Job=fun()->
      Svg=Generate(),
      io:format("COUNTS ~s: ~p~n",[Mode,[{K,get(K)}||K<-[solves,created,examined,geometric_rejections,budget_discards]]]),
      Svg
    end,
    io:format("Enclosures: ~s~n",[Mode]),
    case gallery_jobs:run([{Name,Title,Job}],list_to_binary("examples/debug/enclosure-counts-"++Mode)) of
      true->ok; false->halt(1)
    end.
parse(S)->{ok,T,_}=erl_scan:string(S),{ok,F}=erl_parse:parse_form(T),F.
replace(Forms,Name,Arity,New)->
    1=length([ok||{function,_,N,A,_}<-Forms,N=:=Name,A=:=Arity]),
    [case X of {function,_,Name,Arity,_}->New; _->X end||X<-Forms].
instrument({function,L,elizabeth_window_overlaps,A,C})->{function,L,bench_original_overlaps,A,C};
instrument({function,L,elizabeth_beam_select,A,C})->{function,L,bench_original_select,A,C};
instrument({function,L,elizabeth_beam_generation,A,Clauses})->
    {function,L,elizabeth_beam_generation,A,
      [{clause,CL,Args,Guards,[{call,CL,{atom,CL,bench_begin},[lists:nth(6,Args),lists:nth(4,Args)]}|rewrite(Body)]}
       ||{clause,CL,Args,Guards,Body}<-Clauses]};
instrument(X)->X.
rewrite({call,L,{atom,AL,window_preserving_split_window_nine},Args})->{call,L,{atom,AL,bench_split},Args};
rewrite(X) when is_tuple(X)->list_to_tuple([rewrite(Y)||Y<-tuple_to_list(X)]);
rewrite(X) when is_list(X)->[rewrite(Y)||Y<-X];
rewrite(X)->X.
