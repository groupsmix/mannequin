--[[
    HUDController.lua
    Manages all UI screens — HUD, notifications, task list, voting, kill screen,
    loading screen, settings, and shop.
    Location: StarterGui/HUDController (LocalScript)
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local Utils = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utils"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RemoteSetup"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- CREATE MAIN UI
-- ============================================================

local function createScreenGui(name: string, displayOrder: number?): ScreenGui
    local existing = playerGui:FindFirstChild(name)
    if existing then existing:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = name
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = displayOrder or 1
    gui.Parent = playerGui
    return gui
end

-- ============================================================
-- HUD (Always visible during gameplay)
-- ============================================================

local hudGui: ScreenGui
local timerLabel: TextLabel
local roleLabel: TextLabel
local xpLabel: TextLabel
local coinsLabel: TextLabel
local taskCountLabel: TextLabel

local function createHUD()
    hudGui = createScreenGui("HUDGui", 5)

    -- Top bar
    local topBar = Instance.new("Frame")
    topBar.Name = "TopBar"
    topBar.Size = UDim2.new(1, 0, 0, 50)
    topBar.Position = UDim2.new(0, 0, 0, 0)
    topBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    topBar.BackgroundTransparency = 0.4
    topBar.BorderSizePixel = 0
    topBar.Parent = hudGui

    -- Timer (center top)
    timerLabel = Instance.new("TextLabel")
    timerLabel.Name = "Timer"
    timerLabel.Size = UDim2.new(0, 200, 0, 40)
    timerLabel.Position = UDim2.new(0.5, -100, 0, 5)
    timerLabel.Text = "5:00"
    timerLabel.TextSize = 28
    timerLabel.Font = Enum.Font.GothamBold
    timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    timerLabel.BackgroundTransparency = 1
    timerLabel.Parent = topBar

    -- Role indicator (left)
    roleLabel = Instance.new("TextLabel")
    roleLabel.Name = "Role"
    roleLabel.Size = UDim2.new(0, 200, 0, 40)
    roleLabel.Position = UDim2.new(0, 20, 0, 5)
    roleLabel.Text = "LOBBY"
    roleLabel.TextSize = 20
    roleLabel.Font = Enum.Font.GothamBold
    roleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    roleLabel.TextXAlignment = Enum.TextXAlignment.Left
    roleLabel.BackgroundTransparency = 1
    roleLabel.Parent = topBar

    -- XP display (right)
    xpLabel = Instance.new("TextLabel")
    xpLabel.Name = "XP"
    xpLabel.Size = UDim2.new(0, 150, 0, 20)
    xpLabel.Position = UDim2.new(1, -170, 0, 5)
    xpLabel.Text = "XP: 0"
    xpLabel.TextSize = 14
    xpLabel.Font = Enum.Font.Gotham
    xpLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    xpLabel.TextXAlignment = Enum.TextXAlignment.Right
    xpLabel.BackgroundTransparency = 1
    xpLabel.Parent = topBar

    -- Coins display
    coinsLabel = Instance.new("TextLabel")
    coinsLabel.Name = "Coins"
    coinsLabel.Size = UDim2.new(0, 150, 0, 20)
    coinsLabel.Position = UDim2.new(1, -170, 0, 28)
    coinsLabel.Text = "Credits: 0"
    coinsLabel.TextSize = 14
    coinsLabel.Font = Enum.Font.Gotham
    coinsLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    coinsLabel.TextXAlignment = Enum.TextXAlignment.Right
    coinsLabel.BackgroundTransparency = 1
    coinsLabel.Parent = topBar
end

-- ============================================================
-- TASK LIST (Left side during gameplay)
-- ============================================================

local taskGui: ScreenGui
local taskListFrame: Frame
local taskLabels: {[string]: TextLabel} = {}

local function createTaskList()
    taskGui = createScreenGui("TaskGui", 6)

    local container = Instance.new("Frame")
    container.Name = "TaskContainer"
    container.Size = UDim2.new(0, 280, 0, 300)
    container.Position = UDim2.new(0, 15, 0.3, 0)
    container.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    container.BackgroundTransparency = 0.4
    container.BorderSizePixel = 0
    container.Parent = taskGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = container

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 10)
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 10)
    padding.Parent = container

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 25)
    title.Text = "TASKS"
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.BackgroundTransparency = 1
    title.Parent = container

    taskListFrame = Instance.new("Frame")
    taskListFrame.Name = "TaskList"
    taskListFrame.Size = UDim2.new(1, 0, 1, -30)
    taskListFrame.Position = UDim2.new(0, 0, 0, 30)
    taskListFrame.BackgroundTransparency = 1
    taskListFrame.Parent = container

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 5)
    listLayout.Parent = taskListFrame

    -- Hide by default
    container.Visible = false
    taskGui:SetAttribute("ContainerRef", "TaskContainer")
