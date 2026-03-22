--[[
    DataManager.lua
    Handles persistent player data using DataStoreService.
    Saves: XP, level, unlocked skins, stats, settings.
    Location: ServerScriptService/DataManager
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local Utils = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utils"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RemoteSetup"))

local DataManager = {}

-- ============================================================
-- DATA STORE
-- ============================================================

local playerDataStore = DataStoreService:GetDataStore(Config.DataStore.PlayerDataStore)

-- In-memory cache of player data
local playerDataCache: { [Player]: { [string]: any } } = {}

-- Default data template for new players
local DEFAULT_DATA = {
	XP = 0,
	Level = 1,
	Coins = 0, -- In-game currency (Store Credits)
	UnlockedSkins = { "skin_default" },
	EquippedSkin = "skin_default",
	UnlockedPoses = {},
	EquippedPose = "Standing",
	Stats = {
		GamesPlayed = 0,
		GamesWon = 0,
		TimesMonster = 0,
		MonsterWins = 0,
		ShopperWins = 0,
		TotalKills = 0,
		TotalTasksCompleted = 0,
		MonstersFound = 0, -- By inspection
		MeetingsCalled = 0,
	},
	GamePasses = {}, -- {[passName]: true}
	Settings = {
		MusicVolume = 0.5,
		SFXVolume = 0.7,
		ShowTutorial = true,
	},
	FirstJoinTimestamp = 0,
	LastJoinTimestamp = 0,
	TotalPlayTime = 0,
	ActiveBoosts = {}, -- {type: string, expiresAt: number}[]
}

-- ============================================================
-- DATA LOADING
-- ============================================================

--- Deep merge: fills in missing keys from template into data.
local function deepMerge(data: { [string]: any }, template: { [string]: any }): { [string]: any }
	for key, defaultValue in pairs(template) do
		if data[key] == nil then
			if type(defaultValue) == "table" then
				data[key] = Utils.deepCopy(defaultValue)
			else
				data[key] = defaultValue
			end
		elseif type(defaultValue) == "table" and type(data[key]) == "table" then
			deepMerge(data[key], defaultValue)
		end
	end
	return data
end

--- Load player data from DataStore with retry.
local function loadPlayerData(player: Player): { [string]: any }?
	local key = "Player_" .. player.UserId
	local data = nil
	local success = false

	for attempt = 1, Config.DataStore.RetryAttempts do
		local ok, result = pcall(function()
			return playerDataStore:GetAsync(key)
		end)

		if ok then
			data = result
			success = true
			break
		else
			warn(
				string.format(
					"[DataManager] Load failed for %s (attempt %d/%d): %s",
					player.Name,
					attempt,
					Config.DataStore.RetryAttempts,
					tostring(result)
				)
			)
			if attempt < Config.DataStore.RetryAttempts then
				task.wait(Config.DataStore.RetryDelay)
			end
		end
	end

	if not success then
		warn("[DataManager] Failed to load data for " .. player.Name .. " after all retries.")
		-- Return default data so the player can still play
		data = Utils.deepCopy(DEFAULT_DATA)
		data.FirstJoinTimestamp = os.time()
	end

	if data == nil then
		-- New player
		data = Utils.deepCopy(DEFAULT_DATA)
		data.FirstJoinTimestamp = os.time()
	else
		-- Existing player — merge with defaults to add new fields
		data = deepMerge(data, DEFAULT_DATA)
	end

	data.LastJoinTimestamp = os.time()

	return data
end

--- Save player data to DataStore with retry.
local function savePlayerData(player: Player): boolean
	local data = playerDataCache[player]
	if not data then
		return false
	end

	local key = "Player_" .. player.UserId

	for attempt = 1, Config.DataStore.RetryAttempts do
		local ok, err = pcall(function()
			playerDataStore:SetAsync(key, data)
		end)

		if ok then
			return true
		else
			warn(
				string.format(
					"[DataManager] Save failed for %s (attempt %d/%d): %s",
					player.Name,
					attempt,
					Config.DataStore.RetryAttempts,
					tostring(err)
				)
			)
			if attempt < Config.DataStore.RetryAttempts then
				task.wait(Config.DataStore.RetryDelay)
			end
		end
	end

	warn("[DataManager] Failed to save data for " .. player.Name .. " after all retries.")
	return false
end

-- ============================================================
-- PUBLIC API
-- ============================================================

--- Get the in-memory data for a player.
function DataManager.getPlayerData(player: Player): { [string]: any }?
	return playerDataCache[player]
end

