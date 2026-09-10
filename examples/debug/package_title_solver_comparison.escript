#!/usr/bin/env escript
%% VM-local solver overrides: no production source/build files are changed.
-mode(compile).
main([Mode]) when Mode =:= "elizabeth18"; Mode =:= "elizabeth15"; Mode =:= "old"; Mode =:= "current" ->
    code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
    M = 'svg_path@intersections',
    F = "build/dev/erlang/svg_path/_gleam_artefacts/svg_path@intersections.erl",
    {ok, Forms} = epp:parse_file(F, [], []),
    Patched = case Mode of
        "current" -> Forms;
        Elizabeth when Elizabeth =:= "elizabeth18"; Elizabeth =:= "elizabeth15" ->
            1 = length([ok || {function,_,elizabeth_generation_budget,2,_} <- Forms]),
            {Coefficient,Stop} = case Mode of
                "elizabeth18" -> {"0.822387721768745", "18"};
                "elizabeth15" -> {"0.7784360616734048", "15"}
            end,
            Budget = lists:flatten(["elizabeth_generation_budget(G, _Start) -> "
                     "B = erlang:max(1, erlang:round(500.0 * math:pow("
                     ,Coefficient,", erlang:max(0, erlang:min(G,",Stop,
                     ")-1)))), {B,B}."]),
            {ok, Tokens, _} = erl_scan:string(Budget),
            {ok, Replacement} = erl_parse:parse_form(Tokens),
            [case X of {function,_,elizabeth_generation_budget,2,_} -> Replacement;
                       _ -> X end || X <- Forms];
        "old" ->
            Changed = [switch(X) || X <- Forms],
            1 = length([ok || {A,B} <- lists:zip(Forms,Changed), A =/= B]),
            Changed
    end,
    {ok,M,Bin} = compile:forms(Patched,[binary,export_all]),
    {module,M} = code:load_binary(M,F,Bin),
    case Mode of "elizabeth18" -> {18,18} = M:elizabeth_generation_budget(18,none);
                 "elizabeth15" -> {15,15} = M:elizabeth_generation_budget(15,none),
                                  {15,15} = M:elizabeth_generation_budget(48,none);
                 _ -> ok end,
    Jobs = [J || J={<<"gallery-package-title-nine-offsets.svg">>,_,_}
                       <- svg_path_gallery_test:gallery_jobs()],
    1 = length(Jobs),
    io:format("Solver: ~s; original nine-offset title fixture (+1.04)~n",[Mode]),
    Directory = list_to_binary("examples/debug/title-comparison-" ++ Mode),
    case gallery_jobs:run(Jobs,Directory) of true -> ok; false -> halt(1) end.

switch({function,L,curve_curve_intersections,3,
        [{clause,CL,Args,Guards,[{'case',CaseL,{atom,AL,true},Clauses}]}]}) ->
    {function,L,curve_curve_intersections,3,
     [{clause,CL,Args,Guards,[{'case',CaseL,{atom,AL,false},Clauses}]}]};
switch(X) -> X.
