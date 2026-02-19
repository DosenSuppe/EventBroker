
--[[
    Hooks enable you connect and listen to any RemoteEvent/ RemoteFunction
    traffic of any player within the server during runtime.

    This allows you to monitor a user's network traffic for malicous requests.
    It also provides info about the size of the packages send from the player and
    the server's response (if connecting to a RemoteFunction).
]]

local EventBroker = require(game.ReplicatedStorage.EventBroker)
local SomeEvent: RemoteEvent
local SomePlayer: Player

local function hookCallback(pData)
    -- Do stuff here
end

EventBroker.HookToPlayerEvent(SomeEvent, SomePlayer, hookCallback)

return {}
