-- 🆂🆃🅾🆁🅼🅰🅸🅾 --
if Player.CharName ~= "Zed" then return end
require("common.log")
module("Storm Zed", package.seeall, log.setup)
clean.module("Storm Zed", clean.seeall, log.setup)
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
local Zed = {}
local ZedHP = {}
local ZedNP = {}
local El = "ASSETS/Perks/Styles/Domination/Electrocute/Electrocute.lua"
local Data = {"AatroxQ","AhriSeduce","CurseoftheSadMummy","InfernalGuardian","EnchantedCrystalArrow","AzirR","BrandWildfire","CassiopeiaPetrifyingGaze","DariusExecute","DravenRCast","EvelynnR","EzrealTrueshotBarrage","Terrify",
"GalioIdolOfDurand","GarenR","GravesChargeShot","HecarimUlt","LissandraR","LuxMaliceCannon","UFSlash","AlZaharNetherGrasp"
,"OrianaDetonateCommand","LeonaSolarFlare","SejuaniGlacialPrisonStart","SonaCrescendo","VarusR","GragasR","GnarR","FizzMarinerDoom"
,"SyndraR","AkaliShadowSwipe","Pulverize","BandageToss","CurseoftheSadMummy","FlashFrost","InfernalGuardian","EnchantedCrystalArrow"
,"AurelionSolQ","AurelionSolR","AzirR","BardQ","BardR","RocketGrab","BraumRWrapper","CamilleEDash2","CassiopeiaW","CassiopeiaR",
"Rupture","DariusAxeGrabCone","DravenDoubleShot","EkkoW","EkkoR","EliseHumanE","EvelynnR","EzrealR","GalioW","GalioE","GnarBigQ"
,"GnarR","GragasE","GragasR","GravesChargeShot","HecarimUlt","HeimerdingerE","IllaoiE","IreliaTranscendentBlades","IvernQ","JannaQ",
"JarvanIVEQ","JinxR","KarmaQMantra","KledQ","LeblancE","LeonaZenithBlade","LeonaSolarFlare","LissandraW","LuxMaliceCannon","UFSlash"
,"DarkBindingMissile","NamiQ","NamiR","NautilusAnchorDrag","OrianaDetonateCommand-","RengarE","RumbleCarpetBombM","SejuaniGlacialPrisonStart","ShenE","SonaR","TaricE","ThreshQ","ThreshEFlay","UrgotE","UrgotR","Vi-q","XerathMageSpear","WarwickR","ZacE2","ZiggsR","ZyraR","ZyraE","yasuoq3w"}
local wshadow = nil 
local rshadow = nil
-- spells1
local Q = Spell.Skillshot({
    Slot = Enums.SpellSlots.Q,
    Range = 925,
    Delay = 0.25,
    Radius = 50,
    Speed = 1700,
    Collisions = {WindWall=true},
    Key = "Q",
    Type = "Linear",
})
local W = Spell.Skillshot({
    Slot = Enums.SpellSlots.W,
    Key = "W",
    Range = 650,
    Delay = 0,
    Radius = 50,
    Speed = 2500,
    Type = "Linear",
    LastW = 0

})
local E = Spell.Active({
    Slot = Enums.SpellSlots.E,
    Range =  315,
    Delay = 0,
    Key = "E",
})
local R = Spell.Targeted({
    Slot = Enums.SpellSlots.R,
    Range = 625,
    Key = "R",
    LastR = 0
})
local W2 = Spell.Active({
    Slot = Enums.SpellSlots.W,
})
local R2 = Spell.Active({
    Slot = Enums.SpellSlots.R,
})
local Summoner2 = Spell.Targeted({
    Slot = Enums.SpellSlots.Summoner2,
    Range = 600,
})
local Summoner1 = Spell.Targeted({
    Slot = Enums.SpellSlots.Summoner1,
    Range = 600,
})

local function GameIsAvailable()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

