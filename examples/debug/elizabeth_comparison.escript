#!/usr/bin/env escript
%% Direct solver comparison: no production dispatch or fallback.
-mode(compile).
main(_) ->
    code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
    P=fun(X,Y)->{point,X,Y} end,
    Flat={quadratic_bezier,P(0.0,0.0),P(0.5,0.0),P(1.0,0.0)},
    D=-0.2*0.21*0.22,C=0.2*0.21+0.2*0.22+0.21*0.22,B=-0.63,
    Cluster={cubic_bezier,P(0.0,D),P(1.0/3,D+C/3),P(2.0/3,D+2*C/3+B/3),P(1.0,D+C+B+1)},
    Kiss={quadratic_bezier,P(0.0,0.25),P(0.5,-0.25),P(1.0,0.25)},
    lists:foreach(fun({Label,Curve})->
      lists:foreach(fun(Solver)->
        {Micros,Result}=timer:tc(fun()->'svg_path@intersections':experimental_curve_intersections(
          Curve,Flat,Solver,'svg_path@intersections':default_options()) end),
        Summary=case Result of
          {ok,Hits}->{ok,length(Hits),[{T,U}||{segment_intersection,T,U,_}<-Hits]};
          Error->Error
        end,
        io:format("~s ~p time=~pms: ~p~n",[Label,Solver,Micros div 1000,Summary])
      end,[henry,edward,elizabeth])
    end,[{"clustered crossings",Cluster},{"kissing quadratics",Kiss}]).
