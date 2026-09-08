-module(affine_ffi).
-export([with_arithmetic_errors/2]).

with_arithmetic_errors(Compute, Overflow) ->
    try Compute()
    catch
        error:badarith -> {error, Overflow}
    end.
