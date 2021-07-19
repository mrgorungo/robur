--[[
  _    _      _ _ _____       _         
 | |  | |    | | |  __ \     | |        
 | |__| | ___| | | |__) |   _| | _____  
 |  __  |/ _ \ | |  ___/ | | | |/ / _ \ 
 | |  | |  __/ | | |   | |_| |   <  __/ 
 |_|  |_|\___|_|_|_|    \__, |_|\_\___| 
                         __/ |          
                        |___/                                                                                                                                                                
]]
if Player.CharName ~= "Pyke" then
    return
end
local scriptName = "HellPyke"
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
local Pyke = {}
local PykeLP = {}
local PykeNP = {}
local PykeHP = {}
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---[Spells]----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
local Q =
    SpellLib.Chargeable(
    {
        Slot = SpellSlots.Q,
        RawSpell = "Q",
        Range = 1100,
        Radius = 70,
        Speed = 2000,
        Delay = 0.25,
        Type = "Linear",
        Collisions = {Minions = true, WindWall = true},
        UseHitbox = true,
        MinRange = 400,
        MaxRange = 1100,
        FullChargeTime = 1
    }
)

local W =
    SpellLib.Active(
    {
        Slot = SpellSlots.W,
        RawSpell = "W",
        Range = 900
    }
)

local E =
    SpellLib.Skillshot(
    {
        Slot = SpellSlots.E,
        RawSpell = "E",
        Range = 475,
        Radius = 110,
        Speed = 3000,
        Delay = 0,
        Type = "Linear"
    }
)

