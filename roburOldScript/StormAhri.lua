-- 🆂🆃🅾🆁🅼🅰🅸🅾 --
if Player.CharName ~= "Ahri" then return end
require("common.log")
module("Storm Ahri", package.seeall, log.setup)
clean.module("Storm Ahri", clean.seeall, log.setup)
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
local Ahri = {}
local AhriHP = {}
local AhriNP = {}

-- spells
local Q = Spell.Skillshot({
    Slot = Enums.SpellSlots.Q,
    Range = 900,
    Delay = 0.25,
    Radius = 100,
    Speed = 1550,
    Collisions = {WindWall=true},
    Key = "Q",
    Type = "Linear",
})
local W = Spell.Active({
    Slot = Enums.SpellSlots.W,
    Key = "W",
    Range = 725
})
local E = Spell.Skillshot({
    Slot = Enums.SpellSlots.E,
    Range =  1000,
    Radius = 60,
    Speed = 1550,
    Delay = 0.25,
    Collisions = {WindWall=true,Minions=true,heroes=true},
    Key = "E",
    Type = "Linear",
})
local R = Spell.Skillshot({
    Slot = Enums.SpellSlots.R,
    Delay = 0,
    Range = 450,
    Key = "R",
})

local function GameIsAvailable()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

local function dmg(spell)
    local dmg = 0
    if spell.Key == "Q" then
        dmg =  (40 + (spell:GetLevel() - 1) * 25) + (0.35 * Player.TotalAP)
    end
    if spell.Key == "E" then
        dmg =  (60 + (spell:GetLevel() - 1) * 30) + (0.4 * Player.TotalAP)
    end
    return dmg
end

