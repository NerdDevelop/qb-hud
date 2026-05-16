-- NERD HUD - client
-- (c) 2026 Nerd. All rights reserved.

local hudVisible, settingsOpen = true, false
local playerHunger, playerThirst = 100, 100
local playerStress = 0
local currentVoiceMode = 2  -- 1=whisper, 2=normal, 3=shout
local wasInVehicle, wasParachuteOn = false, false
local wasSeatbeltOn = true
local seatbeltOn = false
local minimapMode = (Config and Config.MinimapMode) or 'vehicle'


local function SafeNUI(data) SendNUIMessage(data) end

local function GetStreetAndZone(coords)
    local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = GetStreetNameFromHashKey(streetHash) or 'UNKNOWN'
    local zone   = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z)) or 'UNKNOWN'
    return street:upper(), zone:upper()
end

local function HeadingToDegrees(h)
    return math.floor((360 - h) % 360)
end


-- minimap setup. square-map ratio fix from Dalrae (qb-hud)
local function SetupMinimap()
    Wait(50)

    local defaultAspect = 1920 / 1080
    local rx, ry = GetActiveScreenResolution()
    local offset = 0
    if (rx / ry) > defaultAspect then
        offset = ((defaultAspect - (rx / ry)) / 3.6) - 0.008
    end

    RequestStreamedTextureDict('squaremap', false)
    if not HasStreamedTextureDictLoaded('squaremap') then Wait(150) end

    SetMinimapClipType(0)
    AddReplaceTexture('platform:/textures/graphics', 'radarmasksm', 'squaremap', 'radarmasksm')
    AddReplaceTexture('platform:/textures/graphics', 'radarmask1g', 'squaremap', 'radarmasksm')

    SetMinimapComponentPosition('minimap',      'L', 'B', 0.0 + offset, -0.047, 0.1638, 0.183)
    SetMinimapComponentPosition('minimap_mask', 'L', 'B', 0.0 + offset, 0.0,    0.128,  0.20)
    SetMinimapComponentPosition('minimap_blur', 'L', 'B', -0.01 + offset, 0.025, 0.262, 0.300)

    SetBlipAlpha(GetNorthRadarBlip(), 0)

    -- bigmap toggle forces the swap to take
    SetBigmapActive(true, false)
    SetMinimapClipType(0)
    Wait(50)
    SetBigmapActive(false, false)
end

CreateThread(function()
    Wait(500)
    SetupMinimap()
    DisplayRadar(false)
end)

CreateThread(function()
    while true do
        SetBigmapActive(false, false)
        SetRadarZoom(1000)
        Wait(500)
    end
end)

AddEventHandler('playerSpawned', function()
    Wait(500)
    SetupMinimap()
end)


-- 'vehicle' = radar only when driving, 'always' = radar always on
local function applyRadarVisibility(force)
    if Config.Elements and Config.Elements.minimap == false then
        DisplayRadar(false)
        wasInVehicle = false
        return
    end
    if minimapMode == 'always' then
        DisplayRadar(true)
        wasInVehicle = true
        return
    end
    local inVeh = IsPedInAnyVehicle(PlayerPedId(), false)
    if force or inVeh ~= wasInVehicle then
        DisplayRadar(inVeh)
        wasInVehicle = inVeh
    end
end

CreateThread(function()
    while true do
        applyRadarVisibility(false)
        Wait(250)
    end
end)


-- local KVP load. server-side copy comes later in OnPlayerLoaded and overrides.
CreateThread(function()
    Wait(800)
    local saved = GetResourceKvpString('nerd-hud-settings')
    if not saved then return end

    local decoded = json.decode(saved) or {}
    local panelAllows = not (Config.SettingsPanel and Config.SettingsPanel.minimapMode == false)
    if panelAllows and (decoded.minimapMode == 'always' or decoded.minimapMode == 'vehicle') then
        minimapMode = decoded.minimapMode
        applyRadarVisibility(true)
    end
    SafeNUI({ action = 'load-settings', settings = decoded })
end)


