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
local ECastRange = 550--player to CastRange
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


Viktor.E = SpellLib.Skillshot({--all Erange
  Slot = SpellSlots.E,
  Range = 1200,
  Radius = 100,
  Speed = 1050,
  Delay = 0,
  Collisions = { Heroes = false, Minions = false, WindWall = true, Wall = false },
  UseHitbox = true,
  Type = "Linear",
   Key = "E",
})


Viktor.E2 = SpellLib.Skillshot({--castrange to endpoint
  Slot = SpellSlots.E,
  Range = 650,
  Radius = 100,
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


function cmpfunc( a, b )
       return a.price <  b.price
    end


 function Viktor.Logic.E(Target, HitChance, MustUse)
  if not Viktor.E:IsReady() then return false end
  if not MustUse then return false end
  if not Target then return false end





    local foundEnemies = GetHeroes(Player.Position, Viktor.E.Range, "enemy")

    if #foundEnemies >=2 then

         table.sort(foundEnemies,
	function(a,b)
		return (a.Position:Distance(Player.Position) < b.Position:Distance(Player.Position) )
	end)

       -- local closestHero = Viktor.TargetSelector:SortTargetsForMode( foundEnemies, "ClosestToHero")
        --print("foundEnemies1"..foundEnemies[1].BonusHealth)
        --print("foundEnemies2"..foundEnemies[2].BonusHealth)
        if foundEnemies[1] == Target then
            firstTarget = Target
            secTarget = foundEnemies[2]
        else
            firstTarget = foundEnemies[1]
            secTarget = Target
        end

        if firstTarget.Position:Distance(secTarget.Position)<=650 then --firstTarget within ECastRange
            if Player.Position:Distance(firstTarget.Position) <= ECastRange then
                --print("Emelee")
                 --print(firstTarget.BonusHealth)
                 --print(Target.BonusHealth)
                Viktor.E2:Cast(secTarget,Player.Position:Extended(firstTarget.Position,Player.Position:Distance(firstTarget.Position)-10))
            elseif  Player.Position:Distance(firstTarget.Position) <= Viktor.E.Range then
            Pos = Player.Position:Extended(firstTarget.Position, ECastRange)
                --print("ELong")
                 --print(firstTarget.BonusHealth)
                 --print(Target.BonusHealth)
               --[[ local list ={}
                 table.insert(list, firstTarget)
                 table.insert(list, secTarget)
                 local position, hitCount = Viktor.E2:GetBestLinearCastPos(list)
                 Pos = Player.Position:Extended(firstTarget.Position, ECastRange)
                 if hitCount == 2 then
           
                
                    
                    Viktor.E2:Cast(position,Pos)
                 else--]]
                    pred = Prediction.GetPredictedPosition(Target, Viktor.E2, Pos)
                    if pred and pred.HitChance >=HitChance then
                        Viktor.E2:Cast(pred.CastPosition,Pos)                
                     end    
                 end
            
        end
    end
            











    --SINGLE TARGET ---


  if Player.Position:Distance(Target.Position) <= ECastRange  then   --enemy within ecast range

     Viktor.E:Cast(Target,Player.Position:Extended(Target.Position,Player.Position:Distance(Target.Position)-100))
  elseif Player.Position:Distance(Target.Position) <= Viktor.E.Range  then --within max range
    startPos = Player.Position:Extended(Target.Position, ECastRange)
     pred = Prediction.GetPredictedPosition(Target, Viktor.E2, startPos)
    if pred and pred.HitChance >=HitChance then
            Viktor.E:Cast(pred.CastPosition,startPos)                
        end         
     
        
  end
                
end

function GetHeroes(pos, range, team)
    local arr = {}
    for k, v in pairs(ObjectManager.Get(team, "heroes")) do
        local hero = v.AsHero
        if hero.IsValid and not hero.IsDead and hero.IsTargetable and hero:Distance(pos) < range then
            table.insert(arr, hero)
        end
    end
    return arr
end



function SortClosest(heroes)
    local arr = {}
    for k, v in pairs(heroes) do
        local hero = v.AsHero
        if hero.IsValid and not hero.IsDead and hero.IsTargetable and hero:Distance(pos) < range then
            table.insert(arr, hero)
        end
    end
    return arr
end


function Viktor.Logic.Combo()
  local QTarget = Viktor.Q:GetTarget()
  if Viktor.Logic.Q(QTarget, Menu.Get("Combo.Q.Use")) then return true end


  local ETarget = Viktor.E:GetTarget()
  if Viktor.Logic.E(ETarget, Menu.Get("Misc.EHitChance"), Menu.Get("Combo.E.Use")) then return true end


  if Menu.Get("Combo.R.Use") and Viktor.R:IsReady() then
        local hitEnemies = GetHeroes(Player.Position,Viktor.R.Range, "enemy")
        local position, hitCount = Viktor.R:GetBestCircularCastPos(hitEnemies)
        if hitCount >= Menu.Get("Combo.R.MinHit") then
            Viktor.R:Cast(position)
            return
     
        end
    end



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
   --and (os.clock()-timer) >0.01
   
  if RTarget  then
   -- timer = os.clock()
    Viktor.R2:Cast(RTarget)
    return true 
                
    end
end


  function Viktor.UseW()

   local WTarget = Viktor.W:GetTarget()


  if WTarget and Viktor.W:IsReady() then

    Viktor.W:CastOnHitChance(WTarget,0.7)
    return true 
                
    end
end

function Viktor.LoadMenu()
  Menu.RegisterMenu("Goru Viktor", "Goru Viktor", function ()
    Menu.ColumnLayout("Casting", "Casting", 1, true, function ()
      Menu.ColoredText("Combo", 0xB65A94FF, true)
      Menu.Checkbox("Combo.Q.Use", "UseQ", true)
      Menu.Checkbox("Combo.E.Use", "UseE", true)
      Menu.Checkbox("Combo.R.Use", "UseR", true)
      Menu.Slider("Combo.R.MinHit", "Min Hit Heroes for Cast R", 2, 1, 5, 1)
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
      Menu.Keybind("Misc.UseW", "USE W  ", string.byte('S'),false,false)
      Menu.Checkbox("Misc.NoOrb", "Disable Orbwalker", true)
      Menu.Slider("Misc.EHitChance","EHitChance",0.7, 0, 1, 0.1)
                  Menu.Checkbox("Misc.AntiGapCloserQ", "Use Q on GapCloser", true)
            Menu.Checkbox("Misc.AntiGapCloserW", "Use W on GapCloser", true)
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


function Viktor.OnGapclose(source, dash)
    if not source.IsEnemy or source.Invulnerable then
        return
    end
 
    local GapQ = Menu.Get("Misc.AntiGapCloserQ")
    local GapW = Menu.Get("Misc.AntiGapCloserW")
    if GapW and Viktor.W:IsReady() and Viktor.W:IsInRange(source) then
        Viktor.W:Cast(source.Position)
    end
    if Viktor.Q:IsReady() and Viktor.Q:IsInRange(source) and GapQ then
        Viktor.Q:Cast(source)
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

     if Menu.Get("Misc.UseW")  then 
        Viktor.UseW()
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





