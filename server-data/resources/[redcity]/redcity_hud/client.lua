local ESX
local seatbeltOn = false
local hudVisible = false
local playerInfoVisible = false
local lastHudPayload = ''
local lastPlayerPayload = ''
local lastStatusPayload = ''
local lastSoundAt = 0
local voiceIndex = 2
local hunger = 100
local stress = 0
local isRefueling = false
local lastEngineFailure = 0

exports('IsSeatbeltOn', function()
    return seatbeltOn
end)

local directionLabels = {
    N = 'NORTH', NE = 'NORTH EAST BOUND', E = 'EAST BOUND', SE = 'SOUTH EAST BOUND',
    S = 'SOUTH', SW = 'SOUTH WEST BOUND', W = 'WEST BOUND', NW = 'NORTH WEST BOUND'
}

local function clamp(value, min, max)
    value = tonumber(value) or 0
    if value < min then return min end
    if value > max then return max end
    return value
end

local function notify(message)
    if ESX and ESX.ShowNotification then
        ESX.ShowNotification(message)
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(message)
        EndTextCommandThefeedPostTicker(false, false)
    end
end

local function sendIfChanged(cacheName, payload)
    local encoded = json.encode(payload)
    if cacheName == 'vehicle' then
        if encoded == lastHudPayload then return end
        lastHudPayload = encoded
    elseif cacheName == 'player' then
        if encoded == lastPlayerPayload then return end
        lastPlayerPayload = encoded
    elseif cacheName == 'status' then
        if encoded == lastStatusPayload then return end
        lastStatusPayload = encoded
    end
    SendNUIMessage(payload)
end

local function playHudSound(name, forced)
    if not Config.Seatbelt.PlaySound then return end
    local now = GetGameTimer()
    if not forced and now - lastSoundAt < Config.Seatbelt.SoundCooldown then return end
    lastSoundAt = now
    SendNUIMessage({ action = 'sound', name = name })
end

local function headingToDir(heading)
    if heading >= 337.5 or heading < 22.5 then return 'N'
    elseif heading < 67.5 then return 'NE'
    elseif heading < 112.5 then return 'E'
    elseif heading < 157.5 then return 'SE'
    elseif heading < 202.5 then return 'S'
    elseif heading < 247.5 then return 'SW'
    elseif heading < 292.5 then return 'W'
    else return 'NW' end
end

local function getStreetText(coords)
    local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = GetStreetNameFromHashKey(streetHash)
    if not street or street == '' then street = 'Unknown Road' end
    local crossing = ''
    if crossingHash and crossingHash ~= 0 then
        crossing = GetStreetNameFromHashKey(crossingHash) or ''
    end
    if crossing ~= '' then return street .. ' / ' .. crossing end
    return street
end

local function getFuel(veh)
    local ok, fuel
    if GetResourceState('LegacyFuel') == 'started' then
        ok, fuel = pcall(function() return exports['LegacyFuel']:GetFuel(veh) end)
        if ok and fuel then return clamp(fuel, 0.0, Config.Fuel.MaxFuel), 'LegacyFuel' end
    end
    if GetResourceState('ox_fuel') == 'started' then
        ok, fuel = pcall(function() return Entity(veh).state.fuel end)
        if ok and fuel then return clamp(fuel, 0.0, Config.Fuel.MaxFuel), 'ox_fuel' end
    end
    if GetResourceState('cdn-fuel') == 'started' then
        ok, fuel = pcall(function() return exports['cdn-fuel']:GetFuel(veh) end)
        if ok and fuel then return clamp(fuel, 0.0, Config.Fuel.MaxFuel), 'cdn-fuel' end
    end
    return clamp(GetVehicleFuelLevel(veh), 0.0, Config.Fuel.MaxFuel), 'native'
end

local function setFuel(veh, fuel)
    fuel = clamp(fuel, 0.0, Config.Fuel.MaxFuel)
    local ok
    if GetResourceState('LegacyFuel') == 'started' then
        ok = pcall(function() exports['LegacyFuel']:SetFuel(veh, fuel) end)
        if ok then return end
    end
    if GetResourceState('ox_fuel') == 'started' then
        pcall(function()
            Entity(veh).state:set('fuel', fuel, true)
        end)
    end
    if GetResourceState('cdn-fuel') == 'started' then
        ok = pcall(function() exports['cdn-fuel']:SetFuel(veh, fuel) end)
        if ok then return end
    end
    SetVehicleFuelLevel(veh, fuel + 0.0)
end

