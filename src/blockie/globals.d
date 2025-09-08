module blockie.globals;

public:

const string version_ = "0.0.34";

enum uint MODEL  = 1;
enum float SCENE = 8;

/**
 * size 16   (4)  =         4,096 voxels
 * size 32   (5)  =        32,768 voxels
 * size 64   (6)  =       262,144 voxels
 * size 128  (7)  =     2,097,152 voxels (2MB)
 * size 256  (8)  =    16,777,216 voxels (16MB)
 * size 512  (9)  =   134,217,728 voxels (128MB)
 * size 1024 (10) = 1,073,741,824 voxels (1GB)
 */
enum CHUNK_SIZE_SHR     = 10;   
enum CHUNK_SIZE         = 2^^CHUNK_SIZE_SHR;
enum CHUNK_SIZE_SQUARED = CHUNK_SIZE*CHUNK_SIZE;

//──────────────────────────────────────────────────────────────────────────────────────────────────

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
import std.string               : toStringz, fromStringz, strip, indexOf;
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

import maths        : float2, float3, float4, uint2, uint3, int2, int3, int4, mat4, 
                      minOf, maxOf, degrees, 
                      Camera2D, Camera3D, IntRect, ImprovedPerlin;

import resources    : DDS, PNG, HGT;

import logging      : flushLog, log, setEagerFlushing, FileLogger;

import events       : initEvents, getEvents, EventMsg;

import common       : Archive, Async, Borrowed, PDH, Comment, Implements;

import common.io    : ArrayBitWriter, ArrayByteWriter,
                      BitWriter, ByteReader, flushConsole;

import common.utils : From, Timing,
                      as, bitfieldExtract, 
                      containsKey, entriesSortedByValue, expect, 
                      insertAt, isZeroMem, isInteger, onlyContains,
                      nextHighestPowerOf2, repeat, 
                      todo, toString, throwIf, throwIfNot, throwIfNull;

import common.allocators;
import common.containers : ContiguousCircularBuffer, IQueue, Set, Stack, makeSPSCQueue;

import blockie.model;
import blockie.util;

alias worldcoords = int3;
alias chunkcoords = int3;
