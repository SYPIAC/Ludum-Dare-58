-- Render module for Spell Collector
-- Handles all drawing operations

local Render = {}

-- Global variables that need to be exposed from main.lua
local player, staticBoxes, staticTriangles, scrolls, portals, wizardImage, wizardCastingImage, wizardGreenImage, wizardGreenCastingImage, backgroundImage, scrollImage, portalImage
local font, grimoireFont, spellTitleFont, spellDescFont
local isOnGround, grimoireOpen, currentPage, spells, activeSpellEffects, magicSchool, bookmarks

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

-- Draw static triangles
function Render.drawStaticTriangles()
	if staticTriangles then
		for _, staticTriangle in ipairs(staticTriangles) do
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

-- Draw scrolls
function Render.drawScrolls()
	if scrolls then
		for _, scroll in ipairs(scrolls) do
			love.graphics.push()
			love.graphics.translate(scroll.x, scroll.y)
			
		-- Draw scroll image or fallback rectangle (always 100x100)
		love.graphics.setColor(1, 1, 1) -- No color tinting
		if scrollImage then
			-- Scale down to 100x100 (assuming original image is larger)
			local scale = 100 / math.max(scrollImage:getWidth(), scrollImage:getHeight())
			love.graphics.draw(scrollImage, 0, 0, 0, scale, scale, scrollImage:getWidth()/2, scrollImage:getHeight()/2)
		else
			-- Fallback: draw a golden rectangle
			love.graphics.setColor(0.8, 0.6, 0.2)
			love.graphics.rectangle("fill", -50, -50, 100, 100)
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
			
		-- Draw portal image (always 100x100)
		love.graphics.setColor(1, 1, 1) -- No color tinting
		-- Scale down to 100x100 (assuming original image is larger)
		local scale = 100 / math.max(portalImage:getWidth(), portalImage:getHeight())
		love.graphics.draw(portalImage, 0, 0, 0, scale, scale, portalImage:getWidth()/2, portalImage:getHeight()/2)
		
			
			love.graphics.pop()
		end
	end
end


-- Draw the grimoire
function Render.drawGrimoire()
	if not grimoireOpen() then return end
	
	local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
	local pageW = screenW * 0.8
	local pageH = screenH * 0.8
	local pageX = (screenW - pageW) / 2
	local pageY = (screenH - pageH) / 2
	
	-- Draw page background (parchment-like)
	love.graphics.setColor(0.95, 0.9, 0.8)
	love.graphics.rectangle("fill", pageX, pageY, pageW, pageH, 8, 8)
	
	-- Draw page border
	love.graphics.setColor(0.7, 0.6, 0.4)
	love.graphics.setLineWidth(3)
	love.graphics.rectangle("line", pageX, pageY, pageW, pageH, 8, 8)
	
	-- Draw magic school title at top
	love.graphics.setFont(grimoireFont)
	love.graphics.setColor(0.2, 0.1, 0.0)
	local titleW = grimoireFont:getWidth(magicSchool())
	love.graphics.print(magicSchool(), pageX + (pageW - titleW) / 2, pageY + 20)
	
	-- Draw spells in 2x2 grid
	local spellW = pageW * 0.45
	local spellH = pageH * 0.35
	local spellSpacing = pageW * 0.05
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
		
		-- Draw image placeholder
		local imgW, imgH = 60, 60
		local imgX = spellX + 10
		local imgY = spellY + 35
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
	
	-- Draw bookmarks at bottom
	local bookmarkH = 30
	local bookmarkY = pageY + pageH - bookmarkH - 10
	local bookmarkW = (pageW - 20) / #bookmarks()
	
	for i, bookmark in ipairs(bookmarks()) do
		local bookmarkX = pageX + 10 + (i - 1) * bookmarkW
		local bookmarkColor = i == currentPage() and {0.9, 0.8, 0.6} or {0.8, 0.7, 0.5}
		
		love.graphics.setColor(bookmarkColor)
		love.graphics.rectangle("fill", bookmarkX, bookmarkY, bookmarkW - 2, bookmarkH, 2, 2)
		love.graphics.setColor(0.6, 0.5, 0.3)
		love.graphics.rectangle("line", bookmarkX, bookmarkY, bookmarkW - 2, bookmarkH, 2, 2)
		
		love.graphics.setFont(font)
		love.graphics.setColor(0.2, 0.1, 0.0)
		local textW = font:getWidth(bookmark)
		love.graphics.print(bookmark, bookmarkX + (bookmarkW - textW) / 2, bookmarkY + 8)
	end
end

-- Draw UI text
function Render.drawUI()
	if not grimoireOpen() then
		love.graphics.setFont(font)
		love.graphics.setColor(1, 1, 1, 0.85)
		local info = string.format("WASD to move and levitate\nA/D - Move left/right\nW - Levitate (when near ground)\nPress R to reset position\nPress G to open grimoire")
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
	
	-- Draw UI
	Render.drawUI()
end


return Render
