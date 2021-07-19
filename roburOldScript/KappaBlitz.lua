--[[
  Template

  Credits: Developer team

  Ressources:
    League version : https://ddragon.leagueoflegends.com/api/versions.json
    League champions datas : http://ddragon.leagueoflegends.com/cdn/10.21.1/data/en_US/championFull.json

  Advices:
    Combo --> Every spell possible with logic
    Harass --> Poke spells with logic
    LaneClear --> AOE Spells / Low CD/Mana Cost ones with logic
    JungleClear --> Situational with logic
    LastHit --> Spells used to last hit with logic
]]

require("common.log")
module("KappaBlitz", package.seeall, log.setup)
clean.module("KappaBlitz", package.seeall, log.setup)

-- Globals
local CoreEx = _G.CoreEx
local Libs = _G.Libs

local Menu = Libs.NewMenu
local Prediction = Libs.Prediction
local Orbwalker = Libs.Orbwalker
local CollisionLib = Libs.CollisionLib
local DamageLib = Libs.DamageLib
local SpellLib = Libs.Spell
local TargetSelector = Libs.TargetSelector

local ObjectManager = CoreEx.ObjectManager
local EventManager = CoreEx.EventManager
local Input = CoreEx.Input
local Enums = CoreEx.Enums
local Game = CoreEx.Game
local Geometry = CoreEx.Geometry
local Renderer = CoreEx.Renderer

local SpellSlots = Enums.SpellSlots
local SpellStates = Enums.SpellStates
local BuffTypes = Enums.BuffTypes
local Events = Enums.Events
local HitChance = Enums.HitChance
local HitChanceStrings = { "Collision", "OutOfRange", "VeryLow", "Low", "Medium", "High", "VeryHigh", "Dashing", "Immobile" };

local Player = ObjectManager.Player.AsHero

-- Check if we are using the right champion
if Player.CharName ~= "Blitzcrank" then return false end

-- Spells
local Q = SpellLib.Skillshot({
  Slot = SpellSlots.Q,
  Range = 1125,
  Radius = 70,
  Speed = 1800,
  Delay = 0.25,
  Collisions = { Heroes = true, Minions = true, WindWall = true, Wall = false },
  UseHitbox = true,
  Type = "Linear"
})

local W = SpellLib.Active({
  Slot = SpellSlots.W,
  Range = Q.Range + 500
})

local E = SpellLib.Active({
  Slot = SpellSlots.E,
  Range = Player.AttackRange
})

local R = SpellLib.Active({
  Slot = SpellSlots.R,
  Range = 600,
  Delay = 0.25
})

local Utils = {}

local Blitzcrank = {}

Blitzcrank.Menu = nil
Blitzcrank.TargetSelector = nil
Blitzcrank.Logic = {}

function Utils.GameAvailable()
  -- Is game available to automate stuff
  return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

function Utils.WithinMinRange(Target, Min)
  -- if target distance is higher than min range
  local Distance = Player:EdgeDistance(Target.Position)
  if Distance >= Min then return true end
  return false
end

function Utils.WithinMaxRange(Target, Max)
  -- if target distance is lower than max range
  local Distance = Player:EdgeDistance(Target.Position)
  if Distance <= Max then return true end
  return false
end

function Utils.InRange(Range, Type)
  -- return target count in range
  return #(Blitzcrank.TargetSelector:GetValidTargets(Range, ObjectManager.Get("enemy", Type), false))
end

function Utils.IsWhitelisted(Target)
  -- is enemy champion whitelisted?
  Target = Target.AsHero
  return Menu.Get(Target.CharName .. Target.Handle, true)
end

function Utils.GetRedBlueJungle(Range)
  -- return blue or red
  local Minions = ObjectManager.Get("neutral", "minions")

  for _, Minion in pairs(Minions) do
    Minion = Minion.AsMinion
    if
      Minion and
      Minion.IsTargetable and
      (
        Minion.Name == "SRU_Red4.1.1" or
        Minion.Name == "SRU_Red10.1.1" or
        Minion.Name == "SRU_Blue1.1.1" or
        Minion.Name == "SRU_Blue7.1.1"
      )
    then
      if Utils.WithinMaxRange(Minion, Range) then return Minion end
    end
  end

  return nil
end

function Blitzcrank.Logic.Q(MustUse, HitChance)
  if not MustUse then return false end
  local QTarget = Q:GetTarget()
  if
    (QTarget and
    Q:IsReady() and
    Utils.IsWhitelisted(QTarget) and
    Utils.WithinMinRange(QTarget, Orbwalker.GetTrueAutoAttackRange(QTarget)))
  then
    if Q:CastOnHitChance(QTarget, HitChance) then return true end
  end

  return false
end

function Blitzcrank.Logic.W(MustUse)
  if not MustUse then return false end
  local WTarget = W:GetTarget()
  if (WTarget and
    W:IsReady() and
    ((Utils.WithinMinRange(WTarget, Q.Range) and Q:IsReady()) or
    Utils.WithinMaxRange(WTarget, Orbwalker.GetTrueAutoAttackRange(WTarget))))
  then
    if W:Cast() then return true end
  end
end

function Blitzcrank.Logic.E(MustUse)
  if not MustUse then return false end
  local ETarget = Orbwalker.GetTarget() --E:GetTarget()
  if (ETarget and E:IsReady()) then
    if E:Cast() then return true end
  end
end

function Blitzcrank.Logic.R(MustUse, InRangeCount)
  if not MustUse then return false end
  local RTarget = R:GetTarget()
  if (RTarget and R:IsReady() and Utils.InRange(R.Range, "heroes") >= InRangeCount) then
    if R:Cast() then return true end
  end
