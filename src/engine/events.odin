package engine

import "../vendor/sdl3"
import "core:c"

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

                destroyTexture(engine.renderer.depth_texture, engine.renderer.device)
                engine.renderer.depth_texture = initDepthTexture(
                    engine.renderer.window_width,
                    engine.renderer.window_height,
                    engine.renderer.device,
                )

            }
        case .KEY_DOWN:
            {
                input_event := engine.input.state[event.key.scancode]
                input_event.down = true
                input_event.up = false
                engine.input.state[event.key.scancode] = input_event
            }
        case .KEY_UP:
            {
                input_event := engine.input.state[event.key.scancode]
                input_event.down = false
                input_event.up = true
                engine.input.state[event.key.scancode] = input_event
            }
        case .MOUSE_BUTTON_DOWN:
            {
                input_event :=
                    engine.input.state[cast(MouseInput)event.button.button]
                input_event.down = true
                input_event.up = false
                input_event.double_click = event.button.clicks >= 2
                engine.input.state[cast(MouseInput)event.button.button] =
                    input_event
            }
        case .MOUSE_BUTTON_UP:
            {
                input_event :=
                    engine.input.state[cast(MouseInput)event.button.button]
                input_event.down = false
                input_event.up = true
                input_event.double_click = event.button.clicks >= 2
                engine.input.state[cast(MouseInput)event.button.button] =
                    input_event
            }
        case .MOUSE_MOTION:
            {
                input_event := engine.input.state[MouseInput.M_MOTION]
                input_event.mouse_motion = event.motion
                engine.input.state[MouseInput.M_MOTION] = input_event
            }
        case .MOUSE_WHEEL:
            {
                mouse_wheel_event := engine.input.state[MouseInput.M_WHEEL]
                mouse_wheel_event.scrolling = true
                mouse_wheel_event.mouse_wheel = event.wheel
                engine.input.state[MouseInput.M_WHEEL] = mouse_wheel_event
            }
        }
    }
}
