Config = {}

Config.Debug = false

Config.Job = {
    name = 'Oil Runner',
    jobName = 'oilrunner',
    jobGrade = 0,
    restoreFallback = { name = 'unemployed', grade = 0 },
    deposit = 100000,
    reward = { min = 10000, max = 30000 },
    loadDuration = 420000, -- 7 minutes
    deliverDuration = 300000 -- 5 minutes
}

Config.Locations = {
    jobStart = vector3(1240.76, -3257.43, 6.92),
    tugMenu = vector3(1297.0, -3260.35, 5.91),
    tugSpawn = vector4(1305.67, -3237.23, 1.1, 359.37),
    tugReturn = vector3(1328.69, -3186.44, 1.57),
    returnTeleport = vector3(1296.37, -3241.43, 5.91),
    loadOil = vector3(4134.29, -2513.87, 1.38),
    deliverOil = vector3(4920.6, -5149.54, 0.85)
}

Config.Vehicle = {
    model = 'tug',
    fuel = 100.0,
    fuelRetryCount = 6,
    fuelRetryDelay = 2500,
    spawnCheckRadius = 8.0
}

Config.Marker = {
    drawDistance = 35.0,
    interactDistance = 2.5,
    type = 1,
    scale = vector3(2.2, 2.2, 1.0),
    colour = { r = 245, g = 166, b = 35, a = 160 }
}

Config.Blip = {
    sprite = 477,
    colour = 47,
    scale = 0.8,
    label = 'Oil Runner'
}

Config.RouteBlips = {
    tugMenu = { sprite = 410, colour = 47, scale = 0.75, label = 'Oil Runner Tug Station' },
    tugReturn = { sprite = 410, colour = 47, scale = 0.75, label = 'Return Oil Runner Tug' },
    loadOil = { sprite = 436, colour = 47, scale = 0.75, label = 'Load Oil' },
    deliverOil = { sprite = 479, colour = 47, scale = 0.75, label = 'Deliver Oil' }
}

-- Basic work outfit. Adjust component values for your clothing pack/server needs.
Config.WorkOutfit = {
    male = {
        ['tshirt_1'] = 59, ['tshirt_2'] = 0,
        ['torso_1'] = 65, ['torso_2'] = 0,
        ['arms'] = 31,
        ['pants_1'] = 38, ['pants_2'] = 0,
        ['shoes_1'] = 25, ['shoes_2'] = 0,
        ['helmet_1'] = 0, ['helmet_2'] = 0
    },
    female = {
        ['tshirt_1'] = 36, ['tshirt_2'] = 0,
        ['torso_1'] = 59, ['torso_2'] = 0,
        ['arms'] = 36,
        ['pants_1'] = 38, ['pants_2'] = 0,
        ['shoes_1'] = 25, ['shoes_2'] = 0,
        ['helmet_1'] = 0, ['helmet_2'] = 0
    }
}

Config.Notifications = {
    started = 'Oil Runner job started. Head to the tug station.',
    stopped = 'Oil Runner job stopped. Your outfit has been restored.',
    returnTugFirst = 'Return your active tug before stopping the job.',
    noCash = 'You need $100,000 cash for the refundable tug deposit.',
    tugSpawned = 'Tug spawned. Your $100,000 deposit was paid. GPS set to the oil loading point.',
    alreadyTug = 'You already have an active tug.',
    spawnBlocked = 'The tug spawn point is blocked.',
    notInTug = 'You must be driving your registered tug.',
    loadingStarted = 'Loading oil. Stay in the tug until loading is complete.',
    oilLoaded = 'Oil loaded. GPS set to the delivery point.',
    alreadyOil = 'Your tug already has oil loaded.',
    deliveryStarted = 'Delivering oil. Stay in the tug until delivery is complete.',
    deliveryPaid = 'Oil delivered. You received $%s. GPS set back to the loading point.',
    tugReturned = 'Tug returned successfully. Your $100,000 deposit has been refunded.',
    warpFailed = 'Tug spawned, but you could not be seated automatically. Enter your registered tug to continue.',
    actionCancelled = 'Action cancelled.'
}
