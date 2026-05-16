fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'OpenAI GPT-5.5'
description 'Modular ESX Legacy / ox_inventory / ox_lib farming system with instanced farms'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'utils.lua'
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
    'oxmysql'
}
