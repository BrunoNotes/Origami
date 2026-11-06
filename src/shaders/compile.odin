package main

import "core:log"
import "core:os"
import "core:strings"

g_out_folder: string = ""
g_read_folder: string = ""
g_read_input: string = ""

when ODIN_OS == .Windows {
    path_char :: "\\"
} else {
    path_char :: "/"
}

main :: proc() {
    context.logger = log.create_console_logger(opt = {.Level, .Terminal_Color})

    for arg, idx in os.args {
        switch idx {
        case 1:
            g_read_folder = arg
        case 2:
            g_out_folder = arg
        case 3:
            g_read_input = arg
        }
    }

    assert(g_read_folder != "", "Folder to read not specified")
    assert(g_out_folder != "", "Output folder not specified")
    assert(g_read_input != "", "Input type not specified")

    mkdir_err := os.make_directory(g_out_folder)
    assert(mkdir_err != nil)

    readDir(g_read_folder)
}

readDir :: proc(path: string) {
    dir, dir_err := os.read_directory_by_path(path, -1, context.allocator)

    assert(dir_err == nil)

    for file, i in dir {
        defer free_all(context.temp_allocator)

        #partial switch file.type {
        case .Regular:
            {
                if strings.has_suffix(file.name, ".glsl") &&
                   g_read_input == "glsl" {
                    log.infof("Compiling %v", file.name)
                    compileGlslc(file)
                } else if strings.has_suffix(file.name, ".slang") &&
                   g_read_input == "slang" {
                    log.infof("Compiling %v", file.name)
                    compileSlang(file)
                }
            }
        case .Directory:
            {
                readDir(file.fullpath)
            }
        }
    }
}

SlangShader :: struct {
    entry, stage, out_name: string,
}

compileSlang :: proc(file: os.File_Info) {
    data, err := os.read_entire_file(file.fullpath, context.temp_allocator)
    if err != nil {
        log.errorf("Error reading file %v", file.name)
        return
    }
    // defer delete(data, context.temp_allocator)

    file_path_split := strings.split(
        file.fullpath,
        path_char,
        context.temp_allocator,
    )

    file_name := file_path_split[len(file_path_split) - 1]

    slang_shader := make([dynamic]SlangShader, context.temp_allocator)
    it := string(data)
    for line in strings.split_lines_iterator(&it) {
        switch strings.to_lower(line, context.temp_allocator) {
        case "[shader(\"vertex\")]":
            {
                out_file, _ := strings.replace(
                    file_name,
                    ".slang",
                    ".vert.spv",
                    1,
                    context.temp_allocator,
                )

                shader: SlangShader = {
                    entry    = "vertexMain",
                    stage    = "vertex",
                    out_name = out_file,
                }
                append(&slang_shader, shader)
            }
        case "[shader(\"fragment\")]":
            {
                out_file, _ := strings.replace(
                    file_name,
                    ".slang",
                    ".frag.spv",
                    1,
                    context.temp_allocator,
                )

                shader: SlangShader = {
                    entry    = "fragmentMain",
                    stage    = "fragment",
                    out_name = out_file,
                }
                append(&slang_shader, shader)
            }
        }
    }

    for shader in slang_shader {
        cmd := os.Process_Desc {
            command = {
                "slangc",
                file.fullpath,
                "-target",
                "spirv",
                // "-profile",
                // "glsl_450",
                "-entry",
                shader.entry,
                "-stage",
                shader.stage,
                "-o",
                strings.concatenate(
                    {"build/", shader.out_name},
                    context.temp_allocator,
                ),
            },
        }

        state, std_out, std_err, cmd_err := os.process_exec(
            cmd,
            context.temp_allocator,
        )

        if cmd_err != nil {
            log.errorf("Error compiling shader: %v", file_name)
        } else if len(std_err) > 0 {
            log.errorf(
                "Error compiling shader: %v",
                strings.clone_from_bytes(std_err, context.temp_allocator),
            )
        } else {
            log.infof("Compiled shader: %v", shader.out_name)
        }
    }
}

compileGlslc :: proc(file: os.File_Info) {
    file_name_split := strings.split(file.name, ".", context.temp_allocator)

    shader_stage, _ := strings.concatenate(
        {"-fshader-stage=", file_name_split[1]},
        context.temp_allocator,
    )

    file_path_split := strings.split(
        file.fullpath,
        path_char,
        context.temp_allocator,
    )

    file_name := file_path_split[len(file_path_split) - 1]

    out_file, _ := strings.replace(
        file_name,
        ".glsl",
        ".spv",
        1,
        context.temp_allocator,
    )

    out_path, _ := strings.concatenate(
        {g_out_folder, path_char, out_file},
        context.temp_allocator,
    )

    cmd := os.Process_Desc {
        command = {"glslc", shader_stage, file.fullpath, "-o", out_path},
    }

    state, std_out, std_err, cmd_err := os.process_exec(
        cmd,
        context.temp_allocator,
    )

    if cmd_err != nil {
        log.errorf("Error compiling shader: %v", file_name)
    } else if len(std_err) > 0 {
        log.errorf(
            "Error compiling shader: %v",
            strings.clone_from_bytes(std_err, context.temp_allocator),
        )
    } else {
        log.infof("Compiled shader: %v", out_path)
    }
}
