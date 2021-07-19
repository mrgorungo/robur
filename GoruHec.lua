if Player.CharName ~= "Hecarim" then return false end

module("GoruHec", package.seeall, log.setup)
clean.module("GoruHec", clean.seeall, log.setup)

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

function NAShacoMenu()
	Menu.NewTree("NAShacoCombo", "Combo", function ()
		Menu.Checkbox("Combo.CastQ","Cast Q",false)
		Menu.Slider("Combo.CastQMinMana", "Q % Min. Mana", 0, 1, 100, 1)
		Menu.Checkbox("Combo.CastW","Cast W",true)
		Menu.Checkbox("Combo.CastWCC","Cast W on CC Only",true)
		Menu.Slider("Combo.CastWHC", "W Hit Chance", 0.50, 0.05, 1, 0.05)
		Menu.Slider("Combo.CastWMinMana", "W % Min. Mana", 0, 1, 100, 1)
		Menu.Checkbox("Combo.CastE","Cast E",true)
		Menu.Slider("Combo.CastEMinMana", "E % Min. Mana", 0, 1, 100, 1)
		Menu.Checkbox("Combo.CastR","Cast R",true)
		Menu.Checkbox("Combo.CastRHail","Cast R Only After HailOfBlades Buff",true)
		Menu.Slider("Combo.CastRMinMana", "R % Min. Mana", 0, 1, 100, 1)
		Menu.Checkbox("Combo.CastIgnite", "Cast Ignite if Available", true)
		Menu.Checkbox("Combo.CastSmite", "Cast Smite if Available", true)
		Menu.Checkbox("Combo.CastProwler", "Cast Prowler's Claw if Available", true)
		Menu.Checkbox("Combo.CastWhip", "Cast IronsWhip if Available", true)
	end)
	Menu.NewTree("NAShacoHarass", "Harass", function ()
		Menu.Checkbox("Harass.CastW","Cast W",true)
		Menu.Checkbox("Harass.CastWCC","Cast W on CC Only",true)
		Menu.Slider("Harass.CastWHC", "W Hit Chance", 0.60, 0.05, 1, 0.05)
		Menu.Slider("Harass.CastWMinMana", "W % Min. Mana", 0, 1, 100, 1)
		Menu.Checkbox("Harass.CastE","Cast E",true)
		Menu.Slider("Harass.CastEMinMana", "E % Min. Mana", 0, 1, 100, 1)
	end)
	Menu.NewTree("NAShacoWave", "Waveclear", function ()
		Menu.ColoredText("Wave", 0xFFD700FF, true)
		Menu.Checkbox("Waveclear.CastW","Cast W",true)
		Menu.Slider("Waveclear.CastWHC", "W Min. Hit Count", 1, 0, 10, 1)
		Menu.Slider("Waveclear.CastWMinMana", "W % Min. Mana", 0, 1, 100, 1)
		Menu.Checkbox("Waveclear.CastE","Cast E",true)
		Menu.Slider("Waveclear.CastEMinMana", "W % Min. Mana", 0, 1, 100, 1)
		Menu.Separator()
		Menu.ColoredText("Jungle", 0xFFD700FF, true)
		Menu.Checkbox("Waveclear.CastWJg","Cast W",true)
		Menu.Slider("Waveclear.CastWHCJg", "W Min. Hit Count", 1, 0, 10, 1)
		Menu.Slider("Waveclear.CastWMinManaJg", "W % Min. Mana", 0, 1, 100, 1)
		Menu.Checkbox("Waveclear.CastEJg","Cast W",true)
		Menu.Slider("Waveclear.CastEMinManaJg", "W % Min. Mana", 0, 1, 100, 1)
	end)
	Menu.NewTree("NAShacoLasthit", "Lasthit", function ()
		Menu.Checkbox("Lasthit.CastE","Cast E",true)
	end)
	Menu.NewTree("NAShacoMisc", "Misc.", function ()
		Menu.Checkbox("Misc.CastAAQOnlyBackstab","AA Only if Backstab while Stealth on Q",true)
		Menu.Checkbox("Misc.CastEKS","Auto-Cast E Killable",true)
		Menu.Checkbox("Misc.CastWGap","Auto-Cast W GapCloser",true)
		Menu.Checkbox("Misc.CastRLowHP","Auto-Cast R LowHP",true)
		Menu.Slider("Misc.CastRMinLowHP", "R % LowHP", 30, 1, 100, 1)
		Menu.Checkbox("Misc.AutoRFollow","Auto-Clone Follow",true)
		Menu.Checkbox("Misc.CoupRune","Coup De Grace Rune",true)
		Menu.Checkbox("Misc.CastWInitialJg","Cast W for Initial Jungle Spots",true)
		Menu.Keybind("Misc.JgBackStab", "Jungle BackStab Only", string.byte("J"), true, false)
	end)
	Menu.NewTree("GoruHecoDrawing", "Drawing", function ()
		Menu.Checkbox("Drawing.DrawR","Draw R Range",true)
		Menu.ColorPicker("Drawing.DrawRColor", "Draw R Color", 0xEF476FFF)
		
	end)
