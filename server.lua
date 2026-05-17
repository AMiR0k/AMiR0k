local ESX = exports.es_extended:getSharedObject()

local activeRobberies = {}
local cooldownEndsAt = 0

local function locale(key, ...)
    local language = Config.Locales[Config.Language] or Config.Locales.en
    local message = language[key] or Config.Locales.en[key] or key

    if select('#', ...) > 0 then
        return message:format(...)
    end

    return message
end

local function notify(source, description, notifyType, title)
    TriggerClientEvent('six_atmrobbery:client:notify', source, {
        title = title or locale('alert_notify_title'),
        description = description,
        type = notifyType or 'inform'
    })
end

local function buildJobLookup()
    local lookup = {}

    for i = 1, #Config.PoliceJobs do
        lookup[Config.PoliceJobs[i]] = true
    end

    return lookup
end

local function getPoliceCount()
    local policeJobs = buildJobLookup()
    local cops = 0
    local players = ESX.GetPlayers()

    for i = 1, #players do
        local xPlayer = ESX.GetPlayerFromId(players[i])

        if xPlayer and xPlayer.job and policeJobs[xPlayer.job.name] then
            cops = cops + 1
        end
    end

    return cops
end

local function alertPolice(coords)
    local policeJobs = buildJobLookup()
    local players = ESX.GetPlayers()

    for i = 1, #players do
        local xPlayer = ESX.GetPlayerFromId(players[i])

        if xPlayer and xPlayer.job and policeJobs[xPlayer.job.name] then
            TriggerClientEvent('six_atmrobbery:client:policeAlert', xPlayer.source, coords)
        end
    end
end

local function hasItem(source, item, count)
    return (exports.ox_inventory:Search(source, 'count', item) or 0) >= (count or 1)
end

local function canCarryItem(source, item, count)
    if not item or item == '' or (count or 0) <= 0 then
        return true
    end

    return exports.ox_inventory:CanCarryItem(source, item, count or 1)
end

local function removeItem(source, item, count)
    return exports.ox_inventory:RemoveItem(source, item, count or 1)
end

local function addItem(source, item, count)
    if not item or item == '' or (count or 0) <= 0 then
        return true
    end

    return exports.ox_inventory:AddItem(source, item, count or 1)
end

local function addReward(xPlayer, amount)
    if Config.RewardAccount == 'money' then
        xPlayer.addMoney(amount, 'ATM robbery')
        return
    end

    if Config.RewardAccount == 'bank' or Config.RewardAccount == 'black_money' then
        xPlayer.addAccountMoney(Config.RewardAccount, amount, 'ATM robbery')
        return
    end

    print(('[six_atmrobbery] Invalid RewardAccount "%s". Falling back to black_money.'):format(tostring(Config.RewardAccount)))
    xPlayer.addAccountMoney('black_money', amount, 'ATM robbery')
end

local function getPlayerCoords(source)
    local ped = GetPlayerPed(source)

    if not ped or ped == 0 then
        return nil
    end

    return GetEntityCoords(ped)
end

local function distanceBetween(a, b)
    return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z))
end

local function generateToken(source)
    return ('%s:%s:%s'):format(source, os.time(), math.random(100000, 999999))
end

local function cooldownRemainingMinutes()
    return math.max(0, math.ceil((cooldownEndsAt - os.time()) / 60))
end

lib.callback.register('six_atmrobbery:server:startRobbery', function(source, atmCoords)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer then
        return { ok = false, message = locale('robbery_invalid'), type = 'error' }
    end

    if activeRobberies[source] and os.time() > activeRobberies[source].expiresAt then
        activeRobberies[source] = nil
    end

    if activeRobberies[source] then
        return { ok = false, message = locale('robbery_busy'), type = 'error' }
    end

    if type(atmCoords) ~= 'table' or not atmCoords.x or not atmCoords.y or not atmCoords.z then
        return { ok = false, message = locale('robbery_invalid'), type = 'error' }
    end

    local playerCoords = getPlayerCoords(source)

    if not playerCoords or distanceBetween(playerCoords, atmCoords) > Config.MaxStartDistance then
        return { ok = false, message = locale('robbery_too_far'), type = 'error' }
    end

    if os.time() < cooldownEndsAt then
        return { ok = false, message = locale('robbery_cooldown', cooldownRemainingMinutes()), type = 'error' }
    end

    local currentCops = getPoliceCount()

    if currentCops < Config.RequiredCops then
        return { ok = false, message = locale('robbery_missingCops', currentCops, Config.RequiredCops), type = 'error' }
    end

    if not hasItem(source, Config.DrillItem, 1) then
        return { ok = false, message = locale('robbery_no_drill'), type = 'error' }
    end

    if Config.DrillUsedItem and Config.DrillUsedItem ~= '' and not canCarryItem(source, Config.DrillUsedItem, 1) then
        return { ok = false, message = locale('robbery_cannot_carry'), type = 'error' }
    end

    if not removeItem(source, Config.DrillItem, 1) then
        return { ok = false, message = locale('robbery_no_drill'), type = 'error' }
    end

    local token = generateToken(source)
    local now = os.time()

    activeRobberies[source] = {
        token = token,
        coords = { x = atmCoords.x + 0.0, y = atmCoords.y + 0.0, z = atmCoords.z + 0.0 },
        startedAt = now,
        expiresAt = now + (Config.RobberyTime * 60) + 60
    }

    cooldownEndsAt = now + (Config.Cooldown * 60)
    alertPolice(activeRobberies[source].coords)

    return { ok = true, token = token }
end)

RegisterNetEvent('six_atmrobbery:server:finishRobbery', function(token, success)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local robbery = activeRobberies[source]

    if not xPlayer or not robbery or robbery.token ~= token then
        if xPlayer then
            notify(source, locale('robbery_invalid'), 'error')
        end
        return
    end

    activeRobberies[source] = nil

    addItem(source, Config.DrillUsedItem, 1)

    if not success then
        alertPolice(nil)
        return
    end

    if os.time() > robbery.expiresAt then
        notify(source, locale('robbery_invalid'), 'error')
        alertPolice(nil)
        return
    end

    local playerCoords = getPlayerCoords(source)

    if not playerCoords or distanceBetween(playerCoords, robbery.coords) > Config.MaxFinishDistance then
        notify(source, locale('robbery_too_far'), 'error')
        alertPolice(nil)
        return
    end

    local reward = math.random(Config.Reward.min, Config.Reward.max)
    addReward(xPlayer, reward)
    notify(source, locale('robbery_success', reward), 'success')
    alertPolice(nil)
end)

ESX.RegisterUsableItem(Config.DrillItem, function(source)
    if not hasItem(source, Config.DrillItem, 1) then
        notify(source, locale('robbery_no_drill'), 'error')
        return
    end

    TriggerClientEvent('six_atmrobbery:client:useDrill', source)
end)

AddEventHandler('playerDropped', function()
    local source = source

    if activeRobberies[source] then
        activeRobberies[source] = nil
        alertPolice(nil)
    end
end)
