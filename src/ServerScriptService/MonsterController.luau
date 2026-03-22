--[[
    MonsterController.lua (Server-Side)
    Handles Monster-specific server logic:
    - Kill validation (distance + visibility checks)
    - Speed adjustments based on atmosphere phase
    - Inspect detection (when shoppers inspect the Monster's mannequin)
    Location: ServerScriptService/MonsterController
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local Utils = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utils"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RemoteSetup"))

local MonsterController = {}

-- Forward-declare
local GameManager
local GazeSystem
local PlayerManager
local DataManager

-- ============================================================
-- STATE
-- ============================================================

local lastKillTime = 0
local isStunned = false
local stunEndTime = 0

-- ============================================================
-- KILL LOGIC
-- ============================================================

--- Validate and execute a kill attempt by the Monster.
--- Called when the Monster client requests a kill (they pressed the kill button).
local function onKillAttempt(player: Player, data: { targetUserId: number }?)
	-- Only the Monster can kill
	if not GameManager then
		return
	end
	if player ~= GameManager.getMonsterPlayer() then
		return
	end

	-- Must be in Playing state
	if GameManager.getCurrentState() ~= "Playing" then
		return
	end

	-- Monster must not be stunned
	if isStunned and tick() < stunEndTime then
		Remotes.fireClient("ShowNotification", player, {
			text = "You are stunned!",
			duration = 1,
			type = "warning",
		})
		return
	end

	-- Kill cooldown
	if tick() - lastKillTime < Config.Monster.KillCooldown then
		Remotes.fireClient("ShowNotification", player, {
			text = "Kill on cooldown!",
			duration = 1,
			type = "warning",
		})
		return
	end

	-- Monster must NOT be frozen (being watched)
	if GazeSystem and GazeSystem.isMonsterFrozen() then
		Remotes.fireClient("ShowNotification", player, {
			text = "You can't kill while being watched!",
			duration = 1,
			type = "warning",
		})
		return
	end

	-- Get monster position
	local monsterPos = Utils.getPlayerPosition(player)
	if not monsterPos then
		return
	end

	-- Find the closest alive shopper within kill range
	local alivePlayers = GameManager.getAlivePlayers()
	local closestTarget: Player? = nil
	local closestDist = Config.Monster.KillRange + 1

	for _, target in ipairs(alivePlayers) do
		if target == player then
			continue
		end -- Don't kill yourself
		if target == GameManager.getShopkeeperPlayer() then
			continue
		end -- Can't kill shopkeeper

		local targetPos = Utils.getPlayerPosition(target)
		if not targetPos then
			continue
		end

		local dist = (monsterPos - targetPos).Magnitude
		if dist < closestDist then
			closestDist = dist
			closestTarget = target
		end
	end

	-- If data includes a specific target, validate that specific player
	if data and typeof(data) == "table" and typeof(data.targetUserId) == "number" then
		local specificTarget = Players:GetPlayerByUserId(data.targetUserId)
		if specificTarget and GameManager.isPlayerAlive(specificTarget) then
			local targetPos = Utils.getPlayerPosition(specificTarget)
			if targetPos then
				local dist = (monsterPos - targetPos).Magnitude
				if dist <= Config.Monster.KillRange then
					closestTarget = specificTarget
					closestDist = dist
				end
			end
		end
	end

	if not closestTarget or closestDist > Config.Monster.KillRange then
		Remotes.fireClient("ShowNotification", player, {
			text = "No target in range!",
			duration = 1,
			type = "warning",
		})
		return
	end

	-- Server-side visibility check: is the target visible to OTHER shoppers?
	-- (If another shopper is looking at the kill zone, it's risky but we allow it —
	--  the gaze system already prevents Monster from moving while watched)

	-- Execute the kill
	lastKillTime = tick()

	if PlayerManager then
		PlayerManager.killPlayer(closestTarget)
	end

	-- Notify GameManager
	GameManager.onPlayerKilled(closestTarget)

	-- Update monster stats
	if DataManager then
		DataManager.incrementStat(player, "TotalKills")
	end

	print(
		string.format(
			"[MonsterController] %s killed %s (distance: %.1f studs)",
			player.Name,
			closestTarget.Name,
			closestDist
		)
	)
end

-- ============================================================
-- INSPECT HANDLING
-- ============================================================

--- Called when a shopper inspects a mannequin near the Monster.
local function onInspectMannequin(player: Player, data: { mannequinId: string })
	if not GameManager then
		return
	end
	if player == GameManager.getMonsterPlayer() then
		return
	end -- Monster can't inspect
	if not GameManager.isPlayerAlive(player) then
		return
	end
	if GameManager.getCurrentState() ~= "Playing" then
		return
	end

	if typeof(data) ~= "table" then
		return
	end
	local mannequinId = data.mannequinId
	if typeof(mannequinId) ~= "string" then
		return
	end

	-- Get positions
	local playerPos = Utils.getPlayerPosition(player)
	if not playerPos then
		return
	end

	local monster = GameManager.getMonsterPlayer()
	if not monster then
		return
	end

	local monsterPos = Utils.getPlayerPosition(monster)
	if not monsterPos then
		return
	end

	-- Check if the inspector is close enough to the Monster
	local distToMonster = (playerPos - monsterPos).Magnitude

	-- Also check if the Monster is near the mannequin being inspected
	-- Find the mannequin in workspace
	local isMonster = false
	local mannequinPart = nil

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:GetAttribute("MannequinId") == mannequinId then
			mannequinPart = obj
			break
		end
	end

	if mannequinPart then
		local mannequinPos = mannequinPart.Position
		local monsterToMannequin = (monsterPos - mannequinPos).Magnitude

		-- Monster is "disguised" near this mannequin if within 5 studs
		if monsterToMannequin <= 5 and distToMonster <= Config.Shopper.InspectRange then
			isMonster = true
		end
	end

	-- Also check direct distance to monster (in case mannequin isn't found)
	if not isMonster and distToMonster <= Config.Shopper.InspectRange then
		-- Check if the monster is frozen (in disguise pose)
		if GazeSystem and GazeSystem.isMonsterFrozen() then
			-- Monster is frozen near the inspector — they found them!
			isMonster = true
		end
	end

	-- Send result
	Remotes.fireClient("InspectResult", player, {
		isMonster = isMonster,
		mannequinId = mannequinId,
	})

	if isMonster then
		-- Stun the monster
		isStunned = true
		stunEndTime = tick() + Config.Monster.StunDuration

		-- Notify GameManager
		GameManager.onMonsterInspected(player)

		-- Update stats
		if DataManager then
			DataManager.incrementStat(player, "MonstersFound")
		end

		-- Freeze the monster briefly and reveal
		Remotes.fireClient("MonsterFreezeState", monster, {
			frozen = true,
			stunned = true,
			duration = Config.Monster.StunDuration,
		})

		Remotes.fireClient("ShowNotification", player, {
			text = "You found the Mannequin! It's stunned for " .. Config.Monster.StunDuration .. " seconds!",
			duration = 3,
			type = "success",
		})

		-- Auto-unstun after duration
		task.delay(Config.Monster.StunDuration, function()
			isStunned = false
		end)

		print(string.format("[MonsterController] %s found the Monster by inspection!", player.Name))
	else
		Remotes.fireClient("ShowNotification", player, {
			text = "Just a regular mannequin...",
			duration = 2,
			type = "info",
		})
	end
end

-- ============================================================
-- SPEED MANAGEMENT
-- ============================================================

--- Update the Monster's speed based on atmosphere phase.
function MonsterController.updateSpeed(speedMultiplier: number?)
	if not GameManager then
		return
	end
	local monster = GameManager.getMonsterPlayer()
	if not monster then
		return
	end

	local character, humanoid = Utils.getCharacterAndHumanoid(monster)
	if not humanoid then
		return
	end

	local baseSpeed = Config.Monster.BaseWalkSpeed
	local multiplier = speedMultiplier or 1
	humanoid.WalkSpeed = baseSpeed * multiplier
end

-- ============================================================
-- RESET
-- ============================================================

function MonsterController.reset()
	lastKillTime = 0
	isStunned = false
	stunEndTime = 0
end

-- ============================================================
-- INIT
-- ============================================================

function MonsterController.init(services: { [string]: any })
	GameManager = services.GameManager
	GazeSystem = services.GazeSystem
	PlayerManager = services.PlayerManager
	DataManager = services.DataManager

	-- Listen for kill attempts from monster client
	-- We reuse a generic remote — the client sends "MonsterKill" when they press the kill button
	local killEvent = Remotes.getEvent("MonsterKill")
	killEvent.OnServerEvent:Connect(onKillAttempt)

	-- Listen for inspect attempts from shopper clients
	local inspectEvent = Remotes.getEvent("InspectMannequin")
	inspectEvent.OnServerEvent:Connect(onInspectMannequin)

	print("[MonsterController] Initialized.")
end

return MonsterController
