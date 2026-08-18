local module = {}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Variables
-- Using weak tables (__mode = "k") so that when a character model is destroyed,
-- all associated state data is automatically garbage collected to prevent memory leaks.
local weakKeyMeta = { __mode = "k" }

local States = setmetatable({}, weakKeyMeta)
local StateChangeCounter = setmetatable({}, weakKeyMeta)
local StateChangeConnections = setmetatable({}, weakKeyMeta)
local AnyStateChangeConnections = setmetatable({}, weakKeyMeta)

local passiveStates = setmetatable({}, weakKeyMeta)
local passiveStateChangeCounter = setmetatable({}, weakKeyMeta)
local PassiveStateChangeConnections = setmetatable({}, weakKeyMeta)

local StateChangeRemote = ReplicatedStorage.Remotes.Events.StateChange

-- Functions
-- Check if a character is valid
local function IsValidCharacter(character: Model)
	return character and character.Parent
end

-- Trigger all state change callbacks for a characters state
local function TriggerStateChanged(character: Model, state: string)
	-- Trigger callback functions for any state changing
	if AnyStateChangeConnections[character] then
		for _, callback in AnyStateChangeConnections[character] do
			task.spawn(callback, state)
		end
	end

	-- Trigger callback functions for the specific state
	if StateChangeConnections[character] and StateChangeConnections[character][state] then
		for _, callback in StateChangeConnections[character][state] do
			task.spawn(callback, state)
		end
	end
end

-- Trigger callbacks for a specific passive state
local function TriggerPassiveStateChanged(character: Model, state: string)
	if PassiveStateChangeConnections[character] and PassiveStateChangeConnections[character][state] then
		for _, callback in PassiveStateChangeConnections[character][state] do
			task.spawn(callback, state)
		end
	end
end

-- Change a characters state
function module.SetState(character: Model, state: string, value: any, duration: number)
	-- Ensure character is valid
	if not IsValidCharacter(character) then return end

	-- Changing characters state
	if not States[character] then States[character] = {} end

	local previousValue = States[character][state]
	States[character][state] = value

	-- Changing characters state changed counter
	if not StateChangeCounter[character] then StateChangeCounter[character] = {} end
	local newChangedCount = (StateChangeCounter[character][state] or 0) + 1
	StateChangeCounter[character][state] = newChangedCount

	-- Trigger state changed
	if previousValue ~= value then TriggerStateChanged(character, state) end

	-- Replicate the state to players client
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		StateChangeRemote:FireClient(player, state, value)
	end

	-- After a specified duration set state to nil
	if duration then
		task.delay(duration, function()
			if not IsValidCharacter(character) then return end
			if StateChangeCounter[character] and StateChangeCounter[character][state] == newChangedCount then
				States[character][state] = nil
				TriggerStateChanged(character, state)
				if player then StateChangeRemote:FireClient(player, state) end
			end
		end)
	end
end

-- Get the value of a characters state
function module.GetState(character: Model, state: string)
	-- Ensure character is valid
	if not IsValidCharacter(character) then return end

	if not States[character] then return end

	return States[character][state]
end

-- Get all states of a character
function module.GetStates(character: Model)
	-- Ensure character is valid
	if not IsValidCharacter(character) then return end

	-- Return a clone of the characters states table for safety
	return States[character] and table.clone(States[character])
end

-- Clear all data for a character (Useful for manual resets while the character still exists)
function module.ClearStates(character: Model)
	if not character then return end

	States[character] = nil
	StateChangeCounter[character] = nil
	StateChangeConnections[character] = nil
	AnyStateChangeConnections[character] = nil

	passiveStates[character] = nil
	passiveStateChangeCounter[character] = nil
	PassiveStateChangeConnections[character] = nil
end

-- Trigger a callback function when a characters specific state is changed
function module.StateChanged(character: Model, state: string, callback: (any) -> ())
	-- Ensure character is valid
	if not IsValidCharacter(character) then return end

	if not StateChangeConnections[character] then
		StateChangeConnections[character] = {}
	end

	if not StateChangeConnections[character][state] then
		StateChangeConnections[character][state] = {}
	end

	-- Insert the callback into connections table
	table.insert(StateChangeConnections[character][state], callback)

	return callback
