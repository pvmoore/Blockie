module blockie.render.gl.GLComputeRenderer;

import blockie.render.all;

final class GLComputeRenderer : ComputeRenderer {
private:
    enum DEBUG               = false;
    enum DEBUG_BUFFER_LENGTH = 100;

    uint renderTextureID;
    uint marchOutTextureID;

    uint[2] timerQueries;
    uint flipFlop;

    // GL specific
    OpenGL gl;

    uint[] materialTextures;
    SpriteRenderer quadRenderer;
    SphereRenderer3D sphereRenderer;

    Program marchProgram, shadeProgram, dummyProgram;

    VBO marchVoxelsInVBO, marchChunksInVBO;
    VBO marchOutVBO, marchDebugOutVBO;

    struct ChunkData_GL { static assert(ChunkData_GL.sizeof==4);
        uint voxelsOffset;
    }
public:
    this(OpenGL gl, GLRenderView renderView, int4 renderRect) {
        super(renderView, renderRect);

        this.gl             = gl;
        this.sphereRenderer = new SphereRenderer3D(gl);
        this.marchProgram   = new Program;
        this.shadeProgram   = new Program;
        this.dummyProgram   = new Program;

        setupMarchOutputTexture();
        setupShadeOutputTexture();
        loadMaterialTextures();
        setupSpriteRenderer();
        setupCompute();
        renderOptionsChanged();
    }
    @Implements("IRenderer")
    override void destroy() {
        super.destroy();

        if(timerQueries[0]) glDeleteQueries(timerQueries.length, timerQueries.ptr);
        if(quadRenderer) quadRenderer.destroy();
        if(sphereRenderer) sphereRenderer.destroy();
        if(renderTextureID) glDeleteTextures(1, &renderTextureID);
        if(materialTextures.length>0) {
            glDeleteTextures(cast(int)materialTextures.length, materialTextures.ptr);
        }
        if(marchOutTextureID) glDeleteTextures(1, &marchOutTextureID);
        if(marchVoxelsInVBO) marchVoxelsInVBO.destroy();
        if(marchChunksInVBO) marchChunksInVBO.destroy();
        if(marchOutVBO) marchOutVBO.destroy();
        if(marchDebugOutVBO) marchDebugOutVBO.destroy();

        if(marchProgram) marchProgram.destroy();
        if(shadeProgram) shadeProgram.destroy();
        if(dummyProgram) dummyProgram.destroy();
    }
    @Implements("IRenderer")
    override void setWorld(World world) {
        super.setWorld(world);

        chunkManager = new ChunkManager(
            this,
            world,
            new GLGPUMemoryManager!ubyte(marchVoxelsInVBO.getMemoryManager()),
            new GLGPUMemoryManager!uint(marchChunksInVBO.getMemoryManager())
        );

        // View window never changes
        marchProgram
            .use()
            .setUniform("WORLD_CHUNKS_XYZ", chunkManager.getViewWindow());
        shadeProgram
            .use()
            .setUniform("WORLD_CHUNKS_XYZ", chunkManager.getViewWindow());

        sphereRenderer.addSphere(world.sunPos, 100, YELLOW);
        cameraMoved();
    }
    @Implements("IRenderer")
    void update(AbsRenderData renderData, bool camMoved) {
        if(camMoved) cameraMoved();
        chunkManager.afterUpdate();
    }
    @Implements("IRenderer")
    void render(AbsRenderData renderData) {
        //this.log("render");
        renderTiming.startFrame();

        glBeginQuery(GL_TIME_ELAPSED, timerQueries[flipFlop]);
        flipFlop ^= 1;

        executeMarchShader();

        glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);// | GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);

        //executeDummyShader();

        //glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);// | GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);

        executeShadeShader();

        glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);

        if(DEBUG) {
            uint[] buf = readBuffer!uint(marchDebugOutVBO, 0, 10);
            if(buf[0]) {
                writef("debugOut {\n");
                foreach(i, value; buf) {
                    writefln("\t[%s] % 12s (%08x)", i, value, value);
                }
                writefln("}");
            }
        }

        //glFlush();
        glEndQuery(GL_TIME_ELAPSED);

        quadRenderer.render();
        //sphereRenderer.render();

        //glMemoryBarrier(GL_ALL_BARRIER_BITS);
        ulong queryTime = getElapsedTime(timerQueries[flipFlop]);

        if(!DEBUG) {
            computeTiming.endFrame(queryTime);
        }

        renderTiming.endFrame();

        getEvents().fire(EventID.COMPUTE_RENDER_TIME, renderTiming.average(2));
        getEvents().fire(EventID.COMPUTE_TIME, computeTiming.average(2));
    }
    @Implements("IRenderer")
    void renderOptionsChanged() {
        assert(marchProgram);
        assert(shadeProgram);

        auto opts = [
            renderView.getRenderOption(RenderOption.DISPLAY_VOXEL_SIZES),
            renderView.getRenderOption(RenderOption.ACCURATE_VOXEL_BOXES)
        ];

        marchProgram.use().setUniform("RENDER_OPTS", opts);
        shadeProgram.use().setUniform("RENDER_OPTS", opts);
    }
    @Implements("SceneChangeListener")
    void boundsChanged( worldcoords minBB, worldcoords maxBB) {
        marchProgram
            .use()
            .setUniform("WORLD_BB", [minBB.to!float, maxBB.to!float]);

        shadeProgram
            .use()
            .setUniform("WORLD_BB", [minBB.to!float, maxBB.to!float]);
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
        glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 2, marchOutVBO.id);

        if(DEBUG) {
            glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 3, marchDebugOutVBO.id);
        }

        //glBindImageTexture(
        //    2,              // binding
        //    marchOutTextureID,
        //    0,              // level
        //    GL_FALSE,       // layered
        //    0,              //layer
        //    GL_WRITE_ONLY,
        //    GL_RGBA32F);

        glDispatchCompute(renderRect.width/8, renderRect.height/8, 1);
    }
    void executeShadeShader() {
        shadeProgram.use();

        // binding 0 - March out buffer
        glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 2, marchOutVBO.id);

        if(DEBUG) {
            //glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 2, marchDebugOutVBO.id);
        }

        //glBindImageTexture(
        //    0,              // binding
        //    marchOutTextureID,
        //    0,              // level
        //    GL_FALSE,       // layered
        //    0,              // layer
        //    GL_READ_ONLY,
        //    GL_RGBA32F);

        // Image out texture
        glBindImageTexture(
            4,              // binding
            renderTextureID,
            0,              // level
            GL_FALSE,       // layered
            0,              // layer
            GL_WRITE_ONLY,
            GL_RGBA8);

