package engine

import "../vendor/sdl3"
import "../vendor/sdl3_ttf"
import "core:encoding/uuid"
import "core:log"
import "core:math/linalg"
import "core:strings"

NodeType :: enum {
    Undefined,
    Text,
}

NodeAlphaMode :: enum {
    Opaque,
    Transparent,
}

Node :: struct {
    vertex_buffer, index_buffer, indirect_draw_buffer: ^sdl3.GPUBuffer,
    vertex_len, index_len, instances:                  u32,
    texture:                                           Texture,
    rotation:                                          linalg.Quaternionf32,
    translation, scale:                                linalg.Vector3f32,
    transform_matrix:                                  linalg.Matrix4f32,
    color:                                             linalg.Vector4f32,
    type:                                              NodeType,
    id, text:                                          string,
    font:                                              ^sdl3_ttf.Font,
    alpha_mode:                                        NodeAlphaMode,
    double_sided:                                      bool,
    alpha_cutoff:                                      f32,
}

NodeInitOpts :: struct {
    type:                NodeType,
    id, parent_id, text: string,
    vertices:            []Vertex,
    indices:             []u32,
    texture:             Texture,
    instances:           u32,
    rotation:            linalg.Quaternionf32,
    translation, scale:  linalg.Vector3f32,
    transform_matrix:    linalg.Matrix4f32,
    color:               linalg.Vector4f32,
    font:                ^sdl3_ttf.Font,
    alpha_mode:          NodeAlphaMode,
    double_sided:        bool,
    alpha_cutoff:        f32,
}

initNode :: proc(
    opts: NodeInitOpts,
    renderer: ^Renderer,
    allocator := context.allocator,
) -> ^Node {
    node := new(Node, allocator)

    if len(opts.id) <= 0 {
        node.id = uuid.to_string(uuid.generate_v7(), allocator)
    } else {
        node.id = opts.id
    }

    node.type = opts.type

    if len(opts.vertices) > 0 {
        node.vertex_buffer, node.vertex_len = createNodeVertexBuffer(
            opts.vertices,
            node,
            renderer.device,
        )
    }

    if len(opts.indices) > 0 {
        node.index_buffer, node.index_len = createNodeIndexBuffer(
            opts.indices,
            node,
            renderer.device,
        )
    }

    node.texture = opts.texture

    if node.texture.handle == nil {
        img := loadBlankImage()
        defer freeImage(img)

        node.texture = initTextureImage(
            img,
            renderer.device,
            renderer.texture_sampler,
            allocator,
        )
    }

    node.instances = opts.instances <= 0 ? 1 : opts.instances
    node.rotation = opts.rotation
    node.translation = opts.translation
    node.alpha_mode = opts.alpha_mode

    node.scale = opts.scale == 0 ? 1 : opts.scale

    node.color = opts.color == 0 ? 1 : opts.color

    node.indirect_draw_buffer = createNodeDrawBuffer(node, renderer.device)

    node.text = strings.clone(opts.text, allocator)

    if opts.font != nil {
        node.font = opts.font
    }

    node.double_sided = opts.double_sided
    node.alpha_cutoff = opts.alpha_cutoff

    return node
}

destroyNode :: proc(node: ^Node, renderer: ^Renderer) {
    if node == nil {
        log.errorf("Node is nil, unable to destroy")
        return
    }

    if node.indirect_draw_buffer != nil {
        sdl3.ReleaseGPUBuffer(renderer.device, node.indirect_draw_buffer)
    }

    destroyTexture(node.texture, renderer.device)

    if node.index_buffer != nil {
        sdl3.ReleaseGPUBuffer(renderer.device, node.index_buffer)
    }

    if node.vertex_buffer != nil {
        sdl3.ReleaseGPUBuffer(renderer.device, node.vertex_buffer)
    }

    free(node)
}

createNodeDrawBuffer :: proc(
    node: ^Node,
    device: ^sdl3.GPUDevice,
) -> ^sdl3.GPUBuffer {
    if node.indirect_draw_buffer != nil {
        sdl3.ReleaseGPUBuffer(device, node.indirect_draw_buffer)
    }

    // TODO: Group more cmds, this is not the most performant
    cmd := [?]sdl3.GPUIndexedIndirectDrawCommand {
        {
            num_indices = node.index_len,
            num_instances = node.instances,
            first_index = 0,
            vertex_offset = 0,
            first_instance = 0,
        },
    }

    node.indirect_draw_buffer = uploadGpuBuffer(
        {
            usage = {.INDIRECT},
            size = u32(size_of(sdl3.GPUIndexedIndirectDrawCommand) * len(cmd)),
        },
        raw_data(cmd[:]),
        device,
    )

    return node.indirect_draw_buffer
}

