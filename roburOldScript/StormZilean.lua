--[[
    _____ _                         _______ _                  
    /  ___| |                       |___  / (_)                 
    \ `--.| |_ ___  _ __ _ __ ___      / /| |_  ___  __ _ _ __  
     `--. \ __/ _ \| '__| '_ ` _ \    / / | | |/ _ \/ _` | '_ \ 
    /\__/ / || (_) | |  | | | | | | ./ /__| | |  __/ (_| | | | |
    \____/ \__\___/|_|  |_| |_| |_| \_____/_|_|\___|\__,_|_| |_|                                                        
]]

if Player.CharName ~= "Zilean" then return end
--[[ require ]]
require("common.log")
module("Storm Zilean", package.seeall, log.setup)
clean.module("Storm Zilean", clean.seeall, log.setup)
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
---@type TargetSelector
local TS = _G.Libs.TargetSelector()

-- recaller
local Zilean = {}
local ZileanNP = {}

-- spells
local Q = Spell.Skillshot({
    Slot = Enums.SpellSlots.Q,
    Range = 900,
    Speed = 2000,
    Radius = 100,
    Type = "Circular",
    Collisions = {WindWall = true},
    Delay = 0.4,
    Key = "Q"
})
local W = Spell.Active({
    Slot = Enums.SpellSlots.W,
    Key = "W"
})
local E = Spell.Targeted({
    Slot = Enums.SpellSlots.E,
    Range = 550,
    Key = "E",
    LastE = os.clock()
})
local R = Spell.Targeted({
    Slot = Enums.SpellSlots.R,
    Range = 900,
    Key = "R",
})

local function GameIsAvailable()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

function Zilean.OnExtremePriority()
    if not GameIsAvailable() then return end
    if Zilean.ExtremeAuto() then return end
end

function Zilean.OnHighPriority() 
    if not GameIsAvailable() then
        return
    end
    if Zilean.Auto() then return end
    local ModeToExecute = Zilean[Orb.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end

function Zilean.OnNormalPriority()
    if not GameIsAvailable() then
        return
    end
    local ModeToExecute = ZileanNP[Orb.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end

-- DRAW
function Zilean.OnDraw()
    local Pos = Player.Position
    local spells = {Q,E,R}
    for k, v in pairs(spells) do
        if Menu.Get("Drawing."..v.Key..".Enabled", true) and v:IsReady() then
            Renderer.DrawCircle3D(Pos, v.Range, 30, 3, Menu.Get("Drawing."..v.Key..".Color"))
        end
    end
end


-- SPELL HELPERS
local function CanCast(spell,mode)
    return spell:IsReady() and Menu.Get(mode .. ".Cast"..spell.Key)
end

local function HitChance(spell)
    return Menu.Get("Chance."..spell.Key)
end

local function GetTargets(Spell)
    return {TS:GetTarget(Spell.Range,true)}
end

local function Count(spell,team,type)
    local num = 0
    for k, v in pairs(Obj.Get(team, type)) do
        local minion = v.AsAI
        local Tar    = spell:IsInRange(minion) and minion.MaxHealth > 6 and minion.IsTargetable
        if minion and Tar then
            num = num + 1
        end
    end
    return num
end

local function CountHeroes(pos,Range,type)
    local num = 0
    for k, v in pairs(Obj.Get(type, "heroes")) do
        local hero = v.AsHero
        if hero and hero.IsTargetable and hero:Distance(pos.Position) < Range then
            num = num + 1
        end
    end
    return num
end

local function Lane(spell)
    return Menu.Get("Lane."..spell.Key)
end

local function Jungle(spell)
    return Menu.Get("Jungle."..spell.Key)
end

-- MODES FUNCTIONS
function Zilean.ComboLogic(mode)
    if CanCast(Q,mode) then
        for k,v in pairs(GetTargets(Q)) do
            if Q:CastOnHitChance(v,HitChance(Q)) then return end
        end
    end
    if CanCast(W,mode) and not Q:IsReady() and Q:GetManaCost() + W:GetManaCost() <= Player.Mana then
        for k,v in pairs(GetTargets(Q)) do
            W:Cast()
            if Q:CastOnHitChance(v,HitChance(Q)) then return end
        end
    end
    if CanCast(E,mode) then
        for k,v in pairs(GetTargets(E)) do
            if E:Cast(v) then return end
        end
    end
end

function Zilean.HarassLogic(mode)
    if Menu.Get("ManaSlider") > Player.ManaPercent * 100 then return end
    if CanCast(Q,mode) then
        for k,v in pairs(GetTargets(Q)) do
            if Q:CastOnHitChance(v,HitChance(Q)) then return end
        end
    end
    if CanCast(W,mode) and not Q:IsReady() and Q:GetManaCost() + W:GetManaCost() <= Player.Mana then
        for k,v in pairs(GetTargets(Q)) do
            W:Cast()
            if Q:CastOnHitChance(v,HitChance(Q)) then return end
        end
    end
    if CanCast(E,mode) then
        for k,v in pairs(GetTargets(E)) do
            if E:Cast(v) then return end
        end
    end
end


-- CALLBACKS
function Zilean.ExtremeAuto()
    if R:IsReady() and Menu.Get("CastR") then
        for _, v in pairs(Obj.Get("ally","heroes")) do
            local hero = v.AsHero
            local pre = HealthPred.GetHealthPrediction(hero,0,true)
            if R:IsInRange(hero) and Menu.Get("1" .. hero.CharName) and ((pre / Player.MaxHealth) * 100) < Menu.Get("UseRh") and not hero.IsRecalling and CountHeroes(hero,600,"enemy") > 0 then
                if R:Cast(hero) then return end
            end
        end
    end
end

function Zilean.Auto()
    if Menu.Get("Misc.Auto") then
        for k,v in pairs(GetTargets(Q)) do
            if not v.CanMove and Q:CastOnHitChance(v,Enums.HitChance.Immobile) then return end
        end
    end
    if Menu.Get("E.Simi") and E:IsReady() then
        local heroes = {}
        local pos = Renderer.GetMousePos()
        for _, v in pairs(Obj.Get("ally","heroes")) do
            if not Menu.Get("E" .. v.AsHero.CharName) or v.AsHero:GetBuff("TimeWarp") then return end
            table.insert(heroes, v.AsHero)
        end
        table.sort(heroes, function(a, b) return a:Distance(pos) < b:Distance(pos) end)
        for _, hero in ipairs(heroes) do
            if E:IsReady() and E:IsInRange(hero) then 
                if E:Cast(hero) then return end
            end
        end
    end
    if Menu.Get("QWQ.Simi") then 
        local pos = (Renderer.GetMousePos() - Player.Position).Normalized()
        if Player:Distance(Renderer.GetMousePos()) < 800 and Q:IsReady() then 
            Q:Cast(Renderer.GetMousePos())
        end
        if Player:Distance(Renderer.GetMousePos()) > 800 and Q:IsReady() then
            Q:Cast(Player.Position + pos * 800)
        end
        if not Q:IsReady() and Q:GetManaCost() + W:GetManaCost() <= Player.Mana then
            if W:Cast() then return end
        end
    end
end

function Zilean.OnInterruptibleSpell(source, spell, danger, endT, canMove)
    if not (source.IsEnemy and Menu.Get("Misc.QI") and Q:IsReady() and danger > 2) then return end
    if not Menu.Get("2" .. source.AsHero.CharName) then return end
    if Q:CastOnHitChance(source,Enums.HitChance.VeryHigh) then
        return 
    end
end

function Zilean.OnGapclose(Source, DashInstance)
    if not (Source.IsEnemy) then return end
    if not Menu.Get("3" .. Source.AsHero.CharName) then return end
    if Menu.Get("Misc.E") and E:IsReady() and E:IsInRange(Source) and E:Cast(Source) then
        return 
    end
end

function Zilean.OnPreAttack(args)
    if Menu.Get("Support") and args.Target.IsMinion and CountHeroes(Player,1000,"ally") > 1 then
        args.Process = false
    end
end

function Zilean.OnBuffGain(obj,buffInst)
    if not obj.IsHero or not obj.IsAlly then return end
    if buffInst.BuffType == Enums.BuffTypes.Slow  and Menu.Get("Misc.AutoE") and E:IsReady() and E:IsInRange(obj.AsHero) then 
       E:Cast(obj.AsHero) 
    end 
    if not obj.IsHero or not obj.IsAlly or not Menu.Get("4" .. obj.AsHero.CharName) then return end
    if buffInst.BuffType == Enums.BuffTypes.Slow and not Menu.Get("Slow") then return end
    if buffInst.BuffType == Enums.BuffTypes.Disarm and not Menu.Get("Disarm") then return end
    if buffInst.BuffType == Enums.BuffTypes.Stun and not Menu.Get("Stun") then return end
    if buffInst.BuffType == Enums.BuffTypes.Silence and not Menu.Get("Silence") then return end
    if buffInst.BuffType == Enums.BuffTypes.Taunt and not Menu.Get("Taunt") then return end
    if buffInst.BuffType == Enums.BuffTypes.Polymorph and not Menu.Get("Polymorph") then return end
    if buffInst.BuffType == Enums.BuffTypes.Snare and not Menu.Get("Snare") then return end
    if buffInst.BuffType == Enums.BuffTypes.Fear and not Menu.Get("Fear") then return end
    if buffInst.BuffType == Enums.BuffTypes.Charm and not Menu.Get("Charm") then return end
    if buffInst.BuffType == Enums.BuffTypes.Blind and not Menu.Get("Blind") then return end
    if buffInst.BuffType == Enums.BuffTypes.Grounded and not Menu.Get("Grounded") then return end
    if buffInst.BuffType == Enums.BuffTypes.Asleep and not Menu.Get("Asleep") then return end
    if buffInst.BuffType == Enums.BuffTypes.Flee and not Menu.Get("Flee1") then return end
    if buffInst.BuffType == Enums.BuffTypes.Knockup then return end
    if buffInst.BuffType == Enums.BuffTypes.Knockback then return end
    if buffInst.BuffType == Enums.BuffTypes.Suppression then return end
    if buffInst.DurationLeft > Menu.Get("Du") and buffInst.IsCC then 
        for k,v in pairs(Player.Items) do 
            local itemslot = k + 6
            if v.Name == "3222Active" and obj.AsHero:Distance(Player) <= 650 then
                if Player:GetSpellState(itemslot) ==  Enums.SpellStates.Ready then 
                    Input.Cast(itemslot, obj.AsHero)
                end
            end  
        end
    end
end


-- RECALLERS
function Zilean.Combo()  Zilean.ComboLogic("Combo")  end
function ZileanNP.Harass() Zilean.HarassLogic("Harass") end
function ZileanNP.Waveclear()
    local Qpoints = {}
    for k,v in pairs(Obj.Get("enemy", "minions")) do
    local minion = v.AsAI
    local minionInRange = Q:IsInRange(minion)
    local pos = minion:FastPrediction(Game.GetLatency()+ Q.Delay)
        if minionInRange and minion.IsTargetable and minion.MaxHealth > 6 then
            table.insert(Qpoints, pos)
        end
    end
    if Q:IsReady() and Lane(Q) and Menu.Get("ManaSliderLane") < (Player.ManaPercent * 100) then
    local bestPos, hitCount = Q:GetBestCircularCastPos(Qpoints, Q.Radius)
        if bestPos and hitCount >= Menu.Get("Lane.QH") then
            Q:Cast(bestPos)
        end
    end
    if W:IsReady() and Lane(W) and not Q:IsReady() and Menu.Get("ManaSliderLane") < (Player.ManaPercent * 100) then
        for k,v in pairs(Obj.Get("enemy", "minions")) do
            local minion = v.AsAI
            local minionInRange = Q:IsInRange(minion)
            if minionInRange then W:Cast() end
        end
    end
    if Q:IsReady() and Jungle(Q) then
        for k, v in pairs(Obj.Get("neutral", "minions")) do
        local minion = v.AsAI
        local minionInRange = Q:IsInRange(minion)
            if minionInRange and minion.MaxHealth > 6  and minion.IsTargetable then
                if Q:Cast(minion) then
                    return
                end
            end
        end
    end
    if W:IsReady() and Jungle(W) and not Q:IsReady() then
        for k, v in pairs(Obj.Get("neutral", "minions")) do
        local minion = v.AsAI
        local minionInRange = Q:IsInRange(minion)
            if minionInRange and minion.MaxHealth > 6  and minion.IsTargetable then
                if W:Cast() then
                    return
                end
            end
        end
    end
end
function ZileanNP.Flee() 
    local time = os.clock()
    if E:IsReady() then E.LastE = os.clock() + 1 end
    if E:IsReady()  and Menu.Get("Flee.E") then
        E:Cast(Player)
    end
    if W:IsReady() and time > E.LastE and not E:IsReady() and not Player:GetBuff("TimeWarp") and Menu.Get("Flee.ER") then
        W:Cast()
    end
end

-- MENU
function Zilean.LoadMenu()
    Menu.RegisterMenu("StormZilean", "Storm Zilean", function()
        Menu.Checkbox("Support",   "Support Mode", true)
        Menu.NewTree("Combo", "Combo Options", function()
            Menu.Checkbox("Combo.CastQ",   "Use [Q]", true)
            Menu.Checkbox("Combo.CastW",   "Use [W] for Q Rest", true)
            Menu.Checkbox("Combo.CastE",   "Use [E]", true)
        end)
        Menu.NewTree("Rs", "R Options", function()
            Menu.Checkbox("CastR",   "Auto [R]", true)
            Menu.Slider("UseRh", " R when ally x < ", 15, 0, 100)
            Menu.NewTree("Rlist","R Whitelist", function()
                Menu.ColoredText("R Whitelist", 0xFFD700FF, true)
                for _, Object in pairs(Obj.Get("ally", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox("1" .. Name, "Use on " .. Name, true)
                end
            end)
        end)
        Menu.NewTree("Harass", "Harass Options", function()
            Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
            Menu.Slider("ManaSlider","",50,0,100)
            Menu.Checkbox("Harass.CastQ",   "Use [Q]", true)
            Menu.Checkbox("Harass.CastW",   "Use [W] for  Q Rest", true)
            Menu.Checkbox("Harass.CastE",    "Use [E]", false)
        end)
        Menu.NewTree("WaveClear", "WaveClear Options", function()
            Menu.NewTree("Lane", "Lane", function()
                Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
                Menu.Slider("ManaSliderLane","",50,0,100)
                Menu.Checkbox("Lane.Q", "Use [Q]", true)
                Menu.Slider("Lane.QH", "Q HitCount", 2,1,5)
                Menu.Checkbox("Lane.W","Use [W] for  Q Rest", false)
            end)
            Menu.NewTree("Jungle", "Jungle", function()
                Menu.Checkbox("Jungle.Q",   "Use [Q]", true)
                Menu.Checkbox("Jungle.W",   "Use [W] for  Q Rest", true)
            end)
        end)
        Menu.NewTree("Flee", "Flee Options", function()
            Menu.Checkbox("Flee.E", "Use E to Flee", true) 
            Menu.Checkbox("Flee.ER", "Use W to Rest E", false) 
        end)
        Menu.NewTree("Prediction", "Prediction Options", function()
            Menu.Slider("Chance.Q","HitChance [Q]",0.6, 0, 1, 0.05)
        end)
        Menu.NewTree("Misc", "Misc Options", function()
            Menu.Checkbox("Misc.QI",   "Use [Q] on Interrupter", true)
            Menu.NewTree("Interrupter", "Interrupter Whitelist", function()
                for _, Object in pairs(Obj.Get("enemy", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox("2" .. Name, "Use on " .. Name, true)
                end
            end)
            Menu.Checkbox("Misc.E",   "Use [E] on gapclose", true)
            Menu.NewTree("gapclose", "gapclose Whitelist", function()
                for _, Object in pairs(Obj.Get("enemy", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox("3" .. Name, "Use on " .. Name, true)
                end
            end)
            Menu.Checkbox("Misc.Auto",   "Auto Q on CC", true)
            Menu.Checkbox("Misc.AutoE",   "Auto E on Slowed Ally", true)
            Menu.Keybind("E.Simi", "Simi [E] Key (Casts on Nearest ally to Cursor)", string.byte('E'))
            Menu.NewTree("SimiEWhite","Simi E Whitelist", function()
                for _, Object in pairs(Obj.Get("ally", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox("E" .. Name, "Use on " .. Name, true)
                end
            end)
            Menu.Keybind("QWQ.Simi", "Simi [QWQ] Key (Casts on Cursor Position)", string.byte('G'))
        end)
        Menu.NewTree("Items", "Item Options", function()
            Menu.NewTree("MikaelsBlessing","Mikael's Blessing", function ()
                Menu.Slider("Du","Use when CC Duration time > ",1,0.5,3,0.05)
                    Menu.NewTree("CC","CC Whitelist", function ()
                    Menu.Checkbox("Stun","Stun",true)
                    Menu.Checkbox("Fear","Fear",true)
                    Menu.Checkbox("Snare","Snare",true)
                    Menu.Checkbox("Taunt","Taunt",true)
                    Menu.Checkbox("Slow","Slow",true)
                    Menu.Checkbox("Charm","Charm",true)
                    Menu.Checkbox("Blind","Blind",true)
                    Menu.Checkbox("Polymorph","Polymorph(Silence & Disarm)",true)
                    Menu.Checkbox("Flee1","Flee1",true)
                    Menu.Checkbox("Grounded","Grounded",true)
                    Menu.Checkbox("Asleep","Asleep",true)
                    Menu.Checkbox("Disarm","Disarm",false)
                    Menu.Checkbox("Silence","Silence",false)
                end)
                Menu.ColoredText("Mikael's Blessing Whitelist", 0xFFD700FF, true)
                for _, Object in pairs(Obj.Get("ally", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox("4" .. Name, "Use on " .. Name, true)
                end
            end)
        end)
        Menu.NewTree("Draw", "Drawing Options", function()
            Menu.Checkbox("Drawing.Q.Enabled",   "Draw [Q] Range",true)
            Menu.ColorPicker("Drawing.Q.Color", "Draw [Q] Color", 0x118AB2FF)
            Menu.Checkbox("Drawing.E.Enabled",   "Draw [E] Range",false)
            Menu.ColorPicker("Drawing.E.Color", "Draw [E] Color", 0x118AB2FF)
            Menu.Checkbox("Drawing.R.Enabled",   "Draw [R] Range",true)
            Menu.ColorPicker("Drawing.R.Color", "Draw [R] Color", 0x118AB2FF)
        end)
    end)     
end

-- LOAD
function OnLoad()
    Zilean.LoadMenu()
    for eventName, eventId in pairs(Enums.Events) do
        if Zilean[eventName] then
            Event.RegisterCallback(eventId, Zilean[eventName])
        end
    end    
    return true
end