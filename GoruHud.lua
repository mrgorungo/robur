require("common.log")
module("SideHud", package.seeall, log.setup)
clean.module("SideHud", clean.seeall, log.setup)

local _Core = _G.CoreEx
local ObjManager, EventManager, Input, Enums, Game, Geometry, Renderer, Vector,
      Collision, Orbwalker, Prediction, Nav, HitChance, Profiler, TS, Menu =
    _Core.ObjectManager, _Core.EventManager, _Core.Input, _Core.Enums,
    _Core.Game, _Core.Geometry, _Core.Renderer, _Core.Geometry.Vector,
    _G.Libs.CollisionLib, _G.Libs.Orbwalker, _G.Libs.Prediction, _Core.Nav,
    _Core.Enums.HitChance, _G.Libs.Profiler, _G.Libs.TargetSelector(),
    _G.Libs.NewMenu
local itemID = require("lol\\Modules\\Common\\itemID")
local SpellSlots, SpellStates = Enums.SpellSlots, Enums.SpellStates
local Player = ObjManager.Player
local OSClock, floor, format = os.clock, math.floor, string.format
local Version = 1.0


local SideHud = {}
local Events = Enums.Events



local TextClipper = Vector(40, 20, 0)
local TextClipperLarger = Vector(100, 15,0)
local TickCount = 0

---@param arg number(float)
---@return number
local function GetHash(arg)
	return (floor(arg) % 1000)
end

-- Creadit to Thorn
---@param seconds number(float)
---@return string
local function SecondsToClock(seconds)
	local m, s = floor(seconds / 60), floor(seconds % 60)
	return m .. ":" .. (s < 10 and 0 or "") .. s
end
function SideHud.Init()
	SideHud.Heroes = {true, true, true, true, true, true, true, true, true, true}
	SideHud.champImg = {}
	SideHud.StringFormat = "%.f"
	SideHud.EnumColor = {
		NotLearned = 1,
		Ready = 2,
		OnCooldown = 3,
		AlmostReady = 4,
		NoMana = 5
	}
	SideHud.ColorList = {
		[1] = 0x666666FF, --NotLearned
		[2] = 0x00CC00FF, --Ready
		[3] = 0xE60000FF, --OnCooldown
		[4] = 0xff6A00FF, --AlmostReady
		[5] = 0x1AffffFF --NoMana
	}

	SideHud.BoxOutline = 0x333333FF
	SideHud.TextColor = 0x00FF00FF
	SideHud.TextColorBlack = 0x0d0d0dFF

	-- SideHud.SpellBackground = Vector(104, 5, 0)
	-- SideHud.SpellBoxVector = Vector(25, 5, 0)
	-- SideHud.SSBoxVector = Vector(30, 12, 0)
	SideHud.SpellBackground = Vector(111, 7, 0)
	SideHud.SpellBoxVector = Vector(24, 3, 0)
	SideHud.SSBoxVector = Vector(30, 12, 0)
	SideHud.SummonerSpellsStructure = {
		["SummonerBarrier"] = {Name = "Barrier", Path = "Summoners\\SummonerBarrier.png"},
		["SummonerBoost"] = {Name = "Cleanse", Path = "Summoners\\SummonerBoost.png"},
		["SummonerDot"] = {Name = "Ignite", Path = "Summoners\\SummonerDot.png"},
		["SummonerExhaust"] = {Name = "Exhaust", Path = "Summoners\\SummonerExhaust.png"},
		["SummonerFlash"] = {Name = "Flash", Path = "Summoners\\SummonerFlash.png"},
		["SummonerFlashPerksHextechFlashtraptionV2"] = {Name = "HexFlash", Path = "Summoners\\SummonerFlashPerksHextechFlashtraptionV2.png"},
		["SummonerHaste"] = {Name = "Ghost", Path = "Summoners\\SummonerHaste.png"},
		["SummonerHeal"] = {Name = "Heal", Path = "Summoners\\SummonerHeal.png"},
		["SummonerMana"] = {Name = "Clarity", Path = "Summoners\\SummonerMana.png"},
		["SummonerSmite"] = {Name = "Smite", Path = "Summoners\\SummonerSmite.png"},
		["S5_SummonerSmiteDuel"] = {Name = "RedSmite", Path = "Summoners\\S5_SummonerSmiteDuel.png"},
		["S5_SummonerSmitePlayerGanker"] = {Name = "BlueSmite", Path = "Summoners\\S5_SummonerSmitePlayerGanker.png"},
		["SummonerSnowball"] = {Name = "SnowBall", Path = "Summoners\\SummonerSnowball.png"},
		["SummonerTeleport"] = {Name = "Teleport", Path = "Summoners\\SummonerTeleport.png"},
		["Empty"] = {Name = "Empty", Path = "Summoners\\SummonerDarkStarChampSelect1.png"}
		--SummonerDarkStarChampSelect1.png
	}

	-- 1 is to lower side adjustment
	-- 2 is to right side adjustment
	local AdjustmentRequired = {
		["Annie"] = {1, Vector(0, 10, 0)},
		["Jhin"] = {1, Vector(0, 10, 0)},
		["Pantheon"] = {1, Vector(0, 10, 0)},
		["Irelia"] = {1, Vector(0, 10, 0)},
		["Ryze"] = {1, Vector(0, 10, 0)},
		["Zoe"] = {2, Vector(25, 0, 0)},
		["Aphelios"] = {2, Vector(52, 0, 0)},
		["Sylas"] = {2, Vector(28, 0, 0)}
	}

	SideHud.count = 1
	local champList = ObjManager.Get("enemy", "heroes")
	for k, v in pairs(champList) do
		local objHero = v.AsHero
		if (objHero and objHero.IsValid) then
			SideHud.Heroes[SideHud.count] = {true, true, true}
			local adjust = AdjustmentRequired[objHero.CharName]
			if (adjust) then
				SideHud.Heroes[SideHud.count][3] = adjust
			else
				SideHud.Heroes[SideHud.count][3] = {3, nil}
			end
			local copySpell = {
				[0] = {
					Spell = nil,
					IsLearned = false,
					PctCooldown = 0.0,
					RemainingCooldown = 0.0,
					IsEnoughMana = false
				},
				[1] = {
					Spell = nil,
					IsLearned = false,
					PctCooldown = 0.0,
					RemainingCooldown = 0.0,
					IsEnoughMana = false
				},
				[2] = {
					Spell = nil,
					IsLearned = false,
					PctCooldown = 0.0,
					RemainingCooldown = 0.0,
					IsEnoughMana = false
				},
				[3] = {
					Spell = nil,
					IsLearned = false,
					PctCooldown = 0.0,
					RemainingCooldown = 0.0,
					IsEnoughMana = false
				},
				[4] = {Spell = nil, RemainingCooldown = 0.0, Name = "Empty", SSSprite = Renderer.CreateSprite(SideHud.SummonerSpellsStructure["Empty"].Path,30,30)},
				[5] = {Spell = nil, RemainingCooldown = 0.0, Name = "Empty", SSSprite = Renderer.CreateSprite(SideHud.SummonerSpellsStructure["Empty"].Path,30,30)}
			}

			for i = SpellSlots.Q, SpellSlots.Summoner2 do
				local t_spell = objHero:GetSpell(i)
				if (t_spell) then
					copySpell[i].Spell = t_spell
					local ssName = t_spell.Name
					local ss = SideHud.SummonerSpellsStructure[ssName]
					if (ss) then
						copySpell[i].Name = ssName
						if ( i >= SpellSlots.Summoner1 ) then
							local sprite = Renderer.CreateSprite(ss.Path,30,30)
							if ( sprite ) then
								copySpell[i].SSSprite = sprite
							end
						end
					end
				end
			end
			SideHud.Heroes[SideHud.count][1] = copySpell
			SideHud.Heroes[SideHud.count][2] = objHero
			SideHud.count = SideHud.count + 1
		end
	end
	SideHud.count = SideHud.count - 1
