--[[
    Config.lua
    Central configuration for the Mannequin game.
    All tuning values in one place — no magic numbers in scripts.
]]

local Config = {}

-- ============================================================
-- ROUND SETTINGS
-- ============================================================
Config.Round = {
	MinPlayers = 4, -- Minimum players to start
	MaxPlayers = 12, -- Maximum players per server
	LobbyWaitTime = 30, -- Seconds to wait in lobby before round starts
	RoundDuration = 300, -- 5 minutes per round (in seconds)
	IntermissionTime = 10, -- Seconds between rounds
	CountdownTime = 5, -- Pre-round countdown
}

-- ============================================================
-- ROLE SETTINGS
-- ============================================================
Config.Roles = {
	MonsterCount = 1, -- Number of monsters per round
	ShopkeeperEnabled = true, -- Whether shopkeeper role is active
	ShopkeeperMinLevel = 5, -- Minimum level to be eligible for shopkeeper
}

-- ============================================================
-- MONSTER SETTINGS
-- ============================================================
Config.Monster = {
	BaseWalkSpeed = 22, -- Movement speed when unseen
	SprintSpeed = 30, -- Movement speed during final phase (4:00+)
	FinalPhaseSpeedMultiplier = 1.4, -- Speed multiplier at 4:30+
	KillRange = 8, -- Studs distance required for a kill
	KillCooldown = 5, -- Seconds between kills
	StunDuration = 3, -- Seconds stunned after being inspected
	FreezePoses = { -- Available freeze pose animation IDs
		"Standing",
		"ArmsOut",
		"LookingDown",
	},
}

-- ============================================================
-- SHOPPER SETTINGS
-- ============================================================
Config.Shopper = {
	WalkSpeed = 16, -- Default walk speed
	TasksRequired = 5, -- Tasks needed to open exit
	InspectRange = 12, -- Max studs to inspect a mannequin
	InspectHoldTime = 2, -- Seconds to hold E to inspect
	InspectCooldown = 15, -- Cooldown between inspections
	InspectCooldownVIP = 8, -- Reduced cooldown with Extra Inspect pass
	FlashlightRange = 50, -- Flashlight beam distance (studs)
	FlashlightAngle = 35, -- Flashlight cone angle (degrees)
	FlashlightRangeVIP = 70, -- Extended range with Flashlight Pro pass
	FlashlightAngleVIP = 50, -- Wider angle with Flashlight Pro pass
}

-- ============================================================
-- GAZE / LINE-OF-SIGHT SETTINGS
-- ============================================================
Config.Gaze = {
	FieldOfView = 70, -- Player camera FOV (degrees) for frustum calc
	MaxViewDistance = 120, -- Max studs a player can "see" the monster
	RaycastCount = 5, -- Number of raycasts for occlusion check
	UpdateRate = 0.05, -- Seconds between gaze checks (20 Hz)
	OcclusionThreshold = 0.6, -- Fraction of rays that must be blocked to count as occluded
}

-- ============================================================
-- VOTING SETTINGS
-- ============================================================
Config.Vote = {
	MeetingsPerPlayer = 1, -- Emergency meetings each player can call per round
	DiscussionTime = 30, -- Seconds for discussion before voting
	VotingTime = 15, -- Seconds to cast votes
	MajorityThreshold = 0.5, -- Fraction of votes needed to eliminate (>50%)
	MeetingCooldown = 30, -- Server-wide cooldown between meetings (seconds)
}

-- ============================================================
-- TASK DEFINITIONS
-- ============================================================
Config.Tasks = {
	Types = {
		{
			Name = "FindItem",
			DisplayName = "Find Item",
			Description = "Go to the marked shelf and pick up the item.",
			Duration = 0, -- Instant on interact
			Icon = "rbxassetid://0", -- Placeholder
		},
		{
			Name = "Checkout",
			DisplayName = "Checkout",
			Description = "Bring your items to a register.",
			Duration = 3,
			Icon = "rbxassetid://0",
		},
		{
			Name = "RestockShelf",
			DisplayName = "Restock Shelf",
			Description = "Carry items from the backroom to the marked shelf.",
			Duration = 0,
			Icon = "rbxassetid://0",
		},
		{
			Name = "FixLights",
			DisplayName = "Fix Lights",
			Description = "Find the fuse box and press buttons in the correct order.",
			Duration = 5, -- Minigame duration
			Icon = "rbxassetid://0",
		},
		{
			Name = "CleanSpill",
			DisplayName = "Clean Spill",
			Description = "Stand on the marked spot to clean up.",
			Duration = 5,
			Icon = "rbxassetid://0",
		},
	},
	TasksPerPlayer = 5,
	TaskSpawnLocations = {}, -- Populated at runtime from map markers
}

-- ============================================================
-- ATMOSPHERE / TENSION ESCALATION
-- ============================================================
Config.Atmosphere = {
	Phases = {
		{
			Time = 0,
			Name = "Calm",
			LightingBrightness = 2,
			AmbientColor = Color3.fromRGB(180, 180, 180),
			FogEnd = 500,
			MusicVolume = 0.3,
		},
		{
			Time = 60,
			Name = "Unease",
			LightingBrightness = 1.5,
			AmbientColor = Color3.fromRGB(140, 140, 160),
			FogEnd = 350,
			MusicVolume = 0.4,
			Event = "LightsFlicker",
		},
		{
			Time = 120,
			Name = "Dread",
			LightingBrightness = 1,
			AmbientColor = Color3.fromRGB(100, 100, 130),
			FogEnd = 200,
			MusicVolume = 0.5,
			Event = "SectionDark",
		},
		{
			Time = 180,
			Name = "Terror",
			LightingBrightness = 0.5,
			AmbientColor = Color3.fromRGB(70, 60, 90),
			FogEnd = 120,
			MusicVolume = 0.7,
			Event = "Whispers",
		},
		{
			Time = 240,
			Name = "Emergency",
			LightingBrightness = 0.2,
			AmbientColor = Color3.fromRGB(120, 30, 30),
			FogEnd = 80,
			MusicVolume = 0.9,
			Event = "EmergencyLighting",
			MonsterSpeedMultiplier = 1.2,
		},
		{
			Time = 270,
			Name = "FinalWarning",
			LightingBrightness = 0.1,
			AmbientColor = Color3.fromRGB(150, 20, 20),
			FogEnd = 60,
			MusicVolume = 1.0,
			Event = "DoorsClosing",
			MonsterSpeedMultiplier = 1.4,
		},
	},
}

