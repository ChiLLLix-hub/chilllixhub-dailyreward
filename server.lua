
local QBCore = exports['qb-core']:GetCoreObject()

-- Rate limiting and race condition protection
local playerCooldowns = {} -- Track last request time per player
local playerLocks = {} -- Mutex locks to prevent race conditions

-- Validate configuration on resource start
local function validateConfig()
    if not Config then
        print('^1[LoginReward] ERROR: Config not found!^0')
        return false
    end
    
    if not Config.ItemRewards or #Config.ItemRewards == 0 then
        print('^1[LoginReward] ERROR: Config.ItemRewards is empty!^0')
        return false
    end
    
    if not Config.MoneyReward or not Config.MoneyReward.minAmount or not Config.MoneyReward.maxAmount then
        print('^1[LoginReward] ERROR: Config.MoneyReward is invalid!^0')
        return false
    end
    
    if Config.MoneyReward.minAmount > Config.MoneyReward.maxAmount then
        print('^1[LoginReward] ERROR: MoneyReward minAmount is greater than maxAmount!^0')
        return false
    end
    
    if Config.MoneyReward.minAmount < 0 or Config.MoneyReward.maxAmount < 0 then
        print('^1[LoginReward] ERROR: MoneyReward amounts must be positive!^0')
        return false
    end
    
    for _, item in ipairs(Config.ItemRewards) do
        if not item.name or not item.minQuantity or not item.maxQuantity then
            print('^1[LoginReward] ERROR: Invalid item configuration!^0')
            return false
        end
        if item.minQuantity > item.maxQuantity then
            print('^1[LoginReward] ERROR: Item '..item.name..' minQuantity is greater than maxQuantity!^0')
            return false
        end
    end
    
    print('^2[LoginReward] Configuration validated successfully!^0')
    return true
end

-- Server-side logging function
local function logEvent(playerId, playerName, eventType, message)
    if Config.EnableLogging then
        print(string.format('[LoginReward] [%s] Player: %s (%s) - %s', eventType, playerName or 'Unknown', playerId or 'Unknown', message))
    end
end

-- Give reward to player with validation
local function givePlayerReward(playerId, source, rewardType, rewardValue)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    
    if not xPlayer then
        logEvent(playerId, nil, 'ERROR', 'Player object not found when giving reward')
        return false
    end
    
    if rewardType == 'money' then
        if type(rewardValue) ~= 'number' or rewardValue <= 0 then
            logEvent(playerId, xPlayer.PlayerData.name, 'ERROR', 'Invalid money reward value: '..tostring(rewardValue))
            return false
        end
        
        xPlayer.Functions.AddMoney('bank', rewardValue)
        TriggerClientEvent('QBCore:Notify', source, 'You have received $'..rewardValue..' as a daily reward!', 'success')
        logEvent(playerId, xPlayer.PlayerData.name, 'SUCCESS', 'Received money reward: $'..rewardValue)
        return true
    else
        -- Validate item exists (basic check)
        if type(rewardValue) ~= 'number' or rewardValue <= 0 then
            logEvent(playerId, xPlayer.PlayerData.name, 'ERROR', 'Invalid item reward quantity: '..tostring(rewardValue))
            return false
        end
        
        -- Check if item exists in QBCore shared items
        local itemData = QBCore.Shared.Items[rewardType]
        if not itemData then
            logEvent(playerId, xPlayer.PlayerData.name, 'ERROR', 'Item does not exist: '..rewardType)
            TriggerClientEvent('QBCore:Notify', source, 'Error: Invalid reward item!', 'error')
            return false
        end
        
        xPlayer.Functions.AddItem(rewardType, rewardValue)
        TriggerClientEvent('QBCore:Notify', source, 'You have received '..rewardValue..' '..itemData.label..' as a daily reward!', 'success')
        logEvent(playerId, xPlayer.PlayerData.name, 'SUCCESS', 'Received item reward: '..rewardValue..' '..rewardType)
        return true
    end
