Config = {}

Config.Debug = false
Config.Locale = 'en'

Config.KeyItem = 'vehiclekey'
Config.AllowedKeyItems = {
    vehiclekey = true,
    keycard = true,
    keys = true
}

Config.LockDistance = 8.0
Config.GiveDistance = 4.0
Config.DriverSeatIndex = -1
Config.VehicleCheckInterval = 700
Config.KeyCacheTtl = 3500
Config.LockCommand = 'vlock'
Config.MenuCommand = 'keys'

Config.EnablePreventDriverEntry = true
Config.EnableEngineImmobilizer = true
Config.AutoGiveKeyForOwnedVehicle = true
Config.AutoGiveKeyFromGarage = true

-- Events emitted by common garage resources after spawning a vehicle. Add your own esx_garage event here.
Config.GarageSpawnEvents = {
    'esx_garage:spawnedVehicle',
    'esx_garage:client:spawnedVehicle',
    'garage:client:vehicleSpawned'
}

-- Allow specified jobs to operate matching vehicle models without permanent keys.
Config.JobAccess = {
    police = { enabled = true, grades = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true }, models = { police = true, police2 = true, police3 = true, sheriff = true } },
    ambulance = { enabled = true, grades = false, models = { ambulance = true } },
    mechanic = { enabled = true, grades = false, models = false }
}

-- If not empty, only these model names can receive managed keys.
Config.ModelWhitelist = {
    enabled = false,
    models = {
        -- sultan = true
    }
}

Config.Lockpick = {
    enabled = true,
    doorItem = 'lockpick',
    hotwireItem = 'advancedlockpick',
    doorDuration = 9000,
    hotwireDuration = 14000,
    doorSuccessChance = 55,
    hotwireSuccessChance = 40,
    toolBreakChanceOnSuccess = 12,
    toolBreakChanceOnFail = 45,
    cooldownSeconds = 90,
    hotwireAccessMinutes = 20,
    alertPoliceOnFail = true,
    alertPoliceChance = 65,
    alarmSeconds = 20
}

-- Server event called when a lockpick/hotwire police alert should be dispatched.
-- Replace with your dispatch resource event if desired.
Config.PoliceAlertEvent = 'amir_vehiclekeys:server:policeAlert'

Config.Notifications = {
    position = 'top-right'
}
