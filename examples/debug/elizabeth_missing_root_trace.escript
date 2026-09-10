#!/usr/bin/env escript
%% Trace actual solver calls; replay only scalar diagnostics, not search logic.
-mode(compile).
main(_) ->
    code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
    M='svg_path@intersections',F="build/dev/erlang/svg_path/_gleam_artefacts/svg_path@intersections.erl",
    {ok,M,Bin}=compile:file(F,[binary,export_all]),{module,M}=code:load_binary(M,F,Bin),
    P=fun(X,Y)->{point,X+100.0,Y+100.0} end,
    D=-0.2*0.21*0.22,C=0.2*0.21+0.2*0.22+0.21*0.22,B=-0.63,
    A={cubic_bezier,P(0.0,D),P(1.0/3,D+C/3),P(2.0/3,D+2*C/3+B/3),P(1.0,D+C+B+1)},
    Q={quadratic_bezier,P(0.0,0.0),P(0.5,0.0),P(1.0,0.0)},
    Collector=spawn(fun()->collect([],[],[],[]) end),
    lists:foreach(fun({Name,Arity})->1=erlang:trace_pattern({M,Name,Arity},[{'_',[],[{return_trace}]}],[local]) end,
      [{window_bounds_overlap,5},{elizabeth_terminal_candidates,4},{elizabeth_terminal_newton,7}]),
    erlang:trace(self(),true,[call,{tracer,Collector}]),
    R=M:experimental_curve_intersections(A,Q,elizabeth,{intersection_options,1.0e-14,48,no_parameter_snap},10000),
    erlang:trace(self(),false,[call]),
    Ref=erlang:trace_delivered(self()),receive {trace_delivered,_,Ref}->ok end,
    Collector!{get,self()},
    {Bounds,Terminals,Steps}=receive {data,Bs,Ts,Ss}->{Bs,Ts,Ss} end,
    io:format("Result: ~p~n",[R]),
    {ok,Hits}=R,
    [Missing]=[Root||Root<-[0.2,0.21,0.22],not lists:any(fun({segment_intersection,T,U,_})->abs(T-Root)<1.0e-7 andalso abs(U-Root)<1.0e-7 end,Hits)],
    io:format("Missing expected root: ~p~n",[Missing]),
    Zeroes=[T||I<-lists:seq(-1000,1000),T<-[Missing+I*1.0e-11],residual(A,Q,T,T)=<0.0],
    [Witness|_]=Zeroes,
    io:format("Zero-residual witness: ~p (sampled ~p zeroes)~n",[Witness,length(Zeroes)]),
    io:format("Enclosure decisions containing witness: ~p~n",[[{W,V}||{W,V}<-Bounds,inside(W,Witness,Witness)]]),
    Target=[W||W<-Terminals,inside(W,Witness,Witness)],
    io:format("Terminal windows containing witness: ~p~n",[Target]),
    Relevant=[Args||Args=[_,_,W,_,_,_,_]<-Steps,lists:member(W,Target)],
    lists:foreach(fun(Args)->io:format("Newton: ~p~n",[diagnose(Args)]) end,Relevant),
    Seeds=[Args||Args=[_,_,_,_,_,_,8]<-Relevant],
    Retry=[M:elizabeth_terminal_newton(SA,SB,W,T,U,Tol,64)||[SA,SB,W,T,U,Tol,_]<-Seeds],
    io:format("Same six terminal seeds with 64 iterations: ~p~n",[Retry]),
    io:format("All nearby Newton exit counts: ~p~n",[lists:foldl(fun(Args=[_,_,_,T,U,_,_],Acc)->
      case abs(T-Missing)<1.0e-7 andalso abs(U-Missing)<1.0e-7 of
        true->Key=element(1,diagnose(Args)),maps:update_with(Key,fun(N)->N+1 end,1,Acc);
        false->Acc end end,#{},Steps)]).

collect(Stack,Bounds,Terms,Steps)->receive
  {trace,_,call,{'svg_path@intersections',window_bounds_overlap,[_,_,W,_,_]}}->collect([W|Stack],Bounds,Terms,Steps);
  {trace,_,return_from,{'svg_path@intersections',window_bounds_overlap,5},R}->[W|Rest]=Stack,collect(Rest,[{W,R}|Bounds],Terms,Steps);
  {trace,_,call,{'svg_path@intersections',elizabeth_terminal_candidates,[_,_,W,_]}}->collect(Stack,Bounds,[W|Terms],Steps);
  {trace,_,call,{'svg_path@intersections',elizabeth_terminal_newton,Args}}->collect(Stack,Bounds,Terms,[Args|Steps]);
  {get,P}->P!{data,lists:reverse(Bounds),lists:reverse(Terms),lists:reverse(Steps)};
  _->collect(Stack,Bounds,Terms,Steps)
end.
inside({window_preserving_window,A,B,C,D},T,U)->T>=A andalso T=<B andalso U>=C andalso U=<D.
residual(A,B,T,U)->{ok,{point,X,Y}}=svg_path:segment_point(A,T),{ok,{point,V,W}}=svg_path:segment_point(B,U),math:sqrt((X-V)*(X-V)+(Y-W)*(Y-W)).
diagnose([A,B,Window,T,U,Tol,N])->
    R=residual(A,B,T,U),
    case R=<Tol of
      true->{accepted,T,U,R,N};
      false when N=<0->{iterations,T,U,R,N};
      false->
        {ok,{point,Px,Py}}=svg_path:segment_point(A,T),{ok,{point,Qx,Qy}}=svg_path:segment_point(B,U),
        {ok,V={point,Vx,Vy}}=svg_path:segment_derivative(A,T),{ok,W={point,Wx,Wy}}=svg_path:segment_derivative(B,U),
        case 'svg_path@intersections':directions_are_independent(V,W) of
          false->{singular,T,U,R,N};
          true->Det=Vx*Wy-Vy*Wx,Dx=Qx-Px,Dy=Qy-Py,NT=T+(Dx*Wy-Dy*Wx)/Det,NU=U-(Vx*Dy-Vy*Dx)/Det,
            Kind=case inside(Window,NT,NU) of false->escaped;true when NT=:=T,NU=:=U->stagnant;true->step end,
            {Kind,T,U,R,N,NT,NU}
        end
    end.
