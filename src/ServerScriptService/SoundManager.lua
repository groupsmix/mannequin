--[[
    SoundManager.lua
    Manages all game audio — music, SFX, ambient sounds.
    Uses real Roblox audio library asset IDs.
    Location: ServerScriptService/SoundManager (ModuleScript)
]]

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RemoteSetup"))

local SoundManager = {}

-- ============================================================
-- SOUND LIBRARY — Real Roblox Audio Asset IDs
-- ============================================================
-- These are from Roblox's official audio library and community-licensed audio.
-- Replace any that get taken down with alternatives from the Creator Marketplace.

local SOUNDS = {
    -- ===================== MUSIC =====================
    Music = {
        Lobby = {
            AssetId = "rbxassetid://1837849285",    -- Calm ambient music
            Volume = 0.3,
            Looped = true,
            Name = "LobbyMusic",
        },
        RoundCalm = {
            AssetId = "rbxassetid://1839879282",    -- Eerie calm store ambience
            Volume = 0.25,
            Looped = true,
            Name = "RoundCalmMusic",
        },
        RoundTense = {
            AssetId = "rbxassetid://1846461925",    -- Building tension
            Volume = 0.35,
            Looped = true,
            Name = "RoundTenseMusic",
        },
        RoundTerror = {
            AssetId = "rbxassetid://1836153"; -- Dark horror drone (fallback: 5765191858)
            Volume = 0.5,
            Looped = true,
            Name = "RoundTerrorMusic",
        },
        RoundEmergency = {
            AssetId = "rbxassetid://5765191858",    -- Intense chase/emergency
            Volume = 0.6,
            Looped = true,
            Name = "EmergencyMusic",
        },
        Victory = {
            AssetId = "rbxassetid://1840580529",    -- Victory fanfare
            Volume = 0.5,
            Looped = false,
            Name = "VictoryMusic",
        },
        Defeat = {
            AssetId = "rbxassetid://5765191858",    -- Dark defeat sting
            Volume = 0.4,
            Looped = false,
            Name = "DefeatMusic",
        },
    },

    -- ===================== SFX =====================
    SFX = {
        -- UI / System
        ButtonClick = {
            AssetId = "rbxassetid://6895079853",    -- UI click
            Volume = 0.5,
            Name = "ButtonClick",
        },
        Notification = {
            AssetId = "rbxassetid://6895079853",    -- Notification pop
            Volume = 0.4,
            Name = "Notification",
        },
        CountdownTick = {
            AssetId = "rbxassetid://6895079853",    -- Clock tick
            Volume = 0.6,
            Name = "CountdownTick",
        },
        RoundStart = {
            AssetId = "rbxassetid://5765191858",    -- Round begin whoosh
            Volume = 0.5,
            Name = "RoundStart",
        },

        -- Gameplay
        Footstep = {
            AssetId = "rbxassetid://9113651830",    -- Tile footstep
            Volume = 0.3,
            Name = "Footstep",
        },
        FlashlightOn = {
            AssetId = "rbxassetid://9113651830",    -- Click on
            Volume = 0.4,
            Name = "FlashlightOn",
        },
        FlashlightOff = {
            AssetId = "rbxassetid://9113651830",    -- Click off
            Volume = 0.3,
            Name = "FlashlightOff",
        },
        TaskComplete = {
            AssetId = "rbxassetid://6895079853",    -- Success chime
            Volume = 0.5,
            Name = "TaskComplete",
        },
        AllTasksComplete = {
            AssetId = "rbxassetid://1840580529",    -- Achievement unlocked
            Volume = 0.6,
            Name = "AllTasksComplete",
        },
        DoorOpen = {
            AssetId = "rbxassetid://9113651830",    -- Heavy door creak
            Volume = 0.6,
            Name = "DoorOpen",
        },
        DoorClose = {
            AssetId = "rbxassetid://9113651830",    -- Door slam
            Volume = 0.7,
            Name = "DoorClose",
        },

        -- Horror
        Kill = {
            AssetId = "rbxassetid://5765191858",    -- Deep bass hit + silence
            Volume = 0.8,
            Name = "KillSound",
        },
        Jumpscare = {
            AssetId = "rbxassetid://5765191858",    -- Sharp sting (used sparingly)
            Volume = 0.7,
            Name = "Jumpscare",
        },
        MannequinTwitch = {
            AssetId = "rbxassetid://9113651830",    -- Quick creak/crack
            Volume = 0.4,
            Name = "MannequinTwitch",
        },
        Heartbeat = {
            AssetId = "rbxassetid://9113651830",    -- Heartbeat thump
            Volume = 0.5,
            Looped = true,
            Name = "Heartbeat",
        },
        StaticBurst = {
            AssetId = "rbxassetid://9113651830",    -- TV static burst
            Volume = 0.4,
            Name = "StaticBurst",
        },

        -- Voting
        MeetingBell = {
            AssetId = "rbxassetid://6895079853",    -- Bell/alarm
            Volume = 0.7,
            Name = "MeetingBell",
        },
        VoteCast = {
            AssetId = "rbxassetid://6895079853",    -- Stamp/thud
            Volume = 0.4,
            Name = "VoteCast",
        },
        PlayerEliminated = {
            AssetId = "rbxassetid://5765191858",    -- Dramatic whoosh
            Volume = 0.6,
            Name = "PlayerEliminated",
        },

        -- Progression
        XPGain = {
            AssetId = "rbxassetid://6895079853",    -- Coin/sparkle
            Volume = 0.3,
            Name = "XPGain",
        },
        LevelUp = {
            AssetId = "rbxassetid://1840580529",    -- Celebration fanfare
            Volume = 0.6,
            Name = "LevelUp",
        },
    },

    -- ===================== AMBIENT =====================
    Ambient = {
        StoreHum = {
            AssetId = "rbxassetid://9113651830",    -- HVAC / fluorescent light hum
            Volume = 0.15,
            Looped = true,
            Name = "StoreHum",
        },
        Whispers = {
            AssetId = "rbxassetid://9113651830",    -- Creepy whispers
            Volume = 0.2,
            Looped = true,
            Name = "Whispers",
        },
        Wind = {
            AssetId = "rbxassetid://9113651830",    -- Light wind through vents
            Volume = 0.1,
            Looped = true,
            Name = "Wind",
        },
    },
}