local function getVoiceState()
    local mode = Config.Voice.Modes[voiceIndex] or Config.Voice.Modes[2]
    if GetResourceState('pma-voice') == 'started' and LocalPlayer and LocalPlayer.state then
        local prox = LocalPlayer.state.proximity
        if type(prox) == 'table' then
            local idx = tonumber(prox.index)
            if idx and Config.Voice.Modes[idx] then
                voiceIndex = idx
                mode = Config.Voice.Modes[voiceIndex]
            elseif prox.mode == 'Whisper' then
                voiceIndex = 1
                mode = Config.Voice.Modes[1]
            elseif prox.mode == 'Shouting' then
                voiceIndex = 3
                mode = Config.Voice.Modes[3]
            end
        end
    end
    return {
        index = voiceIndex,
        name = mode.name,
        label = mode.label,
        color = mode.color,
        talking = NetworkIsPlayerTalking(PlayerId())
    }
end

local function cycleVoiceMode()
    if not Config.Voice.Enabled then return end
    if GetResourceState('pma-voice') == 'started' then
        ExecuteCommand('cycleproximity')
        Wait(80)
    else
        voiceIndex = voiceIndex + 1
        if voiceIndex > #Config.Voice.Modes then voiceIndex = 1 end
    end
    SendNUIMessage({ action = 'voiceFlash', voice = getVoiceState() })
end

RegisterCommand('redcity_voice_cycle', cycleVoiceMode, false)
RegisterKeyMapping('redcity_voice_cycle', 'RedCity voice range', 'keyboard', Config.Voice.Key)

RegisterCommand('seatbelt', function()
    if not Config.Seatbelt.Enabled then return end
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return end
    seatbeltOn = not seatbeltOn
    playHudSound(seatbeltOn and 'seatbelt_on' or 'seatbelt_off', true)
    SendNUIMessage({ action = 'seatbelt', enabled = seatbeltOn })
end, false)
RegisterKeyMapping('seatbelt', 'Toggle seatbelt', 'keyboard', Config.Seatbelt.Key)

RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    ESX = ESX or exports['es_extended']:getSharedObject()
end)

AddEventHandler('esx_status:onTick', function(status)
    for _, item in ipairs(status or {}) do
        if item.name == 'hunger' then
            hunger = clamp((item.percent or item.val or 1000000) / 10000, 0, 100)
        elseif item.name == 'stress' then
            stress = clamp((item.percent or item.val or 0) / 10000, 0, 100)
        end
    end
end)

local function showVehicleHud()
    if hudVisible then return end
    hudVisible = true
    SendNUIMessage({ action = 'vehicleVisible', visible = true })
end

local function hideVehicleHud()
    if not hudVisible then return end
    hudVisible = false
    seatbeltOn = false
    lastHudPayload = ''
    SendNUIMessage({ action = 'vehicleVisible', visible = false })
end

local function showPlayerInfo(visible)
    if playerInfoVisible == visible then return end
    playerInfoVisible = visible
    SendNUIMessage({ action = 'playerVisible', visible = visible })
end

local function buildPlayerInfo()
    local h, m
    if Config.UseRealTime then
        h = tonumber(GetClockHours()) or 0
        m = tonumber(GetClockMinutes()) or 0
    else
        h = GetClockHours()
        m = GetClockMinutes()
    end
    local date = Config.UseRealTime and GetLabelText('DATE_FORMAT') or ''
    local year, month, day = GetLocalTime()
    if Config.UseRealTime then
        date = ('%02d/%02d/%02d'):format(day, month, year % 100)
        h, m = select(4, GetLocalTime())
    else
        local d, mo, y = GetClockDayOfMonth(), GetClockMonth() + 1, GetClockYear()
        date = ('%02d/%02d/%02d'):format(d, mo, y % 100)
    end
    return {
        action = 'playerInfo',
        id = GetPlayerServerId(PlayerId()),
        date = date,
        time = ('%02d:%02d'):format(h, m),
        voice = getVoiceState()
    }
end

local function getStatusPayload()
    local ped = PlayerPedId()
    local hp = clamp(GetEntityHealth(ped) - 100, 0, 100)
    local armor = clamp(GetPedArmour(ped), 0, 100)
    return {
        action = 'status',
        hp = hp,
        armor = armor,
        hunger = clamp(hunger, 0, 100),
        stress = clamp(stress, 0, 100)
    }
end

