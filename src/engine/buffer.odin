package engine

import "../vendor/sdl3"
import "core:mem"

uploadGpuBuffer :: proc(
    buffer_info: sdl3.GPUBufferCreateInfo,
    items: rawptr,
    device: ^sdl3.GPUDevice,
) -> ^sdl3.GPUBuffer {
    buffer := sdl3.CreateGPUBuffer(device, buffer_info)

    transfer_info: sdl3.GPUTransferBufferCreateInfo
    transfer_info.size = buffer_info.size
    transfer_info.usage = .UPLOAD

    transfer_buffer := sdl3.CreateGPUTransferBuffer(device, transfer_info)
    defer sdl3.ReleaseGPUTransferBuffer(device, transfer_buffer)

    data := sdl3.MapGPUTransferBuffer(device, transfer_buffer, false)

    mem.copy(data, items, cast(int)buffer_info.size)

    sdl3.UnmapGPUTransferBuffer(device, transfer_buffer)

    cmd := sdl3.AcquireGPUCommandBuffer(device)

    copy_pass := sdl3.BeginGPUCopyPass(cmd)

    location: sdl3.GPUTransferBufferLocation
    location.transfer_buffer = transfer_buffer
    location.offset = 0

    region: sdl3.GPUBufferRegion
    region.buffer = buffer
    region.size = buffer_info.size
    region.offset = 0

    sdl3.UploadToGPUBuffer(copy_pass, location, region, true)

    sdl3.EndGPUCopyPass(copy_pass)
    assert(sdl3.SubmitGPUCommandBuffer(cmd))

    return buffer
}

uploadTextureBuffer :: proc(
    texture: ^sdl3.GPUTexture,
    image: Image,
    device: ^sdl3.GPUDevice,
) {
    channels := image.channels < 4 ? 4 : image.channels
    image_size := u32(image.width * image.height * channels)

    transfer_info: sdl3.GPUTransferBufferCreateInfo
    transfer_info.size = image_size
    transfer_info.usage = .UPLOAD

    transfer_buffer := sdl3.CreateGPUTransferBuffer(device, transfer_info)
    defer sdl3.ReleaseGPUTransferBuffer(device, transfer_buffer)

    data := sdl3.MapGPUTransferBuffer(device, transfer_buffer, false)

    mem.copy(data, image.data, cast(int)image_size)

    sdl3.UnmapGPUTransferBuffer(device, transfer_buffer)

    cmd := sdl3.AcquireGPUCommandBuffer(device)

    copy_pass := sdl3.BeginGPUCopyPass(cmd)

    texture_transfer_info: sdl3.GPUTextureTransferInfo = {
        transfer_buffer = transfer_buffer,
        offset          = 0,
        pixels_per_row  = u32(image.width),
        rows_per_layer  = u32(image.height),
    }

    region: sdl3.GPUTextureRegion = {
        texture   = texture,
        mip_level = 0,
        layer     = 0,
        x         = 0,
        y         = 0,
        z         = 0,
        w         = u32(image.width),
        h         = u32(image.height),
        d         = 1,
    }

    sdl3.UploadToGPUTexture(copy_pass, texture_transfer_info, region, false)

    sdl3.EndGPUCopyPass(copy_pass)
    assert(sdl3.SubmitGPUCommandBuffer(cmd))
}
