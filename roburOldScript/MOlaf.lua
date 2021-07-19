require("common.log")
module("MOlaf", package.seeall, log.setup)
clean.module("MOlaf", clean.seeall, log.setup)

if Player.CharName ~= "Olaf" then return false end

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

function MOlafMenu()
	Menu.NewTree("MOlafCombo", "Combo", function ()
		Menu.Checkbox("Combo.CastQ","Cast Q",true)
		Menu.Slider("Combo.CastQHC", "Q Hit Chance", 0.60, 0.05, 1, 0.05)
		Menu.Slider("Combo.CastQHR", "Q Hit Range", 800, 400, 1000, 10)
		Menu.Slider("Combo.CastQMinMana", "Q % Min. Mana", 0, 1, 100, 1)
		Menu.Checkbox("Combo.CatchQ","Catch Axe (Q) on MousePosition",true)
		Menu.Slider("Combo.CatchQR", "Catch Axe MousePosition Range", 400, 100, 1000, 10)
		Menu.Checkbox("Combo.CastW","Cast W",true)
		Menu.Checkbox("Combo.CastE","Cast E",true)
		Menu.Checkbox("Combo.CastR","Cast R",true)
		Menu.Checkbox("Combo.CastRCC","Cast R Only on CC",true)
	end)
	Menu.NewTree("MOlafHarass", "Harass", function ()
		Menu.Checkbox("Harass.CastQ","Cast Q",true)
		Menu.Slider("Harass.CastQHC", "Q Hit Chance", 0.60, 0.05, 1, 0.05)
		Menu.Slider("Harass.CastQMinMana", "Q % Min. Mana", 20, 1, 100, 1)
		Menu.Checkbox("Harass.CatchQ","Catch Axe (Q) on MousePosition",true)
		Menu.Slider("Harass.CatchQR", "Catch Axe MousePosition Range", 400, 100, 1000, 10)
		Menu.Checkbox("Harass.CastW","Cast W",true)
		Menu.Checkbox("Harass.CastE","Cast E",true)
	end)
	Menu.NewTree("MOlafWave", "Waveclear", function ()
		Menu.ColoredText("Wave", 0xFFD700FF, true)
		Menu.Checkbox("Waveclear.CastQ","Cast Q",true)
		Menu.Slider("Waveclear.CastQHC", "Q Min. Hit Count", 1, 0, 10, 1)
		Menu.Slider("Waveclear.CastQMinMana", "Q % Min. Mana", 20, 1, 100, 1)
		Menu.Checkbox("Waveclear.CastW","Cast W",true)
		Menu.Checkbox("Waveclear.CastE","Cast E",true)
		Menu.Separator()
		Menu.ColoredText("Jungle", 0xFFD700FF, true)
		Menu.Checkbox("Waveclear.CastQJg","Cast Q",true)
		Menu.Slider("Waveclear.CastQHCJg", "Q Min. Hit Count", 1, 0, 10, 1)
		Menu.Slider("Waveclear.CastQMinManaJg", "Q % Min. Mana", 20, 1, 100, 1)
		Menu.Checkbox("Waveclear.CastWJg","Cast W",true)
		Menu.Checkbox("Waveclear.CastEJg","Cast E",true)
		Menu.ColoredText("Misc.", 0xFFD700FF, true)
		Menu.Checkbox("Waveclear.CatchQ","Catch Axe (Q) on MousePosition",true)
		Menu.Slider("Waveclear.CatchQR", "Catch Axe MousePosition Range", 400, 100, 1000, 10)
		Menu.Separator()
	end)
	Menu.NewTree("MOlafLasthit", "Lasthit", function ()
		Menu.Checkbox("Lasthit.CastE","Cast E",true)
	end)
	Menu.NewTree("MOlafDrawing", "Drawing", function ()
		Menu.Checkbox("Drawing.DrawQ","Draw Q Range",true)
		Menu.ColorPicker("Drawing.DrawQColor", "Draw Q Color", 0xEF476FFF)
		Menu.Checkbox("Drawing.DrawE","Draw E Range",true)
		Menu.ColorPicker("Drawing.DrawEColor", "Draw E Color", 0x118AB2FF)
		Menu.Checkbox("Drawing.DrawMP","Draw Catch Axe Range on MousePosition",true)
		Menu.ColorPicker("Drawing.DrawMPColor", "Draw Catch Axe Range Color", 0xFFD166FF)
		Menu.Checkbox("Drawing.DrawAxe","Draw Axe Range",true)
		Menu.ColorPicker("Drawing.DrawAxeColor", "Draw Axe Color", 0xF0FF00FF)
		Menu.Checkbox("Drawing.DrawAxeLine","Draw Axe Player Line",true)
		Menu.ColorPicker("Drawing.DrawAxeLineColor", "Draw Axe Player Line Color", 0xF0FF00FF)
		Menu.Checkbox("Drawing.DrawAxeCD","Draw Axe Countdown",true)
		Menu.ColorPicker("Drawing.DrawAxeCDColor", "Draw Axe Countdown Color", 0xF0FF00FF)
	end)
