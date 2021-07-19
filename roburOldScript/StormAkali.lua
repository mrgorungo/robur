-- 🆂🆃🅾🆁🅼🅰🅸🅾 --
if Player.CharName ~= "Akali" then return end
require("common.log")
module("Storm Akali", package.seeall, log.setup)
clean.module("Storm Akali", clean.seeall, log.setup)
local clock = os.clock
local insert, sort = table.insert, table.sort
local huge, min, max, abs = math.huge, math.min, math.max, math.abs
local _SDK = _G.CoreEx
local Console, ObjManager, EventManager, Geometry, Input, Renderer, Enums, Game = _SDK.Console, _SDK.ObjectManager, _SDK.EventManager, _SDK.Geometry, _SDK.Input, _SDK.Renderer, _SDK.Enums, _SDK.Game
local Menu, Orbwalker, Collision, Prediction, HealthPred = _G.Libs.NewMenu, _G.Libs.Orbwalker, _G.Libs.CollisionLib, _G.Libs.Prediction, _G.Libs.HealthPred
local DmgLib, ImmobileLib, Spell = _G.Libs.DamageLib, _G.Libs.ImmobileLib, _G.Libs.Spell

---@type TargetSelector
local TS = _G.Libs.TargetSelector()
local Akali = {}
local AkaliNP = {}

local spells = {
    Q = Spell.Skillshot({
        Slot = Enums.SpellSlots.Q,
        Range = 500,
        Delay = 0.25,
        Type = "Cone",
    }),
    W = Spell.Skillshot({
        Slot = Enums.SpellSlots.W,
        Delay = 0.25,
        Range = 500
    }),
    E = Spell.Skillshot({
        Slot = Enums.SpellSlots.E,
        Range = 825,
        Delay = 0.40,
        Radius = 120,
        Speed = 1800,
        Collisions = {WindWall = true,Minions=true },
        UseHitbox = true
    }),
    E2 = Spell.Active({
        Slot = Enums.SpellSlots.E,
        Range = 25000,
        Delay = 0.25
    }),
    R = Spell.Skillshot({
        Slot = Enums.SpellSlots.R,
        Range = 750,
        Radius = 60,
        Delay = 0.15,
        Speed = 3000,
        Type = "Linear",
        UseHitbox = true
    }),
    R2 = Spell.Targeted({
        Slot = Enums.SpellSlots.R,
        Range = 670,
    }),
}

local function GameIsAvailable()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end


function Akali.IsEnabledAndReady(spell, mode)
    return Menu.Get(mode .. ".Use"..spell) and spells[spell]:IsReady()
end