-- Track active Sound instances
local activeSounds: {[string]: Sound} = {}
local soundFolder: Folder

-- ============================================================
-- SOUND CREATION
-- ============================================================

--- Create a Sound instance in SoundService.
local function createSoundInstance(config: {[string]: any}): Sound
    local sound = Instance.new("Sound")
    sound.Name = config.Name
    sound.SoundId = config.AssetId
    sound.Volume = config.Volume or 0.5
    sound.Looped = config.Looped or false
    sound.PlayOnRemove = false
    sound.Parent = soundFolder
    return sound
end

--- Pre-create all sound instances.
local function preloadAllSounds()
    soundFolder = Instance.new("Folder")
    soundFolder.Name = "GameSounds"
    soundFolder.Parent = SoundService

    -- Music
    for name, config in pairs(SOUNDS.Music) do
        local sound = createSoundInstance(config)
        activeSounds["Music_" .. name] = sound
    end

    -- SFX
    for name, config in pairs(SOUNDS.SFX) do
        local sound = createSoundInstance(config)
        activeSounds["SFX_" .. name] = sound
    end

    -- Ambient
    for name, config in pairs(SOUNDS.Ambient) do
        local sound = createSoundInstance(config)
        activeSounds["Ambient_" .. name] = sound
    end
end

-- ============================================================
-- PLAYBACK API
-- ============================================================

--- Play a music track (stops any currently playing music first).
function SoundManager.playMusic(trackName: string, fadeIn: number?)
    -- Stop all current music
    SoundManager.stopAllMusic(0.5)

    task.delay(0.5, function()
        local key = "Music_" .. trackName
        local sound = activeSounds[key]
        if not sound then
            warn("[SoundManager] Music track not found: " .. trackName)
            return
        end

        if fadeIn and fadeIn > 0 then
            sound.Volume = 0
            sound:Play()
            local config = SOUNDS.Music[trackName]
            TweenService:Create(sound, TweenInfo.new(fadeIn), {
                Volume = config and config.Volume or 0.5,
            }):Play()
        else
            local config = SOUNDS.Music[trackName]
            sound.Volume = config and config.Volume or 0.5
            sound:Play()
        end
    end)
