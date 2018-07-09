module blockie.domain.chunk.airpocket;

import blockie.all;

//nothrow:

//int countAirVoxels(Chunk chunk) {
//    int count = 0;
//    foreach(v; chunk.voxels) {
//        if(v==V_AIR) count++;
//    }
//    return count;
//}
/+
void findAirPocket(Chunk chunk) {
    const MIN = 50; // 125,000

    int numAirVoxels = countAirVoxels(chunk);
    if(numAirVoxels<MIN*MIN*MIN) {
        chunk.hasAirPocket.setNo();
        return;
    }

    int minX, minY, minZ,
        maxX = CHUNK_SIZE-1, maxY = maxX, maxZ = maxX;
    int x = CHUNK_SIZE/2, x2 = x,
        y = x, y2 = x,
        z = x, z2 = x;

    bool change = true;
    while(change) {
        change = false;
        if(x>minX) {
            if(isWallX(chunk.voxels, V_AIR, x-1, y, y2, z, z2)) {
                x--;
                change = true;
            } else minX = x;
        }
        if(x2<maxX) {
            if(isWallX(chunk.voxels, V_AIR, x2+1, y, y2, z, z2)) {
                x2++;
                change = true;
            } else maxX = x2;
        }
        if(y>minY) {
            if(isWallY(chunk.voxels, V_AIR, y-1, x, x2, z, z2)) {
                y--;
                change = true;
            } else minY = y;
        }
        if(y2<maxY) {
            if(isWallY(chunk.voxels, V_AIR, y2+1, x, x2, z, z2)) {
                y2++;
                change = true;
            } else maxY = y2;
        }
        if(z>minZ) {
            if(isWallZ(chunk.voxels, V_AIR, z-1, x, x2, y, y2)) {
                z--;
                change = true;
            } else minZ = z;
        }
        if(z2<maxZ) {
            if(isWallZ(chunk.voxels, V_AIR, z2+1, x, x2, y, y2)) {
                z2++;
                change = true;
            } else maxZ = z2;
        }
    }
    //writefln("x:%s -> %s", minX, maxX);
    //writefln("y:%s -> %s", minY, maxY);
    //writefln("z:%s -> %s", minZ, maxZ);
    if((maxX-minX)+1 < MIN ||
       (maxY-minY)+1 < MIN ||
       (maxZ-minZ)+1 < MIN)
    {
        chunk.hasAirPocket.setNo();
    } else {
       chunk.hasAirPocket.setYes();
       chunk.airPocket.bounds[0] = Vector3(minX, minY, minZ);
       chunk.airPocket.bounds[1] = Vector3(maxX+1, maxY+1, maxZ+1);
       //writefln("airPocket = %s", chunk.airPocket);
    }
}

/// min and max are inclusive
bool isWallX(const ubyte[] voxels, ubyte vox, int x,
             int minY, int maxY,
             int minZ, int maxZ)
{
    int temp, offset =
                x +
                (minZ*CHUNK_SIZE) +
                (minY*CHUNK_SIZE_SQUARED);
    for(auto y=minY; y<=maxY; y++) {
        temp = offset;
        for(auto z=minZ; z<=maxZ; z++) {
            if(voxels[offset]!=vox) return false;
            offset += CHUNK_SIZE;
        }
        offset = temp + CHUNK_SIZE_SQUARED;
    }
    return true;
}
bool isWallY(const ubyte[] voxels, ubyte vox, int y,
             int minX, int maxX,
             int minZ, int maxZ)
{
    int temp, offset =
                minX +
                (minZ*CHUNK_SIZE) +
                (y*CHUNK_SIZE_SQUARED);
    for(auto z=minZ; z<=maxZ; z++) {
        temp = offset;
        for(auto x=minX; x<=maxX; x++) {
            if(voxels[offset++]!=vox) return false;
        }
        offset = temp + CHUNK_SIZE;
    }
    return true;
}
bool isWallZ(const ubyte[] voxels, ubyte vox, int z,
             int minX, int maxX,
             int minY, int maxY)
{
    int temp, offset =
                minX +
                (z*CHUNK_SIZE) +
                (minY*CHUNK_SIZE_SQUARED);
    for(auto y=minY; y<=maxY; y++) {
        temp = offset;
        for(auto x=minX; x<=maxX; x++) {
            if(voxels[offset++]!=vox) return false;
        }
        offset = temp + CHUNK_SIZE_SQUARED;
    }
    return true;
}


