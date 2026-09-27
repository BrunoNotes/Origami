package engine

import "../vendor/sdl3"
import "../vendor/sdl3_ttf"
import "core:log"
import "core:math/linalg"
import "core:strings"

TextNode :: struct {
    indices:  []u32,
    vertices: []Vertex,
    texture:  ^sdl3.GPUTexture,
}

//TODO: make a pipeline for text

drawTextNode :: proc(
    node: ^Node,
    text: string,
    renderer: ^Renderer,
    cmd_buffer: ^sdl3.GPUCommandBuffer,
    render_pass: ^sdl3.GPURenderPass,
    camera: Maybe(Camera) = nil,
    font: ^sdl3_ttf.Font = nil,
    allocator := context.allocator,
) {
    font := font
    camera := camera

    if font == nil {
        font = renderer.default_font
    }

    if camera == nil {
        camera = D2_CAMERA
    }

    // log.debugf("new: \"%v\", old: \"%v\"", text, node.text)
    if text != node.text {
        updateTextNode(node, text, font, renderer, allocator)
    }

    updateNode(node)
    drawNode(node, camera.?, cmd_buffer, render_pass, renderer)
}

sequenceToTextNode :: proc(
    text: ^sdl3_ttf.Text,
    font: ^sdl3_ttf.Font = nil,
    window_width, window_height: f32,
) -> TextNode {
    text_node: TextNode

    font_height := cast(f32)sdl3_ttf.GetFontHeight(font)

    sequence := sdlCheck(sdl3_ttf.GetGPUTextDrawData(text))
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
            vertices[i] = vertex
        }

        indices := make([]u32, sequence.num_indices, context.temp_allocator)
        for i: i32 = 0; i < sequence.num_indices; i += 1 {
            indices[i] = cast(u32)sequence.indices[i]
        }

        text_node = {
            vertices = vertices,
            indices  = indices,
            texture  = sequence.atlas_texture,
        }
        sequence = sequence.next
    }

    return text_node
}

updateTextNode :: proc(
    node: ^Node,
    text: string,
    font: ^sdl3_ttf.Font,
    renderer: ^Renderer,
    allocator := context.allocator,
) {
    text_to_render := sdlCheck(
        sdl3_ttf.CreateText(
            renderer.txt_engine,
            font,
            strings.clone_to_cstring(text, context.temp_allocator),
            0,
        ),
    )
    defer sdl3_ttf.DestroyText(text_to_render)

    txt_node := sequenceToTextNode(
        text_to_render,
        font,
        cast(f32)renderer.window_width,
        cast(f32)renderer.window_height,
    )

    node.vertex_buffer, node.vertex_len = createNodeVertexBuffer(
        txt_node.vertices,
        node,
        renderer.device,
    )

    node.index_buffer, node.index_len = createNodeIndexBuffer(
        txt_node.indices,
        node,
        renderer.device,
    )

    node.texture.handle = txt_node.texture

    node.text = strings.clone(text, allocator)

    node.indirect_draw_buffer = createNodeDrawBuffer(node, renderer.device)
}
