-- luacheck: globals love love.graphics love.physics love.window love.mouse
-- Spell Collector - Main Game File

-- Import modules
local Render = require("render")
local Spellbook = require("spellbook")

local world
local player = {}
local walls = {}
local staticBoxes = {} -- Array to store static boxes
local staticTriangles = {} -- Array to store static triangles
local scrolls = {} -- Array to store scrolls
local portals = {} -- Array to store portals
local currentLevel = nil -- Current level data
local currentLevelName = "level1" -- Track current level name
local worldMapOpen = false -- World map overlay state
local completedLevels = {} -- Track which levels have been completed (scroll collected)
local portalCooldown = 0 -- Cooldown to prevent spam when touching portals

-- Levels configuration - easy to expand by adding new entries
local levelsConfig = {
	{
		id = "level1",
		name = "Home Sweet Home",
		displayName = "Home",
		filename = "level1.dat",
		position = {x = 0.2, y = 0.5}, -- Relative position on world map (0-1)
		unlocked = true -- Always unlocked
	},
	{
		id = "level2", 
		name = "Balcony",
		displayName = "Balcony",
		filename = "level2.dat",
		position = {x = 0.5, y = 0.5}, -- Relative position on world map (0-1)
		unlocked = true -- Unlocked by completing level1
	},
	{
		id = "level4",
		name = "Forest",
		displayName = "Forest",
		filename = "level4.dat",
		position = {x = 0.8, y = 0.5},
		unlocked = true
	},
	{
		id = "level_end",
		name = "Game Complete", 
		displayName = "Complete!",
		filename = "level_end.dat",
		position = {x = 0.5, y = 0.8},
		unlocked = true
	}
	-- Add new levels here easily:
	-- {
	--     id = "level4",
	--     name = "Sky Palace", 
	--     displayName = "lvl 4",
	--     filename = "level4.dat",
	--     position = {x = 0.5, y = 0.8},
	--     unlocked = false -- Will be unlocked when level3 is completed
	-- }
}
local font
local wizardImage
local wizardCastingImage
local wizardGreenImage
local wizardGreenCastingImage
local backgroundImage
local foregroundImages = {} -- Array to store foreground images with suffixes
local scrollImage
local portalImage
local spellbookImage
local buttonLeftImage
local buttonRightImage
local spellImages = {} -- Dictionary to store loaded spell images
local grimoireFont, spellTitleFont, spellDescFont

local gravityPixelsPerSecond2 = 900 -- positive Y is down in LOVE
local moveForce = 2000 -- force applied by A/D keys
local levitateForce = 5000 -- upward force applied by W key
local linearDamping = 0.5
local angularDamping = 0
local playerWidth = 50
local playerHeight = 75
local isOnGround = false
local groundCheckDistance = 50 -- pixels below box to check for ground
local raycastResult = nil

local raycastCallback = function(fixture, x, y, xn, yn, fraction)
	local body = fixture:getBody()
	local bodyType = body:getType()
	
	-- Check if the fixture belongs to a static body (ground or static box)
	if bodyType == "static" then
		-- Store the closest fraction found (0 = closest to ray start)
		if raycastResult == nil or fraction < raycastResult then
			raycastResult = fraction
		end
	end
	
	-- Continue raycast to find the closest hit
	return -1
end

local startX, startY = 0, 0 -- will be set in love.load()
local maxHorizontalSpeed = 400 -- maximum horizontal speed in pixels per second

-- Function to load all spell images
local function loadSpellImages()
	spellImages = {}
	local imageList = Spellbook.getSpellImages()
	for imagePath, _ in pairs(imageList) do
		local success, image = pcall(function()
			return love.graphics.newImage("gfx/" .. imagePath)
		end)
		if success then
			spellImages[imagePath] = image
			print("Loaded spell image: " .. imagePath)
		else
			print("Failed to load spell image: " .. imagePath)
		end
	end
end

