local EventBroker = require(game.ServerStorage.EventBroker)

-- blocking access to an event for any non-staff members
return function(pPlayer: Player, pLogId: number, ...): boolean
    if not (EventBroker.AssertTrue(pLogId, pPlayer.Name == "TheAdmin", "Player is not staff!")) then
        return false
    end

    return true
end