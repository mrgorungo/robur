-- UPDATE_AT:https://robur.site/RonaldinhoSoccer/CoolStuff/raw/branch/master/BrainExE-HUD.lua
--[[
  ___          _        _____  _____   _   _  _ _   _ ___  
 | _ )_ _ __ _(_)_ _   | __\ \/ / __| | | | || | | | |   \ 
 | _ \ '_/ _` | | ' \ _| _| >  <| _|  | | | __ | |_| | |) |
 |___/_| \__,_|_|_||_(_)___/_/\_\___| | | |_||_|\___/|___/ 
                                      |_|                  
]]
local ScriptName, Version = "BrainExE-HUD", "1.0.0"

module("BrainexeHUD", package.seeall, log.setup)
clean.module("BrainexeHUD", package.seeall, log.setup)


local SDK = _G.CoreEx
local Lib = _G.Libs
local Orb = Lib.Orbwalker
local Spell = Lib.Spell
local Obj = SDK.ObjectManager
local Game = SDK.Game
local Player = Obj.Player
local Event = SDK.EventManager
local Enums = SDK.Enums
local Renderer = SDK.Renderer
local OsClock = os.clock
local Input = SDK.Input
local Nav = SDK.Nav
local HealthPred = Lib.HealthPred
local TS = Lib.TargetSelector()
local BuffTypes = SDK.Enums.BuffTypes

local lastMoveAction = OsClock()
local lastWardPlace = OsClock()

local Menu = Lib.NewMenu
local Geometry = SDK.Geometry
local Vector = Geometry.Vector

local CollorPallet = {
    RED = 0xE60000FF,
    GREEN = 0xFF00FF,
    BLUE = 0x27FFFF,
    CYAN = 0xFFEBFF,
    GRAY = 0x5D5D5DFF,
    WHITE = 0xFFFFFFFF
}

local _Q, _W, _E, _R = 0, 1, 2, 3
local playerSpells = {Spell.Active({
    Slot = Enums.SpellSlots.Q,
    Key = "Q"
}), Spell.Active({
    Slot = Enums.SpellSlots.W,
    Key = "W"
}), Spell.Active({
    Slot = Enums.SpellSlots.E,
    Key = "E"
}), Spell.Active({
    Slot = Enums.SpellSlots.R,
    Key = "R"
})}
local recalling = {}
local heroOrderHasChanged = true
local Heroes = {}
local cloneTracker = {}
local ExpTable = {0, 280, 660, 1140, 1720, 2400, 3180, 4060, 5040, 6120, 7300, 8580, 9960, 11440, 13020, 14700, 16480,
                  18360}

local wardSpots = {{
    playerPos = Vector(13022, 51.36, 3808),
    wardPos = Vector(12442, -66, 3889)
}, -- Ward Bush Botlane
{
    playerPos = Vector(1774, 52.83, 10756),
    wardPos = Vector(2352.10, -30.45, 11018.63)
}, -- Ward Bush TopLane
{
    playerPos = Vector(11737.36, -71.24, 4667.66),
    wardPos = Vector(12216.31, 51.74, 5040.28)
} -- Ward tribrush
}

local showBlinkTraject = {}
local blinkSpells = {"ShacoQ", "LeblancW", "LeblancRW", "KassadinR"}

local lastAATimer = OsClock()

local resolution = Renderer.GetResolution()
local positionX = (resolution.x / 4) * 0.2
local positionY = (resolution.y / 5)

local AdjustmentRequired = {
    Annie = Vector(0, 10, 0),
    Jhin = Vector(0, 10, 0),
    Pantheon = Vector(0, 10, 0),
    Irelia = Vector(0, 10, 0),
    Ryze = Vector(0, 10, 0),
    Zoe = Vector(0, 0, 0),
    Aphelios = Vector(0, 10, 0),
    Sylas = Vector(0, 0, 0)
}

local UsableItems = {
    DefensiveItems = {
        Shield = {2065, 3190, 3143, 7020, 7019},
        Untargetable = {3157, 2420, 2423},
        Healing = {
            Targeted = {3222},
            Position = {3107}
        },
        AntiCC = {
            Self = {3140, 3139, 6035},
            Any = {3222}
        }
    },
    OffensiveItems = {
        Actives = {
            Id = {3142, 6029, 6630, 6631, 6664, 7015, 7003},
            Range = 425
        },
        Targeted = {
            Id = {6693, 7000},
            Range = 500
        },
        SkillShot = {
            GapCloser = {6671, 3152, 7006, 7011, 7014},
            Missile = {6656}
        }
    },
    Wards = {
        ItemIds = {2055, 2056, 2057, 2050, 3340, 3863, 3864, 3860, 3859, 3857, 3855, 3851, 3853},
        Range = 600
    },
    Potions = {
        ItemIds = {2031, 2033, 2003, 2009, 2010, 2012},
        Buffs = {"Item2003", "Item2010", "Item2009", "ItemCrystalFlask", "ItemDarkCrystalFlask"}, -- TODO: Add Cookie
        Range = 0
    }
}

local UsableSS = {
    Ignite = {
        Slot = nil,
        Range = 600
    },
    Smite = {
        Slot = nil,
        IsRed = false,
        Range = 500
    },
    Flash = {
        Slot = nil,
        Range = 400
    }
}

-- UTIL FUNCTIONS --

function HasPotRunning() -- Thanks to wxx
    for _, PotionBuff in ipairs(UsableItems.Potions.Buffs) do
        if Player:GetBuff(PotionBuff) then
            return true
        end
    end
    return false
end

function IsInAARange(Target)
    return Player:Distance(Target) <= Player.AttackRange
end

function HasItem(itemId)
    for itemSlot, item in pairs(Player.Items) do
        if item and item.ItemId == itemId and Player:GetSpellState(itemSlot) == Enums.SpellStates.Ready then
            return itemSlot, item
        end
    end

    return nil, nil
end

function GetItemSlot(Arr)
    for _, itemId in ipairs(Arr) do
        local slot, item = HasItem(itemId)
        if slot then
            slot = slot + 6
            if Player:GetSpellState(slot) == Enums.SpellStates.Ready then
                return slot
            end
        end
    end
    return nil