function Ahri.OnHighPriority() 
    if not GameIsAvailable() then
        return
    end
    if Ahri.Auto() then return end
    local ModeToExecute = AhriHP[Orbwalker.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end

function Ahri.OnNormalPriority()
    if not GameIsAvailable() then
        return
    end
    local ModeToExecute = AhriNP[Orbwalker.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end


-- DRAW
function Ahri.OnDraw()
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

local function GetTargetsRange(Range)
    return {TS:GetTarget(Range,true)}
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

local function KS(spell)
    return Menu.Get("KS."..spell.Key) and spell:IsReady()
end

local function Jungle(spell)
    return Menu.Get("Jungle."..spell.Key) and spell:IsReady()
end



-- CALLBACKS
function Ahri.Auto()
    if KS(Q) then
        for k,v in pairs(GetTargets(Q)) do
            if v then
                local dmg = DmgLib.CalculateMagicalDamage(Player,v,dmg(Q))
                local Ks  = Q:GetKillstealHealth(v)
                if dmg > Ks and Q:CastOnHitChance(v,Enums.HitChance.High) then return end
            end
        end
    end
    if KS(E) then
        for k,v in pairs(GetTargets(E)) do
            if v then
                local dmg = DmgLib.CalculateMagicalDamage(Player,v,dmg(E))
                local Ks  = E:GetKillstealHealth(v)
                if dmg > Ks and E:CastOnHitChance(v,Enums.HitChance.High) then return end
            end
        end
    end
end

function Ahri.OnGapClose(Source, DashInstance)
    if not (Source.IsEnemy or E:IsReady() or Menu.Get("Misc.E") or Menu.Get(Source.AsHero.CharName)) then return end
    if E:CastOnHitChance(Source,Enums.HitChance.VeryHigh) then return end
end

function Ahri.OnInterruptibleSpell(source, spell, danger, endT, canMove)
    if not (source.IsEnemy and Menu.Get("Misc.EI") and E:IsReady() and danger > 2) then return end
    if E:CastOnHitChance(source,Enums.HitChance.VeryHigh) then return end
end


-- RECALLERS
function AhriHP.Combo()
    if CanCast(E,"Combo") then  
        for k,v in pairs(GetTargets(E)) do 
            if v:Distance(Player) > Menu.Get("Max.E") then return end
            if E:CastOnHitChance(v,HitChance(E)) then return end
        end
    end
    if CanCast(R,"Combo") then  
        for k,v in pairs(GetTargetsRange(R.Range * 2)) do 
            if v.HealthPercent * 100 > Menu.Get("RHP") then return end
            local CastPos = nil
            if Menu.Get("Rmode") == 0 then 
                CastPos = Player.Position:Extended(Renderer.GetMousePos(), R.Range)
            end
            if Menu.Get("Rmode") == 1 then 
                CastPos = Renderer.GetMousePos():Extended(v.Position, R.Range)
            end
            if R:Cast(CastPos) then return end
        end
    end
end
function AhriNP.Combo() 
    if CanCast(Q,"Combo") then  
        for k,v in pairs(GetTargets(Q)) do 
            if v:Distance(Player) > Menu.Get("Max.Q") then return end
            if Q:CastOnHitChance(v,HitChance(Q)) then return end
        end
    end
    if CanCast(W,"Combo") then  
        for k,v in pairs(GetTargets(W)) do 
            if W:Cast() then return end
        end
    end
end
function AhriHP.Harass()
    if Menu.Get("ManaSlider") > (Player.ManaPercent * 100) then return end
    if CanCast(E,"Harass") then  
        for k,v in pairs(GetTargets(E)) do 
            if v:Distance(Player) > Menu.Get("Max.E") then return end
            if E:CastOnHitChance(v,HitChance(E)) then return end
        end
    end
end
function AhriNP.Harass() 
    if Menu.Get("ManaSlider") > (Player.ManaPercent * 100) then return end
    if CanCast(Q,"Harass") then  
        for k,v in pairs(GetTargets(Q)) do 
            if v:Distance(Player) > Menu.Get("Max.Q") then return end
            if Q:CastOnHitChance(v,HitChance(Q)) then return end
        end
    end
    if CanCast(W,"Harass") then  
        for k,v in pairs(GetTargets(W)) do 
            if W:Cast() then return end
        end
    end
end

function AhriNP.Waveclear() 
    if Menu.Get("ManaSliderLane") < (Player.ManaPercent * 100) then 
        if Lane(Q) then
            local Qpoints = {}
            for k,v in pairs(ObjManager.Get("enemy", "minions")) do
            local minion = v.AsAI
            local minionInRange = Q:IsInRange(minion)
            local pos = minion:FastPrediction(Game.GetLatency()+ Q.Delay)
                if minionInRange and minion.IsTargetable and minion.MaxHealth > 6 then
                    insert(Qpoints, pos)
                end
            end
            local bestPos, hitCount = Q:GetBestLinearCastPos(Qpoints, Q.Radius)
            if bestPos and hitCount >= Menu.Get("Lane.QH") then
                Q:Cast(bestPos)
            end
        end
        if Lane(W) then 
            if Count(W,"enemy","minions") >= Menu.Get("Lane.WH") then 
                if W:Cast() then return end
            end
        end
    end
    if Jungle(E) then
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
    if Jungle(Q) then
        for k, v in pairs(ObjManager.Get("neutral", "minions")) do
        local minion = v.AsAI
        local minionInRange = E:IsInRange(minion)
            if minionInRange and minion.MaxHealth > 6  and minion.IsTargetable then
                if Q:Cast(minion) then
                    return
                end
            end
        end
    end
    if Jungle(W) then
        for k, v in pairs(ObjManager.Get("neutral", "minions")) do
        local minion = v.AsAI
        local minionInRange = W:IsInRange(minion)
            if minionInRange and minion.MaxHealth > 6  and minion.IsTargetable then
                if W:Cast() then
                    return
                end
            end
        end
    end
end


-- MENU
function Ahri.LoadMenu()
    Menu.RegisterMenu("StormAhri", "Storm Ahri", function()
        Menu.NewTree("Combo", "Combo Options", function()
            Menu.Checkbox("Combo.CastQ",   "Use [Q]", true)
            Menu.Checkbox("Combo.CastW",   "Use [W]", true)
            Menu.Checkbox("Combo.CastE",   "Use [E]", true)
            Menu.Checkbox("Combo.CastR",   "Use [R]", true)
            Menu.Dropdown("Rmode","R Mode",0 ,{"to Mouse","to target"})
            Menu.Slider("RHP","use R when target Hp <=",20,0,100)
        end)
        Menu.NewTree("Harass", "Harass Options", function()
            Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
            Menu.Slider("ManaSlider","",50,0,100)
            Menu.Checkbox("Harass.CastQ",   "Use [Q]", true)
            Menu.Checkbox("Harass.CastW",   "Use [W]", false)
            Menu.Checkbox("Harass.CastE",    "Use [E]", false)
        end)
        Menu.NewTree("WaveClear", "WaveClear Options", function()
            Menu.NewTree("Lane", "Lane", function()
                Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
                Menu.Slider("ManaSliderLane","",50,0,100)
                Menu.Checkbox("Lane.Q","Use [Q]", true)
                Menu.Slider("Lane.QH", "Q HitCount", 3,1,5)
                Menu.Checkbox("Lane.W","Use [W]", false)
                Menu.Slider("Lane.WH", "W if x minions in range", 2,1,5)
            end)
            Menu.NewTree("Jungle", "Jungle", function()
                Menu.Checkbox("Jungle.Q",   "Use [Q]", true)
                Menu.Checkbox("Jungle.W",   "Use [W]", true)
                Menu.Checkbox("Jungle.E",   "Use [E]", true)
            end)
        end)
        Menu.NewTree("Range", "Spell Range Options", function()
            Menu.Slider("Max.Q","[Q] Max Range", 900, 100, 900)
            Menu.Slider("Max.E","[E] Max Range", 1000, 100, 1000)
        end)
        Menu.NewTree("KS", "KillSteal Options", function()
            Menu.Checkbox("KS.Q"," Use [Q] to Ks", true)
            Menu.Checkbox("KS.E"," Use [E] to Ks", true)
        end)
        Menu.NewTree("Misc", "Misc Options", function()
            Menu.Checkbox("Misc.E",   "Use [E] on gapclose", true)
            Menu.NewTree("gapclose", "gapclose Whitelist", function()
                for _, Object in pairs(ObjManager.Get("enemy", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox(Name, "Use on " .. Name, true)
                end
            end)
            Menu.Checkbox("Misc.EI",   "Use [E] on Interrupter", true)
        end)
        Menu.NewTree("Prediction", "Prediction Options", function()
            Menu.Slider("Chance.Q","Q HitChance", 0.6, 0, 1, 0.05)
            Menu.Slider("Chance.E","E HitChance", 0.7, 0, 1, 0.05)
        end)
        Menu.NewTree("Draw", "Drawing Options", function()
            Menu.Checkbox("Drawing.Q.Enabled",   "Draw [Q] Range",true)
            Menu.ColorPicker("Drawing.Q.Color", "Draw [Q] Color", 0x118AB2FF)
            Menu.Checkbox("Drawing.W.Enabled",   "Draw [W] Range",true)
            Menu.ColorPicker("Drawing.W.Color", "Draw [W] Color", 0x118AB2FF)
            Menu.Checkbox("Drawing.E.Enabled",   "Draw [E] Range",false)
            Menu.ColorPicker("Drawing.E.Color", "Draw [E] Color", 0x118AB2FF)
            Menu.Checkbox("Drawing.R.Enabled",   "Draw [R] Range",true)
            Menu.ColorPicker("Drawing.R.Color", "Draw [R] Color", 0x118AB2FF)
        end)
    end)     
end


-- LOAD
function OnLoad()
    Ahri.LoadMenu()
    for eventName, eventId in pairs(Enums.Events) do
        if Ahri[eventName] then
            EventManager.RegisterCallback(eventId, Ahri[eventName])
        end
    end    
    return true
end