--[[
 +-+-+-+-+-+ +-+-+-+-+-+-+
 |S|t|r|o|m| |T|h|r|e|s|h|
 +-+-+-+-+-+ +-+-+-+-+-+-+
]]
if Player.CharName ~= "Thresh" then return end
require("common.log")
module("Storm Thresh", package.seeall, log.setup)
clean.module("Storm Thresh", clean.seeall, log.setup)
local clock = os.clock
local insert, sort = table.insert, table.sort
local huge, min, max, abs = math.huge, math.min, math.max, math.abs
local _SDK = _G.CoreEx
local Console, ObjManager, EventManager, Geometry, Input, Renderer, Enums, Game = _SDK.Console, _SDK.ObjectManager, _SDK.EventManager, _SDK.Geometry, _SDK.Input, _SDK.Renderer, _SDK.Enums, _SDK.Game
local Menu, Orbwalker, Collision, Prediction, HealthPred = _G.Libs.NewMenu, _G.Libs.Orbwalker, _G.Libs.CollisionLib, _G.Libs.Prediction, _G.Libs.HealthPred
local DmgLib, ImmobileLib, Spell = _G.Libs.DamageLib, _G.Libs.ImmobileLib, _G.Libs.Spell

---@type TargetSelector
local TS = _G.Libs.TargetSelector()

--recaller
local Thresh = {}
local ThreshHP = {}
local ThreshNP = {}
local SoulList = {}
local Bufflist = {"talentreaperstacksone","talentreaperstackstwo","talentreaperstacksthree"}
-- spells
local Q = Spell.Skillshot({
    Slot = Enums.SpellSlots.Q,
    Range = 1075,
    Radius = 75,
    Speed = 1900,
    UseHitbox = true,
    Delay = 0.5,
    Collisions = {Minions = true, WindWall = true},
    Type = "Linear",
    Key = "Q",
})
local Q2 = Spell.Active({
    Slot = Enums.SpellSlots.Q,
})
local W = Spell.Skillshot({
    Slot = Enums.SpellSlots.W,
    Range =  950,
    Delay = 0,
    Key = "W",

})
local E = Spell.Skillshot({
    Slot = Enums.SpellSlots.E,
    Range =  400,
    Delay = 0.38889,
    Speed = huge,
    Radius = 110,
    Key = "E",
    UseHitbox = true,
    Type = "Linear"

})
local R = Spell.Active({
    Slot = Enums.SpellSlots.R,
    Range = 450,
    Delay = 0.45,
    Key = "R",
})
local Summoner2 = Spell.Targeted({
    Slot = Enums.SpellSlots.Summoner2,
    Range = 600,
    Key = "I"
})
local Summoner1 = Spell.Targeted({
    Slot = Enums.SpellSlots.Summoner1,
    Range = 600,
    Key = "I"
})


local function GameIsAvailable()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

local function dmg(spell)
    local dmg = 0
    if spell.Key == "I" then
        dmg = (70 + (Player.Level) * 20) 
    end
    return dmg
end

