#!/usr/bin/env escript
%% The saved source/arguments come directly from a traced fixture stroke call.
%% All stroke geometry is recomputed through the public API. Mapping below
%% is display-only translation and uniform scaling, after computation.
-mode(compile).

main(["current"]) -> current();
main(["culling"]) -> culling();
main(["before-caps"]) -> before_caps();
main(_) -> current().

before_caps() ->
    code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
    {ok,[{Source,Join,Cap,Options}]} = file:consult("examples/debug/recursive-dash-source.term"),
    {module,'svg_path@offset'} = code:ensure_loaded('svg_path@offset'),
    Collector = spawn(fun() -> collect_sides([]) end),
    MFA = {'svg_path@offset',band_from_sides,5},
    1 = erlang:trace_pattern(MFA,true,[local]),
    erlang:trace(self(),true,[call,{tracer,Collector}]),
    {ok,_} = 'svg_path@stroke':subpath_with(Source,Join,Cap,Options),
    erlang:trace(self(),false,[call]),
    Ref=erlang:trace_delivered(self()),receive {trace_delivered,_,Ref}->ok end,
    Collector!{get,self()},
    Calls=receive {sides,Found}->Found end,
    [[Inner,-3.0,Outer,3.0,round_cap]] = Calls,
    io:format("Actual pre-cap assembly inputs:~n~p~n",[Calls]),
    ok=file:write_file("examples/debug/recursive-dash-pre-caps.term",io_lib:format("~p.~n",[Calls])),
    {ok,{bounding_box,{point,X0,Y0},{point,X1,Y1}}} = svg_path:path_bounding_box({path,[Inner,Outer]}),
    Scale=min(810.0/(X1-X0),400.0/(Y1-Y0)),
    Map={X0,Y0,Scale,455.0-(X1-X0)*Scale/2.0,290.0-(Y1-Y0)*Scale/2.0},
    Inset={430.67020274716174,178.69477407757557,Scale*200.0,1150.0,290.0},
    Layers=fun(M)->[
        path(svg_path:subpath_segments(Inner),false,M,"none","#2475b5",0.8),
        path(svg_path:subpath_segments(Outer),false,M,"none","#222",0.8),
        [dot(element(2,S),M)||S<-svg_path:subpath_segments(Inner)++svg_path:subpath_segments(Outer)],
        dot(svg_path:subpath_end(Inner),M),dot(svg_path:subpath_end(Outer),M)] end,
    Drawing=["<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1400\" height=\"560\" viewBox=\"0 0 1400 560\">",
        "<rect x=\"0\" y=\"0\" width=\"1400\" height=\"560\" fill=\"white\"/>",
        "<defs><clipPath id=\"detail\"><rect x=\"940\" y=\"60\" width=\"430\" height=\"410\"/></clipPath></defs>",
        "<text x=\"35\" y=\"35\" font-family=\"sans-serif\" font-size=\"18\">Actual offset sides immediately before adding caps</text>",
        "<text x=\"955\" y=\"35\" font-family=\"sans-serif\" font-size=\"18\">Local detail: 200x overview scale</text>",
        Layers(Map),"<g clip-path=\"url(#detail)\">",Layers(Inset),"</g>",
        "<path d=\"M 915 60 V 490\" stroke=\"#ddd\" stroke-width=\"0.6\"/>",
        "<text x=\"35\" y=\"520\" font-family=\"sans-serif\" font-size=\"14\">Blue: inner (-3). Black: outer (+3). Dots: segment endpoints. No caps or final trimming.</text>",
        "<text x=\"955\" y=\"505\" font-family=\"sans-serif\" font-size=\"14\">Around the later two-arc contour</text></svg>"],
    ok=file:write_file("examples/debug/recursive-dash-before-caps.svg",Drawing).

collect_sides(Calls) ->
    receive
        {trace,_,call,{'svg_path@offset',band_from_sides,Args}} -> collect_sides([Args|Calls]);
        {get,Pid} -> Pid!{sides,lists:reverse(Calls)}
    end.

