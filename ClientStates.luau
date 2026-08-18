-- Services
local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local clientStateManager = require(replicatedStorage.Modules.Client.ClientStateManager)

-- Remotes
local stateChangeRemote = replicatedStorage.Remotes.Events.StateChange

-- Variables
local player = players.LocalPlayer

local setupCharactersPassiveStateFolder = nil

-- Start
local function StateChanged(state: string, value: any)
	clientStateManager.SetState(state, value)
end

stateChangeRemote.OnClientEvent:Connect(StateChanged)

local function SetupPassiveStateFolder(child: any)
	if child.Name == "PassiveStateFolder" and setupCharactersPassiveStateFolder ~= child then
		setupCharactersPassiveStateFolder = child
		
		child.AttributeChanged:Connect(function(attribute)
			clientStateManager.SetPassiveState(attribute, child:GetAttribute(attribute))
		end)
		
		for attribute, value in child:GetAttributes() do
			clientStateManager.SetPassiveState(attribute, value)
		end
	end
end

player.PlayerGui.ChildAdded:Connect(SetupPassiveStateFolder)

for _, v in player.PlayerGui:GetChildren() do
	SetupPassiveStateFolder(v)
end
