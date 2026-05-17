AdvancedHunting = AdvancedHunting or {}
AdvancedHunting.Spawn = AdvancedHunting.Spawn or {}

local Spawn = AdvancedHunting.Spawn
Spawn.spawned = Spawn.spawned or {}
Spawn.zoneCooldowns = Spawn.zoneCooldowns or {}

local function requestModel(model)
    if HasModelLoaded(model) then return true end
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(25) end
    return HasModelLoaded(model)
end

local function randomPointInZone(zone)
    local angle = math.random() * math.pi * 2.0
    local distance = math.sqrt(math.random()) * (zone.radius - 25.0)
    local x = zone.center.x + math.cos(angle) * distance
    local y = zone.center.y + math.sin(angle) * distance
    local z = zone.center.z + Config.Spawn.groundProbeHeight
    local found, groundZ = GetGroundZFor_3dCoord(x, y, z, false)
    return vector3(x, y, found and groundZ or zone.center.z)
end

function Spawn.CountZone(zoneId)
    local count = 0
    for _, data in pairs(Spawn.spawned) do
        if data.zoneId == zoneId and DoesEntityExist(data.entity) then count = count + 1 end
    end
    return count
end

function Spawn.CleanupEntity(entity)
    if not entity or not DoesEntityExist(entity) then return end
    exports.ox_target:removeLocalEntity(entity)
    SetEntityAsMissionEntity(entity, true, true)
    DeleteEntity(entity)
end

function Spawn.CleanupZone(zoneId)
    for netId, data in pairs(Spawn.spawned) do
        if not zoneId or data.zoneId == zoneId then
            Spawn.CleanupEntity(data.entity)
            TriggerServerEvent('advanced_hunting:server:unregisterAnimal', netId)
            Spawn.spawned[netId] = nil
        end
    end
end

function Spawn.TrySpawn(zoneId, zone)
    if not Config.Spawn.enabled then return end
    if Spawn.CountZone(zoneId) >= (zone.maxAnimals or 5) then return end
    local now = GetGameTimer()
    if (Spawn.zoneCooldowns[zoneId] or 0) > now then return end
    Spawn.zoneCooldowns[zoneId] = now + (zone.respawnTime or Config.Spawn.spawnCooldown)

    local animalId = AdvancedHunting.Utils.WeightedAnimalForZone(zone)
    local animal = animalId and AdvancedHunting.Utils.GetAnimalConfig(animalId)
    if not animal or not requestModel(animal.model) then return end

    local playerCoords = GetEntityCoords(PlayerPedId())
    local spawnCoords
    for _ = 1, Config.Spawn.maxSpawnAttempts do
        local candidate = randomPointInZone(zone)
        if #(candidate - playerCoords) >= Config.Spawn.minPlayerDistance then
            spawnCoords = candidate
            break
        end
    end
    if not spawnCoords then return end

    local ped = CreatePed(28, animal.model, spawnCoords.x, spawnCoords.y, spawnCoords.z, math.random(0, 359) + 0.0, true, true)
    if not DoesEntityExist(ped) then return end

    SetEntityAsMissionEntity(ped, true, true)
    SetEntityHealth(ped, animal.health or 100)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 5, true)
    if animal.aggressive then
        TaskCombatPed(ped, PlayerPedId(), 0, 16)
    else
        TaskWanderStandard(ped, 10.0, 10)
    end

    local netId = NetworkGetNetworkIdFromEntity(ped)
    Spawn.spawned[netId] = {entity = ped, animalId = animalId, zoneId = zoneId, skinned = false}
    TriggerServerEvent('advanced_hunting:server:registerAnimal', netId, animalId, zoneId, GetEntityCoords(ped))
    TriggerEvent('advanced_hunting:client:addAnimalTarget', ped, netId, animalId)
end
