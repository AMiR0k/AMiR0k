Config = {}

Config.Debug = false

Config.Settings = {
    weldTimer = 250, -- seconds
    maxcash = 15000,
    mincash = 6000,
    black = true,
    cooldown = 1800, -- per bank cooldown (seconds)
    globalCooldown = 600, -- global cooldown (seconds)
    mincops = 0,
    interactDistance = 2.0,
    markerDistance = 12.0,
    antiSpam = 2,
}

Config.Items = {
    hack = 'hacker_device',
    weld = 'blowtorch'
}

Config.Markers = {
    type = 2,
    scale = vec3(0.25, 0.25, 0.25),
    colorStart = { r = 0, g = 140, b = 255, a = 180 },
    colorWeld = { r = 255, g = 120, b = 0, a = 180 },
    bobUpAndDown = false,
    faceCamera = false
}

Config.Locale = {
    interact_start = 'Press ~INPUT_CONTEXT~ to start robbery',
    interact_weld = 'Press ~INPUT_CONTEXT~ to weld the vault',
    cooldown_global = 'All banks are on global cooldown for %s seconds.',
    cooldown_bank = 'This bank is on cooldown for %s seconds.',
    too_far = 'You are too far away from the interaction point.',
    missing_item = 'Required item missing: %s',
    hack_start = 'Hack started...',
    hack_success = 'Hack successful. Go to the weld point.',
    hack_failed = 'Hack failed.',
    weld_progress = 'Welding in progress...',
    weld_done = 'Vault opened. Reward received.',
    weld_canceled = 'Welding canceled.',
    robbery_busy = 'You already have an active robbery.',
    need_cops = 'Not enough police online. Required: %s',
    invalid_bank = 'Invalid bank selected.',
    already_started = 'Robbery already started for this bank.'
}

Config.Banks = {
    sandy = {
        label = 'Sandy',
        start = vec3(1176.04, 2712.86, 38.09),
        weld = vec3(1173.26, 2716.5, 38.07)
    },
    saheli = {
        label = 'Saheli',
        start = vec3(-2956.57, 481.7, 15.7),
        weld = vec3(-2952.92, 484.35, 15.68)
    },
    bimeh = {
        label = 'Bimeh',
        start = vec3(-1210.81, -336.56, 37.78),
        weld = vec3(-1206.49, -338.28, 37.76)
    },
    mechanic = {
        label = 'Mechanic',
        start = vec3(-353.86, -55.29, 49.04),
        weld = vec3(-352.3, -59.84, 49.01)
    },
    shargh = {
        label = 'Shargh',
        start = vec3(311.21, -284.42, 54.16),
        weld = vec3(312.65, -289.0, 54.14)
    }
}

Config.Server = {
    eventPrefix = 'smallbank',
}
