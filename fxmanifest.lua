fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'AMiR0k'
description 'Optimized ESX Legacy bank robbery (hack + weld) using ox_lib and ox_inventory'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

dependencies {
    'es_extended',
    'ox_lib',
    'ox_inventory',
    'utk_hackdependency'
}
