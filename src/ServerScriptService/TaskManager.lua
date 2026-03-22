--[[
    TaskManager.lua
    Manages shopping tasks for shoppers — assignment, tracking, completion.
    When all shoppers complete their tasks, exit doors open.
    Location: ServerScriptService/TaskManager
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local Utils = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utils"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RemoteSetup"))

local TaskManager = {}

-- Forward-declare
local GameManager
local DataManager
local MonetizationManager

-- ============================================================
-- STATE
-- ============================================================

-- {[Player]: {taskId: string, type: string, location: BasePart, completed: boolean}[]}
local playerTasks: {[Player]: {[string]: {
    taskId: string,
    taskType: string,
    displayName: string,
    description: string,
    location: BasePart?,
    completed: boolean,
}}} = {}

local playersCompleted: {[Player]: boolean} = {}
local allTasksComplete = false
local exitDoorsOpen = false

-- ============================================================
-- TASK LOCATION MANAGEMENT
-- ============================================================

--- Get all available task locations from the workspace (tagged with CollectionService).
local function getTaskLocations(): {BasePart}
    local locations = {}
    for _, tag in ipairs({
        Config.Tags.ShelfInteract,
        Config.Tags.Register,
        Config.Tags.FuseBox,
        Config.Tags.SpillZone,
    }) do
        for _, obj in ipairs(CollectionService:GetTagged(tag)) do
            if obj:IsA("BasePart") then
                table.insert(locations, obj)
            end
        end
    end
    return locations
end

--- Map task types to their corresponding workspace tags.
local function getTagForTaskType(taskType: string): string
    local mapping = {
        FindItem = Config.Tags.ShelfInteract,
        Checkout = Config.Tags.Register,
        RestockShelf = Config.Tags.ShelfInteract,
        FixLights = Config.Tags.FuseBox,
        CleanSpill = Config.Tags.SpillZone,
    }
    return mapping[taskType] or Config.Tags.ShelfInteract
end

--- Find a random location for a specific task type.
local function findLocationForTask(taskType: string): BasePart?
    local tag = getTagForTaskType(taskType)
    local tagged = CollectionService:GetTagged(tag)
    local parts = {}
    for _, obj in ipairs(tagged) do
        if obj:IsA("BasePart") then
            table.insert(parts, obj)
        end
    end
    return Utils.pickOne(parts)
end

-- ============================================================
-- TASK ASSIGNMENT
-- ============================================================

