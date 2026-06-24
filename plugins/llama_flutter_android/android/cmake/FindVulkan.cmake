# Custom FindVulkan for Android NDK cross-compilation
# Adapted from sd_flutter_android plugin

if(ANDROID)
    if(DEFINED CMAKE_ANDROID_NDK)
        set(_ANDROID_NDK "${CMAKE_ANDROID_NDK}")
    elseif(DEFINED ANDROID_NDK)
        set(_ANDROID_NDK "${ANDROID_NDK}")
    elseif(DEFINED ENV{ANDROID_NDK})
        set(_ANDROID_NDK "$ENV{ANDROID_NDK}")
    elseif(CMAKE_TOOLCHAIN_FILE)
        get_filename_component(_TOOLCHAIN_DIR "${CMAKE_TOOLCHAIN_FILE}" DIRECTORY)
        get_filename_component(_ANDROID_NDK "${_TOOLCHAIN_DIR}/../../.." ABSOLUTE)
    endif()

    if(NOT _ANDROID_NDK OR NOT EXISTS "${_ANDROID_NDK}")
        message(WARNING "Android NDK not found. Vulkan backend will not be available.")
        set(Vulkan_FOUND FALSE)
        return()
    endif()

    message(STATUS "Android NDK for Vulkan: ${_ANDROID_NDK}")

    # Find glslc from NDK shader-tools or PATH
    if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
        set(_HOST_SUBDIR "darwin-x86_64")
    elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
        set(_HOST_SUBDIR "linux-x86_64")
    elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
        set(_HOST_SUBDIR "windows-x86_64")
    else()
        set(_HOST_SUBDIR "${CMAKE_HOST_SYSTEM_NAME}")
    endif()

    set(_GLSLC_CANDIDATE "${_ANDROID_NDK}/shader-tools/${_HOST_SUBDIR}/glslc")
    if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
        set(_GLSLC_CANDIDATE "${_GLSLC_CANDIDATE}.exe")
    endif()

    if(EXISTS "${_GLSLC_CANDIDATE}")
        set(Vulkan_GLSLC_EXECUTABLE "${_GLSLC_CANDIDATE}" CACHE FILEPATH "Path to glslc" FORCE)
    else()
        find_program(Vulkan_GLSLC_EXECUTABLE NAMES glslc)
    endif()

    if(NOT Vulkan_GLSLC_EXECUTABLE)
        message(WARNING "glslc not found (NDK: ${_GLSLC_CANDIDATE}, PATH). Some shader features may be unavailable.")
    else()
        message(STATUS "Found glslc: ${Vulkan_GLSLC_EXECUTABLE}")
    endif()

    # Vulkan headers: NDK sysroot already contains vulkan_core.h
    # Use cloned Vulkan-Headers for vulkan.hpp which ggml-vulkan requires
    get_filename_component(_CMAKE_DIR "${CMAKE_CURRENT_LIST_DIR}" DIRECTORY)
    set(_VULKAN_HPP_DIR "${_CMAKE_DIR}/src/main/cpp/vulkan-headers/include")
    if(EXISTS "${_VULKAN_HPP_DIR}/vulkan/vulkan.hpp")
        set(Vulkan_INCLUDE_DIRS "${_VULKAN_HPP_DIR}")
        message(STATUS "Vulkan headers (with vulkan.hpp): ${Vulkan_INCLUDE_DIRS}")
    else()
        # Fallback: NDK sysroot has vulkan_core.h but not vulkan.hpp
        # NDK r26+ moved sysroot under toolchains/llvm/prebuilt/<host>/sysroot
        if(EXISTS "${_ANDROID_NDK}/sysroot/usr/include")
            set(Vulkan_INCLUDE_DIRS "${_ANDROID_NDK}/sysroot/usr/include")
        elseif(CMAKE_SYSROOT)
            set(Vulkan_INCLUDE_DIRS "${CMAKE_SYSROOT}/usr/include")
        else()
            message(WARNING "NDK sysroot not found. Vulkan backend will not be available.")
            set(Vulkan_FOUND FALSE)
            return()
        endif()
        message(STATUS "Vulkan headers (sysroot only): ${Vulkan_INCLUDE_DIRS}")
    endif()

    # Create imported target for Android's libvulkan.so
    if(NOT TARGET Vulkan::Vulkan)
        add_library(Vulkan::Vulkan INTERFACE IMPORTED)
        set_target_properties(Vulkan::Vulkan PROPERTIES
            INTERFACE_LINK_LIBRARIES "-lvulkan"
            INTERFACE_INCLUDE_DIRECTORIES "${Vulkan_INCLUDE_DIRS}"
        )
    endif()

    set(Vulkan_FOUND TRUE)
    message(STATUS "Custom FindVulkan configured for Android cross-compilation")
else()
    include(${CMAKE_ROOT}/Modules/FindVulkan.cmake)
endif()
