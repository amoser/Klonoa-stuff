# Klonoa-stuff

## Very Unfinished Klonoa Debug Tool

A Lua script meant to aid exploration of Klonoa: Door To Phantomile. 

**Note: "Very unfinished" is probably an understatement. It can definitely crash the game and just behave super unpredictably**

### Requirements

-US version of Klonoa: Door To Phantomile (I awould like to support all PSX versions, but I'm not sure how involved this would be; if anyone is able to test this on other versions, please let me know what results you get)

-Compatible PSX BIOS

-BizHawk emulator (tested on 2.4.2)

### Installing and Running

1. Click the green "code" button toward the top-right of this page
2. Choose "Download Zip"
3. Extract the files to some location
4. Start the game in BizHawk
5. Once the game is running, open the Lua console from the "Tools" menu
6. From within the Lua console, choose "Open Script..." from the "Script" menu
7. Navigate to where you extracted the files and select "Klonoa - Door to Phantomile (USA).lua"

### Quick Demo Video (youtube)

<!-- [![video](http://img.youtube.com/vi/nJsvJTR_D7s/0.jpg)](https://youtu.be/nJsvJTR_D7s "Klonoa tool quick demo") -->
[![video](https://i9.ytimg.com/vi/nJsvJTR_D7s/mq3.jpg?sqp=CJSFmPoF&rs=AOn4CLAlvQaYJ8kpMnGfZKRjt1idxReEHw)](https://youtu.be/nJsvJTR_D7s "Klonoa tool quick demo")


### Features

This tool has two main components: a window with options for easily manipulating various aspects of the game state, and an in-game display that displays additional information about the game state.

### In-game HUD

Enabling the in-game HUD displays various pieces of information. Currently this includes:

1. **Current vision number**
      
      Not super useful yet. Updates as soon as Klonoa is able to move when starting a vision. Could potentially be modified to create an auto-splitter for LiveSplit, or something.

2. **"Klonoa status"**

      This value tracks certain states, such as double jump, flying, etc. Some of the possible states are identified, but there are a lot of other status values that are currently not labeled. I have no idea why facing towards the camera has a unique value. It made me suspect that the status is actually be a two-byte (half word) value rather than a 4-byte, with the "facing forward" being part of a different variable, but the presence of clearly-intentional values that take up all four bytes (e.g. 0x43434343) seems to rule this out.

3. **"Counter status" (if non-zero)**

      A counter that the game uses for tracking certain temporary effects, e.g. invincibility frames after taking damage. Unlike the above "status" value, this _is_ a two-byte value; stored next to the "ledge physics" value. Not fully documented/understood.

4. **"Ledge physics" (if non-zero)**

      After stepping off a ledge, there is a five-frame window during which Klonoa's physics are different from usual. The most noticeable effect is that Klonoa is able to jump during this time despite not touching the ground. The value counts up from 0 to 5; if you see the value "5" remaining onscreen during a jump, this means you jumped on the last possible frame. This is also a two-byte value.

5. **"Plane pointer," "Plane segment," and "X on segment"**

      See "Level/Geometry" in the general notes below for an explanation of what these values represent. In addition to displaying raw values, a couple of special/moving "planes" (currently limited to 3-1 gondolas and 5-1 moving platforms) are explicitly labeled as well. There are additional "special" planes, but they're not documented yet.

6. **Internal values for lives, health, and dream stones**

      This is potentially useful for understanding situations in which the game fails to display these values properly in its on-screen HUD.

*TODO x position along entire path, not just segment?*

### Control window

![Control window](https://raw.githubusercontent.com/amoser/Klonoa-stuff/master/img/debugwindow.PNG)

**TODO actually document any of these features**

This window is used for changing various aspects of the game state, with the aim of making it easier to explore the game by doing things that are impossible in the original game.

**Note: click+drag functionality for moving Klonoa temporarily disables the kill timer for when Klonoa falls out of bounds, but _not_ the kill planes that are deliberately placed around a level. This means it's pretty easy to die instantly to a "fall" death when trying to move around in the air.**

Note that "locking" values currently works a bit differently than freezing memory the usual way in Bizhawk. Freezing memory prevents the value from changing at all, whereas "locking" resets the value once every frame. This means that the value _is_ possible to change as much as it wants within the span of a single frame. In most cases here, there doesn't seem to be a significant difference.

## General Klonoa Notes

The remainder of this readme is an attempt to document as much information about how the game functions as possible, both as it relates to debugging/hacking tools and as it is of general interest. It will never be complete (at least until it becomes detailed and accurate enough that someone could fully reconstruct something equivalent to the games original source code without having a copy of the game at all), but I'd like for it to be as accurate as possible. There are surely a lot of mistakes at the moment, so let me know if you find any!

### Level/Geometry

**TODO This section needs to be copy-edited for clarity/organization.**

Each room is broken up into multiple "planes," essentially paths that Klonoa can run along. In general, any situation in which Klonoa can choose between two or more different paths requires there to be at least two planes.

![Branching planes in 2-1](https://raw.githubusercontent.com/amoser/Klonoa-stuff/master/img/branching%20planes.png)

Above is a fairly straightforward example from Vision 1-2. Note that the upper plane continues across the gap.

Each plane itself is made up of several smaller segments. Each of these segments is perfectly straight (doesn't bend or curve), just like the polygonal segments of the planes represented as 3D geometry onscreen. 

In general, polygons that make up the path displayed onscreen correspond to plane segments. 

![Plane segments in 1-1](https://raw.githubusercontent.com/amoser/Klonoa-stuff/master/img/plane%20segments.png)

Above is a plane in 1-1 with each segment labeled. Interestingly, the split between segment 17 and 18 does _not_ fall on a polygon edge. In this case it appears that the segment transition might be used to trigger a change in camera angle, but in other cases segments are divided for seemingly no reason.

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

Certain "planes" are re-used for certain types of "special" terrain. For example, all of the gondolas in vision 3-1 share the same plane pointer. I'm not certain what the values located at this pointer are used for in the case of moving platforms, since the values don't change even when the platform is moving. Possibly they still represent an "initial" position of some kind.

It's also worth observing how the plane pointer changes (or does not change) while Klonoa is in the air. In fact, the behavior is not consistent; in some situations, simply moving _above_ some geometry causes the pointer to change immediately. In others, the pointer does not update until Klonoa actually lands on a new plane.

**TODO Video example**

*TODO Confirmation/video showing that this accounts for the weird behavior when moving directly from a gondola to a crate; landing on the crate might position Klonoa relative to the plane he is "on," which would fall apart if he's not "on" the plane directly under the box.*

NOTE: There is a discrepency between how BizHawk represents memory addresses and how pointers are stored within the game's memory: BizHawk omits the first two digits '80' for addresses in the main RAM, since it is redundant (ALL main RAM is mapped to addresses beginning with 80). But BizHawk WON'T omit the 80 for pointers (memory addresses) stored within the games memory itself, because it has no way of knowing whether a given number actually reprsents a memory address or just a number that happens to start with '80'.
This simply means that if you find a pointer in memory like "801757D0" and want to see what's located there using BizHawk, you'll want to search for "1757D0" instead.



### Enemies

The tool doesn't have any functionslity related to enemies yet. That said, the following (incomplete) list describes how the enemy types are enumerated in memory. 

If you are tremendously bored, you can usually do a RAM search for numbers corresponding to some enemies that you see on screen. Once you find an enemy, if you change its type to a different number on this list and break the enemy, it will often respawn as the new type. Or crash the game. Often both, in fact.

**TODO Video example of changing flying moo in 1-1**

0/1 = Moo

3 = Zippoe

5 = Enemy spawn portal (???)

7 = Flying moo

11 = Teton

13 = Shellie

19 = Shielded Moo (springboard)

23 = Dabbie

#### Regarding enemy spawn portal

It's already a bit weird that internally this actually functions almost exactly like an enemy. The game notably has very few enemy spawn portals at the beginning, with enemies instead appearing from ofscreen or behind scenery. I'm guessing this was how it was originally supposed to be the case for _all_ enemies, but it was probably too restrictive, with the enemy spawn portal being added as an easier alternative. That would explain why it's in the middle of the list rather than the beginning/end.

### Other flags etc.

**TODO**

cutscenes = {}
cutscenes[-2145386984] = "In cutscene"
