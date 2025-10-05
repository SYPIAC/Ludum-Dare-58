# Level Editor for Spell Collector

A basic keyboard-operated level editor for creating and editing levels in the Spell Collector game.

## How to Run

1. Make sure Love2D is installed on your system
2. Run the level editor with: `love levelEditor`
3. Or use the batch file: `run_editor.bat`

## Project Structure

```
levelEditor/
├── main.lua          # Level editor code
├── conf.lua          # Love2D configuration
├── level1.dat        # Sample level data
└── level_editor.dat  # Your saved levels
```

The level editor uses the main project's `gfx/` folder for graphics assets (no duplicate needed).

## Controls

### Mode Selection
- **1** - Player Start (P) - Place where the wizard starts
- **2** - Box (B) - Static rectangular obstacles
- **3** - Scroll (S) - Collectible scrolls
- **4** - Portal (E) - Exit portals to other levels
- **5** - Triangle (T) - Static triangular obstacles

### Editing
- **Left Click** - Place object in current mode
- **Right Click** - Delete object at cursor position
- **G** - Toggle grid display
- **S** - Save level to `level_editor.dat`
- **L** - Load level from `level1.dat`
- **C** - Clear all objects
- **ESC** - Exit editor

## Features

- **Visual Grid**: Optional grid for precise placement
- **Object Preview**: See what you're placing before clicking
- **Multiple Object Types**: Player start, boxes, scrolls, portals, and triangles
- **Save/Load**: Save your levels and load existing ones
- **Delete Objects**: Right-click to remove objects
- **Visual Feedback**: Different colors for different object types

## Object Types

1. **Player Start (Blue)**: Where the wizard spawns
2. **Boxes (Brown)**: Static rectangular obstacles
3. **Scrolls (Gold)**: Collectible items
4. **Portals (Blue)**: Exit points to other levels
5. **Triangles (Green)**: Static triangular obstacles

## File Format

The level editor saves to the same format as `level1.dat`, making it compatible with the main game. Saved levels can be loaded directly in the main game by renaming the file.

## Usage Tips

- Use the grid (G key) for precise placement
- Start by placing the player start position
- Add obstacles (boxes/triangles) to create challenges
- Place scrolls for collectibles
- Add portals for level progression
- Save frequently (S key) to avoid losing work

## Integration with Main Game

To use a level created in the editor:

1. Save your level in the editor (S key)
2. Rename `level_editor.dat` to your desired level name (e.g., `level2.dat`)
3. The main game will automatically load the level when you call `loadLevel("level2.dat")`

The level editor creates files in the exact same format as the original `level1.dat`, ensuring full compatibility with the main game.