end

-- Check if it's a new day using UTC timezone
local function isNextDay(lastRewardDate)
    if not lastRewardDate or type(lastRewardDate) ~= 'number' then
        return true
    end
    
    local lastReward, today
    
    if Config.UseUTC then
        lastReward = os.date('!*t', lastRewardDate)
        today = os.date('!*t', os.time())
    else
        lastReward = os.date('*t', lastRewardDate)
        today = os.date('*t', os.time())
    end
    
    return (today.year > lastReward.year) or (today.year == lastReward.year and today.yday > lastReward.yday)
end

-- Calculate time until next reward
local function getTimeUntilNextReward(lastRewardDate)
    if not lastRewardDate or type(lastRewardDate) ~= 'number' then
        return 0
    end
    
    local currentTime = os.time()
    local nextMidnight
    
    if Config.UseUTC then
        -- Get current UTC time
        local utcNow = os.date('!*t', currentTime)
        
        -- Calculate next UTC midnight (in UTC time)
        local utcMidnightToday = os.time({
            year = utcNow.year,
            month = utcNow.month,
            day = utcNow.day,
            hour = 0,
            min = 0,
            sec = 0
        })
        
        -- Get UTC offset (UTC time - local time)
        local utcOffset = os.difftime(os.time(os.date("!*t", currentTime)), os.time(os.date("*t", currentTime)))
        
        -- Calculate next midnight in UTC (adjusted for local server time)
        nextMidnight = utcMidnightToday + 86400 + utcOffset
    else
        -- Use local time
        local now = os.date('*t', currentTime)
        nextMidnight = os.time({
            year = now.year,
            month = now.month,
            day = now.day,
            hour = 0,
            min = 0,
            sec = 0
        }) + 86400 -- Add one day
    end
    
    local secondsUntilMidnight = nextMidnight - currentTime
    return math.max(0, secondsUntilMidnight)
end

-- Format time for display
local function formatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    return string.format('%dh %dm', hours, minutes)
end

