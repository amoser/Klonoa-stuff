visionAddr = 0x1FFDB0

klonoaStateAddr = 0x10B910
klonoaXAddr = 0x0BF020
klonoaYAddr = 0x10674C
		
livesAddr = 0x10E5CA
healthAddr = 0x10E5D0
stonesAddr = 0x10E5CC

cameraAddr1 = 0x10F6C0
cameraAddr2 = 0x10F6B8

iFramesAddr = 0x0BF074
fallDeathTimeAddr = 0x0BEB3C

-- Tables for interpreting various raw memory values

vision = {}
vision[0] = "1-1"
vision[1] = "1-2" 
vision[2] = "Rongo Lango"
vision[3] = "2-1"
vision[4] = "2-2"
vision[5] = "Pamela"
vision[6] = "3-1"
vision[7] = "3-2"
vision[8] = "Gelg Bolm"
vision[9] = "4-2"
vision[10] = "4-3"
vision[11] = "Baladium"
vision[12] = "5-1"
vision[13] = "5-2"
vision[14] = "Joka"
vision[15] = "6-1"
vision[16] = "6-2"
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

split = "Waiting to start..."
klonoaState = states[0]

klonoaY = -1
klonoaX = -1
lastKlonoaY = -1
lastKlonoaX = -1
frozenPosition = false

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
draggedLives = 0

stones = 3
frozenStones = false
stonesChanged = false

iFrames = 0

lastInput = input.get()
lastMouseX = input.getmouse()["X"]
lastMouseY = input.getmouse()["Y"]
mouseX = input.getmouse()["X"]
mouseY = input.getmouse()["Y"]
dragging = false
dragStartX = mouseX
dragStartY = mouseY

manualCam = false



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



-- UI

forms.destroyall()

mainWindow = forms.newform(650, 515, "Very Unfinished Klonoa Debug Tool")

manualCamCheckbox = forms.checkbox(mainWindow, "Manual Camera", 0, 0)

freezePositionCheckbox = forms.checkbox(mainWindow, "Freeze Position", 0, 30)

-- TODO enemy scan button
trackEnemiesCheckbox = forms.checkbox(mainWindow, "Track Enemies", 0, 30)

-- TODO implement real freezing instead of only resetting between frames
healthDropdown = forms.dropdown(mainWindow, {"1", "2", "3", "4", "5", "6"}, 60, 60, 30, 10)
healthButton = forms.button(mainWindow, "Apply Health", function() return setHealth(tonumber(forms.gettext(healthDropdown))) end, 90, 60, 90, 20)
healthFreezeCheckbox = forms.checkbox(mainWindow, "Freeze Health", 190, 60)
healthLabel = forms.label(mainWindow, "Health: ", 0, 60, 60, 20)

livesTextbox = forms.textbox(mainWindow, "3", 20, 20, "", 60, 90)
livesButton = forms.button(mainWindow, "Apply Lives", function() return setLives(tonumber(forms.gettext(livesTextbox))) end, 80, 90, 100, 20)
livesFreezeCheckbox = forms.checkbox(mainWindow, "Freeze Lives", 190, 90)
livesLabel = forms.label(mainWindow, "Lives: ", 0, 90, 60, 20)

stonesTextbox = forms.textbox(mainWindow, "3", 20, 20, "", 60, 120)
stonesButton = forms.button(mainWindow, "Apply Stones", function() return setStones(tonumber(forms.gettext(stonesTextbox))) end, 80, 120, 100, 20)
stonesFreezeCheckbox = forms.checkbox(mainWindow, "Freeze Stones", 190, 120)
stonesLabel = forms.label(mainWindow, "Stones: ", 0, 120, 60, 20)

customAddressTextbox = forms.textbox(mainWindow, "custom", 100, 20, "", 60, 150)

bgCanvas = forms.pictureBox(mainWindow, 0, 0, 640, 480)
forms.drawImage(bgCanvas, "img/uibg2.png", 0, 0, 640, 480)

displayStatus = forms.pictureBox(bgCanvas, 0, 0, 640, 480)

--forms.setDefaultBackgroundColor(displayStatus, "gray")
forms.setDefaultTextBackground(displayStatus, "transparent")
forms.setDefaultForegroundColor(displayStatus, 0xFF380000)
defaultTextColor = 0xFF380000



-- Main logic

