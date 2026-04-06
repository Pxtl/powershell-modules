Set-StrictMode -Version Latest
$ErrorActionPreference = [Management.Automation.ActionPreference]::Stop
. $PSScriptRoot\Shared\Variables.ps1

function Enable-ADAccount {
    [Diagnostics.CodeAnalysis.SuppressMessage(
        'PSShouldProcess','',Scope='Function',Justification='-WhatIf passed through to ADUser func'
    )]
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $Identity,
        [string] $Server,
        [PSCredential] $Credential,
        [switch] $PassThru
    )
    begin {
        $commonParams = @{
            WhatIf = $WhatIfPreference
            Verbose = $VerbosePreference
        }
    }
    process {
        Set-ADUser -Identity $Identity -Enabled $true -Server $Server -Credential $Credential -PassThru:$PassThru @commonParams
    }
}


function Disable-ADAccount {
    [Diagnostics.CodeAnalysis.SuppressMessage(
        'PSShouldProcess','',Scope='Function',Justification='-WhatIf passed through to ADUser func'
    )]
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $Identity,
        [string] $Server,
        [PSCredential] $Credential,
        [switch] $PassThru
    )
    begin {
        $commonParams = @{
            WhatIf = $WhatIfPreference
            Verbose = $VerbosePreference
        }
    }
    process {
        Set-ADUser -Identity $Identity -Enabled $false -Server $Server -Credential $Credential -PassThru:$PassThru @commonParams
    }
}
