AdvancedHunting = AdvancedHunting or {}
AdvancedHunting.Selling = AdvancedHunting.Selling or {}

local function priceFor(item)
    for _, animal in pairs(Animals.Definitions) do
        if animal.rewards.meat and animal.rewards.meat.item == item then return animal.sellPrice.meat or 0 end
        if animal.rewards.skin and animal.rewards.skin.item == item then return animal.sellPrice.skin or 0 end
        if animal.rewards.carcass and animal.rewards.carcass == item then return animal.sellPrice.carcass or 0 end
    end
    return 0
end

RegisterNetEvent('advanced_hunting:server:sellToTrader', function(traderId, coords)
    local source = source
    local trader = HuntingTraders[traderId]
    if not trader then return AdvancedHunting.Security.Fail(source, 'invalid_trader', {traderId = traderId}) end
    local pedCoords = GetEntityCoords(GetPlayerPed(source))
    local traderCoords = vector3(trader.coords.x, trader.coords.y, trader.coords.z)
    if #(pedCoords - traderCoords) > Config.Security.maxSellDistance then
        return AdvancedHunting.Security.Fail(source, 'sell_too_far', {traderId = traderId})
    end

    local total = 0
    for _, item in ipairs(trader.items) do
        local count = exports[Config.Inventory.resource]:Search(source, 'count', item) or 0
        if count > 0 then
            exports[Config.Inventory.resource]:RemoveItem(source, item, count)
            total = total + (priceFor(item) * count)
        end
    end

    if total <= 0 then
        TriggerClientEvent('ox_lib:notify', source, {description = _L('nothing_to_sell'), type = 'error'})
        return
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    xPlayer.addAccountMoney(trader.account, total)
    TriggerClientEvent('ox_lib:notify', source, {description = _L('sold_items', total), type = 'success'})
    AdvancedHunting.Logging.Write('sell', source, 'sold_hunting_goods', {trader = traderId, total = total})
end)
