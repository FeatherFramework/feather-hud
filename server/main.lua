-- Lets the client ask "do I currently have an active character?" on resource
-- start. Without this, a feather-hud restart mid-session has no way to catch
-- up: Feather:Character:Spawned only fires once, at the moment of spawning,
-- so a fresh Lua VM waiting on that event alone would stay hidden/stale
-- until the player actually respawns. `requireCharacter = true` below makes
-- Core's RPC layer itself reject the call with `character_required` before
-- our handler ever runs when there's no active session -- so simply being
-- allowed to answer is already the proof; no character data needs reading.
local installed = false

CreateThread(function()
    local ready = exports['feather-core']:AwaitReady(30000)
    if type(ready) ~= 'table' or not ready.ok or installed then return end
    installed = true

    exports['feather-core']:RegisterRpc('hud.state.get.v1', function()
        return { ok = true, value = true }
    end, {
        contract = 1,
        direction = 'client_to_server',
        requireCharacter = true,
        windowMs = 5000,
        maxCalls = 5,
        maxPayloadBytes = 64,
        maxDepth = 1,
        maxNodes = 1,
        validatePayload = function(payload) return type(payload) == 'table' and next(payload) == nil end
    })
end)
