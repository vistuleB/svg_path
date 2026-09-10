#!/usr/bin/env escript
%% Verify that fixture-level recovery does not hide final-orientation errors.
%% Capture actual production inputs and results, without replacing geometry.
-mode(compile).
main(_) ->
    code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
    M=svg_path_gallery_test,
    F="build/dev/erlang/svg_path/_gleam_artefacts/svg_path_gallery_test.erl",
    {ok,M,B}=compile:file(F,[binary,export_all]),
    {module,M}=code:load_binary(M,F,B),
    {module,'svg_path@offset'}=code:ensure_loaded('svg_path@offset'),
    S=svg_path_two_corner_square_bands_fixture,
    SF="build/dev/erlang/svg_path/_gleam_artefacts/svg_path_two_corner_square_bands_fixture.erl",
    {ok,S,SB}=compile:file(SF,[binary,export_all]),
    {module,S}=code:load_binary(S,SF,SB),
    Results=[check("square both cusps",fun()->S:'band'(S:source_subpath(),true,true) end),
             check("square outer cusps",fun()->S:'band'(S:source_subpath(),false,true) end),
             check("square no cusps",fun()->S:'band'(S:source_subpath(),false,false) end),
             check("recursive dashes",fun M:recursive_dashes/0),
             check("figure eight band",fun M:figure_eight_band/0),
             check("loop eight bands",fun M:symmetric_figure_eight_bands/0)],
    case lists:all(fun(X)->X end,Results) of true->ok;false->halt(1) end.

check(Label,Run) ->
    Collector=spawn(fun()->collect([],0,[]) end),
    1=erlang:trace_pattern({'svg_path@offset',enumerate_band_face_loops,1},[{'_',[],[{return_trace}]}],[local]),
    erlang:trace(self(),true,[call,{tracer,Collector}]),
    Outcome=try Run(),ok catch Class:Reason->{Class,Reason} end,
    erlang:trace(self(),false,[call]),
    R=erlang:trace_delivered(self()),receive {trace_delivered,_,R}->ok end,
    Collector!{get,self()},
    {Count,Errors}=receive {checks,N,E}->{N,E} end,
    io:format("~s: ~p enumeration/orientation calls, ~p errors; fixture ~p~n",[Label,Count,length(Errors),Outcome]),
    case Errors of
        []->ok;
        _->
            %% Keep historical captures intact when testing a new policy.
            File="examples/debug/orientation-latest-"++string:replace(Label," ","-",all)++".term",
            ok=file:write_file(File,io_lib:format("~p.~n",[Errors])),
            io:format("Actual failing orientation inputs/results saved to ~s~n",[File])
    end,
    Errors=:=[] andalso Outcome=:=ok.

collect(Stack,Count,Errors) ->
    receive
        {trace,_,call,{'svg_path@offset',Name,[Path]}} when Name=:=enumerate_band_face_loops ->collect([Path|Stack],Count,Errors);
        {trace,_,return_from,{'svg_path@offset',Name,1},Result} when Name=:=enumerate_band_face_loops ->
            [Path|Rest]=Stack,
            Next=case Result of {error,_}->[{Path,Result}|Errors];_->Errors end,
            collect(Rest,Count+1,Next);
        {get,P}->P!{checks,Count,lists:reverse(Errors)}
    end.
