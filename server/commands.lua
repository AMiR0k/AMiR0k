local function sendUsage(source)
    OKGangs.Notify(source, 'Usage: /setgang [playerId] [gangName] (rank)', 'inform')
end

RegisterCommand('gangs', function(source)
    if not OKGangs.Server.RequireAdmin(source) then return end
    TriggerClientEvent('ok_gangs:client:openAdminMenu', source)
end, false)

RegisterCommand('setgang', function(source, args)
    if not OKGangs.Server.RequireAdmin(source) then return end

    local target = tonumber(args[1])
    local gangName = args[2] and OKGangs.Slug(args[2]) or nil
    local rank = tonumber(args[3]) or 1

    if not target or not gangName or gangName == '' then
        sendUsage(source)
        return
    end

    local ok, result = OKGangs.Server.AdminSetPlayerGang(source, target, gangName, rank)
    if not ok then
        OKGangs.Notify(source, result or 'failed to set gang', 'error')
        return
    end

    OKGangs.Notify(source, ('Player %s added to gang %s as rank %s'):format(target, result.gang.label, result.rank), 'success')
    if source ~= target then
        OKGangs.Notify(target, ('You were added to gang %s as rank %s'):format(result.gang.label, result.rank), 'success')
    end
end, false)
