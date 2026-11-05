# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(codelessly_quickjs_library VERSION 0.1.0 LANGUAGES C)

file(READ "${CMAKE_CURRENT_SOURCE_DIR}/quickjs/VERSION" QUICKJS_VERSION)
string(STRIP "${QUICKJS_VERSION}" QUICKJS_VERSION)

add_library(codelessly_quickjs SHARED
  "codelessly_quickjs.c"
  "quickjs/quickjs.c"
  "quickjs/libregexp.c"
  "quickjs/libunicode.c"
  "quickjs/cutils.c"
  "quickjs/dtoa.c"
)

set_target_properties(codelessly_quickjs PROPERTIES
  PUBLIC_HEADER codelessly_quickjs.h
  OUTPUT_NAME "codelessly_quickjs"
  C_VISIBILITY_PRESET hidden
)

target_compile_definitions(codelessly_quickjs PRIVATE
  DART_SHARED_LIB
  _GNU_SOURCE
  CONFIG_VERSION="${QUICKJS_VERSION}"
)
# QuickJS relies on wrapping signed arithmetic.
target_compile_options(codelessly_quickjs PRIVATE -fwrapv -Os -w)
target_link_libraries(codelessly_quickjs PRIVATE m)

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(codelessly_quickjs PRIVATE "-Wl,-z,max-page-size=16384")
endif()
