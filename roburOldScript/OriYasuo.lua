--[[
    First release by Orietto @ March 10th, 2021
    Update 1.1 by Orietto @ March 12th, 2021
    Update 1.11 by Orietto @ March 12th, 2021
    Update 1.13 by Orietto @ March 21st, 2021
    Update 1.14 by Orietto @ April 1st, 2021
--]]

if Player.CharName ~= "Yasuo" then return end

require("common.log")
module("Ori Yasuo", package.seeall, log.setup)
clean.module("Ori Yasuo", clean.seeall, log.setup)

local clock = os.clock
local insert, sort = table.insert, table.sort
local huge, min, max, abs, ceil, pi, sin, cos = math.huge, math.min, math.max, math.abs, math.ceil, math.pi, math.sin, math.cos

local _SDK = _G.CoreEx
local Console, ObjManager, EventManager, Geometry, Input, Renderer, Enums, Game = _SDK.Console, _SDK.ObjectManager, _SDK.EventManager, _SDK.Geometry, _SDK.Input, _SDK.Renderer, _SDK.Enums, _SDK.Game
local Menu, Orbwalker, Collision, Prediction, HealthPred = _G.Libs.NewMenu, _G.Libs.Orbwalker, _G.Libs.CollisionLib, _G.Libs.Prediction, _G.Libs.HealthPred
local DmgLib, ImmobileLib, Spell = _G.Libs.DamageLib, _G.Libs.ImmobileLib, _G.Libs.Spell
local Vector = Geometry.Vector

local Slots = {
    Q = Enums.SpellSlots.Q,
    W = Enums.SpellSlots.W,
    E = Enums.SpellSlots.E,
    R = Enums.SpellSlots.R
}

local Player = ObjManager.Player

local TS = _G.Libs.TargetSelector()

local Yasuo = {}

Yasuo.Version = "1.14"

Yasuo.Events = {}

Yasuo.MainColor = 0x0BDFE3FF

Yasuo.Dash = {}
Yasuo.Dash.LastQProcT = 0
Yasuo.Dash.LastEProcT = 0
Yasuo.Dash.LastDashEndT = 0
Yasuo.Dash.IsDashing = 0

Yasuo.EnemiesRBuffs = {}

Yasuo.Debug = {}
Yasuo.Debug.DashableObj = nil

Yasuo.LastCastT = {
    [Slots.Q] = 0,
    [Slots.W] = 0,
    [Slots.E] = 0,
    [Slots.R] = 0,
}

Yasuo.Spells = {
    Q1 = Spell.Skillshot({
        Slot = Slots.Q,
        Delay = 0.4,
        Speed = huge,
        Range = 475,
        Radius = 45 / 2,
        Type = "Linear"
    }),
    Q3 = Spell.Skillshot({
        Slot = Slots.Q,
        Delay = 0.4,
        Speed = 1200,
        Range = 1050,
        Radius = 90 / 2,
        Type = "Linear"
    }),
    W = Spell.Skillshot({
        Slot = Slots.W,
        Range = 400,
        Type = "Linear"
    }),
    QCircle = {
        Radius = 220,
        MinDistToEnd = 300
    },
    E = Spell.Targeted({
        Slot = Slots.E,
        Speed = 750,
        Range = 475
    }),
    R = Spell.Skillshot({
        Slot = Slots.R,
        Delay = 0,
        Speed = huge,
        Range = 1400,
        Radius = 400,
        Type = "Circular"
    })
}

Yasuo.Damages = {
    Q = {
        Base = {20, 45, 70, 95, 120},
        TotalAD = 1.0,
        Type = Enums.DamageTypes.Physical
    },
    E = {
        Base = {60, 70, 80, 90, 100},
        BonusAD = 0.2,
        TotalAP = 0.6,
        Type = Enums.DamageTypes.Magical
    },
    R = {
        Base = {200, 300, 400},
        BonusAD = 1.5,
        Type = Enums.DamageTypes.Physical
    }
}

Yasuo.Ignite = {
    Slot = nil,
    LastCastT = 0,
    LastCheckT = 0
}

Yasuo.Flash = {
    Slot = nil,
    LastCastT = 0,
    LastCheckT = 0,
    Range = 400
}

Yasuo.Beyblade = {
    LastCastT = 0
}

Yasuo.G = {
    Q3BuffEndT = nil
}

---@param unit AIHeroClient|AIMinionClient
function Yasuo.IsValidTarget(unit, radius, fromPos)
    fromPos = fromPos or Player.Position

    return unit and unit.MaxHealth > 6 and TS:IsValidTarget(unit, radius, fromPos)
end

function Yasuo.CastSpell(slot, pos_unit)
    return Input.Cast(slot, pos_unit)
end

function Yasuo.CastIgnite(unit)
    if not Yasuo.Ignite.Slot then return end

    local curTime = Game.GetTime()
    if curTime < Yasuo.Ignite.LastCastT + 0.25 then return false end

    return Yasuo.CastSpell(Yasuo.Ignite.Slot, unit)
end

function Yasuo.CastFlash(pos)
    if not Yasuo.Flash.Slot then return end

    local curTime = Game.GetTime()
    if curTime < Yasuo.Flash.LastCastT + 0.25 then return false end

    return Yasuo.CastSpell(Yasuo.Flash.Slot, pos)
end

function Yasuo.CastQ(pos)
    --if Game.GetTime() < Yasuo.Dash.LastEProcT + 0.15 then return false end
    local curTime = Game.GetTime()
    if curTime < Yasuo.LastCastT[Slots.Q] + 0.25 then return false end
    if curTime < Yasuo.LastCastT[Slots.E] + 0.15 then return false end

    if Orbwalker.IsWindingUp() then return false end

    return Yasuo.CastSpell(Slots.Q, pos)
end

function Yasuo.CastW(pos)
    local curTime = Game.GetTime()
    if curTime < Yasuo.LastCastT[Slots.W] + 0.25 then return false end

    return Yasuo.CastSpell(Slots.W, pos)
end

---@param unit AIHeroClient|AIMinionClient
function Yasuo.CastE(unit)
    --if Game.GetTime() < Yasuo.Dash.LastQProcT + 0.15 then return false end
    local curTime = Game.GetTime()
    if curTime < Yasuo.LastCastT[Slots.E] + 0.25 then return false end
    if curTime < Yasuo.LastCastT[Slots.Q] + 0.15 then return false end

    if Orbwalker.IsWindingUp() then return false end

    return Yasuo.CastSpell(Slots.E, unit)
end

---@param pos Vector
function Yasuo.CastR(pos)
    local curTime = Game.GetTime()
    if curTime < Yasuo.LastCastT[Slots.R] + 0.25 then return false end

    return Yasuo.CastSpell(Slots.R, pos)
end

function Yasuo.IsDashingInternal()
    return Player.Pathing.IsDashing
end

function Yasuo.IsDashing()
    --[[
    if Yasuo.IsDashingInternal() then
        return true
    elseif Game.GetTime() <= Yasuo.Dash.LastDashEndT + 0.1 then
        return true
    end

    return false
    --]]

    return Yasuo.IsDashingInternal()
end

function Yasuo.MyDashCallback()
    if Yasuo.IsDashingInternal() and not Yasuo.Dash.IsDashing then
        Yasuo.Dash.IsDashing = true
        EventManager.FireEvent("OnMyDash", true)
    elseif not Yasuo.IsDashingInternal() and Yasuo.Dash.IsDashing then
        Yasuo.Dash.IsDashing = false
        EventManager.FireEvent("OnMyDash", false)
    end