function Akali.OnHighPriority() 
    if not GameIsAvailable() then
        return
    end
    if Akali.Auto() then return end
    local ModeToExecute = Akali[Orbwalker.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end

function Akali.OnNormalPriority()
    if not GameIsAvailable() then
        return
    end
    local ModeToExecute = AkaliNP[Orbwalker.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end

function Akali.OnDraw() 
    local playerPos = Player.Position
    local pRange = Orbwalker.GetTrueAutoAttackRange(Player)   
    

    for k, v in pairs(spells) do
        if Menu.Get("Drawing."..k..".Enabled", true) then
            Renderer.DrawCircle3D(playerPos, v.Range, 30, 2, Menu.Get("Drawing."..k..".Color")) 
        end
    end
end

function Akali.GetTargets(range)
    return {TS:GetTarget(range, true)}
end

function Akali.ComboLogic(mode)
    local Mana = Menu.Get("Combo.manaW")
    if Akali.IsEnabledAndReady("Q", mode) and not Player.IsDashing then
        local qChance = Menu.Get(mode .. ".ChanceQ")
        for k, qTarget in ipairs(Akali.GetTargets(spells.Q.Range)) do
            if spells.Q:CastOnHitChance(qTarget, qChance) then
                return
            end
        end
    end
    if Akali.IsEnabledAndReady("W", mode) and Player.Mana <= Mana then
        for k, wTarget in ipairs(Akali.GetTargets(spells.W.Range)) do
            if spells.W:Cast(Player) then
                return
            end
        end
    end
    if Akali.IsEnabledAndReady("E", mode) and spells.E:GetName() == "AkaliE" then
        local eChance = Menu.Get(mode .. ".ChanceE")
        for k, eTarget in ipairs(Akali.GetTargets(spells.E.Range)) do
            
            if spells.E:CastOnHitChance(eTarget, eChance) then
                return
            end
        end
    end
    if Akali.IsEnabledAndReady("E2", mode) and spells.E:GetName() == "AkaliEb" then
        for k, eTarget in ipairs(Akali.GetTargets(25000)) do
            
            if eTarget:GetBuff("AkaliEMis") then
                if spells.E2:Cast() then
                    return
                end
            end
        end
    end
    if Akali.IsEnabledAndReady("R", mode) and  spells.R:GetName() == "AkaliR" then
        for k, rTarget in ipairs(Akali.GetTargets(spells.R2.Range)) do
            if spells.R2:Cast(rTarget) then
                return
            end
        end
    end
    if Akali.IsEnabledAndReady("R2", mode) and spells.R:GetName() == "AkaliRb" then
        local rChance = Menu.Get(mode .. ".ChanceR")
        for k, rTarget in ipairs(Akali.GetTargets(spells.R.Range)) do
            
            if spells.R:CastOnHitChance(rTarget, rChance) then
                return
            end
        end
    end
end
function Akali.HarassLogic(mode)
    local Mana = Menu.Get("Harass.manaW")
    local p = Menu.Get("Harass.logic")
    if Player:GetBuff("akalipweapon") and p then return end 
    if Akali.IsEnabledAndReady("Q", mode) and not Player.IsDashing then
        local qChance = Menu.Get(mode .. ".ChanceQ")
        for k, qTarget in ipairs(Akali.GetTargets(spells.Q.Range)) do
            if spells.Q:CastOnHitChance(qTarget, qChance) then
                return
            end
        end
    end
    if Akali.IsEnabledAndReady("W", mode) and Player.Mana <= Mana then
        for k, wTarget in ipairs(Akali.GetTargets(spells.W.Range)) do
            if spells.W:Cast(Player) then
                return
            end
        end
    end
    if Akali.IsEnabledAndReady("E", mode) and spells.E:GetName() == "AkaliE" then
        local eChance = Menu.Get(mode .. ".ChanceE")
        for k, eTarget in ipairs(Akali.GetTargets(spells.E.Range)) do
            
            if spells.E:CastOnHitChance(eTarget, eChance) then
                return
            end
        end
    end
    if Akali.IsEnabledAndReady("E2", mode) and spells.E:GetName() == "AkaliEb" then
        for k, eTarget in ipairs(Akali.GetTargets(25000)) do
            
            if eTarget:GetBuff("AkaliEMis") then
                if spells.E2:Cast() then
                    return
                end
            end
        end
    end
end
function Akali.Rdmg1()
    return (125 + (spells.R:GetLevel() - 1) * 100) + (0.5 * Player.BonusAD)
end
function Akali.Rdmg2(target)
    local missingHealthPercent = (1 - target.Health / target.MaxHealth) * 100;
    local totalIncreasement = 1 + 2.86 * missingHealthPercent / 100;
    return ((75 + (spells.R:GetLevel() - 1) * 70) + (0.3 * Player.TotalAP)) * totalIncreasement
end
function Akali.Qdmg()
    return (30 + (spells.Q:GetLevel() - 1) * 25) + (0.65 * Player.TotalAD) + (0.6 * Player.TotalAP)
end
function Akali.Edmg()
    return (50 + (spells.E:GetLevel() - 1) * 35) + (0.35 * Player.TotalAD) + (0.5 * Player.TotalAP)
end

function Akali.OnGapclose(source, dash)
    if not (source.IsEnemy and Menu.Get("Misc.GapE") and spells.E:IsReady()) and spells.E:GetName() == "AkaliE"  then return end
    local paths = dash:GetPaths()
    local endPos = paths[#paths].EndPos
    local pPos = Player.Position
    if source:Distance(Player) < 400 and source:IsFacing(pPos) and spells.E:IsInRange(source) then
    spells.E:Cast(endPos)
    end
end

function Akali.Auto()
  if Menu.Get("KillSteal.Q") then 
    for k, qTarget in ipairs(TS:GetTargets(spells.Q.Range, true)) do        
        local rDmg = DmgLib.CalculateMagicalDamage(Player, qTarget, Akali.Qdmg())
        local ksHealth = spells.Q:GetKillstealHealth(qTarget)
        if rDmg > ksHealth and  spells.Q:CastOnHitChance(qTarget, Enums.HitChance.Medium) then
           return
        end 
   end
  end
  if Menu.Get("KillSteal.E1") and spells.E:GetName() == "AkaliE" then 
    for k, eTarget in ipairs(TS:GetTargets(spells.E.Range, true)) do        
        local eDmg = DmgLib.CalculateMagicalDamage(Player, eTarget, Akali.Edmg())
        local ksHealth = spells.E:GetKillstealHealth(eTarget)
        if eDmg > ksHealth and  spells.E:CastOnHitChance(eTarget, Enums.HitChance.Medium) then
           return
        end 
   end
  end
  if Menu.Get("KillSteal.E2") and spells.E:GetName() == "AkaliEb" then 
    for k, eTarget in ipairs(TS:GetTargets(spells.E2.Range, true)) do        
        local eDmg = DmgLib.CalculateMagicalDamage(Player, eTarget, Akali.Edmg())
        local ksHealth = spells.E2:GetKillstealHealth(eTarget)
        if eDmg > ksHealth and eTarget:GetBuff("AkaliEMis")  then
            if spells.E2:Cast() then
                 return
            end
        end 
   end
  end
  if Menu.Get("KillSteal.R") and spells.R:GetName() == "AkaliR" then 
    for k, rTarget in ipairs(TS:GetTargets(spells.R2.Range, true)) do        
        local rDmg = DmgLib.CalculateMagicalDamage(Player, rTarget, Akali.Rdmg1())
        local ksHealth = spells.R2:GetKillstealHealth(rTarget)
        if rDmg > ksHealth and  spells.R2:Cast(rTarget) then
           return
        end 
   end
  end
  if Menu.Get("KillSteal.R2") and spells.R:GetName() == "AkaliRb" then 
    for k, rTarget in ipairs(TS:GetTargets(spells.R.Range, true)) do        
        local rDmg = DmgLib.CalculateMagicalDamage(Player, rTarget, Akali.Rdmg2(rTarget))
        local ksHealth = spells.R:GetKillstealHealth(rTarget)
        if rDmg > ksHealth and  spells.R:CastOnHitChance(rTarget, Enums.HitChance.Medium) then
           return
        end 
    end
  end
end   


function Akali.Combo()  Akali.ComboLogic("Combo")  end
function AkaliNP.Harass() Akali.HarassLogic("Harass") end
function AkaliNP.Waveclear()
    if not spells.Q:IsReady() then return end
    local farmQ = Menu.Get("Clear.UseQ")
    local pPos, pointsQ = Player.Position, {}
    for k, v in pairs(ObjManager.Get("enemy", "minions")) do
        local minion = v.AsAI
        if minion then
            local pos = minion:FastPrediction(spells.Q.Delay)
            if pos:Distance(pPos) < spells.Q.Range and minion.IsTargetable then
                insert(pointsQ, pos)
            end 
        end                       
    end
    if farmQ then
        local bestPos, hitCount = Geometry.BestCoveringRectangle(pointsQ,pPos, 60*4)
        if bestPos and hitCount >= 2 and spells.Q:Cast(bestPos) then
            return
        end
    end
    local farmQJ = Menu.Get("Clear.UseQJ")
    for k, v in pairs(ObjManager.Get("neutral", "minions")) do
        local minion = v.AsAI
        if minion then
            if minion.IsTargetable and spells.Q:IsInRange(minion) then
                if spells.Q:Cast(minion) then 
                    return
                end
            end 
        end                       
    end
end


function Akali.LoadMenu()
    Menu.RegisterMenu("StormAkali", "Storm Akali", function()
        Menu.NewTree("Combo", "Combo Options", function()
            Menu.Checkbox("Combo.UseQ",   "Use [Q]", true) 
            Menu.Slider("Combo.ChanceQ", "HitChance [Q]", 0.7, 0, 1, 0.05)   
            Menu.Checkbox("Combo.UseW",   "Use [W]", true)
            Menu.Slider("Combo.manaW", "Use [W] when energy <", 60, 0, 200) 
            Menu.Checkbox("Combo.UseE",   "Use [E] first cast", true)
            Menu.Slider("Combo.ChanceE", "HitChance [E]", 0.7, 0, 1, 0.05)  
            Menu.Checkbox("Combo.UseE2",   "Use [E2] second cast", true) 
            Menu.Checkbox("Combo.UseR",   "Use [R] first cast", true)
            Menu.Checkbox("Combo.UseR2",   "Use [R2] second cast", true)
            Menu.Slider("Combo.ChanceR", "HitChance [R]", 0.7, 0, 1, 0.05)  
        end)
        Menu.NewTree("Harass", "Harass Options", function()
            Menu.Checkbox("Harass.logic",   "Don't use Abilities when Passive up", false) 
            Menu.Checkbox("Harass.UseQ",   "Use [Q]", true) 
            Menu.Slider("Harass.ChanceQ", "HitChance [Q]", 0.7, 0, 1, 0.05)   
            Menu.Checkbox("Harass.UseW",   "Use [W]", true)
            Menu.Slider("Harass.manaW", "Use [W] when energy <", 60, 0, 200) 
            Menu.Checkbox("Harass.UseE",   "Use [E] first cast", true)
            Menu.Slider("Harass.ChanceE", "HitChance [E]", 0.7, 0, 1, 0.05)  
            Menu.Checkbox("Harass.UseE2",   "Use [E2] second cast", true) 
        end)
        Menu.NewTree("Clear", "Clear Options", function()
            Menu.ColoredText("Lane", 0xFFD700FF, true)
            Menu.Checkbox("Clear.UseQ",   "Use [Q] Lane", true) 
            Menu.ColoredText("Jungle", 0xFFD700FF, true)
            Menu.Checkbox("Clear.UseQJ",   "Use [Q] Jungle", true) 
        end)
        Menu.NewTree("KillSteal", "KillSteal Options", function()
            Menu.Checkbox("KillSteal.Q", "Use [Q] to KS", true)  
            Menu.Checkbox("KillSteal.E1", "Use [E] first cast to KS", true) 
            Menu.Checkbox("KillSteal.E2", "Use [E2] second cast to KS", true) 
            Menu.Checkbox("KillSteal.R", "Use [R] first to KS", false) 
            Menu.Checkbox("KillSteal.R2", "Use [R] second to KS", true)        
        end)
        Menu.NewTree("Misc", "Misc Options", function()
            Menu.Checkbox("Misc.GapE", "Use [E] on gapcloser", true)   
        end)
        Menu.NewTree("Draw", "Draw Options", function()
            Menu.Checkbox("Drawing.Q.Enabled",   "Draw [Q] Range")
            Menu.ColorPicker("Drawing.Q.Color", "Draw [Q] Color", 0x118AB2FF)    
            Menu.Checkbox("Drawing.W.Enabled",   "Draw [W] Range")
            Menu.ColorPicker("Drawing.W.Color", "Draw [W] Color", 0x118AB2FF)  
            Menu.Checkbox("Drawing.E.Enabled",   "Draw [E] Range")
            Menu.ColorPicker("Drawing.E.Color", "Draw [E] Color", 0x118AB2FF)    
            Menu.Checkbox("Drawing.R.Enabled",   "Draw [R] Range")
            Menu.ColorPicker("Drawing.R.Color", "Draw [R] Color", 0x118AB2FF)     
            Menu.Checkbox("Drawing.R2.Enabled",   "Draw [R2] Range")
            Menu.ColorPicker("Drawing.R2.Color", "Draw [R2] Color", 0x118AB2FF)     
        end) 
    end)     
end

function OnLoad()
    Akali.LoadMenu()
    for eventName, eventId in pairs(Enums.Events) do
        if Akali[eventName] then
            EventManager.RegisterCallback(eventId, Akali[eventName])
        end
    end    
    return true
end
