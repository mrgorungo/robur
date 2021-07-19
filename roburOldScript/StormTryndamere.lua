-- 🆂🆃🅾🆁🅼🅰🅸🅾 --
if Player.CharName ~= "Tryndamere" then return end
require("common.log")
module("Storm Tryndamere", package.seeall, log.setup)
clean.module("Storm Tryndamere", clean.seeall, log.setup)
local clock = os.clock
local insert, sort = table.insert, table.sort
local huge, min, max, abs = math.huge, math.min, math.max, math.abs
local _SDK = _G.CoreEx
local Console, ObjManager, EventManager, Geometry, Input, Renderer, Enums, Game = _SDK.Console, _SDK.ObjectManager, _SDK.EventManager, _SDK.Geometry, _SDK.Input, _SDK.Renderer, _SDK.Enums, _SDK.Game
local Menu, Orbwalker, Collision, Prediction, HealthPred = _G.Libs.NewMenu, _G.Libs.Orbwalker, _G.Libs.CollisionLib, _G.Libs.Prediction, _G.Libs.HealthPred
local DmgLib, ImmobileLib, Spell = _G.Libs.DamageLib, _G.Libs.ImmobileLib, _G.Libs.Spell

---@type TargetSelector
local TS = _G.Libs.TargetSelector()

-- recaller
local Tryndamere   = {}
local TryndamereNP = {}

-- spells
local Q = Spell.Active({
    Slot = Enums.SpellSlots.Q,
    Key = "Q"
})
local W = Spell.Active({
    Slot = Enums.SpellSlots.W,
    Range = 850,
    Delay = 0.3,
    Key = "W"
})
local E = Spell.Skillshot({
    Slot = Enums.SpellSlots.E,
    Range = 660,
    Delay = 0,
    Radius = 225,
    Speed = 1000,
    Type = "Linear",
    Key = "E"
})
local R = Spell.Active({
    Slot = Enums.SpellSlots.R,
    Range = 600,
    Key = "R",
})

local function GameIsAvailable()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end


