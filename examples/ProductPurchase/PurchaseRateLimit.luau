--!strict
local EventBroker = require(game.ServerStorage.EventBroker)

-- configuration
local LimitWindowSeconds = 1
local RequestsPerWindow = 1

-- rate limit logic

local limit: {[number]: {Count: number, WindowStart: number}} = {}

game.Players.PlayerRemoving:Connect(function(pPlayer: Player)
	-- Cleaning up when a player leaves to prevent memory leaks
	limit[pPlayer.UserId] = nil
end)

--[[
    Any middleware returns a boolean.
    True means continue processing the event.
    False means block further processing.

    When blocking, the middleware automatically
    add a log stating the event was blocked by middleware.
]]
return function(pPlayer: Player, pLogId: number, ...): boolean
	limit[pPlayer.UserId] = limit[pPlayer.UserId] or {Count=0, WindowStart=tick()}
	
	local now = tick()
	
	if (limit[pPlayer.UserId].WindowStart + LimitWindowSeconds < now) then
		limit[pPlayer.UserId] = {
			Count = 0,
			WindowStart = now
		}
	end

	limit[pPlayer.UserId].Count += 1

	if (limit[pPlayer.UserId].Count > RequestsPerWindow) then

        -- checking for accessive spamming
        -- in this case, 5 times the normal rate limit per window
		if (limit[pPlayer.UserId].Count > 5 * RequestsPerWindow) then
			EventBroker.AddMessage(pLogId, {
				Type = "Warning",
				Message = "Accessively spamming purchase event"
			})
		end

		return false
	end

	return true
end