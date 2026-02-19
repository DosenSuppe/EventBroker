--!strict

local Types = require(script.Parent.Types)
type EventDataLog = Types.EventDataLog
type Disconnect = Types.Disconnect

export type HookCallback = (pDataLog: EventDataLog) -> ()

export type HookEntry = {
	Remote: RemoteEvent | RemoteFunction,
	Player: Player,
	Callback: HookCallback
}

export type Hook = {
	_hooks: { HookEntry },
	Register: (self: Hook, pRemote: RemoteEvent | RemoteFunction, pPlayer: Player, pCallback: HookCallback) -> Disconnect,
	Fire: (self: Hook, pRemote: RemoteEvent | RemoteFunction, pPlayer: Player, pDataLog: EventDataLog) -> (),
	FireAll: (self: Hook, pDataLog: EventDataLog) -> ()
}

local Hook = {}
Hook.__index = Hook

--[[
	Creates a new Hook manager instance
]]
function Hook.New(): Hook
	return setmetatable({
		_hooks = {} :: { HookEntry }
	}, Hook) :: Hook
end

--[[
	Registers a hook for a specific remote and player combination
	Returns a disconnect function to unregister the hook
]]
function Hook.Register(
	self: Hook,
	pRemote: RemoteEvent | RemoteFunction,
	pPlayer: Player,
	pCallback: HookCallback
): Disconnect
	local hookEntry: HookEntry = {
		Remote = pRemote,
		Player = pPlayer,
		Callback = pCallback
	}

	table.insert(self._hooks, hookEntry)

	return function()
		self:_Unregister(hookEntry)
	end
end

--[[
	Internal function to remove a hook entry
]]
function Hook._Unregister(self: Hook, pHookEntry: HookEntry): nil
	for i, entry in self._hooks do
		if entry == pHookEntry then
			table.remove(self._hooks, i)
			break
		end
	end

	return nil
end

--[[
	Fires all hooks registered for a specific remote and player
]]
function Hook.Fire(
	self: Hook,
	pRemote: RemoteEvent | RemoteFunction,
	pPlayer: Player,
	pDataLog: EventDataLog
): ()
	for _, entry in self._hooks do
		if entry.Remote == pRemote and entry.Player == pPlayer then
			task.spawn(entry.Callback, pDataLog)
		end
	end
end

--[[
	Fires all hooks that match the sender in the EventDataLog
	Used when firing hooks without specific remote/player context
]]
function Hook.FireAll(self: Hook, pDataLog: EventDataLog): ()
	for _, entry in self._hooks do
		-- Match by sender UserId from the log
		if entry.Player.UserId == pDataLog.RemoteLog.Sender then
			-- Match by remote name if possible
			local remoteFullName = pDataLog.RemoteLog.EventOrigin
			local entryRemoteFullName = entry.Remote:GetFullName()

			if remoteFullName == entryRemoteFullName then
				task.spawn(entry.Callback, pDataLog)
			end
		end
	end
end

--[[
	Gets the count of registered hooks
]]
function Hook.GetHookCount(self: Hook): number
	return #self._hooks
end

--[[
	Removes all hooks for a specific player (useful for cleanup on player leave)
]]
function Hook.RemovePlayerHooks(self: Hook, pPlayer: Player): number
	local removedCount = 0
	local i = #self._hooks

	while i > 0 do
		if self._hooks[i].Player == pPlayer then
			table.remove(self._hooks, i)
			removedCount += 1
		end

		i -= 1
	end

	return removedCount
end

return Hook
