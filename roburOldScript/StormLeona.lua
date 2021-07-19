-- 🆂🆃🅾🆁🅼🅰🅸🅾 --
if Player.CharName ~= "Leona" then return end
require("common.log")
module("Storm Leona", package.seeall, log.setup)
clean.module("Storm Leona", clean.seeall, log.setup)
local clock = os.clock
local insert, sort = table.insert, table.sort
local huge, min, max, abs = math.huge, math.min, math.max, math.abs

local _SDK = _G.CoreEx
local Console, ObjManager, EventManager, Geometry, Input, Renderer, Enums, Game = _SDK.Console, _SDK.ObjectManager, _SDK.EventManager, _SDK.Geometry, _SDK.Input, _SDK.Renderer, _SDK.Enums, _SDK.Game
local Menu, Orbwalker, Collision, Prediction, HealthPred = _G.Libs.NewMenu, _G.Libs.Orbwalker, _G.Libs.CollisionLib, _G.Libs.Prediction, _G.Libs.HealthPred
local DmgLib, ImmobileLib, Spell = _G.Libs.DamageLib, _G.Libs.ImmobileLib, _G.Libs.Spell

---@type TargetSelector
local TS = _G.Libs.TargetSelector()

-- RECALLER
local Leona   = {}


-- SPELLS
local Q = Spell.Active({
    Slot = Enums.SpellSlots.Q,
    Range = Player.AttackRange,
    Key = "Q"
})
local W = Spell.Active({
    Slot = Enums.SpellSlots.W,
    Range = 270,
    Key = "W"
})
local E = Spell.Skillshot({
    Slot = Enums.SpellSlots.E,
    Range = 875,
    Delay = 0.25,
    Radius = 70,
    Speed = 2000,
    Collisions = { Heroes = true,WindWall=true},
    Type = "Linear",
    UseHitbox = true,
    Key = "E"
})
local R = Spell.Skillshot({
    Slot = Enums.SpellSlots.R,
    Delay = 0.5,
    Range = 1200,
    Radius = 100,
    Type = "Circular",
    Key = "R",
})

local function GameIsAvailable()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

function Leona.OnHighPriority() 
    if not GameIsAvailable() then
        return
    end
    if Leona.Auto() then return end
end

