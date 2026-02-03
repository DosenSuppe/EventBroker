--!strict

local Types = require(script.Parent.Types)
type LogMessage = Types.LogMessage
type IRemoteLog = Types.IRemoteLog
type Middleware = Types.Middleware
type Parameter = Types.Parameter
type Callback = Types.Callback
type Disconnect = Types.Disconnect


local RemoteHandler = {}
RemoteHandler.__index = RemoteHandler

export type RemoteHandler = {
	Logger: any,
	Validator: any,
	RateLimit: any,
	_registeredMiddlewares: {[RemoteEvent | RemoteFunction]: { Middleware }}
} & typeof(RemoteHandler)


RemoteHandler.New = function(pLogger: any, pValidator: any, pRateLimit: any): RemoteHandler
	return setmetatable({
		Logger = pLogger,
		Validator = pValidator,
		RateLimit = pRateLimit,
		_registeredMiddlewares = {}
	} :: RemoteHandler, RemoteHandler)
end

--[[
	Generic handler for both RemoteEvents and RemoteFunctions
	Eliminates duplicate code between the two
]]
local function HandleRemoteCall(
	self: RemoteHandler,
	pRemoteObject: RemoteEvent | RemoteFunction,
	pSender: Player,
	pCallback: any,
	pParamlist: { Parameter }?,
	pForceLogging: boolean?,
	...: any
): any?

	if (self.RateLimit:CheckRateLimit(pSender.UserId)) then
		local logId: string = self.Logger:GenerateLogId()

		local logEntry: IRemoteLog = {
			['Type'] = pRemoteObject.ClassName :: "RemoteEvent" | "RemoteFunction",
			['EventOrigin'] = pRemoteObject:GetFullName(),
			['Sender'] = pSender.UserId,
			['LogId'] = logId,
			['EventLogs'] = {{
				Type = "Error",
				Message = "Rate limit exceeded - request blocked"
			}},
			['Paramlist'] = {},
			['GivenParams'] = {},
			['Timestamp'] = os.time()
		}

		self.Logger:AddLogEntry(logEntry)

		return nil
	end

	local logId: string = self.Logger:GenerateLogId()
	local givenParams = {...}

	local logEntry: IRemoteLog = {
		['Type'] = pRemoteObject.ClassName :: "RemoteEvent" | "RemoteFunction",
		['EventOrigin'] = pRemoteObject:GetFullName(),
		['Sender'] = pSender.UserId,
		['LogId'] = logId,
		['EventLogs'] = {},
		['Paramlist'] = pParamlist or {},
		['GivenParams'] = givenParams,
		['Timestamp'] = os.time()
	}

	local id = self.Logger:AddLogEntry(logEntry)

	-- Execute middleware chain for this specific remote
	local middlewares = self._registeredMiddlewares[pRemoteObject] or {} :: { Middleware }

	for _, middleware in middlewares do
		local hasRun, shouldContinue: boolean | string = pcall(middleware, pSender, id, ...)

		if not (hasRun) then
			self.Logger:AddMessage(id, {
				Type = "Error",
				Message = `Middleware experienced an error during execution: {tostring(shouldContinue :: string)}`
			})

			return nil
		end

		if not (shouldContinue) then
			self.Logger:AddMessage(id, {
				Type = "Warning",
				Message = "Request blocked by middleware"
			})

			return nil
		end
	end

	if (pParamlist) then
		logEntry.EventLogs = self.Validator:CheckParamlist(pParamlist, givenParams)

		local minParamCount: number, maxParamCount: number = self.Validator:GetParamCount(id, pParamlist)

		if (#givenParams < minParamCount) then
			self.Logger:AddMessage(id, {
				Type = "Warning",
				Message = `Paramlist shorter than expected - given: {#givenParams} expected at least: {minParamCount}!`
			})
		elseif (#givenParams > maxParamCount) then
			self.Logger:AddMessage(id, {
				Type = "Warning",
				Message = `Paramlist larger than expected - given: {#givenParams} expected at most: {maxParamCount}!`
			})
		end
	end


	-- Execute callback
	local success, result = pcall(pCallback, pSender, id, ...)

	if not (success) then
		self.Logger:AddMessage(id, {
			Type = "Error",
			Message = `Callback execution failed! Error: {tostring(result)}`
		})

		return nil
	end

	if (#logEntry.EventLogs == 0 and not pForceLogging) then
		self.Logger:RemoveLogEntry(id)
	end

	return result
end

--[[
	Registers a RemoteEvent to the broker
]]
RemoteHandler.RegisterRemoteEvent = function(
	self: RemoteHandler,
	pRemoteEvent: RemoteEvent, 
	pCallback: Callback, 
	pParamlist: { Parameter }?, 
	pForceLogging: boolean?
): Disconnect
	local connection = pRemoteEvent.OnServerEvent:Connect(function(pSender: Player, ...)
		HandleRemoteCall(self, pRemoteEvent, pSender, pCallback, pParamlist, pForceLogging, ...)
	end)

	return function()
		connection:Disconnect()
	end
end

--[[
	Registers a RemoteFunction to the broker
]]
RemoteHandler.RegisterRemoteFunction = function(
	self: RemoteHandler,
	pRemoteFunction: RemoteFunction, 
	pCallback: Callback, 
	pParamlist: { Parameter }?, 
	pForceLogging: boolean?
): Disconnect

	pRemoteFunction.OnServerInvoke = function(pSender: Player, ...): any
		return HandleRemoteCall(self, pRemoteFunction, pSender, pCallback, pParamlist, pForceLogging, ...)
	end

	return function()
		pRemoteFunction.OnServerInvoke = function()	end
	end
end

--[[
	Adds middleware to a specific remote's execution chain
]]
function RemoteHandler.AddMiddleware(
	self: RemoteHandler,
	pRemote: RemoteEvent | RemoteFunction,
	pMiddleware: Middleware
): nil

	if not (self._registeredMiddlewares[pRemote]) then
		self._registeredMiddlewares[pRemote] = {}
	end

	table.insert(self._registeredMiddlewares[pRemote], pMiddleware)
	
	return nil
end

--[[
	Removes middleware from a specific remote's execution chain
]]
function RemoteHandler.RemoveMiddleware(
	self: RemoteHandler,
	pRemote: RemoteEvent | RemoteFunction,
	pMiddleware: Middleware
): nil
	local middlewares = self._registeredMiddlewares[pRemote]

	if not (middlewares) then
		return nil
	end

	for i, existingMiddleware in middlewares do
		if existingMiddleware == pMiddleware then
			table.remove(middlewares, i)
			break
		end
	end

	if (#middlewares == 0) then
		self._registeredMiddlewares[pRemote] = nil
	end

	return nil
end

return RemoteHandler