end

local function populateTaskList(tasks: {{taskId: string, displayName: string, completed: boolean}})
    -- Clear existing
    for _, child in ipairs(taskListFrame:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    taskLabels = {}

    -- Show container
    local container = taskGui:FindFirstChild("TaskContainer")
    if container then container.Visible = true end

    for i, taskData in ipairs(tasks) do
        local label = Instance.new("TextLabel")
        label.Name = "Task_" .. taskData.taskId
        label.Size = UDim2.new(1, 0, 0, 25)
        label.LayoutOrder = i
        label.Text = (taskData.completed and "[X] " or "[ ] ") .. taskData.displayName
        label.TextSize = 14
        label.Font = Enum.Font.Gotham
        label.TextColor3 = taskData.completed and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(200, 200, 200)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.BackgroundTransparency = 1
        label.Parent = taskListFrame

        taskLabels[taskData.taskId] = label
    end
end

local function updateTaskLabel(taskId: string, completed: boolean)
    local label = taskLabels[taskId]
    if not label then return end

    local taskName = label.Text:gsub("^%[.%] ", "")
    label.Text = (completed and "[X] " or "[ ] ") .. taskName
    label.TextColor3 = completed and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(200, 200, 200)

    -- Strikethrough effect (just dim it)
    if completed then
        label.TextTransparency = 0.4
    end
end

-- ============================================================
-- NOTIFICATION SYSTEM
-- ============================================================

local notifGui: ScreenGui

local function createNotificationSystem()
    notifGui = createScreenGui("NotificationGui", 20)
end

local function showNotification(data: {text: string, duration: number?, type: string?})
    if not notifGui then return end

    local typeColors = {
        info = Color3.fromRGB(60, 120, 200),
        success = Color3.fromRGB(40, 180, 60),
        warning = Color3.fromRGB(200, 150, 30),
        danger = Color3.fromRGB(200, 40, 40),
    }

    local color = typeColors[data.type or "info"] or typeColors.info
    local duration = data.duration or Config.UI.NotificationDuration

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 400, 0, 50)
    frame.Position = UDim2.new(0.5, -200, 0, -60)
    frame.BackgroundColor3 = color
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = notifGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, -20, 1, 0)
    text.Position = UDim2.new(0, 10, 0, 0)
    text.Text = data.text
    text.TextSize = 16
    text.Font = Enum.Font.GothamBold
    text.TextColor3 = Color3.fromRGB(255, 255, 255)
    text.TextWrapped = true
    text.BackgroundTransparency = 1
    text.Parent = frame

    -- Slide in
    TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Position = UDim2.new(0.5, -200, 0, 60),
    }):Play()

    -- Fade out and destroy
    task.delay(duration, function()
        local fadeOut = TweenService:Create(frame, TweenInfo.new(0.5), {
            BackgroundTransparency = 1,
        })
        TweenService:Create(text, TweenInfo.new(0.5), {
            TextTransparency = 1,
        }):Play()
        fadeOut:Play()
        fadeOut.Completed:Wait()
        frame:Destroy()
    end)
end

-- ============================================================
-- KILL SCREEN (shown when player is killed)
-- ============================================================

