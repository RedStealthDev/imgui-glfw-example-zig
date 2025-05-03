const std = @import("std");

//a simple enum spcifying what graphics backend to use
const graphics_api_type = enum { opengl, openglES, vulkan };

pub fn build(b: *std.Build) void {
    //initializing target os and os optimization options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const graphics_option = b.option(graphics_api_type, "Graphics Api", "select graphics api (default: opengl)") orelse .opengl;

    //specifying the executable
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const exe = b.addExecutable(.{
        .name = "imgui_glfw_example",
        .root_module = exe_mod,
    });
    //adding libc and libraries
    exe.linkLibC();
    exe.linkLibCpp();
    exe.linkLibrary(buildGLFW(b, optimize, target));
    exe.linkLibrary(buildIMGUI(b, optimize, target, graphics_option));

    //build and link glad
    const glad_lib = b.addStaticLibrary(.{
        .optimize = optimize,
        .target = target,
        .name = "glad",
        .link_libc = true,
    });
    glad_lib.addIncludePath(b.path("lib/glad/include/"));
    glad_lib.addIncludePath(b.path("lib/glad/src/"));
    glad_lib.installHeadersDirectory(b.path("lib/glad/include/"), "glad", .{});
    glad_lib.installHeadersDirectory(b.path("lib/glad/src/"), ".", .{});
    glad_lib.addCSourceFiles(.{
        .root = b.path("lib/glad/src"),
        .files = &.{
            switch (graphics_option) {
                .opengl => "gl.c",
                .openglES => "gles2.c",
                .vulkan => "vulkan.c",
            },
        },
        .flags = &.{},
    });
    b.installArtifact(glad_lib);

    exe.addIncludePath(b.path("lib/glad/include/"));
    exe.addIncludePath(b.path("lib/glad/src/"));
    exe.installHeadersDirectory(b.path("lib/glad/include/"), "glad", .{});
    exe.installHeadersDirectory(b.path("lib/glad/src/"), ".", .{});

    exe.linkLibrary(glad_lib);

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
fn buildIMGUI(b: *std.Build, optimize: std.builtin.OptimizeMode, target: std.Build.ResolvedTarget, graphics_option: graphics_api_type) *std.Build.Step.Compile {
    //making the static library
    const imgui_lib = b.addStaticLibrary(.{
        .optimize = optimize,
        .target = target,
        .name = "imgui",
        .link_libc = true,
    });
    //getting the imgui dependency by name from build.zig.zon
    const imgui_dep = b.dependency("imgui", .{
        .target = target,
        .optimize = optimize,
    });
    //getting the imgui dependency by name from build.zig.zon
    const cimgui_dep = b.dependency("cimgui", .{
        .target = target,
        .optimize = optimize,
    });

    //getting the cimgui path and deleting any previously symlinked imgui and then re symlinking it
    const cimguidir = std.fs.openDirAbsolute(cimgui_dep.path(".").getPath(b), .{ .iterate = true }) catch |err| std.debug.panic("opening the cimgui directory failed with the error: {any}", .{err});
    cimguidir.deleteTree("imgui") catch |err| std.debug.panic("Deleting the imgui directory from cimgui failed with the error: {any}", .{err});
    cimguidir.symLink(imgui_dep.path(".").getPath(b), "imgui", .{ .is_directory = true }) catch |err| std.debug.panic("symlinking the imgui directory failed with the error: {any}", .{err});

    //adding the cimgui and imgui header files
    imgui_lib.installHeadersDirectory(cimgui_dep.path("."), "cimgui", .{});
    imgui_lib.installHeadersDirectory(cimgui_dep.path("imgui"), "cimgui/imgui", .{});
    imgui_lib.addIncludePath(cimgui_dep.path("."));
    imgui_lib.addIncludePath(cimgui_dep.path("imgui"));
    //specifying what cpp file to add depending on what backend to use
    const imgui_backend: []const u8 = switch (graphics_option) {
        .opengl => "imgui/backends/imgui_impl_opengl3.cpp",
        .openglES => "imgui/backends/imgui_impl_opengl3.cpp",
        .vulkan => "imgui/backends/imgui_impl_vulkan.cpp",
    };
    //adding flags depending on what backend to use
    const imgui_backend_flag: []const u8 = switch (graphics_option) {
        .opengl => "-DCIMGUI_USE_OPENGL3",
        .openglES => "-DCIMGUI_USE_OPENGL3",
        .vulkan => "-DCIMGUI_USE_VULKAN",
    };

    //adding the cpp files to the build if using something like sdl then change the impl_glfw file for the one/ones neaded for sdl also make sure to chnage the flags
    imgui_lib.addCSourceFiles(.{
        .root = cimgui_dep.path(""),
        .files = &.{
            "cimgui.cpp",
            "imgui/imgui.cpp",
            "imgui/imgui_draw.cpp",
            "imgui/imgui_demo.cpp",
            "imgui/imgui_widgets.cpp",
            "imgui/imgui_tables.cpp",
            "imgui/backends/imgui_impl_glfw.cpp",
            imgui_backend,
        },
        .flags = &.{ "-DIMGUI_DISABLE_SSE", "-DIMGUI_USER_CONFIG=\"cimconfig.h\"", "-DIMGUI_DISABLE_OBSOLETE_FUNCTIONS=1", "-DIMGUI_IMPL_API=extern\t\"C\"\t", "-DIMGUI_IMPL_OPENGL_LOADER_GL3W", "-DCIMGUI_USE_GLFW", imgui_backend_flag },
    });

    //add backend specific header files

    _ = switch (graphics_option) {
        .opengl => {
            imgui_lib.installHeader(cimgui_dep.path("imgui/backends/imgui_impl_opengl3.h"), "cimgui/imgui/imgui_impl_opengl3.h");
            imgui_lib.installHeader(cimgui_dep.path("imgui/backends/imgui_impl_opengl3_loader.h"), "cimgui/imgui/imgui_impl_opengl3_loader.h");
        },
        .openglES => {
            imgui_lib.installHeader(cimgui_dep.path("imgui/backends/imgui_impl_opengl3.h"), "cimgui/imgui/imgui_impl_opengl3.h");
            imgui_lib.installHeader(cimgui_dep.path("imgui/backends/imgui_impl_opengl3_loader.h"), "cimgui/imgui/imgui_impl_opengl3_loader.h");
        },
        .vulkan => {
            imgui_lib.installHeader(cimgui_dep.path("imgui/backends/imgui_impl_vulkan.h"), "cimgui/imgui/imgui_impl_vulkan.h");
        },
    };

    //build the final library
    b.installArtifact(imgui_lib);
    return imgui_lib;
}

fn buildGLFW(b: *std.Build, optimize: std.builtin.OptimizeMode, target: std.Build.ResolvedTarget) *std.Build.Step.Compile {
    //making the static library
    const glfw_lib = b.addStaticLibrary(.{
        .optimize = optimize,
        .target = target,
        .name = "glfw",
        .link_libc = true,
    });
    //getting the glfw dependency by name from build.zig.zon
    const glfw_dep = b.dependency("glfw", .{
        .target = target,
        .optimize = optimize,
    });

    //building glfw from source instead of using cmake as build tool i used zig
    //
    //wARNING i have only tested this on linux if it does not work on your os please make an issue

    //including all the header files
    glfw_lib.addIncludePath(glfw_dep.path("include"));
    glfw_lib.addIncludePath(glfw_dep.path("src"));
    glfw_lib.root_module.addCMacro("_GLFW_BUILD_DLL", "1");
    glfw_lib.installHeadersDirectory(glfw_dep.path("include/GLFW"), "GLFW", .{});
    glfw_lib.installHeadersDirectory(glfw_dep.path("src"), ".", .{});
    glfw_lib.addIncludePath(glfw_dep.path("deps"));

    if (target.result.os.tag == .macos) {
        //including mac specific libraries and source files
        glfw_lib.linkFramework("CFNetwork");
        glfw_lib.linkFramework("ApplicationServices");
        glfw_lib.linkFramework("ColorSync");
        glfw_lib.linkFramework("CoreText");
        glfw_lib.linkFramework("ImageIO");
        glfw_lib.linkSystemLibrary("objc");
        glfw_lib.linkFramework("IOKit");
        glfw_lib.linkFramework("CoreFoundation");
        glfw_lib.linkFramework("AppKit");
        glfw_lib.linkFramework("CoreServices");
        glfw_lib.linkFramework("CoreGraphics");
        glfw_lib.linkFramework("Foundation");
        glfw_lib.linkFramework("OpenGL");
        glfw_lib.addCSourceFiles(.{ .root = glfw_dep.path(""), .files = &.{
            "src/context.c",
            "src/init.c",
            "src/input.c",
            "src/monitor.c",
            "src/platform.c",
            "src/vulkan.c",
            "src/window.c",
            "src/egl_context.c",
            "src/osmesa_context.c",
            "src/null_init.c",
            "src/null_monitor.c",
            "src/null_window.c",
            "src/null_joystick.c",
        }, .flags = &.{
            "-D_GLFW_COCOA",
            "-Isrc",
        } });
        glfw_lib.addCSourceFiles(.{ .root = glfw_dep.path(""), .files = &.{
            "src/cocoa_time.c",
            "src/posix_module.c",
            "src/posix_thread.c",
            "src/cocoa_init.m",
            "src/cocoa_joystick.m",
            "src/cocoa_monitor.m",
            "src/cocoa_window.m",
            "src/nsgl_context.m",
        }, .flags = &.{
            "-D_GLFW_COCOA",
            "-Isrc",
        } });
    } else if (target.result.os.tag == .windows) {
        //including windows specific libraries and source files
        glfw_lib.linkSystemLibrary("gdi32");
        glfw_lib.linkSystemLibrary("user32");
        glfw_lib.linkSystemLibrary("shell32");
        glfw_lib.linkSystemLibrary("opengl32");
        glfw_lib.addCSourceFiles(.{ .root = glfw_dep.path(""), .files = &.{
            "src/context.c",
            "src/init.c",
            "src/input.c",
            "src/monitor.c",
            "src/platform.c",
            "src/vulkan.c",
            "src/window.c",
            "src/egl_context.c",
            "src/osmesa_context.c",
            "src/null_init.c",
            "src/null_monitor.c",
            "src/null_window.c",
            "src/null_joystick.c",
        }, .flags = &.{
            "-D_GLFW_WIN32",
            "-Isrc",
        } });

        glfw_lib.addCSourceFiles(.{ .root = glfw_dep.path(""), .files = &.{
            "src/win32_time.c",
            "src/win32_module.c",
            "src/win32_thread.c",
            "src/win32_init.c",
            "src/win32_joystick.c",
            "src/win32_monitor.c",
            "src/win32_window.c",
            "src/wgl_context.c",
        }, .flags = &.{
            "-D_GLFW_WIN32",
            "-Isrc",
        } });
    } else {
        //building the wayland .xml files
        const dir = std.fs.openDirAbsolute(glfw_dep.path("deps/wayland").getPath(glfw_dep.builder), .{ .iterate = true }) catch |err| std.debug.panic("opening the deps/wayland directory failed with the error: {any}", .{err});
        var walker = dir.walk(std.heap.page_allocator) catch |err| std.debug.panic("making the walker for deps/wayland directory failed with the error: {any}", .{err});
        defer walker.deinit();
        while (walker.next() catch |err| std.debug.panic("getting next item from walker deps/wayland failed with error: {any}", .{err})) |dire| {
            if (!std.mem.eql(u8, dire.path[dire.path.len - 4 ..], ".xml")) {
                continue;
            }
            waylandgen(glfw_dep.builder, glfw_dep.builder.pathJoin(&.{ glfw_dep.path("deps/wayland").getPath(glfw_dep.builder), dire.path }));
        }

        //including linux libraries and source files
        glfw_lib.installHeadersDirectory(glfw_dep.path("deps/wayland"), ".", .{});
        glfw_lib.addIncludePath(glfw_dep.path("deps/wayland"));
        glfw_lib.root_module.addCMacro("WL_MARSHAL_FLAG_DESTROY", "1");
        glfw_lib.addCSourceFiles(.{ .root = glfw_dep.path(""), .files = &.{
            "src/context.c",
            "src/init.c",
            "src/input.c",
            "src/monitor.c",
            "src/platform.c",
            "src/vulkan.c",
            "src/window.c",
            "src/egl_context.c",
            "src/osmesa_context.c",
            "src/null_init.c",
            "src/null_monitor.c",
            "src/null_window.c",
            "src/null_joystick.c",
        }, .flags = &.{
            "-D_GLFW_WAYLAND",
            "-D_GLFW_X11",
            "-Wno-implicit-function-declaration",
            "-Isrc",
        } });
        glfw_lib.addCSourceFiles(.{ .root = glfw_dep.path(""), .files = &.{
            "src/posix_time.c",
            "src/posix_module.c",
            "src/posix_thread.c",
            "src/x11_init.c",
            "src/x11_monitor.c",
            "src/x11_window.c",
            "src/xkb_unicode.c",
            "src/glx_context.c",
            "src/wl_init.c",
            "src/wl_monitor.c",
            "src/wl_window.c",
            "src/linux_joystick.c",
            "src/posix_poll.c",
        }, .flags = &.{
            "-D_GLFW_WAYLAND",
            "-D_GLFW_X11",
            "-Wno-implicit-function-declaration",
            "-Isrc",
        } });
    }

    //finaly install the library so it builds it
    b.installArtifact(glfw_lib);
    return glfw_lib;
}

// Only input a src_path
fn waylandgen(builder: *std.Build, file: []const u8) void {
    //runs the wayland-scanner system program to build the xml files
    if (std.Build.findProgram(builder, &.{"wayland-scanner"}, &.{}) != error.FileNotFound) {
        var buf: [1000]u8 = undefined;
        var buf2: [1000]u8 = undefined;
        const header_file = std.fmt.bufPrint(&buf, "{s}{s}", .{ file[0 .. file.len - 4], "-client-protocol.h" }) catch return;
        const code_file = std.fmt.bufPrint(&buf2, "{s}{s}", .{ file[0 .. file.len - 4], "-client-protocol-code.h" }) catch return;
        _ = builder.run(&.{
            "wayland-scanner",
            "client-header",
            file,
            header_file,
        });
        _ = builder.run(&.{
            "wayland-scanner",
            "private-code",
            file,
            code_file,
        });
    } else {
        std.io.getStdErr().writer().print("FAILED TO FIND PACKAGE wayland-scanner", .{}) catch return;
    }
}
