require("common.log")
module("MTeemo", package.seeall, log.setup)
clean.module("MTeemo", clean.seeall, log.setup)

if Player.CharName ~= "Teemo" then return false end

local _SDK = _G.CoreEx
local ObjManager, EventManager, Input, Enums, Game, Geometry, Renderer = _SDK.ObjectManager, _SDK.EventManager, _SDK.Input, _SDK.Enums, _SDK.Game, _SDK.Geometry, _SDK.Renderer
local SpellSlots, SpellStates = Enums.SpellSlots, Enums.SpellStates
local Player = ObjManager.Player
local Prediction = _G.Libs.Prediction
local Orbwalker = _G.Libs.Orbwalker
local Spell, HealthPred = _G.Libs.Spell, _G.Libs.HealthPred
local DamageLib = _G.Libs.DamageLib

TS = _G.Libs.TargetSelector(Orbwalker.Menu)

-- NewMenu
local Menu = _G.Libs.NewMenu

function MTeemoMenu()
	Menu.NewTree("MTeemoCombo", "Combo", function ()
		Menu.Checkbox("Combo.CastQ","Cast Q",true)
		Menu.Checkbox("Combo.CastAAQ","Cast Q After AA",true)
		Menu.Checkbox("Combo.CastW","Cast W",true)
		Menu.Checkbox("Combo.CastR","Cast R",true)
		Menu.Slider("Combo.CastRHC", "R Hit Chance", 0.60, 0.05, 1, 0.05)
		Menu.Slider("Combo.CastRHR", "R Hit Range", 400, 400, 900, 10)
		Menu.Slider("Combo.CastRMinMana", "R % Min. Mana", 0, 1, 100, 1)
	end)
	Menu.NewTree("MTeemoHarass", "Harass", function ()
		Menu.Checkbox("Harass.CastQ","Cast Q",true)
		Menu.Checkbox("Harass.CastAAQ","Cast Q After AA",true)
		Menu.Checkbox("Harass.CastR","Cast R",true)
		Menu.Slider("Harass.CastRHC", "R Hit Chance", 0.60, 0.05, 1, 0.05)
		Menu.Slider("Harass.CastRHR", "R Hit Range", 400, 400, 900, 10)
		Menu.Slider("Harass.CastRMinMana", "R % Min. Mana", 0, 1, 100, 1)
	end)
	Menu.NewTree("MTeemoWave", "Waveclear", function ()
		Menu.ColoredText("Wave", 0xFFD700FF, true)
		Menu.Checkbox("Waveclear.CastQ","Cast Q",true)
		Menu.Checkbox("Waveclear.CastR","Cast R",true)
		Menu.Slider("Waveclear.CastRHC", "R Min. Hit Count", 1, 0, 10, 1)
		Menu.Slider("Waveclear.CastRMinMana", "R % Min. Mana", 0, 1, 100, 1)
		Menu.Separator()
		Menu.ColoredText("Jungle", 0xFFD700FF, true)
		Menu.Checkbox("Waveclear.CastQJg","Cast Q",true)
		Menu.Checkbox("Waveclear.CastRJg","Cast R",true)
		Menu.Slider("Waveclear.CastRHCJg", "R Min. Hit Count", 1, 0, 10, 1)
		Menu.Slider("Waveclear.CastRMinManaJg", "R % Min. Mana", 0, 1, 100, 1)
	end)
	Menu.NewTree("MTeemoLasthit", "Lasthit", function ()
		Menu.Checkbox("Lasthit.CastQ","Cast Q",true)
	end)
	Menu.NewTree("MTeemoFlee", "Flee", function ()
		Menu.Checkbox("Flee.CastW","Cast W",true)
	end)
	Menu.NewTree("MTeemoMisc", "Misc.", function ()
		Menu.Checkbox("Misc.CastQKS","Auto-Cast Q Killable",true)
		Menu.Checkbox("Misc.CastRGap","Auto-Cast R GapCloser",true)
	end)
	Menu.NewTree("MTeemoDrawing", "Drawing", function ()
		Menu.Checkbox("Drawing.DrawQ","Draw Q Range",true)
		Menu.ColorPicker("Drawing.DrawQColor", "Draw Q Color", 0xEF476FFF)
		Menu.Checkbox("Drawing.DrawR","Draw R Range",true)
		Menu.ColorPicker("Drawing.DrawRColor", "Draw R Color", 0xFFD166FF)
	end)