function Leona.OnNormalPriority()
    if not GameIsAvailable() then
        return
    end
    local ModeToExecute = Leona[Orbwalker.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end


-- DRAW
function Leona.OnDraw()
    local Pos = Player.Position
    local spells = {W,E,R}
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


-- MODES FUNCTIONS
function Leona.ComboLogic(mode)
    local Ma = Menu.Get("Max.E")
    local Mi = Menu.Get("Min.E")
    if CanCast(E,mode) then
        for k, eTarget in ipairs(GetTargets(E)) do
            if eTarget:Distance(Player) < Ma and Player:Distance(eTarget) > Mi and E:CastOnHitChance(eTarget, HitChance(E)) then
                return
            end
        end
    end
    if CanCast(W,mode) then
        for k, wTarget in ipairs(GetTargets(W)) do
            if W:Cast() then
                return
            end
        end
    end    
    if CanCast(R,mode) then
        for k, rTarget in ipairs(GetTargets(R)) do
            if R:CastOnHitChance(rTarget, HitChance(R)) then
                return
            end
        end
    end
end

function Leona.HarassLogic(mode)
    if Menu.Get("ManaSlider") > Player.ManaPercent * 100 then return end
    local Ma = Menu.Get("Max.E")
    local Mi = Menu.Get("Min.E")
    if CanCast(E,mode) then
        for k, eTarget in ipairs(GetTargets(E)) do
            if eTarget:Distance(Player) < Ma and Player:Distance(eTarget) > Mi and E:CastOnHitChance(eTarget, HitChance(E)) then
                return
            end
        end
    end
    if CanCast(W,mode) then
        for k, wTarget in ipairs(GetTargets(W)) do
            if W:Cast() then
                return
            end
        end
    end
end

function Leona.OnInterruptibleSpell(source, spell, danger, endT, canMove)
    if not (source.IsEnemy and Menu.Get("Misc.IntE") and E:IsReady() and danger > 2) then return end
    E:CastOnHitChance(source, Enums.HitChance.VeryHigh)
end

function Leona.OnInterruptibleSpell(source, spell, danger, endT, canMove)
    if not (source.IsEnemy and Menu.Get("Misc.IntR") and R:IsReady() and danger > 2) then return end
    R:CastOnHitChance(source, Enums.HitChance.VeryHigh)
end

function Leona.OnPreAttack(args)
    local mode = Orbwalker.GetMode()
     if not args.Target.AsAI or not Q:IsReady() then return end
    if args.Target and args.Target.IsHero then
        if mode == "Combo" and Menu.Get("Qmode") == 1 then
            if CanCast(Q,mode) and Q:Cast() then return end
        end
    end
    if args.Target and args.Target.IsHero then
        if mode == "Harass" and Menu.Get("QmodeH") == 1 then
            if CanCast(Q,mode) and Menu.Get("ManaSlider") < Player.ManaPercent * 100 then
                if Q:Cast() then return end
            end
        end
    end
end

function Leona.OnPostAttack(target)
    local mode = Orbwalker.GetMode()
    if not target.AsAI or not Q:IsReady() then return end
    if target.IsHero then
        if mode == "Combo" and Menu.Get("Qmode") == 0 then
            if CanCast(Q,mode) and Q:Cast() then return end
        end
    end
    if target.IsHero then
        if mode == "Harass" and Menu.Get("QmodeH") == 0 then
            if CanCast(Q,mode) and Menu.Get("ManaSlider") < Player.ManaPercent * 100 then
                if Q:Cast() then return end
            end
        end
    end
end


function Leona.Auto() 
    local ForceR = Menu.Get("Misc.ForceR")
    if ForceR then
        Input.MoveTo(Renderer.GetMousePos())
        for k, rTarget in ipairs(GetTargets(R)) do
            if R:CastOnHitChance(rTarget, 0.7) then
                return
            end
        end
    end 
    local points = {}
    local autoR = Menu.Get("Misc.AutoR")
    for k, rTarget in ipairs(TS:GetTargets(R.Range, true)) do
        local pred = R:GetPrediction(rTarget)
        if pred and pred.HitChanceEnum >= Enums.HitChance.High then
            insert(points, pred.CastPosition)
        end
    end
    if autoR then
        local bestPos, hitCount = R:GetBestCircularCastPos(points)
        if hitCount >= Menu.Get("Misc.AutoR") then
            R:Cast(bestPos)
        end
    end
end


-- RECALLERS
function Leona.Combo()  Leona.ComboLogic("Combo")  end
function Leona.Harass() Leona.HarassLogic("Harass") end



function Leona.LoadMenu()
    Menu.RegisterMenu("StormLeona", "Storm Leona", function()
        Menu.NewTree("Combo", "Combo Options", function()
            Menu.Checkbox("Combo.CastQ",   "Use [Q]", true)
            Menu.Dropdown("Qmode","Q mode",1,{"Post Attack", "Pre Attack"})
            Menu.Checkbox("Combo.CastW",   "Use [W]", true)
            Menu.Checkbox("Combo.CastE",   "Use [E]", true)
            Menu.Checkbox("Combo.CastR",   "Use [R]", false)
        end)
        Menu.NewTree("Harass", "Harass Options", function()
            Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
            Menu.Slider("ManaSlider","",50,0,100)
            Menu.Checkbox("Harass.CastQ",   "Use [Q]", true)
            Menu.Dropdown("QmodeH","Q mode",1,{"Post Attack", "Pre Attack"})
            Menu.Checkbox("Harass.CastW",   "Use [W]", false)
            Menu.Checkbox("Harass.CastE",   "Use [E]", true)
        end)
        Menu.NewTree("Range", "Spell Range Options", function()
            Menu.Slider("Max.E","[E] Max Range", 875, 500, 875)
            Menu.Slider("Min.E","[E] Min Range",100, 0, 400)
        end)
        Menu.NewTree("Prediction", "Prediction Options", function()
            Menu.Slider("Chance.E","HitChance [E]",0.75, 0, 1, 0.05)
            Menu.Slider("Chance.R","HitChance [R]",0.75, 0, 1, 0.05)
        end)
        Menu.NewTree("Misc", "Misc Options", function()
            Menu.Checkbox("Misc.IntE", "Use [E] Interrupt", true)
            Menu.Checkbox("Misc.IntR", "Use [R] Interrupt", false)
            Menu.Slider("Misc.AutoR", "Auto [R] If Hit X", 3, 2, 5)
            Menu.Keybind("Misc.ForceR", "Force [R] Key", string.byte('T'))
        end)
        Menu.NewTree("Draw", "Drawing Options", function()
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
    Leona.LoadMenu()
    for eventName, eventId in pairs(Enums.Events) do
        if Leona[eventName] then
            EventManager.RegisterCallback(eventId, Leona[eventName])
        end
    end    
    return true
end