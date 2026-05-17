AdvancedHunting = AdvancedHunting or {}

AddEventHandler('advanced_hunting:client:addAnimalTarget', function(entity, netId, animalId)
    exports.ox_target:addLocalEntity(entity, {
        {
            name = ('advanced_hunting_skin_%s'):format(netId),
            label = _L('skin_animal'),
            icon = 'fa-solid fa-knife',
            distance = 2.5,
            canInteract = function(target)
                return IsEntityDead(target) and not (AdvancedHunting.Spawn.spawned[netId] and AdvancedHunting.Spawn.spawned[netId].skinned)
            end,
            onSelect = function(data)
                AdvancedHunting.Skinning.Start(data.entity, netId, animalId)
            end
        },
        {
            name = ('advanced_hunting_carry_%s'):format(netId),
            label = _L('carry_carcass'),
            icon = 'fa-solid fa-hand',
            distance = 2.5,
            canInteract = function(target)
                return IsEntityDead(target)
            end,
            onSelect = function(data)
                AdvancedHunting.Carcass.ToggleCarry(data.entity, netId)
            end
        },
        {
            name = ('advanced_hunting_butcher_%s'):format(netId),
            label = _L('butcher_animal'),
            icon = 'fa-solid fa-drumstick-bite',
            distance = 2.5,
            canInteract = function(target)
                return IsEntityDead(target) and AdvancedHunting.Spawn.spawned[netId] and AdvancedHunting.Spawn.spawned[netId].skinned
            end,
            onSelect = function(data)
                AdvancedHunting.Butcher.Start(data.entity, netId, animalId)
            end
        },
        {
            name = ('advanced_hunting_inspect_%s'):format(netId),
            label = _L('inspect_animal'),
            icon = 'fa-solid fa-magnifying-glass',
            distance = 2.5,
            canInteract = function(target)
                return IsEntityDead(target)
            end,
            onSelect = function(data)
                AdvancedHunting.Animals.Inspect(data.entity, animalId)
            end
        }
    })
end)