end

Menu.RegisterMenu("MOlaf","MOlaf",MOlafMenu)

-- Global vars
local spells = {
	Q = Spell.Skillshot({
		Slot = Enums.SpellSlots.Q,
		Range = 1000,
		Speed = 1550,
		Delay = 0.25,
		Radius = 90,
		Type = "Linear",
	}),
	W = Spell.Active({
		Slot = Enums.SpellSlots.W,
	}),
	E = Spell.Targeted({
		Slot = Enums.SpellSlots.E,
		Delay = 0.25,
		Range = 325,
	}),
	R = Spell.Active({
		Slot = Enums.SpellSlots.R,
	}),
}

local axeObj = nil
local axeTick = 0
local lastTick = 0

local function ValidMinion(minion)
	return minion and minion.IsTargetable and minion.MaxHealth > 6 -- check if not plant or shroom
end

local function GameIsAvailable()
	return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

local function IsOnUltimate()
	return Player:GetBuff("OlafRagnarok")
end

local function GetEDmg(target)
	local playerAI = Player.AsAI
	local dmgE = 25 + 45 * Player:GetSpell(SpellSlots.E).Level
	local bonusDmg = playerAI.TotalAD * 0.5
	local totalDmg = dmgE + bonusDmg
	return totalDmg
end

local function CastQ(target,hitChance)
	if spells.Q:IsReady() then
		if spells.Q:CastOnHitChance(target, hitChance) then
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

local function CastE(target)
	if spells.E:IsReady() then
		if spells.E:Cast(target) then
			return
		end
	end
end

local function CastR()
	if spells.R:IsReady() and not IsOnUltimate() then
		if spells.R:Cast() then
			return
		end
	end
end

local function GetAxe()
	return axeObj
end

local function CatchAxe(range)
	local axe = GetAxe()
	if axe then
		local axePos = axe.Position
		if Renderer.GetMousePos():Distance(axePos) <= range+225 then
			Orbwalker.MoveTo(axePos)
		else
			Orbwalker.MoveTo(nil)
		end
	else
		Orbwalker.MoveTo(nil)
	end
end

local function Waveclear()

	if Menu.Get("Waveclear.CatchQ") then
		CatchAxe(Menu.Get("Waveclear.CatchQR"))
	end

	if spells.Q:IsReady() or spells.W:IsReady() or spells.E:IsReady() then

		local pPos, pointsQ, minionE = Player.Position, {}, nil
		local isJgCS = false

		-- Enemy Minions
		for k, v in pairs(ObjManager.GetNearby("enemy", "minions")) do
			local minion = v.AsAI
			if ValidMinion(minion) then
				local posQ = minion:FastPrediction(spells.Q.Delay)
				if posQ:Distance(pPos) < spells.Q.Range and minion.IsTargetable then
					table.insert(pointsQ, posQ)
				end

				if minion:Distance(pPos) <= spells.E.Range then
					if minionE then
						local healthPred = HealthPred.GetHealthPrediction(minion, spells.E.Delay)
						if minionE.Health >= healthPred then
							minionE = minion
						end
					else
						minionE = minion
					end
				end
			end
		end

		-- Jungle Minions
		if #pointsQ == 0 or not minionE then
			for k, v in pairs(ObjManager.GetNearby("neutral", "minions")) do
				local minion = v.AsAI
				if ValidMinion(minion) then
					local posQ = minion:FastPrediction(spells.Q.Delay)
					if posQ:Distance(pPos) < spells.Q.Range then
						isJgCS = true
						table.insert(pointsQ, posQ)
					end

					if minion:Distance(pPos) <= spells.E.Range then
						isJgCS = true
						if minionE then
							local healthPred = HealthPred.GetHealthPrediction(minion, spells.E.Delay)
							if minionE.Health >= healthPred then
								minionE = minion
							end
						else
							minionE = minion
						end
					end
				end
			end
		end

		local castQMenu = nil
		local castWMenu = nil
		local castEMenu = nil
		local castQHCMenu = nil
		local castQMinManaMenu = nil

		if not isJgCS then
			castQMenu = Menu.Get("Waveclear.CastQ")
			castWMenu = Menu.Get("Waveclear.CastW")
			castEMenu = Menu.Get("Waveclear.CastE")
			castQHCMenu = Menu.Get("Waveclear.CastQHC")
			castQMinManaMenu = Menu.Get("Waveclear.CastQMinMana")
		else
			castQMenu = Menu.Get("Waveclear.CastQJg")
			castWMenu = Menu.Get("Waveclear.CastWJg")
			castEMenu = Menu.Get("Waveclear.CastEJg")
			castQHCMenu = Menu.Get("Waveclear.CastQHCJg")
			castQMinManaMenu = Menu.Get("Waveclear.CastQMinManaJg")
		end

		local bestPosQ, hitCountQ = spells.Q:GetBestLinearCastPos(pointsQ)
		if bestPosQ and hitCountQ >= castQHCMenu
				and spells.Q:IsReady() and castQMenu
				and Player.Mana >= (castQMinManaMenu / 100) * Player.MaxMana then
			spells.Q:Cast(bestPosQ)
			return
		end
		if minionE and spells.W:IsReady() and castWMenu then
			CastW()
			return
		end
		if minionE and spells.E:IsReady() and castEMenu then
			spells.E:Cast(minionE)
			return
		end

	end