end

function SideHud.LoadMenu()
	Menu.RegisterMenu("GoruHud", "GoruHud", function ()
    Menu.NewTree("SideHud", "SideHud", function ()
        Menu.Checkbox("SideHud.Show", "Show SideHud", true)

    end)
	end)
end

local function CDCondition(objHero)
	if (objHero.IsValid) then
		return true
	end
	return false
end

local function CDPercentToBox(cd, tcd)
	local result = floor(24 * cd / tcd)
	-- Because if the drawline is only 1 width, the line is kinda glitchy
	if (result >= 23) then
		return 22
	end
	return result
end

function SideHud.OnTick()

		local Heroes = SideHud.Heroes
		local maxHeroes = SideHud.count
		local enum = SideHud.EnumColor
		local copySpell, cd, tcd, mana, t_spell
		for h = 1, maxHeroes do
			local objHero = Heroes[h][2].AsHero
			if (CDCondition(objHero)) then
			
			

				for i = SpellSlots.Q, SpellSlots.R do
					copySpell = Heroes[h][1]
					if (copySpell[i].Spell.IsLearned) then
						copySpell[i].IsLearned = true
						cd = copySpell[i].Spell.RemainingCooldown
						tcd = copySpell[i].Spell.TotalCooldown
						copySpell[i].RemainingCooldown = cd
						copySpell[i].PctCooldown = CDPercentToBox(cd, tcd)

						if (cd > 0.0) then
							copySpell[i].Color = enum.NotLearned
							if (cd <= 10.0) then
								copySpell[i].Color2 = enum.AlmostReady
							else
								copySpell[i].Color2 = enum.OnCooldown
							end
						else
							copySpell[i].Color = enum.Ready
							mana = objHero.Mana - copySpell[i].Spell.ManaCost
							if (mana < 0) then
								copySpell[i].IsEnoughMana = false
								copySpell[i].Color = enum.NoMana
							else
								copySpell[i].IsEnoughMana = true
							end
						end
					else
						copySpell[i].IsLearned = false
						copySpell[i].Color = enum.NotLearned
					end
					Heroes[h][1] = copySpell
				end

				for i = SpellSlots.Summoner1, SpellSlots.Summoner2 do
					copySpell = Heroes[h][1]
					t_spell = objHero:GetSpell(i)
					if (t_spell) then
						copySpell[i].Spell = t_spell
						cd = t_spell.RemainingCooldown
						copySpell[i].RemainingCooldown = cd
						if ( cd > 0 ) then
							-- Darker
							copySpell[i].SSSprite:SetColor(0x848484ff)
						else
							-- Restore original color
							copySpell[i].SSSprite:SetColor(0xffffffff)
						end
						local ssName = t_spell.Name
						if( copySpell[i].Name ~= ssName ) then
							local ss = SideHud.SummonerSpellsStructure[ssName]
							if (ss) then
								copySpell[i].Name = ssName
								local sprite = Renderer.CreateSprite(ss.Path,15,15)
								if ( sprite ) then
									copySpell[i].SSSprite = sprite
								end
							end
						end
					end
					Heroes[h][1] = copySpell
				end
			end
		end
	
