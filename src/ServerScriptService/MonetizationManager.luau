--[[
    MonetizationManager.lua
    Handles Game Passes, Developer Products, and the in-game cosmetic shop.
    Location: ServerScriptService/MonetizationManager
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RemoteSetup"))

local MonetizationManager = {}

-- Forward-declare
local DataManager
local TaskManager
local VoteManager

-- ============================================================
-- GAME PASS CACHE
-- ============================================================

local gamePassCache: { [Player]: { [string]: boolean } } = {}

--- Check if a player owns a game pass (cached).
function MonetizationManager.hasGamePass(player: Player, passName: string): boolean
	local cache = gamePassCache[player]
	if cache and cache[passName] ~= nil then
		return cache[passName]
	end

	local passConfig = Config.GamePasses[passName]
	if not passConfig or passConfig.AssetId == 0 then
		return false
	end

	local success, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passConfig.AssetId)
	end)

	if success then
		if not gamePassCache[player] then
			gamePassCache[player] = {}
		end
		gamePassCache[player][passName] = owns
		return owns
	end

	return false
end

-- ============================================================
-- GAME PASS PURCHASE HANDLING
-- ============================================================

local function onGamePassPurchaseFinished(player: Player, gamePassId: number, wasPurchased: boolean)
	if not wasPurchased then
		return
	end

	-- Find which pass was purchased
	for name, passConfig in pairs(Config.GamePasses) do
		if passConfig.AssetId == gamePassId then
			-- Update cache
			if not gamePassCache[player] then
				gamePassCache[player] = {}
			end
			gamePassCache[player][name] = true

			-- Update player data
			if DataManager then
				local data = DataManager.getPlayerData(player)
				if data then
					data.GamePasses[name] = true
				end
			end

			Remotes.fireClient("PurchaseResult", player, {
				success = true,
				item = passConfig.Name,
			})

			Remotes.fireClient("ShowNotification", player, {
				text = "Thank you for purchasing " .. passConfig.Name .. "!",
				duration = 5,
				type = "success",
			})

			print(string.format("[Monetization] %s purchased Game Pass: %s", player.Name, name))
			break
		end
	end
end

-- ============================================================
-- DEVELOPER PRODUCT PURCHASE HANDLING
-- ============================================================

local function processReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productId = receiptInfo.ProductId

	-- 2x XP Boost
	local xpBoostConfig = Config.DevProducts.XPBoost
	if xpBoostConfig.AssetId == productId then
		if DataManager then
			DataManager.addBoost(player, "XPBoost", xpBoostConfig.Duration)
		end
		Remotes.fireClient("PurchaseResult", player, {
			success = true,
			item = xpBoostConfig.Name,
		})
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- Skip Task
	local skipTaskConfig = Config.DevProducts.SkipTask
	if skipTaskConfig.AssetId == productId then
		if TaskManager then
			local skipped = TaskManager.skipTask(player)
			if skipped then
				Remotes.fireClient("PurchaseResult", player, {
					success = true,
					item = skipTaskConfig.Name,
				})
			else
				Remotes.fireClient("PurchaseResult", player, {
					success = false,
					item = "No tasks to skip!",
				})
			end
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- Extra Vote
	local extraVoteConfig = Config.DevProducts.ExtraVote
	if extraVoteConfig.AssetId == productId then
		if VoteManager then
			VoteManager.grantExtraVote(player)
		end
		Remotes.fireClient("PurchaseResult", player, {
			success = true,
			item = extraVoteConfig.Name,
		})
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- ============================================================
-- IN-GAME COSMETIC SHOP (Store Credits)
-- ============================================================

