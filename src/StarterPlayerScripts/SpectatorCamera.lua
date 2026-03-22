--[[
    SpectatorCamera.lua
    Spectator camera system for dead/eliminated players.
    Allows cycling between alive players with smooth transitions.
    Location: StarterPlayerScripts/SpectatorCamera (LocalScript)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

-- ============================================================
-- STATE
-- ============================================================

local spectating = false
local spectateTargets: {Player} = {}
local currentTargetIndex = 0
local spectateConnection: RBXScriptConnection? = nil
local cameraOffset = Vector3.new(0, 8, 12)
local cameraSmoothing = 0.1

-- UI elements
local spectateGui: ScreenGui
local targetLabel: TextLabel
local controlsLabel: TextLabel
local leftBtn: TextButton
local rightBtn: TextButton

-- ============================================================
-- UI
-- ============================================================

local function buildSpectateUI()
    spectateGui = Instance.new("ScreenGui")
    spectateGui.Name = "SpectateGui"
    spectateGui.IgnoreGuiInset = true
    spectateGui.DisplayOrder = 30
    spectateGui.ResetOnSpawn = false
    spectateGui.Enabled = false
    spectateGui.Parent = playerGui

    -- Bottom bar background
    local bottomBar = Instance.new("Frame")
    bottomBar.Name = "BottomBar"
    bottomBar.Size = UDim2.new(1, 0, 0, 60)
    bottomBar.Position = UDim2.new(0, 0, 1, -60)
    bottomBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bottomBar.BackgroundTransparency = 0.4
    bottomBar.BorderSizePixel = 0
    bottomBar.Parent = spectateGui

    -- "SPECTATING" label
    local spectateLabel = Instance.new("TextLabel")
    spectateLabel.Size = UDim2.new(1, 0, 0, 20)
    spectateLabel.Position = UDim2.new(0, 0, 0, 5)
    spectateLabel.Text = "👁️ SPECTATING"
    spectateLabel.TextSize = 12
    spectateLabel.Font = Enum.Font.GothamBold
    spectateLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    spectateLabel.BackgroundTransparency = 1
    spectateLabel.Parent = bottomBar

    -- Target name
    targetLabel = Instance.new("TextLabel")
    targetLabel.Name = "TargetName"
    targetLabel.Size = UDim2.new(1, -120, 0, 30)
    targetLabel.Position = UDim2.new(0, 60, 0, 25)
    targetLabel.Text = "---"
    targetLabel.TextSize = 22
    targetLabel.Font = Enum.Font.GothamBold
    targetLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    targetLabel.BackgroundTransparency = 1
    targetLabel.Parent = bottomBar

    -- Left arrow button
    leftBtn = Instance.new("TextButton")
    leftBtn.Size = UDim2.new(0, 50, 0, 50)
    leftBtn.Position = UDim2.new(0, 5, 0, 5)
    leftBtn.Text = "◀"
    leftBtn.TextSize = 24
    leftBtn.Font = Enum.Font.GothamBold
    leftBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
    leftBtn.BackgroundColor3 = Color3.fromRGB(50, 45, 65)
    leftBtn.BackgroundTransparency = 0.3
    leftBtn.BorderSizePixel = 0
    leftBtn.Parent = bottomBar

    local leftCorner = Instance.new("UICorner")
    leftCorner.CornerRadius = UDim.new(0, 8)
    leftCorner.Parent = leftBtn

    leftBtn.MouseButton1Click:Connect(function()
        cyclePrevious()
    end)

    -- Right arrow button
    rightBtn = Instance.new("TextButton")
    rightBtn.Size = UDim2.new(0, 50, 0, 50)
    rightBtn.Position = UDim2.new(1, -55, 0, 5)
    rightBtn.Text = "▶"
    rightBtn.TextSize = 24
    rightBtn.Font = Enum.Font.GothamBold
    rightBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
    rightBtn.BackgroundColor3 = Color3.fromRGB(50, 45, 65)
    rightBtn.BackgroundTransparency = 0.3
    rightBtn.BorderSizePixel = 0
    rightBtn.Parent = bottomBar

    local rightCorner = Instance.new("UICorner")
    rightCorner.CornerRadius = UDim.new(0, 8)
    rightCorner.Parent = rightBtn

    rightBtn.MouseButton1Click:Connect(function()
        cycleNext()
    end)

    -- Controls hint (top)
    controlsLabel = Instance.new("TextLabel")
    controlsLabel.Size = UDim2.new(0, 300, 0, 25)
    controlsLabel.Position = UDim2.new(0.5, -150, 0, 10)
    controlsLabel.Text = "← → Arrow Keys or Click to Cycle Players"
    controlsLabel.TextSize = 13
    controlsLabel.Font = Enum.Font.Gotham
    controlsLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    controlsLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    controlsLabel.BackgroundTransparency = 0.5
    controlsLabel.BorderSizePixel = 0
    controlsLabel.Parent = spectateGui

    local controlsCorner = Instance.new("UICorner")
    controlsCorner.CornerRadius = UDim.new(0, 6)
    controlsCorner.Parent = controlsLabel

    -- Fade out controls hint after 5 seconds
    task.delay(5, function()
        if controlsLabel and controlsLabel.Parent then
            TweenService:Create(controlsLabel, TweenInfo.new(1), {
                TextTransparency = 1,
                BackgroundTransparency = 1,
            }):Play()
        end
    end)
end

-- ============================================================
-- TARGET MANAGEMENT
-- ============================================================

--- Refresh the list of alive players (excluding local player).
local function refreshTargets()
    spectateTargets = {}

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local humanoid = p.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                table.insert(spectateTargets, p)
            end
        end
    end

    -- If current target is out of range, clamp
    if currentTargetIndex > #spectateTargets then
        currentTargetIndex = math.max(1, #spectateTargets)
    end
    if currentTargetIndex < 1 and #spectateTargets > 0 then
        currentTargetIndex = 1
    end
end

--- Get the current target player.
local function getCurrentTarget(): Player?
    if currentTargetIndex < 1 or currentTargetIndex > #spectateTargets then
        return nil
    end
    return spectateTargets[currentTargetIndex]
end

--- Update the UI with the current target's name.
local function updateUI()
    local target = getCurrentTarget()
    if target then
        targetLabel.Text = target.Name
    else
        targetLabel.Text = "No players to spectate"
    end
end

-- ============================================================
-- CYCLING
-- ============================================================

function cycleNext()
    if #spectateTargets == 0 then return end
    currentTargetIndex = currentTargetIndex + 1
    if currentTargetIndex > #spectateTargets then
        currentTargetIndex = 1
    end
    updateUI()

    -- Show controls hint briefly
    if controlsLabel then
        controlsLabel.TextTransparency = 0
        controlsLabel.BackgroundTransparency = 0.5
        task.delay(2, function()
            if controlsLabel and controlsLabel.Parent then
                TweenService:Create(controlsLabel, TweenInfo.new(0.5), {
                    TextTransparency = 1,
                    BackgroundTransparency = 1,
                }):Play()
            end
        end)
    end
end

function cyclePrevious()
    if #spectateTargets == 0 then return end
    currentTargetIndex = currentTargetIndex - 1
    if currentTargetIndex < 1 then
        currentTargetIndex = #spectateTargets
    end
    updateUI()
end

-- ============================================================
-- CAMERA FOLLOW
-- ============================================================

local function startFollowing()
    if spectateConnection then
        spectateConnection:Disconnect()
    end

    camera.CameraType = Enum.CameraType.Scriptable

    spectateConnection = RunService.RenderStepped:Connect(function(dt)
        refreshTargets()

        local target = getCurrentTarget()
        if not target then
            -- Free camera mode if nobody to spectate
            return
        end

        local character = target.Character
        if not character then return end

        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not rootPart then return end

        -- Calculate target camera position (behind and above)
        local targetCFrame = rootPart.CFrame
        local lookDir = targetCFrame.LookVector
        local targetPos = targetCFrame.Position + cameraOffset + lookDir * -2

        -- Smooth camera movement
        local currentPos = camera.CFrame.Position
        local newPos = currentPos:Lerp(targetPos, cameraSmoothing)

        -- Look at the target
        camera.CFrame = CFrame.new(newPos, rootPart.Position + Vector3.new(0, 2, 0))
    end)
end

local function stopFollowing()
    if spectateConnection then
        spectateConnection:Disconnect()
        spectateConnection = nil
    end

    camera.CameraType = Enum.CameraType.Custom

    -- Re-attach camera to local player
    if player.Character then
        camera.CameraSubject = player.Character:FindFirstChildOfClass("Humanoid")
    end
end

-- ============================================================
-- PUBLIC API
-- ============================================================

local SpectatorCamera = {}

--- Start spectating. Called when local player dies.
function SpectatorCamera.startSpectating()
    if spectating then return end
    spectating = true

    refreshTargets()
    currentTargetIndex = 1
    updateUI()

    spectateGui.Enabled = true
    startFollowing()

    -- Fade in the spectate UI
    local bottomBar = spectateGui:FindFirstChild("BottomBar")
    if bottomBar then
        bottomBar.BackgroundTransparency = 1
        TweenService:Create(bottomBar, TweenInfo.new(0.5), {
            BackgroundTransparency = 0.4,
        }):Play()
    end
end

--- Stop spectating. Called when round ends or player respawns.
function SpectatorCamera.stopSpectating()
    if not spectating then return end
    spectating = false

    stopFollowing()
    spectateGui.Enabled = false
    spectateTargets = {}
    currentTargetIndex = 0
end

--- Check if currently spectating.
function SpectatorCamera.isSpectating(): boolean
    return spectating
end

-- ============================================================
-- INPUT HANDLING
-- ============================================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not spectating then return end
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.Right or input.KeyCode == Enum.KeyCode.D then
        cycleNext()
    elseif input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.A then
        cyclePrevious()
    end
end)

-- ============================================================
-- LISTEN FOR DEATH / ROUND END
-- ============================================================

-- Listen for player death to start spectating
player.CharacterAdded:Connect(function(character)
    local humanoid = character:WaitForChild("Humanoid", 10)
    if humanoid then
        humanoid.Died:Connect(function()
            task.delay(2, function()
                SpectatorCamera.startSpectating()
            end)
        end)
    end
end)

-- Listen for round end to stop spectating
pcall(function()
    local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
    if remotes then
        local roundEndEvent = remotes:FindFirstChild("RoundEnd")
        if roundEndEvent and roundEndEvent:IsA("RemoteEvent") then
            roundEndEvent.OnClientEvent:Connect(function()
                SpectatorCamera.stopSpectating()
            end)
        end

        local roundStartEvent = remotes:FindFirstChild("RoundStart")
        if roundStartEvent and roundStartEvent:IsA("RemoteEvent") then
            roundStartEvent.OnClientEvent:Connect(function()
                SpectatorCamera.stopSpectating()
            end)
        end
    end
end)

-- Handle target player leaving the game
Players.PlayerRemoving:Connect(function(removedPlayer)
    if not spectating then return end
    refreshTargets()
    if currentTargetIndex > #spectateTargets then
        currentTargetIndex = math.max(1, #spectateTargets)
    end
    updateUI()
end)

-- ============================================================
-- INIT
-- ============================================================

buildSpectateUI()

return SpectatorCamera
