local function translate(key, ...)
    local locale = Locales and (Locales[Config.Locale] or Locales.en) or {}
    local phrase = locale[key] or key
    if select('#', ...) > 0 then
        return phrase:format(...)
    end
    return phrase
end

_L = translate
