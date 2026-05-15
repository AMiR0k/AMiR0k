RegisterCommand('gangs', function(source)
    if not OKGangs.Server.RequireAdmin(source) then return end
    TriggerClientEvent('ok_gangs:client:openAdminMenu', source)
end, false)