local function getVehiclePayload(veh, ped)
    local coords = GetEntityCoords(ped)
    local speed = math.floor(GetEntitySpeed(veh) * 3.6 + 0.5)
    local gearNum = GetVehicleCurrentGear(veh)
    local speedVector = GetEntitySpeedVector(veh, true)
    local gear = gearNum == 0 and 'N' or tostring(gearNum)
    if speedVector.y < -1.0 then gear = 'R' end
    local fuel, fuelSource = getFuel(veh)
    local engineHealth = clamp(GetVehicleEngineHealth(veh), 0, 1000)
    local bodyHealth = clamp(GetVehicleBodyHealth(veh), 0, 1000)
    local durability = math.floor(math.min(engineHealth, bodyHealth) / 10 + 0.5)
    local dir = headingToDir(GetEntityHeading(veh))
    local engineRunning = GetIsVehicleEngineRunning(veh)
    local lockStatus = GetVehicleDoorLockStatus(veh)
    local beltWarn = Config.Seatbelt.Enabled and not seatbeltOn and speed > Config.Seatbelt.WarningSpeed

    return {
        action = 'vehicle',
        speed = speed,
        maxSpeed = Config.HUD.MaxSpeed,
        gear = gear,
        fuel = math.floor(fuel + 0.5),
        fuelSource = fuelSource,
        fuelWarn = fuel <= 15,
        engine = engineRunning,
        engineHealth = math.floor(engineHealth + 0.5),
        bodyHealth = math.floor(bodyHealth + 0.5),
        durability = durability,
        engineWarn = engineHealth <= Config.VehicleDamage.WarningHealth or bodyHealth <= Config.VehicleDamage.WarningHealth,
        engineFailed = engineHealth <= Config.VehicleDamage.EngineFailHealth,
        locked = lockStatus >= 2,
        seatbelt = seatbeltOn,
        seatbeltWarn = beltWarn,
        direction = dir,
        directionText = directionLabels[dir] or dir,
        street = getStreetText(coords),
        voice = getVoiceState()
    }
end

CreateThread(function()
    while not ESX do
        pcall(function()
            ESX = exports['es_extended']:getSharedObject()
        end)
        Wait(500)
    end
end)

CreateThread(function()
    Wait(600)
    SendNUIMessage({ action = 'config', hud = Config.HUD, voiceModes = Config.Voice.Modes })

    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        local inVehicle = veh ~= 0 and IsPedInAnyVehicle(ped, false)
        local isDriver = inVehicle and GetPedInVehicleSeat(veh, -1) == ped

        if inVehicle then
            DisplayRadar(true)
            showPlayerInfo(false)
            showVehicleHud()
            sendIfChanged('vehicle', getVehiclePayload(veh, ped))
            if isDriver and Config.Seatbelt.Enabled and not seatbeltOn and GetEntitySpeed(veh) * 3.6 > Config.Seatbelt.WarningSpeed then
                playHudSound('seatbelt_warning', false)
            end
            Wait(Config.HUD.VehicleUpdateInterval)
        else
            hideVehicleHud()
            if Config.HUD.HideRadarOnFoot then DisplayRadar(false) end
            showPlayerInfo(Config.HUD.ShowPlayerInfoOnFoot)
            if Config.HUD.ShowPlayerInfoOnFoot then
                sendIfChanged('player', buildPlayerInfo())
            end
            Wait(Config.HUD.OnFootUpdateInterval)
        end
    end
end)

CreateThread(function()
    while true do
        if Config.HUD.ShowStatusHUD then
            sendIfChanged('status', getStatusPayload())
        end
        Wait(Config.HUD.StatusUpdateInterval)
    end
end)

CreateThread(function()
    while true do
        if Config.Fuel.Enabled then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
                local fuel = getFuel(veh)
                local engineRunning = GetIsVehicleEngineRunning(veh)
                if engineRunning and fuel > 0.0 then
                    local speed = GetEntitySpeed(veh) * 3.6
                    local rpm = GetVehicleCurrentRpm(veh)
                    local class = GetVehicleClass(veh)
                    local classMul = (class == 8 and 0.72) or (class == 15 and 1.35) or (class == 16 and 1.65) or (class == 18 and 1.2) or 1.0
                    local used = Config.Fuel.BaseConsumption + (speed * Config.Fuel.SpeedMultiplier) + (rpm * Config.Fuel.RpmMultiplier)
                    if speed < 2.0 then used = Config.Fuel.IdleConsumption end
                    setFuel(veh, fuel - (used * classMul))
                elseif fuel <= Config.Fuel.EmptyEngineCutoff then
                    SetVehicleEngineOn(veh, false, true, true)
                    DisableControlAction(0, 71, true)
                end
            end
        end
        Wait(Config.Fuel.UpdateInterval)
    end
end)

