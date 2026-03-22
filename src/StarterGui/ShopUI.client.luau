--[[
    ShopUI.lua
    Full scrollable cosmetics shop with categories, previews, and purchase flow.
    Location: StarterGui/ShopUI (LocalScript)
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- SHOP DATA
-- ============================================================

local CATEGORIES = {
	{ Name = "Skins", Icon = "🎭", Color = Color3.fromRGB(200, 60, 60) },
	{ Name = "Effects", Icon = "✨", Color = Color3.fromRGB(60, 150, 200) },
	{ Name = "Emotes", Icon = "💃", Color = Color3.fromRGB(200, 180, 60) },
	{ Name = "Game Passes", Icon = "⭐", Color = Color3.fromRGB(255, 170, 0) },
}

-- Cosmetic items available for purchase
local SHOP_ITEMS = {
	Skins = {
		{
			Id = "skin_bloody",
			Name = "Blood-Stained",
			Description = "A mannequin covered in mysterious red stains.",
			Price = 500,
			Currency = "Coins",
			Rarity = "Rare",
			RarityColor = Color3.fromRGB(50, 120, 255),
			Preview = "🩸",
		},
		{
			Id = "skin_golden",
			Name = "Golden Mannequin",
			Description = "Gleaming gold from head to toe. Flex on the shoppers.",
			Price = 1500,
			Currency = "Coins",
			Rarity = "Legendary",
			RarityColor = Color3.fromRGB(255, 200, 50),
			Preview = "👑",
		},
		{
			Id = "skin_neon",
			Name = "Neon Glow",
			Description = "Faintly glowing neon outlines. Harder to hide, but looks incredible.",
			Price = 800,
			Currency = "Coins",
			Rarity = "Epic",
			RarityColor = Color3.fromRGB(170, 50, 255),
			Preview = "💡",
		},
		{
			Id = "skin_cracked",
			Name = "Cracked Porcelain",
			Description = "Shattered and repaired. Each crack tells a story.",
			Price = 350,
			Currency = "Coins",
			Rarity = "Uncommon",
			RarityColor = Color3.fromRGB(50, 200, 50),
			Preview = "🏺",
		},
		{
			Id = "skin_shadow",
			Name = "Shadow Form",
			Description = "A silhouette of pure darkness. Are you even real?",
			Price = 2000,
			Currency = "Coins",
			Rarity = "Legendary",
			RarityColor = Color3.fromRGB(255, 200, 50),
			Preview = "🌑",
		},
		{
			Id = "skin_vintage",
			Name = "Vintage Department",
			Description = "Classic 1960s department store mannequin aesthetic.",
			Price = 200,
			Currency = "Coins",
			Rarity = "Common",
			RarityColor = Color3.fromRGB(180, 180, 180),
			Preview = "🕰️",
		},
		{
			Id = "skin_crystal",
			Name = "Crystal Clear",
			Description = "Transparent crystalline form. Beautiful and terrifying.",
			Price = 1200,
			Currency = "Coins",
			Rarity = "Epic",
			RarityColor = Color3.fromRGB(170, 50, 255),
			Preview = "💎",
		},
		{
			Id = "skin_wireframe",
			Name = "Wireframe",
			Description = "See-through mesh construction. The future of mannequins.",
			Price = 600,
			Currency = "Coins",
			Rarity = "Rare",
			RarityColor = Color3.fromRGB(50, 120, 255),
			Preview = "🔲",
		},
	},
	Effects = {
		{
			Id = "effect_smoke",
			Name = "Smoke Trail",
			Description = "Leave a trail of eerie smoke as you move.",
			Price = 400,
			Currency = "Coins",
			Rarity = "Rare",
			RarityColor = Color3.fromRGB(50, 120, 255),
			Preview = "💨",
		},
		{
			Id = "effect_sparks",
			Name = "Static Sparks",
			Description = "Electrical sparks crackle around you.",
			Price = 700,
			Currency = "Coins",
			Rarity = "Epic",
			RarityColor = Color3.fromRGB(170, 50, 255),
			Preview = "⚡",
		},
		{
			Id = "effect_glitch",
			Name = "Digital Glitch",
			Description = "Your character glitches and distorts periodically.",
			Price = 900,
			Currency = "Coins",
			Rarity = "Epic",
			RarityColor = Color3.fromRGB(170, 50, 255),
			Preview = "📺",
		},
		{
			Id = "effect_frost",
			Name = "Frost Aura",
			Description = "Cold mist swirls around your feet.",
			Price = 500,
			Currency = "Coins",
			Rarity = "Rare",
			RarityColor = Color3.fromRGB(50, 120, 255),
			Preview = "❄️",
		},
	},
	Emotes = {
		{
			Id = "emote_wave",
			Name = "Creepy Wave",
			Description = "A slow, unsettling wave. Perfect for taunting.",
			Price = 150,
			Currency = "Coins",
			Rarity = "Common",
			RarityColor = Color3.fromRGB(180, 180, 180),
			Preview = "👋",
		},
		{
			Id = "emote_tpose",
			Name = "T-Pose",
			Description = "Assert dominance. Mannequin style.",
			Price = 100,
			Currency = "Coins",
			Rarity = "Common",
			RarityColor = Color3.fromRGB(180, 180, 180),
			Preview = "✝️",
		},
		{
			Id = "emote_headtilt",
			Name = "Head Tilt",
			Description = "Slowly tilt your head 45 degrees. Disturbing.",
			Price = 300,
			Currency = "Coins",
			Rarity = "Uncommon",
			RarityColor = Color3.fromRGB(50, 200, 50),
			Preview = "🤔",
		},
		{
			Id = "emote_freeze",
			Name = "Freeze Frame",
			Description = "Instantly snap into a mannequin pose.",
			Price = 450,
			Currency = "Coins",
			Rarity = "Rare",
			RarityColor = Color3.fromRGB(50, 120, 255),
			Preview = "🧊",
		},
	},
	["Game Passes"] = {
		{
			Id = "gp_vip",
			Name = "VIP Pass",
			Description = "2x XP, VIP lobby, exclusive chat tag, priority role selection.",
			Price = 499,
			Currency = "Robux",
			Rarity = "Legendary",
			RarityColor = Color3.fromRGB(255, 200, 50),
			Preview = "⭐",
			GamePassId = 0, -- Replace with real ID
		},
		{
			Id = "gp_radio",
			Name = "Monster Radio",
			Description = "Hear Monster proximity audio as a Shopper.",
			Price = 199,
			Currency = "Robux",
			Rarity = "Epic",
			RarityColor = Color3.fromRGB(170, 50, 255),
			Preview = "📻",
			GamePassId = 0,
		},
		{
			Id = "gp_flashlight",
			Name = "Flashlight Pro",
			Description = "Wider beam, longer range, and a strobe mode.",
			Price = 149,
			Currency = "Robux",
			Rarity = "Rare",
			RarityColor = Color3.fromRGB(50, 120, 255),
			Preview = "🔦",
			GamePassId = 0,
		},
		{
			Id = "gp_inspect",
			Name = "Extra Inspect",
			Description = "Inspect range +50%, cooldown -30%.",
			Price = 99,
			Currency = "Robux",
			Rarity = "Uncommon",
			RarityColor = Color3.fromRGB(50, 200, 50),
			Preview = "🔍",
			GamePassId = 0,
		},
	},
}

-- ============================================================
-- STATE
-- ============================================================

local shopOpen = false
local shopGui: ScreenGui
local currentCategory = "Skins"
local itemCards: { [string]: Frame } = {}

-- ============================================================
-- HELPERS
-- ============================================================

local function createCorner(parent: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = parent
end

local function getPlayerCoins(): number
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local coins = leaderstats:FindFirstChild("Coins")
		if coins then
			return coins.Value
		end
	end
	return 0
end

-- ============================================================
-- BUILD SHOP UI
-- ============================================================

local function buildShopUI()
	shopGui = Instance.new("ScreenGui")
	shopGui.Name = "ShopGui"
	shopGui.IgnoreGuiInset = true
	shopGui.DisplayOrder = 40
	shopGui.ResetOnSpawn = false
	shopGui.Enabled = false
	shopGui.Parent = playerGui

	-- Overlay
	local overlay = Instance.new("Frame")
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.3
	overlay.BorderSizePixel = 0
	overlay.Parent = shopGui

	overlay.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			closeShop()
		end
	end)

	-- Main panel
	local mainPanel = Instance.new("Frame")
	mainPanel.Name = "ShopPanel"
	mainPanel.Size = UDim2.new(0, 700, 0, 500)
	mainPanel.Position = UDim2.new(0.5, -350, 0.5, -250)
	mainPanel.BackgroundColor3 = Color3.fromRGB(20, 18, 30)
	mainPanel.BorderSizePixel = 0
	mainPanel.Parent = shopGui
	createCorner(mainPanel, 16)

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(80, 60, 100)
	panelStroke.Thickness = 2
	panelStroke.Parent = mainPanel

	-- Title bar
	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 55)
	titleBar.BackgroundColor3 = Color3.fromRGB(30, 25, 42)
	titleBar.BorderSizePixel = 0
	titleBar.Parent = mainPanel
	createCorner(titleBar, 16)

	local titleFix = Instance.new("Frame")
	titleFix.Size = UDim2.new(1, 0, 0, 16)
	titleFix.Position = UDim2.new(0, 0, 1, -16)
	titleFix.BackgroundColor3 = Color3.fromRGB(30, 25, 42)
	titleFix.BorderSizePixel = 0
	titleFix.Parent = titleBar

	local titleText = Instance.new("TextLabel")
	titleText.Size = UDim2.new(0.5, 0, 1, 0)
	titleText.Position = UDim2.new(0, 20, 0, 0)
	titleText.Text = "🛍️  MANNEQUIN SHOP"
	titleText.TextSize = 22
	titleText.Font = Enum.Font.GothamBold
	titleText.TextColor3 = Color3.fromRGB(220, 200, 180)
	titleText.TextXAlignment = Enum.TextXAlignment.Left
	titleText.BackgroundTransparency = 1
	titleText.Parent = titleBar

	-- Coin display
	local coinDisplay = Instance.new("TextLabel")
	coinDisplay.Name = "CoinDisplay"
	coinDisplay.Size = UDim2.new(0, 150, 0, 30)
	coinDisplay.Position = UDim2.new(1, -220, 0.5, -15)
	coinDisplay.Text = "🪙 " .. tostring(getPlayerCoins())
	coinDisplay.TextSize = 16
	coinDisplay.Font = Enum.Font.GothamBold
	coinDisplay.TextColor3 = Color3.fromRGB(255, 215, 0)
	coinDisplay.TextXAlignment = Enum.TextXAlignment.Right
	coinDisplay.BackgroundTransparency = 1
	coinDisplay.Parent = titleBar

	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 40, 0, 40)
	closeBtn.Position = UDim2.new(1, -50, 0, 8)
	closeBtn.Text = "X"
	closeBtn.TextSize = 20
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
	closeBtn.BackgroundColor3 = Color3.fromRGB(60, 50, 75)
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = titleBar
	createCorner(closeBtn, 8)

	closeBtn.MouseButton1Click:Connect(function()
		closeShop()
	end)
	closeBtn.MouseEnter:Connect(function()
		TweenService:Create(closeBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(200, 60, 60) }):Play()
	end)
	closeBtn.MouseLeave:Connect(function()
		TweenService:Create(closeBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(60, 50, 75) }):Play()
	end)

	-- Category tabs
	local tabBar = Instance.new("Frame")
	tabBar.Size = UDim2.new(1, -20, 0, 40)
	tabBar.Position = UDim2.new(0, 10, 0, 60)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = mainPanel

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Padding = UDim.new(0, 5)
	tabLayout.Parent = tabBar

	for i, category in ipairs(CATEGORIES) do
		local tab = Instance.new("TextButton")
		tab.Name = "Tab_" .. category.Name
		tab.Size = UDim2.new(0, 160, 1, 0)
		tab.Text = category.Icon .. " " .. category.Name
		tab.TextSize = 14
		tab.Font = Enum.Font.GothamBold
		tab.TextColor3 = i == 1 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 150)
		tab.BackgroundColor3 = i == 1 and category.Color or Color3.fromRGB(40, 35, 55)
		tab.BorderSizePixel = 0
		tab.LayoutOrder = i
		tab.Parent = tabBar
		createCorner(tab, 8)

		tab.MouseButton1Click:Connect(function()
			switchCategory(category.Name)
			-- Update tab visuals
			for _, otherTab in ipairs(tabBar:GetChildren()) do
				if otherTab:IsA("TextButton") then
					local idx = otherTab.LayoutOrder
					local cat = CATEGORIES[idx]
					if otherTab.Name == "Tab_" .. category.Name then
						TweenService:Create(otherTab, TweenInfo.new(0.2), {
							BackgroundColor3 = cat.Color,
							TextColor3 = Color3.fromRGB(255, 255, 255),
						}):Play()
					else
						TweenService:Create(otherTab, TweenInfo.new(0.2), {
							BackgroundColor3 = Color3.fromRGB(40, 35, 55),
							TextColor3 = Color3.fromRGB(150, 150, 150),
						}):Play()
					end
				end
			end
		end)
	end

	-- Item grid (scrollable)
	local itemGrid = Instance.new("ScrollingFrame")
	itemGrid.Name = "ItemGrid"
	itemGrid.Size = UDim2.new(1, -20, 1, -115)
	itemGrid.Position = UDim2.new(0, 10, 0, 105)
	itemGrid.BackgroundTransparency = 1
	itemGrid.ScrollBarThickness = 4
	itemGrid.ScrollBarImageColor3 = Color3.fromRGB(100, 80, 120)
	itemGrid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	itemGrid.Parent = mainPanel

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 155, 0, 200)
	gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = itemGrid

	local gridPadding = Instance.new("UIPadding")
	gridPadding.PaddingTop = UDim.new(0, 5)
	gridPadding.PaddingLeft = UDim.new(0, 5)
	gridPadding.Parent = itemGrid

	-- Populate initial category
	populateItems(itemGrid, "Skins")
