if Player.CharName ~= "Viktor" then return false end

require("common.log")
module("Goru Viktor", package.seeall, log.setup)
clean.module("Goru Viktor", clean.seeall, log.setup)

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
local EMaxRange = 1200
local ECastRange = 550
local EMeleeRange = 300
local RLeashRange = 1200

local pred = nil 

local Player = ObjectManager.Player.AsHero
local timer = os.clock()



-- Globals
local OrbwalkerMode = nil
local Utils = {}
local Viktor = {}



Viktor.Menu = nil
Viktor.TargetSelector = nil
Viktor.Logic = {}

Viktor.storm = nil


-- Spells




Viktor.Q = SpellLib.Targeted({
  Slot = SpellSlots.Q,
  Range = 750,
  Key = "Q",
})


Viktor.W = SpellLib.Skillshot({

 Slot = SpellSlots.W,
  Range = 800,
  Delay = 0.25,
  Type = "Circular"

})


Viktor.E = SpellLib.Skillshot({
  Slot = SpellSlots.E,
  Range = 1200,
  Radius = 80,
  Speed = 1050,
  Delay = 0,
  Collisions = { Heroes = false, Minions = false, WindWall = true, Wall = false },
  UseHitbox = true,
  Type = "Linear",
   Key = "E",
})


Viktor.E2 = SpellLib.Skillshot({
  Slot = SpellSlots.E,
  Range = 650,
  Radius = 80,
  Speed = 1050,
  Delay = 0,
  Collisions = { Heroes = false, Minions = false, WindWall = true, Wall = false },
  UseHitbox = true,
  Type = "Linear"
})


Viktor.R = SpellLib.Skillshot({

 Slot = SpellSlots.R,
  Range = 800,
  Radius = 160,
  Delay = 0.25,
  Type = "Circular"

})


Viktor.R2 = SpellLib.Skillshot({

 Slot = SpellSlots.R,
  Range = 1800,
  Radius = 160,
  Delay = 0.25,
  Type = "Circular"

})


function dmg(spell)
    local dmg = 0
   
    if spell.Key == "Q" then 
        dmg = (60 + (Viktor.Q:GetLevel() - 1) * 15) + (0.4 * Player.TotalAP)
    end
    if spell.Key == "E" then 
        dmg = (70 + (Viktor.E:GetLevel() - 1) * 40) + (0.5 * Player.TotalAP)
    end
    
    return math.floor(dmg) 
end




function Utils.GameAvailable()

  return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end




function Viktor.Logic.Q(Target, MustUse)
  if not Viktor.Q:IsReady() then return false end
  if not MustUse then return false end
  if not Target then return false end
  
  Target = Target.AsAI
  if Viktor.Q:IsReady() then
  return Viktor.Q:Cast(Target)
  end



end





 function Viktor.Logic.E(Target, HitChance, MustUse)
  if not Viktor.E:IsReady() then return false end
  if not MustUse then return false end
  if not Target then return false end

    startPos = Player.Position:Extended(Target.Position, ECastRange)
    startPos2 = Player.Position:Extended(Target.Position, 300)
    startPos3 = Player.Position:Extended(Target.Position, 50)
    pred = Prediction.GetPredictedPosition(Target, Viktor.E2, startPos)

  --enemy within super melee range
  if Player.Position:Distance(Target.Position) <= EMeleeRange  then
     Viktor.E:Cast(Target,startPos3)
  --enemy within e casst range
  elseif Player.Position:Distance(Target.Position) <= ECastRange then
     Viktor.E:Cast(Target,startPos2)

  elseif Player.Position:Distance(Target.Position) < Viktor.E.Range  then
       --print("pred hitchace"..pred.HitChance)
       --print("menu hitchace"..HitChance)
       if pred and pred.HitChance >=HitChance then
            Viktor.E:Cast(pred.CastPosition,startPos)                
        end         
  end
                
end


function Viktor.Logic.Combo()
  local QTarget = Viktor.Q:GetTarget()
  if Viktor.Logic.Q(QTarget, Menu.Get("Combo.Q.Use")) then return true end


  local ETarget = Viktor.E:GetTarget()
  if Viktor.Logic.E(ETarget, Menu.Get("Misc.EHitChance"), Menu.Get("Combo.E.Use")) then return true end

 end


 function Viktor.OnCreateObject(sender)

    if sender.Name:find("Viktor_Base_R_Droid") then 
        Viktor.storm = sender
  
        
    end

  

 end



  function Viktor.OnDeleteObject(sender)

    if sender.Name:find("Viktor_Base_R_Droid") then 
        Viktor.storm = nil

    end

  

 end


  function Viktor.RFollow()

   local RTarget = Viktor.R2:GetTarget()

   -- and (os.clock()-timer) >1
  if RTarget then
    --timer = os.clock()
    Viktor.R2:Cast(RTarget)
    return true 
                
    end
