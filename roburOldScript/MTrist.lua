if Player.CharName ~= "Tristana" then return false end

module("MTrist", package.seeall, log.setup)
clean.module("MTrist", clean.seeall, log.setup)

local _SDK = _G.CoreEx
local ObjManager, EventManager, Input, Enums, Game, Geometry, Renderer = _SDK.ObjectManager, _SDK.EventManager, _SDK.Input, _SDK.Enums, _SDK.Game, _SDK.Geometry, _SDK.Renderer
local SpellSlots, SpellStates = Enums.SpellSlots, Enums.SpellStates 
local Player = ObjManager.Player
local Orbwalker = _G.Libs.Orbwalker
local DamageLib = _G.Libs.DamageLib
local Prediction = _G.Libs.Prediction

-- NewMenu
local Menu = _G.Libs.NewMenu

function MTristMenu()
	Menu.NewTree("MTristCombo", "Combo", function ()
		Menu.Checkbox("Combo.CastQ","Cast Q",true)
		Menu.Checkbox("Combo.CastW","Cast W",true)
		Menu.Slider("Combo.CastWHC", "W Hit Chance", 0.70, 0.05, 1, 0.05)
		Menu.Checkbox("Combo.CastE","Cast E",true)
	end)
	Menu.NewTree("MTristHarass", "Harass", function ()
    	Menu.Checkbox("Harass.CastQ","Cast Q",true)
		Menu.Checkbox("Harass.CastE","Cast E",true)
	end)
		Menu.NewTree("MTristWave", "Waveclear", function ()
		Menu.Checkbox("Wave.CastE","Cast E",true)
	end)
	Menu.NewTree("MTristMisc", "Misc.", function ()
		Menu.Checkbox("Misc.CastRKS","Cast R KillSteal",true)
		Menu.Checkbox("Misc.CastRGap","Cast R GapCloser",true)
		Menu.Checkbox("Misc.CastRIntSpell","Cast R Interruptible Spells",true)
	end)
	Menu.NewTree("MTristDrawing", "Drawing", function ()
    Menu.Checkbox("Drawing.DrawW","Draw W Range",true)
    Menu.ColorPicker("Drawing.DrawWColor", "Draw W Color", 0x06D6A0FF)
	end)
end

Menu.RegisterMenu("MTrist","MTrist",MTristMenu)

-- Tristana Spell Info
local spellW = {Range=900, Radius=350, Speed=1100, Delay=0.65, Type="Circular"}

local function ValidMinion(minion)
	return minion and minion.IsTargetable and minion.MaxHealth > 6 -- check if not plant or shroom
end

local function GetEDmg(target)

	local tristECount = CountEStacks(target)

	if tristECount > 0 then

		local dmgE = 60 + 10 * Player:GetSpell(SpellSlots.E).Level
		local dmgEStack = 18 + 3 * Player:GetSpell(SpellSlots.E).Level

		local bonusDmgE = ((25 + 25 * Player:GetSpell(SpellSlots.E).Level) * 0.01) * Player.BonusAD + 0.5 * Player.TotalAP
		local bonusDmgEStack = 7.5 + (7.5 * Player:GetSpell(SpellSlots.E).Level) + 0.15 * Player.TotalAP

		local totalDmgE = dmgE + bonusDmgE + ((dmgEStack + bonusDmgEStack) * tristECount)

		return DamageLib.CalculatePhysicalDamage(Player, target, totalDmgE)
	else
		return 0
	end

end

local function GetRDmg(target)
	local playerAI = Player.AsAI
	local tristR = {300, 400, 500}
	local dmgR = tristR[Player:GetSpell(SpellSlots.R).Level]
	local bonusDmg = playerAI.FlatMagicalDamageMod
    local totalDmg = dmgR + bonusDmg
    return DamageLib.CalculateMagicalDamage(Player, target, totalDmg)
end

