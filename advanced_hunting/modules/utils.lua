AdvancedHunting = AdvancedHunting or {}
AdvancedHunting.Utils = AdvancedHunting.Utils or {}

local Utils = AdvancedHunting.Utils

function Utils.Debug(message, ...)
    if not Config.Debug then return end
    print(('[advanced_hunting] ' .. tostring(message)):format(...))
end

function Utils.Notify(message, notifyType, duration)
    if lib and lib.notify then
        lib.notify({description = message, type = notifyType or 'inform', duration = duration or 5000})
    else
        print(('[advanced_hunting] %s'):format(message))
    end
end

function Utils.TableContains(tbl, value)
    for _, item in pairs(tbl or {}) do
        if item == value then return true end
    end
    return false
end

function Utils.Distance(a, b)
    return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z))
end

function Utils.GetZoneAtCoords(coords)
    for zoneId, zone in pairs(HuntingZones or {}) do
        if Utils.Distance(coords, zone.center) <= zone.radius then
            return zoneId, zone
        end
    end
    return nil, nil
end

function Utils.IsNight()
    local hour = GetClockHours and GetClockHours() or 12
    return hour >= 20 or hour <= 5
end

function Utils.GetAnimalConfig(animalId)
    return Animals and Animals.Definitions and Animals.Definitions[animalId]
end

function Utils.WeightedAnimalForZone(zone)
    local isNight = Utils.IsNight()
    local pool, total = {}, 0

    for _, animalId in ipairs(zone.allowedAnimals or {}) do
        local animal = Utils.GetAnimalConfig(animalId)
        if animal and Utils.TableContains(animal.spawnZones, zone.name) == false then
            -- Names and ids may differ; explicit allowedAnimals still wins below.
        end
        if animal and ((isNight and animal.time.night) or (not isNight and animal.time.day)) then
            local chance = animal.spawnChance or 1
            if animal.legendary then
                chance = math.max(1, math.floor((zone.legendaryChance or 0.5) * chance))
            end
            total = total + chance
            pool[#pool + 1] = {id = animalId, weight = chance}
        end
    end

    if total <= 0 then return nil end
    local roll = math.random(1, total)
    local cursor = 0
    for _, entry in ipairs(pool) do
        cursor = cursor + entry.weight
        if roll <= cursor then return entry.id end
    end
    return pool[#pool].id
end

function Utils.IsAllowedSkinningWeapon(weapon)
    if not weapon or weapon == 0 then return false end

    -- Accept direct hash keys from Config.Skinning.allowedKnives.
    if Config.Skinning.allowedKnives and Config.Skinning.allowedKnives[weapon] then
        return true
    end

    -- Accept weapon names too, then resolve them to hashes. This keeps every knife/axe
    -- model configurable and prevents client/server hash format mismatches from
    -- blocking valid skinning weapons.
    if type(weapon) == 'string' then
        if Config.Skinning.allowedKnifeNames and Config.Skinning.allowedKnifeNames[weapon] then
            return true
        end

        local hash = GetHashKey(weapon)
        return Config.Skinning.allowedKnives and Config.Skinning.allowedKnives[hash] == true
    end

    for weaponName, enabled in pairs(Config.Skinning.allowedKnifeNames or {}) do
        if enabled and GetHashKey(weaponName) == weapon then
            return true
        end
    end

    return false
end

function Utils.ClampQualityIndex(index)
    return math.max(1, math.min(#Config.Quality.order, index))
end

function Utils.QualityFromIndex(index)
    return Config.Quality.order[Utils.ClampQualityIndex(index)]
end

function Utils.QualityIndex(quality)
    for index, value in ipairs(Config.Quality.order) do
        if value == quality then return index end
    end
    return 2
end
