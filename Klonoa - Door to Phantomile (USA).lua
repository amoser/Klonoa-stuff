-- TODO
-- Add explanation of click+drag to readme

-- Figure out plane structure
-- --Use onmemoryread to see when we hit certain sections

-- Locate enemies (and find onscreen position after GTE transformation)
-- Figure out models (recalling that setting '7's to other values appeard to modify seventh vertex)

-- 0x800BE670 == KAKE?

-- 801e0c04


-- Const locations of various game-relevant information

visionAddr = 0x1FFDB0

klonoaStateAddr = 0x10B910
klonoaXAddr = 0x0BF020
klonoaYAddr = 0x10674C
		
livesAddr = 0x10E5CA
healthAddr = 0x10E5D0
stonesAddr = 0x10E5CC

-- These are both two bytes each
iFramesAddr = 0x0BF074
ledgePhysicsAddr = 0x0BF076

-- These aren't really sufficient as the "camera" position is affected by many other things as well
-- One example is that they don't have any effect on fixed camera angles used when klonoa is near doors
cameraAddr1 = 0x10F6C0
cameraAddr2 = 0x10F6B8

fallDeathTimeAddr = 0x0BEB3C

planeXposAddr = 0x0BF020
planePtrAddr = 0x0BF024
planeSegmentAddr = 0x0BF028



-- Tables for interpreting various raw memory values

vision = {}
vision[0] = "Vision 1-1"
vision[1] = "Vision 1-2" 
vision[2] = "Rongo Lango"
vision[3] = "Vision 2-1"
vision[4] = "Vision 2-2"
vision[5] = "Pamela"
vision[6] = "Vision 3-1"
vision[7] = "Vision 3-2"
vision[8] = "Gelg Bolm"
vision[9] = "Vision 4-2"
vision[10] = "Vision 4-3"
vision[11] = "Baladium"
vision[12] = "Vision 5-1"
vision[13] = "Vision 5-2"
vision[14] = "Joka"
vision[15] = "Vision 6-1"
vision[16] = "Vision 6-2"
vision[17] = "Nahatomb"

cutscenes = {}
cutscenes[-2145386984] = "In cutscene"

states = {}
states[0] = "Neutral"
states[6] = "Holding enemy" 
states[1542] = "Flying" -- 0x606
states[101058088] = "Double jump" -- 0x6060628
states[438839593] = "Taking damage" -- 0x1A282929
states[1128481603] = "---" -- 0x43434343

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

planes = {}
planes[0x801757d0] = "3-1 Gondola"
planes[0x801705b8] = "5-1 Moving Platform type 1"
planes[0x80172330] = "5-1 Moving Platform type 2"
planes[0x80173838] = "5-1 Moving Platform type 3"


split = "Waiting to start..."
klonoaState = states[0]



-- Variables for storing/interacting with game state, along with user-controlled info specific to this tool

-- Holds previous instruction executed so it can be logged/displayed when state changes
instructionPointer = -1

-- Klonoa position
-- Note: X value is relative to current plane segment
klonoaY = -1
klonoaX = -1
lastKlonoaY = -1
lastKlonoaX = -1
frozenPosition = false

-- Camera "position"
-- Note: Not complete at all!
cam1 = 0
cam2 = 0
cam3 = 0
lastCam1 = 0
lastCam2 = 0
lastCam3 = 0

health = 6
frozenHealth = false
healthChanged = false

lives = 3
frozenLives = false
livesChanged = false

stones = 0
frozenStones = false
stonesChanged = false

iFrames = 0
ledgePhysics = 0

planePtr = 0
planeSegment = 0

lastInput = input.get()
lastMouseX = input.getmouse()["X"]
lastMouseY = input.getmouse()["Y"]
mouseX = input.getmouse()["X"]
mouseY = input.getmouse()["Y"]
dragging = false
dragStartX = mouseX
dragStartY = mouseY

manualCam = false

inGameHUD = false

invincible = false

noKillPlanes = false



-- Utility functions

function setLives(newLives)
	lives = newLives
	livesChanged = true
end

