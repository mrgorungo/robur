--[[
  Gank Alerter

  Credits: wxx
]]

require("common.log")
module("KappaGankAlerter", package.seeall, log.setup)
clean.module("KappaGankAlerter", package.seeall, log.setup)

local CoreEx = _G.CoreEx
local Libs   = _G.Libs

local Menu = Libs.NewMenu

local Game          = CoreEx.Game
local Enums         = CoreEx.Enums
local Renderer      = CoreEx.Renderer
local ObjectManager = CoreEx.ObjectManager
local EventManager  = CoreEx.EventManager

local Events = Enums.Events

local LocalPlayer = ObjectManager.Player.AsHero

local Utils     = {}
local Callbacks = {}

function Utils.IsGameAvailable()
  -- Is game available to automate stuff
  return not (
    Game.IsChatOpen()  or
    Game.IsMinimized() or
    LocalPlayer.IsDead or
    LocalPlayer.IsRecalling
  )
end

function Callbacks.LoadMenu()
  Menu.RegisterMenu("KappaGankAlerter", "KappaGankAlerter", function ()
    Menu.ColumnLayout("Drawings", "Drawings", 1, true, function ()
      Menu.Slider("MinDistance", "Min Distance", 1200, 0, 1500, 100)
      Menu.Slider("MaxDistance", "Max Distance", 3000, 3000, 5000, 100)
      Menu.Checkbox("Enemy", "Show Enemy", true)
      Menu.Checkbox("Ally", "Show Ally", false)
    end)
  end)
end

function Callbacks.OnDraw()
  if not Utils.IsGameAvailable() then return false end

  local ShowEnemy =  Menu.Get("Enemy")
  local ShowAlly = Menu.Get("Ally")

  if not ShowAlly and not ShowEnemy then return false end

  local MinDistance = Menu.Get("MinDistance")
  local MaxDistance = Menu.Get("MaxDistance")

  local Players = ObjectManager.Get("all", "heroes")

  for _, Player in pairs(Players) do
    Player = Player.AsHero

    local Distance = LocalPlayer:Distance(Player.Position)

    if
      Player.IsAlive and
      Distance >= MinDistance and
      Distance <= MaxDistance
    then
      local MaxMinDelta = MaxDistance - MinDistance
      local DistanceDelta = Distance - MinDistance

      local Ratio = DistanceDelta / MaxMinDelta
      local Thickness = math.floor(math.abs(Ratio - 1) * 10)

      local CharNameSize = Renderer.CalcTextSize(Player.CharName)
      local CharNamePosition3D = LocalPlayer.Position:Extended(Player.Position, 200)
      local CharNamePosition2D = Renderer.WorldToScreen(CharNamePosition3D)

      CharNamePosition2D.x = CharNamePosition2D.x - (CharNameSize.x / 2)

      if(Player.IsAlly and ShowAlly) then
        Renderer.DrawLine3D(LocalPlayer.Position, Player.Position, Thickness, 0x00FF00FF)
        Renderer.DrawText(CharNamePosition2D, CharNameSize, Player.CharName, 0xFFFFFFFF)
      elseif(Player.IsEnemy and ShowEnemy) then
        Renderer.DrawLine3D(LocalPlayer.Position, Player.Position, Thickness, 0xFF0000FF)
        Renderer.DrawText(CharNamePosition2D, CharNameSize, Player.CharName, 0xFFFFFFFF)
      end
    end
  end

  return true
end

function OnLoad()
  -- Load Menu
  Callbacks.LoadMenu()

  -- Register callback for func available in champion object
  for EventName, EventId in pairs(Events) do
    if Events[EventName] then
        EventManager.RegisterCallback(EventId, Callbacks[EventName])
    end
  end

  INFO("> KappaGankAlerter Enabled !")

  return true
end