createNodeVertexBuffer :: proc(
    vertices: []Vertex,
    node: ^Node,
    device: ^sdl3.GPUDevice,
) -> (
    ^sdl3.GPUBuffer,
    u32,
) {
    if node.vertex_buffer != nil {
        sdl3.ReleaseGPUBuffer(device, node.vertex_buffer)
    }

    vertex_buffer_info: sdl3.GPUBufferCreateInfo
    vertex_buffer_info.size = cast(u32)(size_of(Vertex) * len(vertices))
    vertex_buffer_info.usage = {.VERTEX}

    node.vertex_buffer = uploadGpuBuffer(
        vertex_buffer_info,
        raw_data(vertices[:]),
        device,
    )

    assert(node.vertex_buffer != nil)

    node.vertex_len = cast(u32)len(vertices)

    return node.vertex_buffer, node.vertex_len
}

createNodeIndexBuffer :: proc(
    indices: []u32,
    node: ^Node,
    device: ^sdl3.GPUDevice,
) -> (
    ^sdl3.GPUBuffer,
    u32,
) {
    if node.index_buffer != nil {
        sdl3.ReleaseGPUBuffer(device, node.index_buffer)
    }

    index_buffer_info: sdl3.GPUBufferCreateInfo
    index_buffer_info.size = cast(u32)(size_of(u32) * len(indices))
    index_buffer_info.usage = {.INDEX}

    node.index_buffer = uploadGpuBuffer(
        index_buffer_info,
        raw_data(indices[:]),
        device,
    )

    assert(node.index_buffer != nil)

    node.index_len = cast(u32)len(indices)

    return node.index_buffer, node.index_len
}

updateNode :: proc(node: ^Node) {
    if node == nil {
        return
    }
    // projection
    rot := linalg.matrix4_from_quaternion(node.rotation)

    center: linalg.Vector3f32 = 0

    t_minus := linalg.matrix4_translate(-center)
    t_plus := linalg.matrix4_translate(center)

    rotation_matrix := t_plus * rot * t_minus

    translation := linalg.matrix4_translate(node.translation)

    node.transform_matrix =
        translation * rotation_matrix * linalg.matrix4_scale(node.scale)
}

drawNode :: proc(
    node: ^Node,
    cmd_buffer: ^sdl3.GPUCommandBuffer,
    render_pass: ^sdl3.GPURenderPass,
    renderer: ^Renderer,
) {
    sdl3.PushGPUVertexUniformData(
        cmd_buffer,
        2,
        &node.transform_matrix,
        size_of(linalg.Matrix4f32),
    )

    sdl3.PushGPUFragmentUniformData(
        cmd_buffer,
        0,
        &node.color,
        size_of(linalg.Vector4f32),
    )

    if node.type != .Text {
        sdl3.PushGPUFragmentUniformData(
            cmd_buffer,
            1,
            &node.alpha_cutoff,
            size_of(f32),
        )
    }

    vertex_buffer_bindings := [?]sdl3.GPUBufferBinding {
        {buffer = node.vertex_buffer, offset = 0},
    }

    sdl3.BindGPUVertexBuffers(
        render_pass,
        0,
        raw_data(vertex_buffer_bindings[:]),
        len(vertex_buffer_bindings),
    )

    index_buffer_bindings := sdl3.GPUBufferBinding {
        buffer = node.index_buffer,
        offset = 0,
    }

    sdl3.BindGPUIndexBuffer(render_pass, index_buffer_bindings, ._32BIT)

    texture_buffer_bindings := [?]sdl3.GPUTextureSamplerBinding {
        {
            texture = node.texture.handle,
            sampler = node.texture.sampler == nil ? renderer.texture_sampler : node.texture.sampler,
        },
    }

    sdl3.BindGPUFragmentSamplers(
        render_pass,
        0,
        raw_data(texture_buffer_bindings[:]),
        len(texture_buffer_bindings),
    )

    // sdl3.DrawGPUIndexedPrimitives(
    //     render_pass,
    //     node.index_len,
    //     node.vertex_len,
    //     0,
    //     0,
    //     0,
    // )

    sdl3.DrawGPUIndexedPrimitivesIndirect(
        render_pass,
        node.indirect_draw_buffer,
        0,
        // node.indirect_draw_count,
        1,
    )
}
