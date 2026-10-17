fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

name 'w_chat'
author 'Wraith Studio'
version '1.1.1'
description 'w_chat — The custom, roleplay-ready chat system built for Red River and styled after w_lib'

lua54 'yes'

-- Satisfies any third-party script expecting CFX default chat
provide 'chat'

ui_page 'web/index.html'

shared_scripts {
    '@w_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/tex/ui/*.png',
    'web/fonts/*.woff2',
    'web/**/*',
    'locales/*.json',
}

w_lib {
    'locale',
    'callback',
}

dependencies {
    'w_lib',
    'w_core',
}