end


function Viktor.LoadMenu()
  Menu.RegisterMenu("Goru Viktor", "Goru Viktor", function ()
    Menu.ColumnLayout("Casting", "Casting", 1, true, function ()
      Menu.ColoredText("Combo", 0xB65A94FF, true)
      Menu.Checkbox("Combo.Q.Use", "UseQ", true)
      Menu.Checkbox("Combo.E.Use", "UseE", true)

    end)

    --KS
     Menu.Separator()
     Menu.ColumnLayout("KS", "KS", 1, true, function ()
            Menu.ColoredText("Kill Steal", 0xB65A94FF, true)
            Menu.Checkbox("KS.Q"," Use Q to KS", true)
            Menu.Checkbox("KS.E"," Use E to KS", true)
           

    end)


    --misc menu
    Menu.Separator()
     Menu.ColumnLayout("Misc", "Misc", 1, true, function ()
      Menu.Checkbox("Misc.AutoRSilence", "Auto R On interruptible skill ( Danger level > 3)", true)
      Menu.Keybind("Misc.AutoRFollow", "R follow target (toggle) ", string.byte('T'),true,true)
      Menu.Checkbox("Misc.NoOrb", "Disable Orbwalker", true)
      Menu.Slider("Misc.EHitChance","EHitChance",0.7, 0, 1, 0.1)
      --Menu.Dropdown("Misc.EHitChance", "EHitChance", 2, HitChanceStrings)

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

function Viktor.OnDraw()
  local Spells = { Q = Viktor.Q,
                   E = Viktor.E,
                   W = Viktor.W,
                   R = Viktor.R,}
 


  -- Draw them all
  for k, v in pairs(Spells) do
    if Menu.Get("Drawings." .. k) then
        Renderer.DrawCircle3D(Player.Position, v.Range, 30, 1, 0xFFFFFFFF)
    end
  end


  return true
end






function Viktor.OnInterruptibleSpell(unit, spell, Danger, EndTime, CanMoveDuringChannel)
    if not unit.IsEnemy then return end
    if not Menu.Get("Misc.AutoRSilence") then return end 
    if Viktor.R:IsReady() and Player.Position:Distance(unit) <= 800 and  unit.IsHero and Danger>3  then
        Viktor.R:Cast(unit)
    end
end







function Viktor.OnTick()

  if not Utils.GameAvailable()  then return false end
  OrbwalkerMode = Orbwalker.GetMode()
 
  local OrbwalkerLogic = Viktor.Logic[OrbwalkerMode]

   if Menu.Get("KS.Q") then
        for k,v in pairs(Viktor.Q:GetTargets()) do 
            local dmg = DamageLib.CalculateMagicalDamage(Player,v,dmg(Viktor.Q))
            local Ks  = Viktor.Q:GetKillstealHealth(v)
            if dmg > Ks and Viktor.Logic.Q(v, 1) then return end
            
        end
    end
    
    if Menu.Get("KS.E") then
        for k,v in pairs(Viktor.E:GetTargets()) do 
            local dmg = DamageLib.CalculateMagicalDamage(Player,v,dmg(Viktor.E))
            local Ks  = Viktor.E:GetKillstealHealth(v)
            if dmg > Ks and Viktor.Logic.E(v, 0.75,1) then return end
            
        end
    end

    

  if Menu.Get("Misc.NoOrb") then 
    Orbwalker.BlockMove(true) 
  else
    Orbwalker.BlockMove(false) 
  end 



 
  if OrbwalkerLogic then
    if OrbwalkerLogic() then return true end
  end

   if Viktor.storm and Menu.Get("Misc.AutoRFollow") then 
        Viktor.RFollow()
  end
end





function OnLoad()
  Viktor.LoadMenu()
  Viktor.TargetSelector = TargetSelector(Viktor.Menu)

  for EventName, EventId in pairs(Events) do
    if Viktor[EventName] then
        EventManager.RegisterCallback(EventId, Viktor[EventName])
    end
  end

	return true
end





