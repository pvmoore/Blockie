module blockie.render.gl_compute_renderer;

import blockie.all;

final class GLComputeRenderer : IRenderer, ChunkManager.SceneChangeListener {
private:
    const bool DEBUG               = false;
    const uint DEBUG_BUFFER_LENGTH = 100;

    RenderView renderView;
    OpenGL gl;
    World world;
    uint renderTextureID;
    uint marchOutTextureID;
    int width, height;
    int4 renderRect;
    ChunkManager chunkManager;
    SpriteRenderer quadRenderer;
    SphereRenderer3D sphereRenderer;
    Timing renderTiming;
    Timing computeTiming;

    Program marchProgram, shadeProgram, dummyProgram;

    VBO marchVoxelsInVBO, marchChunksInVBO;
    VBO marchOutVBO, marchDebugOutVBO;

    uint[2] timerQueries;
    uint flipFlop;

    uint[] materialTextures;

    final static struct ChunkData_GL {
        uint voxelsOffset;
        static assert(ChunkData_GL.sizeof==4);
    }
public:
    this(OpenGL gl, RenderView renderView, int4 renderRect) {
        this.gl           = gl;
        this.renderRect   = renderRect;
        this.renderView   = renderView;
        this.width        = renderRect.width;
        this.height       = renderRect.height;

        expect((width&7)==0, "Width must be multiple of 8. It is %s".format(width));
        expect((height&7)==0, "Height must be multiple of 8. It is %s".format(height));

        this.renderTiming   = new Timing(10,3);
        this.computeTiming  = new Timing(10,3);
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
    void destroy() {
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
        if(chunkManager) chunkManager.destroy();

        if(marchProgram) marchProgram.destroy();
        if(shadeProgram) shadeProgram.destroy();
        if(dummyProgram) dummyProgram.destroy();
    }
    @Implements("IRenderer")
    void setWorld(World world) {
        this.world = world;
        chunkManager = new ChunkManager(
            this,
            world,
            marchVoxelsInVBO.getMemoryManager(),
            marchChunksInVBO.getMemoryManager()
        );
        sphereRenderer.addSphere(world.sunPos, 100, YELLOW);
        cameraMoved();
    }
    @Implements("IRenderer")
    void afterUpdate(bool camMoved) {
        if(camMoved) cameraMoved();
        chunkManager.afterUpdate();
    }
    @Implements("IRenderer")
    void render() {
        //log("render");
        renderTiming.startFrame();

        glBeginQuery(GL_TIME_ELAPSED, timerQueries[flipFlop]);
        flipFlop ^= 1;

        executeMarchShader();

        glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);// | GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);

        executeDummyShader();

        glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);// | GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);

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
        //log("render end");
        //flushLog();
    }
    @Implements("SceneChangeListener")
    void boundsChanged(uvec3 chunksDim, worldcoords minBB, worldcoords maxBB) {
        marchProgram
            .use()
            .setUniform("WORLD_CHUNKS_XYZ", chunksDim)
            .setUniform("WORLD_BB", [minBB.to!float, maxBB.to!float]);

        shadeProgram
            .use()
            .setUniform("WORLD_CHUNKS_XYZ", chunksDim)
            .setUniform("WORLD_BB", [minBB.to!float, maxBB.to!float]);
    }
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

        glDispatchCompute(
            width/8,
            height/8,
            1);
    }
    void executeShadeShader() {
        shadeProgram.use();

        glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, marchOutVBO.id);

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

        glBindImageTexture(
            1,              // binding
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

        glDispatchCompute(
            width/8,
            height/8,
            1);
    }
    void executeDummyShader() {
        dummyProgram.use();

        glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, marchOutVBO.id);

        glDispatchCompute(
            width/8,
            height/8,
            1
        );
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
                "C:/pvmoore/_assets/shaders/"],
                defines
            );
            shadeProgram.loadCompute(
                "pass3_shade.comp",
                ["shaders/",
                "C:/pvmoore/_assets/shaders/"],
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
                    .setUniform("SIZE", int2(width,height));
        shadeProgram.use()
                    .setUniform("SIZE", ivec2(width,height));
        dummyProgram.use()
                    .setUniform("SIZE", ivec2(width,height));

        /// create 1300MB voxels buffer
        marchVoxelsInVBO = VBO.shaderStorage(1024*1024*1300, GL_DYNAMIC_DRAW);

        /// create space for 1 million offsets
        marchChunksInVBO = VBO.shaderStorage(1024*1024*uint.sizeof, GL_DYNAMIC_DRAW);

        marchOutVBO = VBO.shaderStorage(width*height*8, GL_DYNAMIC_DRAW);

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
                     width, height,
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
            .withTexture(new Texture2D(renderTextureID, Dimension(width, height)))
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
        log("cameraMoved");
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

        marchProgram
            .use()
            .setUniform("SCREEN_MIDDLE", camera.screenToWorld(w2, Y+h2, z) - cameraPos)
            .setUniform("SCREEN_XDELTA", (right-left) / w)
            .setUniform("SCREEN_YDELTA", (bottom-top) / h)
            .setUniform("CAMERA_POS", world.camera.position);

        //import std.math : tan;
        //marchProgram.setUniform("VIEW",    camera.V);
        //marchProgram.setUniform("INVVIEW", camera.V.inversed());
        //marchProgram.setUniform("TANFOV2", tan(camera.fov.radians/2));

        shadeProgram
            .use()
            .setUniform("SUN_POS", world.sunPos)
            .setUniform("CAMERA_POS", cameraPos)
            .setUniform("SCREEN_MIDDLE", camera.screenToWorld(w2, Y+h2, z) - cameraPos)
            .setUniform("SCREEN_XDELTA", (right-left) / w)
            .setUniform("SCREEN_YDELTA", (bottom-top) / h);

        sphereRenderer.cameraUpdate(camera);
        log("cameraMoved end"); flushLog();
    }
}


