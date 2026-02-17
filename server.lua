
local QBCore = exports['qb-core']:GetCoreObject()
-- Include the configuration file

--Config = {}
--local Config = {}
--Config.MinReward = 1000  -- Minimum reward amount
--Config.MaxReward = 3000  -- Maximum reward amount
--Config = require('config')

local function givePlayerReward(playerId, source, rewardType, rewardValue)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if xPlayer then
        if rewardType == 'money' then
            xPlayer.Functions.AddMoney('bank', rewardValue)
            TriggerClientEvent('QBCore:Notify', source, 'You have received $'..rewardValue..' as a reward!', 'success')
        else -- rewardType is 'item'
            xPlayer.Functions.AddItem(rewardType, rewardValue)
            TriggerClientEvent('QBCore:Notify', source, 'You have received '..rewardValue..' '..rewardType..' as a reward!', 'success')
        end
    end
end

local function isNextDay(lastRewardDate)
    local lastReward = os.date('*t', lastRewardDate)
    local today = os.date('*t', os.time())

    return (today.year > lastReward.year) or (today.year == lastReward.year and today.yday > lastReward.yday)
end

local function checkPlayerInDatabase(playerId, playerName, source)
    MySQL.Async.fetchScalar('SELECT UNIX_TIMESTAMP(date) FROM player_reward WHERE id = @id', {
        ['@id'] = playerId
    }, function(lastRewardDate)
        if lastRewardDate and not isNextDay(lastRewardDate) then
            TriggerClientEvent('QBCore:Notify', source, 'You have already received your reward today. Come back tomorrow!', 'error')
        else
            local rewardType
            local rewardValue
            local rewardData
            if math.random(2) == 1 then
                -- Give money
                rewardType = 'money'
                rewardValue = math.random(Config.MoneyReward.minAmount, Config.MoneyReward.maxAmount) -- Use configured values for money
                rewardData = "money: " .. tostring(rewardValue)
            else
                -- Give item
                local selectedItem = Config.ItemRewards[math.random(#Config.ItemRewards)]
                rewardType = selectedItem.name
                rewardValue = math.random(selectedItem.minQuantity, selectedItem.maxQuantity)
                rewardData = rewardType .. ": " .. tostring(rewardValue)
            end

            MySQL.Async.execute('INSERT INTO player_reward (id, name, reward, flag, date) VALUES (@id, @name, @reward, @flag, NOW()) ON DUPLICATE KEY UPDATE reward = @reward, date = NOW(), flag = flag + 1', {
                ['@id'] = playerId,
                ['@name'] = playerName,
                ['@reward'] = rewardData,
                ['@flag'] = 1 -- for checking and detecting inject
            }, function(rowsChanged)
                givePlayerReward(playerId, source, rewardType, rewardValue)
            end)
        end
    end)
end
--[[
RegisterCommand('rewards', function(source, args, rawCommand)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    local playerId = xPlayer.PlayerData.citizenid
    local playerName = xPlayer.PlayerData.name

    checkPlayerInDatabase(playerId, playerName, source)
end, false)
--]]
-- Registering a new server event
RegisterNetEvent('login_reward:triggerCheck')
AddEventHandler('login_reward:triggerCheck', function()
    local playerId = source  -- 'source' is the player's server ID in FiveM
    local xPlayer = QBCore.Functions.GetPlayer(playerId)
    if xPlayer then
        local citizenId = xPlayer.PlayerData.citizenid
        local playerName = xPlayer.PlayerData.name

        checkPlayerInDatabase(citizenId, playerName, playerId)
    end
end)