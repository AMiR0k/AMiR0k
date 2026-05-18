VehicleKeys = VehicleKeys or {}

function VehicleKeys.Trim(value)
    if type(value) ~= 'string' then return '' end
    return (value:gsub('^%s*(.-)%s*$', '%1'))
end

function VehicleKeys.NormalizePlate(plate)
    plate = VehicleKeys.Trim(plate):upper()
    return plate:gsub('%s+', '')
end

function VehicleKeys.DisplayPlate(plate)
    return VehicleKeys.Trim(plate):upper()
end

function VehicleKeys.ModelName(model)
    if type(model) == 'number' then
        return tostring(model)
    end

    model = VehicleKeys.Trim(model)
    if model == '' then return 'unknown' end
    return model:lower()
end

function VehicleKeys.KeyLabel(plate, model)
    local cleanPlate = VehicleKeys.DisplayPlate(plate)
    local modelName = VehicleKeys.ModelName(model)
    return ('Vehicle Key - %s (%s)'):format(cleanPlate, modelName)
end

function VehicleKeys.KeyMetadata(plate, model, ownerIdentifier)
    local displayPlate = VehicleKeys.DisplayPlate(plate)
    local modelName = VehicleKeys.ModelName(model)

    return {
        plate = VehicleKeys.NormalizePlate(displayPlate),
        displayPlate = displayPlate,
        vehicle_model = modelName,
        owner = ownerIdentifier,
        label = VehicleKeys.KeyLabel(displayPlate, modelName),
        description = ('Plate: %s | Model: %s'):format(displayPlate, modelName)
    }
end

function VehicleKeys.Debug(message, ...)
    if not Config or not Config.Debug then return end
    local formatted = message
    if select('#', ...) > 0 then
        formatted = message:format(...)
    end
    print(('[amir_vehiclekeys] %s'):format(formatted))
end

function VehicleKeys.IsModelAllowed(model)
    if not Config.ModelWhitelist or not Config.ModelWhitelist.enabled then return true end
    local modelName = VehicleKeys.ModelName(model)
    return Config.ModelWhitelist.models[modelName] == true
end
