-- Spellbook module for Spell Collector
-- Handles grimoire, spell effects, and spell casting

local Spellbook = {}

-- Spellbook state
local grimoireOpen = false
local currentPage = 1
local activeSpellEffects = {} -- Currently active spell effects

-- Spell effect system
local spellEffects = {
	["Become Green"] = {
		normalImage = "wizardGreenImage",
		castingImage = "wizardGreenCastingImage",
		description = "You feel your skin tingling with magical energy as you turn a vibrant shade of green."
	}
	-- Future spells can be added here easily
}

local spells = {
	[1] = {
		name = "Become Green",
		description = "Transform yourself into a vibrant green color, granting camouflage in forest environments.",
		image = "icon_1.png"
	},
	[2] = { name = "???", description = "Hidden beneath the forest temple", image = "???" },
	[3] = { name = "???", description = "Follow us on Twitter to unlock this spell", image = "???" },
	[4] = { name = "???", description = "Available now for owners of 'Spell Collector: Season 1 Pass'", image = "???" }
}

local magicSchool = "Transmutation"
local bookmarks = {"Transmutation", "Evocation", "Abjuration", "Sleep", "Disenchantment"}

-- Initialize the spellbook system
function Spellbook.init()
	-- Any initialization code can go here
end

-- Toggle grimoire open/closed
function Spellbook.toggleGrimoire()
	grimoireOpen = not grimoireOpen
end

-- Check if grimoire is open
function Spellbook.isGrimoireOpen()
	return grimoireOpen
end

-- Cast a spell
function Spellbook.castSpell(spellName)
	if spellEffects[spellName] then
		activeSpellEffects[spellName] = true
		print("Cast: " .. spellName .. " - " .. spellEffects[spellName].description)
	end
end

-- Get active spell effects
function Spellbook.getActiveSpellEffects()
	return activeSpellEffects
end

-- Get spells data
function Spellbook.getSpells()
	return spells
end

-- Get magic school
function Spellbook.getMagicSchool()
	return magicSchool
end

-- Get bookmarks
function Spellbook.getBookmarks()
	return bookmarks
end

-- Get current page
function Spellbook.getCurrentPage()
	return currentPage
end


-- Check if a spell can be cast (not ???)
function Spellbook.canCastSpell(spellName)
	return spellName ~= "???" and spellEffects[spellName] ~= nil
end

-- Get spell effect data
function Spellbook.getSpellEffect(spellName)
	return spellEffects[spellName]
end

-- Get all unique spell images that need to be loaded
function Spellbook.getSpellImages()
	local images = {}
	for _, spell in pairs(spells) do
		if spell.image and spell.image ~= "???" and not images[spell.image] then
			images[spell.image] = true
		end
	end
	return images
end

-- Get image path for a specific spell
function Spellbook.getSpellImage(spellName)
	for _, spell in pairs(spells) do
		if spell.name == spellName then
			return spell.image
		end
	end
	return nil
end

return Spellbook
