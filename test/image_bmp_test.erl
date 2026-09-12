%%
%% Copyright (c) 2026, Byteplug LLC.
%%
%% This source file is part of a project made by the Erlangsters community and
%% is released under the MIT license. Please refer to the LICENSE.md file that
%% can be found at the root of the project repository.
%%
%% Written by Jonathan De Wachter <jonathan.dewachter@byteplug.io>
%%
-module(image_bmp_test).
-include_lib("eunit/include/eunit.hrl").
-include_lib("beam_graphics/include/graphics.hrl").

-define(IMAGE, {2, 2, [
    ?COLOR_RED, ?COLOR_GREEN,
    ?COLOR_BLUE, ?COLOR_WHITE
]}).

image_bmp_roundtrip_test() ->
    Binary = image_bmp:encode(?IMAGE),
    <<"BM", _/binary>> = Binary,
    {ok, Decoded} = image_bmp:decode(Binary),
    true = image_equal(Decoded, ?IMAGE),
    ok.

image_bmp_drops_alpha_test() ->
    Image = {1, 1, [?COLOR_TRANSPARENT]},
    {ok, {1, 1, [Color]}} = image_bmp:decode(image_bmp:encode(Image)),
    true = color:is_equal_to(Color, ?COLOR_BLACK),
    ok.

image_bmp_load_save_test() ->
    Path = tmp_path(".bmp"),
    ok = image_bmp:save(?IMAGE, Path),
    {ok, Decoded} = image_bmp:load(Path),
    true = image_equal(Decoded, ?IMAGE),
    ok = file:delete(Path),
    ok.

image_bmp_unsupported_format_test() ->
    {error, unsupported_format} = image_bmp:decode(<<"not a bmp">>),
    Png = image_png:encode(?IMAGE),
    {error, unsupported_format} = image_bmp:decode(Png),
    ok.

image_bmp_decode_failed_test() ->
    {error, decode_failed} = image_bmp:decode(<<"BM", 0, 1, 2>>),
    ok.

image_bmp_missing_file_test() ->
    {error, enoent} = image_bmp:load("beam-graphics-image-missing-bmp-test.bmp"),
    ok.

image_bmp_badarg_test() ->
    ?assertError(function_clause, image_bmp:encode(not_an_image)),
    ?assertError(function_clause, image_bmp:decode(not_a_binary)),
    ?assertError(function_clause, image_bmp:load(123)),
    ok.

image_equal({Width, Height, Left}, {Width, Height, Right}) ->
    lists:all(
        fun({A, B}) -> color:is_equal_to(A, B) end,
        lists:zip(Left, Right)
    ).

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
