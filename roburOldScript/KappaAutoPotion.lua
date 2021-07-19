--[[
  Auto Potion

  Credits: wxx
]]

require("common.log")

local Meta = {
  Name = "KappaAutoPotion",
  Version = "1.0.0"
}

module(Meta.Name, package.seeall, log.setup)
clean.module(Meta.Name, package.seeall, log.setup)

local CoreEx = _G.CoreEx
local Libs   = _G.Libs

local Game          = CoreEx.Game
local Enums         = CoreEx.Enums
local ObjectManager = CoreEx.ObjectManager
local EventManager  = CoreEx.EventManager
local Input         = CoreEx.Input

local Menu  = Libs.NewMenu
local Spell = Libs.Spell

local Events    = Enums.Events
local SpellSlots = Enums.SpellSlots
local ItemSlots = Enums.ItemSlots

local LocalPlayer = ObjectManager.Player.AsHero

-- POTIONS LIST
local PotionsList = {
  { Id = 2003, Buff = "Item2003", HP = true, Mana = false },
  { Id = 2010, Buff = "Item2010", HP = true, Mana = true },
  { Id = 2031, Buff = "ItemCrystalFlask", HP = true, Mana = false },
  { Id = 2033, Buff = "ItemDarkCrystalFlask", HP = true, Mana = true }
}

-- UTILS --
local Utils = {}
function Utils.LoadMenu()
  Menu.RegisterMenu(Meta.Name, Meta.Name, function ()
    Menu.ColumnLayout("Drawings", "Drawings", 1, true, function ()
      Menu.Checkbox("EnabledHP", "Enabled", true)
      Menu.Slider("MinHP", "Minimum HP", 25, 0, 100, 1)
      Menu.Checkbox("EnabledMana", "Enabled", true)
      Menu.Slider("MinMana", "Minimum Mana", 10, 0, 100, 1)
    end)
  end)
end

function Utils.IsGameAvailable()
  -- Is game available to automate stuff
  return not (
    Game.IsChatOpen()  or
    Game.IsMinimized() or
    LocalPlayer.IsDead
  )
end

function Utils.UseItem(Id)
  for Key, Item in pairs(LocalPlayer.Items) do
    if Item.ItemId == Id then
      local PotionSlot = SpellSlots.Item1 + Key
  
      local PotionSpell = Spell.Active({ Slot = PotionSlot })
  
      if PotionSpell:IsReady() then
        return PotionSpell:Cast()
      end
    end
  end
  return false
end

-- CALLBACKS --
local Callbacks = {}
function Callbacks.OnTick()
  if not Utils.IsGameAvailable() then return false end

  for _, Potion in ipairs(PotionsList) do
    if LocalPlayer:GetBuff(Potion.Buff) then return false end
  end
  
  for _, Potion in ipairs(PotionsList) do
    if Menu.Get("EnabledHP") and LocalPlayer.HealthPercent * 100 <= Menu.Get("MinHP") and Potion.HP then
      if Utils.UseItem(Potion.Id) then return true end
    end
    if Menu.Get("EnabledMana") and LocalPlayer.ManaPercent * 100 <= Menu.Get("MinMana") and Potion.Mana then
      if Utils.UseItem(Potion.Id) then return true end
    end
  end

  return false
end

function OnLoad()
  -- Load Menu
  Utils.LoadMenu()

  -- Register callback for func available in champion object
  for EventName, EventId in pairs(Events) do
    if Events[EventName] then
        EventManager.RegisterCallback(EventId, Callbacks[EventName])
    end
  end

  INFO("> " .. Meta.Name .. " Enabled !")

  return true
end