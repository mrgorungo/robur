require("common.log")
module("Storm Support Utility", package.seeall, log.setup)
clean.module("Storm Support Utility", clean.seeall, log.setup)
--[[ SDK ]]
local SDK         = _G.CoreEx
local Obj         = SDK.ObjectManager
local Event       = SDK.EventManager
local Game        = SDK.Game
local Enums       = SDK.Enums
local Geo         = SDK.Geometry
local Renderer    = SDK.Renderer
local Input       = SDK.Input
--[[Libraries]] 
local TS          = _G.Libs.TargetSelector()
local Menu        = _G.Libs.NewMenu
local Orb         = _G.Libs.Orbwalker
local HealthPred =  _G.Libs.HealthPred
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
local Marksman = {"Varus","Aphelios","Xayah","Lucian","Draven","Vayne","MissFortune","Sivir","Tristana","Jinx","Ezreal","KogMaw","Jhin","Senna","Twitch","Samira","Kaisa","Caitlyn","Kindred","Kalista","Ashe"}
-- recaller
local Items = {}
local ItemSlots = require("lol/Modules/Common/ItemID")
local Supportlist = {"Leona","Lulu","Zilean","Seraphine","Brand","Blitzcrank","Bard","Janna","Karma","Morgana","Nami","Nautilus","Pyke","Rell","Rakan","Sona","Taric","Thresh","Zyra","Yuumi"}
-- MODES FUNCTIONS

local function GameIsAvailable()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

local function CountHeroes(pos,Range,type)
    local num = 0
    for k, v in pairs(Obj.Get(type, "heroes")) do
        local hero = v.AsHero
        if hero and hero.IsTargetable and hero:Distance(pos.Position) < Range then
            num = num + 1
        end
    end
    return num
end

local function Getallies()
    local allies = {}
    for k, v in pairs(Obj.Get("ally", "heroes")) do
        local hero = v.AsHero
        table.insert(allies,hero)
    end
    return  allies
end

local function AlliesTable(Range,name)
    local allies = {}
    for k, v in pairs(Obj.Get("ally", "heroes")) do
        local hero = v.AsHero
        local Tar  = hero:Distance(Player) < Range and hero.IsTargetable and Menu.Get(name .. hero.CharName)
        if Tar then
           table.insert(allies,v.AsHero)
        end
    end
    return allies
end

function Items.OnBuffGain(obj,buffInst)
    if not obj.IsHero or not obj.IsAlly or not Menu.Get("Mikael." .. obj.AsHero.CharName) or not Menu.Get("Blessing") then return end
    if buffInst.BuffType == Enums.BuffTypes.Slow and not Menu.Get("Slow") then return end
    if buffInst.BuffType == Enums.BuffTypes.Disarm and not Menu.Get("Disarm") then return end
    if buffInst.BuffType == Enums.BuffTypes.Stun and not Menu.Get("Stun") then return end
    if buffInst.BuffType == Enums.BuffTypes.Silence and not Menu.Get("Silence") then return end
    if buffInst.BuffType == Enums.BuffTypes.Taunt and not Menu.Get("Taunt") then return end
    if buffInst.BuffType == Enums.BuffTypes.Polymorph and not Menu.Get("Polymorph") then return end
    if buffInst.BuffType == Enums.BuffTypes.Snare and not Menu.Get("Snare") then return end
    if buffInst.BuffType == Enums.BuffTypes.Fear and not Menu.Get("Fear") then return end
    if buffInst.BuffType == Enums.BuffTypes.Charm and not Menu.Get("Charm") then return end
    if buffInst.BuffType == Enums.BuffTypes.Blind and not Menu.Get("Blind") then return end
    if buffInst.BuffType == Enums.BuffTypes.Grounded and not Menu.Get("Grounded") then return end
    if buffInst.BuffType == Enums.BuffTypes.Asleep and not Menu.Get("Asleep") then return end
    if buffInst.BuffType == Enums.BuffTypes.Flee and not Menu.Get("Flee") then return end
    if buffInst.BuffType == Enums.BuffTypes.Knockup then return end
    if buffInst.BuffType == Enums.BuffTypes.Knockback then return end
    if buffInst.BuffType == Enums.BuffTypes.Suppression then return end
    if buffInst.DurationLeft > Menu.Get("Du") and buffInst.IsCC then 
        for k,v in pairs(Player.Items) do 
            local itemslot = k + 6
            local id = v.ItemId
            if id == ItemSlots.MikaelsBlessing and obj.AsHero:Distance(Player) <= 650 then
                if Player:GetSpellState(itemslot) ==  Enums.SpellStates.Ready then 
                    Input.Cast(itemslot, obj.AsHero)
                end
            end  
        end
    end
end

