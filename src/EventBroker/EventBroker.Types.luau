--!strict

export type LogMessage = {
	Type: "Info" | "Warning" | "Error",
	Message: string
}

export type IRemoteLog = {
	Type: "RemoteEvent" | "RemoteFunction",
	EventOrigin: string,
	Sender: number,
	LogId: string,
	EventLogs: {LogMessage},
	Paramlist: {string},
	GivenParams: {any},
	Timestamp: number
}

export type EventBrokerStatistics = {
	TotalLogs: number,
	ErrorLogs: number,
	WarningLogs: number,
	EventTypes: {[string]: number}
}

return {}