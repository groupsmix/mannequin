--[[
    GameManager.lua
    Master game loop — handles states, round lifecycle, role assignment, and win conditions.
    Location: ServerScriptService/GameManager
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local Utils = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utils"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RemoteSetup"))

-- Forward-declare service references (set in init)
local PlayerManager
local GazeSystem
local TaskManager
local VoteManager
local AtmosphereManager
local DataManager
local MonetizationManager

local GameManager = {}

-- ============================================================
-- STATE MACHINE
-- ============================================================
--[[
    States:
    - WaitingForPlayers
    - Lobby (countdown to start)
    - RoleAssignment
    - Playing (main round)
    - Voting (emergency meeting in progress)
    - RoundEnd (show results)
    - Intermission (brief pause between rounds)
]]

local currentState = "WaitingForPlayers"
local roundTimer = 0
local roundStartTime = 0
local stateData = {}

-- Forward-declare round lifecycle functions
local startRound
local startIntermission
local endRound

-- Role tracking
local monsterPlayer: Player? = nil
local shopkeeperPlayer: Player? = nil
local alivePlayers: { Player } = {}
local eliminatedPlayers: { Player } = {}
local killCount = 0

function GameManager.getCurrentState(): string
	return currentState
end

function GameManager.getMonsterPlayer(): Player?
	return monsterPlayer
end

function GameManager.getAlivePlayers(): { Player }
	return alivePlayers
end

function GameManager.isPlayerAlive(player: Player): boolean
	for _, p in ipairs(alivePlayers) do
		if p == player then
			return true
		end
	end
	return false
end

function GameManager.getShopkeeperPlayer(): Player?
	return shopkeeperPlayer
end

-- ============================================================
-- STATE TRANSITIONS
-- ============================================================

local function setState(newState: string, data: { [string]: any }?)
	local oldState = currentState
	currentState = newState
	stateData = data or {}

	print(string.format("[GameManager] State: %s → %s", oldState, newState))

	Remotes.fireAllClients("GameStateChanged", {
		state = newState,
		data = stateData,
	})
end

-- ============================================================
-- ROLE ASSIGNMENT
-- ============================================================

local function assignRoles()
	local allPlayers = Players:GetPlayers()
	if #allPlayers < Config.Round.MinPlayers then
		return false
	end

	-- Reset tracking
	alivePlayers = {}
	eliminatedPlayers = {}
	killCount = 0
	monsterPlayer = nil
	shopkeeperPlayer = nil

	-- Shuffle players for random assignment
	local shuffled = Utils.shuffle(table.clone(allPlayers))

	-- Assign Monster (first player in shuffled list)
	monsterPlayer = shuffled[1]

	-- Assign Shopkeeper if enabled and eligible player exists
	if Config.Roles.ShopkeeperEnabled then
		for i = 2, #shuffled do
			local player = shuffled[i]
			local playerData = DataManager and DataManager.getPlayerData(player)
			if playerData then
				local level = Utils.getLevelFromXP(playerData.XP or 0, Config.Levels.Thresholds)
				if level >= Config.Roles.ShopkeeperMinLevel then
					shopkeeperPlayer = player
					break
				end
			end
		end
	end

	-- All non-monster, non-shopkeeper players are shoppers
	for _, player in ipairs(shuffled) do
		if player ~= monsterPlayer then
			table.insert(alivePlayers, player)
		end
	end

	-- Notify each player of their role
	for _, player in ipairs(allPlayers) do
		local role = "Shopper"
		if player == monsterPlayer then
			role = "Monster"
		elseif player == shopkeeperPlayer then
			role = "Shopkeeper"
		end

		Remotes.fireClient("RoundStarted", player, {
			role = role,
			roundTime = Config.Round.RoundDuration,
		})
	end

	print(
		string.format(
			"[GameManager] Roles assigned. Monster: %s | Shopkeeper: %s",
			monsterPlayer.Name,
			shopkeeperPlayer and shopkeeperPlayer.Name or "None"
		)
	)

	return true
end

-- ============================================================
-- WIN CONDITION CHECKS
-- ============================================================

local function checkWinConditions(): (boolean, string?, string?)
	-- Monster wins if they killed enough shoppers
	local shopperCount = 0
	for _, p in ipairs(alivePlayers) do
		if p ~= shopkeeperPlayer then
			shopperCount = shopperCount + 1
		end
	end

	if killCount >= 3 or shopperCount <= 1 then
		return true, "MonsterWin", "The Mannequin eliminated enough shoppers!"
	end

	-- Shoppers win if all tasks complete and they escape (handled by TaskManager callback)
	-- Shoppers win if Monster is voted out (handled by VoteManager callback)

	return false, nil, nil
end

-- ============================================================
-- ROUND LIFECYCLE
-- ============================================================

local function startWaiting()
	setState("WaitingForPlayers", {
		required = Config.Round.MinPlayers,
		current = #Players:GetPlayers(),
	})
