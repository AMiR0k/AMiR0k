local ESX = exports.es_extended:getSharedObject()
local rentals = {}

local function notify(src, msg, ntype)
    TriggerClientEvent('ox_lib:notify', src, { description = msg, type = ntype or 'inform' })
end

local function isAdmin(xPlayer)
    return xPlayer and Config.AdminGroups[xPlayer.getGroup()] == true
end

local function getOwnedVehicleCount(identifier)
    return MySQL.scalar.await('SELECT COUNT(*) FROM owned_vehicles WHERE owner = ?', { identifier }) or 0
end

local function setGarageState(plate, state)
    MySQL.update.await('UPDATE owned_vehicles SET stored = ? WHERE plate = ?', { state, plate })
end

local function refreshRental(id)
    local row = MySQL.single.await('SELECT * FROM rentcar_rentals WHERE id = ?', { id })
    if row then
        row.spawn_position = json.decode(row.spawn_position or '{}')
        row.vehicle = json.decode(row.vehicle or '{}')
        rentals[id] = row
        TriggerClientEvent('amir0k_rentcar:client:upsertRental', -1, row)
    end
end

local function deleteRentalEntity(id)
    TriggerClientEvent('amir0k_rentcar:client:deleteRentalEntity', -1, id)
end

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS rentcar_rentals (
        id INT NOT NULL AUTO_INCREMENT,
        owner_identifier VARCHAR(64) NOT NULL,
        owner_name VARCHAR(80) NOT NULL,
        renter_identifier VARCHAR(64) NULL,
        renter_name VARCHAR(80) NULL,
        plate VARCHAR(16) NOT NULL,
        vehicle LONGTEXT NOT NULL,
        vehicle_label VARCHAR(80) NOT NULL,
        spawn_position LONGTEXT NOT NULL,
        rental_start BIGINT NULL,
        rental_end BIGINT NULL,
        status VARCHAR(20) NOT NULL DEFAULT 'available',
        price_per_hour INT NOT NULL DEFAULT 0,
        total_price INT NOT NULL DEFAULT 0,
        deposit INT NOT NULL DEFAULT 0,
        revenue INT NOT NULL DEFAULT 0,
        commission INT NOT NULL DEFAULT 0,
        tax INT NOT NULL DEFAULT 0,
        collected TINYINT NOT NULL DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id), UNIQUE KEY uniq_plate (plate), KEY idx_owner (owner_identifier), KEY idx_status (status)
    )]])

    local rows = MySQL.query.await('SELECT * FROM rentcar_rentals WHERE status IN (?, ?)', { 'available', 'rented' }) or {}
    for _, row in ipairs(rows) do
        row.spawn_position = json.decode(row.spawn_position or '{}')
        row.vehicle = json.decode(row.vehicle or '{}')
        rentals[row.id] = row
    end
    TriggerClientEvent('amir0k_rentcar:client:syncRentals', -1, rentals)
end)

lib.callback.register('amir0k_rentcar:server:getRentals', function()
    return rentals
end)

lib.callback.register('amir0k_rentcar:server:joinJob', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    local count = getOwnedVehicleCount(xPlayer.identifier)
    if count < Config.MinimumOwnedVehicles then
        notify(source, Config.Notifications.notEnoughVehicles:format(Config.MinimumOwnedVehicles), 'error')
        return false
    end
    xPlayer.setJob(Config.JobName, 0)
    notify(source, Config.Notifications.jobGranted, 'success')
    return true
end)

lib.callback.register('amir0k_rentcar:server:getOwnedVehicles', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or xPlayer.job.name ~= Config.JobName then return {} end
    return MySQL.query.await('SELECT plate, vehicle FROM owned_vehicles WHERE owner = ? AND stored = ?', { xPlayer.identifier, Config.GarageStates.inGarage }) or {}
end)

RegisterNetEvent('amir0k_rentcar:server:listVehicle', function(plate, props, lotId, pricePerHour, label)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or xPlayer.job.name ~= Config.JobName then return notify(src, Config.Notifications.noPermission, 'error') end
    pricePerHour = math.max(1, tonumber(pricePerHour) or Config.DefaultPricePerHour)
    plate = ESX.Math.Trim(plate or '')
    local lot
    for _, item in ipairs(Config.RentalLots) do if item.id == lotId then lot = item break end end
    if not lot or plate == '' or type(props) ~= 'table' then return end
    local owned = MySQL.single.await('SELECT plate FROM owned_vehicles WHERE owner = ? AND plate = ? AND stored = ?', { xPlayer.identifier, plate, Config.GarageStates.inGarage })
    if not owned or MySQL.scalar.await('SELECT id FROM rentcar_rentals WHERE plate = ? AND status IN (?, ?)', { plate, 'available', 'rented' }) then return end
    local id = MySQL.insert.await('INSERT INTO rentcar_rentals (owner_identifier, owner_name, plate, vehicle, vehicle_label, spawn_position, status, price_per_hour, deposit) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        xPlayer.identifier, xPlayer.getName(), plate, json.encode(props), label or plate, json.encode({ x = lot.coords.x, y = lot.coords.y, z = lot.coords.z, w = lot.coords.w, lot = lot.id, label = lot.label }), 'available', pricePerHour, Config.DefaultDeposit
    })
    setGarageState(plate, Config.GarageStates.rental)
    refreshRental(id)
end)

