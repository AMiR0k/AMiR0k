OKGangs = OKGangs or {}
OKGangs.Server = OKGangs.Server or {}

lib.callback.register('ok_gangs:server:createGang', function(source, data) return OKGangs.Server.CreateGang(source, data) end)
lib.callback.register('ok_gangs:server:setGangStatus', function(source, gangId, status) return OKGangs.Server.SetGangStatus(source, gangId, status) end)
lib.callback.register('ok_gangs:server:updateGangField', function(source, gangId, field, value) return OKGangs.Server.UpdateGangField(source, gangId, field, value) end)
lib.callback.register('ok_gangs:server:extendGang', function(source, gangId, days) return OKGangs.Server.ExtendGang(source, gangId, days) end)
lib.callback.register('ok_gangs:server:setLocation', function(source, gangId, locationType, coords) return OKGangs.Server.SetLocation(source, gangId, locationType, coords) end)
lib.callback.register('ok_gangs:server:addMember', function(source, target, gangId, rank)
    if not OKGangs.Server.IsAdmin(source) then
        local isBoss, gang = OKGangs.Server.IsBoss(source)
        if not isBoss or gang.id ~= tonumber(gangId) then return false, OKGangs.Errors.no_permission end
        if not OKGangs.Server.CheckDistance(source, target, Config.PlayerActionDistance) then return false, OKGangs.Errors.player_too_far end
    end
    return OKGangs.Server.AddMember(source, target, gangId, rank)
end)
lib.callback.register('ok_gangs:server:removeMember', function(source, identifier)
    local member = OKGangs.Server.GetMember(identifier)
    if not member then return false end
    if not OKGangs.Server.IsAdmin(source) then
        local isBoss, gang = OKGangs.Server.IsBoss(source)
        if not isBoss or gang.id ~= member.gang_id then return false, OKGangs.Errors.no_permission end
    end
    return OKGangs.Server.RemoveMember(source, identifier)
end)
lib.callback.register('ok_gangs:server:setMemberRank', function(source, identifier, rank)
    local member = OKGangs.Server.GetMember(identifier)
    if not member then return false end
    if not OKGangs.Server.IsAdmin(source) then
        local isBoss, gang = OKGangs.Server.IsBoss(source)
        if not isBoss or gang.id ~= member.gang_id then return false, OKGangs.Errors.no_permission end
    end
    return OKGangs.Server.SetMemberRank(source, identifier, rank)
end)
lib.callback.register('ok_gangs:server:setRankData', function(source, gangId, rank, label, salary, permissions)
    if not OKGangs.Server.IsAdmin(source) then
        local isBoss, gang = OKGangs.Server.IsBoss(source)
        if not isBoss or gang.id ~= tonumber(gangId) then return false, OKGangs.Errors.no_permission end
    end
    return OKGangs.Server.SetRankData(source, gangId, rank, label, salary, permissions)
end)
