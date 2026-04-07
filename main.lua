--this script handles saving for the standalone version of mod config menu

--load some scripts
local function exec(path)
	if type(include) == "function" then -- trick to try to detect if we're on repentance
		include(path)
	else -- if not then we're in afterbirth plus
		require(path)
	end
end

exec("scripts.filepathhelper")
exec("scripts.customcallbacks")
exec("scripts.savehelper")

--create the mod
local mod = RegisterMod("Mod Config Menu Standalone", 1)

ModConfigMenu = ModConfigMenu or {}
ModConfigMenu.StandaloneMod = mod

--add MCM's save to savehelper
SaveHelper.AddMod(mod)
SaveHelper.DefaultGameSave(mod, {
	ModConfigSave = false
})

--get and apply the mcm save when savehelper saves and loads data
mod:AddCustomCallback(CustomCallbacks.SH_PRE_MOD_SAVE, function(_, modRef, saveData)

	local mcmSave = ModConfigMenu.GetSave()
	saveData.ModConfigSave = mcmSave
	
end, mod.Name)

mod:AddCustomCallback(CustomCallbacks.SH_POST_MOD_LOAD, function(_, modRef, saveData)

	local mcmSave = ModConfigMenu.LoadSave(saveData.ModConfigSave)
	
end, mod.Name)

--load mod config menu
exec("scripts.modconfig")

if not ModConfigMenu.StandaloneSaveLoaded then
	SaveHelper.Load(ModConfigMenu.StandaloneMod)
	ModConfigMenu.StandaloneSaveLoaded = true
end

if not ModConfigMenu.CompatibilityMode then
	exec("scripts.modconfigoldcompatibility")
end
