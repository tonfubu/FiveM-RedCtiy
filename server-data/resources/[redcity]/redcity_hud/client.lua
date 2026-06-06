--[[ RedCity HUD - capsule vehicle HUD (NUI)
     Reads real game values: speed, gear, fuel, street, zone, heading,
     seatbelt, lock, engine, voice. Shows only while in a vehicle. ]]

local Config = {
    maxSpeed   = 220,   -- km/h used for the speedometer ring (visual only)
    units      = 'km/h',
    inVehTick  = 150,   -- ms update while in vehicle
    onFootTick = 1000,  -- ms poll while on foot
    lowFuel    = 20,    -- % threshold for fuel warning
    beltKey    = 'B',
}

local display    = false
local seatbelt   = false
local lastSent   = {}

----------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------
local dirText = {
    N='North Bound', NE='North-East Bound', E='East Bound', SE='South-East Bound',
    S='South Bound', SW='South-West Bound', W='West Bound', NW='North-West Bound',
}

local function headingToDir(h)
    if h >= 337.5 or h < 22.5 then return 'N'
    elseif h < 67.5  then return 'NE'
    elseif h < 112.5 then return 'E'
    elseif h < 157.5 then return 'SE'
    elseif h < 202.5 then return 'S'
    elseif h < 247.5 then return 'SW'
    elseif h < 292.5 then return 'W'
    else return 'NW' end
end

local function getStreetZone(ped)
    local p = GetEntityCoords(ped)
    local s1, s2 = GetStreetNameAtCoord(p.x, p.y, p.z)
    local street = GetStreetNameFromHashKey(s1)
    if not street or street == '' then street = 'Unknown Street' end
    local cross = ''
    if s2 ~= 0 then cross = GetStreetNameFromHashKey(s2) or '' end
    local zCode = GetNameOfZone(p.x, p.y, p.z)
    local zone  = GetLabelText(zCode)
    if not zone or zone == 'NULL' or zone == '' then zone = zCode or '' end
    return street, cross, zone
end

local function getFuel(veh)
    local ok, lvl
    if GetResourceState('LegacyFuel') == 'started' then
        ok, lvl = pcall(function() return exports['LegacyFuel']:GetFuel(veh) end)
        if ok and lvl then return math.floor(lvl + 0.5) end
    end
    if GetResourceState('ps-fuel') == 'started' then
        ok, lvl = pcall(function() return exports['ps-fuel']:GetFuel(veh) end)
        if ok and lvl then return math.floor(lvl + 0.5) end
    end
    if GetResourceState('cdn-fuel') == 'started' then
        ok, lvl = pcall(function() return exports['cdn-fuel']:GetFuel(veh) end)
        if ok and lvl then return math.floor(lvl + 0.5) end
    end
    if GetResourceState('ox_fuel') == 'started' then
        ok, lvl = pcall(function() return Entity(veh).state.fuel end)
        if ok and lvl then return math.floor(lvl + 0.5) end
    end
    return math.floor(GetVehicleFuelLevel(veh) + 0.5)
end

local function getVoice()
    local talking = NetworkIsPlayerTalking(PlayerId()) == 1 or NetworkIsPlayerTalking(PlayerId()) == true
    local mode = 'normal'
    if GetResourceState('pma-voice') == 'started' then
        local ok, prox = pcall(function() return LocalPlayer.state.proximity end)
        if ok and type(prox) == 'table' then
            local m = prox.index or prox.mode
            if m == 1 or m == 'Whisper' then mode = 'whisper'
            elseif m == 3 or m == 'Shouting' then mode = 'shout'
            else mode = 'normal' end
        end
    end
    return mode, talking
end

----------------------------------------------------------------------
-- exports
----------------------------------------------------------------------
exports('IsSeatbeltOn', function() return seatbelt end)
exports('GetSeatbelt',  function() return seatbelt end)

----------------------------------------------------------------------
-- seatbelt toggle (keymapping B)
----------------------------------------------------------------------
RegisterCommand('seatbelt', function()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return end
    seatbelt = not seatbelt
    PlaySoundFrontend(-1, seatbelt and 'PICK_UP' or 'PUT_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
end, false)
RegisterKeyMapping('seatbelt', 'Toggle Seatbelt', 'keyboard', Config.beltKey)

----------------------------------------------------------------------
-- debug / toggle commands
----------------------------------------------------------------------
RegisterCommand('togglehud', function()
    display = not display
    SendNUIMessage({ action = display and 'show' or 'hide' })
end, false)

RegisterCommand('hudtest', function()
    SendNUIMessage({ action = 'show' })
    SendNUIMessage({ action = 'update', data = {
        speed = 181, gear = '4', fuel = 62, direction = 'E',
        directionText = 'East Bound', street = 'Wayne Thunder Dr', zone = 'Vinewood',
        seatbelt = true, locked = true, engine = true, engineWarn = false,
        fuelWarn = false, voiceMode = 'normal', talking = false, maxSpeed = Config.maxSpeed,
    }})
end, false)

----------------------------------------------------------------------
-- main loop
----------------------------------------------------------------------
CreateThread(function()
    -- push config to NUI once
    Wait(500)
    SendNUIMessage({ action = 'config', data = { maxSpeed = Config.maxSpeed, units = Config.units } })

    while true do
        local sleep = Config.onFootTick
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        if veh ~= 0 and IsPedInAnyVehicle(ped, false) then
            sleep = Config.inVehTick
            if not display then
                display = true
                SendNUIMessage({ action = 'show' })
            end

            local speed = math.floor(GetEntitySpeed(veh) * 3.6 + 0.5)

            local gearNum = GetVehicleCurrentGear(veh)
            local sv = GetEntitySpeedVector(veh, true)
            local gear
            if sv.y < -1.0 then gear = 'R'
            elseif gearNum == 0 then gear = 'N'
            else gear = tostring(gearNum) end

            local fuel = getFuel(veh)
            local street, cross, zone = getStreetZone(ped)
            if cross ~= '' then street = street .. '  /  ' .. cross end
            local dir = headingToDir(GetEntityHeading(veh))

            local engine = GetIsVehicleEngineRunning(veh)
            local eHealth = GetVehicleEngineHealth(veh)
            local lockStatus = GetVehicleDoorLockStatus(veh)
            local voiceMode, talking = getVoice()

            local data = {
                speed         = speed,
                gear          = gear,
                fuel          = fuel,
                direction     = dir,
                directionText = dirText[dir] or dir,
                street        = street,
                zone          = zone,
                seatbelt      = seatbelt,
                locked        = lockStatus >= 2,
                engine        = engine,
                engineWarn    = eHealth < 350,
                fuelWarn      = fuel <= Config.lowFuel,
                voiceMode     = voiceMode,
                talking       = talking,
                maxSpeed      = Config.maxSpeed,
            }
            SendNUIMessage({ action = 'update', data = data })
        else
            if display then
                display = false
                seatbelt = false
                SendNUIMessage({ action = 'hide' })
            end
        end

        Wait(sleep)
    end
end)

-- hide on resource stop (clean restart)
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        SendNUIMessage({ action = 'hide' })
    end
end)
