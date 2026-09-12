%%
%% Copyright (c) 2026, Byteplug LLC.
%%
%% This source file is part of a project made by the Erlangsters community and
%% is released under the MIT license. Please refer to the LICENSE.md file that
%% can be found at the root of the project repository.
%%
%% Written by Jonathan De Wachter <jonathan.dewachter@byteplug.io>
%%
-module(graphics_image_nif).
-moduledoc false.

-on_load(init/0).

-export([
    decode_raw/1,
    encode_png_raw/3,
    encode_jpeg_raw/4,
    encode_bmp_raw/3
]).
-export([
    image_from_rgba/3,
    rgba_from_image/1
]).

init() ->
    LibName = "beam-graphics-image",
    LibPath = case code:priv_dir(beam_graphics_image) of
        {error, bad_name} ->
            case filelib:is_dir(filename:join(["..", priv])) of
                true ->
                    filename:join(["..", priv, LibName]);
                _ ->
                    filename:join([priv, LibName])
            end;
        PrivDir ->
            filename:join(PrivDir, LibName)
    end,
    erlang:load_nif(LibPath, undefined).

decode_raw(_Binary) ->
    erlang:nif_error(beam_graphics_image_not_loaded).

encode_png_raw(_Width, _Height, _Rgba) ->
    erlang:nif_error(beam_graphics_image_not_loaded).

encode_jpeg_raw(_Width, _Height, _Rgba, _Quality) ->
    erlang:nif_error(beam_graphics_image_not_loaded).

encode_bmp_raw(_Width, _Height, _Rgba) ->
    erlang:nif_error(beam_graphics_image_not_loaded).

image_from_rgba(Width, Height, Rgba)
  when is_integer(Width), Width >= 1,
       is_integer(Height), Height >= 1,
       is_binary(Rgba),
       byte_size(Rgba) =:= Width * Height * 4 ->
    {Width, Height, pixels_from_rgba(Rgba, [])}.

rgba_from_image({Width, Height, Pixels})
  when is_integer(Width), Width >= 1,
       is_integer(Height), Height >= 1,
       is_list(Pixels),
       length(Pixels) =:= Width * Height ->
    Rgba = iolist_to_binary([rgba_pixel(Color) || Color <- Pixels]),
    {Width, Height, Rgba}.

pixels_from_rgba(<<>>, Acc) ->
    lists:reverse(Acc);
pixels_from_rgba(<<Red, Green, Blue, Alpha, Rest/binary>>, Acc) ->
    pixels_from_rgba(Rest, [graphics_color:from_bytes(Red, Green, Blue, Alpha) | Acc]).

rgba_pixel(Color) ->
    {Red, Green, Blue, Alpha} = graphics_color:to_bytes(Color),
    <<Red, Green, Blue, Alpha>>.