local function showKillScreen()
    local killGui = createScreenGui("KillScreenGui", 50)

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bg.BackgroundTransparency = 0
    bg.BorderSizePixel = 0
    bg.Parent = killGui

    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, 0, 0, 60)
    text.Position = UDim2.new(0, 0, 0.4, 0)
    text.Text = "YOU HAVE BEEN CAUGHT"
    text.TextSize = 36
    text.Font = Enum.Font.GothamBold
    text.TextColor3 = Color3.fromRGB(200, 30, 30)
    text.BackgroundTransparency = 1
    text.Parent = bg

    local subText = Instance.new("TextLabel")
    subText.Size = UDim2.new(1, 0, 0, 30)
    subText.Position = UDim2.new(0, 0, 0.5, 0)
    subText.Text = "The Mannequin got you..."
    subText.TextSize = 18
    subText.Font = Enum.Font.Gotham
    subText.TextColor3 = Color3.fromRGB(150, 150, 150)
    subText.BackgroundTransparency = 1
    subText.Parent = bg

    -- Fade out after 2 seconds
    task.delay(2, function()
        TweenService:Create(bg, TweenInfo.new(1), {
            BackgroundTransparency = 1,
        }):Play()
        TweenService:Create(text, TweenInfo.new(1), {
            TextTransparency = 1,
        }):Play()
        TweenService:Create(subText, TweenInfo.new(1), {
            TextTransparency = 1,
        }):Play()
        task.wait(1.5)
        killGui:Destroy()
    end)
end

-- ============================================================
-- VOTING UI
-- ============================================================

local voteGui: ScreenGui

local function createVotingUI()
    voteGui = createScreenGui("VoteGui", 30)
    voteGui.Enabled = false
end

local function showVotingScreen(data: {timeLeft: number, players: {{userId: number, name: string, displayName: string}}})
    if not voteGui then createVotingUI() end
    voteGui.Enabled = true

    -- Clear previous
    for _, child in ipairs(voteGui:GetChildren()) do
        child:Destroy()
    end

    -- Background
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    bg.BackgroundTransparency = 0.3
    bg.BorderSizePixel = 0
    bg.Parent = voteGui

    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 50)
    title.Position = UDim2.new(0, 0, 0.05, 0)
    title.Text = "WHO IS THE MANNEQUIN?"
    title.TextSize = 32
    title.Font = Enum.Font.GothamBold
    title.TextColor3 = Color3.fromRGB(255, 50, 50)
    title.BackgroundTransparency = 1
    title.Parent = bg

    -- Timer
    local voteTimer = Instance.new("TextLabel")
    voteTimer.Name = "VoteTimer"
    voteTimer.Size = UDim2.new(1, 0, 0, 30)
    voteTimer.Position = UDim2.new(0, 0, 0.12, 0)
    voteTimer.Text = "Time: " .. data.timeLeft .. "s"
    voteTimer.TextSize = 20
    voteTimer.Font = Enum.Font.Gotham
    voteTimer.TextColor3 = Color3.fromRGB(200, 200, 200)
    voteTimer.BackgroundTransparency = 1
    voteTimer.Parent = bg

    -- Player vote buttons
    local buttonContainer = Instance.new("Frame")
    buttonContainer.Size = UDim2.new(0, 400, 0, 400)
    buttonContainer.Position = UDim2.new(0.5, -200, 0.2, 0)
    buttonContainer.BackgroundTransparency = 1
    buttonContainer.Parent = bg

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Parent = buttonContainer

    for i, playerData in ipairs(data.players) do
        local btn = Instance.new("TextButton")
        btn.Name = "Vote_" .. playerData.userId
        btn.Size = UDim2.new(1, 0, 0, 45)
        btn.LayoutOrder = i
        btn.Text = playerData.displayName
        btn.TextSize = 18
        btn.Font = Enum.Font.GothamBold
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
        btn.BackgroundTransparency = 0.2
        btn.Parent = buttonContainer

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent = btn

        btn.MouseButton1Click:Connect(function()
            Remotes.fireServer("CastVote", {targetPlayerId = playerData.userId})
            btn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            btn.Text = playerData.displayName .. " (VOTED)"

            -- Disable all buttons
            for _, child in ipairs(buttonContainer:GetChildren()) do
                if child:IsA("TextButton") then
                    child.Active = false
                end
            end
        end)
    end

    -- Skip vote button
    local skipBtn = Instance.new("TextButton")
    skipBtn.Name = "SkipVote"
    skipBtn.Size = UDim2.new(1, 0, 0, 45)
    skipBtn.LayoutOrder = #data.players + 1
    skipBtn.Text = "SKIP VOTE"
    skipBtn.TextSize = 18
    skipBtn.Font = Enum.Font.GothamBold
    skipBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    skipBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    skipBtn.BackgroundTransparency = 0.2
    skipBtn.Parent = buttonContainer

    local skipCorner = Instance.new("UICorner")
    skipCorner.CornerRadius = UDim.new(0, 8)
    skipCorner.Parent = skipBtn

    skipBtn.MouseButton1Click:Connect(function()
        Remotes.fireServer("CastVote", {targetPlayerId = "skip"})
        skipBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        skipBtn.Text = "SKIPPED"

        for _, child in ipairs(buttonContainer:GetChildren()) do
            if child:IsA("TextButton") then
                child.Active = false
            end
        end
    end)
