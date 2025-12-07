--!strict

local Types = require(script.Parent.Types)
type LogMessage = Types.LogMessage

local Validator = {}
Validator.__index = Validator

export type Validator = {
	Logger: any,
} & typeof(Validator)


Validator.New = function(pLogger: any): Validator
	return setmetatable({
		Logger = pLogger
	}, Validator) :: Validator
end

--[[
	Checks all types and the given paramlist with the trusted paramlist
	
	Parameters:
		pTrustedParamlist: {string}
		pGivenParamlist: {any}
		
	Returns:
		{LogMessage}
]]
function Validator.CheckParamlist(self: Validator, pTrustedParamlist: {string}, pGivenParamlist: {any}): {LogMessage}
	local infoMessages: {LogMessage} = {}

	for index: number = 2, #pTrustedParamlist, 2 do 
		local givenValue: any = pGivenParamlist[index/2]
		local paramType: string = pTrustedParamlist[index]

		local givenValueType = typeof(givenValue)
		local paramTypeSuffix = paramType:sub(-1)
		local paramTypeNoSuffix = paramType:sub(1, -2)

		-- Enhanced type checking
		local isValidType = false

		if paramType == "any" then
			isValidType = true
		elseif paramType:find("|") then
			-- Handle union types like "string|number"
			for unionType in paramType:gmatch("[^|]+") do
				if givenValueType == unionType:gsub("%s+", "") then
					isValidType = true
					break
				end
			end
		elseif givenValueType == paramType then
			isValidType = true
		elseif givenValueType == "nil" and paramTypeSuffix == "?" then
			isValidType = true
		elseif givenValueType == paramTypeNoSuffix and paramTypeSuffix == "?" then
			isValidType = true
		elseif paramType == "integer" and givenValueType == "number" and givenValue % 1 == 0 then
			isValidType = true
		elseif paramType:find("^range%[") then
			-- Handle range validation like "range[1,100]"
			local min, max = paramType:match("range%[([%d%.%-]+),([%d%.%-]+)%]")
			if min and max and givenValueType == "number" then
				min, max = tonumber(min), tonumber(max)
				isValidType = givenValue >= min and givenValue <= max
				if not isValidType then
					table.insert(infoMessages, {
						Type = "Warning",
						Message = `Value {givenValue} not in range [{min}, {max}] for parameter '{pTrustedParamlist[index-1]}'`
					})
				end
			end
		end

		if not isValidType and not paramType:find("^range%[") then
			local paramName: string = pTrustedParamlist[index-1]
			table.insert(infoMessages, {
				Type = "Warning",
				Message = `Type mismatch at variable '{paramName}' - Type given: {tostring(typeof(givenValue))}, expected: {paramType}!`
			} :: LogMessage)
		end
	end

	return infoMessages
end

--[[
	Returns the min count of parameters and the max count of parameters
	
	Parameters:
		pLogIndex: number
		pParamList: {string}
		
	Returns:
		(number, number)
]]
function Validator.GetParamCount(self: Validator, pLogIndex: number, pParamlist: {string}): (number, number)
	local size: number = #pParamlist/2

	-- checking for a malformed paramlist
	if size % 1 ~= 0 then
		self.Logger:AddMessage(pLogIndex, {
			Type = "Warning",
			Message = "Registered with malformed paramlist: Expected even amount of params. Type-Checking security unknown!"
		})
	end

	local minSize: number = size

	-- counting the min. of params that have to be passed
	for i = 2, #pParamlist, 2 do
		local paramType: string = pParamlist[i]
		if paramType:find("?") then
			minSize -= 1
		end
	end

	return minSize, size
end

return Validator