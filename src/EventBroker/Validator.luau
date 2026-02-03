--!strict
local Types = require(script.Parent.Types)
type LogMessage = Types.LogMessage
type Parameter = Types.Parameter

local Validator = {}
Validator.__index = Validator

export type Validator = {
	Logger: any,
} & typeof(Validator)


Validator.New = function(pLogger: any): Validator
	return setmetatable({
		Logger = pLogger
	} :: Validator, Validator)
end

--[[
	Checks all types and the given paramlist with the trusted paramlist
]]
function Validator.CheckParamlist(self: Validator, pTrustedParamlist: { Parameter }, pGivenParamlist: { any }): { LogMessage }
	local infoMessages: {LogMessage} = {}

	for index, parameter in pTrustedParamlist do
		local givenParam: any = pGivenParamlist[index]

		if not (typeof(givenParam) == parameter._type or typeof(givenParam) == "nil" and parameter._isOptional) then
			table.insert(infoMessages, {
				Type = "Warning",
				Message = `Type mismatch at variable '{parameter.Name}' - Type given: {tostring(typeof(givenParam))}, expected: {parameter._type}!`
			} :: LogMessage)
		end
	end

	return infoMessages
end

--[[
	Returns the min count of parameters and the max count of parameters
]]
function Validator.GetParamCount(self: Validator, pLogId: number, pParamlist: { Parameter }): (number, number)
	local size: number = 0
	local minSize: number = 0
	
	for _, param in pParamlist do
		if not (param._isOptional) then
			minSize += 1
		end
		size += 1
	end

	return minSize, size
end

return Validator