AdvancedHunting = AdvancedHunting or {}
AdvancedHunting.Skinning = AdvancedHunting.Skinning or {}

local Skinning = AdvancedHunting.Skinning

function Skinning.HasAllowedWeapon()
    local ped = PlayerPedId()
    local selected = GetSelectedPedWeapon(ped)
    local _, current = GetCurrentPedWeapon(ped, true)

    if AdvancedHunting.Utils.IsAllowedSkinningWeapon(selected) then
        return true, selected
    end

    if AdvancedHunting.Utils.IsAllowedSkinningWeapon(current) then
        return true, current
    end

    return false, selected
end

function Skinning.CalculateClientQuality(entity, skillSuccess)
    local _, weapon = GetCurrentPedWeapon(PlayerPedId(), true)
    local index = AdvancedHunting.Utils.QualityIndex(Config.Quality.default)
    local modifier = Config.Quality.weaponModifiers[weapon] or 0
    index = index - modifier

    if HasPedBeenDamagedByWeapon(entity, `WEAPON_PUMPSHOTGUN`, 0) or HasPedBeenDamagedByWeapon(entity, `WEAPON_SAWNOFFSHOTGUN`, 0) then
        index = AdvancedHunting.Utils.QualityIndex('ruined')
    end

    if not skillSuccess then
        index = index + Config.Skinning.qualityOnFailPenalty
    end

    return AdvancedHunting.Utils.QualityFromIndex(index)
end

function Skinning.Start(entity, netId, animalId)
    if not DoesEntityExist(entity) or not IsEntityDead(entity) then return end
    if not AdvancedHunting.State.active then return AdvancedHunting.Utils.Notify(_L('not_hunting'), 'error') end

    local allowed = Skinning.HasAllowedWeapon()
    if not allowed then return AdvancedHunting.Utils.Notify(_L('need_knife_weapon'), 'error') end

    local hasKnife = lib.callback.await('advanced_hunting:server:hasKnife', false)
    if not hasKnife then return AdvancedHunting.Utils.Notify(_L('need_knife_item'), 'error') end

    if not lib.skillCheck(Config.Skinning.skillCheck, {'w', 'a', 's', 'd'}) then
        AdvancedHunting.Utils.Notify(_L('skinning_failed'), 'warning')
        Skinning.Finish(entity, netId, animalId, false)
        return
    end

    if AdvancedHunting.Animations.PlaySkinning(Config.Skinning.duration) then
        Skinning.Finish(entity, netId, animalId, true)
    else
        AdvancedHunting.Utils.Notify(_L('skinning_cancelled'), 'error')
    end
end

function Skinning.Finish(entity, netId, animalId, skillSuccess)
    local quality = Skinning.CalculateClientQuality(entity, skillSuccess)
    local coords = GetEntityCoords(entity)
    local _, weapon = Skinning.HasAllowedWeapon()
    TriggerServerEvent('advanced_hunting:server:skinAnimal', netId, animalId, coords, quality, skillSuccess, weapon)
    TriggerEvent('advanced_hunting:client:createCarcass', entity, netId, animalId)
end
