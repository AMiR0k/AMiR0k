fx_version 'cerulean'
game 'gta5'

name 'Oil Runner'
author 'AMiR0k / OpenAI'
description 'ESX Legacy oil transport job with tug deposits, loading, and delivery routes.'
version '1.0.0'
lua54 'yes'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

dependencies {
    'es_extended',
    'ox_lib',
    'ox_inventory'
}
