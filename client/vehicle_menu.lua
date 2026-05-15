OKGangs = OKGangs or {}
OKGangs.Client = OKGangs.Client or {}

local function spawnAtLocation(vehicle, vehicleType)
    local gang = OKGangs.Client.myGang
    local key = vehicleType == 'helicopter' and 'heli_spawn' or 'vehicle_spawn'
    local loc = gang.locations and gang.locations[key]
    if not loc or not loc.coords then return lib.notify({ description = 'No spawn point configured', type = 'error' }) end
    local model = joaat(vehicle.model)
    lib.requestModel(model)
    local ent = CreateVehicle(model, loc.coords.x, loc.coords.y, loc.coords.z, loc.coords.w or 0.0, true, false)
    if vehicle.props then lib.setVehicleProperties(ent, vehicle.props) end
    SetVehicleNumberPlateText(ent, vehicle.plate)
    TaskWarpPedIntoVehicle(cache.ped, ent, -1)
    SetModelAsNoLongerNeeded(model)
end

function OKGangs.Client.OpenVehicleMenu(gang, vehicleType)
    local vehicles = lib.callback.await('ok_gangs:server:getVehicles', false, vehicleType) or {}
    local options = {}
    for _, vehicle in ipairs(vehicles) do
        options[#options + 1] = { title = vehicle.label or vehicle.model, description = ('Plate: %s | Rank: %s'):format(vehicle.plate, vehicle.min_rank), onSelect = function()
            local ok, result = lib.callback.await('ok_gangs:server:spawnVehicle', false, vehicle.plate)
            if ok then spawnAtLocation(result, vehicleType) else lib.notify({ description = tostring(result), type = 'error' }) end
        end }
    end
    lib.registerContext({ id = 'ok_gangs_vehicle_' .. vehicleType, title = vehicleType == 'helicopter' and 'Helicopter Garage' or 'Car Garage', options = options })
    lib.showContext('ok_gangs_vehicle_' .. vehicleType)
end

function OKGangs.Client.StoreCurrentVehicle(gang, vehicleType)
    local vehicle = cache.vehicle or GetVehiclePedIsIn(cache.ped, false)
    if vehicle == 0 then return lib.notify({ description = 'Not in vehicle', type = 'error' }) end
    local props = lib.getVehicleProperties(vehicle)
    local input = lib.inputDialog('Store Vehicle', { { type = 'checkbox', label = 'Personal vehicle parking' } })
    local personal = input and input[1] or false
    local ok, result = lib.callback.await('ok_gangs:server:storeVehicle', false, props, vehicleType, personal)
    if ok then DeleteEntity(vehicle) end
    lib.notify({ description = ok and 'Stored' or tostring(result), type = ok and 'success' or 'error' })
end
