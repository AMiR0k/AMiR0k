OKGangs = OKGangs or {}
OKGangs.Server = OKGangs.Server or {}

lib.callback.register('ok_gangs:server:getAllGangs', function(source)
    return OKGangs.Server.GetAllPublicGangs()
end)

lib.callback.register('ok_gangs:server:getMyGang', function(source)
    local gang, member = OKGangs.Server.GetPlayerGang(source)
    return OKGangs.Server.GetPublicGang(gang), member
end)

lib.callback.register('ok_gangs:server:getNearbyPlayers', function(source)
    local players = {}
    for _, playerId in ipairs(ESX.GetPlayers()) do
        if playerId ~= source and OKGangs.Server.CheckDistance(source, playerId, Config.PlayerActionDistance) then
            local xPlayer = ESX.GetPlayerFromId(playerId)
            if xPlayer then players[#players + 1] = { id = playerId, name = xPlayer.getName(), hasGang = OKGangs.Server.GetMember(xPlayer.identifier) ~= nil } end
        end
    end
    return players
end)
