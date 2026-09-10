#!/usr/bin/env escript
%% Threshold experiments alter only the compiled module in this process.
-mode(compile).
main(_) ->
    code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
    M='svg_path@intersections',
    F="build/dev/erlang/svg_path/_gleam_artefacts/svg_path@intersections.erl",
    {ok,Forms}=epp:parse_file(F,[],[]),
    {ok,[{Build,_}]}=file:consult("examples/debug/elizabeth-figure-eight-winding.term"),
    Indexed=element(3,Build),A=element(4,lists:nth(33,Indexed)),B=element(4,hd(Indexed)),
    lists:foreach(fun(Tol)->
      {ok,M,Bin}=compile:forms(replace(Forms,Tol),[binary,export_all]),
      code:purge(M),{module,M}=code:load_binary(M,F,Bin),
      Collector=spawn(fun()->collect([]) end),
      erlang:trace_pattern({M,elizabeth_terminal_newton,7},true,[local]),
      erlang:trace(self(),true,[call,{tracer,Collector}]),
      R=M:elizabeth_beam_intersections(A,B,M:default_options()),
      erlang:trace(self(),false,[call]),
      Ref=erlang:trace_delivered(self()),receive {trace_delivered,_,Ref}->ok end,
      Collector!{get,self()},Steps=receive {steps,S}->S end,
      Residuals=lists:usort([residual(A,B,T,U)||[_,_,_,T,U,_,_]<-Steps]),
      io:format("threshold ~p result ~p~nsmallest visited residuals ~p~n",[Tol,R,lists:sublist(Residuals,6)]),
      case Tol of
        5.0e-14->
          Seeds=[Args||Args=[_,_,_,_,_,_,8]<-Steps],
          io:format("64-step retries ~p~n",[[M:elizabeth_terminal_newton(SA,SB,W,T,U,ST,64)||[SA,SB,W,T,U,ST,_]<-Seeds]]),
          file:write_file("examples/debug/elizabeth-figure-eight-newton.term",io_lib:format("~p.~n",[Steps]));
        1.0e-13->
          GF="build/dev/erlang/svg_path/_gleam_artefacts/svg_path_gallery_test.erl",
          {ok,GM,GB}=compile:file(GF,[binary,export_all]),
          {module,GM}=code:load_binary(GM,GF,GB),
          Outcome=try GM:figure_eight_band(),ok catch C:E->{C,E} end,
          io:format("Whole figure-eight band at 1e-13: ~p~n",[Outcome]);
        _->ok
      end
    end,[5.0e-14,1.0e-13,1.0e-12]).
replace({float,L,5.0e-14},T)->{float,L,T};
replace(X,T) when is_tuple(X)->list_to_tuple([replace(Y,T)||Y<-tuple_to_list(X)]);
replace(X,T) when is_list(X)->[replace(Y,T)||Y<-X];
replace(X,_)->X.
collect(S)->receive
  {trace,_,call,{'svg_path@intersections',elizabeth_terminal_newton,A}}->collect([A|S]);
  {get,P}->P!{steps,lists:reverse(S)};
  _->collect(S)
end.
residual(A,B,T,U)->
  {ok,{point,X,Y}}=svg_path:segment_point(A,T),
  {ok,{point,V,W}}=svg_path:segment_point(B,U),
  math:sqrt((X-V)*(X-V)+(Y-W)*(Y-W)).
