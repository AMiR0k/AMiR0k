RegisterNetEvent('ok_gangs:client:notify', function(message, ntype)
    lib.notify({ title = 'OK_GANGS', description = message, type = ntype or 'inform' })
end)
