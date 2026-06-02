fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'OpenAI'
description 'Oil Runner job for ESX Legacy using ox_lib and ox_inventory'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@es_extended/imports.lua',
    'server/main.lua'
}

dependencies {
    'es_extended',
    'ox_lib',
    'ox_inventory',
    'skinchanger',
    'esx_skin'
}
