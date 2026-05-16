OKGangs = OKGangs or {}
OKGangs.Server = OKGangs.Server or {}

function OKGangs.Server.RegisterGangInventories(gang)
    if not gang then return end
    local groups = { [gang.name] = 0 }
    exports.ox_inventory:RegisterStash(('gang_stash_%s'):format(gang.name), ('%s Stash'):format(gang.label), Config.Stashes.stash.slots, Config.Stashes.stash.weight, false, groups)
    exports.ox_inventory:RegisterStash(('gang_armory_%s'):format(gang.name), ('%s Armory'):format(gang.label), Config.Stashes.armory.slots, Config.Stashes.armory.weight, false, groups)
end

function OKGangs.Server.RegisterAllInventories()
    for _, gang in pairs(OKGangs.Server.Gangs) do OKGangs.Server.RegisterGangInventories(gang) end
end

local function canOpenInventory(source, invType, gangName)
    local gang, member = OKGangs.Server.RequireActiveGang(source)
    if not gang then return false end
    if gang.name ~= gangName then
        OKGangs.Notify(source, OKGangs.Errors.stash_access_denied, 'error')
        return false
    end
    if invType == 'armory' then
        local rank = gang.ranks[member.rank]
        local perms = rank and rank.permissions or {}
        if perms.armory == false then
            OKGangs.Notify(source, OKGangs.Errors.stash_access_denied, 'error')
            return false
        end
    end
    return true, gang
end

RegisterNetEvent('ok_gangs:server:openStash', function(gangName)
    local source = source
    local ok, gang = canOpenInventory(source, 'stash', gangName)
    if not ok then return end
    OKGangs.Server.Audit(gang.id, source, 'Stash Deposit', { action = 'open_stash' })
    exports.ox_inventory:forceOpenInventory(source, 'stash', ('gang_stash_%s'):format(gang.name))
end)

RegisterNetEvent('ok_gangs:server:openArmory', function(gangName)
    local source = source
    local ok, gang = canOpenInventory(source, 'armory', gangName)
    if not ok then return end
    OKGangs.Server.Audit(gang.id, source, 'Armory Withdraw', { action = 'open_armory' })
    exports.ox_inventory:forceOpenInventory(source, 'stash', ('gang_armory_%s'):format(gang.name))
end)