function setHealth(newHealth)
	health = newHealth
	healthChanged = true
end

function setStones(newStones)
	stones = newStones
	stonesChanged = true
end

function readValuesFromMemory()
	-- Instruction pointer
	instructionPointer = string.format("%x", emu.getregister("pc"))
	
	-- Splits
	-- "visionCounter" contains the game's current Vision (more or less...)
	-- Notes:
	-- -equals 0 during "boss transition"/loading screen.
	-- -stores other info during cutscenes etc. (appears as large or negative)
	-- -first updates to "correct" value when player gains control of Klonoa
	local visionCounter = memory.read_s32_le(visionAddr)	
	-- TODO given above, need to detect when screen fades to black between visions to get correct splits
	if not (vision[tonumber(visionCounter)] == nil) then
		split = vision[tonumber(visionCounter)]
	-- else
		-- split = "UNKNOWN VALUE (" .. visionCounter .. ")"
	end
	
	-- Camera
	cam2 = memory.read_s32_le(cameraAddr1)
	cam3 = memory.read_s32_le(cameraAddr2)
	
	-- Klonoa position
	klonoaX = memory.read_s32_le(klonoaXAddr)
	klonoaY = memory.read_s32_le(klonoaYAddr)
	
	-- Klonoa state
	-- Notes:
	-- State 1128481603 ("---") == Dead, out-of-game menu, etc.
	-- Dying goes through some several values but I don't know what they mean;
	-- Those are displayed as "UNKNOWN"
	-- State is preserved during in-game pause menu
	-- Works during automatic demo gameplay (waiting too long on title screen)
	local klonoaInternalState = memory.read_s32_le(klonoaStateAddr)
	if not (states[tonumber(klonoaInternalState)] == nil) then
		klonoaState = states[tonumber(klonoaInternalState)]
	else
		klonoaState = "UNKNOWN VALUE (" .. klonoaInternalState .. ")"
	end
	
	local cutsceneState = ""
	if not (cutscenes[tonumber(visionCounter)] == nil) then
		cutsceneState = "In cutscene."
	elseif tonumber(visionCounter) > 16 or tonumber(visionCounter) < 0 then
		cutsceneState = "In cutscene? " .. tonumber(visionCounter)
	end
		
	iFrames = memory.read_s16_le(iFramesAddr)
	ledgePhysics = memory.read_s16_le(ledgePhysicsAddr)

	planePtr = memory.read_u32_le(planePtrAddr)
	planeSegment = memory.read_s16_le(planeSegmentAddr)
	planeX = memory.read_s32_le(planeXposAddr)
	
	stones = memory.read_s16_le(stonesAddr)
	lives = memory.read_s16_le(livesAddr)
	health = memory.read_s32_le(healthAddr)
end



-- UI

forms.destroyall()

mainWindow = forms.newform(650, 515, "Very Unfinished Klonoa Debug Tool")

-- Global offsets to make it easier to "stack" UI elements relative to each other
controlPosX = 60
controlPosY = 40

-- Note: dropdown options get sorted alphabetically regardless of what order they're listed in, hence the inclusion of useless numbers for the options
mouseDropdown = forms.dropdown(mainWindow, {"---------- Click+Drag Action ----------", "0. Do nothing", "1. Move Klonoa (buggy)", "2. Adjust Camera (buggy/incompete)"}, controlPosX, controlPosY, 180, 10)
controlPosX = controlPosX + 190
manualCamCheckbox = forms.checkbox(mainWindow, "Lock Camera", controlPosX, controlPosY)
controlPosX = controlPosX + 110
LockPositionCheckbox = forms.checkbox(mainWindow, "Lock Position", controlPosX, controlPosY)

controlPosX = 0
controlPosY = controlPosY + 40

-- TODO enemy scan button
--trackEnemiesCheckbox = forms.checkbox(mainWindow, "Track Enemies", 0, 30)

