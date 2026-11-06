package engine

import "../vendor/sdl3"
import "core:math/linalg"

D2_CAMERA: Camera : {
    type = .D2,
    projection_matrix = 1,
    view_matrix = 1,
    id = "default_2d_camera",
}

PERSPECTIVE_CAMERA: Camera : {
    type = .Perspective,
    fov = 70,
    translation = {0, 0, 0},
    id = "default_perspective_camera",
}

CameraType :: enum {
    None,
    Perspective,
    D2,
}

Camera :: struct {
    velocity:          linalg.Vector3f32,
    translation:       linalg.Vector3f32,
    pitch:             f32,
    yaw:               f32,
    row:               f32,
    fov:               f32,
    projection_matrix: linalg.Matrix4f32,
    view_matrix:       linalg.Matrix4f32,
    type:              CameraType,
    id:                string,
}

getCameraRotationMatrix :: proc(cam: Camera) -> linalg.Matrix4f32 {
    return linalg.matrix4_from_quaternion(
        linalg.quaternion_from_pitch_yaw_roll(cam.pitch, cam.yaw, cam.row),
    )
}

getCameraViewMatrix :: proc(cam: Camera) -> linalg.Matrix4f32 {
    rotation := getCameraRotationMatrix(cam)
    translation := linalg.matrix4_translate(cam.translation)

    return linalg.inverse(translation * rotation)
}

updateCameraProjection :: proc(cam: ^Camera, width, height: f32) {
    // perspective camera
    #partial switch cam.type {
    case .Perspective:
        {
            v := linalg.Vector4f32 {
                cam.velocity.x,
                cam.velocity.y,
                cam.velocity.z,
                0,
            }
            r := getCameraRotationMatrix(cam^)
            result := r * v
            cam.translation += linalg.Vector3f32{result.x, result.y, result.z}

            cam.view_matrix = getCameraViewMatrix(cam^)
            cam.projection_matrix = linalg.matrix4_perspective(
                cam.fov,
                width / height,
                0.1,
                1000.0,
            )
        }
    case .D2:
    case:
        {
            cam.view_matrix = 1
            cam.projection_matrix = 1
        }
    }
}

renderCamera :: proc(cmd_buffer: ^sdl3.GPUCommandBuffer, camera: ^Camera) {
    sdl3.PushGPUVertexUniformData(
        cmd_buffer,
        0,
        &camera.projection_matrix,
        size_of(linalg.Matrix4f32),
    )

    sdl3.PushGPUVertexUniformData(
        cmd_buffer,
        1,
        &camera.view_matrix,
        size_of(linalg.Matrix4f32),
    )
}