end

local function hideVotingScreen()
    if voteGui then
        voteGui.Enabled = false
    end
end

-- ============================================================
-- ROUND END SCREEN
-- ============================================================

local function showRoundEndScreen(data: {result: string, message: string, monsterName: string})
    local endGui = createScreenGui("RoundEndGui", 40)

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bg.BackgroundTransparency = 0.4
    bg.BorderSizePixel = 0
    bg.Parent = endGui

    local isWin = data.result == "ShopperWin"
    local resultColor = isWin and Color3.fromRGB(50, 200, 50) or Color3.fromRGB(200, 50, 50)

    local resultLabel = Instance.new("TextLabel")
    resultLabel.Size = UDim2.new(1, 0, 0, 60)
    resultLabel.Position = UDim2.new(0, 0, 0.3, 0)
    resultLabel.Text = isWin and "SHOPPERS WIN!" or "THE MANNEQUIN WINS!"
    resultLabel.TextSize = 40
    resultLabel.Font = Enum.Font.GothamBold
    resultLabel.TextColor3 = resultColor
    resultLabel.BackgroundTransparency = 1
    resultLabel.Parent = bg

    local messageLabel = Instance.new("TextLabel")
    messageLabel.Size = UDim2.new(1, 0, 0, 30)
    messageLabel.Position = UDim2.new(0, 0, 0.4, 0)
    messageLabel.Text = data.message
    messageLabel.TextSize = 20
    messageLabel.Font = Enum.Font.Gotham
    messageLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    messageLabel.BackgroundTransparency = 1
    messageLabel.Parent = bg

    local monsterLabel = Instance.new("TextLabel")
    monsterLabel.Size = UDim2.new(1, 0, 0, 25)
    monsterLabel.Position = UDim2.new(0, 0, 0.48, 0)
    monsterLabel.Text = "The Mannequin was: " .. data.monsterName
    monsterLabel.TextSize = 18
    monsterLabel.Font = Enum.Font.GothamBold
    monsterLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    monsterLabel.BackgroundTransparency = 1
    monsterLabel.Parent = bg

    -- Auto-destroy after intermission
    task.delay(Config.Round.IntermissionTime + 2, function()
        endGui:Destroy()
    end)
end

-- ============================================================
-- LOBBY / WAITING SCREEN
-- ============================================================

local lobbyGui: ScreenGui
local waitingLabel: TextLabel

local function createLobbyUI()
    lobbyGui = createScreenGui("LobbyGui", 3)

    local container = Instance.new("Frame")
    container.Name = "WaitingContainer"
    container.Size = UDim2.new(0, 400, 0, 100)
    container.Position = UDim2.new(0.5, -200, 0.8, 0)
    container.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    container.BackgroundTransparency = 0.4
    container.BorderSizePixel = 0
    container.Parent = lobbyGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = container

    waitingLabel = Instance.new("TextLabel")
    waitingLabel.Name = "WaitingText"
    waitingLabel.Size = UDim2.new(1, 0, 1, 0)
    waitingLabel.Text = "Waiting for players..."
    waitingLabel.TextSize = 22
    waitingLabel.Font = Enum.Font.GothamBold
    waitingLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    waitingLabel.BackgroundTransparency = 1
    waitingLabel.Parent = container
end

