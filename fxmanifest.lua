fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

name 'w_chat'
author 'Wraith Studio'
version '1.2.2'
description 'w_chat — The custom, roleplay-ready chat system built for Red River and styled after w_lib'
-- 1.1.2 (2026-10-21): the store's VIP tiers (w_vip, bronze .. diamond) get their own badge colours
--   (Config.Ranks vip_*, Config.VipTiers); the staff ranks keep precedence. Without w_vip nothing changes.
-- 1.2.0 (2026-11-08): the page is built (web/: vite, `npm run build`, no install) on the board kit; it no
--   longer links w_lib's store theme, Font Awesome or its own font copies.

lua54 'yes'

-- Satisfies any third-party script expecting CFX default chat
provide 'chat'

ui_page 'web/build/index.html'

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
    'web/build/index.html',
    'web/build/**/*',
    'locales/*.json',
}

w_lib {
    'locale',
    'callback',
}

dependencies {
    'w_lib',
}
