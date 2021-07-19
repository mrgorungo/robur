if Player.CharName ~= "Twitch" then return false end

module("MTwitch", package.seeall, log.setup)
clean.module("MTwitch", clean.seeall, log.setup)

local _SDK = _G.CoreEx
local ObjManager, EventManager, Input, Enums, Game, Geometry, Renderer = _SDK.ObjectManager, _SDK.EventManager, _SDK.Input, _SDK.Enums, _SDK.Game, _SDK.Geometry, _SDK.Renderer
local SpellSlots, SpellStates = Enums.SpellSlots, Enums.SpellStates 
local Player = ObjManager.Player
local Orbwalker = _G.Libs.Orbwalker
local Prediction = _G.Libs.Prediction
local DamageLib = _G.Libs.DamageLib

-- NewMenu
local Menu = _G.Libs.NewMenu

function MTwitchMenu()
	Menu.NewTree("MTwitchCombo", "Combo", function ()
    Menu.Checkbox("Combo.CastQ","Cast Q",true)
    Menu.Checkbox("Combo.CastW","Cast W",true)
	Menu.Slider("Combo.CastWHC", "W Hit Chance", 0.60, 0.05, 1, 0.05)
	Menu.Checkbox("Combo.CastE","Cast E",true)
	Menu.Slider("Combo.CastEMS", "E Min Stacks", 6, 1, 6, 1)
	end)
	Menu.NewTree("MTwitchHarass", "Harass", function ()
	Menu.Checkbox("Harass.CastW","Cast W",true)
	Menu.Slider("Harass.CastWHC", "W Hit Chance", 0.60, 0.05, 1, 0.05)
	Menu.Checkbox("Harass.CastE","Cast E",true)
	Menu.Slider("Harass.CastEMS", "E Min Stacks", 3, 1, 6, 1)
	end)
	Menu.NewTree("MTwitchWave", "Waveclear", function ()
	Menu.Checkbox("Wave.CastW","Cast W",true)
	Menu.Slider("Wave.CastWHC", "W Hit Count", 3, 1, 10, 1)
	Menu.Checkbox("Wave.CastE","Cast E",true)
	end)
	Menu.NewTree("MTwitchMisc", "Misc.", function ()
    Menu.Checkbox("Misc.CastEKS","Auto-Cast E Killable",true)
	end)
	Menu.NewTree("MTwitchDrawing", "Drawing", function ()
	Menu.Checkbox("Drawing.DrawW","Draw W Range",true)
    Menu.ColorPicker("Drawing.DrawWColor", "Draw W Color", 0x06D6A0FF)
	Menu.Checkbox("Drawing.DrawE","Draw E Range",true)
    Menu.ColorPicker("Drawing.DrawEColor", "Draw E Color", 0x118AB2FF)
	Menu.Checkbox("Drawing.DrawR","Draw R Range",true)
    Menu.ColorPicker("Drawing.DrawRColor", "Draw R Color", 0xFFD166FF)
	end)
end

Menu.RegisterMenu("MTwitch","MTwitch",MTwitchMenu)

-- Twitch Spell Info
local spellW = {Range=950, Radius=120, Speed=1400, Delay=0.65, Type="Circular"}
local spellE = {Range=1200}
local spellR = {Range=Player.AttackRange + Player.BoundingRadius + 300}

local lastTick = 0

local function ValidMinion(minion)
	return minion and minion.IsTargetable and minion.MaxHealth > 6 -- check if not plant or shroom
end

local function GameIsAvailable()
	return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

function GetEDmg(target, buffCount)
	
	local playerBonusAD = Player.BonusAD
	local playerTotalAP = Player.TotalAP
	if buffCount > 0 and playerBonusAD then
		local twitchE = {20, 30, 40, 50, 60}
		local twitchEStack = {15, 20, 25, 30, 35}
		local dmgE = twitchE[Player:GetSpell(SpellSlots.E).Level]
		local dmgEStack = twitchEStack[Player:GetSpell(SpellSlots.E).Level]
		
		local totalDmgE = dmgE + (dmgEStack + playerBonusAD * 0.35 + playerTotalAP * 0.333) * buffCount
		
		return DamageLib.CalculatePhysicalDamage(Player, target, totalDmgE)
	else
		return 0
	end

end

function CountEStacks(target) 
	local targetAI = target.AsAI
    if targetAI and targetAI.IsValid then
		local twitchPoisonBuff = targetAI:GetBuff("TwitchDeadlyVenom")
		
		if twitchPoisonBuff then 
			return twitchPoisonBuff.Count
		end
	end

	return 0
	
end

local function CastW(target, hitchance)
	local targetAI = target.AsAI
	local wPred = Prediction.GetPredictedPosition(targetAI, spellW, Player.Position)
	if wPred and wPred.HitChance >= hitchance then
		Input.Cast(SpellSlots.W, wPred.CastPosition)
	end
end

