AdvancedHunting = AdvancedHunting or {}
AdvancedHunting.Animals = AdvancedHunting.Animals or {}

function AdvancedHunting.Animals.Inspect(entity, animalId)
    local animal = AdvancedHunting.Utils.GetAnimalConfig(animalId)
    if not animal then return end
    local quality = AdvancedHunting.Skinning.CalculateClientQuality(entity, true)
    lib.alertDialog({
        header = animal.label,
        content = _L('inspect_text', animal.label, quality, animal.legendary and 'yes' or 'no'),
        centered = true
    })
end

AddEventHandler('advanced_hunting:client:createCarcass', function(entity, netId, animalId)
    AdvancedHunting.Carcass.CreateFromAnimal(entity, netId, animalId)
end)
