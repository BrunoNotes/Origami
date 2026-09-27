package engine

import "../vendor/sdl3"
import "../vendor/sdl3_ttf"
import "base:runtime"
import "core:c"
import "core:strings"

Renderer :: struct {
    window:                        ^sdl3.Window,
    window_width, window_height:   i32,
    window_open:                   bool,
    device:                        ^sdl3.GPUDevice,
    texture_sampler, font_sampler: ^sdl3.GPUSampler,
    depth_texture:                 Texture,
    txt_engine:                    ^sdl3_ttf.TextEngine,
    default_font:                  ^sdl3_ttf.Font,
    config:                        RendererConfig,
}

RendererConfig :: struct {
    present_mode:          sdl3.GPUPresentMode,
    mouse_captured:        bool,
    swapchain_composition: sdl3.GPUSwapchainComposition,
}

RendererInitOpts :: struct {
    window_title:                string,
    window_width, window_height: i32,
    vsync, hdr, mouse_captured:  bool,
}

initRenderer :: proc(
    opts: RendererInitOpts,
    allocator := context.allocator,
) -> ^Renderer {
    opts := opts
    renderer := new(Renderer, allocator)

    assert(opts.window_width > 0)
    assert(opts.window_height > 0)

    if len(opts.window_title) <= 0 {
        opts.window_title = "Origami Window"
    }

    renderer.window = sdlCheck(
        sdl3.CreateWindow(
            strings.clone_to_cstring(
                opts.window_title,
                context.temp_allocator,
            ),
            cast(c.int)opts.window_width,
            cast(c.int)opts.window_height,
            {.RESIZABLE, .VULKAN},
        ),
    )

    renderer.window_open = true
    renderer.window_width = i32(opts.window_width)
    renderer.window_height = i32(opts.window_height)

    assert(
        sdl3.SetWindowRelativeMouseMode(renderer.window, opts.mouse_captured),
    )

    renderer.config.mouse_captured = opts.mouse_captured

    device_props := sdl3.CreateProperties()

    when ODIN_DEBUG {
        sdl3.SetBooleanProperty(
            device_props,
            sdl3.PROP_GPU_DEVICE_CREATE_DEBUGMODE_BOOLEAN,
            true,
        )

        sdl3.SetBooleanProperty(
            device_props,
            sdl3.PROP_GPU_DEVICE_CREATE_VERBOSE_BOOLEAN,
            true,
        )
    } else {
        sdl3.SetBooleanProperty(
            device_props,
            sdl3.PROP_GPU_DEVICE_CREATE_DEBUGMODE_BOOLEAN,
            false,
        )
    }

    sdl3.SetBooleanProperty(
        device_props,
        sdl3.PROP_GPU_DEVICE_CREATE_SHADERS_SPIRV_BOOLEAN,
        true,
    )

    vk_options: sdl3.GPUVulkanOptions = {
        vulkan_api_version = MAKE_API_VERSION(0, 1, 3, 0),
    }

    sdl3.SetPointerProperty(
        device_props,
        sdl3.PROP_GPU_DEVICE_CREATE_VULKAN_OPTIONS_POINTER,
        &vk_options,
    )

    renderer.device = sdl3.CreateGPUDeviceWithProperties(device_props)

    assert(sdl3.ClaimWindowForGPUDevice(renderer.device, renderer.window))

    if (sdl3.WindowSupportsGPUPresentMode(
               renderer.device,
               renderer.window,
               .MAILBOX,
           )) &&
       !opts.vsync {
        renderer.config.present_mode = .MAILBOX
    } else {
        renderer.config.present_mode = .VSYNC
    }

    if sdl3.WindowSupportsGPUSwapchainComposition(
           renderer.device,
           renderer.window,
           .HDR10_ST2084,
       ) &&
       opts.hdr {
        renderer.config.swapchain_composition = .HDR10_ST2084
    } else {
        renderer.config.swapchain_composition = .SDR
    }

    assert(
        sdl3.SetGPUSwapchainParameters(
            renderer.device,
            renderer.window,
            renderer.config.swapchain_composition,
            renderer.config.present_mode,
        ),
    )

    renderer.texture_sampler = initTextureSampler(renderer.device)
    renderer.font_sampler = initTextureSampler(renderer.device, .CLAMP_TO_EDGE)

    renderer.depth_texture = initDepthTexture(
        renderer.window_width,
        renderer.window_height,
        renderer.device,
    )

    renderer.txt_engine = sdlCheck(
        sdl3_ttf.CreateGPUTextEngine(renderer.device),
    )
    sdl3_ttf.SetGPUTextEngineWinding(renderer.txt_engine, .COUNTER_CLOCKWISE)

    // TODO: make a font size update
    renderer.default_font = sdlCheck(
        sdl3_ttf.OpenFont("assets/fonts/JetBrainsMono-Regular.ttf", 14),
        "Failed to load font:",
    )

    return renderer
}

