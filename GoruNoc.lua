if Player.CharName ~= "Nocturne" then return end

module("Goru Noc", package.seeall, log.setup)
clean.module("Goru Noc", clean.seeall, log.setup)

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
local HPred = Libs.HealthPred
local TS = Libs.TargetSelector()
local DashLib = Libs.DashLib

local ObjectManager = CoreEx.ObjectManager
local EventManager = CoreEx.EventManager
local Input = CoreEx.Input
local Enums = CoreEx.Enums
local Game = CoreEx.Game
local Geometry = CoreEx.Geometry
local Renderer = CoreEx.Renderer
local Vector = CoreEx.Geometry.Vector
local SpellSlots = Enums.SpellSlots
local SpellStates = Enums.SpellStates
local BuffTypes = Enums.BuffTypes
local Events = Enums.Events
local HitChanceEnum = Enums.HitChance

local Nav = CoreEx.Nav

local Nocturne = {}
local qMana = 0
local wMana = 0
local eMana = 0
local rMana = 0
local spellslist = {}

Nocturne.Q = SpellLib.Skillshot({
  Slot = SpellSlots.Q,
  Range = 1200,
  Delay = 0.250,
  Speed = 1300,
  Radius = 140,
  Collisions = { Heroes = false, Minions = false, WindWall = true },
  Type = "Linear",
  UseHitbox = true,
  Key = "Q"
})



Nocturne.W = SpellLib.Active({
  Slot = SpellSlots.W,
 
  Key = "W"
})

Nocturne.E = SpellLib.Targeted({
  Slot = SpellSlots.E,
  Range = 450,

  Key = "E"
})





Nocturne.R = SpellLib.Active({
  Slot = SpellSlots.R,
  Range = 600,
  Delay = 0.350,
  Key = "R"
})

Nocturne.TargetSelector = nil
Nocturne.Logic = {}

local Utils = {}

function Utils.IsGameAvailable()
  return not (
  Game.IsChatOpen()  or
  Game.IsMinimized() or
  Player.IsDead
  )
end

function Utils.SetMana()
  if (Player.Health/Player.MaxHealth) * 100 < 20 then
    qMana = 0
    wMana = 0
    eMana = 0
    rMana = 0
    return true
  end
  if Nocturne.Q:IsReady() then
    qMana = Nocturne.Q:GetManaCost()
  else
    qMana = 0
  end
  if Nocturne.W:IsReady() then
    wMana = Nocturne.W:GetManaCost()
  else
    wMana = 0
  end
  if Nocturne.E:IsReady() then
    eMana = Nocturne.E:GetManaCost()
  else
    eMana = 0
  end
  if Nocturne.R:IsReady() then
    rMana = Nocturne.R:GetManaCost()
  else
    rMana = 0
  end
  return false
end

function Utils.GetTargets(Spell)
  return TS:GetTargets(Spell.Range,true)
end

function Utils.GetTargetsRange(Range)
  return {TS:GetTarget(Range,true)}
end

function Utils.HasBuffType(unit,buffType)
  local ai = unit.AsAI
  if ai.IsValid then
    for i = 0, ai.BuffCount do
      local buff = ai:GetBuff(i)
      if buff and buff.IsValid and buff.BuffType == buffType then
        return true
      end
    end
  end
  return false
end

function Utils.Count(spell)
  local num = 0
  for k, v in pairs(ObjectManager.GetNearby("enemy", "heroes")) do
    local hero = v.AsHero
    if hero and hero.IsTargetable and hero:Distance(Player.Position) < spell.Range then
      num = num + 1
    end
  end
  return num
end
function Utils.hasValue(tab,val)
  for index, value in ipairs(tab) do
    if value == val then
      return true
    end
  end
  return false
end

function Utils.tablefind(tab,el)
  for index, value in pairs(tab) do
    if value == el then
      return index
    end
  end
end

