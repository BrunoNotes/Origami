package engine

import "../vendor/sdl3"
import "../vendor/sdl3_ttf"
import "core:log"
import "core:math/linalg"
import "core:strings"

//TODO: make a pipeline for text

initTextNode :: proc(
    text: string,
    font: ^sdl3_ttf.Font,
    renderer: ^Renderer,
    allocator := context.allocator,
) -> ^Node {
    text := text

    // TODO: sdl_ttf does not accept empty strings, find a solution to accept
    // this is a temp hack
    assert(len(text) > 0, "TODO: fix, sdl_ttf does not accept empty strings")

    text_to_render := sdlCheck(
        sdl3_ttf.CreateText(
            renderer.txt_engine,
            font,
            strings.clone_to_cstring(text, context.temp_allocator),
            0,
        ),
    )
    defer sdl3_ttf.DestroyText(text_to_render)

    seq_indices, seq_vertices, seq_texture := getTextDrawData(
        text_to_render,
        font,
        cast(f32)renderer.window_width,
        cast(f32)renderer.window_height,
    )

    texture: Texture = {
        handle  = seq_texture,
        sampler = renderer.font_sampler,
        destroy = false,
    }

    node := initNode(
        {
            vertices = seq_vertices[:],
            indices = seq_indices[:],
            texture = texture,
            type = .Text,
            text = text,
            font = font,
        },
        renderer,
        allocator,
    )

    return node
}

getTextDrawData :: proc(
    text: ^sdl3_ttf.Text,
    font: ^sdl3_ttf.Font = nil,
    window_width, window_height: f32,
) -> (
    indices: []u32,
    vertices: []Vertex,
    texture: ^sdl3.GPUTexture,
) {
    font_height := cast(f32)sdl3_ttf.GetFontHeight(font)

    sequence := sdlCheck(sdl3_ttf.GetGPUTextDrawData(text))
    for sequence != nil {
        if sequence.num_vertices <= 0 ||
           sequence.num_indices <= 0 ||
           sequence.atlas_texture == nil {
            sequence = sequence.next
            continue
        }

        seq_vertices := make(
            []Vertex,
            sequence.num_vertices,
            context.temp_allocator,
        )
        for i: i32 = 0; i < sequence.num_vertices; i += 1 {
            x: f32 = sequence.xy[i].x
            y: f32 = sequence.xy[i].y + font_height

            x = x / (window_width / 2.0)
            y = y / (window_height / 2.0)
            vertex: Vertex = {
                position = {x, y, 0.0},
                uv       = {sequence.uv[i].x, sequence.uv[i].y},
                color    = 1,
                normal   = {0, 0, 1},
            }
            seq_vertices[i] = vertex
        }

        seq_indices := make([]u32, sequence.num_indices, context.temp_allocator)
        for i: i32 = 0; i < sequence.num_indices; i += 1 {
            seq_indices[i] = cast(u32)sequence.indices[i]
        }

        indices = seq_indices
        vertices = seq_vertices
        texture = sequence.atlas_texture

        sequence = sequence.next
    }

    return indices, vertices, texture
}

updateTextNode :: proc(
    node: ^Node,
    text: string,
    renderer: ^Renderer,
    allocator := context.allocator,
) {
    text_to_render := sdlCheck(
        sdl3_ttf.CreateText(
            renderer.txt_engine,
            node.font,
            strings.clone_to_cstring(text, context.temp_allocator),
            0,
        ),
    )
    defer sdl3_ttf.DestroyText(text_to_render)

    seq_indices, seq_vertices, seq_texture := getTextDrawData(
        text_to_render,
        node.font,
        cast(f32)renderer.window_width,
        cast(f32)renderer.window_height,
    )

    node.vertex_buffer, node.vertex_len = createNodeVertexBuffer(
        seq_vertices,
        node,
        renderer.device,
    )

    node.index_buffer, node.index_len = createNodeIndexBuffer(
        seq_indices,
        node,
        renderer.device,
    )

    node.texture.handle = seq_texture

    node.text = strings.clone(text, allocator)

    node.indirect_draw_buffer = createNodeDrawBuffer(node, renderer.device)
}