end

-- ============================================================
-- ITEM CARDS
-- ============================================================

function populateItems(grid: ScrollingFrame, categoryName: string)
	-- Clear existing items
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local items = SHOP_ITEMS[categoryName]
	if not items then
		return
	end

	for i, item in ipairs(items) do
		local card = Instance.new("Frame")
		card.Name = "Item_" .. item.Id
		card.BackgroundColor3 = Color3.fromRGB(35, 30, 50)
		card.BorderSizePixel = 0
		card.LayoutOrder = i
		card.Parent = grid
		createCorner(card, 10)

		local cardStroke = Instance.new("UIStroke")
		cardStroke.Color = Color3.fromRGB(60, 55, 80)
		cardStroke.Thickness = 1
		cardStroke.Parent = card

		-- Preview icon
		local preview = Instance.new("TextLabel")
		preview.Size = UDim2.new(1, 0, 0, 70)
		preview.Position = UDim2.new(0, 0, 0, 5)
		preview.Text = item.Preview
		preview.TextSize = 48
		preview.Font = Enum.Font.SourceSans
		preview.BackgroundTransparency = 1
		preview.Parent = card

		-- Rarity badge
		local rarityBadge = Instance.new("TextLabel")
		rarityBadge.Size = UDim2.new(0, 70, 0, 18)
		rarityBadge.Position = UDim2.new(0.5, -35, 0, 75)
		rarityBadge.Text = item.Rarity
		rarityBadge.TextSize = 10
		rarityBadge.Font = Enum.Font.GothamBold
		rarityBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
		rarityBadge.BackgroundColor3 = item.RarityColor
		rarityBadge.BorderSizePixel = 0
		rarityBadge.Parent = card
		createCorner(rarityBadge, 4)

		-- Item name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -10, 0, 20)
		nameLabel.Position = UDim2.new(0, 5, 0, 98)
		nameLabel.Text = item.Name
		nameLabel.TextSize = 13
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.BackgroundTransparency = 1
		nameLabel.Parent = card

		-- Description
		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(1, -10, 0, 30)
		descLabel.Position = UDim2.new(0, 5, 0, 118)
		descLabel.Text = item.Description
		descLabel.TextSize = 10
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
		descLabel.TextWrapped = true
		descLabel.TextYAlignment = Enum.TextYAlignment.Top
		descLabel.BackgroundTransparency = 1
		descLabel.Parent = card

		-- Buy button
		local buyBtn = Instance.new("TextButton")
		buyBtn.Size = UDim2.new(1, -16, 0, 32)
		buyBtn.Position = UDim2.new(0, 8, 1, -40)
		buyBtn.TextSize = 13
		buyBtn.Font = Enum.Font.GothamBold
		buyBtn.BorderSizePixel = 0
		buyBtn.Parent = card
		createCorner(buyBtn, 6)

		if item.Currency == "Robux" then
			buyBtn.Text = "R$ " .. tostring(item.Price)
			buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			buyBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 0)
		else
			buyBtn.Text = "🪙 " .. tostring(item.Price)
			buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			buyBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
		end

		-- Hover effect
		card.MouseEnter:Connect(function()
			TweenService:Create(cardStroke, TweenInfo.new(0.2), { Color = item.RarityColor }):Play()
			TweenService:Create(card, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(45, 40, 65) }):Play()
		end)
		card.MouseLeave:Connect(function()
			TweenService:Create(cardStroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(60, 55, 80) }):Play()
			TweenService:Create(card, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(35, 30, 50) }):Play()
		end)

		-- Purchase handler
		buyBtn.MouseButton1Click:Connect(function()
			purchaseItem(item, buyBtn)
		end)

		itemCards[item.Id] = card
	end
