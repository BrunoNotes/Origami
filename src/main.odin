package main

import "core:fmt"
import "core:log"
import "core:math/linalg"
import vmem "core:mem/virtual"
import "core:strconv"

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
                vsync = true,
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
    defer eng.destroyPipeline(engine.renderer.device, pipeline)

    camera := eng.PERSPECTIVE_CAMERA
    camera.translation = {0, 0, 5}

    // d2_camera := eng.D2_CAMERA

    triangle_node := eng.initNode(
        {
            vertices = []eng.Vertex {
                {position = {0.0, 1.0, 0.0}, color = 1},
                {position = {-1.0, -1.0, 0.0}, color = 1},
                {position = {1.0, -1.0, 0.0}, color = 1},
            },
            indices = []u32{0, 1, 2},
        },
        engine.renderer,
    )
    defer eng.destroyNode(triangle_node, engine.renderer)

    box_data, _ := eng.loadGltf("assets/models/BoxTextured.glb")
    defer eng.destroyGltf(box_data)

    box_node := eng.nodeFromGltf(box_data, engine.renderer)
    defer eng.destroyNode(box_node, engine.renderer)

    sponza_path := "/home/bruno/tmp/glTF-Sample-Models/2.0/Sponza/glTF/Sponza.gltf"
    sponza_data, _ := eng.loadGltf(sponza_path)
    defer eng.destroyGltf(sponza_data)

    sponza_node := eng.nodeFromGltf(sponza_data, engine.renderer, sponza_path)
    defer eng.destroyNode(sponza_node, engine.renderer)

    free_all(context.temp_allocator)

    for engine.renderer.window_open {
        defer free_all(context.temp_allocator)

        eng.updateEngine(engine)

        eng.processEvents(engine)

        eng.flyCameraController(
            &camera,
            engine.input,
            engine.delta_time,
            engine.renderer,
        )
        eng.updateCameraProjection(
            &camera,
            cast(f32)engine.renderer.window_width,
            cast(f32)engine.renderer.window_height,
        )

        cmd_buffer, render_pass := eng.beginRender(engine.renderer)

        sdl3.BindGPUGraphicsPipeline(render_pass, pipeline)

        eng.updateNode(triangle_node)
        eng.drawNode(
            triangle_node,
            camera,
            cmd_buffer,
            render_pass,
            engine.renderer,
        )

        eng.updateNode(box_node)
        eng.drawNode(
            box_node,
            camera,
            cmd_buffer,
            render_pass,
            engine.renderer,
        )

        eng.updateNode(sponza_node)
        eng.drawNode(
            sponza_node,
            camera,
            cmd_buffer,
            render_pass,
            engine.renderer,
        )

        // eng.drawText("Hello world", engine.renderer, cmd_buffer, render_pass)
        // buf: [8]byte
        // fps := strconv.write_float(buf[:], engine.fps, 'f', 2, 64)
        fps := fmt.tprintf("%v", engine.fps)

        eng.drawText(
            fps,
            engine.renderer,
            cmd_buffer,
            render_pass,
            translation = {0.95, 0.95, 0},
        )

        eng.endRender(cmd_buffer, render_pass)

    }
}
