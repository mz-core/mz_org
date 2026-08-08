MZOrgMenuTheme = MZOrgMenuTheme or {}

function MZOrgMenuTheme.Resolve(organization)
  organization = type(organization) == 'table' and organization or {}
  if type(organization.presentation) == 'table' then return organization.presentation end
  return MZOrgMenuProfiles.Resolve(organization.type, nil)
end

