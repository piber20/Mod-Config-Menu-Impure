----------------------
-- Version Handling --
----------------------
-- Chifilly's Mod Config Menu fork was 33.
-- The "pure" version selected a starting point of 100 and incremented
-- We'll start with 200 and increment. We'll display it as 2.00.
local VERSION = 201

-- Prevent older/same versions of this script from loading
if MCM and MCM.Version and MCM.Version >= VERSION then
	return MCM
end

-- Handle old versions
local oldVersion = nil
if (ModConfigMenu and not MCM) or (MCM and MCM.Version and MCM.Version < VERSION) then
	if not MCM then
		MCM = ModConfigMenu
	end

	oldVersion = MCM.Version

	if MCM.MenuData then
		for i=#MCM.MenuData, 1, -1 do
			if MCM.MenuData[i].Name == "General" or MCM.MenuData[i].Name == "Mod Config Menu" then
				MCM.MenuData[i] = nil
			end
		end
	end
	
	if MCM.PostGameStarted then
		if MCM.Mod.RemoveCustomCallback then
			MCM.Mod:RemoveCustomCallback(CustomCallbacks.CCH_GAME_STARTED, MCM.PostGameStarted)
		else
			MCM.Mod.RemoveCallback(ModCallbacks.MC_POST_GAME_STARTED, MCM.PostGameStarted)
		end
	end
	
	if MCM.PostUpdate then
		MCM.Mod:RemoveCallback(ModCallbacks.MC_POST_UPDATE, MCM.PostUpdate)
	end
	if MCM.PostRender then
		MCM.Mod:RemoveCallback(ModCallbacks.MC_POST_RENDER, MCM.PostRender)
	end
	if MCM.InputAction then
		MCM.Mod:RemoveCallback(ModCallbacks.MC_INPUT_ACTION, MCM.InputAction)
	end
	if MCM.ExecuteCmd then
		MCM.Mod:RemoveCallback(ModCallbacks.MC_EXECUTE_CMD, MCM.ExecuteCmd)
	end
end

----------
-- Init --
----------
if not MCM then
	MCM = {}
end
MCM.Version = VERSION

function MCM.GetVersionString(override)

	local versionNum = MCM.Version
	if override then
		versionNum = override
	end

	local versionMain = math.floor(versionNum*0.01)
	local versionSub = versionNum - (versionMain*100)
	local versionString = "" .. versionMain .. "." .. versionSub

	return versionString

end

Isaac.DebugString("Loading Mod Config Menu v" .. MCM.GetVersionString() .. "...")
if oldVersion then
	Isaac.DebugString("Removed old version: v" .. MCM.GetVersionString(oldVersion))
end

local vecZero = Vector(0,0)

---------------
-- Libraries --
---------------
-- Function that makes it easy to load scripts regardless of DLC
function MCM.Exec(path)
	if type(include) == "function" then
		return include(path) --repentance
	else
		return require(path) --afterbirth+
	end
end
local function exec(path)
	return MCM.Exec(path)
end

local json = require("json")

--load other scripts
if not CustomCallbackHelper then
	exec("scripts.customcallbacks")
end

if not SaveHelper then
	exec("scripts.savehelper")
	if not SaveHelper then
		error("Mod Config Menu requires Save Helper to function", 2)
	end
end

--create the mod
MCM.Mod = MCM.Mod or RegisterMod("Mod Config Menu", 1)


----------
--Tables--
----------
function MCM.CopyTable(tableToCopy)
	local table2 = {}
	for i, value in pairs(tableToCopy) do
		if type(value) == "table" then
			table2[i] = MCM.CopyTable(value)
		else
			table2[i] = value
		end
	end
	return table2
end

function MCM.FillTable(tableToFill, tableToFillFrom)
	for i, value in pairs(tableToFillFrom) do
		if tableToFill[i] ~= nil then
			if type(value) == "table" then
				if type(tableToFill[i]) ~= "table" then
					tableToFill[i] = {}
				end
				tableToFill[i] = MCM.FillTable(tableToFill[i], value)
			else
				tableToFill[i] = value
			end
		else
			if type(value) == "table" then
				if type(tableToFill[i]) ~= "table" then
					tableToFill[i] = {}
				end
				tableToFill[i] = MCM.FillTable({}, value)
			else
				tableToFill[i] = value
			end
		end
	end
	return tableToFill
end

---------
--Input--
---------
--Use in place of Keyboard enum to check for controller inputs
Controller = Controller or {}
Controller.DPAD_LEFT = 0
Controller.DPAD_RIGHT = 1
Controller.DPAD_UP = 2
Controller.DPAD_DOWN = 3
Controller.BUTTON_A = 4
Controller.BUTTON_B = 5
Controller.BUTTON_X = 6
Controller.BUTTON_Y = 7
Controller.BUMPER_LEFT = 8
Controller.TRIGGER_LEFT = 9
Controller.STICK_LEFT = 10
Controller.BUMPER_RIGHT = 11
Controller.TRIGGER_RIGHT = 12
Controller.STICK_RIGHT = 13
Controller.BUTTON_BACK = 14
Controller.BUTTON_START = 15

--Helps with displaying buttons
MCM.KeyboardToString = MCM.KeyboardToString or {}
for key,num in pairs(Keyboard) do
	local keyString = key
	local keyStart, keyEnd = string.find(keyString, "KEY_")
	keyString = string.sub(keyString, keyEnd+1, string.len(keyString))
	keyString = string.gsub(keyString, "_", " ")
	MCM.KeyboardToString[num] = keyString
end

MCM.ControllerToString = MCM.ControllerToString or {}
for button,num in pairs(Controller) do
	local buttonString = button
	if string.match(buttonString, "BUTTON_") then
		local buttonStart, buttonEnd = string.find(buttonString, "BUTTON_")
		buttonString = string.sub(buttonString, buttonEnd+1, string.len(buttonString))
	end
	if string.match(buttonString, "BUMPER_") then
		local bumperStart, bumperEnd = string.find(buttonString, "BUMPER_")
		buttonString = string.sub(buttonString, bumperEnd+1, string.len(buttonString)) .. "_BUMPER"
	end
	if string.match(buttonString, "TRIGGER_") then
		local triggerStart, triggerEnd = string.find(buttonString, "TRIGGER_")
		buttonString = string.sub(buttonString, triggerEnd+1, string.len(buttonString)) .. "_TRIGGER"
	end
	if string.match(buttonString, "STICK_") then
		local stickStart, stickEnd = string.find(buttonString, "STICK_")
		buttonString = string.sub(buttonString, stickEnd+1, string.len(buttonString)) .. "_STICK"
	end
	buttonString = string.gsub(buttonString, "_", " ")
	MCM.ControllerToString[num] = buttonString
end

--Work around a bug related to controller inputs
function MCM.KeyboardTriggered(key, controllerIndex)
	return Input.IsButtonTriggered(key, controllerIndex) and not Input.IsButtonTriggered(key % 32, controllerIndex)
end
function MCM.KeyboardPressed(key, controllerIndex)
	return Input.IsButtonPressed(key, controllerIndex) and not Input.IsButtonPressed(key % 32, controllerIndex)
end

--Multiple triggered functions
function MCM.MultipleActionTriggered(actions, controllerIndex, func)
	local func = func or Input.IsActionTriggered
	for i,action in pairs(actions) do
		for index=0, 4 do
			if controllerIndex ~= nil then
				index = controllerIndex
			end
			if func(action, index) then
				return action
			end
			if controllerIndex ~= nil then
				break
			end
		end
	end
	return nil
end
function MCM.MultipleActionPressed(actions, controllerIndex)
	return MCM.MultipleActionTriggered(actions, controllerIndex, Input.IsActionPressed)
end
function MCM.MultipleButtonTriggered(buttons, controllerIndex)
	return MCM.MultipleActionTriggered(buttons, controllerIndex, Input.IsButtonTriggered)
end
function MCM.MultipleButtonPressed(buttons, controllerIndex)
	return MCM.MultipleActionTriggered(buttons, controllerIndex, Input.IsButtonPressed)
end
function MCM.MultipleKeyboardTriggered(keys, controllerIndex)
	return MCM.MultipleActionTriggered(keys, controllerIndex, MCM.KeyboardTriggered)
end
function MCM.MultipleKeyboardPressed(keys, controllerIndex)
	return MCM.MultipleActionTriggered(keys, controllerIndex, MCM.KeyboardPressed)
end

--force inputs
local forcingActionTriggered = {}
function MCM.ForceActionTriggered(controllerIndex, buttonAction, value)
	forcingActionTriggered[controllerIndex] = forcingActionTriggered[controllerIndex] or {}
	forcingActionTriggered[controllerIndex][buttonAction] = value
end

local forcingActionPressed = {}
local forcingActionPressedTimer = {}
function MCM.ForceActionPressed(controllerIndex, buttonAction, value, timer)
	forcingActionPressed[controllerIndex] = forcingActionPressed[controllerIndex] or {}
	forcingActionPressed[controllerIndex][buttonAction] = value
	timer = timer or 1
	forcingActionPressedTimer[controllerIndex] = forcingActionPressedTimer[controllerIndex] or {}
	forcingActionPressedTimer[controllerIndex][buttonAction] = timer
end

function MCM.HandleForceActionPressed(_, entity, inputHook, buttonAction)
	if entity and entity:ToPlayer() then
		local player = entity:ToPlayer()
		local controllerIndex = player.ControllerIndex
		if inputHook == InputHook.IS_ACTION_TRIGGERED then
			if forcingActionTriggered[controllerIndex] and forcingActionTriggered[controllerIndex][buttonAction] ~= nil then
				local toReturn = forcingActionTriggered[controllerIndex][buttonAction]
				forcingActionTriggered[controllerIndex][buttonAction] = nil
				return toReturn
			end
		elseif inputHook == InputHook.IS_ACTION_PRESSED then
			if forcingActionPressed[controllerIndex] and forcingActionPressed[controllerIndex][buttonAction] ~= nil then
				local toReturn = forcingActionPressed[controllerIndex][buttonAction]
				forcingActionPressedTimer[controllerIndex][buttonAction] = forcingActionPressedTimer[controllerIndex][buttonAction] - 1
				if forcingActionPressedTimer[controllerIndex][buttonAction] <= 0 then
					forcingActionPressed[controllerIndex][buttonAction] = nil
				end
				return toReturn
			end
		end
	end
end
MCM.Mod:AddCallback(ModCallbacks.MC_INPUT_ACTION, MCM.HandleForceActionPressed)


-------------------
--CUSTOM CALLBACK--
-------------------
--triggered after a setting is changed
--function(settingTable, currentSetting)
--extra variable 1 is the category of the setting, extra variable 2 is the attribute that gets saved to the config table. these are both optional
CustomCallbacks.MCM_POST_MODIFY_SETTING = 4200


----------
--SAVING--
----------

MCM.SetConfigMetatables = MCM.SetConfigMetatables or function() end

MCM.ConfigDefault = MCM.ConfigDefault or {}
MCM.FillTable(MCM.ConfigDefault,{
	
	--last button pressed tracker
	LastBackPressed = Keyboard.KEY_ESCAPE,
	LastSelectPressed = Keyboard.KEY_ENTER
	
})
MCM.Config = MCM.Config or {}
MCM.FillTable(MCM.Config, MCM.ConfigDefault)

MCM.SetConfigMetatables()

function MCM.GetSave()
	
	local saveData = MCM.CopyTable(MCM.ConfigDefault)
	saveData = MCM.FillTable(saveData, MCM.Config)
	
	saveData = json.encode(saveData)
	
	return saveData
	
end

function MCM.LoadSave(fromData)

	if fromData and ((type(fromData) == "string" and json.decode(fromData)) or type(fromData) == "table") then
	
		local saveData = MCM.CopyTable(MCM.ConfigDefault)
		
		if type(fromData) == "string" then
			fromData = json.decode(fromData)
		end
		saveData = MCM.FillTable(saveData, fromData)
		
		local currentData = MCM.CopyTable(MCM.Config)
		saveData = MCM.FillTable(currentData, saveData)
		
		MCM.Config = MCM.CopyTable(saveData)
		MCM.SetConfigMetatables()
		if Options then
			MCM.CurrentScreenOffset = math.min(math.max(math.floor(Options.HUDOffset*10),0),10)
		else
			MCM.SetOffset(MCM.Config["General"].HudOffset)
		end

		return saveData
		
	end
	
end


--------------
--game start--
--------------
local versionPrintFont = Font()
versionPrintFont:Load("font/pftempestasevencondensed.fnt")

--returns true if the room is clear and there are no active enemies and there are no projectiles
MCM.IgnoreActiveEnemies = MCM.IgnoreActiveEnemies or {}
function MCM.RoomIsSafe()

	local roomHasDanger = false
	
	for _, entity in pairs(Isaac.GetRoomEntities()) do
		if entity:IsActiveEnemy() and not entity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
		and (not MCM.IgnoreActiveEnemies[entity.Type] or (MCM.IgnoreActiveEnemies[entity.Type] and not MCM.IgnoreActiveEnemies[entity.Type][-1] and not MCM.IgnoreActiveEnemies[entity.Type][entity.Variant])) then
			roomHasDanger = true
		elseif entity.Type == EntityType.ENTITY_PROJECTILE and entity:ToProjectile().ProjectileFlags & ProjectileFlags.CANT_HIT_PLAYER ~= 1 then
			roomHasDanger = true
		elseif entity.Type == EntityType.ENTITY_BOMBDROP then
			roomHasDanger = true
		end
	end
	
	local game = Game()
	local room = game:GetRoom()
	
	if room:IsClear() and not roomHasDanger then
		return true
	end
	
	return false
	
end

local versionPrintTimer = 0
local isFirstRun
MCM.IsVisible = false
function MCM.PostGameStarted()

	rerunWarnMessage = nil

	if MCM.Config["Mod Config Menu"].ShowControls and isFirstRun then
		versionPrintTimer = 120
		isFirstRun = false
	end
	
	MCM.IsVisible = false
	
	--add potato dummy to ignore list
	local potatoType = Isaac.GetEntityTypeByName("Potato Dummy")
	local potatoVariant = Isaac.GetEntityVariantByName("Potato Dummy")
	
	if potatoType and potatoType > 0 then
		MCM.IgnoreActiveEnemies[potatoType] = MCM.IgnoreActiveEnemies or {}
		MCM.IgnoreActiveEnemies[potatoType][potatoVariant] = true
	end
	
end
if MCM.Mod.AddCustomCallback then
	MCM.Mod:AddCustomCallback(CustomCallbacks.CCH_GAME_STARTED, MCM.PostGameStarted)
else
	MCM.Mod.AddCallback(ModCallbacks.MC_POST_GAME_STARTED, MCM.PostGameStarted)
end


---------------
--post update--
---------------
function MCM.PostUpdate()

	if versionPrintTimer > 0 then
	
		versionPrintTimer = versionPrintTimer - 1
		
	end
	
end
MCM.Mod:AddCallback(ModCallbacks.MC_POST_UPDATE, MCM.PostUpdate)


------------------------------------
--set up the menu sprites and font--
------------------------------------
function MCM.GetMenuAnm2Sprite(animation, frame, color, anm2)

	anm2 = anm2 or "gfx/ui/modconfig/menu.anm2"
	local sprite = Sprite()
	
	sprite:Load(anm2, true)
	sprite:SetFrame(animation or "Idle", frame or 0)
	
	if color then
		sprite.Color = color
	end
	
	return sprite
	
end

--main menu sprites
local MenuSprite = MCM.GetMenuAnm2Sprite("Idle", 0)
local MenuOverlaySprite = MCM.GetMenuAnm2Sprite("IdleOverlay", 0)
local PopupSprite = MCM.GetMenuAnm2Sprite("Popup", 0)

