module blockie.generate.all;

public:

import blockie.globals;

import blockie.generate.Generator;
import blockie.generate.diamondsquare;
import blockie.generate.landscapeworld;
import blockie.generate.scenes.testscene1;
import blockie.generate.scenes.testscene2;
import blockie.generate.scenes.testscene3;
import blockie.generate.scenes.testscene4;
import blockie.generate.scenes.testscene4b;
import blockie.generate.scenes.testscene4c;
import blockie.generate.scenes.testscene5;
import blockie.generate.scenes.testscene6_bunny;
import blockie.generate.scenes.testscene7_hgt;
import blockie.generate.scenes.testscene8;
import blockie.generate.scenes.testscene9;

import blockie.generate.magicavoxel;

interface SceneGenerator {
    World getWorld();
    void build(WorldEditor b);
}
