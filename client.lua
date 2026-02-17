local QBCore = exports['qb-core']:GetCoreObject()

-- Triggering the server event from the client
RegisterNetEvent('login_reward:triggerCheckOnServer')
AddEventHandler('login_reward:triggerCheckOnServer', function()
    TriggerServerEvent('login_reward:triggerCheck')
end)
--[[ You can trigger this event in various ways, for example, via a command:
RegisterCommand("claimreward", function()
    TriggerEvent('login_reward:triggerCheckOnServer')
end, false)
--]]