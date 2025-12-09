--!strict

local EventBroker = require(game.ServerStorage.EventBroker)
local PurchaseRatelimit = require(script.Parent.PurchaseRatelimit)

local PurchaseEvent: RemoteEvent = game.ReplicatedStorage.Purchase

--- Purchase event
local ValidProducts = {"Apple", "Book", "Car"}

local function HandlePurchaseEvent(pPlayer: Player, pLogId: number, pProduct: string)
	
    -- Checking if the product is valid.
    -- "ValidProducts" could be fetched from a database or defined elsewhere
    if not (EventBroker.AssertInList(pLogId, pProduct, ValidProducts)) then
        -- Invalid products will be logged
        -- event will not execute the purchase process
		return
	end

    -- Process the purchase
	print(`Server received Purchase request from {pPlayer.Name} for {pProduct}`)

	return
end

EventBroker.RegisterRemoteEvent(PurchaseEvent, HandlePurchaseEvent, {"pProduct", "string"})
EventBroker.AddMiddleware(PurchaseEvent, PurchaseRatelimit)

