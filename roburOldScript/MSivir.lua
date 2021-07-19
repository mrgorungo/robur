if Player.CharName ~= "Sivir" then return false end

module("MSivir", package.seeall, log.setup)
clean.module("MSivir", clean.seeall, log.setup)

local _SDK = _G.CoreEx
local ObjManager, EventManager, Input, Enums, Game, Geometry, Renderer = _SDK.ObjectManager, _SDK.EventManager, _SDK.Input, _SDK.Enums, _SDK.Game, _SDK.Geometry, _SDK.Renderer
local SpellSlots, SpellStates = Enums.SpellSlots, Enums.SpellStates 
local Player = ObjManager.Player
local Prediction = _G.Libs.Prediction
local Orbwalker = _G.Libs.Orbwalker

if Player.CharName ~= "Sivir" then return false end 

TS = _G.Libs.TargetSelector(Orbwalker.Menu)

-- NewMenu
local Menu = _G.Libs.NewMenu

function MSivirMenu()
	Menu.NewTree("MSivirCombo", "Combo", function ()
    Menu.Checkbox("Combo.CastQ","Cast Q",true)
	Menu.Slider("Combo.CastQHC", "Q Hit Chance", 0.70, 0.05, 1, 0.05)
	Menu.Slider("Combo.CastQHR", "Q Hit Range", 1000, 500, 1250, 10)
	Menu.Checkbox("Combo.CastW","Cast W After AA",true)
	end)
	Menu.NewTree("MSivirHarass", "Harass", function ()
	Menu.Checkbox("Harass.CastW","Cast W After AA",true)
	end)
	Menu.NewTree("MSivirWave", "Waveclear", function ()
    Menu.Checkbox("Wave.CastQ","Cast Q",true)
	Menu.Slider("Wave.CastQHC", "Q Hit Count", 3, 1, 10, 1)
	Menu.Checkbox("Wave.CastW","Cast W",true)
	end)
	Menu.NewTree("MSivirMisc", "Misc.", function ()
    Menu.Checkbox("Misc.CastEOnTarget","Auto-Cast E Targetted Spells",true)
	end)
	Menu.NewTree("MSivirDrawing", "Drawing", function ()
    Menu.Checkbox("Drawing.DrawQ","Draw Q Range",true)
    Menu.ColorPicker("Drawing.DrawQColor", "Draw Q Color", 0xEF476FFF)
	end)
end

Menu.RegisterMenu("MSivir","MSivir",MSivirMenu)

-- Sivir Spell Info
local spellQ = {Range=1250, Radius=100, Speed=1350, Delay=0.65, Type="Linear"}

local function CastW()
	if Player:GetSpellState(SpellSlots.W) == SpellStates.Ready then
		Input.Cast(SpellSlots.W)
	end
end

local function CastE()
	if Player:GetSpellState(SpellSlots.E) == SpellStates.Ready then
		Input.Cast(SpellSlots.E)
	end
end

local function Combo(target)
	local targetAI = target.AsAI
	local qPred = nil
	if targetAI and Menu.Get("Combo.CastQ") then
		if Player.Position:Distance(target.Position) <= Menu.Get("Combo.CastQHR") then
			qPred = Prediction.GetPredictedPosition(targetAI, spellQ, Player.Position)
			if qPred then 
				if qPred.HitChance >= Menu.Get("Combo.CastQHC") then
					qPred = qPred.CastPosition
				else 
					qPred = nil
				end
			end
		end
	end
	
	if Player:GetSpellState(SpellSlots.Q) == SpellStates.Ready
		and qPred then
		Input.Cast(SpellSlots.Q, qPred)
	end
end

local function OnProcessSpell(sender,spell)
    local eEnabled = Menu.Get("Misc.CastEOnTarget")
    if not eEnabled or spell.IsBasicAttack or not (sender.IsHero and sender.IsEnemy) then
        return 
    end
    
    local spellTarget = spell.Target
    if spellTarget and spellTarget.IsMe then
		CastE()
	end
end

local function OnPostAttack()			
	
	local target = Orbwalker.GetTarget()
	if Orbwalker.GetMode() == "Combo" and Menu.Get("Combo.CastW") and target then 
		CastW()
	elseif Orbwalker.GetMode() == "Waveclear" and Menu.Get("Wave.CastW") then
		CastW()
	elseif Orbwalker.GetMode() == "Harass" and Menu.Get("Harass.CastW") then
		CastW()
	end

end

local function OnNormalPriority()

	local target = Orbwalker.GetTarget() or TS:GetTarget(1250, true)
	
	-- Combo
	if target and Orbwalker.GetMode() == "Combo" then 
		Combo(target)
		
	-- Waveclear
	elseif Orbwalker.GetMode() == "Waveclear" then	
		local pPos, pointsQ = Player.Position, {}
		
		-- Enemy Minions
		for k, v in pairs(ObjManager.Get("enemy", "minions")) do
			local minion = v.AsAI
			if minion then
				local pos = minion:FastPrediction(spellQ.Delay)
				if pos:Distance(pPos) < spellQ.Range and minion.IsTargetable then
					table.insert(pointsQ, pos)
				end 
			end                       
		end
		
		-- Jungle Minions
		if #pointsQ == 0 then 
			for k, v in pairs(ObjManager.Get("neutral", "minions")) do
				local minion = v.AsAI
				if minion then
					local pos = minion:FastPrediction(spellQ.Delay)
					if pos:Distance(pPos) < spellQ.Range and minion.IsTargetable then
						table.insert(pointsQ, pos)
					end 
				end                       
			end
		end
		local bestPos, hitCount = Geometry.BestCoveringRectangle(pointsQ, pPos, spellQ.Radius*2)
		if bestPos and hitCount >= Menu.Get("Wave.CastQHC")
			and Player:GetSpellState(SpellSlots.Q) == SpellStates.Ready and Menu.Get("Wave.CastQ") then
            Input.Cast(SpellSlots.Q, bestPos)
        end
	end
end

local function OnDraw()	

	-- Draw Q Range
	if Player:GetSpell(SpellSlots.Q).IsLearned and Menu.Get("Drawing.DrawQ") then 
		Renderer.DrawCircle3D(Player.Position, spellQ.Range, 30, 1.0, Menu.Get("Drawing.DrawQColor"))
	end

end

function OnLoad() 
	if Player.CharName ~= "Sivir" then return false end 
	
	EventManager.RegisterCallback(Enums.Events.OnPostAttack, OnPostAttack)
	EventManager.RegisterCallback(Enums.Events.OnNormalPriority, OnNormalPriority)
	EventManager.RegisterCallback(Enums.Events.OnDraw, OnDraw)
	EventManager.RegisterCallback(Enums.Events.OnProcessSpell, OnProcessSpell)
		
	return true
end

