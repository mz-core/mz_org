fx_version 'cerulean'
game 'gta5'

name 'mz_org'
author 'Mazus'
description 'Painel NUI modular de organizações para MZ_CORE'
version '0.1.0'

lua54 'yes'

dependency 'mz_core'

shared_scripts {
  'shared/config.lua',
  'shared/capabilities.lua',
  'shared/modules.lua'
}

client_scripts {
  'client/main.lua'
}

server_scripts {
  'server/main.lua',
  'server/session.lua',
  'server/permissions.lua',
  'server/orgs.lua',
  'server/members.lua',
  'server/bank.lua',
  'server/recruitment.lua',
  'server/goals.lua',
  'server/logs.lua'
}

ui_page 'web/index.html'

files {
  'web/index.html',
  'web/style.css',
  'web/script.js',
  'web/panels/**/*.js',
  'web/assets/**/*'
}