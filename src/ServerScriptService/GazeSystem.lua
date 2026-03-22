--[[
    GazeSystem.lua
    THE CORE MECHANIC — Line-of-sight / gaze detection system.
    Determines whether the Monster is being watched by any shopper.
    If ANY player's camera frustum includes the Monster (and not occluded), the Monster freezes.
    Location: ServerScriptService/GazeSystem
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local Utils = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utils"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RemoteSetup"))

local GazeSystem = {}

-- Forward-declare
local GameManager

-- ============================================================
-- STATE
-- ============================================================

local isTracking = false
local playerCameraData: {[Player]: CFrame} = {}  -- Latest camera CFrame from each player
local monsterFrozen = false
local previousFrozenState = false

-- Raycast params (reused)
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

-- ============================================================
-- CAMERA DATA COLLECTION
-- ============================================================

--- Called when a client sends their camera CFrame.
local function onCameraDataReceived(player: Player, data: {cframe: CFrame})
    if not isTracking then return end
    if typeof(data) ~= "table" then return end

    local cframe = data.cframe
    if typeof(cframe) ~= "CFrame" then return end

    -- Basic validation: position shouldn't be too far from character
    local playerPos = Utils.getPlayerPosition(player)
    if playerPos then
        local cameraDist = (cframe.Position - playerPos).Magnitude
        if cameraDist > 50 then
            -- Suspicious — camera too far from body, ignore
            return
        end
    end

    playerCameraData[player] = cframe
end

-- ============================================================
-- OCCLUSION CHECK
-- ============================================================

--- Check if the line of sight between a camera and the monster is blocked by geometry.
--- Uses multiple raycasts to handle partial occlusion.
local function isOccluded(cameraPos: Vector3, monsterPos: Vector3, monsterCharacter: Model): boolean
    -- Get all parts of the monster character to exclude from raycasts
    local filterInstances = {monsterCharacter}

    -- Also exclude the viewing player's character
    -- (raycastParams will be set per-call)

    local blockedCount = 0
    local totalRays = Config.Gaze.RaycastCount

    -- Cast rays to different points on the monster (head, torso, feet, left, right)
    local offsets = {
        Vector3.new(0, 2, 0),    -- Head
        Vector3.new(0, 0, 0),    -- Center
        Vector3.new(0, -2, 0),   -- Feet
        Vector3.new(1, 0, 0),    -- Right
        Vector3.new(-1, 0, 0),   -- Left
    }

    for i = 1, math.min(totalRays, #offsets) do
        local targetPos = monsterPos + offsets[i]
        local direction = targetPos - cameraPos
        local distance = direction.Magnitude

        if distance > Config.Gaze.MaxViewDistance then
            blockedCount = blockedCount + 1
            continue
        end

        raycastParams.FilterDescendantsInstances = filterInstances

        local result = workspace:Raycast(cameraPos, direction.Unit * distance, raycastParams)

        if result then
            -- Something is blocking the view
            blockedCount = blockedCount + 1
        end
    end

    -- If enough rays are blocked, consider it occluded
    return (blockedCount / totalRays) >= Config.Gaze.OcclusionThreshold
end

-- ============================================================
-- CORE GAZE CHECK
-- ============================================================

--- Check if ANY player can currently see the Monster.
--- Returns true if the Monster is visible to at least one player.
local function isMonsterVisible(): boolean
    if not GameManager then return false end

    local monster = GameManager.getMonsterPlayer()
    if not monster then return false end

    local monsterCharacter = monster.Character
    if not monsterCharacter then return false end

    local monsterRootPart = monsterCharacter:FindFirstChild("HumanoidRootPart")
    if not monsterRootPart then return false end

    local monsterPos = monsterRootPart.Position

    -- Check each alive player's camera
    local alivePlayers = GameManager.getAlivePlayers()

    for _, player in ipairs(alivePlayers) do
        -- Skip the monster themselves
        if player == monster then continue end

        local cameraCFrame = playerCameraData[player]
        if not cameraCFrame then continue end

        local cameraPos = cameraCFrame.Position
        local lookVector = cameraCFrame.LookVector

        -- Step 1: Is the monster within the player's field of view?
        local inFrustum = Utils.isPointInFrustum(
            cameraPos,
            lookVector,
            monsterPos,
            Config.Gaze.FieldOfView,
            Config.Gaze.MaxViewDistance
        )

        if not inFrustum then continue end

        -- Step 2: Is the monster occluded by walls/objects?
        -- Exclude both the viewer's character and the monster's character
        local viewerCharacter = player.Character
        if viewerCharacter then
            -- Temporarily add viewer's character to filter
            local filterList = {monsterCharacter, viewerCharacter}
            raycastParams.FilterDescendantsInstances = filterList
        end

        local occluded = isOccluded(cameraPos, monsterPos, monsterCharacter)

        if not occluded then
            -- Monster IS visible to this player
            return true
        end
    end

    return false
end

-- ============================================================
-- TRACKING LOOP
-- ============================================================

local trackingConnection: RBXScriptConnection? = nil

local function gazeUpdateLoop()
    if not isTracking then return end

    local visible = isMonsterVisible()
    monsterFrozen = visible

    -- Only send update to monster if state changed
    if monsterFrozen ~= previousFrozenState then
        previousFrozenState = monsterFrozen

        local monster = GameManager and GameManager.getMonsterPlayer()
        if monster then
            Remotes.fireClient("MonsterFreezeState", monster, {frozen = monsterFrozen})
        end
    end
end

-- ============================================================
-- PUBLIC API
-- ============================================================

function GazeSystem.startTracking()
    isTracking = true
    monsterFrozen = false
    previousFrozenState = false
    playerCameraData = {}

    -- Run gaze checks on a fixed interval
    task.spawn(function()
        while isTracking do
            gazeUpdateLoop()
            task.wait(Config.Gaze.UpdateRate)
        end
    end)

    print("[GazeSystem] Tracking started.")
end

function GazeSystem.stopTracking()
    isTracking = false
    monsterFrozen = false
    playerCameraData = {}

    print("[GazeSystem] Tracking stopped.")
end

function GazeSystem.isMonsterFrozen(): boolean
    return monsterFrozen
end

function GazeSystem.isTracking(): boolean
    return isTracking
end

-- ============================================================
-- INIT
-- ============================================================

function GazeSystem.init(services: {[string]: any})
    GameManager = services.GameManager

    -- Listen for camera data from clients
    local sendCameraEvent = Remotes.getEvent("SendCameraData")
    sendCameraEvent.OnServerEvent:Connect(onCameraDataReceived)

    -- Clean up camera data when players leave
    Players.PlayerRemoving:Connect(function(player)
        playerCameraData[player] = nil
    end)

    print("[GazeSystem] Initialized.")
end

return GazeSystem
