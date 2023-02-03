<#
.SYNOPSIS
    A simple Powershell script to download and install a Salt minion on Windows.

.DESCRIPTION
    The script will download the official Salt package from SaltProject. It will
    install a specific package version and accept parameters for the master and
    minion ids. Finally, it can stop and set the Windows service to "manual" for
    local testing.

.EXAMPLE
    ./bootstrap-salt.ps1
    Runs without any parameters. Uses all the default values/settings.

.EXAMPLE
    ./bootstrap-salt.ps1 -version 2017.7.0
    Specifies a particular version of the installer.

.EXAMPLE
    ./bootstrap-salt.ps1 -pythonVersion 3
    Specifies the Python version of the installer. Can be "2" or "3". Defaults
    to "2". Python 3 installers are only available for Salt 2017.7.0 and newer.
    Starting with Python 3002 only Python 3 installers are available.

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
    URL to the windows packages. Default is "https://repo.saltproject.io/windows"

.NOTES
    All of the parameters are optional. The default should be the latest
    version. The architecture is dynamically determined by the script.

.LINK
    Salt Bootstrap GitHub Project (script home) - https://github.com/saltstack/salt-bootstrap
    Original Vagrant Provisioner Project - https://github.com/saltstack/salty-vagrant
    Vagrant Project (utilizes this script) - https://github.com/mitchellh/vagrant
    Salt Download Location - https://repo.saltproject.io/windows/
#>

#===============================================================================
# Bind Parameters
#===============================================================================
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false, ValueFromPipeline=$True)]
    # Doesn't support versions prior to "YYYY.M.R-B"
    # Supports new version and latest
    # Option 1 means case insensitive
    [ValidatePattern('^(\d{4}(\.\d{1,2}){0,2}(\-\d{1})?)|(latest)$', Options=1)]
    [string]$Version = '',

    [Parameter(Mandatory=$false, ValueFromPipeline=$True)]
    # Doesn't support Python versions prior to "2017.7.0"
    [ValidateSet("2","3")]
    [string]$PythonVersion = "3",

    [Parameter(Mandatory=$false, ValueFromPipeline=$True)]
    [ValidateSet("true","false")]
    [string]$RunService = "true",

    [Parameter(Mandatory=$false, ValueFromPipeline=$True)]
    [string]$Minion = "not-specified",

    [Parameter(Mandatory=$false, ValueFromPipeline=$True)]
    [string]$Master = "not-specified",

    [Parameter(Mandatory=$false, ValueFromPipeline=$True)]
    [string]$RepoUrl= "https://repo.saltproject.io/windows",

    [Parameter(Mandatory=$false, ValueFromPipeline=$True)]
    [switch]$ConfigureOnly
)

