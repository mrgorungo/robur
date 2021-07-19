--[[
 __ _                           ___                     
/ _\ |_ ___  _ __ _ __ ___     / _ \__ _ _ __ ___ _ __  
\ \| __/ _ \| '__| '_ ` _ \   / /_\/ _` | '__/ _ \ '_ \ 
_\ \ || (_) | |  | | | | | | / /_\\ (_| | | |  __/ | | |
\__/\__\___/|_|  |_| |_| |_| \____/\__,_|_|  \___|_| |_|
                                                                                                                                                           
]]
if Player.CharName ~= "Garen" then return end
--[[ require ]]
require("common.log")
module("Storm Garen", package.seeall, log.setup)
clean.module("Storm Garen", clean.seeall, log.setup)
--[[ SDK ]]
local SDK         = _G.CoreEx
local Obj         = SDK.ObjectManager
local Event       = SDK.EventManager
local Game        = SDK.Game
local Enums       = SDK.Enums
local Geo         = SDK.Geometry
local Renderer    = SDK.Renderer
local Input       = SDK.Input
--[[Libraries]] 
local TS          = _G.Libs.TargetSelector()
local Menu        = _G.Libs.NewMenu
local Orb         = _G.Libs.Orbwalker
local Collision   = _G.Libs.CollisionLib
local Pred        = _G.Libs.Prediction
local HealthPred  = _G.Libs.HealthPred
local DmgLib      = _G.Libs.DamageLib
local ImmobileLib = _G.Libs.ImmobileLib
local Spell       = _G.Libs.Spell
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
local Garen = {}
local GarenHP = {}
local GarenNP = {}
--[[Spells]] 
local Q = Spell.Active({
    Slot = Enums.SpellSlots.Q,
    Key = "Q",
})
local W = Spell.Active({
    Slot = Enums.SpellSlots.W,
    Delay = 0,
    Key = "W",
})
local E = Spell.Active({
    Slot = Enums.SpellSlots.E,
    Range =  325,
    Delay = 0,
    Key = "E",
    Type = "Circular"
})
local R = Spell.Targeted({
    Slot = Enums.SpellSlots.R,
    Delay = 0.435,
    Range = 400,
    Key = "R",

})
--[[Startup]] 
local function GameIsAvailable()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

function Garen.OnHighPriority() 
    if not GameIsAvailable() then
        return
    end
    if Garen.Auto() then return end
    local ModeToExecute = GarenHP[Orb.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end

function Garen.OnNormalPriority()
    if not GameIsAvailable() then
        return
    end
    local ModeToExecute = GarenNP[Orb.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end

--[[Draw]] 
function Garen.OnDraw()
    local Pos = Player.Position
    local spells = {E,R}
    for k, v in pairs(spells) do
        if Menu.Get("Drawing."..v.Key..".Enabled", true) and v:IsReady() then
            Renderer.DrawCircle3D(Pos, v.Range, 30, 3, Menu.Get("Drawing."..v.Key..".Color"))
        end
    end
end

--[[Helper Functions]]
local function EActive()
    return Player:GetBuff("GarenE")
end

local function QActive()
    return Player:GetBuff("GarenQ")
end


local function CanCast(spell,mode)
    return spell:IsReady() and Menu.Get(mode .. ".Cast"..spell.Key)
end

local function HitChance(spell)
    return Menu.Get("Chance."..spell.Key)
end

local function Lane(spell)
    return spell:IsReady() and Menu.Get("Lane."..spell.Key)
end

local function LastHit(spell)
    return Menu.Get("LastHit."..spell.Key) and spell:IsReady()
end

local function Structure(spell)
    return Menu.Get("Structure."..spell.Key) and spell:IsReady()
end

local function Jungle(spell)
    return spell:IsReady() and Menu.Get("Jungle."..spell.Key)
end

local function Flee(spell)
    return Menu.Get("Flee."..spell.Key) and spell:IsReady()
end

local function KS(spell)
    return Menu.Get("KS."..spell.Key) and spell:IsReady()
end

local function GetTargetsRange(Range)
    return {TS:GetTarget(Range,true)}
end

local function GetTargets(Spell)
    return {TS:GetTarget(Spell.Range,true)}
end

local function CountHeroes(pos,Range,type)
    local num = 0
    for k, v in pairs(Obj.Get(type, "heroes")) do
        local hero = v.AsHero
        if hero and hero.IsTargetable and not hero.IsMe and hero:Distance(pos.Position) < Range then
            num = num + 1
        end
    end
    return num
end

local function Count(spell,team,type)
    local num = 0
    for k, v in pairs(Obj.Get(team, type)) do
        local minion = v.AsAI
        local Tar    = spell:IsInRange(minion) and minion.MaxHealth > 6 and minion.IsTargetable and not Orb.IsLasthitMinion(minion)
        if minion and Tar then
            num = num + 1
        end
    end
    return num
end

local function ValidAI(minion,Range)
    local AI = minion.AsAI
    return AI.IsTargetable and AI.MaxHealth > 6 and AI:Distance(Player) < Range
end

local function SortMinion(list)
    table.sort(list, function(a, b) return a.MaxHealth > b.MaxHealth end)
    return list
end

local function IsUnderTurrent(pos)
    local sortme = {}
    for k, v in pairs(Obj.Get("enemy", "turrets")) do
        if not v.IsDead and v.IsTurret then 
            table.insert(sortme,v)
        end
    end
    table.sort(sortme,function(a, b) return b:Distance(Player) > a:Distance(Player) end)
    for  k,v  in ipairs(sortme) do 
        return v:Distance(pos) <= 870
    end
end

local function dmg(spell,t)
    local dmg = 0
    local RMulitper = {200,250,300}
    if spell.Key == "Q" then 
        dmg = (30 + (Q:GetLevel() - 1) * 30) + (0.5 * Player.TotalAD)
    end
    if spell.Key == "R" then
        dmg = (150 + (R:GetLevel() - 1) * 150) + ((t.MaxHealth - t.Health) * RMulitper[R:GetLevel()] / t.MaxHealth)
    end
    return dmg 
end

--[[Events]]
function Garen.Auto()
    if KS(R) then 
        for k,v in pairs(GetTargets(R)) do 
            local RKs  = R:GetKillstealHealth(v)
            local Rdmg = dmg(R,v)
            if Rdmg > RKs then 
                if R:Cast(v) then return end
            end
        end
    end
end

function Garen.OnPostAttack(targets)
    local Target = targets.AsAI
    local mode = Orb.GetMode()
    if not Target or not Q:IsReady() then return end
    if Target.IsHero and mode == "Combo" then 
        if CanCast(Q,mode) then 
            if Q:Cast() then return end
        end
    end
    if Target.IsHero and mode == "Harass" then 
        if CanCast(Q,mode) then 
            if Q:Cast() then return end
        end
    end
    if Target.IsStructure and Structure(Q) then 
        if Q:Cast() then return end
    end
end

function Garen.OnBuffGain(obj,buffInst)
    if not obj.IsMe then return end
    if buffInst.BuffType == Enums.BuffTypes.Slow  and Menu.Get("Misc.Q") and Q:IsReady() then 
        if Q:Cast() then return end
    end 
end

function Garen.OnProcessSpell(sender,spell)
    if W:IsReady() then 
        if sender.IsTurret and spell.Target and spell.Target.IsMe and Menu.Get("Misc.W") then 
            if W:Cast() then return end
        end
    end
    if W:IsReady() then 
        if not (sender.IsHero and sender.IsEnemy) then return end
        if Menu.Get("Misc.WAA") and spell.Target and spell.Target.IsMe then 
            if W:Cast() then return end
        end
    end
end

--[[Orbwalker Recallers]]
function GarenHP.Combo()
    local mode = "Combo"
    if CanCast(R,mode) then 
        for k,v in pairs(GetTargets(R)) do 
            local RKs  = R:GetKillstealHealth(v)
            local Rdmg = dmg(R,v)
            if Rdmg > RKs then 
                if R:Cast(v) then return end
            end
        end
    end
end

function  GarenNP.Combo()
    local mode = "Combo"
    if CanCast(E,mode) and not QActive() and not EActive() then
        for k,v in pairs(GetTargets(E)) do 
            if Menu.Get("Misc.E") and not v:IsFacing(Player) then return end
            if E:Cast() then return end
        end
    end
    if CanCast(Q,mode) and not EActive() then 
        for k,v in pairs(GetTargetsRange(Menu.Get("ActiveRange"))) do 
            if Menu.Get("Misc.QL") and (v:IsFacing(Player) and Player:IsFacing(v)) or v:Distance(Player) < Player.AttackRange then return end
            if Q:Cast() then return end
        end
    end
end

function GarenNP.Harass()
    local mode = "Harass"
    if CanCast(E,mode) and not QActive() and not EActive() then
        for k,v in pairs(GetTargets(E)) do 
            if Menu.Get("Misc.E") and not v:IsFacing(Player) then return end
            if E:Cast() then return end
        end
    end
    if CanCast(Q,mode) and not EActive() then 
        for k,v in pairs(GetTargetsRange(Menu.Get("hActiveRange"))) do 
            if Menu.Get("Misc.QL") and (v:IsFacing(Player) and Player:IsFacing(v)) or v:Distance(Player) < Player.AttackRange then return end
            if Q:Cast() then return end
        end
    end
end

function GarenNP.Waveclear()
    if Lane(Q) and not EActive() then 
        for k, v in pairs(Obj.Get("enemy", "minions")) do 
            local minion = v.AsAI
            local trueRange = Player.AttackRange
            local minionInRange = Player:Distance(minion) < trueRange and minion.MaxHealth > 6 and minion.IsTargetable
            if minionInRange then
                local healthPred = Q:GetHealthPred(minion)
                local QDmg = DmgLib.CalculatePhysicalDamage(Player, minion, dmg(Q))
                if healthPred > 0 and healthPred < QDmg then 
                    Orb.StopIgnoringMinion(minion)
                    if Q:Cast() then return end 
                end    
            end                  
        end
    end
    if Lane(E) and not EActive() and not QActive() then 
        if Count(E,"enemy","minions") >= Menu.Get("Lane.EH") then
            if E:Cast() then return end
        end
    end
    if Jungle(Q) and not EActive() then 
        for k, v in pairs(Obj.Get("neutral", "minions")) do 
            local minion = v.AsAI
            local trueRange = Player.AttackRange + 50
            local minionInRange = Player:Distance(minion) < trueRange and minion.MaxHealth > 6 and minion.IsTargetable
            if minionInRange then
                if Q:Cast() then return end 
            end                  
        end
    end
    if Jungle(E) and not EActive() and not QActive() then 
        if Count(E,"neutral","minions") >= 1 then
            if E:Cast() then return end
        end
    end
end

function GarenNP.Lasthit()
    if LastHit(Q) and not EActive() then 
        for k, v in pairs(Obj.Get("enemy", "minions")) do 
            local minion = v.AsAI
            local trueRange = Player.AttackRange
            local minionInRange = Player:Distance(minion) < trueRange and minion.MaxHealth > 6 and minion.IsTargetable
            if minionInRange then
                local healthPred = Q:GetHealthPred(minion)
                local QDmg = DmgLib.CalculatePhysicalDamage(Player, minion, dmg(Q))
                if healthPred > 0 and healthPred < QDmg then 
                    Orb.StopIgnoringMinion(minion)
                    if Q:Cast() then return end 
                end    
            end                  
        end
    end
end

function GarenNP.Flee()
    if Flee(Q) then 
        if Q:Cast() then return end
    end
end

--[[Menu]]
function Garen.LoadMenu()
    Menu.RegisterMenu("StormGaren", "Storm Garen", function()
        Menu.NewTree("Combo", "Combo Options", function()
            Menu.Checkbox("Combo.CastQ",   "Use [Q]", true)
            Menu.Slider("ActiveRange","Q Active Range",800,100,1000)
            Menu.Checkbox("Combo.CastE",   "Use [E]", true)
            Menu.Checkbox("Combo.CastR",   "Use [R]", true)
        end)
        Menu.NewTree("Harass", "Harass Options", function()
            Menu.Checkbox("Harass.CastQ",   "Use [Q]", false)
            Menu.Slider("hActiveRange","Q Active Range",300,100,1000)
            Menu.Checkbox("Harass.CastE",   "Use [E]", false)
        end)
        Menu.NewTree("Waveclear", "Waveclear Options", function()
            Menu.NewTree("Lane", "Lane Options", function() 
                Menu.Checkbox("Lane.Q",   "Use [Q]", true)
                Menu.Checkbox("Lane.W",   "Use [W]", true)
                Menu.Checkbox("Lane.E",   "Use [E]", true)
                Menu.Slider("Lane.EH","E HitCount",3,1,5)
            end)
            Menu.NewTree("Lasthit", "Lasthit Options", function() 
                Menu.Checkbox("LastHit.Q",   "Use [Q] ", true)
            end)
            Menu.NewTree("Structure", "Structure Options", function() 
                Menu.Checkbox("Structure.Q",   "Use [Q]", true)
            end)
            Menu.NewTree("Jungle", "Jungle Options", function() 
                Menu.Checkbox("Jungle.Q",   "Use [Q]", true)
                Menu.Checkbox("Jungle.E",   "Use [E]", true)
            end)
        end)
        Menu.NewTree("KillSteal", "KillSteal Options", function()
            Menu.Checkbox("KS.R"," Use R", true)
        end)
        Menu.NewTree("Flee", "Flee Options", function()
            Menu.Checkbox("Flee.Q"," Use Q ", true)
        end)
        Menu.NewTree("Misc", "Misc Options", function()
            Menu.Checkbox("Misc.W",   "Auto W on Tower Shots", true)
            Menu.Checkbox("Misc.WAA",   "Auto W on Attacks", true)
            Menu.Checkbox("Misc.Q",   "Auto Q on Slow Debuff", true)
            Menu.Checkbox("Misc.QL",   "Turn on Casting Q with Logic", false)
            Menu.Checkbox("Misc.E",   "Check if Facing Before Cast E", false)
        end)
        Menu.NewTree("Draw", "Drawing Options", function()
            Menu.Checkbox("Drawing.E.Enabled",   "Draw [E] Range",false)
            Menu.ColorPicker("Drawing.E.Color", "Draw [E] Color", 0x118AB2FF)
            Menu.Checkbox("Drawing.R.Enabled",   "Draw [R] Range",false)
            Menu.ColorPicker("Drawing.R.Color", "Draw [R] Color", 0x118AB2FF)
        end)
    end)     
end

-- LOAD
function OnLoad()
    Garen.LoadMenu()
    for eventName, eventId in pairs(Enums.Events) do
        if Garen[eventName] then
            Event.RegisterCallback(eventId, Garen[eventName])
        end
    end    
    return true
end