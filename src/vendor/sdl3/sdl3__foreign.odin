package sdl3

when ODIN_OS == .Windows {
    @(export)
    // @(extra_linker_flags="ole32.lib shell32.lib user32.lib gdi32.lib imm32.lib oleaut32.lib version.lib cfgmgr32.lib ucrt.lib setupapi.lib advapi32.lib winmm.lib")
    // foreign import lib "./lib/windows/SDL3-static.lib"
    foreign import lib "./lib/windows/SDL3.lib"
} else when ODIN_OS == .Linux {
    @(export)
    foreign import lib "./lib/linux/libSDL3.a"
} else {
    @(export)
    foreign import lib "system:SDL3"
}

