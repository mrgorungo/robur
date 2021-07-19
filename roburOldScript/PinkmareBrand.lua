if Player.CharName ~= "Brand" then return end

require("common.log")
module("Pinkmare Brand", package.seeall, log.setup)
clean.module("Pinkmare Brand", clean.seeall, log.setup)

local _SDK = _G.CoreEx
local Console, ObjManager, EventManager, Geometry, Input, Renderer, Enums, Game = _SDK.Console, _SDK.ObjectManager, _SDK.EventManager, _SDK.Geometry, _SDK.Input, _SDK.Renderer, _SDK.Enums, _SDK.Game
local Menu, Orbwalker, Collision, Prediction, HealthPred = _G.Libs.NewMenu, _G.Libs.Orbwalker, _G.Libs.CollisionLib, _G.Libs.Prediction, _G.Libs.HealthPred
local DmgLib, ImmobileLib, Spell = _G.Libs.DamageLib, _G.Libs.ImmobileLib, _G.Libs.Spell
local SpellSlots, SpellStates = Enums.SpellSlots, Enums.SpellStates
local Spell = _G.Libs.Spell
local BuffInst

local spells = {
	_Q = Spell.Skillshot({
		 Slot = Enums.SpellSlots.Q,
		 Range = 1100,
		 Delay = 0.25,
		 Speed =  1600,
		 Radius = 120,
		 Type = "Linear",
		 Collisions = {Heroes=true, Minions=true, WindWall=true},
	}),
	_W = Spell.Skillshot({
		 Slot = Enums.SpellSlots.W,
		 Range = 900,
		 Delay = 0.889,
		 Speed = 1200,
		 Radius = 260,
		 Type = "Circular",
		 UseHitbox = true,
	}),
	_E = Spell.Targeted({
		 Slot = Enums.SpellSlots.E,
		 Range = 675,		 
	}),
	_R = Spell.Targeted({
		 Slot = Enums.SpellSlots.R,
		 Range = 750,
	}),
}

---@type TargetSelector
local TS = _G.Libs.TargetSelector()
local Brand = {}
local targetQ = {}


function Brand.LoadMenu()
    Menu.RegisterMenu("PinkmareBrand", "Pinkmare Brand", function()
        Menu.ColumnLayout("cols", "cols", 2, true, function()
            Menu.ColoredText("Combo", 0xFF00CEFF, true)
            Menu.Checkbox("Combo.UseQ", "Use Q", true)
			Menu.Slider("Combo.QHC", "Q Hit Chance", 0.60, 0, 1, 0.05)
			
			Menu.Checkbox("Combo.UseW", "Use W", true)
			Menu.Slider("Combo.WHC", "W Hit Chance", 0.60, 0, 1, 0.05)
			
            Menu.Checkbox("Combo.UseE", "Use E", true)
			Menu.Checkbox("Combo.UseR", "Use R", true)

            Menu.NextColumn()

            Menu.ColoredText("KillSteal", 0xFF00CEFF, true)
            Menu.Checkbox("KillSteal.Q", "Use Q", true)		
			Menu.Checkbox("KillSteal.W", "Use W", true)			
            Menu.Checkbox("KillSteal.E", "Use E", true)
			Menu.Checkbox("KillSteal.R", "Use R", true)		
        end)        

        Menu.Separator()

        Menu.ColoredText("Draw Options", 0xFF00CEFF, true)
		Menu.Checkbox("Draw.Q.Enabled",   "Draw Q Range")
        Menu.ColorPicker("Draw.Q.Color", "Draw Q Color", 0xFF00CEFF)
        Menu.Checkbox("Draw.W.Enabled",   "Draw W Range")
        Menu.ColorPicker("Draw.W.Color", "Draw W Color", 0xFFFF00FF) 
		Menu.Checkbox("Draw.E.Enabled",   "Draw E Range")
        Menu.ColorPicker("Draw.E.Color", "Draw E Color", 0x118AB2FF)
        Menu.Checkbox("Draw.R.Enabled",   "Draw R Range")
        Menu.ColorPicker("Draw.R.Color", "Draw R Color", 0xFF0606FF) 
    end)
end

function Brand.GetTargets(range)
    return {TS:GetTarget(range, true)}
end

function Brand.Qdmg()
	return (80 + (spells._Q:GetLevel() - 1) * 30) + (0.55 * Player.TotalAP)
end

function Brand.Wdmg()
	return (75 + (spells._W:GetLevel() - 1) * 45) + (0.6 * Player.TotalAP)
end

function Brand.Edmg()
	return (70 + (spells._E:GetLevel() - 1) * 25) + (0.45 * Player.TotalAP)
end

function Brand.Rdmg()
	return (100 + (spells._R:GetLevel() - 1) * 100) + (0.25 * Player.TotalAP)
end

function Brand.OnTick()
	if Brand.KsQ() then return end
	if Brand.KsW() then return end
	if Brand.KsE() then return end
	if Brand.KsR() then return end
	
	if Orbwalker.GetMode() == "Combo" then
	
		if Menu.Get("Combo.UseW") then
			local target = Orbwalker.GetTarget() or TS:GetTarget(spells._W.Range + Player.BoundingRadius, true)
			if target then
				CastW(target,Menu.Get("Combo.WHC"))
			end
		end
		
		if Menu.Get("Combo.UseQ") then
			local target = Orbwalker.GetTarget() or TS:GetTarget(spells._Q.Range + Player.BoundingRadius, true)
			if target then
				CastQ(Menu.Get("Combo.QHC"))
			end
		end
		
		if Menu.Get("Combo.UseE") then
			local target = Orbwalker.GetTarget() or TS:GetTarget(spells._E.Range + Player.BoundingRadius, true)
			if target then
				CastE(target)
			end
		end
		
		if Menu.Get("Combo.UseR") then
			local target = Orbwalker.GetTarget() or TS:GetTarget(spells._R.Range + Player.BoundingRadius, true)
			if target then
				CastR(target)
			end
		end	
	end