function Nocturne.Logic.Combo()
  local MenuValueQ = Menu.Get("Combo.Q")
  local MenuValueE = Menu.Get("Combo.E")
  local enemy = TS:GetTarget(Nocturne.Q.Range,true)
   local Eenemy = TS:GetTarget(Nocturne.E.Range,false)
   if enemy then 
    if Nocturne.Q:IsReady() and MenuValueQ  then
      local predQ = Nocturne.Q:GetPrediction(enemy)
      if predQ ~= nil and predQ.HitChanceEnum >= 0.5 and Nocturne.Q:IsInRange(enemy) then
        if Nocturne.Q:Cast(predQ.CastPosition) then return true end
      end
    end
    end

    if Eenemy then 
    if Nocturne.E:IsReady() and MenuValueE and not Eenemy.IsZombie  then
        if Nocturne.E:Cast(Eenemy) then return true end
    end
    end
    
 
  return false
end

function Nocturne.Logic.Harass()
  if Menu.Get("ManaSlider") >= Player.ManaPercent * 100 then return false end
  local MenuValueQ = Menu.Get("Harass.Q")
  local MenuValueW = Menu.Get("Harass.W")
  for k, enemy in pairs(Utils.GetTargets(Nocturne.Q)) do
    if Nocturne.Q:IsReady() and MenuValueQ then
      local predQ = Nocturne.Q:GetPrediction(enemy)
      if predQ ~= nil and predQ.HitChanceEnum >= HitChanceEnum.VeryHigh and Nocturne.Q:IsInRange(enemy) then
        if Nocturne.Q:Cast(predQ.CastPosition) then return true end
      end
    end
    if Nocturne.W:IsReady() and MenuValueW and not enemy.IsZombie then
      local predW = Nocturne.W:GetPrediction(enemy)
      if predW ~= nil and Nocturne.W:GetDamage(enemy) >= enemy.Health and Nocturne.W:IsInRange(enemy) and predW.HitChanceEnum >= HitChanceEnum.VeryHigh then
        if Nocturne.W:Cast(predW.CastPosition) then return true end
      elseif predW ~= nil and Nocturne.W:IsInRange(predW.CastPosition) and predW.HitChanceEnum >= HitChanceEnum.VeryHigh then
        if Nocturne.W:Cast(predW.CastPosition) then return true end
      elseif predW ~= nil and not Menu.Get("AutoWcc") and not enemy.CanMove and predW.HitChanceEnum == HitChanceEnum.Immobile and Nocturne.W:IsInRange(predW.CastPosition) then
        if Nocturne.W:Cast(predW.CastPosition) then return true end
      end
    end
  end
  return false
end

