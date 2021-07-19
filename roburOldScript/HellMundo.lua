--[[
  _    _      _ _ __  __                 _       
 | |  | |    | | |  \/  |               | |      
 | |__| | ___| | | \  / |_   _ _ __   __| | ___  
 |  __  |/ _ \ | | |\/| | | | | '_ \ / _` |/ _ \ 
 | |  | |  __/ | | |  | | |_| | | | | (_| | (_) |
 |_|  |_|\___|_|_|_|  |_|\__,_|_| |_|\__,_|\___/ 
                                                                                                                                                                                                                                                                                 
]]
if Player.CharName ~= "DrMundo" then
    return
end
local scriptName = "HellMundo"
local author = "48656c6c636174"
local version = "1.1"
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
local Mundo = {}
local MundoLP = {}
local MundoNP = {}
local MundoHP = {}
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---[Spells]----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
local Q =
    SpellLib.Skillshot(
    {
        Slot = SpellSlots.Q,
        RawSpell = "Q",
        Range = 975,
        Radius = 60,
        Speed = 2000,
        Delay = 0.25,
        Type = "Linear",
        Collisions = {Minions = true, WindWall = true},
        UseHitbox = true
    }
)

local W =
    SpellLib.Active(
    {
        Slot = SpellSlots.W,
        RawSpell = "W",
        Range = 325,
        Delay = 0
    }
)

local E =
    SpellLib.Active(
    {
        Slot = SpellSlots.E,
        RawSpell = "E",
        Range = 150,
        Delay = 0
    }
)

local R =
    SpellLib.Active(
    {
        Slot = SpellSlots.R,
        RawSpell = "R",
        Delay = 0
    }
)
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---[Menu]------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Mundo.Menu()
    Menu.NewTree(
        scriptName .. "Combo",
        "Combo Settings",
        function()
            Menu.Checkbox("Combo.UseQ", "Use Q", true)
            Menu.Slider("Combo.MinHPQ", "% HP Limit", 0, 0, 100, 1)
            Menu.Checkbox("Combo.UseW", "Use W", true)
            Menu.Slider("Combo.MinHPW", "% HP Limit", 0, 0, 100, 1)
            Menu.Checkbox("Combo.UseE", "Use E", true)
            Menu.Slider("Combo.MinHPE", "% HP Limit", 0, 0, 100, 1)
            Menu.Checkbox("Combo.UseR", "Use R", true)
            Menu.Slider("Combo.MinHPR", "% HP Trigger", 5, 0, 100, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "Harass",
        "Harass Settings",
        function()
            Menu.Checkbox("Harass.UseQ", "Use Q", true)
            Menu.Slider("Harass.MinHPQ", "% HP Limit", 0, 0, 100, 1)
            Menu.Checkbox("Harass.UseW", "Use W", true)
            Menu.Slider("Harass.MinHPW", "% HP Limit", 0, 0, 100, 1)
            Menu.Checkbox("Harass.UseE", "Use E", true)
            Menu.Slider("Harass.MinHPE", "% HP Limit", 0, 0, 100, 1)
            Menu.Checkbox("Harass.UseR", "Use R", false)
            Menu.Slider("Harass.MinHPR", "% HP Trigger", 5, 0, 100, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "Lasthit",
        "Lasthit Settings",
        function()
            Menu.Checkbox("Lasthit.UseQ", "Use Q", true)
            Menu.Slider("Lasthit.MinHPQ", "% HP Limit", 0, 0, 100, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "Waveclear",
        "Waveclear Settings",
        function()
            Menu.Checkbox("Waveclear.UseQ", "Use Q", true)
            Menu.Slider("Waveclear.MinHPQ", "% HP Limit", 0, 0, 100, 1)
            Menu.Checkbox("Waveclear.UseW", "Use W", true)
            Menu.Slider("Waveclear.MinHPW", "% HP Limit", 0, 0, 100, 1)
            Menu.Checkbox("Waveclear.UseE", "Use E", true)
            Menu.Slider("Waveclear.MinHPE", "% HP Limit", 0, 0, 100, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "Jungleclear",
        "Jungleclear Settings",
        function()
            Menu.Checkbox("Jungleclear.UseQ", "Use Q", true)
            Menu.Slider("Jungleclear.MinHPQ", "% HP Limit", 0, 0, 100, 1)
            Menu.Checkbox("Jungleclear.UseW", "Use W", true)
            Menu.Slider("Jungleclear.MinHPW", "% HP Limit", 0, 0, 100, 1)
            Menu.Checkbox("Jungleclear.UseE", "Use E", true)
            Menu.Slider("Jungleclear.MinHPE", "% HP Limit", 0, 0, 100, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "Killsteal",
        "Killsteal Settings",
        function()
            Menu.Checkbox("Killsteal.UseQ", "Use Q", true)
            Menu.Slider("Killsteal.MinHPQ", "% HP Limit", 0, 0, 100, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "AntiGapcloser",
        "AntiGapcloser Settings",
        function()
            Menu.Checkbox("AntiGapcloser.UseQ", "Use Q", true)
            Menu.Slider("AntiGapcloser.MinHPQ", "% HP Limit", 0, 0, 100, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "Miscellaneous",
        "Miscellaneous Settings",
        function()
            Menu.Checkbox("Flee.UseQ", "Use Q on Flee", true)
            Menu.Slider("Flee.MinHPQ", "% HP Limit", 0, 0, 100, 1)
            Menu.Checkbox("Auto.UseW", "Smart Auto W", true)
            Menu.Slider("Auto.MinHPW", "% HP Limit", 0, 0, 100, 1)
            Menu.Checkbox("Auto.UseR", "Use Auto R", false)
            Menu.Slider("Auto.MinHPR", "% HP Trigger", 5, 0, 100, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "Prediction",
        "Prediction Settings",
        function()
            Menu.Slider("HitChanceQ", "Q Hit Chance", 0.75, 0.05, 1, 0.05)
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
        end
    )
end
Menu.RegisterMenu(scriptName, scriptName .. " Menu", Mundo.Menu)
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

function Mundo.IsEnabledAndReady(mode, spell)
    if spell ~= R then
        local HealthLimit = Menu.Get(mode .. ".MinHP" .. spell.RawSpell) / 100
        if HealthLimit > Player.HealthPercent then
            return
        end
    end
    return Menu.Get(mode .. ".Use" .. spell.RawSpell) and spell:IsReady()
end

function Mundo.GetRawDamageQ(target)
    local minimumDmg = 30 + Q:GetLevel() * 50
    local healthDmg = (0.175 + Q:GetLevel() * 0.025) * target.Health
    if healthDmg < minimumDmg then
        return minimumDmg
    else
        if target.IsMinion or target.IsMonster then
            local cappedDmg = 250 + Q:GetLevel() * 50
            if healthDmg > cappedDmg then
                return cappedDmg
            else
                return healthDmg
            end
        else
            return healthDmg
        end
    end
end

function Mundo.GetRawDamageE()
    return (0.025 + E:GetLevel() * 0.005) * Player.Health + Player.TotalAD
end

function Mundo.QLogic(mode)
    if not Mundo.IsEnabledAndReady(mode, Q) then
        return
    end
    local target = Q:GetTarget()
    if not target then
        return
    end
    if mode == "Killsteal" then
        local qDmg = DamageLib.CalculateMagicalDamage(Player, target, Mundo.GetRawDamageQ(target))
        if qDmg < Q:GetHealthPred(target) then
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

function Mundo.WLogic(mode)
    if not Mundo.IsEnabledAndReady(mode, W) then
        return
    end
    local target = W:GetTarget()
    if not target then
        if W:GetToggleState() == 0 or W:GetToggleState() == 1 then
            return
        end
        return W:Cast()
    end
    if W:GetToggleState() == 2 then
        return
    end
    if W:Cast() then
        return
    end
end

function Mundo.RLogic(mode)
    if not Mundo.IsEnabledAndReady(mode, R) then
        return
    end
    local hpmenu = Menu.Get(mode .. ".MinHPR") / 100 * Player.MaxHealth
    local hpred = R:GetHealthPred(Player)
    if hpmenu < hpred then
        return
    end
    if R:Cast() then
        return
    end
end

function Mundo.QClear(type, mode)
    if not Mundo.IsEnabledAndReady(mode, Q) then
        return
    end
    local minions = ObjectManager.GetNearby(type, "minions")
    if tLenght(minions) == 0 then
        return
    end
    for k, v in pairs(minions) do
        if CheckMinions(v, Q) then
            local minion = v.AsAI
            if mode == "Lasthit" then
                local qDmg = DamageLib.CalculateMagicalDamage(Player, minion, Mundo.GetRawDamageQ(minion))
                if Q:GetHealthPred(minion) < qDmg then
                    if Q:Cast(minion) then
                        return
                    end
                end
            else
                if Q:Cast(minion) then
                    return
                end
            end
        end
    end
end

function Mundo.WClear(type, mode)
    if not Mundo.IsEnabledAndReady(mode, W) then
        return
    end
    local minions = ObjectManager.GetNearby(type, "minions")
    if tLenght(minions) == 0 then
        return
    end
    local minionsInRange = {}
    for k, v in pairs(minions) do
        if CheckMinions(v, W) then
            tInsert(minionsInRange, v.AsAI)
        end
    end
    if tLenght(minionsInRange) == 0 then
        if W:GetToggleState() == 0 or W:GetToggleState() == 1 then
            return
        end
        return W:Cast()
    end
    if W:GetToggleState() == 2 then
        return
    end
    if W:Cast() then
        return
    end
end

function MundoNP.Combo()
    Mundo.QLogic("Combo")
    Mundo.WLogic("Combo")
end
function MundoHP.Combo()
    Mundo.RLogic("Combo")
end

function MundoNP.Harass()
    Mundo.QLogic("Harass")
    Mundo.WLogic("Harass")
end
function MundoHP.Harass()
    Mundo.RLogic("Harass")
end

function MundoNP.Lasthit()
    Mundo.QClear("enemy", "Lasthit")
    Mundo.QClear("neutral", "Lasthit")
end

function MundoLP.Waveclear()
    Mundo.QClear("enemy", "Waveclear")
    Mundo.QClear("neutral", "Jungleclear")
end
function MundoNP.Waveclear()
    Mundo.WClear("enemy", "Waveclear")
    Mundo.WClear("neutral", "Jungleclear")
end

function MundoHP.Killsteal()
    Mundo.QLogic("Killsteal")
end

function MundoLP.Flee()
    Mundo.QLogic("Flee")
end

function MundoLP.Auto()
    Mundo.RLogic("Auto")
    Mundo.WLogic("Auto")
end
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---[Events]----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Mundo.OnHighPriority()
    if not GameIsAvailable() then
        return
    end
    if MundoHP.Killsteal() then
        return
    end
    local ModeToExecute = MundoHP[Orbwalker.GetMode()]
    if ModeToExecute then
        ModeToExecute()
    end
end

function Mundo.OnNormalPriority()
    if not GameIsAvailable() then
        return
    end
    local ModeToExecute = MundoNP[Orbwalker.GetMode()]
    if ModeToExecute then
        ModeToExecute()
    end
end

function Mundo.OnLowPriority()
    if not GameIsAvailable() then
        return
    end
    local ModeToExecute = MundoLP[Orbwalker.GetMode()]
    if ModeToExecute then
        ModeToExecute()
    elseif MundoLP.Auto() then
        return
    end
end

function Mundo.OnGapclose(Source, DashInst)
    if not Source.IsEnemy then
        return
    end
    return Mundo.QLogic("AntiGapcloser")
end

function Mundo.OnPostAttack(target)
    if target.IsHero then
        if Mundo.IsEnabledAndReady("Combo", E) and Orbwalker.GetMode() == "Combo" then
            E:Cast()
        end
        if Mundo.IsEnabledAndReady("Harass", E) and Orbwalker.GetMode() == "Harass" then
            E:Cast()
        end
    end
    if target.IsMinion and Orbwalker.GetMode() == "Waveclear" then
        if target.IsNeutral then
            if Mundo.IsEnabledAndReady("Jungleclear", E) then
                E:Cast()
            end
        elseif target.IsEnemy then
            if Mundo.IsEnabledAndReady("Waveclear", E) then
                E:Cast()
            end
        end
    end
end

function Mundo.OnDraw()
    local spells = {Q, W}
    local playerPos = Player.Position
    for k, v in pairs(spells) do
        if Menu.Get("Draw" .. v.RawSpell) then
            Renderer.DrawCircle3D(playerPos, v.Range, 30, 1, Menu.Get("Color" .. v.RawSpell))
        end
    end
end

function OnLoad()
    for eventName, eventId in pairs(Events) do
        if Mundo[eventName] then
            EventManager.RegisterCallback(eventId, Mundo[eventName])
        end
    end
    print("[" .. author .. "]" .. scriptName .. " Version: " .. version)
    return true
end
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
