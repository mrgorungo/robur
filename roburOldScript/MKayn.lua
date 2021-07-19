if Player.CharName ~= "Kayn" then return false end

module("MKayn", package.seeall, log.setup)
clean.module("MKayn", clean.seeall, log.setup)

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

function MKaynMenu()
	Menu.NewTree("MKaynCombo", "Combo", function ()
		Menu.Checkbox("Combo.CastQ","Cast Q",true)
		Menu.Slider("Combo.CastQHC", "Q Hit Chance", 0.60, 0.05, 1, 0.05)
		Menu.Checkbox("Combo.CastW","Cast W",true)
		Menu.Slider("Combo.CastWHC", "W Hit Chance", 0.60, 0.05, 1, 0.05)
	end)
	Menu.NewTree("MKaynHarass", "Harass", function ()
		Menu.Checkbox("Harass.CastQ","Cast Q",true)
		Menu.Slider("Harass.CastQHC", "Q Hit Chance", 0.60, 0.05, 1, 0.05)
		Menu.Checkbox("Harass.CastW","Cast W",true)
		Menu.Slider("Harass.CastWHC", "W Hit Chance", 0.60, 0.05, 1, 0.05)
	end)
	Menu.NewTree("MKaynWave", "Waveclear", function ()
		Menu.Checkbox("Wave.CastQ","Cast Q",true)
		Menu.Slider("Wave.CastQHC", "Q Min. Hit Count", 1, 0, 10, 1)
		Menu.Checkbox("Wave.CastW","Cast W",true)
		Menu.Slider("Wave.CastWHC", "W Min. Hit Count", 1, 0, 10, 1)
	end)
	Menu.NewTree("MKaynFlee", "Flee", function ()
		Menu.Checkbox("Flee.CastE","Cast E",true)
	end)
	Menu.NewTree("MKaynMisc", "Misc.", function ()
		Menu.Checkbox("Misc.CastRKS","Auto-Cast R Killable",true)
		Menu.Checkbox("Misc.CastR","Auto-Cast R Own LowHP",true)
		Menu.Slider("Misc.CastRMinHP", "R % Min. HP", 20, 1, 100, 1)
		Menu.Checkbox("Misc.KaynTransf","Is Kayn Transformed (Set Only on Reload)",false)
	end)
	Menu.NewTree("MKaynDrawing", "Drawing", function ()
		Menu.Checkbox("Drawing.DrawQ","Draw Q Range",true)
		Menu.ColorPicker("Drawing.DrawQColor", "Draw Q Color", 0xEF476FFF)
		Menu.Checkbox("Drawing.DrawW","Draw W Range",true)
		Menu.ColorPicker("Drawing.DrawWColor", "Draw W Color", 0x06D6A0FF)
		Menu.Checkbox("Drawing.DrawR","Draw R Range",true)
		Menu.ColorPicker("Drawing.DrawRColor", "Draw R Color", 0xFFD166FF)
	end)
end

Menu.RegisterMenu("MKayn","MKayn",MKaynMenu)

local spells = {
	Q = Spell.Skillshot({
		Slot = Enums.SpellSlots.Q,
		Range = 350,
		Speed = 2000,
		Delay = 0,
		Radius = 350,
		Type = "Linear",
	}),
	W = Spell.Skillshot({
		Slot = Enums.SpellSlots.W,
		Range = 700,
		Delay = 0.55,
		Speed = 1700,
		Radius = 175,
		Type = "Linear",
		UseHitbox = true -- check
	}),
	E = Spell.Active({
		Slot = Enums.SpellSlots.E,
	}),
	R = Spell.Targeted({
		Slot = Enums.SpellSlots.R,
		Delay = 1,
		Range = 550,
	}),
}

-- Global vars
local isTransformed = false
local lastTick = 0

local function GameIsAvailable()
	return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

local function ValidMinion(minion)
	return minion and minion.IsTargetable and minion.MaxHealth > 6 -- check if not plant or shroom
end

local function IsOnUltimate()
	return Player:GetSpell(SpellSlots.R).Name == "KaynRJumpOut"