end

Menu.RegisterMenu("MTeemo","MTeemo",MTeemoMenu)

-- Global vars
local spells = {
	Q = Spell.Targeted({
		Slot = Enums.SpellSlots.Q,
		Delay = 0.25,
		Range = 680,
	}),
	W = Spell.Active({
		Slot = Enums.SpellSlots.W,
	}),
	R = Spell.Skillshot({
		Slot = Enums.SpellSlots.R,
		Range = 400, -- initial range
		Speed = 1550,
		Delay = 0.25,
		Radius = 75,
		Type = "Circular",
	}),
}

local lastTick = 0

local function ValidMinion(minion)
	return minion and minion.IsTargetable and minion.MaxHealth > 6 -- check if not plant or shroom
end

local function GameIsAvailable()
	return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

local function CountShrooms()
	return Player:GetSpell(SpellSlots.R).Ammo
end

-- dynamic R Range
local function GetRRange()
	local rLevel = Player:GetSpell(SpellSlots.R).Level
	local rRange = 150 + rLevel * 250
	local baseBounceRange = 200 + rLevel * 100

	local nShrooms = CountShrooms()
	local bounceRange = 0

	--if nShrooms >= 2 then
	--	bounceRange = nShrooms * baseBounceRange
	--end

	finalRange = rRange + bounceRange
	spells.R.Range = finalRange
	return finalRange
end

local function GetQDmg(target)
	local playerAI = Player.AsAI
	local dmgQ = 35 + 45 * Player:GetSpell(SpellSlots.Q).Level
	local bonusDmg = playerAI.TotalAP * 0.8
	local totalDmg = dmgQ + bonusDmg
	return DamageLib.CalculateMagicalDamage(Player, target, totalDmg)
end

local function CastQ(target)
	if spells.Q:IsReady() then
		if spells.Q:Cast(target) then
			return
		end
	end
end

local function CastW()
	if spells.W:IsReady() then
		if spells.W:Cast() then
			return
		end
	end
end

local function CastR(target, hitChance)
	if spells.R:IsReady() then
		if spells.R:CastOnHitChance(target, hitChance)  then
			return
		end
	end
end

local function AutoQKS()
	if not spells.Q:IsReady() then return end

	local enemies = ObjManager.Get("enemy", "heroes")
	local myPos, qRange = Player.Position, (spells.Q.Range + Player.BoundingRadius)

	for handle, obj in pairs(enemies) do
		local hero = obj.AsHero
		if hero and hero.IsTargetable then
			local dist = myPos:Distance(hero.Position)
			local healthPred = HealthPred.GetHealthPrediction(hero, spells.Q.Delay)
			if dist <= qRange and GetQDmg(hero) > healthPred then
				CastQ(hero) -- Q KS
			end
		end
	end
end