end

function Yasuo.GetQDelay()
    local bonusASPercent = (Player.AttackSpeedMod - 1) * 100
    return 0.4 * (1 - (0.01 * min(bonusASPercent, 111.1) / 1.67))
end

function Yasuo.IsSpellReady(slot)
    return Player:GetSpellState(slot) == Enums.SpellStates.Ready
end

function Yasuo.HasQ3()
    return Player:GetSpell(Slots.Q).Name == "YasuoQ3Wrapper"
end

function Yasuo.GetDashEndPos()
    return Yasuo.IsDashing() and Player.Pathing.EndPos or false
end

function Yasuo.GetEnemyAndJungleMinions(radius, fromPos)
    fromPos = fromPos or Player.Position

    local function AddIfValid(group, addTo)
        ---@param obj GameObject
        for handle, obj in pairs(group) do
            local minion = obj.AsMinion
            if Yasuo.IsValidTarget(minion, radius, fromPos) then
                addTo[#addTo + 1] = minion
            end
        end
    end

    local result = {}

    local enemyMinions = ObjManager.GetNearby("enemy", "minions")
    local jungleMinions = ObjManager.GetNearby("neutral", "minions")

    AddIfValid(enemyMinions, result)
    AddIfValid(jungleMinions, result)

    return result
end

---@param forcedHero AIHeroClient
function Yasuo.PosHasQCircleTargets(pos, forcedHero)
    local hasHero, hasMinion = false, false

    local qCircle = Yasuo.Spells.QCircle

    if Player.Position:Distance(pos) > qCircle.MinDistToEnd then
        return false, false
    end

    local enemyHeroes = ObjManager.Get("enemy", "heroes")

    ---@param obj GameObject
    for handle, obj in pairs(enemyHeroes) do
        local hero = obj.AsHero
        if Yasuo.IsValidTarget(hero, qCircle.Radius, pos) then
            if forcedHero and forcedHero.Handle == handle or not forcedHero then
                hasHero = true
                break
            end
        end
    end

    local minions = Yasuo.GetEnemyAndJungleMinions(qCircle.Radius, pos)
    if #minions > 0 then
        hasMinion = true
    end

    return hasHero, hasMinion
end

---@return Vector
---@param target AIBaseClient
function Yasuo.PosAfterE(target)
    --return Player.Position:Extended(target, Yasuo.Spells.E.Range)

    local myPos = Player.Position
    local targetPos = target.Position

    local dir = (targetPos - myPos):Normalized()

    return myPos + dir * Yasuo.Spells.E.Range
end

---@param target AIHeroClient|AIMinionClient
function Yasuo.CanCastE(target)
    return not target:GetBuff("YasuoE")
end

---@param target AIHeroClient
function Yasuo.CanCastR(target)
    --[[
    local knockUpType = Enums.BuffTypes.Knockup
    local knockBackType = Enums.BuffTypes.Knockback

    local buffs = target.Buffs

    for name, buff in pairs(buffs) do
        if buff and buff.IsValid and (buff.BuffType == knockUpType or buff.BuffType == knockBackType) then
            return true
        end
    end

    return false
    --]]

    local enemyBuffs = Yasuo.EnemiesRBuffs[target.Handle]
    if enemyBuffs then
        for name, endTime in pairs(enemyBuffs) do
            if name and endTime then
                return true
            end
        end
    end

    return false
end

---@param target AIBaseClient
function Yasuo.GetDashableObj(target)
    local pos = target and target.Position or Renderer.GetMousePos()

    local distToMyHero = Player.Position:Distance(pos)

    local possibleDash = {}

    local function IsEndPosCloser(unit)
        local posAfterE = Yasuo.PosAfterE(unit)

        return posAfterE:Distance(pos) < distToMyHero
    end

    local enemyHeroes = ObjManager.Get("enemy", "heroes")

    ---@param obj GameObject
    for handle, obj in pairs(enemyHeroes) do
        local hero = obj.AsHero
        if Yasuo.IsValidTarget(hero, Yasuo.Spells.E.Range) and Yasuo.CanCastE(hero) and IsEndPosCloser(hero) then
            possibleDash[#possibleDash + 1] = hero
        end
    end

    local minions = Yasuo.GetEnemyAndJungleMinions(Yasuo.Spells.E.Range)

    for _, minion in ipairs(minions) do
        if Yasuo.CanCastE(minion) and IsEndPosCloser(minion) then
            possibleDash[#possibleDash + 1] = minion
        end
    end

    if #possibleDash == 0 then
        return nil
    end

    sort(possibleDash, function(a, b)
        return Yasuo.PosAfterE(a):Distance(pos) < Yasuo.PosAfterE(b):Distance(pos)
    end)


    return possibleDash[1]
end

---@param target AIHeroClient
function Yasuo.TimeLeftForR(target)
    --[[
    local knockUpType = Enums.BuffTypes.Knockup
    local knockBackType = Enums.BuffTypes.Knockback

    local longestDuration = 0

    local buffs = target.Buffs
    for name, buff in pairs(buffs) do
        if buff.IsValid and (buff.BuffType == knockUpType or buff.BuffType == knockBackType) then
            if buff.DurationLeft > longestDuration then
                longestDuration = buff.DurationLeft
            end
        end
    end

    return longestDuration
    --]]

    local longestDuration = 0

    local enemyBuffs = Yasuo.EnemiesRBuffs[target.Handle]
    if enemyBuffs then
        for name, endTime in pairs(enemyBuffs) do
            local durationLeft = endTime - Game.GetTime()

            if durationLeft > longestDuration then
                longestDuration = durationLeft
            end
        end
    end

    return longestDuration
end

function Yasuo.GetLimitRFall()
    local baseLimit = Menu.Get("combo.useR.fallLimit")

    return baseLimit + Game.GetLatency() / 1000
end

function Yasuo.GetGroupTimeLeftR(targets)
    local firstToFallT = huge

    for _, hero in ipairs(targets) do
        local timeLeft = Yasuo.TimeLeftForR(hero)
        if timeLeft < firstToFallT then
            firstToFallT = timeLeft
        end
    end

    return firstToFallT
end

---@param mainTarget AIHeroClient
function Yasuo.GetAirborneEnemiesAround(mainTarget)
    local result = {}

    local pos = mainTarget.Position

    local enemyHeroes = ObjManager.Get("enemy", "heroes")

    ---@param obj GameObject
    for handle, obj in pairs(enemyHeroes) do
        local hero = obj.AsHero
        if Yasuo.IsValidTarget(hero, Yasuo.Spells.R.Radius, pos) and Yasuo.CanCastR(hero) then
            result[#result + 1] = hero
        end
    end

    return result
end

---@param target AIHeroClient
function Yasuo.ExecuteRLogic(target, useQ, useE, shouldForceCast)
    local timeLeft = Yasuo.TimeLeftForR(target)
    local timeLimit = Yasuo.GetLimitRFall()

    local myPos = Player.Position
    local targetPos = target.Position

    if shouldForceCast and Yasuo.CastR(targetPos) then
        return true
    end

    if timeLeft > timeLimit then
        local function IsValid(unit)
            if unit then
                local posAfterE = Yasuo.PosAfterE(unit)
                local isNotMain = unit.Handle ~= target.Handle
                local canReachMain = posAfterE:Distance(targetPos) < Yasuo.Spells.R.Range
                local validTarget = Yasuo.IsValidTarget(unit, Yasuo.Spells.E.Range)

                return validTarget and isNotMain and canReachMain
            end

            return false
        end

        local function MiniCombo(unit)
            if useQ and Yasuo.IsSpellReady(Slots.Q) then
                if useE and Yasuo.CanCastE(unit) and Yasuo.IsSpellReady(Slots.E) then
                    if Yasuo.CastE(unit) then
                        return true
                    end
                else
                    if Yasuo.CastQ(targetPos) then
                        return true
                    end
                end
            elseif useE and Yasuo.CanCastE(unit) and Yasuo.IsSpellReady(Slots.E) then
                if Yasuo.CastE(unit) then
                    return true
                end
            end

            return false
        end

        if targetPos:Distance(myPos) < Yasuo.Spells.E.Range then
            if MiniCombo(target) then
                return true
            end
        else
            local enemyHeroes = ObjManager.Get("enemy", "heroes")


            ---@param obj GameObject
            for handle, obj in pairs(enemyHeroes) do
                local hero = obj.AsHero
                if IsValid(hero) and MiniCombo(hero) then
                    return true
                end
            end

            local minions = Yasuo.GetEnemyAndJungleMinions(Yasuo.Spells.E.Range)
            for _, minion in ipairs(minions) do
                if IsValid(minion) and MiniCombo(minion) then
                    return true
                end
            end
        end
    else
        if Yasuo.CastR(targetPos) then
            return true
        end
    end

    return false
end

---@return boolean, boolean @ShouldCast, ForceCast
---@param target AIHeroClient
function Yasuo.ShouldCastR(target, menuHealth, menuAirEnemies)
    local shouldCast, forceCast = false, false

    if not Yasuo.IsValidTarget(target, Yasuo.Spells.R.Range) or not Yasuo.CanCastR(target) then
        return false, false
    end

    local hp = target.HealthPercent * 100
    local airborneEnemies = Yasuo.GetAirborneEnemiesAround(target)

    if #airborneEnemies >= menuAirEnemies then
        local firstToFall = Yasuo.GetGroupTimeLeftR(airborneEnemies)
        local limitR = Yasuo.GetLimitRFall()

        shouldCast = true

        if limitR >= firstToFall then
            forceCast = true
        end
    end

    if hp <= menuHealth then
        shouldCast = true
    end

    return shouldCast, forceCast
end

function Yasuo.GetBestQTarget(forcedTarget, spellToUse)
    if forcedTarget then
        return Yasuo.IsValidTarget(forcedTarget, spellToUse.Range) and forcedTarget
    else
        return TS:GetTarget(spellToUse.Range)
    end
end

function Yasuo.GetBestETarget()
    local target = TS:GetTarget(Yasuo.Spells.Q1.Range)

    if not target then
        target = TS:GetTarget(Yasuo.Spells.Q3.Range + 600)
    end

    return target
end

---@return AIHeroClient, boolean @BestTarget, ForceCast
function Yasuo.GetBestRTarget(menuHealth, menuAirEnemies)
    local possibleTargets = {}

    local enemyHeroes = ObjManager.Get("enemy", "heroes")


    ---@param obj GameObject
    for handle, obj in pairs(enemyHeroes) do
        local hero = obj.AsHero
        local shouldCast, forceCast = Yasuo.ShouldCastR(hero, menuHealth, menuAirEnemies)

        if shouldCast then
            possibleTargets[#possibleTargets + 1] = {unit = hero, force = forceCast}
        end
    end

    --TODO: Sort by priority

    if #possibleTargets == 0 then
        return nil, false
    end

    sort(possibleTargets, function(a, b)
        if a.force and not b.force then
            return true
        elseif not a.force and b.force then
            return false
        else
            return true
        end
    end)

    local elem = possibleTargets[1]

    return elem.unit, elem.force
end

---@param pos Vector
function Yasuo.IsPosUnderTurret(pos)
    local enemyTurrets = ObjManager.Get("enemy", "turrets")

    ---@param obj GameObject
    for handle, obj in pairs(enemyTurrets) do
        local turret = obj.AsTurret
        if turret and turret.IsValid and not turret.IsDead and pos:Distance(turret) <= 850 + Player.BoundingRadius then
            return true
        end
    end

    return false
end

---@param target AIHeroClient
function Yasuo.GapcloseToTarget(target, minDist, underTurret)
    local myPos = Player.Position

    if myPos:Distance(target.Position) > minDist then
        local dashObj = Yasuo.GetDashableObj(target)

        if dashObj then
            local posAfterDash = Yasuo.PosAfterE(dashObj)

            if not Yasuo.IsPosUnderTurret(posAfterDash) or underTurret then
                if Yasuo.CastE(dashObj) then
                    return true
                end
            end
        end
    end

    return false
end

---@param target AIHeroClient
function Yasuo.KiteAroundTarget(target, maxDist, maxHealth, underTurret)
    local targetPos = target.Position

    local function ShouldKite(unit)
        local posAfterE = Yasuo.PosAfterE(unit)

        local validCondition = Yasuo.IsValidTarget(unit, Yasuo.Spells.E.Range) and Yasuo.CanCastE(unit)
        local distCondition = targetPos:Distance(posAfterE) < maxDist
        local turretCondition = not Yasuo.IsPosUnderTurret(posAfterE) or underTurret

        return validCondition and distCondition and turretCondition
    end

    if not target or (target.HealthPercent * 100) <= maxHealth then
        return false
    end

    local minions = Yasuo.GetEnemyAndJungleMinions(Yasuo.Spells.E.Range)
    for _, minion in ipairs(minions) do
        if ShouldKite(minion) and Yasuo.CastE(minion) then
            return true
        end
    end

    return false
end

function Yasuo.CanGapcloseTo(target)
    local myPos = Player.Position
    local targetPos = target.Position

    local distToEnemy = myPos:Distance(targetPos)

    local function IsValid(unit)
        if Yasuo.IsValidTarget(unit, distToEnemy) and Yasuo.CanCastE(unit) then
            local distToUnit = myPos:Distance(unit)

            local posAfterE = nil
            if distToUnit < Yasuo.Spells.E.Range then
                posAfterE = Yasuo.PosAfterE(unit)
            else
                posAfterE = unit.Position
            end

            if posAfterE:Distance(targetPos) < distToEnemy then
                return true
            end
        end

        return false
    end

    if not Menu.Get("combo.useE") then
        return false
    end

    local minions = Yasuo.GetEnemyAndJungleMinions(distToEnemy)
    for _, minion in ipairs(minions) do
        if IsValid(minion) then
            return true
        end
    end

    local enemyHeroes = ObjManager.Get("enemy", "heroes")


    ---@param obj GameObject
    for handle, obj in pairs(enemyHeroes) do
        local hero = obj.AsHero
        if IsValid(hero) then
            return true
        end
    end

    local useEGCMinDist = Menu.Get("combo.useE.GC.minDist")
    if Yasuo.CanCastE(target) and distToEnemy < Yasuo.Spells.E.Range and distToEnemy > useEGCMinDist then
        return true
    end

    return false
end

function Yasuo.GetDamage(target, slot)
    local rawDamage = 0
    local dmgType = nil

    local spellLevel = Player:GetSpell(slot).Level

    local damages = Yasuo.Damages
    local slotToTable = {
        [Slots.Q] = damages.Q,
        [Slots.E] = damages.E,
        [Slots.R] = damages.R
    }

    local data = slotToTable[slot]
    if data then
        dmgType = data.Type
        rawDamage = data.Base[spellLevel]

        if data.TotalAD then
            rawDamage = rawDamage + (data.TotalAD * Player.TotalAD)
        end

        if data.BonusAD then
            rawDamage = rawDamage + (data.BonusAD * Player.BonusAD)
        end

        if data.TotalAP then
            rawDamage = rawDamage + (data.TotalAP * Player.TotalAP)
        end

        if dmgType == Enums.DamageTypes.Physical then
            return DmgLib.CalculatePhysicalDamage(Player, target, rawDamage)
        elseif dmgType == Enums.DamageTypes.Magical then
            return DmgLib.CalculateMagicalDamage(Player, target, rawDamage)
        else
            return rawDamage
        end
    end

    return 0
end

---@param target AIHeroClient
function Yasuo.GetIgniteDamage(target)
    local myLevel = min(Player.Level, 18)

    local rawDamage = 50 + 20 * myLevel

    local enemyRegen = target.HealthRegen * 2.5

    return rawDamage - enemyRegen
end

---@param target AIHeroClient
function Yasuo.ComboKillable(target)
    local damageToDeal = 0
    local targetHealth = target.Health + target.ShieldAll

    local useQ = Menu.Get("combo.useQ") and Player:GetSpell(Slots.Q).Level >= 1
    local useE = Menu.Get("combo.useE") and Player:GetSpell(Slots.E).Level >= 1
    local useR = Menu.Get("combo.useR") and Player:GetSpell(Slots.R).Level >= 1

    damageToDeal = DmgLib.GetAutoAttackDamage(Player, target, false) * 3

    if useQ then
        damageToDeal = damageToDeal + Yasuo.GetDamage(target, Slots.Q)
    end

    if useE then
        damageToDeal = damageToDeal + Yasuo.GetDamage(target, Slots.E)
    end

    if useR then
        damageToDeal = damageToDeal + Yasuo.GetDamage(target, Slots.R)
    end

    return targetHealth < damageToDeal
end

function Yasuo.GetHitchance(slot)
    local hc = 0.5

    if slot == Slots.Q then
        if Yasuo.HasQ3() then
            hc = Menu.Get("hc.Q3")
        else
            hc = Menu.Get("hc.Q1")
        end
    end

    return hc
end

---@param pos Vector
function Yasuo.PosHasJungleMinions(pos, range)
    local jungleMinions = ObjManager.GetNearby("neutral", "minions")
    ---@param obj GameObject
    for handle, obj in pairs(jungleMinions) do
        local minion = obj.AsMinion

        if Yasuo.IsValidTarget(minion, range, pos) then
            return true
        end
    end

    return false
end

function Yasuo.ShouldRunLogic()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

function Yasuo.StackQ()
    if not Yasuo.IsSpellReady(Slots.Q) or Yasuo.HasQ3() or Yasuo.IsDashing() then
        return
    end

    local myPos = Player.Position

    local target = TS:GetTarget(Yasuo.Spells.Q1.Range)
    if target then
        local pred = Prediction.GetPredictedPosition(target, Yasuo.Spells.Q1, myPos)

        if pred and pred.CastPosition and pred.HitChance >= 0.15 then
            if Yasuo.CastQ(pred.CastPosition) then
                return
            end
        end
    else
        local fallbackMinions = {}

        local minions = Yasuo.GetEnemyAndJungleMinions(Yasuo.Spells.Q1.Range)

        ---@param minion AIMinionClient
        for _, minion in ipairs(minions) do
            fallbackMinions[#fallbackMinions + 1] = minion

            if minion.Health < Yasuo.GetDamage(minion, Slots.Q) then
                local pred = minion:FastPrediction(Yasuo.Spells.Q1.Delay)

                if pred and Yasuo.CastQ(pred) then
                    return
                end
            end
        end

        if #fallbackMinions > 0 then
            sort(fallbackMinions, function(a, b)
                return myPos:Distance(a.Position) < myPos:Distance(b.Position)
            end)

            ---@type AIMinionClient
            local fallback = fallbackMinions[1]

            local pred = fallback:FastPrediction(Yasuo.Spells.Q1.Delay)
            if pred and Yasuo.CastQ(pred) then
                return
            end
        end
    end
end

function Yasuo.ShouldQLasthit(minion)
    return not Orbwalker.IsLasthitMinion(minion)
end

function Yasuo.Killsteal()
    local ksIgnite = Menu.Get("ks.ignite")

    local enemyHeroes = ObjManager.Get("enemy", "heroes")

    ---@param obj GameObject
    for handle, obj in pairs(enemyHeroes) do
        local hero = obj.AsHero
        local totalHealth = hero.Health + hero.ShieldAll

        if Yasuo.IsValidTarget(hero) then
            if ksIgnite and Yasuo.Ignite.Slot and Yasuo.IsSpellReady(Yasuo.Ignite.Slot) then
                if Player:Distance(hero.Position) < 600 and Yasuo.GetIgniteDamage(hero) > totalHealth then
                    if Yasuo.CastIgnite(hero) then
                        return
                    end
                end
            end
        end
    end
end

function Yasuo.CheckQDelay()
    local qDelay = Yasuo.GetQDelay()

    if Yasuo.Spells.Q1.Delay ~= qDelay then
        Yasuo.Spells.Q1.Delay = qDelay
        Yasuo.Spells.Q3.Delay = qDelay
    end
end

function Yasuo.CheckIgniteSlot()
    local curTime = Game.GetTime()
    if curTime < Yasuo.Ignite.LastCheckT + 1 then return end

    Yasuo.Ignite.LastCheckT = curTime

    local slots = {Enums.SpellSlots.Summoner1, Enums.SpellSlots.Summoner2}

    local function IsIgnite(slot)
        return Player:GetSpell(slot).Name == "SummonerDot"
    end

    for _, slot in ipairs(slots) do
        if IsIgnite(slot) then
            if Yasuo.Ignite.Slot ~= slot then
                INFO("Ignite was found in slot %d", slot)
                Yasuo.Ignite.Slot = slot
            end

            return
        end
    end

    if Yasuo.Ignite.Slot ~= nil then
        INFO("Ignite was lost")
        Yasuo.Ignite.Slot = nil
    end
end

function Yasuo.CheckFlashSlot()
    local curTime = Game.GetTime()
    if curTime < Yasuo.Flash.LastCheckT + 1 then return end

    Yasuo.Flash.LastCheckT = curTime

    local slots = {Enums.SpellSlots.Summoner1, Enums.SpellSlots.Summoner2}

    local function IsFlash(slot)
        return Player:GetSpell(slot).Name == "SummonerFlash"
    end

    for _, slot in ipairs(slots) do
        if IsFlash(slot) then
            if Yasuo.Flash.Slot ~= slot then
                INFO("Flash was found in slot %d", slot)
                Yasuo.Flash.Slot = slot
            end

            return
        end
    end

    if Yasuo.Flash.SLot ~= nil then
        INFO("Ignite was lost")
        Yasuo.Flash.Slot = nil
    end
end

function Yasuo.DoBeyblade()
    Orbwalker.Orbwalk(Renderer.GetMousePos())

    local curTime = Game.GetTime()

    local normalCombo = Menu.Get("bb.normalCombo")

    if normalCombo and curTime < Yasuo.Beyblade.LastCastT + 2 then
        Yasuo.DoCombo()
        return
    end

    local flashReady = Yasuo.Flash.Slot and Yasuo.IsSpellReady(Yasuo.Flash.Slot)
    if not flashReady or not Yasuo.IsSpellReady(Slots.Q) or not Yasuo.HasQ3() then
        return
    end

    local function ChooseTarget(range)
        local target = TS:GetForcedTarget()

        if target then
            if Yasuo.IsValidTarget(target, range) then
                return target
            end
        else
            return TS:GetTarget(range)
        end

        return nil
    end

    if Yasuo.IsDashing() then
        local realTarget = ChooseTarget(Yasuo.Flash.Range + (Yasuo.Spells.QCircle.Radius - 75))

        if realTarget then
            if Yasuo.CastQ(Player.Position) then
                delay(50, function()
                    if Yasuo.CastFlash(realTarget.Position) then
                        Yasuo.Beyblade.LastCastT = curTime
                    end
                end)

                return
            end
        end
    else
        if Yasuo.IsSpellReady(Slots.E) then
            local realTarget = ChooseTarget((Yasuo.Spells.E.Range - 75) + Yasuo.Flash.Range + (Yasuo.Spells.QCircle.Radius - 75))

            if realTarget then
                local enemyMinions = ObjManager.GetNearby("enemy", "heroes")

                local dashObj = Yasuo.GetDashableObj(realTarget)
                if dashObj then
                    local endPos = Yasuo.PosAfterE(dashObj)

                    if endPos:Distance(realTarget.Position) < Yasuo.Flash.Range + (Yasuo.Spells.QCircle.Radius - 75) then
                        if Yasuo.CastE(dashObj) then
                            return
                        end
                    end
                end
            end
        end
    end
end

function Yasuo.DoFlee()
    local useE = Menu.Get("flee.useE")
    local stackQ = Menu.Get("flee.stackQ")

    if not useE then return end

    if stackQ and Yasuo.IsSpellReady(Slots.Q) and not Yasuo.HasQ3() then
        local endPos = Yasuo.GetDashEndPos()

        if endPos then
            local hasHero, hasMinion = Yasuo.PosHasQCircleTargets(endPos)

            if hasHero or hasMinion and Yasuo.CastQ(Player.Position) then
                return
            end
        end
    end

    if Yasuo.IsSpellReady(Slots.E) then
        local dashableObj = Yasuo.GetDashableObj()

        if dashableObj and Yasuo.CastE(dashableObj) then
            return
        end
    end
end

function Yasuo.DoCombo()
    local forcedTarget = TS:GetForcedTarget()

    local useQ = Menu.Get("combo.useQ")
    local stackQ = Menu.Get("combo.useQ.stack")
    local useExpireQ3 = Menu.Get("combo.useQ.expireQ3")

    local useE = Menu.Get("combo.useE")
    local useEKiting = Menu.Get("combo.useE.kiting")
    local useEKitingTurret = Menu.Get("combo.useE.kiting.turret")
    local useEKitingMaxDist = Menu.Get("combo.useE.kiting.maxDist")
    local useEKitingMaxHealth = Menu.Get("combo.useE.kiting.maxHealth")
    local useEGC = Menu.Get("combo.useE.GC")
    local useEGCTurret = Menu.Get("combo.useE.GC.turret")
    local useEGCMinDist = Menu.Get("combo.useE.GC.minDist")

    local useR = Menu.Get("combo.useR")
    local useRMinHp = Menu.Get("combo.useR.minHp")
    local useREnemyCount = Menu.Get("combo.useR.enemyCount")

    local myPos = Player.Position

    if useR and Yasuo.IsSpellReady(Slots.R) then
        if forcedTarget then
            local shouldCast, forceCast = Yasuo.ShouldCastR(forcedTarget, useRMinHp, useREnemyCount)
            if shouldCast and Yasuo.ExecuteRLogic(forcedTarget, useQ, useE, forceCast) then
                return
            end
        else
            local bestTarget, forceCast = Yasuo.GetBestRTarget(useRMinHp, useREnemyCount)
            if bestTarget and Yasuo.ExecuteRLogic(bestTarget, useQ, useE, forceCast) then
                return
            end
        end
    end

    if useE and Yasuo.IsSpellReady(Slots.E) then
        ---@type GameObject
        local target = nil

        if forcedTarget and Yasuo.IsValidTarget(forcedTarget) then
            target = forcedTarget
        else
            target = Yasuo.GetBestETarget()
        end

        if target then
            if useEGC then
                if Yasuo.GapcloseToTarget(target, useEGCMinDist, useEGCTurret) then
                    return
                end
            end

            if useEKiting then
                if Yasuo.KiteAroundTarget(target, useEKitingMaxDist, useEKitingMaxHealth, useEKitingTurret) then
                    return
                end
            end
        end
    end

    if useQ and Yasuo.IsSpellReady(Slots.Q) then
        local spell = Yasuo.HasQ3() and Yasuo.Spells.Q3 or Yasuo.Spells.Q1

        local target = Yasuo.GetBestQTarget(forcedTarget, spell)

        if Yasuo.IsDashing() then
            local dashEndPos = Yasuo.GetDashEndPos()

            if dashEndPos then
                local hasHero, hasMinion = Yasuo.PosHasQCircleTargets(dashEndPos, target)

                if hasHero and Yasuo.CastQ(myPos) then
                    return
                end

                if hasMinion and stackQ and not Yasuo.HasQ3() and Yasuo.CastQ(myPos) then
                    return
                end
            end
        else
            if target then
                local useExpire = useExpireQ3 and Yasuo.G.Q3BuffEndT and Game.GetTime() > Yasuo.G.Q3BuffEndT - 0.75

                local function Q3Condition(unit)
                    local dist = myPos:Distance(unit)

                    if dist < useEGCMinDist or useExpire then
                        return false
                    else
                        return Yasuo.CanGapcloseTo(target) and Yasuo.ComboKillable(target)
                    end
                end

                local eLeveled = Player:GetSpell(Slots.E).Level > 0

                if not useE or not eLeveled or not Yasuo.CanGapcloseTo(target) or useExpire then
                    if Yasuo.HasQ3() and not Q3Condition(target) or not Yasuo.HasQ3() then
                        local pred = Prediction.GetPredictedPosition(target, spell, myPos)

                        if pred and pred.CastPosition then
                            local cond = useExpire and pred.HitChanceEnum > Enums.HitChance.OutOfRange or pred.HitChance >= Yasuo.GetHitchance(Slots.Q)
                            if cond then
                                if Yasuo.CastQ(pred.CastPosition) then
                                    return
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function Yasuo.DoHarass()
    local useQ = Menu.Get("harass.useQ")
    local useQQ3 = Menu.Get("harass.useQ.Q3")
    local useQTurret = Menu.Get("harass.useQ.turret")
    local useQLastHit = Menu.Get("harass.useQ.lastHit")

    local forcedTarget = TS:GetForcedTarget()

    local myPos = Player.Position

    if useQ and Yasuo.IsSpellReady(Slots.Q) then
        if (not Yasuo.HasQ3() or useQQ3) and (not Yasuo.IsPosUnderTurret(myPos) or useQTurret) then
            if Yasuo.IsDashing() then
                local endPos = Yasuo.GetDashEndPos()

                if endPos then
                    local hasHero, hasMinion = Yasuo.PosHasQCircleTargets(endPos)

                    if hasHero and Yasuo.CastQ(Player.Position) then
                        return
                    end
                end
            else
                local spell = Yasuo.HasQ3() and Yasuo.Spells.Q3 or Yasuo.Spells.Q1
                local target = Yasuo.GetBestQTarget(forcedTarget, spell)

                if target then
                    local pred = Prediction.GetPredictedPosition(target, spell, myPos)

                    if pred and pred.CastPosition and pred.HitChance >= Yasuo.GetHitchance(Slots.Q) then
                        if Yasuo.CastQ(pred.CastPosition) then
                            return
                        end
                    end
                end

                if useQLastHit and not Yasuo.HasQ3() and not TS:GetTarget(Yasuo.Spells.Q1.Range + 100) then
                    local minions = Yasuo.GetEnemyAndJungleMinions(Yasuo.Spells.Q1.Range)

                    ---@param minion AIMinionClient
                    for _, minion in ipairs(minions) do
                        if Yasuo.ShouldQLasthit(minion) and minion.Health < Yasuo.GetDamage(minion, Slots.Q) then
                            local pred = minion:FastPrediction(Yasuo.Spells.Q1.Delay)

                            if pred and Yasuo.CastQ(pred) then
                                return
                            end
                        end
                    end
                end
            end
        end
    end
end

function Yasuo.DoClear()
    local useQ = Menu.Get("clear.useQ")
    local useQQ3 = Menu.Get("clear.useQ.Q3")
    local useQQ3MinHit = Menu.Get("clear.useQ.Q3.minHit")

    local useE = Menu.Get("clear.useE")
    local useELastHit = Menu.Get("clear.useE.lastHit")
    local useETurret = Menu.Get("clear.useE.turret")

    local myPos = Player.Position

    local minions = Yasuo.GetEnemyAndJungleMinions(Yasuo.Spells.Q3.Range)

    local function IsKillableWith(unit, useE, useQ)
        if useQ and useE then
            return unit.Health < Yasuo.GetDamage(unit, Slots.Q) + Yasuo.GetDamage(unit, Slots.E)
        elseif useQ then
            return unit.Health < Yasuo.GetDamage(unit, Slots.Q)
        elseif useE then
            return unit.Health < Yasuo.GetDamage(unit, Slots.E)
        end

        return false
    end

    local function IsValidEQ(unit)
        local posAfterE = Yasuo.PosAfterE(unit)

        return posAfterE:Distance(unit.Position) < Yasuo.Spells.QCircle.Radius
    end

    local function HasJungleMinionEndPos(unit, minionCache)
        local posAfterE = Yasuo.PosAfterE(unit)

        if minionCache then
            ---@param minion AIMinionClient
            for _, minion in ipairs(minionCache) do
                if minion.TeamId == Enums.Teams.Neutral and Yasuo.IsValidTarget(minion, Yasuo.Spells.QCircle.Radius, posAfterE) then
                    return true
                end
            end

            return false
        else
            return Yasuo.PosHasJungleMinions(posAfterE, Yasuo.Spells.QCircle.Radius)
        end
    end

    local function HitsAfterDash(unit, minionCache)
        local posAfterE = Yasuo.PosAfterE(unit)
        local count = 0

        if minionCache then
            ---@param minion AIMinionClient
            for _, minion in ipairs(minionCache) do
                if Yasuo.IsValidTarget(minion, Yasuo.Spells.QCircle.Radius, posAfterE) then
                    count = count + 1
                end
            end
        end

        return count
    end

    local function TurretCondition(unit)
        local posAfterE = Yasuo.PosAfterE(unit)
        return useETurret or not Yasuo.IsPosUnderTurret(posAfterE)
    end

    local possibleQPositions = {}
    local possibleQUnits = {}

    local qCondition = useQ and Yasuo.IsSpellReady(Slots.Q) and (useQQ3 or not Yasuo.HasQ3())
    local eCondition = useE and Yasuo.IsSpellReady(Slots.E)

    ---@param minion AIMinionClient
    for _, minion in ipairs(minions) do
        local distToMinion = myPos:Distance(minion.Position)

        if eCondition and distToMinion < Yasuo.Spells.E.Range and Yasuo.CanCastE(minion) then
            if TurretCondition(minion) then
                if IsKillableWith(minion, true, false) or HasJungleMinionEndPos(minion, minions) then
                    if Yasuo.CastE(minion) then
                        return
                    end
                end

                if not useELastHit and useQ and Yasuo.IsSpellReady(Slots.Q) and not Yasuo.HasQ3() then
                    if IsValidEQ(minion) then
                        if IsKillableWith(minion, true, true) or HitsAfterDash(minion, minions) >= 3 or HasJungleMinionEndPos(minion, minions) then
                            if Yasuo.CastE(minion) then
                                return
                            end
                        end
                    end
                end
            end
        end

        if qCondition then
            if Yasuo.IsDashing() then
                if not Yasuo.HasQ3() then
                    local endDashPos = Yasuo.GetDashEndPos()
                    local hasHero, hasMinion = Yasuo.PosHasQCircleTargets(endDashPos)

                    if hasMinion and Yasuo.CastQ(myPos) then
                        return
                    end
                end
            else
                local spell = Yasuo.HasQ3() and Yasuo.Spells.Q3 or Yasuo.Spells.Q1

                if distToMinion < spell.Range then
                    possibleQPositions[#possibleQPositions + 1] = minion.Position
                    possibleQUnits[#possibleQUnits + 1] = minion
                end
            end
        end
    end

    if #possibleQPositions > 0 then
        if Yasuo.HasQ3() then
            local bestPos, hits = Geometry.BestCoveringRectangle(possibleQPositions, myPos, Yasuo.Spells.Q3.Radius * 2)
            if hits >= useQQ3MinHit and bestPos and Yasuo.CastQ(bestPos) then
                return
            end
        else
            ---@param minion AIMinionClient
            for _, minion in ipairs(possibleQUnits) do
                if IsKillableWith(minion, false, true) and Yasuo.ShouldQLasthit(minion) then
                    local pred = minion:FastPrediction(Yasuo.Spells.Q1.Delay)

                    if Yasuo.CastQ(pred) then
                        return
                    end
                end
            end
        end

        if useQQ3 or not Yasuo.HasQ3() then
            local nUnits = #possibleQUnits
            if nUnits > 0 and nUnits < useQQ3MinHit then
                ---@param a AIMinionClient
                ---@param b AIMinionClient
                sort(possibleQUnits, function(a, b)
                    return a.MaxHealth > b.MaxHealth
                end)

                ---@type AIMinionClient
                local targetMinion = possibleQUnits[1]

                local pred = targetMinion:FastPrediction(Yasuo.Spells.Q1.Delay)
                if Yasuo.CastQ(pred) then
                    return
                end
            end
        end
    end
end

function Yasuo.DoLasthit()
    local useQ = Menu.Get("lh.useQ")
    local useQQ3 = Menu.Get("lh.useQ.Q3")

    local useE = Menu.Get("lh.useE")
    local useETurret = Menu.Get("lh.useE.turret")

    local minions = Yasuo.GetEnemyAndJungleMinions(Yasuo.Spells.Q3.Range)

    local qSpell = Yasuo.HasQ3() and Yasuo.Spells.Q3 or Yasuo.Spells.Q1

    local myPos = Player.Position

    local qCondition = useQ and Yasuo.IsSpellReady(Slots.Q) and not Yasuo.IsDashing() and (useQQ3 or not Yasuo.HasQ3())
    local eCondition = useE and Yasuo.IsSpellReady(Slots.E)

    ---@param minion AIMinionClient
    for _, minion in ipairs(minions) do
        local distToMinion = myPos:Distance(minion.Position)

        if qCondition and distToMinion < qSpell.Range then
            if Yasuo.ShouldQLasthit(minion) and minion.Health < Yasuo.GetDamage(minion, Slots.Q) then
                local pred = minion:FastPrediction(Yasuo.Spells.Q1.Delay)

                if pred and Yasuo.CastQ(pred) then
                    return
                end
            end
        end

        if eCondition and distToMinion < Yasuo.Spells.E.Range then
            if minion.Health < Yasuo.GetDamage(minion, Slots.E) then
                local aaRange = Orbwalker.GetTrueAutoAttackRange(Player, minion)

                if distToMinion >= aaRange then
                    local posAfterE = Yasuo.PosAfterE(minion)

                    if useETurret or not Yasuo.IsPosUnderTurret(posAfterE) then
                        if Yasuo.CastE(minion) then
                            return
                        end
                    end
                end
            end
        end
    end
end

function Yasuo.Events.OnTick()
    Yasuo.CheckQDelay()

    Yasuo.CheckIgniteSlot()
    Yasuo.CheckFlashSlot()

    Yasuo.MyDashCallback()

    if not Yasuo.ShouldRunLogic() then return end

    Yasuo.Killsteal()

    if Menu.Get("bb.key") then
        Yasuo.DoBeyblade()
    end

    if Menu.Get("misc.stackQ") then
        Yasuo.StackQ()
    end

    local modesMap = {
        ["Flee"] = Yasuo.DoFlee,
        ["Combo"] = Yasuo.DoCombo,
        ["Harass"] = Yasuo.DoHarass,
        ["Waveclear"] = Yasuo.DoClear,
        ["Lasthit"] = Yasuo.DoLasthit
    }

    local owMode = Orbwalker.GetMode()
    if modesMap[owMode] then
        modesMap[owMode]()
    end
end

function Yasuo.Events.OnDraw()
    if Player.IsDead then return end

    local myPos = Player.Position

    local qRange = Yasuo.HasQ3() and Yasuo.Spells.Q3.Range or Yasuo.Spells.Q1.Range

    local SlotsToData = {
        [Slots.Q] = {str = "Q", range = qRange},
        [Slots.W] = {str = "W", range = Yasuo.Spells.W.Range},
        [Slots.E] = {str = "E", range = Yasuo.Spells.E.Range},
        [Slots.R] = {str = "R", range = Yasuo.Spells.R.Range}
    }

    for slot, data in pairs(SlotsToData) do
        if Menu.Get("draw." .. data.str) and Yasuo.IsSpellReady(slot) then
            Renderer.DrawCircle3D(myPos, data.range, 30, 2, Menu.Get("draw." .. data.str .. ".color"))
        end
    end
end

function Yasuo.Events.OnDrawDamage(target, dmgList)
    if not Menu.Get("draw.healthbar") then return end

    local damageToDeal = 0

    for id, slot in pairs(Slots) do
        if Yasuo.IsSpellReady(slot) then
            damageToDeal = damageToDeal + Yasuo.GetDamage(target, slot)
        end
    end

    damageToDeal = damageToDeal + DmgLib.GetAutoAttackDamage(Player, target, true)

    if Yasuo.IsSpellReady(Slots.Q) then
        damageToDeal = damageToDeal + Yasuo.GetDamage(target, Slots.Q)
    end

    if Yasuo.IsSpellReady(Slots.E) and Yasuo.CanCastE(target) then
        damageToDeal = damageToDeal + Yasuo.GetDamage(target, Slots.E)
    end

    if Yasuo.IsSpellReady(Slots.R) then
        damageToDeal = damageToDeal + Yasuo.GetDamage(target, Slots.R)
    end

    insert(dmgList, damageToDeal)
end

function Yasuo.Events.OnCastSpell(data)
    if data then
        if Yasuo.LastCastT[data.Slot] then
            Yasuo.LastCastT[data.Slot] = Game.GetTime()
        end

        if Yasuo.Ignite.Slot and Yasuo.Ignite.Slot == data.Slot then
            Yasuo.Ignite.LastCastT = Game.GetTime()
        end

        if Yasuo.Flash.Slot and Yasuo.Flash.Slot == data.Slot then
            Yasuo.Flash.LastCastT = Game.GetTime()
        end
    end
end

---@param obj GameObject
function Yasuo.Events.OnCreateObject(obj)
    local useWOnAA = Menu.Get("misc.useWOnAA")
    local useWOnAAMinHp = Menu.Get("misc.useWOnAA.minHp")

    local myHP = Player.HealthPercent * 100

    if not useWOnAA or not Yasuo.IsSpellReady(Slots.W) then return end
    if myHP > useWOnAAMinHp then return end

    if not obj or not obj.IsMissile then return end

    local missile = obj.AsMissile
    if not missile.IsBasicAttack or not missile.Target or not missile.Target.IsMe then return end

    local caster = missile.Caster
    if not caster or caster.IsAlly or not caster.IsHero then return end

    local hero = caster.AsHero
    local charName = hero.CharName

    local whitelistValue = Menu.Get("blockAA." .. charName)

    if whitelistValue then
        if Yasuo.CastW(hero.Position) then
            return
        end
    end
end

---@param obj GameObject
---@param buffInst BuffInst
function Yasuo.Events.OnBuffGain(obj, buffInst)
    if not obj then return end

    if obj.IsMe and buffInst.Name == "YasuoQ2" then
        Yasuo.G.Q3BuffEndT = buffInst.EndTime
    end

    if obj.IsAlly or not obj.IsHero then return end

    if buffInst.BuffType ~= Enums.BuffTypes.Knockup and buffInst.BuffType ~= Enums.BuffTypes.Knockback then return end

    if not Yasuo.EnemiesRBuffs[obj.Handle] then
        Yasuo.EnemiesRBuffs[obj.Handle] = {}
    end

    local enemyBuffs = Yasuo.EnemiesRBuffs[obj.Handle]

    enemyBuffs[buffInst.Name] = buffInst.EndTime
end

---@param obj GameObject
---@param buffInst BuffInst
function Yasuo.Events.OnBuffLost(obj, buffInst)
    if not obj then return end

    if obj.IsMe and buffInst.Name == "YasuoQ2" then
        Yasuo.G.Q3BuffEndT = nil
    end

    if obj.IsAlly or not obj.IsHero then return end

    if buffInst.BuffType ~= Enums.BuffTypes.Knockup and buffInst.BuffType ~= Enums.BuffTypes.Knockback then return end

    local enemyBuffs = Yasuo.EnemiesRBuffs[obj.Handle]

    if enemyBuffs and enemyBuffs[buffInst.Name] then
        enemyBuffs[buffInst.Name] = nil
    end
end

function Yasuo.Events.OnMyDash(started)
    if not started then
        Yasuo.Dash.LastDashEndT = Game.GetTime()
    end
end

function Yasuo.RegisterEvents()
    for eventName, eventId in pairs(Enums.Events) do
        if Yasuo.Events[eventName] then
            EventManager.RegisterCallback(eventId, Yasuo.Events[eventName])
        end
    end

    EventManager.RegisterEvent("OnMyDash")
    EventManager.RegisterCallback("OnMyDash", Yasuo.Events.OnMyDash)
end

function Yasuo.LoadMenu()
    local function YasuoMenu()
        Menu.Text("Version: " .. Yasuo.Version, true)

        Menu.NewTree("comboMenu", "Combo Settings", function()
            Menu.ColoredText("Q Settings", Yasuo.MainColor, true)
            Menu.Checkbox("combo.useQ", "Use Q", true)
            Menu.Checkbox("combo.useQ.stack", " ^ Stack while dashing", false)
            Menu.Checkbox("combo.useQ.expireQ3", " ^ Force Q3 when it's about to expire", true)

            Menu.Separator()

            Menu.ColoredText("E Settings", Yasuo.MainColor, true)
            Menu.Checkbox("combo.useE", "Use E", true)
            Menu.Checkbox("combo.useE.kiting", " ^ Kite around target", true)
            Menu.Checkbox("combo.useE.kiting.turret", " ^^ Kite end pos under turret", false)
            Menu.Slider("combo.useE.kiting.maxDist", " ^^ Max dist after kite", 320, 50, Yasuo.Spells.E.Range, 1)
            Menu.Slider("combo.useE.kiting.maxHealth", " ^^ Max target %HP to kite", 30, 1, 100, 1)
            Menu.Checkbox("combo.useE.GC", " ^ To gapclose", true)
            Menu.Checkbox("combo.useE.GC.turret", " ^^ Allow under turret", true)
            Menu.Slider("combo.useE.GC.minDist", " ^^ Min dist to gapclose", 300, 1, Yasuo.Spells.E.Range, 1)

            Menu.Separator()

            Menu.ColoredText("R Settings", Yasuo.MainColor, true)
            Menu.Checkbox("combo.useR", "Use R", true)
            Menu.Slider("combo.useR.fallLimit", " ^ Wait until X to cast", 0.01, 0.01, 0.25, 0.01)
            Menu.Slider("combo.useR.minHp", " ^ If enemy %HP <=", 55, 1, 100, 1)
            Menu.Slider("combo.useR.enemyCount", " ^ If X airborne enemies", 2, 1, 5, 1)
        end)

        Menu.NewTree("EQ3FMenu", "Beyblade Settings", function()
            Menu.Keybind("bb.key", "Beyblade Key", string.byte("T"), false, false, false)
            Menu.Checkbox("bb.normalCombo", "Do normal combo after Beyblade", true)
            Menu.Text(" ^ You need to hold the beyblade key even after the flash")
            Menu.Text(" ^ The combo-after-flash will last for two seconds, hold normal combo key after that")
        end)

        Menu.NewTree("harassMenu", "Harass Settings", function()
            Menu.ColoredText("Q Settings", Yasuo.MainColor, true)
            Menu.Checkbox("harass.useQ", "Use Q", true)
            Menu.Checkbox("harass.useQ.Q3", " ^ Use Q3", true)
            Menu.Checkbox("harass.useQ.turret", " ^ Use under turret", true)
            Menu.Checkbox("harass.useQ.lastHit", " ^ Last hit with Q1 & Q2", true)
        end)

        Menu.NewTree("clearMenu", "Clear Settings", function()
            Menu.ColoredText("Q Settings", Yasuo.MainColor, true)
            Menu.Checkbox("clear.useQ", "Use Q", true)
            Menu.Checkbox("clear.useQ.Q3", " ^ Use Q3", true)
            Menu.Slider("clear.useQ.Q3.minHit", " ^^ Line Q3 min hit", 2, 1, 5, 1)

            Menu.Separator()

            Menu.ColoredText("E Settings", Yasuo.MainColor, true)
            Menu.Checkbox("clear.useE", "Use E", true)
            Menu.Checkbox("clear.useE.lastHit", " ^ Only to last hit", false)
            Menu.Checkbox("clear.useE.turret", " ^ Allow under turret", false)
        end)

        Menu.NewTree("lhMenu", "Last hit Settings", function()
            Menu.ColoredText("Q settings", Yasuo.MainColor, true)
            Menu.Checkbox("lh.useQ", "Use Q", true)
            Menu.Checkbox("lh.useQ.Q3", " ^ Use Q3", false)

            Menu.Separator()

            Menu.ColoredText("E Settings", Yasuo.MainColor, true)
            Menu.Checkbox("lh.useE", "Use E", true)
            Menu.Checkbox("lh.useE.turret", " ^ Allow under turret", false)
        end)

        Menu.NewTree("fleeMenu", "Flee Settings", function()
            Menu.Checkbox("flee.useE", "UseE", true)
            Menu.Checkbox("flee.stackQ", "Stack Q while fleeing", true)
        end)

        Menu.NewTree("miscMenu", "Misc Settings", function()
            Menu.Keybind("misc.stackQ", "Stack Q", string.byte("G"), false, false, false)
            Menu.Checkbox("misc.useWOnAA", "Use W on enemy AA", false)
            Menu.Slider("misc.useWOnAA.minHp", " ^ Block enemy AA if my HP% <", 60, 0, 100, 1)
            Menu.NewTree("misc.useWOnAA.wl", " ^ Block AA Whitelist", function()
                local specialHeroNames = {
                    ["Azir"] = true,
                    ["Lillia"] = true,
                    ["Rakan"] = true,
                    ["Senna"] = true,
                    ["Thresh"] = true,
                    ["Velkoz"] = true
                }
                local enemyHeroes = ObjManager.Get("enemy", "heroes")
                ---@param obj GameObject
                for handle, obj in pairs(enemyHeroes) do
                    local hero = obj.AsHero
                    local charName = hero.CharName
                    if hero and (hero.IsRanged and not specialHeroNames[charName]) then
                        Menu.Checkbox("blockAA." .. charName, "Block " .. charName .. "'s AAs", true)
                    end
                end
            end)
        end)

        Menu.NewTree("ksMenu", "Killsteal Settings", function()
            Menu.Checkbox("ks.ignite", "Use Ignite", true)
        end)

        Menu.NewTree("hcMenu", "Hitchance Settings", function()
            Menu.Slider("hc.Q1", "Q1 Hitchance", 0.35, 0, 1, 0.01)
            Menu.Slider("hc.Q3", "Q3 Hitchance", 0.35, 0, 1, 0.01)
        end)

        Menu.NewTree("drawings", "Drawings", function()
            Menu.Checkbox("draw.Q", "Draw Q1/Q3 range", true)
            Menu.ColorPicker("draw.Q.color", " ^ Color", Yasuo.MainColor)

            Menu.Separator()

            Menu.Checkbox("draw.W", "Draw W range", false)
            Menu.ColorPicker("draw.W.color", " ^ Color", Yasuo.MainColor)

            Menu.Separator()

            Menu.Checkbox("draw.E", "Draw E range", true)
            Menu.ColorPicker("draw.E.color", " ^ Color", Yasuo.MainColor)

            Menu.Separator()

            Menu.Checkbox("draw.R", "Draw R range", true)
            Menu.ColorPicker("draw.R.color", " ^ Color", Yasuo.MainColor)

            Menu.Separator()

            Menu.Checkbox("draw.healthbar", "Draw damage on healthbar", true)
        end)
    end

    Menu.RegisterMenu("oriyasuo", "OriYasuo", YasuoMenu)
end

function OnLoad()
    Yasuo.LoadMenu()

    Yasuo.RegisterEvents()

    return true
end