-- Main function to check and give reward
local function checkPlayerInDatabase(playerId, playerName, source)
    -- Race condition protection: Check if already processing
    if playerLocks[playerId] then
        logEvent(playerId, playerName, 'BLOCKED', 'Already processing reward request (race condition prevented)')
        TriggerClientEvent('QBCore:Notify', source, 'Please wait, processing your request...', 'info')
        return
    end
    
    -- Set lock with timestamp
    playerLocks[playerId] = os.time()
    
    -- Wrap in pcall for error handling
    local success, err = pcall(function()
        MySQL.Async.fetchScalar('SELECT UNIX_TIMESTAMP(date) FROM player_reward WHERE id = @id', {
            ['@id'] = playerId
        }, function(lastRewardDate)
            if not lastRewardDate then
                logEvent(playerId, playerName, 'INFO', 'First time claiming reward')
            end
            
            if lastRewardDate and not isNextDay(lastRewardDate) then
                -- Release lock
                playerLocks[playerId] = nil
                
                local timeRemaining = getTimeUntilNextReward(lastRewardDate)
                local timeFormatted = formatTime(timeRemaining)
                TriggerClientEvent('QBCore:Notify', source, 'You have already received your reward today. Come back in '..timeFormatted..'!', 'error')
                logEvent(playerId, playerName, 'REJECTED', 'Already claimed today. Time remaining: '..timeFormatted)
                return
            end
            
            -- Select random reward
            local rewardType, rewardValue, rewardData
            
            if math.random(2) == 1 then
                -- Give money
                rewardType = 'money'
                rewardValue = math.random(Config.MoneyReward.minAmount, Config.MoneyReward.maxAmount)
                rewardData = "money: " .. tostring(rewardValue)
            else
                -- Give item
                local selectedItem = Config.ItemRewards[math.random(#Config.ItemRewards)]
                rewardType = selectedItem.name
                rewardValue = math.random(selectedItem.minQuantity, selectedItem.maxQuantity)
                rewardData = rewardType .. ": " .. tostring(rewardValue)
            end
            
            -- Update database
            MySQL.Async.execute('INSERT INTO player_reward (id, name, reward, flag, date) VALUES (@id, @name, @reward, @flag, NOW()) ON DUPLICATE KEY UPDATE reward = @reward, date = NOW(), flag = flag + 1', {
                ['@id'] = playerId,
                ['@name'] = playerName,
                ['@reward'] = rewardData,
                ['@flag'] = 1 -- Login counter (incremented on each reward claim)
            }, function(rowsChanged)
                -- Release lock after completion
                playerLocks[playerId] = nil
                
                if rowsChanged and rowsChanged > 0 then
                    givePlayerReward(playerId, source, rewardType, rewardValue)
                else
                    logEvent(playerId, playerName, 'ERROR', 'Database update failed')
                    TriggerClientEvent('QBCore:Notify', source, 'Error updating reward data. Please contact an administrator.', 'error')
                end
            end)
        end)
    end)
    
    if not success then
        -- Release lock on error
        playerLocks[playerId] = nil
        logEvent(playerId, playerName, 'ERROR', 'Exception occurred: '..tostring(err))
        TriggerClientEvent('QBCore:Notify', source, 'An error occurred. Please contact an administrator.', 'error')
    end
end

-- Server event handler with rate limiting
RegisterNetEvent('login_reward:checkReward', function()
    local source = source
    local xPlayer = QBCore.Functions.GetPlayer(source)
    
    -- Validate player exists
    if not xPlayer then
        logEvent(nil, nil, 'ERROR', 'Player object not found for source: '..tostring(source))
        return
    end
    
    local citizenId = xPlayer.PlayerData.citizenid
    local playerName = xPlayer.PlayerData.name
    
    -- Validate player data
    if not citizenId or not playerName then
        logEvent(nil, playerName or 'Unknown', 'ERROR', 'Invalid player data')
        return
    end
    
    -- Rate limiting check
    local currentTime = os.time()
    local lastRequestTime = playerCooldowns[citizenId] or 0
    local timeSinceLastRequest = currentTime - lastRequestTime
    local rateLimitCooldown = Config.RateLimitCooldown or 5
    
    if timeSinceLastRequest < rateLimitCooldown then
        local remainingCooldown = rateLimitCooldown - timeSinceLastRequest
        TriggerClientEvent('QBCore:Notify', source, 'Please wait '..remainingCooldown..' seconds before trying again.', 'error')
        
        if Config.LogExploitAttempts then
            logEvent(citizenId, playerName, 'EXPLOIT', 'Rate limit triggered. Time since last request: '..timeSinceLastRequest..'s')
        end
        return
    end
    
    -- Update cooldown timestamp
    playerCooldowns[citizenId] = currentTime
    
    -- Process reward check
    checkPlayerInDatabase(citizenId, playerName, source)
end)

-- Clean up cooldowns and locks periodically (every 5 minutes)
CreateThread(function()
    while true do
        Wait(300000) -- 5 minutes
        local currentTime = os.time()
        local lockTimeout = Config.LockTimeout or 60
        
        -- Clean up old cooldowns (older than 1 hour)
        for playerId, timestamp in pairs(playerCooldowns) do
            if currentTime - timestamp > 3600 then
                playerCooldowns[playerId] = nil
            end
        end
        
        -- Clean up stuck locks (older than configured timeout)
        for playerId, lockTime in pairs(playerLocks) do
            if type(lockTime) == 'number' and currentTime - lockTime > lockTimeout then
                playerLocks[playerId] = nil
                logEvent(playerId, nil, 'WARNING', 'Cleared stuck lock after '..lockTimeout..' seconds')
            end
        end
    end
end)

-- Validate configuration on resource start
CreateThread(function()
    if not validateConfig() then
        print('^1[LoginReward] Resource will not function properly due to configuration errors!^0')
    end
end)