%%
%% Copyright (c) 2026, Byteplug LLC.
%%
%% This source file is part of a project made by the Erlangsters community and
%% is released under the MIT license. Please refer to the LICENSE.md file that
%% can be found at the root of the project repository.
%%
%% Written by Jonathan De Wachter <jonathan.dewachter@byteplug.io>
%%
-module(graphics_image_png_test).
-include_lib("eunit/include/eunit.hrl").
-include_lib("beam_graphics/include/graphics.hrl").

-define(IMAGE, {2, 2, [
    ?COLOR_RED, ?COLOR_GREEN,
    ?COLOR_BLUE, ?COLOR_WHITE
]}).

image_png_roundtrip_test() ->
    Binary = graphics_image_png:encode(?IMAGE),
    <<137, 80, 78, 71, 13, 10, 26, 10, _/binary>> = Binary,
    {ok, Decoded} = graphics_image_png:decode(Binary),
    true = image_equal(Decoded, ?IMAGE),
    ok.

image_png_transparent_test() ->
    Image = {1, 1, [?COLOR_TRANSPARENT]},
    {ok, Decoded} = graphics_image_png:decode(graphics_image_png:encode(Image)),
    true = image_equal(Decoded, Image),
    ok.

image_png_gray_fixture_test() ->
    Binary = raw_png(1, 1, 0, <<128>>),
    {ok, {1, 1, [Color]}} = graphics_image_png:decode(Binary),
    Expected = graphics_color:from_bytes(128, 128, 128, 255),
    true = graphics_color:is_equal_to(Color, Expected),
    ok.

image_png_rgb_fixture_test() ->
    Binary = raw_png(1, 1, 2, <<255, 0, 0>>),
    {ok, {1, 1, [Color]}} = graphics_image_png:decode(Binary),
    true = graphics_color:is_equal_to(Color, ?COLOR_RED),
    ok.

image_png_load_save_test() ->
    Path = tmp_path(".png"),
    ok = graphics_image_png:save(?IMAGE, Path),
    {ok, Decoded} = graphics_image_png:load(Path),
    true = image_equal(Decoded, ?IMAGE),
    ok = file:delete(Path),
    ok.

image_png_unsupported_format_test() ->
    {error, unsupported_format} = graphics_image_png:decode(<<"not a png">>),
    Jpeg = graphics_image_jpeg:encode(?IMAGE),
    {error, unsupported_format} = graphics_image_png:decode(Jpeg),
    ok.

image_png_decode_failed_test() ->
    {error, decode_failed} = graphics_image_png:decode(<<137, 80, 78, 71, 13, 10, 26, 10, 0, 1, 2>>),
    ok.

image_png_missing_file_test() ->
    {error, enoent} = graphics_image_png:load("beam-graphics-image-missing-png-test.png"),
    ok.

image_png_badarg_test() ->
    ?assertError(function_clause, graphics_image_png:encode(not_an_image)),
    ?assertError(function_clause, graphics_image_png:encode({0, 1, [?COLOR_RED]})),
    ?assertError(function_clause, graphics_image_png:encode({1, 1, []})),
    ?assertError(function_clause, graphics_image_png:decode(not_a_binary)),
    ?assertError(function_clause, graphics_image_png:load(123)),
    ok.

image_equal({Width, Height, Left}, {Width, Height, Right}) ->
    lists:all(
        fun({A, B}) -> graphics_color:is_equal_to(A, B) end,
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

raw_png(Width, Height, ColorType, PixelBytes) ->
    BytesPerPixel = byte_size(PixelBytes) div (Width * Height),
    Rows = split_rows(PixelBytes, Width * BytesPerPixel),
    Scanlines = << <<0, Row/binary>> || Row <- Rows >>,
    Signature = <<137, 80, 78, 71, 13, 10, 26, 10>>,
    IHDR = png_chunk(<<"IHDR">>, <<Width:32, Height:32, 8, ColorType, 0, 0, 0>>),
    IDAT = png_chunk(<<"IDAT">>, zlib:compress(Scanlines)),
    IEND = png_chunk(<<"IEND">>, <<>>),
    <<Signature/binary, IHDR/binary, IDAT/binary, IEND/binary>>.

png_chunk(Type, Data) ->
    CRC = erlang:crc32(<<Type/binary, Data/binary>>),
    <<(byte_size(Data)):32, Type/binary, Data/binary, CRC:32>>.

split_rows(<<>>, _RowSize) ->
    [];
split_rows(Bytes, RowSize) ->
    <<Row:RowSize/binary, Rest/binary>> = Bytes,
    [Row | split_rows(Rest, RowSize)].
