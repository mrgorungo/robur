-- 🆂🆃🅾🆁🅼🅰🅸🅾 --
if Player.CharName ~= "Amumu" then return end
require("common.log")
module("Storm Amumu", package.seeall, log.setup)
clean.module("Storm Amumu", clean.seeall, log.setup)
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
local Amumu = {}
local AmumuHP = {}

-- spells
local Q = Spell.Skillshot({
        Slot = Enums.SpellSlots.Q,
        Range = 1050,
        Radius = 80,
        Delay = 0.25,
        Speed = 2000,
        Collisions = {WindWall = true,Minions=true },
        Type = "Linear",
        UseHitbox = true,
        Key = "Q"
})
local W = Spell.Active({
        Slot = Enums.SpellSlots.W,
        Range = 300,
        Key = "W"
})
local E = Spell.Active({
        Slot = Enums.SpellSlots.E,
        Range = 350,
        Key = "E"
})
local R = Spell.Active({
        Slot = Enums.SpellSlots.R,
        Range = 550,
        Delay = 0.25,
        Key = "R"
})

local function GameIsAvailable()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end


function Amumu.OnHighPriority() 
    if not GameIsAvailable() then
        return
    end
    if Amumu.Auto() then return end
    local ModeToExecute = AmumuHP[Orbwalker.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end

function Amumu.OnNormalPriority()
    if not GameIsAvailable() then
        return
    end
    local ModeToExecute = Amumu[Orbwalker.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end


-- draw
function Amumu.OnDraw() 
    local Pos = Player.Position
    local spells = {Q,W,E,R}
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

local function GetTargets(spell)
    return {TS:GetTarget(spell.Range,true)}
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

local function CountHeroes(Range,type)
    local num = 0
    for k, v in pairs(ObjManager.Get(type, "heroes")) do
        local hero = v.AsHero
        if hero and hero.IsTargetable and hero:Distance(Player.Position) < Range then
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
function Amumu.ComboLogic(mode)
    if CanCast(W,mode) then
        for k, wTarget in pairs(GetTargets(W)) do
            if not Player:GetBuff("AuraOfDespair") then
                W:Cast()
                return
            end
        end
    end
    if W:IsReady() and Player:GetBuff("AuraOfDespair") then 
        if CountHeroes(W.Range,"enemy") < 1 then
            W:Cast() return
        end
    end
    if CanCast(E,mode) then
        for k, eTarget in pairs(GetTargets(E)) do
            if E:Cast() then
                return
            end
        end
    end
end


-- Callbacks
---@param source AIBaseClient
---@param spell SpellCast
function Amumu.OnInterruptibleSpell(source, spell, danger, endT, canMove)
    if not (source.IsEnemy and Menu.Get("Misc.IntQ") and Q:IsReady() and danger > 2) then return end

    Q:CastOnHitChance(source, Enums.HitChance.VeryHigh)
end

function Amumu.Auto()
   
end


-- mode Recallers
function Amumu.Combo()  Amumu.ComboLogic("Combo")  end
function AmumuHP.Combo()
    local mode = "Combo"
    if CanCast(Q,mode) then
        for k, qTarget in pairs(GetTargets(Q)) do
            if not Menu.Get(qTarget.CharName) then return end
            if qTarget:Distance(Player) < Menu.Get("Max.Q") and qTarget:Distance(Player) >  Menu.Get("Min.Q") then
                if Q:CastOnHitChance(qTarget, HitChance(Q)) then
                return
                end
            end
        end
    end
    if CanCast(R,mode) then 
        if R:IsReady() and #TS:GetTargets(R.Range, true) >= Menu.Get("Combo.R") then
            if R:Cast() then return end     
        end
    end
end
function Amumu.Waveclear()
    if Jungle(Q) and Q:IsReady() then 
          for k, v in pairs(ObjManager.Get("neutral", "minions")) do
            local minion = v.AsAI
            if minion then
                if minion.IsTargetable and minion.MaxHealth > 6 and Q:IsInRange(minion) then
                    if Q:Cast(minion) then 
                        return
                    end
                end 
            end                       
        end
    end
    if Jungle(W) and W:IsReady() then 
        for k, v in pairs(ObjManager.Get("neutral", "minions")) do
          local minion = v.AsAI
            if minion then
                if minion.IsTargetable and minion.MaxHealth > 6 and W:IsInRange(minion) then
                    if not Player:GetBuff("AuraOfDespair") then
                        W:Cast() return
                    end
                end
            end    
        end
    end
    if Jungle(W) and W:IsReady() and Player:GetBuff("AuraOfDespair") then 
        if Count(W,"neutral","minions") < 1 then
            W:Cast() return
        end
    end
    if Jungle(E) and E:IsReady() then 
        for k, v in pairs(ObjManager.Get("neutral", "minions")) do
          local minion = v.AsAI
            if minion then
                if minion.IsTargetable and minion.MaxHealth > 6 and E:IsInRange(minion) then
                    E:Cast()  
                end 
            end                       
        end
    end
end


-- Menu
function Amumu.LoadMenu()
    Menu.RegisterMenu("StormAmumu", "Storm Amumu", function()
        Menu.NewTree("Combo", "Combo Options", function()
            Menu.Checkbox("Combo.CastQ",   "Use [Q]", true)
            Menu.NewTree("QList", "Q Whitelist", function()
                for _, Object in pairs(ObjManager.Get("enemy", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox(Name, "Use [Q] on " .. Name, true)
                end 
            end)
            Menu.Checkbox("Combo.CastW",   "Use [W]", true)
            Menu.Checkbox("Combo.CastE",   "Use [E]", true)
            Menu.Checkbox("Combo.CastR",   "Use [R]", true)
            Menu.Slider("Combo.R", "R Hitcount", 2, 1, 5, 1) 
        end)
        Menu.NewTree("Wave", "Farming Options", function()
            Menu.NewTree("Jungle", "Jungleclear Options", function()
                Menu.Checkbox("Jungle.Q",   "Use Q", true)
                Menu.Checkbox("Jungle.W",   "Use W", true)
                Menu.Checkbox("Jungle.E",   "Use W", true)
            end)
        end)
        Menu.NewTree("Range", "Spell Range Options", function()
            Menu.Slider("Max.Q","[Q] Max Range", 1050, 0, 1050)
            Menu.Slider("Min.Q","[Q] Min Range", 150, 0, 700)
        end)
        Menu.NewTree("Prediction", "Prediction Options", function()
            Menu.Slider("Chance.Q","HitChance [Q]",0.7, 0, 1, 0.05)
        end)
        Menu.NewTree("Misc", "Misc Options", function()
                Menu.Checkbox("Misc.IntQ",   "Use [Q] Interrupt", true)
        end)
        Menu.NewTree("Draw", "Drawing Options", function()
            Menu.Checkbox("Drawing.Q.Enabled",   "Draw [Q] Range",true)
            Menu.ColorPicker("Drawing.Q.Color", "Draw [Q] Color", 0xf03030ff)
            Menu.Checkbox("Drawing.W.Enabled",   "Draw [W] Range",true)
            Menu.ColorPicker("Drawing.W.Color", "Draw [W] Color", 0x30e6f0ff)
            Menu.Checkbox("Drawing.E.Enabled",   "Draw [E] Range",false)
            Menu.ColorPicker("Drawing.E.Color", "Draw [E] Color", 0x3060f0ff)
            Menu.Checkbox("Drawing.R.Enabled",   "Draw [R] Range",true)
            Menu.ColorPicker("Drawing.R.Color", "Draw [R] Color", 0xf03086ff)
        end)
    end)     
end

function OnLoad()
    Amumu.LoadMenu()
    for eventName, eventId in pairs(Enums.Events) do
        if Amumu[eventName] then
            EventManager.RegisterCallback(eventId, Amumu[eventName])
        end
    end    
    return true
end
