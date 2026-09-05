# StateManager-Luau
Lightweight client-server state management system for Luau, featuring selective network replication for high-frequency data.

## Features
* **Automatic memory management:** Uses weak tables (`__mode = "k"`) to garbage collect state data when a character model is destroyed.
* **Two types of states:** 
  * **Active states:** Standard states that replicate to clients via `RemoteEvents`.
  * **Passive states:** High-frequency states (e.g., Mana, Stamina) optimised for network performance.
* **Selective replication:** Passive states utilise a `PassiveStateFolder` parented to the client's `PlayerGui`. This ensures rapidly changing attributes only replicate to the specific local player rather than replicating to all players, reducing network overhead.
* **State change signals:** Listen to specific or global state updates on both server and client.
* **Built-in expirations:** Optional `duration` parameters allow states to automatically expire and reset after a set time.

---

## Installation

1. Place the `StateManager` module script in `ServerScriptService` or `ReplicatedStorage`.
2. Place the `ClientStateManager` module script in `ReplicatedStorage` (e.g., `ReplicatedStorage.Modules.Client.ClientStateManager`).
3. Place the `ClientReplication` LocalScript into `StarterPlayer.StarterPlayerScripts`.
4. Set up a `RemoteEvent` called `StateChange`.
5. Update script require and `RemoteEvent` paths.

---

## Code Examples

### Server API
Setting and Getting States:
```luau
local StateManager = require(path.to.StateManager)

-- Set a state (e.g., Stun the character for 3 seconds)
StateManager.SetState(character, "IsStunned", true, 3)

-- Check a state
local isStunned = StateManager.GetState(character, "IsStunned")

local function onStunned(stateName)
    print("Character stun state changed!")
end
```

Listening to State Changes:
```luau
-- Connect the callback
StateManager.StateChanged(character, "IsStunned", onStunned)

-- Disconnect the callback when no longer needed
StateManager.DisconnectStateChanged(character, "IsStunned", onStunned)
```

Setting High-Frequency Passive States (Selective Replication):
```luau
-- Updates the passive state, which replicates ONLY to this specific player via PlayerGui attributes
StateManager.SetPassiveState(character, "Stamina", 75)
```

### Client API
The client automatically receives replicated states from the server. You can listen to these changes locally to do things such as update UI or trigger visual effects.

Listening to Replicated States on the Client:
```luau
local ClientStateManager = require(ReplicatedStorage.Modules.Client.ClientStateManager)

-- Listen for standard state changes
ClientStateManager.StateChanged("IsStunned", function(stateName)
    local isStunned = ClientStateManager.GetState("IsStunned")
    if isStunned then
        -- Play local stun visual effect
    end
end)

-- Listen for rapidly updating passive states (e.g., updating a stamina bar)
ClientStateManager.PassiveStateChanged("Stamina", function(stateName)
    local currentStamina = ClientStateManager.GetPassiveState("Stamina")
    print("UI Update: Stamina is now " .. tostring(currentStamina))
end)
```

## Technical Notes for Developers
### Why Attributes instead of RemoteEvents for passive states?
Using `RemoteEvents` for high-frequency updates (like a mana or stamina bar changing every tick) can quickly flood the remote queue. When the network queue is spammed, it delays other critical, time-sensitive network calls—such as combat hit-registration or important state changes. Roblox's engine optimises Attribute replication natively at the C++ level, handling rapid changes much more efficiently than Lua-invoked `RemoteEvents`.

### Why PlayerGui for Passive States?
By default, placing attributes on the Player or Character object replicates those changes to every single client in the server. For rapidly changing values like health, stamina or mana this wastes client bandwidth and clutters the network in large servers. By writing these attributes to a folder inside PlayerGui, the engine is forced to replicate the data only to the local player who owns that GUI.

Using PlayerGui attributes gives you native C++ replication only on the target players client, leaving `RemoteEvents` open for more essential packets like hit registration or input processing.
