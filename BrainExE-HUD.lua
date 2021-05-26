--UPDATE_AT:https://robur.site/MrArticuno/CoolStuff/raw/branch/master/BrainExE-HUD.lua
--[[
  ___          _        _____  _____   _   _  _ _   _ ___  
 | _ )_ _ __ _(_)_ _   | __\ \/ / __| | | | || | | | |   \ 
 | _ \ '_/ _` | | ' \ _| _| >  <| _|  | | | __ | |_| | |) |
 |___/_| \__,_|_|_||_(_)___/_/\_\___| | | |_||_|\___/|___/ 
                                      |_|                  
]]
module("BrainexeHUD", package.seeall, log.setup)
clean.module("BrainexeHUD", package.seeall, log.setup)

local ScriptName, Version = "BrainexeHUD", "0.5"

local SDK = _G.CoreEx
local Lib = _G.Libs
local Obj = SDK.ObjectManager
local Event = SDK.EventManager
local Enums = SDK.Enums
local Renderer = SDK.Renderer

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

local lastHeroOrder = {}
local heroOrderHasChanged = true
local Heroes = {}
local ExpTable = {0, 280, 660, 1140, 1720, 2400, 3180, 4060, 5040, 6120, 7300, 8580, 9960, 11440, 13020, 14700, 16480,
                  18360}
local resolution = Renderer.GetResolution()
local positionX = (resolution.x / 4) * 0.15
local positionY = (resolution.y / 5)
local AdjustmentRequired = {
    Annie = Vector(0, 10, 0),
    Jhin = Vector(0, 10, 0),
    Pantheon = Vector(0, 10, 0),
    Irelia = Vector(0, 10, 0),
    Ryze = Vector(0, 10, 0),
    Zoe = Vector(25, 0, 0),
    Aphelios = Vector(52, 0, 0),
    Sylas = Vector(28, 0, 0)
}

BaseStrucutre = {}

function BaseStrucutre:new(dat)
    dat = dat or {}
    setmetatable(dat, self)
    self.__index = self
    local counter = 1
    for key, value in pairs(Obj.Get("all", "heroes")) do
        if not value.IsMe then
            local hero = value.AsHero
  
            Heroes[hero.IsAlly and hero.CharName or counter] = {
                HeroData = hero,
                Spells = {hero:GetSpell(_Q), hero:GetSpell(_W), hero:GetSpell(_E), hero:GetSpell(_R)},
                Icons = {
                    Hero = Renderer.CreateSprite("Champions\\\\" .. hero.CharName .. ".png", 42, 42),
                    Ultimate = Renderer.CreateSprite("Ultimates\\\\" .. hero.CharName .. ".png", 24, 24),
                    Summoners = {
                        SS1 = Renderer.CreateSprite(
                            "Summoners\\\\" .. hero:GetSpell(Enums.SpellSlots.Summoner1).Name .. ".png", 24, 24),
                        SS2 = Renderer.CreateSprite(
                            "Summoners\\\\" .. hero:GetSpell(Enums.SpellSlots.Summoner2).Name .. ".png", 24, 24)
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
    return dat
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
    lastHeroOrder = Heroes
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
    local drawCharHud = Menu.Get("CoolDownTracker." .. HeroData.CharName)
    local healthBarPos = HeroData.HealthBarScreenPos
    local expBox = Vector(self:GetExpPercent(HeroData), 5, 0)
    local skillBox = Vector(25, 5, 0)
    if Menu.Get("CoolDownTracker.EXP") then
        Renderer.DrawRectOutline(Vector(healthBarPos.x - 45, healthBarPos.y - 30, 0), args.expBoxSize, 2, 2,
            CollorPallet.WHITE)
        Renderer.DrawFilledRect(Vector(healthBarPos.x - 45, healthBarPos.y - 30, 0), expBox, 5,
            CollorPallet.CYAN)
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
            Renderer.DrawRectOutline(Vector(healthBarPos.x - 45 + skillXSum + offsetX,
                                         healthBarPos.y + offsetY, 0), args.skillBoxSize, 2, 2, CollorPallet.WHITE)
            if spell.IsLearned and spell.RemainingCooldown == 0 then
                Renderer.DrawFilledRect(Vector(healthBarPos.x - 45 + skillXSum + offsetX,
                                            healthBarPos.y + offsetY, 0), skillBox, 5, CollorPallet.GREEN)
            else
                Renderer.DrawFilledRect(Vector(healthBarPos.x - 45 + skillXSum + offsetX,
                                            healthBarPos.y + offsetY, 0), skillBox, 5, CollorPallet.RED)
                if spell.IsLearned and spell.RemainingCooldown > 0 then
                    Renderer.DrawText(Vector(healthBarPos.x - 40 + skillXSum + offsetX,
                                          healthBarPos.y + 5 + offsetY, 0), Vector(50, 50),
                        math.floor(spell.RemainingCooldown), CollorPallet.WHITE)
                end
            end
            skillXSum = skillXSum + 25
        end
    end
end

function BaseStrucutre:DrawSideBarHud(value, args)
    if value.HeroData.IsAlly then return end

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

function BaseStrucutre:OnDraw()
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
    for key, value in pairs(Heroes) do
        if value.HeroData.IsEnemy then
            -- END OF CHAMPION HUD
            if Menu.Get("SideBar.Show") then
                self:DrawSideBarHud(value, args)
            end
            args.ySum = args.ySum + 80
        end
        -- Champion HUD
        if Menu.Get("CoolDownTracker.Show") and not value.HeroData.IsDead and value.HeroData.IsVisible and Renderer.IsOnScreen(value.HeroData.Position) then
            self:DrawCoolDownTracker(value.HeroData, value.Spells, args)
        end
    end
end

function BaseStrucutre:Menu()
    Menu.RegisterMenu(ScriptName, ScriptName, function()
        Menu.NewTree("SideBar", "Sidebar Controls", function()
            Menu.Checkbox("SideBar.Show", "Show Sidebar", true)
            Menu.Checkbox("SideBar.SS", "Show Summoners", true)
            Menu.Checkbox("SideBar.Ultimate", "Show Ultimate", true)
            Menu.Checkbox("SideBar.EXP", "Show EXP", true)
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
                    Menu.Slider("SideBar.Order." .. heroData.CharName, "Order 1 is top 5 is bottom " .. heroData.CharName, counter, 1, 5, 1)
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
                        Menu.Checkbox("CoolDownTracker." .. heroData.CharName, "Disable for " .. heroData.CharName, false)
                    end
                end
            end)
        end)
    end)
end

BrainexeHUD = BaseStrucutre:new()

BrainexeHUD:Menu()

-- Events --

local OnDraw = function()
    BrainexeHUD:OnDraw()
end

function OnLoad()
    Event.RegisterCallback(Enums.Events.OnDraw, OnDraw)

    return true
end