end

function switchCategory(categoryName: string)
	currentCategory = categoryName
	local grid = shopGui:FindFirstChild("ShopPanel"):FindFirstChild("ItemGrid")
	if grid then
		populateItems(grid, categoryName)
	end
end

-- ============================================================
-- PURCHASE FLOW
-- ============================================================

function purchaseItem(item: { [string]: any }, button: TextButton)
	if item.Currency == "Robux" then
		-- Trigger Roblox marketplace prompt
		if item.GamePassId and item.GamePassId > 0 then
			MarketplaceService:PromptGamePassPurchase(player, item.GamePassId)
		end
	else
		-- In-game coin purchase
		local originalText = button.Text
		button.Text = "Buying..."
		button.BackgroundColor3 = Color3.fromRGB(100, 100, 100)

		-- Fire server to process purchase
		pcall(function()
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			if remotes then
				local purchaseEvent = remotes:FindFirstChild("PurchaseShopItem")
				if purchaseEvent then
					purchaseEvent:FireServer(item.Id)
				end
			end
		end)

		-- Reset button after delay
		task.delay(1.5, function()
			button.Text = originalText
			button.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
		end)
	end
end

-- ============================================================
-- OPEN / CLOSE
-- ============================================================

function closeShop()
	if not shopOpen then
		return
	end
	shopOpen = false

	local panel = shopGui:FindFirstChild("ShopPanel")
	if panel then
		TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, -350, 1.5, 0),
		}):Play()
	end

	task.delay(0.3, function()
		shopGui.Enabled = false
		if panel then
			panel.Position = UDim2.new(0.5, -350, 0.5, -250)
		end
	end)
