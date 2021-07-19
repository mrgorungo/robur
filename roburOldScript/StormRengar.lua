--[[
 +-+-+-+-+-+ +-+-+-+-+-+-+
 |S|t|r|o|m| |R|e|n|g|a|r|
 +-+-+-+-+-+ +-+-+-+-+-+-+
]]
if Player.CharName ~= "Rengar" then return end
require("common.log")
module("Storm Rengar", package.seeall, log.setup)
clean.module("Storm Rengar", clean.seeall, log.setup)
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
local Rengar = {}
local RengarHP = {}
local RengarNP = {}
local stacks = 0
-- spells
local Q = Spell.Active({
    Slot = Enums.SpellSlots.Q,
    Key = "Q",
})
local W = Spell.Active({
    Slot = Enums.SpellSlots.W,
    Range =  450,
    Delay = 0,
    Key = "W",
    LastW = os.clock()
})
local E = Spell.Skillshot({
    Slot = Enums.SpellSlots.E,
    Range =  1000,
    Delay = 0.25,
    Speed = 1500,
    Radius = 70,
    Collisions = { Heroes = true, Minions = true, WindWall = true},
    Key = "E",
    Type = "Linear",
})
local LastDash = os.clock()
local R = Spell.Active({
    Slot = Enums.SpellSlots.R,
    Key = "R",
})


local function GameIsAvailable()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

local function dmg(spell)
    local dmg = 0
    if spell.Key == "E" then
        dmg = (55 + (E:GetLevel() - 1) * 45) + (0.8 * Player.BonusAD)
    end
    local QBaseAd = {1,1.05,1.10,1.15,1.20}
    if spell.Key == "Q" then
        dmg = (30 + (Q:GetLevel() - 1) * 30) + (QBaseAd[Q:GetLevel()] * Player.TotalAD)
    end
    return dmg
end
function Rengar.OnExtremePriority() 
    if not GameIsAvailable() then return end  
    if not Player:GetBuff("rengarq") and not Player:GetBuff("rengarqemp") or stacks > 4 then
        stacks = Player.Mana
    end
end