local function updateLobbyUI(data: {[string]: any})
    if not waitingLabel then return end

    if data.state == "WaitingForPlayers" then
        lobbyGui.Enabled = true
        local current = data.data and data.data.current or 0
        local required = data.data and data.data.required or Config.Round.MinPlayers
        waitingLabel.Text = string.format("Waiting for players... (%d/%d)", current, required)
    elseif data.state == "Lobby" then
        lobbyGui.Enabled = true
        local countdown = data.data and data.data.countdown or 0
        waitingLabel.Text = "Game starting..."
    elseif data.state == "Playing" or data.state == "Voting" then
        lobbyGui.Enabled = false
    elseif data.state == "Intermission" then
        lobbyGui.Enabled = true
        waitingLabel.Text = "Intermission..."
    end
end

-- ============================================================
-- XP POPUP
-- ============================================================

local function showXPPopup(data: {amount: number, reason: string})
    local popup = Instance.new("TextLabel")
    popup.Size = UDim2.new(0, 300, 0, 30)
    popup.Position = UDim2.new(0.5, -150, 0.7, 0)
    popup.Text = string.format("+%d XP (%s)", data.amount, data.reason)
    popup.TextSize = 18
    popup.Font = Enum.Font.GothamBold
    popup.TextColor3 = Color3.fromRGB(255, 215, 0)
    popup.BackgroundTransparency = 1
    popup.TextStrokeTransparency = 0.5
    popup.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    popup.Parent = hudGui or playerGui

    -- Float up and fade
    TweenService:Create(popup, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -150, 0.6, 0),
        TextTransparency = 1,
        TextStrokeTransparency = 1,
    }):Play()

    task.delay(2.5, function()
        popup:Destroy()
    end)
end

-- ============================================================
-- LEVEL UP POPUP
-- ============================================================