function CountEStacks(target)
	local targetAI = target.AsAI
	if targetAI and targetAI.IsValid then
		local tristEChargeBuff = targetAI:GetBuff("TristanaECharge")

		if tristEChargeBuff then
			return tristEChargeBuff.Count
		end
	end

	return 0
end

local function Combo(target)
	if Player:GetSpellState(SpellSlots.Q) == SpellStates.Ready and Menu.Get("Combo.CastQ") then
		Input.Cast(SpellSlots.Q)
	elseif Player:GetSpellState(SpellSlots.W) == SpellStates.Ready and Menu.Get("Combo.CastW") then
		local targetAI = target.AsAI
		local wPred = Prediction.GetPredictedPosition(targetAI, spellW, Player.Position)
		if wPred and wPred.HitChance >= Menu.Get("Combo.CastWHC") then
			Input.Cast(SpellSlots.W, wPred.CastPosition)
		end
	elseif Player:GetSpellState(SpellSlots.E) == SpellStates.Ready and Menu.Get("Combo.CastE") then
		Input.Cast(SpellSlots.E, target)
	end
end

local function Harass(target)
	if Player:GetSpellState(SpellSlots.Q) == SpellStates.Ready and Menu.Get("Harass.CastQ") then
		Input.Cast(SpellSlots.Q)
	elseif Player:GetSpellState(SpellSlots.E) == SpellStates.Ready and Menu.Get("Harass.CastE") then
		Input.Cast(SpellSlots.E, target)
	end
end

local function Waveclear()
	if Player:GetSpellState(SpellSlots.E) == SpellStates.Ready and Menu.Get("Wave.CastE") then
		local pPos, pointsE, myRange = Player.Position, {}, (Player.AttackRange + Player.BoundingRadius)
		-- Enemy Minions
		for k, v in pairs(ObjManager.Get("enemy", "minions")) do
			local minion = v.AsAI
			if minion and ValidMinion(minion) then
				local pos = minion:FastPrediction(0.2)
				if pos:Distance(pPos) < myRange and minion.IsTargetable then
					table.insert(pointsE, pos)
				end 
			end                       
		end
		
		-- Jungle Minions
		if #pointsE == 0 then 
			for k, v in pairs(ObjManager.Get("neutral", "minions")) do
				local minion = v.AsAI
				if minion and ValidMinion(minion) then
					local pos = minion:FastPrediction(0.2)
					if pos:Distance(pPos) < myRange and minion.IsTargetable then
						table.insert(pointsE, pos)
					end 
				end                       
			end
		end
		local bestPos, hitCount = Geometry.BestCoveringCircle(pointsE, 300)
		local bestMinion = nil
		if bestPos then
			-- Enemy Minions Check with bestPos
			for k, v in pairs(ObjManager.Get("enemy", "minions")) do
				local minion = v.AsAI
				if minion and ValidMinion(minion) then
					local pos = minion.Position
					if bestMinion == nil and pos:Distance(pPos) < myRange then
						bestMinion = minion
					end
					if bestMinion then
						local posBest = bestMinion.Position
						if pos:Distance(bestPos) < posBest:Distance(bestPos) and minion.IsTargetable then
							bestMinion = minion
						end
					end
				end
			end
			if bestMinion and bestMinion.IsTargetable then
				Input.Cast(SpellSlots.E, bestMinion)
			else 
				-- Jungle Minions Check with bestPos
				for k, v in pairs(ObjManager.Get("neutral", "minions")) do
					local minion = v.AsAI
					if minion and ValidMinion(minion) then
						local pos = minion.Position
						if bestMinion == nil and pos:Distance(pPos) < myRange then
							bestMinion = minion
						end
						if bestMinion then
							local posBest = bestMinion.Position
							if pos:Distance(bestPos) < posBest:Distance(bestPos) and minion.IsTargetable then
								bestMinion = minion
							end
						end
					end
				end
				if bestMinion and bestMinion.IsTargetable then
					Input.Cast(SpellSlots.E, bestMinion)
				end
			end
        end
	end
end

