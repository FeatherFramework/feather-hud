-- Drives the always-on Resource Strip NUI (cash/gold/tokens/XP). Unlike the
-- old togglable popup this replaced, the NUI page is live from resource
-- start, not opened on demand -- so there's no "toggle" event to hang state
-- pushes off of. Instead:
--   1. The page calls the 'ready' NUI callback once it's mounted, and Lua
--      answers synchronously with both the validated config and the
--      current state in one round trip (see RegisterNUICallback below).
--      This sidesteps the classic NUI race where a SendNUIMessage fires
--      before the page's JS listener is attached -- a real risk here since
--      there's no user action (like opening a menu) to guarantee the page
--      has had time to load first.
--   2. After that, every economy/spawn/revive event pushes a fresh
--      SendNUIMessage the same way the old popup did.
local state = {
    cash = 0,
    gold = 0,
    tokens = 0,
    xp = 0,
    level = 1,
    xpPercent = 0,
    visible = false
}

-- Derives level/xpPercent from raw xp -- there's no `level` column/field
-- anywhere in the character schema (checked feather-recipe's migration.sql),
-- so this is the only source of truth for it.
local function applyCharacter(character)
    if not character then return end

    state.cash = tonumber(character.dollars) or 0
    state.gold = tonumber(character.gold) or 0
    state.tokens = tonumber(character.tokens) or 0

    local xp = tonumber(character.xp) or 0
    local perLevel = math.max(1, tonumber(Config.XPPerLevel) or 1900)

    state.xp = xp
    state.level = math.floor(xp / perLevel) + 1
    state.xpPercent = math.floor((xp % perLevel) / perLevel * 100)
end

local function pushState()
    SendNUIMessage({
        type = 'state',
        state = state
    })
end

-- Falls back to HudPosition.BottomRight on anything that isn't one of the
-- HudPosition.* values from config.lua -- a server owner typo shouldn't be
-- able to break the NUI's layout math.
local function validAnchors()
    local valid = {}
    for _, value in pairs(HudPosition) do
        valid[value] = true
    end
    return valid
end

local function getValidatedConfig()
    local valid = validAnchors()
    local anchor = Config.ResourceStrip.anchor

    if not valid[anchor] then
        print(("[feather-hud] Config.ResourceStrip.anchor (%s) is not a valid HudPosition value -- falling back to bottom-right"):format(tostring(anchor)))
        anchor = HudPosition.BottomRight
    end

    return {
        anchor = anchor,
        padding = tonumber(Config.ResourceStrip.padding) or 26,
        topPadding = tonumber(Config.ResourceStrip.topPadding) or 56,
        scale = tonumber(Config.ResourceStrip.scale) or 1.0,
        scrim = Config.ResourceStrip.scrim ~= false
    }
end

RegisterNUICallback('ready', function(_, cb)
    cb({
        config = getValidatedConfig(),
        state = state
    })
end)

RegisterNetEvent("Feather:Character:Spawned", function(character)
    state.visible = true
    applyCharacter(character)
    pushState()
end)

RegisterNetEvent("Feather:Character:EconomyUpdated", function(character)
    applyCharacter(character)
    pushState()
end)

RegisterNetEvent("Feather:Character:Revive", function()
    state.visible = true
    pushState()
end)

-- Feather:Character:Spawned only fires once, at the moment of spawning --
-- it never replays for a resource that (re)starts after that already
-- happened. Ask the server directly on start: a successful reply is proof
-- a character is currently active, so the strip doesn't stay stuck hidden
-- until the player's next actual spawn.
-- Note: the character-profile provider only carries identity fields (name,
-- model, appearance) -- not dollars/gold/tokens/xp, which this codebase has
-- no live source for at all today (nothing ever fires
-- Feather:Character:EconomyUpdated either). So this can only recover
-- visibility, not the economy figures; those stay at 0 until that separate,
-- pre-existing gap is addressed.
FeatherCore.RPC.Call('hud.state.get.v1', {}, function(result)
    if type(result) == 'table' and result.ok then
        state.visible = true
        pushState()
    end
end)

-- Hide the strip while the pause menu is open; edge-triggered so it only
-- pushes an NUI update on actual state changes, not every frame.
local paused, visibleBeforePause = false, false

CreateThread(function()
    while true do
        Wait(0)
        local nowPaused = IsPauseMenuActive()
        if nowPaused ~= paused then
            paused = nowPaused
            if paused then
                visibleBeforePause = state.visible
                state.visible = false
            else
                state.visible = visibleBeforePause
            end
            pushState()
        end
    end
end)