local function Waveclear()

	if spells.Q:IsReady() or spells.R:IsReady() then

		local pPos, pointsR, minionQ = Player.Position, {}, nil
		local isJgCS = false

		-- Enemy Minions
		for k, v in pairs(ObjManager.GetNearby("enemy", "minions")) do
			local minion = v.AsAI
			if ValidMinion(minion) then
				local posR = minion:FastPrediction(spells.R.Delay)
				if posR:Distance(pPos) < spells.R.Range and minion.IsTargetable then
					table.insert(pointsR, posR)
				end

				if minion:Distance(pPos) <= spells.Q.Range then
					if minionQ then
						local healthPred = HealthPred.GetHealthPrediction(minion, spells.Q.Delay)
						if minionQ.Health >= healthPred then
							minionQ = minion
						end
					else
						minionQ = minion
					end
				end
			end
		end

		-- Jungle Minions
		if #pointsR == 0 or not minionQ then
			for k, v in pairs(ObjManager.GetNearby("neutral", "minions")) do
				local minion = v.AsAI
				if ValidMinion(minion) then
					local posR = minion:FastPrediction(spells.R.Delay)
					if posR:Distance(pPos) < spells.R.Range and minion.IsTargetable then
						isJgCS = true
						table.insert(pointsR, posR)
					end

					if minion:Distance(pPos) <= spells.Q.Range then
						isJgCS = true
						if minionQ then
							local healthPred = HealthPred.GetHealthPrediction(minion, spells.Q.Delay)
							if minionQ.Health >= healthPred then
								minionQ = minion
							end
						else
							minionQ = minion
						end
					end
				end
			end
		end

		local castQMenu = nil
		local castRMenu = nil
		local castRHCMenu = nil
		local castRMinManaMenu = nil

		if not isJgCS then
			castQMenu = Menu.Get("Waveclear.CastQ")
			castRMenu = Menu.Get("Waveclear.CastR")
			castRHCMenu = Menu.Get("Waveclear.CastRHC")
			castRMinManaMenu = Menu.Get("Waveclear.CastRMinMana")
		else
			castQMenu = Menu.Get("Waveclear.CastQJg")
			castRMenu = Menu.Get("Waveclear.CastRJg")
			castRHCMenu = Menu.Get("Waveclear.CastRHCJg")
			castRMinManaMenu = Menu.Get("Waveclear.CastRMinManaJg")
		end

		local bestPosR, hitCountR = spells.R:GetBestCircularCastPos(pointsR)
		if bestPosR and hitCountR >= castRHCMenu
				and spells.R:IsReady() and castRMenu
				and Player.Mana >= (castRMinManaMenu / 100) * Player.MaxMana then
			spells.R:Cast(bestPosR)
			return
		end
		if minionQ and spells.Q:IsReady() and castQMenu then
			if minionQ.Health <= GetQDmg(minionQ) then
				CastQ(minionQ)
				return
			end
		end

	end
end

local function LasthitQ()
	if spells.Q:IsReady() then
		local pPos, minionQ = Player.Position, nil

		-- Enemy Minions
		for k, v in pairs(ObjManager.GetNearby("enemy", "minions")) do
			local minion = v.AsAI
			if ValidMinion(minion) then
				if minion:Distance(pPos) <= spells.Q.Range then
					if minionQ then
						local healthPred = HealthPred.GetHealthPrediction(minion, spells.Q.Delay)
						if minionQ.Health >= healthPred then
							minionQ = minion
						end
					else
						minionQ = minion
					end
				end
			end
		end

		-- Jungle Minions
		if not minionQ then
			for k, v in pairs(ObjManager.GetNearby("neutral", "minions")) do
				local minion = v.AsAI
				if ValidMinion(minion) then
					if minion:Distance(pPos) <= spells.Q.Range then
						if minionQ then
							local healthPred = HealthPred.GetHealthPrediction(minion, spells.Q.Delay)
							if minionQ.Health >= healthPred then
								minionQ = minion
							end
						else
							minionQ = minion
						end
					end
				end
			end
		end

		if minionQ then
			if minionQ.Health <= GetQDmg(minionQ) then
				CastQ(minionQ)
				return
			end
		end

	end

end

local function OnHighPriority()

	if not GameIsAvailable() then return end
	if not Orbwalker.CanCast() then return end

	AutoQKS()
end

