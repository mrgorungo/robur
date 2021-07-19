-- 🆂🆃🅾🆁🅼🅰🅸🅾 --
if Player.CharName ~= "Mordekaiser" then return end
require("common.log")
module("Storm Mordekaiser", package.seeall, log.setup)
clean.module("Storm Mordekaiser", clean.seeall, log.setup)
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
local Mordekaiser = {}
local MordekaiserHP = {}


-- spells
local Q = Spell.Skillshot({
    Slot = Enums.SpellSlots.Q,
    Range = 625,
    Delay = 0.5,
    Radius = 80,
    Speed = huge,
    Key = "Q",
    Type = "Linear",
})
local W = Spell.Active({
    Slot = Enums.SpellSlots.W,
    Key = "W"
})
local E = Spell.Skillshot({
    Slot = Enums.SpellSlots.E,
    Range =  700,
    Radius = 100,
    Speed = 3000,
    Delay = 0.25,
    Key = "E",
    Type = "Linear",
})
local R = Spell.Targeted({
    Slot = Enums.SpellSlots.R,
    Delay = 0,
    Range = 650,
    Key = "R",
})

local function GameIsAvailable()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

function Mordekaiser.OnHighPriority() 
    if not GameIsAvailable() then
        return
    end
    if Mordekaiser.Auto() then return end
    local ModeToExecute = MordekaiserHP[Orbwalker.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end

function Mordekaiser.OnNormalPriority()
    if not GameIsAvailable() then
        return
    end
    local ModeToExecute = Mordekaiser[Orbwalker.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end


-- DRAW
function Mordekaiser.OnDraw()
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
    for k, v in pairs(ObjManager.Get(team, type)) do
        local minion = v.AsAI
        local Tar    = spell:IsInRange(minion) and minion.MaxHealth > 6 and minion.IsTargetable
        if minion and Tar then
            num = num + 1
        end
    end
    return num
end

local function Lane(spell)
    return Menu.Get("Lane."..spell.Key) and spell:IsReady()
end

local function Jungle(spell)
    return Menu.Get("Jungle."..spell.Key) and spell:IsReady()
end


-- MODES FUNCTIONS
function MordekaiserHP.ComboLogic(mode)
    if CanCast(Q,mode) then 
        for k,v in pairs(GetTargets(Q)) do 
            if Q:CastOnHitChance(v,HitChance(Q)) then return end
        end
    end
    if CanCast(E,mode) then 
        for k,v in pairs(GetTargets(E)) do 
            local pre = Prediction.GetPredictedPosition(v,E,Player.Position)
            if pre and pre.HitChance >= HitChance(E) then 
                local castpos = Player.Position:Extended(pre.CastPosition, E.Range)
                if E:Cast(castpos) then return end
            end
        end
    end
    if CanCast(R,mode) then 
        for k,v in pairs(GetTargets(R)) do 
            if (v.HealthPercent * 100) <= Menu.Get("RHP") and R:Cast(v) then return end
        end
    end
end

function Mordekaiser.HarassLogic(mode)
    if CanCast(Q,mode) then 
        for k,v in pairs(GetTargets(Q)) do 
            if Q:CastOnHitChance(v,HitChance(Q)) then return end
        end
    end
    if CanCast(E,mode) then 
        for k,v in pairs(GetTargets(E)) do 
            local pre = Prediction.GetPredictedPosition(v,E,Player.Position)
            if pre and pre.HitChance >= HitChance(E) then 
                local castpos = Player.Position:Extended(pre.CastPosition, E.Range)
                if E:Cast(castpos) then return end
            end
        end
    end
end

function Mordekaiser.WaveClearLogic()
    if Jungle(Q) then 
        for k,v in pairs(ObjManager.Get("neutral","minions")) do
            local minion = v.AsAI
            local minionIsInRange = minion.MaxHealth > 6 and minion.IsTargetable and Q:IsInRange(minion)
            if minionIsInRange then 
                if Q:CastOnHitChance(minion,Enums.HitChance.Low) then return end
            end
        end
    end
    if Jungle(E) then 
        for k,v in pairs(ObjManager.Get("neutral","minions")) do
            local minion = v.AsAI
            local minionIsInRange = minion.MaxHealth > 6 and minion.IsTargetable and E:IsInRange(minion)
            if minionIsInRange then 
                local castpos = Player.Position:Extended(minion.Position, 500)
                if E:Cast(castpos) then return end
            end
        end
    end
    if Lane(Q) then 
        local pointsQ = {}
        for k,v in pairs(ObjManager.Get("enemy","minions")) do
            local minion = v.AsAI
            local minionIsInRange = minion.MaxHealth > 6 and minion.IsTargetable and Q:IsInRange(minion)
            if minionIsInRange then 
                local pos = minion:FastPrediction(Game.GetLatency()+ Q.Delay)
                if pos:Distance(Player.Position) < Q.Range then
                    insert(pointsQ, pos)
                end 
            end
        end
        local bestPos, hitCount  = Q:GetBestLinearCastPos(pointsQ, Q.Radius * 2)
        if bestPos and hitCount >= Menu.Get("Lane.QH") then
            Q:Cast(bestPos)
        end
    end
    if Lane(E) then 
        local pointsE = {}
        for k,v in pairs(ObjManager.Get("enemy","minions")) do
            local minion = v.AsAI
            local minionIsInRange = minion.MaxHealth > 6 and minion.IsTargetable and E:IsInRange(minion)
            if minionIsInRange then 
                local pos = minion:FastPrediction(Game.GetLatency()+ E.Delay)
                if pos:Distance(Player.Position) < E.Range then
                    insert(pointsE, pos)
                end 
            end
        end
        local bestPos, hitCount  = E:GetBestLinearCastPos(pointsE, E.Radius)
        if bestPos and hitCount >= Menu.Get("Lane.EH") then
            local pos = Player.Position:Extended(bestPos, E.Range)
            E:Cast(pos)
        end
    end
end

-- CALLBACKS
function Mordekaiser.Auto()
    if Menu.Get("Misc.R") and R:IsReady() and Menu.Get("RSimi") then 
        local Pos = Renderer.GetMousePos()
        local hero = {}
        for k,v in pairs(ObjManager.Get("enemy","heroes")) do 
            insert(hero,v.AsHero)
        end
        table.sort(hero, function(a, b) return a:Distance(Pos) < b:Distance(Pos) end)
        for k,v in pairs(hero) do 
            if R:IsInRange(v) and R:Cast(v) then return end
        end
    end
end

function Mordekaiser.OnGapClose(Source, DashInstance)
    if not (Source.IsEnemy or Menu.Get("Misc.E") or Menu.Get(Source.AsHero.CharName)) then return end
    local pre = Prediction.GetPredictedPosition(Source,E,Player.Position)
    if pre and pre.HitChance >= Enums.HitChance.VeryHigh then 
        local castpos = pre.CastPosition:Extended(Player.Position, 400)
        if E:Cast(castpos) then return end
    end
end

function Mordekaiser.OnProcessSpell(sender,spell) 
    if W:IsReady() and Menu.Get("Misc.W") and sender.IsEnemy and sender.IsHero and spell.IsSpecialAttack then 
        local target = spell.Target
        if target.IsMe then W:Cast() return end
    end
end


-- RECALLERS
function MordekaiserHP.Combo()  MordekaiserHP.ComboLogic("Combo")  end
function Mordekaiser.Harass() Mordekaiser.HarassLogic("Harass") end
function Mordekaiser.Waveclear() Mordekaiser.WaveClearLogic() end


-- MENU
function Mordekaiser.LoadMenu()
    Menu.RegisterMenu("StormMordekaiser", "Storm Mordekaiser", function()
        Menu.NewTree("Combo", "Combo Options", function()
            Menu.Checkbox("Combo.CastQ",   "Use [Q]", true)
            Menu.Checkbox("Combo.CastE",   "Use [E]", true)
            Menu.Checkbox("Combo.CastR",   "Use [R]", true)
            Menu.Slider("RHP","use R when target Hp <=",30,0,100)
        end)
        Menu.NewTree("Harass", "Harass Options", function()
            Menu.Checkbox("Harass.CastQ",   "Use [Q]", true)
            Menu.Checkbox("Harass.CastE",    "Use [E]", false)
        end)
        Menu.NewTree("WaveClear", "WaveClear Options", function()
            Menu.NewTree("Lane", "Lane", function()
                Menu.Checkbox("Lane.Q","Use [Q]", true)
                Menu.Slider("Lane.QH", "Q HitCount", 2,1,5)
                Menu.Checkbox("Lane.E","Use [E]", false)
                Menu.Slider("Lane.EH", "E HitCount", 2,1,5)
            end)
            Menu.NewTree("Jungle", "Jungle", function()
                Menu.Checkbox("Jungle.Q",   "Use [Q]", true)
                Menu.Checkbox("Jungle.E",   "Use [E]", true)
            end)
        end)
        Menu.NewTree("Misc", "Misc Options", function()
            Menu.Checkbox("Misc.W",   "Auto W on Special Attacks ", true)
            Menu.Checkbox("Misc.E",   "Use [E] on gapclose", true)
            Menu.NewTree("gapclose", "gapclose Whitelist", function()
                for _, Object in pairs(ObjManager.Get("enemy", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox(Name, "Use on " .. Name, true)
                end
            end)
            Menu.Checkbox("Misc.R",   "Use [R] Simi Key", true)
            Menu.Keybind("RSimi","R Simi Key", string.byte('R'))
        end)
        Menu.NewTree("Prediction", "Prediction Options", function()
            Menu.Slider("Chance.Q","Q HitChance", 0.6, 0, 1, 0.05)
            Menu.Slider("Chance.E","E HitChance", 0.7, 0, 1, 0.05)
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
    Mordekaiser.LoadMenu()
    for eventName, eventId in pairs(Enums.Events) do
        if Mordekaiser[eventName] then
            EventManager.RegisterCallback(eventId, Mordekaiser[eventName])
        end
    end    
    return true
end