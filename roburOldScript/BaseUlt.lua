require("common.log")
module("BaseUlt", package.seeall, log.setup)
clean.module("BaseUlt", clean.seeall, log.setup)

local SDK               = _G.CoreEx
local DamageLib         = _G.Libs.DamageLib
local CollisionLib      = _G.Libs.CollisionLib
local Menu              = _G.Libs.NewMenu
local ObjectManager     = SDK.ObjectManager
local EventManager      = SDK.EventManager
local Input             = SDK.Input
local Enums             = SDK.Enums
local Game              = SDK.Game
local Geometry          = SDK.Geometry
local Renderer          = SDK.Renderer
local Player            = ObjectManager.Player
local Events            = Enums.Events
local SpellStates       = Enums.SpellStates
local Vector            = Geometry.Vector
local _Q, _W, _E, _R    = 0, 1, 2, 3

local BaseUlt = {}
local SupportedChampions = {
    ["Ashe"]    = true,
    ["Draven"]  = true,
    ["Ezreal"]  = true,
    ["Jinx"]    = true,
	["Karthus"]    = true,
	["Senna"]    = true,
}

if not SupportedChampions[Player.CharName] then return end

function BaseUlt.LoadMenu()
	Menu.RegisterMenu("BaseUlt", "BaseUlt", function()
        Menu.Checkbox("Enabled", "Enabled", true)
        Menu.Text("")
        Menu.Text("")
        Menu.Text("===> Credits <===")
        Menu.Text("- Shulepin")
        Menu.Text("- Pinkmare")
    end)
end
---@type fun(slot: number):boolean
local IsReady = function(slot)
    return Player:GetSpellState(slot) == 0
end

---@type fun():Vector
local GetBasePosition = function()
    return Player.TeamId == 100 and Vector(14302, 172, 14387) or Vector(415, 182, 415)
end

---@type fun(delay: number, speed: number, position: Vector):number
local CalculateTravelTime = function(delay, speed, position)
    return (delay + Player:EdgeDistance(position) / speed) - (Game.GetLatency() / 1000)
end

