--[[
  KappaRyze

  Credits: wxx

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
module("KappaRyze", package.seeall, log.setup)
clean.module("KappaRyze", package.seeall, log.setup)

-- Globals
local CoreEx = _G.CoreEx
local Libs = _G.Libs

local Menu = Libs.NewMenu
local Prediction = Libs.Prediction
local Orbwalker = Libs.Orbwalker
local CollisionLib = Libs.CollisionLib
local DamageLib = Libs.DamageLib
local ImmobileLib = Libs.ImmobileLib
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
if Player.CharName ~= "Ryze" then return false end

-- Globals
local OrbwalkerMode = nil
local Utils = {}
local Ryze = {}

Ryze.Menu = nil
Ryze.TargetSelector = nil
Ryze.Logic = {}

-- Spells
Ryze.Q = SpellLib.Skillshot({
  Slot = SpellSlots.Q,
  Range = 1000,
  Radius = 55,
  Speed = 1700,
  Delay = 0.25,
  Collisions = { Heroes=true, Minions=true, WindWall=true },
  UseHitbox = true,
  Type = "Linear"
})

Ryze.W = SpellLib.Targeted({
  Slot = SpellSlots.W,
  Range = 550
})

Ryze.E = SpellLib.Targeted({
  Slot = SpellSlots.E,
  Range = 550
})

function Utils.GameAvailable()
  -- Is game available to automate stuff
  return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

function Utils.WithinMinRange(Target, Min)
  -- if target distance is higher than min range
  local Distance = Player:Distance(Target.Position)
  if Distance >= Min then return true end
  return false
end

function Utils.WithinMaxRange(Target, Max)
  -- if target distance is lower than max range
  local Distance = Player:Distance(Target.Position)
  if Distance <= Max then return true end
  return false
end

function Utils.GetBoundingRadius(Target)
  return Player.BoundingRadius + Target.BoundingRadius
end

function Utils.InRange(Target, Range, Type)
  -- return target in range
  local Objects = ObjectManager.Get("enemy", Type)
  local Array = {}
  local Index = 0

  for _, Object in pairs(Objects) do
    if Object and Object ~= Target then
      Object = Object.AsAI
      if Object.IsTargetable then
        local Distance = Target:Distance(Object.Position)
        if Distance <= Range + Utils.GetBoundingRadius(Object) then
          Array[Index] = Object
          Index = Index + 1
        end
      end
    end
  end

  return { Array = Array, Count = Index }
end

function Utils.GetClosestMinion(Range)
  local Minions = ObjectManager.Get("all", "minions")

  local FoundMinion = { Obj = nil, Distance = math.huge }

  for _, Minion in pairs(Minions) do
    Minion = Minion.AsMinion
    if
      Minion and
      Minion.IsTargetable and
      not Minion.IsJunglePlant and
      (Minion.IsEnemy or 
      Minion.IsNeutral or
      Minion.IsMonster)
    then
      local Distance = Player:Distance(Minion.Position)
      if Distance <= Range and Distance < FoundMinion.Distance then
        FoundMinion.Obj = Minion
        FoundMinion.Distance = Distance
      end
    end
  end

  return FoundMinion.Obj
end

function Ryze.Logic.Q(Target, HitChance, MustUse)
  if not Ryze.Q:IsReady() then return false end
  if not MustUse then return false end
  if not Target then return false end

  Target = Target.AsAI

  if not HitChance then
    return Ryze.Q:Cast(Target)
  end

  return Ryze.Q:CastOnHitChance(Target, HitChance)
end

function Ryze.Logic.W(Target, MustUse)
  if not Ryze.W:IsReady() then return false end
  if not MustUse then return false end
  if not Target then return false end

  Target = Target.AsAI

  if Ryze.E.IsLearned and not Target:GetBuff("RyzeE") then return false end

  return Ryze.W:Cast(Target)
end

function Ryze.Logic.E(Target, MustUse)
  if not Ryze.E:IsReady() then return false end
  if not MustUse then return false end
  if not Target then return false end
  
  Target = Target.AsAI

  return Ryze.E:Cast(Target)
end

function Ryze.Logic.Combo()
  local ETarget = Ryze.E:GetTarget()
  if Ryze.Logic.E(ETarget, Menu.Get("Combo.E.Use")) then return true end

  local WTarget = Ryze.W:GetTarget()
  if Ryze.Logic.W(WTarget, Menu.Get("Combo.W.Use")) then return true end

  if not WTarget or not Ryze.W:IsReady() then
    local QTarget = Ryze.Q:GetTarget()
    if Ryze.Logic.Q(QTarget, Menu.Get("Combo.Q.HitChance"), Menu.Get("Combo.Q.Use")) then return true end
  end
end

function Ryze.Logic.Harass()
  if (Player.Mana / Player.MaxMana < (Menu.Get("Harass.ManaSave") / 100)) then return false end

  local Target

  Target = Ryze.Q:GetTarget()
  if Ryze.Logic.Q(Target, Menu.Get("Harass.Q.HitChance"), Menu.Get("Harass.Q.Use")) then return true end

  Target = Ryze.E:GetTarget()
  if Ryze.Logic.E(Target, Menu.Get("Harass.E.Use")) then return true end
end

function Ryze.Logic.Waveclear()
  if (Player.Mana / Player.MaxMana < (Menu.Get("Waveclear.ManaSave") / 100)) then return false end

  local Target

  Target = Utils.GetClosestMinion(Ryze.Q.Range)
  if Ryze.Logic.Q(Target, nil, Menu.Get("Waveclear.Q.Use")) then return true end

  Target = Utils.GetClosestMinion(Ryze.E.Range)
  if Ryze.Logic.E(Target, Menu.Get("Waveclear.E.Use")) then return true end
end

function Ryze.LoadMenu()
  Menu.RegisterMenu("KappaRyze", "KappaRyze", function ()
    Menu.ColumnLayout("Casting", "Casting", 3, true, function ()
      Menu.ColoredText("Combo", 0xB65A94FF, true)
      Menu.ColoredText("> Q", 0x0066CCFF, false)
      Menu.Checkbox("Combo.Q.Use", "Use", true)
      Menu.Dropdown("Combo.Q.HitChance", "HitChance", 5, HitChanceStrings)
      Menu.ColoredText("> W", 0x0066CCFF, false)
      Menu.Checkbox("Combo.W.Use", "Use", true)
      Menu.ColoredText("> E", 0x0066CCFF, false)
      Menu.Checkbox("Combo.E.Use", "Use", true)
      Menu.NextColumn()
      Menu.ColoredText("Harass", 0xB65A94FF, true)
      Menu.Slider("Harass.ManaSave", "Mana Save", 65, 0, 100, 1)
      Menu.ColoredText("> Q", 0x0066CCFF, false)
      Menu.Checkbox("Harass.Q.Use", "Use", true)
      Menu.Dropdown("Harass.Q.HitChance", "HitChance", 5, HitChanceStrings)
      Menu.ColoredText("> E", 0x0066CCFF, false)
      Menu.Checkbox("Harass.E.Use", "Use", true)
      Menu.NextColumn()
      Menu.ColoredText("Waveclear", 0xB65A94FF, true)
      Menu.Slider("Waveclear.ManaSave", "Mana Save", 0, 0, 100, 1)
      Menu.ColoredText("> Q", 0x0066CCFF, false)
      Menu.Checkbox("Waveclear.Q.Use", "Use", true)
      Menu.ColoredText("> E", 0x0066CCFF, false)
      Menu.Checkbox("Waveclear.E.Use", "Use", true)
    end)
    Menu.Separator()
    Menu.ColumnLayout("Drawings", "Drawings", 1, true, function ()
      Menu.ColoredText("Drawings", 0xB65A94FF, true)
      Menu.Checkbox("Drawings.Q", "Q", true)
      Menu.Checkbox("Drawings.W", "W", true)
      Menu.Checkbox("Drawings.E", "E", true)
      Menu.Checkbox("Drawings.R", "R", true)
    end)
  end)
end

function Ryze.OnDraw()
  -- Draw on minimap
  if Menu.Get("Drawings.R") then
    Renderer.DrawCircleMM(Player.Position, 3000, 1, 0xFFFFFFFF)
  end

  -- If player is not on screen than don't draw
  if not Player.IsOnScreen then return false end;

  -- Get spells ranges
  local Spells = { Q = Ryze.Q, W = Ryze.W, E = Ryze.E }

  -- Draw them all
  for k, v in pairs(Spells) do
    if Menu.Get("Drawings." .. k) then
        Renderer.DrawCircle3D(Player.Position, v.Range, 30, 1, 0xFFFFFFFF)
    end
  end

  return true
end

function Ryze.OnPreAttack(Args)
  if not OrbwalkerMode or OrbwalkerMode ~= "Combo" then return false end
  Args.Process = not (Ryze.Q:IsReady() or Ryze.W:IsReady() or Ryze.E:IsReady())
end

function Ryze.OnTick()
  -- Check if game is available to do anything
  if not Utils.GameAvailable() then return false end

  -- Get current orbwalker mode
  OrbwalkerMode = Orbwalker.GetMode()

  -- Get the right logic func
  local OrbwalkerLogic = Ryze.Logic[OrbwalkerMode]

  -- Call it
  if OrbwalkerLogic then
    if OrbwalkerLogic() then return true end
  end

  return false
end

function OnLoad()
  -- Load our menu
  Ryze.LoadMenu()

  -- Load our target selector
  Ryze.TargetSelector = TargetSelector(Ryze.Menu)

  -- Register callback for func available in champion object
  for EventName, EventId in pairs(Events) do
    if Ryze[EventName] then
        EventManager.RegisterCallback(EventId, Ryze[EventName])
    end
  end

  DEBUG("> You are using KappaRyze !")

	return true
end