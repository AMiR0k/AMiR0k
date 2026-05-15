OKGangs = OKGangs or {}
OKGangs.Client = OKGangs.Client or {}

function OKGangs.Client.OpenCrafting()
    local options = {}
    for name, recipe in pairs(OKGangs.CraftingRecipes) do
        local desc = {}
        for item, count in pairs(recipe.items) do desc[#desc + 1] = ('%sx %s'):format(count, item) end
        options[#options + 1] = { title = recipe.label or name, description = table.concat(desc, ', '), onSelect = function()
            if lib.progressCircle({ duration = recipe.duration, label = 'Crafting...', canCancel = true, disable = { move = true, car = true, combat = true } }) then
                local ok, result = lib.callback.await('ok_gangs:server:craft', false, name)
                lib.notify({ description = ok and 'Crafted' or tostring(result), type = ok and 'success' or 'error' })
            end
        end }
    end
    lib.registerContext({ id = 'ok_gangs_crafting', title = 'Gang Crafting', options = options })
    lib.showContext('ok_gangs_crafting')
end
