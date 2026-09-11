-module(format_ffi).
-export([scientific_fixed/2]).

scientific_fixed(Number, DecimalPlaces) ->
    erlang:float_to_binary(Number, [{scientific, DecimalPlaces}]).
