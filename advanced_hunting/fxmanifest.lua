fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'advanced_hunting'
author 'AMiR0k / OpenAI'
description 'Config driven RPG hunting system for ESX Legacy, ox_inventory, ox_lib and ox_target.'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/locales.lua',
    'shared/config.lua',
    'shared/animals.lua',
    'shared/items.lua',
    'data/zones.lua',
    'data/traders.lua',
    'modules/utils.lua'
}

client_scripts {
    'modules/antiabuse.lua',
    'modules/spawn.lua',
    'modules/skinning.lua',
    'modules/carcass.lua',
    'modules/butcher.lua',
    'client/animations.lua',
    'client/blips.lua',
    'client/zones.lua',
    'client/animals.lua',
    'client/tracking.lua',
    'client/target.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'modules/antiabuse.lua',
    'server/logging.lua',
    'server/security.lua',
    'server/xp.lua',
    'server/rewards.lua',
    'server/selling.lua',
    'server/main.lua'
}

dependency 'es_extended'
dependency 'ox_lib'
dependency 'ox_inventory'
dependency 'ox_target'
