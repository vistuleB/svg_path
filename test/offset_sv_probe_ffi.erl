-module(offset_sv_probe_ffi).

-export([write_file/2]).

write_file(Path, Contents) ->
    case file:write_file(Path, Contents) of
        ok -> nil;
        {error, Reason} -> erlang:error({write_file_failed, Path, Reason})
    end.