--main cursors
local CursorSpriteRight = MCM.GetMenuAnm2Sprite("Cursor", 0)
local CursorSpriteUp = MCM.GetMenuAnm2Sprite("Cursor", 1)
local CursorSpriteDown = MCM.GetMenuAnm2Sprite("Cursor", 2)

--colors
local colorDefault = Color(1,1,1,1,0,0,0)
local colorHalf = Color(1,1,1,0.5,0,0,0)

--subcategory pane cursors
local SubcategoryCursorSpriteLeft = MCM.GetMenuAnm2Sprite("Cursor", 3, colorHalf)
local SubcategoryCursorSpriteRight = MCM.GetMenuAnm2Sprite("Cursor", 0, colorHalf)

--options pane cursors
local OptionsCursorSpriteUp = MCM.GetMenuAnm2Sprite("Cursor", 1, colorHalf)
local OptionsCursorSpriteDown = MCM.GetMenuAnm2Sprite("Cursor", 2, colorHalf)

--other options pane objects
local SubcategoryDividerSprite = MCM.GetMenuAnm2Sprite("Divider", 0, colorHalf)
local SliderSprite = MCM.GetMenuAnm2Sprite("Slider1", 0)

--strikeout
local StrikeOutSprite = MCM.GetMenuAnm2Sprite("Strikeout", 0)

--back/select corner papers
local CornerSelect = MCM.GetMenuAnm2Sprite("BackSelect", 0)
local CornerBack = MCM.GetMenuAnm2Sprite("BackSelect", 1)
local CornerOpen = MCM.GetMenuAnm2Sprite("BackSelect", 2)
local CornerExit = MCM.GetMenuAnm2Sprite("BackSelect", 3)

--fonts
local Font10 = Font()
Font10:Load("font/teammeatfont10.fnt")

local Font12 = Font()
Font12:Load("font/teammeatfont12.fnt")

local Font16Bold = Font()
Font16Bold:Load("font/teammeatfont16bold.fnt")

--popups
MCM.PopupGfx = MCM.PopupGfx or {}
MCM.PopupGfx.THIN_SMALL = "gfx/ui/modconfig/popup_thin_small.png"
MCM.PopupGfx.THIN_MEDIUM = "gfx/ui/modconfig/popup_thin_medium.png"
MCM.PopupGfx.THIN_LARGE = "gfx/ui/modconfig/popup_thin_large.png"
MCM.PopupGfx.WIDE_SMALL = "gfx/ui/modconfig/popup_wide_small.png"
MCM.PopupGfx.WIDE_MEDIUM = "gfx/ui/modconfig/popup_wide_medium.png"
MCM.PopupGfx.WIDE_LARGE = "gfx/ui/modconfig/popup_wide_large.png"


-------------------------
--add setting functions--
-------------------------
MCM.OptionType = MCM.OptionType or {}
MCM.OptionType.TEXT = 1
MCM.OptionType.SPACE = 2
MCM.OptionType.SCROLL = 3
MCM.OptionType.BOOLEAN = 4
MCM.OptionType.NUMBER = 5
MCM.OptionType.KEYBIND_KEYBOARD = 6
MCM.OptionType.KEYBIND_CONTROLLER = 7
MCM.OptionType.TITLE = 8

MCM.MenuData = MCM.MenuData or {}

--CATEGORY FUNCTIONS
function MCM.GetCategoryIDByName(categoryName)

	if type(categoryName) ~= "string" then
		return categoryName
	end
	
	local categoryID = nil
	
	for i=1, #MCM.MenuData do
		if categoryName == MCM.MenuData[i].Name then
			categoryID = i
			break
		end
	end
	
	return categoryID
	
end

function MCM.UpdateCategory(categoryName, dataTable)

	if type(categoryName) ~= "string" and type(categoryName) ~= "number" then
		error("MCM.UpdateCategory - No valid category name provided", 2)
	end
	
	local categoryID = MCM.GetCategoryIDByName(categoryName)
	if categoryID == nil then
		categoryID = #MCM.MenuData+1
		MCM.MenuData[categoryID] = {}
		MCM.MenuData[categoryID].Subcategories = {}
	end
	
	if type(categoryName) == "string" or dataTable.Name then
		MCM.MenuData[categoryID].Name = dataTable.Name or categoryName
	end
	
	if dataTable.Info then
		MCM.MenuData[categoryID].Info = dataTable.Info
	end
	
	if dataTable.IsOld then
		MCM.MenuData[categoryID].IsOld = dataTable.IsOld
	end
	
end

function MCM.SetCategoryInfo(categoryName, info)

	if type(categoryName) ~= "string" and type(categoryName) ~= "number" then
		error("MCM.SetCategoryInfo - No valid category name provided", 2)
	end

	MCM.UpdateCategory(categoryName, {
		Info = info
	})
	
end

function MCM.RemoveCategory(categoryName)

	if type(categoryName) ~= "string" and type(categoryName) ~= "number" then
		error("MCM.RemoveCategory - No valid category name provided", 2)
	end
	
	local categoryID = MCM.GetCategoryIDByName(categoryName)
	if categoryID then
	
		table.remove(MCM.MenuData, categoryID)
		return true
		
	end
	
	return false

end

--SUBCATEGORY FUNCTIONS
function MCM.GetSubcategoryIDByName(categoryName, subcategoryName)

	if type(categoryName) ~= "string" and type(categoryName) ~= "number" then
		error("MCM.GetSubcategoryIDByName - No valid category name provided", 2)
	end
	
	local categoryID = MCM.GetCategoryIDByName(categoryName)

	if type(subcategoryName) ~= "string" then
		return subcategoryName
	end
	
	local subcategoryID = nil
	
	for i=1, #MCM.MenuData[categoryID].Subcategories do
		if subcategoryName == MCM.MenuData[categoryID].Subcategories[i].Name then
			subcategoryID = i
			break
		end
	end
	
	return subcategoryID
	
end

function MCM.UpdateSubcategory(categoryName, subcategoryName, dataTable)

	if type(categoryName) ~= "string" and type(categoryName) ~= "number" then
		error("MCM.UpdateSubcategory - No valid category name provided", 2)
	end

	if type(subcategoryName) ~= "string" and type(subcategoryName) ~= "number" then
		error("MCM.UpdateSubcategory - No valid subcategory name provided", 2)
	end
	
	local categoryID = MCM.GetCategoryIDByName(categoryName)
	if categoryID == nil then
		categoryID = #MCM.MenuData+1
		MCM.MenuData[categoryID] = {}
		MCM.MenuData[categoryID].Name = tostring(categoryName)
		MCM.MenuData[categoryID].Subcategories = {}
	end
	
	local subcategoryID = MCM.GetSubcategoryIDByName(categoryID, subcategoryName)
	if subcategoryID == nil then
		subcategoryID = #MCM.MenuData[categoryID].Subcategories+1
		MCM.MenuData[categoryID].Subcategories[subcategoryID] = {}
		MCM.MenuData[categoryID].Subcategories[subcategoryID].Options = {}
	end
	
	if type(subcategoryName) == "string" or dataTable.Name then
		MCM.MenuData[categoryID].Subcategories[subcategoryID].Name = dataTable.Name or subcategoryName
	end
	
	if dataTable.Info then
		MCM.MenuData[categoryID].Subcategories[subcategoryID].Info = dataTable.Info
	end
	
end

function MCM.RemoveSubcategory(categoryName, subcategoryName)

	if type(categoryName) ~= "string" and type(categoryName) ~= "number" then
		error("MCM.RemoveSubcategory - No valid category name provided", 2)
	end

	if type(subcategoryName) ~= "string" and type(subcategoryName) ~= "number" then
		error("MCM.RemoveSubcategory - No valid subcategory name provided", 2)
	end
	
	local categoryID = MCM.GetCategoryIDByName(categoryName)
	if categoryID then
	
		local subcategoryID = MCM.GetSubcategoryIDByName(categoryID, subcategoryName)
		if subcategoryID then
		
			table.remove(MCM.MenuData[categoryID].Subcategories, subcategoryID)
			return true
			
		end
		
	end
	
	return false

end

