AdvancedHunting = AdvancedHunting or {}
AdvancedHunting.Security = AdvancedHunting.Security or {}
AdvancedHunting.ServerState = AdvancedHunting.ServerState or {players = {}, animals = {}, processed = {}}

local Security = AdvancedHunting.Security

function Security.Fail(source, reason, data)
    AdvancedHunting.Logging.Write('exploit', source, reason, data)
    TriggerClientEvent('ox_lib:notify', source, {description = _L('exploit_detected'), type = 'error'})
    return false
end

function Security.IsPlayerActive(source)
    return AdvancedHunting.ServerState.players[source] and AdvancedHunting.ServerState.players[source].active == true
end

function Security.ValidateZone(source, coords, zoneId)
    local zone = HuntingZones[zoneId]
    if not zone then return Security.Fail(source, 'invalid_zone', {zoneId = zoneId}) end
    local ped = GetPlayerPed(source)
    local serverCoords = GetEntityCoords(ped)
    local checkedCoords = coords and vector3(coords.x, coords.y, coords.z) or serverCoords
    if #(serverCoords - zone.center) > zone.radius + 25.0 or #(checkedCoords - zone.center) > zone.radius + 25.0 then
        return Security.Fail(source, 'outside_zone', {zoneId = zoneId})
    end
    return true
end

function Security.ValidateKnife(source, weaponHash)
    local selected = GetSelectedPedWeapon(GetPlayerPed(source))
    if not AdvancedHunting.Utils.IsAllowedSkinningWeapon(selected) and not AdvancedHunting.Utils.IsAllowedSkinningWeapon(weaponHash) then
        return Security.Fail(source, 'invalid_skinning_weapon', {selected = selected, sent = weaponHash})
    end
    return true
end

function Security.ValidateAnimal(source, netId, animalId, coords, requireDead)
    local record = AdvancedHunting.ServerState.animals[netId]
    if not record then return Security.Fail(source, 'unknown_animal', {netId = netId}) end
    if record.animalId ~= animalId then return Security.Fail(source, 'animal_mismatch', {netId = netId, animalId = animalId}) end
    if Config.Security.animalOwnershipRequired and record.owner ~= source then
        return Security.Fail(source, 'animal_owner_mismatch', {owner = record.owner, netId = netId})
    end
    if AdvancedHunting.ServerState.processed[netId] then
        TriggerClientEvent('ox_lib:notify', source, {description = _L('already_processed'), type = 'error'})
        return false
    end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity ~= 0 and DoesEntityExist(entity) then
        if requireDead and not IsEntityDead(entity) then return Security.Fail(source, 'animal_not_dead', {netId = netId}) end
        local pedCoords = GetEntityCoords(GetPlayerPed(source))
        local entityCoords = GetEntityCoords(entity)
        if #(pedCoords - entityCoords) > Config.Security.maxActionDistance then
            return Security.Fail(source, 'too_far_from_animal', {distance = #(pedCoords - entityCoords)})
        end
    elseif coords then
        local pedCoords = GetEntityCoords(GetPlayerPed(source))
        local sentCoords = vector3(coords.x, coords.y, coords.z)
        if #(pedCoords - sentCoords) > Config.Security.maxActionDistance then
            return Security.Fail(source, 'too_far_from_sent_animal', {distance = #(pedCoords - sentCoords)})
        end
    end
    return record
end
