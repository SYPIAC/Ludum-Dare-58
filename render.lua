-- Render module for Spell Collector
-- Handles all drawing operations

local Spellbook = require("spellbook")
local Render = {}

-- Global variables that need to be exposed from main.lua
local player, staticBoxes, staticTriangles, scrolls, portals, wizardImage, wizardCastingImage, wizardGreenImage, wizardGreenCastingImage, backgroundImage, foregroundImages, scrollImage, portalImage, spellbookImage, spellImages, buttonLeftImage, buttonRightImage
local font, grimoireFont, spellTitleFont, spellDescFont
local isOnGround, grimoireOpen, currentPage, spells, activeSpellEffects, magicSchool, bookmarks
local worldMapOpen, completedLevels, currentLevelName, levelsConfig, isLevelUnlocked

-- Function to set the global references
function Render.setGlobals(globals)
	player = globals.player
	staticBoxes = globals.staticBoxes
	staticTriangles = globals.staticTriangles
	scrolls = globals.scrolls
	portals = globals.portals
	wizardImage = globals.wizardImage
	wizardCastingImage = globals.wizardCastingImage
	wizardGreenImage = globals.wizardGreenImage
	wizardGreenCastingImage = globals.wizardGreenCastingImage
	backgroundImage = globals.backgroundImage
	foregroundImages = globals.foregroundImages
	scrollImage = globals.scrollImage
	portalImage = globals.portalImage
	spellbookImage = globals.spellbookImage
	spellImages = globals.spellImages
	buttonLeftImage = globals.buttonLeftImage
	buttonRightImage = globals.buttonRightImage
	font = globals.font
	grimoireFont = globals.grimoireFont
	spellTitleFont = globals.spellTitleFont
	spellDescFont = globals.spellDescFont
	isOnGround = globals.isOnGround
	grimoireOpen = globals.grimoireOpen
	currentPage = globals.currentPage
	spells = globals.spells
	activeSpellEffects = globals.activeSpellEffects
	magicSchool = globals.magicSchool
	bookmarks = globals.bookmarks
	worldMapOpen = globals.worldMapOpen
	completedLevels = globals.completedLevels
	currentLevelName = globals.currentLevelName
	levelsConfig = globals.levelsConfig
	isLevelUnlocked = globals.isLevelUnlocked
end

-- Get spell image for a given spell name
local function getSpellImage(spellName)
	local imagePath = Spellbook.getSpellImage(spellName)
	if imagePath and spellImages and spellImages[imagePath] then
		return spellImages[imagePath]
	end
	return nil
end

-- Draw a chevron bookmark
local function drawChevronBookmark(x, y, width, height, color, isActive)
	-- Draw the main rectangular part
	love.graphics.setColor(color)
	love.graphics.rectangle("fill", x, y, width, height - 10)
	
	-- Draw the chevron point at the bottom
	local chevronPoints = {
		x, y + height - 10,  -- top-left of chevron
		x + width/2, y + height,  -- bottom point of chevron
		x + width, y + height - 10  -- top-right of chevron
	}
	love.graphics.polygon("fill", chevronPoints)
	
	-- Draw border
	local borderColor = isActive and {0.4, 0.3, 0.2} or {0.5, 0.4, 0.3}
	love.graphics.setColor(borderColor)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", x, y, width, height - 10)
	love.graphics.polygon("line", chevronPoints)
end

-- Draw a triangular arrow button
local function drawArrowButton(x, y, size, direction, color, isActive)
	-- direction: "left" or "right"
	local points = {}
	
	if direction == "left" then
		-- Left-pointing triangle
		points = {
			x + size, y,  -- top-right
			x, y + size/2,  -- left point
			x + size, y + size  -- bottom-right
		}
	else -- right
		-- Right-pointing triangle
		points = {
			x, y,  -- top-left
			x + size, y + size/2,  -- right point
			x, y + size  -- bottom-left
		}
	end
	
	-- Draw the triangle
	love.graphics.setColor(color)
	love.graphics.polygon("fill", points)
	
	-- Draw border
	local borderColor = isActive and {0.2, 0.1, 0.0} or {0.3, 0.2, 0.1}
	love.graphics.setColor(borderColor)
	love.graphics.setLineWidth(2)
	love.graphics.polygon("line", points)