destroyRenderer :: proc(renderer: ^Renderer) {
    sdl3_ttf.CloseFont(renderer.default_font)
    sdl3_ttf.DestroyGPUTextEngine(renderer.txt_engine)

    destroyTextureSampler(renderer.font_sampler, renderer.device)
    destroyTextureSampler(renderer.texture_sampler, renderer.device)
    destroyTexture(renderer.depth_texture, renderer.device)

    sdl3.DestroyGPUDevice(renderer.device)
    sdl3.DestroyWindow(renderer.window)

    free(renderer)
}

beginRender :: proc(
    renderer: ^Renderer,
) -> (
    ^sdl3.GPUCommandBuffer,
    ^sdl3.GPURenderPass,
) {
    cmd_buffer := sdl3.AcquireGPUCommandBuffer(renderer.device)

    swapchain_texture: ^sdl3.GPUTexture
    swapchain_width, swapchain_height: u32
    // swapchain_width: u32 = cast(u32)renderer.window_width
    // swapchain_height: u32 = cast(u32)renderer.window_height
    assert(
        sdl3.WaitAndAcquireGPUSwapchainTexture(
            cmd_buffer,
            renderer.window,
            &swapchain_texture,
            &swapchain_width,
            &swapchain_height,
        ),
    )

    color_target_info: sdl3.GPUColorTargetInfo = {
        texture               = swapchain_texture,
        mip_level             = 0,
        layer_or_depth_plane  = 0,
        clear_color           = {
            100.0 / 255.0,
            149.0 / 255.0,
            237.0 / 255.0,
            1.0,
        },
        // clear_color = {0, 0, 0, 0},
        load_op               = .CLEAR,
        store_op              = .STORE,
        resolve_texture       = nil,
        resolve_mip_level     = 0,
        resolve_layer         = 0,
        cycle                 = true,
        cycle_resolve_texture = false,
    }

    depth_target_info: sdl3.GPUDepthStencilTargetInfo = {
        texture          = renderer.depth_texture.handle,
        clear_depth      = 1.0,
        load_op          = .CLEAR,
        store_op         = .DONT_CARE,
        stencil_load_op  = .CLEAR,
        stencil_store_op = .DONT_CARE,
        cycle            = false,
        clear_stencil    = 0,
        mip_level        = 0,
        layer            = 0,
    }

    render_pass := sdl3.BeginGPURenderPass(
        cmd_buffer,
        &color_target_info,
        1,
        &depth_target_info,
    )

    // sdl3.BindGPUGraphicsPipeline(render_pass, renderer.mesh_pipeline)

    viewport: sdl3.GPUViewport = {
        x         = 0,
        y         = 0,
        w         = cast(f32)renderer.window_width,
        h         = cast(f32)renderer.window_height,
        min_depth = 0,
        max_depth = 1.0,
    }
    sdl3.SetGPUViewport(render_pass, viewport)

    return cmd_buffer, render_pass
}

endRender :: proc(
    cmd_buffer: ^sdl3.GPUCommandBuffer,
    render_pass: ^sdl3.GPURenderPass,
) {
    sdl3.EndGPURenderPass(render_pass)

    assert(sdl3.SubmitGPUCommandBuffer(cmd_buffer))

}
