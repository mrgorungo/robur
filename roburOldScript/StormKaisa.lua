-- 🆂🆃🅾🆁🅼🅰🅸🅾 --
if Player.CharName ~= "Kaisa" then return end
--[[ require ]]
require("common.log")
module("Storm Kaisa", package.seeall, log.setup)
clean.module("Storm Kaisa", clean.seeall, log.setup)
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
-- recaller
local Kaisa = {}
local KaisaNP = {}
local hailofblades = "ASSETS/Perks/Styles/Domination/HailOfBlades/HailOfBladesBuff.Lua"
local LethalTempo = "ASSETS/Perks/Styles/Precision/LethalTempo/LethalTempoEmpowered.lua"
-- spells
local Q = Spell.Active({
    Slot = Enums.SpellSlots.Q,
    Range = 600,
    Delay = 0.25,
    Key = "Q"
})
local W = Spell.Skillshot({
    Slot = Enums.SpellSlots.W,
    Range = 3000,
    Delay = 0.40,
    Speed = 1750,
    Radius = 100,
    Type = "Linear",
    Collisions = {WindWall=true,Minions=true,heroes=true},
    UseHitbox = true,
    Key = "W"
})
local E = Spell.Active({
    Slot = Enums.SpellSlots.E,
    Range = 1000,
    Key = "E"
})
local R = Spell.Targeted({
    Slot = Enums.SpellSlots.R,
    Range = 1500,
    Delay = 0.35,
    Key = "R",
})

local function GameIsAvailable()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

-- PASSIVE
local function PASSIVECOUNT(target)
    if target:GetBuff("kaisapassivemarker") then
        return target:GetBuff("kaisapassivemarker").Count
    end
end