CreateThread(function()
    while true do
        if hudVisible then
            local ped    = PlayerPedId()
            local player = PlayerId()

            local health  = math.max(0, GetEntityHealth(ped) - 100)
            local armor   = GetPedArmour(ped)
            local stamina = 100 - GetPlayerSprintStaminaRemaining(player)
            local oxygen  = math.floor(GetPlayerUnderwaterTimeRemaining(player) * 10)

            if Config.HungerThirstSource == 'qb-core' then
                local QBCore = exports['qb-core'] and exports['qb-core']:GetCoreObject()
                if QBCore then
                    local data = QBCore.Functions.GetPlayerData()
                    if data and data.metadata then
                        playerHunger = data.metadata.hunger or 100
                        playerThirst = data.metadata.thirst or 100
                    end
                end
            elseif Config.HungerThirstSource == 'esx' then
                local ESX = exports.es_extended and exports.es_extended:getSharedObject()
                if ESX then
                    local data = ESX.GetPlayerData()
                    if data and data.metadata then
                        playerHunger = data.metadata.hunger or 100
                        playerThirst = data.metadata.thirst or 100
                    end
                end
            end

            SafeNUI({
                action  = 'update-stats',
                health  = health,
                armor   = armor,
                hunger  = playerHunger,
                thirst  = playerThirst,
                stamina = stamina,
                oxygen  = oxygen,
                isUnderwater = IsPedSwimmingUnderWater(ped),
            })
        end
        Wait(Config.UpdateRate)
    end
end)


CreateThread(function()
    while true do
        if hudVisible then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)

            if veh ~= 0 then
                local speed  = GetEntitySpeed(veh) * (Config.UseMPH and 2.236936 or 3.6)
                local fuel   = GetVehicleFuelLevel(veh)
                local engine = math.max(0, math.min(100, GetVehicleEngineHealth(veh) / 10))

                -- GTA doesn't reset currentGear when you stop from a forward gear -
                -- it sticks at the last drive gear (e.g. 1). So P is judged on speed
                -- alone, R only when gear==0 AND the car is actually moving.
                local currentGear = GetVehicleCurrentGear(veh)
                local gearLabel
                if speed < 1 then
                    gearLabel = 'P'
                elseif currentGear == 0 then
                    gearLabel = 'R'
                else
                    gearLabel = 'D' .. currentGear
                end

                SafeNUI({
                    action    = 'update-vehicle',
                    inVehicle = true,
                    speed     = math.floor(speed),
                    fuel      = math.floor(fuel),
                    engine    = math.floor(engine),
                    seatbelt  = seatbeltOn,
                    gear      = gearLabel,
                })
            else
                SafeNUI({ action = 'update-vehicle', inVehicle = false })
            end
        end
        Wait(Config.VehicleRate)
    end
end)


CreateThread(function()
    while true do
        if hudVisible then
            local ped    = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local street, zone = GetStreetAndZone(coords)

            SafeNUI({
                action  = 'update-compass',
                heading = HeadingToDegrees(GetEntityHeading(ped)),
                street  = street,
                zone    = zone,
            })
        end
        Wait(Config.CompassRate)
    end
end)


-- pma-voice integration
if Config.VoiceSystem == 'pma-voice' then
    AddEventHandler('pma-voice:setTalkingMode', function(mode)
        currentVoiceMode = mode
        SafeNUI({ action = 'update-mic', on = true, mode = mode })
    end)

    -- initial mode after join
    CreateThread(function()
        Wait(2000)
        local proximity = LocalPlayer.state.proximity
        if proximity and proximity.index then
            currentVoiceMode = proximity.index
        end
        SafeNUI({ action = 'update-mic', on = true, mode = currentVoiceMode })
    end)

    AddStateBagChangeHandler('proximity', ('player:%s'):format(GetPlayerServerId(PlayerId())), function(_, _, value)
        if value and value.index then
            currentVoiceMode = value.index
            SafeNUI({ action = 'update-mic', on = true, mode = currentVoiceMode })
        end
    end)

    CreateThread(function()
        local lastTalking = false
        while true do
            if hudVisible then
                local talking = NetworkIsPlayerTalking(PlayerId())
                if talking ~= lastTalking then
                    SafeNUI({ action = 'update-mic-talking', talking = talking })
                    lastTalking = talking
                end
            end
            Wait(150)
        end
    end)

    AddEventHandler('pma-voice:radioActive', function(active)
        SafeNUI({ action = 'update-mic-radio', active = active })
    end)
end

-- fallback for non-pma-voice setups
RegisterNetEvent('nerd-hud:setMic', function(on, mode)
    SafeNUI({ action = 'update-mic', on = on, mode = mode or 2 })
end)


-- stress: up from speeding/shooting/damage, down from smoking
local isSmoking = false
local QBCoreStress = exports['qb-core'] and exports['qb-core']:GetCoreObject() or nil

local function isJobWhitelisted()
    if not QBCoreStress then return false end
    local data = QBCoreStress.Functions.GetPlayerData()
    if not data or not data.job then return false end
    for name, t in pairs(Config.WhitelistedJobs or {}) do
        if name == data.job.name then return true end
        if t and t == data.job.type then return true end
    end
    return false
