# Image loader/saver for the BEAM graphics library

> :construction: This project is under active development. Do not used at the
> moment as it's not ready. Consult the `develop` branch for progress.

[![Erlangsters Repository](https://img.shields.io/badge/erlangsters-beam--graphics--image-%23a90432)](https://github.com/erlangsters/beam-graphics-image)
![Supported Erlang/OTP Versions](https://img.shields.io/badge/erlang%2Fotp-28-%23a90432)
![Current Version](https://img.shields.io/badge/version-0.1.0-%23354052)
![License](https://img.shields.io/github/license/erlangsters/beam-graphics-image)
[![Build Status](https://img.shields.io/github/actions/workflow/status/erlangsters/beam-graphics-image/workflow.yml)](https://github.com/erlangsters/beam-graphics-image/actions/workflows/workflow.yml)
[![Documentation Link](https://img.shields.io/badge/documentation-available-yellow)](http://erlangsters.github.io/beam-graphics-image/)

A helper library to complement the [graphics library](https://github.com/erlangsters/beam-graphics)
of the BEAM ecosystem and load images into ready-to-use textures.

It decodes and encodes PNG, JPEG, and BMP as a `graphics:image()`. It does not
draw and it does not create a GPU texture. Upload pixels with
`texture:with_image/1`.

```erlang
{ok, Image} = image_png:load("sprite.png"),
{ok, Texture} = texture:with_image(Image).
```

```erlang
Image = surface:image(Surface),
ok = image_png:save(Image, "screenshot.png").
```

`decode/1` and `encode/1` work on binaries. `load/1` and `save/2` are file
wrappers. `save/2` takes the image first, then the path.

Supported formats:

- PNG (`image_png`)
- JPEG (`image_jpeg`), quality 90, no alpha
- BMP (`image_bmp`), 24-bit on encode, no alpha

Pixels are row-major RGBA colors. X varies fastest, then Y. `(0, 0)` is the
first pixel. The codec does not Y-flip. Gray, RGB, and palette sources expand
to alpha `1.0`.

The native backend is stb_image and stb_image_write. Building the NIF requires
CMake.

Written by the Erlangsters [community](https://about.erlangsters.org/) and
released under the MIT [license](/https://opensource.org/license/mit).

## Using it in your project

With the **Rebar3** build system, add the following to the `rebar.config` file
of your project.

```erlang
{deps, [
  {beam_graphics, {git, "https://github.com/erlangsters/beam-graphics.git", {tag, "master"}}},
  {beam_graphics_image, {git, "https://github.com/erlangsters/beam-graphics-image.git", {tag, "master"}}}
]}.
```

In practice, you want to replace the branch "master" with a specific tag to
avoid breaking your project if incompatible changes are made.

## Later

These stay out of the current slice:

- a sniffer `image:load/1` that dispatches on magic bytes
- `load_texture` / `with_texture` (needs a live graphics context)
- GIF, WebP, HDR, TIFF, and animation
- a Y-flip option (the texture API does not flip)
- color space on the image (belongs on `texture`)
- JPEG quality arity and PNG filter or compression options
- 16-bit and float images
- the `graphics_` module prefix (cross-library rename)
- a GPU-backed `decode → texture:with_image → remote_image` test
