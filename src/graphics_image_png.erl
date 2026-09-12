%%
%% Copyright (c) 2026, Byteplug LLC.
%%
%% This source file is part of a project made by the Erlangsters community and
%% is released under the MIT license. Please refer to the LICENSE.md file that
%% can be found at the root of the project repository.
%%
%% Written by Jonathan De Wachter <jonathan.dewachter@byteplug.io>
%%
-module(graphics_image_png).
-moduledoc """
PNG image codec.

It decodes and encodes PNG files as a `graphics:image()`: a width, a height,
and a row-major list of RGBA colors. It does not create a texture. Upload
decoded pixels with `graphics_texture:with_image/1`.

```erlang
{ok, Image} = graphics_image_png:load("sprite.png"),
{ok, Texture} = graphics_texture:with_image(Image).
```

```erlang
ok = graphics_image_png:save(Image, "screenshot.png").
```

Pixels are row-major. X varies fastest, then Y. Slice index `(0, 0)` is the
first pixel and UV `(0, 0)`. The codec does not Y-flip. Gray, RGB, and
palette PNGs are expanded to RGBA with alpha `1.0` when the file has no
alpha.

`decode/1` and `encode/1` work on binaries. `load/1` and `save/2` are file
wrappers. `save/2` takes the image first, then the path.

A binary that is not a PNG is `{error, unsupported_format}`. A PNG that
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
Decode a PNG binary.

It returns a `graphics:image()` when the binary is a PNG. A different
container is `{error, unsupported_format}`.
""".
-spec decode(binary()) ->
    {ok, graphics:image()} | {error, unsupported_format | decode_failed | out_of_memory}.
decode(<<137, 80, 78, 71, 13, 10, 26, 10, _/binary>> = Binary) ->
    decode_image(Binary);
decode(Binary) when is_binary(Binary) ->
    {error, unsupported_format}.

-doc """
Encode an image as a PNG binary.

The image must be a well-formed `graphics:image()`.
""".
-spec encode(graphics:image()) -> binary().
encode(Image) ->
    {Width, Height, Rgba} = graphics_image_nif:rgba_from_image(Image),
    case graphics_image_nif:encode_png_raw(Width, Height, Rgba) of
        {ok, Binary} ->
            Binary;
        {error, out_of_memory} ->
            error(out_of_memory)
    end.

-doc """
Load a PNG file.

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
Save an image as a PNG file.

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
