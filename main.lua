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
local font
local wizardImage
local wizardCastingImage
local wizardGreenImage
local wizardGreenCastingImage
local backgroundImage
local scrollImage
local portalImage
local spellImages = {} -- Dictionary to store loaded spell images
local grimoireFont, spellTitleFont, spellDescFont

local gravityPixelsPerSecond2 = 900 -- positive Y is down in LOVE
local moveForce = 1000 -- force applied by A/D keys
local levitateForce = 5000 -- upward force applied by W key
local linearDamping = 0.5
local angularDamping = 0
local playerWidth = 50
local playerHeight = 75
local isOnGround = false
local groundCheckDistance = 100 -- pixels below box to check for ground
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


-- Function to create a static immovable box
-- x, y are top-left coordinates (not center)
local function createStaticBox(x, y, width, height)
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
	
	table.insert(staticBoxes, staticBox)
	return staticBox
end

-- Function to create a static immovable triangle with custom vertices
-- x, y are the center coordinates of the triangle
-- v1x, v1y, v2x, v2y, v3x, v3y are the three vertices relative to the center
local function createStaticTriangle(x, y, v1x, v1y, v2x, v2y, v3x, v3y)
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
			createStaticBox(x, y, boxData.width, boxData.height)
		end
	end
	
	-- Load custom triangles
	if levelData.customTriangles then
		for _, triData in ipairs(levelData.customTriangles) do
			local x = triData.x
			local y = triData.y
			createStaticTriangle(x, y, triData.v1x, triData.v1y, triData.v2x, triData.v2y, triData.v3x, triData.v3y)
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
		scrollImage = scrollImage,
		portalImage = portalImage,
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
		bookmarks = function() return Spellbook.getBookmarks() end
	})
	
	return true
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
		scrollImage = scrollImage,
		portalImage = portalImage,
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
		bookmarks = function() return Spellbook.getBookmarks() end
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

function love.update(dt)
	world:update(dt)
	checkGroundContact()
	applyMovementForces()
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

function love.mousepressed(x, y, button)
	if button == 1 and Spellbook.isGrimoireOpen() then -- Left mouse button and grimoire is open
		-- Check if clicking on any spell
		for i = 1, 4 do
			if isMouseOverSpell(i) then
				local spells = Spellbook.getSpells()
				local spell = spells[i]
				if Spellbook.canCastSpell(spell.name) then
					Spellbook.castSpell(spell.name)
				end
				break
			end
		end
	end
end

function love.resize(w, h)
	if walls and walls.rebuild then
		walls.rebuild(w, h)
	end
end