-- Shop items purchasable with in-game currency
local shopItems = {
	-- Shopper outfits
	{ Id = "outfit_detective", Name = "Detective Hat", Type = "Outfit", Price = 500, Category = "Hats" },
	{ Id = "outfit_sunglasses", Name = "Dark Sunglasses", Type = "Outfit", Price = 300, Category = "Accessories" },
	{ Id = "outfit_hoodie", Name = "Mysterious Hoodie", Type = "Outfit", Price = 750, Category = "Shirts" },

	-- Kill effects (for Monster)
	{ Id = "kill_shadow", Name = "Shadow Grab", Type = "KillEffect", Price = 1000, Category = "Effects" },
	{ Id = "kill_static", Name = "TV Static", Type = "KillEffect", Price = 1500, Category = "Effects" },
	{ Id = "kill_glitch", Name = "Reality Glitch", Type = "KillEffect", Price = 2000, Category = "Effects" },

	-- Lobby emotes
	{ Id = "emote_wave", Name = "Friendly Wave", Type = "Emote", Price = 200, Category = "Emotes" },
	{ Id = "emote_scared", Name = "Scared Shiver", Type = "Emote", Price = 400, Category = "Emotes" },
	{ Id = "emote_dance", Name = "Victory Dance", Type = "Emote", Price = 600, Category = "Emotes" },
}

function MonetizationManager.getShopItems(): { { [string]: any } }
	return shopItems
end

function MonetizationManager.purchaseShopItem(player: Player, itemId: string): (boolean, string)
	local item = nil
	for _, shopItem in ipairs(shopItems) do
		if shopItem.Id == itemId then
			item = shopItem
			break
		end
	end

	if not item then
		return false, "Item not found."
	end

	if not DataManager then
		return false, "Data system unavailable."
	end

	local data = DataManager.getPlayerData(player)
	if not data then
		return false, "Player data not loaded."
	end

	-- Check if already owned
	if data.UnlockedSkins and table.find(data.UnlockedSkins, itemId) then
		return false, "You already own this item."
	end

	-- Check coins
	local success = DataManager.spendCoins(player, item.Price)
	if not success then
		return false, "Not enough Store Credits! (Need " .. item.Price .. ")"
	end

	-- Grant the item
	if item.Type == "Skin" then
		table.insert(data.UnlockedSkins, itemId)
	end
	-- Other types stored generically
	if not data.OwnedItems then
		data.OwnedItems = {}
	end
	table.insert(data.OwnedItems, itemId)

	Remotes.fireClient("PurchaseResult", player, {
		success = true,
		item = item.Name,
	})

	return true, "Purchased " .. item.Name .. "!"
end

-- ============================================================
-- CLIENT PURCHASE REQUESTS
-- ============================================================

local function onPurchaseGamePass(player: Player, data: { passId: string })
	if typeof(data) ~= "table" then
		return
	end
	local passName = data.passId
	if typeof(passName) ~= "string" then
		return
	end

	local passConfig = Config.GamePasses[passName]
	if not passConfig or passConfig.AssetId == 0 then
		Remotes.fireClient("ShowNotification", player, {
			text = "This Game Pass is not available yet.",
			duration = 3,
			type = "warning",
		})
		return
	end

	-- Prompt the purchase through Roblox
	MarketplaceService:PromptGamePassPurchase(player, passConfig.AssetId)
end

local function onPurchaseProduct(player: Player, data: { productId: string })
	if typeof(data) ~= "table" then
		return
	end
	local productName = data.productId
	if typeof(productName) ~= "string" then
		return
	end

	local productConfig = Config.DevProducts[productName]
	if not productConfig or productConfig.AssetId == 0 then
		Remotes.fireClient("ShowNotification", player, {
			text = "This product is not available yet.",
			duration = 3,
			type = "warning",
		})
		return
	end

	MarketplaceService:PromptProductPurchase(player, productConfig.AssetId)
end

-- ============================================================
-- INIT
-- ============================================================

function MonetizationManager.init(services: { [string]: any })
	DataManager = services.DataManager
	TaskManager = services.TaskManager
	VoteManager = services.VoteManager

	-- Game Pass purchase callback
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onGamePassPurchaseFinished)

	-- Developer Product receipt callback
	MarketplaceService.ProcessReceipt = processReceipt

	-- Client purchase requests
	local purchasePassEvent = Remotes.getEvent("PurchaseGamePass")
	purchasePassEvent.OnServerEvent:Connect(onPurchaseGamePass)

	local purchaseProductEvent = Remotes.getEvent("PurchaseProduct")
	purchaseProductEvent.OnServerEvent:Connect(onPurchaseProduct)

	-- Clean up cache on player leave
	Players.PlayerRemoving:Connect(function(player)
		gamePassCache[player] = nil
	end)

	print("[MonetizationManager] Initialized.")
end

return MonetizationManager