end

local function LasthitE()
	if spells.E:IsReady() then
		local pPos, minionE = Player.Position, nil

		-- Enemy Minions
		for k, v in pairs(ObjManager.GetNearby("enemy", "minions")) do
			local minion = v.AsAI
			if ValidMinion(minion) then
				if minion:Distance(pPos) <= spells.E.Range then
					if minionE then
						local healthPred = HealthPred.GetHealthPrediction(minion, spells.E.Delay)
						if minionE.Health >= healthPred then
							minionE = minion
						end
					else
						minionE = minion
					end
				end
			end
		end

		-- Jungle Minions
		if not minionE then
			for k, v in pairs(ObjManager.GetNearby("neutral", "minions")) do
				local minion = v.AsAI
				if ValidMinion(minion) then
					if minion:Distance(pPos) <= spells.E.Range then
						if minionE then
							local healthPred = HealthPred.GetHealthPrediction(minion, spells.E.Delay)
							if minionE.Health >= healthPred then
								minionE = minion
							end
						else
							minionE = minion
						end
					end
				end
			end
		end

		if minionE then
			if minionE.Health <= GetEDmg(minionE) then
				CastE(minionE)
				return
			end
		end

	end

end

local function OnHighPriority()

	if not GameIsAvailable() then return end
	if not Orbwalker.CanCast() then return end

	-- Combo
	if Orbwalker.GetMode() == "Combo" then
		if Menu.Get("Combo.CastR") and not Menu.Get("Combo.CastRCC") then
			if spells.R:IsReady() then
				local target = Orbwalker.GetTarget() or TS:GetTarget(Player.AttackRange + Player.BoundingRadius, false)
				if target then
					CastR()
					return
				end
			end
		end
	end
end

local function OnNormalPriority()

	if not GameIsAvailable() then return end
	if not Orbwalker.CanCast() then return end

	local gameTime = Game.GetTime()
	if gameTime < (lastTick + 0.25) then return end
	lastTick = gameTime

	-- Combo
	if Orbwalker.GetMode() == "Combo" then

		if Menu.Get("Combo.CastQ") then
			if spells.Q:IsReady() then
				local target = Orbwalker.GetTarget() or TS:GetTarget(spells.Q.Range + Player.BoundingRadius, true)
				if target and target.Position:Distance(Player.Position) <= Menu.Get("Combo.CastQHR")
						and Player.Mana >= (Menu.Get("Combo.CastQMinMana") / 100) * Player.MaxMana then
					CastQ(target,Menu.Get("Combo.CastQHC"))
					return
				end
			end
		end
		if Menu.Get("Combo.CatchQ") then
			CatchAxe(Menu.Get("Combo.CatchQR"))
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
		if Menu.Get("Combo.CastE") then
			if spells.E:IsReady() then
				local target = Orbwalker.GetTarget() or TS:GetTarget(spells.E.Range + Player.BoundingRadius, false)
				if target then
					CastE(target)
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
				local target = Orbwalker.GetTarget() or TS:GetTarget(spells.Q.Range + Player.BoundingRadius, true)
				if target and Player.Mana >= (Menu.Get("Harass.CastQMinMana") / 100) * Player.MaxMana then
					CastQ(target,Menu.Get("Harass.CastQHC"))
					return
				end
			end
		end
		if Menu.Get("Harass.CatchQ") then
			CatchAxe(Menu.Get("Harass.CatchQR"))
		end
		if Menu.Get("Harass.CastW") then
			if spells.W:IsReady() then
				local target = Orbwalker.GetTarget() or TS:GetTarget(Player.AttackRange + Player.BoundingRadius, false)
				if target then
					CastW()
					return
				end
			end
		end
		if Menu.Get("Harass.CastE") then
			if spells.E:IsReady() then
				local target = Orbwalker.GetTarget() or TS:GetTarget(spells.E.Range + Player.BoundingRadius, false)
				if target then
					CastE(target)
					return
				end
			end
		end

	-- Lasthit
	elseif Orbwalker.GetMode() == "Lasthit" then
		if Menu.Get("Lasthit.CastE") then
			LasthitE()
		end
	end

