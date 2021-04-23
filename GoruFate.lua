
if Player.CharName ~= "TwistedFate" then return false end
---[Requirements]----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
require("common.log")
module("GoruFate", package.seeall, log.setup)
--clean.module("GoruFate", clean.seeall, log.setup)
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---[LUA Utilities]---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
local clock = os.clock()
local insert, tlenght= table.insert, table.getn
local huge, min, max = math.huge, math.min, math.max

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---[API]-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
local _Core, _Libs = _G.CoreEx, _G.Libs
-- CoreEx 
local Enums, EventManager, Game, Geometry, Input, Nav, ObjectManager, Renderer = 
_Core.Enums, _Core.EventManager, _Core.Game, _Core.Geometry, _Core.Input, _Core.Nav, _Core.ObjectManager, _Core.Renderer
-- CoreEx Enums
local AbilityResourceTypes, BuffTypes, DamageTypes, Events, GameObjectOrders, HitChance, ItemSlots, ObjectTypeFlags, PerkIDs, SpellSlots, SpellStates, Teams = 
Enums.AbilityResourceTypes, Enums.BuffTypes, Enums.DamageTypes, Enums.Events, Enums.GameObjectOrders, Enums.HitChance, Enums.ItemSlots, Enums.ObjectTypeFlags, Enums.PerkIDs, Enums.SpellSlots, Enums.SpellStates, Enums.Teams
-- CoreEx Geometry
local Vector, Circle, Path = Geometry.Vector, Geometry.Circle, Geometry.Path
-- Libs
local Collision, DamageLib, DashLib, HealthPred, Menu, Orbwalker, Prediction, Profiler, TargetSelector, SpellLib, ImmobileLib = 
_Libs.CollisionLib, _Libs.DamageLib, _Libs.DashLib, _Libs.HealthPred, _Libs.NewMenu, _Libs.Orbwalker, _Libs.Prediction, _Libs.Profiler, _Libs.TargetSelector(), _Libs.Spell,_Libs.ImmobileLib
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---[Tables]----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------













local _Q = SpellLib.Skillshot({
    Slot = SpellSlots.Q,
    RawSpell = "Q",
    Range = 1550,
    Radius = 40,
    Speed = 1000,
    Delay = 0.25,
    Type = "Linear",
    Collisions={ Heroes = false, Minions = false, WindWall = true, Wall = false},
    UseHitbox = true
})



local _W = SpellLib.Active({
    Slot = SpellSlots.W,
    RawSpell = "W",
    Delay = 0,
   
})

--[[
local _E = SpellLib.Active({
    Slot = SpellSlots.E,
    RawSpell = "E"
})

local _R = SpellLib.Active({
    Slot = SpellSlots.R,
    RawSpell = "R"
})

]]
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---[Variables]-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
local TwistedFate = {}
local Player = ObjectManager.Player.AsHero
local cardtopick = nil

----------------------------------------------------------------------------------------------------------------------------------------------------------
---[Menu]------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function TwistedFate.Init()
    function GoruFate.Menu()
        Menu.ColumnLayout("GoruFate.Menu", "GoruFate Menu", 1, true, function ()
     
        Menu.NextColumn()
         Menu.Separator()
        Menu.ColoredText("Card picker", 0xFFFF00FF, true)
      
            Menu.Keybind("CP.gold", "Gold card", string.byte('E'),false,false)
            Menu.Keybind("CP.red", "Red card", string.byte('T'),false,false)
            Menu.Keybind("CP.blue", "Blue card", string.byte('U'),false,false)

        
        Menu.NextColumn()
         Menu.Separator()
        Menu.ColoredText("Auto", 0xFFFF00FF, true)
            Menu.Checkbox("Auto.UseQ","Use Q on Immobile target", true)
            Menu.Checkbox("Auto.UseQKS","Use Q to KS", true)
            Menu.Slider("Auto.HitChanceQ", "HitChance ", 0.7, 0, 1, 0.1)

     Menu.NextColumn()
     Menu.Separator()
     Menu.ColoredText("Misc", 0xFFFF00FF, true)
              
      Menu.Checkbox("Misc.NoOrb", "Disable Orbwalker", true)

        Menu.NextColumn()
         Menu.Separator()
        Menu.ColoredText("Drawings", 0xFFFF00FF, true)
            Menu.Checkbox("DrawQ", "Draw Q Range", true)
            Menu.ColorPicker("ColorQ", "Q Color", 0x118AB2FF)
            
       
		
        end)
      
    end
    Menu.RegisterMenu("GoruFate", "GoruFate Menu", GoruFate.Menu)
end
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---[Functions]-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
local function IsSpellReady(slot)--スキルが使用可能かどうか
    return Player:GetSpellState(SpellSlots[slot]) == SpellStates.Ready
end

function TwistedFate.IsEnabledAndReady(spell, mode)--メニューで有効and使用可能かどうか
	return Menu.Get(mode..".Use"..spell) and IsSpellReady(spell)
end

function TwistedFate.GetRawDamageQ()--Qのダメージを取得
    local Dmg = 15 + (_Q:GetLevel() * 45) + (Player.TotalAP * 0.65)
    return Dmg
    
end



