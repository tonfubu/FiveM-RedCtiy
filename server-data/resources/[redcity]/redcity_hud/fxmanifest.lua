fx_version 'cerulean'
game 'gta5'

lua54 'yes'

name 'redcity_hud'
author 'RedCity'
description 'RedCity ESX Legacy dark glass HUD with vehicle, fuel, status, seatbelt, voice, and gas station systems'
version '2.0.0'

shared_script 'config.lua'
client_script 'client.lua'
server_script 'server.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/sounds/seatbelt_on.ogg',
    'html/sounds/seatbelt_off.ogg',
    'html/sounds/seatbelt_warning.ogg'
}
