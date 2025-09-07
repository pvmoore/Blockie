# Blockie

Voxel renderer using Vulkan compute shaders

![Scene7](screenshots/scene7-2.png)
![Scene4](screenshots/scene4.png)
![Scene4c](screenshots/scene4c.png)
![Scene6](screenshots/scene6.png)

## Requirements
- Windows
- Dlang https://dlang.org/
- Vulkan Runtime dll (provided by your GPU vendor if supported)
- GLFW dll (provided by dlang-vulkan)
- CImgui dll (provided by dlang-vulkan)
- https://github.com/pvmoore/dlang-vulkan
- https://github.com/pvmoore/dlang-common
- https://github.com/pvmoore/dlang-logging
- https://github.com/pvmoore/dlang-maths
- https://github.com/pvmoore/dlang-events
- https://github.com/pvmoore/dlang-resources

## Features
- Sparse voxel octrees
- 1024³ voxel chunks
- Asynchronous chunk loading
- Vulkan compute shader 2-pass renderer
    - 1st pass ... Ray caster that computes hit distances
    - 2nd pass ... Shader that calculates colour/texture/lighting
- Currently no secondary shadow rays are used

[Version History](docs/version_history.md)
