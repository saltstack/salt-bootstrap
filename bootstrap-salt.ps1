<#
.SYNOPSIS
    A simple Powershell script to download and install a salt minion on windows.

.DESCRIPTION
    The script will download the official salt package from saltstack. It will
    install a specific package version and accept parameters for the master and
    minion ids. Finally, it can stop and set the windows service to "manual" for
    local testing.

.EXAMPLE
    ./bootstrap-salt.ps1
    Runs without any parameters. Uses all the default values/settings.

.EXAMPLE
    ./bootstrap-salt.ps1 -version 2017.7.0
    Specifies a particular version of the installer.

.EXAMPLE
    ./bootstrap-salt.ps1 -pythonVersion 3
    Specifies the Python version of the installer. Can be "2" or "3". Defaults to "2".
    Python 3 installers are only available for Salt 2017.7.0 and newer.

.EXAMPLE
    ./bootstrap-salt.ps1 -runservice false
    Specifies the salt-minion service to stop and be set to manual. Useful for
    testing locally from the command line with the --local switch

.EXAMPLE
    ./bootstrap-salt.ps1 -minion minion-box -master master-box
    Specifies the minion and master ids in the minion config. Defaults to the
    installer values of host name for the minion id and "salt" for the master.

.EXAMPLE
    ./bootstrap-salt.ps1 -minion minion-box -master master-box -version 2017.7.0 -runservice false
    Specifies all the optional parameters in no particular order.

.PARAMETER version
    Default version defined in this script.

.PARAMETER pythonVersion
    The version of Python the installer should use. Specify either "2" or "3".
    Beginning with Salt 2017.7.0, Salt will run on either Python 2 or Python 3.
    The default is Python 2 if not specified. This parameter only works for Salt
    versions >= 2017.7.0.

.PARAMETER runservice
    Boolean flag to start or stop the minion service. True will start the minion
    service. False will stop the minion service and set it to "manual". The
    installer starts it by default.

.PARAMETER minion
    Name of the minion being installed on this host. Installer defaults to the
    host name.

.PARAMETER master
    Name or IP of the master server. Installer defaults to "salt".

.PARAMETER repourl
    URL to the windows packages. Default is "https://repo.saltstack.com/windows"

.NOTES
    All of the parameters are optional. The default should be the latest
    version. The architecture is dynamically determined by the script.

.LINK
    Bootstrap GitHub Project (script home) - https://github.com/saltstack/salt-windows-bootstrap
    Original Vagrant Provisioner Project -https://github.com/saltstack/salty-vagrant
    Vagrant Project (utilizes this script) - https://github.com/mitchellh/vagrant
    SaltStack Download Location - https://repo.saltstack.com/windows/
#>

#===============================================================================
# Commandlet Binding
#===============================================================================
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$false,ValueFromPipeline=$true)]
    # Doesn't support versions prior to "YYYY.M.R-B"
    [ValidatePattern('^201\d\.\d{1,2}\.\d{1,2}(\-\d{1})?|(rc\d)$')]
    [string]$version = '',

    [Parameter(Mandatory=$false,ValueFromPipeline=$true)]
    # Doesn't support versions prior to "2017.7.0"
    [ValidateSet("2","3")]
    [string]$pythonVersion = "",

    [Parameter(Mandatory=$false,ValueFromPipeline=$true)]
    [ValidateSet("true","false")]
    [string]$runservice = "true",

    [Parameter(Mandatory=$false,ValueFromPipeline=$true)]
    [string]$minion = "not-specified",

    [Parameter(Mandatory=$false,ValueFromPipeline=$true)]
    [string]$master = "not-specified",

    [Parameter(Mandatory=$false,ValueFromPipeline=$true)]
    [string]$repourl= "https://repo.saltstack.com/windows"
)

