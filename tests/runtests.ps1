<#
.SYNOPSIS
    A simple Powershell script to test installed salt minion on windows.

.PARAMETER version
    Salt version installed.

.PARAMETER runservice
    Boolean flag whenever to test if service is running.

.PARAMETER noservice
    Boolean flag whenever to test if service is not running.

.PARAMETER minion
    Name of the minion installed on this host.

.PARAMETER master
    Name of the master configured on this host.

.EXAMPLE
    ./runtests.ps1
    Runs without any parameters. Uses all the default values/settings.
#>

#===============================================================================
# Commandlet Binding
#===============================================================================
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$False,ValueFromPipeline=$True)]
    [string]$version = $null,

    [Parameter(Mandatory=$False,ValueFromPipeline=$True)]
    [switch]$runservice,

    [Parameter(Mandatory=$False,ValueFromPipeline=$True)]
    [switch]$noservice,

    [Parameter(Mandatory=$False,ValueFromPipeline=$True)]
    [string]$minion = $null,

    [Parameter(Mandatory=$False,ValueFromPipeline=$True)]
    [string]$master = $null
)

#===============================================================================
# Script Functions
#===============================================================================
function Get-Grains ([string]$Name) {
    $Command = "salt-call --local --out json --out-indent -1 grains.get $Name"
    $Result = iex $Command | Out-String | ConvertFrom-Json

    Write-Verbose "salt-call grains.get ${Name}:`n${Result}"
    return $Result."local"
}

function Get-Service-Status([string]$Name) {
    $Service = Get-Service $Name -ErrorAction Stop
    $Status = $Service.Status

    Write-Verbose "${Name}: ${Status}"
    return $Status
}

function Assert-Equal {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
        [string]$Actual,

        [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
        [string]$Expected
    )

    If ($Actual -ne $Expected) {
        throw "Assert: $Actual != $Expected"
    }
}

#===============================================================================
# Do enabled checks
#===============================================================================
if ($True) {
    Get-Grains -Name os_family | Assert-Equal -Expected "Windows"
}

if ($version) {
    Get-Grains -Name saltversion | Assert-Equal -Expected $version
}

if ($master) {
    Get-Grains -Name master | Assert-Equal -Expected $master
}

if ($minion) {
    Get-Grains -Name id | Assert-Equal -Expected $minion
}

if ($runservice) {
    Get-Service-Status salt-minion | Assert-Equal -Expected "Running"
}

if ($noservice) {
    Get-Service-Status salt-minion | Assert-Equal -Expected "Stopped"
}
