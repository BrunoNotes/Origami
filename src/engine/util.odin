package engine

import "../vendor/sdl3"
import "base:runtime"
import "core:log"
import "core:math/linalg"

@(private)
_g_ctx: runtime.Context

Vertex :: struct {
    position: linalg.Vector3f32,
    color:    linalg.Vector4f32,
    uv:       linalg.Vector2f32,
    normal:   linalg.Vector3f32,
}

VEC2ZERO :: linalg.Vector2f32{0, 0}
VEC2UP :: linalg.Vector2f32{0, 1}
VEC2DOWN :: linalg.Vector2f32{0, -1}
VEC2LEFT :: linalg.Vector2f32{-1, 0}
VEC2RIGHT :: linalg.Vector2f32{1, 0}
VEC2FORWARD :: linalg.Vector2f32{0, 0}
VEC2BACK :: linalg.Vector2f32{0, 0}

VEC3ZERO :: linalg.Vector3f32{0, 0, 0}
VEC3UP :: linalg.Vector3f32{0, 1, 0}
VEC3DOWN :: linalg.Vector3f32{0, -1, 0}
VEC3LEFT :: linalg.Vector3f32{-1, 0, 0}
VEC3RIGHT :: linalg.Vector3f32{1, 0, 0}
VEC3FORWARD :: linalg.Vector3f32{0, 0, -1}
VEC3BACK :: linalg.Vector3f32{0, 0, 1}

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
