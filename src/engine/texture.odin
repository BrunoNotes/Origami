package engine

import "../vendor/sdl3"
import "core:encoding/uuid"
import "core:log"
import "core:strings"

Texture :: struct {
    handle:  ^sdl3.GPUTexture,
    type:    sdl3.GPUTextureType,
    format:  sdl3.GPUTextureFormat,
    sampler: ^sdl3.GPUSampler,
    destroy: bool,
}

initTextureSampler :: proc(
    device: ^sdl3.GPUDevice,
    address_mode: sdl3.GPUSamplerAddressMode = .REPEAT,
) -> ^sdl3.GPUSampler {
    sampler_info: sdl3.GPUSamplerCreateInfo = {
        min_filter        = .LINEAR,
        mag_filter        = .LINEAR,
        mipmap_mode       = .LINEAR,
        address_mode_u    = address_mode,
        address_mode_v    = address_mode,
        address_mode_w    = address_mode,
        enable_anisotropy = true,
        max_anisotropy    = 16.0,
        mip_lod_bias      = 0.0,
        min_lod           = 0.0,
        max_lod           = 0.0,
        props             = 0,
    }

    return sdl3.CreateGPUSampler(device, sampler_info)
}

destroyTextureSampler :: proc(
    sampler: ^sdl3.GPUSampler,
    device: ^sdl3.GPUDevice,
) {
    sdl3.ReleaseGPUSampler(device, sampler)
}

initTextureImage :: proc(
    img: Image,
    device: ^sdl3.GPUDevice,
    sampler: ^sdl3.GPUSampler = nil,
    allocator := context.allocator,
) -> Texture {
    tex: Texture

    if sampler == nil {
        tex.sampler = initTextureSampler(device)
    }

    tex.type = .D2
    tex.format = .R8G8B8A8_UNORM_SRGB
    // tex.format = .R8G8B8A8_UNORM
    texture_usage: sdl3.GPUTextureUsageFlags = {.SAMPLER}
    assert(
        sdl3.GPUTextureSupportsFormat(
            device,
            tex.format,
            tex.type,
            texture_usage,
        ),
    )

    texture_info: sdl3.GPUTextureCreateInfo = {
        type                 = tex.type,
        format               = tex.format,
        usage                = texture_usage,
        width                = cast(u32)img.width,
        height               = cast(u32)img.height,
        layer_count_or_depth = 1,
        num_levels           = 1,
        sample_count         = ._1,
        props                = 0,
    }

    tex.handle = sdl3.CreateGPUTexture(device, texture_info)
    tex.format = texture_info.format

    img_name := uuid.to_string(uuid.generate_v7())

    sdl3.SetGPUTextureName(
        device,
        tex.handle,
        strings.clone_to_cstring(img_name, context.temp_allocator),
    )

    uploadTextureBuffer(tex.handle, img, device)

    tex.destroy = true

    return tex
}

initDepthTexture :: proc(
    window_width, window_height: i32,
    device: ^sdl3.GPUDevice,
) -> Texture {
    tex: Texture

    tex.type = .D2
    texture_usage: sdl3.GPUTextureUsageFlags = {.DEPTH_STENCIL_TARGET}

    if (sdl3.GPUTextureSupportsFormat(
               device,
               .D32_FLOAT,
               tex.type,
               texture_usage,
           )) {
        tex.format = .D32_FLOAT
    } else if (sdl3.GPUTextureSupportsFormat(
               device,
               .D32_FLOAT_S8_UINT,
               tex.type,
               texture_usage,
           )) {
        tex.format = .D32_FLOAT_S8_UINT
    } else if (sdl3.GPUTextureSupportsFormat(
               device,
               .D24_UNORM_S8_UINT,
               tex.type,
               texture_usage,
           )) {
        tex.format = .D24_UNORM_S8_UINT
    } else if (sdl3.GPUTextureSupportsFormat(
               device,
               .D16_UNORM,
               tex.type,
               texture_usage,
           )) {
        tex.format = .D16_UNORM
    } else {
        log.fatal(
            "The graphics device does not support any valid depth formats!",
        )
    }

    texture_info: sdl3.GPUTextureCreateInfo = {
        type                 = tex.type,
        format               = tex.format,
        usage                = texture_usage,
        width                = cast(u32)window_width,
        height               = cast(u32)window_height,
        layer_count_or_depth = 1,
        num_levels           = 1,
        sample_count         = ._1,
        props                = 0,
    }

    tex.handle = sdl3.CreateGPUTexture(device, texture_info)

    tex.destroy = true

    return tex
}

destroyTexture :: proc(texture: Texture, device: ^sdl3.GPUDevice) {
    if !texture.destroy {
        return
    }

    if texture.sampler != nil {
        destroyTextureSampler(texture.sampler, device)
    }
    sdl3.ReleaseGPUTexture(device, texture.handle)
}
