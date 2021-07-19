require("common.log")
module("E2Utility", package.seeall, log.setup)

local _Core = _G.CoreEx
local ObjManager, EventManager, Input, Enums, Game, Geometry, Renderer, Vector,
      Collision, Orbwalker, Prediction, Nav, HitChance, Profiler, TS, Menu =
    _Core.ObjectManager, _Core.EventManager, _Core.Input, _Core.Enums,
    _Core.Game, _Core.Geometry, _Core.Renderer, _Core.Geometry.Vector,
    _G.Libs.CollisionLib, _G.Libs.Orbwalker, _G.Libs.Prediction, _Core.Nav,
    _Core.Enums.HitChance, _G.Libs.Profiler, _G.Libs.TargetSelector(),
    _G.Libs.NewMenu
local itemID = require("lol\\Modules\\Common\\itemID")
local SpellSlots, SpellStates = Enums.SpellSlots, Enums.SpellStates
local Player = ObjManager.Player
local OSClock, floor, format = os.clock, math.floor, string.format
local Version = 2.7

local JungleTimer = {}
local CloneTracker = {}
local InhibitorsTimer = {}
local DragonBaronTracker = {}
local CooldownTracker = {}
local Activator = {}
local TurnAround = {}
local TowerRanges = {}
local PathTracker = {}
local BlockMinion = {}
local SSUtility = {}
local RecallTracker = {}
local WardTracker = {}

local ActiveFeaturedClasses = {}

local FeatureType = {
    Activators = 1,
    Detectors = 2,
    Drawings = 3,
    Timers = 4,
    Trackers = 5,
    Others = 6
}

local FeaturedClassesInit = {
	{ShortName = "JGT", FullName = "JungleTimer", FeatureClass = JungleTimer, Type = FeatureType.Timers},
	{ShortName = "CT", FullName = "CloneTracker", FeatureClass = CloneTracker, Type = FeatureType.Trackers},
	{ShortName = "IT", FullName = "InhibitorsTimer", FeatureClass = InhibitorsTimer, Type = FeatureType.Timers},
	{ShortName = "DBT", FullName = "DragonBaronTracker", FeatureClass = DragonBaronTracker, Type = FeatureType.Trackers},
	{ShortName = "CDT", FullName = "CooldownTracker", FeatureClass = CooldownTracker, Type = FeatureType.Trackers},
	{ShortName = "AT", FullName = "Activator", FeatureClass = Activator, Type = FeatureType.Activators},
	{ShortName = "TA", FullName = "TurnAround", FeatureClass = TurnAround, Type = FeatureType.Detectors},
	{ShortName = "TR", FullName = "TowerRanges", FeatureClass = TowerRanges, Type = FeatureType.Drawings},
	{ShortName = "PT", FullName = "PathTracker", FeatureClass = PathTracker, Type = FeatureType.Trackers},
	{ShortName = "BM", FullName = "BlockMinion", FeatureClass = BlockMinion, Type = FeatureType.Others},
	{ShortName = "SU", FullName = "SSUtility", FeatureClass = SSUtility, Type = FeatureType.Others},
	{ShortName = "RT", FullName = "RecallTracker", FeatureClass = RecallTracker, Type = FeatureType.Trackers},
	{ShortName = "WT", FullName = "WardTracker", FeatureClass = WardTracker, Type = FeatureType.Trackers},
}

local TextClipper = Vector(30, 15, 0)
local TextClipperLarger = Vector(100, 15,0)
local TickCount = 0

---@param arg number(float)
---@return number
local function GetHash(arg)
	return (floor(arg) % 1000)
end

-- Creadit to Thorn
---@param seconds number(float)
---@return string
local function SecondsToClock(seconds)
	local m, s = floor(seconds / 60), floor(seconds % 60)
	return m .. ":" .. (s < 10 and 0 or "") .. s
end

--[[
		██ ██    ██ ███    ██  ██████  ██      ███████     ████████ ██ ███    ███ ███████ ██████  
		██ ██    ██ ████   ██ ██       ██      ██             ██    ██ ████  ████ ██      ██   ██ 
		██ ██    ██ ██ ██  ██ ██   ███ ██      █████          ██    ██ ██ ████ ██ █████   ██████  
   ██   ██ ██    ██ ██  ██ ██ ██    ██ ██      ██             ██    ██ ██  ██  ██ ██      ██   ██ 
    █████   ██████  ██   ████  ██████  ███████ ███████        ██    ██ ██      ██ ███████ ██   ██                                                                                                                                                                                          
]]
function JungleTimer.Init()

	-- A Bool to end Rift timer
	JungleTimer.RiftOver = false
	JungleTimer.TotalCamps = 16
	JungleTimer.ObjName = {["CampRespawn"] = true}
	JungleTimer.ObjBuffNameSTR = "camprespawncountdownhidden"
	-- [id] hashtable ID
	-- ["m_name"] Name for the menu
	-- ["position"] Position for the jungle mob
	-- ["adjustment"] A Vector to adjust the position because some of them are at the accurate position
	-- ["respawn_timer"] Respawning time
	-- ["saved_time"] GameTime + Respawning Time
	-- ["active"] Active status for the current jungle mob
	-- ["b_menu"] Menu boolean value (Deleted)
	local emptyVector = Vector(0, 0, 0)
	JungleTimer.JungleMobsData = {
		[821] = {
			["m_name"] = "Blue (West)",
			["position"] = Vector(3821.48, 51.12, 8101.05),
			["adjustment"] = Vector(0, -300, 0),
			["respawn_timer"] = 300,
			["saved_time"] = 90,
			["active"] = true
		},
		[288] = {
			["m_name"] = "Gromp (West)",
			["position"] = Vector(2288.01, 51.77, 8448.13),
			["adjustment"] = Vector(-100, 0, 0),
			["respawn_timer"] = 120,
			["saved_time"] = 102,
			["active"] = true
		},
		[783] = {
			["m_name"] = "Wovles (West)",
			["position"] = Vector(3783.37, 52.46, 6495.56),
			["adjustment"] = emptyVector,
			["respawn_timer"] = 120,
			["saved_time"] = 90,
			["active"] = true
		},
		[61] = {
			["m_name"] = "Raptors (South)",
			["position"] = Vector(7061.5, 50.12, 5325.50),
			["adjustment"] = Vector(-100, 100, 0),
			["respawn_timer"] = 120,
			["saved_time"] = 90,
			["active"] = true
		},
		[762] = {
			["m_name"] = "Red (South)",
			["position"] = Vector(7762.24, 53.96, 4011.18),
			["adjustment"] = emptyVector,
			["respawn_timer"] = 300,
			["saved_time"] = 90,
			["active"] = true
		},
		[394] = {
			["m_name"] = "Krugs (South)",
			["position"] = Vector(8394.76, 50.73, 2641.59),
			["adjustment"] = emptyVector,
			["respawn_timer"] = 120,
			["saved_time"] = 102,
			["active"] = true
		},
		[400] = {
			["m_name"] = "Scuttler (Baron)",
			["position"] = Vector(4400.00, -66.53, 9600.00),
			["adjustment"] = emptyVector,
			["respawn_timer"] = 150,
			["saved_time"] = 195,
			["active"] = true
		},
		[500] = {
			["m_name"] = "Scuttler (Dragon)",
			["position"] = Vector(10500.00, -62.81, 5170.00),
			["adjustment"] = emptyVector,
			["respawn_timer"] = 150,
			["saved_time"] = 195,
			["active"] = true
		},
		[866] = {
			["m_name"] = "Dragon",
			["position"] = Vector(9866.14, -71.24, 4414.01),
			["adjustment"] = emptyVector,
			["respawn_timer"] = 300,
			["saved_time"] = 300,
			["active"] = true
		},
		[7] = {
			["m_name"] = "Baron/Rift",
			["position"] = Vector(5007.12, -71.24, 10471.44),
			["adjustment"] = emptyVector,
			["respawn_timer"] = 360,
			["saved_time"] = 480,
			["active"] = true
		},
		[131] = {
			["m_name"] = "Blue (East)",
			["position"] = Vector(11131.72, 51.72, 6990.84),
			["adjustment"] = emptyVector,
			["respawn_timer"] = 300,
			["saved_time"] = 90,
			["active"] = true
		},
		[703] = {
			["m_name"] = "Gromp (East)",
			["position"] = Vector(12703.62, 51.69, 6443.98),
			["adjustment"] = emptyVector,
			["respawn_timer"] = 120,
			["saved_time"] = 102,
			["active"] = true
		},
		[59] = {
			["m_name"] = "Wovles (East)",
			["position"] = Vector(11059.76, 60.35, 8419.83),
			["adjustment"] = emptyVector,
			["respawn_timer"] = 120,
			["saved_time"] = 90,
			["active"] = true
		},
		[820] = {
			["m_name"] = "Raptors (North)",
			["position"] = Vector(7820.22, 52.19, 9644.45),
			["adjustment"] = emptyVector,
			["respawn_timer"] = 120,
			["saved_time"] = 90,
			["active"] = true
		},
		[66] = {
			["m_name"] = "Red (North)",
			["position"] = Vector(7066.86, 56.18, 10975.54),
			["adjustment"] = emptyVector,
			["respawn_timer"] = 300,
			["saved_time"] = 90,
			["active"] = true
		},
		[499] = {
			["m_name"] = "Krugs (North)",
			["position"] = Vector(6499.49, 56.47, 12287.37),
			["adjustment"] = emptyVector,
			["respawn_timer"] = 120,
			["saved_time"] = 102,
			["active"] = true
		}
	}

	JungleTimer.JungleTimerTable = {821, 783, 61, 762, 131, 59, 820, 66, 499, 394, 288, 703, 400, 500, 866, 7}
end


function JungleTimer.Menu()
    Menu.NewTree("JungleTimer", "JungleTimer", function ()
        Menu.Checkbox("JGT.DrawMap", "Draw Timer on the Map", true)
        Menu.ColorPicker("JGT.DrawMapColor", "Timer Text on Map Color", 0x00FF00FF)
        Menu.Checkbox("JGT.DrawMapBG", "Use a Background on Timer", true)
        Menu.ColorPicker("JGT.DrawMapBGColor", "Background Color", 0x008000FF)
        Menu.Checkbox("JGT.DrawMiniMap", "Draw Timer on the MiniMap", true)
        Menu.ColorPicker("JGT.DrawMiniMapColor", "Timer Text on MiniMap Color", 0x00FF00FF)
        Menu.Text("A Unique Feature Included")
        Menu.Text("Read the forum for the details")
    end)
end