lib.callback.register('amir0k_rentcar:server:rentVehicle', function(source, id, minutes, account)
    local xPlayer = ESX.GetPlayerFromId(source)
    local rental = rentals[id]
    minutes = tonumber(minutes)
    if not xPlayer or not rental or rental.status ~= 'available' or not minutes then return false end
    if account ~= 'bank' then account = 'money' end
    if account == 'bank' and not Config.PaymentMethods.bank then return false end
    if account == 'money' and not Config.PaymentMethods.cash then return false end
    local allowed = false
    for _, duration in ipairs(Config.RentalDurations) do if duration.minutes == minutes then allowed = true break end end
    if not allowed or xPlayer.identifier == rental.owner_identifier then return false end
    local base = math.floor((rental.price_per_hour or Config.DefaultPricePerHour) * (minutes / 60))
    local deposit = rental.deposit or Config.DefaultDeposit
    local total = base + deposit
    if xPlayer.getAccount(account).money < total then return false end
    xPlayer.removeAccountMoney(account, total, 'Vehicle rental')
    local commission = math.floor(base * Config.ServerCommissionPercent / 100)
    local tax = math.floor(base * Config.TaxPercent / 100)
    local revenue = math.max(0, base - commission - tax)
    local now = os.time()
    MySQL.update.await('UPDATE rentcar_rentals SET renter_identifier = ?, renter_name = ?, rental_start = ?, rental_end = ?, status = ?, total_price = ?, revenue = ?, commission = ?, tax = ? WHERE id = ? AND status = ?', {
        xPlayer.identifier, xPlayer.getName(), now, now + (minutes * 60), 'rented', base, revenue, commission, tax, id, 'available'
    })
    if Config.PayOwnerImmediately then
        local owner = ESX.GetPlayerFromIdentifier(rental.owner_identifier)
        if owner then owner.addAccountMoney('bank', revenue, 'Vehicle rental revenue') end
    end
    refreshRental(id)
    TriggerClientEvent('amir0k_rentcar:client:rentalStarted', source, id, rental.plate)
    notify(source, Config.Notifications.paid, 'success')
    return true
end)

local function finishRental(id, toImpound)
    local rental = rentals[id]
    if not rental then return end
    setGarageState(rental.plate, toImpound and Config.GarageStates.impound or Config.GarageStates.rental)
    MySQL.update.await('UPDATE rentcar_rentals SET status = ?, renter_identifier = NULL, renter_name = NULL, rental_start = NULL, rental_end = NULL WHERE id = ?', { toImpound and 'impounded' or 'available', id })
    deleteRentalEntity(id)
    refreshRental(id)
end

RegisterNetEvent('amir0k_rentcar:server:finishAfterExit', function(id)
    local rental = rentals[id]
    local xPlayer = ESX.GetPlayerFromId(source)
    if rental and xPlayer and rental.renter_identifier == xPlayer.identifier and rental.rental_end and os.time() >= rental.rental_end then finishRental(id, true) end
end)

RegisterCommand(Config.Commands.ownerPanel, function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    local owned = {}
    for id, rental in pairs(rentals) do
        if rental.owner_identifier == xPlayer.identifier then owned[id] = rental end
    end
    TriggerClientEvent('amir0k_rentcar:client:openOwnerPanel', source, owned)
end, false)

RegisterCommand(Config.Commands.adminPanel, function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not isAdmin(xPlayer) then return notify(source, Config.Notifications.noPermission, 'error') end
    TriggerClientEvent('amir0k_rentcar:client:openAdminPanel', source, rentals)
end, false)

RegisterNetEvent('amir0k_rentcar:server:ownerAction', function(id, action)
    local xPlayer = ESX.GetPlayerFromId(source)
    local rental = rentals[id]
    if not xPlayer or not rental or rental.owner_identifier ~= xPlayer.identifier then return end
    if action == 'cancel' and rental.status == 'available' then finishRental(id, false) end
    if action == 'impound' and rental.status ~= 'rented' then finishRental(id, true) end
end)

RegisterNetEvent('amir0k_rentcar:server:adminAction', function(id, action, value)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not isAdmin(xPlayer) then return end
    if action == 'delete' then
        MySQL.update.await('UPDATE rentcar_rentals SET status = ? WHERE id = ?', { 'deleted', id })
        deleteRentalEntity(id); rentals[id] = nil; TriggerClientEvent('amir0k_rentcar:client:removeRental', -1, id)
    elseif action == 'release' then finishRental(id, false)
    elseif action == 'impound' then finishRental(id, true)
    elseif action == 'price' then
        MySQL.update.await('UPDATE rentcar_rentals SET price_per_hour = ? WHERE id = ?', { tonumber(value) or Config.DefaultPricePerHour, id }); refreshRental(id)
    elseif action == 'owner' then
        MySQL.update.await('UPDATE rentcar_rentals SET owner_identifier = ? WHERE id = ?', { tostring(value or ''), id }); refreshRental(id)
    end
end)

CreateThread(function()
    while true do
        Wait(Config.ExpirationCheckSeconds * 1000)
        for id, rental in pairs(rentals) do
            if rental.status == 'rented' and rental.rental_end and os.time() >= rental.rental_end then
                local renter = rental.renter_identifier and ESX.GetPlayerFromIdentifier(rental.renter_identifier)
                if renter then
                    TriggerClientEvent('amir0k_rentcar:client:rentalExpired', renter.source, id, rental.renter_identifier)
                else
                    finishRental(id, true)
                end
            end
        end
    end
end)
