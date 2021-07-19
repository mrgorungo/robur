-- 🆂🆃🅾🆁🅼🅰🅸🅾 --
if Player.CharName ~= "Lulu" then return end
require("common.log")
module("Storm Lulu", package.seeall, log.setup)
clean.module("Storm Lulu", clean.seeall, log.setup)
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

---@type TargetSelector
local TS = _G.Libs.TargetSelector()
local List = {"Varus","Aphelios","Xayah","Lucian","Draven","Vayne","MissFortune","Sivir","Tristana","Jinx","Ezreal","KogMaw","Jhin","Senna","Twitch","Samira","Kaisa","Caitlyn","Kindred","Kalista","Ashe"}

--recaller
local Lulu = {}
local LuluHP = {}
local pix = nil

--spells
local Q = Spell.Skillshot({
    Slot = Enums.SpellSlots.Q,
    Range = 925, 
    Delay = 0.25,
    Speed = 1500,
    Radius = 60,
    Type = "Linear",
    Key = "Q"
})
local Q2 = Spell.Skillshot({
    Slot = Enums.SpellSlots.Q,
    Range = 925, 
    Delay = 0.25,
    Speed = 1500,
    Radius = 60,
    Type = "Linear",
    Key = "Q"
})
local W = Spell.Targeted({
        Slot = Enums.SpellSlots.W,
        Range = 650,
        Delay = 0,
        Key = "W"
})
local E = Spell.Targeted({
        Slot = Enums.SpellSlots.E,
        Range = 650,
        Delay = 0,
        Key = "E"
})
local R = Spell.Targeted({
        Slot = Enums.SpellSlots.R,
        Range = 900,
        Key = "R"
})

local function GameIsAvailable()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

