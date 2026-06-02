Config = {}

-- نام شغل و گریدی که در دیتابیس ESX باید وجود داشته باشد.
Config.JobName = 'oilrunner'
Config.JobGrade = 0
Config.FallbackJob = 'unemployed'
Config.FallbackGrade = 0

-- فاصله مجاز برای اعتبارسنجی سمت سرور و لغو پروگرس سمت کلاینت.
Config.MaxActionDistance = 30.0

-- مدل یدک‌کش دریایی.
Config.TugModel = joaat('tug')

-- زمان‌ها بر حسب میلی‌ثانیه.
Config.LoadDuration = 420000 -- 7 دقیقه
Config.DeliverDuration = 300000 -- 5 دقیقه

-- پاداش تحویل نفت؛ پرداخت فقط سمت سرور انجام می‌شود.
Config.Reward = {
    min = 10000,
    max = 30000
}

Config.Locations = {
    startStop = vector3(1240.76, -3257.43, 6.92),
    tugMenu = vector3(1297.0, -3260.35, 5.91),
    tugSpawn = vector4(1305.67, -3237.23, 1.1, 359.37),
    afterTugSpawn = vector3(1304.43, -3240.49, 5.55),
    tugReturn = vector3(1328.69, -3186.44, 1.57),
    afterTugReturn = vector3(1296.37, -3241.43, 5.91),
    loadOil = vector3(4134.29, -2513.87, 1.38),
    deliverOil = vector3(4920.6, -5149.54, 0.85)
}

Config.Markers = {
    startStop = {
        type = 1,
        size = vector3(2.0, 2.0, 1.0),
        colour = { r = 255, g = 180, b = 0, a = 160 },
        drawDistance = 35.0,
        interactDistance = 2.2
    },
    tugMenu = {
        type = 1,
        size = vector3(3.0, 3.0, 1.0),
        colour = { r = 0, g = 150, b = 255, a = 155 },
        drawDistance = 35.0,
        interactDistance = 3.0
    },
    tugReturn = {
        type = 1,
        size = vector3(30.0, 30.0, 3.0),
        colour = { r = 255, g = 80, b = 80, a = 120 },
        drawDistance = 120.0,
        interactDistance = 30.0
    },
    loadOil = {
        type = 1,
        size = vector3(45.0, 45.0, 5.0),
        colour = { r = 20, g = 170, b = 40, a = 115 },
        drawDistance = 180.0,
        interactDistance = 45.0
    },
    deliverOil = {
        type = 1,
        size = vector3(45.0, 45.0, 5.0),
        colour = { r = 180, g = 80, b = 255, a = 115 },
        drawDistance = 180.0,
        interactDistance = 45.0
    }
}

Config.Blips = {
    startStop = {
        label = 'Oil Runner - Start/Stop',
        sprite = 477,
        colour = 5,
        scale = 0.85
    },
    loadOil = {
        label = 'Oil Runner - Load Oil',
        sprite = 467,
        colour = 2,
        scale = 0.9
    },
    deliverOil = {
        label = 'Oil Runner - Deliver Oil',
        sprite = 467,
        colour = 27,
        scale = 0.9
    }
}

-- لباس کاری نمونه. در صورت نیاز مقدار کامپوننت‌ها را مطابق سرور خود تغییر دهید.
Config.WorkClothes = {
    male = {
        ['tshirt_1'] = 15, ['tshirt_2'] = 0,
        ['torso_1'] = 65, ['torso_2'] = 0,
        ['arms'] = 31,
        ['pants_1'] = 38, ['pants_2'] = 0,
        ['shoes_1'] = 25, ['shoes_2'] = 0,
        ['helmet_1'] = 0, ['helmet_2'] = 0
    },
    female = {
        ['tshirt_1'] = 14, ['tshirt_2'] = 0,
        ['torso_1'] = 59, ['torso_2'] = 0,
        ['arms'] = 36,
        ['pants_1'] = 38, ['pants_2'] = 0,
        ['shoes_1'] = 25, ['shoes_2'] = 0,
        ['helmet_1'] = 0, ['helmet_2'] = 0
    }
}

Config.Text = {
    pressStartStop = '[E] شروع / پایان شغل Oil Runner',
    pressTugMenu = '[E] منوی یدک‌کش',
    pressReturnTug = '[E] حذف Tug و بازگشت',
    pressLoadOil = '[E] شروع بارگیری نفت',
    pressDeliverOil = '[E] شروع تحویل نفت'
}
