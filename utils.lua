FarmUtils = FarmUtils or {}

function FarmUtils.uuid()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return (template:gsub('[xy]', function(c)
        local v = c == 'x' and math.random(0, 15) or math.random(8, 11)
        return ('%x'):format(v)
    end))
end

function FarmUtils.distance(a, b)
    return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z))
end

function FarmUtils.lerpVec3(a, b, t)
    return vector3(
        a.x + (b.x - a.x) * t,
        a.y + (b.y - a.y) * t,
        a.z + (b.z - a.z) * t
    )
end

function FarmUtils.pointInFarmRange(coords)
    return FarmUtils.distance(coords, Config.Farm.center) <= Config.Farm.radius
end

function FarmUtils.formatSeconds(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    local days = math.floor(seconds / 86400)
    seconds = seconds % 86400
    local hours = math.floor(seconds / 3600)
    seconds = seconds % 3600
    local minutes = math.floor(seconds / 60)

    if days > 0 then
        return ('%d روز، %d ساعت، %d دقیقه'):format(days, hours, minutes)
    end

    return ('%d ساعت، %d دقیقه'):format(hours, minutes)
end
