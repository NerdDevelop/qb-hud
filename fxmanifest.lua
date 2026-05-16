-- NERD HUD
-- (c) 2026 Nerd. All rights reserved.

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Sultan · NERD'
description 'HUD by NERD'
version '1.0.0'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client.lua',
}

server_scripts {
    'server.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/nerd-theme.css',
}

-- minimap textures auto-stream from the stream/ folder
