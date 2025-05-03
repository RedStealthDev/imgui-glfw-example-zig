# imgui and glfw build example for zig
This repo contains example code for building glfw and cimgui/imgui from source using zig.
When built and run it will open a opengl and glfw window with the imgui demo running.

> [!NOTE]
> The code in this repo is cherrypicked from my WIP game engine written in zig.

> [!WARNING]
> This project has only been tested on linux if you have any issues please make an issue.

### Zig version
This project uses ver `0.14.0`

## Building

```
git clone URL
cd imgui-glfw-example-zig
zig build run
```

## Projects to checkout
The amazing [Dear ImGui](https://github.com/ocornut/imgui)\
The c port of ImGui [CImGui](https://github.com/cimgui/cimgui)\
The window manager [GLFW](https://github.com/glfw/glfw)\
And of course [Zig](https://ziglang.org/) itself