-- Function to load foreground images with suffixes
local function loadForegroundImages(baseImagePath)
	foregroundImages = {}
	
	-- Extract the base path without extension
	local basePath = baseImagePath:gsub("%.png$", ""):gsub("%.jpg$", ""):gsub("%.jpeg$", "")
	
	-- Try to load images with suffixes _1, _2, _3, etc.
	local suffix = 1
	while true do
		local foregroundPath = basePath .. "_" .. suffix .. ".png"
		local success, image = pcall(function()
			return love.graphics.newImage(foregroundPath)
		end)
		
		if success then
			table.insert(foregroundImages, image)
			print("Loaded foreground image: " .. foregroundPath)
			suffix = suffix + 1
		else
			-- No more images with this suffix, stop loading
			break
		end
	end
	
	print("Loaded " .. #foregroundImages .. " foreground images for " .. baseImagePath)
end


-- Function to create a static immovable box
-- x, y are top-left coordinates (not center)
local function createStaticBox(x, y, width, height, visible)
	local staticBox = {}
		-- Convert top-left coordinates to center coordinates for physics body
	local centerX = x + width / 2
	local centerY = y + height / 2
	staticBox.body = love.physics.newBody(world, centerX, centerY, "static")
	staticBox.shape = love.physics.newRectangleShape(width, height)
	staticBox.fixture = love.physics.newFixture(staticBox.body, staticBox.shape, 0)
	staticBox.fixture:setFriction(0)
	staticBox.fixture:setRestitution(0)
	staticBox.width = width
	staticBox.height = height
	staticBox.color = {0.6, 0.4, 0.2} -- Brown color for boxes
	staticBox.visible = visible ~= false -- Default to true if not specified
	
	table.insert(staticBoxes, staticBox)
	return staticBox
end

-- Function to create a static immovable triangle with custom vertices
-- x, y are the center coordinates of the triangle
-- v1x, v1y, v2x, v2y, v3x, v3y are the three vertices relative to the center
local function createStaticTriangle(x, y, v1x, v1y, v2x, v2y, v3x, v3y, visible)
	local staticTriangle = {}
	staticTriangle.body = love.physics.newBody(world, x, y, "static")
	
	-- Store vertices relative to center
	staticTriangle.vertices = {
		{v1x, v1y},
		{v2x, v2y},
		{v3x, v3y}
	}
	
	staticTriangle.shape = love.physics.newPolygonShape(v1x, v1y, v2x, v2y, v3x, v3y)
	staticTriangle.fixture = love.physics.newFixture(staticTriangle.body, staticTriangle.shape, 0)
	staticTriangle.fixture:setFriction(0)
	staticTriangle.fixture:setRestitution(0)
	staticTriangle.color = {0.2, 0.6, 0.4} -- Green color for triangles
	staticTriangle.visible = visible ~= false -- Default to true if not specified
	
	table.insert(staticTriangles, staticTriangle)
	return staticTriangle
end

-- Function to create a scroll
-- x, y are the center coordinates
-- width, height are the dimensions (default 100x100)
local function createScroll(x, y, width, height)
	local scroll = {}
	scroll.x = x
	scroll.y = y
	scroll.width = width or 100
	scroll.height = height or 100
	scroll.color = {0.8, 0.6, 0.2} -- Golden color for scrolls
	
	table.insert(scrolls, scroll)
	return scroll
end

-- Function to create a portal
-- x, y are the center coordinates
-- width, height are the dimensions (default 100x100)
-- targetLevel is the level to teleport to (optional)
local function createPortal(x, y, width, height, targetLevel)
	local portal = {}
	portal.x = x
	portal.y = y
	portal.width = width or 100
	portal.height = height or 100
	portal.targetLevel = targetLevel
	portal.color = {0.2, 0.6, 0.8} -- Blue color for portals
	
	table.insert(portals, portal)
	return portal
end


-- Function to clear all static shapes
local function clearStaticShapes()
	-- Clear boxes
	for _, box in ipairs(staticBoxes) do
		if box.body then
			box.body:destroy()
		end
	end
	staticBoxes = {}
	
	-- Clear triangles
	for _, triangle in ipairs(staticTriangles) do
		if triangle.body then
			triangle.body:destroy()
		end
	end
	staticTriangles = {}
	
	-- Clear scrolls and portals (no physics bodies to destroy)
	scrolls = {}
	portals = {}
end

-- Function to load a level from a data file
local function loadLevel(filename)
	-- Clear existing shapes
	clearStaticShapes()
	
	-- Load level data
	local success, levelData = pcall(function()
		return love.filesystem.load(filename)()
	end)
	
	if not success then
		print("Error loading level: " .. filename)
		return false
	end
	
	currentLevel = levelData
	currentLevelName = filename:gsub("%.dat$", "") -- Extract level name from filename
	local w, h = love.graphics.getWidth(), love.graphics.getHeight()
	
	-- Load player start position if specified
	if levelData.playerStart then
		startX = levelData.playerStart.x
		startY = levelData.playerStart.y
		
		-- Calculate density to maintain consistent weight regardless of size
		local originalWidth = 50
		local originalHeight = 75
		local originalArea = originalWidth * originalHeight
		local originalDensity = 1
		
		if levelData.playerStart.width then
			playerWidth = levelData.playerStart.width
		end
		if levelData.playerStart.height then
			playerHeight = levelData.playerStart.height
		end
		
		local newArea = playerWidth * playerHeight
		-- Adjust density inversely to area change to maintain same mass
		local adjustedDensity = originalDensity * (originalArea / newArea)
		
		-- Update player body with new dimensions
		player.body:destroy()
		player.body = love.physics.newBody(world, startX, startY, "dynamic")
		player.shape = love.physics.newRectangleShape(playerWidth, playerHeight)
		player.fixture = love.physics.newFixture(player.body, player.shape, adjustedDensity)
		player.fixture:setFriction(1.0)
		player.fixture:setRestitution(0.6)
		player.body:setLinearDamping(linearDamping)
		player.body:setAngularDamping(angularDamping)
		player.body:setBullet(true)
	end
	
	-- Load boxes
	if levelData.boxes then
		for _, boxData in ipairs(levelData.boxes) do
			local x = boxData.x - boxData.width / 2  -- Convert from center to top-left coordinates
			local y = boxData.y - boxData.height / 2
			createStaticBox(x, y, boxData.width, boxData.height, boxData.visible)
		end
	end
	
	-- Load custom triangles
	if levelData.customTriangles then
		for _, triData in ipairs(levelData.customTriangles) do
			local x = triData.x
			local y = triData.y
			createStaticTriangle(x, y, triData.v1x, triData.v1y, triData.v2x, triData.v2y, triData.v3x, triData.v3y, triData.visible)
		end
	end
	
	-- Load scrolls
	if levelData.scrolls then
		for _, scrollData in ipairs(levelData.scrolls) do
			local x = scrollData.x
			local y = scrollData.y
			createScroll(x, y, scrollData.width, scrollData.height)
		end
	end
	
	-- Load portals
	if levelData.portals then
		for _, portalData in ipairs(levelData.portals) do
			local x = portalData.x
			local y = portalData.y
			createPortal(x, y, portalData.width, portalData.height, portalData.targetLevel)
		end
	end
	
	-- Load background image if specified
	if levelData.backgroundImage then
		local success, img = pcall(function()
			return love.graphics.newImage(levelData.backgroundImage)
		end)
		if success then
			backgroundImage = img
			print("Loaded background: " .. levelData.backgroundImage)
			-- Load foreground images with suffixes
			loadForegroundImages(levelData.backgroundImage)
		else
			print("Failed to load background: " .. levelData.backgroundImage)
		end
	end
	
	print("Level loaded: " .. filename)
	
	-- Update render module with new arrays
	Render.setGlobals({
		player = player,
		staticBoxes = staticBoxes,
		staticTriangles = staticTriangles,
		scrolls = scrolls,
		portals = portals,
		wizardImage = wizardImage,
		wizardCastingImage = wizardCastingImage,
		wizardGreenImage = wizardGreenImage,
		wizardGreenCastingImage = wizardGreenCastingImage,
		backgroundImage = backgroundImage,
		foregroundImages = foregroundImages,
		scrollImage = scrollImage,
		portalImage = portalImage,
		spellbookImage = spellbookImage,
		buttonLeftImage = buttonLeftImage,
		buttonRightImage = buttonRightImage,
		spellImages = spellImages,
		font = font,
		grimoireFont = grimoireFont,
		spellTitleFont = spellTitleFont,
		spellDescFont = spellDescFont,
		isOnGround = isOnGround,
		grimoireOpen = function() return Spellbook.isGrimoireOpen() end,
		currentPage = function() return Spellbook.getCurrentPage() end,
		spells = function() return Spellbook.getSpells() end,
		activeSpellEffects = function() return Spellbook.getActiveSpellEffects() end,
		magicSchool = function() return Spellbook.getMagicSchool() end,
		bookmarks = function() return Spellbook.getBookmarks() end,
		worldMapOpen = function() return worldMapOpen end,
		completedLevels = function() return completedLevels end,
		currentLevelName = function() return currentLevelName end,
		levelsConfig = function() return levelsConfig end,
		isLevelUnlocked = isLevelUnlocked
	})
	
	return true
end

-- Function to get level configuration by ID
local function getLevelConfig(levelId)
	for _, level in ipairs(levelsConfig) do
		if level.id == levelId then
			return level
		end
	end
	return nil
end

-- Function to check if a level is unlocked
local function isLevelUnlocked(levelId)
	local level = getLevelConfig(levelId)
	if not level then 
		print("Warning: Level not found in config: " .. tostring(levelId))
		return false 
	end
	return level.unlocked
end

-- Function to unlock the next level when current level is completed
local function unlockNextLevel(completedLevelId)
	for i, level in ipairs(levelsConfig) do
		if level.id == completedLevelId and i < #levelsConfig then
			-- Unlock the next level
			levelsConfig[i + 1].unlocked = true
			print("Unlocked: " .. levelsConfig[i + 1].name)
			break
		end
	end
end

-- Function to navigate to a specific level
local function navigateToLevel(levelId)
	if levelId == currentLevelName then
		worldMapOpen = false
		portalCooldown = 0 -- Reset cooldown when closing world map
		return
	end
	
	local level = getLevelConfig(levelId)
	if not level then
		print("Level not found: " .. levelId)
		return
	end
	
	if not isLevelUnlocked(levelId) then
		print("Level locked: " .. level.name)
		return
	end
	
	if loadLevel(level.filename) then
		worldMapOpen = false
		portalCooldown = 0 -- Reset cooldown when navigating to new level
		print("Navigated to: " .. level.name)
	else
		print("Failed to load level: " .. level.name)
	end
end


function love.load()
	love.window.setTitle("Spell Collector")
	font = love.graphics.newFont(16)
	backgroundImage = love.graphics.newImage("gfx/background.jpg")
	wizardImage = love.graphics.newImage("gfx/wizard.png")
	wizardCastingImage = love.graphics.newImage("gfx/wizard_casting.png")
	wizardGreenImage = love.graphics.newImage("gfx/wizard_green.png")
	wizardGreenCastingImage = love.graphics.newImage("gfx/wizard_green_casting.png")
	scrollImage = love.graphics.newImage("gfx/scroll.png")
	portalImage = love.graphics.newImage("gfx/portal.png")
	spellbookImage = love.graphics.newImage("gfx/spellbook.png")
	buttonLeftImage = love.graphics.newImage("gfx/button_left.png")
	buttonRightImage = love.graphics.newImage("gfx/button_right.png")
	
	-- Load all spell images dynamically
	loadSpellImages()
	
	-- Load additional fonts for grimoire
	grimoireFont = love.graphics.newFont(20)
	spellTitleFont = love.graphics.newFont(18)
	spellDescFont = love.graphics.newFont(14)
	
	-- Initialize modules
	Spellbook.init()
	
	world = love.physics.newWorld(0, gravityPixelsPerSecond2, true)

	-- Set global start position
	startX, startY = love.graphics.getWidth() * 0.1, love.graphics.getHeight() * 0.9
	
	-- Calculate density to maintain consistent weight regardless of size
	local originalWidth = 50
	local originalHeight = 75
	local originalArea = originalWidth * originalHeight
	local originalDensity = 1
	local currentArea = playerWidth * playerHeight
	local adjustedDensity = originalDensity * (originalArea / currentArea)
	
	player.body = love.physics.newBody(world, startX, startY, "dynamic")
	player.shape = love.physics.newRectangleShape(playerWidth, playerHeight)
	player.fixture = love.physics.newFixture(player.body, player.shape, adjustedDensity)
	player.fixture:setFriction(1.0)
	player.fixture:setRestitution(0.6)
	player.body:setLinearDamping(linearDamping)
	player.body:setAngularDamping(angularDamping)
	player.body:setBullet(true)
	player.color = {0.2, 0.7, 1.0}

	-- Screen walls
	local w, h = love.graphics.getWidth(), love.graphics.getHeight()
	local function createOrUpdateEdge(idx, x1, y1, x2, y2)
		if not walls[idx] then
			walls[idx] = { body = love.physics.newBody(world, 0, 0, "static") }
		else
			if walls[idx].fixture then walls[idx].fixture:destroy() end
		end
		walls[idx].shape = love.physics.newEdgeShape(x1, y1, x2, y2)
		walls[idx].fixture = love.physics.newFixture(walls[idx].body, walls[idx].shape, 0)
		walls[idx].fixture:setFriction(0)
		walls[idx].fixture:setRestitution(0)
	end

	local function rebuildWalls(width, height)
		-- Edges exactly at the screen bounds
		createOrUpdateEdge(1, 0, 0, width, 0)          -- top
		createOrUpdateEdge(2, 0, height, width, height) -- bottom
		createOrUpdateEdge(3, 0, 0, 0, height)          -- left
		createOrUpdateEdge(4, width, 0, width, height)  -- right
	end
	walls.rebuild = rebuildWalls
	walls.rebuild(w, h)
	
	-- Load level from file
	loadLevel("level1.dat")
	
	-- Set up render module with global references AFTER loading level
	Render.setGlobals({
		player = player,
		staticBoxes = staticBoxes,
		staticTriangles = staticTriangles,
		scrolls = scrolls,
		portals = portals,
		wizardImage = wizardImage,
		wizardCastingImage = wizardCastingImage,
		wizardGreenImage = wizardGreenImage,
		wizardGreenCastingImage = wizardGreenCastingImage,
		backgroundImage = backgroundImage,
		foregroundImages = foregroundImages,
		scrollImage = scrollImage,
		portalImage = portalImage,
		spellbookImage = spellbookImage,
		buttonLeftImage = buttonLeftImage,
		buttonRightImage = buttonRightImage,
		spellImages = spellImages,
		font = font,
		grimoireFont = grimoireFont,
		spellTitleFont = spellTitleFont,
		spellDescFont = spellDescFont,
		isOnGround = isOnGround,
		grimoireOpen = function() return Spellbook.isGrimoireOpen() end,
		currentPage = function() return Spellbook.getCurrentPage() end,
		spells = function() return Spellbook.getSpells() end,
		activeSpellEffects = function() return Spellbook.getActiveSpellEffects() end,
		magicSchool = function() return Spellbook.getMagicSchool() end,
		bookmarks = function() return Spellbook.getBookmarks() end,
		worldMapOpen = function() return worldMapOpen end,
		completedLevels = function() return completedLevels end,
		currentLevelName = function() return currentLevelName end,
		levelsConfig = function() return levelsConfig end,
		isLevelUnlocked = isLevelUnlocked
	})
end

local function checkGroundContact()
	local px, py = player.body:getPosition()
	
	-- Calculate dynamic ground check distance based on wizard size
	-- Add half of the lowest dimension (width or height) to allow bigger wizards to levitate higher
	local wizardHalfSize = math.min(playerWidth, playerHeight) / 2
	local dynamicGroundCheckDistance = groundCheckDistance + wizardHalfSize
	
	-- Cast a ray downward from the center of the player
	local rayStartX = px
	local rayStartY = py
	local rayEndX = px
	local rayEndY = py + dynamicGroundCheckDistance
	
	-- Reset raycast result before performing raycast
	raycastResult = nil
	
	-- Perform the raycast
	world:rayCast(rayStartX, rayStartY, rayEndX, rayEndY, raycastCallback)
	
	-- If we hit something within the ground check distance, we're on ground
	isOnGround = raycastResult ~= nil and raycastResult <= 1.0
	
	-- Fallback: check if close to bottom wall
	if not isOnGround then
		isOnGround = (py + dynamicGroundCheckDistance) >= love.graphics.getHeight()
	end
end

local function applyMovementForces()
	local vx, vy = player.body:getLinearVelocity()
	local currentSpeed = math.abs(vx)
	
	-- Check if Levitation spell is active
	local activeSpellEffects = Spellbook.getActiveSpellEffects()
	local canMove = activeSpellEffects["Levitation"] == true
	
	-- Only allow movement if Levitation spell is active
	if canMove then
		-- Horizontal movement with A/D keys (with speed limiting)
		if love.keyboard.isDown("a") or love.keyboard.isDown("left") then
			-- Only apply force if we're not already at max speed in this direction
			if vx > -maxHorizontalSpeed then
				-- Reduce force as we approach max speed
				local speedRatio = math.max(0, (maxHorizontalSpeed + vx) / maxHorizontalSpeed)
				player.body:applyForce(-moveForce * speedRatio, 0)
			end
		end
		if love.keyboard.isDown("d") or love.keyboard.isDown("right") then
			-- Only apply force if we're not already at max speed in this direction
			if vx < maxHorizontalSpeed then
				-- Reduce force as we approach max speed
				local speedRatio = math.max(0, (maxHorizontalSpeed - vx) / maxHorizontalSpeed)
				player.body:applyForce(moveForce * speedRatio, 0)
			end
		end
		
		-- Levitate with W key (only near ground)
		if love.keyboard.isDown("w") or love.keyboard.isDown("up") then
			if isOnGround then
				player.body:applyForce(0, -levitateForce)
			end
		end
	end
end

-- Function to check collision between player and scrolls/portals
local function checkPlayerCollisions()
	local px, py = player.body:getPosition()
	local playerHalfWidth = playerWidth / 2
	local playerHalfHeight = playerHeight / 2
	
	-- Update portal cooldown
	if portalCooldown > 0 then
		portalCooldown = portalCooldown - 1
	end
	
	-- Check scroll collisions
	for i, scroll in ipairs(scrolls) do
		local dx = math.abs(px - scroll.x)
		local dy = math.abs(py - scroll.y)
		
		if dx < (playerHalfWidth + scroll.width/2) and dy < (playerHalfHeight + scroll.height/2) then
			-- Player collected scroll
			table.remove(scrolls, i)
			completedLevels[currentLevelName] = true
			print("Scroll collected! Level " .. currentLevelName .. " completed!")
			break
		end
	end
	
	-- Check portal collisions (only if cooldown is 0 and world map is not already open)
	if portalCooldown == 0 and not worldMapOpen then
		for _, portal in ipairs(portals) do
			local dx = math.abs(px - portal.x)
			local dy = math.abs(py - portal.y)
			
			if dx < (playerHalfWidth + portal.width/2) and dy < (playerHalfHeight + portal.height/2) then
				-- Unlock the next level
				unlockNextLevel(currentLevelName)
				-- Player touched portal - open world map
				worldMapOpen = true
				portalCooldown = 60 -- 1 second cooldown at 60 FPS
				print("Portal touched! Opening world map...")
				break
			end
		end
	end
end

function love.update(dt)
	world:update(dt)
	checkGroundContact()
	applyMovementForces()
	checkPlayerCollisions()
end

function love.draw()
	Render.draw()
end

function love.keypressed(key)
	if key == "r" then
		player.body:setPosition(startX, startY)
		player.body:setLinearVelocity(0, 0)
		player.body:setAngularVelocity(0)
		player.body:setAngle(0)
	elseif key == "g" then
		Spellbook.toggleGrimoire()
	elseif key == "p" then
		worldMapOpen = not worldMapOpen
		if not worldMapOpen then
			portalCooldown = 0 -- Reset cooldown when closing world map
		end
		print("World map toggled: " .. tostring(worldMapOpen))
	end
end

-- Check if mouse is over a spell in the grimoire
local function isMouseOverSpell(spellIndex)
	if not Spellbook.isGrimoireOpen() then return false end
	
	local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
	local pageW = screenW * 0.8
	local pageH = screenH * 0.8
	local pageX = (screenW - pageW) / 2
	local pageY = (screenH - pageH) / 2
	
	local mx, my = love.mouse.getPosition()
	
	-- Calculate spell position
	local spellW = pageW * 0.45
	local spellH = pageH * 0.35
	local spellSpacing = pageW * 0.05
	local topSpellY = pageY + 80
	
	local col = ((spellIndex - 1) % 2) + 1
	local row = math.floor((spellIndex - 1) / 2) + 1
	local spellX = pageX + spellSpacing + (col - 1) * (spellW + spellSpacing)
	local spellY = topSpellY + (row - 1) * (spellH + 20)
	
	return mx >= spellX and mx <= spellX + spellW and my >= spellY and my <= spellY + spellH
end

-- Check if mouse is over a level in the world map
local function isMouseOverLevel(levelId, mx, my)
	if not worldMapOpen then return false end
	
	local level = getLevelConfig(levelId)
	if not level then return false end
	
	local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
	local mapW = screenW * 0.6
	local mapH = screenH * 0.4
	local mapX = (screenW - mapW) / 2
	local mapY = (screenH - mapH) / 2
	
	-- Calculate level position based on configuration
	local levelX = mapX + mapW * level.position.x
	local levelY = mapY + mapH * level.position.y
	local levelSize = 80
	
	return mx >= levelX - levelSize/2 and mx <= levelX + levelSize/2 and 
	       my >= levelY - levelSize/2 and my <= levelY + levelSize/2
end

function love.mousepressed(x, y, button)
	if button == 1 then -- Left mouse button
		if Spellbook.isGrimoireOpen() then
			-- Check if clicking on any spell
			for i = 1, 4 do
				if isMouseOverSpell(i) then
					local spells = Spellbook.getSpells()
					local spell = spells[i]
					if Spellbook.canCastSpell(spell.name) then
						Spellbook.castSpell(spell.name)
						-- Close the grimoire after casting a spell
						Spellbook.toggleGrimoire()
					end
					break
				end
			end
		elseif worldMapOpen then
			-- Check if clicking on any level in world map
			for _, level in ipairs(levelsConfig) do
				if isMouseOverLevel(level.id, x, y) then
					navigateToLevel(level.id)
					break
				end
			end
		end
	end
end

function love.resize(w, h)
	if walls and walls.rebuild then
		walls.rebuild(w, h)
	end
end