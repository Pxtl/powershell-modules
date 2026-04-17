@{  
    ModuleVersion = '0.3.1'
    GUID = 'c29c8e32-38a3-4ed4-acc3-11ad44bcab3c'
    Author = 'Martin C Zarate (AKA Pxtl)'
    Copyright = '2025, Martin C Zarate'
    Description = @'
Rough re-implementation of the MS ActiveDirectory powershell module by
leveraging the C# "System.DirectoryServices.Protocols" assembly which is available by
default on .NET enabled platforms instead of requiring that the user install RSAT. Very
feature-incomplete at this time.
'@
    
    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1'

    RootModule = 'bin\netstandard2.0\ADServices.dll'
    CmdletsToExport = '*'
    CompatiblePSEditions = @('Desktop', 'Core')
    FileList = @(
        'ADServices.psd1'
        'bin\netstandard2.0\ADServices.dll'
        'bin\netstandard2.0\ADServices.pdb'
        'bin\netstandard2.0\System.Buffers.dll'
        'bin\netstandard2.0\System.DirectoryServices.Protocols.dll'
        'bin\netstandard2.0\System.Management.Automation.dll'
        'bin\netstandard2.0\System.Memory.dll'
        'bin\netstandard2.0\System.Numerics.Vectors.dll'
        'bin\netstandard2.0\System.Runtime.CompilerServices.Unsafe.dll'
        'bin\netstandard2.0\System.Security.Principal.Windows.dll'
    )
    RequiredAssemblies = @(
        'bin\netstandard2.0\System.Buffers.dll'
        'bin\netstandard2.0\System.DirectoryServices.Protocols.dll'
        'bin\netstandard2.0\System.Management.Automation.dll'
        'bin\netstandard2.0\System.Memory.dll'
        'bin\netstandard2.0\System.Numerics.Vectors.dll'
        'bin\netstandard2.0\System.Runtime.CompilerServices.Unsafe.dll'
        'bin\netstandard2.0\System.Security.Principal.Windows.dll'
    )

    PrivateData = @{
        PSData = @{
            Tags = 'ActiveDirectory', 'DirectoryServices', 'RSAT'
            LicenseUri = 'https://github.com/Pxtl/powershell-modules?tab=MIT-1-ov-file'
    
            ProjectUri = 'https://github.com/Pxtl/powershell-modules'
            # IconUri = ''
            ReleaseNotes = @'
v0.3.1
- restrict manifest to not include peripheral files

v0.3.0
- converted module to .NET Framework 4.8

v0.2.0
- rewrote module using System.DirectoryServices.Protocols instead of SystemDirectoryServices
- supports ADOrganizationalUnit, ADRootDSE
- now attempts to match the object properties of the ActiveDirectory module.

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