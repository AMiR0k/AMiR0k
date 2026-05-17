AdvancedHunting = AdvancedHunting or {}
AdvancedHunting.Rewards = AdvancedHunting.Rewards or {}

local Rewards = AdvancedHunting.Rewards

local qualityMultiplier = {perfect = 1.35, good = 1.0, damaged = 0.55, ruined = 0.15}

local function addItem(source, item, count, metadata)
    if not item or count <= 0 then return end
    exports[Config.Inventory.resource]:AddItem(source, item, count, metadata)
end

function Rewards.NormalizeQuality(source, clientQuality, skillSuccess)
    local index = AdvancedHunting.Utils.QualityIndex(clientQuality or Config.Quality.default)
    local level = AdvancedHunting.XP.Get(source).level or 1
    index = index - math.floor(level / Config.Quality.levelPerfectBonusEvery)
    if not skillSuccess then index = index + Config.Skinning.qualityOnFailPenalty end
    return AdvancedHunting.Utils.QualityFromIndex(index)
end

function Rewards.GrantSkinning(source, record, quality, skillSuccess)
    local animal = AdvancedHunting.Utils.GetAnimalConfig(record.animalId)
    if not animal then return end
    local multiplier = qualityMultiplier[quality] or 1.0
    if not skillSuccess then multiplier = multiplier * Config.Skinning.failMeatMultiplier end

    if animal.rewards.meat then
        local base = math.random(animal.rewards.meat.min, animal.rewards.meat.max)
        addItem(source, animal.rewards.meat.item, math.max(1, math.floor(base * multiplier)), {quality = quality, species = record.animalId})
    end
    if animal.rewards.skin and quality ~= 'ruined' then
        addItem(source, animal.rewards.skin.item, animal.rewards.skin.amount or 1, {quality = quality, species = record.animalId, legendary = animal.legendary})
    end
    if animal.rewards.carcass then
        addItem(source, animal.rewards.carcass, 1, {species = record.animalId, quality = quality})
    end

    AdvancedHunting.XP.Add(source, animal.xp or 0)
    if animal.legendary then
        TriggerClientEvent('ox_lib:notify', source, {description = _L('legendary_kill', animal.label), type = 'success', duration = 9000})
        AdvancedHunting.Logging.Write('legendary', source, 'legendary_harvest', {animal = record.animalId, quality = quality})
    end
    AdvancedHunting.Logging.Write('harvest', source, 'animal_harvested', {animal = record.animalId, quality = quality})
end

function Rewards.GrantButcher(source, record)
    local animal = AdvancedHunting.Utils.GetAnimalConfig(record.animalId)
    if not animal or not animal.rewards.meat then return end
    local count = math.random(animal.rewards.meat.min, animal.rewards.meat.max)
    addItem(source, animal.rewards.meat.item, count, {species = record.animalId, butchered = true})
    AdvancedHunting.Logging.Write('butcher', source, 'carcass_butchered', {animal = record.animalId, count = count})
end
