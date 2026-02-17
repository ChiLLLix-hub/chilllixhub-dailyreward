local QBCore = exports['qb-core']:GetCoreObject()

-- Automatically trigger reward check on player login
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    -- Wait a short time to ensure player data is fully loaded
    Wait(1000)
    TriggerServerEvent('login_reward:checkReward')
end)