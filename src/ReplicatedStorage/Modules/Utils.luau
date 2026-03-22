--[[
    Utils.lua
    Shared utility functions used across server and client.
]]

local Utils = {}

--- Shuffle a table in-place using Fisher-Yates algorithm.
function Utils.shuffle(tbl: { any }): { any }
	for i = #tbl, 2, -1 do
		local j = math.random(1, i)
		tbl[i], tbl[j] = tbl[j], tbl[i]
	end
	return tbl
end

--- Pick N random elements from a table (without replacement).
function Utils.pickRandom(tbl: { any }, count: number): { any }
	local copy = table.clone(tbl)
	Utils.shuffle(copy)
	local result = {}
	for i = 1, math.min(count, #copy) do
		table.insert(result, copy[i])
	end
	return result
end

--- Pick a single random element from a table.
function Utils.pickOne(tbl: { any }): any
	if #tbl == 0 then
		return nil
	end
	return tbl[math.random(1, #tbl)]
end

--- Lerp between two numbers.
function Utils.lerp(a: number, b: number, t: number): number
	return a + (b - a) * math.clamp(t, 0, 1)
end

--- Lerp between two Color3 values.
function Utils.lerpColor3(a: Color3, b: Color3, t: number): Color3
	t = math.clamp(t, 0, 1)
	return Color3.new(Utils.lerp(a.R, b.R, t), Utils.lerp(a.G, b.G, t), Utils.lerp(a.B, b.B, t))
end

--- Check if a point is within a frustum defined by origin, lookVector, fov, and maxDistance.
--- Returns true if the point is within the view cone.
function Utils.isPointInFrustum(
	origin: Vector3,
	lookVector: Vector3,
	point: Vector3,
	fovDegrees: number,
	maxDistance: number
): boolean
	local toPoint = point - origin
	local distance = toPoint.Magnitude

	if distance > maxDistance or distance < 0.1 then
		return false
	end

	local dirToPoint = toPoint.Unit
	local dotProduct = lookVector:Dot(dirToPoint)
	local angleRadians = math.acos(math.clamp(dotProduct, -1, 1))
	local halfFovRadians = math.rad(fovDegrees / 2)

	return angleRadians <= halfFovRadians
end

--- Get the level for a given amount of XP.
function Utils.getLevelFromXP(xp: number, thresholds: { number }): number
	local level = 1
	for i, threshold in ipairs(thresholds) do
		if xp >= threshold then
			level = i
		else
			break
		end
	end
	return level
end

--- Get XP needed for next level.
function Utils.xpForNextLevel(xp: number, thresholds: { number }): number?
	local currentLevel = Utils.getLevelFromXP(xp, thresholds)
	if currentLevel >= #thresholds then
		return nil -- Max level
	end
	return thresholds[currentLevel + 1] - xp
end

--- Get unlocks available at a given level.
function Utils.getUnlocksForLevel(
	level: number,
	unlocks: { { Level: number, Type: string, Name: string, Id: string } }
): { { Level: number, Type: string, Name: string, Id: string } }
	local result = {}
	for _, unlock in ipairs(unlocks) do
		if unlock.Level <= level then
			table.insert(result, unlock)
		end
	end
	return result
end

--- Format time in MM:SS.
function Utils.formatTime(seconds: number): string
	local mins = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%d:%02d", mins, secs)
end

--- Deep copy a table.
function Utils.deepCopy(original: { [any]: any }): { [any]: any }
	local copy = {}
	for key, value in pairs(original) do
		if type(value) == "table" then
			copy[key] = Utils.deepCopy(value)
		else
			copy[key] = value
		end
	end
	return copy
end

--- Create a debounce wrapper for a function.
function Utils.debounce(func: (...any) -> (), cooldown: number): (...any) -> ()
	local lastCall = 0
	return function(...)
		local now = tick()
		if now - lastCall >= cooldown then
			lastCall = now
			func(...)
		end
	end
end

--- Safely get a player's character and humanoid.
function Utils.getCharacterAndHumanoid(player: Player): (Model?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return character, humanoid
end

--- Safely get the HumanoidRootPart position of a player.
function Utils.getPlayerPosition(player: Player): Vector3?
	local character = player.Character
	if not character then
		return nil
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return nil
	end
	return rootPart.Position
end

return Utils