end

-- Get current wizard image based on active spells and casting state
local function getCurrentWizardImage(isCasting)
	-- Check for active spell effects in order of priority
	if activeSpellEffects()["Become Green"] then
		return isCasting and wizardGreenCastingImage or wizardGreenImage
	end
	
	-- Default wizard images
	return isCasting and wizardCastingImage or wizardImage
end

-- Draw the wizard
function Render.drawWizard()
	local x, y = player.body:getPosition()
	local angle = player.body:getAngle()
	love.graphics.push()
	love.graphics.translate(x, y)
	love.graphics.rotate(angle)
	
	-- Determine which image to use based on movement/levitation and active spells
	local isMoving = love.keyboard.isDown("a") or love.keyboard.isDown("d") or 
	                 love.keyboard.isDown("left") or love.keyboard.isDown("right")
	local isLevitating = love.keyboard.isDown("w") or love.keyboard.isDown("up")
	local isCasting = isMoving or isLevitating
	local currentImage = getCurrentWizardImage(isCasting)
	
	-- Get the image dimensions
	local imgW, imgH = currentImage:getDimensions()
	-- Get the physics shape dimensions
	local shape = player.shape
	local x1, y1, x2, y2, x3, y3, x4, y4 = shape:getPoints()
	
	local physicsW = math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
	local physicsH = math.sqrt((x3 - x2)^2 + (y3 - y2)^2)
	
	-- Draw the appropriate wizard image centered on the physics body
	love.graphics.setColor(1, 1, 1) -- white tint (no color modification)
	love.graphics.draw(currentImage, 0, 0, 0, physicsW/imgW, physicsH/imgH, imgW/2, imgH/2)
	
	-- Draw debug box around the physics shape
	love.graphics.setColor(1, 0, 0, 0.8) -- red with transparency
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", -physicsW/2, -physicsH/2, physicsW, physicsH)
	
	love.graphics.pop()
end

-- Draw the background
function Render.drawBackground()
	local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
	local imgW, imgH = backgroundImage:getDimensions()
	
	-- Scale the background to cover the entire screen
	local scaleX = screenW / imgW
	local scaleY = screenH / imgH
	
	love.graphics.setColor(1, 1, 1) -- No color tinting
	love.graphics.draw(backgroundImage, 0, 0, 0, scaleX, scaleY)
end

-- Draw foreground images (in front of the player)
function Render.drawForeground()
	if foregroundImages and #foregroundImages > 0 then
		local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
		
		-- Draw each foreground image
		for _, foregroundImage in ipairs(foregroundImages) do
			local imgW, imgH = foregroundImage:getDimensions()
			
			-- Scale the foreground image to cover the entire screen
			local scaleX = screenW / imgW
			local scaleY = screenH / imgH
			
			love.graphics.setColor(1, 1, 1) -- No color tinting
			love.graphics.draw(foregroundImage, 0, 0, 0, scaleX, scaleY)
		end
	end
end

-- Draw static boxes
function Render.drawStaticBoxes()
	if staticBoxes then
		for _, staticBox in ipairs(staticBoxes) do
			-- Only draw if visible
			if staticBox.visible then
				local x, y = staticBox.body:getPosition()
				local angle = staticBox.body:getAngle()
				
				love.graphics.push()
				love.graphics.translate(x, y)
				love.graphics.rotate(angle)
				
				-- Draw the box with its color
				love.graphics.setColor(staticBox.color)
				love.graphics.rectangle("fill", -staticBox.width/2, -staticBox.height/2, staticBox.width, staticBox.height)
				
				-- Draw a border
				love.graphics.setColor(0.3, 0.2, 0.1)
				love.graphics.setLineWidth(2)
				love.graphics.rectangle("line", -staticBox.width/2, -staticBox.height/2, staticBox.width, staticBox.height)
				
				love.graphics.pop()
			end
		end
	end