end

function Brand.OnBuffGain(target, buffInst)
    if buffInst.Name ~= "BrandAblaze" or target.IsAlly then return end
    targetQ[target.Handle] = {Object = target.AsAI}
end

function Brand.OnBuffUpdate(target, buffInst)
    if buffInst.Name ~= "BrandAblaze" or target.IsAlly then return end
    targetQ[target.Handle] = {Object = target.AsAI}
end

function Brand.OnBuffLost(target, buffInst)
    if buffInst.Name ~= "BrandAblaze" or target.IsAlly then return end
    targetQ[target.Handle] = nil
end

function Brand.OnDeleteObject(target)
    targetQ[target.Handle] = nil
end

function CastQ(hitChance)
	if Player:GetSpellState(Enums.SpellSlots.Q) == SpellStates.Ready then		
		for k, v in pairs(targetQ) do
			local obj = v.Object
			local validHero = obj.IsHero and obj.IsAlive and obj.IsTargetable
			if validHero then
				local targetAI = obj.AsAI
				local qPred = Prediction.GetPredictedPosition(targetAI, spells._Q, Player.Position)
				if qPred and qPred.HitChance >= hitChance then
					Input.Cast(SpellSlots.Q, qPred.CastPosition)
				end
			end
		end
	end
end

function CastW(target,hitChance)
	if Player:GetSpellState(Enums.SpellSlots.W) == SpellStates.Ready then
		local targetAI = target.AsAI
		local wPred = Prediction.GetPredictedPosition(targetAI, spells._W, Player.Position)
		if wPred and wPred.HitChance >= hitChance then
			Input.Cast(SpellSlots.W, wPred.CastPosition)
		end
	end
end

function CastE(target)
	if Player:GetSpellState(Enums.SpellSlots.E) == SpellStates.Ready then
		local targetAI = target.AsAI
			Input.Cast(SpellSlots.E, targetAI)
	end
end

function CastR(target)
	if Player:GetSpellState(Enums.SpellSlots.R) == SpellStates.Ready then
		local targetAI = target.AsAI
			Input.Cast(SpellSlots.R, targetAI)
	end
end


function Brand.KsQ()
  if Menu.Get("KillSteal.Q") then
	for k, qTarget in ipairs(TS:GetTargets(spells._Q.Range, true)) do
		local qDmg = DmgLib.CalculateMagicalDamage(Player, qTarget, Brand.Qdmg())
		local ksHealth = spells._Q:GetKillstealHealth(qTarget)
		if qDmg > ksHealth and spells._Q:CastOnHitChance(qTarget, Enums.HitChance.VeryHigh) then
			return
		end
	end
  end
end

function Brand.KsW()
  if Menu.Get("KillSteal.W") then
	for k, wTarget in ipairs(TS:GetTargets(spells._W.Range, true)) do
		local wDmg = DmgLib.CalculateMagicalDamage(Player, wTarget, Brand.Wdmg())
		local ksHealth = spells._W:GetKillstealHealth(wTarget)
		if wDmg > ksHealth and spells._W:CastOnHitChance(wTarget, Enums.HitChance.VeryHigh) then
			return
		end
	end
  end
end

function Brand.KsE()
  if Menu.Get("KillSteal.E") then
	for k, eTarget in ipairs(TS:GetTargets(spells._E.Range, true)) do
		local eDmg = DmgLib.CalculateMagicalDamage(Player, eTarget, Brand.Edmg())
		local ksHealth = spells._E:GetKillstealHealth(eTarget)
		if eDmg > ksHealth and spells._E:Cast(eTarget) then
			return
		end
	end
  end
end
 
function Brand.KsR()
  if Menu.Get("KillSteal.R") then
	for k, rTarget in ipairs(TS:GetTargets(spells._R.Range, true)) do
		local rDmg = DmgLib.CalculateMagicalDamage(Player, rTarget, Brand.Rdmg())
		local ksHealth = spells._R:GetKillstealHealth(rTarget)
		if rDmg > ksHealth and spells._R:Cast(rTarget) then
			return
		end
	end
  end
end

function Brand.OnDraw() 
	if Menu.Get("Draw.Q.Enabled") then
        Renderer.DrawCircle3D(Player.Position, spells._Q.Range, 25, 2, Menu.Get("Draw.Q.Color"))
    end
    if Menu.Get("Draw.W.Enabled") then
        Renderer.DrawCircle3D(Player.Position, spells._W.Range, 25, 2, Menu.Get("Draw.W.Color"))
    end
	if Menu.Get("Draw.E.Enabled") then
        Renderer.DrawCircle3D(Player.Position, spells._E.Range, 25, 2, Menu.Get("Draw.E.Color"))
    end
    if Menu.Get("Draw.R.Enabled") then
        Renderer.DrawCircle3D(Player.Position, spells._R.Range, 25, 2, Menu.Get("Draw.R.Color"))
    end
end

function OnLoad()
    Brand.LoadMenu()
    for eventName, eventId in pairs(Enums.Events) do
		if Brand[eventName] then
			EventManager.RegisterCallback(eventId, Brand[eventName])
        end
    end
	
	return true
end