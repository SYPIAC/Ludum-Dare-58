-- Configuration for Level Editor
function love.conf(t)
    t.title = "Level Editor - Spell Collector"
    t.author = "Spell Collector Team"
    t.version = "11.4"
    
    -- Window settings
    t.window.width = 1024
    t.window.height = 768
    t.window.resizable = true
    t.window.minwidth = 800
    t.window.minheight = 600
    
    -- Disable unused modules for better performance
    t.modules.joystick = false
    t.modules.physics = false
    t.modules.sound = false
    t.modules.touch = false
end
