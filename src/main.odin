package main

import "core:fmt"
import "core:log"
import vmem "core:mem/virtual"

import eng "./engine"
import "./vendor/sdl3"

@(private)
mesh_vertex_code := #load("../build/mesh.vert.spv")

@(private)
mesh_fragment_code := #load("../build/mesh.frag.spv")

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

    pipeline := eng.initPipeline(
        {
            wireframe = false,
            vertex_code = mesh_vertex_code,
            vertex_uniform_buffers = 3,
            fragment_code = mesh_fragment_code,
            fragment_uniform_buffers = 1,
            fragment_samplers = 1,
        },
        engine.renderer,
    )
    defer sdl3.ReleaseGPUGraphicsPipeline(engine.renderer.device, pipeline)

    test_node := eng.initNode(
        {
            vertices = []eng.Vertex {
                {position = {0.0, 1.0, 0.0}, color = 1},
                {position = {-1.0, -1.0, 0.0}, color = 1},
                {position = {1.0, -1.0, 0.0}, color = 1},
            },
            indices = []u32{0, 1, 2},
            instances = 1,
            color = 1,
        },
        engine.renderer.device,
    )
    defer eng.destroyNode(test_node, engine.renderer.device)

    camera := eng.PERSPECTIVE_CAMERA
    camera.translation = {0, 0, 5}
    // camera := eng.D2_CAMERA

    free_all(context.temp_allocator)

    for engine.renderer.window_open {
        defer free_all(context.temp_allocator)

        eng.processEvents(engine)

        eng.updateCameraProjection(
            &camera,
            cast(f32)engine.renderer.window_width,
            cast(f32)engine.renderer.window_height,
        )

        cmd_buffer, render_pass := eng.beginRender(engine.renderer)

        sdl3.BindGPUGraphicsPipeline(render_pass, pipeline)

        eng.updateNode(test_node)
        eng.drawNode(test_node, camera, cmd_buffer, render_pass)

        eng.endRender(cmd_buffer, render_pass)
    }
}
