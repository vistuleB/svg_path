#!/usr/bin/env escript
-mode(compile).
main([Directory]) ->
    code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
    Parent=self(),
    Gate=spawn(fun()->
      receive {ready,A}->receive {ready,B}->A!go,B!go end end
    end),
    First=fun()->Gate!{ready,self()},receive go->ok end,<<"<svg/>\n">> end,
    Second=fun()->
      Gate!{ready,self()},receive go->ok end,
      await_file(filename:join(Directory,"first.svg"),100),
      Parent!observed_immediate_write,
      error(intentional_fixture_failure)
    end,
    false=gallery_jobs:run([{<<"first.svg">>,<<"first">>,First},
                           {<<"failure.svg">>,<<"failure">>,Second},
                           {<<"killed.svg">>,<<"killed">>,fun()->exit(self(),kill) end}],
                          list_to_binary(Directory)),
    receive observed_immediate_write->ok after 1000->error(no_immediate_write) end,
    {ok,_}=file:read_file(filename:join(Directory,"first.svg")),
    {error,enoent}=file:read_file(filename:join(Directory,"failure.svg")),
    {ok,_}=file:read_file(filename:join(Directory,"failure.svg.error.txt")),
    {ok,Index}=file:read_file(filename:join(Directory,"README.md")),
    nomatch=binary:match(Index,<<"failure.svg">>),
    {ok,Report}=file:read_file(filename:join(Directory,"timings.tsv")),
    true=byte_size(Report)>0,
    io:format("Runner checks passed: concurrent start, immediate write, exception isolation, killed worker, reports.~n").
await_file(_,0)->error(output_not_written);
await_file(Path,N)->case file:read_file(Path) of
  {ok,_}->ok;
  _->timer:sleep(10),await_file(Path,N-1)
end.
