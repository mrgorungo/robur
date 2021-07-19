--[[
  KappaSenna

  Credits: wxx
]]

require("common.log")

local Meta = {
  Name = "KappaSenna",
  Version = "1.0.0",
  ChampionName = "Senna"
}

module(Meta.Name, package.seeall, log.setup)
clean.module(Meta.Name, package.seeall, log.setup)

local CoreEx = _G.CoreEx
local Libs   = _G.Libs

local Menu = Libs.NewMenu

local Game          = CoreEx.Game
local Input         = CoreEx.Input
local Enums         = CoreEx.Enums
local Renderer      = CoreEx.Renderer
local ObjectManager = CoreEx.ObjectManager
local EventManager  = CoreEx.EventManager
local Vector        = CoreEx.Geometry.Vector

local TargetSelector = Libs.TargetSelector
local Spell          = Libs.Spell
local Orbwalker      = Libs.Orbwalker
local DamageLib      = Libs.DamageLib

local Events     = Enums.Events
local SpellSlots = Enums.SpellSlots
local HitChance  = Enums.HitChance

local LocalPlayer = ObjectManager.Player.AsHero

-- Check if we are using the right champion
if LocalPlayer.CharName ~= Meta.ChampionName then return false end

local HitChanceList = { "Collision", "OutOfRange", "VeryLow", "Low", "Medium", "High", "VeryHigh", "Dashing", "Immobile" }

-- UTILS --
local Utils = {}

function Utils.IsGameAvailable()
  -- Is game available to automate stuff
  return not (
    Game.IsChatOpen()  or
    Game.IsMinimized() or
    LocalPlayer.IsDead
  )
end

function Utils.IsInRange(From, To, Min, Max)
  local Distance = From:Distance(To)
  return Distance >= Min and Distance <= Max
end

function Utils.IsValidTarget(Target)
  return Target.IsTargetable and Target.IsAlive
end

function Utils.LoadMenu()
  Menu.RegisterMenu(Meta.Name, Meta.Name, function ()
    Menu.NewTree("Q", "[Q] Piercing Darkness", function()
      Menu.NewTree("ComboQ", "Combo", function()
          Menu.Checkbox("ComboUseQ", "Enabled", true)
      end)
      Menu.NewTree("HarassQ", "Harass", function()
        Menu.Checkbox("HarassUseQ", "Enabled", true)
        Menu.Slider("HarassQMana", "Min Mana", 60, 0, 100, 1)
      end)
      Menu.NewTree("AutoQ", "Auto", function()
        Menu.Checkbox("AutoUseQAlly", "Enabled Heal", true)
        Menu.Slider("AutoQHealth", "HP %", 50, 0, 100, 1)
    end)
    end)
    Menu.NewTree("W", "[W] Last Embrace", function()
      Menu.NewTree("ComboW", "Combo", function()
          Menu.Checkbox("ComboUseW", "Enabled", true)
          Menu.Dropdown("ComboHitChanceW", "Hitchance", 6, HitChanceList)
      end)
      Menu.NewTree("GapcloseW", "Gapclose", function()
        Menu.Checkbox("GapcloseUseW", "Enabled", true)
      end)
      Menu.NewTree("ImmobilizedW", "Immobilized", function()
        Menu.Checkbox("ImmobilizedUseW", "Enabled", true)
      end)
    end)
    Menu.NewTree("E", "[E] Curse of the Black Mist", function()
      Menu.NewTree("GapcloseE", "Gapclose", function()
          Menu.Checkbox("GapcloseUseE", "Enabled", true)
      end)
    end)
    Menu.NewTree("R", "[R] Dawning Shadow", function()
      Menu.NewTree("AutoR", "Auto", function()
          Menu.Checkbox("AutoUseR", "Enabled", true)
          Menu.Dropdown("AutoHitChanceR", "Hitchance", 6, HitChanceList)
          Menu.Slider("AutoRMinRange", "Min Range", 1300, 0, 3000, 100)
          Menu.Slider("AutoRMaxRange", "Max Range", 50000, 3000, 50000, 100)
      end)
    end)
  end)
end

-- CHAMPION SPELLS --
local Champion  = {}

Champion.Spells = {}

