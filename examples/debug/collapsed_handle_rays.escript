#!/usr/bin/env escript
%% Test the compiled private fitter without changing its implementation.
-mode(compile).
main(_) ->
    code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
    File = "build/dev/erlang/svg_path/_gleam_artefacts/svg_path@offset.erl",
    Compiled = compile:file(File, [binary, export_all, return_errors]),
    {ok, Module, Binary} = Compiled,
    {module, Module} = code:load_binary(Module, File, Binary),
    S = {point,0.0,0.0}, E = {point,1.0,0.0},
    Cases = [{"correct rays",{point,1.0,1.0},{point,0.0,-1.0},ok},
             {"wrong collapsed ray",{point,-1.0,-1.0},{point,0.0,-1.0},error},
             {"wrong noncollapsed ray",{point,1.0,1.0},{point,0.0,1.0},error},
             {"both wrong",{point,-1.0,-1.0},{point,0.0,1.0},error},
             {"parallel backward",{point,-1.0,0.0},{point,-1.0,0.0},error},
             {"parallel forward",{point,1.0,0.0},{point,1.0,0.0},ok}],
    Samples = [{0.5,{bezier_point,0.4,0.0}}],
    lists:foreach(fun({Label,DS,DE,Expected}) ->
        A = Module:stalled_start_control2(S,E,DS,DE,Samples),
        B = Module:stalled_end_control1(E,S,negate(DE),negate(DS),Samples),
        io:format("~s: start=~p end=~p~n",[Label,A,B]),
        Expected = element(1,A), Expected = element(1,B)
    end, Cases),
    io:format("12 collapsed-handle ray cases passed.~n").
negate({point,X,Y}) -> {point,-X,-Y}.