function Nocturne.Logic.Waveclear()
  local MenuValueQ = Menu.Get("WaveClear.Q")
  local MenuValueW = Menu.Get("WaveClear.W")
  local Cannons = {}
  local otherMinions = {}
  local JungleMinions = {}
  for k, v in pairs(ObjectManager.GetNearby("enemy", "minions")) do
    local minion = v.AsMinion
    local pos = minion:FastPrediction(Game.GetLatency()+ Nocturne.W.Delay)
    if minion.IsTargetable and (minion.IsSiegeMinion or minion.IsSuperMinion) and Nocturne.W:IsInRange(minion) then
      table.insert(Cannons, pos)
    end
    if minion.IsTargetable and minion.IsLaneMinion and Nocturne.W:IsInRange(minion) then
      table.insert(otherMinions, pos)
    end
    if Nocturne.W:IsReady() and  MenuValueW then
      local cannonsPos, hitCount1 = Nocturne.W:GetBestCircularCastPos(Cannons, Nocturne.W.Radius)
      local laneMinionsPos, hitCount2 = Nocturne.W:GetBestCircularCastPos(otherMinions, Nocturne.W.Radius)

      if cannonsPos ~= nil and laneMinionsPos ~= nil and Menu.Get("ManaSliderLane") <= Player.ManaPercent * 100 then
        if hitCount1 >= 1 then
          if Nocturne.W:Cast(cannonsPos) then return true end
        end
      end
      if laneMinionsPos ~= nil and Menu.Get("ManaSliderLane") <= Player.ManaPercent * 100 then
        if hitCount2 >= 3 then
          if Nocturne.W:Cast(laneMinionsPos) then return true end
        end
      end
    end
  end
  for k, v in pairs(ObjectManager.GetNearby("neutral", "minions")) do
    local minion = v.AsMinion
    local pos = minion:FastPrediction(Game.GetLatency()+ Nocturne.W.Delay)
    if Nocturne.W:IsInRange(minion) and minion.IsTargetable and not minion.IsJunglePlant then
      table.insert(JungleMinions, pos)
      local predQ = Prediction.GetPredictedPosition(minion, Nocturne.Q, Player.Position)
      if predQ ~= nil and Nocturne.Q:IsReady() and MenuValueQ and predQ.HitChanceEnum >= HitChanceEnum.VeryHigh  then
        if Nocturne.Q:Cast(predQ.CastPosition) then return true end
      end
    end
    if Nocturne.W:IsReady() and  MenuValueW then
      local JungleMinionPos, hitCount3 = Nocturne.W:GetBestCircularCastPos(JungleMinions, Nocturne.W.Radius)
      if JungleMinionPos ~= nil then
        if hitCount3 >= 1 then
          if Nocturne.W:Cast(JungleMinionPos) then return true end
        end
      end
    end
  end
  return false
end

function Nocturne.Logic.Auto()
  if Menu.Get("AutoQcc") then
    for k, v in pairs(ObjectManager.GetNearby("enemy", "heroes")) do
      local enemy = v.AsHero
      if not enemy.CanMove and Nocturne.Q:IsReady() and Nocturne.Q:IsInRange(enemy) then
        if Nocturne.Q:CastOnHitChance(enemy,Enums.HitChance.Immobile) then return true end
      end
    end
  end

  return false
end

function Nocturne.OnProcessSpell(sender,spell)
  if sender.IsHero and sender.IsEnemy and Menu.Get("AutoW") then

  --[[rint(sender.CharName)
  print(spell.Name)
  print(spell.CastAngle)
  print(spell.CastRadius)
  print(spell.CastRadius2)
  (Vector(pred):LineDistance(Vector(spell.StartPos),Vector(spell.EndPos),true) <= powCalc) or 
  ]]
    --for _, v in pairs(ObjectManager.GetNearby("ally","heroes")) do
      local hero = Player

        local pred = hero:FastPrediction(Game.GetLatency())
        if spell.LineWidth > 0 then
       
          local powCalc = (spell.LineWidth + hero.BoundingRadius)^2
          if (Vector(hero.Position):LineDistance(Vector(spell.StartPos),Vector(spell.EndPos),true) <= powCalc) and Nocturne.W:IsReady() and hero:Distance(spell.EndPos) <50 + hero.BoundingRadius then
            if Utils.hasValue(spellslist,spell.Name) then
              if Nocturne.W:Cast() then print("skillshot") print(sender.CharName) print(spell.Name) return true end
            end
          end
        elseif (hero:Distance(spell.EndPos) <50 + hero.BoundingRadius or pred:Distance(spell.EndPos) < 50 + hero.BoundingRadius ) and (Nocturne.W:IsReady() ) then
          if Utils.hasValue(spellslist,spell.Name) then
            if Nocturne.W:Cast()  then  print("skillshot 50") print(sender.CharName) print(spell.Name)  return true end
          end
        end
      
      if (spell.Target and spell.Target.IsHero and spell.Target.IsMe ) and Menu.Get("1" .. spell.Target.AsHero.CharName) and Nocturne.W:IsReady() then
        if Utils.hasValue(spellslist,spell.Name) then
          if Nocturne.W:Cast() then print("targ") print(sender.CharName) print(spell.Name)  return true end
        end
      end
      if (spell.ConeAngle  > 0 or  spell.ConeRadius  > 0 or  spell.CastRadius  > 0) and (spell.CastDelay ~=0 ) and (Player:Distance(sender.Position) < 450 ) then
        if Utils.hasValue(spellslist,spell.Name) and Nocturne.W:IsReady() then
            if Nocturne.W:Cast() then return true end
        end
      end
      
      
        
    --end
  end
  return false
