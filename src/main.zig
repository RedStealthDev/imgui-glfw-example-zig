const std = @import("std");
const c = @cImport({
    @cDefine("CIMGUI_USE_GLFW", "");
    @cDefine("CIMGUI_USE_OPENGL3", "");
    @cDefine("CIMGUI_DEFINE_ENUMS_AND_STRUCTS", "");
    @cInclude("cimgui/cimgui.h");
    @cInclude("cimgui/generator/output/cimgui_impl.h");
    @cDefine("GLAD_GL_IMPLEMENTATION", "");
    @cDefine("GLFW_INCLUDE_NONE", "");
    @cInclude("glad/gl.h");
    @cInclude("GLFW/glfw3.h");
});

fn glfwErrorCallback(eror: c_int, description: [*c]const u8) callconv(.C) void {
    std.io.getStdErr().writer().print("Error: {d} : {s}", .{ eror, description }) catch return;
}

fn key_callback(win: ?*c.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.C) void {
    if (win) |w| {
        _ = scancode;
        _ = mods;
        if (key == c.GLFW_KEY_ESCAPE and action == c.GLFW_PRESS) {
            c.glfwSetWindowShouldClose(w, c.GLFW_TRUE);
        }
    }
}

const errors = error{
    glfwInitFail,
    glfwCreateWindowFail,
};

const Vertex = [5]f32;
const vertecies = [_]Vertex{
    .{ -0.5, -0.5, 1, 0, 0 },
    .{ 0.5, -0.5, 0, 1, 0 },
    .{ 0, 0.5, 0, 0, 1 },
};
const vertexShaderText =
    \\#version 330
    \\in vec3 vCol;
    \\in vec2 vPos;
    \\out vec3 color;
    \\void main()
    \\{
    \\  gl_Position = vec4(vPos, 0.0, 1.0);
    \\  color = vCol;
    \\}
;
const fragmentShaderText =
    \\#version 330
    \\in vec3 color;
    \\out vec4 fragment;
    \\void main()
    \\{
    \\  fragment = vec4(color, 1.0);
    \\}
;

pub fn main() !void {
    _ = c.glfwSetErrorCallback(glfwErrorCallback);
    if (c.glfwInit() == 0) {
        return error.glfwInitFail;
    }
    defer c.glfwTerminate();
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);

    //making the window
    var window: *c.GLFWwindow = undefined;
    if (c.glfwCreateWindow(640, 480, "OpenGL Triangle", null, null)) |win| {
        window = win;
    } else {
        return error.glfwCreateWindowFail;
    }
    _ = c.glfwSetKeyCallback(window, key_callback);

    c.glfwMakeContextCurrent(window);
    _ = c.gladLoadGL(c.glfwGetProcAddress);
    c.glfwSwapInterval(1);

    //initializing imgui
    const imguiContext = c.igCreateContext(c.ImFontAtlas_ImFontAtlas());
    _ = c.ImGui_ImplGlfw_InitForOpenGL(window, true);
    _ = c.ImGui_ImplOpenGL3_Init("#version 460");
    c.igStyleColorsDark(c.ImGuiStyle_ImGuiStyle());
    const imguiIOptr = c.igGetIO();
    imguiIOptr.?.*.ConfigFlags |= c.ImGuiConfigFlags_NavEnableKeyboard;

    //specifying vertex buffer

    var vertexBuffer: u32 = undefined;
    c.glGenBuffers(1, &vertexBuffer);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, vertexBuffer);
    c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(Vertex) * vertecies.len, &vertecies, c.GL_STATIC_DRAW);

    //specifying and setting up the shaders
    const vertexShader = c.glCreateShader(c.GL_VERTEX_SHADER);
    const shaderptr: ?[*]const u8 = vertexShaderText.ptr;
    c.glShaderSource(vertexShader, 1, &shaderptr, null);
    c.glCompileShader(vertexShader);

    const fragmentShader = c.glCreateShader(c.GL_FRAGMENT_SHADER);
    const fragmentShaderptr: ?[*]const u8 = fragmentShaderText.ptr;
    c.glShaderSource(fragmentShader, 1, &fragmentShaderptr, null);
    c.glCompileShader(fragmentShader);

    //attatching the shaders to a shader program
    const program = c.glCreateProgram();
    c.glAttachShader(program, vertexShader);
    c.glAttachShader(program, fragmentShader);
    c.glLinkProgram(program);

    //get vPos and vCol gpu pointers
    const vPosLocal: u32 = @intCast(c.glGetAttribLocation(program, "vPos"));
    const vColLocal: u32 = @intCast(c.glGetAttribLocation(program, "vCol"));

    //generate and bind the vertex buffers
    var vertexArray: u32 = undefined;
    c.glGenVertexArrays(1, &vertexArray);
    c.glBindVertexArray(vertexArray);
    c.glEnableVertexAttribArray(vPosLocal);
    c.glVertexAttribPointer(vPosLocal, 2, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Vertex), @ptrFromInt(0));
    c.glEnableVertexAttribArray(vColLocal);
    c.glVertexAttribPointer(vColLocal, 3, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Vertex), @ptrFromInt(@sizeOf(f32) * 2));

    while (c.glfwWindowShouldClose(window) == 0) {
        var width: i32 = 0;
        var height: i32 = 0;
        //get current window size
        c.glfwGetFramebufferSize(window, &width, &height);
        //change gl widnowsize
        c.glViewport(0, 0, width, height);
        //start a new imgui frame
        c.ImGui_ImplOpenGL3_NewFrame();
        c.ImGui_ImplGlfw_NewFrame();
        c.igNewFrame();
        //clear screen to black
        c.glClearColor(0, 0, 0, 1);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        //finally the imgui part any imgui code can be run here
        c.igShowDemoWindow(&showdemo);

        //drawing the triangle
        c.glUseProgram(program);
        c.glBindVertexArray(vertexArray);
        c.glDrawArrays(c.GL_TRIANGLES, 0, 3);

        //finalize imgui rendering
        c.igRender();
        c.ImGui_ImplOpenGL3_RenderDrawData(c.igGetDrawData());

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }
    //destroy the glfw and imgui contexts
    c.glfwDestroyWindow(window);
    c.ImGui_ImplOpenGL3_Shutdown();
    c.ImGui_ImplGlfw_Shutdown();
    c.igDestroyContext(imguiContext.?);
}

var showdemo = true;
