--!strict

local RateLimit = {}
RateLimit.__index = RateLimit
export type RateLimit = {
	config: any,
	playerRateLimits: {[number]: {count: number, resetTime: number}},
} & typeof(RateLimit)


RateLimit.New = function(config: any): RateLimit
	return setmetatable({
		config = config,
		playerRateLimits = {}
	}, RateLimit) :: RateLimit
end

function RateLimit.CheckRateLimit(self: RateLimit, pUserId: number): boolean
	local currentTime = os.time()
	local playerLimit = self.playerRateLimits[pUserId]

	if not playerLimit or currentTime >= playerLimit.resetTime then
		self.playerRateLimits[pUserId] = {
			count = 1,
			resetTime = currentTime + self.config.rateLimitWindow
		}
		return false -- Not rate limited
	end

	playerLimit.count += 1

	if playerLimit.count > self.config.rateLimitMaxRequests then
		return true -- Rate limited
	end

	return false -- Not rate limited
end

function RateLimit.GetRateLimitStats(self: RateLimit): {rateLimitedUsers: number}
	local stats = { rateLimitedUsers = 0 }
	local currentTime = os.time()

	for userId, limit in self.playerRateLimits do
		if currentTime < limit.resetTime and limit.count > self.config.rateLimitMaxRequests then
			stats.rateLimitedUsers += 1
		end
	end

	return stats
end

return RateLimit