function Thresh.OnHighPriority() 
    if not GameIsAvailable() then
        return
    end
    if Thresh.Auto() then return end
    local ModeToExecute = ThreshHP[Orbwalker.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end

function Thresh.OnNormalPriority()
    if not GameIsAvailable() then
        return
    end
    local ModeToExecute = ThreshNP[Orbwalker.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end


-- DRAW
function Thresh.OnDraw()
    local Pos = Player.Position
   
    local spells = {Q,W,E,R}
    for k, v in pairs(spells) do
        if Menu.Get("Drawing."..v.Key..".Enabled", true) and v:IsReady() then
            Renderer.DrawCircle3D(Pos, v.Range, 30, 3, Menu.Get("Drawing."..v.Key..".Color"))
        end
    end
    if Menu.Get("DrawAroundSoul") then
        for k,v in pairs(SoulList) do
            if not v.IsDead and v.IsValid then
                Renderer.DrawCircle3D(v.Position, v.BoundingRadius, 30, 3, Menu.Get("AroundSoulcolor"))
            end
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

local function GetTargetsRange(Range)
    return {TS:GetTarget(Range,true)}
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

local function GetBestAdAlly(spell)
    local heroes = {}
    for k, v in pairs(ObjManager.Get("ally", "heroes")) do
        if not v.IsDead and not v.IsMe and v.IsValid and spell:IsInRange(v) then 
            insert(heroes,v.AsHero)
        end
    end
    table.sort(heroes,function(a, b) return a.TotalAD > b.TotalAD end)
    for  k,v  in ipairs(heroes) do 
        if v then
            return v.Position
        end
    end
end

local function GetBestEpos(Range)
    local heroes = {}
    for k, v in pairs(ObjManager.Get("ally", "heroes")) do
        if not v.IsDead and not v.IsMe and v.IsValid and v:Distance(Player) < Range then 
            insert(heroes,v.AsHero)
        end
    end
    table.sort(heroes,function(a, b) return b:Distance(Player) > a:Distance(Player) end)
    for  k,v  in ipairs(heroes) do 
        if v then
            return v.Position
        end
    end
end

local function IsUnderTurrent(pos)
    local sortme = {}
    for k, v in pairs(ObjManager.Get("enemy", "turrets")) do
        if not v.IsDead and v.IsTurret then 
            insert(sortme,v)
        end
    end
    table.sort(sortme,function(a, b) return b:Distance(Player) > a:Distance(Player) end)
    for  k,v  in ipairs(sortme) do 
        return v:Distance(pos) <= 870
    end
end

local function KS(spell)
    return Menu.Get("KS."..spell.Key) and spell:IsReady()
end



-- CALLBACKS
function Thresh.Auto()
    if Menu.Get("Misc.WSimi") and W:IsReady() then 
        local Pos = Renderer.GetMousePos()
        local hero = {}
        for k,v in pairs(ObjManager.Get("ally","heroes")) do 
            if not v.IsDead and not v.IsMe and v.IsValid and W:IsInRange(v) then 
                insert(hero,v.AsHero)
            end
        end
        table.sort(hero, function(a, b) return a:Distance(Pos) < b:Distance(Pos) end)
        for k,v in ipairs(hero) do 
            if W:Cast(v.Position) then return end
        end
    end
    if KS(Summoner1) then 
        for k, obj in pairs(GetTargets(Summoner1)) do 
            if obj.Health >= dmg(Summoner1) then return end
            if Summoner1:IsReady() and Summoner1:GetName() == "SummonerDot" then 
                if Summoner1:IsInRange(obj) and Summoner1:Cast(obj) then return end
            end
            if Summoner2:IsReady() and Summoner2:GetName() == "SummonerDot" then 
                if Summoner2:IsInRange(obj) and Summoner2:Cast(obj) then return end
            end
        end
    end
    if Menu.Get("Misc.I") then 
        for k, obj in pairs(GetTargets(Summoner1)) do 
            if obj.HealthPercent * 100 >= Menu.Get("Misc.AI")then return end
            if Summoner1:IsReady() and Summoner1:GetName() == "SummonerDot" then 
                if Summoner1:IsInRange(obj) and Summoner1:Cast(obj) then return end
            end
            if Summoner2:IsReady() and Summoner2:GetName() == "SummonerDot" then 
                if Summoner2:IsInRange(obj) and Summoner2:Cast(obj) then return end
            end
        end
    end
end

function Thresh.OnInterruptibleSpell(source, spell, danger, endT, canMove)
    if not (source.IsEnemy and Menu.Get("Misc.EI") and E:IsReady() and danger > 2) or source:GetBuff("ThreshQ") or Q:GetName() == "ThreshQLeap" then return end
    if not Menu.Get("1" .. source.AsHero.CharName) then return end
    if E:CastOnHitChance(source,Enums.HitChance.VeryHigh) then
        return 
    end
end

function Thresh.OnGapclose(Source, DashInstance)
    if not (Source.IsEnemy) or Source:GetBuff("ThreshQ") or Q:GetName() == "ThreshQLeap" then return end
    if not Menu.Get("2" .. Source.AsHero.CharName) then return end
    if Menu.Get("Misc.EGap") and E:IsReady() and E:CastOnHitChance(Source,Enums.HitChance.VeryHigh) then
        return 
    end
end

function Thresh.OnPreAttack(args)
    local mode = Orbwalker.GetMode()
    if Menu.Get("Support") and args.Target.IsMinion and not args.Target.IsMonster and CountHeroes(Player,1000,"ally") > 1 then
        if mode == "Harass" then args.Process = false return end
        if mode ~= "Waveclear" then return end
        for k,v in pairs(Bufflist) do 
            if Player:GetBuff(v) then return end
        end
        args.Process = false
    end
end

function Thresh.OnPreMove(args)
    local mode = Orbwalker.GetMode() 
    if mode ~= "Waveclear" then return end
    for k,v in pairs(SoulList) do
        if not v.IsDead and v.IsValid then 
            local endPos = Player.Pathing.EndPos
            if not Menu.Get("Catch") then return end
            if Menu.Get("Misc.PathFind") and v:Distance(endPos) > Menu.Get("Misc.Path") then return end
            if v:Distance(Player) < (v.BoundingRadius - Player.BoundingRadius) * 0.7 then return end
            if v:Distance(Player) > Menu.Get("Misc.SoulMark") then return end
            args.Process = false
            Input.MoveTo(v.Position)
        end
    end
end

function Thresh.OnCreateObject(obj)
    if obj ~= nil and obj.Name == "Thresh_Base_soul" then
        table.insert(SoulList,obj)
    end
end

function Thresh.OnDeleteObject(obj)
    if obj ~= nil and obj.Name == "Thresh_Base_soul" then
        for k,v in pairs(SoulList) do 
            if v.NetworkId == obj.NetworkId then 
                table.remove(SoulList,k)
            end
        end
    end
end


-- RECALLERS
function ThreshHP.Combo()
    local mode = "Combo"
    if CanCast(Q,mode) then 
        for k,v in pairs(GetTargets(Q)) do 
            if v:GetBuff("ThreshQ") then Q2:Cast() return end
            if Q:GetName() == "ThreshQLeap" then return end
            if v:Distance(Player) > Menu.Get("Max.Q") then return end
            if Q:CastOnHitChance(v,HitChance(Q)) then return end
        end
    end
    if CanCast(E,mode) then 
        for k,v in pairs(GetTargetsRange(E.Range + 50)) do 
            if v:GetBuff("ThreshQ") then return end
            local pre = Prediction.GetPredictedPosition(v,E,Player.Position)
            if pre and pre.HitChance >= HitChance(E) then 
                local castpos = pre.CastPosition:Extended(Player.Position, E.Range)
                if E:Cast(castpos) then return end
            end
        end
    end
end

function  ThreshNP.Combo()
    local mode = "Combo"
    if CanCast(W,mode) then
        for k,v in pairs(GetTargetsRange(Q.Range + 400)) do 
            if not v:GetBuff("ThreshQ") then return end
            local Pos = GetBestAdAlly(W)
            if Pos and W:Cast(Pos) then return end
        end
    end
    if CanCast(R,mode) then
        if #TS:GetTargets(R.Range, true) >= Menu.Get("RH") then 
            if R:Cast() then return end
        end 
    end
end

function ThreshHP.Harass()
    if Menu.Get("ManaSlider") > Player.ManaPercent * 100 then return end
    local mode = "Harass"
    if CanCast(Q,mode) and Q:GetName() ~= "ThreshQLeap" then 
        for k,v in pairs(GetTargets(Q)) do 
            if v:Distance(Player) > Menu.Get("Max.Q") then return end
            if not Menu.Get(v.CharName) then return end
            if Q:CastOnHitChance(v,HitChance(Q)) then return end
        end
    end
end



-- MENU
function Thresh.LoadMenu()
    Menu.RegisterMenu("StormThresh", "Storm Thresh", function()
        Menu.Checkbox("Support",   "Support Mode", true)
        Menu.NewTree("Combo", "Combo Options", function()
            Menu.Checkbox("Combo.CastQ",   "Use [Q]", true)
            Menu.Checkbox("Combo.CastW",   "Use [W]", true)
            Menu.Checkbox("Combo.CastE",   "Use [E]", true)
            Menu.Checkbox("Combo.CastR",   "Use [R] ", true)
            Menu.Slider("RH","^ when x >=",2,1,5)
        end)
        Menu.NewTree("Harass", "Harass Options", function()
            Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
            Menu.Slider("ManaSlider","",50,0,100)
            Menu.Checkbox("Harass.CastQ",   "Use [Q]", true)
            Menu.NewTree("Q", "Q Whitelist", function()
                for _, Object in pairs(ObjManager.Get("enemy", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox(Name, "Use on " .. Name, true)
                end
            end)
        end)
        Menu.NewTree("KS", "KillSteal Options", function()
            Menu.Checkbox("KS.I"," Use Ignite to Ks", true)
        end)
        Menu.NewTree("MiscSoul","Soul Options",function ()
            Menu.Checkbox("Catch", "Catch Soul", true)
            Menu.ColoredText(" ^ Only work WaveClear Mode ",0xff2908FF,true)
            Menu.Slider("Misc.SoulMark", "Magnet To Soul | If Distance To Player <= x", 200, 100, 400)
            Menu.Checkbox("Misc.SoulMarkTower", "Dont Catch | If Soul Under Enemy Turret",true)
            Menu.Checkbox("Misc.PathFind", "use Pathfinding | Only Move to Soul when close to path",false)
            Menu.Slider("Misc.Path", "^ When Distance to Path < x ",200,100,400)
        end)
        Menu.NewTree("Misc", "Misc Options", function()
            Menu.Checkbox("Misc.EI",   "Use [E] on Interrupter", true)
            Menu.NewTree("Interrupter", "Interrupter Whitelist", function()
                for _, Object in pairs(ObjManager.Get("enemy", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox("1" .. Name, "Use on " .. Name, true)
                end
            end)
            Menu.Checkbox("Misc.EGap",   "Use [E] on gapclose", true)
            Menu.NewTree("gapclose", "gapclose Whitelist", function()
                for _, Object in pairs(ObjManager.Get("enemy", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox("2" .. Name, "Use on " .. Name, true)
                end
            end)
            Menu.Checkbox("Misc.I"," Auto Ignite ", false)
            Menu.Slider("Misc.AI"," ^ When Hp < x ", 20,0,100)
            Menu.Keybind("Misc.WSimi","Simi W  Cast W to Closes Ally to ur cursor", string.byte('Z'))
        end)
        Menu.NewTree("Prediction", "Prediction Options", function()
            Menu.Slider("Chance.Q","Q HitChance", 0.6, 0, 1, 0.05)
            Menu.Slider("Chance.E","E HitChance", 0.4, 0, 1, 0.05)
        end)
        Menu.NewTree("Range", "Spell Range Options", function()
            Menu.Slider("Max.Q","[Q] Max Range", 1025, 600, 1075)
        end)
        Menu.NewTree("Draw", "Drawing Options", function()
            Menu.NewTree("SoulDrawing","Soul Options",function ()
                Menu.Checkbox("DrawAroundSoul","Draw Around Soul",true)
                Menu.ColorPicker("AroundSoulcolor", "Draw Around Soul Color", 0xFFFFFFFF)
            end)
            Menu.Checkbox("Drawing.Q.Enabled",   "Draw [Q] Range",true)
            Menu.ColorPicker("Drawing.Q.Color", "Draw [Q] Color", 0x118AB2FF)
            Menu.Checkbox("Drawing.W.Enabled",   "Draw [W] Range",false)
            Menu.ColorPicker("Drawing.W.Color", "Draw [W] Color", 0x118AB2FF)
            Menu.Checkbox("Drawing.E.Enabled",   "Draw [E] Range",true)
            Menu.ColorPicker("Drawing.E.Color", "Draw [E] Color", 0x118AB2FF)
            Menu.Checkbox("Drawing.R.Enabled",   "Draw [R] Range",false)
            Menu.ColorPicker("Drawing.R.Color", "Draw [R] Color", 0x118AB2FF)
        end)
    end)     
end

-- LOAD
function OnLoad()
    Thresh.LoadMenu()
    for eventName, eventId in pairs(Enums.Events) do
        if Thresh[eventName] then
            EventManager.RegisterCallback(eventId, Thresh[eventName])
        end
    end    
    return true
end