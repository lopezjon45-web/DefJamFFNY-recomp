/*
 * uwp_cut.cpp -- what the modules left out of the Xbox One S build answer to
 * the code that stays.
 *
 * cmake/defjam_uwp.cmake leaves out the launcher (pc_launcher*.cpp), the
 * overlay (pc_ui.cpp, pc_ui_actions.cpp, pc_ui_theme.cpp), the debug recorder
 * (pc_debug.c) and the debug-register watchpoints (watchpoint.c): Win32
 * windows, ImGui, the shell's file actions, SetThreadContext and Toolhelp
 * have no app-partition build. The files stay in the tree, untouched. Each
 * entry point below does nothing and answers "not available", as
 * host_posix.c does for the watchpoints, so the callers do not change. C++
 * because pc_mods.cpp asks pc_ui_actions.cpp for the data folder.
 */
#include <cstddef>
#include <cstdlib>
#include <string>

#include "recomp_settings.h"
#include "hooks/pc_ui.h"
#include "hooks/pc_debug.h"
#include "hooks/pc_ui_actions.h"

extern "C" {

int pc_ui_overlay_open(void) { return 0; }
void pc_ui_apply_settings(void) {}

size_t pc_debug_settings(RecompSetting *, size_t) { return 0; }
void pc_debug_start(const char *, int) {}

int watchpoint_init(void) { return 0; }
int watchpoint_handle_trap(void *) { return 0; }

}

namespace pcui
{
/* The shell sets DEFJAM_DATA and makes it the current folder. */
std::string folder_path(Folder which)
{
    const char *data = getenv("DEFJAM_DATA");
    return which == Folder::Data && data ? data : "";
}
} // namespace pcui
