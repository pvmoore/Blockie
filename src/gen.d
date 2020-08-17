module gen;

import blockie.generate.all;

void main(string[] args) {

	Generator app;

    try{
        app = new Generator();
        app.run();
    }catch(Throwable t) {
        writefln("Error: %s", t.msg);
    }finally{
        writefln("");
        flushConsole();
    }
}