end

local function OnDraw()

	-- Draw Q Range
	if Player:GetSpell(SpellSlots.Q).IsLearned and Menu.Get("Drawing.DrawQ") then
		Renderer.DrawCircle3D(Player.Position, spells.Q.Range, 30, 1.0, Menu.Get("Drawing.DrawQColor"))
	end
	-- Draw E Range
	if Player:GetSpell(SpellSlots.E).IsLearned and Menu.Get("Drawing.DrawE") then
		Renderer.DrawCircle3D(Player.Position, spells.E.Range, 30, 1.0, Menu.Get("Drawing.DrawEColor"))
	end
	-- Draw MousePosition Range
	if Menu.Get("Drawing.DrawMP") and Orbwalker.GetMode() and GetAxe() then
		local mode = Orbwalker.GetMode()
		if mode == "Combo" or mode == "Harass" or mode == "Waveclear" then
			Renderer.DrawCircle3D(Renderer.GetMousePos(), Menu.Get(mode ..".CatchQR"),
					30, 1.0, Menu.Get("Drawing.DrawMPColor"))
		end
	end
	-- Draw Axe Range
	if Menu.Get("Drawing.DrawAxe") then
		local axe = GetAxe()
		if axe then
			local axePos = axe.Position
			Renderer.DrawCircle3D(axePos, 200,
					30, 1.0, Menu.Get("Drawing.DrawMPColor"))
		end
	end
	-- Draw Axe Line
	if Menu.Get("Drawing.DrawAxeLine") then
		local axe = GetAxe()
		if axe then
			local axePos = axe.Position
			Renderer.DrawLine3D(Player.Position,axePos, 1.0, Menu.Get("Drawing.DrawAxeLineColor"))
		end
	end
	-- Draw Axe CD
	if Menu.Get("Drawing.DrawAxeCD") then
		local axe = GetAxe()
		if axe then
			local axePos = axe.Position
			if axeTick >= Game.GetTime() then
				local timeQ = string.format("%.1f", (axeTick - Game.GetTime()))
				Renderer.DrawText(axePos:ToScreen(), {x=500,y=500}, timeQ, Menu.Get("Drawing.DrawAxeCDColor"))
			end
		end
	end

end

local function OnCreateObject(obj)
	local objName = obj.Name
	if objName and objName == "Olaf_Base_Q_Axe_Ally" then
		axeObj = obj
		local qCD = Player:GetSpell(SpellSlots.Q).TotalCooldown
		axeTick = Game.GetTime()+qCD+0.4 -- rito lies about CD
	end
end

local function OnDeleteObject(obj)
	local objName = obj.Name
	if objName and objName == "Olaf_Base_Q_Axe_Ally" then
		axeObj = nil
		axeTick = 0
	end
end

local function OnBuffGain(obj, buffInst)
	if Orbwalker.GetMode() == "Combo" then
		if obj.IsHero and obj.IsMe and Menu.Get("Combo.CastR") and Menu.Get("Combo.CastRCC") then
			if buffInst.IsCC then
				CastR()
			end
		end
	end
end

function OnLoad()

	EventManager.RegisterCallback(Enums.Events.OnHighPriority, OnHighPriority)
	EventManager.RegisterCallback(Enums.Events.OnNormalPriority, OnNormalPriority)
	EventManager.RegisterCallback(Enums.Events.OnDraw, OnDraw)
	EventManager.RegisterCallback(Enums.Events.OnCreateObject, OnCreateObject)
	EventManager.RegisterCallback(Enums.Events.OnDeleteObject, OnDeleteObject)
	EventManager.RegisterCallback(Enums.Events.OnBuffGain, OnBuffGain)

	return true
end

