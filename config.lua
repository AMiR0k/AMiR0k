Config = {}

Config.Locale = 'en'
Config.DrawDistance = 100.0
Config.CopsRequired = 5
Config.CooldownMinutes = 15
Config.BlipUpdateTime = 3000
Config.SingleActiveMission = true
Config.PoliceJobs = {
    police = true,
    sheriff = true
}

Config.AbandonTimeout = 60 -- Seconds outside the mission vehicle before failing.
Config.AbandonWarningTime = 50 -- Seconds before the final abandon warning.
Config.MinDeliverySpeed = 3.0 -- Vehicle speed must be lower than this to finish.
Config.FinishDistance = 8.0 -- Server-side distance check from vehicle to delivery point.
Config.SpawnClearRadius = 5.0
Config.SpawnTimeout = 10000
Config.PayAccount = 'black_money' -- Use 'money', 'bank', or an ESX account name.

Config.VehicleKeys = {
    enabled = false,
    item = 'vehicle_key',
    removeOnFinish = true
    -- Integrate your external key system in server/main.lua:giveVehicleKey if needed.
}

Config.StartZone = {
    coords = vec3(759.01, -3195.18, 4.97),
    radius = 3.0,
    marker = {
        type = 1,
        size = vec3(3.0, 3.0, 1.0),
        color = { r = 204, g = 204, b = 0, a = 100 }
    },
    blip = {
        sprite = 229,
        color = 6,
        scale = 1.0,
        label = 'vehicle_robbery'
    }
}

Config.VehicleSpawnPoint = {
    coords = vec4(767.71, -3195.20, 5.50, 0.00)
}

Config.DeliveryMarker = {
    type = 1,
    size = vec3(5.0, 5.0, 1.0),
    color = { r = 204, g = 204, b = 0, a = 100 }
}

Config.PoliceBlip = {
    sprite = 161,
    color = 8,
    scale = 2.0,
    label = 'police_blip'
}

Config.DeliveryBlip = {
    sprite = 1,
    color = 5,
    scale = 1.0,
    label = 'delivery_point'
}

Config.Deliveries = {
    {
        label = 'Trevor Airfield',
        coords = vec3(2130.68, 4781.32, 39.87),
        payment = 500000,
        cars = { 'zentorno', 't20', 'reaper', 'italigtb', 'pfister811' }
    },
    {
        label = 'Lighthouse',
        coords = vec3(3333.51, 5159.91, 17.20),
        payment = 600000,
        cars = { 'sultanrs', 'osiris', 'cyclone', 'ruston', 'turismor' }
    },
    {
        label = 'House in Paleto',
        coords = vec3(-437.56, 6254.53, 29.02),
        payment = 700000,
        cars = { 'entityxf', 'sheava', 'gp1', 'vagner', 'neon' }
    },
    {
        label = 'Great Ocean Highway',
        coords = vec3(-2177.51, 4269.51, 47.93),
        payment = 800000,
        cars = { 'nero', 'seven70', 'tempesta', 'xa21', 'raiden' }
    },
    {
        label = 'Marina Drive Desert',
        coords = vec3(895.02, 3603.87, 31.72),
        payment = 900000,
        cars = { 'specter', 'comet5', 'nightshade', 'sc1', 'banshee2' }
    }
}
