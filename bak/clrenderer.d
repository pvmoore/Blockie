module blockie.render.clrenderer;

import blockie.all;

final class CLSceneRenderer : IRenderer {
private:
    const bool DEBUG = false;
    OpenGL gl;
    OpenCL cl;
    World world;
    uint textureID;
    int width, height;
    IntRect renderRect;
    SpriteRenderer quadRenderer;
    BoxRenderer boxRenderer;
    SphereRenderer3D sphereRenderer;
    CLContext ctx;
    CLCommandQueue queue;
    CLKernel initKernel, marchKernel, shadeKernel;
    ulong[2] kernelSquareWGSize2d;
    ulong[2] kernelRowMajorWGSize2d;
    CLBuffer imageBuf, voxelDataBuf, chunkDataBuf;
    CLBuffer voxelsHitBuf, positionsHitBuf;
    Constants_CL constants;
    ShadeConstants_CL shadeConstants;
    Timing renderTiming;
    Timing marchKernelTiming;
    Timing shadeKernelTiming;
    Timing acquireGLTiming;
    Timing releaseGLTiming;
    cl_event marchKernelEvent;
    cl_event shadeKernelEvent;
    cl_event acquireGLEvent;
    cl_event releaseGLEvent;

    static assert(Constants_CL.sizeof==132);
    final static struct Constants_CL {
        float3 worldBB0;    // 16
        float3 worldBB1;    // 16
        float3 cameraOrigin;// 16
        float3 cameraUp;    // 16
        float3 screenMiddle;// 16
        float3 screenXDelta;// 16
        float3 screenYDelta;// 16
        uint width;         // 4 bytes
        uint height;        // 4
        uint chunksX;       // 4
        uint chunksY;       // 4
        uint chunksZ;       // 4
    }
    static assert(ChunkData_CL.sizeof==4);
    final static struct ChunkData_CL {
        uint voxelsOffset;
    }
    static assert(MarchOut_CL.sizeof==16);
    align(1) final struct MarchOut_CL { align(1):
        float[3] pos;    // in world coords
        ubyte voxel;
        ubyte[3] padding;
    }
    static assert(ShadeConstants_CL.sizeof==24);
    align(1) final struct ShadeConstants_CL { align(1):
        uint width;
        uint height;
        float3 sunPos;
    }
public:
    this(OpenGL gl, OpenCL cl, IntRect renderRect) {
        this.gl     = gl;
        this.cl     = cl;
        this.renderRect = renderRect;
        this.width  = renderRect.w;
        this.height = renderRect.h;
        this.renderTiming = new Timing(10,3);
        this.marchKernelTiming = new Timing(10,3);
        this.shadeKernelTiming = new Timing(10,3);
        this.acquireGLTiming = new Timing(10,1);
        this.releaseGLTiming = new Timing(10,1);
        this.boxRenderer = new BoxRenderer(gl);
        this.sphereRenderer = new SphereRenderer3D(gl);

        boxRenderer.setColour(WHITE*0.5);

        setupTexture();
        setupSpriteRenderer();
        setupCL();
    }
    void destroy() {
        if(boxRenderer) boxRenderer.destroy();
        if(quadRenderer) quadRenderer.destroy();
        if(sphereRenderer) sphereRenderer.destroy();
        if(textureID) glDeleteTextures(1, &textureID);
    }
    void setWorld(World world) {
        this.world = world;
        initialiseBuffers();
        cameraMoved();
    }
    void debugToConsole(Console console) {
        console.log("Render time ..... %s".format(renderTiming));
        console.log("    (March Kernel %s)".format(marchKernelTiming));
        console.log("    (Shade Kernel %s)".format(shadeKernelTiming));
        console.log("(Acquire GL objs %s)".format(acquireGLTiming));
        console.log("(Release GL objs %s)".format(releaseGLTiming));
        console.log(" ");
    }
    void cameraMoved() {
        auto camera = world.camera;
        const float Y  = renderRect.y;
        const float w  = width;
        const float h  = height;
        const float h2 = h/2;
        const float w2 = w/2;
        const float z  = 0;

        Vector3 cameraPos = camera.position();

        Vector3 left   = camera.screenToWorld(0, Y+h2, z) - cameraPos;
        Vector3 right  = camera.screenToWorld(w, Y+h2, z) - cameraPos;
        Vector3 top    = camera.screenToWorld(w2, Y,   z) - cameraPos;
        Vector3 bottom = camera.screenToWorld(w2, Y+h, z) - cameraPos;

        constants.screenMiddle = float3(camera.screenToWorld(w2, Y+h2, z) - cameraPos);
        constants.screenXDelta = float3((right-left) / w);
        constants.screenYDelta = float3((bottom-top) / h);

        updateConstants();

        boxRenderer.update(camera, world.bb.min, world.bb.max);

        sphereRenderer.cameraUpdate(camera);
        sphereRenderer.clear();
        sphereRenderer.addSphere(Vector3(0,0,0), 5, WHITE);
        //sphereRenderer.addSphere(Vector3(0,0,1024), 5, BLUE);
        sphereRenderer.addSphere(world.sunPos, 50, YELLOW);
        //sphereRenderer.addSphere(Vector3(50,50,50), 5, RED);
    }
    void render() {
        renderTiming.startFrame();

        acquireGLObjects();
        executeMarchKernel();
        executeShadeKernel();
        releaseGLObjects();

        //queue.enqueueReadBuffer(outputBuf, output.ptr, null, false, &event4);

        queue.finish();

        if(!DEBUG) {
            marchKernelTiming.endFrame(marchKernelEvent.getRunTime());
            shadeKernelTiming.endFrame(shadeKernelEvent.getRunTime());
            acquireGLTiming.endFrame(acquireGLEvent.getRunTime());
            releaseGLTiming.endFrame(releaseGLEvent.getRunTime());
        }
        marchKernelEvent.release();
        shadeKernelEvent.release();
        acquireGLEvent.release();
        releaseGLEvent.release();

        quadRenderer.render();
        boxRenderer.render();
        sphereRenderer.render();

        renderTiming.endFrame();
    }
    void chunkUpdated(Chunk chunk) {

    }
 private:
    void executeInitKernel() {
        queue.enqueueKernel(
            initKernel,
            [1, 1],
            null,
            null,
            null);
        queue.finish();
    }
    void executeMarchKernel() {
        queue.enqueueKernel(
            marchKernel,
            [width, height],
            kernelSquareWGSize2d,
            null,
            &marchKernelEvent);
    }
    void executeShadeKernel() {
        queue.enqueueKernel(
            shadeKernel,
            [width, height],
            //null,
            kernelRowMajorWGSize2d,
            //kernelSquareWGSize2d,
            null,
            &shadeKernelEvent);
    }
    void acquireGLObjects() {
        queue.enqueueAcquireGLObjects(
            [imageBuf], null, &acquireGLEvent
        );
    }
    void releaseGLObjects() {
        queue.enqueueReleaseGLObjects(
            [imageBuf], null, &releaseGLEvent
        );
    }
    void updateConstants() {
        constants.width    = width;
        constants.height   = height;
        constants.worldBB0 = float3(world.bb.pp[0]);
        constants.worldBB1 = float3(world.bb.pp[1]);
        constants.chunksX  = world.chunksX;
        constants.chunksY  = world.chunksY;
        constants.chunksZ  = world.chunksZ;
        constants.cameraOrigin = float3(world.camera.position);
        constants.cameraUp = float3(world.camera.up);
        marchKernel.setArg!Constants_CL(0, constants);

        shadeConstants.width  = width;
        shadeConstants.height = height;
        shadeConstants.sunPos = float3(world.sunPos);
        shadeKernel.setArg!ShadeConstants_CL(0, shadeConstants);
    }
    /// fill up voxelData and chunkData buffers
    void initialiseBuffers() {
        // todo - handle this
        assert(voxelDataBuf is null);

        auto voxelsSize = world.chunks.map!(it=>it.getVoxelsLength)
                                      .sum();

        this.voxelDataBuf = ctx.createBuffer(
            CL_MEM_READ_ONLY | CL_MEM_HOST_WRITE_ONLY,
            voxelsSize
        );
        this.chunkDataBuf = ctx.createBuffer(
            CL_MEM_READ_ONLY | CL_MEM_HOST_WRITE_ONLY,
            world.chunks.length*ChunkData_CL.sizeof
        );
        marchKernel.setArg!CLBuffer(1, voxelDataBuf);
        marchKernel.setArg!CLBuffer(2, chunkDataBuf);

        uint voxelsOffset = 0;
        uint chunksOffset = 0;
        foreach(c; world.chunks) {
            // write voxelData
            queue.enqueueWriteBufferRect(
                voxelDataBuf, voxelsOffset,
                c.getVoxelsPtr, c.getVoxelsLength,
                null
            );
            // write chunkData
            ChunkData_CL cd;
            cd.voxelsOffset = voxelsOffset;

            queue.enqueueWriteBufferRect(
                chunkDataBuf, chunksOffset, &cd, ChunkData_CL.sizeof,
                null, BLOCKING
            );
            voxelsOffset += c.getVoxelsLength;
            chunksOffset += ChunkData_CL.sizeof;
        }
        writefln("written %s bytes of voxelData", voxelsOffset);
        writefln("written %s bytes of chunkData", chunksOffset);
        flushStdErrOut();
    }
    void setupCL() {
        cl_context_properties[] props = [
            CL_GL_CONTEXT_KHR,
            cast(cl_context_properties)gl.getGLContext(),

            CL_WGL_HDC_KHR,
            cast(cl_context_properties)gl.getDC()
        ];
        this.ctx   = cl.getPlatform().createGPUContext(props);
        this.queue = ctx.createQueue(true);

        CLDevice dev = ctx.getDevices[0];

        this.voxelsHitBuf = ctx.createBuffer(
            CL_MEM_READ_WRITE | CL_MEM_HOST_NO_ACCESS,
            width*height*ubyte.sizeof
        );
        this.positionsHitBuf = ctx.createBuffer(
            CL_MEM_READ_WRITE | CL_MEM_HOST_NO_ACCESS,
            width*height*float.sizeof*3
        );

        this.imageBuf = ctx.createFromGLTexture(
            CL_MEM_WRITE_ONLY,
            textureID,
            GL_TEXTURE_2D,
            width*height*4
        );

        auto program = ctx.getProgram(
            "kernels/main.c",
            [
             //"-cl-std=CL1.2",
             "-D CHUNK_SIZE=%s".format(CHUNK_SIZE),
             "-D CHUNK_SIZE_SHR=%s".format(CHUNK_SIZE_SHR),
             "-D OCTREE_ROOT_BITS=%s".format(OCTREE_ROOT_BITS),
             DEBUG ? "-D DEBUG" : ""
             ], true
        );
        if(!program.compiled) {
            throw new Error("Unable to compile OpenCL kernel:\n"~program.compilationMessage);
        }

        this.initKernel  = program.getKernel("Init");
        this.marchKernel = program.getKernel("March");
        this.shadeKernel = program.getKernel("Shade");

        //marchKernel[0] = Constants_CL
        //marchKernel[1] = voxelDataBuf
        //marchKernel[2] = chunkDataBuf
        marchKernel.setArg!CLBuffer(3, voxelsHitBuf);
        marchKernel.setArg!CLBuffer(4, positionsHitBuf);

        //shadeKernel[0] = ShadeConstants_CL
        shadeKernel.setArg!CLBuffer(1, voxelsHitBuf);
        shadeKernel.setArg!CLBuffer(2, positionsHitBuf);
        shadeKernel.setArg!CLBuffer(3, imageBuf);

        kernelSquareWGSize2d =
            marchKernel.getSquareWorkGroupSize2d(dev);

        kernelRowMajorWGSize2d =
            marchKernel.getRowMajorWorkGroupSize2d(dev);

        log("kernel square work group size 2d = %s", kernelSquareWGSize2d);

        executeInitKernel();
    }
    void setupTexture() {
        glGenTextures(1, &textureID);

        glBindTexture(GL_TEXTURE_2D, textureID);
        glActiveTexture(GL_TEXTURE0 + 0);

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA,
                     width, height,
                     0, GL_RGBA, GL_UNSIGNED_BYTE, null);
    }
    void setupSpriteRenderer() {
        quadRenderer = new SpriteRenderer(gl, false);
        quadRenderer
            .setVP(new Camera2D(gl.windowSize).VP);
        quadRenderer
            .withTexture(new Texture(textureID, Dimension(width, height)))
            .addSprites([
                cast(BitmapSprite)new BitmapSprite()
                    .move(Vector2(renderRect.x,renderRect.y))
                    .scale(renderRect.w, renderRect.h)
            ]);
    }
}