function Kaisa.OnHighPriority() 
    if not GameIsAvailable() then
        return
    end
    if Kaisa.Auto() then return end
    local ModeToExecute = Kaisa[Orb.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end

function Kaisa.OnNormalPriority()
    if not GameIsAvailable() then
        return
    end
    local ModeToExecute = KaisaNP[Orb.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end


-- DRAW
function Kaisa.OnDraw()
    local Pos = Player.Position
    local spells = {Q,W,R}
    for k, v in pairs(spells) do
        if Menu.Get("Drawing."..v.Key..".Enabled", true) and v:IsReady() then
            Renderer.DrawCircle3D(Pos, v.Range, 30, 3, Menu.Get("Drawing."..v.Key..".Color"))
        end
    end
    if Menu.Get("Map.R.Enabled") and R:IsReady() then
        local Range = R.Range + (R:GetLevel() -1 )  * 750
        Renderer.DrawCircleMM(Player.Position, Range, 2, Menu.Get("Drawing.R.Color"))
    end
    if Menu.Get("Map.W.Enabled") and W:IsReady() then
        local Range = W.Range
        Renderer.DrawCircleMM(Player.Position, Range, 2, Menu.Get("Drawing.W.Color"))
    end
end

-- SPELLDMG
local function dmg(spell,target)
    local missinghp = target.MaxHealth - target.Health
    if spell.Key == "W" then
        local dmg =  (30 + (spell:GetLevel() - 1) * 25) + (1.3 * Player.TotalAD) + (0.7 * Player.TotalAP)
        if PASSIVECOUNT(target) and PASSIVECOUNT(target) > 2 then
            dmg = dmg + missinghp *  (0.15 + 0.0375 * Player.TotalAP / 100)
        end
        return dmg
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
    for k, v in pairs(Obj.Get(team, type)) do
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
    for k, v in pairs(Obj.Get(type, "heroes")) do
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
function Kaisa.ComboLogic(mode)
    local Ma = Menu.Get("Max.W")
    local Mi = Menu.Get("Min.W")
    if CanCast(Q,mode) then
        for k,v in pairs(GetTargets(Q)) do
            if v and Count(Q,"enemy","minions") < 4 then
                if Q:Cast() then return end
            end
        end
    end
    if CanCast(W,mode) and Menu.Get("wmodec") == 2 then
        for k,wtarget in pairs(GetTargets(W)) do
            if wtarget and wtarget:Distance(Player) < Ma and Player:Distance(wtarget) > Mi and W:CastOnHitChance(wtarget,HitChance(W)) then
                return
            end
        end
    end
    if CanCast(W,mode) and Menu.Get("wmodec") == 1 then
        for k,wtarget in pairs(GetTargets(W)) do
            if wtarget and PASSIVECOUNT(wtarget) and PASSIVECOUNT(wtarget) > Menu.Get("wc") and W:CastOnHitChance(wtarget,HitChance(W)) then
                return
            end
        end
    end
    if CanCast(E,mode) and Menu.Get("emode") == 1 then
        if Menu.Get("Misc.BlockE") and (Player:GetBuff(hailofblades) or Player:GetBuff(LethalTempo)) then return end
        for k,etarget in pairs(GetTargets(E)) do
            if etarget and etarget:Distance(Player) < Menu.Get("Max.E") and Player:Distance(etarget) > Menu.Get("Min.E") and E:Cast() then
                return
            end
        end
    end
    if CanCast(E,mode) and Menu.Get("emode") == 0 and Player:GetBuff("KaisaEEvolved") then
        if Menu.Get("Misc.BlockE") and (Player:GetBuff(hailofblades) or Player:GetBuff(LethalTempo)) then return end
        for k,etarget in pairs(GetTargets(E)) do
            if etarget and  etarget:Distance(Player) < Menu.Get("Max.Ev") and Player:Distance(etarget) > Menu.Get("Min.Ev") and E:Cast() then
                return
            end
        end
    end
end

function Kaisa.HarassLogic(mode)
    if Menu.Get("ManaSlider") > (Player.ManaPercent * 100) then return end
    local Ma = Menu.Get("Max.W")
    local Mi = Menu.Get("Min.W")
    if CanCast(Q,mode) then
        for k,v in pairs(GetTargets(Q)) do
            if v and Count(Q,"enemy","minions") < 3 then
                if Q:Cast() then return end
            end
        end
    end
    if CanCast(W,mode) and Menu.Get("wmode") == 2 then
        for k,wtarget in pairs(GetTargets(W)) do
            if wtarget and wtarget:Distance(Player) < Ma and Player:Distance(wtarget) > Mi and W:CastOnHitChance(wtarget,HitChance(W)) then
                return
            end
        end
    end
    if CanCast(W,mode) and Menu.Get("wmode") == 1 then
        for k,wtarget in pairs(GetTargets(W)) do
            if wtarget and PASSIVECOUNT(wtarget) and PASSIVECOUNT(wtarget) > Menu.Get("wc") and W:CastOnHitChance(wtarget,HitChance(W)) then
                return
            end
        end
    end
end

function Kaisa.ClearLogic()
    if Q:IsReady() and Lane(Q) and Menu.Get("ManaSliderLane") < (Player.ManaPercent * 100) then
        if Count(Q,"enemy","minions") >= Menu.Get("Lane.QH") then
            if Q:Cast() then return end
        end
    end
    if Q:IsReady() and Jungle(Q) then
        if Count(Q,"neutral","minions") > 0 then
            if Q:Cast() then return end
        end
    end
    if W:IsReady() and Jungle(W) then
        for k, v in pairs(Obj.Get("neutral", "minions")) do
            local minion = v.AsAI
            local Tar    = W:IsInRange(minion) and minion.MaxHealth > 6 and minion.IsTargetable and Player:Distance(minion) < 700
            if minion and Tar then
                if W:Cast(minion) then return end
            end
        end
    end
end

-- CALLBACKS
function Kaisa.Auto()
    if W:IsReady() and Menu.Get("KS.W") then
        for k,v in pairs(GetTargets(W)) do
            if v then
                local dmg = DmgLib.CalculateMagicalDamage(Player,v,dmg(W,v))
                local Ks  = W:GetKillstealHealth(v)
                if dmg > Ks and W:CastOnHitChance(v,Enums.HitChance.High) then return end
            end
        end
    end
end

function Kaisa.OnPostAttack(target)
    local mode = Orb.GetMode()
    local Target = target.AsAI
    if not Target or not W:IsReady() then return end
    if Target.IsHero then
        if mode == "Combo" then
            if CanCast(W,"Combo") and Menu.Get("wmodec") == 0 then
                if W:CastOnHitChance(Target,HitChance(W)) then
                    return
                end
            end
        end
    end
    if Target.IsHero then
        if mode == "Harass" and Menu.Get("ManaSlider") < (Player.ManaPercent * 100) then
            if CanCast(W,"Harass") and Menu.Get("wmode") == 0 then
                if W:CastOnHitChance(Target,HitChance(W)) then
                    return
                end
            end
        end
    end
end

function Kaisa.OnGapclose(Source, DashInstance)
    if not (Source.IsEnemy) then return end
    if not Menu.Get("2" .. Source.AsHero.CharName) then return end
    if Menu.Get("Misc.E") and E:IsReady() then 
        if Menu.Get("Misc.emode") == 0 and not Player:GetBuff("KaisaEEvolved") then return end
        local mypos = Player.Position
        local Dist  = mypos:Distance(Source)
        if Dist < 400 then
            if E:Cast() then return end
        end
    end
    if Menu.Get("Misc.R") and R:IsReady() and Player.HealthPercent * 100 <= Menu.Get("Misc.RHP") then 
        local mypos = Player.Position
        local Dist  = mypos:Distance(Source)
        if Dist < 400 then
            if R:Cast(Source) then return end
        end
    end
end


-- RECALLERS
function Kaisa.Combo()  Kaisa.ComboLogic("Combo")  end
function KaisaNP.Harass() Kaisa.HarassLogic("Harass") end
function KaisaNP.Waveclear() Kaisa.ClearLogic() end


-- MENU
function Kaisa.LoadMenu()
    Menu.RegisterMenu("StormKaisa", "Storm Kaisa", function()
        Menu.NewTree("Combo", "Combo Options", function()
            Menu.Checkbox("Combo.CastQ",   "Use [Q]", true)
            Menu.Checkbox("Combo.CastW",   "Use [W]", true)
            Menu.Slider("wc","Use W | If Plasma stacks >= x",3,1,4)
            Menu.Dropdown("wmodec","W mode",1,{"Post Attack", "Based On Stack", "Always"})
            Menu.Checkbox("Combo.CastE",   "Use [E]", true)
            Menu.Dropdown("emode","e mode",1,{"Only when evolved", "Always"})
        end)
        Menu.NewTree("Harass", "Harass Options", function()
            Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
            Menu.Slider("ManaSlider","",50,0,100)
            Menu.Checkbox("Harass.CastQ",   "Use [Q]", true)
            Menu.Checkbox("Harass.CastW",   "Use [W]", true)
            Menu.Slider("w","Use W | If Plasma stacks >= x",3,1,4)
            Menu.Dropdown("wmode","W mode",2,{"Post Attack", "Based On Stack", "Always"})
        end)
        Menu.NewTree("Wave", "Farming Options", function()
            Menu.NewTree("Lane", "Laneclear Options", function()
                Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
                Menu.Slider("ManaSliderLane","",50,0,100)
                Menu.Checkbox("Lane.Q",   "Use Q", true)
                Menu.Slider("Lane.QH",   "Q Hitcount", 3,1,5)
            end)
            Menu.NewTree("Jungle", "Jungleclear Options", function()
                Menu.Checkbox("Jungle.Q",   "Use Q", true)
                Menu.Checkbox("Jungle.W",   "Use W", true)
            end)
        end)
        Menu.NewTree("Range", "Spell Range Options", function()
            Menu.Slider("Max.W","[W] Max Range", 3000, 0, 3000)
            Menu.Slider("Min.W","[W] Min Range",625, 0, 700)
            Menu.Slider("Max.E","[E] Max Range", 700, 500, 1000)
            Menu.Slider("Min.E","[E] Min Range",525, 100, 525)
            Menu.Slider("Max.Ev","[E Evolved] Max Range", 600, 500, 1000)
            Menu.Slider("Min.Ev","[E Evolved] Min Range",325, 100, 525)
        end)
        Menu.NewTree("Prediction", "Prediction Options", function()
            Menu.Slider("Chance.W","HitChance [W]",0.75, 0, 1, 0.05)
        end)
        Menu.NewTree("KillSteal", "KillSteal Options", function()
            Menu.Checkbox("KS.W",   "Use W", true)
        end)
        Menu.NewTree("Misc", "Misc Options", function()
            Menu.Checkbox("Misc.BlockE",   "Block E while Buff active || hailes of blades or LethalTempo", false)
            Menu.Checkbox("Misc.E",   "Use E on gapclose", false)
            Menu.Dropdown("Misc.emode","^ e mode",0,{"Only when evolved", "Always"})
            Menu.Checkbox("Misc.R",   "Use R on gapclose", true)
            Menu.Slider("Misc.RHP","When ^ Hp | X <=",30,0,100)
            Menu.NewTree("gapclose", "gapclose Whitelist", function()
                for _, Object in pairs(Obj.Get("enemy", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox("2" .. Name, "Use on " .. Name, true)
                end
            end)
        end)
        Menu.NewTree("Draw", "Drawing Options", function()
            Menu.Checkbox("Drawing.Q.Enabled",   "Draw [Q] Range",true)
            Menu.ColorPicker("Drawing.Q.Color", "Draw [Q] Color", 0xf03030ff)
            Menu.Checkbox("Drawing.W.Enabled",   "Draw [W] Range",true)
            Menu.Checkbox("Map.W.Enabled",   "Draw [W] Range On Mini Map",true)
            Menu.ColorPicker("Drawing.W.Color", "Draw [W] Color", 0x30e6f0ff)
            Menu.Checkbox("Drawing.R.Enabled",   "Draw [R] Range",true)
            Menu.Checkbox("Map.R.Enabled",   "Draw [R] Range On Mini Map",true)
            Menu.ColorPicker("Drawing.R.Color", "Draw [R] Color", 0xf03086ff)
        end)
    end)     
end


-- LOAD
function OnLoad()
    Kaisa.LoadMenu()
    for eventName, eventId in pairs(Enums.Events) do
        if Kaisa[eventName] then
            Event.RegisterCallback(eventId, Kaisa[eventName])
        end
    end    
    return true
end