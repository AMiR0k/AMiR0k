OKGangs = OKGangs or {}
OKGangs.Server = OKGangs.Server or {}

lib.callback.register('ok_gangs:server:craft', function(source, recipeName)
    local gang = OKGangs.Server.RequireActiveGang(source)
    if not gang then return false, OKGangs.Errors.gang_inactive end
    local recipe = OKGangs.CraftingRecipes[recipeName]
    if not recipe then return false, 'invalid recipe' end
    for item, count in pairs(recipe.items) do
        if exports.ox_inventory:GetItemCount(source, item) < count then return false, ('missing %s'):format(item) end
    end
    for item, count in pairs(recipe.items) do exports.ox_inventory:RemoveItem(source, item, count) end
    exports.ox_inventory:AddItem(source, recipeName, 1)
    OKGangs.Server.AddXP(gang.id, recipe.xp or 0, 'craft')
    OKGangs.Server.Audit(gang.id, source, 'Craft', { recipe = recipeName })
    return true
end)
