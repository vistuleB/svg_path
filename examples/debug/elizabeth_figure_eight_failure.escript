#!/usr/bin/env escript
%% Trace actual production failures; no geometry or solver substitutions.
-mode(compile).
main(_) ->
    code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
    M=svg_path_gallery_test,
    F="build/dev/erlang/svg_path/_gleam_artefacts/svg_path_gallery_test.erl",
    {ok,M,B}=compile:file(F,[binary,export_all]),
    {module,M}=code:load_binary(M,F,B),
    Collector=spawn(fun()->collect() end),
    Modules=['svg_path@offset','svg_path@arrangement'],
    lists:foreach(fun(Mod)->
      {module,Mod}=code:ensure_loaded(Mod),
      erlang:trace_pattern({Mod,'_','_'},[{'_',[],[{return_trace}]}],[local])
    end,Modules),
    erlang:trace(self(),true,[call,{tracer,Collector}]),
    Result=try M:figure_eight_band(),ok catch C:R->{C,R} end,
    erlang:trace(self(),false,[call]),
    Ref=erlang:trace_delivered(self()),receive {trace_delivered,_,Ref}->ok end,
    Collector!{done,self()},receive done->ok end,
    io:format("Fixture: ~p~n",[Result]).
collect()->
    receive
      {trace,_,return_from,MFA,{error,E}} ->
        case MFA of
          {'svg_path@arrangement',face_windings,2}->
            file:write_file("examples/debug/elizabeth-figure-eight-winding.term",io_lib:format("~p.~n",[{get(build),get(winding)}]));
          _->ok
        end,
        io:format("~p -> ~p~n",[MFA,E]),collect();
      {trace,_,call,{'svg_path@offset',with_face_windings,[Build]}}->
        put(build,Build),collect();
      {trace,_,call,{'svg_path@arrangement',face_windings,Args}}->
        put(winding,Args),collect();
      {done,P}->P!done;
      _->collect()
    end.