end

local function gainStress(amount)
    if Config.DisableStress then return end
    if isJobWhitelisted() then return end
    TriggerServerEvent('hud:server:GainStress', amount)
end

local function relieveStress(amount)
    if Config.DisableStress then return end
    TriggerServerEvent('hud:server:RelieveStress', amount)
end

if not Config.DisableStress then
    -- speeding
    CreateThread(function()
        while true do
            if not isSmoking and playerStress < 100 then
                local ped = PlayerPedId()
                local veh = GetVehiclePedIsIn(ped, false)
                if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
                    local vehClass = GetVehicleClass(veh)
                    local vehHash  = GetEntityModel(veh)
                    if Config.VehClassStress[tostring(vehClass)]
                       and not Config.WhitelistedVehicles[vehHash] then
                        local speed = GetEntitySpeed(veh) * 3.6
                        local threshold
                        if vehClass == 8 then  -- bikes: no seatbelt to worry about
                            threshold = Config.StressMinSpeed or 100
                        else
                            threshold = seatbeltOn and (Config.StressMinSpeed or 100)
                                                   or (Config.StressMinSpeedUnbuckled or 80)
                        end
                        if speed >= threshold then
                            gainStress(math.random(1, 3))
                        end
                    end
                end
            end
            Wait(10000)
        end
    end)

    -- shooting
    CreateThread(function()
        while true do
            local wait = 1500
            if not isSmoking and playerStress < 100 then
                local ped = PlayerPedId()
                local weapon = GetSelectedPedWeapon(ped)
                if weapon ~= `WEAPON_UNARMED`
                   and not Config.WhitelistedWeaponStress[weapon] then
                    if IsPedShooting(ped) and math.random() < (Config.StressShootChance or 0.10) then
                        gainStress(math.random(1, 3))
                    end
                else
                    wait = 1000
                end
            end
            Wait(wait)
        end
    end)

    -- taking damage
    AddEventHandler('gameEventTriggered', function(event, data)
        if event ~= 'CEventNetworkEntityDamage' then return end
        if data[1] == PlayerPedId() and not isSmoking then
            gainStress(math.random(2, 4))
        end
    end)
end

-- smoking calms it down
RegisterNetEvent('nerd-hud:smokingStart', function()
    isSmoking = true
    LocalPlayer.state:set('smoking', true, false)
    CreateThread(function()
        while isSmoking and playerStress > 0 do
            relieveStress(Config.SmokeRelief or 5)
            Wait(Config.SmokeInterval or 1500)
        end
    end)
end)

RegisterNetEvent('nerd-hud:smokingStop', function()
    isSmoking = false
    LocalPlayer.state:set('smoking', false, false)
end)

RegisterNetEvent('hud:client:UpdateStress', function(newStress)
    playerStress = math.max(0, math.min(100, newStress or 0))
    SafeNUI({ action = 'update-stress', value = playerStress })
end)

-- legacy aliases kept around so older scripts keep working
RegisterNetEvent('hud:client:GainStress',    function(amount) gainStress(amount or 5)    end)
RegisterNetEvent('hud:client:RelieveStress', function(amount) relieveStress(amount or 5) end)

-- qb-smokes auto-hook
RegisterNetEvent('qb-smokes:client:lightCigarette', function() TriggerEvent('nerd-hud:smokingStart') end)
RegisterNetEvent('qb-smokes:client:stopSmoking',    function() TriggerEvent('nerd-hud:smokingStop')  end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Wait(500)
    if not QBCoreStress then return end

    local data = QBCoreStress.Functions.GetPlayerData()
    if data and data.metadata and data.metadata.stress then
        playerStress = data.metadata.stress
        SafeNUI({ action = 'update-stress', value = playerStress })
    end

    -- server-side settings (QBCore metadata) win over local KVP so prefs
    -- follow the player across machines and server restarts
    QBCoreStress.Functions.TriggerCallback('nerd-hud:server:getSettings', function(serverSettings)
        if type(serverSettings) ~= 'table' or next(serverSettings) == nil then return end

        local panelAllows = not (Config.SettingsPanel and Config.SettingsPanel.minimapMode == false)
        if panelAllows and (serverSettings.minimapMode == 'always' or serverSettings.minimapMode == 'vehicle') then
            minimapMode = serverSettings.minimapMode
            applyRadarVisibility(true)
        end

        SetResourceKvp('nerd-hud-settings', json.encode(serverSettings))
        SafeNUI({ action = 'load-settings', settings = serverSettings })
    end)
end)