--SETTING FUNCTIONS
function MCM.AddSetting(categoryName, subcategoryName, settingTable)

	if settingTable == nil then
		settingTable = subcategoryName
		subcategoryName = nil
	end

	if type(categoryName) ~= "string" and type(categoryName) ~= "number" then
		error("MCM.AddSetting - No valid category name provided", 2)
	end
	
	subcategoryName = subcategoryName or "Uncategorized"
	if type(subcategoryName) ~= "string" and type(subcategoryName) ~= "number" then
		error("MCM.AddSetting - No valid subcategory name provided", 2)
	end
	
	local categoryID = MCM.GetCategoryIDByName(categoryName)
	if categoryID == nil then
		categoryID = #MCM.MenuData+1
		MCM.MenuData[categoryID] = {}
		MCM.MenuData[categoryID].Name = tostring(categoryName)
		MCM.MenuData[categoryID].Subcategories = {}
	end
	
	local subcategoryID = MCM.GetSubcategoryIDByName(categoryID, subcategoryName)
	if subcategoryID == nil then
		subcategoryID = #MCM.MenuData[categoryID].Subcategories+1
		MCM.MenuData[categoryID].Subcategories[subcategoryID] = {}
		MCM.MenuData[categoryID].Subcategories[subcategoryID].Name = tostring(subcategoryName)
		MCM.MenuData[categoryID].Subcategories[subcategoryID].Options = {}
	end
	
	MCM.MenuData[categoryID].Subcategories[subcategoryID].Options[#MCM.MenuData[categoryID].Subcategories[subcategoryID].Options+1] = settingTable
	
	return settingTable
	
end

function MCM.AddText(categoryName, subcategoryName, text, color)

	if color == nil and type(text) ~= "string" and type(text) ~= "function" then
		color = text
		text = subcategoryName
		subcategoryName = nil
	end

	if type(categoryName) ~= "string" and type(categoryName) ~= "number" then
		error("MCM.AddText - No valid category name provided", 2)
	end
	
	subcategoryName = subcategoryName or "Uncategorized"
	if type(subcategoryName) ~= "string" and type(subcategoryName) ~= "number" then
		error("MCM.AddText - No valid subcategory name provided", 2)
	end
	
	local settingTable = {
		Type = MCM.OptionType.TEXT,
		Display = text,
		Color = color,
		NoCursorHere = true
	}
	
	return MCM.AddSetting(categoryName, subcategoryName, settingTable)
	
end

function MCM.AddTitle(categoryName, subcategoryName, text, color)

	if color == nil and type(text) ~= "string" and type(text) ~= "function" then
		color = text
		text = subcategoryName
		subcategoryName = nil
	end
	
	if type(categoryName) ~= "string" and type(categoryName) ~= "number" then
		error("MCM.AddTitle - No valid category name provided", 2)
	end
	
	subcategoryName = subcategoryName or "Uncategorized"
	if type(subcategoryName) ~= "string" and type(subcategoryName) ~= "number" then
		error("MCM.AddTitle - No valid subcategory name provided", 2)
	end
	
	local settingTable = {
		Type = MCM.OptionType.TITLE,
		Display = text,
		Color = color,
		NoCursorHere = true
	}
	
	return MCM.AddSetting(categoryName, subcategoryName, settingTable)
	
end

function MCM.AddSpace(categoryName, subcategoryName)
	
	if type(categoryName) ~= "string" and type(categoryName) ~= "number" then
		error("MCM.AddSpace - No valid category name provided", 2)
	end
	
	subcategoryName = subcategoryName or "Uncategorized"
	if type(subcategoryName) ~= "string" and type(subcategoryName) ~= "number" then
		error("MCM.AddSpace - No valid subcategory name provided", 2)
	end

	local settingTable = {
		Type = MCM.OptionType.SPACE
	}
	
	return MCM.AddSetting(categoryName, subcategoryName, settingTable)
	
end

local altSlider = false
function MCM.SimpleAddSetting(settingType, categoryName, subcategoryName, configTableAttribute, minValue, maxValue, modifyBy, defaultValue, displayText, displayValueProxies, displayDevice, info, color, functionName)
	
	--set default values
	if defaultValue == nil then
		if settingType == MCM.OptionType.BOOLEAN then
			defaultValue = false
		else
			defaultValue = 0
		end
	end
	
	if settingType == MCM.OptionType.NUMBER then
		minValue = minValue or 0
		maxValue = maxValue or 10
		modifyBy = modifyBy or 1
	else
		minValue = nil
		maxValue = nil
		modifyBy = nil
	end
	
	functionName = functionName or "SimpleAddSetting"
	
	--erroring
	if categoryName == nil then
		error("MCM." .. tostring(functionName) .. " - No valid category name provided", 2)
	end
	if configTableAttribute == nil then
		error("MCM." .. tostring(functionName) .. " - No valid config table attribute provided", 2)
	end
	
	--create config value
	MCM.Config[categoryName] = MCM.Config[categoryName] or {}
	if MCM.Config[categoryName][configTableAttribute] == nil then
		MCM.Config[categoryName][configTableAttribute] = defaultValue
	end
	
	MCM.ConfigDefault[categoryName] = MCM.ConfigDefault[categoryName] or {}
	if MCM.ConfigDefault[categoryName][configTableAttribute] == nil then
		MCM.ConfigDefault[categoryName][configTableAttribute] = defaultValue
	end
	
	--setting
	local settingTable = {
		Type = settingType,
		Attribute = configTableAttribute,
		CurrentSetting = function()
			return MCM.Config[categoryName][configTableAttribute]
		end,
		Default = defaultValue,
		Display = function(cursorIsAtThisOption, configMenuInOptions, lastOptionPos)
		
			local currentValue = MCM.Config[categoryName][configTableAttribute]
		
			local displayString = ""
			
			if displayText then
				displayString = displayText .. ": "
			end
			
			if settingType == MCM.OptionType.SCROLL then
			
				displayString = displayString .. "$scroll" .. tostring(math.floor(currentValue))
				
			elseif settingType == MCM.OptionType.KEYBIND_KEYBOARD then
				
				local key = "None"
				
				if currentValue > -1 then
				
					key = "Unknown Key"
					
					if MCM.KeyboardToString[currentValue] then
						key = MCM.KeyboardToString[currentValue]
					end
					
				end
				
				displayString = displayString .. key
				
				if displayDevice then
					
					displayString = displayString .. " (keyboard)"
					
				end
				
			elseif settingType == MCM.OptionType.KEYBIND_CONTROLLER then
				
				local key = "None"
				
				if currentValue > -1 then
				
					key = "Unknown Button"
					
					if MCM.ControllerToString[currentValue] then
						key = MCM.ControllerToString[currentValue]
					end
					
				end
				
				displayString = displayString .. key
				
				if displayDevice then
					
					displayString = displayString .. " (controller)"
					
				end
				
			elseif displayValueProxies and displayValueProxies[currentValue] then
			
				displayString = displayString .. tostring(displayValueProxies[currentValue])
				
			else
			
				displayString = displayString .. tostring(currentValue)
				
			end
			
			return displayString
			
		end,
		OnChange = function(currentValue)
		
			if not currentValue then
			
				if settingType == MCM.OptionType.KEYBIND_KEYBOARD or settingType == MCM.OptionType.KEYBIND_CONTROLLER then
					currentValue = -1
				end
				
			end
			
			MCM.Config[categoryName][configTableAttribute] = currentValue
			
		end,
		Info = info,
		Color = color
	}
	
	if settingType == MCM.OptionType.NUMBER then
	
		settingTable.Minimum = minValue
		settingTable.Maximum = maxValue
		settingTable.ModifyBy = modifyBy
		
	elseif settingType == MCM.OptionType.SCROLL then

		settingTable.AltSlider = altSlider
		altSlider = not altSlider
		
	elseif settingType == MCM.OptionType.KEYBIND_KEYBOARD or settingType == MCM.OptionType.KEYBIND_CONTROLLER then
		
		settingTable.PopupGfx = MCM.PopupGfx.WIDE_SMALL
		settingTable.PopupWidth = 280
		settingTable.Popup = function()
		
			local currentValue = MCM.Config[categoryName][configTableAttribute]
		
			local goBackString = "back"
			if MCM.Config.LastBackPressed then
			
				if MCM.KeyboardToString[MCM.Config.LastBackPressed] then
					goBackString = MCM.KeyboardToString[MCM.Config.LastBackPressed]
				elseif MCM.ControllerToString[MCM.Config.LastBackPressed] then
					goBackString = MCM.ControllerToString[MCM.Config.LastBackPressed]
				end
				
			end
			
			local keepSettingString = ""
			if currentValue > -1 then
			
				local currentSettingString = nil
				if (settingType == MCM.OptionType.KEYBIND_KEYBOARD and MCM.KeyboardToString[currentValue]) then
					currentSettingString = MCM.KeyboardToString[currentValue]
				elseif (settingType == MCM.OptionType.KEYBIND_CONTROLLER and MCM.ControllerToString[currentValue]) then
					currentSettingString = MCM.ControllerToString[currentValue]
				end
				
				keepSettingString = "This setting is currently set to \"" .. currentSettingString .. "\".$newlinePress this button to keep it unchanged.$newline$newline"
				
			end
			
			local deviceString = ""
			if settingType == MCM.OptionType.KEYBIND_KEYBOARD then
				deviceString = "keyboard"
			elseif settingType == MCM.OptionType.KEYBIND_CONTROLLER then
				deviceString = "controller"
			end
			
			return "Press a button on your " .. deviceString .. " to change this setting.$newline$newline" .. keepSettingString .. "Press \"" .. goBackString .. "\" to go back and clear this setting."
			
		end
		
	end
	
	return MCM.AddSetting(categoryName, subcategoryName, settingTable)
	
end

function MCM.AddBooleanSetting(categoryName, subcategoryName, configTableAttribute, defaultValue, displayText, displayValueProxies, info, color)

	--move args around
	if type(configTableAttribute) ~= "string" then
		color = info
		info = displayValueProxies
		displayValueProxies = displayText
		displayText = defaultValue
		defaultValue = configTableAttribute
		configTableAttribute = subcategoryName
		subcategoryName = nil
	end
	
	if type(defaultValue) ~= "boolean" then
		color = info
		info = displayValueProxies
		displayValueProxies = displayText
		displayText = defaultValue
		defaultValue = false
	end

	if type(displayValueProxies) ~= "table" or type(info) == "userdata" or type(info) == "nil" then
		color = info
		info = displayValueProxies
		displayValueProxies = nil
	end
	
	return MCM.SimpleAddSetting(MCM.OptionType.BOOLEAN, categoryName, subcategoryName, configTableAttribute, nil, nil, nil, defaultValue, displayText, displayValueProxies, nil, info, color, "AddBooleanSetting")
	
end

function MCM.AddNumberSetting(categoryName, subcategoryName, configTableAttribute, minValue, maxValue, modifyBy, defaultValue, displayText, displayValueProxies, info, color)

	--move args around
	if type(configTableAttribute) ~= "string" then
		color = info
		info = displayValueProxies
		displayValueProxies = displayText
		displayText = defaultValue
		defaultValue = modifyBy
		modifyBy = maxValue
		maxValue = minValue
		minValue = configTableAttribute
		configTableAttribute = subcategoryName
		subcategoryName = nil
	end
	
	if type(defaultValue) == "string" then
		color = info
		info = displayValueProxies
		displayValueProxies = displayText
		displayText = defaultValue
		defaultValue = modifyBy
		modifyBy = nil
	end

	if type(displayValueProxies) ~= "table" or type(info) == "userdata" or type(info) == "nil" then
		color = info
		info = displayValueProxies
		displayValueProxies = nil
	end
	
	--set default values
	defaultValue = defaultValue or 0
	minValue = minValue or 0
	maxValue = maxValue or 10
	modifyBy = modifyBy or 1
	
	return MCM.SimpleAddSetting(MCM.OptionType.NUMBER, categoryName, subcategoryName, configTableAttribute, minValue, maxValue, modifyBy, defaultValue, displayText, displayValueProxies, nil, info, color, "AddNumberSetting")
	
end

function MCM.AddScrollSetting(categoryName, subcategoryName, configTableAttribute, defaultValue, displayText, info, color)

	--move args around
	if type(configTableAttribute) ~= "string" then
		color = info
		info = displayText
		displayText = defaultValue
		defaultValue = configTableAttribute
		configTableAttribute = subcategoryName
		subcategoryName = nil
	end
	
	if type(defaultValue) ~= "number" then
		color = info
		info = displayText
		displayText = defaultValue
		defaultValue = nil
	end
	
	--set default values
	defaultValue = defaultValue or 0

	return MCM.SimpleAddSetting(MCM.OptionType.SCROLL, categoryName, subcategoryName, configTableAttribute, nil, nil, nil, defaultValue, displayText, nil, nil, info, color, "AddScrollSetting")
	
end

function MCM.AddKeyboardSetting(categoryName, subcategoryName, configTableAttribute, defaultValue, displayText, displayDevice, info, color)

	--move args around
	if type(configTableAttribute) ~= "string" then
		color = info
		info = displayDevice
		displayDevice = displayText
		displayText = defaultValue
		defaultValue = configTableAttribute
		configTableAttribute = subcategoryName
		subcategoryName = nil
	end
	
	if type(defaultValue) ~= "number" then
		color = info
		info = displayText
		displayText = defaultValue
		defaultValue = nil
	end
	
	if type(displayDevice) ~= "boolean" then
		color = info
		info = displayDevice
		displayDevice = false
	end
	
	--set default values
	defaultValue = defaultValue or -1

	return MCM.SimpleAddSetting(MCM.OptionType.KEYBIND_KEYBOARD, categoryName, subcategoryName, configTableAttribute, nil, nil, nil, defaultValue, displayText, nil, displayDevice, info, color, "AddKeyboardSetting")
	
end

function MCM.AddControllerSetting(categoryName, subcategoryName, configTableAttribute, defaultValue, displayText, displayDevice, info, color)

	--move args around
	if type(configTableAttribute) ~= "string" then
		color = info
		info = displayDevice
		displayDevice = displayText
		displayText = defaultValue
		defaultValue = configTableAttribute
		configTableAttribute = subcategoryName
		subcategoryName = nil
	end
	
	if type(defaultValue) ~= "number" then
		color = info
		info = displayText
		displayText = defaultValue
		defaultValue = nil
	end
	
	if type(displayDevice) ~= "boolean" then
		color = info
		info = displayDevice
		displayDevice = false
	end
	
	--set default values
	defaultValue = defaultValue or -1

	return MCM.SimpleAddSetting(MCM.OptionType.KEYBIND_CONTROLLER, categoryName, subcategoryName, configTableAttribute, nil, nil, nil, defaultValue, displayText, nil, displayDevice, info, color, "AddControllerSetting")
	
end

function MCM.RemoveSetting(categoryName, subcategoryName, settingAttribute)

	if settingAttribute == nil then
		settingAttribute = subcategoryName
		subcategoryName = nil
	end

	if type(categoryName) ~= "string" and type(categoryName) ~= "number" then
		error("MCM.RemoveSetting - No valid category name provided", 2)
	end

	subcategoryName = subcategoryName or "Uncategorized"
	if type(subcategoryName) ~= "string" and type(subcategoryName) ~= "number" then
		error("MCM.RemoveSetting - No valid subcategory name provided", 2)
	end
	
	local categoryID = MCM.GetCategoryIDByName(categoryName)
	if categoryID then
	
		local subcategoryID = MCM.GetSubcategoryIDByName(categoryID, subcategoryName)
		if subcategoryID then
		
			--loop to find matching attribute
			for i=#MCM.MenuData[categoryID].Subcategories[subcategoryID].Options, 1, -1 do
			
				if MCM.MenuData[categoryID].Subcategories[subcategoryID].Options[i]
				and MCM.MenuData[categoryID].Subcategories[subcategoryID].Options[i].Attribute
				and MCM.MenuData[categoryID].Subcategories[subcategoryID].Options[i].Attribute == settingAttribute then
				
					table.remove(MCM.MenuData[categoryID].Subcategories[subcategoryID].Options, i)
					return true
					
				end
				
			end
		
			--loop to find matching display
			for i=#MCM.MenuData[categoryID].Subcategories[subcategoryID].Options, 1, -1 do
			
				if MCM.MenuData[categoryID].Subcategories[subcategoryID].Options[i]
				and MCM.MenuData[categoryID].Subcategories[subcategoryID].Options[i].Display
				and MCM.MenuData[categoryID].Subcategories[subcategoryID].Options[i].Display == settingAttribute then
				
					table.remove(MCM.MenuData[categoryID].Subcategories[subcategoryID].Options, i)
					return true
					
				end
				
			end
			
		end
		
	end
	
	return false

end

--------------------------
--GENERAL SETTINGS SETUP--
--------------------------
if Options then
	MCM.Config["General"] = {}
else
	MCM.SetCategoryInfo("General", "Settings that affect the majority of mods")
end

--------------
--HUD OFFSET--
--------------
if Options then
	MCM.CurrentScreenOffset = math.min(math.max(math.floor(Options.HUDOffset*10),0),10)
else
	MCM.CurrentScreenOffset = MCM.CurrentScreenOffset or 0
end

function MCM.SetOffset(num)
	num = math.min(math.max(math.floor(num),0),10)
	MCM.CurrentScreenOffset = num
	if Options then
		Options.HUDOffset = MCM.CurrentScreenOffset * 0.1
	end
	return num
end

function MCM.GetOffset()
	if Options then
		MCM.CurrentScreenOffset = math.min(math.max(math.floor(Options.HUDOffset*10),0),10)
	end
	return MCM.CurrentScreenOffset
end

function MCM.GetScreenSize()
	if REPENTANCE then
		return Vector(Isaac.GetScreenWidth(), Isaac.GetScreenHeight())
	else--based off of code from kilburn
		local game = Game()
		local room = game:GetRoom()
		local pos = room:WorldToScreenPosition(vecZero) - room:GetRenderScrollOffset() - game.ScreenShakeOffset
		local rx = pos.X + 60 * 26 / 40
		local ry = pos.Y + 140 * (26 / 40)
		return Vector(rx*2 + 13*26, ry*2 + 7*26)
	end
end

function MCM.Round(num, decimalPlaces)
    local mult = 10^(decimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

function MCM.GetScreenCenter()
	return MCM.GetScreenSize() / 2
end

function MCM.GetScreenBottomRight(offset)
	offset = offset or MCM.GetOffset()
	local pos = MCM.GetScreenSize()
	local hudOffset = Vector(-offset * 2.2, -offset * 1.6)
	pos = pos + hudOffset
	return MCM.Round(pos)
end

function MCM.GetScreenBottomLeft(offset)
	offset = offset or MCM.GetOffset()
	local pos = Vector(0, MCM.GetScreenBottomRight(0).Y)
	local hudOffset = Vector(offset * 2.2, -offset * 1.6)
	pos = pos + hudOffset
	return MCM.Round(pos)
end

function MCM.GetScreenTopRight(offset)
	offset = offset or MCM.GetOffset()
	local pos = Vector(MCM.GetScreenBottomRight(0).X, 0)
	local hudOffset = Vector(-offset * 2.2, offset * 1.2)
	pos = pos + hudOffset
	return MCM.Round(pos)
end

function MCM.GetScreenTopLeft(offset)
	offset = offset or MCM.GetOffset()
	local pos = vecZero
	local hudOffset = Vector(offset * 2, offset * 1.2)
	pos = pos + hudOffset
	return MCM.Round(pos)
end

if Options then
	MCM.Config["General"].HudOffset = MCM.GetOffset()
else
	local hudOffsetSetting = MCM.AddScrollSetting(
		"General", --category
		"HudOffset", --attribute in table
		0, --default value
		"Hud Offset", --display text
		"How far from the corners of the screen custom hud elements will be.$newlineTry to make this match your base-game setting."
	)
	hudOffsetSetting.HideControls = true -- hide controls so the screen corner graphics are easier to see
	hudOffsetSetting.ShowOffset = true -- shows screen offset
	--set up callback
	local oldHudOffsetOnChange = hudOffsetSetting.OnChange
	hudOffsetSetting.OnChange = function(currentValue)
		MCM.SetOffset(currentValue)
		return oldHudOffsetOnChange(currentValue)
	end
end

--------------------
--OVERLAYS SETTING--
--------------------
if Options then
	MCM.Config["General"].Overlays = true
else
	MCM.AddBooleanSetting(
		"General", --category
		"Overlays", --attribute in table
		true, --default value
		"Overlays", --display text
		{ --value display text
			[true] = "On",
			[false] = "Off"
		},
		"Enable or disable custom visual overlays, like screen-wide fog."
	)
end

-----------------------
--CHARGE BARS SETTING--
-----------------------
if Options then
	MCM.Config["General"].ChargeBars = Options.ChargeBars
else
	MCM.AddBooleanSetting(
		"General", --category
		"ChargeBars", --attribute in table
		false, --default value
		"Charge Bars", --display text
		{ --value display text
			[true] = "On",
			[false] = "Off"
		},
		"Enable or disable custom charge bar visuals for mod effects, like those from chargeable items."
	)
end

---------------------
--BIG BOOKS SETTING--
---------------------
if Options then
	MCM.Config["General"].BigBooks = true
else
	MCM.AddBooleanSetting(
		"General", --category
		"BigBooks", --attribute in table
		true, --default value
		"Bigbooks", --display text
		{ --value display text
			[true] = "On",
			[false] = "Off"
		},
		"Enable or disable custom overlay animations which appear when some active items are used."
	)
end

---------------------
--ANNOUNCER SETTING--
---------------------
if Options then
	MCM.Config["General"].Announcer = Options.AnnouncerVoiceMode
else
	MCM.AddNumberSetting(
		"General", --category
		"Announcer", --attribute in table
		0, --minimum value
		2, --max value
		0, --default value,
		"Announcer", --display text
		{ --value display text
			[0] = "Sometimes",
			[1] = "Never",
			[2] = "Always"
		},
		"Choose how often custom voice-overs play when pills or cards are used."
	)
end

--------------------------
--GENERAL SETTINGS CLOSE--
--------------------------
if not Options then
	MCM.AddSpace("General") --SPACE
	MCM.AddText("General", "These settings apply to")
	MCM.AddText("General", "all mods which support them")
end


----------------------------------
--MOD CONFIG MENU SETTINGS SETUP--
----------------------------------

MCM.SetCategoryInfo("Mod Config Menu", "Settings specific to Mod Config Menu.$newlineChange keybindings for the menu here.")

MCM.AddTitle("Mod Config Menu", "Version " .. MCM.GetVersionString() .. "!") --VERSION INDICATOR

MCM.AddSpace("Mod Config Menu") --SPACE


----------------------
--OPEN MENU KEYBOARD--
----------------------
local openMenuKeyboardSetting = MCM.AddKeyboardSetting(
	"Mod Config Menu", --category
	"OpenMenuKeyboard", --attribute in table
	Keyboard.KEY_L, --default value
	"Open Menu", --display text
	true, --if (keyboard) is displayed after the key text
	"Choose what button on your keyboard will open Mod Config Menu."
)

openMenuKeyboardSetting.IsOpenMenuKeybind = true


------------------------
--OPEN MENU CONTROLLER--
------------------------
local openMenuControllerSetting = MCM.AddControllerSetting(
	"Mod Config Menu", --category
	"OpenMenuController", --attribute in table
	Controller.STICK_RIGHT, --default value
	"Open Menu", --display text
	true, --if (controller) is displayed after the key text
	"Choose what button on your controller will open Mod Config Menu."
)

openMenuControllerSetting.IsOpenMenuKeybind = true

--f10 note
MCM.AddText("Mod Config Menu", "F10 will always open this menu.")

MCM.AddSpace("Mod Config Menu") --SPACE


------------
--HIDE HUD--
------------
local hideHudSetting = MCM.AddBooleanSetting(
	"Mod Config Menu", --category
	"HideHudInMenu", --attribute in table
	true, --default value
	"Hide HUD", --display text
	{ --value display text
		[true] = "Yes",
		[false] = "No"
	},
	"Enable or disable the hud when this menu is open."
)

--actively modify the hud visibility as this setting changes
local oldHideHudOnChange = hideHudSetting.OnChange
hideHudSetting.OnChange = function(currentValue)

	oldHideHudOnChange(currentValue)
	
	local game = Game()
	if REPENTANCE then
		local hud = game:GetHUD()
		hud:SetVisible = not currentValue
	else
		local seeds = game:GetSeeds()
		if currentValue then
			if not seeds:HasSeedEffect(SeedEffect.SEED_NO_HUD) then
				seeds:AddSeedEffect(SeedEffect.SEED_NO_HUD)
			end
		else
			if seeds:HasSeedEffect(SeedEffect.SEED_NO_HUD) then
				seeds:RemoveSeedEffect(SeedEffect.SEED_NO_HUD)
			end
		end
	end

end


----------------------------
--RESET TO DEFAULT KEYBIND--
----------------------------
local resetKeybindSetting = MCM.AddKeyboardSetting(
	"Mod Config Menu", --category
	"ResetToDefault", --attribute in table
	Keyboard.KEY_R, --default value
	"Reset To Default Keybind", --display text
	"Press this button on your keyboard to reset a setting to its default value."
)

resetKeybindSetting.IsResetKeybind = true


-----------------
--SHOW CONTROLS--
-----------------
MCM.AddBooleanSetting(
	"Mod Config Menu", --category
	"ShowControls", --attribute in table
	true, --default value
	"Show Controls", --display text
	{ --value display text
		[true] = "Yes",
		[false] = "No"
	},
	"Disable this to remove the back and select widgets at the lower corners of the screen and remove the bottom start-up message."
)

--[[
MCM.AddSpace("Mod Config Menu") --SPACE


-----------------
--COMPATIBILITY--
-----------------
local compatibilitySetting = MCM.AddBooleanSetting(
	"Mod Config Menu", --category
	"CompatibilityLayer", --attribute in table
	false, --default value
	"Disable Legacy Warnings", --display text
	{ --value display text
		[true] = "Yes",
		[false] = "No"
	},
	"Use this setting to prevent warnings from being printed to the console for mods that use outdated features of Mod Config Menu."
)
-- compatibilitySetting.Restart = true
]]

local configMenuSubcategoriesCanShow = 3

local configMenuInSubcategory = false
local configMenuInOptions = false
local configMenuInPopup = false

local holdingCounterDown = 0
local holdingCounterUp = 0
local holdingCounterRight = 0
local holdingCounterLeft = 0

local configMenuPositionCursorCategory = 1
local configMenuPositionCursorSubcategory = 1
local configMenuPositionCursorOption = 1

local configMenuPositionFirstSubcategory = 1

--valid action presses
local actionsDown = {ButtonAction.ACTION_DOWN, ButtonAction.ACTION_SHOOTDOWN, ButtonAction.ACTION_MENUDOWN}
local actionsUp = {ButtonAction.ACTION_UP, ButtonAction.ACTION_SHOOTUP, ButtonAction.ACTION_MENUUP}
local actionsRight = {ButtonAction.ACTION_RIGHT, ButtonAction.ACTION_SHOOTRIGHT, ButtonAction.ACTION_MENURIGHT}
local actionsLeft = {ButtonAction.ACTION_LEFT, ButtonAction.ACTION_SHOOTLEFT, ButtonAction.ACTION_MENULEFT}
local actionsBack = {ButtonAction.ACTION_PILLCARD, ButtonAction.ACTION_MAP, ButtonAction.ACTION_MENUBACK}
local actionsSelect = {ButtonAction.ACTION_ITEM, ButtonAction.ACTION_PAUSE, ButtonAction.ACTION_MENUCONFIRM, ButtonAction.ACTION_BOMB}

--ignore these buttons for the above actions
local ignoreActionButtons = {Controller.BUTTON_A, Controller.BUTTON_B, Controller.BUTTON_X, Controller.BUTTON_Y, Controller.DPAD_LEFT, Controller.DPAD_RIGHT, Controller.DPAD_UP, Controller.DPAD_DOWN}

local currentMenuCategory = nil
local currentMenuSubcategory = nil
local currentMenuOption = nil
local function updateCurrentMenuVars()
	if MCM.MenuData[configMenuPositionCursorCategory] then
		currentMenuCategory = MCM.MenuData[configMenuPositionCursorCategory]
		if currentMenuCategory.Subcategories and currentMenuCategory.Subcategories[configMenuPositionCursorSubcategory] then
			currentMenuSubcategory = currentMenuCategory.Subcategories[configMenuPositionCursorSubcategory]
			if currentMenuSubcategory.Options and currentMenuSubcategory.Options[configMenuPositionCursorOption] then
				currentMenuOption = currentMenuSubcategory.Options[configMenuPositionCursorOption]
			end
		end
	end
end

--leaving/entering menu sections
function MCM.EnterPopup()
	if configMenuInSubcategory and configMenuInOptions and not configMenuInPopup then
		local foundValidPopup = false
		if currentMenuOption
		and currentMenuOption.Type
		and currentMenuOption.Type ~= MCM.OptionType.SPACE
		and (currentMenuOption.Popup or currentMenuOption.Restart or currentMenuOption.Rerun) then
			foundValidPopup = true
		end
		if foundValidPopup then
			local popupSpritesheet = MCM.PopupGfx.THIN_SMALL
			if currentMenuOption.PopupGfx and type(currentMenuOption.PopupGfx) == "string" then
				popupSpritesheet = currentMenuOption.PopupGfx
			end
			PopupSprite:ReplaceSpritesheet(5, popupSpritesheet)
			PopupSprite:LoadGraphics()
			configMenuInPopup = true
		end
	end
end

function MCM.EnterOptions()
	if configMenuInSubcategory and not configMenuInOptions then
		if currentMenuSubcategory
		and currentMenuSubcategory.Options
		and #currentMenuSubcategory.Options > 0 then
		
			for optionIndex=1, #currentMenuSubcategory.Options do
				
				local thisOption = currentMenuSubcategory.Options[optionIndex]
				
				if thisOption.Type
				and thisOption.Type ~= MCM.OptionType.SPACE
				and (not thisOption.NoCursorHere or (type(thisOption.NoCursorHere) == "function" and not thisOption.NoCursorHere()))
				and thisOption.Display then
				
					configMenuPositionCursorOption = optionIndex
					configMenuInOptions = true
					OptionsCursorSpriteUp.Color = colorDefault
					OptionsCursorSpriteDown.Color = colorDefault
					
					break
				end
			end
		end
	end
end

function MCM.EnterSubcategory()
	if not configMenuInSubcategory then
		configMenuInSubcategory = true
		SubcategoryCursorSpriteLeft.Color = colorDefault
		SubcategoryCursorSpriteRight.Color = colorDefault
		SubcategoryDividerSprite.Color = colorDefault
		
		local hasUsableCategories = false
		if currentMenuCategory.Subcategories then
			for j=1, #currentMenuCategory.Subcategories do
				if currentMenuCategory.Subcategories[j].Name ~= "Uncategorized" then
					hasUsableCategories = true
				end
			end
		end
		
		if not hasUsableCategories then
			MCM.EnterOptions()
		end
	end
end

local restartWarnMessage = nil
local rerunWarnMessage = nil
function MCM.LeavePopup()
	if configMenuInSubcategory and configMenuInOptions and configMenuInPopup then
		
		if currentMenuOption then
		
			if currentMenuOption.Restart then
			
				restartWarnMessage = "One or more settings require you to restart the game"
			
			elseif currentMenuOption.Rerun then
			
				rerunWarnMessage = "One or more settings require you to start a new run"
				
			end
			
		end
	
		configMenuInPopup = false
		
	end
end

function MCM.LeaveOptions()
	if configMenuInSubcategory and configMenuInOptions then
		configMenuInOptions = false
		OptionsCursorSpriteUp.Color = colorHalf
		OptionsCursorSpriteDown.Color = colorHalf
		
		local hasUsableCategories = false
		if currentMenuCategory.Subcategories then
			for j=1, #currentMenuCategory.Subcategories do
				if currentMenuCategory.Subcategories[j].Name ~= "Uncategorized" then
					hasUsableCategories = true
				end
			end
		end
		
		if not hasUsableCategories then
			MCM.LeaveSubcategory()
		end
	end
end

function MCM.LeaveSubcategory()
	if configMenuInSubcategory then
		configMenuInSubcategory = false
		SubcategoryCursorSpriteLeft.Color = colorHalf
		SubcategoryCursorSpriteRight.Color = colorHalf
		SubcategoryDividerSprite.Color = colorHalf
	end
end

local mainSpriteColor = colorDefault
local optionsSpriteColor = colorDefault
local optionsSpriteColorAlpha = colorHalf
local mainFontColor = KColor(34/255,32/255,30/255,1)
local leftFontColor = KColor(35/255,31/255,30/255,1)
local leftFontColorSelected = KColor(35/255,50/255,70/255,1)

local optionsFontColor = KColor(34/255,32/255,30/255,1)
local optionsFontColorAlpha = KColor(34/255,32/255,30/255,0.5)
local optionsFontColorNoCursor = KColor(34/255,32/255,30/255,0.8)
local optionsFontColorNoCursorAlpha = KColor(34/255,32/255,30/255,0.4)
local optionsFontColorTitle = KColor(50/255,0,0,1)
local optionsFontColorTitleAlpha = KColor(50/255,0,0,0.5)

local subcategoryFontColor = KColor(34/255,32/255,30/255,1)
local subcategoryFontColorSelected = KColor(34/255,50/255,70/255,1)
local subcategoryFontColorAlpha = KColor(34/255,32/255,30/255,0.5)
local subcategoryFontColorSelectedAlpha = KColor(34/255,50/255,70/255,0.5)

function MCM.ConvertDisplayToTextTable(displayValue, lineWidth, font)

	lineWidth = lineWidth or 340

	local textTableDisplay = {}
	if type(displayValue) == "function" then
		displayValue = displayValue()
	end
	
	if type(displayValue) == "string" then
		textTableDisplay = {displayValue}
	elseif type(displayValue) == "table" then
		textTableDisplay = MCM.CopyTable(displayValue)
	else
		textTableDisplay = {tostring(displayValue)}
	end
	
	if type(textTableDisplay) == "string" then
		textTableDisplay = {textTableDisplay}
	end
	
	--create new lines based on $newline modifier
	local textTableDisplayAfterNewlines = {}
	for lineIndex=1, #textTableDisplay do
	
		local line = textTableDisplay[lineIndex]
		local startIdx, endIdx = string.find(line,"$newline")
		while startIdx do

			local newline = string.sub(line, 0, startIdx-1)
			table.insert(textTableDisplayAfterNewlines, newline)
			
			line = string.sub(line, endIdx+1)
			
			startIdx, endIdx = string.find(line,"$newline")
			
		end
		table.insert(textTableDisplayAfterNewlines, line)
		
	end

	--dynamic string new line creation, based on code by wofsauge
	local textTableDisplayAfterWordLength = {}
	for lineIndex=1, #textTableDisplayAfterNewlines do
	
		local line = textTableDisplayAfterNewlines[lineIndex]
		local curLength = 0
		local text = ""
		for word in string.gmatch(tostring(line), "([^%s]+)") do
		
			local wordLength = font:GetStringWidthUTF8(word)

			if curLength + wordLength <= lineWidth or curLength < 12 then
			
				text = text .. word .. " "
				curLength = curLength + wordLength
				
			else
			
				table.insert(textTableDisplayAfterWordLength, text)
				text = word .. " "
				curLength = wordLength
				
			end
			
		end
		table.insert(textTableDisplayAfterWordLength, text)
		
	end
	
	return textTableDisplayAfterWordLength
	
end

--set up screen corner display for hud offset
local HudOffsetVisualTopLeft = MCM.GetMenuAnm2Sprite("Offset", 0)
local HudOffsetVisualTopRight = MCM.GetMenuAnm2Sprite("Offset", 1)
local HudOffsetVisualBottomRight = MCM.GetMenuAnm2Sprite("Offset", 2)
local HudOffsetVisualBottomLeft = MCM.GetMenuAnm2Sprite("Offset", 3)

--render the menu
local leftCurrentOffset = 0
local optionsCurrentOffset = 0
MCM.ControlsEnabled = true
MCM.WarningOffset = 28
MCM.WarningOffsetDSS = 50
function MCM.GetIsPaused()
	if AwaitingTextInput or CustomConsoleOpen then
		return true
	elseif DeadSeaScrollsMenu and DeadSeaScrollsMenu.OpenedMenu then
		return true
	else
		return Game():IsPaused()
	end
end

function MCM.PostRender()

	local game = Game()
	local isPaused = MCM.GetIsPaused()
	
	local sfx = SFXManager()

	local pressingButton = ""

	local pressingNonRebindableKey = false
	local pressedToggleMenu = false

	local openMenuGlobal = Keyboard.KEY_F10
	local openMenuKeyboard = MCM.Config["Mod Config Menu"].OpenMenuKeyboard
	local openMenuController = MCM.Config["Mod Config Menu"].OpenMenuController
	
	local takeScreenshot = Keyboard.KEY_F12

	--handle version display on game start
	if versionPrintTimer > 0 then
	
		local bottomRight = MCM.GetScreenBottomRight(0)

		local openMenuButton = Keyboard.KEY_F10
		if type(MCM.Config["Mod Config Menu"].OpenMenuKeyboard) == "number" and MCM.Config["Mod Config Menu"].OpenMenuKeyboard > -1 then
			openMenuButton = MCM.Config["Mod Config Menu"].OpenMenuKeyboard
		end

		local openMenuButtonString = "Unknown Key"
		if MCM.KeyboardToString[openMenuButton] then
			openMenuButtonString = MCM.KeyboardToString[openMenuButton]
		end
		
		local text = "Press " .. openMenuButtonString .. " to open Mod Config Menu"
		local versionPrintColor = KColor(1, 1, 0, (math.min(versionPrintTimer, 60)/60) * 0.5)
		local warnOffset = MCM.WarningOffset
		if DeadSeaScrollsMenu then
			local level = game:GetLevel()
			local isDSSTextDisplayed = level:GetStage() == LevelStage.STAGE1_1 and
				level:GetCurrentRoomIndex() == level:GetStartingRoomIndex() and game:GetRoom():IsFirstVisit() and
				level:GetStageType() ~= StageType.STAGETYPE_REPENTANCE and
				level:GetStageType() ~= StageType.STAGETYPE_REPENTANCE_B and
				not game:GetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH) and
				not DeadSeaScrollsMenu.IsOpen() and
				DeadSeaScrollsMenu.GetMenuHintSetting() == 1
			if isDSSTextDisplayed then
				warnOffset = MCM.WarningOffsetDSS
			end
		end
		versionPrintFont:DrawString(text, 0, bottomRight.Y - warnOffset, versionPrintColor, bottomRight.X, true)
		
	end
	
	--on-screen warnings
	if restartWarnMessage or rerunWarnMessage then
	
		local bottomRight = MCM.GetScreenBottomRight(0)
	
		local text = restartWarnMessage or rerunWarnMessage
		local warningPrintColor = KColor(1, 0, 0, 1)
		local warnOffset = MCM.WarningOffset
		if DeadSeaScrollsMenu then
			local level = game:GetLevel()
			local isDSSTextDisplayed = level:GetStage() == LevelStage.STAGE1_1 and
				level:GetCurrentRoomIndex() == level:GetStartingRoomIndex() and game:GetRoom():IsFirstVisit() and
				level:GetStageType() ~= StageType.STAGETYPE_REPENTANCE and
				level:GetStageType() ~= StageType.STAGETYPE_REPENTANCE_B and
				not game:GetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH) and
				not DeadSeaScrollsMenu.IsOpen() and
				DeadSeaScrollsMenu.GetMenuHintSetting() == 1
			if isDSSTextDisplayed then
				warnOffset = MCM.WarningOffsetDSS
			end
		end
		versionPrintFont:DrawString(text, 0, bottomRight.Y - warnOffset, warningPrintColor, bottomRight.X, true)
		
	end

	--handle toggling the menu
	if MCM.ControlsEnabled and not isPaused then
	
		for i=0, 4 do
		
			if MCM.KeyboardTriggered(openMenuGlobal, i)
			or (openMenuKeyboard > -1 and MCM.KeyboardTriggered(openMenuKeyboard, i))
			or (openMenuController > -1 and Input.IsButtonTriggered(openMenuController, i)) then
				pressingNonRebindableKey = true
				pressedToggleMenu = true
				if not configMenuInPopup then
					MCM.ToggleConfigMenu()
				end
			end
			
			if MCM.KeyboardTriggered(takeScreenshot, i) then
				pressingNonRebindableKey = true
			end
			
		end
		
	end
	
	--force close the menu in some situations
	if MCM.IsVisible then
	
		if isPaused then
			MCM.CloseConfigMenu()
		end
		
		if not MCM.RoomIsSafe() then
			MCM.CloseConfigMenu()
			sfx:Play(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.75, 0, false, 1)
		end
		
	end

	--replace Dead Sea Scrolls' controller setting to not conflict with mcm's
	if DeadSeaScrollsMenu and DeadSeaScrollsMenu.GetGamepadToggleSetting then
	
		local dssControllerToggle = DeadSeaScrollsMenu.GetGamepadToggleSetting()
	
		if DeadSeaScrollsMenu.SaveGamepadToggleSetting then
		
			if openMenuController == Controller.STICK_RIGHT and (dssControllerToggle == 1 or dssControllerToggle == 3 or dssControllerToggle == 4) then
			
				DeadSeaScrollsMenu.SaveGamepadToggleSetting(2) --force Dead Sea Scrolls to only use the left stick
				
			elseif openMenuController == Controller.STICK_LEFT and (dssControllerToggle == 1 or dssControllerToggle == 2 or dssControllerToggle == 4) then
			
				DeadSeaScrollsMenu.SaveGamepadToggleSetting(3) --force Dead Sea Scrolls to only use the right stick
				
			end
			
		end
		
	end
	
	if MCM.IsVisible then
	
		if MCM.ControlsEnabled and not isPaused then

			for i=0, game:GetNumPlayers()-1 do
		
				local player = Isaac.GetPlayer(i)
				local data = player:GetData()
				
				--freeze players and disable their controls
				player.Velocity = vecZero
				
				if not data.ConfigMenuPlayerPosition then
					data.ConfigMenuPlayerPosition = player.Position
				end
				player.Position = data.ConfigMenuPlayerPosition
				if not data.ConfigMenuPlayerControlsDisabled then
					player.ControlsEnabled = false
					data.ConfigMenuPlayerControlsDisabled = true
				end
				
				--disable toggling Dead Sea Scrolls
				if data.input and data.input.menu and data.input.menu.toggle then
					data.input.menu.toggle = false
				end
				
			end
			
			if not MCM.MultipleButtonTriggered(ignoreActionButtons) then
				--pressing buttons
				local downButtonPressed = MCM.MultipleActionTriggered(actionsDown)
				if downButtonPressed then
					pressingButton = "DOWN"
				end
				local upButtonPressed = MCM.MultipleActionTriggered(actionsUp)
				if upButtonPressed then
					pressingButton = "UP"
				end
				local rightButtonPressed = MCM.MultipleActionTriggered(actionsRight)
				if rightButtonPressed then
					pressingButton = "RIGHT"
				end
				local leftButtonPressed = MCM.MultipleActionTriggered(actionsLeft)
				if leftButtonPressed then
					pressingButton = "LEFT"
				end
				local backButtonPressed = MCM.MultipleActionTriggered(actionsBack) or MCM.MultipleKeyboardTriggered({Keyboard.KEY_BACKSPACE})
				if backButtonPressed then
					pressingButton = "BACK"
					local possiblyPressedButton = MCM.MultipleKeyboardTriggered(Keyboard)
					if possiblyPressedButton then
						MCM.Config.LastBackPressed = possiblyPressedButton
					end
				end
				local selectButtonPressed = MCM.MultipleActionTriggered(actionsSelect)
				if selectButtonPressed then
					pressingButton = "SELECT"
					local possiblyPressedButton = MCM.MultipleKeyboardTriggered(Keyboard)
					if possiblyPressedButton then
						MCM.Config.LastSelectPressed = possiblyPressedButton
					end
				end
				if MCM.Config["Mod Config Menu"].ResetToDefault > -1 and MCM.MultipleKeyboardTriggered({MCM.Config["Mod Config Menu"].ResetToDefault}) then
					pressingButton = "RESET"
				end
				
				--holding buttons
				if MCM.MultipleActionPressed(actionsDown) then
					holdingCounterDown = holdingCounterDown + 1
				else
					holdingCounterDown = 0
				end
				if holdingCounterDown > 20 and holdingCounterDown%5 == 0 then
					pressingButton = "DOWN"
				end
				if MCM.MultipleActionPressed(actionsUp) then
					holdingCounterUp = holdingCounterUp + 1
				else
					holdingCounterUp = 0
				end
				if holdingCounterUp > 20 and holdingCounterUp%5 == 0 then
					pressingButton = "UP"
				end
				if MCM.MultipleActionPressed(actionsRight) then
					holdingCounterRight = holdingCounterRight + 1
				else
					holdingCounterRight = 0
				end
				if holdingCounterRight > 20 and holdingCounterRight%5 == 0 then
					pressingButton = "RIGHT"
				end
				if MCM.MultipleActionPressed(actionsLeft) then
					holdingCounterLeft = holdingCounterLeft + 1
				else
					holdingCounterLeft = 0
				end
				if holdingCounterLeft > 20 and holdingCounterLeft%5 == 0 then
					pressingButton = "LEFT"
				end
			else
				if MCM.MultipleButtonTriggered({Controller.BUTTON_B}) then
					pressingButton = "BACK"
					pressingNonRebindableKey = true
				end
				if MCM.MultipleButtonTriggered({Controller.BUTTON_A}) then
					pressingButton = "SELECT"
					pressingNonRebindableKey = true
				end
			end
			
			if pressingButton ~= "" then
				pressingNonRebindableKey = true
			end
			
		end
		
		updateCurrentMenuVars()
		
		local lastCursorCategoryPosition = configMenuPositionCursorCategory
		local lastCursorSubcategoryPosition = configMenuPositionCursorSubcategory
		local lastCursorOptionsPosition = configMenuPositionCursorOption
		
		local enterPopup = false
		local leavePopup = false
		
		local optionChanged = false
		
		local enterOptions = false
		local leaveOptions = false
		
		local enterSubcategory = false
		local leaveSubcategory = false
		
		if configMenuInPopup then
		
			if currentMenuOption then
				local optionType = currentMenuOption.Type
				local optionCurrent = currentMenuOption.CurrentSetting
				local optionOnChange = currentMenuOption.OnChange

				if optionType == MCM.OptionType.KEYBIND_KEYBOARD
				or optionType == MCM.OptionType.KEYBIND_CONTROLLER
				or currentMenuOption.OnSelect then

					if not isPaused then

						if pressingNonRebindableKey
						and not (pressingButton == "BACK"
						or pressingButton == "LEFT"
						or (currentMenuOption.OnSelect and (pressingButton == "SELECT" or pressingButton == "RIGHT"))
						or (currentMenuOption.IsResetKeybind and pressingButton == "RESET")
						or (currentMenuOption.IsOpenMenuKeybind and pressedToggleMenu)) then
							sfx:Play(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.75, 0, false, 1)
						else
							local numberToChange = nil
							local receivedInput = false
							if optionType == MCM.OptionType.KEYBIND_KEYBOARD or optionType == MCM.OptionType.KEYBIND_CONTROLLER then
								numberToChange = optionCurrent
								
								if type(optionCurrent) == "function" then
									numberToChange = optionCurrent()
								end
								
								if pressingButton == "BACK" or pressingButton == "LEFT" then
									numberToChange = nil
									receivedInput = true
								else
									for i=0, 4 do
										if optionType == MCM.OptionType.KEYBIND_KEYBOARD then
											for j=32, 400 do
												if MCM.KeyboardTriggered(j, i) then
													numberToChange = j
													receivedInput = true
													break
												end
											end
										else
											for j=0, 31 do
												if Input.IsButtonTriggered(j, i) then
													numberToChange = j
													receivedInput = true
													break
												end
											end
										end
									end
								end
							elseif currentMenuOption.OnSelect then
								if pressingButton == "BACK" or pressingButton == "LEFT" then
									receivedInput = true
								end
								if pressingButton == "SELECT" or pressingButton == "RIGHT" then
									numberToChange = true
									receivedInput = true
								end
							end
							
							if receivedInput then
								if optionType == MCM.OptionType.KEYBIND_KEYBOARD or optionType == MCM.OptionType.KEYBIND_CONTROLLER then
								
									if type(optionCurrent) == "function" then
										if optionOnChange then
											optionOnChange(numberToChange)
										end
									elseif type(optionCurrent) == "number" then
										currentMenuOption.CurrentSetting = numberToChange
									end
				
									--callback
									CustomCallbackHelper.CallCallbacks
									(
										CustomCallbacks.MCM_POST_MODIFY_SETTING, --callback id
										nil,
										{currentMenuOption.CurrentSetting, numberToChange}, --args to send
										{currentMenuCategory.Name, currentMenuOption.Attribute} --extra variables
									)
									
								elseif currentMenuOption.OnSelect and numberToChange then
									currentMenuOption.OnSelect()
								end
								
								leavePopup = true
								
								local sound = currentMenuOption.Sound
								if not sound then
									sound = SoundEffect.SOUND_PLOP
								end
								if sound >= 0 then
									sfx:Play(sound, 1, 0, false, 1)
								end
							end
						end
					end
				end
			end
			
			if currentMenuOption.Restart or currentMenuOption.Rerun then
			
				--confirmed left press
				if pressingButton == "RIGHT" then
					leavePopup = true
				end
				
				--confirmed back press
				if pressingButton == "SELECT" then
					leavePopup = true
				end
				
			end
			
			--confirmed left press
			if pressingButton == "LEFT" then
				leavePopup = true
			end
			
			--confirmed back press
			if pressingButton == "BACK" then
				leavePopup = true
			end
		elseif configMenuInOptions then
			--confirmed down press
			if pressingButton == "DOWN" then
				configMenuPositionCursorOption = configMenuPositionCursorOption + 1 --move options cursor down
			end
			
			--confirmed up press
			if pressingButton == "UP" then
				configMenuPositionCursorOption = configMenuPositionCursorOption - 1 --move options cursor up
			end
			
			if pressingButton == "SELECT" or pressingButton == "RIGHT" or pressingButton == "LEFT" or (pressingButton == "RESET" and currentMenuOption and currentMenuOption.Default ~= nil) then
				if pressingButton == "LEFT" then
					leaveOptions = true
				end
				
				if currentMenuOption then
					local optionType = currentMenuOption.Type
					local optionCurrent = currentMenuOption.CurrentSetting
					local optionOnChange = currentMenuOption.OnChange
					
					if optionType == MCM.OptionType.SCROLL or optionType == MCM.OptionType.NUMBER then
						leaveOptions = false
						
						local numberToChange = optionCurrent
						
						if type(optionCurrent) == "function" then
							numberToChange = optionCurrent()
						end
						
						local modifyBy = currentMenuOption.ModifyBy or 1
						modifyBy = math.max(modifyBy,0.001)
						if math.floor(modifyBy) == modifyBy then --force modify by into being an integer instead of a float if it should be
							modifyBy = math.floor(modifyBy)
						end
						
						if pressingButton == "RIGHT" or pressingButton == "SELECT" then
							numberToChange = numberToChange + modifyBy
						elseif pressingButton == "LEFT" then
							numberToChange = numberToChange - modifyBy
						elseif pressingButton == "RESET" and currentMenuOption.Default ~= nil then
							numberToChange = currentMenuOption.Default
							if type(currentMenuOption.Default) == "function" then
								numberToChange = currentMenuOption.Default()
							end
						end
						
						if optionType == MCM.OptionType.SCROLL then
							numberToChange = math.max(math.min(math.floor(numberToChange), 10), 0)
						else
							if currentMenuOption.Maximum and numberToChange > currentMenuOption.Maximum then
								if not currentMenuOption.NoLoopFromMaxMin and currentMenuOption.Minimum then
									numberToChange = currentMenuOption.Minimum
								else
									numberToChange = currentMenuOption.Maximum
								end
							end
							if currentMenuOption.Minimum and numberToChange < currentMenuOption.Minimum then
								if not currentMenuOption.NoLoopFromMaxMin and currentMenuOption.Maximum then
									numberToChange = currentMenuOption.Maximum
								else
									numberToChange = currentMenuOption.Minimum
								end
							end
						end
						
						if math.floor(modifyBy) ~= modifyBy then --check if modify by is a float
							numberToChange = math.floor((numberToChange*1000)+0.5)*0.001
						else
							numberToChange = math.floor(numberToChange)
						end
						
						if type(optionCurrent) == "function" then
							if optionOnChange then
								optionOnChange(numberToChange)
							end
							optionChanged = true
						elseif type(optionCurrent) == "number" then
							currentMenuOption.CurrentSetting = numberToChange
							optionChanged = true
						end
	
						--callback
						CustomCallbackHelper.CallCallbacks
						(
							CustomCallbacks.MCM_POST_MODIFY_SETTING, --callback id
							nil,
							{currentMenuOption.CurrentSetting, numberToChange}, --args to send
							{currentMenuCategory.Name, currentMenuOption.Attribute} --extra variables
						)
						
						local sound = currentMenuOption.Sound
						if not sound then
							sound = SoundEffect.SOUND_PLOP
						end
						if sound >= 0 then
							sfx:Play(sound, 1, 0, false, 1)
						end
					elseif optionType == MCM.OptionType.BOOLEAN then
						leaveOptions = false
						
						local boolToChange = optionCurrent
						
						if type(optionCurrent) == "function" then
							boolToChange = optionCurrent()
						end
						
						if pressingButton == "RESET" and currentMenuOption.Default ~= nil then
							boolToChange = currentMenuOption.Default
							if type(currentMenuOption.Default) == "function" then
								boolToChange = currentMenuOption.Default()
							end
						else
							boolToChange = (not boolToChange)
						end
						
						if type(optionCurrent) == "function" then
							if optionOnChange then
								optionOnChange(boolToChange)
							end
							optionChanged = true
						elseif type(optionCurrent) == "boolean" then
							currentMenuOption.CurrentSetting = boolToChange
							optionChanged = true
						end
	
						--callback
						CustomCallbackHelper.CallCallbacks
						(
							CustomCallbacks.MCM_POST_MODIFY_SETTING, --callback id
							nil,
							{currentMenuOption.CurrentSetting, boolToChange}, --args to send
							{currentMenuCategory.Name, currentMenuOption.Attribute} --extra variables
						)
						
						local sound = currentMenuOption.Sound
						if not sound then
							sound = SoundEffect.SOUND_PLOP
						end
						if sound >= 0 then
							sfx:Play(sound, 1, 0, false, 1)
						end
					elseif (optionType == MCM.OptionType.KEYBIND_KEYBOARD or optionType == MCM.OptionType.KEYBIND_CONTROLLER) and pressingButton == "RESET" and currentMenuOption.Default ~= nil then
						local numberToChange = optionCurrent
						
						if type(optionCurrent) == "function" then
							numberToChange = optionCurrent()
						end
						
						numberToChange = currentMenuOption.Default
						if type(currentMenuOption.Default) == "function" then
							numberToChange = currentMenuOption.Default()
						end
						
						if type(optionCurrent) == "function" then
							if optionOnChange then
								optionOnChange(numberToChange)
							end
							optionChanged = true
						elseif type(optionCurrent) == "number" then
							currentMenuOption.CurrentSetting = numberToChange
							optionChanged = true
						end
	
						--callback
						CustomCallbackHelper.CallCallbacks
						(
							CustomCallbacks.MCM_POST_MODIFY_SETTING, --callback id
							nil,
							{currentMenuOption.CurrentSetting, numberToChange}, --args to send
							{currentMenuCategory.Name, currentMenuOption.Attribute} --extra variables
						)
						
						local sound = currentMenuOption.Sound
						if not sound then
							sound = SoundEffect.SOUND_PLOP
						end
						if sound >= 0 then
							sfx:Play(sound, 1, 0, false, 1)
						end
					elseif optionType ~= MCM.OptionType.SPACE and pressingButton == "RIGHT" then
						if currentMenuOption.Popup then
							enterPopup = true
						elseif currentMenuOption.OnSelect then
							currentMenuOption.OnSelect()
						end
					end
				end
			end
			
			--confirmed back press
			if pressingButton == "BACK" then
				leaveOptions = true
			end
			
			--confirmed select press
			if pressingButton == "SELECT" then
				if currentMenuOption then
					if currentMenuOption.Popup then
						enterPopup = true
					elseif currentMenuOption.OnSelect then
						currentMenuOption.OnSelect()
					end
				end
			end
			
			--reset command
			if optionChanged then
				if currentMenuOption.Restart or currentMenuOption.Rerun then
					enterPopup = true
				end
			end
		elseif configMenuInSubcategory then
			local hasUsableCategories = false
			if currentMenuCategory.Subcategories then
				for j=1, #currentMenuCategory.Subcategories do
					if currentMenuCategory.Subcategories[j].Name ~= "Uncategorized" then
						hasUsableCategories = true
					end
				end
			end
			if hasUsableCategories then
				--confirmed down press
				if pressingButton == "DOWN" then
					enterOptions = true
				end
				
				--confirmed up press
				if pressingButton == "UP" then
					leaveSubcategory = true
				end
				
				--confirmed right press
				if pressingButton == "RIGHT" then
					configMenuPositionCursorSubcategory = configMenuPositionCursorSubcategory + 1 --move right down
				end
				
				--confirmed left press
				if pressingButton == "LEFT" then
					configMenuPositionCursorSubcategory = configMenuPositionCursorSubcategory - 1 --move cursor left
				end
				
				--confirmed back press
				if pressingButton == "BACK" then
					leaveSubcategory = true
				end
				
				--confirmed select press
				if pressingButton == "SELECT" then
					enterOptions = true
				end
			end
		else
			--confirmed down press
			if pressingButton == "DOWN" then
				configMenuPositionCursorCategory = configMenuPositionCursorCategory + 1 --move left cursor down
			end
			
			--confirmed up press
			if pressingButton == "UP" then
				configMenuPositionCursorCategory = configMenuPositionCursorCategory - 1 --move left cursor up
			end
			
			--confirmed right press
			if pressingButton == "RIGHT" then
				enterSubcategory = true
			end
			
			--confirmed back press
			if pressingButton == "BACK" then
				MCM.CloseConfigMenu()
			end
			
			--confirmed select press
			if pressingButton == "SELECT" then
				enterSubcategory = true
			end
		end
		
		--entering popup
		if enterPopup then
			MCM.EnterPopup()
		end
		
		--leaving popup
		if leavePopup then
			MCM.LeavePopup()
		end
		
		--entering subcategory
		if enterSubcategory then
			MCM.EnterSubcategory()
		end
		
		--entering options
		if enterOptions then
			MCM.EnterOptions()
		end
		
		--leaving options
		if leaveOptions then
			MCM.LeaveOptions()
		end
		
		--leaving subcategory
		if leaveSubcategory then
			MCM.LeaveSubcategory()
		end
		
		--category cursor position was changed
		if lastCursorCategoryPosition ~= configMenuPositionCursorCategory then
			if not configMenuInSubcategory then
			
				--cursor position
				if configMenuPositionCursorCategory < 1 then --move from the top of the list to the bottom
					configMenuPositionCursorCategory = #MCM.MenuData
				end
				if configMenuPositionCursorCategory > #MCM.MenuData then --move from the bottom of the list to the top
					configMenuPositionCursorCategory = 1
				end
				
				--make sure subcategory and option positions are 1
				configMenuPositionCursorSubcategory = 1
				configMenuPositionFirstSubcategory = 1
				configMenuPositionCursorOption = 1
				optionsCurrentOffset = 0
				
			end
		end
		
		--subcategory cursor position was changed
		if lastCursorSubcategoryPosition ~= configMenuPositionCursorSubcategory then
			if not configMenuInOptions then
			
				--cursor position
				if configMenuPositionCursorSubcategory < 1 then --move from the top of the list to the bottom
					configMenuPositionCursorSubcategory = #currentMenuCategory.Subcategories
				end
				if configMenuPositionCursorSubcategory > #currentMenuCategory.Subcategories then --move from the bottom of the list to the top
					configMenuPositionCursorSubcategory = 1
				end
				
				--first category selection to render
				if configMenuPositionFirstSubcategory > 1 and configMenuPositionCursorSubcategory <= configMenuPositionFirstSubcategory+1 then
					configMenuPositionFirstSubcategory = configMenuPositionCursorSubcategory-1
				end
				if configMenuPositionFirstSubcategory+(configMenuSubcategoriesCanShow-1) < #currentMenuCategory.Subcategories and configMenuPositionCursorSubcategory >= 1+(configMenuSubcategoriesCanShow-2) then
					configMenuPositionFirstSubcategory = configMenuPositionCursorSubcategory-(configMenuSubcategoriesCanShow-2)
				end
				configMenuPositionFirstSubcategory = math.min(math.max(configMenuPositionFirstSubcategory, 1), #currentMenuCategory.Subcategories-(configMenuSubcategoriesCanShow-1))
				
				--make sure option positions are 1
				configMenuPositionCursorOption = 1
				optionsCurrentOffset = 0
				
			end
		end
		
		--options cursor position was changed
		if lastCursorOptionsPosition ~= configMenuPositionCursorOption then
			if configMenuInOptions
			and currentMenuSubcategory
			and currentMenuSubcategory.Options
			and #currentMenuSubcategory.Options > 0 then
				
				--find next valid option that isn't a space
				local nextValidOptionSelection = configMenuPositionCursorOption
				local optionIndex = configMenuPositionCursorOption
				for i=1, #currentMenuSubcategory.Options*2 do
				
					local thisOption = currentMenuSubcategory.Options[optionIndex]
					
					if thisOption
					and thisOption.Type
					and thisOption.Type ~= MCM.OptionType.SPACE
					and (not thisOption.NoCursorHere or (type(thisOption.NoCursorHere) == "function" and not thisOption.NoCursorHere()))
					and thisOption.Display then
						
						nextValidOptionSelection = optionIndex
						
						break
					end
					
					if configMenuPositionCursorOption > lastCursorOptionsPosition then
						optionIndex = optionIndex + 1
					elseif configMenuPositionCursorOption < lastCursorOptionsPosition then
						optionIndex = optionIndex - 1
					end
					if optionIndex < 1 then
						optionIndex = #currentMenuSubcategory.Options
					end
					if optionIndex > #currentMenuSubcategory.Options then
						optionIndex = 1
					end
				end
				
				configMenuPositionCursorOption = nextValidOptionSelection
				
				updateCurrentMenuVars()
				
				--first options selection to render
				local hasSubcategories = false
				for j=1, #currentMenuCategory.Subcategories do
					if currentMenuCategory.Subcategories[j].Name ~= "Uncategorized" then
						hasSubcategories = true
					end
				end
				if hasSubcategories then
					--todo
				end
				
			end
		end
		
		local centerPos = MCM.GetScreenCenter()
		
		--title pos handling
		local titlePos = centerPos + Vector(68,-118)
		
		--left pos handling
		
		local leftDesiredOffset = 0
		local leftCanScrollUp = false
		local leftCanScrollDown = false
		
		local numLeft = #MCM.MenuData
		
		local leftPos = centerPos + Vector(-142,-102)
		local leftPosTopmost = centerPos.Y - 116
		local leftPosBottommost = centerPos.Y + 90
		
		if numLeft > 7 then
		
			if configMenuPositionCursorCategory > 6 then
			
				leftCanScrollUp = true
				
				local cursorScroll = configMenuPositionCursorCategory - 6
				local maxLeftScroll = numLeft - 8
				leftDesiredOffset = math.min(cursorScroll, maxLeftScroll) * -14
				
				if cursorScroll < maxLeftScroll then
					leftCanScrollDown = true
				end
			
			else
		
				leftCanScrollDown = true
			
			end
			
		end

		if leftDesiredOffset ~= leftCurrentOffset then
		
			local modifyOffset = math.floor(leftDesiredOffset - leftCurrentOffset)/10
			if modifyOffset > -0.1 and modifyOffset < 0 then
				modifyOffset = -0.1
			end
			if modifyOffset < 0.1 and modifyOffset > 0 then
				modifyOffset = 0.1
			end
			
			leftCurrentOffset = leftCurrentOffset + modifyOffset
			if (leftDesiredOffset - leftCurrentOffset) < 0.25 and (leftDesiredOffset - leftCurrentOffset) > -0.25 then
				leftCurrentOffset = leftDesiredOffset
			end
			
		end
		
		if leftCurrentOffset ~= 0 then
			leftPos = leftPos + Vector(0, leftCurrentOffset)
		end
		
		--options pos handling
		local optionsDesiredOffset = 0
		local optionsCanScrollUp = false
		local optionsCanScrollDown = false
		
		local numOptions = 0
		
		local optionPos = centerPos + Vector(68,-18)
		local optionPosTopmost = centerPos.Y - 108
		local optionPosBottommost = centerPos.Y + 86
		
		if currentMenuSubcategory
		and currentMenuSubcategory.Options
		and #currentMenuSubcategory.Options > 0 then
			
			numOptions = #currentMenuSubcategory.Options
		
			local hasSubcategories = false
			if currentMenuCategory.Subcategories then
				for j=1, #currentMenuCategory.Subcategories do
					if currentMenuCategory.Subcategories[j].Name ~= "Uncategorized" then
						numOptions = numOptions + 2
						hasSubcategories = true
						break
					end
				end
			end
			
			if hasSubcategories then
				optionPos = optionPos + Vector(0, -70)
			else
				optionPos = optionPos + Vector(0, math.min(numOptions-1, 10) * -7)
			end
			
			if numOptions > 12 then
			
				if configMenuPositionCursorOption > 6 and configMenuInOptions then
				
					optionsCanScrollUp = true
					
					local cursorScroll = configMenuPositionCursorOption - 6
					local maxOptionsScroll = numOptions - 12
					optionsDesiredOffset = math.min(cursorScroll, maxOptionsScroll) * -14
					
					if cursorScroll < maxOptionsScroll then
						optionsCanScrollDown = true
					end
				
				else
			
					optionsCanScrollDown = true
				
				end
				
			end
			
		end
	
		if optionsDesiredOffset ~= optionsCurrentOffset then
		
			local modifyOffset = math.floor(optionsDesiredOffset - optionsCurrentOffset)/10
			if modifyOffset > -0.1 and modifyOffset < 0 then
				modifyOffset = -0.1
			end
			if modifyOffset < 0.1 and modifyOffset > 0 then
				modifyOffset = 0.1
			end
			
			optionsCurrentOffset = optionsCurrentOffset + modifyOffset
			if (optionsDesiredOffset - optionsCurrentOffset) < 0.25 and (optionsDesiredOffset - optionsCurrentOffset) > -0.25 then
				optionsCurrentOffset = optionsDesiredOffset
			end
			
		end
		
		if optionsCurrentOffset ~= 0 then
			optionPos = optionPos + Vector(0, optionsCurrentOffset)
		end
		
		--info pos handling
		local infoPos = centerPos + Vector(-4,106)
	
		MenuSprite:Render(centerPos, vecZero, vecZero)
		
		--get if controls can be shown
		local shouldShowControls = true
		if configMenuInOptions and currentMenuOption and currentMenuOption.HideControls then
			shouldShowControls = false
		end
		if not MCM.Config["Mod Config Menu"].ShowControls then
			shouldShowControls = false
		end
		
		--category
		local lastLeftPos = leftPos
		local renderedLeft = 0
		for categoryIndex=1, #MCM.MenuData do
		
			--text
			if lastLeftPos.Y > leftPosTopmost and lastLeftPos.Y < leftPosBottommost then
			
				local textToDraw = tostring(MCM.MenuData[categoryIndex].Name)
				
				local color = leftFontColor
				--[[
				if configMenuPositionCursorCategory == categoryIndex then
					color = leftFontColorSelected
				end
				]]
				
				local posOffset = Font12:GetStringWidthUTF8(textToDraw)/2
				Font12:DrawString(textToDraw, lastLeftPos.X - posOffset, lastLeftPos.Y - 8, color, 0, true)
				
				--cursor
				if configMenuPositionCursorCategory == categoryIndex then
					CursorSpriteRight:Render(lastLeftPos + Vector((posOffset + 10)*-1,0), vecZero, vecZero)
				end
				
			end
			
			--increase counter
			renderedLeft = renderedLeft + 1
			
			--pos mod
			lastLeftPos = lastLeftPos + Vector(0,16)
			
		end
		
		--render scroll arrows
		if leftCanScrollUp then
			CursorSpriteUp:Render(centerPos + Vector(-78,-104), vecZero, vecZero) --up arrow
		end
		if leftCanScrollDown then
			CursorSpriteDown:Render(centerPos + Vector(-78,70), vecZero, vecZero) --down arrow
		end
		
		------------------------
		--RENDER SUBCATEGORIES--
		------------------------
		
		local lastOptionPos = optionPos
		local renderedOptions = 0
		
		if currentMenuCategory then
		
			local hasUncategorizedCategory = false
			local hasSubcategories = false
			local numCategories = 0
			for j=1, #currentMenuCategory.Subcategories do
				if currentMenuCategory.Subcategories[j].Name == "Uncategorized" then
					hasUncategorizedCategory = true
				else
					hasSubcategories = true
					numCategories = numCategories + 1
				end
			end
			
			if hasSubcategories then
				
				if hasUncategorizedCategory then
					numCategories = numCategories + 1
				end
				
				if lastOptionPos.Y > optionPosTopmost and lastOptionPos.Y < optionPosBottommost then
				
					local lastSubcategoryPos = optionPos
					if numCategories == 2 then
						lastSubcategoryPos = lastOptionPos + Vector(-38,0)
					elseif numCategories >= 3 then
						lastSubcategoryPos = lastOptionPos + Vector(-76,0)
					end
				
					local renderedSubcategories = 0
				
					for subcategoryIndex=1, #currentMenuCategory.Subcategories do
					
						if subcategoryIndex >= configMenuPositionFirstSubcategory then
						
							local thisSubcategory = currentMenuCategory.Subcategories[subcategoryIndex]
							
							local posOffset = 0
						
							if thisSubcategory.Name then
								local textToDraw = thisSubcategory.Name
								
								textToDraw = tostring(textToDraw)
								
								local color = subcategoryFontColor
								if not configMenuInSubcategory then
									color = subcategoryFontColorAlpha
								--[[
								elseif configMenuPositionCursorSubcategory == subcategoryIndex and configMenuInSubcategory then
									color = subcategoryFontColorSelected
								]]
								end
								
								posOffset = Font12:GetStringWidthUTF8(textToDraw)/2
								Font12:DrawString(textToDraw, lastSubcategoryPos.X - posOffset, lastSubcategoryPos.Y - 8, color, 0, true)
							end
							
							--cursor
							if configMenuPositionCursorSubcategory == subcategoryIndex and configMenuInSubcategory then
								CursorSpriteRight:Render(lastSubcategoryPos + Vector((posOffset + 10)*-1,0), vecZero, vecZero)
							end
							
							--increase counter
							renderedSubcategories = renderedSubcategories + 1
						
							if renderedSubcategories >= configMenuSubcategoriesCanShow then --if this is the last one we should render
							
								--render scroll arrows
								if configMenuPositionFirstSubcategory > 1 then --if the first one we rendered wasn't the first in the list
									SubcategoryCursorSpriteLeft:Render(lastOptionPos + Vector(-125,0), vecZero, vecZero)
								end
								
								if subcategoryIndex < #currentMenuCategory.Subcategories then --if this isn't the last thing
									SubcategoryCursorSpriteRight:Render(lastOptionPos + Vector(125,0), vecZero, vecZero)
								end
								
								break
								
							end
						
							--pos mod
							lastSubcategoryPos = lastSubcategoryPos + Vector(76,0)
						
						end
						
					end
				
				end
				
				--subcategory selection counts as an option that gets rendered
				renderedOptions = renderedOptions + 1
				lastOptionPos = lastOptionPos + Vector(0,14)
				
				--subcategory to options divider
				if lastOptionPos.Y > optionPosTopmost and lastOptionPos.Y < optionPosBottommost then
				
					SubcategoryDividerSprite:Render(lastOptionPos, vecZero, vecZero)
					
				end
				
				--subcategory to options divider counts as an option that gets rendered
				renderedOptions = renderedOptions + 1
				lastOptionPos = lastOptionPos + Vector(0,14)

			end
		end
		
		------------------
		--RENDER OPTIONS--
		------------------
		
		local firstOptionPos = lastOptionPos
		
		if currentMenuSubcategory
		and currentMenuSubcategory.Options
		and #currentMenuSubcategory.Options > 0 then
		
			for optionIndex=1, #currentMenuSubcategory.Options do
				
				local thisOption = currentMenuSubcategory.Options[optionIndex]
				
				local cursorIsAtThisOption = configMenuPositionCursorOption == optionIndex and configMenuInOptions
				local posOffset = 10
				
				if lastOptionPos.Y > optionPosTopmost and lastOptionPos.Y < optionPosBottommost then
					
					if thisOption.Type
					and thisOption.Type ~= MCM.OptionType.SPACE
					and thisOption.Display then
					
						local optionType = thisOption.Type
						local optionDisplay = thisOption.Display
						local optionColor = thisOption.Color
		
						local useAltSlider = thisOption.AltSlider
						
						--get what to draw
						if optionType == MCM.OptionType.TEXT
						or optionType == MCM.OptionType.BOOLEAN
						or optionType == MCM.OptionType.NUMBER
						or optionType == MCM.OptionType.KEYBIND_KEYBOARD
						or optionType == MCM.OptionType.KEYBIND_CONTROLLER
						or optionType == MCM.OptionType.TITLE then
							local textToDraw = optionDisplay
							
							if type(optionDisplay) == "function" then
								textToDraw = optionDisplay(cursorIsAtThisOption, configMenuInOptions, lastOptionPos)
							end
							
							textToDraw = tostring(textToDraw)
							
							local heightOffset = 6
							local font = Font10
							local color = optionsFontColor
							if not configMenuInOptions then
								if thisOption.NoCursorHere then
									color = optionsFontColorNoCursorAlpha
								else
									color = optionsFontColorAlpha
								end
							elseif thisOption.NoCursorHere then
								color = optionsFontColorNoCursor
							end
							if optionType == MCM.OptionType.TITLE then
								heightOffset = 8
								font = Font12
								color = optionsFontColorTitle
								if not configMenuInOptions then
									color = optionsFontColorTitleAlpha
								end
							end
							
							if optionColor then
								color = KColor(optionColor[1], optionColor[2], optionColor[3], color.Alpha)
							end
							
							posOffset = font:GetStringWidthUTF8(textToDraw)/2
							font:DrawString(textToDraw, lastOptionPos.X - posOffset, lastOptionPos.Y - heightOffset, color, 0, true)
						elseif optionType == MCM.OptionType.SCROLL then
							local numberToShow = optionDisplay
							
							if type(optionDisplay) == "function" then
								numberToShow = optionDisplay(cursorIsAtThisOption, configMenuInOptions, lastOptionPos)
							end
							
							posOffset = 31
							local scrollOffset = 0
							
							if type(numberToShow) == "number" then
								numberToShow = math.max(math.min(math.floor(numberToShow), 10), 0)
							elseif type(numberToShow) == "string" then
								local numberToShowStart, numberToShowEnd = string.find(numberToShow, "$scroll")
								if numberToShowStart and numberToShowEnd then
									local numberStart = numberToShowEnd+1
									local numberEnd = numberToShowEnd+3
									local numberString = string.sub(numberToShow, numberStart, numberEnd)
									numberString = tonumber(numberString)
									if not numberString or (numberString and not type(numberString) == "number") or (numberString and type(numberString) == "number" and numberString < 10) then
										numberEnd = numberEnd-1
										numberString = string.sub(numberToShow, numberStart, numberEnd)
										numberString = tonumber(numberString)
									end
									if numberString and type(numberString) == "number" then
										local textToDrawPreScroll = string.sub(numberToShow, 0, numberToShowStart-1)
										local textToDrawPostScroll = string.sub(numberToShow, numberEnd, string.len(numberToShow))
										local textToDraw = textToDrawPreScroll .. "               " .. textToDrawPostScroll
										
										local color = optionsFontColor
										if not configMenuInOptions then
											color = optionsFontColorAlpha
										end
										if optionColor then
											color = KColor(optionColor[1], optionColor[2], optionColor[3], color.Alpha)
										end
										
										scrollOffset = posOffset
										posOffset = Font10:GetStringWidthUTF8(textToDraw)/2
										Font10:DrawString(textToDraw, lastOptionPos.X - posOffset, lastOptionPos.Y - 6, color, 0, true)
										
										scrollOffset = posOffset - (Font10:GetStringWidthUTF8(textToDrawPreScroll)+scrollOffset)
										numberToShow = numberString
									end
								end
							end
							
							local scrollColor = optionsSpriteColor
							if not configMenuInOptions then
								scrollColor = optionsSpriteColorAlpha
							end
							if optionColor then
								scrollColor = Color(optionColor[1], optionColor[2], optionColor[3], scrollColor.A, scrollColor.RO, scrollColor.GO, scrollColor.BO)
							end
							
							local sliderString = "Slider1"
							if useAltSlider then
								sliderString = "Slider2"
							end
							
							SliderSprite.Color = scrollColor
							SliderSprite:SetFrame(sliderString, numberToShow)
							SliderSprite:Render(lastOptionPos - Vector(scrollOffset, -2), vecZero, vecZero)
							
						end
						
						local showStrikeout = thisOption.ShowStrikeout
						if posOffset > 0 and (type(showStrikeout) == "boolean" and showStrikeout == true) or (type(showStrikeout) == "function" and showStrikeout() == true) then
							if configMenuInOptions then
								StrikeOutSprite.Color = colorDefault
							else
								StrikeOutSprite.Color = colorHalf
							end
							StrikeOutSprite:SetFrame("Strikeout", math.floor(posOffset))
							StrikeOutSprite:Render(lastOptionPos, vecZero, vecZero)
						end
					end
					
					--cursor
					if cursorIsAtThisOption then
						CursorSpriteRight:Render(lastOptionPos + Vector((posOffset + 10)*-1,0), vecZero, vecZero)
					end
				
				end
				
				--increase counter
				renderedOptions = renderedOptions + 1
				
				--pos mod
				lastOptionPos = lastOptionPos + Vector(0,14)
				
			end
			
			--render scroll arrows
			if optionsCanScrollUp then
				OptionsCursorSpriteUp:Render(centerPos + Vector(193,-86), vecZero, vecZero) --up arrow
			end
			if optionsCanScrollDown then
			
				local yPos = 66
				if shouldShowControls then
					yPos = 40
				end
				
				OptionsCursorSpriteDown:Render(centerPos + Vector(193,yPos), vecZero, vecZero) --down arrow
				
			end
		
		end
		
		MenuOverlaySprite:Render(centerPos, vecZero, vecZero)
		
		--title
		local titleText = "Mod Config Menu"
		if configMenuInSubcategory then
			titleText = tostring(currentMenuCategory.Name)
		end
		local titleTextOffset = Font16Bold:GetStringWidthUTF8(titleText)/2
		Font16Bold:DrawString(titleText, titlePos.X - titleTextOffset, titlePos.Y - 9, mainFontColor, 0, true)
		
		--info
		local infoTable = nil
		local isOldInfo = false
		
		if configMenuInOptions then
		
			if currentMenuOption and currentMenuOption.Info then
				infoTable = currentMenuOption.Info
			end
			
		elseif configMenuInSubcategory then
		
			if currentMenuSubcategory and currentMenuSubcategory.Info then
				infoTable = currentMenuSubcategory.Info
			end
			
		elseif currentMenuCategory and currentMenuCategory.Info then
			
			infoTable = currentMenuCategory.Info
			if currentMenuCategory.IsOld then
				isOldInfo = true
			end
			
		end
		
		if infoTable then
			
			local lineWidth = 340
			if shouldShowControls then
				lineWidth = 260
			end
			
			local infoTableDisplay = MCM.ConvertDisplayToTextTable(infoTable, lineWidth, Font10)
			
			local lastInfoPos = infoPos - Vector(0,6*#infoTableDisplay)
			for line=1, #infoTableDisplay do
			
				--text
				local textToDraw = tostring(infoTableDisplay[line])
				local posOffset = Font10:GetStringWidthUTF8(textToDraw)/2
				local color = mainFontColor
				if isOldInfo then
					color = optionsFontColorTitle
				end
				Font10:DrawString(textToDraw, lastInfoPos.X - posOffset, lastInfoPos.Y - 6, color, 0, true)
				
				--pos mod
				lastInfoPos = lastInfoPos + Vector(0,10)
				
			end
			
		end
		
		--hud offset
		if configMenuInOptions
		and currentMenuOption
		and currentMenuOption.ShowOffset then
		
			--render the visual
			HudOffsetVisualBottomRight:Render(MCM.GetScreenBottomRight(), vecZero, vecZero)
			HudOffsetVisualBottomLeft:Render(MCM.GetScreenBottomLeft(), vecZero, vecZero)
			HudOffsetVisualTopRight:Render(MCM.GetScreenTopRight(), vecZero, vecZero)
			HudOffsetVisualTopLeft:Render(MCM.GetScreenTopLeft(), vecZero, vecZero)
			
		end
		
		--popup
		if configMenuInPopup
		and currentMenuOption
		and (currentMenuOption.Popup or currentMenuOption.Restart or currentMenuOption.Rerun) then
		
			PopupSprite:Render(centerPos, vecZero, vecZero)
			
			local popupTable = currentMenuOption.Popup
			
			if not popupTable then
			
				if currentMenuOption.Restart then
				
					popupTable = "Restart the game for this setting to take effect"
				
				end
			
				if currentMenuOption.Rerun then
				
					popupTable = "Start a new run for this setting to take effect"
				
				end
				
			end
			
			if popupTable then
				
				local lineWidth = currentMenuOption.PopupWidth or 180
				
				local popupTableDisplay = MCM.ConvertDisplayToTextTable(popupTable, lineWidth, Font10)
				
				local lastPopupPos = (centerPos + Vector(0,2)) - Vector(0,6*#popupTableDisplay)
				for line=1, #popupTableDisplay do
				
					--text
					local textToDraw = tostring(popupTableDisplay[line])
					local posOffset = Font10:GetStringWidthUTF8(textToDraw)/2
					Font10:DrawString(textToDraw, lastPopupPos.X - posOffset, lastPopupPos.Y - 6, mainFontColor, 0, true)
					
					--pos mod
					lastPopupPos = lastPopupPos + Vector(0,10)
					
				end
			
			end
			
		end
		
		--controls
		if shouldShowControls then

			--back
			local bottomLeft = MCM.GetScreenBottomLeft(0)
			if not configMenuInSubcategory then
				CornerExit:Render(bottomLeft, vecZero, vecZero)
			else
				CornerBack:Render(bottomLeft, vecZero, vecZero)
			end

			local goBackString = ""
			if MCM.Config.LastBackPressed then
				if MCM.KeyboardToString[MCM.Config.LastBackPressed] then
					goBackString = MCM.KeyboardToString[MCM.Config.LastBackPressed]
				elseif MCM.ControllerToString[MCM.Config.LastBackPressed] then
					goBackString = MCM.ControllerToString[MCM.Config.LastBackPressed]
				end
			end
			Font10:DrawString(goBackString, (bottomLeft.X - Font10:GetStringWidthUTF8(goBackString)/2) + 36, bottomLeft.Y - 24, mainFontColor, 0, true)

			--select
			local bottomRight = MCM.GetScreenBottomRight(0)
			if not configMenuInPopup then
			
				local foundValidPopup = false
				--[[
				if configMenuInSubcategory
				and configMenuInOptions
				and currentMenuOption
				and currentMenuOption.Type
				and currentMenuOption.Type ~= MCM.OptionType.SPACE
				and currentMenuOption.Popup then
					foundValidPopup = true
				end
				]]
				
				if foundValidPopup then
					CornerOpen:Render(bottomRight, vecZero, vecZero)
				else
					CornerSelect:Render(bottomRight, vecZero, vecZero)
				end
				
				local selectString = ""
				if MCM.Config.LastSelectPressed then
					if MCM.KeyboardToString[MCM.Config.LastSelectPressed] then
						selectString = MCM.KeyboardToString[MCM.Config.LastSelectPressed]
					elseif MCM.ControllerToString[MCM.Config.LastSelectPressed] then
						selectString = MCM.ControllerToString[MCM.Config.LastSelectPressed]
					end
				end
				Font10:DrawString(selectString, (bottomRight.X - Font10:GetStringWidthUTF8(selectString)/2) - 36, bottomRight.Y - 24, mainFontColor, 0, true)
				
			end
			
		end
		
	else
	
		for i=0, game:GetNumPlayers()-1 do
		
			local player = Isaac.GetPlayer(i)
			local data = player:GetData()
			
			--enable player controls
			if data.ConfigMenuPlayerPosition then
				data.ConfigMenuPlayerPosition = nil
			end
			if data.ConfigMenuPlayerControlsDisabled then
				player.ControlsEnabled = true
				data.ConfigMenuPlayerControlsDisabled = false
			end
			
		end
		
		configMenuInSubcategory = false
		configMenuInOptions = false
		configMenuInPopup = false
		
		holdingCounterDown = 0
		holdingCounterUp = 0
		holdingCounterLeft = 0
		holdingCounterRight = 0
		
		configMenuPositionCursorCategory = 1
		configMenuPositionCursorSubcategory = 1
		configMenuPositionCursorOption = 1
		
		configMenuPositionFirstSubcategory = 1
		
		leftCurrentOffset = 0
		optionsCurrentOffset = 0
		
	end
end
MCM.Mod:AddCallback(ModCallbacks.MC_POST_RENDER, MCM.PostRender)

function MCM.OpenConfigMenu()

	if MCM.RoomIsSafe() then
	
		if MCM.Config["Mod Config Menu"].HideHudInMenu then
		
			local game = Game()
			local seeds = game:GetSeeds()
			seeds:AddSeedEffect(SeedEffect.SEED_NO_HUD)
			
		end
		
		MCM.IsVisible = true
		
	else
	
		local sfx = SFXManager()
		sfx:Play(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.75, 0, false, 1)
		
	end
	
end

function MCM.CloseConfigMenu()

	MCM.LeavePopup()
	MCM.LeaveOptions()
	MCM.LeaveSubcategory()

	local game = Game()
	if REPENTANCE then
		local hud = game:GetHUD()
		hud:SetVisible(true)
	else
		local seeds = game:GetSeeds()
		seeds:RemoveSeedEffect(SeedEffect.SEED_NO_HUD)
	end
	
	
	MCM.IsVisible = false
	
end

function MCM.ToggleConfigMenu()
	if MCM.IsVisible then
		MCM.CloseConfigMenu()
	else
		MCM.OpenConfigMenu()
	end
end

function MCM.InputAction(_, entity, inputHook, buttonAction)

	if MCM.IsVisible and buttonAction ~= ButtonAction.ACTION_FULLSCREEN and buttonAction ~= ButtonAction.ACTION_CONSOLE then
	
		if inputHook == InputHook.IS_ACTION_PRESSED or inputHook == InputHook.IS_ACTION_TRIGGERED then 
			return false
		else
			return 0
		end
		
	end
	
end
MCM.Mod:AddCallback(ModCallbacks.MC_INPUT_ACTION, MCM.InputAction)

--console commands that toggle the menu
local toggleCommands = {
	["modconfigmenu"] = true,
	["modconfig"] = true,
	["mcm"] = true,
	["mc"] = true
}
function MCM.ExecuteCmd(_, command, args)

	command = command:lower()
	
	if toggleCommands[command] then
	
		MCM.ToggleConfigMenu()
		
	end
	
end
MCM.Mod:AddCallback(ModCallbacks.MC_EXECUTE_CMD, MCM.ExecuteCmd)

if MCM.StandaloneMod then

	if not MCM.StandaloneSaveLoaded then
		SaveHelper.Load(MCM.StandaloneMod)
		MCM.StandaloneSaveLoaded = true
	end

end

-----------------
--LEGACY COMPAT--
-----------------
function MCM.ReturnNil()
	return nil
end
function MCM.ReturnFalse()
	return false
end

--Make old mods that use old versions of Mod Config Menu still kinda work
MCM.CompatibilityMode = true
local cachedVectorsAndColors = {
	["VECTOR_ZERO"] = Vector(0,0),
	["VECTOR_ONE"] = Vector(1,1),
	["VECTOR_LEFT"] = Vector(-1,0),
	["VECTOR_UP"] = Vector(0,-1),
	["VECTOR_RIGHT"] = Vector(1,0),
	["VECTOR_DOWN"] = Vector(0,1),
	["VECTOR_UP_LEFT"] = Vector(-1,-1),
	["VECTOR_UP_RIGHT"] = Vector(1,-1),
	["VECTOR_DOWN_LEFT"] = Vector(-1,1),
	["VECTOR_DOWN_RIGHT"] = Vector(1,1),
	["COLOR_DEFAULT"] = Color(1,1,1,1,0,0,0),
	["COLOR_HALF"] = Color(1,1,1,0.5,0,0,0),
	["COLOR_INVISIBLE"] = Color(1,1,1,0,0,0,0),
	["KCOLOR_DEFAULT"] = KColor(1,1,1,1),
	["KCOLOR_HALF"] = KColor(1,1,1,0.5),
	["KCOLOR_INVISIBLE"] = KColor(1,1,1,0)
}
local fakeCachedDataToReturn = {
	Game = Game,
	Seeds = function() return Game():GetSeeds() end,
	Level = function() return Game():GetLevel() end,
	Room = function() return Game():GetRoom() end,
	SFX = SFXManager
}
setmetatable(MCM, {
	__index = function(this, key)
		if fakeCachedDataToReturn[key] then
			print("MCM." .. key .. " is no longer used. Please update.")
			return fakeCachedDataToReturn[key]()
		end
		if cachedVectorsAndColors[key] then
			print("MCM." .. key .. " is no longer used. Please update.")
			return cachedVectorsAndColors[key]
		end
	end
})

local fakeConfigDefaultToReturn = {
	HudOffset = function() return MCM.ConfigDefault["General"].HudOffset end,
	Overlays = function() return MCM.ConfigDefault["General"].Overlays end,
	ChargeBars = function() return MCM.ConfigDefault["General"].ChargeBars end,
	BigBooks = function() return MCM.ConfigDefault["General"].BigBooks end,
}
setmetatable(MCM.ConfigDefault, {
	__index = function(this, key)
		if fakeConfigDefaultToReturn[key] then
			print("MCM.ConfigDefault." .. key .. " is no longer used. Please update to use MCM.ConfigDefault.[\"General\"]." .. key .. " instead.")
			return fakeConfigDefaultToReturn[key]()
		end
		return rawget(this, key)
	end,
	__newindex = function(this, key, value)
		if fakeConfigDefaultToReturn[key] then
			print("MCM.ConfigDefault." .. key .. " is no longer used. Please update to use MCM.ConfigDefault.[\"General\"]." .. key .. " instead.")
			rawset(this["General"], key, value)
		else
			rawset(this, key, value)
		end
	end
})

local fakeConfigToReturn = {
	HudOffset = function() return MCM.Config["General"].HudOffset end,
	Overlays = function() return MCM.Config["General"].Overlays end,
	ChargeBars = function() return MCM.Config["General"].ChargeBars end,
	BigBooks = function() return MCM.Config["General"].BigBooks end,
}
setmetatable(MCM.Config, {
	__index = function(this, key)
		if fakeConfigToReturn[key] then
			print("MCM.Config." .. key .. " is no longer used. Please update to use MCM.Config.[\"General\"]." .. key .. " instead.")
			return fakeConfigToReturn[key]()
		end
		return rawget(this, key)
	end,
	__newindex = function(this, key, value)
		if fakeConfigDefaultToReturn[key] then
			print("MCM.Config." .. key .. " is no longer used. Please update to use MCM.Config.[\"General\"]." .. key .. " instead.")
			rawset(this["General"], key, value)
		else
			rawset(this, key, value)
		end
	end
})

ModConfigMenuController = {}
setmetatable(ModConfigMenuController, {
	__index = function(this, key)
		if Controller and Controller[key] then
			print("ModConfigMenuController." .. key .. " is no longer used. Please update to use Controller." .. key .. " instead. This enum is added by MCM.")
			return Controller[key]
		end
		return rawget(this, key)
	end
})

ModConfigMenuKeyboardToString = {}
setmetatable(ModConfigMenuKeyboardToString, {
	__index = function(this, key)
		if MCM and MCM.KeyboardToString and MCM.KeyboardToString[key] then
			print("ModConfigMenuKeyboardToString." .. key .. " is no longer used. Please update to use MCM.KeyboardToString." .. key .. " instead.")
			return MCM.KeyboardToString[key]
		end
		return rawget(this, key)
	end
})

ModConfigMenuControllerToString = {}
setmetatable(ModConfigMenuControllerToString, {
	__index = function(this, key)
		if MCM and MCM.ControllerToString and MCM.ControllerToString[key] then
			print("ModConfigMenuControllerToString." .. key .. " is no longer used. Please update to use MCM.ControllerToString." .. key .. " instead.")
			return MCM.ControllerToString[key]
		end
		return rawget(this, key)
	end
})

ModConfigMenuPopupGfx = {}
setmetatable(ModConfigMenuPopupGfx, {
	__index = function(this, key)
		if MCM.PopupGfx[key] then
			print("ModConfigMenuPopupGfx." .. key .. " is no longer used. Please update to use MCM.PopupGfx." .. key .. " instead.")
			return MCM.PopupGfx[key]
		end
		return rawget(this, key)
	end
})

ModConfigMenuOptionType = {}
setmetatable(ModConfigMenuOptionType, {
	__index = function(this, key)
		if MCM.OptionType[key] then
			print("ModConfigMenuOptionType." .. key .. " is no longer used. Please update to use MCM.OptionType." .. key .. " instead.")
			return MCM.OptionType[key]
		end
		return rawget(this, key)
	end
})

ModConfigMenuData = MCM.MenuData
CustomCallbackHelper.Callbacks = CustomCallbackHelper.Callbacks or {}
CustomCallbackHelper.Callbacks.MCM_POST_MODIFY_HUD_OFFSET = 4300
MCM.Mod:AddCustomCallback(CustomCallbacks.CCH_PRE_ADD_CUSTOM_CALLBACK, function(mod, modRef, callbackId, fn, args)
	print("CallbackHelper.Callbacks.MCM_POST_MODIFY_HUD_OFFSET is no longer used. Please update to use CustomCallbacks.MCM_POST_MODIFY_SETTING with extra variables \"General\" and \"HudOffset\".")
	modRef:AddCustomCallback(CustomCallbacks.MCM_POST_MODIFY_SETTING, function(modRef, settingTable, currentSetting)
		fn(modRef, currentSetting)
	end, "General", "HudOffset")
	return false
end, CustomCallbackHelper.Callbacks.MCM_POST_MODIFY_HUD_OFFSET)

CustomCallbackHelper.Callbacks.MCM_POST_MODIFY_OVERLAYS = 4301
MCM.Mod:AddCustomCallback(CustomCallbacks.CCH_PRE_ADD_CUSTOM_CALLBACK, function(mod, modRef, callbackId, fn, args)
	print("CallbackHelper.Callbacks.MCM_POST_MODIFY_HUD_OFFSET is no longer used. Please update to use CustomCallbacks.MCM_POST_MODIFY_SETTING with extra variables \"General\" and \"Overlays\".")
	modRef:AddCustomCallback(CustomCallbacks.MCM_POST_MODIFY_SETTING, function(modRef, settingTable, currentSetting)
		fn(modRef, currentSetting)
	end, "General", "Overlays")
	return false

end, CustomCallbackHelper.Callbacks.MCM_POST_MODIFY_OVERLAYS)

CustomCallbackHelper.Callbacks.MCM_POST_MODIFY_CHARGE_BARS = 4302
MCM.Mod:AddCustomCallback(CustomCallbacks.CCH_PRE_ADD_CUSTOM_CALLBACK, function(mod, modRef, callbackId, fn, args)
	print("CallbackHelper.Callbacks.MCM_POST_MODIFY_HUD_OFFSET is no longer used. Please update to use CustomCallbacks.MCM_POST_MODIFY_SETTING with extra variables \"General\" and \"ChargeBars\".")
	modRef:AddCustomCallback(CustomCallbacks.MCM_POST_MODIFY_SETTING, function(modRef, settingTable, currentSetting)
		fn(modRef, currentSetting)
	end, "General", "ChargeBars")
	return false
end, CustomCallbackHelper.Callbacks.MCM_POST_MODIFY_CHARGE_BARS)

CustomCallbackHelper.Callbacks.MCM_POST_MODIFY_BIG_BOOKS = 4303
MCM.Mod:AddCustomCallback(CustomCallbacks.CCH_PRE_ADD_CUSTOM_CALLBACK, function(mod, modRef, callbackId, fn, args)
	print("CallbackHelper.Callbacks.MCM_POST_MODIFY_HUD_OFFSET is no longer used. Please update to use CustomCallbacks.MCM_POST_MODIFY_SETTING with extra variables \"General\" and \"BigBooks\".")
	modRef:AddCustomCallback(CustomCallbacks.MCM_POST_MODIFY_SETTING, function(modRef, settingTable, currentSetting)
		fn(modRef, currentSetting)
	end, "General", "BigBooks")
	return false
end, CustomCallbackHelper.Callbacks.MCM_POST_MODIFY_BIG_BOOKS)

MCM.AddHudOffsetChangeCallback = function(functionToAdd)
	print("MCM.AddHudOffsetChangeCallback is no longer used. Please update to use mod:AddCustomCallback added by CustomCallbackHelper using CustomCallbacks.MCM_POST_MODIFY_SETTING with extra variables \"General\" and \"HudOffset\".")
	MCM.Mod:AddCustomCallback(CustomCallbacks.MCM_POST_MODIFY_SETTING, function(modRef, settingTable, currentSetting)
		functionToAdd(currentSetting)
	end, "General", "HudOffset")
end

MCM.AddOverlayChangeCallback = function(functionToAdd)
	print("MCM.AddOverlayChangeCallback is no longer used. Please update to use mod:AddCustomCallback added by CustomCallbackHelper using CustomCallbacks.MCM_POST_MODIFY_SETTING with extra variables \"General\" and \"Overlays\".")
	MCM.Mod:AddCustomCallback(CustomCallbacks.MCM_POST_MODIFY_SETTING, function(modRef, settingTable, currentSetting)
		functionToAdd(currentSetting)
	end, "General", "Overlays")
end

MCM.AddChargeBarChangeCallback = function(functionToAdd)
	print("MCM.AddChargeBarChangeCallback is no longer used. Please update to use mod:AddCustomCallback added by CustomCallbackHelper using CustomCallbacks.MCM_POST_MODIFY_SETTING with extra variables \"General\" and \"ChargeBars\".")
	MCM.Mod:AddCustomCallback(CustomCallbacks.MCM_POST_MODIFY_SETTING, function(modRef, settingTable, currentSetting)
		functionToAdd(currentSetting)
	end, "General", "ChargeBars")
end

MCM.AddBigBookChangeCallback = function(functionToAdd)
	print("MCM.AddBigBookChangeCallback is no longer used. Please update to use mod:AddCustomCallback added by CustomCallbackHelper using CustomCallbacks.MCM_POST_MODIFY_SETTING with extra variables \"General\" and \"BigBooks\".")
	MCM.Mod:AddCustomCallback(CustomCallbacks.MCM_POST_MODIFY_SETTING, function(modRef, settingTable, currentSetting)
		functionToAdd(currentSetting)
	end, "General", "BigBooks")
end

ModConfigMenu = MCM
if not MCM.oldpcall then
	MCM.oldpcall = pcall
	function MCM.pcall(func, path, ...)
		if path == "scripts.modconfig" then
			return true, MCM
		end
		return MCM.oldpcall(func, path, ...)
	end
	pcall = MCM.pcall
end

--Make old mods that use ScreenHelper still kinda work
ScreenHelper = MCM

--Make old mods that use FilepathHelper still kinda work
FilepathHelper = MCM
FilepathHelper.KnownFilePathsByName = {["resources/scripts/"]=true,["mods"]=true}
FilepathHelper.KnownFilePathsByIndex = {"resources/scripts/","mods"}
function FilepathHelper.GetCurrentModPath() return FilepathHelper.KnownFilePathsByIndex[1] end
function FilepathHelper.DoFile(path)
	if type(include) == "function" then
		print("dofile should no longer be used. Please update to use the include function.")
	else
		print("dofile should no longer be used. Please update to use the require function.")
	end
	return exec(path)
end
FilepathHelper.OldDoFile = FilepathHelper.DoFile
if not dofile then
	dofile = FilepathHelper.DoFile
end
FilepathHelper.TestPath = MCM.ReturnNil
FilepathHelper.IsFile = MCM.ReturnFalse
FilepathHelper.IsDirectory = MCM.ReturnFalse
FilepathHelper.IsAnm2 = MCM.ReturnFalse
FilepathHelper.OldRegisterMod = Isaac.RegisterMod
FilepathHelper.RegisterMod = Isaac.RegisterMod

--Make old mods that use InputHelper still kinda work
InputHelper = MCM

------------
--FINISHED--
------------
Isaac.DebugString("Mod Config Menu v" .. MCM.GetVersionString() .. " loaded!")
print("Mod Config Menu v" .. MCM.GetVersionString() .. " loaded!")


return MCM