end

-- Draw static triangles
function Render.drawStaticTriangles()
	if staticTriangles then
		for _, staticTriangle in ipairs(staticTriangles) do
			-- Only draw if visible
			if staticTriangle.visible then
				local x, y = staticTriangle.body:getPosition()
				local angle = staticTriangle.body:getAngle()
				
				love.graphics.push()
				love.graphics.translate(x, y)
				love.graphics.rotate(angle)
				
				-- Draw the triangle with its color
				love.graphics.setColor(staticTriangle.color)
				
				-- Use the stored vertices
				local v1 = staticTriangle.vertices[1]
				local v2 = staticTriangle.vertices[2]
				local v3 = staticTriangle.vertices[3]
				
				love.graphics.polygon("fill", v1[1], v1[2], v2[1], v2[2], v3[1], v3[2])
				
				-- Draw a border
				love.graphics.setColor(0.1, 0.4, 0.2)
				love.graphics.setLineWidth(2)
				love.graphics.polygon("line", v1[1], v1[2], v2[1], v2[2], v3[1], v3[2])
				
				love.graphics.pop()
			end
		end
	end
end

-- Draw scrolls
function Render.drawScrolls()
	if scrolls then
		for _, scroll in ipairs(scrolls) do
			love.graphics.push()
			love.graphics.translate(scroll.x, scroll.y)
			
		-- Draw scroll image or fallback rectangle using actual dimensions
		love.graphics.setColor(1, 1, 1) -- No color tinting
		if scrollImage then
			-- Scale to match the scroll's width and height
			local scaleX = scroll.width / scrollImage:getWidth()
			local scaleY = scroll.height / scrollImage:getHeight()
			love.graphics.draw(scrollImage, 0, 0, 0, scaleX, scaleY, scrollImage:getWidth()/2, scrollImage:getHeight()/2)
		else
			-- Fallback: draw a golden rectangle with actual dimensions
			love.graphics.setColor(0.8, 0.6, 0.2)
			love.graphics.rectangle("fill", -scroll.width/2, -scroll.height/2, scroll.width, scroll.height)
		end
			
			love.graphics.pop()
		end
	end
end

-- Draw portals
function Render.drawPortals()
	if portals then
		for _, portal in ipairs(portals) do
			love.graphics.push()
			love.graphics.translate(portal.x, portal.y)
			
		-- Draw portal image using actual dimensions
		love.graphics.setColor(1, 1, 1) -- No color tinting
		-- Scale to match the portal's width and height
		local scaleX = portal.width / portalImage:getWidth()
		local scaleY = portal.height / portalImage:getHeight()
		love.graphics.draw(portalImage, 0, 0, 0, scaleX, scaleY, portalImage:getWidth()/2, portalImage:getHeight()/2)
		
			
			love.graphics.pop()
		end
	end
end


