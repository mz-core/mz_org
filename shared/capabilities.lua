MZOrgCapabilities = {
  -- Org geral
  'org.view',

  -- Membros
  'members.view',
  'members.invite',
  'members.remove',
  'members.promote',
  'members.demote',
  'members.set_leader',
  'manage.members',

  -- Banco
  'account.view',
  'account.deposit',
  'account.withdraw',
  'account.manage',

  -- Metas
  'goals.view',
  'goals.manage',

  -- Recrutamento
  'recruitment.view',
  'recruitment.manage',

  -- Logs
  'logs.view',

  -- Aliases legados mantidos para compatibilidade
  'members.kick',
  'members.suspend',
  'account.transfer',
  'manage.permissions',
  'manage.account',
  'manage.goals',

  -- Permissoes de dominio usadas pelos seeds padrao
  'radio.use',
  'tablet.open',
  'mdt.open',
  'storage.open',
  'storage.deposit',
  'storage.withdraw',
  'storage.manage',
  'armory.basic',
  'vehicle.basic',
  'vehicle.medium',
  'vehicle.advanced',
  'vehicle.manage',
  'patrol.basic',
  'patrol.lead',
  'reports.approve',
  'manage.team',
  'boss.actions',
  'org.settings',
  'highcommand',
  'command.full',

  -- Policia
  'police.custody',
  'police.search',
  'police.seize',
  'police.impound',
  'police.road.tools',
  'police.anpr',
  'police.radar',
  'police.evidence.collect',
  'police.evidence.manage',
  'police.records.write',
  'police.citation.issue',
  'police.warrant.create',
  'police.warrant.approve',
  'police.arrest.request',
  'police.camera.use',
  'police.camera.view',
  'police.air.support',
  'police.tracker.use',
  'police.tracker.view',
  'police.forensics.request',

  -- Instalacoes e atividades organizacionais. A Fase 1 apenas reserva os
  -- codigos; nenhum seed recebe estas capabilities automaticamente.
  'facility.view',
  'facility.purchase',
  'facility.upgrade',
  'facility.manage',
  'facility.furniture.view',
  'facility.furniture.buy',
  'facility.furniture.place',
  'facility.furniture.move',
  'facility.furniture.store',
  'activities.view',
  'activities.start',
  'activities.cancel',
  'activities.collect',
  'activities.manage',
  'research.view',
  'research.unlock',
  'drugs.process',
  'drugs.package',
  'weapons.craft',
  'weapons.repair',
  'weapons.attachments',
  'ammo.craft',
  'laundering.operate',

  -- VIP
  'vip.chat.tag',
  'vip.kit.bronze',
  'vip.kit.silver',
  'vip.kit.gold',

  -- Hospital
  'ambulance.radio.use',
  'ambulance.tablet.open',
  'ambulance.medkit.basic',
  'ambulance.revive.basic',
  'ambulance.revive.advanced',
  'ambulance.vehicle.basic',
  'ambulance.manage.team',

  -- Mecanica
  'mechanic.tablet.open',
  'mechanic.repair.basic',
  'mechanic.repair.advanced',
  'mechanic.tow.use',
  'mechanic.manage.team',
  'mechanic.boss.actions'
}
