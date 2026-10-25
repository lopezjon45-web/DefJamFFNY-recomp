# The Xbox One S build (DEFJAM_UWP): two static libraries and no executable.
# The defjam-one-s shell owns the entry point, the manifest and the link.
#
#   defjam_host  main.c and every hook and patch that builds without the
#                lifted code, plus src/uwp/uwp_cut.cpp. Builds anywhere.
#   defjam_game  recomp_manual.c, src/recomp/gen/*.c and every hook or patch
#                that includes a generated header. Only where the lift exists.
#
# A source that includes "recomp/gen/..." or "guest_call.h" is game-side.
# That is read from the file on each configure, never listed here.

file(GLOB _defjam_gen     CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/recomp/gen/*.c")
file(GLOB _defjam_hooks   CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/hooks/*.c"
                                            "${CMAKE_CURRENT_SOURCE_DIR}/src/hooks/*.cpp")
file(GLOB _defjam_patches CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/patches/*.c")

# Not in v1: the launcher and the overlay (Win32 windows, ImGui), the debug
# recorder and the debug-register watchpoints (SetThreadContext, Toolhelp).
# src/uwp/uwp_cut.cpp answers for them to the code that stays.
list(FILTER _defjam_hooks EXCLUDE REGEX
     "/(pc_launcher(_home|_sdl)?|pc_ui(_actions|_theme)?|watchpoint|pc_debug)\\.(c|cpp)$")

set(_defjam_host_sources "")
set(_defjam_game_sources "${CMAKE_CURRENT_SOURCE_DIR}/src/recomp_manual.c" ${_defjam_gen})
foreach(_src IN LISTS _defjam_hooks _defjam_patches)
    file(STRINGS "${_src}" _needs_gen LIMIT_COUNT 1
         REGEX "#include[ \t]+\"(recomp/gen/|guest_call\\.h\")")
    if(_needs_gen)
        list(APPEND _defjam_game_sources "${_src}")
    else()
        list(APPEND _defjam_host_sources "${_src}")
    endif()
endforeach()

set(_defjam_includes
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/src/recomp
    ${XBOXRECOMP_DIR}/include
    ${XBOXRECOMP_DIR}/src/platform
    ${XBOXRECOMP_DIR}/src/d3d
    ${XBOXRECOMP_DIR}/src/nv2a)
set(_defjam_defs
    WIN32_LEAN_AND_MEAN NOMINMAX DEFJAM_UWP=1 XBOXRECOMP_UWP=1
    DEFJAM_VERSION=\"${PROJECT_VERSION}\"
    DEFJAM_MOD_SOURCE_DIR=\"${CMAKE_CURRENT_SOURCE_DIR}\")
# The names the partition's headers hide, declared for every file whichever
# header gives it <windows.h> (recorder.c and pc_mods.cpp take it directly).
set(_defjam_options "/FI${XBOXRECOMP_DIR}/src/platform/app_partition.h")
file(READ "${XBOXRECOMP_DIR}/src/nv2a/texture_pack.c" _mod_texture_loader)
string(FIND "${_mod_texture_loader}" "texture_pack_wide_slabs" _mod_has_wide)
if(NOT _mod_has_wide EQUAL -1)
    list(APPEND _defjam_defs DEFJAM_MOD_WIDE=1)
endif()

add_library(defjam_host STATIC
    src/main.c
    src/uwp/uwp_cut.cpp
    ${_defjam_host_sources})
# Exactly C++17, as the desktop build gets it: pc_mods.cpp assigns
# path::u8string() to std::string, which C++20 makes a std::u8string.
set_target_properties(defjam_host PROPERTIES CXX_STANDARD 17 CXX_STANDARD_REQUIRED ON)
target_include_directories(defjam_host PRIVATE ${_defjam_includes})
target_compile_definitions(defjam_host PRIVATE ${_defjam_defs})
target_compile_options(defjam_host PRIVATE ${_defjam_options})
target_link_libraries(defjam_host PUBLIC xboxrecomp recomp_settings)

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/src/recomp/gen/recomp_dispatch.c")
    add_library(defjam_game STATIC ${_defjam_game_sources})
    target_include_directories(defjam_game PRIVATE ${_defjam_includes})
    target_compile_definitions(defjam_game PRIVATE ${_defjam_defs})
    # The lifted code reads memory through casts of every width, relies on
    # wrapping arithmetic, and must not have a multiply and an add fused.
    target_compile_options(defjam_game PRIVATE ${_defjam_options} /bigobj
        /clang:-fwrapv /clang:-fno-strict-aliasing /clang:-ffp-contract=off)
    target_link_libraries(defjam_game PUBLIC defjam_host)
endif()
