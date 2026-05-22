local ESX = exports['es_extended']:getSharedObject()

local PREFIX = Config.Server.eventPrefix
local cooldownBank = {}
local cooldownGlobal = 0
local activeRobberies = {}
local antiSpam = {}

local function now()
    return os.time()
end

local function getRemaining(endTime)
    local remain = endTime - now()
    if remain < 0 then return 0 end
    return remain
end

local function isPolice(xPlayer)
    local job = xPlayer.getJob()
    return job and job.name == 'police'
end

local function countPolice()
    local count = 0
    for _, id in ipairs(ESX.GetPlayers()) do
        local player = ESX.GetPlayerFromId(id)
        if player and isPolice(player) then
            count += 1
        end
    end
    return count
end

local function validBank(bankId)
    return bankId and Config.Banks[bankId] ~= nil
end

local function checkDistance(source, target)
    local ped = GetPlayerPed(source)
    if ped <= 0 then return false end
    local coords = GetEntityCoords(ped)
    return #(coords - target) <= (Config.Settings.interactDistance + 1.0)
end

local function throttle(source)
    local ts = antiSpam[source] or 0
    if now() - ts < Config.Settings.antiSpam then
        return false
    end
    antiSpam[source] = now()
    return true
end

local function setBankCooldown(bankId)
    local ts = now()
    cooldownBank[bankId] = ts + Config.Settings.cooldown
    cooldownGlobal = ts + Config.Settings.globalCooldown
end

local function cleanRobbery(source)
    activeRobberies[source] = nil
    TriggerClientEvent(('%s:client:resetState'):format(PREFIX), source)
end

lib.callback.register(('%s:server:beginHack'):format(PREFIX), function(source, bankId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return { error = 'invalid_bank' } end
    if not validBank(bankId) then return { error = 'invalid_bank' } end
    if not throttle(source) then return { error = 'already_started' } end

    local bank = Config.Banks[bankId]
    if not checkDistance(source, bank.start) then return { error = 'too_far' } end

    if cooldownGlobal > now() then
        return { error = 'cooldown_global', remaining = getRemaining(cooldownGlobal) }
    end

    local bankCooldown = cooldownBank[bankId] or 0
    if bankCooldown > now() then
        return { error = 'cooldown_bank', remaining = getRemaining(bankCooldown) }
    end

    local cops = countPolice()
    if cops < Config.Settings.mincops then
        return { error = 'need_cops' }
    end

    local count = exports.ox_inventory:GetItemCount(source, Config.Items.hack)
    if count < 1 then
        return { error = 'missing_item' }
    end

    if activeRobberies[source] then
        return { error = 'robbery_busy' }
    end

    activeRobberies[source] = {
        bankId = bankId,
        stage = 'hacking',
        started = now()
    }

    setBankCooldown(bankId)
    return { ok = true }
end)

lib.callback.register(('%s:server:completeHack'):format(PREFIX), function(source, bankId)
    local state = activeRobberies[source]
    if not state or state.bankId ~= bankId or state.stage ~= 'hacking' then
        cleanRobbery(source)
        return false
    end

    local bank = Config.Banks[bankId]
    if not bank or not checkDistance(source, bank.start) then
        cleanRobbery(source)
        return false
    end

    state.stage = 'weld'
    return true
end)

RegisterNetEvent(('%s:server:resetAttempt'):format(PREFIX), function(bankId)
    local src = source
    local state = activeRobberies[src]
    if not state then return end
    if state.bankId ~= bankId then return end
    cleanRobbery(src)
end)

lib.callback.register(('%s:server:beginWeld'):format(PREFIX), function(source, bankId)
    local state = activeRobberies[source]
    if not state or state.bankId ~= bankId or state.stage ~= 'weld' then
        return false
    end

    local bank = Config.Banks[bankId]
    if not bank or not checkDistance(source, bank.weld) then
        cleanRobbery(source)
        return { error = 'too_far' }
    end

    local count = exports.ox_inventory:GetItemCount(source, Config.Items.weld)
    if count < 1 then
        return { error = 'missing_item' }
    end

    state.stage = 'welding'
    state.weldStart = now()
    return { ok = true }
end)

RegisterNetEvent(('%s:server:cancelWeld'):format(PREFIX), function(bankId)
    local src = source
    local state = activeRobberies[src]
    if not state or state.bankId ~= bankId then return end
    cleanRobbery(src)
end)

lib.callback.register(('%s:server:completeWeld'):format(PREFIX), function(source, bankId)
    local state = activeRobberies[source]
    if not state or state.bankId ~= bankId or state.stage ~= 'welding' then
        cleanRobbery(source)
        return false
    end

    local bank = Config.Banks[bankId]
    if not bank or not checkDistance(source, bank.weld) then
        cleanRobbery(source)
        return false
    end

    local elapsed = now() - (state.weldStart or now())
    if elapsed < (Config.Settings.weldTimer - 2) then
        cleanRobbery(source)
        return false
    end

    local reward = math.random(Config.Settings.mincash, Config.Settings.maxcash)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        if Config.Settings.black then
            xPlayer.addAccountMoney('black_money', reward)
        else
            xPlayer.addMoney(reward)
        end
    end

    cleanRobbery(source)
    return true
end)

AddEventHandler('playerDropped', function()
    local src = source
    antiSpam[src] = nil
    activeRobberies[src] = nil
end)
