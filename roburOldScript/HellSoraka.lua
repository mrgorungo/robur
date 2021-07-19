--[[
  _    _      _ _    _____                 _         
 | |  | |    | | |  / ____|               | |        
 | |__| | ___| | | | (___   ___  _ __ __ _| | ____ _ 
 |  __  |/ _ \ | |  \___ \ / _ \| '__/ _` | |/ / _` |
 | |  | |  __/ | |  ____) | (_) | | | (_| |   < (_| |
 |_|  |_|\___|_|_| |_____/ \___/|_|  \__,_|_|\_\__,_|
                                                                                                                                                                                                                              
]]
if Player.CharName ~= "Soraka" then
    return
end
local scriptName = "HellSoraka"
local author = "48656c6c636174"
local version = "1.0"
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
local Soraka = {}
local SorakaLP = {}
local SorakaNP = {}
local SorakaHP = {}
local Resolution = Renderer.GetResolution()
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---[Spells]----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
local Q =
    SpellLib.Skillshot(
    {
        Slot = SpellSlots.Q,
        RawSpell = "Q",
        Range = 800,
        Radius = 235,
        Speed = 1150,
        Delay = 0.25,
        Type = "Circular",
        UseHitbox = true
    }
)

local W =
    SpellLib.Targeted(
    {
        Slot = SpellSlots.W,
        RawSpell = "W",
        Range = 550,
        Delay = 0.25
    }
)

local E =
    SpellLib.Skillshot(
    {
        Slot = SpellSlots.E,
        RawSpell = "E",
        Range = 925,
        Radius = 250,
        Speed = mathHuge,
        Delay = 0.25,
        Type = "Circular"
    }
)

local R =
    SpellLib.Active(
    {
        Slot = SpellSlots.R,
        RawSpell = "R",
        Range = 25000,
        Delay = 0.25
    }
)

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---[Menu]------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Soraka.Menu()
    Menu.NewTree(
        scriptName .. "Combo",
        "Combo Settings",
        function()
            Menu.Checkbox("Combo.UseQ", "Use Q", true)
            Menu.Slider("Combo.MinManaQ", "% Mana Limit", 15, 0, 100, 1)
            Menu.Checkbox("Combo.UseW", "Use W", true)
            Menu.Slider("Combo.MinManaW", "% Mana Limit", 15, 0, 100, 1)
            Menu.Slider("Combo.MinHPW", "% HP Limit", 15, 5, 100, 1)
            Menu.Slider("Combo.MinHPAW", "% Ally HP Below", 25, 0, 100, 1)
            Menu.Checkbox("Combo.UseE", "Use E", true)
            Menu.Slider("Combo.MinManaE", "% Mana Limit", 15, 0, 100, 1)
            Menu.Checkbox("Combo.UseR", "Use R", true)
            Menu.Slider("Combo.MinManaR", "% Mana Limit", 15, 0, 100, 1)
            Menu.Slider("Combo.MinHPAR", "% Ally HP Below", 5, 0, 100, 1)
            Menu.Slider("Combo.AlliesR", "Minimum Allies", 1, 1, 5, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "Harass",
        "Harass Settings",
        function()
            Menu.Checkbox("Harass.UseQ", "Use Q", true)
            Menu.Slider("Harass.MinManaQ", "% Mana Limit", 15, 0, 100, 1)
            Menu.Checkbox("Harass.UseW", "Use W", false)
            Menu.Slider("Harass.MinManaW", "% Mana Limit", 15, 0, 100, 1)
            Menu.Slider("Harass.MinHPW", "% HP Limit", 15, 5, 100, 1)
            Menu.Slider("Harass.MinHPAW", "% Ally HP Below", 25, 0, 100, 1)
            Menu.Checkbox("Harass.UseE", "Use E", false)
            Menu.Slider("Harass.MinManaE", "% Mana Limit", 15, 0, 100, 1)
            Menu.Checkbox("Harass.UseR", "Use R", false)
            Menu.Slider("Harass.MinManaR", "% Mana Limit", 15, 0, 100, 1)
            Menu.Slider("Harass.MinHPAR", "% Ally HP Below", 5, 0, 100, 1)
            Menu.Slider("Harass.AlliesR", "Minimum Allies", 1, 1, 5, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "Lasthit",
        "Lasthit Settings",
        function()
            Menu.Checkbox("Lasthit.UseQ", "Use Q", false)
            Menu.Slider("Lasthit.MinManaQ", "% Mana Limit", 15, 0, 100, 1)
            Menu.Slider("Lasthit.TargetsQ", "Minimum Targets", 1, 1, 5, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "Waveclear",
        "Waveclear Settings",
        function()
            Menu.Checkbox("Waveclear.UseQ", "Use Q", false)
            Menu.Slider("Waveclear.MinManaQ", "% Mana Limit", 15, 0, 100, 1)
            Menu.Slider("Waveclear.TargetsQ", "Minimum Minions", 1, 1, 5, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "Jungleclear",
        "Jungleclear Settings",
        function()
            Menu.Checkbox("Jungleclear.UseQ", "Use Q", false)
            Menu.Slider("Jungleclear.MinManaQ", "% Mana Limit", 15, 0, 100, 1)
            Menu.Slider("Jungleclear.TargetsQ", "Minimum Minions", 1, 1, 5, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "Killsteal",
        "Killsteal Settings",
        function()
            Menu.Checkbox("Killsteal.UseQ", "Use Q", false)
            Menu.Slider("Killsteal.MinManaQ", "% Mana Limit", 0, 0, 100, 1)
            Menu.Checkbox("Killsteal.UseE", "Use E", false)
            Menu.Slider("Killsteal.MinManaE", "% Mana Limit", 0, 0, 100, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "AntiGapcloser",
        "AntiGapcloser Settings",
        function()
            Menu.Checkbox("AntiGapcloser.UseQ", "Use Q", true)
            Menu.Slider("AntiGapcloser.MinManaQ", "% Mana Limit", 0, 0, 100, 1)
            Menu.Checkbox("AntiGapcloser.UseE", "Use E", true)
            Menu.Slider("AntiGapcloser.MinManaE", "% Mana Limit", 0, 0, 100, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "Miscellaneous",
        "Miscellaneous Settings",
        function()
            Menu.Checkbox("Auto.UseW", "Auto W to save an ally", true)
            Menu.Slider("Auto.MinManaW", "% Mana Limit", 0, 0, 100, 1)
            Menu.Slider("Auto.MinHPW", "% HP Limit", 5, 5, 100, 1)
            Menu.Checkbox("Auto.UseR", "Auto R to save an ally", true)
            Menu.Slider("Auto.MinManaR", "% Mana Limit", 0, 0, 100, 1)
            Menu.Checkbox("Flee.UseQ", "Use Q on Flee", true)
            Menu.Slider("Flee.MinManaQ", "% Mana Limit", 0, 0, 100, 1)
            Menu.Checkbox("Flee.UseE", "Use E on Flee", false)
            Menu.Slider("Flee.MinManaE", "% Mana Limit", 0, 0, 100, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "Prediction",
        "Prediction Settings",
        function()
            Menu.Slider("HitChanceQ", "Q Hit Chance", 0.75, 0.05, 1, 0.05)
            Menu.Slider("HitChanceE", "E Hit Chance", 0.75, 0.05, 1, 0.05)
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
            Menu.Slider("DrawR.MinHPAR", "% HP Ally", 5, 1, 100, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "Whitelist",
        "Whitelist Settings",
        function()
            for _, Object in pairs(ObjectManager.Get("ally", "heroes")) do
                local Handle = Object.Handle
                local Name = Object.AsHero.CharName
                Menu.Checkbox(Handle, Name, true)
            end
        end
    )
end
Menu.RegisterMenu(scriptName, scriptName .. " Menu", Soraka.Menu)
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

function Soraka.IsEnabledAndReady(mode, spell)
    local ManaLimit = Menu.Get(mode .. ".MinMana" .. spell.RawSpell) / 100
    if ManaLimit > Player.ManaPercent then
        return
    end
    return Menu.Get(mode .. ".Use" .. spell.RawSpell) and spell:IsReady()
end

function Soraka.GetRawDamageQ()
    return 50 + Q:GetLevel() * 35 + Player.TotalAP * 0.35
end

function Soraka.GetRawHealW(target)
    if target:GetBuff("grievouswound") then
        return (45 + W:GetLevel() * 35 + Player.TotalAP * 0.6) * 0.6
    else
        return 45 + W:GetLevel() * 35 + Player.TotalAP * 0.6
    end
end

function Soraka.GetRawDamageE()
    return 45 + E:GetLevel() * 25 + Player.TotalAP * 0.4
end

function Soraka.GetRawHealR(target)
    if target.HealthPercent < 40 then
        if target:GetBuff("grievouswound") then
            return (50 + R:GetLevel() * 100 + Player.TotalAP * 0.55) * 1.5 * 0.6
        else
            return (50 + R:GetLevel() * 100 + Player.TotalAP * 0.55) * 1.5
        end
    else
        if target:GetBuff("grievouswound") then
            return (50 + R:GetLevel() * 100 + Player.TotalAP * 0.55) * 0.6
        else
            return 50 + R:GetLevel() * 100 + Player.TotalAP * 0.55
        end
    end
end

function Soraka.QLogic(mode)
    if not Soraka.IsEnabledAndReady(mode, Q) then
        return
    end
    local target = Q:GetTarget()
    if not target then
        return
    end
    if mode == "Killsteal" then
        local QDamage = DamageLib.CalculateMagicalDamage(Player, target, Soraka.GetRawDamageQ())
        if Q:GetHealthPred(target) > QDamage then
            return
        end
        if Q:CastOnHitChance(target, Menu.Get("HitChanceQ")) then
            return
        end
    else
        if Q:CastOnHitChance(target, Menu.Get("HitChanceQ")) then
            return
        end
    end
end

function Soraka.WLogic(mode)
    if not Soraka.IsEnabledAndReady(mode, W) then
        return
    end
    if Menu.Get(mode .. ".MinHPW") < Player.HealthPercent then
        return
    end
    local allies = ObjectManager.GetNearby("ally", "heroes")
    if not allies then
        return
    end
    tSort(
        allies,
        function(a, b)
            return a.AsHero.HealthPercent > b.AsHero.HealthPercent
        end
    )
    for k, v in pairs(allies) do
        if Menu.Get(v.Handle) then
            local ally = v.AsHero
            if not ally.IsMe then
                if W:IsInRange(ally) then
                    local hPred = W:GetHealthPred(ally)
                    local healthPercent = hPred * 100 / ally.MaxHealth
                    local healthCheck = false
                    if mode == "Auto" then
                        healthCheck = hPred < 1 and -Soraka.GetRawHealW(ally) < hPred
                    else
                        healthCheck = healthPercent < Menu.Get(mode .. ".MinHPAW") and -Soraka.GetRawHealW(ally) < hPred
                    end
                    if Player.HealthPercent > Menu.Get(mode .. ".MinHPW") then
                        if healthCheck then
                            if W:Cast(v) then
                                return
                            end
                        end
                    end
                end
            end
        end
    end
end

function Soraka.ELogic(mode)
    if not Soraka.IsEnabledAndReady(mode, E) then
        return
    end
    local target = E:GetTarget()
    if not target then
        return
    end
    if mode == "Killsteal" then
        local EDamage = DamageLib.CalculateMagicalDamage(Player, target, Soraka.GetRawDamageE())
        if E:GetHealthPred(target) > EDamage then
            return
        end
        if E:CastOnHitChance(target, Menu.Get("HitChanceE")) then
            return
        end
    else
        if E:CastOnHitChance(target, Menu.Get("HitChanceE")) then
            return
        end
    end
end

function Soraka.RLogic(mode)
    if not Soraka.IsEnabledAndReady(mode, R) then
        return
    end
    local allies = ObjectManager.Get("ally", "heroes")
    if not allies then
        return
    end
    for k, v in pairs(allies) do
        if Menu.Get(v.Handle) then
            local ally = v.AsHero
            local hPred = R:GetHealthPred(ally)
            local healthPercent = hPred * 100 / ally.MaxHealth
            local healthCheck = false
            if mode == "Auto" then
                healthCheck = hPred < 1 and -Soraka.GetRawHealR(ally) < hPred
            else
                healthCheck = healthPercent < Menu.Get(mode .. ".MinHPAR") and -Soraka.GetRawHealR(ally) < hPred
            end
            if healthCheck then
                if R:Cast() then
                    return
                end
            end
        end
    end
end

function Soraka.RAlert()
    local allies = ObjectManager.Get("ally", "heroes")
    if not allies then
        return
    end
    local healable = {}
    for k, v in pairs(allies) do
        local ally = v.AsHero
        local hPred = R:GetHealthPred(ally)
        local healthPercent = hPred * 100 / ally.MaxHealth
        local healthCheck = healthPercent < Menu.Get("DrawR.MinHPAR") and -Soraka.GetRawHealR(ally) < hPred
        if healthCheck then
            tInsert(healable, ally.CharName)
        end
    end
    if tLenght(healable) == 0 then
        return
    end
    return healable
end

function Soraka.QClear(type, mode)
    if not Soraka.IsEnabledAndReady(mode, Q) then
        return
    end
    local minions = ObjectManager.GetNearby(type, "minions")
    if tLenght(minions) == 0 then
        return
    end
    local minionPos = {}
    for k, v in pairs(minions) do
        if CheckMinions(v, Q) then
            if mode == "Lasthit" then
                local minion = v.AsAI
                local qDmg = DamageLib.CalculateMagicalDamage(Player, minion, Soraka.GetRawDamageQ())
                if Q:GetHealthPred(minion) < qDmg then
                    Orbwalker.IgnoreMinion(minion)
                    tInsert(minionPos, v.Position)
                end
            else
                tInsert(minionPos, v.Position)
            end
        end
    end
    local bestPos, hitCount = BestCoveringCircle(minionPos, Q.Radius)
    if not bestPos or hitCount < Menu.Get(mode .. ".TargetsQ") then
        return
    end
    if Q:Cast(bestPos) then
        return
    end
end

function SorakaNP.Combo()
    Soraka.QLogic("Combo")
    Soraka.ELogic("Combo")
end
function SorakaHP.Combo()
    Soraka.WLogic("Combo")
    Soraka.RLogic("Combo")
end

function SorakaNP.Harass()
    Soraka.QLogic("Harass")
    Soraka.ELogic("Harass")
end
function SorakaHP.Harass()
    Soraka.WLogic("Harass")
    Soraka.RLogic("Harass")
end

function SorakaHP.Lasthit()
    Soraka.QClear("enemy", "Lasthit")
    Soraka.QClear("neutral", "Lasthit")
end

function SorakaHP.Waveclear()
    Soraka.QClear("enemy", "Waveclear")
    Soraka.QClear("neutral", "Jungleclear")
end

function SorakaHP.Killsteal()
    Soraka.QLogic("Killsteal")
    Soraka.ELogic("Killsteal")
end

function SorakaLP.Flee()
    Soraka.QLogic("Flee")
    Soraka.ELogic("Flee")
end

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---[Events]----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function Soraka.OnHighPriority()
    if not GameIsAvailable() then
        return
    end
    if SorakaHP.Killsteal() then
        return
    end
    local ModeToExecute = SorakaHP[Orbwalker.GetMode()]
    if ModeToExecute then
        ModeToExecute()
    end
end

function Soraka.OnNormalPriority()
    if not GameIsAvailable() then
        return
    end
    local ModeToExecute = SorakaNP[Orbwalker.GetMode()]
    if ModeToExecute then
        ModeToExecute()
    end
end

function Soraka.OnLowPriority()
    if not GameIsAvailable() then
        return
    end
    local ModeToExecute = SorakaLP[Orbwalker.GetMode()]
    if ModeToExecute then
        ModeToExecute()
    end
end

function Soraka.OnGapclose(Source, DashInst)
    if not Source.IsEnemy then
        return
    end
    Soraka.QLogic("AntiGapcloser")
    Soraka.ELogic("AntiGapcloser")
end

function Soraka.OnDraw()
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
    local targets = Soraka.RAlert()
    if not targets then
        return
    end
    for k, v in pairs(targets) do
        local pos = 70 + k * 10
        Renderer.DrawText(
            Resolution / Vector(2, 2) - Vector(50, pos, 100),
            Vector(1000, 1000, 1000),
            v .. " Needs Heal",
            0xFF0000FF
        )
    end
end

function OnLoad()
    for eventName, eventId in pairs(Events) do
        if Soraka[eventName] then
            EventManager.RegisterCallback(eventId, Soraka[eventName])
        end
    end
    print("[" .. author .. "]" .. scriptName .. " Version: " .. version)
    return true
end
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
