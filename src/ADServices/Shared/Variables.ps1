#TODO: REMOVE THIS AFTER CONFIRMING UNUSED.
# https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/useraccountcontrol-manipulate-account-properties
Set-Variable UserAccountControl_SCRIPT -Option ReadOnly -Value 0x01
Set-Variable UserAccountControl_ACCOUNT_DISABLED -Option ReadOnly -Value 0x02
Set-Variable UserAccountControl_HOMEDIR_REQUIRED -Option ReadOnly -Value 0x08
Set-Variable UserAccountControl_LOCKOUT -Option ReadOnly -Value 0x10
Set-Variable UserAccountControl_PASSWD_NOTREQD -Option ReadOnly -Value 0x20
Set-Variable UserAccountControl_PASSWD_CANT_CHANGE -Option ReadOnly -Value 0x40
Set-Variable UserAccountControl_ENCRYPTED_TEXT_PWD_ALLOWED -Option ReadOnly -Value 0x80
Set-Variable UserAccountControl_DONT_EXPIRE_PASSWORD -Option ReadOnly -Value 0x10000
Set-Variable UserAccountControl_MNS_LOGON_ACCOUNT -Option ReadOnly -Value 0x20000
Set-Variable UserAccountControl_SMARTCARD_REQUIRED -Option ReadOnly -Value 0x40000
Set-Variable UserAccountControl_TRUSTED_FOR_DELEGATION -Option ReadOnly -Value 0x80000
Set-Variable UserAccountControl_NOT_DELEGATED -Option ReadOnly -Value 0x100000
Set-Variable UserAccountControl_USE_DES_KEY_ONLY -Option ReadOnly -Value 0x200000
Set-Variable UserAccountControl_DONT_REQ_PREAUTH -Option ReadOnly -Value 0x400000
Set-Variable UserAccountControl_PASSWORD_EXPIRED -Option ReadOnly -Value 0x800000
Set-Variable UserAccountControl_TRUSTED_TO_AUTH_FOR_DELEGATION -Option ReadOnly -Value 0x1000000

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