function Rengar.OnHighPriority() 
    if not GameIsAvailable() then
        return
    end  
    if Player:GetBuff("RengarR") then return end
    if Rengar.Auto() then return end

    local ModeToExecute = RengarHP[Orbwalker.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end

function Rengar.OnNormalPriority()
    if not GameIsAvailable() then
        return
    end
    if Player:GetBuff("RengarR") then return end
    local ModeToExecute = RengarNP[Orbwalker.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end


-- DRAW
function Rengar.OnDraw()
    local Pos = Player.Position
    local spells = {W,E}
    for k, v in pairs(spells) do
        if Menu.Get("Drawing."..v.Key..".Enabled", true) and v:IsReady() then
            Renderer.DrawCircle3D(Pos, v.Range, 30, 3, Menu.Get("Drawing."..v.Key..".Color"))
        end
    end
    if Menu.Get("DrawText") then 
        local mode = nil 
        if Menu.Get("comboMode") == 0 then mode = "Q" end
        if Menu.Get("comboMode") == 1 then mode = "W" end
        if Menu.Get("comboMode") == 2 then mode = "E" end
        if mode == nil then return end
        Renderer.DrawText(Renderer.WorldToScreen(Player.Position) + Geometry.Vector(-45, 50, 0),
        Geometry.Vector(200, 15,0),"Combo Mode = " .. mode ,Menu.Get("color"))
    end
end


-- SPELL HELPERS
local function CanCast(spell,mode)
    return Menu.Get(mode .. ".Cast"..spell.Key)
end

local function HitChance(spell)
    return Menu.Get("Chance."..spell.Key)
end

local function Jungle(spell)
    return Menu.Get("Jungle."..spell.Key)
end

local function Structure(spell)
    return Menu.Get("Structure."..spell.Key)
end

local function Lane(spell)
    return spell:IsReady() and Menu.Get("Lane."..spell.Key)
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

local function KS(spell)
    return Menu.Get("KS."..spell.Key) and spell:IsReady()
end


-- CALLBACKS
function Rengar.Auto()
    if KS(E) then 
        for k, eTarget in pairs(GetTargets(E)) do
            local eDmg = DmgLib.CalculatePhysicalDamage(Player, eTarget, dmg(E))
            local ksHealth = E:GetKillstealHealth(eTarget)
            if  eDmg > ksHealth and E:CastOnHitChance(eTarget, HitChance(E)) then
                return
            end
        end
    end
end
function Rengar.OnProcessSpell(obj, spellcast)
    if not obj.IsMe then return end
    if spellcast.Name == "RengarQAttack" then 
        stacks = stacks + 1
    end
    if spellcast.Name == "RengarE" then 
        stacks = stacks + 1
    end
    if spellcast.Name == "RengarEEmp" then 
        stacks = stacks + 1
    end
    if spellcast.Name == "RengarW" then 
        stacks = stacks + 1
        W.LastW = os.clock() + 0.25 + Game.GetLatency() / 1000
    end
    if spellcast.Name == "RengarWEmp" then 
        stacks = stacks + 1
        W.LastW = os.clock() + 0.25 + Game.GetLatency() / 1000
    end
    if spellcast.Name == "RengarQEmpAttack" then 
        stacks = stacks + 1
    end
end

function Rengar.OnBuffGain(obj, buffInst)
    if obj.IsMe and buffInst.Name == "rengaroutofcombat" then
        stacks = 0
    end
    if not obj.IsMe or not string.match(W:GetName(), "Emp") or not Menu.Get("Misc.W")then return end
    if buffInst.BuffType == Enums.BuffTypes.Taunt or buffInst.BuffType == Enums.BuffTypes.Snare or buffInst.BuffType == Enums.BuffTypes.Charm or buffInst.BuffType == Enums.BuffTypes.Asleep or buffInst.BuffType == Enums.BuffTypes.Suppression or buffInst.BuffType == Enums.BuffTypes.Stun then 
        if W:Cast() then return end
    end
end

function Rengar.OnBuffLost(obj, buffInst)
    if not obj.IsMe then return end
    local time = os.clock()
    if buffInst.Name == "rengaroutofcombat" and LastDash > time then stacks = stacks + 1 end
end

function Rengar.OnGapclose(Source, Dash)
    if not Source.IsMe then return end
    local mode = Orbwalker.GetMode()
    if mode == "Combo" then 
        local paths = Dash:GetPaths()
        local time = Game.GetTime()
        if CanCast(Q,mode)  then delay((paths[#paths].EndTime - time) * 850,Rengar.CastQ,"comboMode") end
    end
    if mode == "Harass" then 
        local paths = Dash:GetPaths()
        local time = Game.GetTime()
        if CanCast(Q,mode)  then delay((paths[#paths].EndTime - time) * 850,Rengar.CastQ,"HarassMode") end
    end
    if mode == "Waveclear" then 
        local paths = Dash:GetPaths()
        local time = Game.GetTime()
        if Jungle(Q) then delay((paths[#paths].EndTime - time) * 850,Rengar.CastQWave,"WaveclearMode") end
    end
    if Player:GetBuff("rengaroutofcombat") then LastDash = os.clock() + 0.5 end
end

function Rengar.OnPreAttack(args)
    local Target = args.Target.AsAI
    local mode = Orbwalker.GetMode()
    if Menu.Get("Misc.C") and not (Q:IsReady() or Orbwalker.CanAttack or Player:GetBuff("rengarq") or Player:GetBuff("rengarqemp")) then 
        local pos = Renderer.GetMousePos()
        if pos:IsGrass() then 
            args.Process = false
        end
    end
    if not Target then return end
    if mode == "Combo" then 
        if CanCast(Q,mode) then 
            if Rengar.CastQ("comboMode") then return end
        end
    end
    if mode == "Harass" and Target.IsHero then 
        if CanCast(Q,mode) then 
            if Rengar.CastQ("HarassMode") then return end
        end
    end
    if mode == "Waveclear" and Target.IsMonster and Target.MaxHealth > 6 then 
        if Jungle(Q) then 
            if Rengar.CastQWave("WaveclearMode") then return end
        end
    end
end

function Rengar.OnPostAttack(target)
    local Target = target.AsAI
    local mode = Orbwalker.GetMode()
    if not Target then return end
    if mode == "Combo" and Target.IsHero  then 
        if CanCast(Q,mode) then 
            if Rengar.CastQ() then return end
        end
    end
    if mode == "Harass" and Target.IsHero then 
        if CanCast(Q,mode) then 
            if Rengar.CastQ() then return end
        end
    end
    if mode == "Waveclear" and Target.IsMonster and Target.MaxHealth > 6 then 
        if Jungle(Q) then 
            if Rengar.CastQWave() then return end
        end
    end
    if Target.IsStructure and Structure(Q) then 
        if Rengar.CastQWave("WaveclearMode") then return end
    end
    if Target.IsStructure and Structure(W) then 
        if Rengar.CastWWave("WaveclearMode") then return end
    end
    if Target.IsStructure and Structure(E) then 
        if Rengar.CastEWave("WaveclearMode",Target.Position) then return end
    end
end


-- RECALLERS
function RengarHP.Combo()
    local mode = "Combo"
    if Player:GetBuff("rengarpassivebuff") and Menu.Get("Misc.P") then return end
    if CanCast(W,mode) then 
        if Rengar.CastW("comboMode") then return end
    end
    if CanCast(E,mode) then 
        if Rengar.CastE("comboMode") then return end
    end
end

function  RengarNP.Combo()
    local mode = "Combo"
    if Player:GetBuff("rengarpassivebuff") and Menu.Get("Misc.P") then return end
    if CanCast(W,mode) then 
        if Rengar.CastW() then return end
    end
    if CanCast(E,mode) then 
        if Rengar.CastE() then return end
    end
end

function RengarHP.Harass()
    local mode = "Harass"
    if Player:GetBuff("rengarpassivebuff") and Menu.Get("Misc.P") then return end
    if CanCast(W,mode) then 
        if Rengar.CastW("HarassMode") then return end
    end
    if CanCast(E,mode) then 
        if Rengar.CastE("HarassMode") then return end
    end
end

function RengarNP.Harass()
    local mode = "Harass"
    if Player:GetBuff("rengarpassivebuff") and Menu.Get("Misc.P") then return end
    if CanCast(W,mode) then 
    if Rengar.CastW() then return end
    end
    if CanCast(E,mode) then 
        if Rengar.CastE() then return end
    end
end

function RengarNP.Waveclear()
    if Player:GetBuff("rengarpassivebuff") and Menu.Get("Misc.P") then return end
    if Lane(Q) then 
        for k, v in pairs(ObjManager.Get("enemy", "minions")) do 
            local minion = v.AsAI
            local trueRange = Player.AttackRange + 25
            local minionInRange = Player:Distance(minion) < trueRange and minion.MaxHealth > 6 and minion.IsTargetable
            if minionInRange then
                local healthPred = Q:GetHealthPred(minion)
                local QDmg = DmgLib.CalculatePhysicalDamage(Player, minion, dmg(Q))
                if healthPred > 0 and healthPred < QDmg then 
                    Orbwalker.StopIgnoringMinion(minion)
                    if Rengar.CastQWave("WaveclearMode") then return end 
                end    
            end                  
        end
    end
    if Lane(W) then 
        if Count(W,"enemy","minions") >= Menu.Get("Lane.WH") then
            if Rengar.CastWWave() then return end
        end
    end
    if Lane(E) then 
        for k, v in pairs(ObjManager.Get("enemy", "minions")) do 
            local minion = v.AsAI
            local minionInRange = E:IsInRange(minion) and minion.MaxHealth > 6 and minion.IsTargetable
            if minionInRange then
                local healthPred = E:GetHealthPred(minion)
                local EDmg = DmgLib.CalculatePhysicalDamage(Player, minion, dmg(E))
                if healthPred > 0 and healthPred < EDmg then 
                    local pos = Renderer.GetMousePos()
                    if minion:Distance(pos) < 250 and Rengar.CastELane("WaveclearMode",minion) then return end 
                end    
            end                  
        end
    end
    if Jungle(W) then 
        for k, v in pairs(ObjManager.Get("neutral", "minions")) do 
            local minion = v.AsAI
            local minionInRange = W:IsInRange(minion) and minion.MaxHealth > 6 and minion.IsTargetable
            if minionInRange then
                if Rengar.CastWWave("WaveclearMode") then return end     
            end                  
        end
    end
    if Jungle(E) then 
        for k, v in pairs(ObjManager.Get("neutral", "minions")) do 
            local minion = v.AsAI
            local minionInRange = E:IsInRange(minion) and minion.MaxHealth > 6 and minion.IsTargetable
            if minionInRange then
                if Rengar.CastEWave("WaveclearMode",minion.Position) then return end     
            end                  
        end
    end
end
-- spellcasts 
function Rengar.CastQ(MenuName)
    if not Q:IsReady() then return end
    local target = TS:GetTarget(270,true);
    if target ~= nil then 
        if not string.match(Q:GetName(), "Emp") and stacks <= 3 then 
            if Q:Cast() then return end
        end
        if MenuName == nil then return end
        if string.match(Q:GetName(), "Emp") and Menu.Get(MenuName) == 0 and not Menu.Get("Save") and stacks >= 4 then 
            if Q:Cast() then return end
        end
    end
end

function Rengar.CastQWave(MenuName)
    if not Q:IsReady() then return end
    if not string.match(Q:GetName(), "Emp") and stacks <= 3 then 
        if Q:Cast() then return end
    end
    if MenuName == nil then return end
    if string.match(Q:GetName(), "Emp") and Menu.Get(MenuName) == 0 and not Menu.Get("Save")  and stacks >= 4 then 
        if Q:Cast() then return end
    end
end

function Rengar.CastW(MenuName)
    local time = os.clock()
    if W.LastW > time then return end
    if not W:IsReady() then return end
    local target = TS:GetTarget(W.Range,true);
    if target ~= nil then 
        if not string.match(W:GetName(), "Emp") and stacks <= 3 then 
            if W:Cast() then return end
        end
        if MenuName == nil then return end
        if string.match(W:GetName(), "Emp") and Menu.Get(MenuName) == 1 and not Menu.Get("Save") and stacks >= 4 then 
            if W:Cast() then return end
        end
    end
end

function Rengar.CastWWave(MenuName)
if not W:IsReady() then return end
    if not string.match(W:GetName(), "Emp") and stacks <= 3 then 
        if W:Cast() then return end
    end
    if MenuName == nil then return end
    if string.match(W:GetName(), "Emp") and Menu.Get(MenuName) == 1 and not Menu.Get("Save") and stacks >= 4 then 
        if W:Cast() then return end
    end
end

function Rengar.CastE(MenuName)
    if not E:IsReady() then return end
    local target = TS:GetTarget(Menu.Get("Max.E"),true);
    if target ~= nil then 
        if not string.match(E:GetName(), "Emp") and stacks <= 3 then 
            if E:CastOnHitChance(target,HitChance(E)) then return end
        end
        if MenuName == nil then return end
        if string.match(E:GetName(), "Emp") and  Menu.Get(MenuName) == 2 and not Menu.Get("Save") and stacks >= 4 then 
            if E:CastOnHitChance(target,HitChance(E)) then return end
        end
    end
end

function Rengar.CastEWave(MenuName,t)
    if not E:IsReady() then return end
    if not string.match(E:GetName(), "Emp") and stacks <= 3 then 
        if E:Cast(t) then return end
    end
    if MenuName == nil then return end
    if string.match(E:GetName(), "Emp") and Menu.Get(MenuName) == 2 and not Menu.Get("Save") and stacks >= 4 then 
        if E:Cast(t) then return end
    end
end
function Rengar.CastELane(MenuName,t)
    if not E:IsReady() then return end
    if not string.match(E:GetName(), "Emp") and stacks <= 3 then 
        if E:CastOnHitChance(t,Enums.HitChance.Medium)  then return end
    end
    if MenuName == nil then return end
    if string.match(E:GetName(), "Emp") and Menu.Get(MenuName) == 2 and not Menu.Get("Save") and stacks >= 4 then 
        if E:CastOnHitChance(t,Enums.HitChance.Medium) then return end
    end
end

-- MENU
function Rengar.LoadMenu()
    Menu.RegisterMenu("StormRengar", "Storm Rengar", function()
        Menu.NewTree("Combo", "Combo Options", function()
            Menu.Dropdown("comboMode","Combo mode",0,{"Q", "W","E"})
            Menu.Checkbox("Combo.CastQ",   "Use [Q]", true)
            Menu.Checkbox("Combo.CastW",   "Use [W]", true)
            Menu.Checkbox("Combo.CastE",   "Use [E]", true)
        end)
        Menu.NewTree("Harass", "Harass Options", function()
            Menu.Dropdown("HarassMode","Harass mode",0,{"Q", "W","E"})
            Menu.Checkbox("Harass.CastQ",   "Use [Q]", true)
            Menu.Checkbox("Harass.CastW",   "Use [W]", true)
            Menu.Checkbox("Harass.CastE",   "Use [E]", true)
        end)
        Menu.NewTree("Waveclear", "Waveclear Options", function()
            Menu.Dropdown("WaveclearMode","Waveclear mode",0,{"Q", "W","E"})
            Menu.NewTree("Lane", "Lane Options", function()
                Menu.Checkbox("Lane.Q",   "Use [Q]", true)
                Menu.Checkbox("Lane.W",   "Use [W]", false)
                Menu.Slider("Lane.WH","W HitCount",3,1,5)
                Menu.Checkbox("Lane.E",   "Use [E] || only to last Hit minion Needs to be (Close to Curosr)", false)
            end)
            Menu.NewTree("Structure", "Structure Options", function()
                Menu.Checkbox("Structure.Q",   "Use [Q]", true)
                Menu.Checkbox("Structure.W",   "Use [W] || Only for Stacking ", false)
                Menu.Checkbox("Structure.E",   "Use [E] || Only for Stacking ", false)
            end)
            Menu.NewTree("Jungle", "Jungle Options", function()
                Menu.Checkbox("Jungle.Q",   "Use [Q]", true)
                Menu.Checkbox("Jungle.W",   "Use [W]", true)
                Menu.Checkbox("Jungle.E",   "Use [E]", true)
            end)
        end)
        Menu.NewTree("KS", "KillSteal Options", function()
            Menu.Checkbox("KS.E"," Use E to Ks", true)
        end)
        Menu.NewTree("Misc", "Misc Options", function()
            Menu.Checkbox("Misc.W","Auto W | to Remove Debuff",true)
            Menu.Checkbox("Misc.C","prevent attack when trying to go Bush High Logic",false)
            Menu.Checkbox("Misc.P","prevent Casting E or W in Bushs",true)
        end)
        Menu.NewTree("Prediction", "Prediction Options", function()
            Menu.Slider("Chance.E","E HitChance", 0.7, 0, 1, 0.05)
        end)
        Menu.NewTree("Range", "Spell Range Options", function()
            Menu.Slider("Max.E","[E] Max Range", 975, 600, 1000)
        end)
        Menu.NewTree("Draw", "Drawing Options", function()
            Menu.Checkbox("DrawText",   "Draw Combo Mode ",true)
            Menu.ColorPicker("color", "Text Color", 0xFFFFFFFF)
            Menu.Checkbox("DrawPer",   "Draw Stack Menu ",true)
            Menu.Checkbox("Drawing.W.Enabled",   "Draw [W] Range",false)
            Menu.ColorPicker("Drawing.W.Color", "Draw [W] Color", 0x118AB2FF)
            Menu.Checkbox("Drawing.E.Enabled",   "Draw [E] Range",true)
            Menu.ColorPicker("Drawing.E.Color", "Draw [E] Color", 0x118AB2FF)
        end)
    end)     
    Menu.RegisterPermashow("StormRengarPermaShow", "Save 4th Stack toggle", function()
        Menu.Keybind("Save", "Save 4th Stack", string.byte("M"), true, false)
    end, function() 
        return Menu.Get("DrawPer")
    end)
end


-- LOAD
function OnLoad()
    Rengar.LoadMenu()
    for eventName, eventId in pairs(Enums.Events) do
        if Rengar[eventName] then
            EventManager.RegisterCallback(eventId, Rengar[eventName])
        end
    end    
    return true
end