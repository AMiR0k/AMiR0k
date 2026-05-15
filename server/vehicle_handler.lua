OKGangs = OKGangs or {}
OKGangs.Server = OKGangs.Server or {}

local function randomPlate()
    return ('OKG%05d'):format(math.random(0, 99999))
end

function OKGangs.Server.GeneratePlate()
    local plate
    repeat
        plate = randomPlate()
    until not MySQL.scalar.await('SELECT plate FROM gang_vehicles WHERE plate = ? UNION SELECT plate FROM owned_vehicles WHERE plate = ? LIMIT 1', { plate, plate })
    return plate
end

lib.callback.register('ok_gangs:server:getVehicles', function(source, vehicleType)
    local gang, member = OKGangs.Server.RequireActiveGang(source)
    if not gang then return {} end
    local list = {}
    for _, vehicle in pairs(gang.vehicles) do
        if vehicle.type == vehicleType and vehicle.stored and member.rank >= vehicle.min_rank then list[#list + 1] = vehicle end
    end
    return list
end)

lib.callback.register('ok_gangs:server:spawnVehicle', function(source, plate)
    local gang, member = OKGangs.Server.RequireActiveGang(source)
    if not gang then return false, OKGangs.Errors.gang_inactive end
    local vehicle = gang.vehicles[plate]
    if not vehicle or not vehicle.stored then return false, 'vehicle unavailable' end
    if member.rank < vehicle.min_rank then return false, OKGangs.Errors.vehicle_access_denied end
    MySQL.update.await('UPDATE gang_vehicles SET stored = 0 WHERE plate = ?', { plate })
    vehicle.stored = false
    OKGangs.Server.Audit(gang.id, source, 'Vehicle Spawn', { plate = plate, model = vehicle.model })
    return true, vehicle
end)

lib.callback.register('ok_gangs:server:storeVehicle', function(source, props, vehicleType, personal)
    local gang, member = OKGangs.Server.RequireActiveGang(source)
    if not gang then return false, OKGangs.Errors.gang_inactive end
    if not props or not props.plate then return false, 'invalid vehicle' end
    local plate = props.plate:gsub('%s+', '')
    local existing = gang.vehicles[plate]
    if existing then
        MySQL.update.await('UPDATE gang_vehicles SET props = ?, stored = 1 WHERE plate = ?', { json.encode(props), plate })
        existing.props, existing.stored = props, true
    elseif personal then
        local xPlayer = ESX.GetPlayerFromId(source)
        local owned = MySQL.single.await('SELECT vehicle FROM owned_vehicles WHERE owner = ? AND REPLACE(plate, " ", "") = ?', { xPlayer.identifier, plate })
        if not owned then return false, 'not owner' end
        MySQL.insert.await('INSERT INTO gang_vehicles (gang_id, owner_identifier, plate, model, label, type, props, stored, min_rank, personal) VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, 1)', { gang.id, xPlayer.identifier, plate, props.model or 'unknown', plate, vehicleType or 'car', json.encode(props), member.rank })
    else
        return false, 'vehicle not registered'
    end
    OKGangs.Server.LoadCache()
    OKGangs.Server.Audit(gang.id, source, 'Vehicle Store', { plate = plate })
    return true
end)

RegisterNetEvent('ok_gangs:server:buyGangVehicle', function(model, label, vehicleType, minRank, props)
    local source = source
    local isBoss, gang = OKGangs.Server.IsBoss(source)
    if not isBoss then OKGangs.Notify(source, OKGangs.Errors.no_permission, 'error') return end
    local plate = (props and props.plate) or OKGangs.Server.GeneratePlate()
    MySQL.insert.await('INSERT INTO gang_vehicles (gang_id, plate, model, label, type, props, stored, min_rank, personal) VALUES (?, ?, ?, ?, ?, ?, 1, ?, 0)', { gang.id, plate, model, label or model, vehicleType or 'car', json.encode(props or { plate = plate, model = model }), math.max(1, math.min(Config.BossRank, tonumber(minRank) or 1)) })
    OKGangs.Server.LoadCache()
    OKGangs.Server.Audit(gang.id, source, 'Vehicle Store', { action = 'buy_for_gang', plate = plate, model = model })
end)

RegisterNetEvent('ok_gangs:server:removeVehicle', function(plate)
    local source = source
    local isBoss, gang = OKGangs.Server.IsBoss(source)
    if not isBoss then return end
    if not gang.vehicles[plate] then return end
    MySQL.update.await('DELETE FROM gang_vehicles WHERE plate = ? AND gang_id = ?', { plate, gang.id })
    OKGangs.Server.LoadCache()
    OKGangs.Server.Audit(gang.id, source, 'Vehicle Store', { action = 'remove', plate = plate })
end)
