#!/usr/bin/env escript
%% Compare propagation with existing probes on actual production captures.
%% Requires a fast build. No pruning decisions or geometry are changed.
-mode(compile).

main(_) ->
    code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
    [expose(M) || M <- ['svg_path@offset', svg_path_band_trimming_fixture,
                        svg_path_two_corner_square_bands_fixture]],
    F = svg_path_band_trimming_fixture,
    check("closed figure eight", fun() -> F:'band'(F:figure_eight(), true) end),
    S = svg_path_two_corner_square_bands_fixture,
    check("closed concave square", fun() -> S:'band'(S:source_subpath(), true, true) end),
    {ok,{path,[Open]}} = 'svg_path@parse':path(<<"M 0 0 H 10 V 10">>),
    Options = 'svg_path@offset':default_options(),
    [check(io_lib:format("open band caps=~p offsets=~p/~p",[Cap,Inner,Outer]), fun() ->
        {ok,P} = 'svg_path@offset':subpath_band_with(Open, Inner, Outer, round, Cap, Options), P
    end) || Cap <- [butt,round_cap,square], {Inner,Outer} <- [{1.0,2.0},{2.0,1.0},{-2.0,-1.0}]],
    [check(io_lib:format("open single offset ~p caps=~p",[Offset,Cap]), fun() ->
        {ok,P} = 'svg_path@offset':subpath_with(Open, Offset, round, Cap, Options), P
    end) || Cap <- [butt,round_cap,square], Offset <- [1.0,-1.0]],
    {ok,Input} = file:read_file("examples/debug/package_title.svg"),
    {match,[D]} = re:run(Input, <<" d=\"([^\"]+)\"">>, [{capture,[1],binary}]),
    {ok,Source} = 'svg_path@parse':path(D),
    check("lettering single offset 0.4", fun() ->
        {ok,P} = 'svg_path@offset':path_with(Source, 0.4, {miter,4.0}, butt, Options), P
    end).

expose(Module) ->
    Filename = "build/dev/erlang/svg_path/_gleam_artefacts/" ++ atom_to_list(Module) ++ ".erl",
    {ok,Module,Binary} = compile:file(Filename, [binary,export_all]),
    {module,Module} = code:load_binary(Module,Filename,Binary).

check(Label, Run) ->
    Collector = spawn(fun() -> collect([]) end),
    MFA = {'svg_path@offset',delete_winding_mismatched_edges,4},
    erlang:trace_pattern(MFA, true, [local]),
    erlang:trace(self(), true, [call,{tracer,Collector}]),
    _ = Run(),
    erlang:trace(self(), false, [call]),
    Ref = erlang:trace_delivered(self()),
    receive {trace_delivered,_,Ref} -> ok end,
    Collector ! {get,self()},
    Captures = receive {captures,Captured} -> Captured end,
    erlang:trace_pattern(MFA, false, [local]),
    io:format("~s: ~p classification graphs~n",[Label,length(Captures)]),
    [compare(C) || C <- Captures].

collect(Events) ->
    receive
        {trace,_,call,{'svg_path@offset',delete_winding_mismatched_edges,Args}} ->
            collect([Args|Events]);
        {get,Pid} -> Pid ! {captures,lists:reverse(Events)}
    end.

compare([Build,TrimGraph,Winding,Distance]) ->
    Graph = element(2,Build),
    {arrangement_graph,_,Edges,_} = Graph,
    Added = [I || I <- element(3,Build), element(2,I) == winding_closure_segment],
    io:format("  added winding-boundary occurrences: ~p~n",[length(Added)]),
    %% Expected opinions remain independent of actual winding contributions.
    Opinions = maps:from_list([begin
        {ok,Opinion} = 'svg_path@offset':arrangement_edge_winding_opinion(Build,element(2,E)),
        {element(2,E),Opinion}
    end || E <- Edges]),
    case 'svg_path@arrangement':dual(Graph) of
        {error,E} -> io:format("  dual failed: ~p~n",[E]);
        {ok,Dual} ->
            case 'svg_path@offset':with_face_windings(Build) of
                {error,E} -> io:format("  propagation failed: ~p~n",[E]);
                {ok,Prepared} ->
                    {some,PairList} = element(6,Prepared),
                    Pairs = maps:from_list(PairList),
                    Results = [begin
                        Id = element(2,E),
                        {L,R} = maps:get(Id,Pairs),
                        Sampled = 'svg_path@offset':arrangement_edge_sampled_windings(E,Winding,Distance),
                        New = 'svg_path@offset':winding_pair_matches_opinion(maps:get(Id,Opinions),L,R),
                        Old = 'svg_path@offset':arrangement_edge_winding_matches_opinion(Build,E,Winding,Distance),
                        {Id,Sampled,{L,R},Old,New}
                    end || E <- element(3,TrimGraph)],
                    PairDiffs = [R || R={_,S,P,_,_} <- Results, S =/= {ok,P}],
                    ClassDiffs = [R || R={_,_,_,Old,New} <- Results, Old =/= {ok,New}],
                    io:format("  ~p faces; ~p checked edges; ~p winding-pair differences; ~p classification differences~n",
                        [length(element(2,Dual)),length(Results),length(PairDiffs),length(ClassDiffs)]),
                    [io:format("  difference: ~p~n",[R]) || R <- lists:sublist(PairDiffs,10)]
            end
    end.
