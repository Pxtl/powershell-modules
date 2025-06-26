@{  
    ModuleVersion = '0.1.1'
    GUID = 'c29c8e32-38a3-4ed4-acc3-11ad44bcab3c'
    Author = 'Martin C Zarate (AKA Pxtl)'
    Copyright = '2025, Martin C Zarate'
    Description = @'
Rough lightweight feature-incomplete drop-in replacement for some of the
components of the MS ActiveDirectory module but leveraging the C#
"System.DirectoryServices.dll" assembly which is available by default on Windows
instead of requiring that the user install RSAT.
'@
    
    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1'

    NestedModules = @(
        '.\Shared\ADDirectoryEntry.psm1'
        '.\Shared\ADHelpers.psm1'
        'ADObject.psm1'
        'ADUser.psm1'
        'ADAccount.psm1'
        'ADGroup.psm1'
        'ADGroupMember.psm1'
        'ADOrganizationalUnit.psm1'
    )

    FunctionsToExport = @(
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
v0.1.1
- hide private functions properly

v0.1.0
- Initial Version
'@
        } # End of PSData hashtable
    } # End of PrivateData hashtable
    HelpInfoURI = 'https://github.com/Pxtl/powershell-modules'
}