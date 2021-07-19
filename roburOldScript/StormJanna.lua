-- 🆂🆃🅾🆁🅼🅰🅸🅾 --
if Player.CharName ~= "Janna" then return end
require("common.log")
module("Storm Janna", package.seeall, log.setup)
clean.module("Storm Janna", clean.seeall, log.setup)
local clock = os.clock
local insert, sort = table.insert, table.sort
local huge, min, max, abs = math.huge, math.min, math.max, math.abs
local _SDK = _G.CoreEx
local Console, ObjManager, EventManager, Geometry, Input, Renderer, Enums, Game = _SDK.Console, _SDK.ObjectManager, _SDK.EventManager, _SDK.Geometry, _SDK.Input, _SDK.Renderer, _SDK.Enums, _SDK.Game
local Menu, Orbwalker, Collision, Prediction, HealthPred = _G.Libs.NewMenu, _G.Libs.Orbwalker, _G.Libs.CollisionLib, _G.Libs.Prediction, _G.Libs.HealthPred
local DmgLib, ImmobileLib, Spell = _G.Libs.DamageLib, _G.Libs.ImmobileLib, _G.Libs.Spell

---@type TargetSelector
local TS = _G.Libs.TargetSelector()

-- recaller
local Janna = {}
local JannaNP = {}

local boostspells = {
    Priority1 = {"Volley","CaitlynPiltoverPeacemaker","CaitlynAceintheHole","PhosphorusBomb",
    "GGun","DravenSpinning","DravenDoubleShot","EzrealMysticShot","GravesClusterShot","JinxW","LucianW",
    "QuinnQ","UrgotPlasmaGrenade","VarusE","VayneCondemn","BlindMonkQOne","ViE","AlphaStrike","WujuStyle",
    "TalonNoxianDiplomacy","YasuoQW","yasuoq2w","yasuoq3w","ZedShuriken","ZedPBAOEDummy","Parley","GarenQ",
    "RengarE","MonkeyKingDoubleAttack","SamiraQ","SennaQ"},
    Priority2 = {"LucianQ","KaisaW","JhinQ","QuinnE","SivirQ","UrgotHeatseekingMissile","VayneTumble","NasusQ","TwoShivPoison",
    "TrundleTrollSmash","ViQ","XenZhaoComboTarget","KhazixQ","KhazixW","PantheonQ","AatroxW","GarenE","JayceToTheSkies",
    "jayceshockblast","RenektonCleave","RenektonPreExecute","RenektonSliceAndDice","RengarQ","MonkeyKingNimbus","KalistaMysticShot"},
    Priority3 = {"KalistaExpungeWrapper","MonkeyKingSpinToWin","RivenFengShuiEngine","RengarR","DariusExecute","zedult",
    "YasuoRKnockUpComboW","JinxR","TalonShadowAssault","XenZhaoParry","ViR","NocturneParanoia","BlindMonkRKick","VayneInquisition",
    "VarusQ","FullAutomatic","QuinnR","Expunge","JhinRShot","MissFortuneBulletTime","SamiraR","SennaR"}
}

-- spells
local Q = Spell.Skillshot({
    Slot = Enums.SpellSlots.Q,
    Range = 830,
    Speed = 900,
    Radius = 120,
    Type = "Linear",
    Delay = 0.25,
    Key = "Q"
})
local Q2 = Spell.Active({
    Slot = Enums.SpellSlots.Q,
})
local W = Spell.Targeted({
    Slot = Enums.SpellSlots.W,
    Range = 625,
    Delay = 0,
    Key = "W"
})
local E = Spell.Targeted({
    Slot = Enums.SpellSlots.E,
    Range = 800,
    Key = "E"
})
local R = Spell.Active({
    Slot = Enums.SpellSlots.R,
    Range = 725,
    Key = "R",
})

local function GameIsAvailable()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

