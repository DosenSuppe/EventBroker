--!strict

local Types = require(script.Parent.Types)
type LogMessage = Types.LogMessage
type IRemoteLog = Types.IRemoteLog


local RemoteHandler = {}
RemoteHandler.__index = RemoteHandler

export type RemoteHandler = {
	config: any,
	Logger: any,
	Validator: any,
	RateLimit: any,
	remoteMiddlewares: {[RemoteEvent | RemoteFunction]: {(player: Player, logIndex: number, remoteObject: RemoteEvent | RemoteFunction, ...any) -> boolean}}
} & typeof(RemoteHandler)


RemoteHandler.New = function(pConfig: any, pLogger: any, pValidator: any, pRateLimit: any): RemoteHandler
	return setmetatable({
		Config = pConfig,
		Logger = pLogger,
		Validator = pValidator,
		RateLimit = pRateLimit,
		remoteMiddlewares = {}
	}, RemoteHandler) :: RemoteHandler
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
	pParamlist: {string}?,
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
			['Paramlist'] = {"RATE_LIMITED"},
			['GivenParams'] = {"RATE_LIMITED"},
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
		['Paramlist'] = pParamlist or {"NO-PARAM-LIST-SPECIFIED"},
		['GivenParams'] = givenParams,
		['Timestamp'] = os.time()
	}

	local index = self.Logger:AddLogEntry(logEntry)
	
	-- Execute middleware chain for this specific remote
	local middlewares = self.remoteMiddlewares[pRemoteObject] or {}
	for _, middleware in middlewares do
		local shouldContinue = middleware(pSender, index, pRemoteObject, ...)
		if not shouldContinue then
			self.Logger:AddMessage(index, {
				Type = "Warning",
				Message = "Request blocked by middleware"
			})

			return nil
		end
	end
	
	if (pParamlist) then
		logEntry.EventLogs = self.Validator:CheckParamlist(pParamlist, givenParams)

		local minParamCount: number, maxParamCount: number = self.Validator:GetParamCount(index, pParamlist)

		if #givenParams < minParamCount then
			self.Logger:AddMessage(index, {
				Type = "Warning",
				Message = `Paramlist shorter than expected - given: {#givenParams} expected at least: {minParamCount}!`
			})
		elseif #givenParams > maxParamCount then
			self.Logger:AddMessage(index, {
				Type = "Warning",
				Message = `Paramlist larger than expected - given: {#givenParams} expected at most: {maxParamCount}!`
			})
		end
	end


	-- Execute callback
	local success, result = pcall(pCallback, pSender, index, ...)

	if not (success) then
		self.Logger:AddMessage(index, {
			Type = "Error",
			Message = `Callback execution failed! Stack-Trace: {tostring(result)}`
		})

		return nil
	end

	if (#logEntry.EventLogs == 0 and not pForceLogging) then
		self.Logger:RemoveLogEntry(index)
	end

	return result
end

--[[
	Registers a RemoteEvent to the broker
]]
RemoteHandler.RegisterRemoteEvent = function(
	self: RemoteHandler,
	pRemoteEvent: RemoteEvent, 
	pCallback: (pPlayer: Player, pLogIdx: number, ...any) -> (), 
	pParamlist: {string}?, 
	pForceLogging: boolean?
): nil
	
	pRemoteEvent.OnServerEvent:Connect(function(pSender: Player, ...)
		HandleRemoteCall(self, pRemoteEvent, pSender, pCallback, pParamlist, pForceLogging, ...)
	end)

	return nil
end

--[[
	Registers a RemoteFunction to the broker
]]
RemoteHandler.RegisterRemoteFunction = function(
	self: RemoteHandler,
	pRemoteFunction: RemoteFunction, 
	pCallback: any, 
	pParamlist: {string}?, 
	pForceLogging: boolean?
): nil
	
	pRemoteFunction.OnServerInvoke = function(pSender: Player, ...): any
		return HandleRemoteCall(self, pRemoteFunction, pSender, pCallback, pParamlist, pForceLogging, ...)
	end

	return nil
end

--[[
	Adds middleware to a specific remote's execution chain
	
	Parameters:
		remoteObject: The RemoteEvent or RemoteFunction to add middleware to
		middleware: function that returns true to continue, false to block
]]
function RemoteHandler.AddMiddleware(
	self: RemoteHandler,
	remoteObject: RemoteEvent | RemoteFunction,
	middleware: (player: Player, logIndex: number, remoteObject: RemoteEvent | RemoteFunction, ...any) -> boolean
): nil
	if not self.remoteMiddlewares[remoteObject] then
		self.remoteMiddlewares[remoteObject] = {}
	end
	table.insert(self.remoteMiddlewares[remoteObject], middleware)
	return nil
end

--[[
	Removes middleware from a specific remote's execution chain
]]
function RemoteHandler.RemoveMiddleware(
	self: RemoteHandler,
	remoteObject: RemoteEvent | RemoteFunction,
	middleware: (player: Player, logIndex: number, remoteObject: RemoteEvent | RemoteFunction, ...any) -> boolean
): nil
	local middlewares = self.remoteMiddlewares[remoteObject]
	if not middlewares then
		return nil
	end
	
	for i, existingMiddleware in middlewares do
		if existingMiddleware == middleware then
			table.remove(middlewares, i)
			break
		end
	end
	
	-- Clean up empty middleware array
	if #middlewares == 0 then
		self.remoteMiddlewares[remoteObject] = nil
	end
	
	return nil
end

return RemoteHandler