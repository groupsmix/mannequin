--[[
    TutorialUI.lua
    Interactive onboarding tutorial for first-time players.
    Shows step-by-step instructions with animated panels.
    Location: StarterGui/TutorialUI (LocalScript)
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- TUTORIAL STEPS
-- ============================================================

local TUTORIAL_STEPS = {
	{
		Title = "Welcome to MANNEQUIN",
		Body = "A department store after hours. The lights are dimming.\nSomething among the mannequins isn't what it seems.\n\nYour goal: Complete your shopping tasks and escape alive.",
		Icon = "🏬",
		HighlightColor = Color3.fromRGB(200, 180, 150),
	},
	{
		Title = "The Roles",
		Body = "SHOPPERS (Most Players)\nComplete 5 tasks, find the exit, and escape.\n\nTHE MANNEQUIN (1 Player)\nDisguised as a store mannequin. Eliminate all shoppers before they escape.\n\nSHOPKEEPER (1 Player)\nAccess security cameras. Help shoppers identify the Monster.",
		Icon = "🎭",
		HighlightColor = Color3.fromRGB(200, 60, 60),
	},
	{
		Title = "The Core Mechanic",
		Body = "The Mannequin can ONLY move when nobody is looking at it.\n\nIf ANY player's camera is pointed at the Monster,\nit freezes instantly — like a real mannequin.\n\nKeep your eyes on suspicious mannequins.\nLook away... and it gets closer.",
		Icon = "👁️",
		HighlightColor = Color3.fromRGB(255, 200, 50),
	},
	{
		Title = "Your Tasks",
		Body = "As a Shopper, you have 5 tasks to complete:\n\n• Find items on shelves\n• Checkout at registers\n• Fix broken fuse boxes\n• Clean up spills\n• Restock shelves\n\nPress TAB to view your task list.\nWalk up to highlighted objects and press E to interact.",
		Icon = "📋",
		HighlightColor = Color3.fromRGB(60, 180, 60),
	},
	{
		Title = "Inspect & Investigate",
		Body = "See a mannequin that looks out of place?\nHold E near it for 2 seconds to INSPECT.\n\nIf it's the Monster — you'll stun it for 3 seconds\nand reveal its location to all players!\n\nBut be careful... you have a cooldown between inspections.",
		Icon = "🔍",
		HighlightColor = Color3.fromRGB(100, 150, 255),
	},
	{
		Title = "Emergency Meetings",
		Body = "Press M to call an Emergency Meeting.\nAll players teleport to the lobby for discussion.\n\nVote to eliminate who you think is the Monster.\nIf the majority agrees, that player is removed.\n\nBe careful — you can eliminate innocent shoppers!",
		Icon = "🗳️",
		HighlightColor = Color3.fromRGB(255, 100, 50),
	},
	{
		Title = "Your Tools",
		Body = "F — Toggle Flashlight\n   Light up dark areas. Essential as the store dims.\n\nE — Interact / Inspect\n   Complete tasks and check mannequins.\n\nQ — Kill (Monster Only)\n   Eliminate a nearby shopper.\n\nM — Emergency Meeting\n   Call all players to vote.\n\nTAB — Task List\n   Check your remaining tasks.",
		Icon = "🔧",
		HighlightColor = Color3.fromRGB(180, 120, 255),
	},
	{
		Title = "The Atmosphere",
		Body = "The store gets darker over time.\n\n0:00 — Normal lighting\n1:00 — Lights begin flickering\n2:00 — Sections go dark\n3:00 — Whispers echo through the aisles\n4:00 — Emergency red lighting\n4:30 — Doors start closing\n5:00 — Round ends!\n\nComplete your tasks and escape before time runs out.",
		Icon = "🌑",
		HighlightColor = Color3.fromRGB(60, 60, 120),
	},
	{
		Title = "Ready to Shop?",
		Body = "Remember:\n\n• Complete tasks to unlock the exit\n• Watch the mannequins — the Monster freezes when seen\n• Inspect suspicious mannequins to stun the Monster\n• Call meetings to vote out the Monster\n• Work together... or nobody escapes\n\nGood luck. Don't look away.",
		Icon = "🚪",
		HighlightColor = Color3.fromRGB(200, 60, 60),
	},
}

-- ============================================================
-- STATE
-- ============================================================

local currentStep = 1
local tutorialGui: ScreenGui
local tutorialActive = false

-- ============================================================
-- HELPERS
-- ============================================================

local function createCorner(parent: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = parent
end

-- ============================================================
-- BUILD TUTORIAL UI
-- ============================================================

local function buildTutorialUI()
	tutorialGui = Instance.new("ScreenGui")
	tutorialGui.Name = "TutorialGui"
	tutorialGui.IgnoreGuiInset = true
	tutorialGui.DisplayOrder = 100
	tutorialGui.ResetOnSpawn = false
	tutorialGui.Enabled = false
	tutorialGui.Parent = playerGui

	-- Dark overlay
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.3
	overlay.BorderSizePixel = 0
	overlay.Parent = tutorialGui

	-- Main panel
	local panel = Instance.new("Frame")
	panel.Name = "TutorialPanel"
	panel.Size = UDim2.new(0, 520, 0, 420)
	panel.Position = UDim2.new(0.5, -260, 0.5, -210)
	panel.BackgroundColor3 = Color3.fromRGB(20, 18, 30)
	panel.BorderSizePixel = 0
	panel.Parent = tutorialGui
	createCorner(panel, 16)

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(80, 60, 100)
	panelStroke.Thickness = 2
	panelStroke.Parent = panel

	-- Accent bar at top
	local accentBar = Instance.new("Frame")
	accentBar.Name = "AccentBar"
	accentBar.Size = UDim2.new(1, 0, 0, 4)
	accentBar.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
	accentBar.BorderSizePixel = 0
	accentBar.Parent = panel

	-- Icon
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "Icon"
	iconLabel.Size = UDim2.new(0, 80, 0, 80)
	iconLabel.Position = UDim2.new(0.5, -40, 0, 15)
	iconLabel.Text = "🏬"
	iconLabel.TextSize = 56
	iconLabel.Font = Enum.Font.SourceSans
	iconLabel.BackgroundTransparency = 1
	iconLabel.Parent = panel

	-- Title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -40, 0, 35)
	titleLabel.Position = UDim2.new(0, 20, 0, 95)
	titleLabel.Text = "Welcome to MANNEQUIN"
	titleLabel.TextSize = 24
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = Color3.fromRGB(220, 200, 180)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Parent = panel

	-- Body text
	local bodyLabel = Instance.new("TextLabel")
	bodyLabel.Name = "Body"
	bodyLabel.Size = UDim2.new(1, -50, 0, 180)
	bodyLabel.Position = UDim2.new(0, 25, 0, 135)
	bodyLabel.Text = ""
	bodyLabel.TextSize = 14
	bodyLabel.Font = Enum.Font.Gotham
	bodyLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	bodyLabel.TextWrapped = true
	bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
	bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
	bodyLabel.BackgroundTransparency = 1
	bodyLabel.Parent = panel

	-- Progress dots
	local dotsContainer = Instance.new("Frame")
	dotsContainer.Name = "Dots"
	dotsContainer.Size = UDim2.new(0, #TUTORIAL_STEPS * 18, 0, 12)
	dotsContainer.Position = UDim2.new(0.5, -(#TUTORIAL_STEPS * 18) / 2, 1, -60)
	dotsContainer.BackgroundTransparency = 1
	dotsContainer.Parent = panel

	local dotsLayout = Instance.new("UIListLayout")
	dotsLayout.FillDirection = Enum.FillDirection.Horizontal
	dotsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	dotsLayout.Padding = UDim.new(0, 6)
	dotsLayout.Parent = dotsContainer

	for i = 1, #TUTORIAL_STEPS do
		local dot = Instance.new("Frame")
		dot.Name = "Dot_" .. i
		dot.Size = UDim2.new(0, 12, 0, 12)
		dot.BackgroundColor3 = i == 1 and Color3.fromRGB(200, 60, 60) or Color3.fromRGB(60, 55, 70)
		dot.BorderSizePixel = 0
		dot.LayoutOrder = i
		dot.Parent = dotsContainer
		createCorner(dot, 6)
	end

	-- Button row
	local buttonRow = Instance.new("Frame")
	buttonRow.Size = UDim2.new(1, -40, 0, 40)
	buttonRow.Position = UDim2.new(0, 20, 1, -50)
	buttonRow.BackgroundTransparency = 1
	buttonRow.Parent = panel

	-- Skip button
	local skipBtn = Instance.new("TextButton")
	skipBtn.Name = "SkipBtn"
	skipBtn.Size = UDim2.new(0, 100, 1, 0)
	skipBtn.Position = UDim2.new(0, 0, 0, 0)
	skipBtn.Text = "Skip Tutorial"
	skipBtn.TextSize = 13
	skipBtn.Font = Enum.Font.Gotham
	skipBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
	skipBtn.BackgroundColor3 = Color3.fromRGB(40, 35, 55)
	skipBtn.BorderSizePixel = 0
	skipBtn.Parent = buttonRow
	createCorner(skipBtn, 8)

	skipBtn.MouseButton1Click:Connect(function()
		closeTutorial()
	end)

	-- Back button
	local backBtn = Instance.new("TextButton")
	backBtn.Name = "BackBtn"
	backBtn.Size = UDim2.new(0, 80, 1, 0)
	backBtn.Position = UDim2.new(1, -200, 0, 0)
	backBtn.Text = "← Back"
	backBtn.TextSize = 14
	backBtn.Font = Enum.Font.GothamMedium
	backBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
	backBtn.BackgroundColor3 = Color3.fromRGB(50, 45, 65)
	backBtn.BorderSizePixel = 0
	backBtn.Visible = false
	backBtn.Parent = buttonRow
	createCorner(backBtn, 8)

	backBtn.MouseButton1Click:Connect(function()
		goToStep(currentStep - 1)
	end)

	-- Next button
	local nextBtn = Instance.new("TextButton")
	nextBtn.Name = "NextBtn"
	nextBtn.Size = UDim2.new(0, 100, 1, 0)
	nextBtn.Position = UDim2.new(1, -100, 0, 0)
	nextBtn.Text = "Next →"
	nextBtn.TextSize = 14
	nextBtn.Font = Enum.Font.GothamBold
	nextBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	nextBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
	nextBtn.BorderSizePixel = 0
	nextBtn.Parent = buttonRow
	createCorner(nextBtn, 8)

	nextBtn.MouseButton1Click:Connect(function()
		if currentStep >= #TUTORIAL_STEPS then
			closeTutorial()
		else
			goToStep(currentStep + 1)
		end
	end)

	-- Hover effects
	for _, btn in ipairs({ skipBtn, backBtn, nextBtn }) do
		local originalColor = btn.BackgroundColor3
		btn.MouseEnter:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.15), {
				BackgroundColor3 = originalColor:Lerp(Color3.fromRGB(255, 255, 255), 0.15),
			}):Play()
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.15), {
				BackgroundColor3 = originalColor,
			}):Play()
		end)
	end
