Config = {}

Config.Language = 'en'
Config.RequiredCops = 0

Config.DrillItem = 'drill'
Config.DrillUsedItem = 'useddrill'

Config.PoliceJobs = { 'police', 'fbi', 'special', 'sheriff' }

Config.Reward = { min = 15000, max = 30000 }
Config.RewardAccount = 'black_money' -- money, black_money, or bank

Config.RobberyTime = 3 -- Minutes before a started robbery expires server-side
Config.Cooldown = 15 -- Global cooldown in minutes

Config.ATM_Props = { 'prop_fleeca_atm', 'prop_atm_02', 'prop_atm_03' }

Config.Target = {
    icon = 'fa-solid fa-screwdriver-wrench',
    label = 'Rob ATM',
    distance = 1.5
}

Config.MaxStartDistance = 2.0
Config.MaxFinishDistance = 8.0
Config.PoliceBlipDuration = 180000 -- milliseconds

Config.Locales = {
    de = {
        robbery_failed = 'Raub fehlgeschlagen! Viel Glück beim nächsten mal! [Überhitzung]',
        robbery_time = 'Verbleibende Zeit: %s Minuten %s Sekunden',
        robbery_success = 'Raubüberfall erfolgreich! Du hast %s$ erbeutet!',
        robbery_cooldown = 'Du musst noch %s Minuten warten!',
        robbery_missingCops = 'Es sind nicht genügend Polizisten im Dienst! %s von %s im Dienst',
        robbery_no_drill = 'Du brauchst einen Bohrer.',
        robbery_busy = 'Du raubst bereits einen Geldautomaten aus.',
        robbery_too_far = 'Du bist zu weit vom Geldautomaten entfernt.',
        robbery_invalid = 'Dieser Raub ist nicht mehr gültig.',
        robbery_cannot_carry = 'Du kannst den benutzten Bohrer nicht tragen.',
        alert_notify_title = 'ATM-Raub',
        alert_notify_started = 'Ein Überfall auf einen Geldautomaten wurde gemeldet!',
        alert_notify_ended = 'Der Überfall wurde beendet!',
        alert_blip_name = 'Überfall | ATM-Raub',
    },
    en = {
        robbery_failed = 'Robbery failed! Better luck next time! [Overheating]',
        robbery_time = 'Remaining time: %s minutes %s seconds',
        robbery_success = 'Robbery successful! You have looted $%s!',
        robbery_cooldown = 'You have to wait %s minutes!',
        robbery_missingCops = 'There are not enough police officers on duty! %s of %s on duty',
        robbery_no_drill = 'You need a drill.',
        robbery_busy = 'You are already robbing an ATM.',
        robbery_too_far = 'You are too far away from the ATM.',
        robbery_invalid = 'This robbery is no longer valid.',
        robbery_cannot_carry = 'You cannot carry the used drill.',
        alert_notify_title = 'ATM Robbery',
        alert_notify_started = 'An ATM robbery has been reported!',
        alert_notify_ended = 'The robbery has ended!',
        alert_blip_name = 'Robbery | ATM Robbery',
    }
}
