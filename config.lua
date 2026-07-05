Config = {}

Config.Locale = 'en'
Config.Debug = false
Config.JobName = 'car_rental'
Config.JobGrade = 0
Config.AdminGroups = { admin = true, superadmin = true }

Config.JobCenter = {
    coords = vec3(-549.26, -191.74, 38.22),
    heading = 210.0,
    npc = { enabled = true, model = `a_m_y_business_03` },
    targetDistance = 2.0,
    marker = { enabled = true, type = 2, drawDistance = 25.0, size = vec3(0.35, 0.35, 0.35), color = { r = 30, g = 144, b = 255, a = 180 } },
    blip = { enabled = true, sprite = 225, color = 3, scale = 0.8, label = 'Car Rental Job Center' }
}

Config.JobRequirements = {
    minimumOwnedVehicles = 5,
    licenseFee = 50000000,
    paymentAccount = 'bank'
}

Config.Rental = {
    defaultHourlyPrice = 10000,
    maxHours = 24,
    allowedDurations = {
        { label = '30 minutes', minutes = 30 },
        { label = '1 hour', minutes = 60 },
        { label = '2 hours', minutes = 120 },
        { label = '4 hours', minutes = 240 },
        { label = '8 hours', minutes = 480 },
        { label = '12 hours', minutes = 720 },
        { label = '24 hours', minutes = 1440 }
    },
    paymentMethods = { cash = true, bank = true },
    commissionPercent = 10,
    taxPercent = 0,
    deposit = { enabled = false, amount = 0 },
    keyExport = nil, -- Example: function(plate, target) exports['vehiclekeys']:GiveKeys(target, plate) end
    removeKeyExport = nil,
    spawnDistance = 40.0,
    deleteDistance = 120.0,
    plateTrim = true,
    ownerRevenueAccount = 'bank',
    impoundState = 2,
    rentalState = 3,
    garageState = 1,
    outState = 0,
    status = { available = 'available', rented = 'rented', impounded = 'impounded', cancelled = 'cancelled' }
}

Config.Parking = {
    marker = { enabled = true, type = 36, drawDistance = 35.0, size = vec3(0.8, 0.8, 0.8), color = { r = 0, g = 200, b = 120, a = 160 } },
    blip = { enabled = true, sprite = 524, color = 2, scale = 0.65, label = 'Rental Parking' },
    targetDistance = 2.5,
    occupancyRadius = 2.5,
    spawnClearRadius = 3.5,
    locations = {
        vec4(237.421509, -812.984009, 30.268751, 251.437439),
        vec4(238.725372, -810.603027, 30.272608, 246.257324),
        vec4(240.801605, -808.335999, 30.268263, 244.503860),
        vec4(241.751480, -806.078003, 30.290337, 253.923523),
        vec4(243.697174, -771.549255, 30.725445, 64.836861),
        vec4(239.865265, -782.092712, 30.617449, 70.486595),
        vec4(300.900513, -1362.726562, 31.830070, 142.688400)
    }
}

Config.Commands = {
    ownerPanel = 'rentalpanel',
    adminPanel = 'rentaladmin'
}

Config.Notifications = {
    position = 'top',
    rentalExpiryWarningMinutes = 5
}