local function OnNormalPriority()

	if not GameIsAvailable() then return end
	if not Orbwalker.CanCast() then return end

	local gameTime = Game.GetTime()
	if gameTime < (lastTick + 0.25) then return end
	lastTick = gameTime

	-- update R range
	GetRRange()

	-- Combo
	if Orbwalker.GetMode() == "Combo" then

		if Menu.Get("Combo.CastQ") and not Menu.Get("Combo.CastAAQ") then
			if spells.Q:IsReady() then
				local target = Orbwalker.GetTarget() or TS:GetTarget(spells.Q.Range + Player.BoundingRadius, false)
				if target then
					CastQ(target)
					return
				end
			end
		end
		if Menu.Get("Combo.CastW") then
			if spells.W:IsReady() then
				local target = Orbwalker.GetTarget() or TS:GetTarget(Player.AttackRange + Player.BoundingRadius, false)
				if target then
					CastW()
					return
				end
			end
		end
		if Menu.Get("Combo.CastR") then
			if spells.R:IsReady() then
				local realRRange = GetRRange()
				local target = Orbwalker.GetTarget() or TS:GetTarget(realRRange + Player.BoundingRadius, true)
				if target and target.Position:Distance(Player.Position) <= Menu.Get("Combo.CastRHR")
						and Player.Mana >= (Menu.Get("Combo.CastRMinMana") / 100) * Player.MaxMana then
					CastR(target,Menu.Get("Combo.CastRHC"))
					return
				end
			end
		end

		-- Waveclear
	elseif Orbwalker.GetMode() == "Waveclear" then

		Waveclear()

		-- Harass
	elseif Orbwalker.GetMode() == "Harass" then

		if Menu.Get("Harass.CastQ") then
			if spells.Q:IsReady() then
				local target = Orbwalker.GetTarget() or TS:GetTarget(spells.Q.Range + Player.BoundingRadius, false)
				if target then
					CastQ(target)
					return
				end
			end
		end
		if Menu.Get("Harass.CastR") then
			if spells.R:IsReady() then
				local realRRange = GetRRange()
				local target = Orbwalker.GetTarget() or TS:GetTarget(realRRange + Player.BoundingRadius, true)
				if target and target.Position:Distance(Player.Position) <= Menu.Get("Harass.CastRHR")
						and Player.Mana >= (Menu.Get("Harass.CastRMinMana") / 100) * Player.MaxMana then
					CastR(target,Menu.Get("Harass.CastRHC"))
					return
				end
			end
		end

		-- Lasthit
	elseif Orbwalker.GetMode() == "Lasthit" then
		if Menu.Get("Lasthit.CastQ") then
			LasthitQ()
		end

		-- Flee
	elseif Orbwalker.GetMode() == "Flee" then
		if Menu.Get("Flee.CastW") then
			CastW()
		end
	end

end

local function OnDraw()

	-- Draw Q Range
	if Player:GetSpell(SpellSlots.Q).IsLearned and Menu.Get("Drawing.DrawQ") then
		Renderer.DrawCircle3D(Player.Position, spells.Q.Range, 30, 1.0, Menu.Get("Drawing.DrawQColor"))
	end
	-- Draw R Range
	if Player:GetSpell(SpellSlots.R).IsLearned and Menu.Get("Drawing.DrawR") then
		Renderer.DrawCircle3D(Player.Position, spells.R.Range, 30, 1.0, Menu.Get("Drawing.DrawRColor"))
	end

end

local function OnGapclose(source, dash)
	if not source.IsEnemy then return end

	local paths = dash:GetPaths()
	local endPos = paths[#paths].EndPos
	local pPos = Player.Position
	local pDist = pPos:Distance(endPos)
	if pDist > 400 or pDist > pPos:Distance(dash.StartPos) or not source:IsFacing(pPos) then return end

	if Menu.Get("Misc.CastRGap") and spells.R:IsReady() then
		Input.Cast(SpellSlots.R, endPos)
	end
end

local function OnPostAttack(target)

	if Orbwalker.GetMode() == "Combo" then
		if Menu.Get("Combo.CastQ") and Menu.Get("Combo.CastAAQ") then
			if spells.Q:IsReady() then
				if target then
					CastQ(target)
					return
				end
			end
		end
	elseif Orbwalker.GetMode() == "Harass" then
		if Menu.Get("Harass.CastQ") and Menu.Get("Harass.CastAAQ") then
			if spells.Q:IsReady() then
				if target then
					CastQ(target)
					return
				end
			end
		end
	end

end

function OnLoad()

	EventManager.RegisterCallback(Enums.Events.OnHighPriority, OnHighPriority)
	EventManager.RegisterCallback(Enums.Events.OnNormalPriority, OnNormalPriority)
	EventManager.RegisterCallback(Enums.Events.OnDraw, OnDraw)
	EventManager.RegisterCallback(Enums.Events.OnGapclose, OnGapclose)
	EventManager.RegisterCallback(Enums.Events.OnPostAttack, OnPostAttack)

	return true
end
