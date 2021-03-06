module blockie.generate.all;

public:

import blockie.globals;

import blockie.generate.Generator;
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
import blockie.generate.testscene8;

interface SceneGenerator {
    World getWorld();
    void build(WorldEditor b);
}