end

function GetActiveItem()
    local hasProwler, hasGaleForce, hasGoredrinker, hasStridebreaker = GetItemSlot(UsableItems.Prowler.ProwlerItemIds),
        GetItemSlot(UsableItems.GaleForce.GaleForceItemIds), GetItemSlot(UsableItems.Goredrinker.GoredrinkerItemIds),
        GetItemSlot(UsableItems.Stridebreaker.StridebreakerItemIds)
    return hasProwler or hasGaleForce or hasGoredrinker or hasStridebreaker
end

function GetWardItem()
    local hasItem = GetItemSlot(UsableItems.Wards.ItemIds)
    return hasItem
end

function GetPotionItem()
    local hasItem = GetItemSlot(UsableItems.Potions.ItemIds)
    return hasItem
end

function CheckSSSlots()
    local slots = {Enums.SpellSlots.Summoner1, Enums.SpellSlots.Summoner2}

    local function IsIgnite(slot)
        return Player:GetSpell(slot).Name == "SummonerDot"
    end

    local function IsFlash(slot)
        return Player:GetSpell(slot).Name == "SummonerFlash"
    end

    local function IsSmite(slot)
        return Player:GetSpell(slot).Name == "S5_SummonerSmiteDuel" or Player:GetSpell(slot).Name ==
                   "S5_SummonerSmitePlayerGanker" or Player:GetSpell(slot).Name == "SummonerSmite"
    end

    for _, slot in ipairs(slots) do
        if IsIgnite(slot) then
            if UsableSS.Ignite.Slot ~= slot then
                UsableSS.Ignite.Slot = slot
            end
        end
        if IsFlash(slot) then
            if UsableSS.Flash.Slot ~= slot then
                UsableSS.Flash.Slot = slot
            end
        end
        if IsSmite(slot) then
            if UsableSS.Smite.Slot ~= slot then
                UsableSS.Smite.Slot = slot
                UsableSS.Smite.IsRed = Player:GetSpell(slot).Name == "S5_SummonerSmiteDuel"
            end
        end
    end

    if UsableSS.Ignite.Slot ~= nil then
        UsableSS.Ignite.Slot = nil
    end
end

function NumberOrMax(number, max)
    if not number or number == nil or number > max then
        return max
    else
        return number
    end
end

function IsOnHardCC()
    local hardCC = {BuffTypes.Stun, BuffTypes.Taunt, BuffTypes.Polymorph, BuffTypes.Fear, BuffTypes.Charm,
                    BuffTypes.Suppression, BuffTypes.Knockup, BuffTypes.Disarm, BuffTypes.Asleep}

    for i, buffInst in pairs(Player.Buffs) do
        for j, buffType in pairs(hardCC) do
            if buffInst.BuffType == buffType then
                return true
            end
        end

    end
    return false
end

function IsOnAnyCC()
    local isCC = {BuffTypes.Stun, BuffTypes.Taunt, BuffTypes.Polymorph, BuffTypes.Slow, BuffTypes.Snare,
                  BuffTypes.NearSight, BuffTypes.Fear, BuffTypes.Charm, BuffTypes.Suppression, BuffTypes.Blind,
                  BuffTypes.Knockup, BuffTypes.Disarm, BuffTypes.Asleep}

    for i, buffInst in pairs(Player.Buffs) do
        for j, buffType in pairs(isCC) do
            if buffInst.BuffType == buffType or buffInst.IsFear or buffInst.IsRoot or buffInst.IsSilence or buffInst.IsDisarm then
                return true
            end
        end

    end
    return false
end

-- Base Structure --

BaseStrucutre = {}

function BaseStrucutre:new(dat)
    dat = dat or {}
    setmetatable(dat, self)
    self.__index = self
    local counter = 1
    for key, value in pairs(Obj.Get("all", "heroes")) do
        if not value.IsMe then
            local hero = value.AsHero
            if hero.CharName ~= "PracticeTool_TargetDummy" then
                Heroes[hero.IsAlly and hero.CharName or counter] =
                    {
                        HeroData = hero,
                        Spells = {hero:GetSpell(_Q), hero:GetSpell(_W), hero:GetSpell(_E), hero:GetSpell(_R)},
                        Icons = {
                            Hero = Renderer.CreateSprite("Champions\\\\" .. hero.CharName .. ".png", 42, 42),
                            Ultimate = Renderer.CreateSprite("Ultimates\\\\" .. hero.CharName .. ".png", 24, 24),
                            Summoners = {
                                SS1 = Renderer.CreateSprite("Summoners\\\\" ..
                                                                hero:GetSpell(Enums.SpellSlots.Summoner1).Name .. ".png",
                                    24, 24),
                                SS2 = Renderer.CreateSprite("Summoners\\\\" ..
                                                                hero:GetSpell(Enums.SpellSlots.Summoner2).Name .. ".png",
                                    24, 24)
                            }
                        }
                    }

           if hero:GetSpell(Enums.SpellSlots.Summoner1).Name == "SummonerFlash" then
             
              ssswap = Heroes[hero.IsAlly and hero.CharName or counter].Icons.Summoners.SS2
		  	  Heroes[hero.IsAlly and hero.CharName or counter].Icons.Summoners.SS2 = Heroes[hero.IsAlly and hero.CharName or counter].Icons.Summoners.SS1
		      Heroes[hero.IsAlly and hero.CharName or counter].Icons.Summoners.SS1 = ssswap
           
           end

                counter = counter + 1
            end
        end
    end
    return dat
end

function BaseStrucutre:GetNearWardPos()
    local mousePos = Renderer.GetMousePos()
    local nearWardPos = nil
    for _, value in pairs(wardSpots) do
        if nearWardPos == nil then
            nearWardPos = value
        elseif mousePos:Distance(value.playerPos) < mousePos:Distance(nearWardPos.playerPos) then
            nearWardPos = value
        end
    end

    return nearWardPos
end

