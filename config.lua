Config = {}

Config.RequiredPolice = 3
Config.GlobalSingleRobbery = false -- true => only one store robbery at a time
Config.Cooldown = 1800 -- seconds per store after finish/cancel
Config.MaxDistance = 20.0 -- cancel distance while robbing
Config.InteractDistance = 1.25
Config.DrawDistance = 20.0
Config.RequireArmed = true
Config.RobberyDuration = 200 -- fallback if store.duration is nil

Config.PoliceJobs = {
    police = true,
    sheriff = true,
    special = true,
    fbi = true,
    cia = true
}

Config.Marker = {
    type = 1,
    size = vec3(1.0, 1.0, 1.2),
    color = { r = 220, g = 50, b = 50, a = 140 }
}

Config.DispatchBlip = {
    sprite = 161,
    color = 3,
    scale = 1.6,
    label = 'Ammunation Robbery'
}

Config.Rewards = {
    gangcoin = { item = 'gangcoin', min = 2, max = 4 },
    weapons = {
        { item = 'weapon_pistol', ammo = 24 },
        { item = 'weapon_snspistol', ammo = 24 },
        { item = 'weapon_microsmg', ammo = 48 },
        { item = 'weapon_minismg', ammo = 48 },
        { item = 'weapon_pistol50', ammo = 18 },
        { item = 'weapon_machete', ammo = 0 }
    }
}

Config.Stores = {
    AmmoNation1 = { label = 'Ammu-Nation (Cypress Flats)', coords = vec3(807.94, -2159.67, 29.63), duration = 200 },
    AmmoNation2 = { label = 'Ammu-Nation (Pillbox Hill)', coords = vec3(24.97, -1105.96, 29.80), duration = 200 },
    AmmoNation3 = { label = 'Ammu-Nation (La Mesa)', coords = vec3(839.86, -1035.80, 28.19), duration = 200 },
    AmmoNation4 = { label = 'Ammu-Nation (Cypress Flats)', coords = vec3(-659.70, -933.34, 21.83), duration = 200 },
    AmmoNation6 = { label = 'Ammu-Nation (Morningwood)', coords = vec3(-1304.25, -397.22, 36.70), duration = 200 },
    AmmoNation7 = { label = 'Ammu-Nation (Hawick)', coords = vec3(253.42, -53.13, 69.94), duration = 200 },
    AmmoNation8 = { label = 'Ammu-Nation (Tataviam Mountains)', coords = vec3(2565.40, 292.08, 108.63), duration = 200 },
    AmmoNation9 = { label = 'Ammu-Nation (Sandy Shores)', coords = vec3(1693.57, 3763.20, 34.71), duration = 200 },
    AmmoNation10 = { label = 'Ammu-Nation (Paleto Bay)', coords = vec3(-330.04, 6087.03, 31.45), duration = 200 },
    AmmoNation11 = { label = 'Ammu-Nation (Grand Senora)', coords = vec3(-1117.48, 2701.36, 18.55), duration = 200 }
}
