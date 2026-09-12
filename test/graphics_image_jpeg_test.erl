%%
%% Copyright (c) 2026, Byteplug LLC.
%%
%% This source file is part of a project made by the Erlangsters community and
%% is released under the MIT license. Please refer to the LICENSE.md file that
%% can be found at the root of the project repository.
%%
%% Written by Jonathan De Wachter <jonathan.dewachter@byteplug.io>
%%
-module(graphics_image_jpeg_test).
-include_lib("eunit/include/eunit.hrl").
-include_lib("beam_graphics/include/graphics.hrl").

-define(IMAGE, {2, 2, [
    ?COLOR_RED, ?COLOR_GREEN,
    ?COLOR_BLUE, ?COLOR_WHITE
]}).
-define(JPEG_EPS, 0.15).

image_jpeg_roundtrip_test() ->
    Solid = {4, 4, lists:duplicate(16, ?COLOR_RED)},
    Binary = graphics_image_jpeg:encode(Solid),
    <<16#FF, 16#D8, 16#FF, _/binary>> = Binary,
    {ok, {4, 4, Pixels}} = graphics_image_jpeg:decode(Binary),
    16 = length(Pixels),
    lists:foreach(
        fun(Color) ->
            true = graphics_color:is_equal_to(Color, ?COLOR_RED, ?JPEG_EPS),
            1.0 = graphics_color:alpha(Color)
        end,
        Pixels
    ),
    ok.

image_jpeg_mixed_roundtrip_test() ->
    Binary = graphics_image_jpeg:encode(?IMAGE),
    {ok, {2, 2, Pixels}} = graphics_image_jpeg:decode(Binary),
    4 = length(Pixels),
    lists:foreach(
        fun({R, G, B, A}) ->
            true = R >= 0.0 andalso R =< 1.0,
            true = G >= 0.0 andalso G =< 1.0,
            true = B >= 0.0 andalso B =< 1.0,
            1.0 = A
        end,
        Pixels
    ),
    ok.

image_jpeg_load_save_test() ->
    Path = tmp_path(".jpeg"),
    Solid = {4, 4, lists:duplicate(16, ?COLOR_RED)},
    ok = graphics_image_jpeg:save(Solid, Path),
    {ok, {4, 4, Pixels}} = graphics_image_jpeg:load(Path),
    16 = length(Pixels),
    ok = file:delete(Path),
    ok.

image_jpeg_unsupported_format_test() ->
    {error, unsupported_format} = graphics_image_jpeg:decode(<<"not a jpeg">>),
    Png = graphics_image_png:encode(?IMAGE),
    {error, unsupported_format} = graphics_image_jpeg:decode(Png),
    ok.

image_jpeg_decode_failed_test() ->
    {error, decode_failed} = graphics_image_jpeg:decode(<<16#FF, 16#D8, 16#FF, 0, 1, 2>>),
    ok.

image_jpeg_missing_file_test() ->
    {error, enoent} = graphics_image_jpeg:load("beam-graphics-image-missing-jpeg-test.jpeg"),
    ok.

image_jpeg_badarg_test() ->
    ?assertError(function_clause, graphics_image_jpeg:encode(not_an_image)),
    ?assertError(function_clause, graphics_image_jpeg:decode(not_a_binary)),
    ?assertError(function_clause, graphics_image_jpeg:load(123)),
    ok.

tmp_path(Ext) ->
    Name = "bgi-" ++ integer_to_list(erlang:unique_integer([positive])) ++ Ext,
    filename:join(tmpdir(), Name).

tmpdir() ->
    case os:getenv("TMPDIR") of
        false ->
            "/tmp";
        Dir ->
            Dir
    end.
