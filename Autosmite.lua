module("Auto Smite", package.seeall, log.setup)
clean.module("Auto Smite", clean.seeall, log.setup)

local _SDK = _G.CoreEx
local ObjManager, EventManager, Input, Renderer, Enums, Game = _SDK.ObjectManager, _SDK.EventManager, _SDK.Input, _SDK.Renderer, _SDK.Enums, _SDK.Game
local SpellSlots, SpellStates = Enums.SpellSlots, Enums.SpellStates 

local Spell, HealthPred = _G.Libs.Spell, _G.Libs.HealthPred
local Menu = _G.Libs.NewMenu
local min = math.min

---@type Targeted
local Smite
local AutoSmite = {}
AutoSmite.SmiteRange  = 500
AutoSmite.CachedDamage = 0

local JungleMonsters = {
	{Name = "SRU_Baron",        DisplayName = "Baron Nashor",   Enabled = true},
	{Name = "SRU_RiftHerald",   DisplayName = "Rift Herald",	Enabled = true},
	{Name = "SRU_Dragon_Air",   DisplayName = "Cloud Drake",	Enabled = true},
	{Name = "SRU_Dragon_Fire",  DisplayName = "Infernal Drake", Enabled = true},
	{Name = "SRU_Dragon_Earth", DisplayName = "Mountain Drake", Enabled = true},
	{Name = "SRU_Dragon_Water", DisplayName = "Ocean Drake",	Enabled = true},
	{Name = "SRU_Dragon_Elder", DisplayName = "Elder Drake",	Enabled = true},
	{Name = "SRU_Blue",         DisplayName = "Blue Buff",		Enabled = true},
	{Name = "SRU_Red",          DisplayName = "Red Buff",		Enabled = true},
	{Name = "SRU_Gromp",        DisplayName = "Gromp",			Enabled = false},
	{Name = "SRU_Murkwolf",     DisplayName = "Greater Wolf",	Enabled = false},
	{Name = "SRU_Razorbeak",    DisplayName = "Crimson Raptor", Enabled = false},
	{Name = "SRU_Krug",         DisplayName = "Ancient Krug",	Enabled = false},
	{Name = "Sru_Crab",         DisplayName = "Rift Scuttler",	Enabled = false},
}

function AutoSmite.IsEnabled() 
    return Menu.Get("Toggle") or Menu.Get("HotKey")
end
function AutoSmite.GetSmiteDamage() return AutoSmite.CachedDamage end
function AutoSmite.CanSmite(minion)
    return minion and Menu.Get(minion.CharName, true)
end
function AutoSmite.GetSmiteSlot()
    for i=SpellSlots.Summoner1, SpellSlots.Summoner2 do
        if Player:GetSpell(i).Name:lower():find("smite") then 
            return i 
        end
    end
    return SpellSlots.Unknown
end

function AutoSmite.LoadMenu()
    Menu.RegisterMenu("AutoSmite", "Auto Smite", function()
        Menu.Keybind("Toggle", "On/Off Toggle", string.byte('M'), true, true)
        Menu.Keybind("HotKey", "On/Off Hotkey", string.byte('V'))
        Menu.Checkbox("DrawStatus", "Draw Smite Status", true)
        Menu.Checkbox("DrawRange", "Draw Smite Range", true)     

        Menu.ColoredText("WhiteList", 0xFFD700FF, true)
        for k, v in pairs(JungleMonsters) do
            Menu.Checkbox(v.Name, v.DisplayName, v.Enabled)
        end 
    end) 
end

function AutoSmite.OnExtremePriority()	
    if not (AutoSmite.IsEnabled() and Smite:IsReady()) then return end
    
    local myPos = Player.Position
    local smiteDmg = AutoSmite.GetSmiteDamage() 
    
    for k, obj in pairs(ObjManager.Get("neutral", "minions")) do       
        local mob = obj.AsMinion
        if AutoSmite.CanSmite(mob) and mob:EdgeDistance(myPos) <= Smite.Range and mob.IsTargetable then
            if mob.Health <= smiteDmg and Smite:Cast(mob) then
                return
            end
        end        
    end
end

function AutoSmite.OnDraw()    
    if Menu.Get("DrawStatus") then
        local status, color
        local p = Player.Position:ToScreen()
        if AutoSmite.IsEnabled() then
            status, color = "AutoSmite: Enabled", 0x00FF00FF
            p.x = p.x - 63
        else
            status, color = "AutoSmite: Disabled", 0xFF0000FF
            p.x = p.x - 66
        end
        Renderer.DrawText(p, {x=500,y=500}, status, color)
    end
    
    if Menu.Get("DrawRange") and Smite:IsReady() then 
        Renderer.DrawCircle3D(Player.Position, Smite.Range + 75, 30, 2, 0xFFFF00FF)
    end
end

function AutoSmite.RecacheSmiteDmg()
    for k, v in pairs(Player.Buffs) do
        if v.Name:find("SmiteDamageTracker") then
            AutoSmite.CachedDamage = v.Count
        end
    end
end

function AutoSmite.OnUpdateBuff(obj, buff)
    if obj.IsMe and buff.Name:find("SmiteDamageTracker") then
        delay(1000, AutoSmite.RecacheSmiteDmg)
    end
end

function OnLoad()
    Smite = Spell.Targeted({Slot = AutoSmite.GetSmiteSlot(), Range = AutoSmite.SmiteRange})

    if Smite.Slot ~= SpellSlots.Unknown then 
        AutoSmite.LoadMenu()
        AutoSmite.RecacheSmiteDmg()

        EventManager.RegisterCallback(Enums.Events.OnExtremePriority, AutoSmite.OnExtremePriority)
        EventManager.RegisterCallback(Enums.Events.OnDraw, AutoSmite.OnDraw)
        EventManager.RegisterCallback(Enums.Events.OnBuffGain, AutoSmite.OnUpdateBuff)
    end
     
    return true
end