# Powershell supports only TLS 1.0 by default. Add support for TLS 1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]'Tls12'

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
if (!(Get-IsAdministrator)) {
    if (Get-IsUacEnabled) {
        # We are not running "as Administrator" - so relaunch as administrator
        # Create a new process object that starts PowerShell
        $newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell";

        # Specify the current script path and name as a parameter`
        $parameters = ""
        foreach ($boundParam in $PSBoundParameters.GetEnumerator())
        {
            $parameters = "$parameters -{0} '{1}'" -f $boundParam.Key, $boundParam.Value
        }
        $newProcess.Arguments = $myInvocation.MyCommand.Definition, $parameters

        # Specify the current working directory
        $newProcess.WorkingDirectory = "$script_path"

        # Indicate that the process should be elevated
        $newProcess.Verb = "runas";

        # Start the new process
        [System.Diagnostics.Process]::Start($newProcess);

        # Exit from the current, unelevated, process
        exit
    }
    else {
        throw "You must be administrator to run this script"
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

if ($runservice.ToLower() -eq "true") {
    Write-Verbose "Windows service will be set to run"
    [bool]$runservice = $True
}
elseif ($runservice.ToLower() -eq "false") {
    Write-Verbose "Windows service will be stopped and set to manual"
    [bool]$runservice = $False
}
else {
    # Param passed in wasn't clear so defaulting to true.
    Write-Verbose "Windows service defaulting to run automatically"
    [bool]$runservice = $True
}

#===============================================================================
# Ensure Directories are present, copy Vagrant Configs if found
#===============================================================================

$ConfiguredAnything = $False

$RootDir = "C:\salt"
$SaltRegKey = "HKLM:\SOFTWARE\Salt Project\Salt"
if (Test-Path -Path $SaltRegKey) {
    if ($null -ne (Get-ItemProperty $SaltRegKey).root_dir) {
        $RootDir = (Get-ItemProperty $SaltRegKey).root_dir
    }
}

$ConfDir = "$RootDir\conf"
$PkiDir = "$ConfDir\pki\minion"
Write-Verbose "ConfDir: $ConfDir"

# Create C:\tmp\
New-Item C:\tmp\ -ItemType directory -Force | Out-Null

#===============================================================================
# Copy Vagrant Files to their proper location.
#===============================================================================

# Vagrant files will be placed in C:\tmp
# Check if minion keys have been uploaded, copy to correct location
if (Test-Path C:\tmp\minion.pem) {
    New-Item $PkiDir -ItemType Directory -Force | Out-Null
    Copy-Item -Path C:\tmp\minion.pem -Destination $PkiDir -Force | Out-Null
    Copy-Item -Path C:\tmp\minion.pub -Destination $PkiDir -Force | Out-Null
    $ConfiguredAnything = $True
}

# Check if minion config has been uploaded
# This should be done before the installer is run so that it can be updated with
# id: and master: settings when the installer runs
if (Test-Path C:\tmp\minion) {
    New-Item $ConfDir -ItemType Directory -Force | Out-Null
    Copy-Item -Path C:\tmp\minion -Destination $ConfDir -Force | Out-Null
    $ConfiguredAnything = $True
}

# Check if grains config has been uploaded
if (Test-Path C:\tmp\grains) {
    New-Item $ConfDir -ItemType Directory -Force | Out-Null
    Copy-Item -Path C:\tmp\grains -Destination $ConfDir -Force | Out-Null
    $ConfiguredAnything = $True
}

if ($ConfigureOnly -and !$ConfiguredAnything) {
    Write-Output "No configuration or keys were copied over. No configuration was done!"
    exit 0
}

#===============================================================================
# Detect architecture
#===============================================================================
if ([IntPtr]::Size -eq 4) {
    $arch = "x86"
} else {
    $arch = "AMD64"
}

#===============================================================================
# Use version "Latest" if no version is passed
#===============================================================================
if ((!$version) -or ($version.ToLower() -eq 'latest')){
    $versionSection = "Latest-Py$PythonVersion"
} else {
    $versionSection = $version
    $year = $version.Substring(0, 4)
    if ([int]$year -ge 2017) {
        if ($PythonVersion -eq "3") {
            $versionSection = "$version-Py3"
        } else {
            $versionSection = "$version-Py2"
        }
    }
}

if (!$ConfigureOnly) {
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
    if($minion -ne "not-specified") {$parameters = "/minion-name=$minion"}
    if($master -ne "not-specified") {$parameters = "$parameters /master=$master"}
    if($runservice -eq $false) {$parameters = "$parameters /start-service=0"}

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
    while (!$service) {
      Start-Sleep -s 2
      $service = Get-Service salt-minion -ErrorAction SilentlyContinue
    }

    if($runservice) {
        # Start service
        Write-Output "Starting the Salt minion service"
        Start-Service -Name "salt-minion" -ErrorAction SilentlyContinue

        # Check if service is started, otherwise retry starting the
        # service 4 times.
        $try = 0
        while (($service.Status -ne "Running") -and ($try -ne 4)) {
            Start-Service -Name "salt-minion" -ErrorAction SilentlyContinue
            $service = Get-Service salt-minion -ErrorAction SilentlyContinue
            Start-Sleep -s 2
            $try += 1
        }

        # If the salt-minion service is still not running, something probably
        # went wrong and user intervention is required - report failure.
        if ($service.Status -eq "Stopped") {
            Write-Output -NoNewline "Failed to start salt minion"
            exit 1
        }
    }
    else {
        Write-Output -NoNewline "Stopping salt minion and setting it to 'Manual'"
        Set-Service "salt-minion" -StartupType "Manual"
        Stop-Service "salt-minion"
    }
}

#===============================================================================
# Script Complete
#===============================================================================
if ($ConfigureOnly) {
    Write-Output "Salt minion successfully configured"
}
else {
    Write-Output "Salt minion successfully installed"
}