/*pragma(inline,true)
int isAirRectangle(int minX, int minY, int minZ,
                   int maxX, int maxY, int maxZ)
{
    int x,y,z;
    int offset = minX +
                (minZ*CHUNK_SIZE) +
                (minY*CHUNK_SIZE_SQUARED);
    int temp,temp2;

    for(y=startY; y<endY; y++) {
        temp2 = offset;
        for(z=startZ; z<endZ; z++) {
            temp = offset;
            for(x=startX; x<endX; x++) {
                if(chunk.voxels[offset++]!=V_AIR) {
                   break;
                }
            }
            if(x<maxX) { maxX = x-1; if(maxX-xx<MIN) return 0; }
            offset = temp + CHUNK_SIZE;
        }
        if(z<maxZ) { maxZ = z-1; if(maxZ-zz<MIN) return 0;}
        offset = temp2 + CHUNK_SIZE_SQUARED;
    }
    if(y<maxY) { maxY = y-1; if(maxY-yy<MIN) return 0; }

    maxX -= xx;
    maxY -= yy;
    maxZ -= zz;
    *outX = maxX;
    *outY = maxY;
    *outZ = maxZ;
    return maxX*maxY*maxZ;
}*/

/*void findAirPocket2(Chunk chunk) {
    const MIN = 50; // 125,000

    int numAirVoxels = countAirVoxels(chunk);
    if(numAirVoxels<MIN*MIN*MIN) {
        chunk.hasAirPocket.setNo();
        return;
    }
    writefln("Chunk has %s air voxels", numAirVoxels);

    pragma(inline,true)
    int potentialVolume(int xx, int yy, int zz) {
        int offsetStart = xx +
                         (zz*CHUNK_SIZE) +
                         (yy*CHUNK_SIZE_SQUARED);
        int offset = offsetStart;
        int x,y,z;

        for(x=xx+1;x<CHUNK_SIZE;x++) {
            if(chunk.voxels[offset++]!=V_AIR) break;
        }
        if(x-xx<MIN) return 0;

        offset = offsetStart;
        for(z=zz+1;z<CHUNK_SIZE;z++) {
            if(chunk.voxels[offset]!=V_AIR) break;
            offset += CHUNK_SIZE;
        }
        if(z-zz<MIN) return 0;

        offset = offsetStart;
        for(y=yy+1;y<CHUNK_SIZE;y++) {
            if(chunk.voxels[offset]!=V_AIR) break;
            offset += CHUNK_SIZE_SQUARED;
        }
        if(y-yy<MIN) return 0;
        return (x-xx)*(y-yy)*(z-zz);
    }

    int largestVolume = 0;
    int startX, startY, startZ;
    int largestX, largestY, largestZ;
    int volX, volY, volZ;

    int offset = 0, temp, temp2;
    for(auto y=0; y<CHUNK_SIZE-MIN; y++) {
        temp2 = offset;
        for(auto z=0; z<CHUNK_SIZE-MIN; z++) {
            temp = offset;
            for(auto x=0; x<CHUNK_SIZE-MIN; x++)
            {
                if(chunk.voxels[offset++]!=V_AIR) continue;
                int volume = potentialVolume(x,y,z);
                if(volume <= largestVolume) continue;

                volume = airVolume(x, y, z, &volX, &volY, &volZ);
                if(volume>largestVolume) {
                    largestVolume = volume;
                    startX = x; startY = y; startZ = z;
                    largestX = volX; largestY = volY; largestZ = volZ;
                }
            }
            offset = temp + CHUNK_SIZE;
        }
        offset = temp2 + (CHUNK_SIZE_SQUARED);
    }
    writefln("largestVolume is %s",largestVolume);
    if(largestVolume>0) {
        chunk.hasAirPocket.setYes();
        chunk.airPocket.bounds[0] = Vector3(startX, startY, startZ);
        chunk.airPocket.bounds[1] = Vector3(startX+largestX, startY+largestY, startZ+largestZ);
        writefln("airPocket = %s", chunk.airPocket);
    } else {
        chunk.hasAirPocket.setNo();
    }
}
*/
* +/


