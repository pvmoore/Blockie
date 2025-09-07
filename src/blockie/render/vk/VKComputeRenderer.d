module blockie.render.vk.VKComputeRenderer;

import blockie.render.all;

private enum ENABLE_SHADER_PRINTF = false;

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
    VkQueryPool queryPool;

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
        createQueryPool();
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

        if(queryPool) device.destroyQueryPool(queryPool);
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
        VkPipelineStageFlags[] waitStages;

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
            waitStages     ~= VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT;
        }

        ulong[2] queryData;
        if(VK_SUCCESS==device.getQueryPoolResults(queryPool, res.index*2, 2, 16, queryData.ptr, 8, VK_QUERY_RESULT_64_BIT)) {
            ulong computeTime = cast(ulong)((queryData[1]-queryData[0])*vk.limits.timestampPeriod);

            getEvents().fire(EventID.COMPUTE_TIME, computeTime.as!double / 1_000_000.0);
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
        renderData.waitStages     ~= VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT;
    }
    void beforeRenderPass(VKRenderData renderData) {
        auto res = renderData.frame.resource;
        FrameResource frameRes  = frameResources[res.index];
        auto b = res.adhocCB;
        // acquire the image from compute queue
        b.pipelineBarrier(
            VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
            VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
            0,      // dependency flags
            null,   // memory barriers
            null,   // buffer barriers
            [
                imageMemoryBarrier(
                    frameRes.computeTargetImage.handle,
                    VK_ACCESS_SHADER_WRITE_BIT,
                    VK_ACCESS_SHADER_READ_BIT,
                    VK_IMAGE_LAYOUT_GENERAL,
                    VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                    vk.getComputeQueueFamily().index,
                    vk.getGraphicsQueueFamily().index
                )
            ]
        );
    }
    @Implements("IRenderer")
    void render(AbsRenderData absRenderData) {
        // We are inside the render pass here
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
            VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
            VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
            0,      // dependency flags
            null,   // memory barriers
            null,   // buffer barriers
            [
                imageMemoryBarrier(
                    frameRes.computeTargetImage.handle,
                    VK_ACCESS_SHADER_READ_BIT,
                    VK_ACCESS_SHADER_WRITE_BIT,
                    VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                    VK_IMAGE_LAYOUT_GENERAL,
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
            VK_COMMAND_POOL_CREATE_TRANSIENT_BIT | VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT);

        this.transferCP = device.createCommandPool(vk.getTransferQueueFamily().index,
            VK_COMMAND_POOL_CREATE_TRANSIENT_BIT | VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT);
    }
    void createQueryPool() {
        this.log("Creating query pool");
        this.queryPool = device.createQueryPool(
            VK_QUERY_TYPE_TIMESTAMP,    // queryType
            vk.swapchain.numImages*2    // num queries
        );
    }
    void createSamplers() {
        this.log("Creating samplers");
        this.materialSampler = device.createSampler(samplerCreateInfo((info){
            info.addressModeU     = VK_SAMPLER_ADDRESS_MODE_REPEAT;
            info.addressModeV     = VK_SAMPLER_ADDRESS_MODE_REPEAT;
            info.anisotropyEnable = VK_TRUE;
            info.maxAnisotropy    = 16;
        }));
        this.quadSampler = device.createSampler(samplerCreateInfo((info) {
            info.addressModeU = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
            info.addressModeV = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
        }));
    }
    void createMaterials() {
        this.log("Creating materials");
        this.materialImages ~= context.images().get("rock8.png");
    }
    void createSkybox() {
        this.log("Creating skybox cubemap");
        this.skyboxCubeMap = context.images().getCubemap("skybox", "png");
        this.skyboxCubeMap.image.view(skyboxCubeMap.format, VK_IMAGE_VIEW_TYPE_CUBE);
    }
    void createBuffers() {
        this.log("Creating buffers");
        this.voxelData = new GPUData!ubyte(context, VKBlockie.MARCH_VOXEL_BUFFER, true, Blockie.VOXEL_BUFFER_SIZE)
            .withFrameStrategy(GPUDataFrameStrategy.ONLY_ONE)
            .withUploadStrategy(GPUDataUploadStrategy.RANGE)
            .withAccessAndStageMasks(AccessAndStageMasks(
                VK_ACCESS_SHADER_READ_BIT,
                VK_ACCESS_SHADER_READ_BIT,
                VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
                VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT
            ))
            .initialise();
        this.chunkData = new GPUData!uint(context, VKBlockie.MARCH_CHUNK_BUFFER, true, Blockie.CHUNK_BUFFER_SIZE / 4)
            .withFrameStrategy(GPUDataFrameStrategy.ONE_PER_FRAME)
            .withAccessAndStageMasks(AccessAndStageMasks(
                VK_ACCESS_SHADER_READ_BIT,
                VK_ACCESS_SHADER_READ_BIT,
                VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
                VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT
            ))
            .initialise();
        this.ubo = new GPUData!UBO(context, BufID.UNIFORM, true)
            .withFrameStrategy(GPUDataFrameStrategy.ONE_PER_FRAME)
            .withAccessAndStageMasks(AccessAndStageMasks(
                VK_ACCESS_UNIFORM_READ_BIT,
                VK_ACCESS_UNIFORM_READ_BIT,
                VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
                VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT
            ))
            .initialise();

        ubo.write((it) {
            it.size = uint2(renderRect.width, renderRect.height);
        });
    }
    void createFrameResources() {
        this.log("Creating frame resources");
        foreach(i; 0..vk.swapchain.numImages()) {
            this.frameResources ~= setupFrame(i);
        }
    }
    FrameResource setupFrame(uint index) {
        this.log("Setting up frame %s", index);
        auto fr = new FrameResource;
        fr.computeCommands = device.allocFrom(computeCP);
        fr.transferCommands = device.allocFrom(transferCP);
        fr.computeFinished = device.createSemaphore();
        fr.transferFinished = device.createSemaphore();
        fr.marchOutBuffer = context.buffer(BufID.STORAGE).alloc(renderRect.width * renderRect.height * 8);

        fr.computeTargetImage = context.memory(MemID.LOCAL).allocImage(
            "computeTargetImage%s".format(index),
            [renderRect.width, renderRect.height],
            VK_IMAGE_USAGE_STORAGE_BIT | VK_IMAGE_USAGE_SAMPLED_BIT,
            VK_FORMAT_R8G8B8A8_UNORM);
        fr.computeTargetImage.createView(VK_FORMAT_R8G8B8A8_UNORM, VK_IMAGE_VIEW_TYPE_2D, VK_IMAGE_ASPECT_COLOR_BIT);

        fr.quad = new Quad(context, ImageMeta(fr.computeTargetImage, VK_FORMAT_R8G8B8A8_UNORM), quadSampler);

        auto camera = Camera2D.forVulkan(renderRect.dimension);
        auto scale  = mat4.scale(float3(renderRect.dimension.to!float, 0));
        auto trans  = mat4.translate(float3(renderRect.xy.to!float, 0));
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
            .add(chunkData, index)
            .add(fr.marchOutBuffer.handle, fr.marchOutBuffer.offset, fr.marchOutBuffer.size)
            .add(ubo, index)
            .add(fr.computeTargetImage.view, VK_IMAGE_LAYOUT_GENERAL)
            .add(materialSampler, materialImages[0].image.view, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL)
            .add(materialSampler, skyboxCubeMap.image.view, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL)
            .write();

        // Record the compute instructions
        auto b = fr.computeCommands;
        b.begin();

        b.resetQueryPool(queryPool,
            index*2,    // firstQuery
            2);             // queryCount
        b.writeTimestamp(VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
            queryPool,
            index*2); // query

        // Both shaders use the same Pipeline layout
        b.bindDescriptorSets(
            VK_PIPELINE_BIND_POINT_COMPUTE,
            marchPipeline.layout,
            0,
            [descriptors.getSet(0, index)],
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
            VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
            VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
            0,      // dependency flags
            null,   // memory barriers
            null,   // buffer barriers
            [
                imageMemoryBarrier(
                    fr.computeTargetImage.handle,
                    VK_ACCESS_NONE,
                    VK_ACCESS_SHADER_WRITE_BIT,
                    VK_IMAGE_LAYOUT_UNDEFINED,
                    VK_IMAGE_LAYOUT_GENERAL,
                    vk.getGraphicsQueueFamily().index,
                    vk.getComputeQueueFamily().index
                )
            ]
        );

        b.dispatch(renderRect.width/8, renderRect.height/8, 1);

        // release the image
        b.pipelineBarrier(
            VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
            VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
            0,      // dependency flags
            null,   // memory barriers
            null,   // buffer barriers
            [
                imageMemoryBarrier(
                    fr.computeTargetImage.handle,
                    VK_ACCESS_SHADER_WRITE_BIT,
                    VK_ACCESS_SHADER_READ_BIT,
                    VK_IMAGE_LAYOUT_GENERAL,
                    VK_IMAGE_LAYOUT_GENERAL,
                    vk.getComputeQueueFamily().index,
                    vk.getGraphicsQueueFamily().index
                )
            ]
        );

        b.writeTimestamp(VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
            queryPool,
            index*2+1); // query

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
                .storageBuffer(VK_SHADER_STAGE_COMPUTE_BIT)            // voxelData
                .storageBuffer(VK_SHADER_STAGE_COMPUTE_BIT)            // chunkData
                .storageBuffer(VK_SHADER_STAGE_COMPUTE_BIT)            // MarchOut[]
                .uniformBuffer(VK_SHADER_STAGE_COMPUTE_BIT)            // ubo
                .storageImage(VK_SHADER_STAGE_COMPUTE_BIT)             // output image
                .combinedImageSampler(VK_SHADER_STAGE_COMPUTE_BIT)     // texture
                .combinedImageSampler(VK_SHADER_STAGE_COMPUTE_BIT)     // skybox cubemap texture
                //.storageBuffer(VK_SHADER_STAGE_COMPUTE_BIT)          // materials
                .sets(vk.swapchain.numImages());

        descriptors
            .build();
    }
    void createPipelines() {
        this.log("Creating pipelines");
        auto marchShader = "pass1_marchM%s.comp".format(MODEL);

        static if(MODEL==1) {
            auto shadeShader = "pass3_shade.comp";
        } else {
            auto shadeShader = "pass3_shadeM2.comp";
        }
        this.log("  March program: %s", marchShader);
        this.log("  Shade program: %s", shadeShader);

        this.marchPipeline = new ComputePipeline(context, "March")
            .withDSLayouts(descriptors.getAllLayouts())
            .withShader(context.shaders.getModule(marchShader))
            //.withPushConstantRange!PushConstants()
            .build();
        this.shadePipeline = new ComputePipeline(context, "Shade")
            .withDSLayouts(descriptors.getAllLayouts())
            .withShader(context.shaders.getModule(shadeShader))
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
