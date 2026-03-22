--[[
    ProximityPromptSetup.lua
    Sets up ProximityPrompts on all interactive objects in the map.
    This is the modern Roblox way to handle "press E to interact."
    Location: ServerScriptService/ProximityPromptSetup (ModuleScript)
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RemoteSetup"))

local ProximityPromptSetup = {}

-- Forward-declare
local GameManager
local TaskManager

-- ============================================================
-- PROMPT CONFIGURATIONS
-- ============================================================

local PROMPT_CONFIGS = {
    -- Shopping task: Find Item / Restock Shelf
    ShelfInteract = {
        ActionText = "Pick Up Item",
        ObjectText = "Shelf",
        HoldDuration = 0,
        MaxActivationDistance = 8,
        KeyboardKeyCode = Enum.KeyCode.E,
        GamepadKeyCode = Enum.KeyCode.ButtonX,
        RequiresLineOfSight = true,
        Icon = "rbxassetid://7733960981", -- Hand icon
    },

    -- Checkout Register
    Register = {
        ActionText = "Checkout",
        ObjectText = "Register",
        HoldDuration = 3,
        MaxActivationDistance = 6,
        KeyboardKeyCode = Enum.KeyCode.E,
        GamepadKeyCode = Enum.KeyCode.ButtonX,
        RequiresLineOfSight = true,
        Icon = "rbxassetid://7733960981",
    },

    -- Fuse Box (Fix Lights task)
    FuseBox = {
        ActionText = "Fix Fuse Box",
        ObjectText = "Fuse Box",
        HoldDuration = 5,
        MaxActivationDistance = 6,
        KeyboardKeyCode = Enum.KeyCode.E,
        GamepadKeyCode = Enum.KeyCode.ButtonX,
        RequiresLineOfSight = true,
        Icon = "rbxassetid://7743871902", -- Lightning icon
    },

    -- Spill Zone (Clean Spill task)
    SpillZone = {
        ActionText = "Clean Spill",
        ObjectText = "Wet Floor",
        HoldDuration = 5,
        MaxActivationDistance = 8,
        KeyboardKeyCode = Enum.KeyCode.E,
        GamepadKeyCode = Enum.KeyCode.ButtonX,
        RequiresLineOfSight = false,
        Icon = "rbxassetid://7733960981",
    },

    -- Mannequin (Inspect)
    Mannequin = {
        ActionText = "Inspect",
        ObjectText = "Mannequin",
        HoldDuration = 2,
        MaxActivationDistance = 12,
        KeyboardKeyCode = Enum.KeyCode.E,
        GamepadKeyCode = Enum.KeyCode.ButtonX,
        RequiresLineOfSight = true,
        Icon = "rbxassetid://7743871902",
    },

    -- Exit Door
    ExitDoor = {
        ActionText = "Escape",
        ObjectText = "Exit",
        HoldDuration = 0,
        MaxActivationDistance = 10,
        KeyboardKeyCode = Enum.KeyCode.E,
        GamepadKeyCode = Enum.KeyCode.ButtonX,
        RequiresLineOfSight = false,
        Enabled = false, -- Disabled until all tasks complete
        Icon = "rbxassetid://7743871902",
    },

    -- Security Camera (Shopkeeper)
    SecurityCamera = {
        ActionText = "View Camera",
        ObjectText = "Security Camera",
        HoldDuration = 0,
        MaxActivationDistance = 8,
        KeyboardKeyCode = Enum.KeyCode.E,
        GamepadKeyCode = Enum.KeyCode.ButtonX,
        RequiresLineOfSight = true,
        Icon = "rbxassetid://7743871902",
    },
}

-- Track created prompts
local createdPrompts: {ProximityPrompt} = {}

-- Cooldown tracking per player per tag
local playerCooldowns: {[Player]: {[string]: number}} = {}

-- ============================================================
-- PROMPT CREATION
-- ============================================================

--- Create a ProximityPrompt on a tagged object.
local function createPromptOnObject(object: BasePart, tag: string)
    -- Don't create duplicate prompts
    if object:FindFirstChildOfClass("ProximityPrompt") then return end

    local config = PROMPT_CONFIGS[tag]
    if not config then return end

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = config.ActionText
    prompt.ObjectText = config.ObjectText
    prompt.HoldDuration = config.HoldDuration
    prompt.MaxActivationDistance = config.MaxActivationDistance
    prompt.KeyboardKeyCode = config.KeyboardKeyCode
    prompt.GamepadKeyCode = config.GamepadKeyCode
    prompt.RequiresLineOfSight = config.RequiresLineOfSight
    prompt.Enabled = config.Enabled ~= false
    prompt.Style = Enum.ProximityPromptStyle.Default
    prompt.UIOffset = Vector2.new(0, -40)
    prompt:SetAttribute("PromptTag", tag)
    prompt.Parent = object

    table.insert(createdPrompts, prompt)

    -- Connect trigger handler
    prompt.Triggered:Connect(function(playerWhoTriggered: Player)
        handlePromptTriggered(playerWhoTriggered, object, tag, prompt)
    end)
end

--- Create prompts on all tagged objects for a given tag.
local function setupPromptsForTag(tag: string)
    for _, object in ipairs(CollectionService:GetTagged(tag)) do
        if object:IsA("BasePart") then
            createPromptOnObject(object, tag)
        elseif object:IsA("Model") then
            -- For models, attach to PrimaryPart or first BasePart
            local part = object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart")
            if part then
                createPromptOnObject(part, tag)
            end
        end
    end

    -- Listen for new tagged objects (in case map loads dynamically)
    CollectionService:GetInstanceAddedSignal(tag):Connect(function(object)
        if object:IsA("BasePart") then
            createPromptOnObject(object, tag)
        elseif object:IsA("Model") then
            local part = object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart")
            if part then
                createPromptOnObject(part, tag)
            end
        end
    end)
end

-- ============================================================
-- PROMPT TRIGGER HANDLING
-- ============================================================

function handlePromptTriggered(player: Player, object: BasePart, tag: string, prompt: ProximityPrompt)
    -- Validate player is alive and in a round
    if not GameManager then return end
    if GameManager.getCurrentState() ~= "Playing" then return end

    local role = nil
    if player == GameManager.getMonsterPlayer() then
        role = "Monster"
    elseif player == GameManager.getShopkeeperPlayer() then
        role = "Shopkeeper"
    elseif GameManager.isPlayerAlive(player) then
        role = "Shopper"
    else
        return -- Dead/spectating players can't interact
    end

    -- Per-player cooldown check
    if not playerCooldowns[player] then
        playerCooldowns[player] = {}
    end
    local lastUse = playerCooldowns[player][tag] or 0
    local cooldown = 1 -- 1 second minimum between same-tag interactions
    if tag == Config.Tags.Mannequin then
        cooldown = Config.Shopper.InspectCooldown
    end
    if tick() - lastUse < cooldown then
        return
    end
    playerCooldowns[player][tag] = tick()

    -- Handle based on tag
    if tag == Config.Tags.ShelfInteract then
        handleShelfInteract(player, object)

    elseif tag == Config.Tags.Register then
        handleRegisterInteract(player, object)

    elseif tag == Config.Tags.FuseBox then
        handleFuseBoxInteract(player, object)

    elseif tag == Config.Tags.SpillZone then
        handleSpillInteract(player, object)

    elseif tag == Config.Tags.Mannequin then
        if role ~= "Monster" then
            handleMannequinInspect(player, object)
        end

    elseif tag == Config.Tags.ExitDoor then
        handleExitDoor(player, object)

    elseif tag == Config.Tags.SecurityCamera then
        if role == "Shopkeeper" then
            handleSecurityCamera(player, object)
        end
    end
end

-- ============================================================
-- INTERACTION HANDLERS
-- ============================================================

local function handleShelfInteract(player: Player, object: BasePart)
    -- Find matching task for this player
    if not TaskManager then return end
    local tasks = TaskManager.getPlayerTasks(player)
    if not tasks then return end

    for taskId, taskData in pairs(tasks) do
        if not taskData.completed and (taskData.taskType == "FindItem" or taskData.taskType == "RestockShelf") then
            -- Check if this is the right location
            if taskData.location and (object.Position - taskData.location.Position).Magnitude < 15 then
                Remotes.fireServer("TaskCompleted", {taskId = taskId})
                break
            end
        end
    end

    -- For server: directly complete if valid
    Remotes.fireAllClients("ShowNotification", {
        text = player.Name .. " picked up an item.",
        duration = 1,
        type = "info",
    })
end

local function handleRegisterInteract(player: Player, object: BasePart)
    if not TaskManager then return end
    local tasks = TaskManager.getPlayerTasks(player)
    if not tasks then return end

    for taskId, taskData in pairs(tasks) do
        if not taskData.completed and taskData.taskType == "Checkout" then
            -- Server-side task completion
            -- The ProximityPrompt's HoldDuration already provides the 3-second hold
            Remotes.fireClient("TaskCompleted", player, {taskId = taskId})
            break
        end
    end
end

local function handleFuseBoxInteract(player: Player, object: BasePart)
    if not TaskManager then return end
    local tasks = TaskManager.getPlayerTasks(player)
    if not tasks then return end

    for taskId, taskData in pairs(tasks) do
        if not taskData.completed and taskData.taskType == "FixLights" then
            Remotes.fireClient("TaskCompleted", player, {taskId = taskId})

            -- Re-enable nearby lights
            for _, light in ipairs(CollectionService:GetTagged(Config.Tags.LightFixture)) do
                if light:IsA("PointLight") or light:IsA("SpotLight") then
                    if light.Parent and (light.Parent.Position - object.Position).Magnitude < 40 then
                        light.Enabled = true
                    end
                end
            end
            break
        end
    end
end

local function handleSpillInteract(player: Player, object: BasePart)
    if not TaskManager then return end
    local tasks = TaskManager.getPlayerTasks(player)
    if not tasks then return end

    for taskId, taskData in pairs(tasks) do
        if not taskData.completed and taskData.taskType == "CleanSpill" then
            Remotes.fireClient("TaskCompleted", player, {taskId = taskId})

            -- Visual: remove the spill decal
            local decal = object:FindFirstChildOfClass("Decal") or object:FindFirstChildOfClass("Texture")
            if decal then
                decal.Transparency = 1
            end
            break
        end
    end
end

local function handleMannequinInspect(player: Player, object: BasePart)
    local mannequinId = object:GetAttribute("MannequinId")
        or (object.Parent and object.Parent:GetAttribute("MannequinId"))
    if not mannequinId then return end

    Remotes.fireServer("InspectMannequin", {mannequinId = mannequinId})
end

local function handleExitDoor(player: Player, object: BasePart)
    -- Only works if exit doors are open (tasks complete)
    if not object.CanCollide == false then return end -- Door must be unlocked

    -- Notify server that this player escaped
    if TaskManager and TaskManager.hasPlayerCompleted(player) then
        Remotes.fireClient("ShowNotification", player, {
            text = "You escaped the store!",
            duration = 3,
            type = "success",
        })
        -- Check if all completed players have escaped
        GameManager.onShoppersEscaped()
    end
end

local function handleSecurityCamera(player: Player, object: BasePart)
    -- Send camera feed info to shopkeeper client
    local cameraId = object:GetAttribute("CameraId") or object.Name
    Remotes.fireClient("ShowNotification", player, {
        text = "Viewing camera: " .. cameraId,
        duration = 2,
        type = "info",
    })
    -- The actual camera view switching is handled client-side
end

-- ============================================================
-- EXIT DOOR MANAGEMENT
-- ============================================================

--- Enable exit door prompts when all tasks are complete.
function ProximityPromptSetup.enableExitDoors()
    for _, object in ipairs(CollectionService:GetTagged(Config.Tags.ExitDoor)) do
        local prompt = object:FindFirstChildOfClass("ProximityPrompt")
            or (object:IsA("Model") and object.PrimaryPart and object.PrimaryPart:FindFirstChildOfClass("ProximityPrompt"))
        if prompt then
            prompt.Enabled = true
        end
    end
end

--- Disable exit door prompts (reset between rounds).
function ProximityPromptSetup.disableExitDoors()
    for _, object in ipairs(CollectionService:GetTagged(Config.Tags.ExitDoor)) do
        local prompt = object:FindFirstChildOfClass("ProximityPrompt")
        if prompt then
            prompt.Enabled = false
        end
    end
end

-- ============================================================
-- CLEANUP
-- ============================================================

function ProximityPromptSetup.reset()
    playerCooldowns = {}
    ProximityPromptSetup.disableExitDoors()
end

-- ============================================================
-- INIT
-- ============================================================

function ProximityPromptSetup.init(services: {[string]: any})
    GameManager = services.GameManager
    TaskManager = services.TaskManager

    -- Setup prompts for all tag types
    for tag, _ in pairs(PROMPT_CONFIGS) do
        setupPromptsForTag(tag)
    end

    -- Clean up cooldowns when players leave
    Players.PlayerRemoving:Connect(function(player)
        playerCooldowns[player] = nil
    end)

    -- Listen for exit doors opening
    Remotes.getEvent("ExitDoorsOpened").Event:Connect(function()
        ProximityPromptSetup.enableExitDoors()
    end)

    print("[ProximityPromptSetup] Initialized. Prompts created for all tagged objects.")
end

return ProximityPromptSetup
