--[[
    LoadingScreen.lua
    Animated loading screen shown when a player first joins.
    Fades out once the game is fully loaded.
    Location: StarterGui/LoadingScreen (LocalScript)
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- CREATE LOADING SCREEN
-- ============================================================

local loadingGui = Instance.new("ScreenGui")
loadingGui.Name = "LoadingScreenGui"
loadingGui.IgnoreGuiInset = true
loadingGui.DisplayOrder = 999
loadingGui.ResetOnSpawn = false
loadingGui.Parent = playerGui

-- Background
local bg = Instance.new("Frame")
bg.Name = "Background"
bg.Size = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3 = Color3.fromRGB(5, 5, 10)
bg.BorderSizePixel = 0
bg.Parent = loadingGui

-- Gradient overlay
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(5, 5, 15)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(15, 10, 25)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 5, 15)),
})
gradient.Rotation = 45
gradient.Parent = bg

-- Game title
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, 0, 0, 80)
titleLabel.Position = UDim2.new(0, 0, 0.25, 0)
titleLabel.Text = "M A N N E Q U I N"
titleLabel.TextSize = 56
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextColor3 = Color3.fromRGB(220, 200, 180)
titleLabel.BackgroundTransparency = 1
titleLabel.TextTransparency = 1
titleLabel.Parent = bg

-- Subtitle
local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.Name = "Subtitle"
subtitleLabel.Size = UDim2.new(1, 0, 0, 30)
subtitleLabel.Position = UDim2.new(0, 0, 0.35, 0)
subtitleLabel.Text = "Don't look away."
subtitleLabel.TextSize = 20
subtitleLabel.Font = Enum.Font.Gotham
subtitleLabel.TextColor3 = Color3.fromRGB(200, 50, 50)
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.TextTransparency = 1
subtitleLabel.Parent = bg

-- Mannequin silhouette (text-based since we can't embed images)
local silhouette = Instance.new("TextLabel")
silhouette.Name = "Silhouette"
silhouette.Size = UDim2.new(0, 200, 0, 200)
silhouette.Position = UDim2.new(0.5, -100, 0.42, 0)
silhouette.Text = "🧍"
silhouette.TextSize = 120
silhouette.Font = Enum.Font.SourceSans
silhouette.TextColor3 = Color3.fromRGB(220, 200, 180)
silhouette.BackgroundTransparency = 1
silhouette.TextTransparency = 1
silhouette.Parent = bg

-- Loading bar background
local barBg = Instance.new("Frame")
barBg.Name = "LoadingBarBg"
barBg.Size = UDim2.new(0.4, 0, 0, 6)
barBg.Position = UDim2.new(0.3, 0, 0.75, 0)
barBg.BackgroundColor3 = Color3.fromRGB(40, 35, 50)
barBg.BorderSizePixel = 0
barBg.Parent = bg

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 3)
barCorner.Parent = barBg

-- Loading bar fill
local barFill = Instance.new("Frame")
barFill.Name = "Fill"
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
barFill.BorderSizePixel = 0
barFill.Parent = barBg

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 3)
fillCorner.Parent = barFill

-- Loading text
local loadingText = Instance.new("TextLabel")
loadingText.Name = "LoadingText"
loadingText.Size = UDim2.new(1, 0, 0, 25)
loadingText.Position = UDim2.new(0, 0, 0.78, 0)
loadingText.Text = "Loading..."
loadingText.TextSize = 14
loadingText.Font = Enum.Font.Gotham
loadingText.TextColor3 = Color3.fromRGB(150, 150, 150)
loadingText.BackgroundTransparency = 1
loadingText.Parent = bg

-- Tip text
local tips = {
    "The Mannequin can only move when no one is looking...",
    "Press E to inspect suspicious mannequins.",
    "Complete all 5 tasks to unlock the exit doors.",
    "Call an emergency meeting if you think you found the Mannequin.",
    "Use your flashlight wisely — it helps you see, but also reveals your position.",
    "The store gets darker over time. Stay alert.",
    "Work together with other shoppers to survive.",
    "The Mannequin freezes instantly when looked at.",
    "Listen carefully — footsteps echo in the dark.",
    "A mannequin that wasn't there before? Run.",
}

