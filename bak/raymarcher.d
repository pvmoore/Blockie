module blockie.render.raymarcher;
/**
 *
 */
import blockie.all;

final class RayMarcher {
    Pixel[] pixels;
    Ray[] rays;
    World world;
    uint width;
    uint height;
    static struct Voxel {
        float distance = 0;
        ushort size = 0;
        ubyte value = 0;
    }
    static struct Position {
        Chunk chunk; // current chunk
        uint x,y,z;  // current pos within world
    }

    this(Pixel[] pixels, Ray[] rays,
         uint width, uint height)
    {
        this.pixels = pixels;
        this.rays   = rays;
        this.width  = width;
        this.height = height;
    }
    void generate(World world) {
        this.world = world;
        uint i = 0;
        for(int y=0; y<height; y++) {
            marchLine(i);
            i += width;
        }
    }
    void marchLine(uint i) {
        Ray ray;
        for(int x=0; x<width; x++) {
            rays[i].copyTo(ray);
            marchRay(ray, i);
            i++;
        }
    }
    void marchRay(ref Ray ray, uint pixelIndex) {
        Position pos;
        float minT, maxT;

        // does ray intersect with the world at all?
        if(!world.bb.intersect(ray, minT, maxT, EPSILON, float.max)) {
            pixels[pixelIndex] = Pixel(0, 0, 0);
            return;
        }
        // move forward to the world entry
        if(minT>=0) {
            ray.origin = (
                (ray.origin-world.bb.min) +
                (ray.direction*minT)
            );
        }
        // make sure we are actually inside the world
        while(pos.chunk is null && maxT > 0) {
            ray.origin += ray.direction*0.1;
            getChunk(ray, pos);
            maxT -= 0.5;
        }
        bool inShadow;
        Voxel voxel = march(ray, pos, float.max);
        if(voxel.value>0) {
            // We hit something.

            // reverse until we are back in air again
            ray.setDirection(-ray.direction);
            float dist = getMinDistToEdge(ray, pos, voxel.size)+0.1f;
            ray.origin += ray.direction*dist;
            getChunk(ray, pos);

            // Fire off a shadow ray
            ray.setDirection((world.sunPos-ray.origin).normalised());

            inShadow = march(ray, pos, float.max).value>0;
        }
        pixels[pixelIndex] = toPixel(voxel, inShadow, ray);
    }
private:
    Voxel march(ref Ray ray, ref Position pos, float maxDistance) {
        Voxel voxel;

//        if(pos.chunk) {
//            auto subChunk = getSubChunk(chunk, x,y,z);
//            if(subChunk.isSolidAir && subChunk.distance>1) {
//                ray.origin += (ray.direction *
//                              (subChunk.distance-1) * SUB_CHUNK_SIZE);
//                chunk = getChunk(ray, x,y,z);
//            }
//        }

        // march through air voxels
        while(pos.chunk &&
              voxel.distance < maxDistance &&
              getAirVoxel(voxel, pos)) {
            // We are inside an air voxel.
            // Move to the edge
            float dist = getMinDistToEdge(ray, pos, voxel.size)+0.05;
            ray.origin += ray.direction*dist;
            voxel.distance += dist;
            getChunk(ray, pos);
        }
        return voxel;
    }
    /// Return true if we have found an air voxel.
    /// The voxel value and size is also set
    bool getAirVoxel(ref Voxel voxel, ref Position pos) {
        const ptr   = pos.chunk.voxels.ptr;
        auto root   = cast(OctreeRoot*)ptr;

        voxel.size  = CHUNK_SIZE;

        // root
        if(root.isSolidAir) return true;

        voxel.size >>= OCTREE_ROOT_BITS;

        static if(OCTREE_ROOT_BITS==1) {
            uint oct = getOctet_1(pos.x,pos.y,pos.z, voxel.size);
        } else static if(OCTREE_ROOT_BITS==2) {
            uint oct = getOctet_11(pos.x,pos.y,pos.z, CHUNK_SIZE_SHR);
        } else static if(OCTREE_ROOT_BITS==3) {
            uint oct = getOctet_111(pos.x,pos.y,pos.z, CHUNK_SIZE_SHR);
        } else static if(OCTREE_ROOT_BITS==4) {
            uint oct = getOctet_1111(pos.x,pos.y,pos.z, CHUNK_SIZE_SHR);
        } else static if(OCTREE_ROOT_BITS==5) {
           uint oct = getOctet_11111(pos.x,pos.y,pos.z, CHUNK_SIZE_SHR);
        } else static assert(false);

        OctreeIndex* index = &root.indexes[oct];

        if(root.isSolid(oct)) {
            voxel.value = index.voxel;
            return voxel.value==V_AIR;
        }

        // branches
        auto branch = cast(OctreeBranch*)(ptr+index.offset);
        voxel.size >>= 1;

        while(voxel.size>1) {
            oct   = getOctet_1(pos.x,pos.y,pos.z, voxel.size);
            index = &branch.indexes[oct];

            if(branch.isSolid(oct)) {
                voxel.value = index.voxel;
                return voxel.value==V_AIR;
            }
            branch = cast(OctreeBranch*)(ptr+index.offset);
            voxel.size >>= 1;
        }
        // leaf
        oct = getOctet_1(pos.x,pos.y,pos.z, 1);
        auto leaf   = cast(OctreeLeaf*)branch;
        voxel.value = leaf.getVoxel(oct);
        return voxel.value==V_AIR;
    }
    float getMinDistToEdge(ref Ray ray, ref Position pos, uint size) {
        const AND = size-1;
        float m, f;
        f = (pos.x&AND) + (ray.origin.x-pos.x);
        f = ray.invDirection.x<0 ? -f : size-f;
        m = f * ray.invDirection.x;

        f = (pos.y&AND) + (ray.origin.y-pos.y);
        f = ray.invDirection.y<0 ? -f : size-f;
        m = min(m, f * ray.invDirection.y);

        f = (pos.z&AND) + (ray.origin.z-pos.z);
        f = ray.invDirection.z<0 ? -f : size-f;
        m = min(m, f * ray.invDirection.z);
        return max(m, 0);
    }
    Pixel toPixel(Voxel voxel, bool inShadow, ref Ray ray) {
        Vector3 diffuse  = DIFFUSE_VOXEL_VALUE[voxel.value];
        float brightness = inShadow ? 0.80 : 1.0;
        return (brightness * diffuse).toPixel;
        //return (diffuse + (diffuse*brightness*0.5)).toPixel;
    }
//    Vector3 getNormal(ref Ray ray, float size) {
//        Vector3 v = (ray.origin%size) - (size/2f);
//        float x = fabs(v.x);
//        float y = fabs(v.y);
//        float z = fabs(v.z);
//        uint xb = x>y && x>z;
//        uint yb = !xb && y>z;
//        uint zb = !xb && !yb;
//        assert(xb+yb+zb==1);
//        return Vector3(
//            signum(xb*v.x),
//            signum(yb*v.y),
//            signum(zb*v.z));
//        //return v.normalised();
//    }
//    float getBrightness(Vector3 hitPoint, Vector3 normal) {
//        Vector3 toLight  = (world.sunPos-hitPoint).normalised();
//        float NdotL 	 = normal.dot(toLight);
//        return max(NdotL, 0);
//    }
    void getChunk(ref Ray ray, ref Position pos) nothrow {
        pos.x     = cast(uint)ray.origin.x;
        pos.y     = cast(uint)ray.origin.y;
        pos.z     = cast(uint)ray.origin.z;
        pos.chunk = world.getChunk(
            pos.x >> CHUNK_SIZE_SHR,
            pos.y >> CHUNK_SIZE_SHR,
            pos.z >> CHUNK_SIZE_SHR);
    }
}
