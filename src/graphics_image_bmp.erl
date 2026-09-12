%%
%% Copyright (c) 2026, Byteplug LLC.
%%
%% This source file is part of a project made by the Erlangsters community and
%% is released under the MIT license. Please refer to the LICENSE.md file that
%% can be found at the root of the project repository.
%%
%% Written by Jonathan De Wachter <jonathan.dewachter@byteplug.io>
%%
-module(graphics_image_bmp).
-moduledoc """
BMP image codec.

It decodes and encodes BMP files as a `graphics:image()`: a width, a height,
and a row-major list of RGBA colors. It does not create a texture. Upload
decoded pixels with `graphics_texture:with_image/1`.

```erlang
{ok, Image} = graphics_image_bmp:load("sprite.bmp"),
{ok, Texture} = graphics_texture:with_image(Image).
```

```erlang
ok = graphics_image_bmp:save(Image, "screenshot.bmp").
```

Pixels are row-major. X varies fastest, then Y. Slice index `(0, 0)` is the
first pixel and UV `(0, 0)`. The codec does not Y-flip. Files without alpha
are expanded to alpha `1.0`. `encode/1` writes 24-bit BMP and drops alpha.

`decode/1` and `encode/1` work on binaries. `load/1` and `save/2` are file
wrappers. `save/2` takes the image first, then the path.

A binary that is not a BMP is `{error, unsupported_format}`. A BMP that
cannot be decoded is `{error, decode_failed}`. Missing files and other I/O
failures are `{error, Reason}` from `file`. A well-formed image always
encodes to a binary. Native writer failure raises `out_of_memory`.

Beware that a well-formed image uses floats for color channels, not integers.
""".

-export([
    decode/1,
    encode/1,
    load/1,
    save/2
]).

-doc """
Decode a BMP binary.

It returns a `graphics:image()` when the binary is a BMP. A different
container is `{error, unsupported_format}`.
""".
-spec decode(binary()) ->
    {ok, graphics:image()} | {error, unsupported_format | decode_failed | out_of_memory}.
decode(<<"BM", _/binary>> = Binary) ->
    decode_image(Binary);
decode(Binary) when is_binary(Binary) ->
    {error, unsupported_format}.

-doc """
Encode an image as a BMP binary.

The image must be a well-formed `graphics:image()`. Alpha is dropped.
""".
-spec encode(graphics:image()) -> binary().
encode(Image) ->
    {Width, Height, Rgba} = graphics_image_nif:rgba_from_image(Image),
    case graphics_image_nif:encode_bmp_raw(Width, Height, Rgba) of
        {ok, Binary} ->
            Binary;
        {error, out_of_memory} ->
            error(out_of_memory)
    end.

-doc """
Load a BMP file.

It reads the file and decodes it as a `graphics:image()`.
""".
-spec load(file:name_all()) ->
    {ok, graphics:image()} |
    {error, unsupported_format | decode_failed | out_of_memory | file:posix() | badarg}.
load(Filename) when is_list(Filename); is_binary(Filename); is_atom(Filename) ->
    case file:read_file(Filename) of
        {ok, Binary} ->
            decode(Binary);
        {error, Reason} ->
            {error, Reason}
    end.

-doc """
Save an image as a BMP file.

It's equivalent to writing `encode(Image)` to `Filename`.
""".
-spec save(graphics:image(), file:name_all()) ->
    ok | {error, file:posix() | badarg}.
save(Image, Filename) when is_list(Filename); is_binary(Filename); is_atom(Filename) ->
    file:write_file(Filename, encode(Image)).

decode_image(Binary) ->
    case graphics_image_nif:decode_raw(Binary) of
        {ok, {Width, Height, Rgba}} ->
            {ok, graphics_image_nif:image_from_rgba(Width, Height, Rgba)};
        {error, Reason} ->
            {error, Reason}
    end.
