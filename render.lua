-- Render module for Spell Collector
-- Handles all drawing operations

local Spellbook = require("spellbook")
local Render = {}

-- Global variables that need to be exposed from main.lua
local player, staticBoxes, staticTriangles, scrolls, portals, wizardImage, wizardCastingImage, wizardGreenImage, wizardGreenCastingImage, backgroundImage, scrollImage, portalImage, spellbookImage, spellImages
local font, grimoireFont, spellTitleFont, spellDescFont
local isOnGround, grimoireOpen, currentPage, spells, activeSpellEffects, magicSchool, bookmarks
local worldMapOpen, completedLevels, currentLevelName

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
	scrollImage = globals.scrollImage
	portalImage = globals.portalImage
	spellbookImage = globals.spellbookImage
	spellImages = globals.spellImages
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
		
		-- Draw description
		love.graphics.setFont(spellDescFont)
		love.graphics.setColor(0.3, 0.2, 0.1)
		local descW = spellW - imgW - 30
		local descX = imgX + imgW + 10
		local descY = imgY + 5
		
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
	
	-- Draw navigation arrows on the sides of the spellbook
	local arrowSize = 50
	local arrowY = pageY + (pageH - arrowSize) / 2  -- Center vertically with the spellbook
	local leftArrowX = pageX - arrowSize  -- Left side of the spellbook
	local rightArrowX = pageX + pageW  -- Right side of the spellbook
	
	-- Left arrow (previous page)
	drawArrowButton(leftArrowX, arrowY, arrowSize, "left", {0.6, 0.3, 0.2}, false)
	
	-- Right arrow (next page)
	drawArrowButton(rightArrowX, arrowY, arrowSize, "right", {0.6, 0.3, 0.2}, false)
end

-- Draw the world map
function Render.drawWorldMap()
	if not worldMapOpen() then return end
	
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
	
	-- Level positions
	local level1X = mapX + mapW * 0.2
	local level1Y = mapY + mapH * 0.5
	local level2X = mapX + mapW * 0.8
	local level2Y = mapY + mapH * 0.5
	local levelSize = 80
	
	-- Draw connecting line
	love.graphics.setColor(1, 1, 1)
	love.graphics.setLineWidth(4)
	love.graphics.line(level1X + levelSize/2, level1Y, level2X - levelSize/2, level2Y)
	
	-- Draw level 1 portal
	love.graphics.push()
	love.graphics.translate(level1X, level1Y)
	
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
	
	-- Draw level label
	love.graphics.setFont(font)
	love.graphics.setColor(1, 1, 1)
	local label = "lvl 1"
	local labelW = font:getWidth(label)
	love.graphics.print(label, -labelW/2, -levelSize/2 - 30)
	
	-- Draw checkmark if completed
	if completedLevels()["level1"] then
		love.graphics.setColor(0, 1, 0) -- Green
		love.graphics.setLineWidth(4)
		local checkSize = 20
		love.graphics.line(-checkSize/2, 0, -checkSize/4, checkSize/4)
		love.graphics.line(-checkSize/4, checkSize/4, checkSize/2, -checkSize/4)
	end
	
	love.graphics.pop()
	
	-- Draw level 2 portal
	love.graphics.push()
	love.graphics.translate(level2X, level2Y)
	
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
	
	-- Draw level label
	love.graphics.setFont(font)
	love.graphics.setColor(1, 1, 1)
	local label = "lvl 2"
	local labelW = font:getWidth(label)
	love.graphics.print(label, -labelW/2, -levelSize/2 - 30)
	
	-- Draw checkmark if completed
	if completedLevels()["level2"] then
		love.graphics.setColor(0, 1, 0) -- Green
		love.graphics.setLineWidth(4)
		local checkSize = 20
		love.graphics.line(-checkSize/2, 0, -checkSize/4, checkSize/4)
		love.graphics.line(-checkSize/4, checkSize/4, checkSize/2, -checkSize/4)
	end
	
	love.graphics.pop()
	
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
		local info = string.format("WASD to move and levitate\nA/D - Move left/right\nW - Levitate (when near ground)\nPress R to reset position\nPress G to open grimoire\nPress P to open world map")
		love.graphics.print(info, 12, 12)
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
	
	-- Draw grimoire if open
	Render.drawGrimoire()
	
	-- Draw world map if open
	Render.drawWorldMap()
	
	-- Draw UI
	Render.drawUI()
end


return Render
