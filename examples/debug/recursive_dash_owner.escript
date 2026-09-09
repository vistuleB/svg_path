#!/usr/bin/env escript
%% Trace the real fixture's stroke calls; do not reconstruct its pipeline.
-mode(compile).

main(_) ->
    code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
    M = svg_path_gallery_test,
    File = "build/dev/erlang/svg_path/_gleam_artefacts/svg_path_gallery_test.erl",
    {ok,M,Binary} = compile:file(File, [binary,export_all]),
    {module,M} = code:load_binary(M,File,Binary),
    {ok,[{SavedSource,_,_,_}]} = file:consult("examples/debug/recursive-dash-source.term"),
    Collector = spawn(fun() -> collect(SavedSource, [], []) end),
    MFA = {'svg_path@stroke',subpath_with,4},
    {module,'svg_path@stroke'} = code:ensure_loaded('svg_path@stroke'),
    1 = erlang:trace_pattern(MFA, [{'_',[],[{return_trace}]}], [local]),
    erlang:trace(self(), true, [call,{tracer,Collector}]),
    Drawing = M:recursive_dashes(),
    erlang:trace(self(), false, [call]),
    Ref = erlang:trace_delivered(self()),
    receive {trace_delivered,_,Ref} -> ok end,
    Collector ! {get,self()},
    Matches = receive {matches,Found} -> Found end,
    io:format("Matching stroke calls: ~p~n",[length(Matches)]),
    [{[Source,Join,Cap,Options],{ok,Path}}] = Matches,
    ok = file:write_file("examples/debug/recursive-dash-source.term",
        io_lib:format("~p.~n",[{Source,Join,Cap,Options}])),
    io:format("Source dash: ~p~nResult: ~p~n",[Source,Path]),
    D = 'svg_path@serialize':path(Path),
    SourceD = 'svg_path@serialize':subpath(Source),
    Overlay = ["<path d=\"",D,"\" fill=\"#ff3333\" fill-opacity=\"0.65\" stroke=\"#e00000\" stroke-width=\"1.7\" />\n",
               "<path d=\"",SourceD,"\" fill=\"none\" stroke=\"#b00000\" stroke-width=\"0.7\" />\n",
               "<circle cx=\"430.6702\" cy=\"178.69477\" r=\"8\" fill=\"none\" stroke=\"#e00000\" stroke-width=\"1\" />\n</svg>"],
    Highlight = binary:replace(Drawing, <<"</svg>">>, iolist_to_binary(Overlay)),
    ok = file:write_file("examples/debug/recursive-dashes-highlighted-owner.svg",Highlight).

collect(SavedSource, Stack, Matches) ->
    receive
        {trace,_,call,{'svg_path@stroke',subpath_with,Args}} ->
            collect(SavedSource,[Args|Stack],Matches);
        {trace,_,return_from,{'svg_path@stroke',subpath_with,4},Result} ->
            [Args|Rest] = Stack,
            Found = case Result of
                {ok,_} -> hd(Args) =:= SavedSource;
                _ -> false
            end,
            collect(SavedSource,Rest,case Found of true -> [{Args,Result}|Matches]; false -> Matches end);
        {get,Pid} -> Pid ! {matches,Matches}
    end.