local function AutoR()

	if Player:GetSpellState(SpellSlots.R) ~= SpellStates.Ready then return end

	local enemies = ObjManager.Get("enemy", "heroes")
	local myPos, myRange = Player.Position, (Player.AttackRange + Player.BoundingRadius)	


	for handle, obj in pairs(enemies) do        
		local hero = obj.AsHero        
		if hero and hero.IsTargetable then
			local dist = myPos:Distance(hero.Position)
			if dist <= myRange and (GetRDmg(hero) + GetEDmg(hero)) > (hero.Health) and Menu.Get("Misc.CastRKS") then
				Input.Cast(SpellSlots.R, hero) -- R KS
			end
		end		
	end	
end 

local function OnHighPriority()	

	AutoR()

end

local function OnNormalPriority()			
	
	local target = Orbwalker.GetTarget()
	
	if target and Orbwalker.GetMode() == "Combo" then 
		Combo(target)
	elseif target and Orbwalker.GetMode() == "Harass" then
		Harass(target)
	elseif Orbwalker.GetMode() == "Waveclear" then
		Waveclear()
	end
end

local function OnDraw()	

	-- Draw W Range
	if Player:GetSpell(SpellSlots.W).IsLearned and Menu.Get("Drawing.DrawW") then 
		Renderer.DrawCircle3D(Player.Position, spellW.Range, 30, 1.0, Menu.Get("Drawing.DrawWColor"))
	end

end

local function OnPreAttack(args)
	if Orbwalker.GetMode() == "Waveclear" then
		local myPos, myRange = Player.Position, (Player.AttackRange + Player.BoundingRadius)	
		-- Enemy Minions Check for E Buff
		for k, v in pairs(ObjManager.Get("enemy", "minions")) do
			local minion = v.AsAI
			if minion and ValidMinion(minion) and myPos:Distance(minion.Position) <= myRange then
				local buffE = minion:GetBuff("TristanaECharge")
				if buffE then
					args.Target = minion
				end
			end
		end
		-- Enemy Minions Check for E Buff
		for k, v in pairs(ObjManager.Get("neutral", "minions")) do
			local minion = v.AsAI
			if minion and ValidMinion(minion) and myPos:Distance(minion.Position) <= myRange then
				local buffE = minion:GetBuff("TristanaECharge")
				if buffE then
					args.Target = minion
				end
			end
		end
	end
end

local function OnInterruptibleSpell(source, spellCast, danger, endTime, canMoveDuringChannel)
	if not (source.IsEnemy and Menu.Get("Misc.CastRIntSpell")
			and Player:GetSpellState(SpellSlots.R) == SpellStates.Ready and danger > 3) then return end
	Input.Cast(SpellSlots.R, source)
end

local function OnGapclose(source, dash)
	if not source.IsEnemy then return end

	local paths = dash:GetPaths()
	local endPos = paths[#paths].EndPos
	local pPos = Player.Position
	local pDist = pPos:Distance(endPos)
	if pDist > 400 or pDist > pPos:Distance(dash.StartPos) or not source:IsFacing(pPos) then return end

	if Menu.Get("Misc.CastRGap") and Player:GetSpellState(SpellSlots.R) == SpellStates.Ready then
		Input.Cast(SpellSlots.R, source)
	end
end


function OnLoad() 
	if Player.CharName ~= "Tristana" then return false end 
	
	EventManager.RegisterCallback(Enums.Events.OnHighPriority, OnHighPriority)
	EventManager.RegisterCallback(Enums.Events.OnNormalPriority, OnNormalPriority)
	EventManager.RegisterCallback(Enums.Events.OnDraw, OnDraw)
	EventManager.RegisterCallback(Enums.Events.OnPreAttack, OnPreAttack)
	EventManager.RegisterCallback(Enums.Events.OnInterruptibleSpell, OnInterruptibleSpell)
	EventManager.RegisterCallback(Enums.Events.OnGapclose, OnGapclose)

	return true
end

