local ESX = exports['es_extended']:getSharedObject()

local activeRobberies = {} ---@type table<string, {source:number, startedAt:number, endsAt:number, rewarded:boolean}>
local playerToStore = {} ---@type table<number, string>
local storeCooldown = {} ---@type table<string, number>

math.randomseed(GetGameTimer())

local function isPolice(xPlayer)
    return xPlayer and xPlayer.job and Config.PoliceJobs[xPlayer.job.name] == true
end

local function getOnlinePoliceIds()
    local players = ESX.GetExtendedPlayers()
    local police = {}

    for _, xPlayer in pairs(players) do
        if isPolice(xPlayer) then
            police[#police + 1] = xPlayer.source
        end
    end

    return police
end

local function isNearStore(src, storeId, maxDistance)
    local store = Config.Stores[storeId]
    if not store then return false end

    local ped = GetPlayerPed(src)
    if ped <= 0 then return false end

    local pCoords = GetEntityCoords(ped)
    return #(pCoords - store.coords) <= maxDistance
end

local function notify(src, title, description, nType)
    TriggerClientEvent('ox_lib:notify', src, {
        title = title,
        description = description,
        type = nType or 'inform'
    })
end

local function notifyPolice(message, store)
    local police = getOnlinePoliceIds()
    for i = 1, #police do
        local target = police[i]
        notify(target, 'Dispatch', message, 'warning')
        TriggerClientEvent('ammunation_robbery:client:policeBlip', target, store.coords, store.label)
    end
end

local function clearPoliceBlips(store)
    local police = getOnlinePoliceIds()
    for i = 1, #police do
        TriggerClientEvent('ammunation_robbery:client:removePoliceBlip', police[i], store.coords)
    end
end

local function cancelRobbery(storeId, reason)
    local robbery = activeRobberies[storeId]
    if not robbery then return end

    local src = robbery.source
    local store = Config.Stores[storeId]

    activeRobberies[storeId] = nil
    playerToStore[src] = nil
    storeCooldown[storeId] = os.time()

    if GetPlayerName(src) then
        TriggerClientEvent('ammunation_robbery:client:robberyCancelled', src, reason or 'Robbery cancelled.')
    end

    notifyPolice(('Robbery cancelled at %s.'):format(store.label), store)
    clearPoliceBlips(store)
end

RegisterNetEvent('ammunation_robbery:server:start', function(storeId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local store = Config.Stores[storeId]

    if not xPlayer or not store then return end
    if playerToStore[src] then return end

    if not isNearStore(src, storeId, Config.InteractDistance + 2.0) then
        notify(src, 'Robbery', 'You are too far from the register.', 'error')
        return
    end

    local police = getOnlinePoliceIds()
    if #police < Config.RequiredPolice then
        notify(src, 'Robbery', ('Not enough police online (%d required).'):format(Config.RequiredPolice), 'error')
        return
    end

    if Config.GlobalSingleRobbery then
        for _ in pairs(activeRobberies) do
            notify(src, 'Robbery', 'Another robbery is already active.', 'error')
            return
        end
    end

    if activeRobberies[storeId] then
        notify(src, 'Robbery', 'This store is already being robbed.', 'error')
        return
    end

    local last = storeCooldown[storeId] or 0
    local remaining = Config.Cooldown - (os.time() - last)
    if remaining > 0 then
        notify(src, 'Robbery', ('Store is on cooldown: %ds remaining.'):format(remaining), 'error')
        return
    end

    activeRobberies[storeId] = {
        source = src,
        startedAt = os.time(),
        endsAt = os.time() + (store.duration or Config.RobberyDuration),
        rewarded = false
    }
    playerToStore[src] = storeId

    notify(src, 'Robbery', ('Robbery started at %s. Hold your position!'):format(store.label), 'success')
    TriggerClientEvent('ammunation_robbery:client:robberyStarted', src, storeId, store.duration or Config.RobberyDuration)

    notifyPolice(('Robbery in progress at %s!'):format(store.label), store)
end)

RegisterNetEvent('ammunation_robbery:server:cancel', function(storeId)
    local src = source
    if playerToStore[src] ~= storeId then return end

    if not isNearStore(src, storeId, Config.MaxDistance + 5.0) then
        cancelRobbery(storeId, 'Robbery cancelled (left area).')
        return
    end

    cancelRobbery(storeId, 'Robbery cancelled.')
end)

RegisterNetEvent('ammunation_robbery:server:complete', function(storeId)
    local src = source
    local robbery = activeRobberies[storeId]
    local store = Config.Stores[storeId]

    if not robbery or not store then return end
    if robbery.source ~= src then return end
    if robbery.rewarded then return end

    if os.time() < robbery.endsAt then
        notify(src, 'Security', 'Exploit detected: robbery timer not finished.', 'error')
        return
    end

    if not isNearStore(src, storeId, Config.MaxDistance) then
        cancelRobbery(storeId, 'Robbery failed: moved too far away.')
        return
    end

    robbery.rewarded = true

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then
        cancelRobbery(storeId, 'Robber disconnected.')
        return
    end

    local gangcoinAmount = math.random(Config.Rewards.gangcoin.min, Config.Rewards.gangcoin.max)
    exports.ox_inventory:AddItem(src, Config.Rewards.gangcoin.item, gangcoinAmount)

    local weaponReward = Config.Rewards.weapons[math.random(1, #Config.Rewards.weapons)]
    local metadata = nil
    if weaponReward.ammo and weaponReward.ammo > 0 then
        metadata = { ammo = weaponReward.ammo, durability = 100 }
    end
    exports.ox_inventory:AddItem(src, weaponReward.item, 1, metadata)

    TriggerClientEvent('ammunation_robbery:client:robberyComplete', src, {
        weapon = weaponReward.item,
        ammo = weaponReward.ammo or 0,
        gangcoin = gangcoinAmount
    })

    activeRobberies[storeId] = nil
    playerToStore[src] = nil
    storeCooldown[storeId] = os.time()

    notifyPolice(('Robbery completed at %s. Suspect escaped.'):format(store.label), store)
    clearPoliceBlips(store)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local storeId = playerToStore[src]
    if not storeId then return end

    cancelRobbery(storeId, 'Robbery cancelled (robber disconnected).')
end)
