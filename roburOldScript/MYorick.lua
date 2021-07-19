if Player.CharName ~= "Yorick" then return false end

require("common.log")
module("MYorick", package.seeall, log.setup)
clean.module("MYorick", clean.seeall, log.setup)

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

function MYorickMenu()
	Menu.NewTree("MYorickCombo", "Combo", function ()
		Menu.Checkbox("Combo.CastQ","Cast Q",true)
		Menu.Checkbox("Combo.CastW","Cast W",true)
		Menu.Checkbox("Combo.CastWCC","Cast W on CC Only",true)
		Menu.Slider("Combo.CastWHC", "W Hit Chance", 0.60, 0.05, 1, 0.05)
		Menu.Slider("Combo.CastWMinMana", "W % Min. Mana", 0, 1, 100, 1)
		Menu.Checkbox("Combo.CastE","Cast E",true)
		Menu.Slider("Combo.CastEHC", "E Hit Chance", 0.60, 0.05, 1, 0.05)
		Menu.Slider("Combo.CastEMinMana", "E % Min. Mana", 0, 1, 100, 1)
		Menu.Checkbox("Combo.CastR","Cast R",true)
		Menu.Slider("Combo.CastRHC", "R Hit Chance", 0.60, 0.05, 1, 0.05)
		Menu.Slider("Combo.CastRMinMana", "R % Min. Mana", 0, 1, 100, 1)
	end)
	Menu.NewTree("MYorickHarass", "Harass", function ()
		Menu.Checkbox("Harass.CastQ","Cast Q",true)
		Menu.Checkbox("Harass.CastW","Cast W",true)
		Menu.Checkbox("Harass.CastWCC","Cast W on CC Only",true)
		Menu.Slider("Harass.CastWHC", "W Hit Chance", 0.60, 0.05, 1, 0.05)
		Menu.Slider("Harass.CastWMinMana", "W % Min. Mana", 0, 1, 100, 1)
		Menu.Checkbox("Harass.CastE","Cast E",true)
		Menu.Slider("Harass.CastEHC", "E Hit Chance", 0.60, 0.05, 1, 0.05)
		Menu.Slider("Harass.CastEMinMana", "E % Min. Mana", 0, 1, 100, 1)
	end)
	Menu.NewTree("MYorickWave", "Waveclear", function ()
		Menu.ColoredText("Wave", 0xFFD700FF, true)
		Menu.Checkbox("Waveclear.CastQ","Cast Q for LastHit",true)
		Menu.Checkbox("Waveclear.CastE","Cast E",true)
		Menu.Slider("Waveclear.CastEHC", "E Min. Hit Count", 1, 0, 10, 1)
		Menu.Slider("Waveclear.CastEMinMana", "E % Min. Mana", 0, 1, 100, 1)
		Menu.Separator()
		Menu.ColoredText("Jungle", 0xFFD700FF, true)
		Menu.Checkbox("Waveclear.CastQJg","Cast Q for LastHit",true)
		Menu.Checkbox("Waveclear.CastEJg","Cast E",true)
		Menu.Slider("Waveclear.CastEHCJg", "E Min. Hit Count", 1, 0, 10, 1)
		Menu.Slider("Waveclear.CastEMinManaJg", "E % Min. Mana", 0, 1, 100, 1)
	end)
	Menu.NewTree("MYorickLasthit", "Lasthit", function ()
		Menu.Checkbox("Lasthit.CastQ","Cast Q",true)
	end)
	Menu.NewTree("MYorickMisc", "Misc.", function ()
		Menu.Checkbox("Misc.CastQKS","Auto-Cast Q Killable",true)
		Menu.Checkbox("Misc.CastQTurret","Auto-Cast Q on Turret",true)
		Menu.Checkbox("Misc.CastWGap","Auto-Cast W GapCloser",true)
	end)
	Menu.NewTree("MYorickDrawing", "Drawing", function ()
		Menu.Checkbox("Drawing.DrawQ","Draw Q Range",true)
		Menu.ColorPicker("Drawing.DrawQColor", "Draw Q Color", 0xEF476FFF)
		Menu.Checkbox("Drawing.DrawW","Draw W Range",true)
		Menu.ColorPicker("Drawing.DrawWColor", "Draw W Color", 0x06D6A0FF)
		Menu.Checkbox("Drawing.DrawE","Draw E Range",true)
		Menu.ColorPicker("Drawing.DrawEColor", "Draw E Color", 0x118AB2FF)
		Menu.Checkbox("Drawing.DrawR","Draw R Range",true)
		Menu.ColorPicker("Drawing.DrawRColor", "Draw R Color", 0xFFD166FF)
	end)
end

Menu.RegisterMenu("MYorick","MYorick",MYorickMenu)

-- Global vars
local spells = {
	Q = Spell.Active({
		Slot = Enums.SpellSlots.Q,
		Range = Player.AttackRange + 50,
		Delay = 0.1,
	}),
	W = Spell.Skillshot({
		Slot = Enums.SpellSlots.W,
		Range = 600,
		Speed = 1550,
		Delay = 0.75,
		Radius = 210,
		Type = "Circular",
	}),
	E = Spell.Skillshot({
		Slot = Enums.SpellSlots.E,
		Range = 700,
		Speed = 2000,
		Delay = 0.33,
		Radius = 120,
		Type = "Circular",
	}),
	R = Spell.Skillshot({
		Slot = Enums.SpellSlots.R,
		Delay = 0.5,
		Range = 600,
	}),
}

