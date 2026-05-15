fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'OK_GANGS'
author 'OpenAI'
description 'Dynamic ESX Legacy gang system using ox_lib, ox_inventory, oxmysql, and esx_garage'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@es_extended/imports.lua',
    'config.lua',
    'shared/config_shared.lua',
    'shared/functions.lua',
    'shared/crafting_recipes.lua',
    'shared/vehicle_config.lua',
    'locales/*.lua'
}

client_scripts {
    'client/notifications.lua',
    'client/main.lua',
    'client/blips.lua',
    'client/markers.lua',
    'client/admin_menu.lua',
    'client/gang_menu.lua',
    'client/vehicle_menu.lua',
    'client/crafting.lua',
    'client/interactions.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/discord_logs.lua',
    'server/database.lua',
    'server/permissions.lua',
    'server/gang_manager.lua',
    'server/inventory_handler.lua',
    'server/xp_system.lua',
    'server/vehicle_handler.lua',
    'server/crafting_server.lua',
    'server/callbacks.lua',
    'server/admin_handler.lua',
    'server/commands.lua',
    'server/main.lua'
}

dependencies {
    'es_extended',
    'ox_lib',
    'ox_inventory',
    'oxmysql',
    'esx_garage'
}