--- Add XP to a player and check for level-ups.
function DataManager.addXP(player: Player, amount: number, reason: string)
	local data = playerDataCache[player]
	if not data then
		return
	end

	-- Check for active XP boosts
	local multiplier = 1
	if data.ActiveBoosts then
		local now = os.time()
		for i = #data.ActiveBoosts, 1, -1 do
			local boost = data.ActiveBoosts[i]
			if boost.type == "XPBoost" and boost.expiresAt > now then
				multiplier = multiplier * 2
			elseif boost.expiresAt <= now then
				table.remove(data.ActiveBoosts, i)
			end
		end
	end

	local finalAmount = math.floor(amount * multiplier)
	local oldLevel = data.Level
	data.XP = data.XP + finalAmount
	data.Level = Utils.getLevelFromXP(data.XP, Config.Levels.Thresholds)

	-- Notify client of XP gain
	Remotes.fireClient("XPAwarded", player, {
		amount = finalAmount,
		reason = reason,
		totalXP = data.XP,
	})

	-- Check for level up
	if data.Level > oldLevel then
		-- Check for new unlocks
		local newUnlocks = {}
		for _, unlock in ipairs(Config.Unlocks) do
			if unlock.Level > oldLevel and unlock.Level <= data.Level then
				table.insert(newUnlocks, unlock)

				-- Auto-unlock skins/poses
				if unlock.Type == "Skin" then
					if not table.find(data.UnlockedSkins, unlock.Id) then
						table.insert(data.UnlockedSkins, unlock.Id)
					end
				elseif unlock.Type == "Pose" then
					if not table.find(data.UnlockedPoses, unlock.Id) then
						table.insert(data.UnlockedPoses, unlock.Id)
					end
				end
			end
		end

		Remotes.fireClient("LevelUp", player, {
			newLevel = data.Level,
			unlocks = newUnlocks,
		})

		print(string.format("[DataManager] %s leveled up to %d!", player.Name, data.Level))
	end
end

--- Add coins (Store Credits) to a player.
function DataManager.addCoins(player: Player, amount: number)
	local data = playerDataCache[player]
	if not data then
		return
	end
	data.Coins = data.Coins + amount

	Remotes.fireClient("UpdateHUD", player, { key = "Coins", value = data.Coins })
end

--- Spend coins. Returns true if successful.
function DataManager.spendCoins(player: Player, amount: number): boolean
	local data = playerDataCache[player]
	if not data then
		return false
	end
	if data.Coins < amount then
		return false
	end

	data.Coins = data.Coins - amount
	Remotes.fireClient("UpdateHUD", player, { key = "Coins", value = data.Coins })
	return true
end

--- Increment a stat.
function DataManager.incrementStat(player: Player, statName: string, amount: number?)
	local data = playerDataCache[player]
	if not data or not data.Stats then
		return
	end
	local current = data.Stats[statName]
	if current == nil then
		return
	end
	data.Stats[statName] = current + (amount or 1)
end

--- Add an active boost.
function DataManager.addBoost(player: Player, boostType: string, durationSeconds: number)
	local data = playerDataCache[player]
	if not data then
		return
	end

	table.insert(data.ActiveBoosts, {
		type = boostType,
		expiresAt = os.time() + durationSeconds,
	})

	Remotes.fireClient("ShowNotification", player, {
		text = boostType .. " activated for " .. math.floor(durationSeconds / 60) .. " minutes!",
		duration = 3,
		type = "success",
	})
end

--- Update a player setting.
function DataManager.updateSetting(player: Player, key: string, value: any)
	local data = playerDataCache[player]
	if not data or not data.Settings then
		return
	end
	if data.Settings[key] == nil then
		return
	end -- Only allow updating existing settings
	data.Settings[key] = value
end

--- Force save for a player.
function DataManager.save(player: Player): boolean
	return savePlayerData(player)
end

-- ============================================================
-- AUTO-SAVE LOOP
-- ============================================================

local function startAutoSave()
	task.spawn(function()
		while true do
			task.wait(Config.DataStore.AutoSaveInterval)
			for player, _ in pairs(playerDataCache) do
				if player.Parent then -- Still in game
					task.spawn(function()
						savePlayerData(player)
					end)
				end
			end
		end
	end)
end

-- ============================================================
-- PLAYER CONNECTION
-- ============================================================

local function onPlayerAdded(player: Player)
	local data = loadPlayerData(player)
	if data then
		playerDataCache[player] = data
		print(string.format("[DataManager] Loaded data for %s (Level %d, %d XP)", player.Name, data.Level, data.XP))

		-- Send data to client
		Remotes.fireClient("PlayerDataLoaded", player, {
			data = {
				XP = data.XP,
				Level = data.Level,
				Coins = data.Coins,
				UnlockedSkins = data.UnlockedSkins,
				EquippedSkin = data.EquippedSkin,
				UnlockedPoses = data.UnlockedPoses,
				EquippedPose = data.EquippedPose,
				Stats = data.Stats,
				Settings = data.Settings,
			},
		})
	end
end

local function onPlayerRemoving(player: Player)
	if playerDataCache[player] then
		-- Update total play time
		local data = playerDataCache[player]
		if data.LastJoinTimestamp then
			data.TotalPlayTime = (data.TotalPlayTime or 0) + (os.time() - data.LastJoinTimestamp)
		end

		savePlayerData(player)
		playerDataCache[player] = nil
	end
end

-- ============================================================
-- INIT
-- ============================================================

function DataManager.init()
	-- Remote function for clients to request their data
	local getPlayerData = Remotes.getFunction("GetPlayerData")
	getPlayerData.OnServerInvoke = function(player)
		local data = playerDataCache[player]
		if not data then
			return nil
		end
		return {
			XP = data.XP,
			Level = data.Level,
			Coins = data.Coins,
			UnlockedSkins = data.UnlockedSkins,
			EquippedSkin = data.EquippedSkin,
			UnlockedPoses = data.UnlockedPoses,
			EquippedPose = data.EquippedPose,
			Stats = data.Stats,
			Settings = data.Settings,
		}
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Handle players already in game (studio testing)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			onPlayerAdded(player)
		end)
	end

	-- Start auto-save
	startAutoSave()

	-- Save all on game shutdown
	game:BindToClose(function()
		for player, _ in pairs(playerDataCache) do
			savePlayerData(player)
		end
	end)

	print("[DataManager] Initialized.")
end

return DataManager
