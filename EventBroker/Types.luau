--!strict

export type LogMessageType = "Info" | "Warning" | "Error"

export type LogMessage = {
	Type: LogMessageType,
	Message: string
}

export type IRemoteLog = {
	Type: "RemoteEvent" | "RemoteFunction",
	EventOrigin: string,
	Sender: number,
	LogId: string,
	EventLogs: { LogMessage },
	Paramlist: { Parameter },
	GivenParams: { any },
	Timestamp: number
}

export type Disconnect = () -> ()

export type Middleware = (pPlayer: Player, pLogId: number, ...any) -> boolean

export type EventBrokerStatistics = {
	TotalLogs: number,
	ErrorLogs: number,
	WarningLogs: number,
	EventTypes: {[string]: number}
}

export type Parameter = {
	Name: string,
	_type: string,
	_isOptional: boolean?
}

export type RegisterInfo = {
	ForceLogging: boolean,
	Parameters: { Parameter }
}

export type Callback = (pPlayer: Player, pLogIndex: number, ...any) -> any

export type EventBrokerConfig = {
	MaxLogCount: number?,
	CleanupInterval: number?,
	RateLimitWindow: number?,
	RateLimitMaxRequests: number?,
	DebuggingMode: boolean?
}

return {}