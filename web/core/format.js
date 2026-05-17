(function () {
  'use strict';

  function asNumber(value, fallback) {
    var number = Number(value);
    return Number.isFinite(number) ? number : (fallback || 0);
  }

  function fallback(value) {
    return value === null || value === undefined || value === '' ? '-' : value;
  }

  function formatMoney(value, currency) {
    var amount = asNumber(value, 0);
    try {
      return amount.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
    } catch (error) {
      return (currency || 'R$') + ' ' + amount.toFixed(2).replace('.', ',');
    }
  }

  function formatDate(value) {
    if (!value) return '-';
    var date = new Date(value);
    if (Number.isNaN(date.getTime())) return String(value);
    return date.toLocaleString('pt-BR');
  }

  function formatDateTime(value) {
    return formatDate(value);
  }

  function formatNumber(value) {
    return asNumber(value, 0).toLocaleString('pt-BR');
  }

  function formatOrgType(value) {
    value = String(value || '').toLowerCase();
    if (value === 'job' || value === 'legal') return 'Organizacao legal';
    if (value === 'illegal' || value === 'gang') return 'Faccao';
    if (value === 'business') return 'Empresa';
    if (value === 'government') return 'Governo';
    if (value === 'vip') return 'VIP';
    if (value === 'event') return 'Eventos';
    if (value === 'staff') return 'Staff';
    return value || '-';
  }

  var capabilityLabels = {
    'org.view': 'Ver organizacao',
    'radio.use': 'Usar radio',
    'tablet.open': 'Abrir tablet',
    'mdt.open': 'Abrir MDT',
    'storage.open': 'Abrir deposito',
    'storage.deposit': 'Depositar itens',
    'storage.withdraw': 'Retirar itens',
    'armory.basic': 'Arsenal basico',
    'vehicle.basic': 'Veiculos basicos',
    'vehicle.medium': 'Veiculos intermediarios',
    'vehicle.advanced': 'Veiculos avancados',
    'patrol.basic': 'Patrulhamento',
    'patrol.lead': 'Liderar patrulha',
    'members.view': 'Ver membros',
    'members.invite': 'Convidar membros',
    'members.remove': 'Remover membros',
    'members.kick': 'Remover membros',
    'members.promote': 'Promover membros',
    'members.demote': 'Rebaixar membros',
    'members.set_leader': 'Alterar lideranca',
    'manage.members': 'Gerenciar membros',
    'manage.team': 'Gerenciar equipe',
    'goals.view': 'Ver metas',
    'goals.manage': 'Gerenciar metas',
    'manage.goals': 'Gerenciar metas',
    'account.view': 'Ver banco da organizacao',
    'account.deposit': 'Depositar no banco da organizacao',
    'account.withdraw': 'Sacar do banco da organizacao',
    'account.manage': 'Gerenciar banco da organizacao',
    'manage.account': 'Gerenciar banco',
    'account.transfer': 'Transferir pelo banco',
    'logs.view': 'Ver auditoria',
    'manage.permissions': 'Gerenciar permissoes',
    'org.settings': 'Configurar organizacao',
    'boss.actions': 'Acoes de lideranca',
    'highcommand': 'Alto comando',
    'command.full': 'Comando completo',
    'recruitment.view': 'Ver recrutamento',
    'recruitment.manage': 'Gerenciar recrutamento',
    'reports.approve': 'Aprovar relatorios',
    'staff.panel.open': 'Abrir painel staff',
    'staff.orgs.view': 'Consultar orgs',
    'staff.report.view': 'Ver reports',
    'staff.kick': 'Expulsar jogador',
    'staff.spectate': 'Spectar jogador',
    'staff.ban': 'Banir jogador',
    'staff.teleport': 'Teleportar',
    'staff.orgs.manage': 'Gerenciar orgs',
    'staff.orgs.set_leader': 'Definir liderancas',
    'staff.staff.manage': 'Gerenciar staff',
    'staff.logs.view': 'Ver logs staff',
    'staff.players.manage': 'Gerenciar players',
    'staff.members.invite': 'Convidar staff',
    'staff.members.remove': 'Remover staff',
    'staff.members.promote': 'Promover staff',
    'staff.members.demote': 'Rebaixar staff',
    'vip.chat.tag': 'Tag no chat',
    'vip.kit.bronze': 'Kit bronze',
    'vip.kit.silver': 'Kit prata',
    'vip.kit.gold': 'Kit ouro',
    'ambulance.radio.use': 'Usar radio hospital',
    'ambulance.tablet.open': 'Abrir tablet hospital',
    'ambulance.medkit.basic': 'Kit medico basico',
    'ambulance.revive.basic': 'Atendimento basico',
    'ambulance.revive.advanced': 'Atendimento avancado',
    'ambulance.vehicle.basic': 'Veiculos hospital',
    'ambulance.manage.team': 'Gerenciar equipe',
    'mechanic.tablet.open': 'Abrir tablet mecanica',
    'mechanic.repair.basic': 'Reparo basico',
    'mechanic.repair.advanced': 'Reparo avancado',
    'mechanic.tow.use': 'Usar guincho',
    'mechanic.manage.team': 'Gerenciar equipe',
    'mechanic.boss.actions': 'Acoes de chefia'
  };

  function titleCase(value) {
    return String(value || '').replace(/\w\S*/g, function (word) {
      return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
    });
  }

  function formatCapabilityLabel(capability) {
    capability = String(capability || '').trim();
    if (!capability) return '-';
    if (capabilityLabels[capability]) return capabilityLabels[capability];
    return titleCase(capability.replace(/[._-]+/g, ' '));
  }

  function formatGradeName(item) {
    item = item || {};
    var name = item.gradeName || item.name || item.grade_name;
    var level = item.grade || item.level || item.gradeLevel;
    var code = item.gradeCode || item.code || item.grade_code;

    if (name && level) return name + ' - Nivel ' + level;
    if (name) return name;
    if (code && level) return formatCapabilityLabel(code) + ' - Nivel ' + level;
    if (code) return formatCapabilityLabel(code);
    if (level) return 'Nivel ' + level;
    return '-';
  }

  function maskCitizenId(citizenid) {
    citizenid = String(citizenid || '').trim();
    if (!citizenid) return '-';
    if (citizenid.length <= 8) return citizenid;
    return citizenid.slice(0, 6) + '...' + citizenid.slice(-2);
  }

  function formatGoalType(value) {
    value = String(value || 'manual').toLowerCase();
    if (value === 'weekly') return 'Semanal';
    if (value === 'monthly') return 'Mensal';
    if (value === 'collective') return 'Coletiva';
    if (value === 'individual') return 'Individual';
    return 'Manual';
  }

  function formatStatusLabel(value) {
    value = String(value || '').toLowerCase();
    if (value === 'active' || value === 'ativa') return 'Ativa';
    if (value === 'paused' || value === 'pausada') return 'Pausada';
    if (value === 'completed' || value === 'concluida') return 'Concluida';
    if (value === 'expired' || value === 'expirada') return 'Expirada';
    if (value === 'pending' || value === 'pendente') return 'Pendente';
    if (value === 'approved' || value === 'aprovado') return 'Aprovada';
    if (value === 'rejected' || value === 'recusado') return 'Recusada';
    if (value === 'cancelled' || value === 'arquivado') return 'Arquivada';
    if (value === 'warn') return 'Aviso';
    if (value === 'error') return 'Erro';
    return value ? titleCase(value.replace(/[._-]+/g, ' ')) : '-';
  }

  function formatSeverity(value) {
    value = String(value || 'info').toLowerCase();
    if (value === 'warn') return 'warning';
    if (value === 'error') return 'danger';
    return value;
  }

  window.MZOrgFormat = {
    asNumber: asNumber,
    fallback: fallback,
    formatMoney: formatMoney,
    formatDate: formatDate,
    formatDateTime: formatDateTime,
    formatNumber: formatNumber,
    formatOrgType: formatOrgType,
    formatCapabilityLabel: formatCapabilityLabel,
    formatGradeName: formatGradeName,
    maskCitizenId: maskCitizenId,
    formatGoalType: formatGoalType,
    formatStatusLabel: formatStatusLabel,
    formatSeverity: formatSeverity
  };
}());
