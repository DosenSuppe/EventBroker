--!strict

local Types = require(script.Parent.Types)
type LogMessage = Types.LogMessage


local Assert = {}
Assert.__index = Assert

type Assert = {
	Logger: any,
} & typeof(Assert)


function Assert.New(logger: any): Assert
	return setmetatable({
		Logger = logger
	}, Assert) :: Assert
end

function Assert.AssertInList(self: Assert, pLogId: number, pElement: any, pList: {any}): boolean
	for _, element: any in pList do
		if element == pElement then
			return true
		end
	end

	self.Logger:AddMessage(pLogId, {
		Type = "Error",
		Message = `Element '{tostring(pElement)}' not in list!`
	})

	return false
end

function Assert.AssertTrue(self: Assert, pLogId: number, pTrueValue: boolean, pFailMessage: string?): boolean
	if not pTrueValue then
		self.Logger:AddMessage(pLogId, {
			Type = "Error",
			Message = pFailMessage or "Value is not false!"
		})
	end

	return pTrueValue
end

function Assert.AssertInRange(self: Assert, pLogId: number, pValue: number, pMin: number, pMax: number, pFailMessage: string?): boolean
	local inRange: boolean = pValue >= pMin and pValue <= pMax

	if not inRange then
		self.Logger:AddMessage(pLogId, {
			Type = "Error",
			Message = pFailMessage or `Value {tostring(pValue)} not in range [{pMin}, {pMax}].`
		})
	end

	return inRange
end

function Assert.AssertStringPattern(self: Assert, pLogId: number, pString: string, pPattern: string, pFailMessage: string?): boolean
	local matches = string.match(pString, pPattern) ~= nil

	if not matches then
		self.Logger:AddMessage(pLogId, {
			Type = "Error",
			Message = pFailMessage or `String '{tostring(pString)}' does not match pattern '{tostring(pPattern)}!'`
		})
	end

	return matches
end

return Assert