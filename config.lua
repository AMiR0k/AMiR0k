Config = {}

Config.Debug = false

Config.FarmCount = 200
Config.PurchasePrice = 100000
Config.OwnershipDays = 30
Config.GrowthMinutes = 45
Config.PlantLifeHours = 24
Config.InitialStorageKg = 250
Config.UpgradedStorageKg = 500
Config.StorageUpgradePrice = 50000
Config.StorageSlots = 60
Config.MarkerDrawDistance = 25.0
Config.InteractDistance = 1.8
Config.Marker = {
    type = 2,
    scale = vector3(0.35, 0.35, 0.35),
    color = { r = 40, g = 220, b = 70, a = 180 }
}

Config.Management = {
    coords = vector3(93.99, 6356.12, 31.38),
    blip = {
        sprite = 496,
        color = 2,
        scale = 0.85,
        label = 'F - Farm'
    }
}

Config.Farm = {
    spawn = vector3(200.24, 6470.9, 31.88),
    exit = vector3(200.24, 6470.9, 31.88),
    center = vector3(250.89, 6474.34, 30.85),
    radius = 35.0,
    returnTo = vector3(93.99, 6356.12, 31.38),
    baseBucket = 5000
}

Config.Animations = {
    plant = {
        dict = 'amb@world_human_gardener_plant@male@base',
        clip = 'base',
        duration = 8000,
        label = 'در حال کاشت...'
    },
    harvest = {
        dict = 'amb@world_human_gardener_plant@male@idle_a',
        clip = 'idle_a',
        duration = 6500,
        label = 'در حال برداشت...'
    }
}

-- Seed -> product -> real GTA prop mapping. Add labels to keep menus readable.
Config.Crops = {
    wheat_seed = { product = 'wheat', label = 'Wheat', prop = 'prop_veg_crop_03_pump' },
    barley_seed = { product = 'barley', label = 'Barley', prop = 'prop_veg_crop_04' },
    corn_seed = { product = 'corn', label = 'Corn', prop = 'prop_veg_crop_03_cab' },
    cannabis_seed = { product = 'cannabis', label = 'Cannabis', prop = 'bkr_prop_weed_med_01a' },
    poppy_seed = { product = 'poppy', label = 'Poppy', prop = 'prop_plant_01a' },
    coca_seed = { product = 'coca', label = 'Coca', prop = 'prop_plant_int_02a' },
    khat_seed = { product = 'khat', label = 'Khat', prop = 'prop_plant_int_04a' },
    ephedra_seed = { product = 'ephedra', label = 'Ephedra', prop = 'prop_plant_int_03a' },
    peyote_seed = { product = 'peyote', label = 'Peyote', prop = 'prop_peyote_lowland_01' },
    mushroom_spore = { product = 'mushroom', label = 'Mushroom', prop = 'prop_stoneshroom1' },
    datura_seed = { product = 'datura', label = 'Datura', prop = 'prop_plant_int_05a' },
    salvia_seed = { product = 'salvia', label = 'Salvia', prop = 'prop_plant_int_01a' }
}

Config.SeedOrder = {
    'wheat_seed', 'barley_seed', 'corn_seed', 'cannabis_seed', 'poppy_seed', 'coca_seed',
    'khat_seed', 'ephedra_seed', 'peyote_seed', 'mushroom_spore', 'datura_seed', 'salvia_seed'
}

Config.Harvest = {
    productMin = 20,
    productMax = 30,
    seedMin = 1,
    seedMax = 5
}

Config.SlotGrid = {
    rows = 5,
    columns = 6,
    firstRowFirst = vector3(209.2, 6475.82, 31.58),
    firstRowLast = vector3(286.54, 6482.05, 30.02),
    lastRowFirst = vector3(210.56, 6465.84, 31.79),
    lastRowLast = vector3(287.19, 6472.07, 30.45)
}

local function lerp(a, b, t)
    return vector3(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t)
end

local function buildSlots()
    local slots = {}
    local rows, columns = Config.SlotGrid.rows, Config.SlotGrid.columns

    for row = 1, rows do
        local rowT = rows == 1 and 0.0 or (row - 1) / (rows - 1)
        local rowStart = lerp(Config.SlotGrid.firstRowFirst, Config.SlotGrid.lastRowFirst, rowT)
        local rowEnd = lerp(Config.SlotGrid.firstRowLast, Config.SlotGrid.lastRowLast, rowT)

        for column = 1, columns do
            local colT = columns == 1 and 0.0 or (column - 1) / (columns - 1)
            slots[#slots + 1] = {
                id = #slots + 1,
                coords = lerp(rowStart, rowEnd, colT)
            }
        end
    end

    return slots
end

-- 30 exact cultivation slots calculated from the four configured corners on resource load.
Config.FarmSlots = buildSlots()
