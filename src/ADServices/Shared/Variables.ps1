Set-Variable UserAccountControl_ACCOUNT_DISABLED -Option ReadOnly -Value 0x02

# https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/11972272-09ec-4a42-bf5e-3e99b321cf55
# The names do not match the GroupScope values, but that's what's documented.
# "Global" group
Set-Variable GroupType_ACCOUNT_GROUP -Option ReadOnly -Value 0x02
# "DomainLocal" group
Set-Variable GroupType_RESOURCE_GROUP -Option ReadOnly -Value 0x04
# "Universal" group
Set-Variable GroupType_UNIVERSAL_GROUP -Option ReadOnly -Value 0x08
# Security Enabled group
Set-Variable GroupType_SECURITY_ENABLED -Option ReadOnly -Value 0x80000000
