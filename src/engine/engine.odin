package engine

import "core:log"
import "core:math"
import "../vendor/sdl3"
import "core:time"
import "../vendor/sdl3_ttf"

Engine :: struct {
    renderer:              ^Renderer,
    input:                 ^Input,
    start_time, last_time: time.Time,
    delta_time:            f32,
    frames, fps:           f64,
}

EngineInitOpts :: struct {
    renderer: RendererInitOpts,
}

initEngine :: proc(
    opts: EngineInitOpts,
    allocator := context.allocator,
) -> ^Engine {
    engine := new(Engine, allocator)

    _g_ctx = context

    when ODIN_DEBUG {
        sdl3.SetLogPriorities(.VERBOSE)
    } else {
        sdl3.SetLogPriorities(.DEBUG)
    }

    sdl3.SetLogOutputFunction(sdl3LogHandler, nil)

    assert(sdl3_ttf.Init())

    engine.renderer = initRenderer(opts.renderer, allocator)

    engine.input = initInput(allocator)

    engine.start_time = time.now()
    engine.last_time = engine.start_time
    engine.frames = 0

    return engine
}

destroyEngine :: proc(engine: ^Engine) {
    destroyInput(engine.input)
    destroyRenderer(engine.renderer)
}

updateEngine :: proc(engine: ^Engine) {
    engine.frames += 1

    current_time := time.now()
    elapsed_time := time.diff(engine.start_time, current_time)
    engine.delta_time =
        f32(current_time._nsec - engine.last_time._nsec) / f32(time.Second)
    engine.last_time = current_time

    if elapsed_time >= time.Second {
        engine.fps = math.round(
            (engine.frames * 1000) / time.duration_milliseconds(elapsed_time),
        )
        // log.debugf("fps: %v", engine.fps)
        engine.frames = 0
        engine.start_time = current_time
    }
}
