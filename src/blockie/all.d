module blockie.all;

public:

version(LDC) {
    import ldc.attributes : fastmath;
}

import core.time                : dur;
import core.memory	            : GC;
import core.atomic		        : atomicStore, atomicLoad;
import core.thread              : Thread;
import core.sync.mutex          : Mutex;
import core.sync.semaphore      : Semaphore;
import core.stdc.string         : memcpy;
import core.bitop               : popcnt;

import std.stdio                : writef, writefln, File;
import std.file                 : exists;
import std.math                 : fabs;
import std.datetime.stopwatch   : StopWatch;
import std.string               : toStringz, strip, indexOf;
import std.random	            : uniform, Mt19937;
import std.array                : array, Appender, appender, join, replace, split, uninitializedArray;
import std.conv                 : to;
import std.format               : format;
import std.range                : chain, iota;
import std.parallelism          : task;
import std.typecons             : Tuple, tuple;
import std.algorithm.iteration	: each, filter, map, sum, uniq;
import std.algorithm.searching	: any, all, count;
import std.algorithm.sorting    : sort;

import blockie.blockie;
import blockie.globals;
import blockie.version_;

import blockie.model;
import blockie.model1;
import blockie.model2;
import blockie.model3;
import blockie.model4;
import blockie.model5;
import blockie.model.model6;
import blockie.model.model1a;

import blockie.generate.diamondsquare;
import blockie.generate.landscapeworld;

import blockie.render.irenderer;
import blockie.render.iview;

import blockie.util.async;
import blockie.util.util;


import fonts.sdf;
import resources : PNG, HGT;
import logging : flushLog, log, setEagerFlushing, FileLogger;
import resusage.memory : ProcessMemInfo, processMemInfo;
import maths.noise;
import maths.camera;
import maths;
import events : initEvents, getEvents, EventMsg;
import common :
    Allocator, Allocator_t, Archive, Array, Async,
    BitWriter, ArrayBitWriter, ArrayByteWriter,
    Comment, From,
    IQueue, Implements, PDH, Set, Stack, Timing,
    as, dbg, expect, flushConsole, insertAt, isZeroMem, isInteger, onlyContains,
    makeSPSCQueue, nextHighestPowerOf2, repeat, todo;

version(VULKAN) {
    pragma(msg, "VULKAN");

    import vulkan;

    import blockie.render.vk.VKComputeRenderer;

}
version(OPENGL) {
    pragma(msg, "OPENGL");

    import gl;
    import gl.geom : BitmapSprite;

    import derelict.opengl;
    import derelict.glfw3;

    import blockie.render.gl.bottombar;
    import blockie.render.gl.box_renderer;
    import blockie.render.gl.console;
    import blockie.render.gl.GLComputeRenderer;
    import blockie.render.gl.minimap;
    import blockie.render.gl.monitors;
    import blockie.render.gl.GLRenderview;
    import blockie.render.gl.topbar;
}
