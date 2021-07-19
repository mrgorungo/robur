--[[
  _    _      _ _ _  __          _   _               
 | |  | |    | | | |/ /         | | | |              
 | |__| | ___| | | ' / __ _ _ __| |_| |__  _   _ ___ 
 |  __  |/ _ \ | |  < / _` | '__| __| '_ \| | | / __|
 | |  | |  __/ | | . \ (_| | |  | |_| | | | |_| \__ \
 |_|  |_|\___|_|_|_|\_\__,_|_|   \__|_| |_|\__,_|___/
                                                                                                                                                                                          
]]
if Player.CharName ~= "Karthus" then
    return
end
local scriptName = "HellKarthus"
local author = "48656c6c636174"
local version = "2.1"
---[Requirements]----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
module(scriptName, package.seeall, log.setup)
clean.module(scriptName, clean.seeall, log.setup)
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---[LUA Utilities]---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
local pairs = _G.pairs
local type = _G.type
local toNumber = _G.tonumber
local toString = _G.tostring
local mathAbs = _G.math.abs
local mathHuge = _G.math.huge
local mathMin = _G.math.min
local mathDeg = _G.math.deg
local mathSin = _G.math.sin
local mathCos = _G.math.cos
local mathAcos = _G.math.acos
local mathPi = _G.math.pi
local mathRad = _G.math.rad
local mathSqrt = _G.math.sqrt
local osClock = _G.os.clock
local stringFormat = _G.string.format
local tInsert = _G.table.insert
local tRemove = _G.table.remove
local tSort = _G.table.sort
local tLenght = _G.table.getn
local tNext = _G.next
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---[API]-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
local _Libs, _SDK = _G.Libs, _G.CoreEx
-- Libs
local Collision = _Libs.CollisionLib
local DamageLib = _Libs.DamageLib
local DashLib = _Libs.DashLib
local HealthPred = _Libs.HealthPred
local Menu = _Libs.NewMenu
local ImmobileLib = _Libs.ImmobileLib
local Orbwalker = _Libs.Orbwalker
local Prediction = _Libs.Prediction
local Profiler = _Libs.Profiler
local SpellLib = _Libs.Spell
local TargetSelector = _Libs.TargetSelector()
-- CoreEx
local Enums = _SDK.Enums
local EventManager = _SDK.EventManager
local Game = _SDK.Game
local Geometry = _SDK.Geometry
local Input = _SDK.Input
local Nav = _SDK.Nav
local ObjectManager = _SDK.ObjectManager
local Renderer = _SDK.Renderer
-- CoreEx Enums
local AbilityResourceTypes = Enums.AbilityResourceTypes
local BuffTypes = Enums.BuffTypes
local DamageTypes = Enums.DamageTypes
local Events = Enums.Events
local GameObjectOrders = Enums.GameObjectOrders
local HitChance = Enums.HitChance
local ItemSlots = Enums.ItemSlots
local ObjectTypeFlags = Enums.ObjectTypeFlags
local PerkIDs = Enums.PerkIDs
local SpellSlots = Enums.SpellSlots
local SpellStates = Enums.SpellStates
local Teams = Enums.Teams
-- CoreEx Geometry
local Vector = Geometry.Vector
local Path = Geometry.Path
local Circle = Geometry.Circle
local Rectangle = Geometry.Rectangle
local Cone = Geometry.Cone
local Polygon = Geometry.Polygon
local BestCoveringCircle = Geometry.BestCoveringCircle
local BestCoveringCone = Geometry.BestCoveringCone
local BestCoveringRectangle = Geometry.BestCoveringRectangle
local CircleIntersection = Geometry.CircleCircleIntersection
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---[Variables/Tables]------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
local Karthus = {}
local KarthusLP = {}
local KarthusNP = {}
local KarthusHP = {}
local TargetsR = {}
local Resolution = Renderer.GetResolution()
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---[Spells]----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
local Q =
    SpellLib.Skillshot {
    Slot = SpellSlots.Q,
    RawSpell = "Q",
    Range = 875,
    Radius = 160,
    Speed = mathHuge,
    Delay = 0.9,
    Type = "Circular"
}
local W =
    SpellLib.Skillshot {
    Slot = SpellSlots.W,
    RawSpell = "W",
    Range = 1000,
    Radius = 1000,
    Speed = mathHuge,
    Delay = 0.25,
    Type = "Linear"
}
local E =
    SpellLib.Active {
    Slot = SpellSlots.E,
    RawSpell = "E",
    Range = 550,
    Delay = 0
}
local R =
    SpellLib.Active {
    Slot = SpellSlots.R,
    RawSpell = "R",
    Range = 25000,
    Delay = 3.25
}
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---[Menu]------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Karthus.Menu()
    Menu.NewTree(
        scriptName .. "Combo",
        "Combo Settings",
        function()
            Menu.Checkbox("Combo.UseQ", "Use Q", true)
            Menu.Slider("Combo.MinManaQ", "% Mana Limit", 15, 0, 100, 1)
            Menu.Checkbox("Combo.UseW", "Use W", true)
            Menu.Slider("Combo.MinManaW", "% Mana Limit", 15, 0, 100, 1)
            Menu.Checkbox("Combo.UseE", "Use E", true)
            Menu.Slider("Combo.MinManaE", "% Mana Limit", 15, 0, 100, 1)
            Menu.Slider("Combo.TargetsE", "Minimum Targets", 1, 1, 5, 1)
            Menu.Checkbox("Combo.UseR", "Use R", true)
            Menu.Slider("Combo.MinManaR", "% Mana Limit", 15, 0, 100, 1)
            Menu.Slider("Combo.TargetsR", "Minimum Targets", 1, 1, 5, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "Harass",
        "Harass Settings",
        function()
            Menu.Checkbox("Harass.UseQ", "Use Q", true)
            Menu.Slider("Harass.MinManaQ", "% Mana Limit", 15, 0, 100, 1)
            Menu.Checkbox("Harass.UseW", "Use W", true)
            Menu.Slider("Harass.MinManaW", "% Mana Limit", 15, 0, 100, 1)
            Menu.Checkbox("Harass.UseE", "Use E", false)
            Menu.Slider("Harass.MinManaE", "% Mana Limit", 15, 0, 100, 1)
            Menu.Slider("Harass.TargetsE", "Minimum Targets", 1, 1, 5, 1)
            Menu.Checkbox("Harass.UseR", "Use R", false)
            Menu.Slider("Harass.MinManaR", "% Mana Limit", 15, 0, 100, 1)
            Menu.Slider("Harass.TargetsR", "Minimum Targets", 1, 1, 5, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "Lasthit",
        "Lasthit Settings",
        function()
            Menu.Checkbox("Lasthit.UseQ", "Use Q", true)
            Menu.Slider("Lasthit.MinManaQ", "% Mana Limit", 15, 0, 100, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "Waveclear",
        "Waveclear Settings",
        function()
            Menu.Checkbox("Waveclear.UseQ", "Use Q", true)
            Menu.Slider("Waveclear.MinManaQ", "% Mana Limit", 15, 0, 100, 1)
            Menu.Checkbox("Waveclear.UseE", "Use E", true)
            Menu.Slider("Waveclear.MinManaE", "% Mana Limit", 15, 0, 100, 1)
            Menu.Slider("Waveclear.TargetsE", "Minimum Minions", 1, 1, 5, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "Jungleclear",
        "Jungleclear Settings",
        function()
            Menu.Checkbox("Jungleclear.UseQ", "Use Q", true)
            Menu.Slider("Jungleclear.MinManaQ", "% Mana Limit", 15, 0, 100, 1)
            Menu.Checkbox("Jungleclear.UseE", "Use E", true)
            Menu.Slider("Jungleclear.MinManaE", "% Mana Limit", 15, 0, 100, 1)
            Menu.Slider("Jungleclear.TargetsE", "Minimum Minions", 1, 1, 5, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "Killsteal",
        "Killsteal Settings",
        function()
            Menu.Checkbox("Killsteal.UseQ", "Use Q", true)
            Menu.Slider("Killsteal.MinManaQ", "% Mana Limit", 0, 0, 100, 1)
            Menu.Checkbox("Killsteal.UseR", "Use R", false)
            Menu.Slider("Killsteal.MinManaR", "% Mana Limit", 0, 0, 100, 1)
            Menu.Slider("Killsteal.TargetsR", "Minimum Targets", 1, 1, 5, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "AntiGapcloser",
        "AntiGapcloser Settings",
        function()
            Menu.Checkbox("AntiGapcloser.UseW", "Use W", true)
            Menu.Slider("AntiGapcloser.MinManaW", "% Mana Limit", 0, 0, 100, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "Miscellaneous",
        "Miscellaneous Settings",
        function()
            Menu.Checkbox("Flee.UseW", "Use W on Flee", false)
            Menu.Slider("Flee.MinManaW", "% Mana Limit", 15, 0, 100, 1)
            Menu.Checkbox("Auto.UseE", "Smart Auto E", false)
            Menu.Slider("Auto.MinManaE", "% Mana Limit", 15, 0, 100, 1)
            Menu.Slider("RCastRange", "R Cast Range", 800, 0, 5000, 25)
        end
    )
    Menu.NewTree(
        scriptName .. "Prediction",
        "Prediction Settings",
        function()
            Menu.Slider("HitChanceQ", "Q Hit Chance", 0.75, 0.05, 1, 0.05)
            Menu.Slider("HitChanceW", "W Hit Chance", 0.75, 0.05, 1, 0.05)
        end
    )
    Menu.NewTree(
        scriptName .. "Drawings",
        "Drawings Settings",
        function()
            Menu.Checkbox("DrawQ", "Draw Q Range", true)
            Menu.ColorPicker("ColorQ", "Draw Q Color", 0xEF476FFF)
            Menu.Checkbox("DrawW", "Draw W Range", true)
            Menu.ColorPicker("ColorW", "Draw W Color", 0x06D6A0FF)
            Menu.Checkbox("DrawE", "Draw E Range", true)
            Menu.ColorPicker("ColorE", "Draw E Color", 0x118AB2FF)
            Menu.Checkbox("DrawR", "Draw R Alert", true)
        end
    )
end
Menu.RegisterMenu(scriptName, scriptName .. " Menu", Karthus.Menu)
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---[Functions]-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
local function GameIsAvailable()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

local function CheckMinions(minion, spell)
    local minion = minion.AsAI
    local minionInRange = minion and minion.MaxHealth > 6 and spell:IsInRange(minion)
    if minionInRange and minion.IsTargetable then
        return true
    else
        return false
    end
end

local function TRObject(table, value)
    for k, v in pairs(table) do
        if v == value then
            return tRemove(TargetsR, k)
        end
    end
end

function Karthus.IsEnabledAndReady(mode, spell)
    local ManaLimit = Menu.Get(mode .. ".MinMana" .. spell.RawSpell) / 100
    local KarthusPassive = Player:GetBuff("KarthusDeathDefiedBuff")
    if ManaLimit > Player.ManaPercent and not KarthusPassive then
        return
    end
    return Menu.Get(mode .. ".Use" .. spell.RawSpell) and spell:IsReady()
end

function Karthus.GetRawDamageQ()
    return 30 + Q:GetLevel() * 20 + 0.3 * Player.TotalAP
end

function Karthus.GetRawDamageE()
    return 2.5 + E:GetLevel() * 5 + 0.05 * Player.TotalAP
end

function Karthus.GetRawDamageR()
    return 50 + R:GetLevel() * 150 + 0.75 * Player.TotalAP
end

function Karthus.QLogic(mode)
    if not Karthus.IsEnabledAndReady(mode, Q) then
        return
    end
    if Q:GetCurrentAmmo() == 1 then
        return
    end
    local target = Q:GetTarget()
    if not target then
        return
    end
    if mode == "Killsteal" then
        local qDmg = DamageLib.CalculateMagicalDamage(Player, target, Karthus.GetRawDamageQ())
        if qDmg < Q:GetHealthPred(target) then
            return
        end
        if Q:CastOnHitChance(target, HitChance.Medium) then
            return
        end
    else
        if Q:CastOnHitChance(target, Menu.Get("HitChanceQ")) then
            return
        end
    end
end

function Karthus.WLogic(mode)
    if not Karthus.IsEnabledAndReady(mode, W) then
        return
    end
    local target = W:GetTarget()
    if not target then
        return
    end
    if W:CastOnHitChance(target, Menu.Get("HitChanceW")) then
        return
    end
end

function Karthus.ELogic(mode)
    if not Karthus.IsEnabledAndReady(mode, E) then
        return
    end
    local target = E:GetTarget()
    if not target then
        if E:GetToggleState() == 0 or E:GetToggleState() == 1 then
            return
        end
        return E:Cast()
    end
    if E:GetToggleState() == 2 then
        return
    end
    if E:Cast() then
        return
    end
end

function Karthus.RLogic(mode)
    if not Karthus.IsEnabledAndReady(mode, R) then
        return
    end
    local killable = {}
    local targets = array_merge(R:GetTargets(), TargetsR)
    if tLenght(targets) == 0 then
        return
    end
    for k, v in pairs(targets) do
        local rDmg = DamageLib.CalculateMagicalDamage(Player, v, Karthus.GetRawDamageR())
        if R:GetHealthPred(v) < rDmg and Player:Distance(v.Position) > Menu.Get("RCastRange") then
            tInsert(killable, v)
        end
    end
    if tLenght(killable) < Menu.Get(mode .. ".TargetsR") then
        return
    end
    if R:Cast() then
        return
    end
end

function Karthus.RAlert()
    local targets = array_merge(R:GetTargets(), TargetsR)
    if not targets then
        return
    end
    local killable = {}
    for k, v in pairs(targets) do
        local rDmg = DamageLib.CalculateMagicalDamage(Player, v, Karthus.GetRawDamageR())
        if R:GetHealthPred(v) < rDmg then
            tInsert(killable, v.CharName)
        end
    end
    if tLenght(killable) == 0 then
        return
    end
    return killable
end

function Karthus.QClear(type, mode)
    if not Karthus.IsEnabledAndReady(mode, Q) then
        return
    end
    local minions = ObjectManager.GetNearby(type, "minions")
    if tLenght(minions) == 0 then
        return
    end
    local minionPos = {}
    for k, v in pairs(minions) do
        if CheckMinions(v, W) then
            local minion = v.AsAI
            if Q:GetHealthPred(minion) > 0 then
                if mode == "Lasthit" then
                    local qDmg = DamageLib.CalculateMagicalDamage(Player, minion, Karthus.GetRawDamageQ())
                    if Q:GetHealthPred(minion) < qDmg then
                        Orbwalker.IgnoreMinion(minion)
                        tInsert(minionPos, minion)
                    end
                else
                    tInsert(minionPos, minion)
                end
            end
        end
    end
    local bestPos, hitCount = Q:GetBestCircularCastPos(minionPos)
    if not bestPos or hitCount == 0 then
        return
    end
    if Q:Cast(bestPos) then
        return
    end
end

function Karthus.EClear(type, mode)
    if not Karthus.IsEnabledAndReady(mode, E) then
        return
    end
    local minions = ObjectManager.GetNearby(type, "minions")
    if tLenght(minions) == 0 then
        return
    end
    local minionsInRange = {}
    for k, v in pairs(minions) do
        if CheckMinions(v, E) then
            tInsert(minionsInRange, v.AsAI)
        end
    end
    if tLenght(minionsInRange) < Menu.Get(mode .. ".TargetsE") then
        if E:GetToggleState() == 0 or E:GetToggleState() == 1 then
            return
        end
        return E:Cast()
    end
    if E:GetToggleState() == 2 then
        return
    end
    if E:Cast() then
        return
    end
end

function KarthusNP.Combo()
    Karthus.QLogic("Combo")
    Karthus.WLogic("Combo")
    Karthus.ELogic("Combo")
end
function KarthusHP.Combo()
    Karthus.RLogic("Combo")
end

function KarthusNP.Harass()
    Karthus.QLogic("Harass")
    Karthus.WLogic("Harass")
    Karthus.ELogic("Harass")
end
function KarthusHP.Harass()
    Karthus.RLogic("Harass")
end

function KarthusNP.Lasthit()
    Karthus.QClear("neutral", "Lasthit")
    Karthus.QClear("enemy", "Lasthit")
end

function KarthusNP.Waveclear()
    Karthus.EClear("enemy", "Waveclear")
    Karthus.EClear("neutral", "Jungleclear")
end
function KarthusLP.Waveclear()
    Karthus.QClear("enemy", "Waveclear")
    Karthus.QClear("neutral", "Jungleclear")
end

function KarthusHP.Killsteal()
    Karthus.QLogic("Killsteal")
    Karthus.RLogic("Killsteal")
end

function KarthusLP.Flee()
    Karthus.WLogic("Flee")
end

function KarthusLP.Auto()
    Karthus.ELogic("Auto")
end

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---[Events]----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Karthus.OnHighPriority()
    if not GameIsAvailable() then
        return
    end
    if KarthusHP.Killsteal() then
        return
    end
    local ModeToExecute = KarthusHP[Orbwalker.GetMode()]
    if ModeToExecute then
        ModeToExecute()
    end
end

function Karthus.OnNormalPriority()
    if not GameIsAvailable() then
        return
    end
    local ModeToExecute = KarthusNP[Orbwalker.GetMode()]
    if ModeToExecute then
        ModeToExecute()
    end
end

function Karthus.OnLowPriority()
    if not GameIsAvailable() then
        return
    end
    local ModeToExecute = KarthusLP[Orbwalker.GetMode()]
    if ModeToExecute then
        ModeToExecute()
    elseif KarthusLP.Auto() then
        return
    end
end

function Karthus.OnGapclose(Source, DashInst)
    if not Source.IsEnemy then
        return
    end
    Karthus.WLogic("AntiGapcloser")
end

function Karthus.OnVisionLost(obj)
    if not (obj.IsEnemy or obj.IsHero) then
        return
    end
    tInsert(TargetsR, obj.AsHero)
    delay(3000, TRObject, TargetsR, obj.AsHero)
end

function Karthus.OnVisionGain(obj)
    if not (obj.IsEnemy or obj.IsHero) then
        return
    end
    TRObject(TargetsR, obj.AsHero)
end

function Karthus.OnDraw()
    local spells = {Q, W, E}
    local playerPos = Player.Position
    for k, v in pairs(spells) do
        if Menu.Get("Draw" .. v.RawSpell) then
            Renderer.DrawCircle3D(playerPos, v.Range, 30, 1, Menu.Get("Color" .. v.RawSpell))
        end
    end
    if not Menu.Get("DrawR") then
        return
    end
    local targets = Karthus.RAlert()
    if not targets then
        return
    end
    for k, v in pairs(targets) do
        local pos = 70 + k * 10
        Renderer.DrawText(
            Resolution / Vector(2, 2) - Vector(50, pos, 100),
            Vector(1000, 1000, 1000),
            v .. " Is Killable",
            0xFF0000FF
        )
    end
end

function OnLoad()
    for eventName, eventId in pairs(Events) do
        if Karthus[eventName] then
            EventManager.RegisterCallback(eventId, Karthus[eventName])
        end
    end
    print("[" .. author .. "]" .. scriptName .. " Version: " .. version)
    return true
end
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------