function Lulu.OnHighPriority() 
    if not GameIsAvailable() then
        return
    end
    if Lulu.Auto() then return end
    local ModeToExecute = LuluHP[Orb.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end

function Lulu.OnNormalPriority()
    if not GameIsAvailable() then
        return
    end
    local ModeToExecute = Lulu[Orb.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end

-- draw
function Lulu.OnDraw()   
    if Menu.Get("Drawing.pix.Enabled") then  
        if pix then 
            Renderer.DrawCircle3D(pix.Position, 50, 30, 4, 0x118AB2FF)
        end
    end
    if Menu.Get("Drawing.Q2.Enabled") then 
        if pix then 
            Renderer.DrawCircle3D(pix.Position, Q2.Range, 30, 4, Menu.Get("Drawing.Q2.Color"))
        end
    end
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

local function Flee(spell)
    return Menu.Get("Flee."..spell.Key) and spell:IsReady()
end

local function ValidAI(minion,Range)
    local AI = minion.AsAI
    return AI.IsTargetable and AI.MaxHealth > 6 and AI:Distance(Player) < Range
end

local function Lane(spell)
    return spell:IsReady() and Menu.Get("Lane."..spell.Key)
end

local function Jungle(spell)
    return spell:IsReady() and Menu.Get("Jungle."..spell.Key)
end

local function HitChance(spell)
    return Menu.Get("Chance."..spell.Key)
end

local function GetTargets(Spell)
    return {TS:GetTarget(Spell.Range,true)}
end

local function GetTargetsRange(Range)
    return {TS:GetTarget(Range,true)}
end

local function AlliesTable(Range)
    local allies = {}
    for k, v in pairs(Obj.Get("ally", "heroes")) do
        local hero = v.AsHero
        local Tar  = hero:Distance(Player) < Range and hero.IsTargetable and Menu.Get("item." .. hero.CharName)
        if Tar then
           table.insert(allies,v.AsHero)
        end
    end
    return allies
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

function Lulu.findPix()
    for k, v in pairs(Obj.Get("ally", "minions")) do
        if v.Name == "RobotBuddy" and not v.IsDead then 
            pix = v
        end
    end
end

--mode functions
function Lulu.ComboLogic(mode) 
    if CanCast(W,mode) then
        for k, wTarget in pairs(GetTargets(W)) do
            if not Menu.Get("CW" .. wTarget.CharName) then return end
            if W:Cast(wTarget) then
                return
            end
        end
    end
    if CanCast(E,mode) then
        for k, eTarget in pairs(GetTargets(E)) do
            if not Menu.Get("CE" .. eTarget.CharName) then return end
            if E:Cast(eTarget) then
                return
            end
        end
    end
end

function Lulu.HarassLogic(mode)
    if Menu.Get("ManaSlider") > Player.ManaPercent * 100 then return end
    if CanCast(W,mode) then
        for k, wTarget in pairs(GetTargets(W)) do
            if not Menu.Get("HW" .. wTarget.CharName) then return end
            if W:Cast(wTarget) then
                return
            end
        end
    end
    if CanCast(E,mode) then
        for k, eTarget in pairs(GetTargets(E)) do
            if not Menu.Get("HE" .. eTarget.CharName) then return end
            if E:Cast(eTarget) then
                return
            end
        end
    end
end

-- CALLBACKS
function Lulu.OnProcessSpell(sender,spell)
    if sender.IsEnemy and sender.IsTurret and spell.Target and spell.Target.IsAlly and spell.Target.IsHero and E:IsInRange(spell.Target) and Menu.Get("Misc.E") then 
        return E:Cast(spell.Target)
    end
    if (sender.IsHero and sender.IsEnemy) then
        local spellTarget = spell.Target
        if Menu.Get("Misc.AE") then 
            if spellTarget and spellTarget.IsAlly and spellTarget.IsHero and E:IsInRange(spellTarget) and E:IsReady() then
                return E:Cast(spell.Target)
            end
        end
        if spell.Slot > 3 or not Menu.Get("Misc.AES") then return end
        for k,v in pairs(Obj.Get("ally", "heroes")) do
            local Hero = v.AsHero
            if E:IsInRange(Hero) then
                if Hero:Distance(spell.EndPos) < Hero.BoundingRadius * 1 then
                    return E:Cast(Hero)
                end
            end
        end
    end
    if (sender.IsHero and sender.IsAlly and Menu.Get("Misc.AEB")) then
        local spellTarget = spell.Target
        local Hero = sender.AsHero
        if not Menu.Get("Boost" .. Hero.CharName) then return end
        if spellTarget and spellTarget.IsEnemy and spellTarget.IsHero and E:IsInRange(Hero) and E:IsReady() then
            return E:Cast(Hero)
        end
        if spellTarget and spellTarget.IsEnemy and spellTarget.IsHero and W:IsInRange(Hero) and W:IsReady() then
            return W:Cast(Hero)
        end
    end
end

function Lulu.OnInterruptibleSpell(source, spell, danger, endT, canMove)
    if not (source.IsEnemy and danger > 2) then return end
    if W:IsInRange(source) and W:IsReady() and Menu.Get("Misc.IntW") then
        return W:Cast(source) 
    end
    if R:IsReady() and Menu.Get("Misc.IntR") and Menu.Get("RI" .. source.AsHero.CharName)then
        for k,v in pairs(AlliesTable(R.Range)) do 
            if Menu.Get("R" .. v.CharName) and v:Distance(source) <= 350 then 
                return R:Cast(v) 
            end
        end
    end
end

function Lulu.OnGapclose(source, dash)
    if not (source.IsEnemy and Menu.Get("Misc.GapW") and W:IsReady()) then return end
    if W:IsInRange(source) then
        W:Cast(source) return
    end
end

function Lulu.Auto() 
    if Menu.Get("Boost.Key") then
        Orb.Orbwalk(Renderer.GetMousePos(),Orb:GetTarget())
        local heroes = {}
        for k, v in pairs(Obj.Get("ally","heroes")) do
            if Menu.Get("BoostList" .. v.AsHero.CharName) then 
                table.insert(heroes, v.AsHero)
            end
        end
        table.sort(heroes, function(a, b) return Menu.Get(a.CharName) > Menu.Get(b.CharName) end)
        for k, hero in ipairs(heroes) do
            if E:IsReady() and E:IsInRange(hero) then 
                return E:Cast(hero) 
            end
            if W:IsReady() and W:IsInRange(hero) then 
                return W:Cast(hero) 
            end
        end
    end 
    if R:IsReady() and Menu.Get("CastR") then
        for k, v in pairs(Obj.Get("ally","heroes")) do
            local hero = v.AsHero
            if R:IsInRange(hero) and hero.IsTargetable and Menu.Get("R" .. hero.CharName) and not hero.IsRecalling then
                local delay =  0.10 + Game.GetLatency()/1000
                local predDmg = HealthPred.GetDamagePrediction(hero, delay, false) 
                local predHealth = (hero.Health - predDmg) / hero.MaxHealth
                local minHealth = Menu.Get("UseRh") / 100
                if predHealth < minHealth and (predDmg > 0 or CountHeroes(hero,1000,"enemy") > 0) then                
                    return R:Cast(hero) 
                end
            end
        end
    end

    if R:IsReady() and Menu.Get("CastR") then
        for k, v in pairs(Obj.Get("ally","heroes")) do
            local hero = v.AsHero
            if R:IsInRange(hero) and hero.IsTargetable and Menu.Get("R" .. hero.CharName) and not hero.IsRecalling and CountHeroes(hero,350,"enemy") >= Menu.Get("RH") then
                if R:Cast(hero) then return end
            end
        end
    end
end   

-- Orbwalker RECALLER
function Lulu.Combo()  Lulu.ComboLogic("Combo")  end
function LuluHP.Combo() 
    local mode = "Combo"
    if CanCast(Q,mode) then
        for k, qTarget in pairs(GetTargetsRange(Menu.Get("Max.Q"))) do
            if Q:CastOnHitChance(qTarget,HitChance(Q)) then
                return
            end
        end
    end
    if CanCast(Q,mode) then 
        for k, qTarget in pairs({TS:GetTarget(Menu.Get("Max.Q2") + Player:Distance(pix),true)}) do
            local qPred = Pred.GetPredictedPosition(qTarget, Q2, pix.Position)
            if qPred and qPred.HitChance >= HitChance(Q) then
                Q2:Cast(qPred.CastPosition)
            end
        end
    end
end

function LuluHP.Harass() 
    if Menu.Get("ManaSlider") > Player.ManaPercent * 100 then return end
    local mode = "Harass"
    if CanCast(Q,mode) then
        for k, qTarget in pairs(GetTargetsRange(Menu.Get("Max.Q"))) do
            if Q:CastOnHitChance(qTarget,HitChance(Q2)) then
                return
            end
        end
    end
    if CanCast(Q,mode) then 
        for k, qTarget in pairs({TS:GetTarget(Menu.Get("Max.Q2") + Player:Distance(pix),true)}) do
            local qPred = Pred.GetPredictedPosition(qTarget, Q2, pix.Position)
            if qPred and qPred.HitChance >= HitChance(Q2) then
                Q2:Cast(qPred.CastPosition)
            end
        end
    end
end
function LuluHP.Waveclear()
    if Menu.Get("ManaSliderLane") < Player.ManaPercent * 100 then 
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
            local bestPos, hitCount = Q:GetBestLinearCastPos(QPoint, Q.Radius)
            if bestPos and hitCount >= Menu.Get("Lane.QH") then
                if Q:Cast(bestPos) then return end
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
                 if E:Cast(v) then return end
             end
         end
    end
end

function Lulu.Flee()
    if Flee(W) then
        if W:Cast(Player) then return end
    end
end

function Lulu.Harass() Lulu.HarassLogic("Harass") end


-- Menu
function Lulu.LoadMenu()
    Menu.RegisterMenu("StormLulu", "Storm Lulu", function()
        Menu.NewTree("Combo", "Combo Options", function()
            Menu.Checkbox("Combo.CastQ",   "Use [Q]", true)
            Menu.Checkbox("Combo.CastW",   "Use [W]", false)
            Menu.NewTree("Wlist","W Whitelist", function()
                Menu.ColoredText("W Whitelist", 0xFFD700FF, true)
                for k, v in pairs(Obj.Get("enemy", "heroes")) do
                    local Name = v.AsHero.CharName
                    Menu.Checkbox("CW" .. Name, "Use on " .. Name, true)
                end
            end)
            Menu.Checkbox("Combo.CastE",   "Use [E]", true)
            Menu.NewTree("Elist","E Whitelist", function()
                Menu.ColoredText("E Whitelist", 0xFFD700FF, true)
                for k, v in pairs(Obj.Get("enemy", "heroes")) do
                    local Name = v.AsHero.CharName
                    Menu.Checkbox("CE" .. Name, "Use on " .. Name, true)
                end
            end)
        end)
        Menu.NewTree("Rs", "R Options", function()
            Menu.Checkbox("CastR",   "Auto [R]", true)
            Menu.Slider("UseRh", " R when ally x < ", 20, 0, 100)
            Menu.Slider("RH", "Auto R to knockup =>", 2, 1, 5)
            Menu.NewTree("Rlist","R Whitelist", function()
                for k, v in pairs(Obj.Get("ally", "heroes")) do
                    local Name = v.AsHero.CharName
                    local result = false
                    for k, list in pairs(List) do
                        if list == v.CharName or v.IsMe then result = true end
                    end
                    Menu.Checkbox("R" .. Name, "Use on " .. Name, result)
                end
            end)
        end)
        Menu.NewTree("Harass", "Harass Options", function()
            Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
            Menu.Slider("ManaSlider","",50,0,100)
            Menu.Checkbox("Harass.CastQ",   "Use [Q]", true)
            Menu.Checkbox("Harass.CastW",   "Use [W]", false)
            Menu.NewTree("HWlist","W Whitelist", function()
                Menu.ColoredText("W Whitelist", 0xFFD700FF, true)
                for k, v in pairs(Obj.Get("enemy", "heroes")) do
                    local Name = v.AsHero.CharName
                    Menu.Checkbox("HW" .. Name, "Use on " .. Name, true)
                end
            end)
            Menu.Checkbox("Harass.CastE",   "Use [E]", true)
            Menu.NewTree("HElist","E Whitelist", function()
                Menu.ColoredText("E Whitelist", 0xFFD700FF, true)
                for k, v in pairs(Obj.Get("enemy", "heroes")) do
                    local Name = v.AsHero.CharName
                    Menu.Checkbox("HE" .. Name, "Use on " .. Name, true)
                end
            end)
        end)
        Menu.NewTree("Waveclear", "Waveclear Options", function()
            Menu.NewTree("Lane", "Lane Options", function() 
                Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
                Menu.Slider("ManaSliderLane","",50,0,100)
                Menu.Checkbox("Lane.Q",   "Use [Q]", false)
                Menu.Slider("Lane.QH","Q HitCount",3,1,5)
            end)
            Menu.NewTree("Jungle", "Jungle Options", function() 
                Menu.Checkbox("Jungle.Q",   "Use [Q]", false)
                Menu.Checkbox("Jungle.E",   "Use [E]", false)
            end)
        end)
        Menu.NewTree("priority", "priority Options", function()
            Menu.ColoredText("priority", 0xFFD700FF, true)
            for k, v in pairs(Obj.Get("ally", "heroes")) do
                local Name = v.AsHero.CharName
                local result = 1
                for k , list in pairs(List) do
                    if list == v.CharName then result = 5 end
                end
                Menu.Slider(Name, Name, result,1,5)
                Menu.Checkbox("BoostList" .. Name, Name,true)
            end
            Menu.Keybind("Boost.Key", "Simi [W,E] Key", string.byte('G')) 
        end)
        Menu.NewTree("Range", "Spell Range Options", function()
            Menu.Slider("Max.Q","[Q] Max Range", 900, 500, 925)
            Menu.Slider("Max.Q2","[Q] Extened Max Range",875, 500, 925)
        end)
        Menu.NewTree("Prediction", "Prediction Options", function()
            Menu.Slider("Chance.Q","HitChance [Q]",0.7, 0, 1, 0.05)
            Menu.Slider("Chance.Q2","HitChance [Q] Extended",0.75, 0, 1, 0.05)
        end)
        Menu.NewTree("Flee", "Flee Options", function()
            Menu.Checkbox("Flee.W","Use [W]",true)
        end)
        Menu.NewTree("Misc", "Misc Options", function()
            Menu.Checkbox("Misc.E",   "Auto E on Tower Shots || OnSelf and Allies", true)
            Menu.Checkbox("Misc.GapW", "Use [W] on Gapcloser", true) 
            Menu.Checkbox("Misc.IntW", "Use [W] on Interrupt", true) 
            Menu.Checkbox("Misc.IntR", "Use [R] on Interrupt", true) 
            Menu.NewTree("IntR", "R to Interrupt Whitelist", function()
                for k,v in pairs(Obj.Get("enemy", "heroes")) do
                    local Name = v.AsHero.CharName
                    Menu.Checkbox("RI" .. Name, "Use on " .. Name, false)
                end
            end)
            Menu.Checkbox("Misc.AE",  "Auto Shield allies on attack", true) 
            Menu.Checkbox("Misc.AES", "Auto Shield allies on Spell Attack", true) 
            Menu.Checkbox("Misc.AEB", "Auto Boost allies on Ally Attack", true)
            Menu.NewTree("AutoBoost", "Auto Boost Whitelist", function()
                for k,v in pairs(Obj.Get("ally", "heroes")) do
                    local Name = v.AsHero.CharName
                    local result = false
                    for k, list in pairs(List) do
                        if list == v.CharName then result = true end
                    end
                    Menu.Checkbox("Boost" .. Name, "Use on " .. Name, result)
                end
            end)
        end)
        Menu.NewTree("Draw", "Drawing Options", function()
            Menu.Checkbox("Drawing.pix.Enabled",   "Draw around [pix]",true)
            Menu.Checkbox("Drawing.Q.Enabled",   "Draw [Q] Range",true)
            Menu.ColorPicker("Drawing.Q.Color", "Draw [Q] Color", 0x118AB2FF)
            Menu.Checkbox("Drawing.Q2.Enabled",   "Draw [Q] Range From Pix Postion",false)
            Menu.ColorPicker("Drawing.Q2.Color", "Draw [Q]  From Pix Postion Color", 0x145AB2FF)
            Menu.Checkbox("Drawing.E.Enabled",   "Draw [E] Range",false)
            Menu.ColorPicker("Drawing.E.Color", "Draw [E] Color", 0x118AB2FF)
            Menu.Checkbox("Drawing.R.Enabled",   "Draw [R] Range",true)
            Menu.ColorPicker("Drawing.R.Color", "Draw [R] Color", 0x118AB2FF)
        end)
    end)     
end

function OnLoad()
    Lulu.LoadMenu()
    Lulu.findPix()
    for eventName, eventId in pairs(Enums.Events) do
        if Lulu[eventName] then
            Event.RegisterCallback(eventId, Lulu[eventName])
        end
    end    
    return true
end