local lastTick = 0
local qActive = false

local function ValidMinion(minion)
	return minion and minion.IsTargetable and minion.MaxHealth > 6 -- check if not plant or shroom
end

local function GameIsAvailable()
	return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

local function CanCastMistwalkers()
	return Player:GetSpell(SpellSlots.Q).Name == "YorickQ2"
end

local function IsQActive()
	return qActive
end

local function isTargetCC(target)
	return target.IsImmovable or target.IsTaunted or target.IsFeared or target.IsSurpressed or target.IsAsleep
		or target.IsCharmed or target.IsSlowed or target.IsGrounded
end

local function GetQDmg(target)
	local playerAI = Player.AsAI
	local dmgQ = 5 + 25 * Player:GetSpell(SpellSlots.Q).Level
	local bonusDmg = playerAI.TotalAD * 0.4
	local totalDmg = dmgQ + bonusDmg
	return DamageLib.CalculatePhysicalDamage(Player, target, totalDmg)
end

local function CastQ()
	if spells.Q:IsReady() then
		if spells.Q:Cast() then
			return
		end
	end
end

local function CastW(target, hitChance)
	if spells.W:IsReady() then
		if spells.W:CastOnHitChance(target, hitChance) then
			return
		end
	end
end

local function CastE(target, hitChance)
	if spells.E:IsReady() then
		if spells.E:CastOnHitChance(target, hitChance) then
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
				CastQ() -- Q KS
			end
		end
	end
end

local function Waveclear()

	if spells.Q:IsReady() or spells.E:IsReady() then

		local pPos, pointsE, closeMinionE, minionQ = Player.Position, {}, nil, nil
		local isJgCS = false

		-- Enemy Minions
		for k, v in pairs(ObjManager.GetNearby("enemy", "minions")) do
			local minion = v.AsAI
			if ValidMinion(minion) then
				local posE = minion:FastPrediction(spells.E.Delay)
				if posE:Distance(pPos) < spells.E.Range and minion.IsTargetable then
					table.insert(pointsE, posE)
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
		if #pointsE == 0 or not minionQ then
			for k, v in pairs(ObjManager.GetNearby("neutral", "minions")) do
				local minion = v.AsAI
				if ValidMinion(minion) then
					local posE = minion:FastPrediction(spells.E.Delay)
					if posE:Distance(pPos) < spells.E.Range and minion.IsTargetable then
						isJgCS = true
						table.insert(pointsE, posE)
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
		local castEMenu = nil
		local castEHCMenu = nil
		local castEMinManaMenu = nil

		if not isJgCS then
			castQMenu = Menu.Get("Waveclear.CastQ")
			castEMenu = Menu.Get("Waveclear.CastE")
			castEHCMenu = Menu.Get("Waveclear.CastEHC")
			castEMinManaMenu = Menu.Get("Waveclear.CastEMinMana")
		else
			castQMenu = Menu.Get("Waveclear.CastQJg")
			castEMenu = Menu.Get("Waveclear.CastEJg")
			castEHCMenu = Menu.Get("Waveclear.CastEHCJg")
			castEMinManaMenu = Menu.Get("Waveclear.CastEMinManaJg")
		end

		local bestPosE, hitCountE = spells.E:GetBestCircularCastPos(pointsE)

		if bestPosE and hitCountE >= castEHCMenu
				and spells.E:IsReady() and castEMenu
				and Player.Mana >= (castEMinManaMenu / 100) * Player.MaxMana then
			spells.E:Cast(bestPosE)
			return
		end
		if minionQ and spells.Q:IsReady() and castQMenu then
			if minionQ.Health <= GetQDmg(minionQ) then
				CastQ()
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
				CastQ()
				return
			end
		end

	end

end

local function OnHighPriority()

	if not GameIsAvailable() then return end
	if not Orbwalker.CanCast() then return end

	if Menu.Get("Misc.CastQKS") then
		AutoQKS()
	end
end