function BaseStrucutre:IsValidTW(value)
    local isValid = true
    local tw = value.AsTurret
    if not value.IsOnScreen or value.IsDead or string.find(value.Name, "Shrine_A") or value.IsInhibitor or value.IsNexus then
        isValid = false
    end

    return isValid
end

function BaseStrucutre:SaveOnNextPos(arr, nextIndex, value)
    if arr[nextIndex] ~= nil then
        local aux = arr[nextIndex]
        arr[nextIndex] = value
        arr = self:SaveOnNextPos(arr, nextIndex + 1, aux)
    else
        arr[nextIndex] = value
    end
    return arr
end

function BaseStrucutre:ReorderTable()
    local newHeroes = {}
    for key, value in pairs(Heroes) do
        if key ~= value.HeroData.CharName then
            local heroIndex = Menu.Get("SideBar.Order." .. value.HeroData.CharName)
            if newHeroes[heroIndex] ~= nil then
                newHeroes = self:SaveOnNextPos(newHeroes, heroIndex + 1, value)
            else
                newHeroes[heroIndex] = value
            end
        else
            newHeroes[key] = value
        end
    end
    Heroes = newHeroes
end

function BaseStrucutre:CheckHeroOrder()
    for key, value in pairs(Heroes) do
        if key ~= value.HeroData.CharName then
            local heroIndex = Menu.Get("SideBar.Order." .. value.HeroData.CharName)
            if heroIndex ~= key then
                self:ReorderTable()
                heroOrderHasChanged = false
                return
            end
        end
    end
end

function BaseStrucutre:GetExpPercent(Object)
    if Object.Level == 18 then
        return 100
    end
    local nextLevelExp = ExpTable[Object.Level + 1]

    return math.floor((Object.Experience * 100) / nextLevelExp)
end

function BaseStrucutre:DrawCoolDownTracker(HeroData, Spells, args)
    local healthBarPos = HeroData.HealthBarScreenPos
    local expBox = Vector(self:GetExpPercent(HeroData), 5, 0)
    local skillBox = Vector(25, 5, 0)
    if Menu.Get("CoolDownTracker.EXP") then
        Renderer.DrawRectOutline(Vector(healthBarPos.x - 45, healthBarPos.y - 30, 0), args.expBoxSize, 2, 2,
            CollorPallet.WHITE)
        Renderer.DrawFilledRect(Vector(healthBarPos.x - 45, healthBarPos.y - 30, 0), expBox, 5, CollorPallet.CYAN)
    end
    if Menu.Get("CoolDownTracker.Spells") then
        local skillXSum = 0
        for spellSlot, spell in pairs(Spells) do
            local vectorAdjust = AdjustmentRequired[HeroData.CharName]
            local offsetX, offsetY = 0, 0
            if vectorAdjust ~= nil then
                offsetX = vectorAdjust.x
                offsetY = vectorAdjust.y
            end
            Renderer.DrawRectOutline(Vector(healthBarPos.x - 45 + skillXSum + offsetX, healthBarPos.y + offsetY, 0),
                args.skillBoxSize, 2, 2, CollorPallet.WHITE)
            if spell.IsLearned and spell.RemainingCooldown == 0 then
                Renderer.DrawFilledRect(Vector(healthBarPos.x - 45 + skillXSum + offsetX, healthBarPos.y + offsetY, 0),
                    skillBox, 5, CollorPallet.GREEN)
            else
                Renderer.DrawFilledRect(Vector(healthBarPos.x - 45 + skillXSum + offsetX, healthBarPos.y + offsetY, 0),
                    skillBox, 5, CollorPallet.RED)
                if spell.IsLearned and spell.RemainingCooldown > 0 then
                    Renderer.DrawText(
                        Vector(healthBarPos.x - 40 + skillXSum + offsetX, healthBarPos.y + 5 + offsetY, 0),
                        Vector(50, 50), math.floor(spell.RemainingCooldown), CollorPallet.WHITE)
                end
            end
            skillXSum = skillXSum + 25
        end
    end
end

