OKGangs = OKGangs or {}
OKGangs.Client = OKGangs.Client or {}

local function chooseNearby(cb)
    local players = lib.callback.await('ok_gangs:server:getNearbyPlayers', false) or {}
    local options = {}
    for _, player in ipairs(players) do options[#options + 1] = { title = ('%s [%s]'):format(player.name, player.id), description = player.hasGang and 'Already in gang' or 'Available', onSelect = function() cb(player) end } end
    lib.registerContext({ id = 'ok_gangs_nearby', title = 'Nearby Players', options = options })
    lib.showContext('ok_gangs_nearby')
end

function OKGangs.Client.OpenGangMenu()
    local options = {
        { title = 'Cuff / Uncuff', onSelect = function() chooseNearby(function(p) TriggerServerEvent('ok_gangs:server:cuff', p.id) end) end },
        { title = 'Drag', onSelect = function() chooseNearby(function(p) TriggerServerEvent('ok_gangs:server:drag', p.id) end) end },
        { title = 'Put In Vehicle', onSelect = function() chooseNearby(function(p) TriggerServerEvent('ok_gangs:server:putInVehicle', p.id) end) end },
        { title = 'Put Out Vehicle', onSelect = function() chooseNearby(function(p) TriggerServerEvent('ok_gangs:server:putOutVehicle', p.id) end) end },
        { title = 'Search Player', onSelect = function() chooseNearby(function(p) exports.ox_inventory:openNearbyInventory(p.id) end) end },
        { title = 'Invite Player', onSelect = function() chooseNearby(function(p) lib.callback.await('ok_gangs:server:addMember', false, p.id, OKGangs.Client.myGang.id, 1) end) end }
    }
    lib.registerContext({ id = 'ok_gangs_f6', title = 'Gang Menu', options = options })
    lib.showContext('ok_gangs_f6')
end

local function finance(action)
    local input = lib.inputDialog('Finance', { { type = 'number', label = 'Amount', min = 1, required = true } })
    if not input then return end
    local ok, result = lib.callback.await('ok_gangs:server:finance', false, action, input[1])
    lib.notify({ title = 'Finance', description = ok and 'Done' or tostring(result), type = ok and 'success' or 'error' })
end

function OKGangs.Client.OpenBossMenu(gang)
    if not OKGangs.Client.myMember or OKGangs.Client.myMember.rank < Config.BossRank then return lib.notify({ description = 'No permission', type = 'error' }) end
    lib.registerContext({ id = 'ok_gangs_boss', title = 'Boss Menu', options = {
        { title = 'Invite Player', onSelect = function() chooseNearby(function(p) lib.callback.await('ok_gangs:server:addMember', false, p.id, gang.id, 1) end) end },
        { title = 'Deposit Money', onSelect = function() finance('deposit_money') end },
        { title = 'Withdraw Money', onSelect = function() finance('withdraw_money') end },
        { title = 'Deposit Black Money', onSelect = function() finance('deposit_black') end },
        { title = 'Withdraw Black Money', onSelect = function() finance('withdraw_black') end },
        { title = 'Wash Money', onSelect = function() finance('wash') end },
        { title = 'Set Rank Salary/Name', onSelect = function()
            local input = lib.inputDialog('Rank', { { type = 'number', label = 'Rank', min = 1, max = 6 }, { type = 'input', label = 'Label' }, { type = 'number', label = 'Salary', min = 0, max = 1000 } })
            if input then lib.callback.await('ok_gangs:server:setRankData', false, gang.id, input[1], input[2], input[3], {}) end
        end }
    } })
    lib.showContext('ok_gangs_boss')
end
