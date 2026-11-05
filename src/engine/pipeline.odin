package engine

import "../vendor/sdl3"
import "base:runtime"
import "core:encoding/uuid"
import "core:fmt"
import "core:log"
import "core:math/linalg"
import "core:slice"
import "core:sort"

@(private)
_g_sort_ctx: runtime.Context

PipelineInitOpts :: struct {
    wireframe:                  bool,
    depth_write:                bool, // true = opaque, false = transparent
    vertex_samplers:            u32,
    vertex_storage_buffers:     u32,
    vertex_storage_textures:    u32,
    vertex_uniform_buffers:     u32,
    fragment_samplers:          u32,
    fragment_storage_buffers:   u32,
    fragment_storage_textures:  u32,
    fragment_uniform_buffers:   u32,
    vertex_code, fragment_code: []u8,
    id:                         string,
}

Pipeline :: struct {
    handle:     ^sdl3.GPUGraphicsPipeline,
    id:         string,
    nodes:      [dynamic]^Node,
    alpha_mode: NodeAlphaMode,
}

initPipeline :: proc(
    opts: PipelineInitOpts,
    renderer: ^Renderer,
    allocator := context.allocator,
) -> ^Pipeline {
    assert(len(opts.vertex_code) > 0, "Vertex code not defined")
    assert(len(opts.fragment_code) > 0, "Fragment code not defined")

    pipeline := new(Pipeline, allocator)
    pipeline.nodes = make([dynamic]^Node, allocator)

    if len(opts.id) <= 0 {
        pipeline.id = uuid.to_string(uuid.generate_v7(), allocator)
    } else {
        pipeline.id = opts.id
    }

    vertex_shader := initGpuShader(
        opts.vertex_code,
        renderer.device,
        format = {.SPIRV},
        stage = .VERTEX,
        samplers = opts.vertex_samplers,
        storage_buffers = opts.vertex_storage_buffers,
        storage_textures = opts.vertex_storage_textures,
        uniform_buffers = opts.vertex_uniform_buffers,
    )

    fragment_shader := initGpuShader(
        opts.fragment_code,
        renderer.device,
        format = {.SPIRV},
        stage = .FRAGMENT,
        samplers = opts.fragment_samplers,
        storage_buffers = opts.fragment_storage_buffers,
        storage_textures = opts.fragment_storage_textures,
        uniform_buffers = opts.fragment_uniform_buffers,
    )

    pipeline_info: sdl3.GPUGraphicsPipelineCreateInfo
    pipeline_info.vertex_shader = vertex_shader
    pipeline_info.fragment_shader = fragment_shader
    pipeline_info.primitive_type = .TRIANGLELIST

    vertex_buffer_descriptions := [?]sdl3.GPUVertexBufferDescription {
        {
            slot = 0,
            input_rate = .VERTEX,
            instance_step_rate = 0,
            pitch = size_of(Vertex),
        },
    }

    pipeline_info.vertex_input_state.num_vertex_buffers = len(
        vertex_buffer_descriptions,
    )
    pipeline_info.vertex_input_state.vertex_buffer_descriptions = raw_data(
        vertex_buffer_descriptions[:],
    )

    vertex_attributes := [?]sdl3.GPUVertexAttribute {
        // position
        {
            buffer_slot = 0,
            location = 0,
            format = .FLOAT3,
            offset = u32(offset_of(Vertex, position)),
        },
        // color
        {
            buffer_slot = 0,
            location = 1,
            format = .FLOAT4,
            offset = u32(offset_of(Vertex, color)),
        },
        {
            buffer_slot = 0,
            location = 2,
            format = .FLOAT2,
            offset = u32(offset_of(Vertex, uv)),
        },
        {
            buffer_slot = 0,
            location = 3,
            format = .FLOAT3,
            offset = u32(offset_of(Vertex, normal)),
        },
    }

    pipeline_info.vertex_input_state.num_vertex_attributes = len(
        vertex_attributes,
    )
    pipeline_info.vertex_input_state.vertex_attributes = raw_data(
        vertex_attributes[:],
    )

    // color_write_mask:        GPUColorComponentFlags,  /**< A bitmask specifying which of the RGBA components are enabled for writing. Writes to all channels if enable_color_write_mask is false. */
    // enable_color_write_mask: bool,                    /**< Whether the color write mask is enabled. */
    color_target_descriptions := [?]sdl3.GPUColorTargetDescription {
        {
            blend_state = {
                enable_blend = true,
                color_blend_op = .ADD,
                alpha_blend_op = .ADD,
                src_color_blendfactor = .SRC_ALPHA,
                dst_color_blendfactor = .ONE_MINUS_SRC_ALPHA,
                src_alpha_blendfactor = .ONE,
                dst_alpha_blendfactor = .ONE_MINUS_SRC_ALPHA,
                color_write_mask = {.R, .G, .B, .A},
                enable_color_write_mask = true,
            },
            format = sdl3.GetGPUSwapchainTextureFormat(
                renderer.device,
                renderer.window,
            ),
        },
    }

    pipeline_info.target_info.num_color_targets = len(
        color_target_descriptions,
    )
    pipeline_info.target_info.color_target_descriptions = raw_data(
        color_target_descriptions[:],
    )

    pipeline_info.target_info.has_depth_stencil_target = true
    pipeline_info.target_info.depth_stencil_format =
        renderer.depth_texture.format

    pipeline_info.depth_stencil_state = {
        compare_op          = .LESS,
        back_stencil_state  = {
            // compare_op = .NEVER,
            // fail_op = .REPLACE,
            // pass_op = .KEEP,
            // depth_fail_op = .KEEP,
        },
        front_stencil_state = {
            // compare_op = .NEVER,
            // fail_op = .REPLACE,
            // pass_op = .KEEP,
            // depth_fail_op = .KEEP,
        },
        compare_mask        = 0,
        // write_mask = 0xFF,
        write_mask          = 0,
        enable_depth_test   = true,
        enable_depth_write  = opts.depth_write,
        enable_stencil_test = false,
    }

    if !opts.depth_write {
        pipeline.alpha_mode = .Transparent
    } else {
        pipeline.alpha_mode = .Opaque
    }

    pipeline_info.rasterizer_state = {
        fill_mode                  = opts.wireframe ? .LINE : .FILL,
        cull_mode                  = .BACK,
        front_face                 = .COUNTER_CLOCKWISE,
        depth_bias_constant_factor = 0,
        depth_bias_clamp           = 0,
        depth_bias_slope_factor    = 0,
        enable_depth_bias          = false,
        enable_depth_clip          = false,
    }

    pipeline.handle = sdl3.CreateGPUGraphicsPipeline(
        renderer.device,
        pipeline_info,
    )

    sdl3.ReleaseGPUShader(renderer.device, vertex_shader)
    sdl3.ReleaseGPUShader(renderer.device, fragment_shader)

    return pipeline
}

