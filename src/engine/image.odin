package engine

import stbi "../vendor/stb/image"
import "core:c"
import "core:encoding/uuid"
import "core:log"
import "core:strings"

DEFAULT_IMAGE_BYTE := #load("../../assets/textures/default.png")
BLANK_PIXELS_BYTE := [4]u8{255, 255, 255, 255}

ImageType :: enum {
    STB,
    Blank,
    Default,
}

Image :: struct {
    width, height, channels: i32,
    data:                    [^]byte,
    type:                    ImageType,
}

loadImage :: proc {
    loadImageByte,
    loadImageFile,
    loadBlankImage,
}

loadImageByte :: proc(
    img_byte: []byte,
    allocator := context.allocator,
) -> Image {
    img := Image{}
    img.type = .STB

    // stbi.set_flip_vertically_on_load(1)

    img.data = stbi.load_from_memory(
        raw_data(img_byte),
        i32(len(img_byte)),
        &img.width,
        &img.height,
        &img.channels,
        cast(c.int)stbi.Channels.rgb_alpha,
    )
    // defer stbi.image_free(img.data)

    if img.data == nil {
        log.errorf("Error loading texture byte: %v", stbi.failure_reason())

        img.data = stbi.load_from_memory(
            raw_data(DEFAULT_IMAGE_BYTE),
            i32(len(DEFAULT_IMAGE_BYTE)),
            &img.width,
            &img.height,
            &img.channels,
            cast(c.int)stbi.Channels.rgb_alpha,
        )
    }

    return img
}

loadImageFile :: proc(
    file_path: string,
    // name: string = "",
    allocator := context.allocator,
) -> Image {
    img := Image{}
    img.type = .STB

    // stbi.set_flip_vertically_on_load(1)

    img.data = stbi.load(
        strings.clone_to_cstring(file_path, context.temp_allocator),
        &img.width,
        &img.height,
        &img.channels,
        cast(c.int)stbi.Channels.rgb_alpha,
    )
    // defer stbi.image_free(img.data)

    if img.data == nil {
        log.errorf(
            "Error loading texture %v: %v",
            file_path,
            stbi.failure_reason(),
        )

        img.data = stbi.load_from_memory(
            raw_data(DEFAULT_IMAGE_BYTE),
            i32(len(DEFAULT_IMAGE_BYTE)),
            &img.width,
            &img.height,
            &img.channels,
            cast(c.int)stbi.Channels.rgb_alpha,
        )
    }

    return img
}

loadBlankImage :: proc() -> Image {
    img := Image {
        width      = 1,
        height     = 1,
        channels   = 4,
        data       = raw_data(&BLANK_PIXELS_BYTE),
        type       = .Blank,
    }

    return img
}

freeImage :: proc(img: Image) {
    #partial switch img.type {
    case .STB:
        stbi.image_free(img.data)
    }
}
