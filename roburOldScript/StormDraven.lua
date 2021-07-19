--[[
 +-+-+-+-+-+ +-+-+-+-+-+-+
 |S|t|r|o|m| |D|r|a|v|e|n|
 +-+-+-+-+-+ +-+-+-+-+-+-+
]]
if Player.CharName ~= "Draven" then return end
require("common.log")
module("Storm Draven", package.seeall, log.setup)
clean.module("Storm Draven", clean.seeall, log.setup)
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
local Draven = {}
local DravenHP = {}
local DravenNP = {}
local AxeList = {
    endtime = {}
}
local AxeRadius = 176.7767 - Player.BoundingRadius

-- spells
local Q = Spell.Active({
    Slot = Enums.SpellSlots.Q,
    Key = "Q",
})
local W = Spell.Active({
    Slot = Enums.SpellSlots.W,
    Range =  550,
    Key = "W",

})
local E = Spell.Skillshot({
    Slot = Enums.SpellSlots.E,
    Range =  1050,
    Delay = 0.25,
    Speed = 1400,
    Radius = 130,
    Collision = {WindWall=true},
    Key = "E",
    Type = "Linear"
})
local R = Spell.Skillshot({
    Slot = Enums.SpellSlots.R,
    Range = 3000,
    Delay = 0.5,
    Speed = 2000,
    Radius = 160,
    Key = "R",
    Collision = {WindWall=true,heroes=true},
    Type = "Linear"
})


local function GameIsAvailable()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

local function dmg(spell)
    local dmg = 0
    if spell.Key == "R" then
        local dmgMuiltpler = {1.1,1.3,1.5}
        dmg = (175 + (spell:GetLevel() - 1) * 100) + (dmgMuiltpler[spell:GetLevel()] * Player.BonusAD)
    end
    if spell.Key == "E" then 
        dmg = (75 + (spell:GetLevel() - 1) * 35) + (0.5 * Player.BonusAD)
    end
    return dmg
end

