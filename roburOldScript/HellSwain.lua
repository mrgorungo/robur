--[[
  _    _      _ _    _____              _       
 | |  | |    | | |  / ____|            (_)      
 | |__| | ___| | | | (_____      ____ _ _ _ __  
 |  __  |/ _ \ | |  \___ \ \ /\ / / _` | | '_ \ 
 | |  | |  __/ | |  ____) \ V  V / (_| | | | | |
 |_|  |_|\___|_|_| |_____/ \_/\_/ \__,_|_|_| |_|
                                                                                                                                                                               
]]
if Player.CharName ~= "Swain" then
    return
end
local scriptName = "HellSwain"
local author = "48656c6c636174"
local version = "2.0"
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
local Swain = {}
local SwainLP = {}
local SwainNP = {}
local SwainHP = {}
local DamageTick = 0
local TotalDamage = 0
local LastTick = 0
local RDmgFunc = false
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---[Spells]----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
local Q =
    SpellLib.Skillshot(
    {
        Slot = SpellSlots.Q,
        RawSpell = "Q",
        Range = 725,
        Radius = 50,
        Speed = mathHuge,
        Delay = 0.25,
        Type = "Linear",
        Collisions = {WindWall = true},
        UseHitbox = true
    }
)

local W =
    SpellLib.Skillshot(
    {
        Slot = SpellSlots.W,
        RawSpell = "W",
        Range = 5000,
        Radius = 325,
        Speed = mathHuge,
        Delay = 1.75,
        Type = "Circular"
    }
)

local E =
    SpellLib.Skillshot(
    {
        Slot = SpellSlots.E,
        RawSpell = "E",
        Range = 900,
        Radius = 100,
        Speed = 935,
        Delay = 0.25,
        Type = "Linear",
        Collisions = {Heroes = true, Minions = true, WindWall = true},
        UseHitbox = true
    }
)

local R =
    SpellLib.Active(
    {
        Slot = SpellSlots.R,
        RawSpell = "R",
        Range = 650,
        Delay = 0.25
    }
)

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---[Menu]------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Swain.Menu()
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
            Menu.Checkbox("Harass.UseE", "Use E", true)
            Menu.Slider("Harass.MinManaE", "% Mana Limit", 15, 0, 100, 1)
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
            Menu.Slider("Lasthit.TargetsQ", "Minimum Targets", 1, 1, 5, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "Waveclear",
        "Waveclear Settings",
        function()
            Menu.Checkbox("Waveclear.UseQ", "Use Q", true)
            Menu.Slider("Waveclear.MinManaQ", "% Mana Limit", 15, 0, 100, 1)
            Menu.Slider("Waveclear.TargetsQ", "Minimum Minions", 1, 1, 5, 1)
            Menu.Checkbox("Waveclear.UseW", "Use W", false)
            Menu.Slider("Waveclear.MinManaW", "% Mana Limit", 15, 0, 100, 1)
            Menu.Slider("Waveclear.TargetsW", "Minimum Minions", 1, 1, 5, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "Jungleclear",
        "Jungleclear Settings",
        function()
            Menu.Checkbox("Jungleclear.UseQ", "Use Q", true)
            Menu.Slider("Jungleclear.MinManaQ", "% Mana Limit", 15, 0, 100, 1)
            Menu.Slider("Jungleclear.TargetsQ", "Minimum Minions", 1, 1, 5, 1)
            Menu.Checkbox("Jungleclear.UseW", "Use W", false)
            Menu.Slider("Jungleclear.MinManaW", "% Mana Limit", 15, 0, 100, 1)
            Menu.Slider("Jungleclear.TargetsW", "Minimum Minions", 1, 1, 5, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "Killsteal",
        "Killsteal Settings",
        function()
            Menu.Checkbox("Killsteal.UseQ", "Use Q", true)
            Menu.Slider("Killsteal.MinManaQ", "% Mana Limit", 0, 0, 100, 1)
            Menu.Checkbox("Killsteal.UseW", "Use W", true)
            Menu.Slider("Killsteal.MinManaW", "% Mana Limit", 0, 0, 100, 1)
            Menu.Checkbox("Killsteal.UseE", "Use E", false)
            Menu.Slider("Killsteal.MinManaE", "% Mana Limit", 0, 0, 100, 1)
            Menu.Checkbox("Killsteal.UseR", "Use R", false)
            Menu.Slider("Killsteal.MinManaR", "% Mana Limit", 0, 0, 100, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "AntiGapcloser",
        "AntiGapcloser Settings",
        function()
            Menu.Checkbox("AntiGapcloser.UseW", "Use W", false)
            Menu.Slider("AntiGapcloser.MinManaW", "% Mana Limit", 0, 0, 100, 1)
            Menu.Checkbox("AntiGapcloser.UseE", "Use E", false)
            Menu.Slider("AntiGapcloser.MinManaE", "% Mana Limit", 0, 0, 100, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "Miscellaneous",
        "Miscellaneous Settings",
        function()
            Menu.Checkbox("Auto.Passive", "Auto Trigger Passive", true)
            Menu.Checkbox("Flee.UseE", "Use E on Flee", true)
            Menu.Slider("Flee.MinManaE", "% Mana Limit", 0, 0, 100, 1)
        end
    )
    Menu.NewTree(
        scriptName .. "Prediction",
        "Prediction Settings",
        function()
            Menu.Slider("HitChanceQ", "Q Hit Chance", 0.75, 0.05, 1, 0.05)
            Menu.Slider("HitChanceW", "W Hit Chance", 0.75, 0.05, 1, 0.05)
            Menu.Slider("HitChanceE", "E Hit Chance", 0.75, 0.05, 1, 0.05)
        end
    )
    Menu.NewTree(
        scriptName .. "Drawings",
        "Drawings Settings",
        function()
            Menu.Checkbox("DrawQ", "Draw Q Range", true)
            Menu.ColorPicker("ColorQ", "Draw Q Color", 0xEF476FFF)
            Menu.Checkbox("DrawW", "Draw W Range on Minimap", true)
            Menu.ColorPicker("ColorW", "Draw W Color", 0x06D6A0FF)
            Menu.Checkbox("DrawE", "Draw E Range", true)
            Menu.ColorPicker("ColorE", "Draw E Color", 0x118AB2FF)
            Menu.Checkbox("DrawR", "Draw R Range", true)
            Menu.ColorPicker("ColorR", "Draw R Color", 0xFFD166FF)
        end
    )
end
Menu.RegisterMenu(scriptName, scriptName .. " Menu", Swain.Menu)
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

function Swain.IsEnabledAndReady(mode, spell)
    local ManaLimit = Menu.Get(mode .. ".MinMana" .. spell.RawSpell) / 100
    if ManaLimit > Player.ManaPercent then
        return
    end
    return Menu.Get(mode .. ".Use" .. spell.RawSpell) and spell:IsReady()
end

function Swain.GetMinDamageQ()
    return 35 + Q:GetLevel() * 20 + Player.TotalAP * 0.4
end

function Swain.GetMaxDamageQ()
    local eDmg = {88, 135, 190, 253, 324}
    local eAp = {0.64, 0.72, 0.80, 0.88, 0.96}
    return eDmg[Q:GetLevel()] + Player.TotalAP * eAp[Q:GetLevel()]
end

function Swain.GetRawDamageW()
    return 40 + W:GetLevel() * 40 + Player.TotalAP * 0.7
end

function Swain.GetWRange()
    return 5000 + 500 * W:GetLevel()
end

function Swain.GetRawDamageE()
    return 25 + E:GetLevel() * 45 + Player.TotalAP * 0.5
end

function Swain.GetMinDamageR()
    return 50 + R:GetLevel() * 50 + Player.TotalAP * 0.5
end

function Swain.GetTickDamageR2(numTargets)
    return (5 + R:GetLevel() * 15 + Player.TotalAP * 0.16) * numTargets * 0.375
end

function Swain.GetMaxDamageR()
    return 100 + R:GetLevel() * 100 + Player.TotalAP
end

function Swain.QLogic(mode)
    if not Swain.IsEnabledAndReady(mode, Q) then
        return
    end
    local target = Q:GetTarget()
    if not target then
        return
    end
    local targetPos = target.Position
    local targetHP = Q:GetHealthPred(target)
    if mode == "Killsteal" then
        if Player:Distance(targetPos) < 150 then
            local QDamage = DamageLib.CalculateMagicalDamage(Player, target, Swain.GetMaxDamageQ())
            if targetHP < QDamage then
                if Q:Cast(target) then
                    return
                end
            end
        elseif Player:Distance(targetPos) > 625 then
            local QDamage = DamageLib.CalculateMagicalDamage(Player, target, Swain.GetMinDamageQ())
            if targetHP < QDamage then
                if Q:Cast(target) then
                    return
                end
            end
        else
            local QDamage = DamageLib.CalculateMagicalDamage(Player, target, Swain.GetMaxDamageQ() * 0.75)
            if targetHP < QDamage then
                if Q:Cast(target) then
                    return
                end
            end
        end
    else
        if Q:CastOnHitChance(target, Menu.Get("HitChanceQ")) then
            return
        end
    end
end

function Swain.WLogic(mode)
    if not Swain.IsEnabledAndReady(mode, W) then
        return
    end
    local target = W:GetTarget()
    if not target then
        return
    end
    if mode == "Killsteal" then
        local wDmg = DamageLib.CalculateMagicalDamage(Player, target, Swain.GetRawDamageW())
        if wDmg < W:GetHealthPred(target) then
            return
        end
        if W:CastOnHitChance(target, Menu.Get("HitChanceW")) then
            return
        end
    else
        if W:CastOnHitChance(target, Menu.Get("HitChanceW")) then
            return
        end
    end
end

function Swain.ELogic(mode)
    if not Swain.IsEnabledAndReady(mode, E) then
        return
    end
    local target = E:GetTarget()
    if not target then
        return
    end
    local playerPos = Player.Position
    local endPos = playerPos:Extended(target.Position, E.Range)
    local eCollision = E:GetFirstCollision(endPos, playerPos, "enemy")
    local eCollisionTable, eCollisionResult = eCollision.Objects, eCollision.Result
    if eCollisionResult then
        for k, v in pairs(eCollisionTable) do
            if v.IsMinion then
                local checkSplash = Player:Distance(v.Position) < Player:Distance(target.Position) - E.Radius
                if checkSplash then
                    E.Collisions = {WindWall = true}
                    if E:CastOnHitChance(target, Menu.Get("HitChanceE")) then
                        return
                    end
                end
            elseif v.IsHero then
                E.Collisions = {WindWall = true}
                if E:CastOnHitChance(target, Menu.Get("HitChanceE")) then
                    return
                end
            end
        end
    else
        E.Collisions = {WindWall = true}
        if E:CastOnHitChance(target, Menu.Get("HitChanceE")) then
            return
        end
    end
end

function Swain.RDamage(numTargets)
    if numTargets > 0 then
        DamageTick = DamageTick + Swain.GetTickDamageR2(numTargets)
        if DamageTick > Swain.GetMaxDamageR() then
            TotalDamage = Swain.GetMaxDamageR()
        else
            TotalDamage = DamageTick + Swain.GetMinDamageR()
        end
    end
end

function Swain.RLogic(mode)
    if not Swain.IsEnabledAndReady(mode, R) then
        return
    end
    local targets = R:GetTargets()
    local numTargets = tLenght(targets)
    if numTargets == 0 then
        return
    end
    if not RDmgFunc and mode ~= "Killsteal" then
        if numTargets < Menu.Get(mode .. ".TargetsR") then
            return
        elseif R:Cast() then
            return
        end
    else
        for k, v in pairs(targets) do
            local finalDamage = DamageLib.CalculateMagicalDamage(Player, v, TotalDamage)
            local ksHealth = HealthPred.GetKillstealHealth(v, R.Delay, DamageTypes.Magical)
            if ksHealth < finalDamage then
                if R:Cast() then
                    return
                end
            end
        end
    end
end

function Swain.QClear(type, mode)
    if not Swain.IsEnabledAndReady(mode, Q) then
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
                local qDmg = DamageLib.CalculateMagicalDamage(Player, minion, Swain.GetMinDamageQ())
                if Q:GetHealthPred(minion) < qDmg then
                    Orbwalker.IgnoreMinion(minion)
                    tInsert(minionPos, v.Position)
                end
            else
                tInsert(minionPos, v.Position)
            end
        end
    end
    local bestPos, hitCount = BestCoveringCone(minionPos, Player.Position, mathRad(32))
    if not bestPos or hitCount < Menu.Get(mode .. ".TargetsQ") then
        return
    end
    if Q:Cast(bestPos) then
        return
    end
end

function Swain.WClear(type, mode)
    if not Swain.IsEnabledAndReady(mode, W) then
        return
    end
    local minions = ObjectManager.GetNearby(type, "minions")
    if tLenght(minions) == 0 then
        return
    end
    local minionPos = {}
    for k, v in pairs(minions) do
        if CheckMinions(v, W) then
            if mode == "Lasthit" then
                local minion = v.AsAI
                local wDmg = DamageLib.CalculateMagicalDamage(Player, minion, Swain.GetRawDamageW())
                if W:GetHealthPred(minion) < wDmg then
                    Orbwalker.IgnoreMinion(minion)
                    tInsert(minionPos, v.Position)
                end
            else
                tInsert(minionPos, v.Position)
            end
        end
    end
    local bestPos, hitCount = BestCoveringCircle(minionPos, W.Radius)
    if not bestPos or hitCount < Menu.Get(mode .. ".TargetsW") then
        return
    end
    if W:Cast(bestPos) then
        return
    end
end

function SwainNP.Combo()
    Swain.QLogic("Combo")
    Swain.WLogic("Combo")
    Swain.ELogic("Combo")
end
function SwainHP.Combo()
    Swain.RLogic("Combo")
end

function SwainNP.Harass()
    Swain.QLogic("Harass")
    Swain.WLogic("Harass")
    Swain.ELogic("Harass")
end
function SwainHP.Harass()
    Swain.RLogic("Harass")
end

function SwainHP.Lasthit()
    Swain.QClear("enemy", "Lasthit")
    Swain.QClear("neutral", "Lasthit")
end

function SwainNP.Waveclear()
    Swain.WClear("enemy", "Waveclear")
    Swain.WClear("neutral", "Jungleclear")
end
function SwainHP.Waveclear()
    Swain.QClear("enemy", "Waveclear")
    Swain.QClear("neutral", "Jungleclear")
end

function SwainHP.Killsteal()
    Swain.QLogic("Killsteal")
    Swain.WLogic("Killsteal")
    Swain.ELogic("Killsteal")
    Swain.RLogic("Killsteal")
end

function SwainLP.Flee()
    Swain.ELogic("Flee")
end

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---[Events]----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function Swain.OnHighPriority()
    if not GameIsAvailable() then
        return
    end
    if SwainHP.Killsteal() then
        return
    end
    local ModeToExecute = SwainHP[Orbwalker.GetMode()]
    if ModeToExecute then
        ModeToExecute()
    end
end

function Swain.OnNormalPriority()
    if not GameIsAvailable() then
        return
    end
    local ModeToExecute = SwainNP[Orbwalker.GetMode()]
    if ModeToExecute then
        ModeToExecute()
    end
end

function Swain.OnLowPriority()
    if not GameIsAvailable() then
        return
    end
    local ModeToExecute = SwainLP[Orbwalker.GetMode()]
    if ModeToExecute then
        ModeToExecute()
    end
end

function Swain.OnHeroImmobilized(Source, EndTime, IsStasis)
    if not Source.IsEnemy then
        return
    end
    if not Menu.Get("Auto.Passive") or Orbwalker.GetMode() == "Flee" then
        return
    end
    for k, v in pairs(ObjectManager.GetNearby("all", "particles")) do
        if v.Name == "Swain_Base_P_indicator" then
            return Input.Attack(Source)
        end
    end
end

function Swain.OnGapclose(Source, DashInst)
    if not Source.IsEnemy then
        return
    end
    Swain.WLogic("AntiGapcloser")
    Swain.ELogic("AntiGapcloser")
end

function Swain.OnTick()
    if not RDmgFunc then
        return
    end
    local gameTime = Game.GetTime()
    if gameTime < (LastTick + 1) then
        return
    end
    LastTick = gameTime
    Swain.RDamage(tLenght(R:GetTargets()))
end

function Swain.OnBuffGain(obj, buff)
    if not obj.IsMe or buff.Name ~= "SwainR" then
        return
    end
    RDmgFunc = true
    DamageTick = 0
end

function Swain.OnBuffLost(obj, buff)
    if not obj.IsMe or buff.Name ~= "SwainR" then
        return
    end
    RDmgFunc = false
    DamageTick = 0
    TotalDamage = 0
end

function Swain.OnDraw()
    if W.Range ~= Swain.GetWRange() then
        W.Range = Swain.GetWRange()
    end
    local spells = {Q, W, E, R}
    local playerPos = Player.Position
    for k, v in pairs(spells) do
        if Menu.Get("Draw" .. v.RawSpell) then
            if v == W then
                Renderer.DrawCircleMM(playerPos, v.Range, 2, Menu.Get("Color" .. v.RawSpell))
            else
                Renderer.DrawCircle3D(playerPos, v.Range, 30, 1, Menu.Get("Color" .. v.RawSpell))
            end
        end
    end
end

function OnLoad()
    for eventName, eventId in pairs(Events) do
        if Swain[eventName] then
            EventManager.RegisterCallback(eventId, Swain[eventName])
        end
    end
    print("[" .. author .. "]" .. scriptName .. " Version: " .. version)
    return true
end
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------