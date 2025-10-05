-- Level Editor for Spell Collector
-- Basic keyboard-operated level editor

-- Editor state
local editorState = {
    mode = "player", -- "player", "box", "scroll", "portal", "triangle", "visibility"
    selectedObject = nil,
    isPlacing = false,
    gridSize = 20,
    showGrid = true,
    lastAction = "",
    lastActionTime = 0,
    editMode = false, -- New: edit mode for resizing/moving objects
    dragging = false, -- New: currently dragging something
    dragType = nil, -- "box_resize", "triangle_vertex"
    dragObject = nil, -- Object being dragged
    dragHandle = nil, -- Which handle/vertex is being dragged
    dragOffsetX = nil, -- Offset for smooth dragging
    dragOffsetY = nil, -- Offset for smooth dragging
    fileDialog = {
        active = false,
        mode = nil, -- "save" or "load"
        files = {},
        selectedIndex = 1,
        currentDir = ".",
        inputText = "",
        justOpened = false -- Flag to prevent first key from being added
    }
}

-- Level data
local levelData = {
    playerStart = {x = 100, y = 690, width = 165, height = 165},
    boxes = {},
    scrolls = {},
    portals = {},
    customTriangles = {}
}

-- Visual feedback
local cursorX, cursorY = 0, 0
local font
local backgroundImage

-- Colors for different object types
local colors = {
    player = {0.2, 0.7, 1.0},
    box = {0.6, 0.4, 0.2},
    scroll = {0.8, 0.6, 0.2},
    portal = {0.2, 0.6, 0.8},
    triangle = {0.2, 0.6, 0.4},
    grid = {0.3, 0.3, 0.3, 0.5}
}

-- Helper function to snap to grid
local function snapToGrid(x, y)
    local grid = editorState.gridSize
    return math.floor(x / grid) * grid, math.floor(y / grid) * grid
end

-- Helper function to get mouse position
local function getMousePosition()
    local mx, my = love.mouse.getPosition()
    if editorState.showGrid then
        return snapToGrid(mx, my)
    end
    return mx, my
end

-- Helper function to draw grid
local function drawGrid()
    if not editorState.showGrid then return end
    
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local grid = editorState.gridSize
    
    love.graphics.setColor(colors.grid)
    love.graphics.setLineWidth(1)
    
    -- Vertical lines
    for x = 0, w, grid do
        love.graphics.line(x, 0, x, h)
    end
    
    -- Horizontal lines
    for y = 0, h, grid do
        love.graphics.line(0, y, w, y)
    end
end

-- Helper function to draw resize handles for player
local function drawPlayerResizeHandles(player)
    local handleSize = 8
    local halfHandle = handleSize / 2
    
    love.graphics.setColor(1, 1, 0) -- Yellow handles
    love.graphics.setLineWidth(2)
    
    -- Corner handles
    love.graphics.rectangle("fill", player.x - player.width/2 - halfHandle, player.y - player.height/2 - halfHandle, handleSize, handleSize)
    love.graphics.rectangle("fill", player.x + player.width/2 - halfHandle, player.y - player.height/2 - halfHandle, handleSize, handleSize)
    love.graphics.rectangle("fill", player.x - player.width/2 - halfHandle, player.y + player.height/2 - halfHandle, handleSize, handleSize)
    love.graphics.rectangle("fill", player.x + player.width/2 - halfHandle, player.y + player.height/2 - halfHandle, handleSize, handleSize)
    
    -- Edge handles
    love.graphics.rectangle("fill", player.x - halfHandle, player.y - player.height/2 - halfHandle, handleSize, handleSize)
    love.graphics.rectangle("fill", player.x - halfHandle, player.y + player.height/2 - halfHandle, handleSize, handleSize)
    love.graphics.rectangle("fill", player.x - player.width/2 - halfHandle, player.y - halfHandle, handleSize, handleSize)
    love.graphics.rectangle("fill", player.x + player.width/2 - halfHandle, player.y - halfHandle, handleSize, handleSize)
end

-- Helper function to draw player start
local function drawPlayerStart()
    if not levelData.playerStart then return end
    
    local p = levelData.playerStart
    love.graphics.setColor(colors.player)
    love.graphics.rectangle("fill", p.x - p.width/2, p.y - p.height/2, p.width, p.height)
    love.graphics.setColor(0, 0, 0)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", p.x - p.width/2, p.y - p.height/2, p.width, p.height)
    
    -- Draw "P" label
    love.graphics.setFont(font)
    love.graphics.setColor(1, 1, 1)
    local text = "P"
    local textW = font:getWidth(text)
    local textH = font:getHeight()
    love.graphics.print(text, p.x - textW/2, p.y - textH/2)
    
    -- Draw resize handles in edit mode
    if editorState.editMode then
        drawPlayerResizeHandles(p)
    end
end

-- Helper function to draw resize handles for boxes
local function drawBoxResizeHandles(box, boxIndex)
    local handleSize = 8
    local halfHandle = handleSize / 2
    
    love.graphics.setColor(1, 1, 0) -- Yellow handles
    love.graphics.setLineWidth(2)
    
    -- Corner handles
    love.graphics.rectangle("fill", box.x - halfHandle, box.y - halfHandle, handleSize, handleSize)
    love.graphics.rectangle("fill", box.x + box.width - halfHandle, box.y - halfHandle, handleSize, handleSize)
    love.graphics.rectangle("fill", box.x - halfHandle, box.y + box.height - halfHandle, handleSize, handleSize)
    love.graphics.rectangle("fill", box.x + box.width - halfHandle, box.y + box.height - halfHandle, handleSize, handleSize)
    
    -- Edge handles
    love.graphics.rectangle("fill", box.x + box.width/2 - halfHandle, box.y - halfHandle, handleSize, handleSize)
    love.graphics.rectangle("fill", box.x + box.width/2 - halfHandle, box.y + box.height - halfHandle, handleSize, handleSize)
    love.graphics.rectangle("fill", box.x - halfHandle, box.y + box.height/2 - halfHandle, handleSize, handleSize)
    love.graphics.rectangle("fill", box.x + box.width - halfHandle, box.y + box.height/2 - halfHandle, handleSize, handleSize)
