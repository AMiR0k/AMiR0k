OKGangs = OKGangs or {}
OKGangs.Server = OKGangs.Server or {}

function OKGangs.Server.IsAdmin(source)
    if source == 0 then return true end
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    local group = xPlayer.getGroup and xPlayer.getGroup() or 'user'
    local level = tonumber(group) or tonumber(xPlayer.get and xPlayer.get('adminLevel')) or tonumber(xPlayer.get and xPlayer.get('permission_level')) or 0
    if level >= Config.AdminLevel then return true end
    return group == 'superadmin' or group == 'admin' and Config.AdminLevel <= 1
end

function OKGangs.Server.RequireAdmin(source)
    if OKGangs.Server.IsAdmin(source) then return true end
    OKGangs.Notify(source, OKGangs.Errors.no_permission, 'error')
    return false
end

function OKGangs.Server.IsBoss(source)
    local gang, member = OKGangs.Server.GetPlayerGang(source)
    return gang and member and member.rank == Config.BossRank and gang.status == 1, gang, member
end

function OKGangs.Server.RequireActiveGang(source)
    local gang, member = OKGangs.Server.GetPlayerGang(source)
    if not gang or not member then
        OKGangs.Notify(source, OKGangs.Errors.not_in_gang, 'error')
        return nil, nil
    end
    if gang.status ~= 1 then
        OKGangs.Notify(source, OKGangs.Errors.gang_inactive, 'error')
        return nil, nil
    end
    return gang, member
end

function OKGangs.Server.CheckDistance(source, targetOrCoords, maxDistance)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    local sourceCoords = GetEntityCoords(ped)
    local targetCoords = targetOrCoords
    if type(targetOrCoords) == 'number' then
        local targetPed = GetPlayerPed(targetOrCoords)
        if not targetPed or targetPed == 0 then return false end
        targetCoords = GetEntityCoords(targetPed)
    end
    return #(sourceCoords - targetCoords) <= (maxDistance or Config.PlayerActionDistance)
end
