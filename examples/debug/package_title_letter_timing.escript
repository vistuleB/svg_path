#!/usr/bin/env escript
%% Compare the same isolated S through the production pipeline. Only the
%% private solver switch is changed, in this VM, for the Edward/Henry baseline.
-mode(compile).
main(_) ->
    code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
    M='svg_path@intersections',
    F="build/dev/erlang/svg_path/_gleam_artefacts/svg_path@intersections.erl",
    {ok,Forms}=epp:parse_file(F,[],[]),
    {ok,Input}=file:read_file("examples/debug/package_title.svg"),
    {match,[D]}=re:run(Input,<<" d=\"([^\"]+)\"">>,[{capture,[1],binary}]),
    {ok,{path,[S|_]}}='svg_path@parse':path(D),
    lists:foreach(fun(Mode)->
      Patched=case Mode of elizabeth->Forms;old->[switch(X)||X<-Forms] end,
      {ok,M,Bin}=compile:forms(Patched,[binary,export_all]),
      code:purge(M),{module,M}=code:load_binary(M,F,Bin),
      run(Mode,1,{path,[S]})
    end,[elizabeth,old]).
switch({function,L,curve_curve_intersections,3,
        [{clause,CL,Args,Guards,[{'case',CaseL,{atom,AL,true},Clauses}]}]}) ->
    {function,L,curve_curve_intersections,3,
     [{clause,CL,Args,Guards,[{'case',CaseL,{atom,AL,false},Clauses}]}]};
switch(X)->X.
run(_,3,_)->ok;
run(Mode,N,Path)->
    M='svg_path@intersections',
    Collector=spawn(fun()->collect([],[]) end),
    Fn=case Mode of elizabeth->elizabeth_beam_intersections;old->edward_then_henry_intersections end,
    1=erlang:trace_pattern({M,Fn,3},[{'_',[],[{return_trace}]}],[local]),
    erlang:trace_pattern({M,elizabeth_beam_generation,8},
      [{['_','_','_',[],'_','_','_','_'],[],[]}],[local]),
    erlang:trace(self(),true,[call,{tracer,Collector}]),
    Start=erlang:monotonic_time(microsecond),
    Result='svg_path@offset':path_with(Path,1.04,{miter,4.0},butt,'svg_path@offset':default_options()),
    Elapsed=(erlang:monotonic_time(microsecond)-Start)/1000000,
    erlang:trace(self(),false,[call]),
    Ref=erlang:trace_delivered(self()),receive {trace_delivered,_,Ref}->ok end,
    Collector!{get,self()}, {Calls,Caches}=receive {calls,C,Stats}->{C,Stats} end,
    erlang:trace_pattern({M,Fn,3},false,[local]),
    erlang:trace_pattern({M,elizabeth_beam_generation,8},false,[local]),
    Sorted=lists:reverse(lists:sort(Calls)),
    io:format("~p S offset ~p: ~.3fs; ~p curve-pair calls totaling ~.3fs; ~p~n",
      [Mode,N,Elapsed,length(Calls),lists:sum([T||{T,_,_}<-Calls])/1000000,summary(Result)]),
    io:format("Cache lookups/hits/peak entries: ~p~n",[{lists:sum([L||{L,_,_}<-Caches]),lists:sum([H||{_,H,_}<-Caches]),lists:max([0|[Sz||{_,_,Sz}<-Caches]])}]),
    io:format("Slowest pair timings/results: ~p~n",[[{T/1000000,pair_summary(R)}||{T,_,R}<-lists:sublist(Sorted,8)]]),
    file:write_file("examples/debug/letter-s-"++atom_to_list(Mode)++"-"++integer_to_list(N)++".term",io_lib:format("~p.~n",[{Path,Result,Sorted}])),
    case Result of {ok,Next}->run(Mode,N+1,Next);_->ok end.
summary({ok,{path,S}})->{ok,length(S),lists:sum([length(svg_path:subpath_segments(P))||P<-S])};
summary(E)->E.
pair_summary({ok,{elizabeth_beam_report,Hits,Examined,DC,DO,Peak,Dropped}})->
    {hits,length(Hits),examined,Examined,discarded,DC+DO,peak,Peak,dropped,Dropped};
pair_summary({ok,Hits})->{hits,length(Hits)};
pair_summary(E)->E.
collect(Stack,Calls)->receive
  {trace,_,call,{'svg_path@intersections',elizabeth_beam_generation,[_,_,_,[],_,_,_,Cache]}}->
    Stats=case get(caches) of undefined->[];X->X end,
    put(caches,[{element(3,Cache),element(4,Cache),maps:size(element(2,Cache))}|Stats]),
    collect(Stack,Calls);
  {trace,_,call,{'svg_path@intersections',elizabeth_beam_generation,_}}->collect(Stack,Calls);
  {trace,_,call,{'svg_path@intersections',_,Args}}->collect([{erlang:monotonic_time(microsecond),Args}|Stack],Calls);
  {trace,_,return_from,_,R}->[{T,A}|Rest]=Stack,collect(Rest,[{erlang:monotonic_time(microsecond)-T,A,R}|Calls]);
  {get,P}->P!{calls,Calls,case get(caches) of undefined->[];X->X end}
end.
