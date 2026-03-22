--[[
    VoteManager.lua
    Handles emergency meetings, discussion phase, voting, and elimination.
    Location: ServerScriptService/VoteManager
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local Utils = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utils"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RemoteSetup"))

local VoteManager = {}

-- Forward-declare
local GameManager
local PlayerManager

-- ============================================================
-- STATE
-- ============================================================

local meetingsUsed: { [Player]: number } = {} -- How many meetings each player has called
local votes: { [Player]: Player | "skip" } = {} -- Current votes: voter → target
local isMeetingActive = false
local lastMeetingTime = 0
local extraVotes: { [Player]: number } = {} -- Extra votes from Dev Product

-- ============================================================
-- EMERGENCY MEETING
-- ============================================================

local function onCallEmergencyMeeting(player: Player)
	if isMeetingActive then
		return
	end

	-- Validate: player must be alive
	if not GameManager or not GameManager.isPlayerAlive(player) then
		return
	end

	-- Validate: game must be in Playing state
	if GameManager.getCurrentState() ~= "Playing" then
		return
	end

	-- Validate: meeting cooldown
	if tick() - lastMeetingTime < Config.Vote.MeetingCooldown then
		Remotes.fireClient("ShowNotification", player, {
			text = "Meeting on cooldown! Wait "
				.. math.ceil(Config.Vote.MeetingCooldown - (tick() - lastMeetingTime))
				.. "s",
			duration = 3,
			type = "warning",
		})
		return
	end

	-- Validate: player has meetings remaining
	local used = meetingsUsed[player] or 0
	local maxMeetings = Config.Vote.MeetingsPerPlayer + (extraVotes[player] or 0)
	if used >= maxMeetings then
		Remotes.fireClient("ShowNotification", player, {
			text = "You have no emergency meetings left!",
			duration = 3,
			type = "warning",
		})
		return
	end

	-- Start the meeting
	meetingsUsed[player] = used + 1
	isMeetingActive = true
	lastMeetingTime = tick()
	votes = {}

	-- Notify GameManager to pause the round
	GameManager.onMeetingStarted()

	-- Teleport everyone to meeting point
	if PlayerManager then
		PlayerManager.teleportToMeeting()
	end

	-- Notify all clients
	Remotes.fireAllClients("EmergencyMeetingStarted", { callerName = player.Name })

	-- Build list of alive players for voting UI
	local alivePlayers = GameManager.getAlivePlayers()
	local playerList = {}
	for _, p in ipairs(alivePlayers) do
		table.insert(playerList, {
			userId = p.UserId,
			name = p.Name,
			displayName = p.DisplayName,
		})
	end
	-- Include monster in the list
	local monster = GameManager.getMonsterPlayer()
	if monster then
		table.insert(playerList, {
			userId = monster.UserId,
			name = monster.Name,
			displayName = monster.DisplayName,
		})
	end

	-- Discussion phase
	Remotes.fireAllClients("DiscussionPhase", {
		timeLeft = Config.Vote.DiscussionTime,
		players = playerList,
	})

	for i = Config.Vote.DiscussionTime, 1, -1 do
		if not isMeetingActive then
			return
		end
		task.wait(1)
	end

	-- Voting phase
	Remotes.fireAllClients("VotingPhase", {
		timeLeft = Config.Vote.VotingTime,
		players = playerList,
	})

	for i = Config.Vote.VotingTime, 1, -1 do
		if not isMeetingActive then
			return
		end
		task.wait(1)

		-- Send vote progress
		local voteCount = {}
		for voter, target in pairs(votes) do
			local key = typeof(target) == "string" and target or tostring(target.UserId)
			voteCount[key] = (voteCount[key] or 0) + 1
		end
		Remotes.fireAllClients("VoteUpdate", { votes = voteCount })
	end

	-- Tally votes
	tallyVotes()
end

-- ============================================================
-- VOTE CASTING
-- ============================================================

