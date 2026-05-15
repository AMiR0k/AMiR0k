OKGangs = OKGangs or {}
OKGangs.Client = OKGangs.Client or {}

local function currentCoords()
    local coords = GetEntityCoords(cache.ped)
    local heading = GetEntityHeading(cache.ped)
    return { x = coords.x, y = coords.y, z = coords.z, w = heading }
end

local function notifyResult(ok, result)
    lib.notify({ title = 'OK_GANGS', description = ok and 'Saved successfully' or tostring(result or 'failed'), type = ok and 'success' or 'error' })
end

local function createGang()
    local input = lib.inputDialog('Create Gang', {
        { type = 'input', label = 'Gang Name', required = true },
        { type = 'input', label = 'Gang Label', required = true },
        { type = 'number', label = 'Expire Time (days)', default = Config.DefaultExpireDays, min = Config.MinExpireDays, max = Config.MaxExpireDays }
    })
    if not input then return end
    local ok, result = lib.callback.await('ok_gangs:server:createGang', false, { name = input[1], label = input[2], days = input[3], hq = currentCoords() })
    notifyResult(ok, type(result) == 'table' and result.label or result)
end

local function setGangLocation(gang)
    local options = {}
    for locationType in pairs(OKGangs.LocationTypes) do options[#options + 1] = { value = locationType, label = locationType } end
    table.sort(options, function(a, b) return a.label < b.label end)
    local input = lib.inputDialog(('Locations: %s'):format(gang.label), {
        { type = 'select', label = 'Location Type', options = options, required = true }
    })
    if not input then return end
    local ok, result = lib.callback.await('ok_gangs:server:setLocation', false, gang.id, input[1], currentCoords())
    notifyResult(ok, result)
end

local function editGang(gang)
    local input = lib.inputDialog(('Edit: %s'):format(gang.label), {
        { type = 'select', label = 'Action', required = true, options = {
            { value = 'soft_delete', label = 'Soft Delete Gang' },
            { value = 'restore', label = 'Restore Gang' },
            { value = 'extend', label = 'Extend Expire Time' },
            { value = 'level', label = 'Set Level' },
            { value = 'xp', label = 'Set XP' },
            { value = 'money', label = 'Set Money' },
            { value = 'member_slots', label = 'Change Member Slots' },
            { value = 'locations', label = 'Gang Settings / Locations' }
        } },
        { type = 'number', label = 'Value', default = 1 }
    })
    if not input then return end
    local action, value = input[1], input[2]
    local ok, result
    if action == 'soft_delete' then ok, result = lib.callback.await('ok_gangs:server:setGangStatus', false, gang.id, false)
    elseif action == 'restore' then ok, result = lib.callback.await('ok_gangs:server:setGangStatus', false, gang.id, true)
    elseif action == 'extend' then ok, result = lib.callback.await('ok_gangs:server:extendGang', false, gang.id, value)
    elseif action == 'locations' then setGangLocation(gang) return
    else ok, result = lib.callback.await('ok_gangs:server:updateGangField', false, gang.id, action, value) end
    notifyResult(ok, result)
end

local function manageGangs()
    local gangs = lib.callback.await('ok_gangs:server:getAllGangs', false) or {}
    local options = {}
    for _, gang in ipairs(gangs) do
        options[#options + 1] = { title = gang.label, description = ('%s | Status: %s | Members: %s/%s'):format(gang.name, gang.status, gang.memberCount, gang.member_slots), onSelect = function() editGang(gang) end }
    end
    lib.registerContext({ id = 'ok_gangs_admin_manage', title = 'Manage Gangs', options = options })
    lib.showContext('ok_gangs_admin_manage')
end

RegisterNetEvent('ok_gangs:client:openAdminMenu', function()
    lib.registerContext({ id = 'ok_gangs_admin', title = 'Gang Administration', options = {
        { title = 'Create Gang', onSelect = createGang },
        { title = 'Manage Gangs', onSelect = manageGangs }
    } })
    lib.showContext('ok_gangs_admin')
end)