local RecallData = {}
local SpellData = {
    ["Ashe"] = {
        ---@type fun():number
        ["GetDelay"] = function()
            return 0.25
        end,

        ---@type fun():number
        ["GetSpeed"] = function()
            return 1600
        end,

        ---@type fun(unit: GameObject, endPosition: Vector):number
        ["GetDamage"] = function(unit, endPosition)
            local level = Player:GetSpell(_R).Level
            local baseDamage = ({200, 400, 600})[level > 0 and level or 1]
            local bonusDamage = Player.AsAI.FlatMagicalDamageMod
            local rawDamage = baseDamage + bonusDamage
            local collision = CollisionLib.SearchHeroes(Player.Position, endPosition, 260, 1700, 0.25)

            if collision.Result then
                return 0
            end

            return DamageLib.CalculatePhysicalDamage(Player, unit, rawDamage)
        end,
    },
    ["Draven"] = {
        ---@type fun():number
        ["GetDelay"] = function()
            return 0.25
        end,

        ---@type fun():number
        ["GetSpeed"] = function()
            return 2000
        end,

        ---@type fun(unit: GameObject):number
        ["GetDamage"] = function(unit)
            local level = Player:GetSpell(_R).Level
            local baseDamage = ({175, 275, 375})[level > 0 and level or 1]
            local bonusDamage = Player.AsAI.FlatPhysicalDamageMod * 1.1
            local rawDamage = baseDamage + bonusDamage
            return DamageLib.CalculatePhysicalDamage(Player, unit, rawDamage)
        end,
    },
    ["Ezreal"] = {
        ---@type fun():number
        ["GetDelay"] = function()
            return 1
        end,

        ---@type fun():number
        ["GetSpeed"] = function()
            return 2000
        end,

        ---@type fun(unit: GameObject):number
        ["GetDamage"] = function(unit)
            local level = Player:GetSpell(_R).Level
            local baseDamage = ({350, 500, 650})[level > 0 and level or 1]
            local bonusDamage = Player.AsAI.FlatPhysicalDamageMod + (Player.AsAI.FlatMagicalDamageMod * 0.9)
            local rawDamage = baseDamage + bonusDamage
            return DamageLib.CalculateMagicalDamage(Player, unit, rawDamage)
        end,
    },
    ["Jinx"] = {
        ---@type fun():number
        ["GetDelay"] = function()
            return 0.65
        end,

        ---@type fun(endPosition: Vector):number
        ["GetSpeed"] = function(endPosition)
            local distance = Player:EdgeDistance(endPosition)
            return distance > 1300 and (1300 * 1700 + ((distance - 1300) * 2200)) / distance or 1700
        end,

        ---@type fun(unit: GameObject, endPosition: Vector):number
        ["GetDamage"] = function(unit, endPosition)
            local level = Player:GetSpell(_R).Level
            local baseDamage = ({250, 350, 450})[level > 0 and level or 1]
            local bonusDamage = Player.AsAI.FlatPhysicalDamageMod * 1.5
            local missHealthDamage = (unit.AsHero.MaxHealth - unit.AsHero.Health) * ({0.25, 0.30, 0.35})[level > 0 and level or 1]
            local rawDamage = baseDamage + bonusDamage + missHealthDamage
            local collision = CollisionLib.SearchHeroes(Player.Position, endPosition, 280, 1700, 0.65)

            if collision.Result then
                return 0
            end

            return DamageLib.CalculatePhysicalDamage(Player, unit, rawDamage)
        end,
    },
	
	["Karthus"] = {
        ---@type fun():number
        ["GetDelay"] = function()
            return 3
        end,

        ---@type fun():number
        ["GetSpeed"] = function()
            return 20000
        end,

        ---@type fun(unit: GameObject):number
        ["GetDamage"] = function(unit)
            local level = Player:GetSpell(_R).Level
            local baseDamage = ({200, 350, 500})[level > 0 and level or 1]
            local bonusDamage = (Player.AsAI.FlatMagicalDamageMod * 0.75)
            local rawDamage = baseDamage + bonusDamage
            return DamageLib.CalculateMagicalDamage(Player, unit, rawDamage)
        end,
    },
	["Senna"] = {
        ---@type fun():number
        ["GetDelay"] = function()
            return 1
        end,

        ---@type fun():number
        ["GetSpeed"] = function()
            return 20000
        end,

        ---@type fun(unit: GameObject):number
        ["GetDamage"] = function(unit)
            local level = Player:GetSpell(_R).Level
            local baseDamage = ({250, 375, 500})[level > 0 and level or 1]
            local bonusDamage = Player.AsAI.FlatPhysicalDamageMod + (Player.AsAI.FlatMagicalDamageMod * 0.5)
            local rawDamage = baseDamage + bonusDamage
            return DamageLib.CalculatePhysicalDamage(Player, unit, rawDamage)
        end,
    },
}

---@type fun():void
local OnTick = function()
    if not SpellData[Player.CharName] or not IsReady(_R) or not Menu.Get("Enabled") then
        goto continue
    end

    local data = SpellData[Player.CharName]
    local basePosition = GetBasePosition()
    local travelTime = CalculateTravelTime(data.GetDelay(), data.GetSpeed(basePosition), basePosition)

    for handle, recallData in pairs(RecallData) do
        if not recallData.Status or recallData.Status ~= "Started" then
            goto continue
        end

        ---@type GameObject
        local unit = recallData.Object
        local recallTime = recallData.StartTime + recallData.Duration - Game.GetTime()
        local damage = data.GetDamage(unit, basePosition)

        if damage > unit.AsAI.Health then
            if recallTime > travelTime and recallTime < travelTime + 0.1 then
                Input.Cast(_R, basePosition)
            end
        end

        ::continue::
    end

    ::continue::
end

---@type fun(object: GameObject, name: string, duration: number, status: string):void
local OnTeleport = function(object, name, duration, status)
    if object.IsEnemy then
        RecallData[object.AsAI.Handle] = {
            Object = object,
            Name = name,
            Duration = duration,
            Status = status,
            StartTime = Game.GetTime()
        }
    end
end

---@type fun():boolean
function OnLoad()
	BaseUlt.LoadMenu()
    EventManager.RegisterCallback(Events.OnTick, OnTick)
    EventManager.RegisterCallback(Events.OnTeleport, OnTeleport)

    return true
end
