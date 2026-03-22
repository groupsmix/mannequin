--[[
    SettingsMenu.lua
    Full settings menu with volume sliders, graphics quality, controls reference.
    Location: StarterGui/SettingsMenu (LocalScript)
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- STATE
-- ============================================================

local settingsOpen = false
local settingsGui: ScreenGui
local mainFrame: Frame

-- Default settings (loaded from server if available)
local settings = {
	MusicVolume = 0.5,
	SFXVolume = 0.7,
	AmbientVolume = 0.3,
	GraphicsQuality = 7, -- 1-10
	Sensitivity = 0.5,
	ShowFPS = false,
	ReducedMotion = false,
	Fullbright = false,
}

-- ============================================================
-- UI HELPERS
-- ============================================================

local function createCorner(parent: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = parent
	return corner
end

local function createPadding(parent: GuiObject, padding: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, padding)
	p.PaddingBottom = UDim.new(0, padding)
	p.PaddingLeft = UDim.new(0, padding)
	p.PaddingRight = UDim.new(0, padding)
	p.Parent = parent
	return p
end

-- ============================================================
-- SLIDER COMPONENT
-- ============================================================

local function createSlider(parent: GuiObject, label: string, initialValue: number, onChange: (number) -> ()): Frame
	local container = Instance.new("Frame")
	container.Name = "Slider_" .. label
	container.Size = UDim2.new(1, 0, 0, 50)
	container.BackgroundTransparency = 1
	container.Parent = parent

	-- Label
	local labelText = Instance.new("TextLabel")
	labelText.Size = UDim2.new(0.35, 0, 1, 0)
	labelText.Text = label
	labelText.TextSize = 14
	labelText.Font = Enum.Font.GothamMedium
	labelText.TextColor3 = Color3.fromRGB(200, 200, 200)
	labelText.TextXAlignment = Enum.TextXAlignment.Left
	labelText.BackgroundTransparency = 1
	labelText.Parent = container

	-- Value display
	local valueText = Instance.new("TextLabel")
	valueText.Size = UDim2.new(0, 40, 1, 0)
	valueText.Position = UDim2.new(1, -40, 0, 0)
	valueText.Text = tostring(math.floor(initialValue * 100)) .. "%"
	valueText.TextSize = 14
	valueText.Font = Enum.Font.Gotham
	valueText.TextColor3 = Color3.fromRGB(180, 180, 180)
	valueText.TextXAlignment = Enum.TextXAlignment.Right
	valueText.BackgroundTransparency = 1
	valueText.Parent = container

	-- Slider track
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.new(0.45, 0, 0, 6)
	track.Position = UDim2.new(0.38, 0, 0.5, -3)
	track.BackgroundColor3 = Color3.fromRGB(60, 55, 70)
	track.BorderSizePixel = 0
	track.Parent = container
	createCorner(track, 3)

	-- Slider fill
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(initialValue, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
	fill.BorderSizePixel = 0
	fill.Parent = track
	createCorner(fill, 3)

	-- Slider knob
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.new(0, 16, 0, 16)
	knob.Position = UDim2.new(initialValue, -8, 0.5, -8)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.BorderSizePixel = 0
	knob.ZIndex = 2
	knob.Parent = track
	createCorner(knob, 8)

	-- Shadow on knob
	local knobShadow = Instance.new("UIStroke")
	knobShadow.Color = Color3.fromRGB(0, 0, 0)
	knobShadow.Transparency = 0.5
	knobShadow.Thickness = 2
	knobShadow.Parent = knob

	-- Drag logic
	local dragging = false

	local function updateSlider(inputPos: Vector2)
		local trackAbsPos = track.AbsolutePosition.X
		local trackAbsSize = track.AbsoluteSize.X
		local relativeX = math.clamp((inputPos.X - trackAbsPos) / trackAbsSize, 0, 1)

		fill.Size = UDim2.new(relativeX, 0, 1, 0)
		knob.Position = UDim2.new(relativeX, -8, 0.5, -8)
		valueText.Text = tostring(math.floor(relativeX * 100)) .. "%"
		onChange(relativeX)
	end

	track.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			updateSlider(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)

	knob.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			updateSlider(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)

	return container
end

-- ============================================================
-- TOGGLE COMPONENT
-- ============================================================

local function createToggle(parent: GuiObject, label: string, initialValue: boolean, onChange: (boolean) -> ()): Frame
	local container = Instance.new("Frame")
	container.Name = "Toggle_" .. label
	container.Size = UDim2.new(1, 0, 0, 40)
	container.BackgroundTransparency = 1
	container.Parent = parent

	-- Label
	local labelText = Instance.new("TextLabel")
	labelText.Size = UDim2.new(0.7, 0, 1, 0)
	labelText.Text = label
	labelText.TextSize = 14
	labelText.Font = Enum.Font.GothamMedium
	labelText.TextColor3 = Color3.fromRGB(200, 200, 200)
	labelText.TextXAlignment = Enum.TextXAlignment.Left
	labelText.BackgroundTransparency = 1
	labelText.Parent = container

	-- Toggle track
	local toggleTrack = Instance.new("Frame")
	toggleTrack.Size = UDim2.new(0, 44, 0, 24)
	toggleTrack.Position = UDim2.new(1, -54, 0.5, -12)
	toggleTrack.BackgroundColor3 = initialValue and Color3.fromRGB(200, 60, 60) or Color3.fromRGB(60, 55, 70)
	toggleTrack.BorderSizePixel = 0
	toggleTrack.Parent = container
	createCorner(toggleTrack, 12)

	-- Toggle knob
	local toggleKnob = Instance.new("Frame")
	toggleKnob.Size = UDim2.new(0, 20, 0, 20)
	toggleKnob.Position = initialValue and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
	toggleKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	toggleKnob.BorderSizePixel = 0
	toggleKnob.Parent = toggleTrack
	createCorner(toggleKnob, 10)

	local currentValue = initialValue

	toggleTrack.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			currentValue = not currentValue

			TweenService:Create(toggleKnob, TweenInfo.new(0.2), {
				Position = currentValue and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10),
			}):Play()

			TweenService:Create(toggleTrack, TweenInfo.new(0.2), {
				BackgroundColor3 = currentValue and Color3.fromRGB(200, 60, 60) or Color3.fromRGB(60, 55, 70),
			}):Play()

			onChange(currentValue)
		end
	end)

	return container
end

-- ============================================================
-- SECTION HEADER
-- ============================================================

local function createSectionHeader(parent: GuiObject, text: string)
	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 35)
	header.Text = text
	header.TextSize = 16
	header.Font = Enum.Font.GothamBold
	header.TextColor3 = Color3.fromRGB(200, 60, 60)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.BackgroundTransparency = 1
	header.Parent = parent

	-- Divider line
	local divider = Instance.new("Frame")
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.Position = UDim2.new(0, 0, 1, -2)
	divider.BackgroundColor3 = Color3.fromRGB(60, 55, 70)
	divider.BorderSizePixel = 0
	divider.Parent = header

	return header
end

-- ============================================================
-- BUILD SETTINGS MENU
-- ============================================================

local function buildSettingsMenu()
	settingsGui = Instance.new("ScreenGui")
	settingsGui.Name = "SettingsGui"
	settingsGui.IgnoreGuiInset = true
	settingsGui.DisplayOrder = 50
	settingsGui.ResetOnSpawn = false
	settingsGui.Enabled = false
	settingsGui.Parent = playerGui

	-- Dark overlay
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.4
	overlay.BorderSizePixel = 0
	overlay.Parent = settingsGui

	overlay.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			SoundManager_closeSettings()
		end
	end)

	-- Main panel
	mainFrame = Instance.new("Frame")
	mainFrame.Name = "SettingsPanel"
	mainFrame.Size = UDim2.new(0, 420, 0, 560)
	mainFrame.Position = UDim2.new(0.5, -210, 0.5, -280)
	mainFrame.BackgroundColor3 = Color3.fromRGB(25, 22, 35)
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = settingsGui
	createCorner(mainFrame, 12)

	-- Panel border
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(80, 60, 100)
	panelStroke.Thickness = 1.5
	panelStroke.Parent = mainFrame

	-- Panel shadow
	local shadow = Instance.new("ImageLabel")
	shadow.Size = UDim2.new(1, 30, 1, 30)
	shadow.Position = UDim2.new(0, -15, 0, -15)
	shadow.BackgroundTransparency = 1
	shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
	shadow.ImageTransparency = 0.5
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.SliceCenter = Rect.new(30, 30, 30, 30)
	shadow.ZIndex = 0
	shadow.Parent = mainFrame

	-- Title bar
	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 50)
	titleBar.BackgroundColor3 = Color3.fromRGB(30, 27, 40)
	titleBar.BorderSizePixel = 0
	titleBar.Parent = mainFrame
	createCorner(titleBar, 12)

	-- Fix bottom corners of title bar
	local titleBarFix = Instance.new("Frame")
	titleBarFix.Size = UDim2.new(1, 0, 0, 15)
	titleBarFix.Position = UDim2.new(0, 0, 1, -15)
	titleBarFix.BackgroundColor3 = Color3.fromRGB(30, 27, 40)
	titleBarFix.BorderSizePixel = 0
	titleBarFix.Parent = titleBar

	local titleText = Instance.new("TextLabel")
	titleText.Size = UDim2.new(1, -60, 1, 0)
	titleText.Position = UDim2.new(0, 20, 0, 0)
	titleText.Text = "⚙ Settings"
	titleText.TextSize = 20
	titleText.Font = Enum.Font.GothamBold
	titleText.TextColor3 = Color3.fromRGB(220, 220, 220)
	titleText.TextXAlignment = Enum.TextXAlignment.Left
	titleText.BackgroundTransparency = 1
	titleText.Parent = titleBar

	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -43, 0, 7)
	closeBtn.Text = "X"
	closeBtn.TextSize = 18
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
	closeBtn.BackgroundColor3 = Color3.fromRGB(60, 55, 70)
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = titleBar
	createCorner(closeBtn, 8)

	closeBtn.MouseButton1Click:Connect(function()
		SoundManager_closeSettings()
	end)

	closeBtn.MouseEnter:Connect(function()
		TweenService:Create(closeBtn, TweenInfo.new(0.15), {
			BackgroundColor3 = Color3.fromRGB(200, 60, 60),
		}):Play()
	end)
	closeBtn.MouseLeave:Connect(function()
		TweenService:Create(closeBtn, TweenInfo.new(0.15), {
			BackgroundColor3 = Color3.fromRGB(60, 55, 70),
		}):Play()
	end)

	-- Scrollable content
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "Content"
	scrollFrame.Size = UDim2.new(1, -20, 1, -60)
	scrollFrame.Position = UDim2.new(0, 10, 0, 55)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.ScrollBarThickness = 4
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 80, 120)
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 700)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.Parent = mainFrame

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 5)
	layout.Parent = scrollFrame

	createPadding(scrollFrame, 10)

	-- ================== AUDIO SECTION ==================
	createSectionHeader(scrollFrame, "AUDIO")

	createSlider(scrollFrame, "Music Volume", settings.MusicVolume, function(val)
		settings.MusicVolume = val
		-- Apply to all music sounds
		for _, sound in ipairs(SoundService:GetDescendants()) do
			if sound:IsA("Sound") and sound.Name:find("Music") then
				sound.Volume = val * 0.5
			end
		end
	end)

	createSlider(scrollFrame, "SFX Volume", settings.SFXVolume, function(val)
		settings.SFXVolume = val
	end)

	createSlider(scrollFrame, "Ambient Volume", settings.AmbientVolume, function(val)
		settings.AmbientVolume = val
		for _, sound in ipairs(SoundService:GetDescendants()) do
			if
				sound:IsA("Sound") and (sound.Name:find("Ambient") or sound.Name:find("Hum") or sound.Name:find("Wind"))
			then
				sound.Volume = val * 0.3
			end
		end
	end)

	-- ================== DISPLAY SECTION ==================
	createSectionHeader(scrollFrame, "DISPLAY")

	createSlider(scrollFrame, "Graphics Quality", settings.GraphicsQuality / 10, function(val)
		settings.GraphicsQuality = math.floor(val * 10)
		local level = math.max(1, settings.GraphicsQuality)
		pcall(function()
			game:GetService("UserGameSettings").SavedQualityLevel = Enum.SavedQualitySetting["QualityLevel" .. level]
				or Enum.SavedQualitySetting.Automatic
		end)
	end)

	createSlider(scrollFrame, "Mouse Sensitivity", settings.Sensitivity, function(val)
		settings.Sensitivity = val
		pcall(function()
			UserInputService.MouseDeltaSensitivity = 0.2 + (val * 1.8) -- Range 0.2-2.0
		end)
	end)

	createToggle(scrollFrame, "Show FPS Counter", settings.ShowFPS, function(val)
		settings.ShowFPS = val
		-- Toggle FPS display
		local perfStats = game:GetService("Stats")
		pcall(function()
			perfStats.PerformanceStatsVisible = val
		end)
	end)

	createToggle(scrollFrame, "Reduced Motion", settings.ReducedMotion, function(val)
		settings.ReducedMotion = val
	end)

	-- ================== CONTROLS SECTION ==================
	createSectionHeader(scrollFrame, "CONTROLS")

	local controlsInfo = {
		{ "E", "Interact / Inspect Mannequin" },
		{ "F", "Toggle Flashlight" },
		{ "Q", "Kill (Monster Only)" },
		{ "M", "Call Emergency Meeting" },
		{ "Tab", "Toggle Task List" },
		{ "Esc / P", "Open Settings" },
	}

	for _, controlPair in ipairs(controlsInfo) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 30)
		row.BackgroundTransparency = 1
		row.Parent = scrollFrame

		-- Key badge
		local keyBadge = Instance.new("TextLabel")
		keyBadge.Size = UDim2.new(0, 50, 0, 26)
		keyBadge.Position = UDim2.new(0, 0, 0.5, -13)
		keyBadge.Text = controlPair[1]
		keyBadge.TextSize = 13
		keyBadge.Font = Enum.Font.GothamBold
		keyBadge.TextColor3 = Color3.fromRGB(220, 220, 220)
		keyBadge.BackgroundColor3 = Color3.fromRGB(50, 45, 65)
		keyBadge.BorderSizePixel = 0
		keyBadge.Parent = row
		createCorner(keyBadge, 4)

		local keyStroke = Instance.new("UIStroke")
		keyStroke.Color = Color3.fromRGB(80, 75, 95)
		keyStroke.Thickness = 1
		keyStroke.Parent = keyBadge

		-- Action label
		local actionLabel = Instance.new("TextLabel")
		actionLabel.Size = UDim2.new(1, -65, 1, 0)
		actionLabel.Position = UDim2.new(0, 60, 0, 0)
		actionLabel.Text = controlPair[2]
		actionLabel.TextSize = 14
		actionLabel.Font = Enum.Font.Gotham
		actionLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
		actionLabel.TextXAlignment = Enum.TextXAlignment.Left
		actionLabel.BackgroundTransparency = 1
		actionLabel.Parent = row
	end

	-- ================== ABOUT SECTION ==================
	createSectionHeader(scrollFrame, "ABOUT")

	local aboutText = Instance.new("TextLabel")
	aboutText.Size = UDim2.new(1, 0, 0, 60)
	aboutText.Text =
		"MANNEQUIN v1.0.0\nA horror/social deduction game.\nOne player is the Monster — disguised as a mannequin.\nIt can only move when no one is looking."
	aboutText.TextSize = 12
	aboutText.Font = Enum.Font.Gotham
	aboutText.TextColor3 = Color3.fromRGB(120, 120, 120)
	aboutText.TextWrapped = true
	aboutText.TextXAlignment = Enum.TextXAlignment.Left
	aboutText.TextYAlignment = Enum.TextYAlignment.Top
	aboutText.BackgroundTransparency = 1
	aboutText.Parent = scrollFrame
end

-- ============================================================
-- OPEN / CLOSE
-- ============================================================

function SoundManager_closeSettings()
	if not settingsOpen then
		return
	end
	settingsOpen = false

	-- Animate close
	TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Position = UDim2.new(0.5, -210, 1.5, 0),
	}):Play()

	task.delay(0.3, function()
		settingsGui.Enabled = false
		mainFrame.Position = UDim2.new(0.5, -210, 0.5, -280)
	end)

	-- Save settings to server
	pcall(function()
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		if remotes then
			local saveEvent = remotes:FindFirstChild("SaveSettings")
			if saveEvent then
				saveEvent:FireServer(settings)
			end
		end
	end)
end

local function openSettings()
	if settingsOpen then
		SoundManager_closeSettings()
		return
	end
	settingsOpen = true

	settingsGui.Enabled = true

	-- Animate open
	mainFrame.Position = UDim2.new(0.5, -210, -0.5, 0)
	TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -210, 0.5, -280),
	}):Play()
end

-- ============================================================
-- INPUT
-- ============================================================

local function setupInput()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.P then
			openSettings()
		end
	end)
end

-- ============================================================
-- INIT
-- ============================================================

buildSettingsMenu()
setupInput()