-- TODO implement real freezing where appropriate instead of only resetting between frames
healthDropdown = forms.dropdown(mainWindow, {"1", "2", "3", "4", "5", "6"}, 120, controlPosY, 30, 10)
healthButton = forms.button(mainWindow, "Apply Health", function() return setHealth(tonumber(forms.gettext(healthDropdown))) end, 150, controlPosY, 90, 20)
-- healthLockCheckbox = forms.pictureBox(mainWindow, 250, controlPosY, 25, 25)
-- forms.drawText(healthLockCheckbox, 0, 0, "######")
-- forms.drawText(healthLockCheckbox, 0, 0, "######", "red", null, 12, "Times New Roman", hudFontStyle)
healthLockCheckbox = forms.checkbox(mainWindow, "Lock Health", 250, controlPosY)

controlPosX = 0
controlPosY = controlPosY + 30

livesTextbox = forms.textbox(mainWindow, "3", 20, 20, "", 120, controlPosY)
livesButton = forms.button(mainWindow, "Apply Lives", function() return setLives(tonumber(forms.gettext(livesTextbox))) end, 140, controlPosY, 100, 20)
-- livesLockCheckbox = forms.pictureBox(mainWindow, 250, controlPosY, 25, 25)
livesLockCheckbox = forms.checkbox(mainWindow, "Lock Lives", 250, controlPosY)

controlPosX = 0
controlPosY = controlPosY + 30

stonesTextbox = forms.textbox(mainWindow, "3", 20, 20, "", 120, controlPosY)
stonesButton = forms.button(mainWindow, "Apply Stones", function() return setStones(tonumber(forms.gettext(stonesTextbox))) end, 140, controlPosY, 100, 20)
-- stonesLockCheckbox = forms.pictureBox(mainWindow, 250, controlPosY, 25, 25)
stonesLockCheckbox = forms.checkbox(mainWindow, "Lock Stones", 250, controlPosY)

controlPosY = controlPosY + 30
controlPosX = controlPosX

rescuedDropdown = forms.dropdown(mainWindow, {"0", "1", "2", "3", "4", "5", "6"}, 120, controlPosY, 30, 10)
rescuedButton = forms.button(mainWindow, "Apply Rescued", function() return setHealth(tonumber(forms.gettext(healthDropdown))) end, 150, controlPosY, 90, 20)

controlPosY = controlPosY + 40
controlPosX = controlPosX

planeTextbox = forms.textbox(mainWindow, "3", 20, 20, "", 120, controlPosY)
planeButton  = forms.button(mainWindow, "Set Plane Pointer", function() return setHealth(tonumber(forms.gettext(healthDropdown))) end, 150, controlPosY, 90, 20)
planeCheckbox = forms.checkbox(mainWindow, "Lock Plane", 250, controlPosY)

controlPosY = controlPosY + 30
controlPosX = controlPosX

invincibleCheckbox = forms.checkbox(mainWindow, "Invincible", 60, controlPosY)

controlPosY = controlPosY + 40
controlPosX = controlPosX

-- killPlanesCheckbox = forms.checkbox(mainWindow, "No Kill Planes", 60, controlPosY)

-- controlPosY = controlPosY + 30
-- controlPosX = controlPosX

-- TODO is there really no way to have this checked by default in Bizhawk's "forms" system?
-- hudCheckbox = forms.pictureBox(mainWindow, 250, controlPosY, 25, 25)
hudCheckbox = forms.checkbox(mainWindow, "In-game HUD", 60, controlPosY)

controlPosY = controlPosY + 30
controlPosX = controlPosX

-- hudCheckbox = forms.pictureBox(mainWindow, 250, controlPosY, 25, 25)
consoleLoggingCheckbox = forms.checkbox(mainWindow, "Console logging", 60, controlPosY)

controlPosY = controlPosY + 30
controlPosX = controlPosX

--customAddressTextbox = forms.textbox(mainWindow, "custom", 100, 20, "", 60, 150)

bgCanvas = forms.pictureBox(mainWindow, 0, 0, 640, 480)
forms.drawImage(bgCanvas, "img/uibg2.png", 0, 0, 640, 480)

displayStatus = forms.pictureBox(mainWindow, 0, 0, 640, 480)