function Tryndamere.OnHighPriority() 
    if not GameIsAvailable() then
        return
    end
    if Tryndamere.Auto() then return end
    local ModeToExecute = Tryndamere[Orbwalker.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end

function Tryndamere.OnNormalPriority()
    if not GameIsAvailable() then
        return
    end
    local ModeToExecute = TryndamereNP[Orbwalker.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end

-- DRAW
function Tryndamere.OnDraw()
    local Pos = Player.Position
    local spells = {W,E}
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
    for k, v in pairs(ObjManager.Get(team, type)) do
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
    for k, v in pairs(ObjManager.Get(type, "heroes")) do
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
function Tryndamere.ComboLogic(mode)
    if CanCast(W,mode) then
        for k,v in pairs(GetTargets(W)) do
            if not v:IsFacing(Player) and Player:IsFacing(v) then 
                W:Cast()
            end
        end
    end
    if CanCast(E,mode) and Menu.Get("emode") == 0 then
        Tryndamere.CastE()
    end
    if CanCast(E,mode) and Menu.Get("emode") == 1 and Player.ManaPercent * 100 >= Menu.Get("Furyc") then
        Tryndamere.CastE()
    end
end

function Tryndamere.HarassLogic(mode)
    if CanCast(W,mode) and Menu.Get("wmode") == 0 then
        for k,v in pairs(GetTargets(W)) do
            if not v:IsFacing(Player) and Player:IsFacing(v) then 
                W:Cast()
            end
        end
    end
    if CanCast(W,mode) and Menu.Get("wmode") == 1 and E:IsReady() then
        for k,v in pairs(GetTargets(W)) do
            if not v:IsFacing(Player) and Player:IsFacing(v) then 
                W:Cast()
            end
        end
    end
    if Menu.Get("wmode") == 1 and W:IsReady() then return end
    if CanCast(E,mode) and Menu.Get("emodeh") == 0 then
        Tryndamere.CastE()
    end
    if CanCast(E,mode) and Menu.Get("emodeh") == 1 and Player.ManaPercent * 100 >= Menu.Get("Furyh") then
        Tryndamere.CastE()
    end
end

function Tryndamere.CastE()
    for k,v in pairs(GetTargets(E)) do
        local pos = nil 
        if v:Distance(Player) <= 300 then
            local pre = Prediction.GetPredictedPosition(v,E,Player.Position)
            pos = pre.CastPosition:Extended(Player.Position, -50)
        end
        if v:Distance(Player) <= 400 and v:Distance(Player) >= 300 then
            local pre = Prediction.GetPredictedPosition(v,E,Player.Position)
            pos = pre.CastPosition:Extended(Player.Position, -80)
        end
        if v:Distance(Player) <= 500 and v:Distance(Player) >= 400 then
            local pre = Prediction.GetPredictedPosition(v,E,Player.Position)
            pos = pre.CastPosition:Extended(Player.Position, -120)
        end
        if v:Distance(Player) <= E.Range + 50 and v:Distance(Player) >= 500 then
            local pre = Prediction.GetPredictedPosition(v,E,Player.Position)
            pos = pre.CastPosition:Extended(Player.Position, -150)
        end
    if pos ~= nil then E:Cast(pos) end
    end
end


-- CALLBACKS
function Tryndamere.Auto()
    if R:IsReady() and Menu.Get("Auto") then
        local pre = HealthPred.GetHealthPrediction(Player,0,true)
        if ((pre / Player.MaxHealth) * 100) < Menu.Get("AutoR") and CountHeroes(Player,350,"enemy") < 1 then 
            R:Cast()
        end
    end
    if Q:IsReady() and Menu.Get("AutoQ") and not Player:GetBuff("UndyingRage") then
        if (Player.HealthPercent * 100) < Menu.Get("AutoQQ") then 
            Q:Cast()
        end
    end
end


-- RECALLERS
function Tryndamere.Combo()  Tryndamere.ComboLogic("Combo")  end
function TryndamereNP.Harass() Tryndamere.HarassLogic("Harass") end
function TryndamereNP.Waveclear()
    local Epoints = {}
    for k,v in pairs(ObjManager.Get("enemy", "minions")) do
    local minion = v.AsAI
    local minionInRange = E:IsInRange(minion)
    local pos = minion:FastPrediction(Game.GetLatency()+ E.Delay)
        if minionInRange and minion.IsTargetable and minion.MaxHealth > 6 then
            insert(Epoints, pos)
        end
    end
    if E:IsReady() and Lane(E) and Menu.Get("Logic") and CountHeroes(Player,1000,"enemy") == 0 then
    local bestPos, hitCount = E:GetBestLinearCastPos(Epoints, E.Radius)
        if bestPos and hitCount >= Menu.Get("Lane.EH") then
            E:Cast(bestPos)
        end
    end
    if E:IsReady() and Lane(E) and not Menu.Get("Logic") then
        local bestPos, hitCount = E:GetBestLinearCastPos(Epoints, E.Radius)
        if bestPos and hitCount >= Menu.Get("Lane.EH") then
            E:Cast(bestPos)
        end
    end
    if E:IsReady() and Jungle(E) then
        for k, v in pairs(ObjManager.Get("neutral", "minions")) do
        local minion = v.AsAI
        local minionInRange = E:IsInRange(minion)
            if minionInRange and minion.MaxHealth > 6  and minion.IsTargetable then
                if E:Cast(minion) then
                    return
                end
            end
        end
    end
end
function TryndamereNP.Flee() 
    if E:IsReady()  and Menu.Get("Flee.E") then
        local pos = Renderer.GetMousePos()
        E:Cast(pos)
    end
end

-- MENU
function Tryndamere.LoadMenu()
    Menu.RegisterMenu("StormTryndamere", "Storm Tryndamere", function()
        Menu.NewTree("Combo", "Combo Options", function()
            Menu.Checkbox("Combo.CastW",   "Use [W]", true)
            Menu.Checkbox("Combo.CastE",   "Use [E]", true)
            Menu.Dropdown("emode","e mode",0 ,{"Always", "Fury percent"})
            Menu.Slider("Furyc","When Fury >=",70,10,100)
        end)
        Menu.NewTree("Rs", "Q and R Options", function()
            Menu.Checkbox("AutoQ",   "Auto [Q]", true)
            Menu.Slider("AutoQQ", " Q when HP x < ", 10, 0, 100)
            Menu.Checkbox("Auto",   "Auto [R]", true)
            Menu.Slider("AutoR", " R when HP x < ", 30, 0, 100)
        end)
        Menu.NewTree("Harass", "Harass Options", function()
            Menu.Checkbox("Harass.CastW",   "Use [W]", false)
            Menu.Dropdown("wmode","W mode",0 ,{"Always", "When E Ready"})
            Menu.Checkbox("Harass.CastE",    "Use [E]", true)
            Menu.Dropdown("emodeh","e mode", 1 ,{"Always", "Fury percent"})
            Menu.Slider("Furyh","When Fury >=",60,10,100)
        end)
        Menu.NewTree("WaveClear", "WaveClear Options", function()
            Menu.NewTree("Lane", "Lane", function()
                Menu.Checkbox("Logic","Only Use E when no enemies around")
                Menu.Checkbox("Lane.E","Use [E]", false)
                Menu.Slider("Lane.EH", "E HitCount", 2,1,5)
            end)
            Menu.NewTree("Jungle", "Jungle", function()
                Menu.Checkbox("Jungle.E",   "Use [E]", true)
            end)
        end)
        Menu.NewTree("Flee", "Flee Options", function()
            Menu.Checkbox("Flee.E", "Use E to Flee", true) 
        end)
        Menu.NewTree("Draw", "Drawing Options", function()
            Menu.Checkbox("Drawing.W.Enabled",   "Draw [W] Range",true)
            Menu.ColorPicker("Drawing.W.Color", "Draw [W] Color", 0x118AB2FF)
            Menu.Checkbox("Drawing.E.Enabled",   "Draw [E] Range",false)
            Menu.ColorPicker("Drawing.E.Color", "Draw [E] Color", 0x118AB2FF)
        end)
    end)     
end


-- LOAD
function OnLoad()
    Tryndamere.LoadMenu()
    for eventName, eventId in pairs(Enums.Events) do
        if Tryndamere[eventName] then
            EventManager.RegisterCallback(eventId, Tryndamere[eventName])
        end
    end    
    return true
end