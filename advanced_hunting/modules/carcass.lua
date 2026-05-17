AdvancedHunting = AdvancedHunting or {}
AdvancedHunting.Carcass = AdvancedHunting.Carcass or {}

local Carcass = AdvancedHunting.Carcass
Carcass.current = nil

function Carcass.CreateFromAnimal(entity, netId, animalId)
    local animal = AdvancedHunting.Utils.GetAnimalConfig(animalId)
    if not animal or not animal.rewards.carcass then return end
    if AdvancedHunting.Spawn.spawned[netId] then
        AdvancedHunting.Spawn.spawned[netId].skinned = true
    end
end

function Carcass.ToggleCarry(entity, netId)
    local ped = PlayerPedId()
    if Carcass.current then
        DetachEntity(Carcass.current, true, true)
        ClearPedTasks(ped)
        Carcass.current = nil
        AdvancedHunting.Utils.Notify(_L('carry_stopped'), 'inform')
        return
    end
    if not DoesEntityExist(entity) then return end
    AttachEntityToEntity(entity, ped, GetPedBoneIndex(ped, 28422), 0.0, -0.35, -0.05, 0.0, 90.0, 0.0, true, true, false, true, 1, true)
    Carcass.current = entity
    AdvancedHunting.Animations.PlayCarry()
    AdvancedHunting.Utils.Notify(_L('carry_started'), 'success')
end