local function onCastVote(player: Player, data: { targetPlayerId: number | string })
	if not isMeetingActive then
		return
	end
	if typeof(data) ~= "table" then
		return
	end

	-- Player must be alive
	if not GameManager or not GameManager.isPlayerAlive(player) then
		-- Monster can also vote (they're alive but tracked separately)
		if player ~= GameManager.getMonsterPlayer() then
			return
		end
	end

	-- Can only vote once
	if votes[player] then
		return
	end

	local targetId = data.targetPlayerId

	if targetId == "skip" then
		votes[player] = "skip"
	else
		if typeof(targetId) ~= "number" then
			return
		end
		-- Find the target player
		local targetPlayer = Players:GetPlayerByUserId(targetId)
		if not targetPlayer then
			return
		end
		votes[player] = targetPlayer
	end

	Remotes.fireClient("ShowNotification", player, {
		text = "Vote cast!",
		duration = 2,
		type = "info",
	})
end

-- ============================================================
-- VOTE TALLYING
-- ============================================================

function tallyVotes()
	-- Count votes per player
	local voteCounts: { [Player]: number } = {}
	local skipCount = 0
	local totalVotes = 0

	for _, target in pairs(votes) do
		totalVotes = totalVotes + 1
		if target == "skip" then
			skipCount = skipCount + 1
		else
			voteCounts[target] = (voteCounts[target] or 0) + 1
		end
	end

	-- Find the player with the most votes
	local maxVotes = 0
	local maxPlayer: Player? = nil
	local isTie = false

	for player, count in pairs(voteCounts) do
		if count > maxVotes then
			maxVotes = count
			maxPlayer = player
			isTie = false
		elseif count == maxVotes then
			isTie = true
		end
	end

	-- Check if skip won
	if skipCount >= maxVotes then
		isTie = true -- Treat skip majority as no elimination
	end

	-- Determine result
	local eliminated: Player? = nil
	local wasMonster = false

	if not isTie and maxPlayer and maxVotes > 0 then
		-- Check majority threshold
		local totalEligible = #GameManager.getAlivePlayers()
		local monster = GameManager.getMonsterPlayer()
		if monster then
			totalEligible = totalEligible + 1
		end

		if maxVotes / totalEligible > Config.Vote.MajorityThreshold then
			eliminated = maxPlayer
			wasMonster = (maxPlayer == GameManager.getMonsterPlayer())
		end
	end

	-- Broadcast result
	Remotes.fireAllClients("VoteResult", {
		eliminated = eliminated and eliminated.Name or nil,
		wasMonster = wasMonster,
		voteCounts = voteCounts,
		skipCount = skipCount,
		isTie = isTie,
	})

	-- Wait for players to see the result
	task.wait(3)

	-- Execute elimination
	isMeetingActive = false
	votes = {}

	if eliminated then
		GameManager.onPlayerVotedOut(eliminated)
	end

	-- Resume the game
	GameManager.onMeetingEnded()
end

-- ============================================================
-- EXTRA VOTE (Developer Product)
-- ============================================================

function VoteManager.grantExtraVote(player: Player)
	extraVotes[player] = (extraVotes[player] or 0) + 1
	Remotes.fireClient("ShowNotification", player, {
		text = "You received an extra emergency meeting!",
		duration = 3,
		type = "success",
	})
end

-- ============================================================
-- RESET
-- ============================================================

function VoteManager.reset()
	meetingsUsed = {}
	votes = {}
	isMeetingActive = false
	extraVotes = {}
end

-- ============================================================
-- INIT
-- ============================================================

function VoteManager.init(services: { [string]: any })
	GameManager = services.GameManager
	PlayerManager = services.PlayerManager

	-- Listen for client events
	local callMeetingEvent = Remotes.getEvent("CallEmergencyMeeting")
	callMeetingEvent.OnServerEvent:Connect(onCallEmergencyMeeting)

	local castVoteEvent = Remotes.getEvent("CastVote")
	castVoteEvent.OnServerEvent:Connect(onCastVote)

	-- Clean up on player removal
	Players.PlayerRemoving:Connect(function(player)
		meetingsUsed[player] = nil
		votes[player] = nil
		extraVotes[player] = nil
	end)

	print("[VoteManager] Initialized.")
end

return VoteManager
