fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'oilrunner'
author 'AMiR0k / OpenAI'
description 'Secure ESX Legacy Oil Runner job with ox_lib, ox_inventory, Tug deposit, loading and delivery loop.'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

files {
    'sql/oilrunner.sql'
}

dependencies {
    'es_extended',
    'ox_lib',
    'ox_inventory',
    'oxmysql'
}