--- Assign random tasks to a player.
function TaskManager.assignTasks(player: Player)
    local taskTypes = Config.Tasks.Types
    local count = Config.Tasks.TasksPerPlayer

    -- Pick random task types (with possible repeats if fewer types than count)
    local assigned = {}
    local shuffledTypes = Utils.shuffle(table.clone(taskTypes))

    for i = 1, count do
        local taskDef = shuffledTypes[((i - 1) % #shuffledTypes) + 1]
        local taskId = player.UserId .. "_" .. i .. "_" .. taskDef.Name
        local location = findLocationForTask(taskDef.Name)

        assigned[taskId] = {
            taskId = taskId,
            taskType = taskDef.Name,
            displayName = taskDef.DisplayName,
            description = taskDef.Description,
            location = location,
            completed = false,
        }
    end

    playerTasks[player] = assigned
    playersCompleted[player] = false

    -- Send task list to client
    local clientTasks = {}
    for id, taskData in pairs(assigned) do
        table.insert(clientTasks, {
            taskId = id,
            taskType = taskData.taskType,
            displayName = taskData.displayName,
            description = taskData.description,
            locationPosition = taskData.location and taskData.location.Position or nil,
            completed = false,
        })
    end

    Remotes.fireClient("TaskAssigned", player, {tasks = clientTasks})
end

-- ============================================================
-- TASK COMPLETION
-- ============================================================

--- Called when a client reports completing a task.
local function onTaskCompleted(player: Player, data: {taskId: string})
    if typeof(data) ~= "table" then return end
    local taskId = data.taskId
    if typeof(taskId) ~= "string" then return end

    -- Validate
    local tasks = playerTasks[player]
    if not tasks then return end

    local taskData = tasks[taskId]
    if not taskData then return end
    if taskData.completed then return end

    -- Validate proximity to task location
    if taskData.location then
        local playerPos = Utils.getPlayerPosition(player)
        if playerPos then
            local dist = (playerPos - taskData.location.Position).Magnitude
            if dist > 20 then
                -- Too far from task location — reject
                return
            end
        end
    end

    -- Mark as completed
    taskData.completed = true

    -- Award XP
    if DataManager then
        local xp = Config.XP.TaskComplete
        if MonetizationManager and MonetizationManager.hasGamePass(player, "VIP") then
            xp = xp * Config.XP.VIPMultiplier
        end
        DataManager.addXP(player, xp, "Completed task: " .. taskData.displayName)
    end

    -- Notify client
    Remotes.fireClient("TaskProgressUpdate", player, {
        taskId = taskId,
        completed = true,
    })

    Remotes.fireClient("ShowNotification", player, {
        text = "Task complete: " .. taskData.displayName,
        duration = 2,
        type = "success",
    })

    -- Check if all of this player's tasks are done
    local allDone = true
    for _, t in pairs(tasks) do
        if not t.completed then
            allDone = false
            break
        end
    end

    if allDone then
        playersCompleted[player] = true
        Remotes.fireClient("AllTasksComplete", player)
        Remotes.fireClient("ShowNotification", player, {
            text = "All tasks complete! Head to the exit!",
            duration = 5,
            type = "success",
        })

        -- Check if ALL shoppers have completed their tasks
        checkAllPlayersComplete()
    end
end

--- Check if every alive shopper has finished their tasks.
local function checkAllPlayersComplete()
    if exitDoorsOpen then return end

    local alivePlayers = GameManager and GameManager.getAlivePlayers() or {}
    local shopkeeper = GameManager and GameManager.getShopkeeperPlayer()

    local allComplete = true
    for _, player in ipairs(alivePlayers) do
        if player == shopkeeper then continue end
        if not playersCompleted[player] then
            allComplete = false
            break
        end
    end

    if allComplete and #alivePlayers > 0 then
        openExitDoors()
    end
end

function checkAllPlayersComplete()
    if exitDoorsOpen then return end

    local alivePlayers = GameManager and GameManager.getAlivePlayers() or {}
    local shopkeeper = GameManager and GameManager.getShopkeeperPlayer()

    local allComplete = true
    for _, player in ipairs(alivePlayers) do
        if player == shopkeeper then continue end
        if not playersCompleted[player] then
            allComplete = false
            break
        end
    end

    if allComplete and #alivePlayers > 0 then
        openExitDoors()
    end
end

-- ============================================================
-- EXIT DOORS
-- ============================================================

local function openExitDoors()
    exitDoorsOpen = true

    -- Open all exit doors in the map
    for _, door in ipairs(CollectionService:GetTagged(Config.Tags.ExitDoor)) do
        if door:IsA("BasePart") then
            door.CanCollide = false
            door.Transparency = 0.5
            -- Could also tween the door open
        end
    end

    Remotes.fireAllClients("ExitDoorsOpened")
    Remotes.fireAllClients("ShowNotification", {
        text = "The exit doors are now OPEN! Escape!",
        duration = 5,
        type = "success",
    })

    print("[TaskManager] Exit doors opened!")
end

-- ============================================================
-- SKIP TASK (Developer Product)
-- ============================================================

function TaskManager.skipTask(player: Player): boolean
    local tasks = playerTasks[player]
    if not tasks then return false end

    -- Find first incomplete task
    for taskId, taskData in pairs(tasks) do
        if not taskData.completed then
            taskData.completed = true

            Remotes.fireClient("TaskProgressUpdate", player, {
                taskId = taskId,
                completed = true,
            })

            Remotes.fireClient("ShowNotification", player, {
                text = "Task skipped: " .. taskData.displayName,
                duration = 2,
                type = "info",
            })

            -- Check if all done now
            local allDone = true
            for _, t in pairs(tasks) do
                if not t.completed then
                    allDone = false
                    break
                end
            end

            if allDone then
                playersCompleted[player] = true
                Remotes.fireClient("AllTasksComplete", player)
                checkAllPlayersComplete()
            end

            return true
        end
    end

    return false
end

-- ============================================================
-- RESET
-- ============================================================

function TaskManager.reset()
    playerTasks = {}
    playersCompleted = {}
    allTasksComplete = false
    exitDoorsOpen = false

    -- Re-close exit doors
    for _, door in ipairs(CollectionService:GetTagged(Config.Tags.ExitDoor)) do
        if door:IsA("BasePart") then
            door.CanCollide = true
            door.Transparency = 0
        end
    end
end

-- ============================================================
-- QUERY
-- ============================================================

function TaskManager.getPlayerTasks(player: Player): {[string]: any}?
    return playerTasks[player]
end

function TaskManager.hasPlayerCompleted(player: Player): boolean
    return playersCompleted[player] == true
end

-- ============================================================
-- INIT
-- ============================================================

function TaskManager.init(services: {[string]: any})
    GameManager = services.GameManager
    DataManager = services.DataManager
    MonetizationManager = services.MonetizationManager

    -- Listen for task completion from clients
    local taskEvent = Remotes.getEvent("TaskCompleted")
    taskEvent.OnServerEvent:Connect(onTaskCompleted)

    -- Clean up on player removal
    Players.PlayerRemoving:Connect(function(player)
        playerTasks[player] = nil
        playersCompleted[player] = nil
    end)

    print("[TaskManager] Initialized.")
end

return TaskManager
