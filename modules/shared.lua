local function translate(key, ...)
    local locale = Locales and Locales[Config.Locale] or Locales.en or {}
    local text = locale[key] or key
    if select('#', ...) > 0 then return text:format(...) end
    return text
end

_ENV._L = translate

function NormalizePlate(plate)
    plate = tostring(plate or '')
    if Config.Rental.plateTrim then plate = plate:gsub('^%s*(.-)%s*$', '%1') end
    return plate:upper()
end

function MinutesRemaining(unixEnd)
    return math.max(0, math.ceil((tonumber(unixEnd or 0) - os.time()) / 60))
end