destroyPipeline :: proc(device: ^sdl3.GPUDevice, pipeline: ^Pipeline) {
    sdl3.ReleaseGPUGraphicsPipeline(device, pipeline.handle)
    delete(pipeline.nodes)
    free(pipeline)
}

bindPipeline :: proc(render_pass: ^sdl3.GPURenderPass, pipeline: ^Pipeline) {
    sdl3.BindGPUGraphicsPipeline(render_pass, pipeline.handle)
}

initGpuShader :: proc(
    code: []u8,
    device: ^sdl3.GPUDevice,
    format: sdl3.GPUShaderFormat,
    stage: sdl3.GPUShaderStage,
    samplers: u32 = 0,
    storage_buffers: u32 = 0,
    storage_textures: u32 = 0,
    uniform_buffers: u32 = 0,
) -> ^sdl3.GPUShader {
    shader_info: sdl3.GPUShaderCreateInfo
    shader_info.code = raw_data(code)
    shader_info.code_size = len(code)
    shader_info.entrypoint = "main"
    shader_info.format = format
    shader_info.stage = stage
    shader_info.num_samplers = samplers
    shader_info.num_storage_buffers = storage_buffers
    shader_info.num_storage_textures = storage_textures
    shader_info.num_uniform_buffers = uniform_buffers

    return sdl3.CreateGPUShader(device, shader_info)
}

renderPipeline :: proc(
    cmd_buffer: ^sdl3.GPUCommandBuffer,
    render_pass: ^sdl3.GPURenderPass,
    pipeline: ^Pipeline,
    camera: Camera,
    renderer: ^Renderer,
) {
    camera := camera
    bindPipeline(render_pass, pipeline)

    if pipeline.alpha_mode == .Transparent {
        _g_sort_ctx.user_ptr = &camera

        slice.sort_by(pipeline.nodes[:], proc(a, b: ^Node) -> bool {
            context = _g_sort_ctx
            camera := (^Camera)(context.user_ptr)
            fmt.printfln("%v", camera.translation)
            dist_a := linalg.length(a.translation - camera.translation)
            dist_b := linalg.length(b.translation - camera.translation)
            if dist_a > dist_b {
                return true
            } else {
                return false
            }
        })

        _g_sort_ctx.user_ptr = nil
    }

    for node in pipeline.nodes {
        updateNode(node)

        if node.type == .Text {
            // TODO: Temp
            drawNode(node, D2_CAMERA, cmd_buffer, render_pass, renderer)
        } else {
            drawNode(node, camera, cmd_buffer, render_pass, renderer)
        }
    }
}