end
Menu.RegisterMenu("GoruHec","GoruHec",NAShacoMenu)

local function GetIgniteSlot()
	for i=SpellSlots.Summoner1, SpellSlots.Summoner2 do
		if Player:GetSpell(i).Name:lower():find("summonerdot") then
			return i
		end
	end
	return SpellSlots.Unknown
end

local function GetSmiteSlot()
	for i=SpellSlots.Summoner1, SpellSlots.Summoner2 do
		if Player:GetSpell(i).Name:lower():find("smite") then
			return i
		end
	end
	return SpellSlots.Unknown
end

local function GetProwlerSlot()	
	for i=SpellSlots.Item1, SpellSlots.Item6 do
		local item = Player:GetSpell(i)
		if item and item.Name == "6693Active" then
			return i
		end
	end
	
	return SpellSlots.Unknown
end

local function GetWhipSlot()	
	for i=SpellSlots.Item1, SpellSlots.Item6 do
		local item = Player:GetSpell(i)
		if item then 
		if item.Name == "6029Active" or item.Name == "6631Active" then
			return i
		end
		end
	end
	
	return SpellSlots.Unknown
end



-- Global vars
local spells = {
	Q = Spell.Active({
		Slot = Enums.SpellSlots.Q,
		Range = 350,
		Delay = math.huge,
	}),
	W = Spell.Active({
		Slot = Enums.SpellSlots.W,
		Range = 500,
		Speed = math.huge,

	}),
	E = Spell.Targeted({
		Slot = Enums.SpellSlots.E,
		Delay = 0.25,
		Range = 625,
	}),
	R = Spell.Skillshot({
		Slot = Enums.SpellSlots.R,
		Delay = 0.25,
		Range = 2500,
		Radius = 160,
	
	}),
	Ign = Spell.Targeted({
		Slot = GetIgniteSlot(),
		Delay = math.huge,
		Range = 600,
	}),
	Smite = Spell.Targeted({
		Slot = GetSmiteSlot(),
		Delay = math.huge,
		Range = 600,
	}),
	Prowler = Spell.Targeted({
		Slot = GetProwlerSlot(),
		Delay = math.huge,
		Range = 500,
	}),

	Whip = Spell.Active({
		Slot = GetWhipSlot(),
		Delay = math.huge,
		Range = 270,
	}),
}

local jgWSpots = {
	W1Blue = {
		Position = Geometry.Vector(6861.04,50.17,5374.14),
		Time = 50,
	},
	W2Blue = {
		Position = Geometry.Vector(6970.46,53.94,5456.48),
		Time = 68,
	},
	W3Blue = {
		Position = Geometry.Vector(6905.83,48.53,4559.07),
		Time = 84,
	},
	W1Red = {
		Position = Geometry.Vector(7955.41,52.12,9651.28),
		Time = 50,
	},
	W2Red = {
		Position = Geometry.Vector(7854.32,52.29,9578.22),
		Time = 68,
	},
	W3Red = {
		Position = Geometry.Vector(7898.00,50.21,10385.15),
		Time = 84,
	},
}

local lastTick = 0
local qActive = false
local hailBuffActive = false
local killableEnemies = {}
local smiteDmg = 0

local function ValidMinion(minion)
	return minion and minion.IsTargetable and minion.MaxHealth > 6 -- check if not plant or shroom
