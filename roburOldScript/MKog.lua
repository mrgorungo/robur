if Player.CharName ~= "KogMaw" then return false end

module("MKog", package.seeall, log.setup)
clean.module("MKog", clean.seeall, log.setup)

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

function MKogMenu()
	Menu.NewTree("MKogCombo", "Combo", function ()
    Menu.Checkbox("Combo.CastQ","Cast Q",true)
	Menu.Slider("Combo.CastQHC", "Q Hit Chance", 0.65, 0.05, 1, 0.05)
	Menu.Checkbox("Combo.CastW","Cast W",true)
	Menu.Checkbox("Combo.CastE","Cast E",true)
	Menu.Slider("Combo.CastEHC", "E Hit Chance", 0.70, 0.05, 1, 0.05)
	Menu.Checkbox("Combo.CastR","Cast R",true)
	Menu.Slider("Combo.CastRHC", "R Hit Chance", 0.60, 0.05, 1, 0.05)
	Menu.Slider("Combo.CastRMS", "R Max Stack", 4, 1, 10, 1)
	Menu.Slider("Combo.CastRMinMana", "R % Min. Mana", 20, 1, 100, 1)
	Menu.Checkbox("Combo.CastRNoW","Cast R Only If not in W",true)
	end)
	Menu.NewTree("MKogHarass", "Harass", function ()
	Menu.Checkbox("Harass.CastQ","Cast Q",true)
	Menu.Slider("Harass.CastQHC", "Q Hit Chance", 0.70, 0.05, 1, 0.05)
	Menu.Checkbox("Harass.CastW","Cast W",true)
	Menu.Checkbox("Harass.CastE","Cast E",true)
	Menu.Slider("Harass.CastEHC", "E Hit Chance", 0.70, 0.05, 1, 0.05)
	Menu.Checkbox("Harass.CastR","Cast R",true)
	Menu.Slider("Harass.CastRHC", "R Hit Chance", 0.60, 0.05, 1, 0.05)
	Menu.Slider("Harass.CastRMS", "R Max Stack", 2, 1, 10, 1)
	Menu.Slider("Harass.CastRMinMana", "R % Min. Mana", 20, 1, 100, 1)
	end)
	Menu.NewTree("MKogWave", "Waveclear", function ()
    Menu.Checkbox("Wave.CastW","Cast W",true)
    Menu.Checkbox("Wave.CastE","Cast E",true)
	Menu.Slider("Wave.CastEHC", "E Min. Hit Count", 1, 0, 10, 1)
	Menu.Checkbox("Wave.CastR","Cast R",true)
	Menu.Slider("Wave.CastRHC", "R Min. Hit Count", 1, 0, 10, 1)
	Menu.Slider("Wave.CastRMS", "R Max Stack", 2, 1, 10, 1)
	Menu.Slider("Wave.CastRMinMana", "R % Min. Mana", 20, 1, 100, 1)
	end)
	Menu.NewTree("MKogMisc", "Misc.", function ()
    Menu.Checkbox("Misc.CastRKS","Auto-Cast R Killable",true)
	end)
	Menu.NewTree("MKogDrawing", "Drawing", function ()
    Menu.Checkbox("Drawing.DrawQ","Draw Q Range",true)
    Menu.ColorPicker("Drawing.DrawQColor", "Draw Q Color", 0xEF476FFF)
	Menu.Checkbox("Drawing.DrawE","Draw E Range",true)
    Menu.ColorPicker("Drawing.DrawEColor", "Draw E Color", 0x118AB2FF)
	Menu.Checkbox("Drawing.DrawR","Draw R Range",true)
    Menu.ColorPicker("Drawing.DrawRColor", "Draw R Color", 0xFFD166FF)
	end)
end

Menu.RegisterMenu("MKog","MKog",MKogMenu)

-- KogMaw Spell Info
local spellQ = {Range=1130, Radius=70, Speed=1650, Delay=0.65, Type="Linear", Collisions = {Heroes=true, Minions=true, WindWall=true}}
local spellE = {Range=1280, Radius=125, Speed=1350, Delay=0.65, Type="Linear"}
local spellR = {Range=1050, Radius=240, Speed=math.huge, Delay=1.25, Type="Circular"}

-- Global vars
local wActive = false
local lastTick = 0

local function GameIsAvailable()
	return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

local function ValidMinion(minion)
	return minion and minion.IsTargetable and minion.MaxHealth > 6 -- check if not plant or shroom
end

local function GetRDmg(target)
	local playerAI = Player.AsAI
	local dmgR = 60 + 40 * Player:GetSpell(SpellSlots.R).Level
	local bonusDmg = playerAI.BonusAD * 0.65
	local apDmg = playerAI.TotalAP * 0.35
    local totalDmg = dmgR + bonusDmg + apDmg
    return DamageLib.CalculateMagicalDamage(Player, target, totalDmg)
end

function GetRStacks() 
	local playerAI = Player.AsAI
    if playerAI then
		local kogRBuff = playerAI:GetBuff("kogmawlivingartillerycost")
		
		if kogRBuff then 
			return kogRBuff.Count
		end
	end

	return 0
	
