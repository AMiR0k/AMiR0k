Config = {}

-- General job settings
Config.Locale = 'fa'
Config.TugModel = joaat('tug')
Config.Deposit = 100000
Config.Reward = { min = 10000, max = 30000 }
Config.LoadDuration = 420000 -- 7 minutes
Config.DeliverDuration = 300000 -- 5 minutes
Config.InteractDistance = 2.5
Config.DrawDistance = 35.0
Config.ValidationDistance = 20.0

-- Main locations
Config.Start = vector3(1240.76, -3257.43, 6.92)
Config.SpawnMenu = vector3(1297.0, -3260.35, 5.91)
Config.TugSpawn = vector4(1305.67, -3237.23, 1.1, 359.37)
Config.ReturnTug = vector3(1328.69, -3186.44, 1.57)
Config.AfterReturnTeleport = vector3(1296.37, -3241.43, 5.91)
Config.LoadOil = vector3(4134.29, -2513.87, 1.38)
Config.DeliverOil = vector3(4920.6, -5149.54, 0.85)

-- Blip shown permanently at the job start point.
Config.Blip = {
    sprite = 477,
    color = 47,
    scale = 0.8,
    label = 'Oil Runner'
}

-- Marker defaults. Individual markers may override color/scale/type.
Config.Marker = {
    type = 1,
    scale = vector3(2.0, 2.0, 0.6),
    color = { r = 255, g = 165, b = 0, a = 150 },
    bobUpAndDown = false,
    faceCamera = false,
    rotate = false
}

Config.Markers = {
    start = { color = { r = 0, g = 180, b = 255, a = 160 } },
    spawn = { color = { r = 255, g = 200, b = 0, a = 160 } },
    returnTug = { color = { r = 255, g = 60, b = 60, a = 160 } },
    load = { color = { r = 60, g = 180, b = 255, a = 160 } },
    deliver = { color = { r = 40, g = 220, b = 90, a = 160 } }
}

-- Work clothes. These are intentionally simple defaults; adjust to your server clothing pack.
Config.WorkClothes = {
    male = {
        ['tshirt_1'] = 15, ['tshirt_2'] = 0,
        ['torso_1'] = 65, ['torso_2'] = 0,
        ['arms'] = 17,
        ['pants_1'] = 38, ['pants_2'] = 0,
        ['shoes_1'] = 25, ['shoes_2'] = 0,
        ['helmet_1'] = 0, ['helmet_2'] = 0
    },
    female = {
        ['tshirt_1'] = 14, ['tshirt_2'] = 0,
        ['torso_1'] = 59, ['torso_2'] = 0,
        ['arms'] = 18,
        ['pants_1'] = 38, ['pants_2'] = 0,
        ['shoes_1'] = 25, ['shoes_2'] = 0,
        ['helmet_1'] = 0, ['helmet_2'] = 0
    }
}

Config.Text = {
    startHelp = '[E] شروع / پایان شغل Oil Runner',
    spawnHelp = '[E] باز کردن منوی یدک‌کش',
    returnHelp = '[E] بازگرداندن Tug و دریافت ودیعه',
    loadHelp = '[E] شروع بارگیری نفت',
    deliverHelp = '[E] شروع تحویل نفت',
    jobStarted = 'شغل Oil Runner شروع شد. از محل مشخص‌شده Tug بگیرید.',
    jobEnded = 'شغل Oil Runner پایان یافت و لباس قبلی شما برگشت.',
    mustReturnTug = 'قبل از پایان شغل باید Tug فعال خود را بازگردانید.',
    noMoney = 'برای دریافت Tug به 100,000 دلار پول نقد ودیعه نیاز دارید.',
    tugSpawned = 'یدک‌کش تحویل داده شد. GPS روی محل بارگیری تنظیم شد.',
    alreadyHasTug = 'شما از قبل یک Tug فعال دارید.',
    notInRegisteredTug = 'باید داخل Tug ثبت‌شده خود باشید.',
    loading = 'در حال بارگیری نفت...',
    delivering = 'در حال تحویل نفت...',
    loadComplete = 'نفت با موفقیت بارگیری شد. GPS روی محل تحویل تنظیم شد.',
    deliverComplete = 'نفت تحویل داده شد. پاداش شما: $%s',
    returnComplete = 'یدک‌کش با موفقیت بازگردانده شد. مبلغ ودیعه 100,000 دلاری شما بازپرداخت شد.',
    cancelled = 'عملیات لغو شد.',
    exploitBlocked = 'درخواست نامعتبر است.'
}
