# EventBroker

A production-ready remote monitoring and security framework for Roblox, providing comprehensive validation, rate limiting, and middleware capabilities.

## Features

- **Security First**: Built-in rate limiting, parameter validation, and middleware chains
- **Production Logging**: Comprehensive event tracking with automatic cleanup
- **Modular Design**: Clean separation of concerns with dependency injection
- **Memory Efficient**: Circular buffer prevents memory leaks in long-running servers
- **Granular Control**: Per-remote middleware for fine-tuned security policies
- **Analytics Ready**: Built-in statistics and monitoring capabilities
- **Type Safe**: Full Luau typing for better development experience

## Getting Started

```lua
local EventBroker = require(game.ServerScriptService.EventBroker)

-- Basic remote registration
local chatRemote = game.ReplicatedStorage.ChatRemote

EventBroker.RegisterRemoteEvent(chatRemote, function(player, logIndex, message)
    if #message > 0 then
        broadcastMessage(player, message)
    end
end, {"message", "string"})
```

## Architecture

EventBroker follows a modular architecture with clear separation of responsibilities:

```
EventBroker/
├── EventBroker.luau           # Main module
├── EventBroker.Types.luau     # Type definitions  
├── EventBroker.Logger.luau    # Event storage
├── EventBroker.Validator.luau # Parameter validation
├── EventBroker.RateLimit.luau # Rate limiting
├── EventBroker.RemoteHandler.luau # Core handler
└── EventBroker.Assert.luau    # Validation helpers
```

## Configuration

```lua
EventBroker.Configure({
    maxLogCount = 20000,
    cleanupInterval = 15,
    rateLimitWindow = 60,
    rateLimitMaxRequests = 150,
    debuggingMode = false
})
```

## Remote Registration

### RemoteEvents

```lua
EventBroker.RegisterRemoteEvent(remote, callback, paramlist?, forceLogging?)
```

The callback receives `(player, logIndex, ...args)` where logIndex can be used for assertions and logging.

```lua
EventBroker.RegisterRemoteEvent(purchaseRemote, function(player, logIndex, itemId, quantity)
    -- Validate purchase limits
    if not EventBroker.AssertInRange(logIndex, quantity, 1, 10) then
        return
    end
    
    processPurchase(player, itemId, quantity)
end, {"itemId", "string", "quantity", "number"})
```

### RemoteFunctions

```lua
EventBroker.RegisterRemoteFunction(remote, callback, paramlist?, forceLogging?)
```

Functions should return data or nil on error:

```lua
EventBroker.RegisterRemoteFunction(getDataRemote, function(player, logIndex, dataType)
    if dataType == "stats" then
        return player.leaderstats
    end
    return nil
end, {"dataType", "string"})
```

## Parameter Validation

Parameter lists follow the pattern: `{name, type, name, type, ...}`

**Supported Types:**
- Basic: `string`, `number`, `boolean`, `table`
- Optional: `string?`, `number?` (append ?)
- Union: `string|number`, `table|string`
- Special: `integer`, `any`
- Range: `range[min,max]` for numbers

```lua
-- Complex validation example
{"action", "string", "target", "string|number", "data", "table?", "priority", "range[1,5]"}
```

## Middleware

Middleware functions execute before the main callback and can block requests:

```lua
local function rateLimitMiddleware(player, logIndex, remoteObject, ...)
    local key = `{player.UserId}_{remoteObject.Name}`
    local lastRequest = requestTimes[key] or 0
    local currentTime = os.time()
    
    if currentTime - lastRequest < 2 then
        return false -- Block rapid requests
    end
    
    requestTimes[key] = currentTime
    return true
end

EventBroker.AddMiddleware(tradingRemote, rateLimitMiddleware)
```

Multiple middleware can be chained per remote. Execution stops if any middleware returns false.

## Data Retrieval

```lua
-- Get all logs
local allLogs = EventBroker.RetrieveLogs()

-- Filter by player
local playerLogs = EventBroker.RetrieveLogsBySender(123456)

-- Filter by time range  
local recentLogs = EventBroker.RetrieveLogsByTimeRange(os.time() - 3600, os.time())

-- Get problematic events
local errorLogs = EventBroker.RetrieveLogsWithInfoCount(1)

-- System statistics
local stats = EventBroker.GetStatistics()
print(`Total events: {stats.totalLogs}, Errors: {stats.errorLogs}`)
```

## Validation Helpers

```lua
EventBroker.RegisterRemoteEvent(actionRemote, function(player, logIndex, action, target)
    local validActions = {"move", "attack", "defend"}
    
    if not EventBroker.AssertInList(logIndex, action, validActions) then
        return
    end
    
    if not EventBroker.AssertStringPattern(logIndex, target, "^%d+$") then
        return
    end
    
    executeAction(player, action, target)
end, {"action", "string", "target", "string"})
```

## Advanced Usage

### Security Layers

```lua
local tradingRemote = game.ReplicatedStorage.Trading

-- Layer 1: Permission check
EventBroker.AddMiddleware(tradingRemote, function(player, logIndex, remoteObject, ...)
    return player.leaderstats.Level.Value >= 10
end)

-- Layer 2: Rate limiting
EventBroker.AddMiddleware(tradingRemote, function(player, logIndex, remoteObject, ...)
    return checkCooldown(player.UserId, 30)
end)

-- Layer 3: Data validation  
EventBroker.AddMiddleware(tradingRemote, function(player, logIndex, remoteObject, action, items)
    return typeof(items) == "table" and #items > 0
end)

EventBroker.RegisterRemoteFunction(tradingRemote, function(player, logIndex, action, items)
    return processTrade(player, action, items)
end, {"action", "string", "items", "table"})
```

### Dynamic Control

```lua
local featureFlags = {
    betaFeatures = false,
    maintenanceMode = false
}

local featureGate = function(player, logIndex, remoteObject, ...)
    if featureFlags.maintenanceMode then
        return false
    end
    
    if remoteObject.Name:find("Beta") and not featureFlags.betaFeatures then
        return isTestUser(player.UserId)
    end
    
    return true
end

-- Apply to multiple remotes
for _, remote in betaRemotes do
    EventBroker.AddMiddleware(remote, featureGate)
end
```

### Error Monitoring

```lua
-- Check for suspicious activity
local function monitorErrors()
    local errorLogs = EventBroker.RetrieveLogsWithInfoCount(3)
    
    for _, log in errorLogs do
        local player = game.Players:GetPlayerByUserId(log.Sender)
        if player then
            warn(`Suspicious activity from {player.Name}: {#log.EventLogs} issues`)
        end
    end
end

game:GetService("RunService").Heartbeat:Connect(monitorErrors)
```

## Performance Notes

EventBroker is optimized for production use:

- Automatic log rotation prevents memory growth
- Rate limiting protects against spam attacks  
- Parameter validation happens before callback execution
- Middleware only runs for registered remotes

The circular buffer maintains constant memory usage regardless of server uptime.

## Troubleshooting

**High error counts**: Check parameter validation and ensure clients send correct data types.

**Memory usage**: Reduce `maxLogCount` or increase `cleanupInterval` for lower memory footprint.

**Performance issues**: Profile middleware functions and minimize expensive operations in validation.

Enable debug mode temporarily to monitor cleanup behavior:
```lua
EventBroker.Configure({ debuggingMode = true })
```
