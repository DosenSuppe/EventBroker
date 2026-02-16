--!strict
--!native
--!optimize 2

-- Import sub-modules
local Types = require(script.Types)
local Logger = require(script.Logger)
local Validator = require(script.Validator)
local RateLimit = require(script.RateLimit)
local RemoteHandler = require(script.RemoteHandler)
local Assert = require(script.Assert)
local Parameter = require(script.Parameter)

-- Re-export types
export type LogMessageType = Types.LogMessageType
export type LogMessage = Types.LogMessage
export type IRemoteLog = Types.IRemoteLog
export type Callback = Types.Callback
export type Parameter = Types.Parameter
export type RegisterInfo = Types.RegisterInfo
export type Disconnect = Types.Disconnect
export type Middleware = Types.Middleware

local EventBroker = {}

-- Configuration
EventBroker._maxLogCount = 15_000
EventBroker._isInit = false
EventBroker.CleanupInterval = 10
EventBroker.DebuggingMode = game:GetService("RunService"):IsStudio()
EventBroker.RateLimitWindow = 60
EventBroker.RateLimitMaxRequests = 100

-- Delegate Parameter functions
EventBroker.Parameter = Parameter

-- Create class instances
local logger = Logger.New(EventBroker)
local validator = Validator.New(logger)
local rateLimit = RateLimit.New(EventBroker)
local remoteHandler = RemoteHandler.New(logger, validator, rateLimit)
local assertModule = Assert.New(logger)

--[[
	Configure EventBroker settings
]]
function EventBroker.Configure(pConfig: Types.EventBrokerConfig): nil

	if (pConfig.MaxLogCount) then EventBroker._maxLogCount = pConfig.MaxLogCount end
	if (pConfig.CleanupInterval) then EventBroker.CleanupInterval = pConfig.CleanupInterval end
	if (pConfig.RateLimitWindow) then EventBroker.RateLimitWindow = pConfig.RateLimitWindow end
	if (pConfig.RateLimitMaxRequests) then EventBroker.RateLimitMaxRequests = pConfig.RateLimitMaxRequests end
	if (pConfig.DebuggingMode) ~= nil then EventBroker.DebuggingMode = pConfig.DebuggingMode end

	return nil
end

-- Delegate Message creation
function EventBroker.CreateMessage(pMessage: string, pType: LogMessageType): LogMessage
	return {
		Message = pMessage,
		Type = pType
	}
end

-- Delegate RegisterInfo creation
function EventBroker.CreateRegisterInfo(): RegisterInfo
	return {} :: RegisterInfo
end

-- Delegate to RemoteHandler

--[[
	Registers a callback to an Remote-Object with RegisterInfo.
]]
function EventBroker.RegisterRemote(pRemote: RemoteEvent | RemoteFunction, pCallback: Callback, pRegisterInfo: RegisterInfo): Disconnect
	assert(pRemote:IsA("RemoteEvent") or pRemote:IsA("RemoteFunction"), "You can only register RemoteEvents or RemoteFunctions!")
	
	local disconnectHandler = if (pRemote:IsA("RemoteEvent"))
		then remoteHandler:RegisterRemoteEvent(pRemote, pCallback, pRegisterInfo.Parameters, pRegisterInfo.ForceLogging)
		else remoteHandler:RegisterRemoteFunction(pRemote, pCallback, pRegisterInfo.Parameters, pRegisterInfo.ForceLogging)

	return disconnectHandler
end

--[[
	Registers a callback to an RemoteEvent object.
	]]
--- @deprecated
function EventBroker.RegisterRemoteEvent(pRemoteEvent: RemoteEvent, pCallback: (pPlayer: Player, pLogIdx: number, ...any) -> (), pParamlist: {string}?, pForceLogging: boolean?): nil
	local convertedParamlist = Parameter.ConvertLegacyParamlist(pParamlist or  {})
	
	remoteHandler:RegisterRemoteEvent(pRemoteEvent, pCallback, convertedParamlist, pForceLogging)
	
	return nil
end

--[[
	Registers a callback to an RemoteFunction object.

	Returns Disconnector

	]]
--- @deprecated
function EventBroker.RegisterRemoteFunction(pRemoteFunction: RemoteFunction, pCallback: any, pParamlist: {string}?, pForceLogging: boolean?): nil
	local convertedParamlist = Parameter.ConvertLegacyParamlist(pParamlist or {})
	
	remoteHandler:RegisterRemoteFunction(pRemoteFunction, pCallback, convertedParamlist, pForceLogging)
	
	return nil
