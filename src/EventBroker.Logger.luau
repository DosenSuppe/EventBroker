--!strict

local Types = require(script.Parent.Types)
local HttpService: HttpService = game:GetService("HttpService")

type LogMessage = Types.LogMessage
type IRemoteLog = Types.IRemoteLog
type EventBrokerStatistics = Types.EventBrokerStatistics

local Logger = {}
Logger.__index = Logger

export type Logger = {
	Config: any,
	LogHistory: {IRemoteLog},
	LogStartIndex: number,
	LogNextIndex: number,
	LogCount: number,
	UsedLogIds: {[string]: true},
} & typeof(Logger)

Logger.New = function(config: any): Logger
	return setmetatable({
		Config = config,
		LogHistory = {},
		LogStartIndex = 1,
		LogNextIndex = 1,
		LogCount = 0,
		UsedLogIds = {}
	}, Logger) :: Logger
end

--[[
	Generates a unique Id for every event that's fired
	
	Returns:
		string
]]
Logger.GenerateLogId = function(self: Logger): string
	local logId 

	repeat
		logId = HttpService:GenerateGUID(false)	
	until not self.UsedLogIds[logId]

	self.UsedLogIds[logId] = true

	return logId
end

--[[
	Adds a log entry to the circular buffer
	
	Parameters:
		logEntry: IRemoteLog
		
	Returns:
		number - The index where the log was stored
]]
Logger.AddLogEntry = function(self: Logger, logEntry: IRemoteLog): number
	local index = self.LogNextIndex

	-- Clean up old log if we're overwriting
	local oldLog = self.LogHistory[index]
	
	if oldLog and oldLog.LogId then
		self.UsedLogIds[oldLog.LogId] = nil
	end

	self.LogHistory[index] = logEntry
	self.LogNextIndex = (self.LogNextIndex % self.Config.maxLogCount) + 1

	if self.LogCount < self.Config.maxLogCount then
		self.LogCount += 1
	end

	return index
end

--[[
	Adds a message to an existing log entry
	
	Parameters:
		pLogIndex: number
		pMessage: LogMessage
]]
Logger.AddMessage = function(self: Logger, pLogIndex: number, pMessage: LogMessage): nil
	local log: IRemoteLog? = self.LogHistory[pLogIndex]

	if not log then
		return nil
	end

	table.insert(log.EventLogs, pMessage)
	return nil
end

--[[
	Removes a log entry and cleans up its ID
	
	Parameters:
		pLogIndex: number
]]
Logger.RemoveLogEntry = function(self: Logger, pLogIndex: number): nil
	local log = self.LogHistory[pLogIndex]
	
	if (log and log.LogId) then
		self.UsedLogIds[log.LogId] = nil
		self.LogHistory[pLogIndex] = nil
		self.LogCount = math.max(0, self.LogCount - 1)
	end
	
	return nil
end

--[[
	Returns all Logs from the LogHistory
]]
Logger.RetrieveLogs = function(self: Logger): {IRemoteLog}
	return self.LogHistory
end

--[[
	Returns the number of logs stored
]]
Logger.RetrieveLogCount = function(self: Logger): number
	return self.LogCount
end

--[[
	Returns the Log for the given log-id and index in the history if found
]]
Logger.RetrieveLog = function(self: Logger, pLogId: string|number): (IRemoteLog?, number?)
	if (typeof(pLogId) == "number") then
		return self.LogHistory[pLogId], pLogId
	end

	for i: number, log: IRemoteLog in self.LogHistory do
		if (log and log.LogId == pLogId) then
			return log, i
		end
	end

	return nil, nil
end

--[[
	Cleans all old logs from the log history
]]
Logger.CheckCleanup = function(self: Logger): nil
	local removedCount = 0

	while self.LogCount > self.Config.maxLogCount  do
		
		-- Find oldest log to remove (simple approach for circular buffer)
		for i = 1, self.Config.maxLogCount do
			if self.LogHistory[i] then
				self:RemoveLogEntry(i)
				removedCount += 1
				break
			end
		end

		if removedCount > 100 then break end -- Safety break
	end

	-- Periodic cleanup of orphaned IDs
	if removedCount > 0 and removedCount % 1000 == 0 then
		local validIds: {[string]: true} = {}
		for _, log in self.LogHistory do
			if log and log.LogId then
				validIds[log.LogId] = true
			end
		end
		self.UsedLogIds = validIds
	end

	return nil
end

--[[
	Retrieves all logs with at least the given amount of infos attached
]]
Logger.RetrieveLogsWithInfoCount = function(self: Logger, pInfoCount: number): {IRemoteLog}
	local logs: {IRemoteLog} = {}

	for i, log in self.LogHistory do
		if log and #log.EventLogs >= pInfoCount then
			table.insert(logs, log)
		end
	end	

	return logs
end

--[[
	Retrieves logs within a time range
]]
Logger.RetrieveLogsByTimeRange = function(self: Logger, pStartTime: number?, pEndTime: number?): {IRemoteLog}
	local logs: {IRemoteLog} = {}
	local startTime = pStartTime or 0
	local endTime = pEndTime or os.time()

	for i, log in self.LogHistory do
		if log and log.Timestamp >= startTime and log.Timestamp <= endTime then
			table.insert(logs, log)
		end
	end

	return logs
end

--[[
	Retrieves logs by sender UserId
]]
Logger.RetrieveLogsBySender = function(self: Logger, pUserId: number): {IRemoteLog}
	local logs: {IRemoteLog} = {}

	for i, log in self.LogHistory do
		if log and log.Sender == pUserId then
			table.insert(logs, log)
		end
	end

	return logs
end

--[[
	Get comprehensive statistics about the EventBroker
]]
Logger.GetStatistics = function(self: Logger): EventBrokerStatistics
	local eventBrokerStats: EventBrokerStatistics = {
		TotalLogs = self.LogCount,
		ErrorLogs = 0,
		WarningLogs = 0,
		EventTypes = {}
	}

	for i = 1, self.Config.maxLogCount do
		local log = self.LogHistory[i]
		if not log then continue end

		eventBrokerStats.EventTypes[log.Type] = (eventBrokerStats.EventTypes[log.Type] or 0) + 1

		for _, logMessage in log.EventLogs do
			if logMessage.Type == "Error" then
				eventBrokerStats.ErrorLogs += 1
			elseif logMessage.Type == "Warning" then
				eventBrokerStats.WarningLogs += 1
			end
		end
	end

	return eventBrokerStats
end

Logger.GetUsedLogIdsCount = function(self: Logger): number
	local count = 0
	for _ in self.UsedLogIds do 
		count += 1 
	end
	return count
end

return Logger