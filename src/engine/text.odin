package engine

import "../vendor/sdl3"
import "../vendor/sdl3_ttf"
import "core:math/linalg"
import "core:strings"

//TODO: make a pipeline for text

drawText :: proc(
    text: string,
    renderer: ^Renderer,
    cmd_buffer: ^sdl3.GPUCommandBuffer,
    render_pass: ^sdl3.GPURenderPass,
    camera: Maybe(Camera) = nil,
    font: ^sdl3_ttf.Font = nil,
    translation: linalg.Vector3f32 = 0,
) {
    font := font
    camera := camera

    if font == nil {
        font = renderer.default_font
    }

    if camera == nil {
        camera = D2_CAMERA
    }

    text_to_render := sdlCheck(
        sdl3_ttf.CreateText(
            renderer.txt_engine,
            font,
            strings.clone_to_cstring(text, context.temp_allocator),
            0,
        ),
    )
    defer sdl3_ttf.DestroyText(text_to_render)

    sequence := sdlCheck(sdl3_ttf.GetGPUTextDrawData(text_to_render))
    for sequence != nil {
        if sequence.num_vertices <= 0 ||
           sequence.num_indices <= 0 ||
           sequence.atlas_texture == nil {
            sequence = sequence.next
            continue
        }

        vertices := make(
            []Vertex,
            sequence.num_vertices,
            context.temp_allocator,
        )
        for i: i32 = 0; i < sequence.num_vertices; i += 1 {
            font_height := cast(f32)sdl3_ttf.GetFontHeight(font)
            x: f32 = sequence.xy[i].x
            y: f32 = sequence.xy[i].y + font_height

            x = x / (cast(f32)renderer.window_width / 2.0)
            y = y / (cast(f32)renderer.window_height / 2.0)
            vertex: Vertex = {
                position = {x, y, 0.0},
                uv       = {sequence.uv[i].x, sequence.uv[i].y},
                color    = 1,
                normal   = {0, 0, 1},
            }
            vertices[i] = vertex
        }

        indices := make([]u32, sequence.num_indices, context.temp_allocator)
        for i: i32 = 0; i < sequence.num_indices; i += 1 {
            indices[i] = cast(u32)sequence.indices[i]
        }

        texture: Texture = {
            handle  = sequence.atlas_texture,
            sampler = renderer.font_sampler,
            destroy = false,
        }

        text_node := initNode(
            {vertices = vertices[:], indices = indices[:], texture = texture},
            renderer,
        )
        defer destroyNode(text_node, renderer)

        text_node.translation = translation

        updateNode(text_node)
        drawNode(text_node, camera.?, cmd_buffer, render_pass, renderer)

        sequence = sequence.next
    }
}
