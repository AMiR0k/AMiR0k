fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'amir_vehiclekeys'
author 'AMiR0k / OpenAI'
description 'Professional ESX Legacy vehicle keys system with ox_inventory, ox_lib, esx_garage, lockpick and hotwire support.'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/utils.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'es_extended',
    'ox_lib',
    'ox_inventory',
    'oxmysql'
}

provide 'vehiclekeys'
