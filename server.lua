-- NERD HUD - server
-- (c) 2026 Nerd. All rights reserved.

local QBCore = exports['qb-core']:GetCoreObject()


local function isJobWhitelisted(player)
    if not player or not player.PlayerData or not player.PlayerData.job then return false end
    local jobName = player.PlayerData.job.name
    local jobType = player.PlayerData.job.type
    for name, t in pairs(Config.WhitelistedJobs or {}) do
        if name == jobName then return true end
        if t and t == jobType then return true end
    end
    return false
end

local function setStress(src, value)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if value < 0   then value = 0   end
    if value > 100 then value = 100 end
    Player.Functions.SetMetaData('stress', value)
    TriggerClientEvent('hud:client:UpdateStress', src, value)
end


RegisterNetEvent('hud:server:GainStress', function(amount)
    if Config.DisableStress then return end
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if isJobWhitelisted(Player) then return end

    local current = Player.PlayerData.metadata['stress'] or 0
    setStress(src, current + (tonumber(amount) or 0))
end)

RegisterNetEvent('hud:server:RelieveStress', function(amount)
    if Config.DisableStress then return end
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local current = Player.PlayerData.metadata['stress'] or 0
    setStress(src, current - (tonumber(amount) or 0))
end)


-- restore stress (and seed if first join) when the player loads
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not Player.PlayerData.metadata['stress'] then
        Player.Functions.SetMetaData('stress', 0)
    end
    TriggerClientEvent('hud:client:UpdateStress', src, Player.PlayerData.metadata['stress'] or 0)
end)


QBCore.Functions.CreateCallback('nerd-hud:server:getStress', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(0) end
    cb(Player.PlayerData.metadata['stress'] or 0)
end)


-- HUD settings persistence (QBCore metadata).
-- the client keeps a local KVP copy for fast offline reload, but the
-- server copy is what wins on rejoin so prefs follow the player.

RegisterNetEvent('nerd-hud:server:saveSettings', function(payload)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if type(payload) ~= 'table' then return end
    Player.Functions.SetMetaData('nerdHudSettings', payload)
end)

QBCore.Functions.CreateCallback('nerd-hud:server:getSettings', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(nil) end
    cb(Player.PlayerData.metadata['nerdHudSettings'])
end)
