# ADServices

## Projects

### ADServices.ModuleDll
This project contains the actual code for the functionality of ADServices, since
ADServices is a DLL-based module.  On compile it copies its output to
`ADServices.PSModule\ADServices\bin`.

### ADServices.ModuleDll.Tests
This project contains C# tests for the ModuleDll code directly, since it is
difficult to debug DLL pester tests.  Note that the code in this module does
*not* have the proper setup and teardown of the tests in the main `Tests` directory.

### ADServices.PSModule
This project contains the output `ADServices` directory, which will be packaged
up to publish to the target.  This is because it is difficult to publish without
grabbing undesired objects.  The `ADServices` directory is so named because by
default `publish-powershell-module-action` searches for any .psd1 where its name
matches the name of its parent directory to decide that this particular .psd1
file is a "module".

### Tests / ADServices.Pester.Tests
This project contains automated pester integration and unit tests, including
setup and teardown that uses a docker compose file for "SMBLDS", which is an
AD-work-alike LDAP server used for integration testing.