function BaseStrucutre:DrawSideBarHud(value, args)
    if value.HeroData.IsAlly then
        return
    end

    local drawCharHud = Menu.Get("SideBar." .. value.HeroData.CharName)
    if drawCharHud == nil or drawCharHud then
        return
    end

    -- Hero Icon
    if value.HeroData.IsDead then
        value.Icons.Hero:SetColor(CollorPallet.GRAY)
        value.Icons.Hero:Draw(Vector(positionX + 20, positionY + 15 + args.ySum, 0))
        Renderer.DrawText(Vector(positionX + 34, positionY + 26 + args.ySum), Vector(100, 100),
            math.floor(value.HeroData.TimeUntilRespawn), CollorPallet.WHITE)
    else
        local heathBox = Vector(value.HeroData.HealthPercent * 100, 10, 0)
        local manaBox = Vector(value.HeroData.ManaPercent * 100, 10, 0)
        local expBox = Vector(self:GetExpPercent(value.HeroData), 5, 0)

        -- SIDE HUD
        -- EXP
        if Menu.Get("SideBar.EXP") then
            Renderer.DrawRectOutline(Vector(positionX - 40 + args.xSum, positionY - 17 + args.ySum, 0), args.expBoxSize,
                2, 2, CollorPallet.WHITE)
            Renderer.DrawFilledRect(Vector(positionX - 40 + args.xSum, positionY - 17 + args.ySum, 0), expBox, 5,
                CollorPallet.CYAN)
        end

        -- RecallTrack
        -- print(Player.RecallInfo)
        if Menu.Get("SideBar.Recall") and value.HeroData.IsRecalling then
            local currentRecall = recalling[value.HeroData.CharName]
            if currentRecall == nil or currentRecall.recallEnd then
                recalling[value.HeroData.CharName] = {
                    endTime = value.HeroData.RecallInfo == "recall" and OsClock() + 8 or OsClock() + 4
                }
                currentRecall = recalling[value.HeroData.CharName]
            end
            local eta = currentRecall.endTime - OsClock()
            local recallBox = Vector((args.boxSize.x * (1 / 8) * eta), 10, 0)
            Renderer.DrawRectOutline(Vector(positionX - 145 + args.xSum, positionY - 10 + args.ySum, 0), args.boxSize,
                2, 2, CollorPallet.WHITE)
            Renderer.DrawFilledRect(Vector(positionX - 145 + args.xSum, positionY - 10 + args.ySum, 0), recallBox, 5,
                CollorPallet.BLUE)
            Renderer.DrawText(Vector(positionX - 100 + args.xSum, positionY - 14 + args.ySum), Vector(100, 100),
                math.ceil(eta), CollorPallet.WHITE)
            Renderer.DrawText(Vector(positionX - 125 + args.xSum, positionY - 25 + args.ySum), Vector(100, 100),
                "Recalling", CollorPallet.WHITE)
        elseif not value.HeroData.IsRecalling then
            if recalling[value.HeroData.CharName] ~= nil then
                recalling[value.HeroData.CharName] = {
                    endTime = nil,
                    recallEnd = true
                }
            end
        end

        -- Health
        if Menu.Get("SideBar.Health") then
            Renderer.DrawRectOutline(Vector(positionX - 40 + args.xSum, positionY - 10 + args.ySum, 0), args.boxSize, 2,
                2, CollorPallet.WHITE)
            Renderer.DrawFilledRect(Vector(positionX - 40 + args.xSum, positionY - 10 + args.ySum, 0), heathBox, 5,
                CollorPallet.GREEN)
        end
        -- Mana
        if Menu.Get("SideBar.Mana") then
            Renderer.DrawRectOutline(Vector(positionX - 40 + args.xSum, positionY + args.ySum, 0), args.boxSize, 2, 2,
                CollorPallet.WHITE)
            Renderer.DrawFilledRect(Vector(positionX - 40 + args.xSum, positionY + args.ySum, 0), manaBox, 5,
                CollorPallet.BLUE)
        end

        -- Hero Icon
        value.Icons.Hero:SetColor(CollorPallet.WHITE)
        value.Icons.Hero:Draw(Vector(positionX + 20, positionY + 15 + args.ySum, 0))
        -- END OF SIDE HUD
    end
    -- SS Icons
    if Menu.Get("SideBar.SS") then
        local ss1 = value.HeroData:GetSpell(Enums.SpellSlots.Summoner1)
        local ss2 = value.HeroData:GetSpell(Enums.SpellSlots.Summoner2)
 if ss1.Name == "SummonerFlash" then
        
          
		 
		   ssswap = ss2
		   ss2 = ss1
		   ss1 = ssswap
		   

		   

		  
		   

		end


        if ss1.RemainingCooldown == 0 then
            value.Icons.Summoners.SS1:SetColor(CollorPallet.WHITE)
            value.Icons.Summoners.SS1:Draw(Vector(positionX - 34, positionY + 15 + args.ySum, 0))
        else
            value.Icons.Summoners.SS1:SetColor(CollorPallet.GRAY)
            value.Icons.Summoners.SS1:Draw(Vector(positionX - 34, positionY + 15 + args.ySum, 0))
            Renderer.DrawText(Vector(positionX - 35, positionY + 18 + args.ySum), Vector(50, 50),
                math.floor(ss1.RemainingCooldown), CollorPallet.WHITE)
        end
        if ss2.RemainingCooldown == 0 then
            value.Icons.Summoners.SS2:SetColor(CollorPallet.WHITE)
            value.Icons.Summoners.SS2:Draw(Vector(positionX - 10, positionY + 15 + args.ySum, 0))
        else
            value.Icons.Summoners.SS2:SetColor(CollorPallet.GRAY)
            value.Icons.Summoners.SS2:Draw(Vector(positionX - 10, positionY + 15 + args.ySum, 0))
            Renderer.DrawText(Vector(positionX - 6, positionY + 18 + args.ySum), Vector(50, 50),
                math.floor(ss2.RemainingCooldown), CollorPallet.WHITE)
        end
    end
    -- Ultimate Icon
    if Menu.Get("SideBar.Ultimate") then
        local spell = value.HeroData:GetSpell(_R)
        if spell.RemainingCooldown == 0 and spell.IsLearned then
            value.Icons.Ultimate:SetColor(CollorPallet.WHITE)
            value.Icons.Ultimate:Draw(Vector(positionX - 70, positionY + 5 + args.ySum, 0))
        else
            value.Icons.Ultimate:SetColor(CollorPallet.GRAY)
            value.Icons.Ultimate:Draw(Vector(positionX - 70, positionY + 5 + args.ySum, 0))
            if spell.IsLearned then
                Renderer.DrawText(Vector(positionX - 71, positionY + 8 + args.ySum), Vector(50, 50),
                    math.floor(spell.RemainingCooldown), CollorPallet.WHITE)
            end
        end
    end
    if not value.HeroData.IsVisible and Menu.Get("SideBar.MIA") then
        Renderer.DrawText(Vector(positionX - 50, positionY + 40 + args.ySum), Vector(100, 100), "ENEMY MIA",
            CollorPallet.RED)
    end
end

function BaseStrucutre:CastActiveAntiCCItem()
    local reactionDelay = Menu.Get("Activator.Items.Defensive.AntiCC.Delay")
    local activeItemSelf = GetItemSlot(UsableItems.DefensiveItems.AntiCC.Self)
    local activeItemAny = GetItemSlot(UsableItems.DefensiveItems.AntiCC.Any)
    if activeItemSelf then
        delay(reactionDelay, Input.Cast, activeItemSelf)
        return true
    elseif activeItemAny then
        delay(reactionDelay, Input.Cast, activeItemSelf, Player)
        return true
    end
end

function BaseStrucutre:CastHealingItem(Target)
    local activeItemTarget = GetItemSlot(UsableItems.DefensiveItems.Healing.Targeted)
    local activeItemPosition = GetItemSlot(UsableItems.DefensiveItems.Healing.Position)
    if activeItemTarget then
        Input.Cast(activeItemTarget, Target)
        return true
    elseif activeItemPosition then
        Input.Cast(activeItemPosition, Target.Position)
        return true
    end
