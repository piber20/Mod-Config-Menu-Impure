require("scripts.customcallbacks")
require("scripts.savehelper")

--create the mod
local mod = RegisterMod("Mod Config Menu (Standalone)", 1)
CustomCallbackHelper.ExtendMod(mod)

MCM = MCM or {}
MCM.StandaloneMod = mod

--add MCM's save to savehelper
SaveHelper.AddMod(mod)
SaveHelper.DefaultGameSave(mod, {
	ModConfigSave = false
})

--get and apply the mcm save when savehelper saves and loads data
mod:AddCustomCallback(CustomCallbacks.SH_PRE_MOD_SAVE, function(_, modRef, saveData)

	local mcmSave = MCM.GetSave()
	saveData.ModConfigSave = mcmSave
	
end, mod.Name)

mod:AddCustomCallback(CustomCallbacks.SH_POST_MOD_LOAD, function(_, modRef, saveData)

	local mcmSave = MCM.LoadSave(saveData.ModConfigSave)
	
end, mod.Name)

--load mod config menu
require("scripts.modconfig")

if not MCM.StandaloneSaveLoaded then
	SaveHelper.Load(MCM.StandaloneMod)
	MCM.StandaloneSaveLoaded = true
end