local function getBlurIntensity(level)
    for _, v in pairs(Config.StressIntensity or {}) do
        if level >= v.min and level <= v.max then return v.intensity end
    end
    return 1500
end

local function getEffectInterval(level)
    for _, v in pairs(Config.StressEffectInterval or {}) do
        if level >= v.min and level <= v.max then return v.timeout end
    end
    return 60000
end

CreateThread(function()
    while true do
        local effectInterval = getEffectInterval(playerStress)
        if not Config.DisableStress and playerStress >= (Config.MinimumStressFX or 50) then
            local ped  = PlayerPedId()
            local blur = getBlurIntensity(playerStress)

            if playerStress >= 100 then
                local fallRepeat = math.random(2, 4)
                local ragdollMs  = fallRepeat * 1750
                TriggerScreenblurFadeIn(1000.0)
                Wait(blur)
                TriggerScreenblurFadeOut(1000.0)

                if not IsPedRagdoll(ped) and IsPedOnFoot(ped) and not IsPedSwimming(ped)
                   and not IsPedInAnyVehicle(ped, false) then
                    SetPedToRagdollWithFall(ped, ragdollMs, ragdollMs, 1,
                        GetEntityForwardVector(ped), 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
                end

                Wait(1000)
                for _ = 1, fallRepeat do
                    Wait(750)
                    DoScreenFadeOut(200)
                    Wait(1000)
                    DoScreenFadeIn(200)
                    TriggerScreenblurFadeIn(1000.0)
                    Wait(blur)
                    TriggerScreenblurFadeOut(1000.0)
                end
            else
                TriggerScreenblurFadeIn(1000.0)
                Wait(blur)
                TriggerScreenblurFadeOut(1000.0)
            end
        end
        Wait(effectInterval)
    end
end)


-- test commands
RegisterCommand('stress', function(_, args)
    local val = tonumber(args[1])
    if not val then return end
    TriggerServerEvent('hud:server:RelieveStress', 100)
    if val > 0 then TriggerServerEvent('hud:server:GainStress', val) end
end, false)
TriggerEvent('chat:addSuggestion', '/stress', 'Set stress manually (testing only)',
    { { name = 'value', help = 'value 0-100' } })

RegisterCommand('relievestress', function(_, args)
    relieveStress(tonumber(args[1]) or 100)
end, false)
TriggerEvent('chat:addSuggestion', '/relievestress', 'Lower stress',
    { { name = 'amount', help = 'amount to subtract' } })


-- parachute (only shows when wearing one)
CreateThread(function()
    while true do
        local hasParachute = GetPedParachuteState(PlayerPedId()) >= 0  -- -1 = none
        if hasParachute ~= wasParachuteOn then
            SafeNUI({ action = 'update-parachute', on = hasParachute })
            wasParachuteOn = hasParachute
        end
        Wait(500)
    end
end)


-- seatbelt
-- detection order: state bag -> ped flag 32 -> 3rd-party events -> /seatbelt key
local lastInVeh = false

local function setSeatbelt(state)
    if seatbeltOn == state then return end
    seatbeltOn = state
    -- flag 32: keeps the player from flying through the windshield
    SetPedConfigFlag(PlayerPedId(), 32, not state)
    SafeNUI({ action = 'update-vehicle', seatbelt = seatbeltOn })
    LocalPlayer.state:set('seatbelt', state, false)
end

RegisterCommand('seatbelt', function()
    if not IsPedInAnyVehicle(PlayerPedId(), false) then return end
    setSeatbelt(not seatbeltOn)
end, false)
RegisterKeyMapping('seatbelt', 'Buckle/unbuckle the seatbelt', 'keyboard', 'B')

RegisterNetEvent('seatbelt:client:UpdateSeatbelt', function(state) setSeatbelt(state) end)
RegisterNetEvent('hud:client:UpdateSeatbelt',      function(state) setSeatbelt(state) end)
RegisterNetEvent('qb-smallresources:client:ToggleSeatbelt', function() setSeatbelt(not seatbeltOn) end)

AddStateBagChangeHandler('seatbelt', ('player:%s'):format(GetPlayerServerId(PlayerId())), function(_, _, value)
    if type(value) == 'boolean' then setSeatbelt(value) end
end)

CreateThread(function()
    while true do
        local ped   = PlayerPedId()
        local inVeh = IsPedInAnyVehicle(ped, false)

        if inVeh and not lastInVeh then
            -- just got in. default to unbuckled unless the state bag says otherwise
            local sb = LocalPlayer.state.seatbelt
            setSeatbelt(sb == true)
        elseif not inVeh and lastInVeh then
            setSeatbelt(false)
        elseif inVeh then
            -- flag 32 TRUE = no belt, FALSE = belt on
            local actual = not GetPedConfigFlag(ped, 32, true)
            if actual ~= seatbeltOn then
                seatbeltOn = actual
                SafeNUI({ action = 'update-vehicle', seatbelt = seatbeltOn })
            end
        end

        lastInVeh = inVeh
        Wait(500)
    end
end)

AddEventHandler('playerSpawned', function()
    seatbeltOn = false
    lastInVeh  = false
end)


-- hunger / thirst from manual events or framework
RegisterNetEvent('nerd-hud:updateHungerThirst', function(hunger, thirst)
    if hunger then playerHunger = hunger end
    if thirst then playerThirst = thirst end
end)

RegisterNetEvent('hud:client:UpdateNeeds', function(newHunger, newThirst)
    playerHunger = newHunger
    playerThirst = newThirst
end)

RegisterNetEvent('esx_status:onTick', function(data)
    for i = 1, #data do
        if data[i].name == 'hunger' then playerHunger = math.floor(data[i].val / 10000) end
        if data[i].name == 'thirst' then playerThirst = math.floor(data[i].val / 10000) end
    end
end)


-- /hudsettings
RegisterCommand(Config.Command, function()
    settingsOpen = true
    SetNuiFocus(true, true)
    SafeNUI({ action = 'show-settings' })
end, false)
TriggerEvent('chat:addSuggestion', '/' .. Config.Command, 'Open the HUD settings panel')

if Config.OpenKey then
    RegisterKeyMapping(Config.Command, 'Open the HUD settings panel', 'keyboard', Config.OpenKey)
end


-- /hudtoggle
RegisterCommand('hudtoggle', function()
    hudVisible = not hudVisible
    SafeNUI({ action = 'show-hud', show = hudVisible })
end, false)
TriggerEvent('chat:addSuggestion', '/hudtoggle', 'Hide/show the HUD')


-- NUI callbacks
RegisterNUICallback('close-settings', function(_, cb)
    settingsOpen = false
    SetNuiFocus(false, false)
    cb({ status = 'ok' })
end)

RegisterNUICallback('save-settings', function(data, cb)
    data = data or {}

    local panelLocked = Config.SettingsPanel and Config.SettingsPanel.minimapMode == false
    if panelLocked then
        data.minimapMode = (Config.MinimapMode == 'always' and 'always') or 'vehicle'
        if minimapMode ~= data.minimapMode then
            minimapMode = data.minimapMode
            applyRadarVisibility(true)
        end
    elseif data.minimapMode == 'always' or data.minimapMode == 'vehicle' then
        minimapMode = data.minimapMode
        applyRadarVisibility(true)
    end

    SetResourceKvp('nerd-hud-settings', json.encode(data))
    TriggerServerEvent('nerd-hud:server:saveSettings', data)
    cb({ status = 'saved' })
end)

-- live preview from the panel (fired while the toggle flips, before Save)
RegisterNUICallback('set-minimap-mode', function(data, cb)
    if Config.SettingsPanel and Config.SettingsPanel.minimapMode == false then
        cb({ status = 'locked' })
        return
    end
    local mode = data and data.mode
    if mode == 'always' or mode == 'vehicle' then
        minimapMode = mode
        applyRadarVisibility(true)
    end
    cb({ status = 'ok' })
end)

RegisterNUICallback('reset-settings', function(_, cb)
    DeleteResourceKvp('nerd-hud-settings')
    TriggerServerEvent('nerd-hud:server:saveSettings', {})
    settingsOpen = false
    SetNuiFocus(false, false)
    cb({ status = 'reset' })
end)


-- ship the config to NUI on boot
CreateThread(function()
    Wait(1000)  -- give NUI time to load
    SafeNUI({
        action = 'init-config',
        config = {
            colors      = Config.DefaultColors,
            effects     = Config.DefaultEffects,
            useMPH      = Config.UseMPH,
            maxSpeed    = Config.VehicleMaxSpeed,
            minimapMode = minimapMode,
            elements    = Config.Elements or {},
            panel       = Config.SettingsPanel or {},
            defaults    = {
                hideCompass = Config.DefaultHideCompass and true or false,
                hideStats   = Config.DefaultHideStats   and true or false,
                hudSize     = Config.DefaultHudSize     or 100,
                cinemaMode  = Config.DefaultCinemaMode  and true or false,
            },
        }
    })
end)


AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        DisplayRadar(true)
        SetNuiFocus(false, false)
    end
end)