local tipLabel = Instance.new("TextLabel")
tipLabel.Name = "Tip"
tipLabel.Size = UDim2.new(0.6, 0, 0, 40)
tipLabel.Position = UDim2.new(0.2, 0, 0.85, 0)
tipLabel.Text = "TIP: " .. tips[math.random(1, #tips)]
tipLabel.TextSize = 14
tipLabel.Font = Enum.Font.GothamMedium
tipLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
tipLabel.TextWrapped = true
tipLabel.BackgroundTransparency = 1
tipLabel.TextTransparency = 1
tipLabel.Parent = bg

-- Version info
local versionLabel = Instance.new("TextLabel")
versionLabel.Size = UDim2.new(0, 200, 0, 20)
versionLabel.Position = UDim2.new(1, -210, 1, -30)
versionLabel.Text = "v1.0.0"
versionLabel.TextSize = 12
versionLabel.Font = Enum.Font.Gotham
versionLabel.TextColor3 = Color3.fromRGB(80, 80, 80)
versionLabel.TextXAlignment = Enum.TextXAlignment.Right
versionLabel.BackgroundTransparency = 1
versionLabel.Parent = bg

-- ============================================================
-- ANIMATIONS
-- ============================================================

-- Remove default loading screen
ReplicatedFirst:RemoveDefaultLoadingScreen()

-- Animate title fade in
task.delay(0.5, function()
    TweenService:Create(titleLabel, TweenInfo.new(1.5, Enum.EasingStyle.Sine), {
        TextTransparency = 0,
    }):Play()
end)

-- Animate subtitle
task.delay(1.5, function()
    TweenService:Create(subtitleLabel, TweenInfo.new(1, Enum.EasingStyle.Sine), {
        TextTransparency = 0,
    }):Play()
end)

-- Animate silhouette
task.delay(1, function()
    TweenService:Create(silhouette, TweenInfo.new(2, Enum.EasingStyle.Sine), {
        TextTransparency = 0.3,
    }):Play()
end)

-- Animate tip
task.delay(2, function()
    TweenService:Create(tipLabel, TweenInfo.new(1, Enum.EasingStyle.Sine), {
        TextTransparency = 0,
    }):Play()
end)

-- ============================================================
-- ASSET PRELOADING
-- ============================================================

local function preloadGame()
    -- Collect assets to preload
    local assetsToLoad = {}
    for _, descendant in ipairs(ReplicatedStorage:GetDescendants()) do
        if descendant:IsA("Sound") or descendant:IsA("Decal") or descendant:IsA("Texture") then
            table.insert(assetsToLoad, descendant)
        end
    end
    for _, descendant in ipairs(workspace:GetDescendants()) do
        if descendant:IsA("MeshPart") or descendant:IsA("Sound") or descendant:IsA("Decal") then
            table.insert(assetsToLoad, descendant)
        end
    end

    local total = math.max(#assetsToLoad, 1)
    local loaded = 0

    -- Preload with progress
    for i, asset in ipairs(assetsToLoad) do
        local success = pcall(function()
            ContentProvider:PreloadAsync({asset})
        end)

        loaded = loaded + 1
        local progress = loaded / total

        -- Update loading bar
        TweenService:Create(barFill, TweenInfo.new(0.2), {
            Size = UDim2.new(progress, 0, 1, 0),
        }):Play()

        -- Update loading text
        loadingText.Text = string.format("Loading... %d%%", math.floor(progress * 100))

        -- Cycle tips
        if i % 20 == 0 then
            tipLabel.Text = "TIP: " .. tips[math.random(1, #tips)]
        end
    end

    -- Ensure bar reaches 100%
    TweenService:Create(barFill, TweenInfo.new(0.5), {
        Size = UDim2.new(1, 0, 1, 0),
    }):Play()
    loadingText.Text = "Loading... 100%"
end

-- ============================================================
-- LOADING SEQUENCE
-- ============================================================

task.spawn(function()
    -- Wait minimum time for visual effect
    local minDisplayTime = 4
    local startTime = tick()

    -- Preload assets
    preloadGame()

    -- Wait for game systems to be ready
    ReplicatedStorage:WaitForChild("Remotes", 15)
    ReplicatedStorage:WaitForChild("Modules", 15)

    -- Ensure minimum display time
    local elapsed = tick() - startTime
    if elapsed < minDisplayTime then
        task.wait(minDisplayTime - elapsed)
    end

    -- Ready!
    loadingText.Text = "Ready!"
    barFill.BackgroundColor3 = Color3.fromRGB(50, 200, 50)

    task.wait(1)

    -- Fade out the loading screen
    local fadeTime = 1.5

    TweenService:Create(bg, TweenInfo.new(fadeTime, Enum.EasingStyle.Sine), {
        BackgroundTransparency = 1,
    }):Play()

    for _, child in ipairs(bg:GetDescendants()) do
        if child:IsA("TextLabel") then
            TweenService:Create(child, TweenInfo.new(fadeTime), {
                TextTransparency = 1,
            }):Play()
        elseif child:IsA("Frame") then
            TweenService:Create(child, TweenInfo.new(fadeTime), {
                BackgroundTransparency = 1,
            }):Play()
        end
    end

    task.wait(fadeTime + 0.5)

    -- Destroy loading screen
    loadingGui:Destroy()
end)
