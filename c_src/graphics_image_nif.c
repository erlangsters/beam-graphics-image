/*
    Copyright (c) 2026, Byteplug LLC.

    This source file is part of a project made by the Erlangsters community and
    is released under the MIT license. Please refer to the LICENSE.md file that
    can be found at the root of the project repository.

    Written by Jonathan De Wachter <jonathan.dewachter@byteplug.io>
*/

#include <erl_nif.h>
#include <limits.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define STBI_ASSERT(x) ((void)(x))
#define STBI_NO_STDIO
#define STBI_ONLY_JPEG
#define STBI_ONLY_PNG
#define STBI_ONLY_BMP
#define STB_IMAGE_IMPLEMENTATION
#include "stb/stb_image.h"

#define STBIW_ASSERT(x) ((void)(x))
#define STBI_WRITE_NO_STDIO
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb/stb_image_write.h"

#ifdef ERL_NIF_DIRTY_JOB_CPU_BOUND
#define DIRTY_CPU_NIF ERL_NIF_DIRTY_JOB_CPU_BOUND
#else
#define DIRTY_CPU_NIF 0
#endif

typedef struct {
    ERL_NIF_TERM ok;
    ERL_NIF_TERM error;
    ERL_NIF_TERM decode_failed;
    ERL_NIF_TERM out_of_memory;
} priv_t;

typedef struct {
    unsigned char *data;
    size_t size;
    size_t cap;
    int failed;
} write_buf;

static ERL_NIF_TERM make_error(ErlNifEnv *env, priv_t *priv, ERL_NIF_TERM reason)
{
    return enif_make_tuple2(env, priv->error, reason);
}

static int get_positive_int(ErlNifEnv *env, ERL_NIF_TERM term, int *value)
{
    int parsed;

    if (!enif_get_int(env, term, &parsed)) {
        return 0;
    }
    if (parsed < 1) {
        return 0;
    }
    *value = parsed;
    return 1;
}

static int rgba_size(int width, int height, size_t *size)
{
    if ((size_t)width > SIZE_MAX / 4) {
        return 0;
    }
    if ((size_t)height > SIZE_MAX / ((size_t)width * 4)) {
        return 0;
    }
    *size = (size_t)width * (size_t)height * 4;
    return 1;
}

static int get_image_args(
    ErlNifEnv *env,
    ERL_NIF_TERM width_term,
    ERL_NIF_TERM height_term,
    ERL_NIF_TERM rgba_term,
    int *width,
    int *height,
    ErlNifBinary *rgba
)
{
    size_t expected;

    if (!get_positive_int(env, width_term, width)) {
        return 0;
    }
    if (!get_positive_int(env, height_term, height)) {
        return 0;
    }
    if (!enif_inspect_binary(env, rgba_term, rgba)) {
        return 0;
    }
    if (!rgba_size(*width, *height, &expected)) {
        return 0;
    }
    if (rgba->size != expected) {
        return 0;
    }
    return 1;
}

static void write_append(void *context, void *data, int size)
{
    write_buf *buf = (write_buf *)context;
    size_t n;
    size_t cap;
    unsigned char *grown;

    if (buf->failed || size < 0) {
        buf->failed = 1;
        return;
    }

    n = (size_t)size;
    if (n == 0) {
        return;
    }
    if (buf->size > SIZE_MAX - n) {
        buf->failed = 1;
        return;
    }
    if (buf->size + n > buf->cap) {
        cap = buf->cap == 0 ? 256 : buf->cap;
        while (cap < buf->size + n) {
            if (cap > SIZE_MAX / 2) {
                buf->failed = 1;
                return;
            }
            cap *= 2;
        }
        grown = (unsigned char *)realloc(buf->data, cap);
        if (grown == NULL) {
            buf->failed = 1;
            return;
        }
        buf->data = grown;
        buf->cap = cap;
    }
    memcpy(buf->data + buf->size, data, n);
    buf->size += n;
}

static ERL_NIF_TERM finish_write(ErlNifEnv *env, priv_t *priv, write_buf *buf, int ok)
{
    ERL_NIF_TERM binary;
    unsigned char *out;

    if (!ok || buf->failed || buf->data == NULL || buf->size == 0) {
        free(buf->data);
        return make_error(env, priv, priv->out_of_memory);
    }

    out = enif_make_new_binary(env, buf->size, &binary);
    memcpy(out, buf->data, buf->size);
    free(buf->data);
    return enif_make_tuple2(env, priv->ok, binary);
}

static ERL_NIF_TERM nif_decode_raw(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    priv_t *priv = (priv_t *)enif_priv_data(env);
    ErlNifBinary input;
    int width;
    int height;
    int channels;
    unsigned char *pixels;
    size_t size;
    ERL_NIF_TERM rgba_term;
    unsigned char *rgba;

    (void)argc;

    if (!enif_inspect_binary(env, argv[0], &input)) {
        return enif_make_badarg(env);
    }
    if (input.size > (size_t)INT_MAX) {
        return enif_make_badarg(env);
    }

    pixels = stbi_load_from_memory(
        input.data,
        (int)input.size,
        &width,
        &height,
        &channels,
        STBI_rgb_alpha
    );
    if (pixels == NULL) {
        return make_error(env, priv, priv->decode_failed);
    }
    if (width < 1 || height < 1 || !rgba_size(width, height, &size)) {
        stbi_image_free(pixels);
        return make_error(env, priv, priv->decode_failed);
    }

    rgba = enif_make_new_binary(env, size, &rgba_term);
    memcpy(rgba, pixels, size);
    stbi_image_free(pixels);

    return enif_make_tuple2(
        env,
        priv->ok,
        enif_make_tuple3(
            env,
            enif_make_int(env, width),
            enif_make_int(env, height),
            rgba_term
        )
    );
}