CreateThread(function()
    while true do
        local sleep = 750
        if Config.VehicleDamage.Enabled then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
                local engineHealth = GetVehicleEngineHealth(veh)
                local fuel = getFuel(veh)
                local fuelEmpty = Config.Fuel.Enabled and fuel <= Config.Fuel.EmptyEngineCutoff
                if engineHealth <= Config.VehicleDamage.EngineFailHealth or fuelEmpty then
                    SetVehicleEngineOn(veh, false, true, true)
                    if Config.VehicleDamage.DisableDrivingOnFailure or fuelEmpty then
                        DisableControlAction(0, 71, true)
                        DisableControlAction(0, 72, true)
                    end
                    if GetGameTimer() - lastEngineFailure > 5000 then
                        lastEngineFailure = GetGameTimer()
                        SendNUIMessage({ action = 'alert', text = fuelEmpty and 'FUEL EMPTY' or 'ENGINE FAILURE', level = 'danger' })
                    end
                    sleep = 0
                end
            end
        end
        Wait(sleep)
    end
end)

local function getNearestPump()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local best, dist
    for i, pos in ipairs(Config.GasStations) do
        local d = #(coords - pos)
        if not dist or d < dist then
            best, dist = i, d
        end
    end
    return best, dist
end

local function getDriverVehicleNearPump()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        veh = GetVehiclePedIsIn(ped, true)
    end
    if veh == 0 or #(GetEntityCoords(ped) - GetEntityCoords(veh)) > 5.0 then return 0 end
    if GetPedInVehicleSeat(veh, -1) ~= ped then return 0 end
    return veh
end

CreateThread(function()
    for _, pos in ipairs(Config.GasStations) do
        local blip = AddBlipForCoord(pos.x, pos.y, pos.z)
        SetBlipSprite(blip, 361)
        SetBlipScale(blip, 0.62)
        SetBlipColour(blip, 5)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Gas Station')
        EndTextCommandSetBlipName(blip)
    end

    while true do
        local sleep = 900
        local station, dist = getNearestPump()
        if station and dist and dist < Config.Interaction.DrawDistance then
            sleep = 0
            local pos = Config.GasStations[station]
            if dist < Config.Interaction.MarkerDistance then
                DrawMarker(2, pos.x, pos.y, pos.z + 0.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.28, 0.28, 0.18, 255, 210, 31, 180, false, true, 2, nil, nil, false)
            end
            if dist < Config.Interaction.RefuelDistance and not isRefueling then
                local veh = getDriverVehicleNearPump()
                if veh ~= 0 then
                    local fuel = getFuel(veh)
                    local missing = math.max(Config.Fuel.MaxFuel - fuel, 0.0)
                    local estimate = math.ceil(missing * Config.Fuel.PricePerLiter)
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName(('Press ~INPUT_CONTEXT~ to refuel | $%s | %s%%'):format(estimate, math.floor(fuel + 0.5)))
                    EndTextCommandDisplayHelp(0, false, true, 1)
                    if IsControlJustPressed(0, Config.Interaction.Key) and missing > 0.5 then
                        isRefueling = true
                        TriggerServerEvent('redcity_hud:requestRefuel', VehToNet(veh), fuel)
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('redcity_hud:startRefuel', function(netId, paidLiters)
    local veh = NetToVeh(netId)
    if veh == 0 then isRefueling = false return end
    local filled = 0.0
    SendNUIMessage({ action = 'refuel', active = true, price = Config.Fuel.PricePerLiter })
    while isRefueling and filled < paidLiters do
        local ped = PlayerPedId()
        if #(GetEntityCoords(ped) - GetEntityCoords(veh)) > 6.0 or GetPedInVehicleSeat(veh, -1) ~= ped then break end
        local fuel = getFuel(veh)
        if fuel >= Config.Fuel.MaxFuel - 0.2 then break end
        local add = math.min(Config.Fuel.RefuelLitersPerTick, paidLiters - filled, Config.Fuel.MaxFuel - fuel)
        filled = filled + add
        setFuel(veh, fuel + add)
        SendNUIMessage({ action = 'refuel', active = true, progress = math.floor((filled / paidLiters) * 100) })
        Wait(Config.Fuel.RefuelTick)
    end
    SendNUIMessage({ action = 'refuel', active = false })
    isRefueling = false
end)

RegisterNetEvent('redcity_hud:refuelDenied', function(message)
    isRefueling = false
    notify(message or 'Cannot refuel')
    SendNUIMessage({ action = 'alert', text = message or 'FUEL PAYMENT FAILED', level = 'danger' })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    DisplayRadar(true)
    SendNUIMessage({ action = 'vehicleVisible', visible = false })
    SendNUIMessage({ action = 'playerVisible', visible = false })
end)