end

local function CastQ(target,hitChance)
	if Player:GetSpellState(SpellSlots.Q) == SpellStates.Ready then
		local targetAI = target.AsAI
		local qPred = Prediction.GetPredictedPosition(targetAI, spellQ, Player.Position)
		if qPred and qPred.HitChance >= hitChance then
			Input.Cast(SpellSlots.Q, qPred.CastPosition)
		end
	end
end

local function CastW()
	if Player:GetSpellState(SpellSlots.W) == SpellStates.Ready then
		Input.Cast(SpellSlots.W)
	end
end

local function CastE(target,hitChance)
	if Player:GetSpellState(SpellSlots.E) == SpellStates.Ready then
		local targetAI = target.AsAI
		local ePred = Prediction.GetPredictedPosition(targetAI, spellE, Player.Position)
		if ePred and ePred.HitChance >= hitChance then
			Input.Cast(SpellSlots.E, ePred.CastPosition)
		end
	end
end

local function CastR(target,hitChance)
	if Player:GetSpellState(SpellSlots.R) == SpellStates.Ready then
		local targetAI = target.AsAI
		local rPred = Prediction.GetPredictedPosition(targetAI, spellR, Player.Position)
		if rPred and rPred.HitChance >= hitChance then
			if Player.Position:Distance(target.Position) > (Player.AttackRange + Player.BoundingRadius) then
				Input.Cast(SpellSlots.R, rPred.CastPosition)
			end
		end
	end
end

local function AutoRKS()
	local enemies = ObjManager.Get("enemy", "heroes")
	local myPos, rRange = Player.Position, (spellR.Range + Player.BoundingRadius)	
	if Player:GetSpellState(SpellSlots.R) ~= SpellStates.Ready then return end

	for handle, obj in pairs(enemies) do        
		local hero = obj.AsHero        
		if hero and hero.IsTargetable then
			local dist = myPos:Distance(hero.Position)
			local healthPred = HealthPred.GetHealthPrediction(hero, spellR.Delay)
			if dist <= rRange and GetRDmg(hero) > healthPred then				
				CastR(hero,Menu.Get("Combo.CastRHC")) -- R KS        
			end
		end		
	end	
end

local function Waveclear()

	if Menu.Get("Wave.CastW") then
		CastW()
	end
	
	local pPos, pointsE, pointsR = Player.Position, {}, {}
		
	-- Enemy Minions
	for k, v in pairs(ObjManager.Get("enemy", "minions")) do
		local minion = v.AsAI
		if ValidMinion(minion) then
			local posE = minion:FastPrediction(spellE.Delay)
			local posR = minion:FastPrediction(spellR.Delay)
			if posE:Distance(pPos) < spellE.Range and minion.IsTargetable then
				table.insert(pointsE, posE)
			end
			if posR:Distance(pPos) < spellR.Range and minion.IsTargetable then
				table.insert(pointsR, posR)
			end 
		end    
	end
		
	-- Jungle Minions
	if #pointsE == 0 or pointsR == 0 then 
		for k, v in pairs(ObjManager.Get("neutral", "minions")) do
			local minion = v.AsAI
			if ValidMinion(minion) then
				local posE = minion:FastPrediction(spellE.Delay)
				local posR = minion:FastPrediction(spellR.Delay)
				if posE:Distance(pPos) < spellE.Range then
					table.insert(pointsE, posE)
				end
				if posR:Distance(pPos) < spellR.Range then
					table.insert(pointsR, posR)
				end     
			end
		end
	end
	
	local bestPosE, hitCountE = Geometry.BestCoveringRectangle(pointsE, pPos, spellE.Radius*2)
	if bestPosE and hitCountE >= Menu.Get("Wave.CastEHC")
		and Player:GetSpellState(SpellSlots.E) == SpellStates.Ready and Menu.Get("Wave.CastE") then
           Input.Cast(SpellSlots.E, bestPosE)
    end
	local bestPosR, hitCountR = Geometry.BestCoveringCircle(pointsR, spellR.Radius)
	if bestPosR and hitCountR >= Menu.Get("Wave.CastRHC") 
		and Player:GetSpellState(SpellSlots.R) == SpellStates.Ready and Menu.Get("Wave.CastR") then
		local PlayerAAU = Player.AsAttackableUnit
		if GetRStacks() < Menu.Get("Wave.CastRMS") 
			and PlayerAAU.Mana >= (Menu.Get("Wave.CastRMinMana") / 100) * PlayerAAU.MaxMana then
			Input.Cast(SpellSlots.R, bestPosR)
		end
    end
end

