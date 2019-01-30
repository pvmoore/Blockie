module blockie.generate.all;

public:

import blockie.generate.diamondsquare;
import blockie.generate.landscapeworld;
import blockie.generate.testscene1;
import blockie.generate.testscene2;
import blockie.generate.testscene3;
import blockie.generate.testscene4;
import blockie.generate.testscene4b;
import blockie.generate.testscene4c;
import blockie.generate.testscene5;
import blockie.generate.testscene6_bunny;
import blockie.generate.testscene7_hgt;
import blockie.generate.worldbuilder;

import blockie.model.WorldEditor;

interface SceneGenerator {
    import blockie.all : World;

    World getWorld();
    void build(WorldEditor b);
}