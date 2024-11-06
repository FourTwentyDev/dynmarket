fx_version 'cerulean'
game 'gta5'

author 'FourTwentyDev'
description 'Dynamic Market System'
version '1.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    '@es_extended/locale.lua',
    'shared/*.lua',
    'config.lua'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/styles.css',
    'html/script.js'
}

-- dependencies {
--     'es_extended',
--     'oxmysql'
-- }

lua54 'yes'