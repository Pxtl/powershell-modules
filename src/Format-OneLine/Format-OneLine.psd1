@{
    RootModule = '.\Format-OneLine.psm1'
    ModuleVersion = '0.1.0'
    GUID = 'd46a00ff-0741-4278-85ae-6a71e9aecf14'
    Author = 'Martin C Zarate (AKA Pxtl)'
    Copyright = '2025, Martin C Zarate'
    Description = @'
Simple module providing a function Format-OneLine that converts
objects into semicolon-delimited lists of key=value pairs on a single line.
'@

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1'
    PrivateData = @{
        PSData = @{
            LicenseUri = 'https://github.com/Pxtl/powershell-modules?tab=MIT-1-ov-file'
            ProjectUri = 'https://github.com/Pxtl/powershell-modules'
            # IconUri = ''
            ReleaseNotes = @'
v0.1.0
- Initial Version
'@
        } # End of PSData hashtable
    } # End of PrivateData hashtable
    HelpInfoURI = 'https://github.com/Pxtl/powershell-modules'
}