end

local function HasRMark(target)
	return target:GetBuff("kaynrenemymark");
end

local function GetKaynForm()
	isTransformed = Menu.Get("Misc.KaynTransf")
	if isTransformed then
		if Player:GetSpell(SpellSlots.W).Name == "KaynAssW" then
			return "ass"
		else
			return "rast"
		end
	else
		return "none"
	end
end

local function GetRDmg(target)
	local playerAI = Player.AsAI
	local dmgR = 50 + 100 * Player:GetSpell(SpellSlots.R).Level
	local bonusDmg = playerAI.BonusAD * 1.75
	local transfDmg = 0
	if GetKaynForm() == "ass" then
		transfDmg = (0.10118 + 0.01882 * Player.Level) * Player.BonusAP
	elseif GetKaynForm == "rast" then
		transfDmg = (0.1 + 0.13 * (playerAI.BonusAD/100)) * target.MaxHealth
	end
    local totalDmg = dmgR + bonusDmg + transfDmg
    return DamageLib.CalculatePhysicalDamage(Player, target, totalDmg)
end

local function CastQ(target,hitChance)
	if spells.Q:IsReady() then
		if spells.Q:CastOnHitChance(target, hitChance) then
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

local function CastE()
	if spells.E:IsReady() then
		if spells.E:Cast() then
			return
		end
	end
end

local function CastR(target)
	if spells.R:IsReady() and HasRMark(target) then
		if spells.R:Cast(target) then
			return
		end
	end
end

local function AutoRKS()

	if not spells.R:IsReady() then return end

	if IsOnUltimate() then
		spells.R:Cast(Renderer.GetMousePos()) -- R Final KS
	end

	local enemies = ObjManager.Get("enemy", "heroes")
	local myPos, rRange = Player.Position, (spells.R.Range + Player.BoundingRadius)

	for handle, obj in pairs(enemies) do        
		local hero = obj.AsHero        
		if hero and hero.IsTargetable then
			local dist = myPos:Distance(hero.Position)
			local healthPred = HealthPred.GetHealthPrediction(hero, spells.R.Delay)
			if dist <= rRange and GetRDmg(hero) > healthPred and HasRMark(hero) then
				CastR(hero) -- R KS
			end
		end		
	end	
end

local function AutoRLowHP()
	if not spells.R:IsReady() then return end

	local enemies = ObjManager.Get("enemy", "heroes")
	local myPos, rRange = Player.Position, (spells.R.Range + Player.BoundingRadius)


	for handle, obj in pairs(enemies) do
		local hero = obj.AsHero
		if hero and hero.IsTargetable then
			local dist = myPos:Distance(hero.Position)
			local healthPred = HealthPred.GetHealthPrediction(Player, spells.R.Delay)
			local PlayerAAU = Player.AsAttackableUnit
			if dist <= rRange and healthPred <= (Menu.Get("Misc.CastRMinHP") / 100) * PlayerAAU.MaxHealth
					and HasRMark(hero) then
				CastR(hero) -- R KS
			end
		end
	end
end

local function Waveclear()

	local pPos, pointsQ, pointsW = Player.Position, {}, {}
		
	-- Enemy Minions
	for k, v in pairs(ObjManager.Get("enemy", "minions")) do
		local minion = v.AsAI
		if ValidMinion(minion) then
			local posQ = minion:FastPrediction(spells.Q.Delay)
			local posW = minion:FastPrediction(spells.W.Delay)
			if posQ:Distance(pPos) < spells.Q.Range and minion.IsTargetable then
				table.insert(pointsQ, posQ)
			end
			if posW:Distance(pPos) < spells.W.Range and minion.IsTargetable then
				table.insert(pointsW, posW)
			end 
		end    
	end
		
	-- Jungle Minions
	if #pointsQ == 0 or pointsW == 0 then
		for k, v in pairs(ObjManager.Get("neutral", "minions")) do
			local minion = v.AsAI
			if ValidMinion(minion) then
				local posQ = minion:FastPrediction(spells.Q.Delay)
				local posW = minion:FastPrediction(spells.W.Delay)
				if posQ:Distance(pPos) < spells.Q.Range then
					table.insert(pointsQ, posQ)
				end
				if posW:Distance(pPos) < spells.W.Range then
					table.insert(pointsW, posW)
				end     
			end
		end
	end
	
	local bestPosQ, hitCountQ = spells.Q:GetBestLinearCastPos(pointsQ)
	if bestPosQ and hitCountQ >= Menu.Get("Wave.CastQHC")
		and spells.Q:IsReady() and Menu.Get("Wave.CastQ") then
		spells.Q:Cast(bestPosQ)
    end
	local bestPosW, hitCountW = spells.W:GetBestLinearCastPos(pointsW)
	if bestPosW and hitCountW >= Menu.Get("Wave.CastWHC")
		and spells.W:IsReady() and Menu.Get("Wave.CastW") then
		spells.W:Cast(bestPosW)
    end
