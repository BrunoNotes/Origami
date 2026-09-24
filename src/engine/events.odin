package engine

import "core:c"
import "../vendor/sdl3"

processEvents :: proc(engine: ^Engine) {
    event: sdl3.Event
    for sdl3.PollEvent(&event) {
        #partial switch event.type {
        case .QUIT:
            engine.renderer.window_open = false
        case .WINDOW_RESIZED:
            {
                w_width, w_height: c.int
                sdl3.GetWindowSize(engine.renderer.window, &w_width, &w_height)

                engine.renderer.window_width = w_width
                engine.renderer.window_height = w_height
            }
        }
    }
}
