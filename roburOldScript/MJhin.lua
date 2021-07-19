if Player.CharName ~= "Jhin" then return false end

module("MJhin", package.seeall, log.setup)
clean.module("MJhin", clean.seeall, log.setup)

local _SDK = _G.CoreEx
local ObjManager, EventManager, Input, Enums, Game, Geometry, Renderer =
_SDK.ObjectManager, _SDK.EventManager, _SDK.Input, _SDK.Enums, _SDK.Game, _SDK.Geometry, _SDK.Renderer
local SpellSlots, SpellStates = Enums.SpellSlots, Enums.SpellStates 
local Player = ObjManager.Player
local Prediction = _G.Libs.Prediction
local Orbwalker = _G.Libs.Orbwalker
local Spell, HealthPred = _G.Libs.Spell, _G.Libs.HealthPred
local DamageLib = _G.Libs.DamageLib

TS = _G.Libs.TargetSelector(Orbwalker.Menu)

-- NewMenu
local Menu = _G.Libs.NewMenu

function MJhinMenu()
	Menu.NewTree("MJhinCombo", "Combo", function ()
		Menu.Checkbox("Combo.CastQ","Cast Q",true)
		Menu.Checkbox("Combo.CastW","Cast W",true)
		Menu.Slider("Combo.CastWHC", "W Hit Chance", 0.60, 0.05, 1, 0.05)
		Menu.Checkbox("Combo.CastWMarked","Cast W Only Marked",true)
		Menu.Checkbox("Combo.CastE","Cast E",true)
		Menu.Slider("Combo.CastEHC", "E Hit Chance", 0.60, 0.05, 1, 0.05)
	end)
	Menu.NewTree("MJhinHarass", "Harass", function ()
		Menu.Checkbox("Harass.CastQ","Cast Q",true)
		Menu.Checkbox("Harass.CastQMinion","Cast Q Only Near Minion",true)
		Menu.Checkbox("Harass.CastW","Cast W",true)
		Menu.Slider("Harass.CastWHC", "W Hit Chance", 0.60, 0.05, 1, 0.05)
		Menu.Checkbox("Harass.CastWMarked","Cast W Only Marked",true)
		Menu.Checkbox("Harass.CastE","Cast E",true)
		Menu.Slider("Harass.CastEHC", "E Hit Chance", 0.60, 0.05, 1, 0.05)
	end)
	Menu.NewTree("MJhinWave", "Waveclear", function ()
		Menu.Checkbox("Wave.CastQ","Cast Q",true)
		Menu.Slider("Wave.CastQHC", "W Min. Hit Count", 1, 0, 10, 1)
		Menu.Checkbox("Wave.CastW","Cast W",true)
		Menu.Slider("Wave.CastWHC", "W Min. Hit Count", 1, 0, 10, 1)
		Menu.Checkbox("Wave.CastE","Cast E",true)
		Menu.Slider("Wave.CastEHC", "E Min. Hit Count", 3, 0, 10, 1)
	end)
	Menu.NewTree("MJhinMisc", "Misc.", function ()
		Menu.Checkbox("Misc.CastWKS","Auto-Cast W Killable",true)
    	Menu.Checkbox("Misc.CastR","Auto-Cast R",true)
		Menu.Slider("Misc.CastRHC", "R Hit Chance", 0.60, 0.05, 1, 0.05)
    	Menu.Checkbox("Misc.CastEGap","Auto-Cast E GapCloser",true)
	end)
	Menu.NewTree("MJhinDrawing", "Drawing", function ()
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

Menu.RegisterMenu("MJhin","MJhin",MJhinMenu)

-- Jhin Spell Info
local spellQ = {Range=650, Radius=400, Speed=math.huge, Delay=0.25, Type="Linear"}
local spellW = {Range=2550, Radius=40, Speed=5000, Delay=0.25, Type="Linear"}
local spellE = {Range=750, Radius=260, Speed=1000, Delay=0.25, Type="Circular"}
local spellR = {Range=3500, Radius=80, Speed=5000, Delay=0.25, Type="Linear", UseHitbox=true}

-- Global vars
local rShots = 0
local lastTick = 0

local function GameIsAvailable()
	return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

local function ValidMinion(minion)
	return minion and minion.IsTargetable and minion.MaxHealth > 6 -- check if not plant or shroom
end

local function IsSpellReady(slot)
	return Player:GetSpellState(slot) == SpellStates.Ready
end

local function IsMarked(target)
	return target:GetBuff("jhinespotteddebuff");
end

local function IsOnUltimate()
	return Player:GetSpell(SpellSlots.R).Name == "JhinRShot"
end

local function IsLastUltShot()
	return rShots == 3
end

local function GetWDmg(target)
	local playerAI = Player.AsAI
	local dmgR = 15 + 35 * Player:GetSpell(SpellSlots.W).Level
	local adDmg = playerAI.TotalAD * 0.5
    local totalDmg = dmgR + adDmg
    return DamageLib.CalculateMagicalDamage(Player, target, totalDmg)
end

local function CastQ(target)
	if IsSpellReady(SpellSlots.Q) then
		Input.Cast(SpellSlots.Q, target)
	end
end

local function CastW(target, hitChance)
	if IsSpellReady(SpellSlots.W) then
		local targetAI = target.AsAI
		local wPred = Prediction.GetPredictedPosition(targetAI, spellW, Player.Position)
		if wPred and wPred.HitChance >= hitChance then
			Input.Cast(SpellSlots.W, wPred.CastPosition)
		end
	end
end

local function CastE(target,hitChance)
	if IsSpellReady(SpellSlots.E) then
		local targetAI = target.AsAI
		local ePred = Prediction.GetPredictedPosition(targetAI, spellE, Player.Position)
		if ePred and ePred.HitChance >= hitChance then
			Input.Cast(SpellSlots.E, ePred.CastPosition)
		end
	end
end

local function CastR(target,hitChance)
	if IsSpellReady(SpellSlots.R) then
		local targetAI = target.AsAI
		local rPred = Prediction.GetPredictedPosition(targetAI, spellR, Player.Position)
		if rPred then
		end
		if rPred and rPred.HitChance >= hitChance then
			Input.Cast(SpellSlots.R, rPred.CastPosition)
		end
	end
end

local function AutoWKS()
	local enemies = ObjManager.Get("enemy", "heroes")
	local myPos, wRange = Player.Position, (spellW.Range + Player.BoundingRadius)
	if not IsSpellReady(SpellSlots.W) then return end

	for handle, obj in pairs(enemies) do        
		local hero = obj.AsHero        
		if hero and hero.IsTargetable then
			local dist = myPos:Distance(hero.Position)
			local healthPred = HealthPred.GetHealthPrediction(hero, spellW.Delay)
			if dist <= wRange and GetWDmg(hero) > healthPred then
				CastW(hero,Menu.Get("Combo.CastWHC")) -- R KS
			end
		end		
	end	
end

local function Waveclear()
	
	local pPos, pointsQ, pointsW, pointsE = Player.Position,{}, {}, {}
		
	-- Enemy Minions
	for k, v in pairs(ObjManager.Get("enemy", "minions")) do
		local minion = v.AsAI
		if ValidMinion(minion) then
			local posQ = minion:FastPrediction(spellQ.Delay)
			local posW = minion:FastPrediction(spellW.Delay)
			local posE = minion:FastPrediction(spellE.Delay)
			if posQ:Distance(pPos) < spellQ.Range and minion.IsTargetable then
				table.insert(pointsQ, posQ)
			end
			if posW:Distance(pPos) < spellW.Range and minion.IsTargetable then
				table.insert(pointsW, posW)
			end
			if posE:Distance(pPos) < spellE.Range and minion.IsTargetable then
				table.insert(pointsE, posE)
			end 
		end    
	end
		
	-- Jungle Minions
	if #pointsQ == 0 or #pointsW == 0 or #pointsE == 0 then
		for k, v in pairs(ObjManager.Get("neutral", "minions")) do
			local minion = v.AsAI
			if ValidMinion(minion) then
				local posQ = minion:FastPrediction(spellQ.Delay)
				local posW = minion:FastPrediction(spellW.Delay)
				local posE = minion:FastPrediction(spellE.Delay)
				if posQ:Distance(pPos) < spellQ.Range and minion.IsTargetable then
					table.insert(pointsQ, posQ)
				end
				if posW:Distance(pPos) < spellW.Range then
					table.insert(pointsW, posW)
				end
				if posE:Distance(pPos) < spellE.Range then
					table.insert(pointsE, posE)
				end     
			end
		end
	end

	-- Q Coverage
	local bestPosQ, hitCountQ = Geometry.BestCoveringCircle(pointsQ, spellQ.Radius)
	if bestPosQ and hitCountQ >= Menu.Get("Wave.CastQHC")
			and IsSpellReady(SpellSlots.Q) and Menu.Get("Wave.CastQ") then
		local bestMinionQ = nil
		for k, v in pairs(ObjManager.Get("enemy", "minions")) do
			local minion = v.AsAI
			if ValidMinion(minion) and minion:Distance(pPos) < spellQ.Range then
				if bestMinionQ then
					if minion.Position:Distance(bestPosQ) < bestMinionQ.Position:Distance(bestPosQ) then
						bestMinionQ = minion
					end
				else
					bestMinionQ = minion
				end
			end
		end
		if not bestMinionQ then
			for k, v in pairs(ObjManager.Get("neutral", "minions")) do
				local minion = v.AsAI
				if ValidMinion(minion) and minion:Distance(pPos) < spellQ.Range then
					if bestMinionQ then
						if minion.Position:Distance(bestPosQ) < bestMinionQ.Position:Distance(bestPosQ) then
							bestMinionQ = minion
						end
					else
						bestMinionQ = minion
					end
				end
			end
		end
		if bestMinionQ then
			Input.Cast(SpellSlots.Q, bestMinionQ)
		end
	end

	-- W Coverage
	local bestPosW, hitCountW = Geometry.BestCoveringRectangle(pointsW, pPos, spellW.Radius*2)
	if bestPosW and hitCountW >= Menu.Get("Wave.CastWHC")
		and IsSpellReady(SpellSlots.W) and Menu.Get("Wave.CastW") then
		Input.Cast(SpellSlots.W, bestPosW)
    end
	-- E Coverage
	local bestPosE, hitCountE = Geometry.BestCoveringCircle(pointsE, spellE.Radius)
	if bestPosE and hitCountE >= Menu.Get("Wave.CastEHC")
		and IsSpellReady(SpellSlots.E) and Menu.Get("Wave.CastE") then
		Input.Cast(SpellSlots.E, bestPosE)
    end
end

local function OnHighPriority()

	if not GameIsAvailable() then return end

	-- Auto W KS
	if Menu.Get("Misc.CastWKS") then
		AutoWKS()
	end

end

local function OnNormalPriority()

	if not GameIsAvailable() then return end
	--if not Orbwalker.CanCast() then return end

	local gameTime = Game.GetTime()
	if gameTime < (lastTick + 0.25) then return end
	lastTick = gameTime

	-- Ultimate
	if IsOnUltimate() and Menu.Get("Misc.CastR") then
		local PlayerAAU = Player.AsAttackableUnit
		local target = Orbwalker.GetTarget() or TS:GetTarget(spellR.Range + Player.BoundingRadius,
				false)
		if target then
			CastR(target,Menu.Get("Misc.CastRHC"))
		end
	else
		-- Combo
		if Orbwalker.GetMode() == "Combo" then

			if Menu.Get("Combo.CastQ") then
				local target = Orbwalker.GetTarget() or TS:GetTarget(spellQ.Range, false)
				if target then
					CastQ(target)
				end
			end
			if Menu.Get("Combo.CastW") then
				local target = Orbwalker.GetTarget() or TS:GetTarget(spellW.Range, false)
				if target then
					if Menu.Get("Combo.CastWMarked") then
						if IsMarked(target) then
							CastW(target,Menu.Get("Combo.CastWHC"))
						end
					else
						CastW(target,Menu.Get("Combo.CastWHC"))
					end
				end
			end
			if Menu.Get("Combo.CastE") then
				local target = Orbwalker.GetTarget() or TS:GetTarget(spellE.Range + Player.BoundingRadius,
						false)
				if target then
					CastE(target,Menu.Get("Combo.CastEHC"))
				end
			end

			-- Waveclear
		elseif Orbwalker.GetMode() == "Waveclear" then

			Waveclear()

			-- Harass
		elseif Orbwalker.GetMode() == "Harass" then

			if Menu.Get("Harass.CastQ") then
				if Menu.Get("Harass.CastQMinion") then
					local target = Orbwalker.GetTarget() or TS:GetTarget(spellQ.Range+spellQ.Radius,
							false)
					if target then
						local bestMinionQ = nil
						for k, v in pairs(ObjManager.Get("enemy", "minions")) do
							local minion = v.AsAI
							if ValidMinion(minion) and minion:Distance(target.Position) < spellQ.Radius
								and minion:Distance(Player.Position) < spellQ.Range then
								bestMinionQ = minion
							end
						end
						if bestMinionQ then
							CastQ(bestMinionQ)
						end
					end
				else
					local target = Orbwalker.GetTarget() or TS:GetTarget(spellQ.Range + Player.BoundingRadius,
							false)
					if target then
						CastQ(target)
					end
				end
			end
			if Menu.Get("Harass.CastW") then
				local target = Orbwalker.GetTarget() or TS:GetTarget(spellW.Range, false)
				if target then
					if Menu.Get("Harass.CastWMarked") then
						if IsMarked(target) then
							CastW(target,Menu.Get("Harass.CastWHC"))
						end
					else
						CastW(target,Menu.Get("Harass.CastWHC"))
					end
				end
			end
		end

	end

end

local function OnDraw()	

	-- Draw Q Range
	if Player:GetSpell(SpellSlots.Q).IsLearned and Menu.Get("Drawing.DrawQ") then 
		Renderer.DrawCircle3D(Player.Position, spellQ.Range, 30, 1.0, Menu.Get("Drawing.DrawQColor"))
	end
	-- Draw W Range
	if Player:GetSpell(SpellSlots.W).IsLearned and Menu.Get("Drawing.DrawW") then
		Renderer.DrawCircle3D(Player.Position, spellW.Range, 30, 1.0, Menu.Get("Drawing.DrawWColor"))
	end
	-- Draw E Range
	if Player:GetSpell(SpellSlots.E).IsLearned and Menu.Get("Drawing.DrawE") then 
		Renderer.DrawCircle3D(Player.Position, spellE.Range, 30, 1.0, Menu.Get("Drawing.DrawEColor"))
	end
	-- Draw R Range
	if Player:GetSpell(SpellSlots.R).IsLearned and Menu.Get("Drawing.DrawR") then 
		Renderer.DrawCircle3D(Player.Position, spellR.Range, 30, 1.0, Menu.Get("Drawing.DrawRColor"))
	end

end

local function OnGapclose(source, dash)
	if not source.IsEnemy then return end

	local paths = dash:GetPaths()
	local endPos = paths[#paths].EndPos
	local pPos = Player.Position
	local pDist = pPos:Distance(endPos)
	if pDist > 400 or pDist > pPos:Distance(dash.StartPos) or not source:IsFacing(pPos) then return end

	if Menu.Get("Misc.CastEGap") and IsSpellReady(SpellSlots.E) then
		Input.Cast(SpellSlots.E, endPos)
	end
end

local function OnProcessSpell(sender, spell)
	if spell.Slot ~= SpellSlots.R then return end
	if IsOnUltimate() then
		rShots = rShots + 1
	else
		rShots = 0
	end
end

local function OnPreMove(args)
	if IsOnUltimate() then
		args.Process = nil
	end
end

local function OnPreAttack(args)
	if IsOnUltimate() then
		args.Process = nil
	end
end

function OnLoad() 
	if Player.CharName ~= "Jhin" then return false end
	
	EventManager.RegisterCallback(Enums.Events.OnHighPriority, OnHighPriority)
	EventManager.RegisterCallback(Enums.Events.OnNormalPriority, OnNormalPriority)
	EventManager.RegisterCallback(Enums.Events.OnDraw, OnDraw)
	EventManager.RegisterCallback(Enums.Events.OnGapclose, OnGapclose)
	EventManager.RegisterCallback(Enums.Events.OnProcessSpell, OnProcessSpell)
	EventManager.RegisterCallback(Enums.Events.OnPreMove, OnPreMove)
	EventManager.RegisterCallback(Enums.Events.OnPreAttack, OnPreAttack)

	return true
end

