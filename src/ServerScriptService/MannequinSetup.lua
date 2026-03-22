--[[
    MannequinSetup.lua
    Creates and manages mannequin props in the department store map.
    Run on server at startup AFTER the map is loaded.
    Location: ServerScriptService/MannequinSetup (ModuleScript)
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local Utils = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utils"))

local MannequinSetup = {}

-- ============================================================
-- MANNEQUIN CREATION
-- ============================================================

--- Create a single mannequin model at a given CFrame.
--- In a real game, this would clone a pre-made mannequin model from ServerStorage.
--- Here we create a placeholder structure.
local function createMannequin(id: string, cframe: CFrame): Model
    local model = Instance.new("Model")
    model.Name = "Mannequin_" .. id
    model:SetAttribute("MannequinId", id)

    -- Torso (main body)
    local torso = Instance.new("Part")
    torso.Name = "HumanoidRootPart"
    torso.Size = Vector3.new(2, 2, 1)
    torso.CFrame = cframe
    torso.Anchored = true
    torso.CanCollide = true
    torso.Material = Enum.Material.SmoothPlastic
    torso.Color = Color3.fromRGB(220, 200, 180)
    torso.Parent = model

    -- Head
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Shape = Enum.PartType.Ball
    head.Size = Vector3.new(1.2, 1.2, 1.2)
    head.CFrame = cframe * CFrame.new(0, 2, 0)
    head.Anchored = true
    head.CanCollide = false
    head.Material = Enum.Material.SmoothPlastic
    head.Color = Color3.fromRGB(220, 200, 180)
    head.Parent = model

    -- Left Arm
    local leftArm = Instance.new("Part")
    leftArm.Name = "LeftArm"
    leftArm.Size = Vector3.new(0.5, 2, 0.5)
    leftArm.CFrame = cframe * CFrame.new(-1.5, 0.5, 0)
    leftArm.Anchored = true
    leftArm.CanCollide = false
    leftArm.Material = Enum.Material.SmoothPlastic
    leftArm.Color = Color3.fromRGB(220, 200, 180)
    leftArm.Parent = model

    -- Right Arm
    local rightArm = Instance.new("Part")
    rightArm.Name = "RightArm"
    rightArm.Size = Vector3.new(0.5, 2, 0.5)
    rightArm.CFrame = cframe * CFrame.new(1.5, 0.5, 0)
    rightArm.Anchored = true
    rightArm.CanCollide = false
    rightArm.Material = Enum.Material.SmoothPlastic
    rightArm.Color = Color3.fromRGB(220, 200, 180)
    rightArm.Parent = model

    -- Left Leg
    local leftLeg = Instance.new("Part")
    leftLeg.Name = "LeftLeg"
    leftLeg.Size = Vector3.new(0.6, 2, 0.6)
    leftLeg.CFrame = cframe * CFrame.new(-0.5, -2, 0)
    leftLeg.Anchored = true
    leftLeg.CanCollide = false
    leftLeg.Material = Enum.Material.SmoothPlastic
    leftLeg.Color = Color3.fromRGB(220, 200, 180)
    leftLeg.Parent = model

    -- Right Leg
    local rightLeg = Instance.new("Part")
    rightLeg.Name = "RightLeg"
    rightLeg.Size = Vector3.new(0.6, 2, 0.6)
    rightLeg.CFrame = cframe * CFrame.new(0.5, -2, 0)
    rightLeg.Anchored = true
    rightLeg.CanCollide = false
    rightLeg.Material = Enum.Material.SmoothPlastic
    rightLeg.Color = Color3.fromRGB(220, 200, 180)
    rightLeg.Parent = model

    model.PrimaryPart = torso

    -- Tag for CollectionService
    CollectionService:AddTag(model, Config.Tags.Mannequin)

    return model
end

-- ============================================================
-- MAP POPULATION
-- ============================================================

--- Spawn mannequins at designated MannequinSpawn points in the map.
--- If no spawn points exist, creates mannequins at random positions.
function MannequinSetup.populateMap()
    local spawnPoints = {}

    -- Find mannequin spawn markers in the workspace
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:GetAttribute("MannequinSpawn") == true and obj:IsA("BasePart") then
            table.insert(spawnPoints, obj.CFrame)
        end
    end

    -- If no spawn markers, generate some default positions
    if #spawnPoints == 0 then
        print("[MannequinSetup] No spawn markers found. Generating default positions.")
        -- Create a grid of positions for testing
        for x = -40, 40, 15 do
            for z = -40, 40, 15 do
                table.insert(spawnPoints, CFrame.new(x, 3, z))
            end
        end
    end

    -- Shuffle and pick a random count
    Utils.shuffle(spawnPoints)
    local count = math.clamp(
        math.random(Config.Mannequins.MinCount, Config.Mannequins.MaxCount),
        1,
        #spawnPoints
    )

    -- Create mannequins
    local mannequinFolder = Instance.new("Folder")
    mannequinFolder.Name = "Mannequins"
    mannequinFolder.Parent = workspace

    for i = 1, count do
        local id = "mannequin_" .. i
        local mannequin = createMannequin(id, spawnPoints[i])
        mannequin.Parent = mannequinFolder
    end

    print(string.format("[MannequinSetup] Spawned %d mannequins.", count))
end

--- Shuffle mannequin positions (called between rounds if enabled).
function MannequinSetup.shufflePositions()
    if not Config.Mannequins.ShuffleOnRoundStart then return end

    local mannequinFolder = workspace:FindFirstChild("Mannequins")
    if not mannequinFolder then return end

    local mannequins = mannequinFolder:GetChildren()
    local positions = {}

    -- Collect current positions
    for _, m in ipairs(mannequins) do
        if m:IsA("Model") and m.PrimaryPart then
            table.insert(positions, m.PrimaryPart.CFrame)
        end
    end

    -- Shuffle positions
    Utils.shuffle(positions)

    -- Reassign positions
    for i, m in ipairs(mannequins) do
        if m:IsA("Model") and m.PrimaryPart and positions[i] then
            m:SetPrimaryPartCFrame(positions[i])
        end
    end

    print("[MannequinSetup] Mannequin positions shuffled.")
end

-- ============================================================
-- INIT
-- ============================================================

function MannequinSetup.init()
    MannequinSetup.populateMap()
    print("[MannequinSetup] Initialized.")
end

return MannequinSetup