end

function Blitzcrank.Logic.CalculateRDamage(Target)
  local Level = R:GetLevel()
  local BaseDamage = ({250, 375, 500})[Level]
  local BonusDamage = Player.FlatMagicalDamageMod
  local RawDamage = BaseDamage + BonusDamage
  return DamageLib.CalculateMagicalDamage(Player, Target, RawDamage)
end

function Blitzcrank.Logic.QRSteal(MustUse)
  if not MustUse then return false end
  local Minion = Utils.GetRedBlueJungle(Q.Range)

  if
    Minion and
    Blitzcrank.Logic.CalculateRDamage(Minion) >= Minion.Health
  then
    if Q:IsReady() and Q:Cast(Minion) then return true end
    if R:IsReady() and Utils.WithinMaxRange(Minion, R.Range) and R:Cast() then return true end
  end

  return false
end

function Blitzcrank.Logic.Combo()
  -- combo logic
  if (Blitzcrank.Logic.Q(Menu.Get("Combo.Q.Use"), Menu.Get("Combo.Q.HitChance"))) then return true end
  if (Blitzcrank.Logic.W(Menu.Get("Combo.W.Use"))) then return true end
  if (Blitzcrank.Logic.E(Menu.Get("Combo.E.Use"))) then return true end
  if (Blitzcrank.Logic.R(Menu.Get("Combo.R.Use"), Menu.Get("Combo.R.MinHit"))) then return true end
  return false
end

function Blitzcrank.Logic.Harass()
  -- harass logic
  if (Blitzcrank.Logic.Q(Menu.Get("Harass.Q.Use"), Menu.Get("Harass.Q.HitChance"))) then return true end
  if (Blitzcrank.Logic.E(Menu.Get("Harass.E.Use"))) then return true end
end

function Blitzcrank.LoadMenu()
  Menu.RegisterMenu("KappaBlitz", "KappaBlitz", function ()
    Menu.ColumnLayout("Casting", "Casting", 2, true, function ()
      Menu.ColoredText("Combo", 0xB65A94FF, true)
      Menu.ColoredText("> Q", 0x0066CCFF, false)
      Menu.Checkbox("Combo.Q.Use", "Use", true)
      Menu.Dropdown("Combo.Q.HitChance", "HitChance", 5, HitChanceStrings)
      Menu.ColoredText("> W", 0x0066CCFF, false)
      Menu.Checkbox("Combo.W.Use", "Use", true)
      Menu.ColoredText("> E", 0x0066CCFF, false)
      Menu.Checkbox("Combo.E.Use", "Use", true)
      Menu.ColoredText("> R", 0x0066CCFF, false)
      Menu.Checkbox("Combo.R.Use", "Use", true)
      Menu.Slider("Combo.R.MinHit", "Min Hit", 2, 1, 5, 1)
      Menu.NextColumn()
      Menu.ColoredText("Harass", 0xB65A94FF, true)
      Menu.ColoredText("> Q", 0x0066CCFF, false)
      Menu.Checkbox("Harass.Q.Use", "Use", true)
      Menu.Dropdown("Harass.Q.HitChance", "HitChance", 5, HitChanceStrings)
      Menu.ColoredText("> E", 0x0066CCFF, false)
      Menu.Checkbox("Harass.E.Use", "Use", true)
    end)
    Menu.Separator()
    Menu.ColumnLayout("JungleSteal", "Jungle Steal", 1, true, function ()
      Menu.ColoredText("Jungle Steal", 0xB65A94FF, true)
      Menu.Keybind("JungleSteal.HotKey", "HotKey", string.byte('T'))
    end)
    Menu.Separator()
    Menu.ColumnLayout("Drawings", "Drawings", 2, true, function ()
      Menu.ColoredText("Whitelist", 0xB65A94FF, true)
      for _, Object in pairs(ObjectManager.Get("enemy", "heroes")) do
        local Handle = Object.Handle
        local Name = Object.AsHero.CharName
        Menu.Checkbox(Name .. Handle, Name, true)
      end
      Menu.NextColumn()
      Menu.ColoredText("Drawings", 0xB65A94FF, true)
      Menu.Checkbox("Drawings.Q", "Q", true)
      Menu.Checkbox("Drawings.R", "R", true)
    end)
  end)
end

function Blitzcrank.OnDraw()
  -- If player is not on screen than don't draw
  if not Player.IsOnScreen then return false end;

  -- Get spells ranges
  local Spells = { Q = Q, R = R }

  -- Draw them all
  for k, v in pairs(Spells) do
    if Menu.Get("Drawings." .. k) then
        Renderer.DrawCircle3D(Player.Position, v.Range, 30, 1, 0xFFFFFFFF)
    end
  end

  return true
end

function Blitzcrank.OnTick()
  -- Check if game is available to do anything
  if not Utils.GameAvailable() then return false end

  -- Get current orbwalker mode
  local OrbwalkerMode = Orbwalker.GetMode()

  -- Get the right logic func
  local OrbwalkerLogic = Blitzcrank.Logic[OrbwalkerMode]

  -- Call it
  if OrbwalkerLogic then
    return OrbwalkerLogic()
  end

  -- Auto stuff
  Blitzcrank.Logic.QRSteal(Menu.Get("JungleSteal.HotKey"))

  return true
end

function OnLoad()
  -- Load our menu
  Blitzcrank.LoadMenu()

  -- Load our target selector
  Blitzcrank.TargetSelector = TargetSelector()

  -- Register callback for func available in champion object
  for EventName, EventId in pairs(Events) do
    if Blitzcrank[EventName] then
        EventManager.RegisterCallback(EventId, Blitzcrank[EventName])
    end
  end

	return true
end