end

local function GameIsAvailable()
	return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

local function IsQActive()
	return qActive
end

local function IsCloneActive()
	return Player:GetSpell(SpellSlots.R).Name == "HallucinateGuide"
end

local function isTargetCC(target)
	return target.IsImmovable or target.IsTaunted or target.IsFeared or target.IsSurpressed or target.IsAsleep
		or target.IsCharmed or target.IsSlowed or target.IsGrounded
end

local function GetQDmg(target)
	local playerAI = Player.AsAI
	local count = 0
	local buff = 0
	buff = playerAI:GetBuff("hecarimrapidslash2")
	if buff then 
		count = buff.Count
	end
	
	local dmgQ = 23 + 37 * Player:GetSpell(SpellSlots.Q).Level
	local bonusDmg = playerAI.BonusAD * 0.85
	local stackDmg =  (( 2 + playerAI.BonusAD * 0.03 ) /100) * count

	--local totalDmg = (dmgQ + bonusDmg)

	local totalDmg = (dmgQ + bonusDmg) + (dmgQ + bonusDmg) * stackDmg

	
	

	
	return DamageLib.CalculatePhysicalDamage(Player, target, totalDmg)
end

local function GetIgniteDmg(target)
	return 50 + 20 * Player.Level - target.HealthRegen * 2.5
end

local function GetSmiteDmg(target)
	if spells.Smite.Slot ~= SpellSlots.Unknown and  spells.Smite:IsReady() then
		if Player:GetSpell(spells.Smite.Slot).Name == "S5_SummonerSmitePlayerGanker" then
			return 12 + 8 * Player.Level
		end
	end

	return 0
end

local function GetProwlerDmg(target)
	local playerAI = Player.AsAI
	local dmg = 65 + 0.25 * playerAI.BonusAD
	return DamageLib.CalculatePhysicalDamage(Player, target, dmg)
end

local function GetDamage(target)
	local totalDmg = 0
	if spells.E:IsReady() then
		totalDmg = totalDmg + GetEDmg(target)
	end
	if spells.Ign.Slot ~= SpellSlots.Unknown and  spells.Ign:IsReady() then
		totalDmg = totalDmg + GetIgniteDmg(target)
	end
	if spells.Smite.Slot ~= SpellSlots.Unknown and spells.Smite:IsReady() then
		totalDmg = totalDmg + GetSmiteDmg(target)
	end
	if spells.Prowler.Slot ~= SpellSlots.Unknown and spells.Prowler:IsReady() then
		totalDmg = totalDmg + GetProwlerDmg(target)
	end
	
	return totalDmg
end

local function CastQ(target)
	if spells.Q:IsReady() then
		if target then
			if spells.Q:Cast() then
				return
			end
		
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

local function CastW(pos)
	if spells.W:IsReady() then
		if spells.W:Cast(pos) then
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

local function CastR(target)
	if spells.R:IsReady() then

		if target then
			if spells.R:Cast(target) then
				return
			end
		else
			local mousePos = Renderer.GetMousePos()
			if spells.R:Cast(mousePos)  then
				return
			end
		end
	end
end

local function CastIgnite(target)
	if spells.Ign:IsReady() then
		if spells.Ign:Cast(target) then
			return
		end
	end
end

local function CastSmite(target)
	if spells.Smite:IsReady() then
		if Player:GetSpell(spells.Smite.Slot).Name == "S5_SummonerSmiteDuel" or 
			Player:GetSpell(spells.Smite.Slot).Name == "S5_SummonerSmitePlayerGanker" then
			if spells.Smite:Cast(target) then
				return
			end
		end
	end
end

local function CastProwler(target)
	if spells.Prowler:IsReady() then
		if spells.Prowler:Cast(target) then
			return
		end
	end
end

local function AutoEKS()
	if not spells.Q:IsReady() then return end

	local enemies = ObjManager.GetNearby("enemy", "heroes")
	
	for handle, obj in pairs(enemies) do
		local hero = obj.AsHero
		if hero and hero.IsTargetable then
			local dist = Player.Position:Distance(hero.Position)
			local healthPred = HealthPred.GetHealthPrediction(hero, spells.Q.Delay)
			--if GetEDmg(hero) > healthPred then
			--	killableEnemies[hero.Name] = hero
			--else
			--	killableEnemies[hero.Name] = nil
			--end
			if dist <= spells.Q.Range and GetQDmg(hero) > healthPred then
				spells.Q:Cast() -- E KS
			end
		end
	end
