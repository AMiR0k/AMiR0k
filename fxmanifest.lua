fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'amir0k_rentcar'
author 'AMiR0k / OpenAI'
description 'Production-ready ESX Legacy car rental job with ox_inventory, ox_lib, ox_target, esx_garage and OneSync support.'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locales/*.lua'
}

client_scripts {
    'client.lua',
    'modules/client/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
    'modules/server/*.lua'
}

dependencies {
    'es_extended',
    'ox_lib',
    'ox_inventory',
    'ox_target',
    'oxmysql',
    'esx_garage'
}
