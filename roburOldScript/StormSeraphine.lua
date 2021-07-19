--[[
 _____ _                         _____                      _     _            
/  ___| |                       /  ___|                    | |   (_)           
\ `--.| |_ ___  _ __ _ __ ___   \ `--.  ___ _ __ __ _ _ __ | |__  _ _ __   ___ 
 `--. \ __/ _ \| '__| '_ ` _ \   `--. \/ _ \ '__/ _` | '_ \| '_ \| | '_ \ / _ \
/\__/ / || (_) | |  | | | | | | /\__/ /  __/ | | (_| | |_) | | | | | | | |  __/
\____/ \__\___/|_|  |_| |_| |_| \____/ \___|_|  \__,_| .__/|_| |_|_|_| |_|\___|
                                                     | |                       
                                                     |_|                                                                                                                                                    
]]
if Player.CharName ~= "Seraphine" then return end
--[[ require ]]
require("common.log")
module("Storm Seraphine", package.seeall, log.setup)
clean.module("Storm Seraphine", clean.seeall, log.setup)
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
local Pred        = _G.Libs.Prediction
local HealthPred  = _G.Libs.HealthPred
local DmgLib      = _G.Libs.DamageLib
local ImmobileLib = _G.Libs.ImmobileLib
local Spell       = _G.Libs.Spell
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
local Seraphine = {}
local SeraphineHP = {}
local SeraphineNP = {}
--[[Spells]] 
local Q = Spell.Skillshot({
    Slot = Enums.SpellSlots.Q,
    Range = 900,
    Radius = 350,
    Speed = 1200,
    Delay = 0.30,
    Type = "Circular",
    Collisions = {WindWall=true},
    Key = "Q",
})
local W = Spell.Active({
    Slot = Enums.SpellSlots.W,
    Range = 800,
    Delay = 0.25,
    Key = "W",
})
local E = Spell.Skillshot({
    Slot = Enums.SpellSlots.E,
    Range =  1300,
    Delay = 0.25,
    Speed = 1200,
    Radius = 70,
    Collisions = {WindWall=true},
    Type = "Linear",
    Key = "E"
})
local R = Spell.Skillshot({
    Slot = Enums.SpellSlots.R,
    Delay = 0.5,
    Radius = 160,
    Range = 1200,
    Speed = 1600,
    Collisions = {WindWall=true},
    Type = "Linear",
    Key = "R",
})
--[[Startup]] 
local function GameIsAvailable()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

