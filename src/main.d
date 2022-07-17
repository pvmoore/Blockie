module main;

version(Win64) {} else { static assert(false); }

import blockie.render.all;
import core.sys.windows.windows;
import core.runtime : Runtime;

pragma(lib, "user32.lib");

extern(Windows)
int WinMain(HINSTANCE theHInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
	int result = 0;
	Blockie app;
	Throwable exception;

	try{
		Runtime.initialize();

		app = new VKBlockie();

		app.initialise();
		app.run();

	}catch(Throwable e) {
	    exception = e;
		log("exception: %s", e.msg);
	}finally{
		flushLog();
		flushConsole();
		app.destroy();
		if(exception) {
		    MessageBoxA(null, exception.toString().toStringz, "Error", MB_OK | MB_ICONEXCLAMATION);
        	result = -1;
		}
		Runtime.terminate();
	}
	return result;
}

