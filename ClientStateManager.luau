local module = {}

-- Variables
local states = {}
local stateChangeCounter = {}
local stateChangeConnections = {}
local anyStateChangeConnections = {}

local passiveStates = {}
local passiveStateChangeCounter = {}
local passiveStateChangeConnections = {}

-- Start
-- Trigger all state change callbacks for a specific state
local function TriggerStateChanged(state: string)
	-- Trigger callback functions for any state changing
	for _, callback in anyStateChangeConnections do
		task.spawn(callback, state)
	end

	-- Trigger callback functions for the specific state
	if stateChangeConnections[state] then
		for _, callback in stateChangeConnections[state] do
			task.spawn(callback)
		end
	end
end

-- Set state
function module.SetState(state: string, value: any, duration: number)
	local previousValue = states[state]

	states[state] = value

	-- Increment the change counter for this specific state
	local newChangedCount = (stateChangeCounter[state] or 0) + 1
	stateChangeCounter[state] = newChangedCount

	if previousValue ~= value then
		TriggerStateChanged(state)
	end

	if duration then
		task.delay(duration, function()
			-- Only clear if the state hasn't been changed again since this delay started
			if stateChangeCounter[state] == newChangedCount then
				states[state] = nil
				TriggerStateChanged(state)
			end
		end)
	end
end

-- Get state
function module.GetState(state: string)
	return states[state]
end

-- Add a callback function that triggers when specific state changes
function module.StateChanged(state: string, callback: (any) -> ())
	if not stateChangeConnections[state] then
		stateChangeConnections[state] = {}
	end

	-- Insert the callback into connections table
	table.insert(stateChangeConnections[state], callback)
end

-- Add a callback function that triggers when any state changes
function module.AnyStateChanged(callback: (any) -> ())
	-- Insert the callback into connections table
	table.insert(anyStateChangeConnections, callback)
end

-- Trigger all state change callbacks for a specific passive state
local function TriggerPassiveStateChanged(state: string)
	-- Trigger callback functions for the specific state
	if passiveStateChangeConnections[state] then
		for _, callback in passiveStateChangeConnections[state] do
			task.spawn(callback)
		end
	end
end

-- Set passive state
function module.SetPassiveState(state: string, value: any, duration: number)
	local previousValue = passiveStates[state]

	passiveStates[state] = value

	-- Increment the change counter for this specific passive state
	local newChangedCount = (passiveStateChangeCounter[state] or 0) + 1
	passiveStateChangeCounter[state] = newChangedCount

	if previousValue ~= value then
		TriggerPassiveStateChanged(state)
	end

	if duration then
		task.delay(duration, function()
			-- Only clear if the state hasn't been changed again since this delay started
			if passiveStateChangeCounter[state] == newChangedCount then
				passiveStates[state] = nil
				TriggerPassiveStateChanged(state)
			end
		end)
	end
end

-- Get passive state
function module.GetPassiveState(state: string)
	return passiveStates[state]
end

-- Add a callback function that triggers when specific passive state changes
function module.PassiveStateChanged(state: string, callback: (any) -> ())
	if not passiveStateChangeConnections[state] then
		passiveStateChangeConnections[state] = {}
	end

	-- Insert the callback into connections table
	table.insert(passiveStateChangeConnections[state], callback)
end

-- Clear all tables
function module.ClearStates()
	states = {}
	stateChangeCounter = {}
	stateChangeConnections = {}
	anyStateChangeConnections = {}

	passiveStates = {}
	passiveStateChangeCounter = {}
	passiveStateChangeConnections = {}
end

function module.ResetAllStateValues()
	-- Loop through active states and set them to nil properly
	-- This wipes the value AND notifies the controllers without deleting their connections
	for stateName, _ in pairs(states) do
		module.SetState(stateName, nil)
	end

	for stateName, _ in pairs(passiveStates) do
		module.SetPassiveState(stateName, nil)
	end
end

return module