end

local function startLobby()
	setState("Lobby", { countdown = Config.Round.LobbyWaitTime })

	-- Countdown
	for i = Config.Round.LobbyWaitTime, 1, -1 do
		if currentState ~= "Lobby" then
			return
		end
		if #Players:GetPlayers() < Config.Round.MinPlayers then
			startWaiting()
			return
		end
		Remotes.fireAllClients("CountdownTick", { secondsLeft = i })
		task.wait(1)
	end

	startRound()
end

startRound = function()
	setState("RoleAssignment")

	local success = assignRoles()
	if not success then
		startWaiting()
		return
	end

	-- Brief role reveal pause
	task.wait(Config.Round.CountdownTime)

	-- Spawn players
	if PlayerManager then
		PlayerManager.spawnAllPlayers(monsterPlayer, shopkeeperPlayer, alivePlayers)
	end

	-- Assign tasks to shoppers
	if TaskManager then
		for _, player in ipairs(alivePlayers) do
			if player ~= shopkeeperPlayer then
				TaskManager.assignTasks(player)
			end
		end
	end

	-- Start gaze tracking
	if GazeSystem then
		GazeSystem.startTracking()
	end

	-- Start atmosphere
	if AtmosphereManager then
		AtmosphereManager.startEscalation()
	end

	-- Enter playing state
	roundStartTime = tick()
	roundTimer = Config.Round.RoundDuration
	setState("Playing", { roundTime = roundTimer })

	-- Round timer loop
	while currentState == "Playing" and roundTimer > 0 do
		task.wait(1)
		roundTimer = roundTimer - 1

		-- Check win conditions
		local won, result, message = checkWinConditions()
		if won then
			endRound(result, message)
			return
		end
	end

	-- Time ran out — shoppers survive
	if currentState == "Playing" then
		endRound("ShopperWin", "Time's up! The shoppers survived!")
	end
end

endRound = function(result: string, message: string)
	-- Stop systems
	if GazeSystem then
		GazeSystem.stopTracking()
	end
	if AtmosphereManager then
		AtmosphereManager.stopEscalation()
	end

	setState("RoundEnd", { result = result, message = message })

	-- Award XP
	if DataManager then
		local allPlayers = Players:GetPlayers()
		for _, player in ipairs(allPlayers) do
			if result == "ShopperWin" and player ~= monsterPlayer then
				local xp = Config.XP.SurviveRound
				if MonetizationManager and MonetizationManager.hasGamePass(player, "VIP") then
					xp = xp * Config.XP.VIPMultiplier
				end
				DataManager.addXP(player, xp, "Survived the round")
			elseif result == "MonsterWin" and player == monsterPlayer then
				local xp = Config.XP.WinAsMonster
				if MonetizationManager and MonetizationManager.hasGamePass(player, "VIP") then
					xp = xp * Config.XP.VIPMultiplier
				end
				DataManager.addXP(player, xp, "Won as Monster")
			end
		end
	end

	-- Show results
	Remotes.fireAllClients("RoundEnded", {
		result = result,
		message = message,
		monsterName = monsterPlayer and monsterPlayer.Name or "Unknown",
	})

	-- Wait, then go to intermission
	task.wait(5)
	startIntermission()
end

startIntermission = function()
	setState("Intermission", { duration = Config.Round.IntermissionTime })

	-- Reset player states
	if PlayerManager then
		PlayerManager.resetAllPlayers()
	end

	task.wait(Config.Round.IntermissionTime)

	-- Check if enough players to start again
	if #Players:GetPlayers() >= Config.Round.MinPlayers then
		startLobby()
	else
		startWaiting()
	end
end

-- ============================================================
-- CALLBACKS FROM OTHER SYSTEMS
-- ============================================================

--- Called by VoteManager when a player is voted out.
function GameManager.onPlayerVotedOut(player: Player)
	if player == monsterPlayer then
		-- Shoppers found the monster!
		endRound("ShopperWin", player.Name .. " was the Mannequin! Shoppers win!")
	else
		-- Innocent eliminated
		GameManager.onPlayerEliminated(player)
		Remotes.fireAllClients("ShowNotification", {
			text = player.Name .. " was not the Mannequin...",
			duration = 3,
			type = "warning",
		})
	end
end

--- Called when a player is killed by the Monster.
function GameManager.onPlayerKilled(victim: Player)
	killCount = killCount + 1

	-- Award kill XP to monster
	if DataManager and monsterPlayer then
		local xp = Config.XP.KillShopper
		if MonetizationManager and MonetizationManager.hasGamePass(monsterPlayer, "VIP") then
			xp = xp * Config.XP.VIPMultiplier
		end
		DataManager.addXP(monsterPlayer, xp, "Eliminated " .. victim.Name)
	end

	GameManager.onPlayerEliminated(victim)

	Remotes.fireAllClients("MonsterKill", { victimName = victim.Name })

	-- Check win condition immediately
	local won, result, message = checkWinConditions()
	if won then
		endRound(result, message)
	end
