from pathlib import Path
import re,subprocess
src=Path('build/dev/erlang/svg_path/_gleam_artefacts/svg_path@offset.erl').read_text()
for mode in ['trace','old-source']:
 s=src
 if mode=='trace':
  for name in ['unit_tangent','offset_direction']:
   m=re.search(r'^'+name+r'\(([^\n]+)\) ->\n(.*?)(?=\n\n-file)',s,re.S|re.M)
   assert m
   body=m[2].rstrip();assert body.endswith('.')
   replacement=f'{name}({m[1]}) ->\n Result = begin {body[:-1]} end,\n case Result of {{error,_}} -> io:format("TRACE '+name+' ~p ~p ~p~n",[Segment,T,Result]); _ -> ok end,\n Result.'
   s=s[:m.start()]+replacement+s[m.end():]
 else:
  s=s.replace('normalize_source_subpath(Subpath, _) ->','normalize_source_subpath(Subpath, Options) ->')
  a=s.index("        gleam@result:'try'(gleam@list:try_map",s.index('normalize_source_subpath(Subpath, Options)'))
  b=s.index('\n\n-file',a)
  s=s[:a]+'''        {ok, Short} = normalize_short_source_runs(Subpath@1, 0.001),
        Fitting = erlang:element(2, Options),
        {ok, Cleaned} = svg_path@degeneracy:normalize_degenerate_segments(Short, erlang:element(2, Fitting)),
        case svg_path:subpath_segments(Cleaned) of
          [] -> {ok,Cleaned};
          _ -> colinearize_offset_source_tangents(Cleaned,2.0)
        end
    end).'''+s[b:]
 dest=Path('/tmp/offset-h-'+mode+'-erlang');dest.mkdir(exist_ok=True)
 p=dest/'svg_path@offset.erl';p.write_text(s)
 subprocess.run(['erlc','-o',str(dest),str(p)],check=True)
 print(dest)