function JungleTimer.OnDraw()
	-- ForLooping only table has at least one element
	if (#JungleTimer.JungleTimerTable > 0) then
		local currentGameTime = Game:GetTime()
		local totalCamps = JungleTimer.TotalCamps
        local JungleMobsData = JungleTimer.JungleMobsData
        local drawMap = Menu.Get("JGT.DrawMap", true)
        local drawMapColor = Menu.Get("JGT.DrawMapColor", true)
        local drawMapBG = Menu.Get("JGT.DrawMapBG", true)
        local drawMapBGColor = Menu.Get("JGT.DrawMapBGColor", true)
        local drawMinimap = Menu.Get("JGT.DrawMiniMap", true)
        local drawMinimapColor = Menu.Get("JGT.DrawMiniMapColor", true)
		for i = 1, totalCamps do
			local hash = JungleTimer.JungleTimerTable[i]
			if (JungleMobsData[hash]["active"]) then
				local timeleft = JungleMobsData[hash]["saved_time"] - currentGameTime
				-- First condition for removing ended timers and the second one for removing rift timer after baron spawned.
				if (timeleft <= 0) then
					JungleMobsData[hash]["active"] = false
				else
					if (hash == 7 and currentGameTime >= 1200 and JungleTimer.RiftOver == false) then
						JungleTimer.RiftOver = true
						JungleMobsData[hash]["active"] = false
					else
						-- adjustment vector for correcting position for some jungle mobs
						local pos = JungleMobsData[hash]["position"] + JungleMobsData[hash]["adjustment"]
						-- convert time into m:ss format
						local time = SecondsToClock(timeleft)
						-- draw only pos is on the screen
						if (Renderer.IsOnScreen(pos)) then
							local worldPos = Renderer.WorldToScreen(pos)
							if (drawMap) then
								if (drawMapBG) then
									Renderer.DrawFilledRect(worldPos, TextClipper, 2, drawMapBGColor)
								end
								Renderer.DrawText(worldPos, TextClipper, time, drawMapColor)
							end
						end
						if (drawMinimap) then
							local miniPos = Renderer.WorldToMinimap(pos) + Vector(-10, -10, 0)
							Renderer.DrawText(miniPos, TextClipper, time, drawMinimapColor)
						end
					end
				end
			end
		end
	end
end

local function TimerStarter(objHandle)
	local Object = ObjManager.GetObjectByHandle(objHandle)
	local ObjectAI = Object.AsAI
	if (ObjectAI) then
		local JungleMobsData = JungleTimer.JungleMobsData
		local buff = ObjectAI:GetBuff(JungleTimer.ObjBuffNameSTR)
		if (buff) then
			local hashID = GetHash(ObjectAI.Position.x)
			if (JungleMobsData[hashID]) then
				local endTime = buff.StartTime + JungleMobsData[hashID]["respawn_timer"] + 1
				JungleMobsData[hashID]["saved_time"] = endTime
				JungleMobsData[hashID]["active"] = true
			end
		end
	end
end

function JungleTimer.OnCreateObject(obj)
    if (JungleTimer.ObjName[obj.Name]) then
		delay(100, TimerStarter, obj.Handle)
	end
end

function JungleTimer.OnDeleteObject(obj)
	if (JungleTimer.ObjName[obj.Name]) then
		local hashID = GetHash(obj.AsAI.Position.x)
		local target = JungleTimer.JungleMobsData[hashID]
		if (target) then
			target["saved_time"] = -1
			target["active"] = false
		end
	end
end

--[[
	 ██████ ██       ██████  ███    ██ ███████     ████████ ██████   █████   ██████ ██   ██ ███████ ██████  
	██      ██      ██    ██ ████   ██ ██             ██    ██   ██ ██   ██ ██      ██  ██  ██      ██   ██ 
	██      ██      ██    ██ ██ ██  ██ █████          ██    ██████  ███████ ██      █████   █████   ██████  
	██      ██      ██    ██ ██  ██ ██ ██             ██    ██   ██ ██   ██ ██      ██  ██  ██      ██   ██ 
	 ██████ ███████  ██████  ██   ████ ███████        ██    ██   ██ ██   ██  ██████ ██   ██ ███████ ██   ██                                                                                                                                                                                                                                                                                                                                                                                                      
]]
function CloneTracker.Init()

	-- Clone Tracker Variables
	CloneTracker.CloneEnum = {}
	CloneTracker.CloneEnumCount = 1
	CloneTracker.CloneActiveCount = 0
	CloneTracker.CloneAdjustment = Vector(-15, -50, 0)
	local tableTemplate = {nil, false}
	CloneTracker.CloneTrackerList = {
		["Shaco"] = tableTemplate,
		["Leblanc"] = tableTemplate,
		["MonkeyKing"] = tableTemplate,
		["Neeko"] = tableTemplate
	}
	CloneTracker.Text = "CLONE"
	CloneTracker.TextRectVec = Vector(36, 15, 0)
	-- End of Clone Tracker Variables

	local enemyList = ObjManager.Get("enemy", "heroes")
	local template = {nil, true}
	for handle, enemy in pairs(enemyList) do
		if (enemy and enemy.IsAI) then
			local cloneChamp = enemy.AsAI
			local charName = cloneChamp.CharName
			if (CloneTracker.CloneTrackerList[charName]) then
				CloneTracker.CloneTrackerList[charName] = template
				CloneTracker.CloneEnum[CloneTracker.CloneEnumCount] = charName
				CloneTracker.CloneEnumCount = CloneTracker.CloneEnumCount + 1
			end
		end
	end

    -- if there is no clone champion on the enemy team
	if (CloneTracker.CloneEnumCount < 1) then
		CloneTracker.OnDraw = nil
		CloneTracker.OnCreateObject = nil
		CloneTracker.OnDeleteObject = nil
        collectgarbage()
	end
end

function CloneTracker.Menu()
    Menu.NewTree("CloneTracker", "CloneTracker", function ()
        Menu.Checkbox("CT.TrackOnMap", "Track Clones", true)
        Menu.ColorPicker("CT.TrackOnMapColor", "Clone Tracker on Text Color", 0x000000FF)
        Menu.Checkbox("CT.TrackOnMapBG", "Use a Background on Clone", true)
        Menu.ColorPicker("CT.TrackOnMapBGColor", "Background Color", 0xDF0101FF)
        Menu.Text("Works on Shaco/Wukong/Leblanc/Neeko")
    end)
end

function CloneTracker.OnDraw()
	if (CloneTracker.CloneActiveCount > 0) then
		local enumCount = CloneTracker.CloneEnumCount - 1
		local cloneTracker = CloneTracker.CloneTrackerList
        local drawMap = Menu.Get("CT.TrackOnMap", true)
        local drawMapColor = Menu.Get("CT.TrackOnMapColor", true)
        local drawMapBG = Menu.Get("CT.TrackOnMapBG", true)
        local drawMapBGColor = Menu.Get("CT.TrackOnMapBGColor", true)

		for i = 1, enumCount do
			local charName = CloneTracker.CloneEnum[i]
			if (cloneTracker[charName][1] and cloneTracker[charName][2] == true) then
				local pos = cloneTracker[charName][1].Position
				if (Renderer.IsOnScreen(pos)) then
					local posw2s = Renderer.WorldToScreen(pos) + CloneTracker.CloneAdjustment
					if (drawMapBG) then
						Renderer.DrawFilledRect(posw2s, CloneTracker.TextRectVec, 2, drawMapBGColor)
					end
					if (drawMap) then
						Renderer.DrawText(posw2s, TextClipperLarger, CloneTracker.Text, drawMapColor)
					end
				end
			end
		end
	end
end

function CloneTracker.OnCreateObject(obj)
	if (obj.IsAI) then
		local cloneChamp = obj.AsAI
		if (cloneChamp ~= nil and cloneChamp.IsValid) then
			local cloneTracker = CloneTracker.CloneTrackerList
			local charName = cloneChamp.CharName
			if (cloneTracker[charName] and cloneTracker[charName][2] == true) then
				cloneTracker[charName][1] = cloneChamp
				CloneTracker.CloneActiveCount = CloneTracker.CloneActiveCount + 1
			end
		end
	end
end

function CloneTracker.OnDeleteObject(obj)
	if (obj.IsAI) then
		local cloneChamp = obj.AsAI
		if (cloneChamp and cloneChamp.IsValid) then
			local cloneTracker = CloneTracker.CloneTrackerList
			local charName = cloneChamp.CharName
			if (cloneTracker[charName] and cloneTracker[charName][2] == true) then
				cloneTracker[charName][1] = nil
				-- Decrease the count only greater than 0
				local activeCount = CloneTracker.CloneActiveCount
				if (activeCount > 0) then
					CloneTracker.CloneActiveCount = activeCount - 1
				end
			end
		end
	end
end

--[[
	██ ███    ██ ██   ██ ██ ██████  ██ ████████  ██████  ██████  ███████     ████████ ██ ███    ███ ███████ ██████  
	██ ████   ██ ██   ██ ██ ██   ██ ██    ██    ██    ██ ██   ██ ██             ██    ██ ████  ████ ██      ██   ██ 
	██ ██ ██  ██ ███████ ██ ██████  ██    ██    ██    ██ ██████  ███████        ██    ██ ██ ████ ██ █████   ██████  
	██ ██  ██ ██ ██   ██ ██ ██   ██ ██    ██    ██    ██ ██   ██      ██        ██    ██ ██  ██  ██ ██      ██   ██ 
	██ ██   ████ ██   ██ ██ ██████  ██    ██     ██████  ██   ██ ███████        ██    ██ ██      ██ ███████ ██   ██                                                                                                                                                                                                                                                                                                                                                                                                     
]]
function InhibitorsTimer.Init()

	InhibitorsTimer.InhibitorsTable = {
		-- Blue Top, Mid, Bot
		[171] = {
			IsDestroyed = false,
			Position = Vector(1171, 91, 3571),
			RespawnTime = 0.0
		},
		[203] = {
			IsDestroyed = false,
			Position = Vector(3203, 92, 3208),
			RespawnTime = 0.0
		},
		[452] = {
			IsDestroyed = false,
			Position = Vector(3452, 89, 1236),
			RespawnTime = 0.0
		},
		-- Red Top, Mid, Bot
		[261] = {
			IsDestroyed = false,
			Position = Vector(11261, 88, 13676),
			RespawnTime = 0.0
		},
		[598] = {
			IsDestroyed = false,
			Position = Vector(11598, 89, 11667),
			RespawnTime = 0.0
		},
		[604] = {
			IsDestroyed = false,
			Position = Vector(13604, 89, 11316),
			RespawnTime = 0.0
		}
	}
	InhibitorsTimer.InhibitorsEnum = {171, 203, 452, 261, 598, 604}
	InhibitorsTimer.Inhibitors = 6
	InhibitorsTimer.DestroyedInhibitors = 0
	InhibitorsTimer.ConstRespawnTime = 300.0

	InhibitorsTimer.RespawnComparor = {
		["SRUAP_Chaos_Inhibitor_Spawn_sound.troy"] = {Destroy = false},
		["SRUAP_Order_Inhibitor_Spawn_sound.troy"] = {Destroy = false},
		["SRUAP_Chaos_Inhibitor_Idle1_soundy.troy"] = {Destroy = true},
		["SRUAP_Order_Inhibitor_Idle1_sound.troy"] = {Destroy = true}
	}

	local inhibitorsList = ObjManager.Get("all", "inhibitors")
	for k, obj in pairs(inhibitorsList) do
		local objAT = obj.AsAttackableUnit
		if (obj and obj.IsValid and objAT.Health <= 0.0) then
			local hash = GetHash(obj.Position.x)
			InhibitorsTimer.InhibitorsTable[hash].IsDestroyed = true
			InhibitorsTimer.DestroyedInhibitors = InhibitorsTimer.DestroyedInhibitors + 1
		end
	end

end

function InhibitorsTimer.Menu()
    Menu.NewTree("InhibitorsTimer", "InhibitorsTimer", function ()
        Menu.Checkbox("IT.TrackOnMap", "Use a Inhibitors Timer on Map", true)
        Menu.ColorPicker("IT.TrackOnMapColor", "Inhibitors Timer on Map Color", 0x000000FF)
        Menu.Checkbox("IT.TrackOnMapBG", "Use a Background on Map", true)
        Menu.ColorPicker("IT.TrackOnMapBGColor", "Background Color", 0xDF0101FF)
        Menu.Checkbox("IT.TrackOnMiniMap", "Use a Inhibitors Timer on MiniMap", true)
        Menu.ColorPicker("IT.TrackOnMiniMapColor", "Inhibitors Timer on MiniMap Color", 0x00FF00FF)
    end)
end

function InhibitorsTimer.OnDeleteObject(obj)
	local comparor = InhibitorsTimer.RespawnComparor[obj.Name]
	if (comparor) then
		local hash = GetHash(obj.Position.x)
		local InhibitorsTable = InhibitorsTimer.InhibitorsTable[hash]
		if (InhibitorsTable) then
			if (comparor.Destroy) then
				InhibitorsTable.IsDestroyed = true
				local respawnTime = OSClock() + InhibitorsTimer.ConstRespawnTime
				InhibitorsTable.RespawnTime = respawnTime
				InhibitorsTimer.DestroyedInhibitors = InhibitorsTimer.DestroyedInhibitors + 1
			else
				InhibitorsTable.IsDestroyed = false
				InhibitorsTable.RespawnTime = 0.0
				if (InhibitorsTimer.DestroyedInhibitors > 0) then
					InhibitorsTimer.DestroyedInhibitors = InhibitorsTimer.DestroyedInhibitors - 1
				end
			end
		end
	end
end

function InhibitorsTimer.OnDraw()

    if (InhibitorsTimer.DestroyedInhibitors > 0) then
        local drawMap = Menu.Get("IT.TrackOnMap", true)
        local drawMapColor = Menu.Get("IT.TrackOnMapColor", true)
        local drawMapBG = Menu.Get("IT.TrackOnMapBG", true)
        local drawMapBGColor = Menu.Get("IT.TrackOnMapBGColor", true)
        local drawMiniMap = Menu.Get("IT.TrackOnMiniMap", true)
        local drawMiniMapColor = Menu.Get("IT.TrackOnMiniMapColor", true)

		for i = 1, InhibitorsTimer.Inhibitors do
			local index = InhibitorsTimer.InhibitorsEnum[i]
			if (InhibitorsTimer.InhibitorsTable[index].IsDestroyed) then
				local time = InhibitorsTimer.InhibitorsTable[index].RespawnTime - OSClock()
				local timeleft = SecondsToClock(time)
				if (time <= 0) then
					InhibitorsTimer.InhibitorsTable[index].IsDestroyed = false
					InhibitorsTimer.InhibitorsTable[index].RespawnTime = 0.0
					if (InhibitorsTimer.DestroyedInhibitors > 0) then
						InhibitorsTimer.DestroyedInhibitors = InhibitorsTimer.DestroyedInhibitors - 1
					end
				else
					local pos = InhibitorsTimer.InhibitorsTable[index].Position
					local posw2s = Renderer.WorldToScreen(pos)
					local posw2m = Renderer.WorldToMinimap(pos) + Vector(-15, -10, 0)

					--draw only pos is on the screen
					if (Renderer.IsOnScreen(pos)) then
						if (drawMap) then
							if (drawMapBG) then
								Renderer.DrawFilledRect(posw2s, TextClipper, 2, drawMapBGColor)
							end
							Renderer.DrawText(posw2s, TextClipper, timeleft, drawMapColor)
						end
					end

					if (drawMiniMap) then
						Renderer.DrawText(posw2m, TextClipper, timeleft, drawMiniMapColor)
					end
				end
			end
		end
	end
end

--[[
	██████  ██████   █████   ██████   ██████  ███    ██ ██████   █████  ██████   ██████  ███    ██     ████████ ██████   █████   ██████ ██   ██ ███████ ██████  
	██   ██ ██   ██ ██   ██ ██       ██    ██ ████   ██ ██   ██ ██   ██ ██   ██ ██    ██ ████   ██        ██    ██   ██ ██   ██ ██      ██  ██  ██      ██   ██ 
	██   ██ ██████  ███████ ██   ███ ██    ██ ██ ██  ██ ██████  ███████ ██████  ██    ██ ██ ██  ██        ██    ██████  ███████ ██      █████   █████   ██████  
	██   ██ ██   ██ ██   ██ ██    ██ ██    ██ ██  ██ ██ ██   ██ ██   ██ ██   ██ ██    ██ ██  ██ ██        ██    ██   ██ ██   ██ ██      ██  ██  ██      ██   ██ 
	██████  ██   ██ ██   ██  ██████   ██████  ██   ████ ██████  ██   ██ ██   ██  ██████  ██   ████        ██    ██   ██ ██   ██  ██████ ██   ██ ███████ ██   ██                                                                                                                                                                                                                                                                                                                                                                                                     
]]
function DragonBaronTracker.Init()
	--[[
		IsDragon: 1 - Dragon, 2 - Baron
		IsAttacking: 1 - Attacking, 2 - Resetting, 3 - Dead
	]]
	DragonBaronTracker.DragonBaronTable = {
		["SRU_Dragon_Spawn_Praxis.troy"] = {IsDragon = 1, IsAttacking = 1},
		["SRU_Dragon_idle1_landing_sound.troy"] = {IsDragon = 1, IsAttacking = 2},
		["SRU_Dragon_death_sound.troy"] = {IsDragon = 1, IsAttacking = 3},
		["SRU_Baron_Base_BA1_tar.troy"] = {IsDragon = 2, IsAttacking = 1},
		["SRU_Baron_death_sound.troy"] = {IsDragon = 2, IsAttacking = 3}
	}
	DragonBaronTracker.DragonMessage = "DRAGON IS UNDER ATTACK"
	DragonBaronTracker.BaronMessage = "BARON IS UNDER ATTACK"
	DragonBaronTracker.DragonBaronStatus = {2, 2}
	local playerResolution = Renderer.GetResolution()
	DragonBaronTracker.AlertPosition =
		Vector(floor(playerResolution.x) * 0.5 - 80.0, floor(playerResolution.y) * 0.16666666666, 0)
	DragonBaronTracker.AlertRectPosition =
		Vector(
		DragonBaronTracker.AlertPosition.x - 15,
		DragonBaronTracker.AlertPosition.y,
		DragonBaronTracker.AlertPosition.z
	)
	DragonBaronTracker.BaronAlertPosition =
		Vector(
		DragonBaronTracker.AlertPosition.x,
		DragonBaronTracker.AlertPosition.y - 20,
		DragonBaronTracker.AlertPosition.z
	)
	DragonBaronTracker.BaronRectAlertPosition =
		Vector(
		DragonBaronTracker.BaronAlertPosition.x - 15,
		DragonBaronTracker.BaronAlertPosition.y,
		DragonBaronTracker.BaronAlertPosition.z
	)
	DragonBaronTracker.BaronActiveStatus = 0
	DragonBaronTracker.TextClipper = Vector(200, 15, 0)

end

function DragonBaronTracker.Menu()
    Menu.NewTree("DragonBaronTracker", "DragonBaronTracker", function ()
        Menu.Checkbox("DBT.TrackDragon", "Track Dragon", true)
        Menu.ColorPicker("DBT.TrackDragonColor", "Dragon Tracker Text Color", 0x000000FF)
        Menu.ColorPicker("DBT.TrackDragonBGColor", "Dragon Tracker Background Color", 0xCC6600FF)
        Menu.Checkbox("DBT.TrackBaron", "Track Baron", true)
        Menu.ColorPicker("DBT.TrackBaronColor", "Baron Tracker Text Color", 0x000000FF)
        Menu.ColorPicker("DBT.TrackBaronBGColor", "Baron Tracker Background Color", 0x990099FF)
        Menu.Text("The Tracker Works on Fog of War as Well")
    end)

end

local function IsBaronAttacking()
	local time = OSClock()
	if (time >= DragonBaronTracker.BaronActiveStatus) then
		DragonBaronTracker.DragonBaronStatus[2] = 2
	end
end

function DragonBaronTracker.OnDeleteObject(obj)
    local DragonBaronTable = DragonBaronTracker.DragonBaronTable[obj.Name]
    if (DragonBaronTable) then
        DragonBaronTracker.DragonBaronStatus[DragonBaronTable.IsDragon] = DragonBaronTable.IsAttacking
        -- only baron
        if (DragonBaronTable.IsDragon == 2 and DragonBaronTable.IsAttacking ~= 3) then
            local time = OSClock()
            DragonBaronTracker.BaronActiveStatus = time + 2.0
            delay(3000, IsBaronAttacking)
        end
    end
	
end

function DragonBaronTracker.OnDraw()

    local drawDragon = Menu.Get("DBT.TrackDragon", true)
    local drawBaron = Menu.Get("DBT.TrackBaron", true)
    -- Maybe I can reduce below lines later..
    if (drawDragon and DragonBaronTracker.DragonBaronStatus[1] == 1) then
        local drawDragonColor = Menu.Get("DBT.TrackDragonColor", true)
        local drawDragonBGColor = Menu.Get("DBT.TrackDragonBGColor", true)
        Renderer.DrawFilledRect(
            DragonBaronTracker.AlertRectPosition,
            DragonBaronTracker.TextClipper,
            2,
            drawDragonBGColor
        )
        Renderer.DrawText(
            DragonBaronTracker.AlertPosition,
            DragonBaronTracker.TextClipper,
            DragonBaronTracker.DragonMessage,
            drawDragonColor
        )
    end

    if (drawBaron and DragonBaronTracker.DragonBaronStatus[2] == 1) then
        local drawBaronColor = Menu.Get("DBT.TrackBaronColor", true)
        local drawBaronBGColor = Menu.Get("DBT.TrackBaronBGColor", true)
        Renderer.DrawFilledRect(
            DragonBaronTracker.BaronRectAlertPosition,
            DragonBaronTracker.TextClipper,
            2,
            drawBaronBGColor
        )
        Renderer.DrawText(
            DragonBaronTracker.BaronAlertPosition,
            DragonBaronTracker.TextClipper,
            DragonBaronTracker.BaronMessage,
            drawBaronColor
        )
    end
	
end

--[[
	 ██████  ██████   ██████  ██      ██████   ██████  ██     ██ ███    ██     ████████ ██████   █████   ██████ ██   ██ ███████ ██████  
	██      ██    ██ ██    ██ ██      ██   ██ ██    ██ ██     ██ ████   ██        ██    ██   ██ ██   ██ ██      ██  ██  ██      ██   ██ 
	██      ██    ██ ██    ██ ██      ██   ██ ██    ██ ██  █  ██ ██ ██  ██        ██    ██████  ███████ ██      █████   █████   ██████  
	██      ██    ██ ██    ██ ██      ██   ██ ██    ██ ██ ███ ██ ██  ██ ██        ██    ██   ██ ██   ██ ██      ██  ██  ██      ██   ██ 
	 ██████  ██████   ██████  ███████ ██████   ██████   ███ ███  ██   ████        ██    ██   ██ ██   ██  ██████ ██   ██ ███████ ██   ██                                                                                                                                                                                                                                                                   
]]
function CooldownTracker.Init()
	CooldownTracker.Heroes = {true, true, true, true, true, true, true, true, true, true}
	CooldownTracker.StringFormat = "%.f"
	CooldownTracker.EnumColor = {
		NotLearned = 1,
		Ready = 2,
		OnCooldown = 3,
		AlmostReady = 4,
		NoMana = 5
	}
	CooldownTracker.ColorList = {
		[1] = 0x666666FF, --NotLearned
		[2] = 0x00CC00FF, --Ready
		[3] = 0xE60000FF, --OnCooldown
		[4] = 0xff6A00FF, --AlmostReady
		[5] = 0x1AffffFF --NoMana
	}

	CooldownTracker.BoxOutline = 0x333333FF
	CooldownTracker.TextColor = 0x00FF00FF
	CooldownTracker.TextColorBlack = 0x0d0d0dFF

	-- CooldownTracker.SpellBackground = Vector(104, 5, 0)
	-- CooldownTracker.SpellBoxVector = Vector(25, 5, 0)
	-- CooldownTracker.SSBoxVector = Vector(30, 12, 0)
	CooldownTracker.SpellBackground = Vector(111, 7, 0)
	CooldownTracker.SpellBoxVector = Vector(24, 3, 0)
	CooldownTracker.SSBoxVector = Vector(30, 12, 0)
	CooldownTracker.SummonerSpellsStructure = {
		["SummonerBarrier"] = {Name = "Barrier", Path = "Summoners\\SummonerBarrier.png"},
		["SummonerBoost"] = {Name = "Cleanse", Path = "Summoners\\SummonerBoost.png"},
		["SummonerDot"] = {Name = "Ignite", Path = "Summoners\\SummonerDot.png"},
		["SummonerExhaust"] = {Name = "Exhaust", Path = "Summoners\\SummonerExhaust.png"},
		["SummonerFlash"] = {Name = "Flash", Path = "Summoners\\SummonerFlash.png"},
		["SummonerFlashPerksHextechFlashtraptionV2"] = {Name = "HexFlash", Path = "Summoners\\SummonerFlashPerksHextechFlashtraptionV2.png"},
		["SummonerHaste"] = {Name = "Ghost", Path = "Summoners\\SummonerHaste.png"},
		["SummonerHeal"] = {Name = "Heal", Path = "Summoners\\SummonerHeal.png"},
		["SummonerMana"] = {Name = "Clarity", Path = "Summoners\\SummonerMana.png"},
		["SummonerSmite"] = {Name = "Smite", Path = "Summoners\\SummonerSmite.png"},
		["S5_SummonerSmiteDuel"] = {Name = "RedSmite", Path = "Summoners\\S5_SummonerSmiteDuel.png"},
		["S5_SummonerSmitePlayerGanker"] = {Name = "BlueSmite", Path = "Summoners\\S5_SummonerSmitePlayerGanker.png"},
		["SummonerSnowball"] = {Name = "SnowBall", Path = "Summoners\\SummonerSnowball.png"},
		["SummonerTeleport"] = {Name = "Teleport", Path = "Summoners\\SummonerTeleport.png"},
		["Empty"] = {Name = "Empty", Path = "Summoners\\SummonerDarkStarChampSelect1.png"}
		--SummonerDarkStarChampSelect1.png
	}

	-- 1 is to lower side adjustment
	-- 2 is to right side adjustment
	local AdjustmentRequired = {
		["Annie"] = {1, Vector(0, 10, 0)},
		["Jhin"] = {1, Vector(0, 10, 0)},
		["Pantheon"] = {1, Vector(0, 10, 0)},
		["Irelia"] = {1, Vector(0, 10, 0)},
		["Ryze"] = {1, Vector(0, 10, 0)},
		["Zoe"] = {2, Vector(25, 0, 0)},
		["Aphelios"] = {2, Vector(52, 0, 0)},
		["Sylas"] = {2, Vector(28, 0, 0)}
	}

	CooldownTracker.count = 1
	local champList = ObjManager.Get("all", "heroes")
	for k, v in pairs(champList) do
		local objHero = v.AsHero
		if (objHero and objHero.IsValid) then
			CooldownTracker.Heroes[CooldownTracker.count] = {true, true, true}
			local adjust = AdjustmentRequired[objHero.CharName]
			if (adjust) then
				CooldownTracker.Heroes[CooldownTracker.count][3] = adjust
			else
				CooldownTracker.Heroes[CooldownTracker.count][3] = {3, nil}
			end
			local copySpell = {
				[0] = {
					Spell = nil,
					IsLearned = false,
					PctCooldown = 0.0,
					RemainingCooldown = 0.0,
					IsEnoughMana = false
				},
				[1] = {
					Spell = nil,
					IsLearned = false,
					PctCooldown = 0.0,
					RemainingCooldown = 0.0,
					IsEnoughMana = false
				},
				[2] = {
					Spell = nil,
					IsLearned = false,
					PctCooldown = 0.0,
					RemainingCooldown = 0.0,
					IsEnoughMana = false
				},
				[3] = {
					Spell = nil,
					IsLearned = false,
					PctCooldown = 0.0,
					RemainingCooldown = 0.0,
					IsEnoughMana = false
				},
				[4] = {Spell = nil, RemainingCooldown = 0.0, Name = "Empty", SSSprite = Renderer.CreateSprite(CooldownTracker.SummonerSpellsStructure["Empty"].Path,15,15)},
				[5] = {Spell = nil, RemainingCooldown = 0.0, Name = "Empty", SSSprite = Renderer.CreateSprite(CooldownTracker.SummonerSpellsStructure["Empty"].Path,15,15)}
			}

			for i = SpellSlots.Q, SpellSlots.Summoner2 do
				local t_spell = objHero:GetSpell(i)
				if (t_spell) then
					copySpell[i].Spell = t_spell
					local ssName = t_spell.Name
					local ss = CooldownTracker.SummonerSpellsStructure[ssName]
					if (ss) then
						copySpell[i].Name = ssName
						if ( i >= SpellSlots.Summoner1 ) then
							local sprite = Renderer.CreateSprite(ss.Path,15,15)
							if ( sprite ) then
								copySpell[i].SSSprite = sprite
							end
						end
					end
				end
			end
			CooldownTracker.Heroes[CooldownTracker.count][1] = copySpell
			CooldownTracker.Heroes[CooldownTracker.count][2] = objHero
			CooldownTracker.count = CooldownTracker.count + 1
		end
	end
	CooldownTracker.count = CooldownTracker.count - 1
end

function CooldownTracker.Menu()
    Menu.NewTree("CooldownTracker", "CooldownTracker", function ()
        Menu.Checkbox("CDT.TrackMe", "Track Me", true)
        Menu.Checkbox("CDT.TrackAlly", "Track Ally", true)
        Menu.Checkbox("CDT.TrackEnemy", "Track Enemy", true)
        Menu.Checkbox("CDT.Adjustment", "Adjust CDTracker Position for Champions", true)
        Menu.Text("^-> eg. Annie, Jhin, Ryze ... etc")
    end)
end

local function CDCondition(objHero)
	if (objHero.IsValid and objHero.IsVisible and not objHero.IsDead and objHero.IsOnScreen) then
		return (objHero.IsMe and Menu.Get("CDT.TrackMe", true)) or
			(objHero.IsAlly and not objHero.IsMe and Menu.Get("CDT.TrackAlly", true)) or
			(objHero.IsEnemy and Menu.Get("CDT.TrackEnemy", true))
	end
	return false
end

local function CDPercentToBox(cd, tcd)
	local result = floor(24 * cd / tcd)
	-- Because if the drawline is only 1 width, the line is kinda glitchy
	if (result >= 23) then
		return 22
	end
	return result
end

function CooldownTracker.OnTick()

		local Heroes = CooldownTracker.Heroes
		local maxHeroes = CooldownTracker.count
		local enum = CooldownTracker.EnumColor
		local copySpell, cd, tcd, mana, t_spell
		for h = 1, maxHeroes do
			local objHero = Heroes[h][2].AsHero
			if (CDCondition(objHero)) then
				for i = SpellSlots.Q, SpellSlots.R do
					copySpell = Heroes[h][1]
					if (copySpell[i].Spell.IsLearned) then
						copySpell[i].IsLearned = true
						cd = copySpell[i].Spell.RemainingCooldown
						tcd = copySpell[i].Spell.TotalCooldown
						copySpell[i].RemainingCooldown = cd
						copySpell[i].PctCooldown = CDPercentToBox(cd, tcd)

						if (cd > 0.0) then
							copySpell[i].Color = enum.NotLearned
							if (cd <= 10.0) then
								copySpell[i].Color2 = enum.AlmostReady
							else
								copySpell[i].Color2 = enum.OnCooldown
							end
						else
							copySpell[i].Color = enum.Ready
							mana = objHero.Mana - copySpell[i].Spell.ManaCost
							if (mana < 0) then
								copySpell[i].IsEnoughMana = false
								copySpell[i].Color = enum.NoMana
							else
								copySpell[i].IsEnoughMana = true
							end
						end
					else
						copySpell[i].IsLearned = false
						copySpell[i].Color = enum.NotLearned
					end
					Heroes[h][1] = copySpell
				end

				for i = SpellSlots.Summoner1, SpellSlots.Summoner2 do
					copySpell = Heroes[h][1]
					t_spell = objHero:GetSpell(i)
					if (t_spell) then
						copySpell[i].Spell = t_spell
						cd = t_spell.RemainingCooldown
						copySpell[i].RemainingCooldown = cd
						if ( cd > 0 ) then
							-- Darker
							copySpell[i].SSSprite:SetColor(0x848484ff)
						else
							-- Restore original color
							copySpell[i].SSSprite:SetColor(0xffffffff)
						end
						local ssName = t_spell.Name
						if( copySpell[i].Name ~= ssName ) then
							local ss = CooldownTracker.SummonerSpellsStructure[ssName]
							if (ss) then
								copySpell[i].Name = ssName
								local sprite = Renderer.CreateSprite(ss.Path,15,15)
								if ( sprite ) then
									copySpell[i].SSSprite = sprite
								end
							end
						end
					end
					Heroes[h][1] = copySpell
				end
			end
		end
	
end

function CooldownTracker.ShouldHPPosAdjusted(adjustment, hpPos, isVerticalAdjustment)
    local adjustmentBool = Menu.Get("CDT.Adjustment", true)
	if (adjustmentBool) then
		local adjustType = adjustment[1]
		if ((adjustType == 1 and isVerticalAdjustment) or (adjustType == 2 and not isVerticalAdjustment)) then
			return hpPos + adjustment[2]
		end
	end
	return hpPos
end

function CooldownTracker.OnDraw()

		local Heroes = CooldownTracker.Heroes
		local SpellBackground = CooldownTracker.SpellBackground
		local spellBox = CooldownTracker.SpellBoxVector
		local colorList = CooldownTracker.ColorList

		for h = 1, CooldownTracker.count do
			local objHero = Heroes[h][2].AsHero
			local cond = CDCondition(objHero)
			if (cond) then
				local adjustment = Heroes[h][3]
				local originalHpPos = objHero.HealthBarScreenPos
                local hpPos = CooldownTracker.ShouldHPPosAdjusted(adjustment, originalHpPos, true)
				local copySpell, pos, remainCD, sprite
				-- Grey box for Q to R spells
				Renderer.DrawFilledRect(Vector(hpPos.x - 48, hpPos.y - 3, 0), SpellBackground, 2, CooldownTracker.BoxOutline)
				for i = SpellSlots.Q, SpellSlots.R do
					copySpell = Heroes[h][1]
					pos = Vector(hpPos.x + 27 * i - 45, hpPos.y - 1, 0)
					remainCD = copySpell[i].RemainingCooldown
					if (remainCD > 0) then
						Renderer.DrawFilledRect(pos, spellBox, 1, colorList[CooldownTracker.EnumColor.NotLearned])
						-- Got from 48656c6c636174
						local pctPos = Vector(spellBox.x - copySpell[i].PctCooldown, spellBox.y, 0)
						Renderer.DrawFilledRect(pos, pctPos, 1, colorList[copySpell[i].Color2])
						Renderer.DrawText(
							Vector(pos.x + 4, pos.y + 7, 0),
							TextClipper,
							format(CooldownTracker.StringFormat, remainCD),
							CooldownTracker.TextColor
						)
					else
						Renderer.DrawFilledRect(pos, spellBox, 1, colorList[copySpell[i].Color])
					end
				end

				hpPos = CooldownTracker.ShouldHPPosAdjusted(adjustment, originalHpPos, false) + Vector(64, -42, 0)
				for i = SpellSlots.Summoner1, SpellSlots.Summoner2 do
					copySpell = Heroes[h][1]
					hpPos.y = hpPos.y + 16
					if (copySpell) then
						pos = Vector(hpPos.x + 17, hpPos.y, 0)
						sprite = copySpell[i].SSSprite
						if ( sprite ) then
							sprite:Draw( hpPos , nil, false)
						end
						if (copySpell[i].RemainingCooldown > 0) then
							Renderer.DrawText(
								pos,
								TextClipper,
								format(CooldownTracker.StringFormat, copySpell[i].RemainingCooldown),
								CooldownTracker.TextColor
							)
						end
					end
				end
			end
		end
	
end

--[[
	 █████   ██████ ████████ ██ ██    ██  █████  ████████  ██████  ██████  
	██   ██ ██         ██    ██ ██    ██ ██   ██    ██    ██    ██ ██   ██ 
	███████ ██         ██    ██ ██    ██ ███████    ██    ██    ██ ██████  
	██   ██ ██         ██    ██  ██  ██  ██   ██    ██    ██    ██ ██   ██ 
	██   ██  ██████    ██    ██   ████   ██   ██    ██     ██████  ██   ██                                                                                                                                                                                                                                                                                                                                      
]]
function Activator.Init()
	Activator.EnumMode = {"Combo", "Harass"}
	Activator.EnumOffensiveType = {
		Targeted = 1,
		NonTargeted = 2,
		Active = 3
	}

	Activator.Offensive = {
		[itemID.YoumuusGhostblade] = {
			Name = "Youmuus Ghostblade",
			Type = Activator.EnumOffensiveType.Targeted,
			Range = 600,
			EnemyHealth = 80,
			MyHealth = 35,
			MenuName = "Youmuus",
			Menu = {}
		},
		[itemID.Tiamat] = {
			Name = "Tiamat",
			Type = Activator.EnumOffensiveType.Active,
			Range = 350,
			EnemyHealth = 80,
			MyHealth = 35,
			MenuName = "Tiamat",
			Menu = {}
		},
		[itemID.RavenousHydra] = {
			Name = "Ravenous Hydra",
			Type = Activator.EnumOffensiveType.Active,
			Range = 350,
			EnemyHealth = 80,
			MyHealth = 35,
			MenuName = "Ravenous",
			Menu = {}
		},
		[itemID.TitanicHydra] = {
			Name = "Titanic Hydra",
			Type = Activator.EnumOffensiveType.Active,
			Range = 350,
			EnemyHealth = 80,
			MyHealth = 35,
			MenuName = "Titanic",
			Menu = {}
		},
		[6656] = {
			Name = "Everfrost",
			Type = Activator.EnumOffensiveType.NonTargeted,
			Range = 1000,
			PredictionInput = {
				Range = 1000,
				Width = 30,
				Radius = 15,
				Speed = 2000,
				Delay = 0.25,
				Collisions = {Minions = true, WindWall = true},
				Type = "Linear",
				UseHitbox = true
			},
			EnemyHealth = 80,
			MyHealth = 35,
			MenuName = "Everfrost",
			Menu = {}
		},
		[itemID.HextechProtobelt01] = {
			Name = "Hextech Protobelt-01",
			Type = Activator.EnumOffensiveType.NonTargeted,
			Range = 400,
			PredictionInput = {
				Range = 400,
				Width = 30,
				Radius = 15,
				Speed = 1150,
				Delay = 0,
				Collisions = {WindWall = true},
				Type = "Linear",
				UseHitbox = true
			},
			EnemyHealth = 80,
			MyHealth = 35,
			MenuName = "Protobelt",
			Menu = {}
		},
		[6671] = {
			Name = "GaleForce",
			Type = Activator.EnumOffensiveType.NonTargeted,
			Range = 450,
			PredictionInput = {
				Range = 450,
				Width = 30,
				Radius = 15,
				Speed = 1150,
				Delay = 0,
				Collisions = {WindWall = true},
				Type = "Linear",
				UseHitbox = true
			},
			EnemyHealth = 80,
			MyHealth = 0,
			MenuName = "GaleForce",
			Menu = {}
		},
		[6693] = {
			Name = "Prowler's Claw",
			Type = Activator.EnumOffensiveType.Targeted,
			Range = 500,
			EnemyHealth = 80,
			MyHealth = 35,
			MenuName = "Prowlersclaw",
			Menu = {}
		},
		[6630] = {
			Name = "Gore Drinker",
			Type = Activator.EnumOffensiveType.Active,
			Range = 450,
			EnemyHealth = 80,
			MyHealth = 35,
			MenuName = "GoreDrinker",
			Menu = {}
		},
	}
end

function Activator.Menu()
	Menu.NewTree("Activator", "Activator", function ()
		Menu.NewTree("Offensive", "Offensive", function ()
			for k, v in pairs(Activator.Offensive) do
				local menu = "AT."..v.MenuName
				Menu.NewTree(v.MenuName, v.Name, function ()
					Menu.Slider(menu..".EnemyHealth", "Enemy Min Health %", v.EnemyHealth, 0, 100, 1)
					Menu.Slider(menu..".MyHealth", "My Min Health %", v.MyHealth, 0, 100, 1)
					if ( k == itemID.Tiamat or k == itemID.RavenousHydra ) then
						Menu.Checkbox(menu..".FarmToggle", "Use " .. v.Name .. " on Unkilliable Minions during Farming", true)
					end
					Menu.Checkbox(menu..".Active", "Active " .. v.Name, true)
				end)
			end
		end)
        Menu.Checkbox("AT.FocusedOnly", "Use items on Focused Target ONLY", false)
    end)
end

local function FocusedCondition(Range)
	local focusedT = TS:GetForcedTarget()
	local toggle = Menu.Get("AT.FocusedOnly", true)
	local target = TS:GetTarget(Range)
	return (toggle and ((focusedT and focusedT == target) or (focusedT == nil))) or not toggle
end

function Activator.OnTick()

	if (Orbwalker.GetMode() == Activator.EnumMode[1]) then
		local target = TS:GetTarget(1000)
		if (target == nil) then
			return
		end
		for k, v in pairs(Player.Items) do
			local itemslot = k + 6
			local item = Activator.Offensive[v.ItemId]
			if (item and Menu.Get("AT.".. item.MenuName..".Active", true) and Player:GetSpellState(itemslot) == SpellStates.Ready) then
				target = TS:GetTarget(item.Range)
				local focusedCond = FocusedCondition(item.Range)
				if (target and focusedCond) then
					if
						(Player.HealthPercent <= Menu.Get("AT.".. item.MenuName..".MyHealth", true) * 0.01 or
							target.HealthPercent <= Menu.Get("AT.".. item.MenuName..".EnemyHealth", true) * 0.01)
						then
						if (item.Type == Activator.EnumOffensiveType.Targeted) then
							Input.Cast(itemslot, target)
						elseif (item.Type == Activator.EnumOffensiveType.Active) then
							Input.Cast(itemslot)
						elseif (item.Type == Activator.EnumOffensiveType.NonTargeted) then
							local prediction = Prediction.GetPredictedPosition(target, item.PredictionInput, Player.Position)
							if prediction.HitChanceEnum >= HitChance.Medium then
								Input.Cast(itemslot, prediction.CastPosition)
							end
						end
					end
				end
			end
		end
	end
	
end

local function IsTiamentOrHydra(_ItemID)
	local temp = {[itemID.Tiamat] = true, [itemID.RavenousHydra] = true}
	return (temp[_ItemID] and Menu.Get("AT.".. Activator.Offensive[_ItemID].MenuName..".FarmActive", true))
end

function Activator.OnUnkillableMinion(minion)
	if (minion:Distance(Player) <= Activator.Offensive[itemID.Tiamat].Range) then
		for k, v in pairs(Player.Items) do
			local itemslot = k + 6
			local cond = IsTiamentOrHydra(v.ItemId)
			if (cond) then
				local item = Activator.Offensive[v.ItemId]
				if (item and item.Menu.Active.Value and Player:GetSpellState(itemslot) == SpellStates.Ready) then
					Input.Cast(itemslot, minion)
				end
			end
		end
	end
end


--[[
	████████ ██    ██ ██████  ███    ██  █████  ██████   ██████  ██    ██ ███    ██ ██████  
	   ██    ██    ██ ██   ██ ████   ██ ██   ██ ██   ██ ██    ██ ██    ██ ████   ██ ██   ██ 
	   ██    ██    ██ ██████  ██ ██  ██ ███████ ██████  ██    ██ ██    ██ ██ ██  ██ ██   ██ 
       ██    ██    ██ ██   ██ ██  ██ ██ ██   ██ ██   ██ ██    ██ ██    ██ ██  ██ ██ ██   ██ 
	   ██     ██████  ██   ██ ██   ████ ██   ██ ██   ██  ██████   ██████  ██   ████ ██████                                                                                                                                                                                                                                                                                                                                                                                                                        
]]
function TurnAround.Init()
	TurnAround.TurnAroundActive = false
	TurnAround.SpellData = {
		["Cassiopeia"] = {
			["CassiopeiaR"] = {Range = 850, PreDelay = 0, PostDealy = 525, Delay = 0.5, FacingFront = false, MoveTo = 100}
		},
		["Tryndamere"] = {
			["TryndamereW"] = {Range = 850, PreDelay = 100, PostDealy = 425, Delay = 0.3, FacingFront = true, MoveTo = -100}
		}
	}
	local enemyList = ObjManager.Get("enemy", "heroes")
	for handle, enemy in pairs(enemyList) do
		if (enemy) then
			local enemyHero = enemy.AsHero
			local tr = TurnAround.SpellData[enemyHero.CharName]
			if (tr) then
				TurnAround.TurnAroundActive = true
				break
			end
		end
	end
	TurnAround.LimitIssueOrder = 0
	TurnAround.OriginalPath = Vector(0, 0, 0)

	-- if there is no turn around champion, unload the Turnaround
	if (not TurnAround.TurnAroundActive) then
		EventManager.RemoveCallback(Enums.Events.OnIssueOrder, OnIssueOrder)
		EventManager.RemoveCallback(Enums.Events.OnProcessSpell, OnProcessSpell)
		TurnAround.OnIssueOrder = nil
		TurnAround.OnProcessSpell = nil
		TurnAround.SpellData = nil
		TurnAround.TurnAroundActive = nil
	end
end

function TurnAround.Menu()
    Menu.NewTree("TurnAround", "TurnAround", function ()
        Menu.Checkbox("TA.Use", "Use TurnAround", true)
        Menu.Text("^-> Cassiopeia/Tryndamere Supported")
    end)

end

function TurnAround.OnIssueOrder(Args)
	if (Args and Menu.Get("TA.Use", true)) then
		TurnAround.OriginalPath = Args.Position
		if (TurnAround.LimitIssueOrder > OSClock()) then
			Args.Process = false
		end
	end
end

function TurnAround.OnProcessSpell(obj, spellcast)
	if (Menu.Get("TA.Use", true)) then
		local objHero = obj.AsHero
		local cond = TurnAround.TurnAroundActive and obj and objHero and Player.IsAlive and objHero.IsEnemy
		if (cond) then
			local spelldata = TurnAround.SpellData[objHero.CharName]
			if (spelldata) then
				local spell = spelldata[spellcast.Name]
				if (objHero and spell) then
					local condSpell = Player:Distance(objHero.Position) + Player.BoundingRadius <= spell.Range
					local isFacing = Player:IsFacing(objHero, 120)
					local condFacing = (isFacing and not spell.FacingFront) or (not isFacing and spell.FacingFront)
					if (condSpell and condFacing) then
						local overridePos =
							objHero.Position:Extended(Player.Position, Player.Position:Distance(objHero.Position) + spell.MoveTo)
						Input.MoveTo(overridePos)
						Input.MoveTo(overridePos)
						TurnAround.LimitIssueOrder = OSClock() + (spell.Delay)
						delay((spell.PostDealy), Input.MoveTo, TurnAround.OriginalPath)
					end
				end
			end
		end
	end
end

--[[
	████████  ██████  ██     ██ ███████ ██████      ██████   █████  ███    ██  ██████  ███████ ███████ 
	   ██    ██    ██ ██     ██ ██      ██   ██     ██   ██ ██   ██ ████   ██ ██       ██      ██      
	   ██    ██    ██ ██  █  ██ █████   ██████      ██████  ███████ ██ ██  ██ ██   ███ █████   ███████ 
	   ██    ██    ██ ██ ███ ██ ██      ██   ██     ██   ██ ██   ██ ██  ██ ██ ██    ██ ██           ██ 
	   ██     ██████   ███ ███  ███████ ██   ██     ██   ██ ██   ██ ██   ████  ██████  ███████ ███████                                                                                                                                                                                                                                                                                                                                                                                                                    
]]
-- Thanks to Thron. All credits go to him.
function TowerRanges.Init()
	TowerRanges.FountainTurrets = {["Turret_OrderTurretShrine_A"] = 1350, ["Turret_ChaosTurretShrine_A"] = 1350}
end

function TowerRanges.Menu()
    Menu.NewTree("TowerRanges", "TowerRanges", function ()
        Menu.Checkbox("TR.Enemy", "Track Enemy Towers", true)
        Menu.ColorPicker("TR.EnemyColor", "Enemy Tower Range Color", 0xFF0000FF)
        Menu.Checkbox("TR.Ally", "Track Ally Towers", true)
        Menu.ColorPicker("TR.AllyColor", "Ally Tower Range Color", 0x00FF00FF)
    end)

end

function TowerRanges.DrawRangesForTeam(team_lbl, color)
	local fountainTurrets = TowerRanges.FountainTurrets
	for k, obj in pairs(ObjManager.Get(team_lbl, "turrets")) do
		if not obj.IsDead and obj.IsOnScreen and not obj.IsInhibitor then
			local isFountainTurret = fountainTurrets[obj.Name]
			if not isFountainTurret then
				Renderer.DrawCircle3D(obj.Position, 870, 25, 1, color)
			end
		end
	end
end

function TowerRanges.OnDraw()

    local enemyTower = Menu.Get("TR.Enemy", true)
    local allyTower = Menu.Get("TR.Ally", true)
    if allyTower then
        local allyTowerColor = Menu.Get("TR.AllyColor", true)
        TowerRanges.DrawRangesForTeam("ally", allyTowerColor)
    end

    if enemyTower then
        local enemyTowerColor = Menu.Get("TR.EnemyColor", true)
        TowerRanges.DrawRangesForTeam("enemy", enemyTowerColor)
    end
	
end

--[[
	██████   █████  ████████ ██   ██     ████████ ██████   █████   ██████ ██   ██ ███████ ██████  
	██   ██ ██   ██    ██    ██   ██        ██    ██   ██ ██   ██ ██      ██  ██  ██      ██   ██ 
	██████  ███████    ██    ███████        ██    ██████  ███████ ██      █████   █████   ██████  
	██      ██   ██    ██    ██   ██        ██    ██   ██ ██   ██ ██      ██  ██  ██      ██   ██ 
	██      ██   ██    ██    ██   ██        ██    ██   ██ ██   ██  ██████ ██   ██ ███████ ██   ██                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            
]]
function PathTracker.Init()
	PathTracker.HeroList = {}
	PathTracker.DrawBox = Vector(15, 15, 0)
	PathTracker.TextClipper = Vector(55, 15, 0)
	PathTracker.HandleList = {}

	local smiteNames = { ["S5_SummonerSmiteDuel"] = true , ["S5_SummonerSmitePlayerGanker"] = true , ["SummonerSmite"] = true}
	local handleCount = 0
	local heroList = ObjManager.Get("all", "heroes")
	for handle, hero in pairs(heroList) do
		if (hero) then
			local ObjHero = hero.AsHero
			local isJungler = false
			local ss1 = ObjHero:GetSpell(Enums.SpellSlots.Summoner1)
			local ss2 = ObjHero:GetSpell(Enums.SpellSlots.Summoner2)
			if ( ss1 and ss2 ) then
				if( smiteNames[ss1.Name] or smiteNames[ss2.Name]) then
					isJungler = true
				end
			end
			PathTracker.HeroList[handle] = {Hero = ObjHero, Pathing = nil, ETA = 0, IsJungler = isJungler}
			handleCount = handleCount + 1
			PathTracker.HandleList[handleCount] = handle
		end
	end
end

function PathTracker.Menu()
    Menu.NewTree("PathTracker", "PathTracker", function ()
        Menu.Checkbox("PT.Enemy", "Track Enemy Path", true)
        Menu.ColorPicker("PT.EnemyColor", "Enemy Path Color", 0xFFFFFFFF)
        Menu.Checkbox("PT.Ally", "Track Ally Path", true)
        Menu.ColorPicker("PT.AllyColor", "Ally Path Color", 0x008000FF)
        Menu.Checkbox("PT.Waypoints", "Track Waypoints", true)
        Menu.ColorPicker("PT.WaypointsColor", "Waypoints Color", 0xFFFFFFFF)
        Menu.Checkbox("PT.ETA", "Show Estimated Arrival Time", true)
        Menu.Checkbox("PT.CharName", "Show Champion Name", true)
		Menu.ColorPicker("PT.ETAnNameColor", "ETA/ChampName Color", 0xFFFFFFFF)
		Menu.Checkbox("PT.OnlyJungler", "Track Only Junglers' Path", false)
        
    end)
end

local function CalculateETA(dis, MoveSpeed)
	return (dis / MoveSpeed)
end

local function ETAToSeconds(Seconds)
	return format("%02.f", floor(Seconds))
end

local function IsTeam(IsAlly, this, MenuType)
	return ((IsAlly and Menu.Get(MenuType..".Ally", true)) or (not IsAlly and Menu.Get(MenuType..".Enemy", true)))
end

local function TeamColor(isAlly, this, menuType)
    local str = "AllyColor"
	if (not isAlly) then
		str = "EnemyColor"
    end
    
    return Menu.Get(menuType.."."..str, true)
end


-- Thanks to Thron
function PathTracker.OnDraw()
	local IsOnScreen = Renderer.IsOnScreen
	local drawETA = Menu.Get("PT.ETA", true)
	local drawCharName = Menu.Get("PT.CharName", true)
	local drawColor = Menu.Get("PT.ETAnNameColor", true)
	local onlyJungler = Menu.Get("PT.OnlyJungler", true)

	for i, entry in ipairs(PathTracker.HandleList) do
		local value = PathTracker.HeroList[entry]
		if ( (onlyJungler and value.IsJungler) or not onlyJungler) then
			local hero, pathing, endTime = value.Hero.AsHero, value.Pathing, value.ETA
			if (pathing and pathing.IsMoving and not hero.IsDead) then
				local vEndPos = pathing.EndPos
				local waypoints = pathing.Waypoints
				local curWP = pathing.CurrentWaypoint
				for i = curWP, #waypoints - 1 do
					local endPos = waypoints[i + 1]
					if (IsOnScreen(endPos)) then
						local startPos = (i == curWP and hero.Position) or waypoints[i]
						Renderer.DrawLine3D(startPos, endPos, 1, 0xFFFF00FF)
					end
				end

				if (IsOnScreen(vEndPos)) then
					if drawCharName then
						local drawName = Renderer.WorldToScreen(Vector(vEndPos.x - 30, vEndPos.y, vEndPos.z))
						Renderer.DrawText(drawName, TextClipperLarger, hero.CharName, drawColor)
					end

					if drawETA then
						local drawTime = Renderer.WorldToScreen(Vector(vEndPos.x - 10, vEndPos.y - 35, vEndPos.z))
						Renderer.DrawFilledRect(drawTime, PathTracker.DrawBox, 2, TeamColor(hero.IsAlly, PathTracker, "PT"))
						local time = endTime - OSClock()
						if (time < 0) then
							value.Pathing = nil
							value.ETA = 0
						else
							Renderer.DrawText(drawTime, TextClipperLarger, ETAToSeconds(time), drawColor)
						end
					end
				end
			end
		end
	end
end

function PathTracker.OnNewPath(obj, pathing)

	local cond = obj and obj.IsHero and obj.IsVisible and not obj.IsMe and (IsTeam(obj.IsAlly, PathTracker, "PT"))
	if (cond) then
		local Handle = obj.Handle
		if (Handle) then
			local enemy = PathTracker.HeroList[Handle]
			local onlyJungler = Menu.Get("PT.OnlyJungler", true)
			if (enemy and ((onlyJungler and enemy.IsJungler) or not onlyJungler)) then
                PathTracker.HeroList[Handle].Pathing = pathing
                local eta = Menu.Get("PT.ETA", true)
				if (eta) then
					local waypoints = pathing.Waypoints
					local ETA = 0.0
					local movespeed = obj.MoveSpeed

					for i = 1, #waypoints - 1 do
						local startPos, endPos = waypoints[i], waypoints[i + 1]
						local dis = startPos:Distance(endPos)
						ETA = ETA + CalculateETA(dis, movespeed)
					end

					if (ETA >= 1.0) then
						PathTracker.HeroList[Handle].ETA = OSClock() + ETA
					end
				end
			end
		end
	end
end

--[[
	██████  ██       ██████   ██████ ██   ██     ███    ███ ██ ███    ██ ██  ██████  ███    ██ 
	██   ██ ██      ██    ██ ██      ██  ██      ████  ████ ██ ████   ██ ██ ██    ██ ████   ██ 
	██████  ██      ██    ██ ██      █████       ██ ████ ██ ██ ██ ██  ██ ██ ██    ██ ██ ██  ██ 
	██   ██ ██      ██    ██ ██      ██  ██      ██  ██  ██ ██ ██  ██ ██ ██ ██    ██ ██  ██ ██ 
	██████  ███████  ██████   ██████ ██   ██     ██      ██ ██ ██   ████ ██  ██████  ██   ████                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                
]]
function BlockMinion.Init()
	BlockMinion.TargetMinion = nil
	BlockMinion.GetMinion = false
	BlockMinion.ToggleCondition = false
	BlockMinion.BlockOnMsg = "Blocking ON"
	BlockMinion.FindingMsg = "Fidning a Minion.."
	BlockMinion.TextClipper = Vector(150, 15, 0)
	BlockMinion.LocalTick = 0
end

function BlockMinion.Menu()
    Menu.NewTree("BlockMinion", "BlockMinion", function ()
        Menu.Checkbox("BM.Use", "Use Block Minion", true)
        Menu.Keybind("BM.Key", "Blocking Key", string.byte('Z'), false, false)
    end)

end

local function TurnOffBlockMinion()
	BlockMinion.targetMinion = nil
	BlockMinion.GetMinion = false
end

local function BlockCondition()
    local useBlock = Menu.Get("BM.Use", true)
    local blockKey = Menu.Get("BM.Key", true)
	if (useBlock and not blockKey) then
		TurnOffBlockMinion()
		return false
	end
	return (useBlock and blockKey)
end

local function GetTheClosetMinion()
	local closetMinion = nil
	local minionList = ObjManager.Get("ally", "minions")
	local mindis = 500
	for handle, minion in pairs(minionList) do
		local distance = Player:Distance(minion)
		local minionAI = minion.AsAI
		local isFacing = minionAI:IsFacing(Player, 120)
		if
			(minionAI and distance < mindis and isFacing and minionAI.MoveSpeed > 0 and minionAI.Pathing.IsMoving and
				minionAI.IsVisible)
		 then
			local direction = minionAI.Direction
			if (direction) then
				closetMinion = minion
				mindis = distance
			end
		end
	end
	return closetMinion
end

function BlockMinion.OnUpdate()
	local tick = OSClock()
	if (BlockMinion.LocalTick < tick) then
		BlockMinion.LocalTick = tick + 0.1
		local cond = BlockCondition()
		if (cond) then
			local tgminion = BlockMinion.targetMinion
			if (not BlockMinion.GetMinion) then
				tgminion = GetTheClosetMinion()
				if (not tgminion) then
					BlockMinion.targetMinion = nil
					return
				end
				BlockMinion.targetMinion = tgminion
				BlockMinion.GetMinion = true
			end
			if (tgminion and tgminion.IsValid) then
				local minionAI = tgminion.AsAI
				if (minionAI) then
					local direction = minionAI.Direction
					local isFacing = minionAI:IsFacing(Player, 160)
					if (not isFacing) then
						TurnOffBlockMinion()
					else
						if (direction and minionAI.Pathing.IsMoving and minionAI.IsVisible) then
							local extend = minionAI.Position:Extended(direction, -150)
							local mousepos = Renderer:GetMousePos()
							local newextend = extend:Extended(mousepos, 40)
							Input.MoveTo(newextend)
						end
					end
				end
			end
		end
	end
end

function BlockMinion.OnDraw()
    local blockKey = Menu.Get("BM.Key", true)
	if (blockKey) then
		local cond = BlockCondition()
		BlockMinion.ToggleCondition = cond
		if (cond) then
			local color = 0x00FF00FF
			local str = BlockMinion.FindingMsg
			local tg = BlockMinion.targetMinion
			if (tg and tg.IsValid) then
				local tgMinion = tg.AsAI
				if (tgMinion) then
					Renderer.DrawCircle3D(tgMinion.Position, 50, 15, 1, color)
					str = BlockMinion.BlockOnMsg
				end
			end
			local adjust = Renderer.WorldToScreen(Player.Position) + Vector(0, 20, 0)
			Renderer.DrawText(adjust, BlockMinion.TextClipper, str, color)
		end
	end
end

--[[
	███████ ███████ ██    ██ ████████ ██ ██      ██ ████████ ██    ██ 
	██      ██      ██    ██    ██    ██ ██      ██    ██     ██  ██  
	███████ ███████ ██    ██    ██    ██ ██      ██    ██      ████   
	     ██      ██ ██    ██    ██    ██ ██      ██    ██       ██    
	███████ ███████  ██████     ██    ██ ███████ ██    ██       ██                                                            
]]
function SSUtility.Init()
	SSUtility.Flash = {["SummonerFlash"] = 1, ["SummonerTeleport"] = 2}
	SSUtility.Ingite = "SummonerDot"
	SSUtility.Slot = {-1, -1}
	local HasSS = false
	for i = Enums.SpellSlots.Summoner1, Enums.SpellSlots.Summoner2 do
		local flash = Player:GetSpell(i)
		local flashTable = SSUtility.Flash[flash.Name]
		if (flash and flashTable) then
			HasSS = true
			SSUtility.Slot[flashTable] = i
		end
	end

	if (not HasSS) then
		EventManager.RemoveCallback(Enums.Events.OnCastSpell, OnCastSpell)
		SSUtility.OnCastSpell = nil
		SSUtility.Flash = nil
		SSUtility.Slot = nil
		SSUtility.Ingite = nil
	end
end

function SSUtility.Menu()
    Menu.NewTree("SSUtility", "SSUtility", function ()
        Menu.Checkbox("SU.ExtendedFlash", "Use Extended Flash", true)
        Menu.Checkbox("SU.Ignite", "Block Flash 1", true)
        Menu.Text("^- If you die from Ignite", false)
        Menu.Checkbox("SU.OverWall", "Block Flash 2", true)
        Menu.Text("^- If you can't flash over the wall", false)
        Menu.Checkbox("SU.NearTP", "Block TP", true)
        Menu.Text("^- If you tp to a too close location", false)
    end)

end

local function GetIgniteDmg(duration, level)
	return floor(duration) * (50 + 20 * level) / 5
end

-- All credits go to Thron, I basically copy pasted it from his source
local function GetClosestNonWall(position)
	local wholeCircle = 2.0 * math.pi
	local stepRadius = 40.0
	local posChecked = 0
	local indexRadius = 0
	while (posChecked < 500) do
		indexRadius = indexRadius + 1
		local curRadius = indexRadius * stepRadius
		if (curRadius > 500) then
			break
		end
		local curCircleChecks = math.ceil((wholeCircle * curRadius) / stepRadius)

		for i = 1, curCircleChecks do
			posChecked = posChecked + 1
			local rotationAngle = ((wholeCircle / (curCircleChecks - 1)) * i)
			local pos =
				Vector(position.x + curRadius * math.sin(rotationAngle), 0, position.z + curRadius * math.cos(rotationAngle))
			if (not Nav.IsWall(pos)) then
				return pos
			end
		end
	end
end

function SSUtility.OnCastSpell(Args)

	local slot = SSUtility.Slot
    local extendedFlash = Menu.Get("SU.ExtendedFlash", true)
    local flashIgnite = Menu.Get("SU.Ignite", true)
    local flashOverwall = Menu.Get("SU.OverWall", true)
    local nearTP = Menu.Get("SU.NearTP", true)
	-- flash
	if (Args.Slot == slot[1]) then
		if (flashIgnite) then
			local buff = Player:GetBuff(SSUtility.Ingite)
			if (buff) then
				local dmg = GetIgniteDmg(buff.DurationLeft, buff.Source.AsHero.Level)
				if (Player.Health <= dmg) then
					Args.Process = false
				end
			end
		end

		if (flashOverwall) then
			local mousePos = Renderer.GetMousePos()
			local IsWall = Player.Position:Extended(mousePos, 450)
			if (Nav.IsWall(IsWall)) then
				local nonWallPos = GetClosestNonWall(IsWall)
				if (nonWallPos) then
					local distancePlayer = nonWallPos:Distance(Player.Position)
					if (distancePlayer < 450) then
						Args.Process = false
					end
				end
			end
		end

		if (extendedFlash) then
			local distance = Player:Distance(Args.TargetEndPosition)
			if (distance < 400) then
				local extended = Player.Position:Extended(Args.TargetEndPosition, 450)
				Args.Process = false
				Input.Cast(slot[1], extended)
			end
		end
	end

	-- tp
	if (Args.Slot == slot[2]) then
		if (nearTP) then
			local distance = Player:Distance(Args.TargetEndPosition)
			if (distance < 550) then
				Args.Process = false
			end
		end
	end
end

--[[
	██████  ███████  ██████  █████  ██      ██          ████████ ██████   █████   ██████ ██   ██ ███████ ██████  
	██   ██ ██      ██      ██   ██ ██      ██             ██    ██   ██ ██   ██ ██      ██  ██  ██      ██   ██ 
	██████  █████   ██      ███████ ██      ██             ██    ██████  ███████ ██      █████   █████   ██████  
	██   ██ ██      ██      ██   ██ ██      ██             ██    ██   ██ ██   ██ ██      ██  ██  ██      ██   ██ 
	██   ██ ███████  ██████ ██   ██ ███████ ███████        ██    ██   ██ ██   ██  ██████ ██   ██ ███████ ██   ██                                                                                                         
]]
function RecallTracker.Init()
	RecallTracker.RecallingList = {}
	RecallTracker.ActiveHeroes = {}
	RecallTracker.MouseEvent = {[513] = 1, [514] = 2}
	RecallTracker.Status = {["Invalid"] = 0, ["Started"] = 1, ["Interrupted"] = 2, ["Finished"] = 3}
	local heroList = ObjManager.Get("enemy", "heroes")
	for handle, hero in pairs(heroList) do
		if (hero) then
			local objHero = hero.AsHero
			RecallTracker.RecallingList[handle] = {
				CharName = objHero.CharName,
				RecallName = 0,
				Duration = 0,
				ETA = 0,
				Status = 0,
				IsActive = false
			}
			-- hate to use table.insert but no choice
			table.insert(RecallTracker.ActiveHeroes, handle)
		end
	end
	local resolution = Renderer.GetResolution()
	RecallTracker.DefaultLocation = Vector(resolution.x * 0.70, resolution.y * 0.80, 0)
	RecallTracker.IsDragging = false
	RecallTracker.BoxSize = Vector(200, 18, 0)
	RecallTracker.TestText = " CHAMPION "
end

function RecallTracker.Menu()
    Menu.NewTree("RecallTracker", "RecallTracker", function ()
        -- 16 is Left Shift
        Menu.Keybind("RT.Key", "Adjust Key (Default: Shift)", 16, false, false)
        Menu.Checkbox("RT.AdjustToggle", "Adjust Position", true)
        Menu.Slider("RT.AdjustX", "Adjust X", 0, -1500, 1000, 10)
        Menu.Slider("RT.AdjustY", "Adjust Y", 0, -1500, 1000, 10)
    end)

end

local function DecodeRecallStatus(status, name)
	local returnArray = {"Recall", 0x1972D2FF}
	local tp = {["SummonerTeleport"] = true}
	if (tp[name]) then
		returnArray[1] = "Teleport"
		returnArray[2] = 0xA901DBFF
	end
	if (status == 2) then
		returnArray[1] = "Interrupted " .. returnArray[1]
		returnArray[2] = 0xB40404FF
	elseif (status == 3) then
		returnArray[1] = "Finished " .. returnArray[1]
		returnArray[2] = 0x088A08FF
	end
	return returnArray
end

function RecallTracker.OnDraw()
    local adjustKey = Menu.Get("RT.Key", true)
    local adjustToggle = Menu.Get("RT.AdjustToggle", true)
    local adjustX = Menu.Get("RT.AdjustX", true)
    local adjustY = Menu.Get("RT.AdjustY", true)
		if (RecallTracker.IsDragging) then
			local mousePos = Renderer.GetCursorPos()
			local x_diff = mousePos.x - RecallTracker.DefaultLocation.x
			local y_diff = mousePos.y - RecallTracker.DefaultLocation.y
			adjustX = x_diff
			adjustY = y_diff
		end

		local drawLocation
		-- test drawing
		if (adjustKey) then
			drawLocation =
				Vector(
				RecallTracker.DefaultLocation.x + adjustX,
				RecallTracker.DefaultLocation.y + adjustY,
				0
			)
			local boxSize = RecallTracker.BoxSize
			local testText = RecallTracker.TestText
			for i = 1, 5 do
				Renderer.DrawFilledRect(drawLocation, boxSize, 2, 0x132121FF)
				Renderer.DrawRectOutline(drawLocation, boxSize, 2, 4, 0x17322FFF)
				Renderer.DrawRectOutline(drawLocation, boxSize, 2, 2, 0x685937FF)
				Renderer.DrawText(Vector(drawLocation.x + 5, drawLocation.y + 2, 0), boxSize, testText, 0xFFFFFFFF)
				drawLocation = drawLocation + Vector(0, 23, 0)
			end
		else
			drawLocation =
				Vector(
				RecallTracker.DefaultLocation.x + adjustX,
				RecallTracker.DefaultLocation.y + adjustY,
				0
			)
			local boxSize = RecallTracker.BoxSize
			local count = #RecallTracker.ActiveHeroes
			for i = 1, count do
				local target = RecallTracker.RecallingList[RecallTracker.ActiveHeroes[i]]
				if (target.IsActive) then
					local eta = target.ETA - OSClock()
					if (eta < 0.0) then
						target.IsActive = false
					else
						Renderer.DrawFilledRect(drawLocation, boxSize, 2, 0x132121FF)
						local currentStatus = DecodeRecallStatus(target.Status, target.RecallName)
						local text = target.CharName .. " " .. currentStatus[1]
						if (target.Status == 1) then
							local pct = floor((boxSize.x * (1 / target.Duration) * eta))
							local pctPos = Vector(pct, boxSize.y, 0)
							Renderer.DrawFilledRect(drawLocation, pctPos, 1, currentStatus[2])
							text = text .. " - " .. format("%.1f", eta)
						else
							Renderer.DrawFilledRect(drawLocation, boxSize, 1, currentStatus[2])
						end
						Renderer.DrawRectOutline(drawLocation, boxSize, 2, 4, 0x17322FFF)
						Renderer.DrawRectOutline(drawLocation, boxSize, 2, 2, 0x685937FF)
						Renderer.DrawText(Vector(drawLocation.x + 5, drawLocation.y + 2, 0), boxSize, text, 0xFFFFFFFF)
						drawLocation = drawLocation + Vector(0, 23, 0)
					end
				end
			end
		end
	
end

local function GetRecallStatus(status)
	local currentStatus = RecallTracker.Status[status]
	if (currentStatus) then
		return currentStatus
	end
	-- Invalid status
	return 0
end

local function GetExtraDuration(duration, status)
	if (duration ~= 0 and status == 1) then
		return duration
	end
	return 3
end

function RecallTracker.OnTeleport(obj, name, duration_secs, status)
	if (obj.IsEnemy) then
		local i_status = GetRecallStatus(status)
		local duration = GetExtraDuration(duration_secs, i_status)
		local ETA = OSClock() + duration
		local recallHero = RecallTracker.RecallingList[obj.Handle]
		if (recallHero) then
			recallHero.RecallName = name
			recallHero.Duration = duration_secs
			recallHero.ETA = ETA
			recallHero.Status = GetRecallStatus(status)
			recallHero.IsActive = true
		end
	end
end

function RecallTracker.OnMouseEvent(e)

        local adjustKey = Menu.Get("RT.Key", true)
        local adjustToggle = Menu.Get("RT.AdjustToggle", true)
		if (adjustKey and adjustToggle) then
			local event = RecallTracker.MouseEvent[e]
			-- 513 is Left Mouse Down
			if (event) then
                if (event == 1) then
                    local adjustX = Menu.Get("RT.AdjustX", true)
                    local adjustY = Menu.Get("RT.AdjustY", true)
					local tempLocation =
						Vector(
						RecallTracker.DefaultLocation.x + adjustX,
						RecallTracker.DefaultLocation.y + adjustY,
						0
					)
					local mousePos = Renderer.GetCursorPos()
					local distance = tempLocation:Distance(mousePos)
					if (distance < 200) then
						RecallTracker.IsDragging = true
					end
				else
					RecallTracker.IsDragging = false
				end
			end
		end
	
end

--[[
	██     ██  █████  ██████  ██████      ████████ ██████   █████   ██████ ██   ██ ███████ ██████  
	██     ██ ██   ██ ██   ██ ██   ██        ██    ██   ██ ██   ██ ██      ██  ██  ██      ██   ██ 
	██  █  ██ ███████ ██████  ██   ██        ██    ██████  ███████ ██      █████   █████   ██████  
	██ ███ ██ ██   ██ ██   ██ ██   ██        ██    ██   ██ ██   ██ ██      ██  ██  ██      ██   ██ 
	 ███ ███  ██   ██ ██   ██ ██████         ██    ██   ██ ██   ██  ██████ ██   ██ ███████ ██   ██ 																					
]]

function WardTracker.Init()

	WardTracker.WardTypes = {
		PinkWard = 0,
		BlueTrinket = 1,
		YellowTrinket = 2,
		SightWard = 3,
		GhostPoro = 4,
		ZombieWard = 5
	}
	local folderPath = "Wards\\"
	local spritePaths = {
		[WardTracker.WardTypes.SightWard] = folderPath.."Totem_Ward_icon.png",
		[WardTracker.WardTypes.PinkWard] = folderPath.."Control_Ward_icon.png",
		[WardTracker.WardTypes.YellowTrinket] = folderPath.."Totem_Ward_icon.png",
		[WardTracker.WardTypes.BlueTrinket] = folderPath.."Blue_Ward_icon.png",
	}
	
	local spriteSize = {x= 40, y=40}
	local spriteMiniSize = {x=24, y=24}
	
	WardTracker.WardsInfo = {
		["SightWard"] = {Duration = 150, Color = 0x0, Type = WardTracker.WardTypes.SightWard, Sprite = Renderer.CreateSprite(spritePaths[WardTracker.WardTypes.SightWard],spriteSize.x,spriteSize.y), MiniMapSprite = Renderer.CreateSprite(spritePaths[WardTracker.WardTypes.SightWard],spriteMiniSize.x,spriteMiniSize.y) },
		["JammerDevice"] = {Duration = -1, Color = 0x0, Type = WardTracker.WardTypes.PinkWard, Sprite = Renderer.CreateSprite(spritePaths[WardTracker.WardTypes.PinkWard],spriteSize.x,spriteSize.y), MiniMapSprite = Renderer.CreateSprite(spritePaths[WardTracker.WardTypes.PinkWard],spriteMiniSize.x,spriteMiniSize.y) },
		["YellowTrinket"] = {Duration = 90, Color = 0x0, Type = WardTracker.WardTypes.YellowTrinket, Sprite = Renderer.CreateSprite(spritePaths[WardTracker.WardTypes.YellowTrinket],spriteSize.x,spriteSize.y), MiniMapSprite = Renderer.CreateSprite(spritePaths[WardTracker.WardTypes.YellowTrinket],spriteMiniSize.x,spriteMiniSize.y) },
		["BlueTrinket"] = {Duration = -1, Color = 0x0, Type = WardTracker.WardTypes.BlueTrinket, Sprite = Renderer.CreateSprite(spritePaths[WardTracker.WardTypes.BlueTrinket],spriteSize.x,spriteSize.y), MiniMapSprite = Renderer.CreateSprite(spritePaths[WardTracker.WardTypes.BlueTrinket],spriteMiniSize.x,spriteMiniSize.y) },
		["DominationScout"] = {Duration = 61, Color = 0x0, Type = WardTracker.WardTypes.GhostPoro, Sprite = Renderer.CreateSprite(spritePaths[WardTracker.WardTypes.SightWard],spriteSize.x,spriteSize.y), MiniMapSprite = Renderer.CreateSprite(spritePaths[WardTracker.WardTypes.SightWard],spriteMiniSize.x,spriteMiniSize.y)},
	--	["Perks_CorruptedWard_Idle"] = {Duration = 120, Color = 0x0, Type = WardTracker.WardTypes.ZombieWard, Sprite = Renderer.CreateSprite(spritePaths[WardTracker.WardTypes.SightWard],spriteSize.x,spriteSize.y), MiniMapSprite = Renderer.CreateSprite(spritePaths[WardTracker.WardTypes.SightWard],spriteMiniSize.x,spriteMiniSize.y)},
	}

	WardTracker.SpellCastInfo = {
		["ItemGhostWard"] = {Name = "SightWard", Type = WardTracker.WardTypes.SightWard},
		["JammerDevice"] = {Name = "JammerDevice", Type = WardTracker.WardTypes.PinkWard},
		["TrinketTotemLvl1"] = {Name = "YellowTrinket", Type = WardTracker.WardTypes.YellowTrinket},
		["TrinketOrbLvl3"] = {Name = "BlueTrinket", Type = WardTracker.WardTypes.BlueTrinket},
	}

	WardTracker.ManullyAddedWards = {
	}

	WardTracker.DeleteManualWards = {
		["WardCorpse"] = true,
	}

	WardTracker.CurrentWards = {}

	WardTracker.SavedYellowTrinketDuration = 90
end

function WardTracker.Menu()
    Menu.NewTree("WardTracker", "WardTracker", function ()
        Menu.Checkbox("WT.DrawMap", "Draw on the Map", true)
		Menu.Checkbox("WT.DrawMapTimer", "Draw Timer on the Map", true)
		Menu.Checkbox("WT.DrawMiniMap", "Draw on the MiniMap", true)
    end)
end

local function IsWardValid(ward, manuallyAdded )
	return (not manuallyAdded and ward and ward.IsValid and not ward.IsDead ) or (ward and manuallyAdded)
end

local function WardDrawCondition(wardPos)
	return (Renderer.IsOnScreen(wardPos))
end

local function GetAverageAllChamps()
	local objList = ObjManager.Get("all", "heroes")
	local avg = 0
	local numberOfHeroes = 0
	for handle, hero in pairs(objList) do
		local heroAI = hero.AsHero
		if( heroAI and heroAI.Level) then
			avg = avg + heroAI.Level
			numberOfHeroes = numberOfHeroes + 1
		end
	end
	if ( avg == 0 ) then
		return 1
	end
	return floor( (avg / numberOfHeroes) + 0.5)
end

-- 88.235 + 1.765*average of all champion levels
local function GetYellowTrinketDuration()
	return 88.235 + 1.765*GetAverageAllChamps()
end

function WardTracker.AddWards(objString)
	local objList = ObjManager.Get("all", objString)
	local gameTime = Game:GetTime()
	for handle, ward in pairs(objList) do
		if( ward and not ward.IsAlly) then 
			if (not WardTracker.CurrentWards[handle]) then
				local wardAI = ward.AsAI
				if ( wardAI ) then
					local name = wardAI.CharName
					local isWard = WardTracker.WardsInfo[name]
					if ( name and isWard) then
						local cond = IsWardValid(wardAI, false)
						if ( cond and isWard) then
							local duration = isWard.Duration
							if( isWard.Type ~= WardTracker.WardTypes.GhostPoro and duration < wardAI.Mana ) then
								duration = wardAI.Mana
							elseif ( isWard.Type == WardTracker.WardTypes.YellowTrinket and duration > wardAI.Mana) then
								duration = WardTracker.SavedYellowTrinketDuration
							end
							local wardStruct = {Object= ward, Position = ward.Position,Type = isWard.Type, EndTime = gameTime + duration, Sprite = isWard.Sprite, MiniMapSprite = isWard.MiniMapSprite, IsManuallyAdded = false}
							WardTracker.CurrentWards[handle] = wardStruct
						
						else
							WardTracker.CurrentWards[handle] = nil
						end
					end
				end
			end

			for i, v in ipairs(WardTracker.ManullyAddedWards) do
				if ( v ) then
					local distance = v.Position:Distance(ward)
					-- if there is already a manual ward, remove it 
					if( distance < 50 ) then
						WardTracker.CurrentWards[WardTracker.ManullyAddedWards[i].Index] = nil
						WardTracker.ManullyAddedWards[i] = nil
						break
					end
				end
			end
		end
		
	end
end

function WardTracker.OnProcessSpell(obj, spellcast)
	if( spellcast.Slot >= 6 and spellcast.Name and not obj.IsAlly ) then
		local wardSpell = WardTracker.SpellCastInfo[spellcast.Name]
		if( wardSpell ) then
			local endPos = spellcast.EndPos
			local newDuration = 90
			if( wardSpell.Type == WardTracker.WardTypes.YellowTrinket) then
				newDuration = GetYellowTrinketDuration()
				WardTracker.SavedYellowTrinketDuration = newDuration
			end

			if (Nav.IsWall(endPos)) then
				endPos = GetClosestNonWall(spellcast.EndPos)
			end
			-- The reason why I do delay is my OnTick() has 0.3 delay, so the CurrentWards may not updated to know there is a duplicate ward 
			delay(400, function (endPos)
				for k, ward in pairs(WardTracker.CurrentWards) do
					if( IsWardValid(ward.Object, ward.manuallyAdded) ) then
						local distance = ward.Position:Distance(endPos)
						-- if there is already a ward
						if( distance < 100 ) then
							return
						end
					else
						WardTracker.CurrentWards[k] = nil
					end
				end

				local currentTime = Game:GetTime()
				local index = floor(endPos.x)
				local newWard = WardTracker.CurrentWards[index]
	
				-- find an empty space since we don't know the ward's handle
				while(newWard)
				do
					index = index + index
					newWard = WardTracker.CurrentWards[index]
				end
				local isWard = WardTracker.WardsInfo[wardSpell.Name]
				local duration = isWard.Duration;
				if( wardSpell.Type == WardTracker.WardTypes.YellowTrinket) then
					duration = newDuration
				end
				local wardStruct = {Object= obj, Position = endPos, Type = wardSpell.Type, EndTime = currentTime + duration, Sprite = isWard.Sprite, MiniMapSprite = isWard.MiniMapSprite, IsManuallyAdded = true}
				WardTracker.CurrentWards[index] = wardStruct
				local manuallyAddedWard = {Index = index, Position = endPos}
				table.insert(WardTracker.ManullyAddedWards, manuallyAddedWard)
			end, endPos)
		end
	end
end

function WardTracker.OnCreateObject(obj)
	local objName = obj.Name
	if( objName and obj.IsMinion and not obj.IsAlly)  then
		local wardDeath = WardTracker.DeleteManualWards[objName]
		if( wardDeath ) then
			for k, ward in pairs(WardTracker.CurrentWards) do
				if( ward and ward.IsManuallyAdded ) then
					local distance = ward.Position:Distance(obj.Position)
					if( distance < 100 ) then
						WardTracker.CurrentWards[k] = nil
						return
					end
				end
			end
		end
	end
end


function WardTracker.OnTick()
	-- The reason why I'm using minion object get is some wards are actually considered as Minion somehow.
	WardTracker.AddWards("minions")
	WardTracker.AddWards("wards")
end

function WardTracker.OnDraw()
	local drawMap = Menu.Get("WT.DrawMap", true)
	local drawTimer = Menu.Get("WT.DrawMapTimer", true)
	local drawMiniMap = Menu.Get("WT.DrawMiniMap", true)
	local currentTime = Game:GetTime()
	for k, ward in pairs(WardTracker.CurrentWards) do
		if( ward) then
			local wardObj = ward.Object
			if (ward.IsManuallyAdded and ward.Type >= WardTracker.WardTypes.YellowTrinket and ward.EndTime < currentTime) then
				WardTracker.CurrentWards[k] = nil
			elseif ( IsWardValid(wardObj, ward.manuallyAdded) ) then
				if (WardDrawCondition(ward.Position)) then
					if ( drawMap ) then
						ward.Sprite:Draw( Renderer.WorldToScreen(ward.Position) , nil, true)
					end
					if (drawTimer and ward.Type >= WardTracker.WardTypes.YellowTrinket and ward.EndTime > currentTime) then
						Renderer.DrawText(Renderer.WorldToScreen(ward.Position) - Vector(10,-10,0), Vector(150,5,0), SecondsToClock(ward.EndTime-currentTime), 0xFFFFFFFF)
					end
				end
				if ( drawMiniMap) then
					ward.MiniMapSprite:Draw( Renderer.WorldToMinimap(ward.Position) , nil, true)
				end
			else
				WardTracker.CurrentWards[k] = nil
			end
		end
	end
end


--[[
	███    ███  █████  ██ ███    ██ 
	████  ████ ██   ██ ██ ████   ██ 
	██ ████ ██ ███████ ██ ██ ██  ██ 
	██  ██  ██ ██   ██ ██ ██  ██ ██ 
	██      ██ ██   ██ ██ ██   ████ 
]]

function IsFeatureEnabled(shortName)
	if(shortName ) then
		local checkBox = Menu.Get(shortName, true)
		if(checkBox) then
			return true
		end
	end
	return false
end

function OnUnkillableMinion(minion)
	local unkillable = Activator.OnUnkillableMinion
	if (minion and unkillable and IsFeatureEnabled("AT") ) then
		unkillable(minion)
	end
end

function OnUpdate()
	local update = BlockMinion.OnUpdate
	if ( update and IsFeatureEnabled("BM") ) then
		update()
	end
end

function OnIssueOrder(Args)
	local issueOrder = TurnAround.OnIssueOrder
	if ( Args and issueOrder and IsFeatureEnabled( "TA") ) then
		TurnAround.OnIssueOrder(Args)
	end
end

function OnProcessSpell(obj, spellcast)
	if ( obj and spellcast) then
		local isHero = obj.IsHero
		if( not isHero) then
			return
		end
		local onProcess = TurnAround.OnProcessSpell
		if ( onProcess and IsFeatureEnabled("TA") ) then
			onProcess(obj, spellcast)
		end

		local onProcess = WardTracker.OnProcessSpell
		if ( onProcess and IsFeatureEnabled("WT") ) then
			onProcess(obj, spellcast)
		end
	end
end

function OnNewPath(obj, pathing)
	local onPath = PathTracker.OnNewPath
	if ( obj and pathing and onPath and IsFeatureEnabled("PT") ) then
		onPath(obj, pathing)
	end
end

function OnCastSpell(Args)
	local onCast = SSUtility.OnCastSpell
	if ( Args and onCast and IsFeatureEnabled("SU") ) then
		onCast(Args)
	end
end

function OnTeleport(obj, name, duration_secs, status)
	local onTP = RecallTracker.OnTeleport
	if ( obj and onTP and IsFeatureEnabled("RT") ) then
		onTP(obj, name, duration_secs, status)
	end
end

function OnMouseEvent(e, message, wparam, lparam)
	local onMouse = RecallTracker.OnMouseEvent
	if ( onMouse and IsFeatureEnabled("RT") ) then
		onMouse(e)
	end
end

function OnTick()
	local tick = OSClock()
	if (TickCount < tick) then
		TickCount = tick + 0.3
        for i, v in ipairs(ActiveFeaturedClasses) do
            local onTick = v.Class.OnTick
            if (onTick and IsFeatureEnabled(v.ShortName)) then
                onTick()
            end
        end
	end
end

function OnDraw()
    for i, v in ipairs(ActiveFeaturedClasses) do
        local onDraw = v.Class.OnDraw
        if (onDraw and IsFeatureEnabled(v.ShortName)) then
			onDraw()
		end
	end
end

function OnCreateObject(obj)
	if (obj == nil) then
		return
	end
    for i, v in ipairs(ActiveFeaturedClasses) do
		local onCreate = v.Class.OnCreateObject
		if (onCreate and IsFeatureEnabled(v.ShortName)) then
			onCreate(obj)
		end
	end
end

function OnDeleteObject(obj)
	if (obj == nil) then
		return
	end
	for i, v in ipairs(ActiveFeaturedClasses) do
		local onDelete = v.Class.OnDeleteObject
        if (onDelete and IsFeatureEnabled(v.ShortName)) then
			onDelete(obj)
		end
	end
end

--@param enable boolean a boolean of the enabled check box
--@param feature Class Feature class
local function FeatureEnabler(enable, feature)
    if ( not enable ) then
		-- for k, v in pairs(Enums.Events) do
		-- 	local event = tostring(k)
		-- 	if ( feature[event] ) then
		-- 		feature[event] = nil
		-- 	end
        -- end
        -- feature.Init = nil
        -- feature.Menu = nil
        -- feature = nil
		-- collectgarbage()
		return 
    end
    if( feature.Menu) then
        feature.Menu()
    end
	return 
end

--@param name string Submenu name
--@param featureType enum(number) Type of the submenu
function SubMenuCreator(name, featureType)
    Menu.NewTree(name, name, function ()
        for k, v in pairs(FeaturedClassesInit) do
            if( v.Type == featureType ) then
                local enable = Menu.Checkbox(v.ShortName, "Enable "..v.FullName, true)
                if ( v.FeatureClass.Init ) then
                    FeatureEnabler(enable, v.FeatureClass)
                end
            end
        end
    end)
end

--[[
    Activators = 1,
    Detectors = 2,
    Drawings = 3,
    Timers = 4,
    Trackers = 5,
    Others = 6
]]
function MainMenu()
    Menu.Text("Version "..format("%.1f", Version), false)
    Menu.Separator()
    for k, v in pairs(FeatureType) do
        local str = tostring(k)
        SubMenuCreator(str, v)
    end
    Menu.Separator()
	Menu.ColoredText("If you encounter any bug or error", 0x00FF00FF, true)
	Menu.ColoredText("please report on the forum with your robur.log file", 0x00FF00FF, true)
end

function OnLoad()
	for k, v in pairs(FeaturedClassesInit) do
        local init = v.FeatureClass.Init
        if (init) then
            init()
            table.insert(ActiveFeaturedClasses, {Class = v.FeatureClass, ShortName = v.ShortName})
        end
    end

	EventManager.RegisterCallback(Enums.Events.OnUpdate, OnUpdate)
	EventManager.RegisterCallback(Enums.Events.OnTick, OnTick)
	EventManager.RegisterCallback(Enums.Events.OnDraw, OnDraw)
	EventManager.RegisterCallback(Enums.Events.OnCreateObject, OnCreateObject)
	EventManager.RegisterCallback(Enums.Events.OnDeleteObject, OnDeleteObject)
    EventManager.RegisterCallback(Enums.Events.OnIssueOrder, OnIssueOrder)
    EventManager.RegisterCallback(Enums.Events.OnProcessSpell, OnProcessSpell)
    EventManager.RegisterCallback(Enums.Events.OnNewPath, OnNewPath)
	EventManager.RegisterCallback(Enums.Events.OnCastSpell, OnCastSpell)
	EventManager.RegisterCallback(Enums.Events.OnUnkillableMinion, OnUnkillableMinion)
	EventManager.RegisterCallback(Enums.Events.OnTeleport, OnTeleport)
	EventManager.RegisterCallback(Enums.Events.OnMouseEvent, OnMouseEvent)

    Menu.RegisterMenu("E2Utility", "E2Utility", MainMenu)
	print("[E2Slayer] E2Utility is Loaded - " .. format("%.1f", Version))
	return true
end
