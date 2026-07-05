Config = {}

Config.Locale = 'en'
Config.Debug = false
Config.JobName = 'rentcar'
Config.MinimumOwnedVehicles = 5
Config.DefaultDeposit = 10000

Config.JobCenter = {
    coords = vec3(-33.74, -1102.32, 26.42),
    size = vec3(1.8, 1.8, 2.0),
    rotation = 70.0,
    marker = { type = 36, color = { r = 46, g = 204, b = 113, a = 180 } }
}

Config.RentalLots = {
    { id = 'premium_del_perro', label = 'Del Perro Rental Lot', coords = vec4(-1455.13, -674.81, 26.47, 124.0) },
    { id = 'airport_public', label = 'Airport Rental Lot', coords = vec4(-1033.62, -2730.39, 20.17, 239.0) },
    { id = 'sandy_public', label = 'Sandy Shores Rental Lot', coords = vec4(1728.91, 3710.32, 34.26, 21.0) }
}

Config.RentalDurations = {
    { label = '30 minutes', minutes = 30 },
    { label = '1 hour', minutes = 60 },
    { label = '2 hours', minutes = 120 },
    { label = '4 hours', minutes = 240 },
    { label = '8 hours', minutes = 480 },
    { label = '12 hours', minutes = 720 },
    { label = '24 hours', minutes = 1440 }
}

Config.DefaultPricePerHour = 10000
Config.MaxRentalHours = 24
Config.ServerCommissionPercent = 10
Config.TaxPercent = 0
Config.PaymentMethods = { cash = true, bank = true }
Config.PayOwnerImmediately = true
Config.OwnerSocietyAccount = nil -- Example: 'society_rentcar' for commission/tax sink, nil disables society deposit.

Config.SpawnDistance = 75.0
Config.DeleteDistance = 125.0
Config.TargetDistance = 3.0
Config.JobInteractDistance = 2.0
Config.ExpirationCheckSeconds = 60
Config.RenterExitCheckSeconds = 5

Config.GarageStates = {
    inGarage = 1,
    out = 0,
    rental = 3,
    impound = 2
}

Config.AdminGroups = {
    admin = true,
    superadmin = true
}

Config.Commands = {
    ownerPanel = 'rentals',
    adminPanel = 'rentadmin'
}

Config.Notifications = {
    positionVehicle = 'Park your vehicle in a configured rental slot first.',
    noPermission = 'You are not allowed to do this.',
    expired = 'Rental time has expired. Please stop the vehicle.',
    vehicleImpounded = 'Rental vehicle has been moved to impound.',
    paid = 'Rental payment completed.',
    jobGranted = 'You are now employed by the car rental company.',
    notEnoughVehicles = 'You must own at least %s vehicles to join this job.'
}