-- Draw the grimoire
function Render.drawGrimoire()
	if not grimoireOpen() then return end
	
	local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
	local pageW = screenW * 0.9
	local pageH = screenH * 0.8
	local pageX = (screenW - pageW) / 2
	local pageY = (screenH - pageH) / 2
	
	-- Draw spellbook background image
	if spellbookImage then
		love.graphics.setColor(1, 1, 1) -- No color tinting
		love.graphics.draw(spellbookImage, pageX, pageY, 0, pageW / spellbookImage:getWidth(), pageH / spellbookImage:getHeight())
	else
		-- Fallback to rectangle background if image not loaded
		love.graphics.setColor(0.95, 0.9, 0.8)
		love.graphics.rectangle("fill", pageX, pageY, pageW, pageH, 8, 8)
		
		-- Draw page border
		love.graphics.setColor(0.7, 0.6, 0.4)
		love.graphics.setLineWidth(3)
		love.graphics.rectangle("line", pageX, pageY, pageW, pageH, 8, 8)
	end
	
	-- Draw magic school title at top
	love.graphics.setFont(grimoireFont)
	love.graphics.setColor(0.2, 0.1, 0.0)
	local titleW = grimoireFont:getWidth(magicSchool())
	love.graphics.print(magicSchool(), pageX + (pageW - titleW) / 2, pageY + 20)
	
	-- Draw spells in 2x2 grid
	local spellW = pageW * 0.45
	local spellH = pageH * 0.35
	local spellSpacing = pageW * 0.03
	local topSpellY = pageY + 80
	
	for i = 1, 4 do
		local col = ((i - 1) % 2) + 1
		local row = math.floor((i - 1) / 2) + 1
		local spellX = pageX + spellSpacing + (col - 1) * (spellW + spellSpacing)
		local spellY = topSpellY + (row - 1) * (spellH + 20)
		
		local spell = spells()[i]
		
		-- Draw spell box with different colors for active/available/unknown spells
		local isActive = activeSpellEffects()[spell.name]
		local isAvailable = spell.name ~= "???"
		
		if isActive then
			love.graphics.setColor(0.8, 0.9, 0.8) -- Light green for active spells
		elseif isAvailable then
			love.graphics.setColor(0.9, 0.85, 0.75) -- Normal parchment color
		else
			love.graphics.setColor(0.7, 0.7, 0.7) -- Gray for unknown spells
		end
		love.graphics.rectangle("fill", spellX, spellY, spellW, spellH, 4, 4)
		
		love.graphics.setColor(0.6, 0.5, 0.3)
		love.graphics.setLineWidth(2)
		love.graphics.rectangle("line", spellX, spellY, spellW, spellH, 4, 4)
		
		-- Draw spell name
		love.graphics.setFont(spellTitleFont)
		love.graphics.setColor(0.2, 0.1, 0.0)
		love.graphics.print(spell.name, spellX + 10, spellY + 10)
		
		-- Draw spell image or placeholder
		local imgW, imgH = 60, 60
		local imgX = spellX + 10
		local imgY = spellY + 35
		
		-- Try to get the spell image
		local spellImage = getSpellImage(spell.name)
		if spellImage then
			-- Draw the actual spell image
			love.graphics.setColor(1, 1, 1) -- No color tinting
			local iconW, iconH = spellImage:getDimensions()
			local scale = math.min(imgW / iconW, imgH / iconH)
			local scaledW = iconW * scale
			local scaledH = iconH * scale
			love.graphics.draw(spellImage, imgX + (imgW - scaledW) / 2, imgY + (imgH - scaledH) / 2, 0, scale, scale)
		else
			-- Draw placeholder for spells without images
			love.graphics.setColor(0.8, 0.8, 0.8)
			love.graphics.rectangle("fill", imgX, imgY, imgW, imgH)
			love.graphics.setColor(0.5, 0.5, 0.5)
			love.graphics.rectangle("line", imgX, imgY, imgW, imgH)
			
			-- Draw image placeholder text
			love.graphics.setFont(font)
			love.graphics.setColor(0.3, 0.3, 0.3)
			local placeholderW = font:getWidth(spell.image)
			local placeholderH = font:getHeight()
			love.graphics.print(spell.image, imgX + (imgW - placeholderW) / 2, imgY + (imgH - placeholderH) / 2)
		end
		
		-- Draw description or special image for "Become Green"
		local descW = spellW - imgW - 30
		local descX = imgX + imgW + 10
		local descY = imgY + 5
		
		if spell.name == "Become Green" then
			-- Draw spellmeaning1.png for "Become Green" spell
			local meaningImage = love.graphics.newImage("gfx/spellmeaning1.png")
			if meaningImage then
				love.graphics.setColor(1, 1, 1) -- No color tinting
				local meaningW, meaningH = meaningImage:getDimensions()
				local scale = math.min(descW / meaningW, (spellH - 40) / meaningH)
				local scaledW = meaningW * scale
				local scaledH = meaningH * scale
				love.graphics.draw(meaningImage, descX + (descW - scaledW) / 2, descY + ((spellH - 40) - scaledH) / 2, 0, scale * 2, scale * 2)
			else
				-- Fallback to text if image not found
				love.graphics.setFont(spellDescFont)
				love.graphics.setColor(0.3, 0.2, 0.1)
				love.graphics.print(spell.description, descX, descY)
			end
		else
			-- Draw normal text description for other spells
			love.graphics.setFont(spellDescFont)
			love.graphics.setColor(0.3, 0.2, 0.1)
			
			-- Word wrap description
			local words = {}
			for word in spell.description:gmatch("%S+") do
				table.insert(words, word)
			end
			
			local line = ""
			local y = descY
			for _, word in ipairs(words) do
				local testLine = line == "" and word or line .. " " .. word
				if spellDescFont:getWidth(testLine) <= descW then
					line = testLine
				else
					if line ~= "" then
						love.graphics.print(line, descX, y)
						y = y + spellDescFont:getHeight() + 2
					end
					line = word
				end
			end
			if line ~= "" then
				love.graphics.print(line, descX, y)
			end
		end
	end
	
	-- Draw chevron bookmarks underneath the spellbook
	local bookmarkH = 60
	local bookmarkY = pageY + pageH  -- Position underneath the book
	local bookmarkW = 40
	local bookmarkSpacing = 5
	local totalBookmarkWidth = (#bookmarks() * bookmarkW) + ((#bookmarks() - 1) * bookmarkSpacing)
	local startBookmarkX = pageX + (pageW - totalBookmarkWidth) / 2  -- Center the bookmarks
	
	for i, bookmark in ipairs(bookmarks()) do
		local bookmarkX = startBookmarkX + (i - 1) * (bookmarkW + bookmarkSpacing)
		local isActive = i == currentPage()
		
		-- Different colors for each bookmark (like in the reference image)
		local bookmarkColors = {
			{0.8, 0.2, 0.2},  -- Red
			{0.6, 0.8, 0.4},  -- Light yellow-green
			{0.2, 0.5, 0.2},  -- Dark green
			{0.6, 0.3, 0.8},  -- Purple
			{0.4, 0.2, 0.1}   -- Brown
		}
		local bookmarkColor = bookmarkColors[i] or {0.5, 0.5, 0.5}  -- Default gray
		
		-- Make active bookmark slightly brighter
		if isActive then
			bookmarkColor = {
				math.min(1.0, bookmarkColor[1] + 0.2),
				math.min(1.0, bookmarkColor[2] + 0.2),
				math.min(1.0, bookmarkColor[3] + 0.2)
			}
		end
		
		-- Draw the chevron bookmark
		drawChevronBookmark(bookmarkX, bookmarkY, bookmarkW, bookmarkH, bookmarkColor, isActive)
		
		-- Draw bookmark text
		love.graphics.setFont(font)
		love.graphics.setColor(1, 1, 1)  -- White text for visibility
		local textW = font:getWidth(bookmark)
		love.graphics.print(bookmark, bookmarkX + (bookmarkW - textW) / 2, bookmarkY + 8)
	end
	
	-- Draw navigation buttons on the sides of the spellbook
	local buttonSize = 50
	local buttonY = pageY + (pageH - buttonSize) / 2  -- Center vertically with the spellbook
	local leftButtonX = pageX - buttonSize  -- Left side of the spellbook
	local rightButtonX = pageX + pageW  -- Right side of the spellbook
	
	-- Left button (previous page)
	if buttonLeftImage then
		love.graphics.setColor(1, 1, 1) -- No color tinting
		love.graphics.draw(buttonLeftImage, leftButtonX, buttonY, 0, buttonSize / buttonLeftImage:getWidth(), buttonSize / buttonLeftImage:getHeight())
	else
		-- Fallback to old arrow drawing if image not loaded
		drawArrowButton(leftButtonX, buttonY, buttonSize, "left", {0.6, 0.3, 0.2}, false)
	end
	
	-- Right button (next page)
	if buttonRightImage then
		love.graphics.setColor(1, 1, 1) -- No color tinting
		love.graphics.draw(buttonRightImage, rightButtonX, buttonY, 0, buttonSize / buttonRightImage:getWidth(), buttonSize / buttonRightImage:getHeight())
	else
		-- Fallback to old arrow drawing if image not loaded
		drawArrowButton(rightButtonX, buttonY, buttonSize, "right", {0.6, 0.3, 0.2}, false)
	end
end

-- Draw the world map
function Render.drawWorldMap()
	if not worldMapOpen() then return end
	
	-- Safety check: ensure isLevelUnlocked function is available
	if not isLevelUnlocked then
		print("Warning: isLevelUnlocked function not available in render module")
		-- Create a fallback function that checks the level config directly
		isLevelUnlocked = function(levelId)
			if not levelsConfig or not levelsConfig() then return false end
			for _, level in ipairs(levelsConfig()) do
				if level.id == levelId then
					return level.unlocked
				end
			end
			return false
		end
		print("Created fallback isLevelUnlocked function")
	end
	
	local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
	local mapW = screenW * 0.6
	local mapH = screenH * 0.4
	local mapX = (screenW - mapW) / 2
	local mapY = (screenH - mapH) / 2
	
	-- Draw dark overlay background
	love.graphics.setColor(0, 0, 0, 0.7)
	love.graphics.rectangle("fill", 0, 0, screenW, screenH)
	
	-- Draw world map background
	love.graphics.setColor(0.1, 0.1, 0.2) -- Dark blue background
	love.graphics.rectangle("fill", mapX, mapY, mapW, mapH, 8, 8)
	
	-- Draw world map border
	love.graphics.setColor(0.3, 0.3, 0.5)
	love.graphics.setLineWidth(3)
	love.graphics.rectangle("line", mapX, mapY, mapW, mapH, 8, 8)
	
	-- Draw title
	love.graphics.setFont(grimoireFont)
	love.graphics.setColor(1, 1, 1)
	local title = "Adventure World"
	local titleW = grimoireFont:getWidth(title)
	love.graphics.print(title, mapX + (mapW - titleW) / 2, mapY + 20)
	
	local levelSize = 80
	local levels = levelsConfig()
	
	-- Draw connecting lines between unlocked levels
	love.graphics.setColor(1, 1, 1)
	love.graphics.setLineWidth(4)
	for i = 1, #levels - 1 do
		if isLevelUnlocked and isLevelUnlocked(levels[i].id) and isLevelUnlocked(levels[i + 1].id) then
			local level1X = mapX + mapW * levels[i].position.x
			local level1Y = mapY + mapH * levels[i].position.y
			local level2X = mapX + mapW * levels[i + 1].position.x
			local level2Y = mapY + mapH * levels[i + 1].position.y
			love.graphics.line(level1X + levelSize/2, level1Y, level2X - levelSize/2, level2Y)
		end
	end
	
	-- Draw all levels dynamically
	for _, level in ipairs(levels) do
		local levelX = mapX + mapW * level.position.x
		local levelY = mapY + mapH * level.position.y
		
		love.graphics.push()
		love.graphics.translate(levelX, levelY)
		
		-- Draw portal image or locked indicator
		if isLevelUnlocked and isLevelUnlocked(level.id) then
			-- Draw portal image using actual portal graphic
			love.graphics.setColor(1, 1, 1) -- No color tinting
			if portalImage then
				-- Scale to match the level size
				local scaleX = levelSize / portalImage:getWidth()
				local scaleY = levelSize / portalImage:getHeight()
				love.graphics.draw(portalImage, 0, 0, 0, scaleX, scaleY, portalImage:getWidth()/2, portalImage:getHeight()/2)
			else
				-- Fallback: draw a simple circle
				love.graphics.setColor(0.6, 0.2, 0.8) -- Purple color
				love.graphics.circle("fill", 0, 0, levelSize/2)
				love.graphics.setColor(0.8, 0.4, 1.0)
				love.graphics.circle("line", 0, 0, levelSize/2)
			end
		else
			-- Draw locked level indicator
			love.graphics.setColor(0.3, 0.3, 0.3) -- Gray color for locked
			love.graphics.circle("fill", 0, 0, levelSize/2)
			love.graphics.setColor(0.5, 0.5, 0.5)
			love.graphics.circle("line", 0, 0, levelSize/2)
			
			-- Draw lock icon
			love.graphics.setColor(0.7, 0.7, 0.7)
			love.graphics.setLineWidth(3)
			local lockSize = 15
			love.graphics.rectangle("line", -lockSize/2, -lockSize/2, lockSize, lockSize)
			love.graphics.arc("line", 0, -lockSize/2, lockSize/3, 0, math.pi)
		end
		
		-- Draw level label
		love.graphics.setFont(font)
		if isLevelUnlocked and isLevelUnlocked(level.id) then
			love.graphics.setColor(1, 1, 1)
		else
			love.graphics.setColor(0.6, 0.6, 0.6) -- Gray for locked levels
		end
		local label = level.displayName
		local labelW = font:getWidth(label)
		love.graphics.print(label, -labelW/2, -levelSize/2 - 30)
		
		-- Draw checkmark if completed
		if completedLevels()[level.id] then
			love.graphics.setColor(0, 1, 0) -- Green
			love.graphics.setLineWidth(4)
			local checkSize = 20
			love.graphics.line(-checkSize/2, 0, -checkSize/4, checkSize/4)
			love.graphics.line(-checkSize/4, checkSize/4, checkSize/2, -checkSize/4)
		end
		
		love.graphics.pop()
	end
	
	-- Draw instructions
	love.graphics.setFont(font)
	love.graphics.setColor(1, 1, 1, 0.8)
	love.graphics.print("Click on levels to navigate\nPress P to close", mapX + 10, mapY + mapH - 40)
end

-- Draw UI text
function Render.drawUI()
	if worldMapOpen() then
		-- Don't show UI text when world map is open
		return
	elseif not grimoireOpen() then
		love.graphics.setFont(font)
		love.graphics.setColor(1, 1, 1, 0.85)
		
		-- Check if Levitation spell is active
		local activeSpellEffects = activeSpellEffects()
		local canMove = activeSpellEffects["Levitation"] == true
	else
		-- Show grimoire instructions
		love.graphics.setFont(font)
		love.graphics.setColor(1, 1, 1, 0.85)
		love.graphics.print("Press G to close grimoire\nClick spells in grimoire to cast them", 12, 12)
	end
end

-- Main draw function
function Render.draw()
	-- Draw background first
	Render.drawBackground()
	
	-- Draw static boxes
	Render.drawStaticBoxes()
	
	-- Draw static triangles
	Render.drawStaticTriangles()
	
	-- Draw scrolls (behind wizard)
	Render.drawScrolls()
	
	-- Draw portals (behind wizard)
	Render.drawPortals()
	
	-- Draw wizard
	Render.drawWizard()
	
	-- Draw foreground images (in front of wizard)
	Render.drawForeground()
	
	-- Draw grimoire if open
	Render.drawGrimoire()
	
	-- Draw world map if open
	Render.drawWorldMap()
	
	-- Draw UI
	Render.drawUI()
	
	-- Draw world text for special levels
	Render.drawWorldText()
end

-- Function to draw world text for special levels
function Render.drawWorldText()
	local levelName = currentLevelName()
	
	-- Define special level text messages
	local specialTexts = {
		level_end = {
			text = "YOU WIN!",
			color = {1, 0.8, 0.2}, -- Golden yellow
			fontSize = 48,
			position = {x = 0.5, y = 0.5, offsetY = 200}, -- Center with 200px offset down
			subTexts = {
				{
					text = "You collected all the spells. Wow!",
					color = {0.9, 0.9, 0.9}, -- Light gray
					fontSize = 24
				},
				{
					text = "Have this one last special one.",
					color = {0.9, 0.9, 0.9}, -- Light gray
					fontSize = 24
				}
			}
		},
		level4 = {
			text = "R to restart",
			color = {0.2, 0.8, 1}, -- Blue
			fontSize = 36,
			position = {x = 0.5, y = 0.98} -- Bottom center
		},
		level1 = {
			text = "I'm not walking anywhere. Are you mad? (Press G to open grimoire)",
			color = {0.2, 0.8, 1}, -- Blue
			fontSize = 16,
			position = {x = 0.3, y = 0.1} -- Top left
		}
	}
		-- Add more special levels here as needed
		-- level_special = {
		--     text = "Special Message",
		--     color = {0.2, 0.8, 1}, -- Blue
		--     fontSize = 36
		-- }
	
	local specialLevel = specialTexts[levelName]
	if specialLevel then
		-- Get screen dimensions
		local screenWidth = love.graphics.getWidth()
		local screenHeight = love.graphics.getHeight()
		
		-- Calculate position based on custom position or default to center
		local position = specialLevel.position or {x = 0.5, y = 0.5, offsetY = 0}
		local baseX = screenWidth * position.x
		local baseY = screenHeight * position.y + (position.offsetY or 0)
		
		-- Draw main text
		local mainFont = love.graphics.newFont(specialLevel.fontSize)
		love.graphics.setFont(mainFont)
		
		-- Calculate text dimensions for background box
		local mainTextWidth = mainFont:getWidth(specialLevel.text)
		local mainTextHeight = mainFont:getHeight()
		local boxPadding = 20
		local boxWidth = mainTextWidth + (boxPadding * 2)
		local boxHeight = mainTextHeight + (boxPadding * 2)
		
		-- Add subtext dimensions if they exist
		if specialLevel.subTexts then
			local subFont = love.graphics.newFont(specialLevel.subTexts[1].fontSize)
			love.graphics.setFont(subFont)
			local subTextWidth = 0
			for _, subText in ipairs(specialLevel.subTexts) do
				local subFont = love.graphics.newFont(subText.fontSize)
				love.graphics.setFont(subFont)
				local textWidth = subFont:getWidth(subText.text)
				if textWidth > subTextWidth then
					subTextWidth = textWidth
				end
			end
			boxWidth = math.max(boxWidth, subTextWidth + (boxPadding * 2))
			boxHeight = boxHeight + (specialLevel.subTexts[1].fontSize + 10) * #specialLevel.subTexts + 20
		end
		
		-- Calculate the actual text area bounds
		local textStartY = baseY - 40
		local textEndY = textStartY + mainTextHeight
		if specialLevel.subTexts then
			textEndY = textEndY + 20 + (specialLevel.subTexts[1].fontSize + 10) * #specialLevel.subTexts
		end
		
		-- Draw black background box centered on the text area
		love.graphics.setColor(0, 0, 0, 0.7) -- Black with 70% opacity
		love.graphics.rectangle("fill", 
			baseX - boxWidth / 2, 
			textStartY - boxPadding, 
			boxWidth, 
			textEndY - textStartY + (boxPadding * 2))
		
		-- Draw text
		love.graphics.setFont(mainFont)
		love.graphics.setColor(specialLevel.color[1], specialLevel.color[2], specialLevel.color[3])
		
		love.graphics.print(specialLevel.text, 
			baseX - mainTextWidth / 2, 
			textStartY)
		
		-- Draw subtexts if they exist
		if specialLevel.subTexts then
			local yOffset = textStartY + mainTextHeight + 20
			
			for i, subText in ipairs(specialLevel.subTexts) do
				local subFont = love.graphics.newFont(subText.fontSize)
				love.graphics.setFont(subFont)
				love.graphics.setColor(subText.color[1], subText.color[2], subText.color[3])
				
				local subTextWidth = subFont:getWidth(subText.text)
				local subTextHeight = subFont:getHeight()
				
				love.graphics.print(subText.text, 
					baseX - subTextWidth / 2, 
					yOffset)
				
				yOffset = yOffset + subTextHeight + 10 -- Add spacing between subtexts
			end
		end
		
		-- Reset color
		love.graphics.setColor(1, 1, 1)
	end
end


return Render
