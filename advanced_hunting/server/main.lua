ESX = exports[Config.Framework.esxExport]:getSharedObject()
AdvancedHunting = AdvancedHunting or {}
AdvancedHunting.ServerState = AdvancedHunting.ServerState or {players = {}, animals = {}, processed = {}}

RegisterNetEvent('advanced_hunting:server:setActive', function(active, zoneId)
    local source = source
    if active then
        if not AdvancedHunting.Security.ValidateZone(source, nil, zoneId) then return end
        AdvancedHunting.ServerState.players[source] = {active = true, zoneId = zoneId, startedAt = os.time()}
    else
        AdvancedHunting.ServerState.players[source] = {active = false, zoneId = nil}
        for netId, record in pairs(AdvancedHunting.ServerState.animals) do
            if record.owner == source then AdvancedHunting.ServerState.animals[netId] = nil end
        end
    end
end)

RegisterNetEvent('advanced_hunting:server:registerAnimal', function(netId, animalId, zoneId, coords)
    local source = source
    if AdvancedHunting.AntiAbuse.IsOnCooldown(('register:%s'):format(source), 750) then return end
    if not AdvancedHunting.Security.IsPlayerActive(source) then return AdvancedHunting.Security.Fail(source, 'register_without_active_hunt', {netId = netId}) end
    if not AdvancedHunting.Security.ValidateZone(source, coords, zoneId) then return end
    local animal = AdvancedHunting.Utils.GetAnimalConfig(animalId)
    local zone = HuntingZones[zoneId]
    if not animal or not AdvancedHunting.Utils.TableContains(zone.allowedAnimals, animalId) then
        return AdvancedHunting.Security.Fail(source, 'register_invalid_animal', {animalId = animalId, zoneId = zoneId})
    end
    local count = 0
    for _, record in pairs(AdvancedHunting.ServerState.animals) do
        if record.owner == source and record.zoneId == zoneId then count = count + 1 end
    end
    if count >= (zone.maxAnimals or 5) then return AdvancedHunting.Security.Fail(source, 'zone_spawn_limit', {zoneId = zoneId}) end
    AdvancedHunting.ServerState.animals[netId] = {owner = source, animalId = animalId, zoneId = zoneId, createdAt = os.time()}
end)

RegisterNetEvent('advanced_hunting:server:unregisterAnimal', function(netId)
    local source = source
    local record = AdvancedHunting.ServerState.animals[netId]
    if record and record.owner == source then
        AdvancedHunting.ServerState.animals[netId] = nil
        AdvancedHunting.ServerState.processed[netId] = nil
    end
end)

RegisterNetEvent('advanced_hunting:server:skinAnimal', function(netId, animalId, coords, clientQuality, skillSuccess, weaponHash)
    local source = source
    if AdvancedHunting.AntiAbuse.IsOnCooldown(('skin:%s'):format(source), Config.Security.actionCooldown) then return end
    if not AdvancedHunting.Security.IsPlayerActive(source) then return AdvancedHunting.Security.Fail(source, 'skin_without_active_hunt', {netId = netId}) end
    if not AdvancedHunting.Security.ValidateKnife(source, weaponHash) then return end
    local record = AdvancedHunting.Security.ValidateAnimal(source, netId, animalId, coords, true)
    if not record then return end
    if not AdvancedHunting.Security.ValidateZone(source, coords, record.zoneId) then return end

    AdvancedHunting.ServerState.processed[netId] = true
    local quality = AdvancedHunting.Rewards.NormalizeQuality(source, clientQuality, skillSuccess)
    AdvancedHunting.Rewards.GrantSkinning(source, record, quality, skillSuccess)
    TriggerClientEvent('ox_lib:notify', source, {description = _L('skinning_success', quality), type = 'success'})
end)

RegisterNetEvent('advanced_hunting:server:butcherAnimal', function(netId, animalId, coords)
    local source = source
    if AdvancedHunting.AntiAbuse.IsOnCooldown(('butcher:%s'):format(source), Config.Security.actionCooldown) then return end
    if not AdvancedHunting.Security.IsPlayerActive(source) then return AdvancedHunting.Security.Fail(source, 'butcher_without_active_hunt', {netId = netId}) end
    local record = AdvancedHunting.ServerState.animals[netId]
    if not record or record.owner ~= source or record.animalId ~= animalId then
        return AdvancedHunting.Security.Fail(source, 'invalid_butcher_record', {netId = netId, animalId = animalId})
    end
    if not AdvancedHunting.ServerState.processed[netId] then return AdvancedHunting.Security.Fail(source, 'butcher_before_skin', {netId = netId}) end
    if not AdvancedHunting.Security.ValidateZone(source, coords, record.zoneId) then return end
    AdvancedHunting.Rewards.GrantButcher(source, record)
    AdvancedHunting.ServerState.animals[netId] = nil
    AdvancedHunting.ServerState.processed[netId] = nil
end)

AddEventHandler('playerDropped', function()
    local source = source
    AdvancedHunting.ServerState.players[source] = nil
    for netId, record in pairs(AdvancedHunting.ServerState.animals) do
        if record.owner == source then
            AdvancedHunting.ServerState.animals[netId] = nil
            AdvancedHunting.ServerState.processed[netId] = nil
        end
    end
end)