end

function Nocturne.OnBuffGain(obj,buffInst)
 
  return false
end

function Nocturne.OnInterruptibleSpell(source, spell, danger, endT, canMove)
  
  return false
end

function Nocturne.OnGapclose(source,dash)
  if source.IsEnemy and source.IsHero  and not dash.IsBlink then
    local paths = dash:GetPaths()
    local endPos = paths[#paths].EndPos
    local predQ = Prediction.GetPredictedPosition(source.AsHero, Nocturne.Q, Player.Position)
    if Player:Distance(endPos) <= 600 and Nocturne.Q:IsReady() and predQ.HitChanceEnum >= HitChanceEnum.VeryHigh then
      if Nocturne.Q:Cast(predQ.CastPosition) then return true end
    end
    
  end
  return false
end

function Nocturne.OnDraw()
  if Player.IsVisible and Player.IsOnScreen and not Player.IsDead then
    local Pos = Player.Position
    local spells = {Nocturne.Q,Nocturne.W,Nocturne.E,Nocturne.R}
    for k, v in pairs(spells) do
      if Menu.Get("Drawing."..v.Key..".Enabled", true) then
        if Renderer.DrawCircle3D(Pos, v.Range, 30, 3, Menu.Get("Drawing."..v.Key..".Color")) then return true end
      end
    end
  end
  return false
end

function Nocturne.OnUpdate()
  if not Utils.IsGameAvailable() then return false end
  local OrbwalkerMode = Orbwalker.GetMode()

  local OrbwalkerLogic = Nocturne.Logic[OrbwalkerMode]

  if OrbwalkerLogic then
    if OrbwalkerLogic() then return true end
  end
  if Nocturne.Logic.Auto() then return true end
  if Utils.SetMana() then return true end
  return false
end

function Nocturne.LoadMenu()
  local function NocturneMenu()
    Menu.ColumnLayout("Casting", "Casting", 2, true, function ()
    Menu.ColoredText("Combo", 0xB65A94FF, true)
    Menu.ColoredText("> Q", 0x0066CCFF, false)
    Menu.Checkbox("Combo.Q", "Use Q", true)
    Menu.ColoredText("> E", 0x0066CCFF, false)
    Menu.Checkbox("Combo.E", "Use E", true)
    Menu.ColoredText("> R", 0x0066CCFF, false)
    Menu.Checkbox("Combo.R", "Use R", true)
    Menu.Slider("Combo.HitcountR", "[R] HitCount", 2, 1, 5)
    Menu.ColoredText("Harass", 0x118AB2FF, true)
    Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
    Menu.Slider("ManaSlider","",50,0,100)
    Menu.ColoredText("> Q", 0x0066CCFF, false)
    Menu.Checkbox("Harass.Q", "Use Q", true)
    Menu.ColoredText("> W", 0x0066CCFF, false)
    Menu.Checkbox("Harass.W", "Use W", true)
    Menu.ColoredText("WaveClear/JungleClear", 0xEF476FFF, true)
    Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
    Menu.Slider("ManaSliderLane","",45,0,100)
    Menu.ColoredText("> Q", 0x0066CCFF, false)
    Menu.Checkbox("WaveClear.Q", "Use Q", true)
    Menu.ColoredText("> W", 0x0066CCFF, false)
    Menu.Checkbox("WaveClear.W", "Use W", false)
    Menu.NextColumn()
    Menu.ColoredText("Auto", 0xB65A94FF, true)
    Menu.Checkbox("AutoQcc", "Auto Q chain cc", true)

    Menu.Checkbox("AutoW", "Auto W Shield", true)
    Menu.NewTree("EList","E ally whitelist", function()
    Menu.ColoredText("E Whitelist", 0x06D6A0FF, true)
    for _, Object in pairs(ObjectManager.Get("ally", "heroes")) do
      local Name = Object.AsHero.CharName
      Menu.Checkbox("1" .. Name, "Use on " .. Name, true)
    end
    end)
    Menu.NewTree("EListSpells","E spells whitelist", function()
    Menu.ColoredText("E SpellsWhitelist", 0x06D6A0FF, true)
    for _, Object in pairs(ObjectManager.Get("enemy", "heroes")) do
      local hero = Object.AsHero
      local Name = Object.AsHero.CharName
      Menu.NewTree(Name,Name, function()
      Menu.Checkbox("Q" .. Name, "Use for " .. Name .. "Q", true)
      Menu.Checkbox("W" .. Name, "Use for " .. Name .. "W", true)
      Menu.Checkbox("E" .. Name, "Use for " .. Name .. "E", true)
      Menu.Checkbox("R" .. Name, "Use for " .. Name .. "R", true)
      end)
      local spellQName = hero:GetSpell(SpellSlots.Q).Name
      local spellWName = hero:GetSpell(SpellSlots.W).Name
      local spellEName = hero:GetSpell(SpellSlots.E).Name
      local spellRName = hero:GetSpell(SpellSlots.R).Name
      if Menu.Get("Q"..Name) then
        table.insert(spellslist,spellQName)
      elseif not Menu.Get("Q"..Name) and Utils.hasValue(spellslist,spellQName) then
        table.remove(spellslist,Utils.tablefind(spellslist,spellQName))
      end
      if Menu.Get("W"..Name) then
        table.insert(spellslist,spellWName)
      elseif not Menu.Get("W"..Name) and Utils.hasValue(spellslist,spellWName) then
        table.remove(spellslist,Utils.tablefind(spellslist,spellWName))
      end
      if Menu.Get("E"..Name) then
        table.insert(spellslist,spellEName)
      elseif not Menu.Get("E"..Name) and Utils.hasValue(spellslist,spellEName) then
        table.remove(spellslist,Utils.tablefind(spellslist,spellEName))
      end
      if Menu.Get("R"..Name) then
        table.insert(spellslist,spellRName)
      elseif not Menu.Get("R"..Name) and Utils.hasValue(spellslist,spellRName) then
        table.remove(spellslist,Utils.tablefind(spellslist,spellRName))
      end
    end
    end)
    Menu.Separator()
    Menu.ColoredText("Drawing", 0xB65A94FF, true)
    Menu.Checkbox("Drawing.Q.Enabled",   "Draw [Q] Range",true)
    Menu.ColorPicker("Drawing.Q.Color", "Draw [Q] Color", 0x118AB2FF)
    Menu.Checkbox("Drawing.E.Enabled",   "Draw [E] Range",false)
    Menu.ColorPicker("Drawing.E.Color", "Draw [E] Color", 0x118AB2FF)
    Menu.Checkbox("Drawing.W.Enabled",   "Draw [W] Range",false)
    Menu.ColorPicker("Drawing.W.Color", "Draw [W] Color", 0x118AB2FF)
    Menu.Checkbox("Drawing.R.Enabled",   "Draw [R] Range",false)
    Menu.ColorPicker("Drawing.R.Color", "Draw [R] Color", 0x118AB2FF)
    end)
  end
  if Menu.RegisterMenu("Goru Noc", "Goru Noc", NocturneMenu) then return true end
  return false
end

function OnLoad()
  Nocturne.LoadMenu()
  for EventName, EventId in pairs(Events) do
    if Nocturne[EventName] then
      EventManager.RegisterCallback(EventId, Nocturne[EventName])
    end
  end
  return true
end
