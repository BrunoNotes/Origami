package engine

import "../vendor/cgltf"
import "../vendor/sdl3"
import "base:runtime"
import "core:encoding/ini"
import "core:encoding/uuid"
import "core:log"
import "core:math/linalg"
import "core:path/filepath"
import "core:strings"

GltfNode :: struct {
    rotation:           linalg.Quaternionf32,
    translation, scale: linalg.Vector3f32,
    indices:            []u32,
    vertices:           []Vertex,
    texture:            Image,
    alpha_mode:         NodeAlphaMode,
    alpha_cutoff:       f32,
    double_sided:       bool,
}

loadGltf :: proc {
    loadGltfFile,
    loadGltfByte,
}

loadGltfFile :: proc(
    file_path: string,
    options: cgltf.options = {},
) -> (
    ^cgltf.data,
    cgltf.result,
) {
    file_path_cstring := strings.clone_to_cstring(
        file_path,
        context.temp_allocator,
    )

    data, result := cgltf.parse_file(options, file_path_cstring)
    // defer cgltf.free(data)

    if result == .success {
        result = cgltf.load_buffers(options, data, file_path_cstring)
    }

    if result == .success {
        result = cgltf.validate(data)
    }

    assert(result == .success, "Gltf: invalid data")

    return data, result
}

loadGltfByte :: proc(
    byte: []byte,
    options: cgltf.options = {},
) -> (
    ^cgltf.data,
    cgltf.result,
) {
    data, result := cgltf.parse(options, raw_data(byte), len(byte))
    // defer cgltf.free(data)

    if result == .success {
        result = cgltf.load_buffers(options, data, "")
    }

    if result == .success {
        result = cgltf.validate(data)
    }

    assert(result == .success, "Gltf: invalid data")

    return data, result
}

destroyGltf :: proc(data: ^cgltf.data) {
    cgltf.free(data)
}

