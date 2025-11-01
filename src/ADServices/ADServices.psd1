@{  
    ModuleVersion = '0.1.2'
    GUID = 'c29c8e32-38a3-4ed4-acc3-11ad44bcab3c'
    Author = 'Martin C Zarate (AKA Pxtl)'
    Copyright = '2025, Martin C Zarate'
    Description = @'
Rough re-implementation of the MS ActiveDirectory powershell module but
leveraging the C# "System.DirectoryServices.dll" assembly which is available by
default on Windows instead of requiring that the user install RSAT. Very
feature-incomplete at this time.  Also, unfortunately
"System.DirectoryServices.dll" is Windows-only and therefore so is this module.
'@
    
    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1'

    NestedModules = @(
        '.\Shared\LDAPEntry.psm1'
        '.\Shared\ADHelpers.psm1'
        'ADRootDSE.psm1'
        'ADObject.psm1'
        'ADUser.psm1'
        'ADAccount.psm1'
        'ADGroup.psm1'
        'ADGroupMember.psm1'
        'ADOrganizationalUnit.psm1'
    )

    FunctionsToExport = @(
        '*-ADRootDSE'
        '*-ADObject'
        '*-ADUser'
        '*-ADAccount'
        '*-ADGroup'
        '*-ADGroupMember'
        '*-ADOrganizationalUnit'
    )

    CompatiblePSEditions = @('Desktop')

    PrivateData = @{
        PSData = @{
            Tags = 'ActiveDirectory', 'DirectoryServices', 'RSAT'
            LicenseUri = 'https://github.com/Pxtl/powershell-modules?tab=MIT-1-ov-file'
    
            ProjectUri = 'https://github.com/Pxtl/powershell-modules'
            # IconUri = ''
            ReleaseNotes = @'
v0.1.2
- add Get-ADGroupMember

v0.1.1
- hide private functions properly

v0.1.0
- Initial Version
- Includes main verbs for ADObject, ADUser, ADAccount, ADGroup, ADGroupMember
'@
        } # End of PSData hashtable
    } # End of PrivateData hashtable
    HelpInfoURI = 'https://github.com/Pxtl/powershell-modules'
}