static ERL_NIF_TERM nif_encode_png_raw(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    priv_t *priv = (priv_t *)enif_priv_data(env);
    int width;
    int height;
    int out_len;
    ErlNifBinary rgba;
    unsigned char *png;
    unsigned char *out;
    ERL_NIF_TERM binary;

    (void)argc;

    if (!get_image_args(env, argv[0], argv[1], argv[2], &width, &height, &rgba)) {
        return enif_make_badarg(env);
    }
    if (width > INT_MAX / 4) {
        return enif_make_badarg(env);
    }

    png = stbi_write_png_to_mem(rgba.data, width * 4, width, height, 4, &out_len);
    if (png == NULL || out_len <= 0) {
        if (png != NULL) {
            STBIW_FREE(png);
        }
        return make_error(env, priv, priv->out_of_memory);
    }

    out = enif_make_new_binary(env, (size_t)out_len, &binary);
    memcpy(out, png, (size_t)out_len);
    STBIW_FREE(png);
    return enif_make_tuple2(env, priv->ok, binary);
}

static ERL_NIF_TERM nif_encode_jpeg_raw(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    priv_t *priv = (priv_t *)enif_priv_data(env);
    int width;
    int height;
    int quality;
    ErlNifBinary rgba;
    write_buf buf;
    int ok;

    (void)argc;

    if (!get_image_args(env, argv[0], argv[1], argv[2], &width, &height, &rgba)) {
        return enif_make_badarg(env);
    }
    if (!enif_get_int(env, argv[3], &quality) || quality < 1 || quality > 100) {
        return enif_make_badarg(env);
    }

    buf.data = NULL;
    buf.size = 0;
    buf.cap = 0;
    buf.failed = 0;
    ok = stbi_write_jpg_to_func(
        write_append,
        &buf,
        width,
        height,
        4,
        rgba.data,
        quality
    );
    return finish_write(env, priv, &buf, ok);
}

static unsigned char *rgba_to_rgb(const unsigned char *rgba, int width, int height)
{
    size_t count;
    unsigned char *rgb;
    size_t i;

    if ((size_t)width > SIZE_MAX / (size_t)height) {
        return NULL;
    }
    count = (size_t)width * (size_t)height;
    if (count > SIZE_MAX / 3) {
        return NULL;
    }
    rgb = (unsigned char *)malloc(count * 3);
    if (rgb == NULL) {
        return NULL;
    }
    for (i = 0; i < count; i++) {
        rgb[i * 3 + 0] = rgba[i * 4 + 0];
        rgb[i * 3 + 1] = rgba[i * 4 + 1];
        rgb[i * 3 + 2] = rgba[i * 4 + 2];
    }
    return rgb;
}

static ERL_NIF_TERM nif_encode_bmp_raw(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    priv_t *priv = (priv_t *)enif_priv_data(env);
    int width;
    int height;
    ErlNifBinary rgba;
    unsigned char *rgb;
    write_buf buf;
    int ok;
    ERL_NIF_TERM result;

    (void)argc;

    if (!get_image_args(env, argv[0], argv[1], argv[2], &width, &height, &rgba)) {
        return enif_make_badarg(env);
    }

    rgb = rgba_to_rgb(rgba.data, width, height);
    if (rgb == NULL) {
        return make_error(env, priv, priv->out_of_memory);
    }

    buf.data = NULL;
    buf.size = 0;
    buf.cap = 0;
    buf.failed = 0;
    ok = stbi_write_bmp_to_func(
        write_append,
        &buf,
        width,
        height,
        3,
        rgb
    );
    free(rgb);
    result = finish_write(env, priv, &buf, ok);
    return result;
}

static int nif_load(ErlNifEnv *env, void **priv_data, ERL_NIF_TERM load_info)
{
    priv_t *priv;

    (void)load_info;

    priv = (priv_t *)enif_alloc(sizeof(*priv));
    if (priv == NULL) {
        return 1;
    }

    priv->ok = enif_make_atom(env, "ok");
    priv->error = enif_make_atom(env, "error");
    priv->decode_failed = enif_make_atom(env, "decode_failed");
    priv->out_of_memory = enif_make_atom(env, "out_of_memory");
    stbi_set_flip_vertically_on_load(0);
    stbi_flip_vertically_on_write(0);

    *priv_data = priv;
    return 0;
}

static void nif_unload(ErlNifEnv *env, void *priv_data)
{
    (void)env;
    enif_free(priv_data);
}

static ErlNifFunc nif_functions[] = {
    {"decode_raw", 1, nif_decode_raw, DIRTY_CPU_NIF},
    {"encode_png_raw", 3, nif_encode_png_raw, DIRTY_CPU_NIF},
    {"encode_jpeg_raw", 4, nif_encode_jpeg_raw, DIRTY_CPU_NIF},
    {"encode_bmp_raw", 3, nif_encode_bmp_raw, DIRTY_CPU_NIF}
};

ERL_NIF_INIT(
    graphics_image_nif,
    nif_functions,
    nif_load,
    NULL,
    NULL,
    nif_unload
)
