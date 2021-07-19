-- 🆂🆃🅾🆁🅼🅰🅸🅾 --
if Player.CharName ~= "Morgana" then return end
require("common.log")
module("Storm Morgana", package.seeall, log.setup)
clean.module("Storm Morgana", clean.seeall, log.setup)
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
local Morgana = {}
local MorganaNP = {}


-- spells
local Q = Spell.Skillshot({
    Slot = Enums.SpellSlots.Q,
    Range = 1300,
    Radius = 70,
    Delay = 0.25,
    Speed = 1200,
    Collisions = { Heroes = true, Minions = true, WindWall = true },
    Type = "Linear",
    UseHitbox = true,
    Key = "Q"
})
local W = Spell.Skillshot({
    Slot = Enums.SpellSlots.W,
    Range = 900,
    Radius = 275,
    Delay = 0.25,
    Type = "Circular",
    Key = "W"
})
local E = Spell.Targeted({
    Slot = Enums.SpellSlots.E,
    Range = 800,
    Delay = 0,
    Key = "E"
})
local R = Spell.Active({
    Slot = Enums.SpellSlots.R,
    Range = 625,
    Delay = 0.35,
    Key = "R",
})

local function GameIsAvailable()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

function Morgana.OnHighPriority() 
    if not GameIsAvailable() then
        return
    end
    if Morgana.Auto() then return end
    local ModeToExecute = Morgana[Orbwalker.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end

function Morgana.OnNormalPriority()
    if not GameIsAvailable() then
        return
    end
    local ModeToExecute = MorganaNP[Orbwalker.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end



-- Draw
function Morgana.OnDraw()
    local Pos = Player.Position
    local spells = {Q,W,E,R}
    for k, v in pairs(spells) do
        if Menu.Get("Drawing."..v.Key..".Enabled", true) and v:IsReady() then
            Renderer.DrawCircle3D(Pos, v.Range, 30, 3, Menu.Get("Drawing."..v.Key..".Color"))
        end
    end
end


--spellDmg
local function dmg(spell)
    if spell.Key == "Q" then
        return (80 + (spell:GetLevel() - 1) * 55) + (0.9 * Player.TotalAP)
    end
    if spell.Key == "R" then
        return  (150 + (spell:GetLevel() - 1) * 75) + (0.7 * Player.TotalAP)
    end
end


-- spell Helpers
local function CanCast(spell,mode)
    return spell:IsReady() and Menu.Get(mode .. ".Cast"..spell.Key)
end

local function HitChance(spell)
    return Menu.Get("Chance."..spell.Key)
end

local function GetTargets(Spell)
    return {TS:GetTarget(Spell.Range,true)}
end

local function Count(spell)
    local num = 0
    for k, v in pairs(ObjManager.Get("enemy", "heroes")) do
        local hero = v.AsHero
        if hero and hero.IsTargetable and hero:Distance(Player.Position) < spell.Range then
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


-- Mode Functions
function Morgana.ComboLogic(mode)
    local Ma = Menu.Get("Max.Q")
    local Mi = Menu.Get("Min.Q")
    if CanCast(Q,mode) then
        for k, qTarget in ipairs(GetTargets(Q)) do
            if qTarget:Distance(Player) < Ma and Player:Distance(qTarget) > Mi and Q:CastOnHitChance(qTarget, HitChance(Q)) then
                return
            end
        end
    end
    if CanCast(W,mode) and Menu.Get("wmode") == 0 then
        for k, wTarget in ipairs(GetTargets(W)) do
            if W:CastOnHitChance(wTarget, HitChance(W)) then
                return
            end
        end
    end
    if CanCast(W,mode) and Menu.Get("wmode") == 1 then
        for k, wTarget in ipairs(GetTargets(W)) do
            if not wTarget.CanMove and W:CastOnHitChance(wTarget, Enums.HitChance.Immobile) then
                return
            end
        end
    end
    if CanCast(R,mode) then
        if Count(R) >= Menu.Get("Combo.HitcountR") then
            if R:Cast() then
                return
            end
        end
    end
end

function Morgana.HarassLogic(mode)
    if Menu.Get("ManaSlider") > (Player.ManaPercent * 100) then return end
    local Ma = Menu.Get("Max.Q")
    local Mi = Menu.Get("Min.Q")
    if CanCast(Q,mode) then
        for k, qTarget in ipairs(GetTargets(Q)) do
            if qTarget:Distance(Player) < Ma and Player:Distance(qTarget) > Mi and Q:CastOnHitChance(qTarget, HitChance(Q)) then
                return
            end
        end
    end
    if CanCast(W,mode) and Menu.Get("wmodeh") == 1 then
        for k, wTarget in ipairs(GetTargets(W)) do
            if not wTarget.CanMove and W:CastOnHitChance(wTarget, Enums.HitChance.Immobile) then
                return
            end
        end
    end
    if CanCast(W,mode) and Menu.Get("wmodeh") == 0 then
        for k, wTarget in ipairs(GetTargets(W)) do
            if W:CastOnHitChance(wTarget, HitChance(W)) then
                return
            end
        end
    end
end


-- callbacks
---@param source AIBaseClient
---@param spell SpellCast
function Morgana.OnInterruptibleSpell(source, spell, danger, endT, canMove)
    if not (source.IsEnemy and Menu.Get("Misc.IntQ") and Q:IsReady() and danger > 2) then return end
    Q:CastOnHitChance(source, Enums.HitChance.VeryHigh)
end

function Morgana.OnPreAttack(args)
    if Menu.Get("Support") and args.Target.IsMinion and CountHeroes(1000,"ally") > 1 then
        args.Process = false
    end
end

function Morgana.OnProcessSpell(sender,spell)
    if not (sender.IsHero and sender.IsEnemy) or not E:IsReady() then return end

    if spell.Target and Menu.Get(spell.Target.AsHero.CharName) and E:IsInRange(spell.Target) then
        if spell.Name == "PantheonW" then
            E:Cast(spell.Target)
            return
        end -- [[TODO add more targeted spell names]]
    end
    if spell.IsSpecialAttack then
        local target = spell.Target
        if target and E:IsInRange(target) and target.IsHero and spell.IsSpecialAttack and Menu.Get(target.AsHero.CharName) then
            E:Cast(target)
        end
    end
    if spell.Slot > 3 then return end
    if  not Menu.Get(spell.Slot .. sender.CharName) then return end
    for k,v in pairs(ObjManager.Get("ally", "heroes")) do
        local Hero = v.AsHero
        if E:IsInRange(Hero) and Menu.Get(Hero.CharName) then
            if Hero:Distance(spell.EndPos) < Hero.BoundingRadius * 2 then
                if E:Cast(Hero) then
                    return
                end
            end
        end
    end
end

function Morgana.OnGapclose(Source, DashInstance)
    if not (Source.IsEnemy or Menu.Get("Misc.GapQ") or Q:IsReady()) then return end
    local mypos = Player.Position
    local Dist  = mypos:Distance(Source)
    if Dist < 400 then
        if Q:CastOnHitChance(Source,Enums.HitChance.Dashing) then return end
    end
end

function Morgana.Auto()
    if R:IsReady() and Menu.Get("Misc.AutoR") then
        if Count(R) >= Menu.Get("Misc.AutoRhit") then
            if R:Cast() then
                return
            end
        end
    end
    if Q:IsReady() and Menu.Get("KS.Q") then
        for k, qTarget in ipairs(GetTargets(Q)) do
            local Qdmg = DmgLib.CalculateMagicalDamage(Player,qTarget,dmg(Q))
            local ks   = Q:GetKillstealHealth(qTarget)
            if Qdmg > ks and Q:CastOnHitChance(qTarget,HitChance(Q))then return end
        end
    end
    if R:IsReady() and Menu.Get("KS.R") then
        for k, rTarget in ipairs(GetTargets(R)) do
            local Rdmg = DmgLib.CalculateMagicalDamage(Player,rTarget,dmg(R))
            local ks   = R:GetKillstealHealth(rTarget)
            if Rdmg > ks and R:Cast() then return end
        end
    end
end


-- Orbwalker mode recaller
function Morgana.Combo()  Morgana.ComboLogic("Combo")  end
function MorganaNP.Harass() Morgana.HarassLogic("Harass") end
function MorganaNP.Waveclear()
    if Q:IsReady() and Jungle(Q) then
        for k, v in pairs(ObjManager.Get("neutral", "minions")) do
        local minion = v.AsAI
        local minionInRange = Q:IsInRange(minion)
        if minionInRange and minion.MaxHealth > 6  and minion.IsTargetable then
            if Q:Cast(minion) then
                return
            end
        end
        end
    end
    if W:IsReady() and Jungle(W) then
        for k, v in pairs(ObjManager.Get("neutral", "minions")) do
        local minion = v.AsAI
        local minionInRange = W:IsInRange(minion)
        if minionInRange and minion.MaxHealth > 6  and minion.IsTargetable then
            if W:Cast(minion) then
                return
            end
        end
        end
    end
    if Menu.Get("ManaSliderLane") > (Player.ManaPercent * 100) then return end
    if Q:IsReady() and Lane(Q) then
         for k, v in pairs(ObjManager.Get("enemy", "minions")) do
         local minion = v.AsAI
         local minionInRange = Q:IsInRange(minion)
         local pre  = Q:GetHealthPred(minion)
         local Qdmg = DmgLib.CalculateMagicalDamage(Player,minion,dmg(Q))
            if minionInRange and minion.MaxHealth > 6  and minion.IsTargetable and pre > 0 and Qdmg > pre then
                if Q:CastOnHitChance(minion, Enums.HitChance.Medium) then
                    return
                end
            end
         end
    end
    local Wpoints = {}
    for k,v in pairs(ObjManager.Get("enemy", "minions")) do
    local minion = v.AsAI
    local minionInRange = W:IsInRange(minion)
    local pos = minion:FastPrediction(Game.GetLatency()+ W.Delay)
        if minionInRange and minion.IsTargetable and minion.MaxHealth > 6 then
            insert(Wpoints, pos)
        end
    end
    if W:IsReady() and Lane(W) then
    local bestPos, hitCount = W:GetBestCircularCastPos(Wpoints, W.Radius)
        if bestPos and hitCount >= Menu.Get("Lane.WH") then
            W:Cast(bestPos)
        end
    end
end


-- Menu
function Morgana.LoadMenu()
    Menu.RegisterMenu("StormMorgana", "Storm Morgana", function()
        Menu.Checkbox("Support",   "Support Mode", true)
        Menu.NewTree("Combo", "Combo Options", function()
            Menu.Checkbox("Combo.CastQ",   "Use [Q]", true)
            Menu.Checkbox("Combo.CastW",   "Use [W]", true)
            Menu.Dropdown("wmode","W mode",1,{"Always","Immobile"})
            Menu.Checkbox("Combo.CastR",   "Use [R]", true)
            Menu.Slider("Combo.HitcountR", "[R] HitCount", 2, 1, 5)
        end)
        Menu.NewTree("Harass", "Harass Options", function()
            Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
            Menu.Slider("ManaSlider","",50,0,100)
            Menu.Checkbox("Harass.CastQ",   "Use [Q]", true)
            Menu.Checkbox("Harass.CastW",   "Use [W]", true)
            Menu.Dropdown("wmodeh","W mode",1,{"Always","Immobile"})
        end)
        Menu.NewTree("Wave", "Farming Options", function()
            Menu.NewTree("Lane", "Laneclear Options", function()
                Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
                Menu.Slider("ManaSliderLane","",50,0,100)
                Menu.Checkbox("Lane.Q",   "Use Q", false)
                Menu.Checkbox("Lane.W",   "Use W", false)
                Menu.Slider("Lane.WH",   "W Hitcount", 2,1,5)
            end)
            Menu.NewTree("Jungle", "Jungleclear Options", function()
                Menu.Checkbox("Jungle.Q",   "Use Q", false)
                Menu.Checkbox("Jungle.W",   "Use W", false)
            end)
        end)
        Menu.NewTree("Misc", "Misc Options", function()
            Menu.NewTree("MiscQ", "Q Options", function()
                Menu.Checkbox("Misc.GapQ",   "Use [Q] on gapcloser", true)
                Menu.Checkbox("Misc.IntQ", "Use [Q] on Interrupt",true)
            end)
            Menu.NewTree("MiscE", "E Options", function()
                Menu.Checkbox("Misc.UseE", "Use [E] to block Speical Attacks",true)
                Menu.ColoredText("E spellblocker List", 0xFFD700FF, true)
                for k, Object in pairs(ObjManager.Get("enemy", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.NewTree(Name,Name, function()
                        Menu.Checkbox(0 .. Name, "Use on " .. "Q", false)
                        Menu.Checkbox(1 .. Name, "Use on " .. "W", false)
                        Menu.Checkbox(2 .. Name, "Use on " .. "E", false)
                        Menu.Checkbox(3 .. Name, "Use on " .. "R", false)
                    end)
                end
                Menu.ColoredText("E White List", 0xFFD700FF, true)
                for k, Object in pairs(ObjManager.Get("ally", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox(Name, "Use on " .. Name, true)
                end
            end)
            Menu.NewTree("MiscR", "R Options", function()
                Menu.Checkbox("Misc.AutoR",   "Auto R", true)
                Menu.Slider("Misc.AutoRhit", "Auto R if hitcount =>",4,1,5)
            end)
        end)
        Menu.NewTree("Range", "Spell Range Options", function()
            Menu.Slider("Max.Q","[Q] Max Range", 1300, 0, 1300)
            Menu.Slider("Min.Q","[Q] Min Range",100, 0, 500)
        end)
        Menu.NewTree("Prediction", "Prediction Options", function()
            Menu.Slider("Chance.Q","HitChance [Q]", 0.75, 0, 1, 0.05)
            Menu.Slider("Chance.W","HitChance [W]",0.85, 0, 1, 0.05)
        end)
        Menu.NewTree("KillSteal", "KillSteal Options", function()
            Menu.Checkbox("KS.Q",   "Use Q", false)
            Menu.Checkbox("KS.R",   "Use R", false)
        end)
        Menu.NewTree("Draw", "Drawing Options", function()
            Menu.Checkbox("Drawing.Q.Enabled",   "Draw [Q] Range",true)
            Menu.ColorPicker("Drawing.Q.Color", "Draw [Q] Color", 0xf03030ff)
            Menu.Checkbox("Drawing.W.Enabled",   "Draw [W] Range",true)
            Menu.ColorPicker("Drawing.W.Color", "Draw [W] Color", 0x30e6f0ff)
            Menu.Checkbox("Drawing.E.Enabled",   "Draw [E] Range",false)
            Menu.ColorPicker("Drawing.E.Color", "Draw [E] Color", 0x3060f0ff)
            Menu.Checkbox("DrawingR.R.Enabled",   "Draw [R] Range",true)
            Menu.ColorPicker("DrawingR.R.Color", "Draw [R] Color", 0xf03086ff)
        end)
    end)
end

function OnLoad()
    Morgana.LoadMenu()
    for eventName, eventId in pairs(Enums.Events) do
        if Morgana[eventName] then
            EventManager.RegisterCallback(eventId, Morgana[eventName])
        end
    end
    return true
end