processGltfNode :: proc(
    node: ^cgltf.node,
    file_path: string = "",
    allocator: runtime.Allocator = context.allocator,
) -> []GltfNode {
    gltf_nodes := make([dynamic]GltfNode, context.temp_allocator)
    gltf_node: GltfNode
    // node := node

    gltf_node.translation = node.translation

    gltf_node.rotation.x = node.rotation.x
    gltf_node.rotation.y = node.rotation.y
    gltf_node.rotation.z = node.rotation.z
    gltf_node.rotation.w = node.rotation.w

    gltf_node.scale = node.scale

    if node.mesh != nil {
        for prim in node.mesh.primitives {
            // indices: []u32
            // vertices: []Vertex
            // tex: Texture

            // ----- index -----
            {
                index_accessor := prim.indices
                index_size := cgltf.accessor_unpack_indices(
                    index_accessor,
                    nil,
                    0,
                    0,
                )

                gltf_node.indices = make([]u32, index_size, allocator)
                index_unpacked := cgltf.accessor_unpack_indices(
                    index_accessor,
                    raw_data(gltf_node.indices),
                    uint(size_of(u32)),
                    index_size,
                )

                assert(
                    index_unpacked == index_size,
                    "Gltf: error getting all indices",
                )

                assert(
                    len(gltf_node.indices) == int(index_size),
                    "Gltf: error getting index buffer",
                )
            }

            // ----- position -----
            {
                position_accessor: ^cgltf.accessor
                for &attr in prim.attributes {
                    if attr.type == .position {
                        position_accessor = attr.data
                        break
                    }
                }

                assert(
                    position_accessor != nil,
                    "Gltf: error getting position accessor",
                )
                assert(
                    position_accessor.type == .vec3,
                    "Gltf: position acessor is not a vec3",
                )

                position_size := cgltf.accessor_unpack_floats(
                    position_accessor,
                    nil,
                    0,
                )

                gltf_node.vertices = make(
                    []Vertex,
                    position_size / 3,
                    allocator,
                )

                positions := make([]f32, position_size, context.temp_allocator)
                position_unpacked := cgltf.accessor_unpack_floats(
                    position_accessor,
                    raw_data(positions),
                    position_size,
                )

                assert(
                    position_unpacked == position_size,
                    "Gltf: error getting all positions",
                )
                assert(
                    len(gltf_node.vertices) * 3 == len(positions),
                    "Gltf: error getting positions",
                )

                for i in 0 ..< len(gltf_node.vertices) {
                    position_idx := i * 3
                    gltf_node.vertices[i].position = {
                        positions[position_idx],
                        positions[position_idx + 1],
                        positions[position_idx + 2],
                    }

                    gltf_node.vertices[i].normal = {1, 0, 0}
                    gltf_node.vertices[i].color = 1
                    gltf_node.vertices[i].uv = 0
                }
            }

            // ----- normals -----
            {
                normal_accessor: ^cgltf.accessor
                for &attr in prim.attributes {
                    if attr.type == .position {
                        normal_accessor = attr.data
                        break
                    }
                }

                if normal_accessor != nil {
                    assert(
                        normal_accessor.type == .vec3,
                        "Gltf: normal acessor type is not a vec3",
                    )

                    normals_size := cgltf.accessor_unpack_floats(
                        normal_accessor,
                        nil,
                        0,
                    )

                    normals := make([]f32, normals_size)
                    defer delete(normals)

                    normals_unpacked := cgltf.accessor_unpack_floats(
                        normal_accessor,
                        raw_data(normals),
                        normals_size,
                    )

                    assert(
                        normals_unpacked == normals_size,
                        "Gltf: error getting all normals",
                    )
                    assert(
                        len(gltf_node.vertices) * 3 == len(normals),
                        "Gltf: error getting normals",
                    )

                    for i in 0 ..< len(gltf_node.vertices) {
                        normal_idx := i * 3
                        gltf_node.vertices[i].normal = {
                            normals[normal_idx],
                            normals[normal_idx + 1],
                            normals[normal_idx + 2],
                        }
                    }
                }
            }

            // Uv
            {
                uv_accessor: ^cgltf.accessor
                for &attr in prim.attributes {
                    if attr.type == .texcoord {
                        uv_accessor = attr.data
                        break
                    }
                }


                if uv_accessor != nil {
                    assert(
                        uv_accessor.type == .vec2,
                        "Gltf: uv acessor type is not a vec2",
                    )

                    uv_size := cgltf.accessor_unpack_floats(
                        uv_accessor,
                        nil,
                        0,
                    )

                    uvs := make([]f32, uv_size)
                    defer delete(uvs)

                    uv_unpacked := cgltf.accessor_unpack_floats(
                        uv_accessor,
                        raw_data(uvs),
                        uint(uv_size),
                    )

                    assert(
                        uv_unpacked == uv_size,
                        "Gltf: error getting all uvs",
                    )
                    assert(
                        len(gltf_node.vertices) * 2 == len(uvs),
                        "Gltf: error getting uvs",
                    )

                    for i in 0 ..< len(gltf_node.vertices) {
                        uv_idx := i * 2
                        gltf_node.vertices[i].uv = {
                            uvs[uv_idx],
                            uvs[uv_idx + 1],
                        }
                    }
                }
            }

            // color
            {
                color_accessor: ^cgltf.accessor
                for &attr in prim.attributes {
                    if attr.type == .color {
                        color_accessor = attr.data
                        break
                    }
                }

                if color_accessor != nil {
                    assert(
                        color_accessor.type == .vec4,
                        "Gltf: color acessor type is not a vec4",
                    )

                    color_size := cgltf.accessor_unpack_floats(
                        color_accessor,
                        nil,
                        0,
                    )

                    colors := make([]f32, color_size, context.temp_allocator)
                    color_unpacked := cgltf.accessor_unpack_floats(
                        color_accessor,
                        raw_data(colors),
                        color_size,
                    )

                    assert(
                        color_unpacked == color_size,
                        "Gltf: error getting all colors",
                    )
                    assert(
                        len(gltf_node.vertices) * 4 == len(colors),
                        "Gltf: error getting colors",
                    )

                    for i in 0 ..< len(gltf_node.vertices) {
                        color_idx := i * 4
                        gltf_node.vertices[i].color = {
                            colors[color_idx],
                            colors[color_idx + 1],
                            colors[color_idx + 2],
                            colors[color_idx + 3],
                        }
                    }
                }

                if prim.material.has_pbr_metallic_roughness {
                    texture :=
                        prim.material.pbr_metallic_roughness.base_color_texture.texture

                    if texture.image_.buffer_view != nil {
                        start := texture.image_.buffer_view.offset
                        // end := start + texture.image_.buffer_view.size
                        end := texture.image_.buffer_view.buffer.size

                        texture_data := ([^]byte)(
                            texture.image_.buffer_view.buffer.data,
                        )[start:end]

                        gltf_node.texture = loadImage(texture_data, allocator)

                    } else {
                        gltf_dir, _ := filepath.split(file_path)

                        texture_path, err := filepath.join(
                            {
                                gltf_dir,
                                strings.clone_from_cstring(
                                    texture.image_.uri,
                                    context.temp_allocator,
                                ),
                            },
                            context.temp_allocator,
                        )

                        gltf_node.texture = loadImage(texture_path, allocator)
                    }

                } else if prim.material.has_pbr_specular_glossiness {
                    log.debugf("%#v", prim.material.pbr_specular_glossiness)
                }
            }

            if prim.material.alpha_mode == .blend {
                gltf_node.alpha_mode = .Transparent
            } else {
                gltf_node.alpha_mode = .Opaque
            }

            gltf_node.double_sided = prim.material.double_sided ? true : false
            gltf_node.alpha_cutoff = prim.material.alpha_cutoff

            append(&gltf_nodes, gltf_node)
        }
    }

    return gltf_nodes[:]
}