Champion.Spells.Q = Spell.Targeted({
  Slot = SpellSlots.Q,
  SlotString = "Q",
  Range = Orbwalker.GetTrueAutoAttackRange(LocalPlayer)
})

Champion.Spells.W = Spell.Skillshot({
  Slot = SpellSlots.W,
  SlotString = "W",
  Range = 1300,
  Speed = 1200,
  Radius = 70,
  EffectRadius = 280,
  Delay = 0.25,
  Collisions = { Heroes = true, Minions = true, WindWall = true },
  UseHitbox = true,
  Type = "Linear"
})

Champion.Spells.E = Spell.Active({
  Slot = SpellSlots.E,
  SlotString = "E"
})

Champion.Spells.R = Spell.Skillshot({
  Slot = SpellSlots.R,
  SlotString = "R",
  Range = math.huge,
  Speed = 20000,
  Radius = 160,
  Delay = 1,
  Collisions = { Heroes = true, WindWall = true },
  UseHitbox = true,
  Type = "Linear",
})

Champion.Spells.R.GetDamage = function (Target)
  local Level = Champion.Spells.R:GetLevel()
  local BaseDamage = ({ 250, 375, 500 })[Level]
  local BonusDamage = LocalPlayer.FlatPhysicalDamageMod + (LocalPlayer.FlatMagicalDamageMod * 0.5)
  local TotalDamage = BaseDamage + BonusDamage
  return DamageLib.CalculatePhysicalDamage(LocalPlayer, Target, TotalDamage)
end

Champion.Spells.R.GetShield = function (Target)
  local Level = Champion.Spells.R:GetLevel()
  local BaseShield = ({ 120, 160, 200 })[Level]
  local BonusShield = LocalPlayer.TotalAP * 0.4 -- todo: mist count
  return BaseShield + BonusShield
end

-- CHAMPION LOGICS --
Champion.Logic = {}

function Champion.Logic.Q(Target, Enable)
  local Q = Champion.Spells.Q
  
  if
    Enable and
    Target and
    Q:IsReady() and
    Q:IsInRange(Target)
  then
    return Q:Cast(Target)
  end

  return false
end

function Champion.Logic.W(Target, Hitchance, Enable)
  local W = Champion.Spells.W
  
  if
    Enable and
    Target and
    W:IsReady()
  then
    return W:CastOnHitChance(Target, Hitchance)
  end

  return false
end

function Champion.Logic.E(Target, DashInstance, Enable)
  local E = Champion.Spells.E
  local Position = LocalPlayer.Position
  local EndPosition = DashInstance:GetPosition(E.Delay)
  
  if
    Enable and
    Utils.IsInRange(Position, EndPosition, 0, 500) and
    Target and
    E:IsReady()
  then
    return E:Cast()
  end

  return false
end

function Champion.Logic.R(Target, Hitchance, MinRange, MaxRange, Enable)
  local R = Champion.Spells.R

  if
    Enable and
    Target and
    R:IsReady() and
    Utils.IsInRange(LocalPlayer.Position, Target.Position, MinRange, MaxRange) and
    Target.Health <= Champion.Spells.R.GetDamage(Target)
  then
    return R:CastOnHitChance(Target, Hitchance)
  end

  return false
end

function Champion.Logic.Combo()
  if Champion.Logic.W(Champion.Spells.W:GetTarget(), Menu.Get("ComboHitChanceW"), Menu.Get("ComboUseW")) then return true end
  if Champion.Logic.Q(Champion.Spells.Q:GetTarget(), Menu.Get("ComboUseQ")) then return true end

  return false
end

function Champion.Logic.Harass()
  if (LocalPlayer.Mana / LocalPlayer.MaxMana) * 100 < Menu.Get("HarassQMana") then return false end
  
  if Champion.Logic.Q(Champion.Spells.Q:GetTarget(), Menu.Get("HarassUseQ")) then return true end

  return false
end

function Champion.Logic.AutoCatchSoul(OrbwalkerMode)
  if OrbwalkerMode == "Combo" then return false end
  -- TODO: no filter available for senna souls?
  local GameObjects = ObjectManager.Get("all", "minions")

  for _, GameObject in pairs(GameObjects) do
    if GameObject then
      local Target = GameObject.AsMinion

      if
        Utils.IsValidTarget(Target) and
        Target.IsSennaSoul and
        Utils.IsInRange(LocalPlayer.Position, Target.Position, 0, Orbwalker.GetTrueAutoAttackRange(LocalPlayer, Target))
      then
        return Orbwalker.Orbwalk(LocalPlayer.Position, Target)
      end
    end
  end

  return false