function Seraphine.OnHighPriority() 
    if not GameIsAvailable() then
        return
    end
    if Seraphine.Auto() then return end
    local ModeToExecute = SeraphineHP[Orb.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end

function Seraphine.OnNormalPriority()
    if not GameIsAvailable() then
        return
    end
    local ModeToExecute = SeraphineNP[Orb.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end

--[[Draw]] 
function Seraphine.OnDraw()
    local Pos = Player.Position
    local spells = {Q,W,E,R}
    for k, v in pairs(spells) do
        if Menu.Get("Drawing."..v.Key..".Enabled", true) and v:IsReady() then
            Renderer.DrawCircle3D(Pos, v.Range, 30, 3, Menu.Get("Drawing."..v.Key..".Color"))
        end
    end
end

--[[Helper Functions]]
local function HasEcho()
    return Player:GetBuff("SeraphinePassiveEchoStage2")
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
        if hero and hero.IsTargetable and hero:Distance(pos.Position) < Range then
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
    local healthprec = 0
    if t ~= nil then 
        healthprec = (t.MaxHealth - t.Health) / t.MaxHealth
        if healthprec > 0.75 then 
            healthprec = 0.75 / 1.5
        end
    end
    local QMulitper = {0.4,0.45,0.5,0.55,0.6}
    if spell.Key == "Q" then 
        dmg = (55 + (Q:GetLevel() - 1) * 15) + (QMulitper[Q:GetLevel()] * Player.TotalAP)
        dmg = dmg + dmg * healthprec
    end
    if spell.Key == "E" then 
        dmg = (60 + (E:GetLevel() - 1) * 20) + (0.35 * Player.TotalAP)
    end
    if spell.Key == "R" then
        dmg = (150 + (R:GetLevel() - 1) * 50) + (0.6 * Player.TotalAP)
    end
    return dmg 
end

local function Passive()
    local AttackRange = Player.AttackRange - 525
    return AttackRange / 25
end

local function Passivedmg(t)
    local Mulit = 0.06 
    if Player.Level >= 6 and Player.Level <= 10 then 
        Mulit = 0.07
    end
    if Player.Level >= 11 and Player.Level <= 15 then 
        Mulit = 0.08
    end
    if Player.Level >= 16 then 
        Mulit = 0.09
    end
    local truedmg = 4.117 + 0.88 * Player.Level
    local Magicdmg = DmgLib.CalculateMagicalDamage(Player,t,Mulit * Player.TotalAP)
    local totaldmg = (truedmg + Magicdmg) * Passive()
    return totaldmg
end


local function TotalDmg(t)
    local Damage = DmgLib.CalculatePhysicalDamage(Player,t,Player.TotalAD)
    if Q:IsReady() then
        Damage = Damage + DmgLib.CalculateMagicalDamage(Player,t,dmg(Q,t))
    end
    if E:IsReady() then
        Damage = Damage + DmgLib.CalculateMagicalDamage(Player,t,dmg(E))
    end
    if R:IsReady() then
        Damage = Damage + DmgLib.CalculateMagicalDamage(Player,t,dmg(R))
    end
    Damage = Damage + Passivedmg(t)
    return Damage
end

--[[Events]]
function Seraphine.OnDrawDamage(target, dmgList)
    if Menu.Get("DrawDmg") then 
        table.insert(dmgList,TotalDmg(target))
    end
end
function Seraphine.Auto()
    if Menu.Get("Combo.RKey") then
        Orb.Orbwalk(Renderer.GetMousePos())
        for k, rTarget in pairs(GetTargets(R)) do
            if R:CastOnHitChance(rTarget, HitChance(R)) then
                return
            end
        end
    end 
    local Echo = 1
    if HasEcho() then 
        Echo = 2
    end
    if KS(Q) then
        for k,v in pairs(GetTargets(Q)) do 
            local dmg = DmgLib.CalculateMagicalDamage(Player,v,dmg(Q,v)) * Echo
            local Ks  = Q:GetKillstealHealth(v)
            if dmg > Ks and Q:CastOnHitChance(v,HitChance(Q)) then return end
        end
    end
    if KS(E) then
        for k,v in pairs(GetTargets(E)) do 
            local dmg = DmgLib.CalculateMagicalDamage(Player,v,dmg(E)) * Echo
            local Ks  = E:GetKillstealHealth(v)
            if dmg > Ks and E:CastOnHitChance(v,HitChance(E)) then return end
        end
    end
    if KS(R) then
        for k,v in pairs(GetTargets(R)) do 
            local dmg = DmgLib.CalculateMagicalDamage(Player,v,dmg(R))
            local Ks  = R:GetKillstealHealth(v)
            if dmg > Ks and R:CastOnHitChance(v,HitChance(R)) then return end
        end
    end
end

function Seraphine.OnInterruptibleSpell(source, spell, danger, endT, canMove)
    if source.IsEnemy and danger > 3 and R:IsReady() and Menu.Get("Misc.RI") then 
        if not Menu.Get("RI" .. source.AsHero.CharName) then return end
        if R:CastOnHitChance(source,Enums.HitChance.VeryHigh) then
            return 
        end
    end
    if source.IsEnemy and danger >= 1 and E:IsReady() and Menu.Get("Misc.EI") then 
        if not Menu.Get("EI" .. source.AsHero.CharName) then return end
        if E:CastOnHitChance(source,Enums.HitChance.VeryHigh) then
            return 
        end
    end
end

function Seraphine.OnGapclose(Source, DashInstance)
    if not (Source.IsEnemy) then return end
    if R:IsReady() and Menu.Get("Misc.R") then 
        if not Menu.Get("RG" .. Source.AsHero.CharName) then return end
        if R:CastOnHitChance(Source,Enums.HitChance.VeryHigh) then return end
    end
    if E:IsReady() and Menu.Get("Misc.R") then 
        if not Menu.Get("EG" .. Source.AsHero.CharName) then return end
        if E:CastOnHitChance(Source,Enums.HitChance.VeryHigh) then return end
    end
end

function Seraphine.OnProcessSpell(sender,spell)
    if not Menu.Get("Misc.Echo") and HasEcho() then return end
    if W:IsReady() then 
        if sender.IsTurret and spell.Target and  spell.Target.IsAlly and spell.Target.IsHero and W:IsInRange(spell.Target) and Menu.Get("Misc.W") then 
            if W:Cast() then return end
        end
        if (sender.IsHero and sender.IsEnemy) then
            local spellTarget = spell.Target
            if Menu.Get("Misc.WAA") then 
                if spellTarget and spellTarget.IsAlly and spellTarget.IsHero and W:IsInRange(spellTarget) and W:IsReady() then
                    if W:Cast() then return end
                end
            end
        end
    end
end

function Seraphine.OnBuffGain(obj,buffInst)
    if not obj.IsHero or not obj.IsEnemy or not Menu.Get("Misc.AutoE") or not E:IsReady() then return end
    if buffInst.BuffType == Enums.BuffTypes.Stun and buffInst.BuffType == Enums.BuffTypes.Snare or buffInst.BuffType == Enums.BuffTypes.Charm or buffInst.BuffType == Enums.BuffTypes.Suppression or buffInst.BuffType == Enums.BuffTypes.Grounded then 
        if E:CastOnHitChance(obj,Enums.HitChance.VeryHigh) then return end
    end
end

--[[Orbwalker Recallers]]
function SeraphineHP.Combo()
    local mode = "Combo"
    if CanCast(R,mode) then
        local points = {}
        for k, rTarget in ipairs(TS:GetTargets(Menu.Get("Max.R"), true)) do
            local pred = R:GetPrediction(rTarget)
            if pred and pred.HitChance >= HitChance(R) then
                table.insert(points, pred.CastPosition)
            end
        end
        local bestPos, hitCount = R:GetBestLinearCastPos(points)
        if hitCount >= Menu.Get("Combo.RH") then
            R:Cast(bestPos)
        end
    end
    if not HasEcho() then return end
    if CanCast(Q,mode) and Menu.Get("Combo.Echo") == 0 then
        for k,v in pairs(GetTargetsRange(Menu.Get("Max.Q"))) do 
            if Q:CastOnHitChance(v,HitChance(Q)) then return end
        end
    end
    if CanCast(E,mode) and Menu.Get("Combo.Echo") == 2 then
        for k,v in pairs(GetTargetsRange(Menu.Get("Max.E"))) do 
            if E:CastOnHitChance(v,HitChance(E)) then return end
        end
    end
end

function SeraphineNP.Combo()
    local mode = "Combo"
    if HasEcho() then return end
    if CanCast(Q,mode) then
        for k,v in pairs(GetTargetsRange(Menu.Get("Max.Q"))) do 
            if Q:CastOnHitChance(v,HitChance(Q)) then return end
        end
    end
    if CanCast(E,mode) then
        for k,v in pairs(GetTargetsRange(Menu.Get("Max.E"))) do 
            if E:CastOnHitChance(v,HitChance(E)) then return end
        end
    end
end

function SeraphineHP.Harass()
    local mode = "Harass"
    if Menu.Get("ManaSlider") > (Player.ManaPercent * 100) then return end
    if not HasEcho() then return end
    if CanCast(Q,mode) and Menu.Get("Harass.Echo") == 0 then
        for k,v in pairs(GetTargetsRange(Menu.Get("Max.Q"))) do 
            if Q:CastOnHitChance(v,HitChance(Q)) then return end
        end
    end
    if CanCast(E,mode) and Menu.Get("Harass.Echo") == 2 and not R:IsReady() then
        for k,v in pairs(GetTargetsRange(Menu.Get("Max.E"))) do 
            if E:CastOnHitChance(v,HitChance(E)) then return end
        end
    end
end

function SeraphineNP.Harass()
    local mode = "Harass"
    if Menu.Get("ManaSlider") > (Player.ManaPercent * 100) then return end
    if HasEcho() then return end
    if CanCast(Q,mode) then
        for k,v in pairs(GetTargetsRange(Menu.Get("Max.Q"))) do 
            if Q:CastOnHitChance(v,HitChance(Q)) then return end
        end
    end
    if CanCast(E,mode) then
        for k,v in pairs(GetTargetsRange(Menu.Get("Max.E"))) do 
            if E:CastOnHitChance(v,HitChance(E)) then return end
        end
    end
end

function SeraphineHP.Waveclear()
    if Menu.Get("ManaSliderLane") < Player.ManaPercent * 100 and HasEcho() then 
        if Lane(Q) and Menu.Get("Lane.Echo") == 0 then 
            local QPoint = {}
            for k, v in pairs(Obj.Get("enemy", "minions")) do
                if ValidAI(v,Q.Range) then
                    local minion = v.AsAI
                    local pos = minion:FastPrediction(Game.GetLatency()+ Q.Delay)
                    if pos:Distance(Player.Position) < Q.Range then
                        table.insert(QPoint, pos)
                    end
                end                       
            end
            local bestPos, hitCount = Q:GetBestCircularCastPos(QPoint, Q.Radius)
            if bestPos and hitCount >= Menu.Get("Lane.QH") then
                if Q:Cast(bestPos) then return end
            end
        end
        if Lane(E) and Menu.Get("Lane.Echo") == 1 then 
            local EPoint = {}
            for k, v in pairs(Obj.Get("enemy", "minions")) do
                if ValidAI(v,E.Range) then
                    local minion = v.AsAI
                    local pos = minion:FastPrediction(Game.GetLatency()+ E.Delay)
                    if pos:Distance(Player.Position) < E.Range then
                        table.insert(EPoint, pos)
                    end
                end                       
            end
            local bestPos, hitCount = E:GetBestCircularCastPos(EPoint, E.Radius)
            if bestPos and hitCount >= Menu.Get("Lane.EH") then
                if E:Cast(bestPos) then return end
            end
        end
    end
end

function SeraphineNP.Waveclear()
    if Menu.Get("ManaSliderLane") < Player.ManaPercent * 100 and not HasEcho() then 
        if Lane(Q) then 
            local QPoint = {}
            for k, v in pairs(Obj.Get("enemy", "minions")) do
                if ValidAI(v,Q.Range) then
                    local minion = v.AsAI
                    local pos = minion:FastPrediction(Game.GetLatency()+ Q.Delay)
                    if pos:Distance(Player.Position) < Q.Range then
                        table.insert(QPoint, pos)
                    end
                end                       
            end
            local bestPos, hitCount = Q:GetBestCircularCastPos(QPoint, Q.Radius)
            if bestPos and hitCount >= Menu.Get("Lane.QH") then
                if Q:Cast(bestPos) then return end
            end
        end
        if Lane(E) then 
            local EPoint = {}
            for k, v in pairs(Obj.Get("enemy", "minions")) do
                if ValidAI(v,E.Range) then
                    local minion = v.AsAI
                    local pos = minion:FastPrediction(Game.GetLatency()+ E.Delay)
                    if pos:Distance(Player.Position) < E.Range then
                        table.insert(EPoint, pos)
                    end
                end                       
            end
            local bestPos, hitCount = E:GetBestCircularCastPos(EPoint, E.Radius)
            if bestPos and hitCount >= Menu.Get("Lane.EH") then
                if E:Cast(bestPos) then return end
            end
        end
    end
    if Jungle(Q) then 
        for k,v in pairs(Obj.Get("neutral","minions")) do
            if ValidAI(v,Q.Range) then  
                if Q:Cast(v.Position) then return end
            end
        end
   end
    if Jungle(E) then 
         for k,v in pairs(Obj.Get("neutral","minions")) do
             if ValidAI(v,E.Range) then  
                 if E:Cast(v.Position) then return end
             end
         end
    end
end

function SeraphineNP.Flee()
    if Flee(W) then
        if W:Cast() then return end
    end
end

--[[Menu]]
function Seraphine.LoadMenu()
    Menu.RegisterMenu("StormSeraphine", "Storm Seraphine", function()
        Menu.NewTree("Combo", "Combo Options", function()
            Menu.Checkbox("Combo.CastQ",   "Use [Q]", true)
            Menu.Checkbox("Combo.CastE",   "Use [E]", true)
            Menu.Dropdown("Combo.Echo","Double Cast",2,{"Q", "W", "E"})
            Menu.Checkbox("Combo.CastR",   "Use [R]", true)
            Menu.Slider("Combo.RH","R HitCount",2,1,5)
            Menu.Keybind("Combo.RKey", "Simi [R] Key", string.byte('T'))
        end)
        Menu.NewTree("Harass", "Harass Options", function()
            Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
            Menu.Slider("ManaSlider","",50,0,100)
            Menu.Checkbox("Harass.CastQ",   "Use [Q]", true)
            Menu.Checkbox("Harass.CastE",   "Use [E]", true)
            Menu.Dropdown("Harass.Echo","Double Cast",0,{"Q", "W", "E"})
        end)
        Menu.NewTree("Waveclear", "Waveclear Options", function()
            Menu.NewTree("Lane", "Lane Options", function() 
                Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
                Menu.Slider("ManaSliderLane","",50,0,100)
                Menu.Dropdown("Lane.Echo","Double Cast",0,{"Q", "E"})
                Menu.Checkbox("Lane.Q",   "Use [Q]", true)
                Menu.Slider("Lane.QH","Q HitCount",3,1,5)
                Menu.Checkbox("Lane.E",   "Use [E]", true)
                Menu.Slider("Lane.EH","E HitCount",3,1,5)
            end)
            Menu.NewTree("Jungle", "Jungle Options", function() 
                Menu.Checkbox("Jungle.Q",   "Use [Q]", true)
                Menu.Checkbox("Jungle.E",   "Use [E]", true)
            end)
        end)
        Menu.NewTree("Range", "Spell Range Options", function()
            Menu.Slider("Max.Q","[Q] Max Range", 800, 600, 900)
            Menu.Slider("Max.E","[E] Max Range", 1050, 700, 1300)
            Menu.Slider("Max.R","[R] Max Range", 1050, 650, 1200)
        end)
        Menu.NewTree("Prediction", "Prediction Options", function()
            Menu.Slider("Chance.Q","HitChance [Q]",0.75, 0, 1, 0.05)
            Menu.Slider("Chance.E","HitChance [E]",0.85, 0, 1, 0.05)
            Menu.Slider("Chance.R","HitChance [R]",0.75, 0, 1, 0.05)
        end)
        Menu.NewTree("KillSteal", "KillSteal Options", function()
            Menu.Checkbox("KS.Q"," Use Q", true)
            Menu.Checkbox("KS.E"," Use E", true)
            Menu.Checkbox("KS.R"," Use R", false)
        end)
        Menu.NewTree("Flee", "Flee Options", function()
            Menu.Checkbox("Flee.W"," Use W ", false)
        end)
        Menu.NewTree("Misc", "Misc Options", function()
            Menu.Checkbox("Misc.W",   "Auto W on Tower Shots", true)
            Menu.Checkbox("Misc.AutoE",   "Auto E Targets with Debuffs", true)
            Menu.Checkbox("Misc.WAA",   "Auto W on Attacks", true)
            Menu.Checkbox("Misc.Echo",   "Use ^ Echo (double Cast)", false)
            Menu.Checkbox("Misc.EI",   "Use [E] on Interrupter ", true)
            Menu.NewTree("EInterrupter", "Interrupter E Whitelist", function()
                for _, Object in pairs(Obj.Get("enemy", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox("EI" .. Name, "Use on " .. Name, true)
                end
            end)
            Menu.Checkbox("Misc.RI",   "Use [R] on Interrupter", true)
            Menu.NewTree("RInterrupter", "Interrupter R Whitelist", function()
                for _, Object in pairs(Obj.Get("enemy", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox("RI" .. Name, "Use on " .. Name, false)
                end
            end)
            Menu.Checkbox("Misc.E",   "Use [E] on gapclose", true)
            Menu.NewTree("Egapclose", "gapclose E Whitelist", function()
                for _, Object in pairs(Obj.Get("enemy", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox("EG" .. Name, "Use on " .. Name, true)
                end
            end)
            Menu.Checkbox("Misc.R",   "Use [R] on gapclose", true)
            Menu.NewTree("Rgapclose", "gapclose R Whitelist", function()
                for _, Object in pairs(Obj.Get("enemy", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox("RG" .. Name, "Use on " .. Name, false)
                end
            end)
        end)
        Menu.NewTree("Draw", "Drawing Options", function()
            Menu.Checkbox("Drawing.Q.Enabled",   "Draw [Q] Range",true)
            Menu.ColorPicker("Drawing.Q.Color", "Draw [Q] Color", 0x118AB2FF)
            Menu.Checkbox("Drawing.W.Enabled",   "Draw [W] Range",false)
            Menu.ColorPicker("Drawing.W.Color", "Draw [W] Color", 0x118AB2FF)
            Menu.Checkbox("Drawing.E.Enabled",   "Draw [E] Range",true)
            Menu.ColorPicker("Drawing.E.Color", "Draw [E] Color", 0x118AB2FF)
            Menu.Checkbox("Drawing.R.Enabled",   "Draw [R] Range",true)
            Menu.ColorPicker("Drawing.R.Color", "Draw [R] Color", 0x118AB2FF)
            Menu.Checkbox("DrawDmg",   "Draw Total Dmg",true)
        end)
    end)     
end

-- LOAD
function OnLoad()
    Seraphine.LoadMenu()
    for eventName, eventId in pairs(Enums.Events) do
        if Seraphine[eventName] then
            Event.RegisterCallback(eventId, Seraphine[eventName])
        end
    end    
    return true
end