local R =
    SpellLib.Skillshot(
    {
        Slot = SpellSlots.R,
        RawSpell = "R",
        Range = 750,
        Radius = 250,
        Speed = mathHuge,
        Type = "Circular",
        Delay = 0.5
    }
)

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---[Menu]------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Pyke.Menu()
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
            Menu.Checkbox("Combo.UseR", "Use R", true)
            Menu.Slider("Combo.MinManaR", "% Mana Limit", 15, 0, 100, 1)
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
            Menu.Checkbox("Harass.UseE", "Use E", true)
            Menu.Slider("Harass.MinManaE", "% Mana Limit", 15, 0, 100, 1)
            Menu.Checkbox("Harass.UseR", "Use R", false)
            Menu.Slider("Harass.MinManaR", "% Mana Limit", 15, 0, 100, 1)
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
        end
    )
    Menu.NewTree(
        scriptName .. "Jungleclear",
        "Jungleclear Settings",
        function()
            Menu.Checkbox("Jungleclear.UseQ", "Use Q", true)
            Menu.Slider("Jungleclear.MinManaQ", "% Mana Limit", 15, 0, 100, 1)
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
        end
    )
    Menu.NewTree(
        scriptName .. "AntiGapcloser",
        "AntiGapcloser Settings",
        function()
            Menu.Checkbox("AntiGapcloser.UseE", "Use E", false)
            Menu.Slider("AntiGapcloser.MinManaE", "% Mana Limit", 0, 0, 100, 1)
            Menu.Slider("AntiGapcloser.MinHPE", "% HP Below", 15, 1, 100, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "Miscellaneous",
        "Miscellaneous Settings",
        function()
            Menu.Checkbox("Block.UseQ", "Block Q Stab on Combo/Harass", false)
            Menu.Slider("Trigger.RangeW", "W Trigger Range on Combo/Harass", 900, 600, 1500, 50)
            Menu.Checkbox("Flee.UseW", "Use W on Flee", true)
            Menu.Slider("Flee.MinManaW", "% Mana Limit", 0, 0, 100, 1)
            Menu.Checkbox("Flee.UseE", "Use E on Flee", true)
            Menu.Slider("Flee.MinManaE", "% Mana Limit", 0, 0, 100, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "Prediction",
        "Prediction Settings",
        function()
            Menu.Slider("HitChanceQ", "Q Hit Chance", 0.75, 0.05, 1, 0.05)
            Menu.Slider("HitChanceR", "R Hit Chance", 0.75, 0.05, 1, 0.05)
        end
    )
    Menu.NewTree(
        scriptName .. "Drawings",
        "Drawings Settings",
        function()
            Menu.Checkbox("DrawQ", "Draw Q Range", true)
            Menu.ColorPicker("ColorQ", "Draw Q Color", 0xEF476FFF)
            Menu.Checkbox("DrawW", "Draw W Trigger Range", true)
            Menu.ColorPicker("ColorW", "Draw W Color", 0x118AB2FF)
            Menu.Checkbox("DrawE", "Draw E Range", true)
            Menu.ColorPicker("ColorE", "Draw E Color", 0x118AB2FF)
            Menu.Checkbox("DrawR", "Draw R Range", true)
            Menu.ColorPicker("ColorR", "Draw R Color", 0xFFD166FF)
        end
    )
end
Menu.RegisterMenu(scriptName, scriptName .. " Menu", Pyke.Menu)
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

function Pyke.IsEnabledAndReady(mode, spell)
    local ManaLimit = Menu.Get(mode .. ".MinMana" .. spell.RawSpell) / 100
    if ManaLimit > Player.ManaPercent then
        return
    end
    return Menu.Get(mode .. ".Use" .. spell.RawSpell) and spell:IsReady()
end

function Pyke.GetRawDamageQ()
    return 35 + Q:GetLevel() * 50 + Player.BonusAD * 0.6
end

function Pyke.GetRawDamageE()
    return 75 + E:GetLevel() * 30 + Player.BonusAD
end

function Pyke.GetRawDamageR()
    local healthDmg = {0, 0, 0, 0, 0, 250, 290, 330, 370, 400, 430, 450, 470, 490, 510, 530, 540, 550}
    return healthDmg[Player.Level] + Player.BonusAD * 0.8 + Player.PhysicalLethality * 1.5
end

function Pyke.QLogic(mode)
    if not Pyke.IsEnabledAndReady(mode, Q) then
        return
    end
    if mode == "Killsteal" then
        local target = Q:GetTarget()
        if not target then
            return
        end
        local qDmg = DamageLib.CalculatePhysicalDamage(Player, target, Pyke.GetRawDamageQ())
        if Q:GetHealthPred(target) > qDmg then
            return
        end
        if Q:Cast(target) then
            Q:Release(target.Position)
            return
        end
    else
        local target = TargetSelector:GetTarget(Q.MaxRange, true)
        if not target then
            return
        end
        if Q:Cast(target) then
            return
        end
        if Q:IsInRange(target) then
            local collision = Q:GetFirstCollision(Player.Position, target.Position, "enemy")
            local QPrediction = Q:GetPrediction(target)
            if collision.Result or not QPrediction then
                return
            end
            if QPrediction.HitChance < Menu.Get("HitChanceQ") then
                return
            end
            if Menu.Get("Block.UseQ") and Q.Range < 550 then
                return
            end
            if Q:Release(QPrediction.CastPosition) then
                return
            end
        end
    end
end

function Pyke.WLogic(mode)
    if not Pyke.IsEnabledAndReady(mode, W) then
        return
    end
    if mode == "Flee" then
        if W:Cast() then
            return
        end
    else
        local target = TargetSelector:GetTarget(Menu.Get("Trigger.RangeW"), false)
        if not target then
            return
        end
        if Player:Distance(target) < Q.MinRange then
            return
        end
        if W:Cast() then
            return
        end
    end
end

function Pyke.ELogic(mode)
    if not Pyke.IsEnabledAndReady(mode, E) then
        return
    end
    if mode == "Flee" then
        if E:Cast(Renderer.GetMousePos()) then
            return
        end
    else
        local target = E:GetTarget()
        if not target then
            return
        end
        local endPos = Player.Position:Extended(target.Position, E.Range)
        if E:Cast(endPos) then
            return
        end
    end
end

function Pyke.RLogic(mode)
    if not Pyke.IsEnabledAndReady(mode, R) then
        return
    end
    local targets = R:GetTargets()
    if tLenght(targets) == 0 then
        return
    end
    for k, target in pairs(targets) do
        if target.Health < Pyke.GetRawDamageR() then
            if R:CastOnHitChance(target, Menu.Get("HitChanceR")) then
                return
            end
        end
    end
end

function Pyke.QClear(type, mode)
    if not Pyke.IsEnabledAndReady(mode, Q) then
        return
    end
    local minions = ObjectManager.GetNearby(type, "minions")
    if tLenght(minions) == 0 then
        return
    end
    for k, v in pairs(minions) do
        if CheckMinions(v, Q) then
            local minion = v.AsAI
            local qDmg = DamageLib.CalculatePhysicalDamage(Player, minion, Pyke.GetRawDamageQ())
            if Q:GetHealthPred(minion) < qDmg then
                Orbwalker.IgnoreMinion(minion)
                Q:Cast(minion)
                if Q:GetRange() < 500 then
                    if Q:Release(minion.Position) then
                        return
                    end
                end
            end
        end
    end
end

function PykeNP.Combo()
    Pyke.WLogic("Combo")
    Pyke.QLogic("Combo")
    Pyke.ELogic("Combo")
end
function PykeHP.Combo()
    Pyke.RLogic("Combo")
end

function PykeNP.Harass()
    Pyke.WLogic("Harass")
    Pyke.QLogic("Harass")
    Pyke.ELogic("Harass")
end
function PykeHP.Harass()
    Pyke.RLogic("Harass")
end

function PykeHP.Lasthit()
    Pyke.QClear("enemy", "Lasthit")
    Pyke.QClear("neutral", "Lasthit")
end

function PykeHP.Waveclear()
    Pyke.QClear("enemy", "Waveclear")
    Pyke.QClear("neutral", "Jungleclear")
end

function PykeHP.Killsteal()
    Pyke.RLogic("Killsteal")
    Pyke.QLogic("Killsteal")
end

function PykeLP.Flee()
    Pyke.ELogic("Flee")
    Pyke.WLogic("Flee")
end

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---[Events]----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function Pyke.OnHighPriority()
    if not GameIsAvailable() then
        return
    end
    if PykeHP.Killsteal() then
        return
    end
    local ModeToExecute = PykeHP[Orbwalker.GetMode()]
    if ModeToExecute then
        ModeToExecute()
    end
end

function Pyke.OnNormalPriority()
    if not GameIsAvailable() then
        return
    end
    local ModeToExecute = PykeNP[Orbwalker.GetMode()]
    if ModeToExecute then
        ModeToExecute()
    end
end

function Pyke.OnLowPriority()
    if not GameIsAvailable() then
        return
    end
    local ModeToExecute = PykeLP[Orbwalker.GetMode()]
    if ModeToExecute then
        ModeToExecute()
    end
end

function Pyke.OnGapclose(Source, DashInst)
    if not Source.IsEnemy then
        return
    end
    local QCD = Player:GetSpell(Q.Slot)
    if QCD.TotalCooldown - QCD.RemainingCooldown < 1 then
        return
    end
    if Menu.Get("AntiGapcloser.MinHPE") < Player.HealthPercent then
        return
    end
    if not Pyke.IsEnabledAndReady("AntiGapcloser", E) then
        return
    end
    for k, v in pairs(DashInst:GetPaths()) do
        if Player:Distance(v.EndPos) < E.Range then
            local bestPos = Player.Position:Extended(v.EndPos, -E.Range + 65)
            if E:Cast(bestPos) then
                return
            end
        end
    end
end

function Pyke.OnDraw()
    if W.Range ~= Menu.Get("Trigger.RangeW") then
        W.Range = Menu.Get("Trigger.RangeW")
    end
    local spells = {Q, W, E, R}
    local playerPos = Player.Position
    for k, v in pairs(spells) do
        if Menu.Get("Draw" .. v.RawSpell) then
            Renderer.DrawCircle3D(playerPos, v.Range, 30, 1, Menu.Get("Color" .. v.RawSpell))
        end
    end
end

function OnLoad()
    for eventName, eventId in pairs(Events) do
        if Pyke[eventName] then
            EventManager.RegisterCallback(eventId, Pyke[eventName])
        end
    end
    print("[" .. author .. "]" .. scriptName .. " Version: " .. version)
    return true
end
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------