end

-- Trigger a callback function when a character has any state changed
function module.AnyStateChanged(character: Model, callback: (any) -> ())
	-- Ensure character is valid
	if not IsValidCharacter(character) then return end

	if not AnyStateChangeConnections[character] then
		AnyStateChangeConnections[character] = {}
	end

	-- Insert the callback into connections table
	table.insert(AnyStateChangeConnections[character], callback)

	return callback
end

-- Disconnect a specific callback function from a characters state
function module.DisconnectStateChanged(character: Model, state: string, callback: (any) -> ())
	if not IsValidCharacter(character) then return end

	if not StateChangeConnections[character] or not StateChangeConnections[character][state] then return end

	for i, storedCallback in StateChangeConnections[character][state] do
		if storedCallback == callback then
			table.remove(StateChangeConnections[character][state], i)
			break
		end
	end
end

-- Disconnect an any state changed callback function for a character
function module.DisconnectAnyStateChanged(character: Model, callback: (any) -> ())
	if not IsValidCharacter(character) then return end

	if not AnyStateChangeConnections[character] then return end

	for i, storedCallback in AnyStateChangeConnections[character] do
		if storedCallback == callback then
			table.remove(AnyStateChangeConnections[character], i)
			break
		end
	end
end

-- Set a passive state
function module.SetPassiveState(character: Model, state: string, value: any, duration: number)
	if not IsValidCharacter(character) then return end

	if not passiveStates[character] then passiveStates[character] = {} end

	-- Store previous value to check if it actually changed
	local previousValue = passiveStates[character][state]
	passiveStates[character][state] = value

	if not passiveStateChangeCounter[character] then passiveStateChangeCounter[character] = {} end
	local newChangedCount = (passiveStateChangeCounter[character][state] or 0) + 1
	passiveStateChangeCounter[character][state] = newChangedCount

	-- Trigger passive state changed if the value is different
	if previousValue ~= value then 
		TriggerPassiveStateChanged(character, state) 
	end

	-- Replicate to client
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		local playerGui = player:FindFirstChild("PlayerGui")
		if playerGui then
			local folder = playerGui:FindFirstChild("PassiveStateFolder")
			if not folder then
				-- Yields briefly if we caught the player mid-respawn
				folder = playerGui:WaitForChild("PassiveStateFolder", 3)
			end
			if folder then
				folder:SetAttribute(state, value)
			end
		end
	end

	-- After a specified duration set state to nil
	if duration then
		task.delay(duration, function()
			if not IsValidCharacter(character) then return end
			if passiveStateChangeCounter[character] and passiveStateChangeCounter[character][state] == newChangedCount then
				passiveStates[character][state] = nil

				-- Trigger callback when duration expires
				TriggerPassiveStateChanged(character, state)

				if player then
					local folder = player.PlayerGui:FindFirstChild("PassiveStateFolder")
					if folder then folder:SetAttribute(state, nil) end
				end
			end
		end)
	end
end

-- Get the value of a passive state
function module.GetPassiveState(character: Model, state: string)
	if not IsValidCharacter(character) then return end

	if not passiveStates[character] then return end

	return passiveStates[character][state]
end

-- Trigger a callback function when a characters specific passive state is changed
function module.PassiveStateChanged(character: Model, state: string, callback: (any) -> ())
	if not IsValidCharacter(character) then return end

	if not PassiveStateChangeConnections[character] then
		PassiveStateChangeConnections[character] = {}
	end

	if not PassiveStateChangeConnections[character][state] then
		PassiveStateChangeConnections[character][state] = {}
	end

	table.insert(PassiveStateChangeConnections[character][state], callback)

	return callback
end

-- Disconnect a specific callback function from a characters passive state
function module.DisconnectPassiveStateChanged(character: Model, state: string, callback: (any) -> ())
	if not IsValidCharacter(character) then return end

	if not PassiveStateChangeConnections[character] or not PassiveStateChangeConnections[character][state] then return end

	for i, storedCallback in PassiveStateChangeConnections[character][state] do
		if storedCallback == callback then
			table.remove(PassiveStateChangeConnections[character][state], i)
			break
		end
	end
end

return module
