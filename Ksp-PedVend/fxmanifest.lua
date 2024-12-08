fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'The-Last-Knight'   'Support Discord https://discord.gg/7M7tZcKCrM'
description 'Vendor script for buying & selling items plus exchanging markedbills'
version '2.0.'

shared_script 'config.lua'
client_script 'client.lua'
server_script 'server.lua'

files {
    'html/menu.html',
    'html/menu.js',
    'html/style.css'
}

ui_page 'html/menu.html'
