--!strict
--[[
	RateLimiter: a small token-bucket limiter.

	Each key (usually a Player) gets a bucket of `capacity` tokens.
	Every allowed request spends one token; tokens come back at
	`refillPerSecond`. Use it on the server to ignore remote spam.

	local limiter = RateLimiter.new(5, 5) -- bursts of 5, then 5 per second
	if not limiter:allow(player) then return end
]]

type Bucket = { tokens: number, updatedAt: number }

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable(
	{} :: {
		_capacity: number,
		_refillPerSecond: number,
		_clock: () -> number,
		_buckets: { [any]: Bucket },
	},
	RateLimiter
))

-- `clock` is optional and only there so the module can be tested without waiting.
function RateLimiter.new(capacity: number, refillPerSecond: number, clock: (() -> number)?): RateLimiter
	assert(capacity >= 1, "capacity must be at least 1")
	assert(refillPerSecond > 0, "refillPerSecond must be positive")
	return setmetatable({
		_capacity = capacity,
		_refillPerSecond = refillPerSecond,
		_clock = clock or os.clock,
		_buckets = {},
	}, RateLimiter)
end

-- Returns true and spends a token if the key is under its limit.
function RateLimiter.allow(self: RateLimiter, key: any): boolean
	local now = self._clock()
	local bucket = self._buckets[key]
	if not bucket then
		bucket = { tokens = self._capacity, updatedAt = now }
		self._buckets[key] = bucket
	end

	local refilled = bucket.tokens + (now - bucket.updatedAt) * self._refillPerSecond
	bucket.tokens = math.min(self._capacity, refilled)
	bucket.updatedAt = now

	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

-- Call when a player leaves so their bucket does not stay in memory.
function RateLimiter.forget(self: RateLimiter, key: any)
	self._buckets[key] = nil
end

return RateLimiter