function Janna.OnHighPriority() 
    if not GameIsAvailable() then
        return
    end
    if Janna.Auto() then return end
    local ModeToExecute = Janna[Orbwalker.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end

function Janna.OnNormalPriority()
    if not GameIsAvailable() then
        return
    end
    local ModeToExecute = JannaNP[Orbwalker.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end


-- DRAW
function Janna.OnDraw()
    local Pos = Player.Position
    local spells = {Q,W,E,R}
    for k, v in pairs(spells) do
        if Menu.Get("Drawing."..v.Key..".Enabled", true) and v:IsReady() then
            Renderer.DrawCircle3D(Pos, v.Range, 30, 3, Menu.Get("Drawing."..v.Key..".Color"))
        end
    end
end


-- SPELL HELPERS
local function CanCast(spell,mode)
    return spell:IsReady() and Menu.Get(mode .. ".Cast"..spell.Key)
end

local function HitChance(spell)
    return Menu.Get("Chance."..spell.Key)
end

local function GetTargets(Spell)
    return {TS:GetTarget(Spell.Range,true)}
end

local function Count(spell,team,type)
    local num = 0
    for k, v in pairs(ObjManager.Get(team, type)) do
        local minion = v.AsAI
        local Tar    = spell:IsInRange(minion) and minion.MaxHealth > 6 and minion.IsTargetable
        if minion and Tar then
            num = num + 1
        end
    end
    return num
end

local function CountHeroes(pos,Range,type)
    local num = 0
    for k, v in pairs(ObjManager.Get(type, "heroes")) do
        local hero = v.AsHero
        if hero and hero.IsTargetable and hero:Distance(pos.Position) < Range then
            num = num + 1
        end
    end
    return num
end


-- MODES FUNCTIONS
function Janna.ComboLogic(mode)
    if CanCast(Q,mode) then
        for k,v in pairs(GetTargets(Q)) do
            if Q:CastOnHitChance(v,HitChance(Q)) then return end
        end
    end
end

function Janna.HarassLogic(mode)
    if Menu.Get("ManaSlider") > Player.ManaPercent * 100 then return end
    if CanCast(Q,mode) then
        for k,v in pairs(GetTargets(Q)) do
            if Q:CastOnHitChance(v,HitChance(Q)) then return end
        end
    end
end


-- CALLBACKS
function Janna.Auto()
    if Q:IsReady() and Q:GetToggleState() == 2 then 
        Q2:Cast()
    end
    if R:IsReady() and Menu.Get("CastR") then
        for _, v in pairs(ObjManager.Get("ally","heroes")) do
            local hero = v.AsHero
            if R:IsInRange(hero) and Menu.Get("1" .. hero.CharName) and (hero.HealthPercent * 100 ) < Menu.Get("UseRh") and not hero.IsRecalling and CountHeroes(hero,800,"enemy") > 0 then
                if R:Cast() then return end
            end
        end
    end
    if Menu.Get("E.Simi") and E:IsReady() then
        local heroes = {}
        local pos = Renderer.GetMousePos()
        for _, v in pairs(ObjManager.Get("ally","heroes")) do
            insert(heroes, v.AsHero)
        end
        table.sort(heroes, function(a, b) return a:Distance(pos) < b:Distance(pos) end)
        for _, hero in ipairs(heroes) do
            if E:IsReady() and E:IsInRange(hero) then 
                if E:Cast(hero) then return end
            end
        end
    end 
end

function Janna.OnInterruptibleSpell(source, spell, danger, endT, canMove)
    if not (source.IsEnemy and Menu.Get("Misc.QI") and Q:IsReady() and danger > 2) then return end
    if not Menu.Get("2" .. source.AsHero.CharName) then return end
    if Q:CastOnHitChance(source,Enums.HitChance.VeryHigh) then
        return 
    end
end

function Janna.OnGapclose(Source, DashInstance)
    if not (Source.IsEnemy) then return end
    if not Menu.Get("3" .. Source.AsHero.CharName) then return end
    if Menu.Get("Misc.Q") and Q:IsReady() and Q:CastOnHitChance(Source,Enums.HitChance.VeryHigh) then
        return 
    end
    if Menu.Get("Misc.W") and W:IsInRange(Source) and W:IsReady() and W:Cast(Source) then
        return 
    end
end

function Janna.OnPreAttack(args)
    if Menu.Get("Support") and args.Target.IsMinion and CountHeroes(Player,1000,"ally") > 1 then
        args.Process = false
    end
    local mode = Orbwalker.GetMode()
    if args.Target.IsHero and W:IsReady() then
        if mode == "Combo" then
            if CanCast(W,mode) then
                W:Cast(args.Target) 
            return end
        end
    end
    if args.Target.IsHero and W:IsReady() then
        if mode == "Harass" then
            if CanCast(W,mode) and Menu.Get("ManaSlider") < Player.ManaPercent * 100 then
                W:Cast(args.Target) 
            return end
        end
    end
end

function Janna.OnBuffGain(obj,buffInst)
    if not obj.IsHero or not obj.IsAlly or not Menu.Get("4" .. obj.AsHero.CharName) then return end
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
            if v.Name == "3222Active" and obj.AsHero:Distance(Player) <= 650 then
                if Player:GetSpellState(itemslot) ==  Enums.SpellStates.Ready then 
                    Input.Cast(itemslot, obj.AsHero)
                end
            end  
        end
    end
end

function Janna.OnProcessSpell(sender,spell)
    if (sender.IsHero and sender.IsEnemy and E:IsReady()) then
        local spellTarget = spell.Target
        if Menu.Get("Misc.AE") then 
            if spellTarget and spellTarget.IsAlly and spellTarget.IsHero and E:IsInRange(spellTarget) and E:IsReady() then
                E:Cast(spellTarget)
            end
        end
        if spell.Slot > 3 or not Menu.Get("Misc.AES") then return end
        for k,v in pairs(ObjManager.Get("ally", "heroes")) do
            local Hero = v.AsHero
            if E:IsInRange(Hero) then
                if Hero:Distance(spell.EndPos) < Hero.BoundingRadius * 2 then
                    if E:Cast(Hero) then
                        return
                    end
                end
            end
        end
    end
    if (sender.IsHero and sender.IsAlly and Menu.Get("Boost") and E:IsReady()) then
        local hero = sender.AsHero
        if not E:IsInRange(hero) or not Menu.Get(hero.CharName) or CountHeroes(hero,1500,"enemy") < 1 then return end
        if Menu.Get("BP") == 1 then 
            for k,v in pairs(boostspells.Priority1) do 
                if v == spell.Name then E:Cast(sender) end
            end
            for k,v in pairs(boostspells.Priority2) do 
                if v == spell.Name then E:Cast(sender) end
            end
            for k,v in pairs(boostspells.Priority3) do 
                if v == spell.Name then E:Cast(sender) end
            end
        end
        if Menu.Get("BP") == 2 then 
            for k,v in pairs(boostspells.Priority2) do 
                if v == spell.Name then E:Cast(sender) end
            end
            for k,v in pairs(boostspells.Priority3) do 
                if v == spell.Name then E:Cast(sender) end
            end
        end
        if Menu.Get("BP") == 3 then 
            for k,v in pairs(boostspells.Priority3) do 
                if v == spell.Name then E:Cast(sender) end
            end
        end
    end
end


-- RECALLERS
function Janna.Combo()  Janna.ComboLogic("Combo")  end
function JannaNP.Harass() Janna.HarassLogic("Harass") end


-- MENU
function Janna.LoadMenu()
    Menu.RegisterMenu("StormJanna", "Storm Janna", function()
        Menu.Checkbox("Support",   "Support Mode", true)
        Menu.NewTree("Combo", "Combo Options", function()
            Menu.Checkbox("Combo.CastQ",   "Use [Q]", true)
            Menu.Checkbox("Combo.CastW",   "Use [W]", true)
        end)
        Menu.NewTree("Rs", "R Options", function()
            Menu.Checkbox("CastR",   "Auto [R]", true)
            Menu.Slider("UseRh", " R when ally x < ", 25, 0, 100)
            Menu.NewTree("Rlist","R Whitelist", function()
                Menu.ColoredText("R Whitelist", 0xFFD700FF, true)
                for _, Object in pairs(ObjManager.Get("ally", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox("1" .. Name, "Use on " .. Name, true)
                end
            end)
        end)
        Menu.NewTree("Harass", "Harass Options", function()
            Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
            Menu.Slider("ManaSlider","",50,0,100)
            Menu.Checkbox("Harass.CastQ",   "Use [Q]", true)
            Menu.Checkbox("Harass.CastW",   "Use [W]", true)
        end)
        Menu.NewTree("E", "E Options", function()
            Menu.Keybind("E.Simi", "Simi [E] Key (Casts on Nearest ally to Cursor)", string.byte('E')) 
            Menu.Checkbox("Boost",   "Use [E] To Boost damage Spells", true)
            Menu.Slider("BP","Boost priority", 2,1,3)
            Menu.Checkbox("Misc.AE",  "Auto Shield allies on Basic attack", false)
            Menu.Checkbox("Misc.AES", "Auto Shield allies on Spell Attack", true) 
            Menu.ColoredText("E WhiteList", 0xFFD700FF, true)
            for _, Object in pairs(ObjManager.Get("ally", "heroes")) do
                local Name = Object.AsHero.CharName
                Menu.Checkbox(Name, Name, 1,1,5)
            end
        end)
        Menu.NewTree("Prediction", "Prediction Options", function()
            Menu.Slider("Chance.Q","HitChance [Q]",0.6, 0, 1, 0.05)
        end)
        Menu.NewTree("Misc", "Misc Options", function()
            Menu.Checkbox("Misc.QI",   "Use [Q] on Interrupter", true)
            Menu.NewTree("Interrupter", "Interrupter Whitelist", function()
                for _, Object in pairs(ObjManager.Get("enemy", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox("2" .. Name, "Use on " .. Name, true)
                end
            end)
            Menu.Checkbox("Misc.Q",   "Use [Q] on gapclose", true)
            Menu.Checkbox("Misc.W",   "Use [W] on gapclose", true)
            Menu.NewTree("gapclose", "gapclose Whitelist", function()
                for _, Object in pairs(ObjManager.Get("enemy", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox("3" .. Name, "Use on " .. Name, true)
                end
            end)
        end)
        Menu.NewTree("Items", "Item Options", function()
            Menu.NewTree("MikaelsBlessing","Mikael's Blessing", function ()
                Menu.Slider("Du","Use when CC Duration time > ",1,0.5,3,0.05)
                    Menu.NewTree("CC","CC Whitelist", function ()
                    Menu.Checkbox("Stun","Stun",true)
                    Menu.Checkbox("Fear","Fear",true)
                    Menu.Checkbox("Snare","Snare",true)
                    Menu.Checkbox("Taunt","Taunt",true)
                    Menu.Checkbox("Slow","Slow",true)
                    Menu.Checkbox("Charm","Charm",true)
                    Menu.Checkbox("Blind","Blind",true)
                    Menu.Checkbox("Polymorph","Polymorph(Silence & Disarm)",true)
                    Menu.Checkbox("Flee","Flee",true)
                    Menu.Checkbox("Grounded","Grounded",true)
                    Menu.Checkbox("Asleep","Asleep",true)
                    Menu.Checkbox("Disarm","Disarm",false)
                    Menu.Checkbox("Silence","Silence",false)
                end)
                Menu.ColoredText("Mikael's Blessing Whitelist", 0xFFD700FF, true)
                for _, Object in pairs(ObjManager.Get("ally", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox("4" .. Name, "Use on " .. Name, true)
                end
            end)
        end)
        Menu.NewTree("Draw", "Drawing Options", function()
            Menu.Checkbox("Drawing.Q.Enabled",   "Draw [Q] Range",true)
            Menu.ColorPicker("Drawing.Q.Color", "Draw [Q] Color", 0x118AB2FF)
            Menu.Checkbox("Drawing.W.Enabled",   "Draw [W] Range",true)
            Menu.ColorPicker("Drawing.W.Color", "Draw [W] Color", 0x118AB2FF)
            Menu.Checkbox("Drawing.E.Enabled",   "Draw [E] Range",false)
            Menu.ColorPicker("Drawing.E.Color", "Draw [E] Color", 0x118AB2FF)
            Menu.Checkbox("Drawing.R.Enabled",   "Draw [R] Range",true)
            Menu.ColorPicker("Drawing.R.Color", "Draw [R] Color", 0x118AB2FF)
        end)
    end)     
end


-- LOAD
function OnLoad()
    Janna.LoadMenu()
    for eventName, eventId in pairs(Enums.Events) do
        if Janna[eventName] then
            EventManager.RegisterCallback(eventId, Janna[eventName])
        end
    end    
    return true
end