end

function Champion.Logic.AutoHeroes()
  local GameObjects = ObjectManager.Get("all", "heroes")

  for _, GameObject in pairs(GameObjects) do
    if GameObject then
      local Target = GameObject.AsHero

      if Utils.IsValidTarget(Target) then
        if Target.IsEnemy then
          if
            Champion.Logic.R(
              Target,
              Menu.Get("AutoHitChanceR"),
              Menu.Get("AutoRMinRange"),
              Menu.Get("AutoRMaxRange"),
              Menu.Get("AutoUseR")
            )
          then return true end
        end
        if Target.IsAlly and Target.Handle ~= LocalPlayer.Handle then
          if
            Champion.Logic.Q(
              Target,
              Menu.Get("AutoUseQAlly") and
              (Target.HealthPercent * 100) <= Menu.Get("AutoQHealth")
            )
          then return true end
        end
      end
    end
  end

  return false
end

function Champion.Logic.Auto(OrbwalkerMode)
  if Champion.Logic.AutoCatchSoul(OrbwalkerMode) then return true end
  if Champion.Logic.AutoHeroes() then return true end

  return false
end

-- CALLBACKS --
local Callbacks = {}

function Callbacks.OnTick()
  -- Update range
  Champion.Spells.Q.Range = Orbwalker.GetTrueAutoAttackRange(LocalPlayer)

  -- Get current orbwalker mode
  local OrbwalkerMode = Orbwalker.GetMode()

  -- Automatic stuff
  if Champion.Logic.Auto(OrbwalkerMode) then return false end

  -- Get the right logic func
  local OrbwalkerLogic = Champion.Logic[OrbwalkerMode]

  -- Call it
  if OrbwalkerLogic then
    return OrbwalkerLogic()
  end

  return false
end

function Callbacks.OnHeroImmobilized(GameObject, EndTime)
  if GameObject.IsEnemy and Champion.Logic.W(GameObject, HitChance.VeryHigh, Menu.Get("ImmobilizedUseW")) then return true end

  return false
end

function Callbacks.OnGapclose(GameObject, DashInstance)
  if GameObject.IsEnemy then
    if Champion.Logic.W(GameObject, HitChance.VeryHigh, Menu.Get("GapcloseUseW")) then return true end
    if Champion.Logic.E(GameObject, DashInstance, Menu.Get("GapcloseUseE")) then return true end
  end

  return false
end

function Callbacks.OnBuffGain(GameObject, BuffInst)
  -- not sync with orbwalker range update tick
  -- update Q range every 20 stacks
  -- if
  --   GameObject.Handle == LocalPlayer.Handle and
  --   BuffInst.Name == "sennapassivehaste"
  -- then
  --   Champion.Spells.Q.Range = Orbwalker.GetTrueAutoAttackRange(LocalPlayer)
  -- end

  -- return true
end

function Callbacks.OnDraw()
  -- If player is not on screen than don't draw
  if not LocalPlayer.IsOnScreen then return false end;

  -- Get spells ranges
  local Spells = { Q = Champion.Spells.Q, W = Champion.Spells.W }

  -- Draw them all
  for k, v in pairs(Spells) do
    Renderer.DrawCircle3D(LocalPlayer.Position, v.Range, 30, 1, 0xFFFFFFFF)
    Renderer.DrawText(
      Renderer.WorldToScreen(
        LocalPlayer.Position:Extended(
          Vector(LocalPlayer.Position.x + 1, LocalPlayer.Position.y, LocalPlayer.Position.z),
          v.Range + 10
        )
      ),
      Vector(100, 100),
      v.SlotString,
      0xFFFFFFFF
  )
  end

  return true
end

-- ENTRYPOINT --
function OnLoad()
  -- Load Menu
  Utils.LoadMenu()

  -- Register callback for func available in champion object
  for EventName, EventId in pairs(Events) do
    if Events[EventName] then
        EventManager.RegisterCallback(EventId, Callbacks[EventName])
    end
  end

  return true
end