local function dmg(spell)
    local dmg = 0
    if spell.Key == "Q" then
        dmg =  (80 + (spell:GetLevel() - 1) * 35) + (1 * Player.BonusAD)
    end
    if spell.Key == "E" then
        dmg =  (70 + (spell:GetLevel() - 1) * 20) + (0.8 * Player.BonusAD)
    end
    return dmg
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

function Zed.OnHighPriority() 
    if not GameIsAvailable() then
        return
    end
    local ModeToExecute = ZedHP[Orbwalker.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end

function Zed.OnNormalPriority()
    if not GameIsAvailable() then
        return
    end
    if Zed.Auto() then return end
    local ModeToExecute = ZedNP[Orbwalker.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end


-- DRAW
function Zed.OnDraw()
    local Pos = Player.Position
    if wshadow ~= nil then 
        if Menu.Get("Drawing."..Q.Key..".Enabled", true) and Q:IsReady() then
            Renderer.DrawCircle3D(wshadow.Position, Q.Range, 30, 3, 0x6741d9FF)
        end
    end
    if rshadow ~= nil then 
        if Menu.Get("Drawing."..Q.Key..".Enabled", true) and Q:IsReady() then
            Renderer.DrawCircle3D(rshadow.Position, Q.Range, 30, 3, 0xeb2fbcFF)
        end
    end
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

local function Count1(pos,team,type)
    local num = 0
    for k, v in pairs(ObjManager.Get(team, type)) do
        local minion = v.AsAI
        local Tar    = pos:Distance(minion) <= 290 and minion.MaxHealth > 6 and minion.IsTargetable
        if minion and Tar then
            num = num + 1
        end
    end
    return num
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

local function KS(spell)
    return Menu.Get("KS."..spell.Key) and spell:IsReady()
end

local function Jungle(spell)
    return Menu.Get("Jungle."..spell.Key) and spell:IsReady()
end
-- functions 
function Zed.CastW()
    local time = Game.GetTime()
    if W.LastW < time and W:GetToggleState() == 0 and Q:GetManaCost() + W:GetManaCost() < Player.Mana then  
        for k,v in pairs(GetTargetsRange(W.Range + 100)) do 
            local castpos = v.Position:Extended(Player.Position,100)
            if castpos:IsWall() then return end
            if W:Cast(castpos) then W.LastW = time + 0.25 return end
        end
    end
end

function Zed.CastW2()
    if Menu.Get("Combo.Electrocute") and Player:GetBuff(El) and Q:IsReady() and Player.Mana > 60 then  
        for k,v in pairs(GetTargetsRange(W.Range + 100)) do 
            local castpos = v.Position:Extended(Player.Position,-25)
            if castpos:IsWall() then return end
            if W:Cast(castpos) then return end
        end
    else 
        return Zed.CastW()
    end
end


-- CALLBACKS
function Zed.Auto()
    if KS(Q) then 
        for k,v in pairs(GetTargets(Q)) do 
            local dmg = DmgLib.CalculatePhysicalDamage(Player,v,dmg(Q))
            local Ks  = Q:GetKillstealHealth(v)
            if Ks > dmg then return end
            if Q:CastOnHitChance(v,HitChance(Q)) then return end
        end
        if wshadow ~=nil then 
            for k,v in pairs(GetTargetsRange(Q.Range + Player:Distance(wshadow))) do 
                local dmg = DmgLib.CalculatePhysicalDamage(Player,v,dmg(Q))
                local Ks  = Q:GetKillstealHealth(v)
                if Ks > dmg then return end
                local pre = Prediction.GetPredictedPosition(v,Q,wshadow.Position)
                if pre and pre.HitChance >= HitChance(Q) then 
                    if Q:Cast(pre.CastPosition) then return end
                end
            end
        end
        if rshadow ~=nil then 
            for k,v in pairs(GetTargetsRange(Q.Range + Player:Distance(rshadow))) do 
                local dmg = DmgLib.CalculatePhysicalDamage(Player,v,dmg(Q))
                local Ks  = Q:GetKillstealHealth(v)
                if Ks > dmg then return end
                local pre = Prediction.GetPredictedPosition(v,Q,rshadow.Position)
                if pre and pre.HitChance >= HitChance(Q) then 
                    if Q:Cast(pre.CastPosition) then return end
                end
            end
        end
    end
    if KS(E) then 
        for k,v in pairs(GetTargets(E)) do 
            local dmg = DmgLib.CalculatePhysicalDamage(Player,v,dmg(E))
            local Ks  = E:GetKillstealHealth(v)
            if Ks > dmg then return end
            if E:IsInRange(v) and E:Cast() then return end
        end
        if wshadow ~=nil then 
            for k,v in pairs(GetTargetsRange(E.Range + Player:Distance(wshadow))) do 
                local dmg = DmgLib.CalculatePhysicalDamage(Player,v,dmg(E))
                local Ks  = E:GetKillstealHealth(v)
                if Ks > dmg then return end
                if v:Distance(wshadow) <= 290 then 
                    if E:Cast() then return end
                end
            end
        end
        if rshadow ~=nil then 
            for k,v in pairs(GetTargetsRange(E.Range + Player:Distance(rshadow))) do 
                local dmg = DmgLib.CalculatePhysicalDamage(Player,v,dmg(E))
                local Ks  = E:GetKillstealHealth(v)
                if Ks > dmg then return end
                if v:Distance(rshadow) <= 290 then 
                    if E:Cast() then return end
                end
            end
        end
    end
end

function Zed.OnCreateObject(obj)
    if obj.Name == "Zed_Base_R_cloneswap_buf" then 
        rshadow = obj
    end
    if obj.Name == "Zed_Base_W_cloneswap_buf" then 
        wshadow = obj
    end
    if obj.Name == "Zed_Base_R_buf_tell" and R:GetToggleState() == 2 and rshadow ~= nil and Menu.Get("Misc.AutoRBack") then 
        if not IsUnderTurrent(rshadow.Position) then 
            if CountHeroes(Player,450) >= CountHeroes(rshadow,450) then 
                R2:Cast()
            end
        end
    end
end

function Zed.OnDeleteObject(obj)
    if obj.Name == "Zed_Base_R_cloneswap_buf" then 
        rshadow = nil
    end
    if obj.Name == "Zed_Base_W_cloneswap_buf" then 
        wshadow = nil
    end
end

function Zed.OnBuffGain(obj, buffInst)
    if not obj.IsHero or not obj.IsEnemy then return end
    if buffInst.Name == "zedrtargetmark" and Menu.Get("Combo.Ignite") then 
        if Summoner1:IsReady() and Summoner1:GetName() == "SummonerDot" then 
            if Summoner1:IsInRange(obj) and Summoner1:Cast(obj) then return end
        end
        if Summoner2:IsReady() and Summoner2:GetName() == "SummonerDot" then 
            if Summoner2:IsInRange(obj) and Summoner2:Cast(obj) then return end
        end
    end
end

function Zed.OnProcessSpell(sender,spell)
    if (sender.IsHero and sender.IsEnemy) and W:GetToggleState() == 2 and Menu.Get("Misc.WEvade") then  
        for k,v in pairs(Data) do 
            if v == spell.Name then 
                if Player:Distance(spell.EndPos) < Player.BoundingRadius * 2 then
                    if wshadow ~=nil and not IsUnderTurrent(wshadow) then  
                        if CountHeroes(Player,450) > CountHeroes(wshadow,300) then 
                            W2:Cast()
                        end
                    end
                end
            end
        end
    end
    if not (sender.IsHero and sender.IsEnemy) or R:GetToggleState() ~= 2 or not Menu.Get("Misc.REvade") then return end
    if spell.Target and spell.Target.IsMe and spell.Slot == 3 then
        for k,v in pairs(GetTargets(R)) do 
            if R:Cast(v) then return end
        end
    end
    for k,v in pairs(Data) do 
        if v == spell.Name then 
            if Player:Distance(spell.EndPos) < Player.BoundingRadius * 2 then
                if  rshadow ~=nil and not IsUnderTurrent(rshadow) then 
                    if CountHeroes(Player,450) > CountHeroes(rshadow,300) then 
                        R2:Cast()
                    end
                end
            end
        end
    end
end


-- RECALLERS
function ZedHP.Combo()
    local gametime = Game.GetTime()
    if not R:IsReady() or R:GetToggleState() == 2 or not Menu.Get("Combo.CastR") or (Menu.Get("Combo.OnlyUseR") and not TS:GetForcedTarget()) then
        if CanCast(Q,"Combo") and (not W:IsReady() or W:GetToggleState() == 2 or not Menu.Get("Combo.CastW")) then  
            for k,v in pairs(GetTargets(Q)) do 
                if Q:CastOnHitChance(v,HitChance(Q)) then return end
            end
            if wshadow ~=nil then 
                for k,v in pairs(GetTargetsRange(Q.Range + Player:Distance(wshadow))) do 
                    local pre = Prediction.GetPredictedPosition(v,Q,wshadow.Position)
                    if pre and pre.HitChance >= HitChance(Q) then 
                        if Q:Cast(pre.CastPosition) then return end
                    end
                end
            end
            if rshadow ~=nil then 
                for k,v in pairs(GetTargetsRange(Q.Range + Player:Distance(rshadow))) do 
                    local pre = Prediction.GetPredictedPosition(v,Q,rshadow.Position)
                    if pre and pre.HitChance >= HitChance(Q) then 
                        if Q:Cast(pre.CastPosition) then return end
                    end
                end
            end
        end
        if CanCast(W,"Combo") then  
            if Zed.CastW2() then return end
        end
        if CanCast(E,"Combo") then  
            for k,v in pairs(GetTargets(E)) do 
                if E:Cast() then return end
            end
            if wshadow ~=nil then 
                for k,v in pairs(GetTargetsRange(E.Range + Player:Distance(wshadow))) do 
                    if v:Distance(wshadow) <= 290 then 
                        if E:Cast() then return end
                    end
                end
            end
            if rshadow ~=nil then 
                for k,v in pairs(GetTargetsRange(E.Range + Player:Distance(rshadow))) do 
                    if v:Distance(rshadow) <= 290 then 
                        if E:Cast() then return end
                    end
                end
            end
        end
    end
    if CanCast(R,"Combo") and R:GetToggleState() == 0 and R.LastR < gametime then 
        if Player.Mana < Menu.Get("RE") then return end
        if not Menu.Get("Combo.OnlyUseR") then 
            for k,v in pairs(GetTargetsRange(R.Range + W.Range)) do 
            local target = v
            if not R:IsInRange(target) and target:Distance(Player) <= R.Range + W.Range and W:IsReady() and Menu.Get("Combo.WGapB") then 
                local Castpos = target.Position:Extended(Player.Position, -650) 
                if Castpos:IsWall() then return end
                if W:Cast(Castpos) then return end
            end
            if R:IsInRange(target) and R:Cast(target) then R.LastR = gametime + 0.25  return end
            end
        end
        if Menu.Get("Combo.OnlyUseR") and TS:GetForcedTarget() then 
            local target = TS:GetForcedTarget()
            if not R:IsInRange(target) and target:Distance(Player) <= R.Range + W.Range and W:IsReady() and Menu.Get("Combo.WGapB") then 
                local Castpos = target.Position:Extended(Player.Position, -650) 
                if Castpos:IsWall() then return end
                if W:Cast(Castpos) then return end
            end
            if R:IsInRange(target) and R:Cast(target) then R.LastR = gametime + 0.25  return end
        end
    end
end

function ZedHP.Harass()
    if CanCast(Q,"Harass") and (not W:IsReady() or W:GetToggleState() == 2 or not Menu.Get("Harass.CastW")) then  
        for k,v in pairs(GetTargets(Q)) do 
            if Q:CastOnHitChance(v,HitChance(Q)) then return end
        end
        if wshadow ~=nil then 
            for k,v in pairs(GetTargetsRange(Q.Range + Player:Distance(wshadow))) do 
                local pre = Prediction.GetPredictedPosition(v,Q,wshadow.Position)
                if pre and pre.HitChance >= HitChance(Q) then 
                    if Q:Cast(pre.CastPosition) then return end
                end
            end
        end
        if rshadow ~=nil then 
            for k,v in pairs(GetTargetsRange(Q.Range + Player:Distance(rshadow))) do 
                local pre = Prediction.GetPredictedPosition(v,Q,rshadow.Position)
                if pre and pre.HitChance >= HitChance(Q) then 
                    if Q:Cast(pre.CastPosition) then return end
                end
            end
        end
    end
    if CanCast(E,"Harass") then  
        for k,v in pairs(GetTargets(E)) do 
            if E:Cast() then return end
        end
        if wshadow ~=nil then 
            for k,v in pairs(GetTargetsRange(E.Range + Player:Distance(wshadow))) do 
                if v:Distance(wshadow) <= 290 then 
                    if E:Cast() then return end
                end
            end
        end
        if rshadow ~=nil then 
            for k,v in pairs(GetTargetsRange(E.Range + Player:Distance(rshadow))) do 
                if v:Distance(rshadow) <= 290 then 
                    if E:Cast() then return end
                end
            end
        end
    end
end
function ZedNP.Harass() 
    local time = Game.GetTime()
    if CanCast(W,"Harass") and W.LastW < time and W:GetToggleState() == 0 and Q:IsReady() and Q:GetManaCost() + W:GetManaCost() < Player.Mana then  
        for k,v in pairs(GetTargetsRange(W.Range + 100)) do 
            local castpos = v.Position:Extended(Player.Position,100)
            if W:Cast(castpos) then W.LastW = time + 0.25 return end
        end
    end
end

function ZedNP.Waveclear() 
    if Lane(Q) then 
        local Qpoints = {}
        for k,v in pairs(ObjManager.GetNearby("enemy", "minions")) do
            local minion = v.AsAI
            local minionInRange = Q:IsInRange(minion)
            local pos = minion:FastPrediction(Game.GetLatency()+ Q.Delay)
            if minionInRange and minion.IsTargetable and minion.MaxHealth > 6 then
                insert(Qpoints, pos)
            end
        end
        local bestPos, hitCount = Q:GetBestLinearCastPos(Qpoints, Q.Radius)
        if bestPos and hitCount >= Menu.Get("Lane.QH") then
            Q:Cast(bestPos)
        end
    end
    if Lane(E) then 
        if Count(E,"enemy","minions") >= Menu.Get("Lane.EH") then 
            if E:Cast() then return end
        end
        if wshadow ~=nil then 
            if Count1(wshadow,"enemy","minions") >= Menu.Get("Lane.EH") then 
                if E:Cast() then return end
            end
        end
        if rshadow ~=nil then 
            if Count1(rshadow,"enemy","minions") >= Menu.Get("Lane.EH") then 
                if E:Cast() then return end
            end
        end
    end
    if Jungle(Q) then 
        for k, v in pairs(ObjManager.GetNearby("neutral", "minions")) do
            local minion = v.AsAI
            local minionInRange = Q:IsInRange(minion)
            if minionInRange and minion.MaxHealth > 6  and minion.IsTargetable then
                if Q:Cast(minion) then
                    return
                end
            end
            if wshadow ~=nil then 
                if minion:Distance(wshadow) <= Q.Range and minion.MaxHealth > 6  and minion.IsTargetable then 
                    if Q:Cast(minion.Position) then return end
                end
            end
            if rshadow ~=nil then 
                if minion:Distance(rshadow) <= Q.Range and minion.MaxHealth > 6  and minion.IsTargetable then 
                    if Q:Cast(minion.Position) then return end
                end
            end
        end
    end
    if Jungle(E) then 
        for k, v in pairs(ObjManager.GetNearby("neutral", "minions")) do
            local minion = v.AsAI
            local minionInRange = E:IsInRange(minion)
            if minionInRange and minion.MaxHealth > 6  and minion.IsTargetable then
                if E:Cast() then
                    return
                end
            end
            if wshadow ~=nil then 
                if minion:Distance(wshadow) <= 290 and minion.MaxHealth > 6  and minion.IsTargetable then 
                    if E:Cast() then return end
                end
            end
            if rshadow ~=nil then 
                if minion:Distance(rshadow) <= 290 and minion.MaxHealth > 6  and minion.IsTargetable then 
                    if E:Cast() then return end
                end
            end
        end
    end
end


-- MENU
function Zed.LoadMenu()
    Menu.RegisterMenu("StormZed", "Storm Zed", function()
        Menu.NewTree("Combo", "Combo Options", function()
            Menu.Checkbox("Combo.CastQ",   "Use [Q]", true)
            Menu.Checkbox("Combo.CastW",   "Use [W]", true)
            Menu.Checkbox("Combo.WGapB",   "Use ^ W to gapclose for utl", false)
            Menu.Checkbox("Combo.Electrocute",   "Use ^ W to Recast Electrocute proc", false)
            Menu.Checkbox("Combo.CastE",   "Use [E]", true)
            Menu.Checkbox("Combo.CastR",   "Use [R]", true)
            Menu.Slider("RE","Use R |  If Energy >= x",100,0,200)
            Menu.Checkbox("Combo.Ignite",   "Use Ignite When Utling", true)
            Menu.Checkbox("Combo.OnlyUseR",   "Only UseR on selected target", false)
        end)
        Menu.NewTree("Harass", "Harass Options", function()
            Menu.Checkbox("Harass.CastQ",   "Use [Q]", true)
            Menu.Checkbox("Harass.CastW",   "Use [W]", true)
            Menu.Checkbox("Harass.CastE",    "Use [E]", true)
        end)
        Menu.NewTree("WaveClear", "WaveClear Options", function()
            Menu.NewTree("Lane", "Lane", function()
                Menu.Checkbox("Lane.Q","Use [Q]", true)
                Menu.Slider("Lane.QH", "Q HitCount", 2,1,5)
                Menu.Checkbox("Lane.E","Use [E]", false)
                Menu.Slider("Lane.EH", "E HitCount", 2,1,5)
            end)
            Menu.NewTree("Jungle", "Jungle", function()
                Menu.Checkbox("Jungle.Q",   "Use [Q]", true)
                Menu.Checkbox("Jungle.E",   "Use [E]", true)
            end)
        end)
        Menu.NewTree("KS", "KillSteal Options", function()
            Menu.Checkbox("KS.Q"," Use [Q] to Ks", true)
            Menu.Checkbox("KS.E"," Use [E] to Ks", true)
        end)
        Menu.NewTree("Misc", "Misc Options", function()
            Menu.Checkbox("Misc.AutoRBack",   "Auto R back if Target Has DeathMark", true)
            Menu.ColoredText(" ^ Doesn't work with every skin Try the default skin for the best result",0xff2908FF,true)
            Menu.Checkbox("Misc.WEvade",   "Use [W] to Evade Spells", true)
            Menu.Checkbox("Misc.REvade",   "Use [R] to Evade Spells", true)
        end)
        Menu.NewTree("Prediction", "Prediction Options", function()
            Menu.Slider("Chance.Q","Q HitChance", 0.6, 0, 1, 0.05)
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
    Zed.LoadMenu()
    for eventName, eventId in pairs(Enums.Events) do
        if Zed[eventName] then
            EventManager.RegisterCallback(eventId, Zed[eventName])
        end
    end    
    return true
end