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

```erlang
{deps, [
  {beam_graphics, {git, "https://github.com/erlangsters/beam-graphics.git", {tag, "master"}}},
  {beam_graphics_image, {git, "https://github.com/erlangsters/beam-graphics-image.git", {tag, "master"}}}
]}.
```

Written by the Erlangsters [community](https://about.erlangsters.org/) and
released under the MIT [license](/https://opensource.org/license/mit).
