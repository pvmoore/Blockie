module blockie.generate.shapes;

import blockie.all;
import blockie.generate.all;

// hollow rectangle
void rectangle(WorldBuilder e,
               ivec3 min,
               ivec3 max,
               uint thickness,
               ubyte v)
{
    int t = thickness-1;
    // x
    e.rectangle(ivec3(min.x,   min.y, min.z),
                ivec3(min.x+t, max.y, max.z), v);
    e.rectangle(ivec3(max.x-t, min.y, min.z),
                ivec3(max.x,   max.y, max.z), v);
    // y
    e.rectangle(ivec3(min.x, min.y,   min.z),
                ivec3(max.x, min.y+t, max.z), v);
    e.rectangle(ivec3(min.x, max.y-t, min.z),
                ivec3(max.x, max.y,   max.z), v);
    // z
    e.rectangle(ivec3(min.x, min.y, min.z),
                ivec3(max.x, max.y, min.z+t), v);
    e.rectangle(ivec3(min.x, min.y, max.z-t),
                ivec3(max.x, max.y, max.z), v);
}
/// solid rectangle
void rectangle(WorldBuilder e,
               ivec3 min,
               ivec3 max,
               ubyte v)
{
    for(int z=min.z; z<=max.z; z++)
    for(int y=min.y; y<=max.y; y++)
    for(int x=min.x; x<=max.x; x++) {
        e.setVoxel(v, x,y,z);
    }
}
void sphere(WorldBuilder e,
            ivec3 centre,
            uint minRadius,
            uint maxRadius,
            ubyte v)
{
    vec3 c = centre.to!float;
    for(int z=centre.z-maxRadius; z<centre.z+maxRadius; z++)
    for(int y=centre.y-maxRadius; y<centre.y+maxRadius; y++)
    for(int x=centre.x-maxRadius; x<centre.x+maxRadius; x++) {

        float dist = distance(c, vec3(x,y,z));
        if(dist>=minRadius && dist<=maxRadius) {
            e.setVoxel(v, x,y,z);
        }
    }
}
// solid cylinder
void cylinder(WorldBuilder e,
              ivec3 start,
              ivec3 end,
              uint radius,
              ubyte v)
{

}
