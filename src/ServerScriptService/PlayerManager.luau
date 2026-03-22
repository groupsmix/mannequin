--[[
    PlayerManager.lua
    Handles player spawning, death, spectating, and character management.
    Location: ServerScriptService/PlayerManager
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local Utils = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utils"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RemoteSetup"))

local PlayerManager = {}

-- Track player states
local playerStates: { [Player]: string } = {} -- "alive", "dead", "spectating", "lobby"
local spectateTargets: { [Player]: Player } = {}

-- ============================================================
-- SPAWNING
-- ============================================================

--- Spawn all players at the start of a round.
function PlayerManager.spawnAllPlayers(monster: Player, shopkeeper: Player?, shoppers: { Player })
	-- Spawn monster at monster spawn
	PlayerManager.spawnPlayer(monster, "MonsterSpawn")
	playerStates[monster] = "alive"

	-- Spawn shopkeeper at security room
	if shopkeeper then
		PlayerManager.spawnPlayer(shopkeeper, "ShopkeeperSpawn")
		playerStates[shopkeeper] = "alive"
	end

	-- Spawn shoppers at shopper spawns
	for _, player in ipairs(shoppers) do
		if player ~= shopkeeper then
			PlayerManager.spawnPlayer(player, "ShopperSpawn")
			playerStates[player] = "alive"
		end
	end
end

--- Spawn a single player at a named spawn location.
function PlayerManager.spawnPlayer(player: Player, spawnTag: string)
	local character = player.Character
	if not character then
		player:LoadCharacter()
		character = player.CharacterAdded:Wait()
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	-- Find spawn points with the given tag
	local spawnPoints = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("SpawnLocation") and obj:GetAttribute("SpawnTag") == spawnTag then
			table.insert(spawnPoints, obj)
		end
	end

	-- Fallback: use any SpawnLocation
	if #spawnPoints == 0 then
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("SpawnLocation") then
				table.insert(spawnPoints, obj)
			end
		end
	end

	if #spawnPoints > 0 then
		local spawn = Utils.pickOne(spawnPoints)
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart and spawn then
			rootPart.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end

	-- Set walk speed based on role (will be refined by Monster controller)
	humanoid.WalkSpeed = Config.Shopper.WalkSpeed
end

-- ============================================================
-- PLAYER STATE MANAGEMENT
-- ============================================================

function PlayerManager.getState(player: Player): string
	return playerStates[player] or "lobby"
end

function PlayerManager.isAlive(player: Player): boolean
	return playerStates[player] == "alive"
end

--- Put a player into spectate mode after death/elimination.
function PlayerManager.setSpectating(player: Player)
	playerStates[player] = "spectating"

	local character = player.Character
	if character then
		-- Make character invisible and non-collidable
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Transparency = 1
				part.CanCollide = false
			elseif part:IsA("Decal") or part:IsA("Texture") then
				part.Transparency = 1
			end
		end

		-- Disable humanoid
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 24 -- Ghost speed for spectating
			humanoid.JumpPower = 0
		end
	end

	Remotes.fireClient("ShowSpectateUI", player)
	Remotes.fireClient("ShowNotification", player, {
		text = "You have been eliminated. You are now spectating.",
		duration = 5,
		type = "info",
	})
end

--- Kill a player (called when Monster catches them).
function PlayerManager.killPlayer(victim: Player)
	if playerStates[victim] ~= "alive" then
		return
	end

	playerStates[victim] = "dead"

	-- Show kill screen to victim
	Remotes.fireClient("ShowKillScreen", victim)

	-- Brief delay before transitioning to spectate
	task.delay(2, function()
		PlayerManager.setSpectating(victim)
	end)
end

--- Reset all players to lobby state (between rounds).
function PlayerManager.resetAllPlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		playerStates[player] = "lobby"
		spectateTargets[player] = nil

		-- Reload character to reset appearance
		task.spawn(function()
			player:LoadCharacter()
		end)
	end
end

-- ============================================================
-- SPECTATE CYCLING
-- ============================================================

--- Get the next alive player to spectate.
function PlayerManager.getNextSpectateTarget(spectator: Player, currentTarget: Player?): Player?
	local alive = {}
	for player, state in pairs(playerStates) do
		if state == "alive" and player ~= spectator then
			table.insert(alive, player)
		end
	end

	if #alive == 0 then
		return nil
	end

	if currentTarget == nil then
		return alive[1]
	end

	-- Find current index and cycle to next
	for i, p in ipairs(alive) do
		if p == currentTarget then
			return alive[(i % #alive) + 1]
		end
	end

	return alive[1]
end

-- ============================================================
-- TELEPORT PLAYERS (for meetings)
-- ============================================================

--- Teleport all alive players to the meeting point.
function PlayerManager.teleportToMeeting()
	local meetingPoints = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") and obj:GetAttribute("SpawnTag") == "MeetingPoint" then
			table.insert(meetingPoints, obj)
		end
	end

	if #meetingPoints == 0 then
		return
	end

	local meetingPoint = meetingPoints[1]
	local offset = 0

	for player, state in pairs(playerStates) do
		if state == "alive" then
			local character = player.Character
			if character then
				local rootPart = character:FindFirstChild("HumanoidRootPart")
				if rootPart then
					rootPart.CFrame = meetingPoint.CFrame + Vector3.new(offset * 4, 3, 0)
					offset = offset + 1
				end
			end
		end
	end
end

-- ============================================================
-- PLAYER CONNECTION
-- ============================================================

local function onPlayerAdded(player: Player)
	playerStates[player] = "lobby"

	player.CharacterAdded:Connect(function(character)
		-- Ensure humanoid exists
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			humanoid.Died:Connect(function()
				-- Only process if in a round
				if playerStates[player] == "alive" then
					playerStates[player] = "dead"
				end
			end)
		end
	end)
end

local function onPlayerRemoving(player: Player)
	playerStates[player] = nil
	spectateTargets[player] = nil
end

-- ============================================================
-- INIT
-- ============================================================

function PlayerManager.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	print("[PlayerManager] Initialized.")
end

return PlayerManager
