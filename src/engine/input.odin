package engine

import "../vendor/sdl3"
import "base:runtime"
import "core:math/linalg"
import "core:reflect"

MouseInput :: enum {
    M_LEFT = sdl3.BUTTON_LEFT,
    M_MIDDLE = sdl3.BUTTON_MIDDLE,
    M_RIGHT = sdl3.BUTTON_RIGHT,
    M_X1 = sdl3.BUTTON_X1,
    M_X2 = sdl3.BUTTON_X2,
    M_WHEEL,
    M_MOTION,
}

InputMode :: enum {
    Global, // runs on all modes
    Normal,
}

InputType :: union {
    sdl3.Scancode,
    MouseInput,
}

InputState :: struct {
    name:                   string,
    up, down, double_click: bool,
    mouse_motion:           sdl3.MouseMotionEvent,
    mouse_wheel:            sdl3.MouseWheelEvent,
    scrolling:              bool,
    scancode:               InputType,
}

Input :: struct {
    state:        map[InputType]InputState,
    current_mode: InputMode,
}

initInput :: proc(allocator: runtime.Allocator = context.allocator) -> ^Input {
    input := new(Input, allocator)

    input.state = make(map[InputType]InputState, allocator)

    for field in reflect.enum_fields_zipped(sdl3.Scancode) {
        input.state[cast(sdl3.Scancode)field.value] = {
            name     = field.name,
            scancode = cast(sdl3.Scancode)field.value,
        }
    }

    for field in reflect.enum_fields_zipped(MouseInput) {
        input.state[cast(sdl3.Scancode)field.value] = {
            name     = field.name,
            scancode = cast(MouseInput)field.value,
        }
    }

    input.current_mode = .Normal

    return input
}

destroyInput :: proc(input: ^Input) {
    free(input)
}

resetInput :: proc(input: ^Input) {
    mouse_wheel_event := input.state[MouseInput.M_WHEEL]
    mouse_wheel_event.scrolling = false
    input.state[MouseInput.M_WHEEL] = mouse_wheel_event
}

isKeyPressed :: proc(
    input: ^Input,
    key: sdl3.Scancode,
    mode: InputMode = .Global,
) -> bool {
    if input.current_mode == mode || mode == .Global {
        return input.state[key].down
    } else {
        return false
    }
}

isMouseButtonPressed :: proc(
    input: ^Input,
    button: MouseInput,
    mode: InputMode = .Global,
) -> bool {
    if input.current_mode == mode || mode == .Global {
        return input.state[button].down
    } else {
        return false
    }
}

getMousePosition :: proc(
    input: ^Input,
    mode: InputMode = .Global,
) -> linalg.Vector2f32 {
    if input.current_mode == mode || mode == .Global {
        input := input.state[MouseInput.M_MOTION]
        return linalg.Vector2f32{input.mouse_motion.x, input.mouse_motion.y}
    } else {
        return VEC2ZERO
    }
}

getMouseScroll :: proc(
    input: ^Input,
    mode: InputMode = .Global,
) -> linalg.Vector2f32 {
    if input.current_mode == mode || mode == .Global {
        input := input.state[MouseInput.M_WHEEL]

        vector := linalg.Vector2f32{0, 0}

        if input.scrolling {
            vector.x = input.mouse_wheel.x
            vector.y = input.mouse_wheel.y
        }

        return vector
    } else {
        return VEC2ZERO
    }
}

setMouseCapture :: proc(renderer: ^Renderer, captured: bool) {
    if renderer.config.mouse_captured == captured {
        return
    }

    renderer.config.mouse_captured = captured

    assert(
        sdl3.SetWindowRelativeMouseMode(
            renderer.window,
            renderer.config.mouse_captured,
        ),
    )
}
