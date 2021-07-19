-- 🆂🆃🅾🆁🅼🅰🅸🅾 --
if Player.CharName ~= "Lux" then return end
require("common.log")
module("Storm Lux", package.seeall, log.setup)
clean.module("Storm Lux", clean.seeall, log.setup)
local clock = os.clock
local insert, sort = table.insert, table.sort
local huge, min, max, abs = math.huge, math.min, math.max, math.abs
local _SDK = _G.CoreEx
local Console, ObjManager, EventManager, Geometry, Input, Renderer, Enums, Game = _SDK.Console, _SDK.ObjectManager, _SDK.EventManager, _SDK.Geometry, _SDK.Input, _SDK.Renderer, _SDK.Enums, _SDK.Game
local Menu, Orbwalker, Collision, Prediction, HealthPred = _G.Libs.NewMenu, _G.Libs.Orbwalker, _G.Libs.CollisionLib, _G.Libs.Prediction, _G.Libs.HealthPred
local DmgLib, ImmobileLib, Spell = _G.Libs.DamageLib, _G.Libs.ImmobileLib, _G.Libs.Spell

---@type TargetSelector
local TS = _G.Libs.TargetSelector()
local Lux = {}
local LuxHP = {}

local spells = {
    Q = Spell.Skillshot({
        Slot = Enums.SpellSlots.Q,
        Range = 1300,
        Radius = 80,
        Delay = 0.25,
        Speed = 1200,
        Collisions = { Heroes = true, Minions = true, WindWall = true },
        MaxCollisions = 2,
        Type = "Linear",
        UseHitbox = true
    }),
    W = Spell.Skillshot({
        Slot = Enums.SpellSlots.W,
        Range = 1175,
        Radius = 200,
        Delay = 0.25,
        Type = "Linear",
    }),
    E = Spell.Skillshot({
        Slot = Enums.SpellSlots.E,
        Range = 1100,
        Radius = 250,
        Delay = 0.25,
        Speed = 1200,
        Collisions = {WindWall = true },
        Type = "Circular",
        UseHitbox = true
    }),
    E2 = Spell.Active({
        Slot = Enums.SpellSlots.E,
    }),
    R = Spell.Skillshot({
        Slot = Enums.SpellSlots.R,
        Range = 3400,
        Radius = 100,
        Delay = 1,
        Speed = huge,
        Type = "Linear",
        UseHitbox = true
    }),
}

local function GameIsAvailable()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end


function Lux.IsEnabledAndReady(spell, mode)
    return Menu.Get(mode .. ".Use"..spell) and spells[spell]:IsReady()
end

