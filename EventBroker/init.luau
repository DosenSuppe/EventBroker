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

-- Re-export types
export type LogMessage = Types.LogMessage
export type IRemoteLog = Types.IRemoteLog

local EventBroker = {}

-- Configuration
EventBroker.maxLogCount = 15_000
EventBroker.isInit = false
EventBroker.cleanupInterval = 10
EventBroker.debuggingMode = game:GetService("RunService"):IsStudio()
EventBroker.rateLimitWindow = 60
EventBroker.rateLimitMaxRequests = 100

-- Create class instances
local logger = Logger.New(EventBroker)
local validator = Validator.New(logger)
local rateLimit = RateLimit.New(EventBroker)
local remoteHandler = RemoteHandler.New(EventBroker, logger, validator, rateLimit)
local assertModule = Assert.New(logger)

--[[
	Configure EventBroker settings
	
	Parameters:
		config: {
			maxLogCount: number?,
			cleanupInterval: number?,
			rateLimitWindow: number?,
			rateLimitMaxRequests: number?,
			debuggingMode: boolean?
		}
		
	Returns:
		nil
]]
EventBroker.Configure = function(config: {
	maxLogCount: number?,
	cleanupInterval: number?,
	rateLimitWindow: number?,
	rateLimitMaxRequests: number?,
	debuggingMode: boolean?
	}): nil
	if config.maxLogCount then EventBroker.maxLogCount = config.maxLogCount end
	if config.cleanupInterval then EventBroker.cleanupInterval = config.cleanupInterval end
	if config.rateLimitWindow then EventBroker.rateLimitWindow = config.rateLimitWindow end
	if config.rateLimitMaxRequests then EventBroker.rateLimitMaxRequests = config.rateLimitMaxRequests end
	if config.debuggingMode ~= nil then EventBroker.debuggingMode = config.debuggingMode end

	return nil
end

-- Delegate to RemoteHandler
function EventBroker.RegisterRemoteEvent(pRemoteEvent: RemoteEvent, pCallback: (pPlayer: Player, pLogIdx: number, ...any) -> (), pParamlist: {string}?, pForceLogging: boolean?)
	return remoteHandler:RegisterRemoteEvent(pRemoteEvent, pCallback, pParamlist, pForceLogging)
end

function EventBroker.RegisterRemoteFunction(pRemoteFunction: RemoteFunction, pCallback: any, pParamlist: {string}?, pForceLogging: boolean?)
	return remoteHandler:RegisterRemoteFunction(pRemoteFunction, pCallback, pParamlist, pForceLogging)
end

-- Middleware functions
function EventBroker.AddMiddleware(remoteObject: RemoteEvent | RemoteFunction, middleware: (player: Player, logIndex: number, remoteObject: RemoteEvent | RemoteFunction, ...any) -> boolean)
	return remoteHandler:AddMiddleware(remoteObject, middleware)
end

function EventBroker.RemoveMiddleware(remoteObject: RemoteEvent | RemoteFunction, middleware: (player: Player, logIndex: number, remoteObject: RemoteEvent | RemoteFunction, ...any) -> boolean)
	return remoteHandler:RemoveMiddleware(remoteObject, middleware)
end

-- Delegate to Logger
function EventBroker.AddMessage(pLogIndex: number, pMessage: LogMessage)
	return logger:AddMessage(pLogIndex, pMessage)
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
function EventBroker.AssertInList(pLogId: number, pElement: any, pList: {any})
	return assertModule:AssertInList(pLogId, pElement, pList)
end

function EventBroker.AssertTrue(pLogId: number, pTrueValue: boolean, pFailMessage: string?)
	return assertModule:AssertTrue(pLogId, pTrueValue, pFailMessage)
end

function EventBroker.AssertInRange(pLogId: number, pValue: number, pMin: number, pMax: number, pFailMessage: string?)
	return assertModule:AssertInRange(pLogId, pValue, pMin, pMax, pFailMessage)
end

function EventBroker.AssertStringPattern(pLogId: number, pString: string, pPattern: string, pFailMessage: string?)
	return assertModule:AssertStringPattern(pLogId, pString, pPattern, pFailMessage)
end

-- Combined statistics
EventBroker.GetStatistics = function(): {
	totalLogs: number,
	errorLogs: number,
	warningLogs: number,
	rateLimitedUsers: number,
	eventTypes: {[string]: number}
	}
	local logStats = logger:GetStatistics()
	local rateLimitStats = rateLimit:GetRateLimitStats()

	return {
		totalLogs = logStats.TotalLogs,
		errorLogs = logStats.ErrorLogs,
		warningLogs = logStats.WarningLogs,
		rateLimitedUsers = rateLimitStats.rateLimitedUsers,
		eventTypes = logStats.EventTypes
	}
end

-- Cleanup loop
task.spawn(function()
	if EventBroker.isInit then return end
	EventBroker.isInit = true

	while true do
		task.wait(EventBroker.cleanupInterval)

		local oldLogCount: number = logger:RetrieveLogCount()
		logger:CheckCleanup()

		if EventBroker.debuggingMode then
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
			print(logger.LogHistory)
		end
	end
end)

return EventBroker