local ESX
local refuelLocks = {}

local function getESX()
    if ESX then return ESX end
    local ok, obj = pcall(function()
        return exports['es_extended']:getSharedObject()
    end)
    if ok and obj then
        ESX = obj
        return ESX
    end
    TriggerEvent('esx:getSharedObject', function(obj)
        ESX = obj
    end)
    return ESX
end

local function getPlayerMoney(xPlayer, account)
    if account == 'bank' then
        local bank = xPlayer.getAccount('bank')
        return bank and bank.money or 0
    end
    return xPlayer.getMoney()
end

local function removeMoney(xPlayer, account, amount)
    if account == 'bank' then
        xPlayer.removeAccountMoney('bank', amount)
    else
        xPlayer.removeMoney(amount)
    end
end

RegisterNetEvent('redcity_hud:requestRefuel', function(netId, currentFuel)
    local src = source
    local now = os.time()
    if refuelLocks[src] and now - refuelLocks[src] < 3 then
        TriggerClientEvent('redcity_hud:refuelDenied', src, 'Please wait before refueling again')
        return
    end
    refuelLocks[src] = now

    local esx = getESX()
    if not esx then
        TriggerClientEvent('redcity_hud:refuelDenied', src, 'ESX is not ready')
        return
    end

    local xPlayer = esx.GetPlayerFromId(src)
    if not xPlayer then return end

    currentFuel = tonumber(currentFuel) or 0
    currentFuel = math.max(0.0, math.min(Config.Fuel.MaxFuel, currentFuel))
    local missing = Config.Fuel.MaxFuel - currentFuel
    if missing <= 0.5 then
        TriggerClientEvent('redcity_hud:refuelDenied', src, 'Fuel tank is already full')
        return
    end

    local account = Config.Fuel.PaymentAccount or 'money'
    local available = getPlayerMoney(xPlayer, account)
    local maxAffordableLiters = math.floor(available / Config.Fuel.PricePerLiter)
    if maxAffordableLiters <= 0 then
        TriggerClientEvent('redcity_hud:refuelDenied', src, 'Not enough money')
        return
    end

    local liters = math.min(missing, maxAffordableLiters)
    local price = math.ceil(liters * Config.Fuel.PricePerLiter)
    if price <= 0 then
        TriggerClientEvent('redcity_hud:refuelDenied', src, 'Invalid fuel amount')
        return
    end

    removeMoney(xPlayer, account, price)
    TriggerClientEvent('redcity_hud:startRefuel', src, netId, liters)
end)

AddEventHandler('playerDropped', function()
    refuelLocks[source] = nil
end)