end

--- Called when a player is removed from the alive list (kill or vote).
function GameManager.onPlayerEliminated(player: Player)
	for i, p in ipairs(alivePlayers) do
		if p == player then
			table.remove(alivePlayers, i)
			break
		end
	end
	table.insert(eliminatedPlayers, player)

	Remotes.fireAllClients("PlayerEliminated", { playerName = player.Name })

	-- Put the player in spectate mode
	if PlayerManager then
		PlayerManager.setSpectating(player)
	end
end

--- Called when all shoppers have completed their tasks and reached the exit.
function GameManager.onShoppersEscaped()
	endRound("ShopperWin", "The shoppers escaped the store!")
end

--- Called when an emergency meeting is started — pause the round.
function GameManager.onMeetingStarted()
	if currentState ~= "Playing" then
		return
	end
	setState("Voting")

	-- Freeze the monster
	if GazeSystem then
		GazeSystem.stopTracking()
	end
end

--- Called when the meeting/vote is resolved — resume the round.
function GameManager.onMeetingEnded()
	if currentState ~= "Voting" then
		return
	end
	setState("Playing", { roundTime = roundTimer })

	-- Resume gaze tracking
	if GazeSystem then
		GazeSystem.startTracking()
	end
end

--- Called when the Monster is revealed by inspection.
function GameManager.onMonsterInspected(inspector: Player)
	if DataManager then
		local xp = Config.XP.InspectFindMonster
		if MonetizationManager and MonetizationManager.hasGamePass(inspector, "VIP") then
			xp = xp * Config.XP.VIPMultiplier
		end
		DataManager.addXP(inspector, xp, "Found the Mannequin by inspection")
	end

	if monsterPlayer then
		local pos = Utils.getPlayerPosition(monsterPlayer)
		if pos then
			Remotes.fireAllClients("MonsterRevealed", {
				position = pos,
				duration = Config.Monster.StunDuration,
			})
		end
	end
end

-- ============================================================
-- PLAYER CONNECTION HANDLING
-- ============================================================

local function onPlayerAdded(player: Player)
	if currentState == "WaitingForPlayers" then
		local count = #Players:GetPlayers()
		Remotes.fireAllClients("GameStateChanged", {
			state = "WaitingForPlayers",
			data = { required = Config.Round.MinPlayers, current = count },
		})

		if count >= Config.Round.MinPlayers then
			startLobby()
		end
	end
end

local function onPlayerRemoving(player: Player)
	-- Remove from alive players
	for i, p in ipairs(alivePlayers) do
		if p == player then
			table.remove(alivePlayers, i)
			break
		end
	end

	-- If the monster left, shoppers win
	if player == monsterPlayer and (currentState == "Playing" or currentState == "Voting") then
		endRound("ShopperWin", "The Mannequin disconnected! Shoppers win!")
		return
	end

	-- If not enough players, end round
	if currentState == "Playing" or currentState == "Voting" then
		if #alivePlayers < 2 then
			endRound("Draw", "Not enough players to continue.")
		end
	end

	-- Check lobby
	if currentState == "WaitingForPlayers" or currentState == "Lobby" then
		if #Players:GetPlayers() < Config.Round.MinPlayers then
			startWaiting()
		end
	end
end

-- ============================================================
-- ELAPSED TIME
-- ============================================================

function GameManager.getElapsedTime(): number
	if currentState ~= "Playing" then
		return 0
	end
	return tick() - roundStartTime
end

function GameManager.getRemainingTime(): number
	return roundTimer
end

-- ============================================================
-- INITIALIZATION
-- ============================================================

function GameManager.init(services: { [string]: any })
	PlayerManager = services.PlayerManager
	GazeSystem = services.GazeSystem
	TaskManager = services.TaskManager
	VoteManager = services.VoteManager
	AtmosphereManager = services.AtmosphereManager
	DataManager = services.DataManager
	MonetizationManager = services.MonetizationManager

	-- Set up remote functions
	local getGameState = Remotes.getFunction("GetGameState")
	getGameState.OnServerInvoke = function(_player)
		return { state = currentState, data = stateData }
	end

	local getPlayerRole = Remotes.getFunction("GetPlayerRole")
	getPlayerRole.OnServerInvoke = function(player)
		if player == monsterPlayer then
			return "Monster"
		elseif player == shopkeeperPlayer then
			return "Shopkeeper"
		elseif GameManager.isPlayerAlive(player) then
			return "Shopper"
		else
			return "Spectator"
		end
	end

	-- Connect player events
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Handle players already in the game (for studio testing)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	-- Start the game loop
	startWaiting()

	print("[GameManager] Initialized.")
end

return GameManager
