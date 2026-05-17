Config = Config or {}

Config.Locale = 'en'
Config.Debug = false

Config.Framework = {
    esxExport = 'es_extended',
    appearance = 'auto' -- auto, esx_skin, illenium, none
}

Config.Inventory = {
    resource = 'ox_inventory',
    knifeItem = 'hunting_knife'
}

Config.Security = {
    actionCooldown = 2500,
    maxRegisterDistance = 450.0,
    maxActionDistance = 4.0,
    maxSellDistance = 5.0,
    animalOwnershipRequired = true,
    cleanupOnResourceStop = true,
    logWebhook = ''
}

Config.Spawn = {
    enabled = true,
    spawnDistance = 120.0,
    despawnDistance = 340.0,
    spawnCooldown = 45000,
    retryDelay = 2500,
    groundProbeHeight = 80.0,
    minPlayerDistance = 45.0,
    maxSpawnAttempts = 20
}

Config.Skinning = {
    duration = 8500,
    skillCheck = {'easy', 'medium', 'medium'},
    qualityOnFailPenalty = 1,
    failMeatMultiplier = 0.45,
    requiredItem = 'hunting_knife',
    allowedKnives = {
        [`WEAPON_KNIFE`] = true,
        [`WEAPON_DAGGER`] = true,
        [`WEAPON_SWITCHBLADE`] = true,
        [`WEAPON_HATCHET`] = true,
        [`WEAPON_BATTLEAXE`] = true,
        [`WEAPON_MACHETE`] = true
    },
    allowedKnifeNames = {
        WEAPON_KNIFE = true,
        WEAPON_DAGGER = true,
        WEAPON_SWITCHBLADE = true,
        WEAPON_HATCHET = true,
        WEAPON_BATTLEAXE = true,
        WEAPON_MACHETE = true
    }
}

Config.Quality = {
    order = {'perfect', 'good', 'damaged', 'ruined'},
    default = 'good',
    headshotBonus = 1,
    levelPerfectBonusEvery = 10,
    weaponModifiers = {
        [`WEAPON_MUSKET`] = 1,
        [`WEAPON_SNIPERRIFLE`] = 0,
        [`WEAPON_MARKSMANRIFLE`] = 0,
        [`WEAPON_PISTOL`] = -1,
        [`WEAPON_COMBATPISTOL`] = -1,
        [`WEAPON_ASSAULTRIFLE`] = -1,
        [`WEAPON_PUMPSHOTGUN`] = -3,
        [`WEAPON_SAWNOFFSHOTGUN`] = -3,
        [`WEAPON_GRENADE`] = -4,
        [`WEAPON_RPG`] = -4,
        [`WEAPON_EXPLOSION`] = -4
    }
}

Config.XP = {
    enabled = true,
    tableName = 'advanced_hunting_xp',
    baseLevelXP = 100,
    levelMultiplier = 1.35,
    rewardMultiplierPerLevel = 0.015
}

Config.StartStop = {
    requireActiveHunt = true,
    markerDistance = 35.0,
    interactDistance = 2.5,
    start = vector3(-567.69, 5252.89, 70.49),
    stop = vector3(-560.33, 5258.10, 70.48),
    marker = {
        type = 2,
        scale = vector3(0.55, 0.55, 0.55),
        color = {r = 34, g = 139, b = 34, a = 180},
        bobUpAndDown = true,
        rotate = true,
        text = '[E] %s'
    },
    blip = {
        enabled = true,
        sprite = 141,
        color = 25,
        scale = 0.85,
        label = 'Paleto Hunting Grounds',
        radiusColor = 25,
        radiusAlpha = 70
    }
}

Config.Outfit = {
    enabled = true,
    male = {
        tshirt_1 = 15,
        torso_1 = 65,
        pants_1 = 38,
        shoes_1 = 12
    },
    female = {
        tshirt_1 = 14,
        torso_1 = 59,
        pants_1 = 38,
        shoes_1 = 27
    }
}