function Items.OnHighPriority()
    if Menu.Get("Redemption") then 
        for v, k in pairs(Player.Items) do
            local id = k.ItemId
            local slot = v + 6
            if id == ItemSlots.Redemption and Player:GetSpellState(slot) ==  Enums.SpellStates.Ready then
                for k,hero in pairs(AlliesTable(5500,"Redemption.")) do 
                    local delay =  2.5 + Game.GetLatency()/1000
                    local predDmg = HealthPred.GetDamagePrediction(hero, delay, false) 
                    local predHealth = (hero.Health - predDmg) / hero.MaxHealth
                    local minHealth = Menu.Get("RedemptionHealth") / 100
                    if predHealth < minHealth and (predDmg > 0 or CountHeroes(hero,1000,"enemy") > 0) then                
                        return Input.Cast(slot,hero.Position) 
                    end
                end
            end
        end
    end
    if not GameIsAvailable() then
        return
    end
    if Menu.Get("Locket") then 
        for v, k in pairs(Player.Items) do
            local id = k.ItemId
            local slot = v + 6
            if id == ItemSlots.LocketOftheIronSolari and Player:GetSpellState(slot) ==  Enums.SpellStates.Ready then
                for k,hero in pairs(AlliesTable(1100,"Locket.")) do 
                    local delay =  0.10 + Game.GetLatency()/1000
                    local predDmg = HealthPred.GetDamagePrediction(hero, delay, false) 
                    local predHealth = (hero.Health - predDmg) / hero.MaxHealth
                    local minHealth = Menu.Get("minHealth") / 100
                    if predHealth < minHealth and (predDmg > 0 or CountHeroes(hero,1000,"enemy") > 0) then                
                        return Input.Cast(slot) 
                    end
                end
            end
        end
    end
end


function Items.OnPreAttack(args)
    if Menu.Get("Support") and not args.Target.IsMonster and args.Target.IsMinion and CountHeroes(Player,1000,"ally") > 1 then
        args.Process = false
    end
end

-- MENU
function Items.LoadMenu()
    Menu.RegisterMenu("Stormitems" .. Player.CharName, "Storm Support Utility", function()
        local IsSupportChamp = false
        for k, v in pairs(Supportlist) do
            if v == Player.CharName then IsSupportChamp = true end
        end
        Menu.Checkbox("Support","Support Mode",IsSupportChamp)
        Menu.NewTree("Items", "Item Options", function()
            Menu.NewTree("MikaelsBlessing","Mikael's Blessing", function ()
                Menu.Checkbox("Blessing","Enabled",true)
                Menu.Slider("Du","Use when CC Duration time > ",0.6,0.5,3,0.05)
                    Menu.NewTree("CC","CC Whitelist", function ()
                    Menu.Checkbox("Stun","Stun",true)
                    Menu.Checkbox("Fear","Fear",true)
                    Menu.Checkbox("Snare","Snare",true)
                    Menu.Checkbox("Taunt","Taunt",true)
                    Menu.Checkbox("Slow","Slow",false)
                    Menu.Checkbox("Charm","Charm",true)
                    Menu.Checkbox("Blind","Blind",true)
                    Menu.Checkbox("Polymorph","Polymorph(Silence & Disarm)",true)
                    Menu.Checkbox("Flee","Flee",true)
                    Menu.Checkbox("Grounded","Grounded",true)
                    Menu.Checkbox("Asleep","Asleep",true)
                    Menu.Checkbox("Disarm","Disarm",false)
                    Menu.Checkbox("Silence","Silence",false)
                end)
                Menu.NewTree("MikaelWhitelist","Mikael Whitelist", function ()
                    for l,list in pairs(Getallies()) do 
                        local result = false
                        for k, v in pairs(Marksman) do
                            if v == list.CharName then result = true end
                        end
                        Menu.Checkbox("Mikael." .. list.CharName, "Use on " .. list.CharName, result)
                    end
                end)
            end)
            Menu.NewTree("RedemptionMenu","Redemption", function ()
                Menu.Checkbox("Redemption","Enabled",true)
                Menu.Slider("RedemptionHealth","When Health x <=",35,0,100)
                Menu.NewTree("RedemptionWhitelist","Redemption Whitelist", function ()
                    for l,list in pairs(Getallies()) do 
                        local result = false
                        for k, v in pairs(Marksman) do
                            if v == list.CharName or list.IsMe then result = true end
                        end
                        Menu.Checkbox("Redemption." .. list.CharName, "Use on " .. list.CharName, result)
                    end
                end)
            end)
            Menu.NewTree("LocketOftheIronSolari","Locket Of the Iron Solari", function ()
                Menu.Checkbox("Locket","Enabled",true)
                Menu.Slider("minHealth","When Health x <=",35,0,100)
                Menu.NewTree("LocketWhitelist","Locket Whitelist", function ()
                    for l,list in pairs(Getallies()) do 
                        local result = false
                        for k, v in pairs(Marksman) do
                            if v == list.CharName or list.IsMe then result = true end
                        end
                        Menu.Checkbox("Locket." .. list.CharName, "Use on " .. list.CharName, result)
                    end
                end)
            end)
        end)
    end)     
end

-- LOAD
function OnLoad()
    Items.LoadMenu()
    for eventName, eventId in pairs(Enums.Events) do
        if Items[eventName] then
            Event.RegisterCallback(eventId, Items[eventName])
        end
    end    
    return true
end