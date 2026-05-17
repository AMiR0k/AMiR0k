fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'six_atmrobbery'
author 'OpenAI / AMiR0k'
description 'Production-ready ESX Legacy ATM robbery using ox_inventory, ox_lib, ox_target, and scaleform drilling.'
version '2.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

dependencies {
    'es_extended',
    'ox_inventory',
    'ox_lib',
    'ox_target'
}