-- ============================================================
-- XP & PROGRESSION
-- ============================================================
Config.XP = {
	TaskComplete = 25,
	SurviveRound = 100,
	CorrectVote = 150,
	KillShopper = 50,
	WinAsMonster = 200,
	InspectFindMonster = 100,
	VIPMultiplier = 2,
}

Config.Levels = {
	Thresholds = {
		0,
		500,
		1500,
		3000,
		5000,
		8000,
		12000,
		17000,
		23000,
		30000,
		38000,
		47000,
		57000,
		68000,
		80000,
		95000,
		112000,
		131000,
		152000,
		175000,
		200000,
		230000,
		265000,
		305000,
		350000,
		400000,
		460000,
		530000,
		610000,
		700000,
	},
}

Config.Unlocks = {
	{ Level = 1, Type = "Skin", Name = "Default", Id = "skin_default" },
	{ Level = 3, Type = "Skin", Name = "Wooden", Id = "skin_wooden" },
	{ Level = 5, Type = "Role", Name = "Shopkeeper", Id = "role_shopkeeper" },
	{ Level = 7, Type = "Skin", Name = "Chrome", Id = "skin_chrome" },
	{ Level = 10, Type = "Pose", Name = "Hands on Hips", Id = "pose_hips" },
	{ Level = 15, Type = "Skin", Name = "Cracked Porcelain", Id = "skin_porcelain" },
	{ Level = 20, Type = "Pose", Name = "Reaching Forward", Id = "pose_reaching" },
	{ Level = 25, Type = "Skin", Name = "Shadow", Id = "skin_shadow" },
	{ Level = 30, Type = "Skin", Name = "Gold", Id = "skin_gold" },
	{ Level = 50, Type = "Skin", Name = "Void", Id = "skin_void" },
}

-- ============================================================
-- MONETIZATION — GAME PASSES
-- ============================================================
Config.GamePasses = {
	VIP = {
		Name = "VIP",
		AssetId = 0, -- Replace with actual Game Pass ID
		Price = 199,
		Description = "2x XP, VIP nameplate, VIP lounge access",
	},
	Radio = {
		Name = "Radio",
		AssetId = 0,
		Price = 99,
		Description = "Play music in the lobby",
	},
	FlashlightPro = {
		Name = "Flashlight Pro",
		AssetId = 0,
		Price = 149,
		Description = "Wider, brighter flashlight beam",
	},
	ExtraInspect = {
		Name = "Extra Inspect",
		AssetId = 0,
		Price = 99,
		Description = "Inspect cooldown reduced from 15s to 8s",
	},
}

-- ============================================================
-- MONETIZATION — DEVELOPER PRODUCTS
-- ============================================================
Config.DevProducts = {
	XPBoost = {
		Name = "2x XP Boost (1 hr)",
		AssetId = 0, -- Replace with actual Product ID
		Price = 49,
		Duration = 3600,
	},
	SkipTask = {
		Name = "Skip Task",
		AssetId = 0,
		Price = 29,
	},
	ExtraVote = {
		Name = "Extra Vote",
		AssetId = 0,
		Price = 19,
	},
}

-- ============================================================
-- MANNEQUIN SETTINGS
-- ============================================================
Config.Mannequins = {
	MinCount = 25, -- Minimum mannequins on the map
	MaxCount = 40, -- Maximum mannequins on the map
	ShuffleOnRoundStart = true, -- Randomize mannequin positions each round
	TwitchChance = 0.1, -- Chance per phase for a real mannequin to "twitch" (cosmetic scare)
	TwitchCooldown = 30, -- Min seconds between twitches per mannequin
}

-- ============================================================
-- DATASTORE KEYS
-- ============================================================
Config.DataStore = {
	PlayerDataStore = "MannequinPlayerData_v1",
	OrderedLeaderboard = "MannequinLeaderboard_v1",
	AutoSaveInterval = 60, -- Save player data every 60 seconds
	RetryAttempts = 3,
	RetryDelay = 2,
}

-- ============================================================
-- UI SETTINGS
-- ============================================================
Config.UI = {
	FadeInDuration = 0.5,
	FadeOutDuration = 0.3,
	NotificationDuration = 3,
	TaskListPosition = UDim2.new(0, 20, 0.3, 0),
	KillFeedPosition = UDim2.new(0.5, 0, 0, 10),
}

-- ============================================================
-- MAP TAG NAMES (used to find objects in workspace)
-- ============================================================
Config.Tags = {
	Mannequin = "Mannequin",
	MannequinSpawn = "MannequinSpawn",
	TaskLocation = "TaskLocation",
	SpawnPoint = "ShopperSpawn",
	MonsterSpawn = "MonsterSpawn",
	MeetingPoint = "MeetingPoint",
	ExitDoor = "ExitDoor",
	FuseBox = "FuseBox",
	SecurityCamera = "SecurityCamera",
	LightFixture = "LightFixture",
	ShelfInteract = "ShelfInteract",
	Register = "Register",
	SpillZone = "SpillZone",
}

return Config