local function showLevelUpPopup(data: {newLevel: number, unlocks: {{Name: string, Type: string}}})
    local lvlGui = createScreenGui("LevelUpGui", 45)

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(0, 350, 0, 200)
    bg.Position = UDim2.new(0.5, -175, 0.3, 0)
    bg.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
    bg.BackgroundTransparency = 0.1
    bg.BorderSizePixel = 0
    bg.Parent = lvlGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = bg

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Position = UDim2.new(0, 0, 0, 10)
    title.Text = "LEVEL UP!"
    title.TextSize = 30
    title.Font = Enum.Font.GothamBold
    title.TextColor3 = Color3.fromRGB(255, 215, 0)
    title.BackgroundTransparency = 1
    title.Parent = bg

    local levelText = Instance.new("TextLabel")
    levelText.Size = UDim2.new(1, 0, 0, 40)
    levelText.Position = UDim2.new(0, 0, 0, 50)
    levelText.Text = "Level " .. data.newLevel
    levelText.TextSize = 24
    levelText.Font = Enum.Font.GothamBold
    levelText.TextColor3 = Color3.fromRGB(255, 255, 255)
    levelText.BackgroundTransparency = 1
    levelText.Parent = bg

    -- Show unlocks
    if data.unlocks and #data.unlocks > 0 then
        local unlockText = "Unlocked: "
        for i, unlock in ipairs(data.unlocks) do
            unlockText = unlockText .. unlock.Name
            if i < #data.unlocks then unlockText = unlockText .. ", " end
        end

        local unlockLabel = Instance.new("TextLabel")
        unlockLabel.Size = UDim2.new(1, -20, 0, 60)
        unlockLabel.Position = UDim2.new(0, 10, 0, 100)
        unlockLabel.Text = unlockText
        unlockLabel.TextSize = 16
        unlockLabel.Font = Enum.Font.Gotham
        unlockLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        unlockLabel.TextWrapped = true
        unlockLabel.BackgroundTransparency = 1
        unlockLabel.Parent = bg
    end

    task.delay(4, function()
        TweenService:Create(bg, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
        task.wait(0.6)
        lvlGui:Destroy()
    end)
end

-- ============================================================
-- COUNTDOWN DISPLAY
-- ============================================================

local function showCountdown(data: {secondsLeft: number})
    if not waitingLabel then return end
    waitingLabel.Text = "Starting in " .. data.secondsLeft .. "..."
end

-- ============================================================
-- HUD UPDATES
-- ============================================================

local function updateHUD(data: {key: string, value: any})
    if data.key == "Coins" and coinsLabel then
        coinsLabel.Text = "Credits: " .. tostring(data.value)
    elseif data.key == "XP" and xpLabel then
        xpLabel.Text = "XP: " .. tostring(data.value)
    elseif data.key == "Timer" and timerLabel then
        timerLabel.Text = Utils.formatTime(data.value)
    end
end

-- ============================================================
-- ROLE DISPLAY UPDATE
-- ============================================================

local function updateRoleDisplay(data: {role: string})
    if not roleLabel then return end

    local roleColors = {
        Shopper = Color3.fromRGB(100, 200, 255),
        Monster = Color3.fromRGB(255, 50, 50),
        Shopkeeper = Color3.fromRGB(255, 200, 50),
        Spectator = Color3.fromRGB(150, 150, 150),
        Lobby = Color3.fromRGB(255, 255, 255),
    }

    roleLabel.Text = string.upper(data.role)
    roleLabel.TextColor3 = roleColors[data.role] or Color3.fromRGB(255, 255, 255)

    -- Hide task list for non-shoppers
    if taskGui then
        local container = taskGui:FindFirstChild("TaskContainer")
        if container then
            container.Visible = (data.role == "Shopper")
        end
    end
end

-- ============================================================
-- CONNECT REMOTE EVENTS
-- ============================================================

local function connectRemotes()
    -- Notifications
    Remotes.getEvent("ShowNotification").OnClientEvent:Connect(function(data)
        if typeof(data) == "table" then
            showNotification(data)
        end
    end)

    -- Round events
    Remotes.getEvent("RoundStarted").OnClientEvent:Connect(function(data)
        updateRoleDisplay(data)
        if data.role == "Shopper" then
            -- Task list will be populated by TaskAssigned event
        end
    end)

    Remotes.getEvent("RoundEnded").OnClientEvent:Connect(function(data)
        hideVotingScreen()
        showRoundEndScreen(data)
        updateRoleDisplay({role = "Lobby"})
    end)

    -- Game state
    Remotes.getEvent("GameStateChanged").OnClientEvent:Connect(function(data)
        updateLobbyUI(data)
    end)

    Remotes.getEvent("CountdownTick").OnClientEvent:Connect(showCountdown)

    -- Tasks
    Remotes.getEvent("TaskAssigned").OnClientEvent:Connect(function(data)
        if data and data.tasks then
            populateTaskList(data.tasks)
        end
    end)

    Remotes.getEvent("TaskProgressUpdate").OnClientEvent:Connect(function(data)
        if data then
            updateTaskLabel(data.taskId, data.completed)
        end
    end)

    -- Voting
    Remotes.getEvent("VotingPhase").OnClientEvent:Connect(showVotingScreen)
    Remotes.getEvent("DiscussionPhase").OnClientEvent:Connect(function(data)
        showVotingScreen({timeLeft = data.timeLeft, players = data.players})
    end)
    Remotes.getEvent("VoteResult").OnClientEvent:Connect(function(data)
        task.delay(3, hideVotingScreen)
    end)

    -- Kill screen
    Remotes.getEvent("ShowKillScreen").OnClientEvent:Connect(showKillScreen)

    -- XP / Level
    Remotes.getEvent("XPAwarded").OnClientEvent:Connect(showXPPopup)
    Remotes.getEvent("LevelUp").OnClientEvent:Connect(showLevelUpPopup)

    -- HUD updates
    Remotes.getEvent("UpdateHUD").OnClientEvent:Connect(updateHUD)

    -- Player data loaded
    Remotes.getEvent("PlayerDataLoaded").OnClientEvent:Connect(function(data)
        if data and data.data then
            if xpLabel then xpLabel.Text = "XP: " .. (data.data.XP or 0) end
            if coinsLabel then coinsLabel.Text = "Credits: " .. (data.data.Coins or 0) end
        end
    end)
end

-- ============================================================
-- INIT
-- ============================================================

local function init()
    createHUD()
    createTaskList()
    createNotificationSystem()
    createVotingUI()
    createLobbyUI()
    connectRemotes()

    print("[HUDController] Initialized.")
end

init()
