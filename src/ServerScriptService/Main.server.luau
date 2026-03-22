--[[
    Main.lua
    Server bootstrap — initializes all systems in the correct order.
    This is the ONLY Script that should be placed directly in ServerScriptService.
    All other modules are required by this script.
    Location: ServerScriptService/Main (Script, not ModuleScript)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================================================
-- STEP 1: Initialize Remotes (must be first)
-- ============================================================
print("[Main] Initializing Remotes...")
local RemoteSetup = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RemoteSetup"))
RemoteSetup.init()

-- ============================================================
-- STEP 2: Load all server modules
-- ============================================================
print("[Main] Loading server modules...")

local ServerScriptService = game:GetService("ServerScriptService")

local DataManager = require(ServerScriptService:WaitForChild("DataManager"))
local PlayerManager = require(ServerScriptService:WaitForChild("PlayerManager"))
local GazeSystem = require(ServerScriptService:WaitForChild("GazeSystem"))
local TaskManager = require(ServerScriptService:WaitForChild("TaskManager"))
local VoteManager = require(ServerScriptService:WaitForChild("VoteManager"))
local AtmosphereManager = require(ServerScriptService:WaitForChild("AtmosphereManager"))
local MonetizationManager = require(ServerScriptService:WaitForChild("MonetizationManager"))
local MonsterController = require(ServerScriptService:WaitForChild("MonsterController"))
local GameManager = require(ServerScriptService:WaitForChild("GameManager"))
local MannequinSetup = require(ServerScriptService:WaitForChild("MannequinSetup"))
local SoundManager = require(ServerScriptService:WaitForChild("SoundManager"))
local AntiExploit = require(ServerScriptService:WaitForChild("AntiExploit"))
local ProximityPromptSetup = require(ServerScriptService:WaitForChild("ProximityPromptSetup"))

-- ============================================================
-- STEP 3: Build service dependency table
-- ============================================================
local services = {
	GameManager = GameManager,
	PlayerManager = PlayerManager,
	GazeSystem = GazeSystem,
	TaskManager = TaskManager,
	VoteManager = VoteManager,
	AtmosphereManager = AtmosphereManager,
	DataManager = DataManager,
	MonetizationManager = MonetizationManager,
	MonsterController = MonsterController,
	MannequinSetup = MannequinSetup,
	SoundManager = SoundManager,
	AntiExploit = AntiExploit,
	ProximityPromptSetup = ProximityPromptSetup,
}

-- ============================================================
-- STEP 4: Initialize all systems (order matters)
-- ============================================================
print("[Main] Initializing systems...")

-- Anti-exploit first (wraps remote handlers)
AntiExploit.init()

-- Data (no dependencies)
DataManager.init()

-- Sound system (no dependencies)
SoundManager.init()

-- Player management (no dependencies)
PlayerManager.init()

-- Gaze system (depends on GameManager reference, but lazy-loaded)
GazeSystem.init(services)

-- Task system
TaskManager.init(services)

-- Vote system
VoteManager.init(services)

-- Atmosphere
AtmosphereManager.init(services)

-- Monster controller
MonsterController.init(services)

-- Monetization
MonetizationManager.init(services)

-- ProximityPrompts (needs TaskManager and GameManager)
ProximityPromptSetup.init(services)

-- Mannequin setup (populate the map with mannequins)
MannequinSetup.populateMap()

-- Game Manager LAST (depends on all other systems, starts the game loop)
GameManager.init(services)

-- ============================================================
-- DONE
-- ============================================================
print("========================================")
print("  MANNEQUIN v1.0.0 — Server Initialized")
print("  All systems online.")
print("  " .. tostring(#game:GetService("Players"):GetPlayers()) .. " players connected.")
print("========================================")
