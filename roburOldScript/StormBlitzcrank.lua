--[[
 +-+-+-+-+-+ +-+-+-+-+-+-+-+-+-+-+
 |S|t|r|o|m| |B|l|i|t|z|c|r|a|n|k|
 +-+-+-+-+-+ +-+-+-+-+-+-+-+-+-+-+
]]
if Player.CharName ~= "Blitzcrank" then return end
require("common.log")
module("Storm Blitzcrank", package.seeall, log.setup)
clean.module("Storm Blitzcrank", clean.seeall, log.setup)
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
local Blitzcrank = {}
local BlitzcrankHP = {}
local BlitzcrankNP = {}
local Bufflist = {"talentreaperstacksone","talentreaperstackstwo","talentreaperstacksthree"}
local IsGrabbed = false
local totalChampsgrabbed = 0
local Marksman = {"Varus","Aphelios","Xayah","Lucian","Draven","Vayne","MissFortune","Sivir","Tristana","Jinx","Ezreal","KogMaw","Jhin","Senna","Twitch","Samira","Kaisa","Caitlyn","Kindred","Kalista","Ashe"}
-- spells
local Q = Spell.Skillshot({
    Slot = Enums.SpellSlots.Q,
    Range = 1079,
    Radius = 70,
    Speed = 1800,
    UseHitbox = true,
    Delay = 0.25,
    Collisions = {Heroes = true, WindWall = true},
    Type = "Linear",
    Key = "Q",
})
local Q2 = Spell.Skillshot({
    Slot = Enums.SpellSlots.Q,
    Range = 1079,
    Radius = 70,
    Speed = 1800,
    UseHitbox = true,
    Delay = 0.25,
    Collisions = {Heroes = true,Minions = true, WindWall = true},
    Type = "Linear",
    Key = "Q2",
})
local W = Spell.Active({
    Slot = Enums.SpellSlots.W,
    Delay = 0,
    Key = "W",

})
local E = Spell.Active({
    Slot = Enums.SpellSlots.E,
    Key = "E",

})
local R = Spell.Active({
    Slot = Enums.SpellSlots.R,
    Range = 600,
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

function Blitzcrank.OnHighPriority() 
    if not GameIsAvailable() then
        return
    end
    if Blitzcrank.Auto() then return end
    local ModeToExecute = BlitzcrankHP[Orbwalker.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end

function Blitzcrank.OnNormalPriority()
    if not GameIsAvailable() then
        return
    end
    local ModeToExecute = BlitzcrankNP[Orbwalker.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end


-- DRAW
function Blitzcrank.OnDraw()
    local Pos = Player.Position
   
    local spells = {Q,R}
    for k, v in pairs(spells) do
        if Menu.Get("Drawing."..v.Key..".Enabled", true) and v:IsReady() then
            Renderer.DrawCircle3D(Pos, v.Range, 30, 3, Menu.Get("Drawing."..v.Key..".Color"))
        end
    end
    if Menu.Get("DrawText") then 
        Renderer.DrawText(Geometry.Vector(math.floor(Renderer.GetResolution().x) * 0.5 + 750, math.floor(Renderer.GetResolution().y) * 0.07, 0),
        Geometry.Vector(200, 15,0),"total Champs grabbed = " .. totalChampsgrabbed ,Menu.Get("color"))
    end
    if Menu.Get("DrawMulitper") then 
        Renderer.DrawText(Geometry.Vector(math.floor(Renderer.GetResolution().x) * 0.5 + 750, math.floor(Renderer.GetResolution().y) * 0.085, 0),
        Geometry.Vector(200,15,0),"Current WIDTH Multiper = " ..  Menu.Get("Mulitper") .. " + 25" ,Menu.Get("color"))
    end
end

local function CollisionSearchMinions(startPos, endPos, width, speed, delay, maxResults, allyOrEnemy, handlesToIgnore)
    if not maxResults then maxResults = 1 end
    if type(handlesToIgnore) ~= "table" then handlesToIgnore = {} end    
    if type(allyOrEnemy) ~= "string" or allyOrEnemy ~= "ally" then allyOrEnemy = "enemy" end

    local res = {Result = false, Positions = {}, Objects = {}}    
    local dist = startPos:Distance(endPos)

    local minionList = {ObjManager.Get(allyOrEnemy, "minions")}
    if allyOrEnemy == "enemy" then minionList[2] = ObjManager.Get("neutral", "minions") end
    
    for k, minions in ipairs(minionList) do
        for k, obj in pairs(minions) do        
            if not handlesToIgnore[k] then        
                local minion = obj.AsAI
                if obj.Position:Distance(startPos) < dist and not minion.IsDead and minion.IsTargetable and minion.MaxHealth > 5 then
                    local pos = minion:FastPrediction(delay/1000 + minion:EdgeDistance(startPos) / speed)            
                    local isOnSegment, pointSegment, pointLine = pos:ProjectOn(startPos, endPos)
                    local lineDist = pointSegment:Distance(pos)
                    if isOnSegment and lineDist < (minion.BoundingRadius + width * Menu.Get("Mulitper") + 25) then
                        res.Result = true
                        insert(res.Positions, pos:Extended(pointSegment, lineDist):SetHeight(startPos.y))
                        insert(res.Objects, minion)
                        if #res.Positions >= maxResults then break end
                    end
                end
            end
        end
    end    
       
    return res
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

local function Getallies()
    local allies = {}
    for k, v in pairs(ObjManager.Get("ally", "heroes")) do
        local hero = v.AsHero
        insert(allies,hero)
    end
    return  allies
end

local function KS(spell)
    return Menu.Get("KS."..spell.Key) and spell:IsReady()
end


-- CALLBACKS
function Blitzcrank.Auto()
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

function Blitzcrank.OnBuffGain(obj, buffInst)
    if not (obj.IsEnemy) then return end
    if buffInst.Name == "rocketgrab2" then IsGrabbed = true
        totalChampsgrabbed = totalChampsgrabbed + 1
    return end
    
end

function Blitzcrank.OnBuffLost(obj, buffInst)
    if not (obj.IsEnemy) then return end
    if buffInst.Name == "rocketgrab2" then IsGrabbed = false return end
end

function Blitzcrank.OnInterruptibleSpell(source, spell, danger, endT, canMove)
    if not (source.IsEnemy and Menu.Get("Misc.QI") and Q:IsReady() and danger > 2) then return end
    if not Menu.Get("1" .. source.AsHero.CharName) then return end
    if Q2:CastOnHitChance(source,Enums.HitChance.VeryHigh) then
        return 
    end
end

function Blitzcrank.OnGapclose(Source, DashInstance)
    if Source.IsEnemy and Q:IsReady() and Menu.Get("Misc.QGap") then 
        for k, v in pairs(Marksman) do
            for l,list in pairs(Getallies()) do 
                if v == list.CharName then 
                    if not Menu.Get("2" .. list.CharName) then return end
                    if Source:Distance(list) < 400 and Q2:CastOnHitChance(Source,Enums.HitChance.VeryHigh) then return end
                end
            end
        end
    end
    if not (Menu.Get("RGrab") and Source.IsEnemy and R:IsReady() and Orbwalker.GetMode() == "Combo") or not IsGrabbed then return end
    local function CastR()
        return #TS:GetTargets(R.Range, true) >=  1 and R:Cast()
    end
    if E:IsReady() then delay(1000, CastR) return end
    if #TS:GetTargets(R.Range, true) >= 1 and R:Cast() then return end
end

function Blitzcrank.OnPreAttack(args)
    local mode = Orbwalker.GetMode()
    if Menu.Get("Support") and args.Target.IsMinion and not args.Target.IsMonster and CountHeroes(Player,1000,"ally") > 1 then
        if mode == "Harass" then args.Process = false return end
        if mode ~= "Waveclear" then return end
        for k,v in pairs(Bufflist) do 
            if Player:GetBuff(v) then return end
        end
        args.Process = false
    end
    if not args.Target or not E:IsReady() then return end
    if mode == "Combo" and args.Target.IsHero then 
        if CanCast(E,mode) then 
            if E:Cast() then return end
        end
    end
end

-- RECALLERS
function BlitzcrankHP.Combo()
    local mode = "Combo"
    if CanCast(Q,mode) then 
        for k,v in pairs(GetTargetsRange(Menu.Get("Max.Q"))) do 
            if v:Distance(Player) < Menu.Get("Min.Q") then return end
            local collision = CollisionSearchMinions(Player.Position,v.Position,Q.Radius,Q.Speed,Q.Delay)
            if collision.Result then return end
            if not Menu.Get(v.CharName) then return end
            if Q:CastOnHitChance(v,HitChance(Q)) then return end
        end
    end
    
    if CanCast(R,mode) then
        if #TS:GetTargets(R.Range, true) >= Menu.Get("RH") then 
            if R:Cast() then return end
        end 
    end
end

function  BlitzcrankNP.Combo()
    local mode = "Combo"
    if CanCast(W,mode) and W:GetManaCost() + Q:GetManaCost() < Player.Mana and Q:IsReady() then
        for k,v in pairs(GetTargetsRange(Menu.Get("Max.Q") + 400)) do 
            if v:Distance(Player) < Menu.Get("Max.Q") / 1.5 or v:Distance(Renderer.GetMousePos()) > 350 then return end
            if W:Cast() then return end
        end
    end
end

function BlitzcrankHP.Harass()
    if Menu.Get("ManaSlider") > Player.ManaPercent * 100 then return end
    local mode = "Harass"
    if CanCast(Q,mode) then 
        for k,v in pairs(GetTargetsRange(Menu.Get("Max.Q"))) do 
            if v:Distance(Player) < Menu.Get("Min.Q") then return end
            local collision = CollisionSearchMinions(Player.Position,v.Position,Q.Radius,Q.Speed,Q.Delay)
            if collision.Result then return end
            if not Menu.Get(v.CharName) then return end
            if Q:CastOnHitChance(v,HitChance(Q)) then return end
        end
    end
end

-- MENU
function Blitzcrank.LoadMenu()
    Menu.RegisterMenu("StormBlitzcrank", "Storm Blitzcrank", function()
        Menu.Checkbox("Support",   "Support Mode", true)
        Menu.NewTree("Combo", "Combo Options", function()
            Menu.Checkbox("Combo.CastQ",   "Use [Q]", true)
            Menu.Checkbox("Combo.CastW",   "Use [W]", true)
            Menu.Checkbox("Combo.CastE",   "Use [E]", true)
            Menu.Checkbox("Combo.CastR",   "Use [R] ", true)
            Menu.Checkbox("RGrab",   "Force [R] after Grab", true)
            Menu.Slider("RH","^ when x >=",2,1,5)
        end)
        Menu.NewTree("Harass", "Harass Options", function()
            Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
            Menu.Slider("ManaSlider","",50,0,100)
            Menu.Checkbox("Harass.CastQ",   "Use [Q]", true)
        end)
        Menu.NewTree("Q", "Q Whitelist", function()
            for _, Object in pairs(ObjManager.Get("enemy", "heroes")) do
                local Name = Object.AsHero.CharName
                Menu.Checkbox(Name, "Use on " .. Name, true)
            end
        end)
        Menu.NewTree("KS", "KillSteal Options", function()
            Menu.Checkbox("KS.I"," Use Ignite to Ks", true)
        end)
        Menu.NewTree("Misc", "Misc Options", function()
            Menu.Checkbox("Misc.I"," Auto Ignite ", false)
            Menu.Slider("Misc.AI"," ^ When Hp < x ", 20,0,100)
            Menu.Checkbox("Misc.QI",   "Use [Q] on Interrupter", true)
            Menu.NewTree("Interrupter", "Interrupter Whitelist", function()
                for _, Object in pairs(ObjManager.Get("enemy", "heroes")) do
                    local Name = Object.AsHero.CharName
                    Menu.Checkbox("1" .. Name, "Use on " .. Name, true)
                end
            end)
            Menu.Checkbox("Misc.QGap",   "Use [Q] on gapclose", true)
            Menu.NewTree("gapclose", "Anti ally gapcloser", function()
                for k, v in pairs(Marksman) do
                    for l,list in pairs(Getallies()) do 
                        if v == list.CharName then 
                            Menu.Checkbox("2" .. list.CharName, "Use on " .. list.CharName, true)
                        end
                    end
                end
            end)
        end)
        Menu.NewTree("Prediction", "Prediction Options", function()
            Menu.Slider("Chance.Q","Q HitChance", 0.75, 0, 1, 0.05)
        end)
        Menu.NewTree("Range", "Spell Range Options", function()
            Menu.Slider("Max.Q","[Q] Max Range", 950, 600, 1079)
            Menu.Slider("Min.Q","[Q] Min Range", 350, 200, 600)
        end)
        Menu.NewTree("Draw", "Drawing Options", function()
            Menu.Checkbox("Drawing.Q.Enabled",   "Draw [Q] Range",true)
            Menu.ColorPicker("Drawing.Q.Color", "Draw [Q] Color", 0x118AB2FF)
            Menu.Checkbox("Drawing.R.Enabled",   "Draw [R] Range",false)
            Menu.ColorPicker("Drawing.R.Color", "Draw [R] Color", 0x118AB2FF)
        end)
        Menu.NewTree("OP", "Extra Misc Options", function()
            Menu.Checkbox("DrawText",   "Draw Total grabed Champs ",true)
            Menu.ColorPicker("color", "Text Color", 0xFFFFFFFF)
            Menu.Checkbox("DrawMulitper",   "Draw Width Mulitperper",false)
            Menu.Slider("Mulitper","Mulitper",1,0.5,1.5, 0.01)
            Menu.ColoredText("increase if you hit minions decrease to hit target between minions",0xFFFFFFFF,true)
        end)
    end)     
end

-- LOAD
function OnLoad()
    Blitzcrank.LoadMenu()
    for eventName, eventId in pairs(Enums.Events) do
        if Blitzcrank[eventName] then
            EventManager.RegisterCallback(eventId, Blitzcrank[eventName])
        end
    end    
    return true
end