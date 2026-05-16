OKGangs = OKGangs or {}

function OKGangs.Trim(value)
    return value and tostring(value):gsub('^%s*(.-)%s*$', '%1') or ''
end

function OKGangs.Slug(value)
    value = OKGangs.Trim(value):lower():gsub('[^%w_%-]', '_'):gsub('_+', '_')
    return value:sub(1, 50)
end

function OKGangs.Round(value, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(value * mult + 0.5) / mult
end

function OKGangs.EncodeCoords(coords)
    if not coords then return nil end
    return json.encode({ x = OKGangs.Round(coords.x, 3), y = OKGangs.Round(coords.y, 3), z = OKGangs.Round(coords.z, 3), w = coords.w and OKGangs.Round(coords.w, 3) or nil })
end

function OKGangs.DecodeCoords(value)
    if not value or value == '' then return nil end
    local ok, decoded = pcall(json.decode, value)
    if not ok or not decoded then return nil end
    return decoded
end

function OKGangs.Notify(source, message, ntype)
    if source == 0 then
        print(('[OK_GANGS] %s'):format(message))
        return
    end
    TriggerClientEvent('ok_gangs:client:notify', source, message, ntype or 'inform')
end

function OKGangs.TableCount(tbl)
    local count = 0
    for _ in pairs(tbl or {}) do count = count + 1 end
    return count
end