while true do
	-- forms.clear(displayStatus, 0xFFF8E8A8)
	forms.clear(displayStatus, "transparent")
	--forms.clear(bgCanvas, 0xFFF8E8A8)
	forms.drawImage(bgCanvas, "img/uibg2.png", 0, 0)
	
	-- TODO display address, values for current plane segment
	
	--"NOTE: clicking the '?' button will make my comments/explanation appear in the Lua Console's \"output\" pane. Info may be incomplete or incorrect."
	-- TODO check if dynamically allocated addresses only change between visions (e.g. when memory is reset/loaded from disc)
	-- TODO lives/stones glitch seems to be related to playing the animation

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
	else
		split = "UKNOWN VALUE (" .. visionCounter .. ")"
	end
	
	-- Camera
	--cam1 = memory.read_s32_le(klonoaYAddr)
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
		klonoaState = "UKNOWN VALUE (" .. klonoaInternalState .. ")"
	end
	
	local cutsceneState = ""
	if not (cutscenes[tonumber(visionCounter)] == nil) then
		cutsceneState = "In cutscene."
	elseif tonumber(visionCounter) > 16 or tonumber(visionCounter) < 0 then
		cutsceneState = "In cutscene? " .. tonumber(visionCounter)
	end
		
	iFrames = memory.read_s32_le(iFramesAddr)
	
	-- Handle keyboard toggle for override camera control
	local currentInput = input.get()

	manualCam = forms.ischecked(manualCamCheckbox)
	frozenHealth = forms.ischecked(healthFreezeCheckbox)
	frozenLives = forms.ischecked(livesFreezeCheckbox)
	frozenStones = forms.ischecked(stonesFreezeCheckbox)
	frozenPosition = forms.ischecked(freezePositionCheckbox)
	lastInput = currentInput

	-- Handle keyboard camera manipulation when overriden
	-- if input.get()["E"] == true then
		-- cam1 = cam1 - 50000
	-- end

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
		forms.drawText(displayStatus, 0, 180, "MANUAL CAMERA CONTROL ON (Incomplete! Be careful.)", "red", null, 24, "Times New Roman", "bold")
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
		memory.write_s32_le(livesAddr, lives + draggedLives)
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
	
	
	-- Display camera info
	--forms.drawText(displayStatus, 0, 180, "Cam 1: " .. cam1, "red")
	forms.drawText(displayStatus, 0, 200, "Cam 2: " .. cam2, "green", null, 24, "Times New Roman", "bold")
	forms.drawText(displayStatus, 0, 220, "Cam 3: " .. cam3, "blue", null, 24, "Times New Roman", "bold")
	--forms.drawAxis(displayStatus, 100, 400, 20) 
	
	-- Display split info
	forms.drawText(displayStatus, 0, 300, "Vision: " .. split, defaultTextColor, null, 24, "Times New Roman", "bold")
	--forms.drawText(displayStatus, 0, 320, "(internal vision counter value: " .. visionCounter .. ")", "white")
	
	-- Mouse interactivity
	if input.getmouse()["Left"] then
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
	else
		if dragging then
			-- Apply change in lives from dragging
			--lives = lives + draggedLives
			draggedLives = 0
			dragging = false
			dragDeltaX = 0
			dragDeltaY = 0
			--livesChanged = true
		end
	end	
	if input.getmouse()["Right"] then
		-- Overwrite camera
		cam2 = lastCam2 + mouseDeltaX*50000
		cam3 = lastCam3 + mouseDeltaY*50000
		
		memory.write_s32_le(cameraAddr1, cam2)
		memory.write_s32_le(cameraAddr2, cam3)
		
		-- Disable timer for fall death
		memory.write_s32_le(fallDeathTimeAddr, 0)
	end
	--if dragDeltaY > 20 then
	--	draggedLives = dragDeltaY/20
	--end
	
	lastMouseX = input.getmouse()["X"]
	lastMouseY = input.getmouse()["Y"]
	lastKlonoaX = klonoaX
	lastKlonoaY = klonoaY
	
	--lastCam1 = cam1
	lastCam2 = cam2
	lastCam3 = cam3
	
	-- Display Klonoa info
	forms.drawText(displayStatus, 0, 360, "Klonoa status: " .. klonoaState, 0x66380000, null, 24, "Times New Roman", "bold")
	forms.drawText(displayStatus, 0, 360, "Klonoa status: " .. klonoaState, defaultTextColor, null, 24, "Times New Roman", "bold")

	if tonumber(iFrames) > 0 then
		forms.drawText(displayStatus, 0, 380, "Invincibility frames: " .. iFrames, "red")
	end
	forms.drawText(displayStatus, 0, 440, cutsceneState, defaultTextColor, null, 24, "Times New Roman")
	forms.refresh(displayStatus)
	--forms.refresh(bgCanvas)
end