end

function BaseStrucutre:CastActiveItem(SlotArr)
    local activeItem = GetItemSlot(SlotArr)
    if activeItem ~= nil then
        Input.Cast(activeItem)
        return true
    end
end

function BaseStrucutre:CastTargetedItem(Target)
    local targetedItem = GetItemSlot(UsableItems.OffensiveItems.Targeted.Id)
    if targetedItem then
        Input.Cast(targetedItem, Target)
        return true
    end
end

function BaseStrucutre:CastSkillShot(Target)
    local slot = GetItemSlot(UsableItems.OffensiveItems.SkillShot.GapCloser)
    if slot and Player:Distance(Target) <= 425 then
        Input.Cast(slot, Player.Position:Extended(Target:FastPrediction(0.15), 200))
        return true
    elseif Player:Distance(Target) <= 800 then
        slot = GetItemSlot(UsableItems.OffensiveItems.SkillShot.Missile)
        if slot then
            Input.Cast(slot, Player.Position:Extended(Target:FastPrediction(0.3), 800))
            return true
        end
    end
end

function BaseStrucutre:HasSpellsReady()
    for i, spell in ipairs(playerSpells) do
        if spell:IsReady() then
            return true
        end
    end
end

function BaseStrucutre:CountHeroes(pos, range, team)
    local num = 0
    for k, v in pairs(Obj.Get(team, "heroes")) do
        local hero = v.AsHero
        if hero.IsValid and not hero.IsDead and hero.IsTargetable and hero:Distance(pos) < range then
            num = num + 1
        end
    end
    return num
end

function BaseStrucutre:OnDraw()
    local TWRangeAlly, TWRangeEnemy = Menu.Get("RangeTracker.Ally"), Menu.Get("RangeTracker.Enemy")
    if heroOrderHasChanged then
        self:CheckHeroOrder()
    end
    local args = {
        ySum = 0,
        xSum = 0,
        boxSize = Vector(100, 10, 0),
        expBoxSize = Vector(100, 5, 0),
        skillBoxSize = Vector(25, 5, 0)
    }
    for _, value in pairs(Heroes) do
        if value.HeroData.IsEnemy then
            -- END OF CHAMPION HUD
            if Menu.Get("SideBar.Show") then
                self:DrawSideBarHud(value, args)
            end
            args.ySum = args.ySum + 80
        end
        -- Champion HUD
        if Menu.Get("CoolDownTracker.Show") and not value.HeroData.IsDead and value.HeroData.IsVisible and
            Renderer.IsOnScreen(value.HeroData.Position) then
            self:DrawCoolDownTracker(value.HeroData, value.Spells, args)
        end
    end

    if TWRangeAlly then
        for _, value in pairs(Obj.Get("ally", "turrets")) do
            if self:IsValidTW(value) then
                Renderer.DrawCircle3D(value.Position, 875, 30, 4, CollorPallet.BLUE)
            end
        end
    end
    if TWRangeEnemy then
        for _, value in pairs(Obj.Get("enemy", "turrets")) do
            if self:IsValidTW(value) then
                Renderer.DrawCircle3D(value.Position, 875, 30, 4, CollorPallet.RED)
            end
        end
    end

    if Menu.Get("AutoWard.ShowWardSpots") then
        for _, value in pairs(wardSpots) do
            if value.playerPos and value.playerPos.IsOnScreen then
                Renderer.DrawCircle3D(value.playerPos, 30, 30, 4, CollorPallet.BLUE)
            end
            if value.wardPos and value.wardPos.IsOnScreen then
                Renderer.DrawCircle3D(value.wardPos, 30, 30, 4, CollorPallet.GREEN)
            end
            if value.wardPos and value.wardPos.IsOnScreen and value.playerPos and value.playerPos.IsOnScreen then
                Renderer.DrawLine3D(value.wardPos, value.playerPos, 2, CollorPallet.RED)
            end
        end
    end

    if Menu.Get("AntiJuke.ShowFlash") or Menu.Get("AntiJuke.ShowChampionBlink") then
        for _, item in pairs(showBlinkTraject) do
            if item.timer - OsClock() > 0 and item then
                if item.startPos and item.startPos.IsOnScreen then
                    Renderer.DrawCircle3D(item.startPos, 30, 30, 4, CollorPallet.GREEN)
                end
                if item.endPos and item.endPos.IsOnScreen then
                    Renderer.DrawCircle3D(item.endPos, 30, 30, 4, CollorPallet.RED)
                end
                if item.startPos and item.startPos.IsOnScreen and item.endPos and item.endPos.IsOnScreen then
                    Renderer.DrawLine3D(item.startPos, item.endPos, 2, CollorPallet.WHITE)
                end
            else
                table.remove(showBlinkTraject, _)
            end
        end
    end

    if Menu.Get("CloneTracker.ShowWhoIsClone") then
        for k, obj in pairs(cloneTracker) do
            if obj.IsValid then
                local healthBarPos = obj.HealthBarScreenPos
                Renderer.DrawText(
                        Vector(healthBarPos.x - 15, healthBarPos.y -75, 0),
                        Vector(50, 50), "CLONE", CollorPallet.WHITE)
                Renderer.DrawCircle3D(obj.Position, 50, 30, 4, CollorPallet.RED)
            else
                table.remove(cloneTracker, k)
                return
            end
        end
    end
end