--forms.setDefaultBackgroundColor(displayStatus, "gray")
forms.setDefaultTextBackground(displayStatus, "transparent")
-- forms.setDefaultTextBackground(displayStatus, 0xFFF8E8A8)
forms.setDefaultForegroundColor(displayStatus, 0xFF380000)
defaultBGColor = 0xFFF8E8A8
defaultTextColor = 0xBBFFFFFF
-- defaultTextColor = 0xFF380000



-- Callbacks

function wroteVision()
	readValuesFromMemory()
	console.log("Current vision set to " .. split .. " by instruction at " .. instructionPointer)
end

function wroteStones()
	readValuesFromMemory()
	console.log("Dream stones set to " .. stones .. " by instruction at " .. instructionPointer)
end

function wroteHealth()
	readValuesFromMemory()
	console.log("Health set to " .. health .. " by instruction at " .. instructionPointer)
end

function wroteLives()
	readValuesFromMemory()
	console.log("Lives set to " .. lives .. " by instruction at " .. instructionPointer)
end

function wrotePlane()
	readValuesFromMemory()
	console.log("Active plane set to " .. planePtr .. " by instruction at " .. instructionPointer)
end

function wrotePlaneSegment()
	readValuesFromMemory()
	console.log("Current plane segment set to " .. planeSegment .. " by instruction at " .. instructionPointer)
end

function wroteStatus1()
	readValuesFromMemory()
	console.log("Klonoa status set to " .. klonoaState .. " by instruction at " .. instructionPointer)
end

function wroteLedgePhysics()
	readValuesFromMemory()
	console.log("Ledge physics enabled by instruction at " .. instructionPointer)
end

function iFrames()
	readValuesFromMemory()
	console.log("Invincibility frames set to " .. " by instruction at " .. instructionPointer)
end

-- function readHealth()
  -- console.log("Read health value.")
-- end

visionCallback = -1
stonesCallback = -1
planeCallback = -1
planeSegmentCallback = -1
livesCallback = -1
healthCallback = -1

callBacksEnabled = false

function registerCallbacks()
	-- I'm not sure why Bizhawk insists on the 0x80000000 prefix for these callbacks but nowhere else, but it's kind of annoying; be careful of this if you're making changes to the script
	stonesCallback = event.onmemorywrite(wroteStones, 0x80000000 + stonesAddr)
	planeCallback = event.onmemorywrite(wrotePlane, 0x80000000 + planePtrAddr)
	livesCallback = event.onmemorywrite(wroteLives, 0x80000000 + livesAddr)
	-- healthCallback = event.onmemorywrite(wroteHealth, 0x80000000 + healthAddr)
	planeSegmentCallback = event.onmemorywrite(wrotePlaneSegment, 0x80000000 + planeSegmentAddr)
	callBacksEnabled = true
end

function unregisterCallbacks()
	-- I'm not sure why Bizhawk insists on the 0x80000000 prefix for these callbacks but nowhere else, but it's kind of annoying; be careful of this if you're making changes to the script
	event.unregisterbyid(stonesCallback)
	event.unregisterbyid(planeCallback)
	event.unregisterbyid(livesCallback)
	-- event.unregisterbyid(healthCallback)
	event.unregisterbyid(planeSegmentCallback)
	callBacksEnabled = false
end

-- TODO a lot of these values get "changed" to the same value repeatedly; "onmemorywrite" is probably not ideal in this case
-- event.onmemorywrite(wroteVision, 0x80000000 + visionAddr)
-- event.onmemorywrite(wroteStatus1, 0x80000000 + klonoaStateAddr)
-- event.onmemorywrite(wroteStones, 0x80000000 + stonesAddr)
-- event.onmemorywrite(wroteStones, 0x80000000 + stonesAddr)
-- TODO callback for when vertices of current plane segment move



-- Main logic