end

-- ============================================================
-- STEP NAVIGATION
-- ============================================================

function goToStep(stepIndex: number)
	if stepIndex < 1 or stepIndex > #TUTORIAL_STEPS then
		return
	end

	local step = TUTORIAL_STEPS[stepIndex]
	currentStep = stepIndex

	local panel = tutorialGui:FindFirstChild("TutorialPanel")
	if not panel then
		return
	end

	-- Animate transition
	local slideDir = stepIndex > currentStep and -1 or 1

	-- Update content
	local iconLabel = panel:FindFirstChild("Icon")
	local titleLabel = panel:FindFirstChild("Title")
	local bodyLabel = panel:FindFirstChild("Body")
	local accentBar = panel:FindFirstChild("AccentBar")

	if iconLabel then
		iconLabel.TextTransparency = 1
		iconLabel.Text = step.Icon
		TweenService:Create(iconLabel, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
	end

	if titleLabel then
		titleLabel.TextTransparency = 1
		titleLabel.Text = step.Title
		TweenService:Create(titleLabel, TweenInfo.new(0.4, Enum.EasingStyle.Sine), {
			TextTransparency = 0,
		}):Play()
		titleLabel.TextColor3 = step.HighlightColor
	end

	if bodyLabel then
		bodyLabel.TextTransparency = 1
		bodyLabel.Text = step.Body
		TweenService:Create(bodyLabel, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {
			TextTransparency = 0,
		}):Play()
	end

	if accentBar then
		TweenService:Create(accentBar, TweenInfo.new(0.3), {
			BackgroundColor3 = step.HighlightColor,
		}):Play()
	end

	-- Update dots
	local dotsContainer = panel:FindFirstChild("Dots")
	if dotsContainer then
		for i = 1, #TUTORIAL_STEPS do
			local dot = dotsContainer:FindFirstChild("Dot_" .. i)
			if dot then
				TweenService:Create(dot, TweenInfo.new(0.3), {
					BackgroundColor3 = i == stepIndex and step.HighlightColor or Color3.fromRGB(60, 55, 70),
					Size = i == stepIndex and UDim2.new(0, 20, 0, 12) or UDim2.new(0, 12, 0, 12),
				}):Play()
			end
		end
	end

	-- Update buttons
	local buttonRow = panel:FindFirstChild(panel:GetChildren()[#panel:GetChildren()].Name)
	local backBtn = panel:FindFirstChild("BackBtn", true)
	local nextBtn = panel:FindFirstChild("NextBtn", true)

	if backBtn then
		backBtn.Visible = stepIndex > 1
	end

	if nextBtn then
		if stepIndex >= #TUTORIAL_STEPS then
			nextBtn.Text = "Start Playing!"
			nextBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
		else
			nextBtn.Text = "Next →"
			nextBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
		end
	end

	-- Update panel stroke color
	local panelStroke = panel:FindFirstChildOfClass("UIStroke")
	if panelStroke then
		TweenService:Create(panelStroke, TweenInfo.new(0.3), {
			Color = step.HighlightColor:Lerp(Color3.fromRGB(0, 0, 0), 0.5),
		}):Play()
	end
end

-- ============================================================
-- OPEN / CLOSE
-- ============================================================

local function openTutorial()
	if tutorialActive then
		return
	end
	tutorialActive = true
	currentStep = 1

	tutorialGui.Enabled = true

	-- Animate in
	local panel = tutorialGui:FindFirstChild("TutorialPanel")
	if panel then
		panel.Position = UDim2.new(0.5, -260, 1.5, 0)
		TweenService:Create(panel, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, -260, 0.5, -210),
		}):Play()
	end

	goToStep(1)
end

function closeTutorial()
	if not tutorialActive then
		return
	end
	tutorialActive = false

	-- Animate out
	local panel = tutorialGui:FindFirstChild("TutorialPanel")
	if panel then
		TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, -260, -1, 0),
		}):Play()
	end

	task.delay(0.3, function()
		tutorialGui.Enabled = false
	end)

	-- Save that tutorial has been seen
	pcall(function()
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		if remotes then
			local saveEvent = remotes:FindFirstChild("SaveSettings")
			if saveEvent then
				saveEvent:FireServer({ ShowTutorial = false })
			end
		end
	end)
