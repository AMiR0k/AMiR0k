AdvancedHunting = AdvancedHunting or {}
AdvancedHunting.Butcher = AdvancedHunting.Butcher or {}

function AdvancedHunting.Butcher.Start(entity, netId, animalId)
    if not AdvancedHunting.State.active then return AdvancedHunting.Utils.Notify(_L('not_hunting'), 'error') end
    if not DoesEntityExist(entity) then return end
    if AdvancedHunting.Animations.PlayButcher(6500) then
        TriggerServerEvent('advanced_hunting:server:butcherAnimal', netId, animalId, GetEntityCoords(entity))
        AdvancedHunting.Spawn.CleanupEntity(entity)
        AdvancedHunting.Spawn.spawned[netId] = nil
        AdvancedHunting.Utils.Notify(_L('butcher_success'), 'success')
    end
end
