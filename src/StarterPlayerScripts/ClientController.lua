--[[
    ClientController.lua
    Main client-side script — handles input, camera data streaming, flashlight, and interaction.
    Location: StarterPlayerScripts/ClientController
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RemoteSetup"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ============================================================
-- STATE
-- ============================================================

local currentRole = "Lobby"    -- "Lobby", "Shopper", "Monster", "Shopkeeper", "Spectator"
local isFlashlightOn = false
local flashlightPart: SpotLight? = nil
local flashlightBeam: Part? = nil
local lastCameraSendTime = 0
local inspectCooldownEnd = 0
local isInspecting = false
local inspectStartTime = 0
local nearestMannequin: Model? = nil

-- ============================================================
-- CAMERA DATA STREAMING
-- ============================================================
-- Send camera position/direction to the server at 20Hz for gaze detection.

local function streamCameraData()
    local now = tick()
    if now - lastCameraSendTime < Config.Gaze.UpdateRate then return end
    lastCameraSendTime = now

    if currentRole == "Spectator" or currentRole == "Lobby" then return end

    Remotes.fireServer("SendCameraData", {
        cframe = camera.CFrame,
    })
end

-- ============================================================
-- FLASHLIGHT
-- ============================================================

local function createFlashlight()
    local character = player.Character
    if not character then return end

    local head = character:FindFirstChild("Head")
    if not head then return end

    -- Create SpotLight attached to head
    if flashlightPart then
        flashlightPart:Destroy()
    end

    local spotlight = Instance.new("SpotLight")
    spotlight.Name = "PlayerFlashlight"
    spotlight.Brightness = 3
    spotlight.Range = Config.Shopper.FlashlightRange
    spotlight.Angle = Config.Shopper.FlashlightAngle
    spotlight.Color = Color3.fromRGB(255, 255, 230)
    spotlight.Enabled = false
    spotlight.Face = Enum.NormalId.Front
    spotlight.Parent = head

    flashlightPart = spotlight
end

local function toggleFlashlight()
    if currentRole ~= "Shopper" and currentRole ~= "Shopkeeper" then return end

    isFlashlightOn = not isFlashlightOn

    if flashlightPart then
        flashlightPart.Enabled = isFlashlightOn
    end

    Remotes.fireServer("ToggleFlashlight")
end

-- ============================================================
-- MANNEQUIN INTERACTION / INSPECT
-- ============================================================

--- Find the nearest mannequin within inspect range.
local function findNearestMannequin(): (Model?, number)
    local character = player.Character
    if not character then return nil, math.huge end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil, math.huge end

    local playerPos = rootPart.Position
    local closest: Model? = nil
    local closestDist = Config.Shopper.InspectRange + 1

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:GetAttribute("MannequinId") then
            local mannequinRoot = nil
            if obj:IsA("Model") then
                mannequinRoot = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
            elseif obj:IsA("BasePart") then
                mannequinRoot = obj
            end

            if mannequinRoot then
                local dist = (playerPos - mannequinRoot.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closest = obj
                end
            end
        end
    end

    return closest, closestDist
end

--- Start inspecting the nearest mannequin (hold E).
local function startInspect()
    if currentRole ~= "Shopper" then return end
    if tick() < inspectCooldownEnd then return end

    local mannequin, dist = findNearestMannequin()
    if not mannequin or dist > Config.Shopper.InspectRange then return end

    isInspecting = true
    inspectStartTime = tick()
    nearestMannequin = mannequin
end

--- Called every frame while inspect key is held.
local function updateInspect()
    if not isInspecting then return end
    if not nearestMannequin then
        isInspecting = false
        return
    end

    local elapsed = tick() - inspectStartTime
    local holdTime = Config.Shopper.InspectHoldTime

    -- Update UI progress (handled by HUD)
    -- Check if hold is complete
    if elapsed >= holdTime then
        -- Send inspect request to server
        local mannequinId = nearestMannequin:GetAttribute("MannequinId")
        if mannequinId then
            Remotes.fireServer("InspectMannequin", {mannequinId = mannequinId})
        end

        -- Set cooldown
        inspectCooldownEnd = tick() + Config.Shopper.InspectCooldown
        isInspecting = false
        nearestMannequin = nil
    end
end

local function cancelInspect()
    isInspecting = false
    nearestMannequin = nil
end

-- ============================================================
-- MONSTER CLIENT CONTROLS
-- ============================================================

local monsterFrozen = false
local monsterVignetteGui: Frame? = nil

local function createMonsterVignette()
    local screenGui = player:WaitForChild("PlayerGui"):FindFirstChild("MonsterVignetteGui")
    if screenGui then screenGui:Destroy() end

    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "MonsterVignetteGui"
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 100
    screenGui.Parent = player:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Name = "Vignette"
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    monsterVignetteGui = frame
end

local function updateMonsterVignette(frozen: boolean)
    if not monsterVignetteGui then return end

    local targetTransparency = frozen and 0.7 or 1
    local targetColor = frozen and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 255, 0)

    TweenService:Create(monsterVignetteGui, TweenInfo.new(0.3), {
        BackgroundTransparency = targetTransparency,
        BackgroundColor3 = targetColor,
    }):Play()

    -- Brief green flash when unfrozen
    if not frozen then
        monsterVignetteGui.BackgroundTransparency = 0.6
        monsterVignetteGui.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
        task.delay(0.5, function()
            if monsterVignetteGui then
                TweenService:Create(monsterVignetteGui, TweenInfo.new(0.5), {
                    BackgroundTransparency = 1,
                }):Play()
            end
        end)
    end
end

--- Monster attempts a kill (press Q or tap Kill button).
local function attemptKill()
    if currentRole ~= "Monster" then return end
    if monsterFrozen then return end

    Remotes.fireServer("MonsterKill", {})
end

-- ============================================================
-- TASK INTERACTION
-- ============================================================

--- Interact with the nearest task location (press E).
local function interactWithTask()
    if currentRole ~= "Shopper" then return end

    -- Check for nearby task locations
    local character = player.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    -- This is handled through proximity prompts in the actual game
    -- For now, the TaskCompleted remote is fired when the player interacts
    -- with a ProximityPrompt on a task location
end

-- ============================================================
-- INPUT HANDLING
-- ============================================================

local function onInputBegan(input: InputObject, gameProcessed: boolean)
    if gameProcessed then return end

    -- F = Toggle Flashlight
    if input.KeyCode == Enum.KeyCode.F then
        toggleFlashlight()
    end

    -- E = Inspect (hold) / Interact
    if input.KeyCode == Enum.KeyCode.E then
        if currentRole == "Shopper" then
            startInspect()
        end
    end

    -- Q = Kill (Monster only)
    if input.KeyCode == Enum.KeyCode.Q then
        if currentRole == "Monster" then
            attemptKill()
        end
    end

    -- M = Call Emergency Meeting
    if input.KeyCode == Enum.KeyCode.M then
        if currentRole == "Shopper" or currentRole == "Monster" then
            Remotes.fireServer("CallEmergencyMeeting")
        end
    end

    -- Tab = Toggle Task List
    if input.KeyCode == Enum.KeyCode.Tab then
        -- Handled by UI system
    end
end

local function onInputEnded(input: InputObject, gameProcessed: boolean)
    -- E released = cancel inspect
    if input.KeyCode == Enum.KeyCode.E then
        cancelInspect()
    end
end

-- ============================================================
-- MOBILE TOUCH CONTROLS
-- ============================================================

local function setupMobileControls()
    if not UserInputService.TouchEnabled then return end

    local playerGui = player:WaitForChild("PlayerGui")
    local mobileGui = Instance.new("ScreenGui")
    mobileGui.Name = "MobileControlsGui"
    mobileGui.ResetOnSpawn = false
    mobileGui.Parent = playerGui

    -- Flashlight Button
    local flashlightBtn = Instance.new("TextButton")
    flashlightBtn.Name = "FlashlightBtn"
    flashlightBtn.Size = UDim2.new(0, 60, 0, 60)
    flashlightBtn.Position = UDim2.new(1, -80, 1, -160)
    flashlightBtn.Text = "F"
    flashlightBtn.TextSize = 24
    flashlightBtn.Font = Enum.Font.GothamBold
    flashlightBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    flashlightBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    flashlightBtn.BackgroundTransparency = 0.3
    flashlightBtn.Parent = mobileGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 30)
    corner.Parent = flashlightBtn

    flashlightBtn.MouseButton1Click:Connect(toggleFlashlight)

    -- Interact Button
    local interactBtn = Instance.new("TextButton")
    interactBtn.Name = "InteractBtn"
    interactBtn.Size = UDim2.new(0, 70, 0, 70)
    interactBtn.Position = UDim2.new(1, -90, 1, -250)
    interactBtn.Text = "E"
    interactBtn.TextSize = 28
    interactBtn.Font = Enum.Font.GothamBold
    interactBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
    interactBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    interactBtn.BackgroundTransparency = 0.3
    interactBtn.Parent = mobileGui

    local corner2 = Instance.new("UICorner")
    corner2.CornerRadius = UDim.new(0, 35)
    corner2.Parent = interactBtn

    interactBtn.MouseButton1Down:Connect(startInspect)
    interactBtn.MouseButton1Up:Connect(cancelInspect)

    -- Kill Button (Monster only, shown/hidden based on role)
    local killBtn = Instance.new("TextButton")
    killBtn.Name = "KillBtn"
    killBtn.Size = UDim2.new(0, 80, 0, 80)
    killBtn.Position = UDim2.new(1, -100, 1, -350)
    killBtn.Text = "KILL"
    killBtn.TextSize = 22
    killBtn.Font = Enum.Font.GothamBold
    killBtn.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
    killBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    killBtn.BackgroundTransparency = 0.3
    killBtn.Visible = false
    killBtn.Parent = mobileGui

    local corner3 = Instance.new("UICorner")
    corner3.CornerRadius = UDim.new(0, 40)
    corner3.Parent = killBtn

    killBtn.MouseButton1Click:Connect(attemptKill)

    -- Meeting Button
    local meetingBtn = Instance.new("TextButton")
    meetingBtn.Name = "MeetingBtn"
    meetingBtn.Size = UDim2.new(0, 50, 0, 50)
    meetingBtn.Position = UDim2.new(1, -70, 0, 80)
    meetingBtn.Text = "!"
    meetingBtn.TextSize = 28
    meetingBtn.Font = Enum.Font.GothamBold
    meetingBtn.BackgroundColor3 = Color3.fromRGB(200, 150, 30)
    meetingBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    meetingBtn.BackgroundTransparency = 0.3
    meetingBtn.Parent = mobileGui

    local corner4 = Instance.new("UICorner")
    corner4.CornerRadius = UDim.new(0, 25)
    corner4.Parent = meetingBtn

    meetingBtn.MouseButton1Click:Connect(function()
        Remotes.fireServer("CallEmergencyMeeting")
    end)

    -- Store reference for role-based visibility
    player:SetAttribute("MobileKillBtn", true)
end

local function updateMobileControls()
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return end
    local mobileGui = playerGui:FindFirstChild("MobileControlsGui")
    if not mobileGui then return end

    local killBtn = mobileGui:FindFirstChild("KillBtn")
    if killBtn then
        killBtn.Visible = (currentRole == "Monster")
    end
end

-- ============================================================
-- REMOTE EVENT HANDLERS
-- ============================================================

local function onRoundStarted(data: {role: string, roundTime: number})
    currentRole = data.role

    if currentRole == "Monster" then
        createMonsterVignette()
    end

    createFlashlight()
    updateMobileControls()
end

local function onMonsterFreezeState(data: {frozen: boolean})
    if currentRole ~= "Monster" then return end
    monsterFrozen = data.frozen

    -- Freeze/unfreeze movement
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            if monsterFrozen then
                humanoid.WalkSpeed = 0
                humanoid.JumpPower = 0
            else
                humanoid.WalkSpeed = Config.Monster.BaseWalkSpeed
                humanoid.JumpPower = 50
            end
        end
    end

    updateMonsterVignette(monsterFrozen)
end

local function onGameStateChanged(data: {state: string})
    if data.state == "WaitingForPlayers" or data.state == "Lobby" or data.state == "Intermission" then
        currentRole = "Lobby"
        monsterFrozen = false
        updateMobileControls()
    end
end

local function onRoundEnded(data: {result: string, message: string, monsterName: string})
    currentRole = "Lobby"
    monsterFrozen = false

    -- Clean up vignette
    if monsterVignetteGui then
        monsterVignetteGui.Parent:Destroy()
        monsterVignetteGui = nil
    end

    updateMobileControls()
end

local function onShowSpectateUI()
    currentRole = "Spectator"
    updateMobileControls()
end

local function onInspectCooldownUpdate(data: {cooldownEnd: number})
    inspectCooldownEnd = data.cooldownEnd
end

-- ============================================================
-- MAIN LOOP
-- ============================================================

local function mainLoop()
    RunService.RenderStepped:Connect(function()
        -- Stream camera data to server
        streamCameraData()

        -- Update inspect hold
        updateInspect()
    end)
end

-- ============================================================
-- INIT
-- ============================================================

local function init()
    -- Connect input
    UserInputService.InputBegan:Connect(onInputBegan)
    UserInputService.InputEnded:Connect(onInputEnded)

    -- Connect remote events
    Remotes.getEvent("RoundStarted").OnClientEvent:Connect(onRoundStarted)
    Remotes.getEvent("MonsterFreezeState").OnClientEvent:Connect(onMonsterFreezeState)
    Remotes.getEvent("GameStateChanged").OnClientEvent:Connect(onGameStateChanged)
    Remotes.getEvent("RoundEnded").OnClientEvent:Connect(onRoundEnded)
    Remotes.getEvent("ShowSpectateUI").OnClientEvent:Connect(onShowSpectateUI)
    Remotes.getEvent("InspectCooldownUpdate").OnClientEvent:Connect(onInspectCooldownUpdate)

    -- Setup mobile controls
    setupMobileControls()

    -- Start main loop
    mainLoop()

    print("[ClientController] Initialized.")
end

init()
