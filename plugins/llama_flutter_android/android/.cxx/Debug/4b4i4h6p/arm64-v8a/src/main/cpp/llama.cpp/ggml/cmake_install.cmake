# Install script for directory: /media/azmarpop/DATA/MY_AI/cross-platform-llm-client/local_plugins/llama_flutter_android/android/src/main/cpp/llama.cpp/ggml

# Set the install prefix
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "/usr/local")
endif()
string(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

# Set the install configuration name.
if(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)
  if(BUILD_TYPE)
    string(REGEX REPLACE "^[^A-Za-z0-9_]+" ""
           CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")
  else()
    set(CMAKE_INSTALL_CONFIG_NAME "Debug")
  endif()
  message(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")
endif()

# Set the component getting installed.
if(NOT CMAKE_INSTALL_COMPONENT)
  if(COMPONENT)
    message(STATUS "Install component: \"${COMPONENT}\"")
    set(CMAKE_INSTALL_COMPONENT "${COMPONENT}")
  else()
    set(CMAKE_INSTALL_COMPONENT)
  endif()
endif()

# Install shared libraries without execute permission?
if(NOT DEFINED CMAKE_INSTALL_SO_NO_EXE)
  set(CMAKE_INSTALL_SO_NO_EXE "1")
endif()

# Is this installation the result of a crosscompile?
if(NOT DEFINED CMAKE_CROSSCOMPILING)
  set(CMAKE_CROSSCOMPILING "TRUE")
endif()

# Set default install directory permissions.
if(NOT DEFINED CMAKE_OBJDUMP)
  set(CMAKE_OBJDUMP "/home/azmarpop/Android/Sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-objdump")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("/media/azmarpop/DATA/MY_AI/cross-platform-llm-client/local_plugins/llama_flutter_android/android/.cxx/Debug/4b4i4h6p/arm64-v8a/src/main/cpp/llama.cpp/ggml/src/cmake_install.cmake")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libggml.so" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libggml.so")
    file(RPATH_CHECK
         FILE "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libggml.so"
         RPATH "")
  endif()
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE SHARED_LIBRARY FILES "/media/azmarpop/DATA/MY_AI/cross-platform-llm-client/local_plugins/llama_flutter_android/android/.cxx/Debug/4b4i4h6p/arm64-v8a/bin/libggml.so")
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libggml.so" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libggml.so")
    if(CMAKE_INSTALL_DO_STRIP)
      execute_process(COMMAND "/home/azmarpop/Android/Sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libggml.so")
    endif()
  endif()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include" TYPE FILE FILES
    "/media/azmarpop/DATA/MY_AI/cross-platform-llm-client/local_plugins/llama_flutter_android/android/src/main/cpp/llama.cpp/ggml/include/ggml.h"
    "/media/azmarpop/DATA/MY_AI/cross-platform-llm-client/local_plugins/llama_flutter_android/android/src/main/cpp/llama.cpp/ggml/include/ggml-cpu.h"
    "/media/azmarpop/DATA/MY_AI/cross-platform-llm-client/local_plugins/llama_flutter_android/android/src/main/cpp/llama.cpp/ggml/include/ggml-alloc.h"
    "/media/azmarpop/DATA/MY_AI/cross-platform-llm-client/local_plugins/llama_flutter_android/android/src/main/cpp/llama.cpp/ggml/include/ggml-backend.h"
    "/media/azmarpop/DATA/MY_AI/cross-platform-llm-client/local_plugins/llama_flutter_android/android/src/main/cpp/llama.cpp/ggml/include/ggml-blas.h"
    "/media/azmarpop/DATA/MY_AI/cross-platform-llm-client/local_plugins/llama_flutter_android/android/src/main/cpp/llama.cpp/ggml/include/ggml-cann.h"
    "/media/azmarpop/DATA/MY_AI/cross-platform-llm-client/local_plugins/llama_flutter_android/android/src/main/cpp/llama.cpp/ggml/include/ggml-cpp.h"
    "/media/azmarpop/DATA/MY_AI/cross-platform-llm-client/local_plugins/llama_flutter_android/android/src/main/cpp/llama.cpp/ggml/include/ggml-cuda.h"
    "/media/azmarpop/DATA/MY_AI/cross-platform-llm-client/local_plugins/llama_flutter_android/android/src/main/cpp/llama.cpp/ggml/include/ggml-opt.h"
    "/media/azmarpop/DATA/MY_AI/cross-platform-llm-client/local_plugins/llama_flutter_android/android/src/main/cpp/llama.cpp/ggml/include/ggml-metal.h"
    "/media/azmarpop/DATA/MY_AI/cross-platform-llm-client/local_plugins/llama_flutter_android/android/src/main/cpp/llama.cpp/ggml/include/ggml-rpc.h"
    "/media/azmarpop/DATA/MY_AI/cross-platform-llm-client/local_plugins/llama_flutter_android/android/src/main/cpp/llama.cpp/ggml/include/ggml-virtgpu.h"
    "/media/azmarpop/DATA/MY_AI/cross-platform-llm-client/local_plugins/llama_flutter_android/android/src/main/cpp/llama.cpp/ggml/include/ggml-sycl.h"
    "/media/azmarpop/DATA/MY_AI/cross-platform-llm-client/local_plugins/llama_flutter_android/android/src/main/cpp/llama.cpp/ggml/include/ggml-vulkan.h"
    "/media/azmarpop/DATA/MY_AI/cross-platform-llm-client/local_plugins/llama_flutter_android/android/src/main/cpp/llama.cpp/ggml/include/ggml-webgpu.h"
    "/media/azmarpop/DATA/MY_AI/cross-platform-llm-client/local_plugins/llama_flutter_android/android/src/main/cpp/llama.cpp/ggml/include/ggml-zendnn.h"
    "/media/azmarpop/DATA/MY_AI/cross-platform-llm-client/local_plugins/llama_flutter_android/android/src/main/cpp/llama.cpp/ggml/include/ggml-openvino.h"
    "/media/azmarpop/DATA/MY_AI/cross-platform-llm-client/local_plugins/llama_flutter_android/android/src/main/cpp/llama.cpp/ggml/include/gguf.h"
    )
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libggml-base.so" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libggml-base.so")
    file(RPATH_CHECK
         FILE "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libggml-base.so"
         RPATH "")
  endif()
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE SHARED_LIBRARY FILES "/media/azmarpop/DATA/MY_AI/cross-platform-llm-client/local_plugins/llama_flutter_android/android/.cxx/Debug/4b4i4h6p/arm64-v8a/bin/libggml-base.so")
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libggml-base.so" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libggml-base.so")
    if(CMAKE_INSTALL_DO_STRIP)
      execute_process(COMMAND "/home/azmarpop/Android/Sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libggml-base.so")
    endif()
  endif()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake/ggml" TYPE FILE FILES
    "/media/azmarpop/DATA/MY_AI/cross-platform-llm-client/local_plugins/llama_flutter_android/android/.cxx/Debug/4b4i4h6p/arm64-v8a/src/main/cpp/llama.cpp/ggml/ggml-config.cmake"
    "/media/azmarpop/DATA/MY_AI/cross-platform-llm-client/local_plugins/llama_flutter_android/android/.cxx/Debug/4b4i4h6p/arm64-v8a/src/main/cpp/llama.cpp/ggml/ggml-version.cmake"
    )
endif()

