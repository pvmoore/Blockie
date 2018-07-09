module blockie.generate.diamondsquare;

import blockie.all;
import blockie.generate.all;
import core.bitop : popcnt;

/**
 *  Size needs to be (2^^n)-1 eg. 129 or 513
 *
 *
 *
 */
final class DiamondSquare {
private:
    uint size;
    uint featureSize;
    float scale;
    float[] heights;
    Mt19937 gen;
public:
    this(uint size, float scale=1, uint featureSize=0) {
        if(popcnt(size-1)!=1) throw new Error("Invalid size");
        this.size  = size;
        this.scale = scale;
        this.featureSize = featureSize==0 ? size-1 : featureSize;
        this.heights.length = size*size;
        heights[] = 0;
        gen.seed(0);
    }
    float[] generate() {
        setSeedValues();

        int samplesize = featureSize;
        float subscale = scale;

        while(samplesize > 1) {
            diamondSquare(samplesize, scale);

            samplesize /= 2;
            subscale   /= 2;
        }
        return heights;
    }
    override string toString() {
        auto buf = appender!(string);
        for(auto y=0; y<size; y++) {
            for(auto x=0; x<size; x++) {
                float f = heights[x+y*size];
                buf.put("%s ".format(f));
            }
            buf.put("\n");
        }
        return buf.data;
    }
private:
   void set(int x, int y, float f) {
        if(x<0) x+=size;
        if(y<0) y+=size;
        if(x>=size) x -= size;
        if(y>=size) y -= size;
        heights[x+y*size] = f;
    }
    float get(int x, int y) {
        if(x<0) x+=size;
        if(y<0) y+=size;
        if(x>=size) x -= size;
        if(y>=size) y -= size;
        return heights[x+y*size];
    }
    void setSeedValues() {
        for(int y = 0; y < size; y += featureSize)
        for (int x = 0; x < size; x += featureSize)
        {
            set(x, y, uniform(-1f, 1f,gen)*scale);
        }
    }
    void square(int x, int y, int subsize, float value) {
        int hs = subsize / 2;

        // a     b
        //
        //    x
        //
        // c     d

        float a = get(x - hs, y - hs);
        float b = get(x + hs, y - hs);
        float c = get(x - hs, y + hs);
        float d = get(x + hs, y + hs);

        set(x, y, ((a + b + c + d) / 4) + value);
    }
    void diamond(int x, int y, int subsize, float value) {
        int hs = subsize / 2;

        //   c
        //
        //a  x  b
        //
        //   d

        float a = get(x - hs, y);
        float b = get(x + hs, y);
        float c = get(x, y - hs);
        float d = get(x, y + hs);

        set(x, y, ((a + b + c + d) / 4.0) + value);
    }
    void diamondSquare(int stepsize, float subscale) {
        int halfstep = stepsize / 2;

        for(int y = halfstep; y < size+halfstep; y += stepsize)
        {
            for(int x = halfstep; x < size+halfstep; x += stepsize)
            {
                square(x, y, stepsize, uniform(-1f,1f,gen) * subscale);
            }
        }

        for(int y = 0; y < size; y += stepsize)
        {
            for(int x = 0; x < size; x += stepsize)
            {
                diamond(x + halfstep, y, stepsize, uniform(-1f,1f,gen) * subscale);
                diamond(x, y + halfstep, stepsize, uniform(-1f,1f,gen) * subscale);
            }
        }

    }
}