while true do
	readValuesFromMemory()
	
	-- Handle keyboard toggle for override camera control
	local currentInput = input.get()

	manualCam = forms.ischecked(manualCamCheckbox)
	frozenHealth = forms.ischecked(healthLockCheckbox)
	frozenLives = forms.ischecked(livesLockCheckbox)
	frozenStones = forms.ischecked(stonesLockCheckbox)
	frozenPosition = forms.ischecked(LockPositionCheckbox)
	invincible = forms.ischecked(invincibleCheckbox)
	-- noKillPlanes = forms.ischecked(killPlanesCheckbox)
	inGameHUD = forms.ischecked(hudCheckbox)
	
	if forms.ischecked(consoleLoggingCheckbox) and not callBacksEnabled then
		registerCallbacks()
	elseif not forms.ischecked(consoleLoggingCheckbox) and callBacksEnabled then
		unregisterCallbacks()
	end
	
	lastInput = currentInput

	emu.frameadvance();
	
	-- Get mouse movement
	mouseX = input.getmouse()["X"]
	mouseY = input.getmouse()["Y"]
	mouseDeltaX = mouseX - lastMouseX
	mouseDeltaY = mouseY - lastMouseY	
	dragDeltaX = mouseX - dragStartX
	dragDeltaY = mouseY - dragStartY
	
	-- Overwrite game's camera memory
	if manualCam then
		-- gui.drawText(40, 180, "MANUAL CAMERA CONTROL ON (Incomplete! Be careful.)", "red", null, 12, "Times New Roman", hudFontStyle)
		--memory.write_s32_le(klonoaYAddr, cam1)
		memory.write_s32_le(cameraAddr1, lastCam2)
		memory.write_s32_le(cameraAddr2, lastCam3)
	end
	
	-- Overwrite Klonoa position
	if frozenPosition then
		memory.write_s32_le(klonoaXAddr, lastKlonoaX)
		memory.write_s32_le(klonoaYAddr, lastKlonoaY)
		
		-- Disable timer for fall death
		memory.write_s32_le(fallDeathTimeAddr, 0)
	end
		
	-- Overwrite life counter
	if frozenLives or livesChanged then
		memory.write_s32_le(livesAddr, lives)
		livesChanged = false
	end
	
	-- Overwrite health counter
	if frozenHealth or healthChanged then
		health = tonumber(forms.gettext(healthDropdown))
		memory.write_s32_le(healthAddr, health)
		healthChanged = false
	end

	-- Overwrite stones counter
	if frozenStones or stonesChanged then
		memory.write_s32_le(stonesAddr, stones)
		stonesChanged = false
	end
	
	-- Invincibility by overwriting iFrames counter
	if invincible then
		memory.write_s16_le(iFramesAddr, 1)
		stonesChanged = false
	end
		
	-- Mouse interactivity
	if input.getmouse()["Left"] and forms.gettext(mouseDropdown) == "1. Move Klonoa (buggy)" then
		klonoaX = lastKlonoaX + mouseDeltaX*50000
		klonoaY = lastKlonoaY + mouseDeltaY*50000
		
		memory.write_s32_le(klonoaXAddr, klonoaX)
		memory.write_s32_le(klonoaYAddr, klonoaY)
		
		-- Disable timer for fall death
		memory.write_s32_le(fallDeathTimeAddr, 0)

		-- Initiated click and drag
		if not dragging then
			dragStartX = mouseX
			dragStartY = mouseY
			dragging = true
		end
	end	
	if input.getmouse()["Left"] and forms.gettext(mouseDropdown) == "2. Adjust Camera (buggy/incompete)" then
		-- Overwrite camera
		cam2 = lastCam2 + mouseDeltaX*50000
		cam3 = lastCam3 + mouseDeltaY*50000
		
		memory.write_s32_le(cameraAddr1, cam2)
		memory.write_s32_le(cameraAddr2, cam3)
		
		-- Disable timer for fall death
		memory.write_s32_le(fallDeathTimeAddr, 0)
	end

	-- Save values to use for next frame in "locked" mode
	lastMouseX = input.getmouse()["X"]
	lastMouseY = input.getmouse()["Y"]
	lastKlonoaX = klonoaX
	lastKlonoaY = klonoaY
	
	lastCam2 = cam2
	lastCam3 = cam3
	
	
	-- HUD
	if inGameHUD then
		hudFontSize = 11
		hudFontStyle = "bold"
		
		if lives < 10 then
			hudX = 78
		else
			hudX = 74
		end
		hudY = 187
		
		-- Display Lives
		gui.drawText(hudX, hudY, lives, defaultTextColor, null, hudFontSize, "Times New Roman", hudFontStyle)

		hudX = 165
		
		-- Display Health
		gui.drawText(hudX, hudY, health, defaultTextColor, null, hudFontSize, "Times New Roman", hudFontStyle)
		
		if stones < 10 then
			hudX = 302
		else
			hudX = 298
		end
		
		-- Display Stones
		gui.drawText(hudX, hudY, stones, defaultTextColor, null, hudFontSize, "Times New Roman", hudFontStyle)

		hudFontStyle = "regular"

		hudY = 3
		hudX = 17
		
		-- Display split info
		gui.drawText(hudX, hudY, split, defaultTextColor, null, hudFontSize, "Times New Roman", hudFontStyle)
		
		hudY = hudY + hudFontSize - 1
		
		-- Display Klonoa info
		gui.drawText(hudX, hudY, "Klonoa status: " .. klonoaState, defaultTextColor, null, hudFontSize, "Times New Roman", hudFontStyle)
		
		hudY = hudY + hudFontSize + 2

		if tonumber(iFrames) > 0 then
			gui.drawText(hudX, hudY, "Counter status: " .. iFrames, "red", null, hudFontSize, "Times New Roman", hudFontStyle)
		end
		
		hudY = hudY + hudFontSize - 1
		
		if tonumber(ledgePhysics) > 0 then
			gui.drawText(hudX, hudY, "Ledge physics frames: " .. ledgePhysics, "green", null, hudFontSize, "Times New Roman", hudFontStyle)
		end
		
		hudY = hudY + hudFontSize + 2
		
		-- Note: broken into two drawTexts to avoid distracting twitchy font kerning as numbers change
		hudFontStyle = "regular"
		gui.drawText(hudX, hudY, "Plane pointer: ", defaultTextColor, null, hudFontSize, "Times New Roman", hudFontStyle)
		hudFontStyle = "bold"
		
		planeText = string.format("%x", planePtr)
		
		if not (planes[tonumber(planePtr)] == nil) then
			gui.drawText(hudX + 75, hudY, planeText .. " (" .. planes[tonumber(planePtr)] .. ")", defaultTextColor, null, hudFontSize, "Times New Roman", hudFontStyle)
		else
			gui.drawText(hudX + 75, hudY, planeText, defaultTextColor, null, hudFontSize, "Times New Roman", hudFontStyle)
		end
		
		hudY = hudY + hudFontSize - 1
		
		hudFontStyle = "regular"
		gui.drawText(hudX, hudY, "Plane segment: ", defaultTextColor, null, hudFontSize, "Times New Roman", hudFontStyle)
		hudFontStyle = "bold"
		gui.drawText(hudX + 75, hudY, planeSegment, defaultTextColor, null, hudFontSize, "Times New Roman", hudFontStyle)
		
		hudY = hudY + hudFontSize - 1
		
		hudFontStyle = "regular"
		gui.drawText(hudX, hudY, "X on segment: ", defaultTextColor, null, hudFontSize, "Times New Roman", hudFontStyle)
		hudFontStyle = "bold"
		gui.drawText(hudX + 75, hudY, planeX, defaultTextColor, null, hudFontSize, "Times New Roman", hudFontStyle)
		
		hudY = hudY + hudFontSize - 1
		
		gui.drawText(hudX, hudY, cutsceneState, defaultTextColor, null, hudFontSize, "Times New Roman", hudFontStyle)
		
		hudY = hudY + hudFontSize - 1
		
		--forms.refresh(displayStatus)
		--forms.refresh(bgCanvas)
		
		-- Fake clear
		--gui.drawText(hudX, hudY, "Klonoa status: " .. klonoaState, defaultBGColor, null, hudFontSize, "Times New Roman", hudFontStyle)
	end
end