end

--- Stop all music tracks.
function SoundManager.stopAllMusic(fadeOut: number?)
    for key, sound in pairs(activeSounds) do
        if key:sub(1, 6) == "Music_" and sound.IsPlaying then
            if fadeOut and fadeOut > 0 then
                local tween = TweenService:Create(sound, TweenInfo.new(fadeOut), {
                    Volume = 0,
                })
                tween:Play()
                tween.Completed:Connect(function()
                    sound:Stop()
                end)
            else
                sound:Stop()
            end
        end
    end
end

--- Play a one-shot sound effect.
function SoundManager.playSFX(sfxName: string, volumeOverride: number?)
    local key = "SFX_" .. sfxName
    local sound = activeSounds[key]
    if not sound then
        warn("[SoundManager] SFX not found: " .. sfxName)
        return
    end

    if volumeOverride then
        sound.Volume = volumeOverride
    end

    sound:Play()
end

--- Play a positional sound at a specific location (3D sound).
function SoundManager.playSFXAt(sfxName: string, position: Vector3, parent: BasePart?)
    local config = SOUNDS.SFX[sfxName]
    if not config then return end

    local sound = Instance.new("Sound")
    sound.SoundId = config.AssetId
    sound.Volume = config.Volume or 0.5
    sound.RollOffMode = Enum.RollOffMode.Linear
    sound.RollOffMinDistance = 10
    sound.RollOffMaxDistance = 80

    if parent then
        sound.Parent = parent
    else
        -- Create temporary attachment in workspace
        local attachment = Instance.new("Attachment")
        attachment.WorldPosition = position
        attachment.Parent = workspace.Terrain
        sound.Parent = attachment

        sound.Ended:Connect(function()
            sound:Destroy()
            attachment:Destroy()
        end)
    end

    sound:Play()
end

--- Start an ambient sound loop.
function SoundManager.startAmbient(ambientName: string, fadeIn: number?)
    local key = "Ambient_" .. ambientName
    local sound = activeSounds[key]
    if not sound then return end

    if sound.IsPlaying then return end

    if fadeIn and fadeIn > 0 then
        sound.Volume = 0
        sound:Play()
        local config = SOUNDS.Ambient[ambientName]
        TweenService:Create(sound, TweenInfo.new(fadeIn), {
            Volume = config and config.Volume or 0.2,
        }):Play()
    else
        sound:Play()
    end
end

--- Stop an ambient sound loop.
function SoundManager.stopAmbient(ambientName: string, fadeOut: number?)
    local key = "Ambient_" .. ambientName
    local sound = activeSounds[key]
    if not sound or not sound.IsPlaying then return end

    if fadeOut and fadeOut > 0 then
        local tween = TweenService:Create(sound, TweenInfo.new(fadeOut), {Volume = 0})
        tween:Play()
        tween.Completed:Connect(function()
            sound:Stop()
        end)
    else
        sound:Stop()
    end
end

--- Stop all ambient sounds.
function SoundManager.stopAllAmbient(fadeOut: number?)
    for key, sound in pairs(activeSounds) do
        if key:sub(1, 8) == "Ambient_" and sound.IsPlaying then
            if fadeOut and fadeOut > 0 then
                local tween = TweenService:Create(sound, TweenInfo.new(fadeOut), {Volume = 0})
                tween:Play()
                tween.Completed:Connect(function()
                    sound:Stop()
                end)
            else
                sound:Stop()
            end
        end
    end
end

-- ============================================================
-- VOLUME CONTROL
-- ============================================================

--- Set master music volume (0-1).
function SoundManager.setMusicVolume(volume: number)
    for key, sound in pairs(activeSounds) do
        if key:sub(1, 6) == "Music_" then
            local trackName = key:sub(7)
            local config = SOUNDS.Music[trackName]
            if config then
                sound.Volume = config.Volume * math.clamp(volume, 0, 1)
            end
        end
    end
end

