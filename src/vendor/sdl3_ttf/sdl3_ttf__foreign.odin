package sdl3_ttf

// TODO: maybe try to vendor this system deps
when ODIN_OS == .Windows {
    foreign import lib {"SDL3_ttf.lib", "system:freetype", "system:harfbuzz", "system:plutosvg"}
} else when ODIN_OS == .Linux {
    @(export)
    foreign import lib {"./lib/linux/libSDL3_ttf.a", "system:freetype", "system:harfbuzz", "system:plutosvg"}
} else {
    foreign import lib {"system:SDL3_ttf", "system:freetype", "system:harfbuzz", "system:plutosvg"}
}
