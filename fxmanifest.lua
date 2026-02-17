fx_version 'cerulean'
game 'gta5'

author 'Chilllix'
description 'Login Reward Script'
version '2.0.0'

shared_script 'config.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

client_script 'client.lua'