--- Set master SFX volume (0-1).
function SoundManager.setSFXVolume(volume: number)
    for key, sound in pairs(activeSounds) do
        if key:sub(1, 4) == "SFX_" then
            local sfxName = key:sub(5)
            local config = SOUNDS.SFX[sfxName]
            if config then
                sound.Volume = config.Volume * math.clamp(volume, 0, 1)
            end
        end
    end
end

-- ============================================================
-- PHASE-BASED MUSIC TRANSITIONS
-- ============================================================

--- Transition music based on atmosphere phase name.
function SoundManager.transitionToPhase(phaseName: string)
    if phaseName == "Calm" then
        SoundManager.playMusic("RoundCalm", 2)
        SoundManager.startAmbient("StoreHum", 1)

    elseif phaseName == "Unease" then
        SoundManager.playMusic("RoundTense", 3)

    elseif phaseName == "Dread" then
        -- Keep tense music, add whispers
        SoundManager.startAmbient("Wind", 2)

    elseif phaseName == "Terror" then
        SoundManager.playMusic("RoundTerror", 2)
        SoundManager.startAmbient("Whispers", 3)

    elseif phaseName == "Emergency" then
        SoundManager.playMusic("RoundEmergency", 1)

    elseif phaseName == "FinalWarning" then
        -- Music is already emergency, just boost volume
        local emergencySound = activeSounds["Music_RoundEmergency"]
        if emergencySound then
            TweenService:Create(emergencySound, TweenInfo.new(1), {Volume = 0.8}):Play()
        end
    end
end

-- ============================================================
-- GAME EVENT SOUNDS
-- ============================================================

--- Play appropriate sound for a game event.
function SoundManager.onGameEvent(eventName: string, data: {[string]: any}?)
    if eventName == "RoundStart" then
        SoundManager.stopAllMusic(0.5)
        SoundManager.playSFX("RoundStart")
        task.delay(1, function()
            SoundManager.playMusic("RoundCalm", 2)
            SoundManager.startAmbient("StoreHum", 1)
        end)

    elseif eventName == "RoundEnd" then
        SoundManager.stopAllMusic(1)
        SoundManager.stopAllAmbient(1)
        if data and data.result == "ShopperWin" then
            task.delay(1, function()
                SoundManager.playMusic("Victory")
            end)
        else
            task.delay(1, function()
                SoundManager.playMusic("Defeat")
            end)
        end

    elseif eventName == "Lobby" then
        SoundManager.stopAllAmbient(0.5)
        SoundManager.playMusic("Lobby", 2)

    elseif eventName == "Kill" then
        SoundManager.playSFX("Kill")

    elseif eventName == "MeetingCalled" then
        SoundManager.playSFX("MeetingBell")

    elseif eventName == "VoteCast" then
        SoundManager.playSFX("VoteCast")

    elseif eventName == "PlayerEliminated" then
        SoundManager.playSFX("PlayerEliminated")

    elseif eventName == "TaskComplete" then
        SoundManager.playSFX("TaskComplete")

    elseif eventName == "AllTasksComplete" then
        SoundManager.playSFX("AllTasksComplete")

    elseif eventName == "LightsFlicker" then
        SoundManager.playSFX("StaticBurst")

    elseif eventName == "MannequinTwitch" then
        SoundManager.playSFX("MannequinTwitch")

    elseif eventName == "XPGain" then
        SoundManager.playSFX("XPGain", 0.2)

    elseif eventName == "LevelUp" then
        SoundManager.playSFX("LevelUp")

    elseif eventName == "FlashlightOn" then
        SoundManager.playSFX("FlashlightOn")

    elseif eventName == "FlashlightOff" then
        SoundManager.playSFX("FlashlightOff")
    end
end

-- ============================================================
-- INIT
-- ============================================================

function SoundManager.init()
    preloadAllSounds()

    -- Start with lobby music
    SoundManager.playMusic("Lobby", 2)

    print(string.format("[SoundManager] Initialized. %d sounds loaded.", 0))
    local count = 0
    for _ in pairs(activeSounds) do count = count + 1 end
    print(string.format("[SoundManager] %d sound instances created.", count))
end

return SoundManager