end

local function openShop()
	if shopOpen then
		closeShop()
		return
	end
	shopOpen = true

	-- Update coin display
	local coinDisplay = shopGui:FindFirstChild("ShopPanel") and shopGui.ShopPanel:FindFirstChild("CoinDisplay")
	if coinDisplay then
		coinDisplay.Text = "🪙 " .. tostring(getPlayerCoins())
	end

	shopGui.Enabled = true

	local panel = shopGui:FindFirstChild("ShopPanel")
	if panel then
		panel.Position = UDim2.new(0.5, -350, -1, 0)
		TweenService:Create(panel, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, -350, 0.5, -250),
		}):Play()
	end
end

-- ============================================================
-- LISTEN FOR PURCHASE RESULTS
-- ============================================================

pcall(function()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	if remotes then
		local purchaseResult = remotes:FindFirstChild("PurchaseResult")
		if purchaseResult and purchaseResult:IsA("RemoteEvent") then
			purchaseResult.OnClientEvent:Connect(function(data)
				if data.success then
					-- Update coin display
					local coinDisplay = shopGui:FindFirstChild("ShopPanel")
						and shopGui.ShopPanel:FindFirstChild("CoinDisplay")
					if coinDisplay then
						coinDisplay.Text = "🪙 " .. tostring(getPlayerCoins())
					end

					-- Mark item as owned
					local card = itemCards[data.itemId]
					if card then
						local btn = card:FindFirstChildOfClass("TextButton")
						if btn then
							btn.Text = "OWNED"
							btn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
						end
					end
				else
					-- Show error
					local card = itemCards[data.itemId]
					if card then
						local btn = card:FindFirstChildOfClass("TextButton")
						if btn then
							btn.Text = data.reason or "Failed"
							btn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
							task.delay(2, function()
								local item = nil
								for _, items in pairs(SHOP_ITEMS) do
									for _, itm in ipairs(items) do
										if itm.Id == data.itemId then
											item = itm
											break
										end
									end
								end
								if item then
									btn.Text = (item.Currency == "Robux" and "R$ " or "🪙 ") .. tostring(item.Price)
									btn.BackgroundColor3 = item.Currency == "Robux" and Color3.fromRGB(0, 160, 0)
										or Color3.fromRGB(200, 60, 60)
								end
							end)
						end
					end
				end
			end)
		end
	end
end)

-- ============================================================
-- INPUT
-- ============================================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.B then
		openShop()
	end
end)

-- ============================================================
-- INIT
-- ============================================================

buildShopUI()
