module blockie.render.gl_compute_renderer;

import blockie.all;

final class GLComputeRenderer : IRenderer, ChunkUpdateListener {
private:
    const bool DEBUG = false;
    OpenGL gl;
    World world;
    uint textureID;
    uint marchOutTextureID;
    int width, height;
    IntRect renderRect;
    SceneManager sceneManager;
    SpriteRenderer quadRenderer;
    SphereRenderer3D sphereRenderer;
    Timing renderTiming;
    Timing computeTiming;
    Program marchProgram, shadeProgram;
    VBO marchVoxelsInVBO, marchChunksInVBO;
    VBO marchDebugOutVBO;
    uint[2] timerQueries;
    uint flipFlop;

    uint[] materialTextures;

    static assert(ChunkData_GL.sizeof==4);
    final static struct ChunkData_GL {
        uint voxelsOffset;
    }
//    static assert(MarchOut_GL.sizeof==16);
//    align(1) final struct MarchOut_GL { align(1):
//        float[3] pos;    // in world coords
//        ubyte voxel;
//        ubyte[3] padding;
//    }
public:
    this(OpenGL gl, IntRect renderRect) {
        this.gl           = gl;
        this.renderRect   = renderRect;
        this.width        = renderRect.width;
        this.height       = renderRect.height;

        expect((width&7)==0, "Width must be multiple of 8. It is %s".format(width));
        expect((height&7)==0, "Height must be multiple of 8. It is %s".format(height));
        //if((width&7)!=0) throw new Error("Width must be multiple of 8. It is %s".format(width));
        //if((height&7)!=0) throw new Error("Height must be multiple of 8. It is %s".format(height));

        this.renderTiming   = new Timing(10,3);
        this.computeTiming  = new Timing(10,3);
        this.sphereRenderer = new SphereRenderer3D(gl);
        this.marchProgram   = new Program();
        this.shadeProgram   = new Program();

        setupMarchOutputTexture();
        setupShadeOutputTexture();
        loadMaterialTextures();
        setupSpriteRenderer();
        setupCompute();
    }
    @Implements("IRenderer")
    void destroy() {
        if(timerQueries[0]) glDeleteQueries(timerQueries.length, timerQueries.ptr);
        if(quadRenderer) quadRenderer.destroy();
        if(sphereRenderer) sphereRenderer.destroy();
        if(textureID) glDeleteTextures(1, &textureID);
        if(materialTextures.length>0) {
            glDeleteTextures(cast(int)materialTextures.length, materialTextures.ptr);
        }
        if(marchOutTextureID) glDeleteTextures(1, &marchOutTextureID);
        if(marchVoxelsInVBO) marchVoxelsInVBO.destroy();
        if(marchChunksInVBO) marchChunksInVBO.destroy();
        if(marchDebugOutVBO) marchDebugOutVBO.destroy();
    }
    @Implements("IRenderer")
    void setWorld(World world) {
        this.world = world;
        sceneManager = new SceneManager(
            this,
            world,
            marchVoxelsInVBO,
            marchChunksInVBO);
        sphereRenderer.addSphere(world.sunPos, 100, YELLOW);
        cameraMoved();
    }
    @Implements("IRenderer")
    void afterUpdate(bool camMoved) {
        if(camMoved) cameraMoved();
        sceneManager.afterUpdate();
    }
    @Implements("IRenderer")
    void render() {
        renderTiming.startFrame();

        glBeginQuery(GL_TIME_ELAPSED, timerQueries[flipFlop]);
        flipFlop ^= 1;

        executeMarchShader();
        glMemoryBarrier(
            GL_SHADER_STORAGE_BARRIER_BIT |
            GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);

        executeShadeShader();
        glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);

//        float[] buf = readBuffer!float(marchDebugOutVBO,0, 13);
//        if(buf[0]) {
//            writefln("debugOut=%s", buf);
//        }

