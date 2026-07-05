fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'amir0k_car_rental'
author 'AMiR0k / OpenAI'
description 'Production-ready ESX Legacy car rental job using ox_lib, ox_target, ox_inventory, esx_garage and OneSync.'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locales/*.lua',
    'modules/shared.lua'
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
    'ox_target',
    'ox_inventory',
    'oxmysql',
    'esx_garage'
}