end

local function AutoRLowHP()
	if not spells.R:IsReady() then return end

	if Player.HealthPercent <= Menu.Get("Misc.CastRMinLowHP")/100 then
		CastR()
	end

end

local function AutoInitialJg()
	local gameTime = Game.GetTime()
	for handle, spot in pairs(jgWSpots) do
		if Player:Distance(spot.Position) <= spells.W.Range and 
			gameTime > spot.Time-0.5 and gameTime <= spot.Time+0.5 then
			CastW(spot.Position)
		end
	end
end

local function Waveclear()

	if spells.Q:IsReady() or spells.W:IsReady() then


	
		for k, v in pairs(ObjManager.GetNearby("enemy", "minions")) do
			local minion = v.AsAI
			if ValidMinion(minion) and Player:Distance(minion.Position) < spells.Q.Range then
				spells.Q:Cast()
				spells.W:Cast()
				return
			end
		end
	

			for k, v in pairs(ObjManager.GetNearby("neutral", "minions")) do
				local minion = v.AsAI
				if ValidMinion(minion) and Player:Distance(minion.Position) < spells.Q.Range then 
					spells.Q:Cast()
					spells.W:Cast()
					return
				end
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
					if minion:Distance(pPos) <= spells.Q.Range then
						if minionE then
							local healthPred = HealthPred.GetHealthPrediction(minion, spells.Q.Delay)
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
local function autoR()
	local target =  spells.R:GetTarget()
		
		if target then
			--print(target.CharName)
			
			spells.R:Cast(target)
			return true
		end
end
	


local function OnHighPriority()

	if not GameIsAvailable() then return end
	if not Orbwalker.CanCast() then return end
	if IsCloneActive() and Menu.Get("Misc.AutoRFollow") then
		autoR()
		
	end


	if Menu.Get("Misc.CastEKS") then
		AutoEKS()
	end
	if Menu.Get("Misc.CastRLowHP") then
		AutoRLowHP()
	end

end

