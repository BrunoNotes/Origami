package engine

import "../vendor/sdl3"

Engine :: struct {
    renderer: ^Renderer,
}

EngineInitOpts :: struct {
    renderer: RendererInitOpts
}

initEngine :: proc(opts: EngineInitOpts, allocator := context.allocator) -> ^Engine {
    engine := new(Engine, allocator)

    _g_ctx = context

    when ODIN_DEBUG {
        sdl3.SetLogPriorities(.VERBOSE)
    } else {
        sdl3.SetLogPriorities(.DEBUG)
    }

    sdl3.SetLogOutputFunction(sdl3LogHandler, nil)

    engine.renderer = initRenderer(opts.renderer, allocator)

    return engine
}

destroyEngine :: proc(engine: ^Engine) {
    destroyRenderer(engine.renderer)
}
