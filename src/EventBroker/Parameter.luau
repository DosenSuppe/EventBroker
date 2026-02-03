--!strict
local Types = require(script.Parent.Types)
type Parameter = Types.Parameter

local Parameter = {}


Parameter.String = function(pName: string): Parameter
    assert(typeof(pName) == "string", "Name of Paramter has to be a string!")

    return {
        _type = "string",
        Name = pName
    }
end

Parameter.Number = function(pName: string): Parameter
    assert(typeof(pName) == "string", "Name of Paramter has to be a string!")

    return {
        _type = "number",
        Name = pName
    }
end

Parameter.Boolean = function(pName: string): Parameter
    assert(typeof(pName) == "string", "Name of Paramter has to be a string!")

    return {
        _type = "boolean",
        Name = pName
    }
end

Parameter.Table = function(pName: string): Parameter
    assert(typeof(pName) == "string", "Name of Paramter has to be a string!")

    return {
        _type = "table",
        Name = pName
    }
end

Parameter.Any = function(pName: string): Parameter
    assert(typeof(pName) == "string", "Name of Paramter has to be a string!")

    return {
        _type = "any",
        Name = pName
    }
end

Parameter.Optional = function(pParameter: Parameter): Parameter
    pParameter._isOptional = true
    return pParameter
end

--[[
    Converts the legacy parameter list into the new parameter list.

    For new registrations use EventBroker.CreateRemote() instead!
    ]]
--- @deprecated @private
Parameter.ConvertLegacyParamlist = function(pParamlist: { string } ): { Parameter }
    local convertedParamlist = {}

    for i = 2, #pParamlist, 2 do
        local name = pParamlist[i-1]
        local _type = pParamlist[i]

        if (_type:find("?")) then
            _type = _type:split("?")[1]
            table.insert(convertedParamlist, {
                _type = _type,
                _isOptional = true,
                Name = name
            })
        elseif (_type:find("|") or _type:find("&")) then
            warn("[EventBroker] Type-Unions are no longer supported!")
        else
            table.insert(convertedParamlist, {
                _type = _type,
                _isOptional = false,
                Name = name
            })
        end
    end

    return convertedParamlist
end

return Parameter