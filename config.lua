Config = {}

-- Define item rewards and their possible quantity range
Config.ItemRewards = {
    { name = "anchovy", minQuantity = 2, maxQuantity = 5 },
    { name = "trout", minQuantity = 2, maxQuantity = 5 },
    -- Add more items as needed
}

-- Define money reward range
Config.MoneyReward = {
    minAmount = 100,
    maxAmount = 1000
}

-- Rate limiting configuration (in seconds)
Config.RateLimitCooldown = 5 -- Minimum time between reward check requests (rate limit) per player

-- Lock timeout configuration (in seconds)
Config.LockTimeout = 60 -- Time before a stuck lock is automatically cleared

-- Timezone configuration (use UTC for consistency)
Config.UseUTC = true -- Set to true to use UTC timezone for daily reset

-- Logging configuration
Config.EnableLogging = true -- Enable server-side logging for debugging
Config.LogExploitAttempts = true -- Log potential exploitation attempts
