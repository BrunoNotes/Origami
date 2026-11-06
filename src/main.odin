package main

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:math/linalg"
import vmem "core:mem/virtual"
import "core:slice"
import "core:sort"
import "core:strconv"

import eng "./engine"
import "./vendor/sdl3"

@(private)
mesh_vertex_code := #load("../build/mesh.vert.spv")
@(private)
mesh_fragment_code := #load("../build/mesh.frag.spv")
@(private)
text_vertex_code := #load("../build/text.vert.spv")
@(private)
text_fragment_code := #load("../build/text.frag.spv")

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
                vsync = false,
            },
        },
    )

    defer eng.destroyEngine(engine)

    opaque_pipeline := eng.initPipeline(
        {
            wireframe = false,
            vertex_code = mesh_vertex_code,
            vertex_uniform_buffers = 3,
            fragment_code = mesh_fragment_code,
            fragment_uniform_buffers = 2,
            fragment_samplers = 1,
            depth_write = true,
        },
        engine.renderer,
    )
    defer eng.destroyPipeline(engine.renderer.device, opaque_pipeline)
    opaque_nodes_to_render := make([dynamic]^eng.Node, context.allocator)
    defer delete(opaque_nodes_to_render)
    opaque_pipeline_no_cull := eng.initPipeline(
        {
            wireframe = false,
            vertex_code = mesh_vertex_code,
            vertex_uniform_buffers = 3,
            fragment_code = mesh_fragment_code,
            fragment_uniform_buffers = 2,
            fragment_samplers = 1,
            depth_write = true,
            cull_mode = .NONE,
        },
        engine.renderer,
    )
    defer eng.destroyPipeline(engine.renderer.device, opaque_pipeline_no_cull)

    transparent_pipeline := eng.initPipeline(
        {
            wireframe = false,
            vertex_code = mesh_vertex_code,
            vertex_uniform_buffers = 3,
            fragment_code = mesh_fragment_code,
            fragment_uniform_buffers = 2,
            fragment_samplers = 1,
            depth_write = false,
        },
        engine.renderer,
    )
    defer eng.destroyPipeline(engine.renderer.device, transparent_pipeline)

    transparent_nodes_to_render := make([dynamic]^eng.Node, context.allocator)
    defer delete(opaque_nodes_to_render)

    text_pipeline := eng.initPipeline(
        {
            wireframe = false,
            vertex_code = text_vertex_code,
            vertex_uniform_buffers = 3,
            fragment_code = text_fragment_code,
            fragment_uniform_buffers = 1,
            fragment_samplers = 1,
            depth_write = true,
        },
        engine.renderer,
    )
    defer eng.destroyPipeline(engine.renderer.device, text_pipeline)

    text_nodes_to_render := make([dynamic]^eng.Node, context.allocator)
    defer delete(opaque_nodes_to_render)

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
            double_sided = true,
        },
        engine.renderer,
    )
    defer eng.destroyNode(triangle_node, engine.renderer)

    append(&opaque_nodes_to_render, triangle_node)

    when ODIN_OS == .Windows {
        sponza_path := "W:\\tmp\\glTF-Sample-Models\\2.0\\Sponza\\glTF\\Sponza.gltf"
    } else {
        sponza_path := "/home/bruno/tmp/glTF-Sample-Models/2.0/Sponza/glTF/Sponza.gltf"
    }
    sponza_data, _ := eng.loadGltf(sponza_path)
    defer eng.destroyGltf(sponza_data)

    sponza_node := eng.nodeFromGltf(sponza_data, engine.renderer, sponza_path)
    defer for node in sponza_node {
        eng.destroyNode(node, engine.renderer)
    }

    for node in sponza_node {
        if node.alpha_mode == .Transparent {
            append(&transparent_nodes_to_render, node)
        } else {
            append(&opaque_nodes_to_render, node)
        }
    }

    text_node := eng.initTextNode(
        "test",
        engine.renderer.default_font,
        engine.renderer,
    )
    defer eng.destroyNode(text_node, engine.renderer)
    text_node.translation = {-1, -1, 0}

    append(&text_nodes_to_render, text_node)

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

        cmd_buffer := eng.beginCmdBuffer(engine.renderer)

        render_pass := eng.beginRenderPass(engine.renderer, cmd_buffer)

        if render_pass != nil {
            eng.bindPipeline(render_pass, opaque_pipeline)

            eng.renderCamera(cmd_buffer, &camera)

            for node in opaque_nodes_to_render {
                if node.type == .Text {
                    continue
                }
                if node.alpha_mode != .Opaque {
                    continue
                }
                if node.double_sided {
                    continue
                }

                eng.updateNode(node)

                eng.drawNode(node, cmd_buffer, render_pass, engine.renderer)
            }

            eng.bindPipeline(render_pass, opaque_pipeline_no_cull)

            for node in opaque_nodes_to_render {
                if node.type == .Text {
                    continue
                }
                if node.alpha_mode != .Opaque {
                    continue
                }
                if !node.double_sided {
                    continue
                }

                eng.updateNode(node)

                eng.drawNode(node, cmd_buffer, render_pass, engine.renderer)
            }

            eng.bindPipeline(render_pass, transparent_pipeline)

            // NOTE(bruno): painters algorithm
            eng._g_ctx.user_ptr = &camera
            slice.sort_by(
                transparent_nodes_to_render[:],
                proc(a, b: ^eng.Node) -> bool {
                    context = eng._g_ctx
                    camera := (^eng.Camera)(context.user_ptr)
                    dist_a := linalg.length(a.translation - camera.translation)
                    dist_b := linalg.length(b.translation - camera.translation)
                    if dist_a > dist_b {
                        return true
                    } else {
                        return false
                    }
                },
            )
            eng._g_ctx.user_ptr = nil

            for node in transparent_nodes_to_render {
                if node.type == .Text {
                    continue
                }
                if node.alpha_mode != .Transparent {
                    continue
                }

                eng.updateNode(node)

                eng.drawNode(node, cmd_buffer, render_pass, engine.renderer)
            }

            eng.bindPipeline(render_pass, text_pipeline)

            for node in text_nodes_to_render {
                if node.type != .Text {
                    continue
                }

                d2_camera := eng.D2_CAMERA
                eng.renderCamera(cmd_buffer, &d2_camera)

                eng.updateTextNode(
                    text_node,
                    fmt.tprintf("fps: %v", engine.fps),
                    engine.renderer,
                )

                eng.drawNode(node, cmd_buffer, render_pass, engine.renderer)
            }
        }

        eng.endRenderPass(render_pass)


        eng.endCmdBuffer(cmd_buffer)
    }
}
