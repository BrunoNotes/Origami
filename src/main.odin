package main

import "core:fmt"
import "core:log"
import vmem "core:mem/virtual"

import eng "./engine"

main :: proc() {
    when ODIN_DEBUG {
        lowest_log_level := log.Level.Debug
    } else {
        lowest_log_level := log.Level.Info
    }
    context.logger = log.create_console_logger(
        lowest = lowest_log_level,
        opt = {.Level, .Terminal_Color},
    )
    defer log.destroy_console_logger(context.logger)

    arena: vmem.Arena
    arena_err := vmem.arena_init_growing(&arena)
    assert(arena_err == nil)
    defer vmem.arena_destroy(&arena)

    context.allocator = vmem.arena_allocator(&arena)
    defer free_all(context.allocator)

    engine := eng.initEngine(
        {
            renderer = {
                window_title = "test",
                window_width = 800,
                window_height = 600,
            },
        },
    )

    defer eng.destroyEngine(engine)

    free_all(context.temp_allocator)

    for engine.renderer.window_open {
        defer free_all(context.temp_allocator)

        eng.processEvents(engine)

        cmd_buffer, render_pass := eng.beginRender(engine.renderer)

        eng.endRender(cmd_buffer, render_pass)
    }
}
