Config = Config or {}

Config.Debug = true

Config.UseMockSession = false
Config.AllowDevMockSession = Config.Debug == true
Config.DebugCommands = Config.Debug == true
Config.NuiCallbackTimeoutMs = 5000

Config.Commands = {
  Dev = 'mzorg',
  Main = 'painel',
  Org = 'org',
  Gang = 'gang',
  Staff = 'staff',
  Vip = 'vip',
  Business = 'business',
  Government = 'government',
  Event = 'event'
}

Config.Command = Config.Commands.Dev

Config.OwnerAce = 'group.mz_owner'

Config.DefaultGangGrades = {
  { level = 1, code = 'recruta', name = 'Recruta', salary = 0 },
  { level = 2, code = 'membro', name = 'Membro', salary = 0, inherits_level = 1 },
  { level = 3, code = 'gerente', name = 'Gerente', salary = 0, inherits_level = 2 },
  { level = 4, code = 'lider', name = 'Líder', salary = 0, inherits_level = 3 }
}