//        glBindImageTexture(
//            2,              // binding
//            materialTextures[0],
//            0,              // level
//            GL_FALSE,       // layered
//            0,              // layer
//            GL_READ_ONLY,
//            GL_RGBA8);
        shadeProgram.setUniform("SAMPLER0", 0);
        glActiveTexture(GL_TEXTURE0 + 0);
        glBindTexture(GL_TEXTURE_2D, materialTextures[0]);

        glDispatchCompute(renderRect.width/8, renderRect.height/8, 1);
    }
    void executeDummyShader() {
        dummyProgram.use();

        glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 2, marchOutVBO.id);

        glDispatchCompute(renderRect.width/8, renderRect.height/8, 1);
    }
    void setupCompute() {

        string[] defines = [
            "#define CHUNK_SIZE %s".format(CHUNK_SIZE),
            "#define CHUNK_SIZE_SHR %s".format(CHUNK_SIZE_SHR),

            // These are MODEL1 only
            "#define OctreeTwigSize %s".format(OctreeTwig.sizeof),
            "#define OctreeLeafSize %s".format(OctreeLeaf.sizeof),
            "#define DFIELD_OFFSET %s".format(OptimisedRoot.dfields.offsetof)
        ];

        version(MODEL1) {
            marchProgram.loadCompute(
                "pass1_marchM1.comp",
                ["shaders/",
                "C:/pvmoore/_assets/shaders/", "."],
                defines
            );
            shadeProgram.loadCompute(
                "pass3_shade.comp",
                ["shaders/",
                "C:/pvmoore/_assets/shaders/", "."],
                defines
            );
        } else version(MODEL1A) {
            todo("fixme");

            marchProgram.loadCompute(
                "pass1_marchM1.comp",
                ["shaders/",
                "C:/pvmoore/_assets/shaders/"],
                defines
            );
            shadeProgram.loadCompute(
                "pass3_shade.comp",
                ["shaders/",
                "C:/pvmoore/_assets/shaders/"],
                defines
            );
        } else version(MODEL2) {

            marchProgram.loadCompute(
                "pass1_marchM2.comp",
                ["shaders/",
                "C:/pvmoore/_assets/shaders/"],
                defines
            );
            shadeProgram.loadCompute(
                "pass3_shadeM2.comp",
                ["shaders/",
                "C:/pvmoore/_assets/shaders/"],
                defines
            );
        } else version(MODEL3) {
            marchProgram.loadCompute(
                "pass1_marchM3.comp",
                ["shaders/",
                "C:/pvmoore/_assets/shaders/"],
                defines
            );
            shadeProgram.loadCompute(
                "pass3_shadeM2.comp",
                ["shaders/",
                "C:/pvmoore/_assets/shaders/"],
                defines
            );
        } else version(MODEL4) {
            marchProgram.loadCompute(
                "pass1_marchM4.comp",
                ["shaders/",
                "C:/pvmoore/_assets/shaders/"],
                defines
            );
            shadeProgram.loadCompute(
                "pass3_shadeM2.comp",
                ["shaders/",
                "C:/pvmoore/_assets/shaders/"],
                defines
            );
        } else version(MODEL5) {
            marchProgram.loadCompute(
                "pass1_marchM5.comp",
                ["shaders/",
                "C:/pvmoore/_assets/shaders/"],
                defines
            );
            shadeProgram.loadCompute(
                "pass3_shadeM2.comp",
                ["shaders/",
                "C:/pvmoore/_assets/shaders/"],
                defines
            );
        } else version(MODEL6) {
            marchProgram.loadCompute(
                "pass1_marchM6.comp",
                ["shaders/",
                "C:/pvmoore/_assets/shaders/"],
                defines
            );
            shadeProgram.loadCompute(
                "pass3_shadeM2.comp",
                ["shaders/",
                "C:/pvmoore/_assets/shaders/"],
                defines
            );
        } else expect(false);

        dummyProgram.loadCompute(
            "pass2.comp",
            ["shaders/", "C:/pvmoore/_assets/shaders/"],
            defines
        );

        marchProgram.use()
                    .setUniform("SIZE", int2(renderRect.width, renderRect.height));
        shadeProgram.use()
                    .setUniform("SIZE", int2(renderRect.width, renderRect.height));
        dummyProgram.use()
                    .setUniform("SIZE", int2(renderRect.width, renderRect.height));

        marchVoxelsInVBO = VBO.shaderStorage(Blockie.VOXEL_BUFFER_SIZE, GL_DYNAMIC_DRAW);
        marchChunksInVBO = VBO.shaderStorage(Blockie.CHUNK_BUFFER_SIZE, GL_DYNAMIC_DRAW);

        marchOutVBO = VBO.shaderStorage(renderRect.width*renderRect.height*8, GL_DYNAMIC_DRAW);

        if(DEBUG) {
            marchDebugOutVBO = VBO.shaderStorage(DEBUG_BUFFER_LENGTH*uint.sizeof, GL_DYNAMIC_DRAW);
        }

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
                     renderRect.width, renderRect.height,
                     0, GL_RGBA,
                     GL_FLOAT, null);
    }
    void setupShadeOutputTexture() {
        glGenTextures(1, &renderTextureID);

        glBindTexture(GL_TEXTURE_2D, renderTextureID);
        glActiveTexture(GL_TEXTURE0 + 0);

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA,
                     renderRect.width, renderRect.height,
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
            .withTexture(new Texture2D(renderTextureID, Dimension(renderRect.width, renderRect.height)))
            .addSprites([
                cast(BitmapSprite)new BitmapSprite()
                    .move(vec2(renderRect.x,renderRect.y))
                    .scale(renderRect.width, renderRect.height)
            ]);
    }
    T[] readBuffer(T)(VBO buf, uint start, uint end) {
        assert(start<end && end<DEBUG_BUFFER_LENGTH);
        buf.bind();
        auto numBytes = (end-start)*T.sizeof;
        T[] dest = new T[end-start];
        buf.getData(dest, start*T.sizeof, numBytes);
        return dest;
    }
    void cameraMoved() {
        auto screen = calculateScreen();

        marchProgram
            .use()
            .setUniform("SCREEN_MIDDLE", screen.middle)
            .setUniform("SCREEN_XDELTA", screen.xDelta)
            .setUniform("SCREEN_YDELTA", screen.yDelta)
            .setUniform("CAMERA_POS", world.camera.position);

        //import std.math : tan;
        //marchProgram.setUniform("VIEW",    camera.V);
        //marchProgram.setUniform("INVVIEW", camera.V.inversed());
        //marchProgram.setUniform("TANFOV2", tan(camera.fov.radians/2));

        shadeProgram
            .use()
            .setUniform("SUN_POS", world.sunPos)
            .setUniform("CAMERA_POS", world.camera.position)
            .setUniform("SCREEN_MIDDLE", screen.middle)
            .setUniform("SCREEN_XDELTA", screen.xDelta)
            .setUniform("SCREEN_YDELTA", screen.yDelta);

        sphereRenderer.cameraUpdate(world.camera);
    }
}