end

-- Helper function to draw boxes
local function drawBoxes()
    if not levelData.boxes then return end
    
    for i, box in ipairs(levelData.boxes) do
        -- Check if box is visible
        local isVisible = box.visible ~= false -- Default to true if not specified
        
        if isVisible then
            love.graphics.setColor(colors.box)
        else
            -- Draw invisible boxes with a different color and pattern
            love.graphics.setColor(0.3, 0.3, 0.3, 0.5) -- Gray and semi-transparent
        end
        
        love.graphics.rectangle("fill", box.x, box.y, box.width, box.height)
        
        if isVisible then
            love.graphics.setColor(0, 0, 0)
        else
            love.graphics.setColor(0.5, 0.5, 0.5) -- Gray border for invisible
        end
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", box.x, box.y, box.width, box.height)
        
        -- Draw box number
        love.graphics.setFont(font)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(tostring(i), box.x + 5, box.y + 5)
        
        -- Draw resize handles in edit mode
        if editorState.editMode then
            drawBoxResizeHandles(box, i)
        end
    end
end

-- Helper function to draw scrolls
local function drawScrolls()
    if not levelData.scrolls then return end
    
    for i, scroll in ipairs(levelData.scrolls) do
        love.graphics.setColor(colors.scroll)
        love.graphics.rectangle("fill", scroll.x - scroll.width/2, scroll.y - scroll.height/2, scroll.width, scroll.height)
        love.graphics.setColor(0, 0, 0)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", scroll.x - scroll.width/2, scroll.y - scroll.height/2, scroll.width, scroll.height)
        
        -- Draw "S" label
        love.graphics.setFont(font)
        love.graphics.setColor(1, 1, 1)
        local text = "S"
        local textW = font:getWidth(text)
        local textH = font:getHeight()
        love.graphics.print(text, scroll.x - textW/2, scroll.y - textH/2)
    end
end

-- Helper function to draw portals
local function drawPortals()
    if not levelData.portals then return end
    
    for i, portal in ipairs(levelData.portals) do
        love.graphics.setColor(colors.portal)
        love.graphics.rectangle("fill", portal.x - portal.width/2, portal.y - portal.height/2, portal.width, portal.height)
        love.graphics.setColor(0, 0, 0)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", portal.x - portal.width/2, portal.y - portal.height/2, portal.width, portal.height)
        
        -- Draw "E" label
        love.graphics.setFont(font)
        love.graphics.setColor(1, 1, 1)
        local text = "E"
        local textW = font:getWidth(text)
        local textH = font:getHeight()
        love.graphics.print(text, portal.x - textW/2, portal.y - textH/2)
    end
end

-- Helper function to draw vertex handles for triangles
local function drawTriangleVertexHandles(triangle, triangleIndex)
    local handleSize = 8
    local halfHandle = handleSize / 2
    
    love.graphics.setColor(1, 0, 1) -- Magenta handles for vertices
    
    -- Draw handles at each vertex
    local v1x, v1y = triangle.x + triangle.v1x, triangle.y + triangle.v1y
    local v2x, v2y = triangle.x + triangle.v2x, triangle.y + triangle.v2y
    local v3x, v3y = triangle.x + triangle.v3x, triangle.y + triangle.v3y
    
    love.graphics.rectangle("fill", v1x - halfHandle, v1y - halfHandle, handleSize, handleSize)
    love.graphics.rectangle("fill", v2x - halfHandle, v2y - halfHandle, handleSize, handleSize)
    love.graphics.rectangle("fill", v3x - halfHandle, v3y - halfHandle, handleSize, handleSize)
end

-- Helper function to draw triangles
local function drawTriangles()
    if not levelData.customTriangles then return end
    
    for i, triangle in ipairs(levelData.customTriangles) do
        -- Check if triangle is visible
        local isVisible = triangle.visible ~= false -- Default to true if not specified
        
        if isVisible then
            love.graphics.setColor(colors.triangle)
        else
            -- Draw invisible triangles with a different color and pattern
            love.graphics.setColor(0.3, 0.3, 0.3, 0.5) -- Gray and semi-transparent
        end
        
        love.graphics.polygon("fill", 
            triangle.x + triangle.v1x, triangle.y + triangle.v1y,
            triangle.x + triangle.v2x, triangle.y + triangle.v2y,
            triangle.x + triangle.v3x, triangle.y + triangle.v3y
        )
        
        if isVisible then
            love.graphics.setColor(0, 0, 0)
        else
            love.graphics.setColor(0.5, 0.5, 0.5) -- Gray border for invisible
        end
        love.graphics.setLineWidth(2)
        love.graphics.polygon("line",
            triangle.x + triangle.v1x, triangle.y + triangle.v1y,
            triangle.x + triangle.v2x, triangle.y + triangle.v2y,
            triangle.x + triangle.v3x, triangle.y + triangle.v3y
        )
        
        -- Draw triangle number
        love.graphics.setFont(font)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(tostring(i), triangle.x, triangle.y)
        
        -- Draw vertex handles in edit mode
        if editorState.editMode then
            drawTriangleVertexHandles(triangle, i)
        end
    end
end

