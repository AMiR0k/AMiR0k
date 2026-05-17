fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'AMiR0k'
description 'Modern ESX Legacy car thief mission using ox_lib and optional ox_inventory keys'
version '1.0.0'

dependencies {
    'es_extended',
    'ox_lib',
    'ox_inventory'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locales/*.lua',
    'shared/locale.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}