end

-- Middleware functions

function EventBroker.AddMiddleware(pRemote: RemoteEvent | RemoteFunction, pMiddleware: Middleware): nil
	return remoteHandler:AddMiddleware(pRemote, pMiddleware)
end

function EventBroker.RemoveMiddleware(pRemote: RemoteEvent | RemoteFunction, pMiddleware: Middleware): nil
	return remoteHandler:RemoveMiddleware(pRemote, pMiddleware)
end

-- Delegate to Logger

function EventBroker.AddMessage(pLogId: number, pMessage: LogMessage): nil
	return logger:AddMessage(pLogId, pMessage)
end

function EventBroker.RetrieveLogs()
	return logger:RetrieveLogs()
end

function EventBroker.RetrieveLogCount()
	return logger:RetrieveLogCount()
end

function EventBroker.RetrieveLog(pLogId: string|number)
	return logger:RetrieveLog(pLogId)
end

function EventBroker.CheckCleanup()
	return logger:CheckCleanup()
end

function EventBroker.RetrieveLogsWithInfoCount(pInfoCount: number)
	return logger:RetrieveLogsWithInfoCount(pInfoCount)
end

function EventBroker.RetrieveLogsByTimeRange(pStartTime: number?, pEndTime: number?)
	return logger:RetrieveLogsByTimeRange(pStartTime, pEndTime)
end

function EventBroker.RetrieveLogsBySender(pUserId: number)
	return logger:RetrieveLogsBySender(pUserId)
end

-- Delegate to Assert

function EventBroker.AssertInList(pLogId: number, pElement: any, pList: {any}): boolean
	return assertModule:AssertInList(pLogId, pElement, pList)
end

function EventBroker.AssertTrue(pLogId: number, pValue: boolean, pFailMessage: string?): boolean
	return assertModule:Assert(pLogId, pValue, pFailMessage)
end

function EventBroker.AssertInRange(pLogId: number, pValue: number, pMin: number, pMax: number, pFailMessage: string?): boolean
	return assertModule:AssertInRange(pLogId, pValue, pMin, pMax, pFailMessage)
end

function EventBroker.AssertStringPattern(pLogId: number, pString: string, pPattern: string, pFailMessage: string?): boolean
	return assertModule:AssertStringPattern(pLogId, pString, pPattern, pFailMessage)
end

--[[
	Returns 
]]
function EventBroker.GetStatistics(): Types.EventBrokerStatistics
	local logStats = logger:GetStatistics()
	local rateLimitStats = rateLimit:GetRateLimitStats()

	return {
		TotalLogs = logStats.TotalLogs,
		ErrorLogs = logStats.ErrorLogs,
		WarningLogs = logStats.WarningLogs,
		RateLimitedUsers = rateLimitStats.rateLimitedUsers,
		EventTypes = logStats.EventTypes
	} :: Types.EventBrokerStatistics
end


--[[
	Initializes the EventBroker module/ log cleanup.

	PLEASE UPDATE TO USE THIS WHEN INITIALIZING!
	INITIALIZING ON "require" WILL BE DEPRECATED SOON!
]]
function EventBroker.Initialize(): nil
	task.spawn(function()
		if (EventBroker._isInit) then return end
		EventBroker._isInit = true

		while (true) do
			task.wait(EventBroker.cleanupInterval)

			local oldLogCount: number = logger:RetrieveLogCount()
			logger:CheckCleanup()

			if (EventBroker.debuggingMode) then
				local newLogCount: number = logger:RetrieveLogCount()
				local deletedLogs: number = oldLogCount - newLogCount
				local susLogCount: number = #logger:RetrieveLogsWithInfoCount(3)

				game:GetService("TestService"):Message(([[
				
				[EVENT-BROKER]
						Currently logged events: %d
						Logs purged since last clean-up: %d
						Logs with more than 3 infos attached: %d
						Used log IDs tracked: %d
				]]):format(newLogCount, deletedLogs, susLogCount, logger:GetUsedLogIdsCount()))
			end
		end
	end)
end

-- REMOVE LINE BELOW WHEN MIGRATING TO `EventBroker.Initialize()` !
if (true) then EventBroker.Initialize() end

return EventBroker
