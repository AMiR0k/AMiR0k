AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    math.randomseed(os.time())
    OKGangs.Server.EnsureSchema()
    OKGangs.Server.LoadCache()
    OKGangs.Server.RegisterAllInventories()
    OKGangs.Server.ExpireOldGangs()
end)

CreateThread(function()
    while true do
        Wait(Config.ExpirationCheckInterval)
        OKGangs.Server.ExpireOldGangs()
    end
end)

AddEventHandler('esx:playerLoaded', function(playerId)
    local gang, member = OKGangs.Server.GetPlayerGang(playerId)
    TriggerClientEvent('ok_gangs:client:syncGangs', playerId, OKGangs.Server.GetAllPublicGangs())
    TriggerClientEvent('ok_gangs:client:playerGang', playerId, OKGangs.Server.GetPublicGang(gang), member)
end)

local function validateAction(source, target, requireState)
    local gang = OKGangs.Server.RequireActiveGang(source)
    if not gang then return false end
    if not target or not GetPlayerName(target) then return false end
    if not OKGangs.Server.CheckDistance(source, target, Config.PlayerActionDistance) then
        OKGangs.Notify(source, OKGangs.Errors.player_too_far, 'error')
        return false
    end
    return true
end

RegisterNetEvent('ok_gangs:server:cuff', function(target)
    local source = source
    target = tonumber(target)
    if not validateAction(source, target) then return end
    TriggerClientEvent('ok_gangs:client:cuff', target, source)
end)

RegisterNetEvent('ok_gangs:server:drag', function(target)
    local source = source
    target = tonumber(target)
    if not validateAction(source, target) then return end
    TriggerClientEvent('ok_gangs:client:drag', target, source)
end)

RegisterNetEvent('ok_gangs:server:putInVehicle', function(target)
    local source = source
    target = tonumber(target)
    if not validateAction(source, target) then return end
    TriggerClientEvent('ok_gangs:client:putInVehicle', target)
end)

RegisterNetEvent('ok_gangs:server:putOutVehicle', function(target)
    local source = source
    target = tonumber(target)
    if not validateAction(source, target) then return end
    TriggerClientEvent('ok_gangs:client:putOutVehicle', target)
end)

lib.callback.register('ok_gangs:server:finance', function(source, action, amount)
    local isBoss, gang = OKGangs.Server.IsBoss(source)
    if not isBoss then return false, OKGangs.Errors.no_permission end
    local xPlayer = ESX.GetPlayerFromId(source)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false, 'invalid amount' end
    if action == 'deposit_money' then
        if xPlayer.getMoney() < amount then return false, 'insufficient funds' end
        xPlayer.removeMoney(amount)
        gang.money = gang.money + amount
    elseif action == 'withdraw_money' then
        if gang.money < amount then return false, OKGangs.Errors.insufficient_gang_funds end
        gang.money = gang.money - amount
        xPlayer.addMoney(amount)
    elseif action == 'deposit_black' then
        local account = xPlayer.getAccount('black_money')
        if not account or account.money < amount then return false, 'insufficient black money' end
        xPlayer.removeAccountMoney('black_money', amount)
        gang.black_money = gang.black_money + amount
    elseif action == 'withdraw_black' then
        if gang.black_money < amount then return false, OKGangs.Errors.insufficient_gang_funds end
        gang.black_money = gang.black_money - amount
        xPlayer.addAccountMoney('black_money', amount)
    elseif action == 'wash' then
        local online = 0
        for _, playerId in ipairs(ESX.GetPlayers()) do
            local g = OKGangs.Server.GetPlayerGang(playerId)
            if g and g.id == gang.id then online = online + 1 end
        end
        local cost = online * Config.MoneyWashCostPerOnlineMember
        if gang.money < cost or gang.black_money < amount then return false, OKGangs.Errors.insufficient_gang_funds end
        gang.money = gang.money - cost
        gang.black_money = gang.black_money - amount
        local clean = math.floor(amount * Config.MoneyWashRate)
        gang.money = gang.money + clean
        OKGangs.Server.Audit(gang.id, source, 'Money Wash', { amount = amount, clean = clean, cost = cost, online = online })
    else
        return false, 'invalid action'
    end
    MySQL.update.await('UPDATE gangs SET money = ?, black_money = ? WHERE id = ?', { gang.money, gang.black_money, gang.id })
    OKGangs.Server.Audit(gang.id, source, 'Finance Actions', { action = action, amount = amount })
    return true, { money = gang.money, black_money = gang.black_money }
end)
