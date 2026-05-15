Config = Config or {}

Config.Locale = 'en'
Config.AdminLevel = 11
Config.InteractDistance = 2.0
Config.PlayerActionDistance = 3.0
Config.VehicleStoreDistance = 8.0
Config.MarkerDistance = 20.0
Config.SalaryInterval = 15 * 60 * 1000
Config.ExpirationCheckInterval = 10 * 60 * 1000
Config.MoneyWashRate = 0.50
Config.MoneyWashCostPerOnlineMember = 25000
Config.MaxRank = 6
Config.BossRank = 6
Config.DefaultMemberSlots = 20
Config.DefaultExpireDays = 30
Config.MinExpireDays = 1
Config.MaxExpireDays = 365
Config.DefaultWebhook = ''
Config.Debug = false

Config.Keys = {
    gangMenu = 'F6',
    interact = 38
}

Config.Stashes = {
    stash = { slots = 100, weight = 1000000 },
    armory = { slots = 80, weight = 500000 }
}

Config.BlipDefaults = {
    sprite = 310,
    colour = 1,
    scale = 0.8
}