local function Combo(target)
	
	if Player:GetSpellState(SpellSlots.Q) == SpellStates.Ready and Menu.Get("Combo.CastQ") then
		Input.Cast(SpellSlots.Q)
	end
	
	if Player:GetSpellState(SpellSlots.W) == SpellStates.Ready and Menu.Get("Combo.CastW") then
		if Player.Position:Distance(target.Position) <= spellW.Range then
			CastW(target,Menu.Get("Combo.CastWHC"))
		end
	end
	
	if Player:GetSpellState(SpellSlots.E) == SpellStates.Ready and Menu.Get("Combo.CastE") then

		local buffCountVenom = CountEStacks(target)

		if buffCountVenom >= Menu.Get("Combo.CastEMS") then
			Input.Cast(SpellSlots.E)
		end
		
	end
	
end

local function Harass(target)

	if Player:GetSpellState(SpellSlots.W) == SpellStates.Ready and Menu.Get("Harass.CastW") then
		if Player.Position:Distance(target.Position) <= spellW.Range then
			CastW(target, Menu.Get("Harass.CastWHC"))
		end
	end
	
	if Player:GetSpellState(SpellSlots.E) == SpellStates.Ready and Menu.Get("Harass.CastE") then

		local buffCountVenom = CountEStacks(target)

		if buffCountVenom >= Menu.Get("Harass.CastEMS") then
			Input.Cast(SpellSlots.E)
		end
		
	end
	
end

local function Waveclear()
	local pPos, pointsW = Player.Position, {}
		
		-- Enemy Minions
		for k, v in pairs(ObjManager.Get("enemy", "minions")) do
			local minion = v.AsAI
			if minion then
				local pos = minion:FastPrediction(spellW.Delay)
				if pos:Distance(pPos) < spellW.Range and minion.IsTargetable then
					table.insert(pointsW, pos)
				end 
			end                       
		end
		
		-- Jungle Minions
		if #pointsW == 0 then 
			for k, v in pairs(ObjManager.Get("neutral", "minions")) do
				local minion = v.AsAI
				if minion then
					local pos = minion:FastPrediction(spellW.Delay)
					if pos:Distance(pPos) < spellW.Range and minion.IsTargetable then
						table.insert(pointsW, pos)
					end 
				end                       
			end
		end
		local bestPos, hitCount = Geometry.BestCoveringCircle(pointsW, spellW.Radius)
		if bestPos and hitCount >= Menu.Get("Wave.CastWHC")
			and Player:GetSpellState(SpellSlots.W) == SpellStates.Ready and Menu.Get("Wave.CastW") then
            Input.Cast(SpellSlots.W, bestPos)
        end
		
		if Player:GetSpellState(SpellSlots.E) == SpellStates.Ready and Menu.Get("Wave.CastE") then
			Input.Cast(SpellSlots.E)
		end
end

local function AutoE()
	local enemies = ObjManager.Get("enemy", "heroes")
	local myPos, myRange = Player.Position, (Player.AttackRange + Player.BoundingRadius)	
	
	if Player:GetSpellState(SpellSlots.E) ~= SpellStates.Ready then return end

	for handle, obj in pairs(enemies) do        
		local hero = obj.AsHero        
		if hero and hero.IsTargetable then
			local buffCountVenom = CountEStacks(hero)
			local dist = myPos:Distance(hero.Position)

			if dist <= spellE.Range and buffCountVenom and GetEDmg(hero,buffCountVenom) >= hero.Health then				
				Input.Cast(SpellSlots.E) -- E KS        
			end
		end		
	end	
end 

local function OnDraw()	

	-- Draw W Range
	if Player:GetSpellState(SpellSlots.W) == SpellStates.Ready and Menu.Get("Drawing.DrawW") then 
		Renderer.DrawCircle3D(Player.Position, spellW.Range, 30, 1.0, Menu.Get("Drawing.DrawWColor"))
	end
	-- Draw E Range
	if Player:GetSpellState(SpellSlots.E) == SpellStates.Ready and Menu.Get("Drawing.DrawE") then 
		Renderer.DrawCircle3D(Player.Position, spellE.Range, 30, 1.0, Menu.Get("Drawing.DrawEColor"))
	end
	-- Draw R Range
	if Player:GetSpellState(SpellSlots.R) == SpellStates.Ready and Menu.Get("Drawing.DrawR") then 
		Renderer.DrawCircle3D(Player.Position, spellR.Range, 30, 1.0, Menu.Get("Drawing.DrawRColor"))
	end

end

local function OnHighPriority()

	if not GameIsAvailable() then return end
	if not Orbwalker.CanCast() then return end

	if Menu.Get("Misc.CastEKS") then
		AutoE()
	end
end

local function OnNormalPriority()

	if not GameIsAvailable() then return end
	if not Orbwalker.CanCast() then return end

	local gameTime = Game.GetTime()
	if gameTime < (lastTick + 0.25) then return end
	lastTick = gameTime
	
	local target = Orbwalker.GetTarget()
	if target and Orbwalker.GetMode() == "Combo" then 
		Combo(target)
	elseif target and Orbwalker.GetMode() == "Harass" then
		Harass(target)
	elseif Orbwalker.GetMode() == "Waveclear" then
		Waveclear()
	end
end

function OnLoad() 
	if Player.CharName ~= "Twitch" then return false end 
	
	EventManager.RegisterCallback(Enums.Events.OnHighPriority, OnHighPriority)
	EventManager.RegisterCallback(Enums.Events.OnNormalPriority, OnNormalPriority)
	EventManager.RegisterCallback(Enums.Events.OnDraw, OnDraw)
	
	return true
end

