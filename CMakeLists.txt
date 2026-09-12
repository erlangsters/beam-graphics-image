cmake_minimum_required(VERSION 3.11)
project(beam_graphics_image LANGUAGES C)

set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Vendored from https://github.com/nothings/stb
# commit 2c980bb59875b0d32144a71867fbdebb2f77cd20
# stb_image.h v2.30, stb_image_write.h v1.16

# We let Rebar3 inform CMake where to find the Erlang/OTP location. Therefore,
# it requires the ERLANG_ERTS_DIR and ERL_INTERFACE_DIR values specified with
# the -D flags.
if(NOT DEFINED ERLANG_ERTS_DIR)
    message(FATAL_ERROR "ERLANG_ERTS_DIR must be defined (pass -DERLANG_ERTS_DIR=...)")
endif()
if(NOT DEFINED ERL_INTERFACE_DIR)
    message(FATAL_ERROR "ERL_INTERFACE_DIR must be defined (pass -DERL_INTERFACE_DIR=...)")
endif()

set(ERTS_INCLUDE_DIR "${ERLANG_ERTS_DIR}/include")
set(ERL_INTERFACE_INCLUDE_DIR "${ERL_INTERFACE_DIR}/include")

add_library(beam-graphics-image SHARED c_src/image_nif.c)
set_target_properties(beam-graphics-image PROPERTIES
    OUTPUT_NAME "beam-graphics-image"
    PREFIX ""
)

# The Rebar3 build system (as configured in rebar.config) does not make use
# of the "install" step. Instead, it produces the NIF library in the priv/
# folder directly during the "build" step.
set_target_properties(beam-graphics-image PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/priv"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/priv"
)

# On macOS, we need to add special linker flags to avoid issues with symbol
# resolution.
if(APPLE)
    set_target_properties(beam-graphics-image PROPERTIES
        LINK_FLAGS "-flat_namespace -undefined suppress"
        SUFFIX ".so"
    )
endif()

target_include_directories(beam-graphics-image PRIVATE
    ${ERTS_INCLUDE_DIR}
    ${ERL_INTERFACE_INCLUDE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/c_src
)

if(UNIX)
    target_link_libraries(beam-graphics-image PRIVATE m)
endif()