end

local function OnHighPriority()

	if not GameIsAvailable() then return end
	if not Orbwalker.CanCast() then return end

	-- Auto R KS
	if Menu.Get("Misc.CastRKS") then
		AutoRKS()
	end

	-- Auto R on Low HP
	if Menu.Get("Misc.CastR") then
		AutoRLowHP()
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
			local target = Orbwalker.GetTarget() or TS:GetTarget(spells.Q.Range + Player.BoundingRadius, true)
			if target then
				CastQ(target,Menu.Get("Combo.CastQHC"))
			end
		end
		if Menu.Get("Combo.CastW") then
			-- dynamic range W
			local target = Orbwalker.GetTarget() or TS:GetTarget(spells.W.Range + Player.BoundingRadius, true)
			if target then 
				CastW(target,Menu.Get("Combo.CastWHC"))
			end
		end
		
	-- Waveclear
	elseif Orbwalker.GetMode() == "Waveclear" then

		Waveclear()
		
	-- Harass
	elseif Orbwalker.GetMode() == "Harass" then

		if Menu.Get("Harass.CastQ") then
			local target = Orbwalker.GetTarget() or TS:GetTarget(spells.Q.Range + Player.BoundingRadius, true)
			if target then
				CastQ(target,Menu.Get("Harass.CastQHC"))
			end
		end
		if Menu.Get("Harass.CastW") then
			-- dynamic range W
			local target = Orbwalker.GetTarget() or TS:GetTarget(spells.W.Range + Player.BoundingRadius, true)
			if target then
				CastW(target,Menu.Get("Harass.CastWHC"))
			end
		end

	-- Flee
	elseif Orbwalker.GetMode() == "Flee" then
		if Menu.Get("Flee.CastE") then
			CastE()
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
	-- Draw R Range
	if Player:GetSpell(SpellSlots.R).IsLearned and Menu.Get("Drawing.DrawR") then 
		Renderer.DrawCircle3D(Player.Position, spells.R.Range, 30, 1.0, Menu.Get("Drawing.DrawRColor"))
	end

end

local function OnBuffLost(obj, buffInst)
	if obj.IsHero and obj.IsMe then
		local buff = buffInst.Name
		if buff == "kaynassready" or buff == "kaynslayready" then
			isTransformed = true
			Menu.Set("Misc.KaynTransf",true)
			-- Update Assassin Range values
			if GetKaynForm() == "ass" then
				spells.W.Range = spells.W.Range + 200
				spells.R.Range = spells.R.Range + 200
			end
		end
	end
end

function OnLoad() 
	if Player.CharName ~= "Kayn" then return false end

	-- Reset to default
	Menu.Set("Misc.KaynTransf",false)

	EventManager.RegisterCallback(Enums.Events.OnNormalPriority, OnNormalPriority)
	EventManager.RegisterCallback(Enums.Events.OnHighPriority, OnHighPriority)
	EventManager.RegisterCallback(Enums.Events.OnDraw, OnDraw)
	EventManager.RegisterCallback(Enums.Events.OnBuffLost, OnBuffLost)

	return true
end

