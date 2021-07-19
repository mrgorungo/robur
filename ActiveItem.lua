

module("Active Items", package.seeall, log.setup)
clean.module("Active Items", clean.seeall, log.setup)

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

		Menu.Checkbox("Combo.CastIgnite", "Cast Ignite if Available", true)
		Menu.Checkbox("Combo.CastSmite", "Cast Smite if Available", true)
		Menu.Checkbox("Combo.CastProwler", "Cast Prowler's Claw if Available", true)
		Menu.Checkbox("Combo.CastWhip", "Cast IronsWhip if Available", true)
		Menu.Checkbox("Combo.CastEverfrost", "Cast Everfrost if Available", true)
		Menu.Checkbox("Combo.NoMove", "Block Orb move", true)
		Menu.Checkbox("Combo.NoAttack", "Block Orb attack", true)



	end)

end
Menu.RegisterMenu("Active Items","Active Items",NAShacoMenu)

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


local function GetEverfrostSlot()	
	for i=SpellSlots.Item1, SpellSlots.Item6 do
		local item = Player:GetSpell(i)
		
		if item then 
		--print(item.Name)
		if item.Name == "6656Cast"  then
			return i
		end
		end
	end
	
	return SpellSlots.Unknown
end


-- Global vars
local spells = {
	
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

	Everfrost = Spell.Skillshot({
		Slot = GetEverfrostSlot(),
		Delay = 0.5,
		Range = 900,
	}),
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




local function OnHighPriority()

	

end

local function OnNormalPriority()

	if not GameIsAvailable() then return end
	--if not Orbwalker.CanCast() then return end

	local gameTime = Game.GetTime()
	if gameTime < (lastTick + 0.25) then return end
	lastTick = gameTime


	if Menu.Get("Combo.NoMove") then Orbwalker.BlockMove(true) else Orbwalker.BlockMove(false) end
	if Menu.Get("Combo.NoAttack") then Orbwalker.BlockAttack(true) else Orbwalker.BlockAttack(false)  end



	
	-- Combo
	if Orbwalker.GetMode() == "Combo" then

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
					local target = Orbwalker.GetTarget() or TS:GetTarget(spells.Prowler.Range + Player.BoundingRadius, false)
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
					local target = Orbwalker.GetTarget() or TS:GetTarget(spells.Whip.Range + Player.BoundingRadius, false)
					if target and target.Position:Distance(Player.Position) <= (spells.Whip.Range + Player.BoundingRadius) and not qActive then
						
						spells.Whip:Cast()
						return
					end
				end
			end
		end



		

		-- Waveclear
	end



	
		if Menu.Get("Combo.CastEverfrost") then
			
			spells.Everfrost.Slot = GetEverfrostSlot()
			if spells.Everfrost.Slot ~= SpellSlots.Unknown then
				local target =  TS:GetTargets(spells.Everfrost.Range + Player.BoundingRadius , true)
				
				if target  then
						for k, targ in pairs(target) do     
							if targ ~= nil then
								local buffs = targ.Buffs
								if buffs ~= nil then
										for buffName, buff in pairs(buffs) do

											--print(buff.BuffType)
         
											if (buff.BuffType == Enums.BuffTypes.Stun
														or buff.BuffType == 12
         
														or buff.BuffType == Enums.BuffTypes.Suppression
														or buff.BuffType == Enums.BuffTypes.Knockup) then
													
														spells.Everfrost:Cast(targ.Position)
											end
										end

									
								end
							end
						end
				end
			end
		end
														 


         
         






end

local function OnDraw()

	


end

local function OnDrawDamage(target, dmgList)
 
end

local function OnGapclose(source, dash)

end

local function OnPreAttack(args)

	
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