culling() ->
    code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
    {ok,[{Source,Join,Cap,Options}]}=file:consult("examples/debug/recursive-dash-source.term"),
    {module,'svg_path@offset'}=code:ensure_loaded('svg_path@offset'),
    Collector=spawn(fun()->collect_culling([],[]) end),
    MFA={'svg_path@offset',cull_adjacent_preimage_loops,1},
    1=erlang:trace_pattern(MFA,[{'_',[],[{return_trace}]}],[local]),
    erlang:trace(self(),true,[call,{tracer,Collector}]),
    {ok,_}='svg_path@stroke':subpath_with(Source,Join,Cap,Options),
    erlang:trace(self(),false,[call]),
    R=erlang:trace_delivered(self()),receive {trace_delivered,_,R}->ok end,
    Collector!{get,self()},Captured=receive {culled,X}->X end,
    [{Before,After}]=[{H,I}||{H,I}<-Captured,element(4,H)=:=outer],
    BeforeSegments=[element(2,H)||H<-element(2,Before)],
    AfterSegments=[element(2,I)||I<-element(2,After)],
    Unchanged=BeforeSegments=:=AfterSegments,
    io:format("Exact geometry unchanged: ~p~n",[Unchanged]),
    io:format("Retained preimage intervals: ~p~n",[[{element(4,I),element(5,I)}||I<-element(2,After)]]),
    [Prev,J,Next]=AfterSegments,
    io:format("After culling join/line intersection: ~p~n",['svg_path@intersections':segment(J,Next)]),
    ok=file:write_file("examples/debug/recursive-dash-culling-capture.term",io_lib:format("~p.~n",[{Before,After}])),
    {ok,{bounding_box,{point,X0,Y0},{point,X1,Y1}}}=svg_path:segment_bounding_box(J),
    S=min(400.0/(X1-X0),280.0/(Y1-Y0)),
    M={0.5*(X0+X1),0.5*(Y0+Y1),S,300.0,235.0},
    N={0.5*(X0+X1),0.5*(Y0+Y1),S,900.0,235.0},
    Draw=fun([A,B,C],Map)->[
        path([A],false,Map,"none","#222",0.8),
        path([B],false,Map,"none","#d22",0.8),
        path([C],false,Map,"none","#2475b5",0.8),
        dot(element(2,B),Map),dot(element(7,B),Map)] end,
    Drawing=["<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1200\" height=\"480\" viewBox=\"0 0 1200 480\">",
        "<rect x=\"0\" y=\"0\" width=\"1200\" height=\"480\" fill=\"white\"/>",
        "<defs><clipPath id=\"left\"><rect x=\"30\" y=\"65\" width=\"540\" height=\"335\"/></clipPath><clipPath id=\"right\"><rect x=\"630\" y=\"65\" width=\"540\" height=\"335\"/></clipPath></defs>",
        "<text x=\"30\" y=\"35\" font-family=\"sans-serif\" font-size=\"18\">Before small-loop culling: outer join</text>",
        "<text x=\"630\" y=\"35\" font-family=\"sans-serif\" font-size=\"18\">After small-loop culling: ",
        case Unchanged of true->"unchanged";false->"join and line shortened" end,"</text>",
        "<g clip-path=\"url(#left)\">",Draw(BeforeSegments,M),"</g>",
        "<g clip-path=\"url(#right)\">",Draw([Prev,J,Next],N),"</g>",
        "<text x=\"30\" y=\"445\" font-family=\"sans-serif\" font-size=\"15\">Black: preceding arc. Red: reversed join. Blue: following line. Dots: join endpoints.</text></svg>"],
    ok=file:write_file("examples/debug/recursive-dash-before-after-culling.svg",Drawing).

current() ->
    code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
    {ok,[{Source,Join,Cap,Options}]}=file:consult("examples/debug/recursive-dash-source.term"),
    {ok,{path,Subs}=Result}='svg_path@stroke':subpath_with(Source,Join,Cap,Options),
    io:format("Current isolated final result (~p subpaths): ~p~n",[length(Subs),Result]),
    {ok,{bounding_box,{point,X0,Y0},{point,X1,Y1}}}=svg_path:path_bounding_box(Result),
    S=min(1000.0/(X1-X0),420.0/(Y1-Y0)),
    Map={X0,Y0,S,550.0-(X1-X0)*S/2.0,280.0-(Y1-Y0)*S/2.0},
    Drawing=["<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1100\" height=\"560\" viewBox=\"0 0 1100 560\">",
        "<rect x=\"0\" y=\"0\" width=\"1100\" height=\"560\" fill=\"white\"/>",
        "<text x=\"30\" y=\"30\" font-family=\"sans-serif\" font-size=\"18\">Final isolated dash after the shared-endpoint culling fix</text>",
        [path(svg_path:subpath_segments(P),svg_path:subpath_is_closed(P),Map,"#f1f5f9","#222",0.8)||P<-Subs],
        path(svg_path:subpath_segments(Source),false,Map,"none","#aaa",0.65),"</svg>"],
    ok=file:write_file("examples/debug/recursive-dash-isolated-current.svg",Drawing),
    M=svg_path_gallery_test,
    F="build/dev/erlang/svg_path/_gleam_artefacts/svg_path_gallery_test.erl",
    {ok,M,B}=compile:file(F,[binary,export_all]),
    {module,M}=code:load_binary(M,F,B),
    ok=file:write_file("examples/debug/recursive-dashes-current.svg",M:recursive_dashes()).

collect_culling(Stack,Pairs) ->
    receive
        {trace,_,call,{'svg_path@offset',cull_adjacent_preimage_loops,[H]}}->collect_culling([H|Stack],Pairs);
        {trace,_,return_from,{'svg_path@offset',cull_adjacent_preimage_loops,1},{ok,I}}->
            [H|Rest]=Stack,collect_culling(Rest,[{H,I}|Pairs]);
        {get,P}->P!{culled,Pairs}
    end.

n(X) -> float_to_binary(float(X),[short]).
point({point,X,Y},{X0,Y0,S,DX,DY}) -> {point,(X-X0)*S+DX,(Y-Y0)*S+DY}.
p(P,M) -> {point,X,Y}=point(P,M),[n(X)," ",n(Y)].
segment({line,_,Z},M) -> [" L ",p(Z,M)];
segment({cubic_bezier,_,A,B,Z},M) -> [" C ",p(A,M)," ",p(B,M)," ",p(Z,M)];
segment({arc,_,{point,RX,RY},Rot,Large,Sweep,Z},M={_,_,S,_,_}) ->
    [" A ",n(RX*S)," ",n(RY*S)," ",n(Rot)," ",flag(Large)," ",flag(Sweep)," ",p(Z,M)].
flag(true)->"1";flag(false)->"0".
path(Segs,Closed,M,Fill,Stroke,Width) ->
    First=hd(Segs), Start=element(2,First),
    ["<path d=\"M ",p(Start,M),[segment(S,M)||S<-Segs],
      case Closed of true->" Z";false->"" end,
      "\" fill=\"",Fill,"\" stroke=\"",Stroke,"\" stroke-width=\"",n(Width),"\"/>\n"].
dot(P,M) ->
    {point,X,Y}=point(P,M),
    ["<circle cx=\"",n(X),"\" cy=\"",n(Y),"\" r=\"2\" fill=\"#222\"/>"] .
