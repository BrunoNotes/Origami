package engine

import "core:log"
import "base:runtime"
import "../vendor/sdl3"

@(private)
_g_ctx: runtime.Context

MAKE_API_VERSION :: proc "contextless" (
    variant, major, minor, patch: u32,
) -> u32 {
    return (variant << 29) | (major << 22) | (minor << 12) | (patch)
}

sdl3LogHandler :: proc "c" (
    userdata: rawptr,
    category: sdl3.LogCategory,
    priority: sdl3.LogPriority,
    message: cstring,
) {
    // context = runtime.default_context()
    context = _g_ctx

    #partial switch priority {
    case .DEBUG:
        log.debugf("SDL: [%v] %v", category, message)
    case .INFO:
        log.infof("SDL: [%v] %v", category, message)
    case .WARN:
        log.warnf("SDL: [%v] %v", category, message)
    case .ERROR:
        log.errorf("SDL: [%v] %v", category, message)
    case:
        log.infof("SDL: [%v] %v", category, message)
    }
}