local function OnNormalPriority()

	if not GameIsAvailable() then return end
	if not Orbwalker.CanCast() then return end

	local gameTime = Game.GetTime()
	if gameTime < (lastTick + 0.25) then return end
	lastTick = gameTime

	if CanCastMistwalkers() then
		CastQ()
	end
	-- Combo
	if Orbwalker.GetMode() == "Combo" then
		if Menu.Get("Combo.CastQ") then
			if spells.Q:IsReady() then
				local target = Orbwalker.GetTarget() or TS:GetTarget(spells.Q.Range + Player.BoundingRadius, false)
				if target then
					CastQ()
					return
				end
			end
		end
		if Menu.Get("Combo.CastE") then
			if spells.E:IsReady() then
				local target = Orbwalker.GetTarget() or TS:GetTarget(spells.E.Range + Player.BoundingRadius, true)
				if target and target.Position:Distance(Player.Position) <= (spells.E.Range + Player.BoundingRadius)
						and Player.Mana >= (Menu.Get("Combo.CastEMinMana") / 100) * Player.MaxMana then
					CastE(target,Menu.Get("Combo.CastEHC"))
					return
				end
			end
		end
		if Menu.Get("Combo.CastW") then
			if spells.W:IsReady() then
				local target = Orbwalker.GetTarget() or TS:GetTarget(spells.W.Range + Player.BoundingRadius, true)
				if target and target.Position:Distance(Player.Position) <= (spells.W.Range + Player.BoundingRadius)
						and Player.Mana >= (Menu.Get("Combo.CastWMinMana") / 100) * Player.MaxMana then
					if Menu.Get("Combo.CastWCC") then
						print("target ta cc: ", tostring(isTargetCC(target)))
						if isTargetCC(target) then
							CastW(target,Menu.Get("Combo.CastWHC"))
							return
						end
					else
						CastW(target,Menu.Get("Combo.CastWHC"))
						return
					end

				end
			end
		end
		if Menu.Get("Combo.CastR") then
			if spells.R:IsReady() then
				local target = Orbwalker.GetTarget() or TS:GetTarget(spells.R.Range + Player.BoundingRadius, true)
				if target and target.Position:Distance(Player.Position) <= (spells.R.Range + Player.BoundingRadius)
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
					CastQ()
					return
				end
			end
		end
		if Menu.Get("Harass.CastE") then
			if spells.E:IsReady() then
				local target = Orbwalker.GetTarget() or TS:GetTarget(spells.E.Range + Player.BoundingRadius, true)
				if target and target.Position:Distance(Player.Position) <= (spells.E.Range + Player.BoundingRadius)
						and Player.Mana >= (Menu.Get("Harass.CastEMinMana") / 100) * Player.MaxMana then
					CastE(target,Menu.Get("Harass.CastEHC"))
					return
				end
			end
		end
		if Menu.Get("Harass.CastW") then
			if spells.W:IsReady() then
				local target = Orbwalker.GetTarget() or TS:GetTarget(spells.W.Range + Player.BoundingRadius, true)
				if target and target.Position:Distance(Player.Position) <= (spells.W.Range + Player.BoundingRadius)
						and Player.Mana >= (Menu.Get("Harass.CastWMinMana") / 100) * Player.MaxMana then
					if Menu.Get("Harass.CastWCC") then
						if isTargetCC(target) then
							CastW(target,Menu.Get("Harass.CastWHC"))
							return
						end
					else
						CastW(target,Menu.Get("Harass.CastWHC"))
						return
					end
				end
			end
		end

		-- Lasthit
	elseif Orbwalker.GetMode() == "Lasthit" then
		if Menu.Get("Lasthit.CastQ") then
			LasthitQ()
		end

	end

end

local function OnDraw()

	-- Draw Q Range
	if Player:GetSpell(SpellSlots.Q).IsLearned and Menu.Get("Drawing.DrawQ") then
		Renderer.DrawCircle3D(Player.Position, spells.Q.Range, 30, 1.0, Menu.Get("Drawing.DrawQColor"))
	end
	-- Draw W Range
	if Player:GetSpell(SpellSlots.W).IsLearned and Menu.Get("Drawing.DrawW") then
		Renderer.DrawCircle3D(Player.Position, spells.W.Range, 30, 1.0, Menu.Get("Drawing.DrawWColor"))
	end
	-- Draw E Range
	if Player:GetSpell(SpellSlots.E).IsLearned and Menu.Get("Drawing.DrawE") then
		Renderer.DrawCircle3D(Player.Position, spells.E.Range, 30, 1.0, Menu.Get("Drawing.DrawEColor"))
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

	if Menu.Get("Misc.CastWGap") and spells.W:IsReady() then
		Input.Cast(SpellSlots.W, endPos)
	end
end

local function OnPreAttack(args)

	if args.Target.IsTurret and Menu.Get("Misc.CastQTurret") then
		CastQ()
	end

end

local function OnBuffGain(obj, buffInst)
	if obj.IsMe then
		local buff = buffInst.Name
		if buff == "yorickqbuff" then
			qActive = true
		end
	end
end

local function OnBuffLost(obj, buffInst)
	if obj.IsMe then
		local buff = buffInst.Name
		if buff == "yorickqbuff" then
			qActive = false
		end
	end
end

function OnLoad()

	EventManager.RegisterCallback(Enums.Events.OnHighPriority, OnHighPriority)
	EventManager.RegisterCallback(Enums.Events.OnNormalPriority, OnNormalPriority)
	EventManager.RegisterCallback(Enums.Events.OnDraw, OnDraw)
	EventManager.RegisterCallback(Enums.Events.OnGapclose, OnGapclose)
	EventManager.RegisterCallback(Enums.Events.OnPreAttack, OnPreAttack)
	EventManager.RegisterCallback(Enums.Events.OnBuffGain, OnBuffGain)
	EventManager.RegisterCallback(Enums.Events.OnBuffLost, OnBuffLost)

	return true
end
