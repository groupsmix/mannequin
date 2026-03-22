--[[
    RemoteSetup.lua
    Creates all RemoteEvents and RemoteFunctions used for client-server communication.
    Run this ONCE on the server at startup. Clients access these from ReplicatedStorage.Remotes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteSetup = {}

-- All remote event names used in the game
local REMOTE_EVENTS = {
    -- Game State
    "GameStateChanged",         -- Server → Client: {state: string, data: table}
    "RoundStarted",             -- Server → Client: {role: string, roundTime: number}
    "RoundEnded",               -- Server → Client: {result: string, winner: string}
    "CountdownTick",            -- Server → Client: {secondsLeft: number}

    -- Gaze System
    "SendCameraData",           -- Client → Server: {cframe: CFrame}
    "MonsterFreezeState",       -- Server → Monster Client: {frozen: boolean}

    -- Monster
    "MonsterKill",              -- Server → All Clients: {victimName: string}
    "PlayerEliminated",         -- Server → All Clients: {playerName: string}
    "MonsterRevealed",          -- Server → All Clients: {position: Vector3, duration: number}

    -- Tasks
    "TaskAssigned",             -- Server → Client: {tasks: table}
    "TaskCompleted",            -- Client → Server: {taskId: string}
    "TaskProgressUpdate",       -- Server → Client: {taskId: string, completed: boolean}
    "AllTasksComplete",         -- Server → Client: {}
    "ExitDoorsOpened",          -- Server → All Clients: {}

    -- Inspect
    "InspectMannequin",         -- Client → Server: {mannequinId: string}
    "InspectResult",            -- Server → Client: {isMonster: boolean, mannequinId: string}
    "InspectCooldownUpdate",    -- Server → Client: {cooldownEnd: number}

    -- Voting
    "CallEmergencyMeeting",     -- Client → Server: {}
    "EmergencyMeetingStarted",  -- Server → All Clients: {callerName: string}
    "CastVote",                 -- Client → Server: {targetPlayerId: number | "skip"}
    "VoteUpdate",               -- Server → All Clients: {votes: table}
    "VoteResult",               -- Server → All Clients: {eliminated: string?, wasMonster: boolean?}
    "DiscussionPhase",          -- Server → All Clients: {timeLeft: number}
    "VotingPhase",              -- Server → All Clients: {timeLeft: number, players: table}

    -- Atmosphere
    "AtmosphereUpdate",         -- Server → All Clients: {phase: table}
    "LightsFlicker",            -- Server → All Clients: {duration: number}
    "MannequinTwitch",          -- Server → All Clients: {mannequinId: string}

    -- UI
    "ShowNotification",         -- Server → Client: {text: string, duration: number, type: string}
    "UpdateHUD",                -- Server → Client: {key: string, value: any}
    "ShowKillScreen",           -- Server → Client (victim): {}
    "ShowSpectateUI",           -- Server → Client: {}

    -- Data / Progression
    "XPAwarded",                -- Server → Client: {amount: number, reason: string}
    "LevelUp",                  -- Server → Client: {newLevel: number, unlocks: table}
    "PlayerDataLoaded",         -- Server → Client: {data: table}

    -- Shop
    "PurchaseGamePass",         -- Client → Server: {passId: string}
    "PurchaseProduct",          -- Client → Server: {productId: string}
    "PurchaseResult",           -- Server → Client: {success: boolean, item: string}

    -- Flashlight
    "ToggleFlashlight",         -- Client → Server: {}
    "FlashlightState",          -- Server → All Clients: {playerId: number, on: boolean}

    -- Settings
    "SaveSettings",             -- Client → Server: {settings: table}

    -- Shop (in-game currency)
    "PurchaseShopItem",         -- Client → Server: {itemId: string}

    -- Tutorial
    "ShowTutorial",             -- Server → Client: {}

    -- Round lifecycle (for spectator/tutorial)
    "RoundStart",               -- Server → All Clients: {}
    "RoundEnd",                 -- Server → All Clients: {}

    -- Sound
    "PlaySound",                -- Server → Client: {soundName: string, position: Vector3?}
    "PlayMusic",                -- Server → Client: {trackName: string}
}

local REMOTE_FUNCTIONS = {
    "GetPlayerData",            -- Client → Server: returns player data table
    "GetLeaderboard",           -- Client → Server: returns top players
    "GetGameState",             -- Client → Server: returns current game state
    "GetPlayerRole",            -- Client → Server: returns current role
    "GetPlayerSettings",        -- Client → Server: returns player settings
}

function RemoteSetup.init()
    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotesFolder then
        remotesFolder = Instance.new("Folder")
        remotesFolder.Name = "Remotes"
        remotesFolder.Parent = ReplicatedStorage
    end

    for _, eventName in ipairs(REMOTE_EVENTS) do
        if not remotesFolder:FindFirstChild(eventName) then
            local remote = Instance.new("RemoteEvent")
            remote.Name = eventName
            remote.Parent = remotesFolder
        end
    end

    for _, funcName in ipairs(REMOTE_FUNCTIONS) do
        if not remotesFolder:FindFirstChild(funcName) then
            local remote = Instance.new("RemoteFunction")
            remote.Name = funcName
            remote.Parent = remotesFolder
        end
    end
end

--- Get a remote event by name.
function RemoteSetup.getEvent(name: string): RemoteEvent
    local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
    return remotesFolder:WaitForChild(name)
end

--- Get a remote function by name.
function RemoteSetup.getFunction(name: string): RemoteFunction
    local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
    return remotesFolder:WaitForChild(name)
end

--- Fire a remote event to a specific player.
function RemoteSetup.fireClient(name: string, player: Player, ...: any)
    local remote = RemoteSetup.getEvent(name)
    remote:FireClient(player, ...)
end

--- Fire a remote event to all players.
function RemoteSetup.fireAllClients(name: string, ...: any)
    local remote = RemoteSetup.getEvent(name)
    remote:FireAllClients(...)
end

--- Fire a remote event to the server (from client).
function RemoteSetup.fireServer(name: string, ...: any)
    local remote = RemoteSetup.getEvent(name)
    remote:FireServer(...)
end

return RemoteSetup