nodeFromGltf :: proc(
    data: ^cgltf.data,
    renderer: ^Renderer,
    file_path: string = "",
    allocator := context.allocator,
) -> []^Node {
    result := make([dynamic]^Node)

    for scene in data.scenes {
        for node in scene.nodes {
            if node.mesh != nil && len(node.mesh.primitives) > 0 {
                gltf_nodes := processGltfNode(node, file_path, allocator)
                for gltf_node in gltf_nodes {
                    append(
                        &result,
                        gltfNodeToNode(gltf_node, renderer, allocator),
                    )
                }
            }

            for child_node in node.children {
                gltf_nodes := processGltfNode(child_node, file_path, allocator)
                for gltf_node in gltf_nodes {
                    append(
                        &result,
                        gltfNodeToNode(gltf_node, renderer, allocator),
                    )
                }
            }
        }
    }

    return result[:]
}

gltfNodeToNode :: proc(
    gltf_node: GltfNode,
    renderer: ^Renderer,
    allocator := context.allocator,
) -> ^Node {
    node_init_opts: NodeInitOpts
    node_init_opts.vertices = gltf_node.vertices
    node_init_opts.indices = gltf_node.indices
    node_init_opts.rotation = gltf_node.rotation
    node_init_opts.translation = gltf_node.translation
    node_init_opts.scale = gltf_node.scale
    node_init_opts.alpha_mode = gltf_node.alpha_mode
    node_init_opts.double_sided = gltf_node.double_sided
    node_init_opts.alpha_cutoff = gltf_node.alpha_cutoff

    if gltf_node.texture.data != nil {
        defer freeImage(gltf_node.texture)

        node_init_opts.texture = initTextureImage(
            gltf_node.texture,
            renderer.device,
            renderer.texture_sampler,
            allocator,
        )
    }

    return initNode(node_init_opts, renderer)

}