end

-- ============================================================
-- KEYBOARD NAVIGATION
-- ============================================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not tutorialActive then
		return
	end

	if input.KeyCode == Enum.KeyCode.Right or input.KeyCode == Enum.KeyCode.Return then
		if currentStep >= #TUTORIAL_STEPS then
			closeTutorial()
		else
			goToStep(currentStep + 1)
		end
	elseif input.KeyCode == Enum.KeyCode.Left then
		goToStep(currentStep - 1)
	elseif input.KeyCode == Enum.KeyCode.Escape then
		closeTutorial()
	end
end)

-- ============================================================
-- AUTO-SHOW FOR NEW PLAYERS
-- ============================================================

task.spawn(function()
	-- Wait for data to load
	task.wait(5)

	-- Check if player has seen tutorial before
	local shouldShow = true
	pcall(function()
		local remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
		if remotes then
			local getSettings = remotes:FindFirstChild("GetPlayerSettings")
			if getSettings and getSettings:IsA("RemoteFunction") then
				local playerSettings = getSettings:InvokeServer()
				if playerSettings and playerSettings.ShowTutorial == false then
					shouldShow = false
				end
			end
		end
	end)

	if shouldShow then
		openTutorial()
	end
end)

-- ============================================================
-- INIT
-- ============================================================

buildTutorialUI()

-- Allow re-opening from lobby/settings
pcall(function()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	if remotes then
		local showTutorial = remotes:FindFirstChild("ShowTutorial")
		if showTutorial and showTutorial:IsA("RemoteEvent") then
			showTutorial.OnClientEvent:Connect(function()
				openTutorial()
			end)
		end
	end
end)