local function OnHighPriority()

	if not GameIsAvailable() then return end
	if not Orbwalker.CanCast() then return end

	-- Auto R KS
	if Menu.Get("Misc.CastRKS") then
		local rLevel = Player:GetSpell(SpellSlots.R).Level
		spellR.Range = 1050 + rLevel * 250
		AutoRKS()
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
			local target = Orbwalker.GetTarget() or TS:GetTarget(spellQ.Range + Player.BoundingRadius, true)
			if target then
				CastQ(target,Menu.Get("Combo.CastQHC"))
			end
		end
		if Menu.Get("Combo.CastW") then
			-- dynamic range W
			local wLevel = Player:GetSpell(SpellSlots.W).Level
			local wRange = 110 + wLevel * 20
			local target = Orbwalker.GetTarget() or TS:GetTarget(Player.AttackRange + wRange + Player.BoundingRadius, true)
			if target then 
				CastW()
			end
		end
		if Menu.Get("Combo.CastE") then
			local target = Orbwalker.GetTarget() or TS:GetTarget(spellE.Range + Player.BoundingRadius, true)
			if target then
				CastE(target,Menu.Get("Combo.CastEHC"))
			end
		end
		
		if Menu.Get("Combo.CastR") then
			local PlayerAAU = Player.AsAttackableUnit
			if GetRStacks() < Menu.Get("Combo.CastRMS")
				and PlayerAAU.Mana >= (Menu.Get("Combo.CastRMinMana") / 100) * PlayerAAU.MaxMana then
				-- dynamic range R
				local rLevel = Player:GetSpell(SpellSlots.R).Level
				spellR.Range = 1050 + rLevel * 250
				local target = Orbwalker.GetTarget() or TS:GetTarget(spellR.Range + Player.BoundingRadius, true)
				if target then
					if Menu.Get("Combo.CastRNoW") then
						if not wActive then 
							CastR(target,Menu.Get("Combo.CastRHC"))
						end
					else
						CastR(target,Menu.Get("Combo.CastRHC"))
					end
				end
			end
		end
		
	-- Waveclear
	elseif Orbwalker.GetMode() == "Waveclear" then	
	
		Waveclear()
		
	-- Harass
	elseif Orbwalker.GetMode() == "Harass" then	
	
		if Menu.Get("Harass.CastQ") then
			local target = Orbwalker.GetTarget() or TS:GetTarget(spellQ.Range + Player.BoundingRadius, true)
			if target then
				CastQ(target,Menu.Get("Harass.CastQHC"))
			end
		end
		if Menu.Get("Harass.CastW") then
			-- dynamic range W
			local wLevel = Player:GetSpell(SpellSlots.W).Level
			local wRange = 110 + wLevel * 20
			local target = Orbwalker.GetTarget() or TS:GetTarget(Player.AttackRange + wRange + Player.BoundingRadius, true)
			if target then 
				CastW()
			end
		end
		if Menu.Get("Harass.CastE") then
			local target = Orbwalker.GetTarget() or TS:GetTarget(spellE.Range + Player.BoundingRadius, true)
			if target then
				CastE(target,Menu.Get("Harass.CastEHC"))
			end
		end
		if Menu.Get("Harass.CastR") then
			local PlayerAAU = Player.AsAttackableUnit
			if GetRStacks() < Menu.Get("Harass.CastRMS") 
				and PlayerAAU.Mana >= (Menu.Get("Harass.CastRMinMana") / 100) * PlayerAAU.MaxMana then
				-- dynamic range R
				local rLevel = Player:GetSpell(SpellSlots.R).Level
				spellR.Range = 1050 + rLevel * 250
				local target = Orbwalker.GetTarget() or TS:GetTarget(spellR.Range + Player.BoundingRadius, true)
				if target then
					CastR(target,Menu.Get("Harass.CastRHC"))
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
	-- Draw E Range
	if Player:GetSpell(SpellSlots.E).IsLearned and Menu.Get("Drawing.DrawE") then 
		Renderer.DrawCircle3D(Player.Position, spellE.Range, 30, 1.0, Menu.Get("Drawing.DrawEColor"))
	end
	-- Draw R Range
	if Player:GetSpell(SpellSlots.R).IsLearned and Menu.Get("Drawing.DrawR") then 
		Renderer.DrawCircle3D(Player.Position, spellR.Range, 30, 1.0, Menu.Get("Drawing.DrawRColor"))
	end

end

local function OnBuffGain(obj, buffInst)
	if obj.IsMe then
		local buff = buffInst.Name
		if buff == "KogMawBioArcaneBarrage" then 
			wActive = true
		end
	end
end

local function OnBuffLost(obj, buffInst)
	if obj.IsMe then
		local buff = buffInst.Name
		if buff == "KogMawBioArcaneBarrage" then 
			wActive = false
		end
	end
end

function OnLoad() 
	if Player.CharName ~= "KogMaw" then return false end 
	
	EventManager.RegisterCallback(Enums.Events.OnHighPriority, OnHighPriority)
	EventManager.RegisterCallback(Enums.Events.OnNormalPriority, OnNormalPriority)
	EventManager.RegisterCallback(Enums.Events.OnDraw, OnDraw)
	EventManager.RegisterCallback(Enums.Events.OnBuffGain, OnBuffGain)
	EventManager.RegisterCallback(Enums.Events.OnBuffLost, OnBuffLost)
		
	return true
end