local function OnNormalPriority()

	if not GameIsAvailable() then return end
	--if not Orbwalker.CanCast() then return end

	local gameTime = Game.GetTime()
	if gameTime < (lastTick + 0.25) then return end
	lastTick = gameTime

	Orbwalker.BlockAttack(true) 
	 Orbwalker.BlockMove(true) 
	if Menu.Get("Misc.CastWInitialJg") and spells.W:IsReady() 
		and gameTime >= 50 and gameTime < 90 then
		AutoInitialJg()
	end
	
	-- Combo
	if Orbwalker.GetMode() == "Combo" then
		if Menu.Get("Combo.CastQ") then
			if spells.Q:IsReady() then
				local target = Orbwalker.GetTarget() or TS:GetTarget(spells.Q.Range , false)
				if target then
					spells.Q:Cast()
					return
				end
			end
		end
		if Menu.Get("Combo.CastW") then
			if spells.W:IsReady() then
				local target = Orbwalker.GetTarget() or TS:GetTarget(spells.W.Range,false)
				if target then
					spells.W:Cast()
					return

				end
			end
		end
		if Menu.Get("Combo.CastIgnite") then
			if spells.Ign.Slot ~= SpellSlots.Unknown then
				if spells.Ign:IsReady() and not qActive then
					local target = Orbwalker.GetTarget() or TS:GetTarget(spells.Ign.Range + Player.BoundingRadius, true)
					if target and target.Position:Distance(Player.Position) <= (spells.Ign.Range + Player.BoundingRadius) then
						CastIgnite(target)
						return
					end
				end
			end
		end
		if Menu.Get("Combo.CastSmite") then
			if spells.Smite.Slot ~= SpellSlots.Unknown then
				if spells.Smite:IsReady() and not qActive then
					local target = Orbwalker.GetTarget() or TS:GetTarget(spells.Smite.Range + Player.BoundingRadius, true)
					if target and target.Position:Distance(Player.Position) <= (spells.Smite.Range + Player.BoundingRadius) then
						CastSmite(target)
					end
				end
			end
		end
		if Menu.Get("Combo.CastProwler") then
			spells.Prowler.Slot = GetProwlerSlot()
			if spells.Prowler.Slot ~= SpellSlots.Unknown then
				if spells.Prowler:IsReady() then
					local target = Orbwalker.GetTarget() or TS:GetTarget(spells.Prowler.Range + Player.BoundingRadius, true)
					if target and target.Position:Distance(Player.Position) <= (spells.Prowler.Range + Player.BoundingRadius) then
						CastProwler(target)
						return
					end
				end
			end
		end

				if Menu.Get("Combo.CastWhip") then
			spells.Whip.Slot = GetWhipSlot()
			if spells.Whip.Slot ~= SpellSlots.Unknown then
				if spells.Whip:IsReady() then
					local target = Orbwalker.GetTarget() or TS:GetTarget(spells.Whip.Range + Player.BoundingRadius, true)
					if target and target.Position:Distance(Player.Position) <= (spells.Whip.Range + Player.BoundingRadius) and not qActive then
						
						spells.Whip:Cast()
						return
					end
				end
			end
		end


		if Menu.Get("Combo.CastE") then
			if spells.E:IsReady() and not qActive then
				local target = Orbwalker.GetTarget() or TS:GetTarget(spells.E.Range + Player.BoundingRadius, true)
				if target and target.Position:Distance(Player.Position) <= (spells.E.Range + Player.BoundingRadius)
						and Player.Mana >= (Menu.Get("Combo.CastEMinMana") / 100) * Player.MaxMana 
						and target.HealthPercent<0.30 then
						print(target.CharName..target.HealthPercent)
					CastE(target)
					return
				end
			end
		end
		if Menu.Get("Combo.CastR") then
			if spells.R:IsReady() then
				local target = Orbwalker.GetTarget() or TS:GetTarget(spells.R.Range + Player.BoundingRadius, true)
				if target and target.Position:Distance(Player.Position) <= (spells.R.Range + Player.BoundingRadius)
						and Player.Mana >= (Menu.Get("Combo.CastRMinMana") / 100) * Player.MaxMana then
					if Menu.Get("Combo.CastRHail") then
						if hailBuffActive then
							CastR()
						end
					else
						CastR()
					end
					return
				end
			end
		end

		-- Waveclear
	elseif Orbwalker.GetMode() == "Waveclear" then

		Waveclear()

		-- Harass
	elseif Orbwalker.GetMode() == "Harass" then

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

		-- Lasthit
	elseif Orbwalker.GetMode() == "Lasthit" then
		if Menu.Get("Lasthit.CastE") then
			LasthitE()
		end

	end

end

local function OnDraw()

	-- Draw Q Range
	if Player:GetSpell(SpellSlots.R).IsLearned and Menu.Get("Drawing.DrawR") then
		Renderer.DrawCircle3D(Player.Position, 1000, 30, 1.0, Menu.Get("Drawing.DrawRColor"))
	end
	
	
	


end

local function OnDrawDamage(target, dmgList)
    if Menu.Get("Drawing.DrawDamage") then
        table.insert(dmgList, GetDamage(target))
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

	if qActive and Menu.Get("Misc.CastAAQOnlyBackstab")then
		local pPos = Player.Position
		if args.Target:IsFacing(pPos,90) then
			args.Target = nil
		end
	end
	
	local target = args.Target
	
	if target and target.IsMonster and Menu.Get("Misc.JgBackStab") then
		local pPos = Player.Position
		if args.Target:IsFacing(pPos,90) then
			args.Target = nil
		end
	end
end




function OnLoad()

	EventManager.RegisterCallback(Enums.Events.OnHighPriority, OnHighPriority)
	EventManager.RegisterCallback(Enums.Events.OnNormalPriority, OnNormalPriority)
	EventManager.RegisterCallback(Enums.Events.OnDraw, OnDraw)
	EventManager.RegisterCallback(Enums.Events.OnDrawDamage, OnDrawDamage)
	EventManager.RegisterCallback(Enums.Events.OnGapclose, OnGapclose)
	EventManager.RegisterCallback(Enums.Events.OnPreAttack, OnPreAttack)


	return true
end