function BaseStrucutre:OnLowPriority()
    local Target = Orb.GetTarget()
    local OrbMode = Orb.GetMode()
    if Menu.Get("AutoWard.PlaceWard") and OsClock() - lastMoveAction > 1 then
        local hasWard = GetWardItem()
        if hasWard then
            local nearWardPos = self:GetNearWardPos()
            if Player:Distance(nearWardPos.playerPos) < 50 then
                if hasWard ~= nil and Player:GetSpellState(hasWard) == Enums.SpellStates.Ready and OsClock() -
                    lastWardPlace > 3 then
                    Input.Cast(hasWard, nearWardPos.wardPos)
                    lastWardPlace = OsClock()
                    return
                end
            else
                Input.MoveTo(nearWardPos.playerPos)
                lastMoveAction = OsClock()
                return
            end
        end
    end
    if Menu.Get("Activator.AutoPot") and not HasPotRunning() and not Player.IsInBase then
        local potionSlot = GetPotionItem()
        if potionSlot and Player.HealthPercent <= Menu.Get("Activator.AutoPotMinHP") / 100 then
            Input.Cast(potionSlot)
            return
        end
    end

    if Target ~= nil and OrbMode == "Combo" and not Player.IsDead then
        if Menu.Get("Activator.Items.Offensive.Active") then
            local activeStyle = Menu.Get("Activator.Items.Offensive.Active.Style")
            if activeStyle == 0 and OsClock() - lastAATimer >= 0.25 and IsInAARange(Target) and
                self:CastActiveItem(UsableItems.OffensiveItems.Actives.Id) then -- After attack
                return
            elseif activeStyle == 1 and not self:HasSpellsReady() and IsInAARange(Target) and
                self:CastActiveItem(UsableItems.OffensiveItems.Actives.Id) then
                return
            elseif activeStyle == 2 and not IsInAARange(Target) and
                self:CastActiveItem(UsableItems.OffensiveItems.Actives.Id) then
                return
            elseif activeStyle == 3 and IsInAARange(Target) and
                self:CastActiveItem(UsableItems.OffensiveItems.Actives.Id) then
                return
            end
        end
        if Menu.Get("Activator.Items.Offensive.Targeted") then
            local targetedStyle = Menu.Get("Activator.Items.Offensive.Targeted.Style")
            if targetedStyle == 0 and OsClock() - lastAATimer >= 0.25 and IsInAARange(Target) and
                self:CastTargetedItem(Target) then -- After attack
                return
            elseif targetedStyle == 1 and not self:HasSpellsReady() and IsInAARange(Target) and
                self:CastTargetedItem(Target) then
                return
            elseif targetedStyle == 2 and not IsInAARange(Target) and Player:Distance(Target) <
                UsableItems.OffensiveItems.Targeted.Range and self:CastTargetedItem(Target) then
                return
            elseif targetedStyle == 3 and IsInAARange(Target) and self:CastTargetedItem(Target) then
                return
            end
        end
        if Menu.Get("Activator.Items.Offensive.Skillshot") then
            local targetedStyle = Menu.Get("Activator.Items.Offensive.Skillshot.Style")
            if targetedStyle == 0 and OsClock() - lastAATimer >= 0.25 and IsInAARange(Target) and
                self:CastSkillShot(Target) then -- After attack
                return
            elseif targetedStyle == 1 and not self:HasSpellsReady() and IsInAARange(Target) and
                self:CastSkillShot(Target) then
                return
            elseif targetedStyle == 2 and not IsInAARange(Target) and self:CastSkillShot(Target) then
                return
            elseif targetedStyle == 3 and IsInAARange(Target) and self:CastSkillShot(Target) then
                return
            end
        end
        if Menu.Get("Activator.Items.Defensive.Shield") then
            local styleUsage = Menu.Get("Activator.Items.Defensive.Shield.Style")
            if styleUsage == 0 and self:CountHeroes(Player.Position, 600, "enemy") > 2 and
                self:CastActiveItem(UsableItems.DefensiveItems.Shield) then
                return
            elseif styleUsage == 1 and Player.HealthPercent < 0.5 and
                self:CastActiveItem(UsableItems.DefensiveItems.Shield) then
                return
            elseif styleUsage == 2 and Player.HealthPercent < Target.HealthPercent and
                self:CastActiveItem(UsableItems.DefensiveItems.Shield) then
                return
            elseif styleUsage == 3 and self:CastActiveItem(UsableItems.DefensiveItems.Shield) then
                return
            end
        end
        if Menu.Get("Activator.Items.Defensive.Healing") then
            local styleUsage = Menu.Get("Activator.Items.Defensive.Healing.Style")
            if styleUsage == 0 and self:CountHeroes(Player.Position, 600, "enemy") > 2 and self:CastHealingItem(Player) then
                return
            elseif styleUsage == 1 and Player.HealthPercent < 0.5 and self:CastHealingItem(Player) then
                return
            elseif styleUsage == 2 and Player.HealthPercent < Target.HealthPercent and self:CastHealingItem(Player) then
                return
            elseif styleUsage == 3 and self:CastHealingItem(Player) then
                return
            end
        end
        if Menu.Get("Activator.Items.Defensive.AntiCC") then
            local styleUsage = Menu.Get("Activator.Items.Defensive.AntiCC.Style")
            if styleUsage == 0 and IsOnHardCC() and self:CastActiveAntiCCItem() then
                return
            elseif styleUsage == 1 and IsOnAnyCC() and self:CastActiveAntiCCItem() then
                return
            end
        end
        if Menu.Get("Activator.Items.Defensive.Untargetable") then
            local styleUsage = Menu.Get("Activator.Items.Defensive.Untargetable.Style")
            local minHpPercent = Menu.Get("Activator.Items.Defensive.Untargetable.Percent")
            if styleUsage == 0 and math.floor((HealthPred.GetHealthPrediction(Player, 1) * 100) / Player.MaxHealth) <
                minHpPercent then
                self:CastActiveItem(UsableItems.DefensiveItems.Untargetable)
                return
            elseif styleUsage == 1 and math.floor((HealthPred.GetHealthPrediction(Player, 2) * 100) / Player.MaxHealth) <
                minHpPercent then
                self:CastActiveItem(UsableItems.DefensiveItems.Untargetable)
                return
            elseif styleUsage == 2 and math.floor((HealthPred.GetHealthPrediction(Player, 3) * 100) / Player.MaxHealth) <
                minHpPercent then
                self:CastActiveItem(UsableItems.DefensiveItems.Untargetable)
                return
            elseif styleUsage == 3 and math.floor((HealthPred.GetHealthPrediction(Player, 4) * 100) / Player.MaxHealth) <
                minHpPercent then
                self:CastActiveItem(UsableItems.DefensiveItems.Untargetable)
                return
            end
        end
    end
