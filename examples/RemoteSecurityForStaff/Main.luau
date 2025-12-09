--!strict

local EventBroker = require(game.ServerStorage.EventBroker)
local StaffPolicy = require(script.Parent.StaffPolicy)

-- typical RemoteFunctions/ RemoteEvents for an Admin-System
local IsUserBanned: RemoteFunction = game.ReplicatedStorage.IsUserBanned
local BanUser: RemoteEvent = game.ReplicatedStorage.BanUser

-- handlers for the events
local function HandleIsUserBanned(pModerator: Player, pLogId: number, pUserId: number): boolean
	return math.random(1, 2) == 1 -- mocking a database call
end

local function HandleBanUser(pModerator: Player, pLogId: number, pUserId: number)
    -- checking if the UserId is acutally provided
	if not (EventBroker.AssertTrue(pLogId, pUserId~=nil, "Expected userId to not be nil!")) then
		return
	end

    -- mock banning the user
    print(`{pModerator.Name} banned user {tostring(pUserId)}!`)

	return
end

-- register the events to log

EventBroker.RegisterRemoteFunction(IsUserBanned, HandleIsUserBanned, {"pUserId", "number"})
EventBroker.RegisterRemoteEvent(BanUser, HandleBanUser, {"pUserId", "number"}, true) -- force logging for ban events
-- Force logging will make sure an event is always logged, even if no messages were added to it.

-- Add middleware to secure them against non-staff members
EventBroker.AddMiddleware(IsUserBanned, StaffPolicy)
EventBroker.AddMiddleware(BanUser, StaffPolicy)