function Draven.OnHighPriority() 
    if not GameIsAvailable() then
        return
    end
    local ModeToExecute = DravenHP[Orbwalker.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end

function Draven.OnNormalPriority()
    if not GameIsAvailable() then
        return
    end
    if Draven.Auto() then return end
    local ModeToExecute = DravenNP[Orbwalker.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end


-- DRAW
function Draven.OnDraw()
    local Pos = Player.Position
   
    local spells = {E,R}
    for k, v in pairs(spells) do
        if Menu.Get("Drawing."..v.Key..".Enabled", true) and v:IsReady() then
            Renderer.DrawCircle3D(Pos, v.Range, 30, 3, Menu.Get("Drawing."..v.Key..".Color"))
        end
    end
    if Menu.Get("DrawAroundMouse") then
        Renderer.DrawCircle3D(Renderer.GetMousePos(), Menu.Get("Misc.AxeMark"), 30, 3, Menu.Get("Cursorcolor"))
    end
    if Menu.Get("DrawAroundAxe") then
        for k,v in pairs(AxeList) do
            if not v.IsDead and v.IsValid then
                Renderer.DrawCircle3D(v.Position, v.BoundingRadius, 30, 3, Menu.Get("AroundAxecolor"))
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

local function CountAxe()
    local buff = Player:GetBuff("DravenSpinningAttack")
    local buffCount = 0
    if buff then buffCount = buff.Count end
    local markCount = #(AxeList)

    local flyingAxes = 0
    for k, v in pairs(ObjManager.Get("all", "missiles")) do
        if v.IsValid and v.Name == "DravenSpinningAttack" then 
            flyingAxes = flyingAxes + 1
        end
    end
    return buffCount + markCount + flyingAxes
end

local function CountHeroes(pos,Range)
    local num = 0
    for k, v in pairs(ObjManager.Get("enemy", "heroes")) do
        local hero = v.AsHero
        if hero and hero.IsTargetable and hero:Distance(pos.Position) < Range then
            num = num + 1
        end
    end
    return num
end

local function Lane(spell)
    return Menu.Get("Lane."..spell.Key) and spell:IsReady()
end

local function LastHit(spell)
    return Menu.Get("LastHit."..spell.Key) and spell:IsReady()
end

local function Structure(spell)
    return Menu.Get("Structure."..spell.Key) and spell:IsReady()
end

local function KS(spell)
    return Menu.Get("KS."..spell.Key) and spell:IsReady()
end

local function Jungle(spell)
    return Menu.Get("Jungle."..spell.Key) and spell:IsReady()
end


-- CALLBACKS
function Draven.Auto()
    if KS(E) then 
        for k,v in pairs(GetTargets(E)) do
            if v then
                local dmg = DmgLib.CalculateMagicalDamage(Player,v,dmg(E))
                local Ks  = E:GetKillstealHealth(v)
                if dmg > Ks and E:CastOnHitChance(v,HitChance(E)) then return end
            end
        end
    end
end
function Draven.OnInterruptibleSpell(source, spell, danger, endT, canMove)
    if not (source.IsEnemy and Menu.Get("Misc.EI") and E:IsReady() and danger > 2) then return end
    if not Menu.Get("1" .. source.AsHero.CharName) then return end
    if E:CastOnHitChance(source,Enums.HitChance.VeryHigh) then
        return 
    end
end

function Draven.OnGapclose(Source, DashInstance)
    if not (Source.IsEnemy) then return end
    if not Menu.Get("2" .. Source.AsHero.CharName) then return end
    if Menu.Get("Misc.EGap") and E:IsReady() and E:CastOnHitChance(Source,Enums.HitChance.VeryHigh) then
        return 
    end
end

function Draven.OnPreAttack(args)
    local mode = Orbwalker.GetMode()
    local Target = args.Target.AsAI
    if not Target then return end
    if mode == "Combo" then 
        if CanCast(Q,mode) then 
            Draven.CastQ("ComboAxeSlider")
        end
        if CanCast(W,mode) then 
            W:Cast()
        end
    end
    if mode == "Harass" then 
        if Menu.Get("ManaSlider") > Player.ManaPercent * 100 then return end
        if CanCast(Q,mode) then 
            Draven.CastQ("HarassAxeSlider")
        end
        if CanCast(W,mode) and Target.IsHero then 
            Draven.CastW()
        end
    end
    if mode == "Waveclear" then 
        if Target.MaxHealth < 6 then return end
        if W:IsReady() and Jungle(W) and Target.IsMonster then W:Cast() end
        if Q:IsReady() and Lane(Q) and Target.IsMonster then Draven.CastQ("LaneAxeSlider") end
        if Menu.Get("ManaSliderLane") > Player.ManaPercent * 100 then return end
        if W:IsReady() and Structure(W) and Target.IsTurret then W:Cast() end
        if Q:IsReady() and Lane(Q) and Target.IsMinion then Draven.CastQ("LaneAxeSlider") end
        if W:IsReady() and Lane(W) and Count(W,"enemy","minions") >= Menu.Get("Lane.WH") and Target.IsMinion then W:Cast() end
        
    end
    if mode == "Lasthit" then 
        if Target.MaxHealth < 6 then return end
        if Q:IsReady() and LastHit(Q) and CountAxe() < 1 and Target.IsMinion then Q:Cast() end
    end
end

function Draven.OnPostAttack(targets)
    local Target = targets.AsAI
    local mode = Orbwalker.GetMode()
    if not Target or not E:IsReady() then return end
    if Target.IsHero and mode == "Combo" then 
        if CanCast(E,mode) then  
            if E:CastOnHitChance(Target,HitChance(E)) then return end
        end
    end
end

function Draven.OnPreMove(args)
    for k,v in pairs(AxeList) do
        for k2,time in pairs(AxeList.endtime) do
            if not v.IsDead and v.IsValid then 
                local endPos = Player.Pathing.EndPos
                if not Menu.Get("Catch") then return end
                if Menu.Get("Misc.PathFind") and v:Distance(endPos) > Menu.Get("Misc.Path") then return end
                if Menu.Get("Misc.AxeMarkTower") and IsUnderTurrent(v.Position) then return end
                if Menu.Get("Misc.BlockMovement") and v:Distance(Player) < AxeRadius then
                    args.Process = false
                    return 
                end
                if v:Distance(Player) < AxeRadius * 0.7 then return end
                
                if v:Distance(Renderer.GetMousePos()) > Menu.Get("Misc.AxeMark") then return end
                if Menu.Get("Misc.WAxe") and W:IsReady() and v:Distance(Player) / Player.MoveSpeed * 1000 > (time - Game.GetTime() * 1000) then 
                    W:Cast()
                end
                args.Process = false
                Input.MoveTo(v.Position)
            end
        end
    end
end

function Draven.OnCreateObject(obj)
    if obj ~= nil and string.match(obj.Name,"Draven_") and string.match(obj.Name,"_Q_reticle_self") then
        table.insert(AxeList,obj)
        table.insert(AxeList.endtime, Game.GetTime() * 1000 + 1290)
    end
end

function Draven.OnDeleteObject(obj)
    if obj ~= nil and string.match(obj.Name,"Draven_") and string.match(obj.Name,"_Q_reticle_self") then
        for k,v in pairs(AxeList) do 
            if v.NetworkId == obj.NetworkId then 
                table.remove(AxeList,k)
                table.remove(AxeList.endtime,k)
            end
        end
    end
end

function Draven.OnBuffGain(obj, buffInst)
    if not W:IsReady() or not obj.IsHero or not obj.IsMe or not Menu.Get("Misc.AutoWonSlow")  then return end
    if buffInst.BuffType == Enums.BuffTypes.Slow then 
        W:Cast()
    end
end

-- RECALLERS
function DravenHP.Combo()
    local mode = "Combo"
    if CanCast(W,mode) then 
        Draven.CastW()
    end
    if CanCast(R,mode) then
        for k,v in pairs(GetTargets(R)) do
            if v then
                if v:Distance(Player) < Menu.Get("R.Min") or v:Distance(Player) > Menu.Get("R.Max") then return end
                local dmg = DmgLib.CalculateMagicalDamage(Player,v,dmg(R) * Menu.Get("DmgSlider"))
                local Ks  = R:GetKillstealHealth(v)
                if dmg > Ks and R:CastOnHitChance(v,HitChance(R)) then return end
            end
        end
    end
end

function DravenHP.Harass()
    
end
function DravenNP.Harass() 
   
end

function DravenNP.Waveclear() 
    if Menu.Get("ManaSliderLane") > Player.ManaPercent * 100 then return end
    if Lane(E) then 
        local Epoints = {}
        for k,v in pairs(ObjManager.Get("enemy", "minions")) do
        local minion = v.AsAI
        local minionInRange = E:IsInRange(minion) and minion.IsTargetable and minion.MaxHealth > 6
        local pos = minion:FastPrediction(Game.GetLatency()+ E.Delay)
            if minionInRange then
                insert(Epoints, pos)
            end
        end
        local bestPos, hitCount = E:GetBestLinearCastPos(Epoints, E.Radius)
        if bestPos and hitCount >= Menu.Get("Lane.EH") then
            E:Cast(bestPos)
        end
    end
end

-- spell casts
function Draven.CastQ(value)
    if Menu.Get(value) <= CountAxe() then return end
    Q:Cast()
end

function Draven.CastW()
    for k,v in pairs(GetTargetsRange(1500)) do
        if v:Distance(Player) > Player.AttackRange and v:Distance(Renderer.GetMousePos()) <= 250 then 
            if W:Cast() then return end
        end
    end
end


-- MENU
function Draven.LoadMenu()
    Menu.RegisterMenu("StormDraven", "Storm Draven", function()
        Menu.NewTree("Combo", "Combo Options", function()
            Menu.Checkbox("Combo.CastQ",   "Use [Q]", true)
            Menu.Slider("ComboAxeSlider","^ Only if Total Axes < x",2,1,3)
            Menu.Checkbox("Combo.CastW",   "Use [W]", true)
            Menu.Checkbox("Combo.CastE",   "Use [E]", true)
            Menu.Checkbox("Combo.CastR",   "Use [R] | Only When Killable", true)
            Menu.Slider("R.Min","Min R Range", 1000, 500, 2500)
            Menu.Slider("R.Max","Max R Range", 3000, 1500, 3000)
            Menu.Slider("DmgSlider","R dmg calculation | Both or one",1,1,2)
        end)
        Menu.NewTree("Harass", "Harass Options", function()
            Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
            Menu.Slider("ManaSlider","",50,0,100)
            Menu.Checkbox("Harass.CastQ",   "Use [Q]", true)
            Menu.Slider("HarassAxeSlider","^ Only if Total Axes < x",2,1,3)
            Menu.Checkbox("Harass.CastW",   "Use [W]", false)
        end)
        Menu.NewTree("WaveClear", "WaveClear Options", function()
            Menu.NewTree("Lane", "Lane", function()
                Menu.ColoredText("Mana Percent limit", 0xFFD700FF, true)
                Menu.Slider("ManaSliderLane","",50,0,100)
                Menu.Checkbox("Lane.Q","Use [Q]", true)
                Menu.Slider("LaneAxeSlider","^ Only if Total Axes < x",2,1,3)
                Menu.Checkbox("Lane.W","Use [W]", true)
                Menu.Slider("Lane.WH", "When | X Minions Around", 3,1,5)
                Menu.Checkbox("Lane.E","Use [E]", true)
                Menu.Slider("Lane.EH", "E HitCount", 5,1,5)
            end)
            Menu.NewTree("LastHit", "Lasthit Options", function()
                Menu.Checkbox("LastHit.Q","Use [Q]", true)
            end)
            Menu.NewTree("Jungle", "Jungle", function()
                Menu.Checkbox("Jungle.Q",   "Use [Q]", true)
                Menu.Checkbox("Jungle.W",   "Use [W]", true)
            end)
            Menu.NewTree("Structure", "Structure Options", function()
                Menu.Checkbox("Structure.W","Use [W]", true)
            end)
        end)
        Menu.NewTree("KS", "KillSteal Options", function()
            Menu.Checkbox("KS.E"," Use [E] to Ks", true)
        end)
        Menu.NewTree("MiscAxe","Axe Options",function ()
            Menu.Checkbox("Catch", "Catch Axe", true)
            Menu.Slider("Misc.AxeMark", "Magnet To AxeMark | If Distance To Mouse <= x", 600, 350, 750)
            Menu.Checkbox("Misc.AxeMarkTower", "Dont Catch | If Axe Under Enemy Turret",true)
            Menu.Checkbox("Misc.WAxe", "Cast W | If Axe too Far",true)
            Menu.Checkbox("Misc.BlockMovement", "Block Movement | If Axe Close",false)
            Menu.Checkbox("Misc.PathFind", "use Pathfinding | Only Catch when close to path",false)
            Menu.Slider("Misc.Path", "^ Catch when Distance to Path < x ",200,100,450)
        end)
        Menu.NewTree("Misc", "Misc Options", function()
            Menu.Checkbox("Misc.AutoWonSlow","Auto W On Slow",true)
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
        end)
        Menu.NewTree("Prediction", "Prediction Options", function()
            Menu.Slider("Chance.E","E HitChance", 0.75, 0, 1, 0.05)
            Menu.Slider("Chance.R","R HitChance", 0.75, 0, 1, 0.05)
        end)
        Menu.NewTree("Draw", "Drawing Options", function()
            Menu.NewTree("AxeDrawing","Axe Options",function ()
                Menu.Checkbox("DrawAroundMouse","Draw Magnet Range on Cursor",true)
                Menu.ColorPicker("Cursorcolor", "Draw Around Cursor Color", 0x118AB2FF)
                Menu.Checkbox("DrawAroundAxe","Draw Around Axe",true)
                Menu.ColorPicker("AroundAxecolor", "Draw Around Axe Color", 0xFFFFFFFF)
            end)
            Menu.Checkbox("Drawing.E.Enabled",   "Draw [E] Range",false)
            Menu.ColorPicker("Drawing.E.Color", "Draw [E] Color", 0x118AB2FF)
        end)
    end)     
end


-- LOAD
function OnLoad()
    Draven.LoadMenu()
    for eventName, eventId in pairs(Enums.Events) do
        if Draven[eventName] then
            EventManager.RegisterCallback(eventId, Draven[eventName])
        end
    end    
    return true
end