end

function BaseStrucutre:OnCastSpell(Args)
    local checkFlash, maxRange = Menu.Get("PerfectFlash.CheckHeadButt"), Menu.Get("PerfectFlash.MaxRange")
    if (maxRange or checkFlash) and Player:GetSpell(Args.Slot).Name == "SummonerFlash" then
        local distaceTargeted = Player.Position:Distance(Args.TargetEndPosition)
        local finalPos = Args.TargetEndPosition
        local realDestination = nil
        local isMaxRange = distaceTargeted >= 400 and distaceTargeted <= 425
        if maxRange and not isMaxRange then
            finalPos = Player.Position:Extended(Args.TargetEndPosition, 425)
            Args.Process = false
            Input.Cast(Args.Slot, finalPos)
        end
        if not isMaxRange and distaceTargeted > 425 or (distaceTargeted < 425 and maxRange) then
            finalPos = Player.Position:Extended(Args.TargetEndPosition, 425)
            isMaxRange = true
        end
        if isMaxRange and Nav.IsWall(finalPos) then
            if not Nav.IsWall(Player.Position:Extended(finalPos, 125)) or
                Nav.IsWall(Player.Position:Extended(finalPos, 775)) then
                Args.Process = false
            end
        elseif not isMaxRange and Nav.IsWall(finalPos) then
            finalPos = Player.Position:Extended(Args.TargetEndPosition, 425 - distaceTargeted)
            if Nav.IsWall(finalPos) then
                Input.Cast(Args.Slot, finalPos)
            else
                Args.Process = false
            end
        end
    end
end

function BaseStrucutre:OnProcessSpell(obj, spellCast)
    local ShowFlash, ShowChampionBlink = Menu.Get("AntiJuke.ShowFlash"), Menu.Get("AntiJuke.ShowChampionBlink")
    if obj.IsEnemy then
        if "SummonerFlash" == spellCast.Name and ShowFlash then
            table.insert(showBlinkTraject, {
                timer = OsClock() + 5,
                startPos = spellCast.StartPos,
                endPos = spellCast.EndPos
            })
            return
        end
        for i, value in ipairs(blinkSpells) do
            if ShowChampionBlink and spellCast.Name == value then
                table.insert(showBlinkTraject, {
                    timer = OsClock() + 5,
                    startPos = spellCast.StartPos,
                    endPos = spellCast.EndPos
                })
                return
            end
        end
    end
end

function BaseStrucutre:OnVisionLost(obj)
    local orbMode = Orb.GetMode()
    if orbMode == "Combo" then
        if Menu.Get("AutoWard.LostVision") then
            local hasWard = GetWardItem()
            if hasWard ~= nil and Player:GetSpellState(hasWard) == Enums.SpellStates.Ready and obj.Position:IsGrass() then
                Input.Cast(hasWard, obj.Position)
            end
        end
    elseif orbMode == "Harass" then
        if Menu.Get("AutoWard.LostVision") then
            local hasWard = GetWardItem()
            if hasWard ~= nil and Player:GetSpellState(hasWard) == Enums.SpellStates.Ready and obj.Position:IsGrass() then
                Input.Cast(hasWard, obj.Position)
            end
        end
    end
end

function BaseStrucutre:OnCreateObject(obj)
    if obj.IsAI then
		local aiObject = obj.AsAI
		if (aiObject ~= nil and aiObject.IsValid) then
            for k, v in pairs(Obj.Get("enemy", "heroes")) do
                local hero = v.AsHero
                if hero.IsValid and not hero.IsDead and hero.CharName == aiObject.CharName then
                    table.insert(cloneTracker, aiObject)
                end
            end
		end
	end
end

