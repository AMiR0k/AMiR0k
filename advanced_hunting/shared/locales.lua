Locales = Locales or {}

Locales.en = {
    start_hunting = 'Start Hunting',
    stop_hunting = 'Stop Hunting',
    hunting_started = 'Hunting started. Stay inside the hunting zone.',
    hunting_stopped = 'Hunting stopped and spawned animals were cleaned up.',
    enter_zone = 'You entered %s.',
    leave_zone = 'You left %s.',
    skin_animal = 'Skin Animal',
    carry_carcass = 'Carry Carcass',
    butcher_animal = 'Butcher Animal',
    inspect_animal = 'Inspect Animal',
    need_knife_weapon = 'Hold an approved knife or axe before skinning.',
    not_hunting = 'You must start hunting first.',
    not_in_zone = 'You must be inside a hunting zone.',
    too_far = 'You are too far away.',
    already_processed = 'This animal has already been processed.',
    skinning_cancelled = 'Skinning cancelled.',
    skinning_failed = 'You damaged the animal while skinning.',
    skinning_success = 'Animal skinned. Quality: %s.',
    butcher_success = 'Carcass butchered.',
    carry_started = 'You picked up the carcass.',
    carry_stopped = 'You dropped the carcass.',
    inspect_text = 'Species: %s\nQuality estimate: %s\nLegendary: %s',
    seller_legal = 'Sell hunting goods',
    seller_illegal = 'Sell rare pelts',
    nothing_to_sell = 'You have nothing this trader wants.',
    sold_items = 'Sold hunting goods for $%s.',
    exploit_detected = 'Suspicious hunting action blocked.',
    level_up = 'Hunting level increased to %s.',
    legendary_kill = 'Legendary animal harvested: %s!'
}

Locales.fa = {
    start_hunting = 'شروع شکار',
    stop_hunting = 'پایان شکار',
    hunting_started = 'شکار شروع شد. داخل محدوده شکار بمانید.',
    hunting_stopped = 'شکار پایان یافت و حیوانات پاکسازی شدند.',
    enter_zone = 'وارد %s شدید.',
    leave_zone = 'از %s خارج شدید.',
    skin_animal = 'پوست کندن حیوان',
    carry_carcass = 'حمل لاشه',
    butcher_animal = 'قصابی لاشه',
    inspect_animal = 'بررسی حیوان',
    need_knife_weapon = 'برای پوست کندن باید چاقو یا تبر مجاز در دست داشته باشید.',
    not_hunting = 'ابتدا شکار را شروع کنید.',
    not_in_zone = 'باید داخل منطقه شکار باشید.',
    too_far = 'خیلی دور هستید.',
    already_processed = 'این حیوان قبلاً پردازش شده است.',
    skinning_cancelled = 'پوست کندن لغو شد.',
    skinning_failed = 'هنگام پوست کندن به حیوان آسیب زدید.',
    skinning_success = 'حیوان پوست کنده شد. کیفیت: %s.',
    butcher_success = 'لاشه قصابی شد.',
    carry_started = 'لاشه را برداشتید.',
    carry_stopped = 'لاشه را رها کردید.',
    inspect_text = 'گونه: %s\nکیفیت تخمینی: %s\nافسانه‌ای: %s',
    seller_legal = 'فروش محصولات شکار',
    seller_illegal = 'فروش پوست کمیاب',
    nothing_to_sell = 'چیزی برای فروش به این فروشنده ندارید.',
    sold_items = 'محصولات شکار به قیمت $%s فروخته شد.',
    exploit_detected = 'عملیات مشکوک شکار مسدود شد.',
    level_up = 'سطح شکار شما به %s رسید.',
    legendary_kill = 'حیوان افسانه‌ای برداشت شد: %s!'
}

function _L(key, ...)
    local locale = Config and Config.Locale or 'en'
    local phrase = (Locales[locale] and Locales[locale][key]) or Locales.en[key] or key
    if select('#', ...) > 0 then
        return phrase:format(...)
    end
    return phrase
end
