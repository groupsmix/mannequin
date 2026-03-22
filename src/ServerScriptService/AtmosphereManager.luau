--[[
    AtmosphereManager.lua
    Controls the tension escalation system — lighting, fog, sounds, and mannequin twitches.
    Phases progress over the 5-minute round to increase dread.
    Location: ServerScriptService/AtmosphereManager
]]

local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local Utils = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utils"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RemoteSetup"))

local AtmosphereManager = {}

-- Forward-declare
local GameManager

-- ============================================================
-- STATE
-- ============================================================

local isEscalating = false
local currentPhaseIndex = 0
local savedLighting = {} -- Store original lighting to restore later

-- Forward-declare
local triggerMannequinTwitches

-- ============================================================
-- LIGHTING STORAGE / RESTORE
-- ============================================================

local function saveLighting()
	savedLighting = {
		Brightness = Lighting.Brightness,
		Ambient = Lighting.Ambient,
		FogEnd = Lighting.FogEnd,
		FogStart = Lighting.FogStart,
		FogColor = Lighting.FogColor,
	}
end

local function restoreLighting()
	Lighting.Brightness = savedLighting.Brightness or 2
	Lighting.Ambient = savedLighting.Ambient or Color3.fromRGB(180, 180, 180)
	Lighting.FogEnd = savedLighting.FogEnd or 500
	Lighting.FogStart = savedLighting.FogStart or 0
	Lighting.FogColor = savedLighting.FogColor or Color3.fromRGB(128, 128, 128)
end

-- ============================================================
-- PHASE TRANSITIONS
-- ============================================================

--- Smoothly transition lighting to a new phase over 2 seconds.
local function transitionToPhase(phase: { [string]: any })
	local steps = 20
	local stepTime = 2 / steps

	local startBrightness = Lighting.Brightness
	local startAmbient = Lighting.Ambient
	local startFogEnd = Lighting.FogEnd

	for i = 1, steps do
		if not isEscalating then
			break
		end
		local t = i / steps

		Lighting.Brightness = Utils.lerp(startBrightness, phase.LightingBrightness, t)
		Lighting.Ambient = Utils.lerpColor3(startAmbient, phase.AmbientColor, t)
		Lighting.FogEnd = Utils.lerp(startFogEnd, phase.FogEnd, t)

		task.wait(stepTime)
	end
end

--- Handle special events for each phase.
local function triggerPhaseEvent(eventName: string)
	if eventName == "LightsFlicker" then
		-- Tell clients to play flicker effect
		Remotes.fireAllClients("LightsFlicker", { duration = 2 })

		-- Some real mannequins twitch (cosmetic scare)
		triggerMannequinTwitches()
	elseif eventName == "SectionDark" then
		-- Turn off lights in a random section
		local lights = CollectionService:GetTagged(Config.Tags.LightFixture)
		if #lights > 0 then
			local shuffled = Utils.shuffle(table.clone(lights))
			local turnOff = math.min(math.floor(#shuffled / 3), 10)
			for i = 1, turnOff do
				local light = shuffled[i]
				if light:IsA("PointLight") or light:IsA("SpotLight") or light:IsA("SurfaceLight") then
					light.Enabled = false
				end
			end
		end
	elseif eventName == "Whispers" then
		-- Notify clients to start ambient whisper sounds
		Remotes.fireAllClients("AtmosphereUpdate", {
			event = "Whispers",
			enabled = true,
		})
	elseif eventName == "EmergencyLighting" then
		-- Switch to red emergency lighting
		Lighting.FogColor = Color3.fromRGB(40, 10, 10)
		Remotes.fireAllClients("AtmosphereUpdate", {
			event = "EmergencyLighting",
			enabled = true,
		})

		-- Turn off most remaining lights
		local lights = CollectionService:GetTagged(Config.Tags.LightFixture)
		for _, light in ipairs(lights) do
			if light:IsA("PointLight") or light:IsA("SpotLight") or light:IsA("SurfaceLight") then
				if math.random() > 0.2 then
					light.Enabled = false
				else
					light.Color = Color3.fromRGB(255, 50, 50)
				end
			end
		end
	elseif eventName == "DoorsClosing" then
		Remotes.fireAllClients("AtmosphereUpdate", {
			event = "DoorsClosing",
			enabled = true,
		})
		Remotes.fireAllClients("ShowNotification", {
			text = "EXIT DOORS CLOSING IN 30 SECONDS!",
			duration = 5,
			type = "danger",
		})
	end
end

--- Randomly twitch some real mannequins (cosmetic — not the monster).
triggerMannequinTwitches = function()
	local mannequins = CollectionService:GetTagged(Config.Tags.Mannequin)
	for _, mannequin in ipairs(mannequins) do
		if math.random() < Config.Mannequins.TwitchChance then
			-- Don't twitch the monster's mannequin disguise
			if not mannequin:GetAttribute("IsMonsterDisguise") then
				Remotes.fireAllClients("MannequinTwitch", {
					mannequinId = mannequin:GetAttribute("MannequinId") or mannequin.Name,
				})
			end
		end
	end
end

-- ============================================================
-- ESCALATION LOOP
-- ============================================================

function AtmosphereManager.startEscalation()
	isEscalating = true
	currentPhaseIndex = 0
	saveLighting()

	task.spawn(function()
		while isEscalating do
			if not GameManager then
				break
			end
			local elapsed = GameManager.getElapsedTime()

			-- Check if we should transition to the next phase
			local phases = Config.Atmosphere.Phases
			local targetPhaseIndex = 0

			for i, phase in ipairs(phases) do
				if elapsed >= phase.Time then
					targetPhaseIndex = i
				end
			end

			-- If we've entered a new phase, transition
			if targetPhaseIndex > currentPhaseIndex and targetPhaseIndex > 0 then
				currentPhaseIndex = targetPhaseIndex
				local phase = phases[currentPhaseIndex]

				print(
					string.format(
						"[Atmosphere] Phase %d: %s (t=%ds)",
						currentPhaseIndex,
						phase.Name,
						math.floor(elapsed)
					)
				)

				-- Smooth lighting transition
				transitionToPhase(phase)

				-- Fire phase event
				if phase.Event then
					triggerPhaseEvent(phase.Event)
				end

				-- Notify clients of atmosphere change
				Remotes.fireAllClients("AtmosphereUpdate", {
					phase = phase.Name,
					musicVolume = phase.MusicVolume,
					monsterSpeedMultiplier = phase.MonsterSpeedMultiplier,
				})
			end

			task.wait(1)
		end
	end)

	print("[Atmosphere] Escalation started.")
end

function AtmosphereManager.stopEscalation()
	isEscalating = false
	currentPhaseIndex = 0
	restoreLighting()

	-- Re-enable all lights
	local lights = CollectionService:GetTagged(Config.Tags.LightFixture)
	for _, light in ipairs(lights) do
		if light:IsA("PointLight") or light:IsA("SpotLight") or light:IsA("SurfaceLight") then
			light.Enabled = true
			-- Reset color (will be set properly by map setup)
		end
	end

	print("[Atmosphere] Escalation stopped. Lighting restored.")
end

function AtmosphereManager.getCurrentPhase(): string
	local phases = Config.Atmosphere.Phases
	if currentPhaseIndex > 0 and currentPhaseIndex <= #phases then
		return phases[currentPhaseIndex].Name
	end
	return "None"
end

-- ============================================================
-- INIT
-- ============================================================

function AtmosphereManager.init(services: { [string]: any })
	GameManager = services.GameManager
	print("[AtmosphereManager] Initialized.")
end

return AtmosphereManager