function TwistedFate.AutoQImmobile(minChance)

   
    local pPos = Player.Position
    --local targs = _Q:GetTargets()
    local targs = TargetSelector:GetTargets(_Q.Range,true)
    --local delay = Game.GetLatency()/1000 + _Q.Delay

    if targs ~= nil then
      

    for k, targ in pairs(targs) do     

     
     if targ ~= nil then
        --print(targ.Name)
        local buffs = targ.Buffs
        --local flightTime = delay + (pPos:Distance(targ)/_Q.Speed)
        
        
        if buffs ~= nil then
        for buffName, buff in pairs(buffs) do
        --print(buffName)
         if buff.BuffType == Enums.BuffTypes.Stun
         or buff.BuffType == Enums.BuffTypes.Snare
         or buff.BuffType == Enums.BuffTypes.Taunt
         or buff.BuffType == Enums.BuffTypes.Fear
         or buff.BuffType == Enums.BuffTypes.Flee
         or buff.BuffType == Enums.BuffTypes.Charm
         or buff.BuffType == Enums.BuffTypes.Suppression
         or buff.BuffType == Enums.BuffTypes.Knockup
         or buff.BuffType == Enums.BuffTypes.Knockback
         or buff.BuffType == Enums.BuffTypes.Asleep
         --or buff.BuffType == Enums.BuffTypes.Slow
         then

          --
          --local flightTime = delay + (pPos:Distance(targ)/_Q.Speed)
          --ImmobileLib.GetImmobileTimeLeft(targ) <= flightTime and not
          
           local pred = Prediction.GetPredictedPosition(targ, _Q, Player.Position)
          
                  if pred and pred.HitChance >= Menu.Get("Auto.HitChanceQ") and targ.IsValid and targ.IsEnemy and targ.IsHero then
          
                        
                     _Q:Cast(targ,pred.CastPosition)
                     end
          
         end
        end
        end
        end
        end
    end




end

function TwistedFate.AutoQKS(minChance)
     

    local pPos = Player.Position

      
    for k, targ in ipairs(TargetSelector:GetTargets(_Q.Range-400)) do        
        

        local targHp = targ.Health --_Q:GetHealthPred(targ) -----@field CalculateMagicalDamage fun(source:AIBaseClient, target: AttackableUnit, rawDmg: number):number
        -----@field GetHealthPred fun(self:SpellBase, target:AIBaseClient) 
        local qDmg = DamageLib.CalculateMagicalDamage(Player, targ, TwistedFate.GetRawDamageQ())
   
            if targHp - qDmg <= 0 then
                  local pred = Prediction.GetPredictedPosition(targ, _Q, Player.Position)
                  if pred and pred.HitChance >= Menu.Get("Auto.HitChanceQ")  and targ.IsValid and targ.IsEnemy and targ.IsHero then
                  _Q:Cast(targ,pred.CastPosition)
                 --_Q:Cast(targ)
                 end
            end


        
    end


end




function TwistedFate.CardPicker()
    local name = _W:GetName()


 if name == "GoldCardLock" and name == cardtopick then
    _W:Cast()
     cardtopick = nil
 end

 if name == "RedCardLock" and name == cardtopick then
    _W:Cast()
     cardtopick = nil
 end

 if name == "BlueCardLock" and name == cardtopick then
    _W:Cast()
     cardtopick = nil
 end


end

  

function TwistedFate.OnTick()

      if Menu.Get("Misc.NoOrb") then 
    Orbwalker.BlockMove(true) 
  else
    Orbwalker.BlockMove(false) 
  end 


    if TwistedFate.Auto() then return end

end


function TwistedFate.Combo()
	
end

function TwistedFate.Harass()
	
end

function TwistedFate.Waveclear()
	
end

function TwistedFate.Lasthit()
	
end

function TwistedFate.Auto()
	if TwistedFate.IsEnabledAndReady("Q", "Auto") then
        TwistedFate.AutoQImmobile(Menu.Get("Auto.HitChanceQ"))
    end
   
      


 
   if Menu.Get("Auto.UseQKS") and IsSpellReady("Q") and Player:GetBuff("goldcardpreattack") == nil then
        TwistedFate.AutoQKS(Menu.Get("Auto.HitChanceQ"))
    end



    if _W:IsReady() and cardtopick ~= nil and  _W:GetName() ~=  "PickACard" then 
        TwistedFate.CardPicker()
    end


    


    if _W:IsReady() and _W:GetName() == "PickACard" and os.clock() - clock > 1 then
    
        if Menu.Get("CP.gold") then 
            cardtopick = "GoldCardLock"
            _W:Cast()
            clock = os.clock() 
        end
         if Menu.Get("CP.red") then 
            cardtopick = "RedCardLock"
            _W:Cast()
            clock = os.clock() 
        end
         if Menu.Get("CP.blue") then 
            cardtopick = "BlueCardLock"
            _W:Cast()
            clock = os.clock() 
        end
    end

  
  
    if _W:IsReady() and _W:GetName() ~=  "PickACard" and os.clock() - clock > 1  then --if already started picking 
       if Menu.Get("CP.gold") then 
            cardtopick = "GoldCardLock"
            
            clock = os.clock() 
        end
         if Menu.Get("CP.red") then 
            cardtopick = "RedCardLock"
            
            clock = os.clock() 
        end
         if Menu.Get("CP.blue") then 
            cardtopick = "BlueCardLock"
          
            clock = os.clock() 
        end
    end



    
    
    
end

function TwistedFate.OnDraw()
    local PlayerPos = Player.Position
    local check = Player.IsOnScreen and Menu.Get("DrawQ")
    if check then
        Renderer.DrawCircle3D(PlayerPos, _Q.Range, 30, 2, Menu.Get("ColorQ")) 
    end
end

function OnLoad()
    TwistedFate.Init()
	for eventName, eventId in pairs(Events) do
        if TwistedFate[eventName] then
            EventManager.RegisterCallback(eventId, TwistedFate[eventName])
        end
	end
    print("GoruFate Loaded !")
	return true
end
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