-- Helper function to draw cursor preview
local function drawCursorPreview()
    -- Don't show cursor preview in edit mode
    if editorState.editMode then
        return
    end
    
    local mx, my = getMousePosition()
    
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.setLineWidth(2)
    
    if editorState.mode == "player" then
        local w, h = 165, 165 -- Default player size
        if levelData.playerStart then
            w, h = levelData.playerStart.width, levelData.playerStart.height
        end
        love.graphics.rectangle("line", mx - w/2, my - h/2, w, h)
    elseif editorState.mode == "box" then
        love.graphics.rectangle("line", mx, my, 80, 60)
    elseif editorState.mode == "scroll" then
        love.graphics.rectangle("line", mx - 50, my - 50, 100, 100)
    elseif editorState.mode == "portal" then
        love.graphics.rectangle("line", mx - 50, my - 50, 100, 100)
    elseif editorState.mode == "triangle" then
        -- Simple triangle preview
        love.graphics.polygon("line", mx, my - 20, mx - 20, my + 20, mx + 20, my + 20)
    end
end

-- Helper function to draw UI
local function drawUI()
    love.graphics.setFont(font)
    love.graphics.setColor(1, 1, 1)
    
    local y = 10
    love.graphics.print("LEVEL EDITOR", 10, y)
    y = y + 25
    
    love.graphics.print("Mode: " .. editorState.mode, 10, y)
    y = y + 15
    love.graphics.print("Edit Mode: " .. (editorState.editMode and "ON" or "OFF"), 10, y)
    y = y + 20
    
    love.graphics.print("Controls:", 10, y)
    y = y + 20
    love.graphics.print("1 - Player Start", 10, y)
    y = y + 15
    love.graphics.print("2 - Box", 10, y)
    y = y + 15
    love.graphics.print("3 - Scroll", 10, y)
    y = y + 15
    love.graphics.print("4 - Portal", 10, y)
    y = y + 15
    love.graphics.print("5 - Triangle", 10, y)
    y = y + 15
    love.graphics.print("6 - Visibility Toggle", 10, y)
    y = y + 20
    
    love.graphics.print("G - Toggle Grid", 10, y)
    y = y + 15
    love.graphics.print("E - Toggle Edit Mode", 10, y)
    y = y + 15
    love.graphics.print("S - Save Level", 10, y)
    y = y + 15
    love.graphics.print("L - Load Level", 10, y)
    y = y + 15
    love.graphics.print("C - Clear Level", 10, y)
    y = y + 15
    love.graphics.print("ESC - Exit", 10, y)
    y = y + 20
    
    love.graphics.print("Click to place objects", 10, y)
    y = y + 15
    love.graphics.print("Right-click to delete", 10, y)
    y = y + 20
    
    -- Show current level data
    love.graphics.print("Current Level Data:", 10, y)
    y = y + 15
    love.graphics.print("Player: " .. (levelData.playerStart and "YES" or "NO"), 10, y)
    y = y + 15
    love.graphics.print("Boxes: " .. (levelData.boxes and #levelData.boxes or 0), 10, y)
    y = y + 15
    love.graphics.print("Scrolls: " .. (levelData.scrolls and #levelData.scrolls or 0), 10, y)
    y = y + 15
    love.graphics.print("Portals: " .. (levelData.portals and #levelData.portals or 0), 10, y)
    y = y + 15
    love.graphics.print("Triangles: " .. (levelData.customTriangles and #levelData.customTriangles or 0), 10, y)
    
    -- Show file dialog if active
    if editorState.fileDialog.active then
        local dialog = editorState.fileDialog
        local dialogX = 200
        local dialogY = 100
        local dialogW = 400
        local dialogH = 300
        
        -- Draw dialog background
        love.graphics.setColor(0.2, 0.2, 0.2, 0.9)
        love.graphics.rectangle("fill", dialogX, dialogY, dialogW, dialogH)
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", dialogX, dialogY, dialogW, dialogH)
        
        -- Draw title
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(dialog.mode:upper() .. " LEVEL", dialogX + 10, dialogY + 10)
        
        -- Draw file list
        local listY = dialogY + 40
        local listH = 150
        love.graphics.setColor(0.1, 0.1, 0.1)
        love.graphics.rectangle("fill", dialogX + 10, listY, dialogW - 20, listH)
        
        -- Show files (without .dat extension)
        for i, file in ipairs(dialog.files) do
            local color = (i == dialog.selectedIndex) and {1, 1, 0} or {0.8, 0.8, 0.8}
            love.graphics.setColor(color)
            local displayName = file:gsub("%.dat$", "") -- Remove .dat extension for display
            love.graphics.print(displayName, dialogX + 15, listY + 10 + (i - 1) * 20)
        end
        
        -- Draw input field
        local inputY = listY + listH + 20
        love.graphics.setColor(0.1, 0.1, 0.1)
        love.graphics.rectangle("fill", dialogX + 10, inputY, dialogW - 20, 30)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Filename: " .. dialog.inputText .. "_", dialogX + 15, inputY + 8)
        
        -- Draw buttons
        local buttonY = inputY + 40
        love.graphics.setColor(0.2, 0.6, 0.2)
        love.graphics.rectangle("fill", dialogX + 10, buttonY, 80, 30)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("OK", dialogX + 35, buttonY + 8)
        
        love.graphics.setColor(0.6, 0.2, 0.2)
        love.graphics.rectangle("fill", dialogX + 100, buttonY, 80, 30)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Cancel", dialogX + 115, buttonY + 8)
        
        -- Draw instructions
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print("Use UP/DOWN to select files, ENTER to confirm", dialogX + 10, buttonY + 40)
    end
    
    -- Show last action feedback
    if editorState.lastAction ~= "" then
        local timeSince = love.timer.getTime() - editorState.lastActionTime
        if timeSince < 3 then -- Show for 3 seconds
            love.graphics.setColor(0, 1, 0) -- Green for success
            love.graphics.print("Last Action: " .. editorState.lastAction, 10, y)
            love.graphics.setColor(1, 1, 1) -- Reset to white
        end
    end
end

-- Helper function to scan directory for files
local function scanDirectory(path)
    local files = {}
    local handle = io.popen('dir "' .. path .. '" /b 2>nul')
    if handle then
        for line in handle:lines() do
            if line:match("%.dat$") then
                table.insert(files, line)
            end
        end
        handle:close()
    end
    return files
end

-- Helper function to save level
local function saveLevel()
    editorState.fileDialog.active = true
    editorState.fileDialog.mode = "save"
    editorState.fileDialog.inputText = "level_editor" -- No .dat extension shown
    editorState.fileDialog.files = scanDirectory(".")
    editorState.fileDialog.selectedIndex = 1
    editorState.fileDialog.justOpened = true -- Prevent first key from being added
end

-- Helper function to load level
local function loadLevel()
    editorState.fileDialog.active = true
    editorState.fileDialog.mode = "load"
    editorState.fileDialog.inputText = "level1" -- No .dat extension shown
    editorState.fileDialog.files = scanDirectory(".")
    editorState.fileDialog.selectedIndex = 1
    editorState.fileDialog.justOpened = true -- Prevent first key from being added
end

-- Helper function to actually save the level
local function performSave(filename)
    -- Auto-append .dat extension if not present
    if not filename:match("%.dat$") then
        filename = filename .. ".dat"
    end
    
    -- Create the level data as a string
    local levelString = "-- Level Editor Data File\n"
    levelString = levelString .. "-- Generated by level editor\n\n"
    levelString = levelString .. "return {\n"
    
    -- Player start
    if levelData.playerStart then
        levelString = levelString .. "    playerStart = {\n"
        levelString = levelString .. "        x = " .. levelData.playerStart.x .. ",\n"
        levelString = levelString .. "        y = " .. levelData.playerStart.y .. ",\n"
        levelString = levelString .. "        width = " .. levelData.playerStart.width .. ",\n"
        levelString = levelString .. "        height = " .. levelData.playerStart.height .. "\n"
        levelString = levelString .. "    },\n"
    end
    
    -- Boxes (convert from top-left to center coordinates)
    if #levelData.boxes > 0 then
        levelString = levelString .. "    boxes = {\n"
        for i, box in ipairs(levelData.boxes) do
            local centerX = box.x + box.width / 2
            local centerY = box.y + box.height / 2
            levelString = levelString .. "        {x = " .. centerX .. ", y = " .. centerY .. ", width = " .. box.width .. ", height = " .. box.height .. ", visible = " .. tostring(box.visible ~= false) .. "}"
            if i < #levelData.boxes then
                levelString = levelString .. ","
            end
            levelString = levelString .. "\n"
        end
        levelString = levelString .. "    },\n"
    end
    
    -- Scrolls
    if #levelData.scrolls > 0 then
        levelString = levelString .. "    scrolls = {\n"
        for i, scroll in ipairs(levelData.scrolls) do
            levelString = levelString .. "        {x = " .. scroll.x .. ", y = " .. scroll.y .. ", width = " .. scroll.width .. ", height = " .. scroll.height .. "}"
            if i < #levelData.scrolls then
                levelString = levelString .. ","
            end
            levelString = levelString .. "\n"
        end
        levelString = levelString .. "    },\n"
    end
    
    -- Portals
    if #levelData.portals > 0 then
        levelString = levelString .. "    portals = {\n"
        for i, portal in ipairs(levelData.portals) do
            levelString = levelString .. "        {x = " .. portal.x .. ", y = " .. portal.y .. ", width = " .. portal.width .. ", height = " .. portal.height .. ", targetLevel = \"" .. (portal.targetLevel or "level2") .. "\"}"
            if i < #levelData.portals then
                levelString = levelString .. ","
            end
            levelString = levelString .. "\n"
        end
        levelString = levelString .. "    },\n"
    end
    
    -- Triangles
    if #levelData.customTriangles > 0 then
        levelString = levelString .. "    customTriangles = {\n"
        for i, triangle in ipairs(levelData.customTriangles) do
            levelString = levelString .. "        {x = " .. triangle.x .. ", y = " .. triangle.y .. ", v1x = " .. triangle.v1x .. ", v1y = " .. triangle.v1y .. ", v2x = " .. triangle.v2x .. ", v2y = " .. triangle.v2y .. ", v3x = " .. triangle.v3x .. ", v3y = " .. triangle.v3y .. ", visible = " .. tostring(triangle.visible ~= false) .. "}"
            if i < #levelData.customTriangles then
                levelString = levelString .. ","
            end
            levelString = levelString .. "\n"
        end
        levelString = levelString .. "    }\n"
    end
    
    levelString = levelString .. "}\n"
    
    -- Write to the file
    local file = io.open(filename, "w")
    if file then
        file:write(levelString)
        file:close()
        editorState.lastAction = "Saved to: " .. filename
        editorState.lastActionTime = love.timer.getTime()
        return true
    else
        editorState.lastAction = "Failed to save"
        editorState.lastActionTime = love.timer.getTime()
        return false
    end
end

-- Helper function to actually load the level
local function performLoad(filename)
    -- Auto-append .dat extension if not present
    if not filename:match("%.dat$") then
        filename = filename .. ".dat"
    end
    
    
    local success, data = pcall(function()
        -- Load the file using dofile
        local chunk = loadfile(filename)
        if chunk then
            return chunk()
        else
            error("Failed to load file")
        end
    end)
    
    if success then
        levelData = data
        
        -- Ensure all arrays exist
        levelData.boxes = levelData.boxes or {}
        levelData.scrolls = levelData.scrolls or {}
        levelData.portals = levelData.portals or {}
        levelData.customTriangles = levelData.customTriangles or {}
        
        -- Convert boxes from center coordinates to top-left coordinates for editor display
        for i, box in ipairs(levelData.boxes) do
            levelData.boxes[i].x = box.x - box.width / 2
            levelData.boxes[i].y = box.y - box.height / 2
            -- Ensure visible flag exists (default to true if not specified)
            if levelData.boxes[i].visible == nil then
                levelData.boxes[i].visible = true
            end
        end
        
        -- Ensure visible flag exists for triangles (default to true if not specified)
        for i, triangle in ipairs(levelData.customTriangles) do
            if levelData.customTriangles[i].visible == nil then
                levelData.customTriangles[i].visible = true
            end
        end
        
        
        -- Show visual feedback
        editorState.lastAction = "Loaded: " .. filename
        editorState.lastActionTime = love.timer.getTime()
        return true
    else
        editorState.lastAction = "Failed to load " .. filename
        editorState.lastActionTime = love.timer.getTime()
        return false
    end
end

-- Helper function to clear level
local function clearLevel()
    levelData = {
        playerStart = {x = 100, y = 690, width = 165, height = 165},
        boxes = {},
        scrolls = {},
        portals = {},
        customTriangles = {}
    }
end


-- Helper function to check if point is inside rectangle
local function pointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

-- Helper function to check if point is inside a handle
local function pointInHandle(px, py, hx, hy, handleSize)
    local halfHandle = handleSize / 2
    local hitboxSize = handleSize + 8 -- Add 4 pixels on each side for easier clicking
    local halfHitbox = hitboxSize / 2
    return px >= hx - halfHitbox and px <= hx + halfHitbox and 
           py >= hy - halfHitbox and py <= hy + halfHitbox
end

-- Helper function to find which box handle is clicked
local function findBoxHandle(x, y)
    if not levelData.boxes then return nil, nil, nil end
    
    local handleSize = 8
    for i, box in ipairs(levelData.boxes) do
        -- Check corner handles
        if pointInHandle(x, y, box.x, box.y, handleSize) then
            return i, "corner_tl", box
        elseif pointInHandle(x, y, box.x + box.width, box.y, handleSize) then
            return i, "corner_tr", box
        elseif pointInHandle(x, y, box.x, box.y + box.height, handleSize) then
            return i, "corner_bl", box
        elseif pointInHandle(x, y, box.x + box.width, box.y + box.height, handleSize) then
            return i, "corner_br", box
        -- Check edge handles
        elseif pointInHandle(x, y, box.x + box.width/2, box.y, handleSize) then
            return i, "edge_top", box
        elseif pointInHandle(x, y, box.x + box.width/2, box.y + box.height, handleSize) then
            return i, "edge_bottom", box
        elseif pointInHandle(x, y, box.x, box.y + box.height/2, handleSize) then
            return i, "edge_left", box
        elseif pointInHandle(x, y, box.x + box.width, box.y + box.height/2, handleSize) then
            return i, "edge_right", box
        end
    end
    return nil, nil, nil
end

-- Helper function to find which triangle vertex is clicked
local function findTriangleVertex(x, y)
    if not levelData.customTriangles then return nil, nil, nil end
    
    local handleSize = 8
    for i, triangle in ipairs(levelData.customTriangles) do
        local v1x, v1y = triangle.x + triangle.v1x, triangle.y + triangle.v1y
        local v2x, v2y = triangle.x + triangle.v2x, triangle.y + triangle.v2y
        local v3x, v3y = triangle.x + triangle.v3x, triangle.y + triangle.v3y
        
        if pointInHandle(x, y, v1x, v1y, handleSize) then
            return i, "v1", triangle
        elseif pointInHandle(x, y, v2x, v2y, handleSize) then
            return i, "v2", triangle
        elseif pointInHandle(x, y, v3x, v3y, handleSize) then
            return i, "v3", triangle
        end
    end
    return nil, nil, nil
end

-- Helper function to find which player handle is clicked
local function findPlayerHandle(x, y)
    if not levelData.playerStart then return nil, nil, nil end
    
    local player = levelData.playerStart
    local handleSize = 8
    
    -- Check corner handles
    if pointInHandle(x, y, player.x - player.width/2, player.y - player.height/2, handleSize) then
        return "corner_tl", player
    elseif pointInHandle(x, y, player.x + player.width/2, player.y - player.height/2, handleSize) then
        return "corner_tr", player
    elseif pointInHandle(x, y, player.x - player.width/2, player.y + player.height/2, handleSize) then
        return "corner_bl", player
    elseif pointInHandle(x, y, player.x + player.width/2, player.y + player.height/2, handleSize) then
        return "corner_br", player
    -- Check edge handles
    elseif pointInHandle(x, y, player.x, player.y - player.height/2, handleSize) then
        return "edge_top", player
    elseif pointInHandle(x, y, player.x, player.y + player.height/2, handleSize) then
        return "edge_bottom", player
    elseif pointInHandle(x, y, player.x - player.width/2, player.y, handleSize) then
        return "edge_left", player
    elseif pointInHandle(x, y, player.x + player.width/2, player.y, handleSize) then
        return "edge_right", player
    end
    return nil, nil
end

-- Helper function to find object at position
local function findObjectAt(x, y)
    -- Check player start
    if levelData.playerStart then
        local p = levelData.playerStart
        if pointInRect(x, y, p.x - p.width/2, p.y - p.height/2, p.width, p.height) then
            return "player", levelData.playerStart
        end
    end
    
    -- Check boxes
    for i, box in ipairs(levelData.boxes) do
        if pointInRect(x, y, box.x, box.y, box.width, box.height) then
            return "box", i
        end
    end
    
    -- Check scrolls
    for i, scroll in ipairs(levelData.scrolls) do
        if pointInRect(x, y, scroll.x - scroll.width/2, scroll.y - scroll.height/2, scroll.width, scroll.height) then
            return "scroll", i
        end
    end
    
    -- Check portals
    for i, portal in ipairs(levelData.portals) do
        if pointInRect(x, y, portal.x - portal.width/2, portal.y - portal.height/2, portal.width, portal.height) then
            return "portal", i
        end
    end
    
    -- Check triangles
    for i, triangle in ipairs(levelData.customTriangles) do
        -- Simple bounding box check for triangles
        local minX = math.min(triangle.x + triangle.v1x, triangle.x + triangle.v2x, triangle.x + triangle.v3x)
        local maxX = math.max(triangle.x + triangle.v1x, triangle.x + triangle.v2x, triangle.x + triangle.v3x)
        local minY = math.min(triangle.y + triangle.v1y, triangle.y + triangle.v2y, triangle.y + triangle.v3y)
        local maxY = math.max(triangle.y + triangle.v1y, triangle.y + triangle.v2y, triangle.y + triangle.v3y)
        
        if pointInRect(x, y, minX, minY, maxX - minX, maxY - minY) then
            return "triangle", i
        end
    end
    
    return nil, nil
end

-- Love2D callbacks
function love.load()
    love.window.setTitle("Level Editor - Spell Collector")
    font = love.graphics.newFont(14)
    
    -- Try to load background image
    local success, img = pcall(function()
        return love.graphics.newImage("gfx/background.jpg")
    end)
    if success then
        backgroundImage = img
    end
    
    -- Load default level
    loadLevel()
end

-- Helper function to handle box resizing
local function handleBoxResize(mx, my)
    local box = editorState.dragObject
    local handle = editorState.dragHandle
    
    if handle == "corner_tl" then
        local newWidth = box.x + box.width - mx
        local newHeight = box.y + box.height - my
        if newWidth > 10 and newHeight > 10 then
            box.width = newWidth
            box.height = newHeight
            box.x = mx
            box.y = my
        end
    elseif handle == "corner_tr" then
        local newWidth = mx - box.x
        local newHeight = box.y + box.height - my
        if newWidth > 10 and newHeight > 10 then
            box.width = newWidth
            box.height = newHeight
            box.y = my
        end
    elseif handle == "corner_bl" then
        local newWidth = box.x + box.width - mx
        local newHeight = my - box.y
        if newWidth > 10 and newHeight > 10 then
            box.width = newWidth
            box.height = newHeight
            box.x = mx
        end
    elseif handle == "corner_br" then
        local newWidth = mx - box.x
        local newHeight = my - box.y
        if newWidth > 10 and newHeight > 10 then
            box.width = newWidth
            box.height = newHeight
        end
    elseif handle == "edge_top" then
        local newHeight = box.y + box.height - my
        if newHeight > 10 then
            box.height = newHeight
            box.y = my
        end
    elseif handle == "edge_bottom" then
        local newHeight = my - box.y
        if newHeight > 10 then
            box.height = newHeight
        end
    elseif handle == "edge_left" then
        local newWidth = box.x + box.width - mx
        if newWidth > 10 then
            box.width = newWidth
            box.x = mx
        end
    elseif handle == "edge_right" then
        local newWidth = mx - box.x
        if newWidth > 10 then
            box.width = newWidth
        end
    end
end

-- Helper function to handle triangle vertex movement
local function handleTriangleVertexMove(mx, my)
    local triangle = editorState.dragObject
    local vertex = editorState.dragHandle
    
    if vertex == "v1" then
        triangle.v1x = mx - triangle.x
        triangle.v1y = my - triangle.y
    elseif vertex == "v2" then
        triangle.v2x = mx - triangle.x
        triangle.v2y = my - triangle.y
    elseif vertex == "v3" then
        triangle.v3x = mx - triangle.x
        triangle.v3y = my - triangle.y
    end
end

-- Helper function to handle object movement (boxes, scrolls, portals, player)
local function handleObjectMove(mx, my)
    local obj = editorState.dragObject
    
    if obj then
        -- Calculate offset from initial click position
        if not editorState.dragOffsetX then
            editorState.dragOffsetX = mx - obj.x
            editorState.dragOffsetY = my - obj.y
        end
        
        -- Move the object maintaining the offset
        obj.x = mx - editorState.dragOffsetX
        obj.y = my - editorState.dragOffsetY
    end
end

-- Helper function to handle triangle movement (special case - moves center point)
local function handleTriangleMove(mx, my)
    local triangle = editorState.dragObject
    
    if triangle then
        -- Move the triangle's center point
        triangle.x = mx
        triangle.y = my
    end
end

-- Helper function to handle player resizing
local function handlePlayerResize(mx, my)
    local player = editorState.dragObject
    local handle = editorState.dragHandle
    
    if handle == "corner_tl" then
        local newWidth = (player.x + player.width/2) - mx
        local newHeight = (player.y + player.height/2) - my
        if newWidth > 10 and newHeight > 10 then
            player.width = newWidth
            player.height = newHeight
            player.x = mx + newWidth/2
            player.y = my + newHeight/2
        end
    elseif handle == "corner_tr" then
        local newWidth = mx - (player.x - player.width/2)
        local newHeight = (player.y + player.height/2) - my
        if newWidth > 10 and newHeight > 10 then
            player.width = newWidth
            player.height = newHeight
            player.x = mx - newWidth/2
            player.y = my + newHeight/2
        end
    elseif handle == "corner_bl" then
        local newWidth = (player.x + player.width/2) - mx
        local newHeight = my - (player.y - player.height/2)
        if newWidth > 10 and newHeight > 10 then
            player.width = newWidth
            player.height = newHeight
            player.x = mx + newWidth/2
            player.y = my - newHeight/2
        end
    elseif handle == "corner_br" then
        local newWidth = mx - (player.x - player.width/2)
        local newHeight = my - (player.y - player.height/2)
        if newWidth > 10 and newHeight > 10 then
            player.width = newWidth
            player.height = newHeight
            player.x = mx - newWidth/2
            player.y = my - newHeight/2
        end
    elseif handle == "edge_top" then
        local newHeight = (player.y + player.height/2) - my
        if newHeight > 10 then
            player.height = newHeight
            player.y = my + newHeight/2
        end
    elseif handle == "edge_bottom" then
        local newHeight = my - (player.y - player.height/2)
        if newHeight > 10 then
            player.height = newHeight
            player.y = my - newHeight/2
        end
    elseif handle == "edge_left" then
        local newWidth = (player.x + player.width/2) - mx
        if newWidth > 10 then
            player.width = newWidth
            player.x = mx + newWidth/2
        end
    elseif handle == "edge_right" then
        local newWidth = mx - (player.x - player.width/2)
        if newWidth > 10 then
            player.width = newWidth
            player.x = mx - newWidth/2
        end
    end
end

function love.update(dt)
    cursorX, cursorY = getMousePosition()
    
    -- Handle dragging in edit mode
    if editorState.dragging and editorState.editMode then
        local mx, my = getMousePosition()
        
        if editorState.dragType == "player_resize" then
            handlePlayerResize(mx, my)
        elseif editorState.dragType == "box_resize" then
            handleBoxResize(mx, my)
        elseif editorState.dragType == "triangle_vertex" then
            handleTriangleVertexMove(mx, my)
        elseif editorState.dragType == "box_move" then
            handleObjectMove(mx, my)
        elseif editorState.dragType == "scroll_move" then
            handleObjectMove(mx, my)
        elseif editorState.dragType == "portal_move" then
            handleObjectMove(mx, my)
        elseif editorState.dragType == "triangle_move" then
            handleTriangleMove(mx, my)
        elseif editorState.dragType == "player_move" then
            handleObjectMove(mx, my)
        end
    end
end

function love.draw()
    -- Draw background
    if backgroundImage then
        local w, h = love.graphics.getWidth(), love.graphics.getHeight()
        local imgW, imgH = backgroundImage:getDimensions()
        local scaleX = w / imgW
        local scaleY = h / imgH
        love.graphics.setColor(1, 1, 1, 1) -- Full opacity
        love.graphics.draw(backgroundImage, 0, 0, 0, scaleX, scaleY)
    end
    
    -- Draw grid
    drawGrid()
    
    -- Draw level objects
    drawPlayerStart()
    drawBoxes()
    drawScrolls()
    drawPortals()
    drawTriangles()
    
    -- Draw cursor preview
    drawCursorPreview()
    
    -- Draw UI
    drawUI()
end

function love.mousepressed(x, y, button)
    if editorState.fileDialog.active then
        local dialog = editorState.fileDialog
        local dialogX = 200
        local dialogY = 100
        local listY = dialogY + 40
        local listH = 150
        
        -- Check if clicking on file list
        if x >= dialogX + 10 and x <= dialogX + 390 and y >= listY and y <= listY + listH then
            local fileIndex = math.floor((y - listY - 10) / 20) + 1
            if fileIndex >= 1 and fileIndex <= #dialog.files then
                dialog.selectedIndex = fileIndex
                dialog.inputText = dialog.files[fileIndex]:gsub("%.dat$", "") -- Remove .dat extension
            end
        end
        
        -- Check if clicking OK button
        local buttonY = listY + listH + 60
        if x >= dialogX + 10 and x <= dialogX + 90 and y >= buttonY and y <= buttonY + 30 then
            if dialog.mode == "save" then
                performSave(dialog.inputText)
            elseif dialog.mode == "load" then
                performLoad(dialog.inputText)
            end
            editorState.fileDialog.active = false
        end
        
        -- Check if clicking Cancel button
        if x >= dialogX + 100 and x <= dialogX + 180 and y >= buttonY and y <= buttonY + 30 then
            editorState.fileDialog.active = false
            editorState.lastAction = "Cancelled"
            editorState.lastActionTime = love.timer.getTime()
        end
    else
        local mx, my = getMousePosition()
        
        if button == 1 then -- Left click
            if editorState.editMode then
                -- Check for player handles first
                local playerHandleType, player = findPlayerHandle(mx, my)
                if playerHandleType then
                    editorState.dragging = true
                    editorState.dragType = "player_resize"
                    editorState.dragObject = player
                    editorState.dragHandle = playerHandleType
                    return
                end
                
                -- Check for box handles
                local boxIndex, handleType, box = findBoxHandle(mx, my)
                if boxIndex then
                    editorState.dragging = true
                    editorState.dragType = "box_resize"
                    editorState.dragObject = box
                    editorState.dragHandle = handleType
                    return
                end
                
                -- Check for triangle vertices
                local triIndex, vertexType, triangle = findTriangleVertex(mx, my)
                if triIndex then
                    editorState.dragging = true
                    editorState.dragType = "triangle_vertex"
                    editorState.dragObject = triangle
                    editorState.dragHandle = vertexType
                    return
                end
                
                -- Check for object dragging (clicking on objects to move them)
                local objType, objIndex = findObjectAt(mx, my)
                if objType == "box" then
                    editorState.dragging = true
                    editorState.dragType = "box_move"
                    editorState.dragObject = levelData.boxes[objIndex]
                    editorState.dragHandle = "move"
                    editorState.dragOffsetX = nil -- Reset offset
                    editorState.dragOffsetY = nil
                    return
                elseif objType == "scroll" then
                    editorState.dragging = true
                    editorState.dragType = "scroll_move"
                    editorState.dragObject = levelData.scrolls[objIndex]
                    editorState.dragHandle = "move"
                    editorState.dragOffsetX = nil -- Reset offset
                    editorState.dragOffsetY = nil
                    return
                elseif objType == "portal" then
                    editorState.dragging = true
                    editorState.dragType = "portal_move"
                    editorState.dragObject = levelData.portals[objIndex]
                    editorState.dragHandle = "move"
                    editorState.dragOffsetX = nil -- Reset offset
                    editorState.dragOffsetY = nil
                    return
                elseif objType == "triangle" then
                    editorState.dragging = true
                    editorState.dragType = "triangle_move"
                    editorState.dragObject = levelData.customTriangles[objIndex]
                    editorState.dragHandle = "move"
                    editorState.dragOffsetX = nil -- Reset offset
                    editorState.dragOffsetY = nil
                    return
                elseif objType == "player" then
                    editorState.dragging = true
                    editorState.dragType = "player_move"
                    editorState.dragObject = levelData.playerStart
                    editorState.dragHandle = "move"
                    editorState.dragOffsetX = nil -- Reset offset
                    editorState.dragOffsetY = nil
                    return
                end
            else
                -- Normal placement mode (only when NOT in edit mode)
                if editorState.mode == "player" then
                    levelData.playerStart = {x = mx, y = my, width = 165, height = 165}
                elseif editorState.mode == "box" then
                    table.insert(levelData.boxes, {x = mx, y = my, width = 80, height = 60, visible = true})
                elseif editorState.mode == "scroll" then
                    table.insert(levelData.scrolls, {x = mx, y = my, width = 100, height = 100})
                elseif editorState.mode == "portal" then
                    table.insert(levelData.portals, {x = mx, y = my, width = 100, height = 100, targetLevel = "level2"})
                elseif editorState.mode == "triangle" then
                    table.insert(levelData.customTriangles, {
                        x = mx, y = my,
                        v1x = 0, v1y = -20,
                        v2x = -20, v2y = 20,
                        v3x = 20, v3y = 20,
                        visible = true
                    })
                elseif editorState.mode == "visibility" then
                    -- Toggle visibility of clicked object
                    local objType, objIndex = findObjectAt(mx, my)
                    if objType == "box" and levelData.boxes[objIndex] then
                        levelData.boxes[objIndex].visible = not (levelData.boxes[objIndex].visible ~= false)
                        editorState.lastAction = "Box " .. objIndex .. " visibility: " .. (levelData.boxes[objIndex].visible and "ON" or "OFF")
                        editorState.lastActionTime = love.timer.getTime()
                    elseif objType == "triangle" and levelData.customTriangles[objIndex] then
                        levelData.customTriangles[objIndex].visible = not (levelData.customTriangles[objIndex].visible ~= false)
                        editorState.lastAction = "Triangle " .. objIndex .. " visibility: " .. (levelData.customTriangles[objIndex].visible and "ON" or "OFF")
                        editorState.lastActionTime = love.timer.getTime()
                    end
                end
            end
        elseif button == 2 then -- Right click - delete
            local objType, objIndex = findObjectAt(mx, my)
            if objType == "player" then
                levelData.playerStart = nil
            elseif objType == "box" then
                table.remove(levelData.boxes, objIndex)
            elseif objType == "scroll" then
                table.remove(levelData.scrolls, objIndex)
            elseif objType == "portal" then
                table.remove(levelData.portals, objIndex)
            elseif objType == "triangle" then
                table.remove(levelData.customTriangles, objIndex)
            end
        end
    end
end

function love.mousereleased(x, y, button)
    if button == 1 and editorState.dragging then
        editorState.dragging = false
        editorState.dragType = nil
        editorState.dragObject = nil
        editorState.dragHandle = nil
        editorState.dragOffsetX = nil
        editorState.dragOffsetY = nil
    end
end

function love.keypressed(key)
    if editorState.fileDialog.active then
        local dialog = editorState.fileDialog
        if key == "up" then
            dialog.selectedIndex = math.max(1, dialog.selectedIndex - 1)
        elseif key == "down" then
            dialog.selectedIndex = math.min(#dialog.files, dialog.selectedIndex + 1)
        elseif key == "return" or key == "kpenter" then
            -- Confirm selection
            if dialog.mode == "save" then
                performSave(dialog.inputText)
            elseif dialog.mode == "load" then
                performLoad(dialog.inputText)
            end
            editorState.fileDialog.active = false
        elseif key == "escape" then
            -- Cancel dialog
            editorState.fileDialog.active = false
            editorState.lastAction = "Cancelled"
            editorState.lastActionTime = love.timer.getTime()
        elseif key == "backspace" then
            -- Delete last character from input
            dialog.inputText = string.sub(dialog.inputText, 1, -2)
        end
    else
        if key == "1" then
            editorState.mode = "player"
        elseif key == "2" then
            editorState.mode = "box"
        elseif key == "3" then
            editorState.mode = "scroll"
        elseif key == "4" then
            editorState.mode = "portal"
        elseif key == "5" then
            editorState.mode = "triangle"
        elseif key == "6" then
            editorState.mode = "visibility"
        elseif key == "g" then
            editorState.showGrid = not editorState.showGrid
        elseif key == "e" then
            editorState.editMode = not editorState.editMode
            editorState.dragging = false
            editorState.dragType = nil
            editorState.dragObject = nil
            editorState.dragHandle = nil
        elseif key == "s" then
            saveLevel()
        elseif key == "l" then
            loadLevel()
        elseif key == "c" then
            clearLevel()
        elseif key == "escape" then
            love.event.quit()
        end
    end
end

function love.textinput(text)
    if editorState.fileDialog.active then
        if editorState.fileDialog.justOpened then
            -- Ignore the first key press (S or L)
            editorState.fileDialog.justOpened = false
        else
            editorState.fileDialog.inputText = editorState.fileDialog.inputText .. text
        end
    end
end