#===============================================================================
# Script Functions
#===============================================================================
function Get-IsAdministrator
{
    $Identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object System.Security.Principal.WindowsPrincipal($Identity)
    $Principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-IsUacEnabled
{
    (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System).EnableLua -ne 0
}

#===============================================================================
# Check for Elevated Privileges
#===============================================================================
If (!(Get-IsAdministrator)) {
    If (Get-IsUacEnabled) {
        # We are not running "as Administrator" - so relaunch as administrator
        # Create a new process object that starts PowerShell
        $newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell";

        # Specify the current script path and name as a parameter`
        $parameters = ""
        If($minion -ne "not-specified") {$parameters = "-minion $minion"}
        If($master -ne "not-specified") {$parameters = "$parameters -master $master"}
        If($runservice -eq $false) {$parameters = "$parameters -runservice false"}
        If($version -ne '') {$parameters = "$parameters -version $version"}
        If($pythonVersion -ne "") {$parameters = "$parameters -pythonVersion $pythonVersion"}
        $newProcess.Arguments = $myInvocation.MyCommand.Definition, $parameters

        # Specify the current working directory
        $newProcess.WorkingDirectory = "$script_path"

        # Indicate that the process should be elevated
        $newProcess.Verb = "runas";

        # Start the new process
        [System.Diagnostics.Process]::Start($newProcess);

        # Exit from the current, unelevated, process
        Exit
    }
    Else {
        Throw "You must be administrator to run this script"
    }
}

#===============================================================================
# Verify Parameters
#===============================================================================
Write-Verbose "Parameters passed in:"
Write-Verbose "version: $version"
Write-Verbose "runservice: $runservice"
Write-Verbose "master: $master"
Write-Verbose "minion: $minion"
Write-Verbose "repourl: $repourl"

If ($runservice.ToLower() -eq "true") {
    Write-Verbose "Windows service will be set to run"
    [bool]$runservice = $True
}
ElseIf ($runservice.ToLower() -eq "false") {
    Write-Verbose "Windows service will be stopped and set to manual"
    [bool]$runservice = $False
}
Else {
    # Param passed in wasn't clear so defaulting to true.
    Write-Verbose "Windows service defaulting to run automatically"
    [bool]$runservice = $True
}

#===============================================================================
# Ensure Directories are present, copy Vagrant Configs if found
#===============================================================================
# Create C:\tmp\
New-Item C:\tmp\ -ItemType directory -Force | Out-Null

# Copy Vagrant Files to their proper location. Vagrant files will be placed
# in C:\tmp
# Check if minion keys have been uploaded, copy to correct location
If (Test-Path C:\tmp\minion.pem) {
    New-Item C:\salt\conf\pki\minion\ -ItemType Directory -Force | Out-Null
    # Copy minion keys & config to correct location
    cp C:\tmp\minion.pem C:\salt\conf\pki\minion\
    cp C:\tmp\minion.pub C:\salt\conf\pki\minion\
}

# Check if minion config has been uploaded
# This should be done before the installer is run so that it can be updated with
# id: and master: settings when the installer runs
If (Test-Path C:\tmp\minion) {
    New-Item C:\salt\conf\ -ItemType Directory -Force | Out-Null
    Copy-Item -Path C:\tmp\minion -Destination C:\salt\conf\ -Force | Out-Null
}

#===============================================================================
# Detect architecture
#===============================================================================
If ([IntPtr]::Size -eq 4) {
    $arch = "x86"
}
Else {
    $arch = "AMD64"
}

#===============================================================================
# Figure out the latest version if no version is passed
#===============================================================================
# If version isn't supplied, use latest.
If (!$version) {
    # Find latest version of Salt Minion
    $repo = Invoke-Restmethod "$repourl"
    $regex = "<\s*a\s*[^>]*?href\s*=\s*[`"']*([^`"'>]+)[^>]*?>"
    $returnMatches = New-Object System.Collections.ArrayList
    $resultingMatches = [Regex]::Matches($repo, $regex, "IgnoreCase")
    foreach($match in $resultingMatches) {
        $cleanedMatch = $match.Groups[1].Value.Trim()
        [void] $returnMatches.Add($cleanedMatch)
    }
    If ($arch -eq 'x86') {
        $returnMatches = $returnMatches | Where {$_ -like "Salt-Minion*x86-Setup.exe"}
    }
    Else {
        $returnMatches = $returnMatches | Where {$_ -like "Salt-Minion*AMD64-Setup.exe"}
    }

    $version = $($returnMatches[$returnMatches.Count -1]).Split(("n-","-A","-x","-P"),([System.StringSplitOptions]::RemoveEmptyEntries))[1]
}

$versionSection = $version

$year = $version.Substring(0, 4)
If ([int]$year -ge 2017) {
    If ($pythonVersion -eq "3") {
        $versionSection = "$version-Py3"
    }
    Else {
        $versionSection = "$version-Py2"
    }
}

#===============================================================================
# Download minion setup file
#===============================================================================
$saltExe = "Salt-Minion-$versionSection-$arch-Setup.exe"
Write-Output "Downloading Salt minion installer $saltExe"
$webclient = New-Object System.Net.WebClient
$url = "$repourl/$saltExe"
$file = "C:\Windows\Temp\$saltExe"
$webclient.DownloadFile($url, $file)

#===============================================================================
# Set the parameters for the installer
#===============================================================================
# Unless specified, use the installer defaults
# - id: <hostname>
# - master: salt
# - Start the service
$parameters = ""
If($minion -ne "not-specified") {$parameters = "/minion-name=$minion"}
If($master -ne "not-specified") {$parameters = "$parameters /master=$master"}
If($runservice -eq $false) {$parameters = "$parameters /start-service=0"}

#===============================================================================
# Install minion silently
#===============================================================================
#Wait for process to exit before continuing.
Write-Output "Installing Salt minion"
Start-Process C:\Windows\Temp\$saltExe -ArgumentList "/S $parameters" -Wait -NoNewWindow -PassThru | Out-Null

#===============================================================================
# Configure the minion service
#===============================================================================
# Wait for salt-minion service to be registered before trying to start it
$service = Get-Service salt-minion -ErrorAction SilentlyContinue
While (!$service) {
  Start-Sleep -s 2
  $service = Get-Service salt-minion -ErrorAction SilentlyContinue
}

If($runservice) {
    # Start service
    Start-Service -Name "salt-minion" -ErrorAction SilentlyContinue

    # Check if service is started, otherwise retry starting the
    # service 4 times.
    $try = 0
    While (($service.Status -ne "Running") -and ($try -ne 4)) {
        Start-Service -Name "salt-minion" -ErrorAction SilentlyContinue
        $service = Get-Service salt-minion -ErrorAction SilentlyContinue
        Start-Sleep -s 2
        $try += 1
    }

    # If the salt-minion service is still not running, something probably
    # went wrong and user intervention is required - report failure.
    If ($service.Status -eq "Stopped") {
        Write-Output -NoNewline "Failed to start salt minion"
        exit 1
    }
}
Else {
    Write-Output -NoNewline "Stopping salt minion and setting it to 'Manual'"
    Set-Service "salt-minion" -StartupType "Manual"
    Stop-Service "salt-minion"
}

#===============================================================================
# Script Complete
#===============================================================================
Write-Output "Salt minion successfully installed"