        glFlush();
        glEndQuery(GL_TIME_ELAPSED);

        quadRenderer.render();
        sphereRenderer.render();

        //glMemoryBarrier(GL_ALL_BARRIER_BITS);
        ulong queryTime = getElapsedTime(timerQueries[flipFlop]);

        if(!DEBUG) {
            computeTiming.endFrame(queryTime);
        }

        renderTiming.endFrame();

        getComputeMonitor().setValues(
            renderTiming.average(2),
            computeTiming.average(2)
        );
    }
    @Implements("ChunkUpdateListener")
    void setBounds(uvec3 chunksDim, ivec3 minBB, ivec3 maxBB) {
        marchProgram.use();
        marchProgram.setUniform("WORLD_CHUNKS_XYZ",
            chunksDim
        );
        marchProgram.setUniform("WORLD_BB",
            [minBB.to!float, maxBB.to!float]
        );
    }
 private:
    ulong getElapsedTime(uint query) {
        ulong time;
        int available;
        while(!available) {
            glGetQueryObjectiv(query, GL_QUERY_RESULT_AVAILABLE, &available);
        }
        glGetQueryObjectui64v(query, GL_QUERY_RESULT, &time);
        return time;
    }
    void executeMarchShader() {
        marchProgram.use();

        glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, marchVoxelsInVBO.id);
        glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, marchChunksInVBO.id);

        //glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 3, marchDebugOutVBO.id);

        glBindImageTexture(
            2,              // binding
            marchOutTextureID,
            0,              // level
            GL_FALSE,       // layered
            0,              //layer
            GL_WRITE_ONLY,
            GL_RGBA32F);

        glDispatchCompute(
            width/8,
            height/8,
            1);
    }
    void executeShadeShader() {
        shadeProgram.use();

        glBindImageTexture(
            0,              // binding
            marchOutTextureID,
            0,              // level
            GL_FALSE,       // layered
            0,              //layer
            GL_READ_ONLY,
            GL_RGBA32F);

        glBindImageTexture(
            1,              // binding
            textureID,
            0,              // level
            GL_FALSE,       // layered
            0,              //layer
            GL_WRITE_ONLY,
            GL_RGBA8);

//        glBindImageTexture(
//            2,              // binding
//            materialTextures[0],
//            0,              // level
//            GL_FALSE,       // layered
//            0,              //layer
//            GL_READ_ONLY,
//            GL_RGBA8);
        shadeProgram.setUniform("SAMPLER0", 0);
        glActiveTexture(GL_TEXTURE0 + 0);
        glBindTexture(GL_TEXTURE_2D, materialTextures[0]);

        glDispatchCompute(
            width >> 3,
            height >> 3,
            1);
    }
    void setupCompute() {
        string[] defines = [
            "#define CHUNK_SIZE %s".format(CHUNK_SIZE),
            "#define CHUNK_SIZE_SHR %s".format(CHUNK_SIZE_SHR),
            "#define OCTREE_ROOT_BITS %s".format(OCTREE_ROOT_BITS),
            "#define OctreeRootSize %s".format(OctreeRoot.sizeof),
            "#define OctreeBranchSize %s".format(OctreeBranch.sizeof),
            "#define OctreeTwigSize %s".format(OctreeTwig.sizeof),
            "#define OctreeLeafSize %s".format(OctreeLeaf.sizeof),
            "#define DFIELD_OFFSET %s".format(OptimisedRoot.dfields.offsetof)
        ];

        marchProgram.loadCompute(
            "march.comp",
            ["shaders/",
             "C:/pvmoore/_assets/shaders/"],
            defines
        ).use()
         .setUniform("SIZE", ivec2(width,height));

        // create 500MB buffer
        marchVoxelsInVBO = VBO.shaderStorage(1024*1024*750, GL_DYNAMIC_DRAW);

        // create space for 1 million offsets
        marchChunksInVBO = VBO.shaderStorage(1024*1024*uint.sizeof, GL_DYNAMIC_DRAW);

        marchDebugOutVBO = VBO.shaderStorage(width*height*vec4.sizeof, GL_DYNAMIC_DRAW);

        shadeProgram.loadCompute(
            "shade.comp",
            ["shaders/",
             "C:/pvmoore/_assets/shaders/"],
            defines
        ).use()
         .setUniform("SIZE", ivec2(width,height));

        glGenQueries(timerQueries.length, timerQueries.ptr);

        // ensure query[1] is valid
        glBeginQuery(GL_TIME_ELAPSED, timerQueries[1]);
        glEndQuery(GL_TIME_ELAPSED);
    }
    void setupMarchOutputTexture() {
        glGenTextures(1, &marchOutTextureID);

        glBindTexture(GL_TEXTURE_2D, marchOutTextureID);
        glActiveTexture(GL_TEXTURE0 + 0);

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);

        glTexImage2D(GL_TEXTURE_2D, 0,
                     GL_RGBA32F,
                     width, height,
                     0, GL_RGBA,
                     GL_FLOAT, null);
    }
    void setupShadeOutputTexture() {
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
    void loadMaterialTextures() {
        auto png = PNG.read("/pvmoore/_assets/images/png/rock8.png");

        uint id;
        glGenTextures(1, &id);
        materialTextures ~= id;

        glBindTexture(GL_TEXTURE_2D, id);
        glActiveTexture(GL_TEXTURE0 + 0);

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

        auto format = png.bytesPerPixel==3 ? GL_RGB : GL_RGBA;

        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA,
                     png.width, png.height,
                     0, format, GL_UNSIGNED_BYTE, png.data.ptr);

    }
    void setupSpriteRenderer() {
        quadRenderer = new SpriteRenderer(gl, false);
        quadRenderer
            .setVP(new Camera2D(gl.windowSize).VP);
        quadRenderer
            .withTexture(new Texture2D(textureID, Dimension(width, height)))
            .addSprites([
                cast(BitmapSprite)new BitmapSprite()
                    .move(vec2(renderRect.x,renderRect.y))
                    .scale(renderRect.width, renderRect.height)
            ]);
    }
    T[] readBuffer(T)(VBO buf, uint start, uint end) {
        buf.bind();
        auto numBytes = (end-start)*T.sizeof;
        T[] dest = new T[end-start];
        buf.getData(dest, start*T.sizeof, numBytes);
        return dest;
    }
    void cameraMoved() {
        auto camera = world.camera;
        const float Y  = renderRect.y;
        const float w  = width;
        const float h  = height;
        const float h2 = h/2;
        const float w2 = w/2;
        const float z  = 0;

        vec3 cameraPos = camera.position();

        vec3 left   = camera.screenToWorld(0, Y+h2, z) - cameraPos;
        vec3 right  = camera.screenToWorld(w, Y+h2, z) - cameraPos;
        vec3 top    = camera.screenToWorld(w2, Y,   z) - cameraPos;
        vec3 bottom = camera.screenToWorld(w2, Y+h, z) - cameraPos;

        marchProgram.use();
        marchProgram.setUniform("SCREEN_MIDDLE",
            camera.screenToWorld(w2, Y+h2, z) - cameraPos
        );
        marchProgram.setUniform("SCREEN_XDELTA",
            (right-left) / w
        );
        marchProgram.setUniform("SCREEN_YDELTA",
            (bottom-top) / h
        );
        marchProgram.setUniform("CAMERA_ORIGIN",
            world.camera.position
        );

        shadeProgram.use();
        shadeProgram.setUniform("SUN_POS",
            world.sunPos
        );
        shadeProgram.setUniform("CAMERA_ORIGIN",
            world.camera.position
        );

        //auto worldMinMax = sceneManager.worldMinMax();

        sphereRenderer.cameraUpdate(camera);
    }
}