function Lux.OnHighPriority() 
    if not GameIsAvailable() then
        return
    end
    if Lux.Auto() then return end
    local ModeToExecute = LuxHP[Orbwalker.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end

function Lux.OnNormalPriority()
    if not GameIsAvailable() then
        return
    end
    local ModeToExecute = Lux[Orbwalker.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end

function Lux.OnDraw() 
    local playerPos = Player.Position
    local pRange = Orbwalker.GetTrueAutoAttackRange(Player)   
    

    for k, v in pairs(spells) do
        if Menu.Get("Drawing."..k..".Enabled", true) then
            Renderer.DrawCircle3D(playerPos, v.Range, 30, 2, Menu.Get("Drawing."..k..".Color")) 
        end
    end
end
local function CountEnemiesInRange(pos, range, t)
    local res = 0
    for k, v in pairs(t or ObjManager.Get("enemy", "heroes")) do
        local hero = v.AsHero
        if hero and hero.IsTargetable and hero:Distance(pos) < range then
            res = res + 1
        end
    end
    return res
end
function Lux.GetTargets(range)
    return {TS:GetTarget(range, true)}
end
function Lux.GetQdmg() 
    return  (80 + (spells.Q:GetLevel() - 1) * 45) + (0.6 * Player.TotalAP)
end
function Lux.GetEdmg() 
    return  (60 + (spells.E:GetLevel() - 1) * 45) + (0.6 * Player.TotalAP)
end
function Lux.GetRdmg() 
    return  (300 + (spells.R:GetLevel() - 1) * 100) + (1 * Player.TotalAP)
end
function Lux.ComboLogic(mode)
    if Lux.IsEnabledAndReady("E", mode) then
        local eChance = Menu.Get(mode .. ".ChanceE")
        for k, eTarget in ipairs(Lux.GetTargets(spells.E.Range)) do
            if spells.E:GetToggleState() == 0 and spells.E:CastOnHitChance(eTarget,eChance) then
                return
            end
        end
    end
end
function Lux.HarassLogic(mode)
    local PM = Player.Mana / Player.MaxMana * 100
    if Lux.IsEnabledAndReady("E", mode) then
        local eChance = Menu.Get(mode .. ".ChanceE")
        for k, eTarget in ipairs(Lux.GetTargets(spells.E.Range)) do
            local SettedMana = Menu.Get("Harass.ManaQ")
            if SettedMana < PM then 
                if spells.E:GetToggleState() == 0 and spells.E:CastOnHitChance(eTarget,eChance) then
                    return
                 end 
            end
        end
    end
end
---@param source AIBaseClient
---@param spell SpellCast
function Lux.OnInterruptibleSpell(source, spell, danger, endT, canMove)
    if not (source.IsEnemy and Menu.Get("Misc.IntQ") and spells.Q:IsReady() and danger > 2) then return end
    if source:Distance(Player) > 1100 then  return end
    spells.Q:CastOnHitChance(source, Enums.HitChance.VeryHigh)
end
---@param source AIBaseClient
---@param dash DashInstance
function Lux.OnGapclose(source, dash)
    if not (source.IsEnemy and Menu.Get("Misc.GapQ") and spells.Q:IsReady()) then return end
    local Hero = source.AsHero
    if spells.Q:CastOnHitChance(Hero,Enums.HitChance.VeryHigh) then return end
end
function Lux.Auto() 
    if spells.R:IsReady() then  
        local autoR = Menu.Get("Misc.AutoR")
        local points = {}
        for k, rTarget in ipairs(TS:GetTargets(spells.R.Range, true)) do        
            local pred = spells.R:GetPrediction(rTarget)
            if pred and pred.HitChanceEnum >= Enums.HitChance.VeryHigh then
            insert(points, pred.CastPosition)
            end   
        end

        if autoR then
            local bestPos, hitCount = spells.R:GetBestLinearCastPos(points)
            if hitCount >= Menu.Get("Misc.AutoRhit") then
                spells.R:Cast(bestPos)
            end
        end
    end
    if spells.Q:IsReady() and Menu.Get("KS.Q") then 
        for k, qTarget in ipairs(Lux.GetTargets(spells.Q.Range)) do
            local rDmg = DmgLib.CalculateMagicalDamage(Player, qTarget, Lux.GetQdmg())
            local ksHealth = spells.Q:GetKillstealHealth(qTarget)
            if  rDmg > ksHealth and spells.Q:CastOnHitChance(qTarget, Enums.HitChance.Medium) then
                return
            end
        end
    end
    if spells.E:IsReady() and Menu.Get("KS.E") then 
        for k, eTarget in ipairs(Lux.GetTargets(spells.E.Range)) do
            local eDmg = DmgLib.CalculateMagicalDamage(Player, eTarget, Lux.GetEdmg())
            local ksHealth = spells.E:GetKillstealHealth(eTarget)
            if  eDmg > ksHealth and spells.E:GetToggleState() == 0  and spells.E:CastOnHitChance(eTarget, Enums.HitChance.Medium) then
                return
            end
            if spells.E:GetToggleState() == 2 then
                for k, v in pairs(ObjManager.Get("all", "particles")) do
                    if eDmg > ksHealth and v.Name == "Lux_Base_E_tar_aoe_sound" and v:Distance(eTarget) < spells.E.Radius then
                        if spells.E2:Cast() then return end
                    end
                end
            end
        end
    end
    if spells.R:IsReady() and Menu.Get("KS.R") then 
        for k, rTarget in ipairs(Lux.GetTargets(spells.R.Range)) do
            local rDmg = DmgLib.CalculateMagicalDamage(Player, rTarget, Lux.GetRdmg())
            local ksHealth = spells.R:GetKillstealHealth(rTarget)
            if  rDmg > ksHealth and spells.R:CastOnHitChance(rTarget, Enums.HitChance.VeryHigh) then
                return
            end
        end
    end
    if spells.E:IsReady() then
        if spells.E:GetToggleState() == 2 then
            for k, v in pairs(ObjManager.Get("all", "particles")) do
                if v.Name == "Lux_Base_E_tar_aoe_sound" and CountEnemiesInRange(v.Position,310) > 0 then
                    if   spells.E2:Cast() then return end
                end
            end
        end
    end
end
local function OnProcessSpell(sender,spell)
    local sh = Menu.Get("Misc.AutoW")
    if  not (sender.IsHero and sender.IsEnemy) or not sh then
        return 
    end
    local spellTarget = spell.Target
    if spellTarget and spellTarget.HealthPercent * 100 < Menu.Get("Misc.minHP") and spellTarget.IsAlly and spellTarget.IsHero and spells.W:IsInRange(spellTarget) and spells.W:IsReady() then
        spells.W:Cast(spell.Target)
	end
end
function Lux.Combo()  Lux.ComboLogic("Combo")  end
function LuxHP.Combo()
    local mode = "Combo"
    if Lux.IsEnabledAndReady("Q", mode) then
        local qChance = Menu.Get(mode .. ".ChanceQ")
        local Min = Menu.Get("Q.Min")
        local Max = Menu.Get("Q.Max")
        for k, qTarget in ipairs(Lux.GetTargets(spells.Q.Range)) do
            if qTarget:Distance(Player) > Min and qTarget:Distance(Player) < Max and spells.Q:CastOnHitChance(qTarget, qChance) then
                return
            end
        end
    end
    if Lux.IsEnabledAndReady("R", mode) then
        local rChance = Menu.Get(mode .. ".ChanceR")
        local Min = Menu.Get("R.Min")
        local Max = Menu.Get("R.Max")
        for k, rTarget in ipairs(Lux.GetTargets(spells.R.Range)) do
            local rDmg = DmgLib.CalculateMagicalDamage(Player, rTarget, Lux.GetRdmg())
            local ksHealth = spells.R:GetKillstealHealth(rTarget)
            if  rDmg > ksHealth and rTarget:Distance(Player) > Min and rTarget:Distance(Player) < Max and spells.R:CastOnHitChance(rTarget, rChance) then
                return
            end
        end
    end
end
function LuxHP.Harass()
    local mode = "Harass"
    local PM = Player.Mana / Player.MaxMana * 100
    if Lux.IsEnabledAndReady("Q", mode) then
        local qChance = Menu.Get(mode .. ".ChanceQ")
        local Min = Menu.Get("Q.Min")
        local Max = Menu.Get("Q.Max")
        local SettedMana = Menu.Get("Harass.ManaQ")
        if SettedMana > PM then 
            return 
            end
        for k, qTarget in ipairs(Lux.GetTargets(spells.Q.Range)) do
            if qTarget:Distance(Player) > Min and qTarget:Distance(Player) < Max and spells.Q:CastOnHitChance(qTarget, qChance) then
                return
            end
        end
    end
end
function Lux.Harass() Lux.HarassLogic("Harass") end
function Lux.Waveclear()
    local Q = Menu.Get("Lane.Q")
    local E = Menu.Get("Lane.E")
    local QJ = Menu.Get("Jungle.Q")
    local EJ = Menu.Get("Jungle.E")
        local pPos, pointsQ = Player.Position, {}
        local pointsE = {}
          for k, v in pairs(ObjManager.Get("enemy", "minions")) do
            local minion = v.AsAI
            if minion then
                if minion.IsTargetable and minion.MaxHealth > 6 and spells.Q:IsInRange(minion) then
                    local pos = minion:FastPrediction(Game.GetLatency()+spells.Q.Delay)
                    if pos:Distance(pPos) < spells.Q.Range and minion.IsTargetable then
                        insert(pointsQ, pos)
                    end 
                end 
            end                       
        end
    if Q and spells.Q:IsReady() and Menu.Get("Lane.Mana") < (Player.ManaPercent * 100) then 
        local bestPos, hitCount = spells.Q:GetBestLinearCastPos(pointsQ, spells.Q.Radius)
        if bestPos and hitCount > 1 then
            spells.Q:Cast(bestPos)
        end
    end
  
    for k, v in pairs(ObjManager.Get("enemy", "minions")) do
        local minion = v.AsAI
        if minion then
            if spells.E:GetToggleState() == 2 then
                for k, v in pairs(ObjManager.Get("all", "particles")) do
                    if v.Name == "Lux_Base_E_tar_aoe_sound" and v:Distance(minion) < spells.E.Radius then
                        if spells.E2:Cast() then return end
                    end
                end
            end
            if minion.IsTargetable and minion.MaxHealth > 6 and spells.E:IsInRange(minion) then
                local pos = minion:FastPrediction(Game.GetLatency()+spells.E.Delay)
                if  spells.E:GetToggleState() == 0 and pos:Distance(pPos) < spells.E.Range and minion.IsTargetable then
                    insert(pointsE, pos)
                end
            end 
        end                       
    end
    if E and spells.E:IsReady() and Menu.Get("Lane.Mana") < (Player.ManaPercent * 100) then 
        local bestPos, hitCount = spells.E:GetBestCircularCastPos(pointsE, spells.E.Radius)
        if bestPos and hitCount >= Menu.Get("Lane.EH") then
         spells.E:Cast(bestPos)
        end
    end
    if spells.Q:IsReady() and QJ then
        for k, v in pairs(ObjManager.Get("neutral", "minions")) do
            local minion = v.AsAI
            local minionInRange = spells.Q:IsInRange(minion)
            if minionInRange and minion.MaxHealth > 6 and minion.IsTargetable then
                if spells.Q:Cast(minion) then 
                    return
                end     
            end                  
        end
    end
    if spells.E:IsReady() and EJ then
        for k, v in pairs(ObjManager.Get("neutral", "minions")) do
            local minion = v.AsAI
            local minionInRange = spells.E:IsInRange(minion)
            if minionInRange and minion.MaxHealth > 6 and minion.IsTargetable then
                if spells.E:GetToggleState() == 0 and spells.E:Cast(minion) then 
                    return
                end  
                if spells.E:GetToggleState() == 2 then
                    for k, v in pairs(ObjManager.Get("all", "particles")) do
                        if v.Name == "Lux_Base_E_tar_aoe_sound" and v:Distance(minion) < spells.E.Radius then
                            if spells.E2:Cast() then return end
                        end
                    end
                end   
            end                  
        end
    end
end


function Lux.LoadMenu()
    Menu.RegisterMenu("StormLux", "Storm Lux", function()
        Menu.NewTree("Q", "[Q] Options", function()
            Menu.NewTree("ComboQ", "Combo Options", function()
                Menu.Checkbox("Combo.UseQ",   "Use [Q]", true) 
                Menu.Slider("Combo.ChanceQ", "HitChance [Q]", 0.7, 0, 1, 0.05)   
            end)
            Menu.NewTree("HarassQ", "Harass Options", function()
                Menu.Slider("Harass.ManaQ", "Mana Percent ", 50,0, 100)
                Menu.Checkbox("Harass.UseQ",   "Use [Q]", true) 
            Menu.Slider("Harass.ChanceQ", "HitChance [Q]", 0.7, 0, 1, 0.05)     
            end)  
            Menu.NewTree("MiscQ", "Misc Options", function()
                Menu.Checkbox("Misc.GapQ",   "Use [Q] on gapcloser", true) 
                Menu.Checkbox("Misc.IntQ", "Use [Q] on Interrupt",true)   
            end)
            Menu.NewTree("QRange", "[Q] Range Options", function()
                Menu.Slider("Q.Min",   "[Q] Min Range", 0,100,500) 
                Menu.Slider("Q.Max", "[Q] Max Range",1300,400,1300)   
            end)
            Menu.NewTree("DrawQ", "Draw Options", function()
                Menu.Checkbox("Drawing.Q.Enabled",   "Draw [Q] Range")
                 Menu.ColorPicker("Drawing.Q.Color", "Draw [Q] Color", 0x118AB2FF)       
            end)
        end)   
        Menu.NewTree("W", "[W] Options", function()
            Menu.NewTree("MiscW", "Misc Options", function()
                Menu.Checkbox("Misc.AutoW",   "Auto W to block Basic Attacks", true) 
                Menu.Slider("Misc.minHP", "Auto W When Hp <",80,0,100)   
            end)
            Menu.NewTree("DrawW", "Draw Options", function()
                Menu.Checkbox("Drawing.W.Enabled",   "Draw [W] Range")
                 Menu.ColorPicker("Drawing.W.Color", "Draw [W] Color", 0x118AB2FF)       
            end)
        end)   
        Menu.NewTree("E", "[E] Options", function()
            Menu.NewTree("ComboE", "Combo Options", function()
                Menu.Checkbox("Combo.UseE",   "Use [E]", true) 
                Menu.Slider("Combo.ChanceE", "HitChance [E]", 0.7, 0, 1, 0.05)   
            end)
            Menu.NewTree("HarassE", "Harass Options", function()
                Menu.Slider("Harass.ManaE", "Mana Percent ", 50,0, 100)
                Menu.Checkbox("Harass.UseE",   "Use [E]", true) 
            Menu.Slider("Harass.ChanceE", "HitChance [E]", 0.7, 0, 1, 0.05)     
            end)  
            Menu.NewTree("DrawE", "Draw Options", function()
                Menu.Checkbox("Drawing.E.Enabled",   "Draw [E] Range")
                 Menu.ColorPicker("Drawing.E.Color", "Draw [E] Color", 0x118AB2FF)       
            end)
        end)   
        Menu.NewTree("R", "[R] Options", function()
            Menu.NewTree("ComboR", "Combo Options", function()
                Menu.Checkbox("Combo.UseR",   "Use [R] When Killable", true) 
                Menu.Slider("Combo.ChanceR", "HitChance [R]", 0.9, 0, 1, 0.05)   
            end)
            Menu.NewTree("RRange", "[R] Range Options", function()
                Menu.Slider("R.Min",   "[R] Min Range", 0,100,1000) 
                Menu.Slider("R.Max", "[R] Max Range",3000,0,3400)   
            end)
            Menu.NewTree("MiscR", "Misc Options", function()
                Menu.Checkbox("Misc.AutoR",   "Auto R", true) 
                Menu.Slider("Misc.AutoRhit", "Auto R if hitcount =>",4,1,5)   
            end)
            Menu.NewTree("DrawR", "Draw Options", function()
                Menu.Checkbox("Drawing.R.Enabled",   "Draw [R] Range")
                 Menu.ColorPicker("Drawing.R.Color", "Draw [R] Color", 0x118AB2FF)       
            end)
        end)   
        Menu.NewTree("Wave", "WaveClear Options", function()
            Menu.NewTree("Lane", "Laneclear Options", function()
                Menu.Slider("Lane.Mana",   "Clear When Mana >", 50,0,100) 
                Menu.Checkbox("Lane.Q",   "Use Q", true) 
                Menu.Checkbox("Lane.E",   "Use E", true) 
                Menu.Slider("Lane.EH",   "E Hitcount", 2,1,5) 
            end)
            Menu.NewTree("Jungle", "Jungleclear Options", function()
                Menu.Checkbox("Jungle.Q",   "Use Q", true) 
                Menu.Checkbox("Jungle.E",   "Use E", true) 
            end)
        end)   
        Menu.NewTree("KS", "KillSteal Options", function()
            Menu.NewTree("KillSteal", "KillSteal Options", function()
                Menu.Checkbox("KS.Q",   "Use Q", true) 
                Menu.Checkbox("KS.E",   "Use E", true) 
                Menu.Checkbox("KS.R",   "Use R", true) 
            end)
        end)   
    end)     
end

function OnLoad()
    Lux.LoadMenu()
    for eventName, eventId in pairs(Enums.Events) do
        if Lux[eventName] then
            EventManager.RegisterCallback(eventId, Lux[eventName])
            EventManager.RegisterCallback(Enums.Events.OnProcessSpell, OnProcessSpell)
        end
    end    
    return true
end