end



function SideHud.OnDraw()
		
		local Heroes = SideHud.Heroes
		local SpellBackground = SideHud.SpellBackground
		local spellBox = SideHud.SpellBoxVector
		local colorList = SideHud.ColorList
		local drawPos = Vector(Renderer.GetResolution().x *0.02,Renderer.GetResolution().y *0.2,0)
		if  Menu.Get("SideHud.Show") then 
		for h = 1, SideHud.count do
			local objHero = Heroes[h][2].AsHero
			local cond = CDCondition(objHero)
			if (cond) then
				
				local champSprite = Renderer.CreateSprite("Champions\\"..objHero.CharName.."_Square.png",60,60)
				
				if champSprite then
					champSprite:Draw( drawPos , nil, false)
				end
					
               
				local adjustment = Heroes[h][3]
				local originalHpPos = objHero.HealthBarScreenPos
       
				local copySpell, pos, remainCD, sprite
				-- Grey box for Q to R spells
				--Renderer.DrawFilledRect(Vector(hpPos.x - 48, hpPos.y - 3, 0), SpellBackground, 2, SideHud.BoxOutline)
				
					copySpell = Heroes[h][1]
				if copySpell[3] then 
					pos = Vector((drawPos.x +drawPos.x+ 60)/2 , drawPos.y - 15, 0)
					remainCD = copySpell[3].RemainingCooldown
					if (remainCD > 0) then
						--Renderer.DrawCircle(pos, 20, 1, colorList[SideHud.EnumColor.NotLearned],1) --not learned
						-- Got from 48656c6c636174
					
						Renderer.DrawCircle(pos, 10, 1, colorList[copySpell[3].Color2],1)
						Renderer.DrawText(
							Vector(pos.x-2 , pos.y-15 , 0),
							TextClipper,
							format(SideHud.StringFormat, remainCD),
							SideHud.TextColor
						)
					else
						Renderer.DrawCircle(pos, 10, 1, colorList[copySpell[3].Color],1) -- available
					end
				end

				local tempy = drawPos.y
				--tp exhast
				local D,F = 0,0
				for i = SpellSlots.Summoner1, SpellSlots.Summoner2 do
					copySpell = Heroes[h][1]
					--drawPos.y = drawPos.y + 16
					if (copySpell) then
						pos = Vector(drawPos.x+60, tempy, 0)
						sprite = copySpell[i].SSSprite
						if ( sprite ) then
							if copySpell[i].Name == "SummonerFlash" then
								pos = Vector(pos.x,pos.y+30,0)
								--sprite:Draw( Vector(pos.x,pos.y+30,0) , nil, false)
								F = 1
							elseif copySpell[i].Name ~= "SummonerFlash" and D ==0 then
								 --sprite:Draw( pos , nil, false)
								D = 1
							end

							if D == 1 and i == 5 and F ==0 then
								pos = Vector(pos.x,pos.y+30,0)
								--sprite:Draw( Vector(pos.x,pos.y+30,0) , nil, false)
							end
								
							
        
							
							sprite:Draw( pos , nil, false)
						end
						if (copySpell[i].RemainingCooldown > 0) then
						---@field DrawText fun(pos:Vector, size:Vector, text:string, color:integer):nil
							Renderer.DrawText(
								pos,
								TextClipper,
								format(SideHud.StringFormat, copySpell[i].RemainingCooldown),
								SideHud.TextColor
							)
						end
					end
					--tempy = tempy + 30
				end
			end
			drawPos.y = drawPos.y + 100
		end
	end
end





function OnLoad()

	SideHud.LoadMenu()
	SideHud.Init()
 

  for EventName, EventId in pairs(Events) do
    if SideHud[EventName] then
        EventManager.RegisterCallback(EventId, SideHud[EventName])
    end
  end

	return true


end