function BaseStrucutre:Menu()
    Menu.RegisterMenu(ScriptName, ScriptName, function()
        Menu.NewTree("Activator", "Activator Options", function()
            Menu.Separator()
            Menu.Checkbox("Activator.AutoPot", "Auto Use Potions", true)
            Menu.Slider("Activator.AutoPotMinHP", "Min % Health for use pot", 40, 0, 100, 5)
            Menu.Separator()
            Menu.NewTree("Activator.Items.Offensive", "Offensive Items", function()
                Menu.Checkbox("Activator.Items.Offensive.Active", "Use Active Items", false)
                Menu.Dropdown("Activator.Items.Offensive.Active.Style", "Use Active Item When", 0,
                    {"After Auto", "No Spells Available", "Not In AA Range", "Always"})
                Menu.Checkbox("Activator.Items.Offensive.Targeted", "Use Targeted Items", false)
                Menu.Dropdown("Activator.Items.Offensive.Targeted.Style", "Use Targeted Item When", 2,
                    {"After Auto", "No Spells Available", "Not In AA Range", "Always"})
                Menu.Checkbox("Activator.Items.Offensive.Skillshot", "Use Skillshot Items", false)
                Menu.Dropdown("Activator.Items.Offensive.Skillshot.Style", "Use Skillshot Item When", 1,
                    {"After Auto", "No Spells Available", "Not In AA Range", "Always"})
            end)
            Menu.Separator()
            Menu.NewTree("Activator.Items.Defensive", "Defensive Items", function()
                Menu.Checkbox("Activator.Items.Defensive.Shield", "Use Shield Items", false)
                Menu.Dropdown("Activator.Items.Defensive.Shield.Style", "Use Shield Item When", 0,
                    {"> 2 Enemies In Range", "Health Below 50%", "Health Lower Than Enemy", "Always"})
                Menu.Checkbox("Activator.Items.Defensive.Untargetable", "Use Zhonya Items", false)
                Menu.Slider("Activator.Items.Defensive.Untargetable.Percent", "Min % Health for use Zhonya", 30, 0, 100,
                    5)
                Menu.Dropdown("Activator.Items.Defensive.Untargetable.Style", "Use Zhonya Item when", 1,
                    {"Life % in 1s", "Life % in 2s", "Life % in 3s", "Life % in 4s"})
                Menu.Checkbox("Activator.Items.Defensive.Healing", "Use Healing Items", false)
                Menu.Dropdown("Activator.Items.Defensive.Healing.Style", "Use Healing Item When", 0,
                    {"> 2 Enemies In Range", "Health Below 50%", "Health Lower Than Enemy", "Always"})
                Menu.Checkbox("Activator.Items.Defensive.AntiCC", "Use AntiCC Items", false)
                Menu.Slider("Activator.Items.Defensive.AntiCC.Delay", "Reaction Delay for AntiCC", 250, 0, 1000, 50)
                Menu.Dropdown("Activator.Items.Defensive.AntiCC.Style", "Use AntiCC Item When", 0,
                    {"On Hard CC", "Any CC"})
            end)
        end)
        Menu.NewTree("SideBar", "Sidebar Controls", function()
            Menu.Checkbox("SideBar.Show", "Show Sidebar", true)
            Menu.Checkbox("SideBar.SS", "Show Summoners", true)
            Menu.Checkbox("SideBar.Ultimate", "Show Ultimate", true)
            Menu.Checkbox("SideBar.EXP", "Show EXP", true)
            Menu.Checkbox("SideBar.Recall", "Show Recall", true)
            Menu.Checkbox("SideBar.Health", "Show Health", true)
            Menu.Checkbox("SideBar.Mana", "Show Mana", true)
            Menu.Checkbox("SideBar.MIA", "Show MIA", true)
            Menu.NewTree("SideBar.Disabled", "Whitelist", function()
                for charName, value in pairs(Obj.Get("enemy", "heroes")) do
                    local heroData = value.AsHero
                    Menu.Checkbox("SideBar." .. heroData.CharName, "Disable for " .. heroData.CharName, false)
                end
            end)
            Menu.NewTree("SideBar.Ordered", "Champion Order", function()
                local counter = 1
                for charName, value in pairs(Obj.Get("enemy", "heroes")) do
                    local heroData = value.AsHero
                    Menu.ColoredText("AFTER SELECT THE ORDER PRESS F5", 0xB65A94FF, true)
                    Menu.Slider("SideBar.Order." .. heroData.CharName,
                        "Order 1 is top 5 is bottom " .. heroData.CharName, counter, 1, 5, 1)
                    counter = counter + 1
                end
            end)
        end)
        Menu.NewTree("CoolDownTracker", "CoolDown Tracker Controls", function()
            Menu.Checkbox("CoolDownTracker.Show", "Show CoolDown Tracker", true)
            Menu.Checkbox("CoolDownTracker.Spells", "Show Spells", true)
            Menu.Checkbox("CoolDownTracker.EXP", "Show EXP", true)
            Menu.NewTree("CoolDownTracker.Disabled", "Whitelist", function()
                for charName, value in pairs(Obj.Get("all", "heroes")) do
                    local heroData = value.AsHero
                    if not heroData.IsMe then
                        Menu.Checkbox("CoolDownTracker." .. heroData.CharName, "Disable for " .. heroData.CharName,
                            false)
                    end
                end
            end)
        end)
        Menu.NewTree("AutoWard", "Ward Controls", function()
            Menu.Checkbox("AutoWard.LostVision", "Auto Ward Bushed enemies", true)
            Menu.Checkbox("AutoWard.ShowWardSpots", "Show Ward Spots", true)
            Menu.Keybind("AutoWard.PlaceWard", "Place Ward on Spot", string.byte('J'))
        end)
        Menu.NewTree("AntiJuke", "Juke Tracker", function()
            Menu.Checkbox("AntiJuke.ShowFlash", "Show Flash Direction", true)
            Menu.Checkbox("AntiJuke.ShowChampionBlink", "Show Champion Blink Direction", true)
        end)
        Menu.NewTree("CloneTracker", "Clone Tracker", function()
            Menu.Checkbox("CloneTracker.ShowWhoIsClone", "Show the clone", true)
        end)
        Menu.NewTree("PerfectFlash", "Flash Wall", function()
            Menu.Checkbox("PerfectFlash.CheckHeadButt", "Block Flash If Not Jump Wall", false)
            Menu.Checkbox("PerfectFlash.MaxRange", "Always Flash Max Range", false)
        end)
        Menu.NewTree("RangeTracker", "Tower Range Tracker", function()
            Menu.Checkbox("RangeTracker.Ally", "Show Ally Tower Range", false)
            Menu.Checkbox("RangeTracker.Enemy", "Show Enemy Tower Range", false)
        end)
    end)
end

BrainexeHUD = BaseStrucutre:new()

BrainexeHUD:Menu()

-- Events --

local OnDraw = function()
    BrainexeHUD:OnDraw()
end

local OnTick = function()
    BrainexeHUD:OnTick()
end

local OnLowPriority = function()
    BrainexeHUD:OnLowPriority()
end

local OnPostAttack = function()
    lastAATimer = OsClock()
end

local OnCastSpell = function(Args)
    BrainexeHUD:OnCastSpell(Args)
end

local OnProcessSpell = function(obj, spellcast)
    BrainexeHUD:OnProcessSpell(obj, spellcast)
end

local OnVisionLost = function(obj)
    BrainexeHUD:OnVisionLost(obj)
end

local OnCreateObject = function(obj)
    BrainexeHUD:OnCreateObject(obj)
end

function OnLoad()
    Event.RegisterCallback(Enums.Events.OnDraw, OnDraw)
    Event.RegisterCallback(Enums.Events.OnLowPriority, OnLowPriority)
    Event.RegisterCallback(Enums.Events.OnCastSpell, OnCastSpell)
    Event.RegisterCallback(Enums.Events.OnProcessSpell, OnProcessSpell)
    Event.RegisterCallback(Enums.Events.OnVisionLost, OnVisionLost)
    Event.RegisterCallback(Enums.Events.OnPostAttack, OnPostAttack)
    Event.RegisterCallback(Enums.Events.OnCreateObject, OnCreateObject)

    return true
end
