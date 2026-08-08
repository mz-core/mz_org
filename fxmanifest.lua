fx_version 'cerulean'
game 'gta5'

name 'mz_org'
author 'Mazus'
description 'Painel NUI modular de organizações para MZ_CORE'
version '0.1.0'

lua54 'yes'

dependencies {
  'mz_core',
  'mz_menu',
  'mz_interact',
  'oxmysql'
}

shared_scripts {
  'shared/config.lua',
  'shared/context.lua',
  'shared/capabilities.lua',
  'shared/modules.lua',
  'shared/menu_profiles.lua',
  'shared/menu_features.lua',
  'shared/menu_mutations.lua',
  'shared/menu_organization_mutations.lua'
}

client_scripts {
  'client/menu/request.lua',
  'client/menu/theme.lua',
  'client/menu/common.lua',
  'client/menu/staff.lua',
  'client/menu/staff_mutations.lua',
  'client/menu/staff_operations.lua',
  'client/menu/staff_features.lua',
  'client/menu/staff_appearance.lua',
  'client/menu/staff_duty.lua',
  'client/menu/staff_organizations.lua',
  'client/menu/staff_logs.lua',
  'client/menu/organization_common.lua',
  'client/menu/organization_members.lua',
  'client/menu/organization_grades.lua',
  'client/menu/organization_finance.lua',
  'client/menu/organization_goals.lua',
  'client/menu/organization_recruitment.lua',
  'client/menu/organization_logs.lua',
  'client/menu/organization.lua',
  'client/menu/router.lua',
  'client/duty_points.lua',
  'client/main.lua'
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/main.lua',
  'server/security.lua',
  'server/session.lua',
  'server/menu_staff.lua',
  'server/menu_staff_mutations.lua',
  'server/menu_staff_operations.lua',
  'server/menu_organization.lua',
  'server/menu_organization_reads.lua',
  'server/menu_organization_operations.lua',
  'server/duty_points.lua',
  'server/permissions.lua',
  'server/orgs.lua',
  'server/members.lua',
  'server/bank.lua',
  'server/recruitment.lua',
  'server/goals.lua',
  'server/logs.lua',
  'tests/phase0_runtime_runner.lua'
}

ui_page 'web/index.html'

files {
  'web/index.html',
  'web/style.css',
  'web/script.js',
  'web/core/**/*.js',
  'web/services/**/*.js',
  'web/panels/**/*.js',
  'web/assets/**/*'
}
