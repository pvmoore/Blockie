module blockie.render.vk.VKComputeRenderer;

import blockie.render.all;

final class VKComputeRenderer : ComputeRenderer {
private:
    @Borrowed VulkanContext context;
    @Borrowed Vulkan vk;
    @Borrowed VkDevice device;
    @Borrowed ImageMeta skyboxCubeMap;

    VkCommandPool computeCP, computeCPTransient, transferCP;
	Descriptors descriptors;
	ComputePipeline marchPipeline, shadePipeline;
    VkSampler materialSampler, quadSampler;

    GPUData!uint chunkData;
    GPUData!ubyte voxelData;
    GPUData!UBO ubo;

    FrameResource[] frameResources;
    ImageMeta[] materialImages;

    final static class FrameResource {
        VkCommandBuffer computeCommands;
        VkCommandBuffer transferCommands;
        VkSemaphore computeFinished;
        VkSemaphore transferFinished;
        SubBuffer marchOutBuffer;
        DeviceImage computeTargetImage;
        Quad quad;
    }
    static struct UBO { static assert(UBO.sizeof == 9*16);
        uint2  size;
        uint2  _0;
        float3 sunPos;
        float  _1;
        uint3  worldChunksXYZ;
        uint   _2;
        int3   worldBBMin;
        int    _3;
        int3   worldBBMax;
        int    _4;
        float3 cameraPos;
        float  _5;
        float3 screenMiddle;
        float  _6;
        float3 screenXDelta;
        float  _7;
        float3 screenYDelta;
        float _8;
    }
    static struct SpecConstants {
        float CHUNK_SIZE;
        float CHUNK_SIZE_SHR;
        float DFIELD_OFFSET;
    }
public:
    this(VulkanContext context, RenderView renderView, int4 renderRect) {
        super(renderView, renderRect);

        this.context    = context;
        this.vk         = context.vk;
        this.device     = context.device;
        this.renderView = renderView;
        this.renderRect = renderRect;

        createCommandPools();
        createSamplers();
        createMaterials();
        createSkybox();
        createBuffers();
        createDescriptors();
        createPipelines();
        createFrameResources();
    }
    @Implements("IRenderer")
    override void destroy() {
        super.destroy();

        foreach(f; frameResources) {
            device.destroySemaphore(f.computeFinished);
            device.destroySemaphore(f.transferFinished);
            f.marchOutBuffer.free();
            f.computeTargetImage.free();
            f.quad.destroy();
        }
        if(chunkData) chunkData.destroy();
        if(voxelData) voxelData.destroy();
        if(ubo) ubo.destroy();

        if(transferCP) device.destroyCommandPool(transferCP);
        if(computeCP) device.destroyCommandPool(computeCP);
        if(computeCPTransient) device.destroyCommandPool(computeCPTransient);
        if(marchPipeline) marchPipeline.destroy();
        if(shadePipeline) shadePipeline.destroy();
        if(descriptors) descriptors.destroy();
        if(materialSampler) device.destroySampler(materialSampler);
        if(quadSampler) device.destroySampler(quadSampler);
    }
    @Implements("IRenderer")
    override void setWorld(World world) {
        this.log("World = %s", world);
        super.setWorld(world);

        this.chunkManager = new ChunkManager(
           this,
           world,
           new VKGPUMemoryManager!ubyte(voxelData),
           new VKGPUMemoryManager!uint(chunkData)
        );

        ubo.write((u) {
            u.sunPos = world.sunPos;
            u.worldChunksXYZ = chunkManager.getViewWindow();
        });

        cameraMoved();
    }
    @Implements("IRenderer")
    void update(AbsRenderData absRenderData, bool camMoved) {
        // We are outside the render pass here
        VKRenderData renderData = absRenderData.as!VKRenderData;
        PerFrameResource res    = renderData.frame.resource;
        FrameResource frameRes  = frameResources[res.index];
        auto b = res.adhocCB;

        if(camMoved) {
            cameraMoved();
        }
        chunkManager.afterUpdate();

        // Upload data to the GPU
        VkSemaphore[] waitSemaphores;
        VPipelineStage[] waitStages;

        if(ubo.isUploadRequired() || voxelData.isUploadRequired() || chunkData.isUploadRequired()) {

            if(voxelData.isUploadRequired() || chunkData.isUploadRequired()) {
                this.log("Uploading GPU data");
            }
            auto t = frameRes.transferCommands;
            t.beginOneTimeSubmit();

            ubo.upload(t);
            voxelData.upload(t);
            chunkData.upload(t);

            t.end();

            vk.getTransferQueue().submit(
                [frameRes.transferCommands],
                null, null,                     // don't wait for anything
                [frameRes.transferFinished],    // signal
                null);

            waitSemaphores ~= frameRes.transferFinished;
            waitStages     ~= VPipelineStage.COMPUTE_SHADER;
        }

        // Execute compute shaders
        vk.getComputeQueue().submit(
            [frameRes.computeCommands],
            waitSemaphores,
            waitStages,
            [frameRes.computeFinished],  // signal semaphores
            null                         // fence
        );

        // Graphics commands need to wait for this to finish
        renderData.waitSemaphores ~= frameRes.computeFinished;
        renderData.waitStages     ~= VPipelineStage.COMPUTE_SHADER;
    }
    void beforeRenderPass(VKRenderData renderData) {
        auto res = renderData.frame.resource;
        FrameResource frameRes  = frameResources[res.index];
        auto b = res.adhocCB;
        // acquire the image from compute queue
        b.pipelineBarrier(
            VPipelineStage.COMPUTE_SHADER,
            VPipelineStage.FRAGMENT_SHADER,
            0,      // dependency flags
            null,   // memory barriers
            null,   // buffer barriers
            [
                imageMemoryBarrier(
                    frameRes.computeTargetImage.handle,
                    VAccess.SHADER_WRITE,
                    VAccess.SHADER_READ,
                    VImageLayout.GENERAL,
                    VImageLayout.SHADER_READ_ONLY_OPTIMAL,
                    vk.getComputeQueueFamily().index,
                    vk.getGraphicsQueueFamily().index
                )
            ]
        );
    }
    @Implements("IRenderer")
    void render(AbsRenderData absRenderData) {
        // We are inside the pender pass here
        VKRenderData renderData = absRenderData.as!VKRenderData;
        Frame frame             = renderData.frame;
        PerFrameResource res    = frame.resource;
        FrameResource frameRes  = frameResources[res.index];
        auto b = res.adhocCB;

        frameRes.quad.insideRenderPass(frame);
    }
    void afterRenderPass(VKRenderData renderData) {
        auto res = renderData.frame.resource;
        FrameResource frameRes  = frameResources[res.index];
        auto b = res.adhocCB;
        // release the imqge
        b.pipelineBarrier(
            VPipelineStage.FRAGMENT_SHADER,
            VPipelineStage.COMPUTE_SHADER,
            0,      // dependency flags
            null,   // memory barriers
            null,   // buffer barriers
            [
                imageMemoryBarrier(
                    frameRes.computeTargetImage.handle,
                    VAccess.SHADER_READ,
                    VAccess.SHADER_WRITE,
                    VImageLayout.SHADER_READ_ONLY_OPTIMAL,
                    VImageLayout.GENERAL,
                    vk.getGraphicsQueueFamily().index,
                    vk.getComputeQueueFamily().index
                )
            ]
        );
    }
    @Implements("SceneChangeListener")
    void boundsChanged(worldcoords minBB, worldcoords maxBB) {
        this.log("Bounds changed");
        ubo.write((u) {
            u.worldBBMin = minBB;
            u.worldBBMax = maxBB;
        });
    }
private:
    void createCommandPools() {
        this.log("Creating command pools");

        this.computeCP = device.createCommandPool(vk.getComputeQueueFamily().index, 0);

        this.computeCPTransient = device.createCommandPool(vk.getComputeQueueFamily().index,
            VCommandPoolCreate.TRANSIENT | VCommandPoolCreate.RESET_COMMAND_BUFFER);

        this.transferCP = device.createCommandPool(vk.getTransferQueueFamily().index,
            VCommandPoolCreate.TRANSIENT | VCommandPoolCreate.RESET_COMMAND_BUFFER);
    }
    void createSamplers() {
        this.log("Creating samplers");
        this.materialSampler = device.createSampler(samplerCreateInfo((info){
            info.addressModeU     = VSamplerAddressMode.REPEAT;
            info.addressModeV     = VSamplerAddressMode.REPEAT;
            info.anisotropyEnable = VK_TRUE;
            info.maxAnisotropy    = 16;
        }));
        this.quadSampler = device.createSampler(samplerCreateInfo((info) {
            info.addressModeU = VSamplerAddressMode.CLAMP_TO_EDGE;
            info.addressModeV = VSamplerAddressMode.CLAMP_TO_EDGE;
        }));
    }
    void createMaterials() {
        this.log("Creating materials");
        this.materialImages ~= context.images().get("rock8.png");
    }
    void createSkybox() {
        this.log("Creating skybox cubemap");
        this.skyboxCubeMap = context.images().getCubemap("skybox", "png");
        this.skyboxCubeMap.image.view(skyboxCubeMap.format, VImageViewType.CUBE);
    }
    void createBuffers() {
        this.log("Creating buffers");
        this.voxelData = new GPUData!ubyte(context, VKBlockie.MARCH_VOXEL_BUFFER, true, Blockie.VOXEL_BUFFER_SIZE)
            .withFrameStrategy(GPUDataFrameStrategy.ONLY_ONE)
            .withUploadStrategy(GPUDataUploadStrategy.RANGE)
            .initialise();
        this.chunkData = new GPUData!uint(context, VKBlockie.MARCH_CHUNK_BUFFER, true, Blockie.CHUNK_BUFFER_SIZE / 4)
            .withFrameStrategy(GPUDataFrameStrategy.ONE_PER_FRAME)
            .initialise();
        this.ubo = new GPUData!UBO(context, BufID.UNIFORM, true)
            .withFrameStrategy(GPUDataFrameStrategy.ONE_PER_FRAME)
            .initialise();

        ubo.write((it) {
            it.size = uint2(renderRect.width, renderRect.height);
        });
    }
    void createFrameResources() {
        this.log("Creating frame resources");
        foreach(i; 0..vk.swapchain.numImages) {
            auto res = vk.getFrameResource(i);
            this.frameResources ~= setupFrame(res);
        }
    }
    FrameResource setupFrame(PerFrameResource res) {
        this.log("Setting up frame %s", res.index);
        auto fr = new FrameResource;
        fr.computeCommands = device.allocFrom(computeCP);
        fr.transferCommands = device.allocFrom(transferCP);
        fr.computeFinished = device.createSemaphore();
        fr.transferFinished = device.createSemaphore();
        fr.marchOutBuffer = context.buffer(BufID.STORAGE).alloc(renderRect.width * renderRect.height * 8);

        fr.computeTargetImage = context.memory(MemID.LOCAL).allocImage(
            "computeTargetImage%s".format(res.index),
            [renderRect.width, renderRect.height],
            VImageUsage.STORAGE | VImageUsage.SAMPLED,
            VFormat.R8G8B8A8_UNORM);
        fr.computeTargetImage.createView(VFormat.R8G8B8A8_UNORM, VImageViewType._2D, VImageAspect.COLOR);

        fr.quad = new Quad(context, ImageMeta(fr.computeTargetImage, VFormat.R8G8B8A8_UNORM), quadSampler);

        auto camera = Camera2D.forVulkan(renderRect.dimension);
        auto scale  = mat4.scale(vec3(renderRect.dimension.to!float, 0));
        auto trans  = mat4.translate(vec3(renderRect.xy.to!float, 0));
        fr.quad.setVP(trans*scale, camera.V(), camera.P());

        /**
         * 0 - voxelData
         * 1 - chunkData
         * 2 - march output buffer
         * 3 - UBO
         * 4 - shade output image
         * 5 - material texture
         * 6 - skybox cubemap texture
         * 7 - (materials - not yet implemented)
         */
        descriptors.createSetFromLayout(0)
            .add(voxelData)
            .add(chunkData, res.index)
            .add(fr.marchOutBuffer.handle, fr.marchOutBuffer.offset, fr.marchOutBuffer.size)
            .add(ubo, res.index)
            .add(fr.computeTargetImage.view, VImageLayout.GENERAL)
            .add(materialSampler, materialImages[0].image.view, VImageLayout.SHADER_READ_ONLY_OPTIMAL)
            .add(materialSampler, skyboxCubeMap.image.view, VImageLayout.SHADER_READ_ONLY_OPTIMAL)
            .write();

        // Record the compute instructions
        auto b = fr.computeCommands;
        b.begin();

        // Both shaders use the same Pipeline layout
        b.bindDescriptorSets(
            VPipelineBindPoint.COMPUTE,
            marchPipeline.layout,
            0,
            [descriptors.getSet(0,res.index)],
            null
        );

        //##########################################################################################
        // March shader
        //##########################################################################################
        b.bindPipeline(marchPipeline);

        //b.resetQueryPool(queryPool, index*2, 2);
        //b.writeTimestamp(VPipelineStage.TOP_OF_PIPE, queryPool, index*2);

        b.dispatch(renderRect.width/8, renderRect.height/8, 1);

        //##########################################################################################
        // Shade shader
        //##########################################################################################
        b.bindPipeline(shadePipeline);

        // acquire the image from graphics queue
        b.pipelineBarrier(
            VPipelineStage.FRAGMENT_SHADER,
            VPipelineStage.COMPUTE_SHADER,
            0,      // dependency flags
            null,   // memory barriers
            null,   // buffer barriers
            [
                imageMemoryBarrier(
                    fr.computeTargetImage.handle,
                    VAccess.NONE,
                    VAccess.SHADER_WRITE,
                    VImageLayout.UNDEFINED,
                    VImageLayout.GENERAL,
                    vk.getGraphicsQueueFamily().index,
                    vk.getComputeQueueFamily().index
                )
            ]
        );

        b.dispatch(renderRect.width/8, renderRect.height/8, 1);

        // release the image
        b.pipelineBarrier(
            VPipelineStage.COMPUTE_SHADER,
            VPipelineStage.FRAGMENT_SHADER,
            0,      // dependency flags
            null,   // memory barriers
            null,   // buffer barriers
            [
                imageMemoryBarrier(
                    fr.computeTargetImage.handle,
                    VAccess.SHADER_WRITE,
                    VAccess.SHADER_READ,
                    VImageLayout.GENERAL,
                    VImageLayout.GENERAL,
                    vk.getComputeQueueFamily().index,
                    vk.getGraphicsQueueFamily().index
                )
            ]
        );

        //b.writeTimestamp(VPipelineStage.BOTTOM_OF_PIPE, queryPool, index*2+1);

        b.end();

        return fr;
    }
    /**
     * 0 - voxelData
     * 1 - chunkData
     * 2 - march output buffer
     * 3 - UBO
     * 4 - shade output image
     * 5 - material texture
     * 6 - skybox cubemap texture
     * 7 - (materials - not yet implemented)
     */
    void createDescriptors() {
        this.log("Creating descriptors");
        this.descriptors = new Descriptors(context);
        descriptors
            .createLayout()
                .storageBuffer(VShaderStage.COMPUTE)            // voxelData
                .storageBuffer(VShaderStage.COMPUTE)            // chunkData
                .storageBuffer(VShaderStage.COMPUTE)            // MarchOut[]
                .uniformBuffer(VShaderStage.COMPUTE)            // ubo
                .storageImage(VShaderStage.COMPUTE)             // output image
                .combinedImageSampler(VShaderStage.COMPUTE)     // texture
                .combinedImageSampler(VShaderStage.COMPUTE)     // skybox cubemap texture
                //.storageBuffer(VShaderStage.COMPUTE)          // materials
                .sets(vk.swapchain.numImages())
            .build();
    }
    void createPipelines() {
        this.log("Creating pipelines");
        auto marchShader = "pass1_marchM%s.comp".format(getModelName());
        version(MODEL1) {
            auto shadeShader = "pass3_shade.comp";
        } else version(MODEL1) {
            auto shadeShader = "pass3_shade.comp";
        } else {
            auto shadeShader = "pass3_shadeM2.comp";
        }
        this.log("  March program: %s", marchShader);
        this.log("  Shade program: %s", shadeShader);

        this.marchPipeline = new ComputePipeline(context)
            .withDSLayouts(descriptors.getAllLayouts())
            .withShader(context.shaderCompiler().getModule(marchShader))
            //.withPushConstantRange!PushConstants()
            .build();
        this.shadePipeline = new ComputePipeline(context)
            .withDSLayouts(descriptors.getAllLayouts())
            .withShader(context.shaderCompiler().getModule(shadeShader))
            //.withPushConstantRange!PushConstants()
            .build();

        // These valuyes are assumed in the shader. Changes will be required if any of them are changed
        static assert(CHUNK_SIZE == 1024);
        static assert(CHUNK_SIZE_SHR == 10);
        static assert(OctreeTwig.sizeof == 12);
        static assert(OctreeLeaf.sizeof == 8);
        static assert(OptimisedRoot.dfields.offsetof == 5152);
    }
    void cameraMoved() {
        auto screen = calculateScreen();

        ubo.write((u) {
            u.sunPos       = world.sunPos;
            u.cameraPos    = world.camera.position;
            u.screenMiddle = screen.middle;
            u.screenXDelta = screen.xDelta;
            u.screenYDelta = screen.yDelta;
        });
    }
}