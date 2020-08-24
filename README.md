# Klonoa-stuff

A Lua script meant to aid exploration of Klonoa: Door To Phantomile

## Requirements

-US version of Klonoa: Door To Phantomile
-Compatible PSX BIOS
-BizHawk emulator (tested on 2.4.2)

## Installing and Running

1. Click the green "code" button toward the top-right of this page
2. Choose "Download Zip"
3. Extract the files to some location
4. Start the game in BizHawk
5. Once the game is running, open the Lua console from the "Tools" menu
6. From within the Lua console, choose "Open Script..." from the "Script" menu
7. Navigate to where you extracted the files and select "Klonoa - Door to Phantomile (USA).lua"

## Features

This tool has two main components: a window with options for easily manipulating various aspects of the game state, and an in-game display that displays additional information about the game state.

TODO x position along entire path, not just segment?

This document will never be complete, but I'd like for it to be as accurate as possible. There are surely a lot of mistakes at the moment, though, so let me know if you find any!



## Level/Geometry

Each room is broken up into multiple "planes," essentially paths that Klonoa can run along. In general, any situation in which Klonoa can choose between two or more different paths requires there to be at least two planes.

[example]

Each plane itself is made up of several smaller segments. Each of these segments is perfectly straight (doesn't bend or curve), just like the polygonal segments of the planes represented as 3D geometry onscreen. 

In fact, I'm almost certain that the polygons that make up the path displayed onscreen are a one-to-one representation of the plane segments. This could ultimately be confirmed by locating the ROM data that represents the plane segments and demonstrating that modifying it affects both the rendered 3D geometry as well as the game logic/physics in a consistent way. That's a major goal for a future version of this tool.

[example]

Each plane has an associated memory address that points to a set of values. This is presumably the beginning of an array of all of the segments which make up that plane. Modifying these values DOES change how Klonoa travels along those segments, but unfortunately the changes are not represented in the 3D geometry.

As far as the logic and physics of the game are concerned, it appears that the following rules hold:

1. At any given moment, Klonoa is assumed to be "on" a single plane segment.
--When Klonoa is touching the ground, he will almost always be "on" the segment he's standing on. (This is not surprising.)
--When he's NOT touching the ground, it's not always obvious which segment he will be "on." 
--I'm speculating that it works as follows: Klonoa is "on" whichever segment he is directly above, but only among segments of the LAST plane he was standing on. This suggests a (partial) explanation for a few strange behaviors that have been discovered over the years.
--I'm not sure exactly how the game detects when Klonoa lands on a segment of any plane, but I'm guessing the game just compares Klonoa's position to every segment of every plane until it finds a segment that's "close enough." 

2. "Horizontal" movement is relative to whichever segment Klonoa is "on"
--That is, moving left or right causes Klonoa to travel "along" the segment he's "on." This is why Klonoa only changes direction AFTER landing on a new plane; he is still "on" the previous plane's segment prior to landing.
--As long as the plane segments are connected to each other, this gives the illusion that Klonoa is moving along a curved path, even though he's really moving along a sequence of straight lines.
--Klonoa's "Horizontal" position is actually stored as a value that simply represents how far he is along the segment he's "on." As far as I know, Klonoa's absolute position is not stored at all.

TODO Test whether this accounts for the weird behavior when moving directly from a gondola to a crate; landing on the crate might position Klonoa relative to the plane he is "on," which would fall apart if he's not "on" the plane directly under the box.

NOTE: There is a discrepency between how BizHawk represents memory addresses and how pointers are stored within the game's memory: BizHawk omits the first two digits '80' for addresses in the main RAM, since it is redundant (ALL main RAM is mapped to addresses beginning with 80). But BizHawk WON'T omit the 80 for pointers (memory addresses) stored within the games memory itself, because it has no way of knowing whether a given number actually reprsents a memory address or just a number that happens to start with '80'.
This simply means that if you find a pointer in memory like "801757D0" and want to see what's located there using BizHawk, you'll want to search for "1757D0" instead.



## Enemies

The tool doesn't have any functionslity related to enemies yet. That said, the following (incomplete) list describes how the enemy types are enumerated in memory. 

If you are tremendously bored, you can usually do a RAM search for numbers corresponding to some enemies that you see on screen. Once you find an enemy, if you change its type to a different number on this list and break the enemy, it will often respawn as the new type. Or crash the game. Often both, in fact.

enemyTypes = {}
enemyTypes[0] = "Moo"
enemyTypes[1] = "Moo"
enemyTypes[3] = "Purple running guy"
-- Spawn portal is treated like an enemy for some reason
-- The fact that it's somewhere in the middle of the list...
-- ...along with the fact that early enemies only spawn from offscreen...
-- ...suggests that a visible spawn portal wasn't part of the initial design.
enemyTypes[5] = "Enemy spawn portal"
enemyTypes[7] = "Birb"
-- I'm not totally sure what's going on with this one
enemyTypes[11] = "Teton but maybe not???"
enemyTypes[13] = "Rolling red shell guys"
enemyTypes[19] = "Yellow springy guys"
enemyTypes[23] = "Pink shooty guy"



## Other flags etc.

cutscenes = {}
cutscenes[-2145386984] = "In cutscene"

states = {}
states[0] = "Neutral"
states[6] = "Holding enemy" 
states[1542] = "Flying" -- 0x606
states[101058088] = "Double jump" -- 0x6060628
states[438839593] = "Taking damage" -- 0x1A282929
states[1128481603] = "---" -- 0x43434343
