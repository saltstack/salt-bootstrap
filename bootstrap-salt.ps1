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
    The version of the Salt minion to install. Default is "latest" which will
    install the latest version of Salt minion available.

.PARAMETER pythonVersion
    The version of Python the installer should use. Specify either "2" or "3".
    Beginning with Salt 2017.7.0, Salt will run on either Python 2 or Python 3.
    The default is Python 2 if not specified. This parameter only works for Salt

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
    [Alias("v")]
    [String]$Version = "latest",

    [Parameter(Mandatory=$false, ValueFromPipeline=$True)]
    # Python 3 support was added in 2017. Python 2 support was dropped in
    # version 3001. This parameter is ignored for all versions before 2017 and
    # after 3000.
    [ValidateSet("2","3")]
    [Alias("p")]
    [String]$PythonVersion = "3",

    [Parameter(Mandatory=$false, ValueFromPipeline=$True)]
    [ValidateSet("true","false")]
    [Alias("s")]
    [String]$RunService = "true",

    [Parameter(Mandatory=$false, ValueFromPipeline=$True)]
    [Alias("m")]
    [String]$Minion = "not-specified",

    [Parameter(Mandatory=$false, ValueFromPipeline=$True)]
    [Alias("a")]
    [String]$Master = "not-specified",

    [Parameter(Mandatory=$false, ValueFromPipeline=$True)]
    [Alias("r")]
    [String]$RepoUrl = "https://repo.saltproject.io/salt/py3/windows",

    [Parameter(Mandatory=$false, ValueFromPipeline=$True)]
    [Alias("c")]
    [Switch]$ConfigureOnly
)


#===============================================================================
# Script Preferences
#===============================================================================
# Powershell supports only TLS 1.0 by default. Add support for TLS 1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]'Tls12'
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

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

function Get-MajorVersion {
    # Parses a version string and returns the major version
    #
    # Args:
    #     Version (string): The Version to parse
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [String] $Version
    )
    return ( $Version -split "\." )[0]
}

function Convert-PSObjectToHashtable {
    param (
        [Parameter(ValueFromPipeline)]
        $InputObject
    )
    if ($null -eq $InputObject) { return $null }

    $is_enum = $InputObject -is [System.Collections.IEnumerable]
    $not_string = $InputObject -isnot [string]
    if ($is_enum -and $not_string) {
        $collection = @(
            foreach ($object in $InputObject) {
                Convert-PSObjectToHashtable $object
            }
        )

        Write-Host -NoEnumerate $collection
    } elseif ($InputObject -is [PSObject]) {
        $hash = @{}

        foreach ($property in $InputObject.PSObject.Properties) {
            $hash[$property.Name] = Convert-PSObjectToHashtable $property.Value
        }

        $hash
    } else {
        $InputObject
    }
}

function Get-FileHash {
    # Get-FileHash is a built-in cmdlet in powershell 5+ but we need to support
    # powershell 3. This will overwrite the powershell 5 commandlet only for
    # this script. But it will provide the missing cmdlet for powershell 3
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String] $Path,

        [Parameter(Mandatory=$false)]
        [ValidateSet(
                "SHA1",
                "SHA256",
                "SHA384",
                "SHA512",
                # https://serverfault.com/questions/820300/
                # why-isnt-mactripledes-algorithm-output-in-powershell-stable
                "MACTripleDES", # don't use
                "MD5",
                "RIPEMD160",
                IgnoreCase=$true)]
        [String] $Algorithm = "SHA256"
    )

    if ( !(Test-Path $Path) ) {
        Write-Verbose "Invalid path for hashing: $Path"
        return @{}
    }

    if ( (Get-Item -Path $Path) -isnot [System.IO.FileInfo]) {
        Write-Verbose "Not a file for hashing: $Path"
        return @{}
    }

    $Path = Resolve-Path -Path $Path

    Switch ($Algorithm) {
        SHA1 {
            $hasher = [System.Security.Cryptography.SHA1CryptoServiceProvider]::Create()
        }
        SHA256 {
            $hasher = [System.Security.Cryptography.SHA256]::Create()
        }
        SHA384 {
            $hasher = [System.Security.Cryptography.SHA384]::Create()
        }
        SHA512 {
            $hasher = [System.Security.Cryptography.SHA512]::Create()
        }
        MACTripleDES {
            $hasher = [System.Security.Cryptography.MACTripleDES]::Create()
        }
        MD5 {
            $hasher = [System.Security.Cryptography.MD5]::Create()
        }
        RIPEMD160 {
            $hasher = [System.Security.Cryptography.RIPEMD160]::Create()
        }
    }

    Write-Verbose "Hashing using $Algorithm algorithm"
    try {
        $data = [System.IO.File]::OpenRead($Path)
        $hash = $hasher.ComputeHash($data)
        $hash = [System.BitConverter]::ToString($hash) -replace "-",""
        return @{
            Path = $Path;
            Algorithm = $Algorithm.ToUpper();
            Hash = $hash
        }
    } catch {
        Write-Verbose "Error hashing: $Path"
        return @{}
    } finally {
        if ($null -ne $data) {
            $data.Close()
        }
    }
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
# Change RepoUrl for older versions
#===============================================================================
$defaultUrl = "https://repo.saltproject.io/salt/py3/windows"
$oldRepoUrl = "https://repo.saltproject.io/windows"
$majorVersion = Get-MajorVersion -Version $Version
$customUrl = $true
if ( $Version.ToLower() -ne "latest" ) {
    # A specific version has been passed
    # We only want to modify the URL if a custom URL was not passed
    $uri = [Uri]($RepoUrl)
    if ( $uri.AbsoluteUri -eq $defaultUrl ) {
        # No customURL passed, let's check for a pre 3006 version
        $customUrl = $false
        if ( $majorVersion -lt "3006" ) {
            # This is an older version, use the old URL
            $RepoUrl = $oldRepoUrl
        } else {
            # This is a new URL, and a version was passed, let's look in minor
            if ( $Version.ToLower() -ne $majorVersion.ToLower() ) {
                $RepoUrl = "$RepoUrl/minor"
            }
        }
    }
} else {
    if ( $RepoUrl -eq $defaultUrl ) {
        $customUrl = $false
    }
}

#===============================================================================
# Verify Parameters
#===============================================================================
Write-Verbose "Parameters passed in:"
Write-Verbose "version: $Version"
Write-Verbose "runservice: $RunService"
Write-Verbose "master: $Master"
Write-Verbose "minion: $Minion"
Write-Verbose "repourl: $RepoUrl"

if ($RunService.ToLower() -eq "true") {
    Write-Verbose "Windows service will be set to run"
    [bool]$RunService = $True
} elseif ($RunService.ToLower() -eq "false") {
    Write-Verbose "Windows service will be stopped and set to manual"
    [bool]$RunService = $False
} else {
    # Param passed in wasn't clear so defaulting to true.
    Write-Verbose "Windows service defaulting to run automatically"
    [bool]$RunService = $True
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

if ( $ConfigureOnly ) {
    if ( !$ConfiguredAnything ) {
        Write-Host "No configuration or keys were copied over." -ForegroundColor yes
        Write-Host "No configuration was done!" -ForegroundColor Yellow
    } else {
        Write-Host "Salt minion successfully configured" -ForegroundColor Green
    }
    # If we're only configuring, we want to end here
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
# Get file name to download
#===============================================================================
$saltFileName = ""
$saltVersion = ""
$saltSha512= ""
$saltFileUrl = ""
if ( ($customUrl) -or ($majorVersion -lt 3006) ) {
    $saltFileName = "Salt-Minion-$Version-Py3-$arch-Setup.exe"
    $saltVersion = $Version
    $saltFileUrl = "$RepoUrl/$saltFileName"
} else {
    if ( $majorVersion -ge 3006 ) {
        $enc = [System.Text.Encoding]::UTF8
        try {
            $response = Invoke-WebRequest -Uri "$RepoUrl/repo.json" -UseBasicParsing
            if ($response.Content.GetType().Name -eq "Byte[]") {
                $psobj = $enc.GetString($response.Content) | ConvertFrom-Json
            } else {
                $psobj = $response.Content | ConvertFrom-Json
            }
            $hash = Convert-PSObjectToHashtable $psobj
        } catch {
            Write-Verbose "repo.json not found at: $RepoUrl"
            $hash = @{}
        }

        $searchVersion = $Version.ToLower()
        if ( $hash.Contains($searchVersion)) {
            foreach ($item in $hash.($searchVersion).Keys) {
                if ( $item.EndsWith(".exe") ) {
                    if ( $item.Contains($arch) ) {
                        $saltFileName = $hash.($searchVersion).($item).name
                        $saltVersion = $hash.($searchVersion).($item).version
                        $saltSha512 = $hash.($searchVersion).($item).SHA512
                    }
                }
            }
        }
        if ( $saltFileName -and $saltVersion -and $saltSha512 ) {
            if ( $RepoUrl.Contains("minor") ) {
                $saltFileUrl = @($RepoUrl, $saltVersion, $saltFileName) -join "/"
            } else {
                $saltFileUrl = @($RepoUrl, "minor", $saltVersion, $saltFileName) -join "/"
            }
        }
    }
}

#===============================================================================
# Download minion setup file
#===============================================================================
Write-Host "===============================================================================" -ForegroundColor Yellow
Write-Host " Bootstrapping Salt Minion" -ForegroundColor Green
Write-Host " - version: $Version"
Write-Host " - file name: $saltFileName"
Write-Host " - file url: $saltFileUrl"
Write-Host "-------------------------------------------------------------------------------" -ForegroundColor Yellow
Write-Host "Downloading Installer: " -NoNewline
$webclient = New-Object System.Net.WebClient
$localFile = "C:\Windows\Temp\$saltFileName"
$webclient.DownloadFile($saltFileUrl, $localFile)

if ( Test-Path -Path $localFile ) {
    Write-Host "Success" -ForegroundColor Green
} else {
    Write-Host "Failed" -ForegroundColor Red
}

if ( $saltSha512 ) {
    $localSha512 = (Get-FileHash -Path $localFile -Algorithm SHA512).Hash
    Write-Host "Comparing Hash: " -NoNewline
    if ( $localSha512 -eq $saltSha512 ) {
        Write-Host "Success" -ForegroundColor Green
    } else {
        Write-Host "Failed" -ForegroundColor Red
        exit 1
    }
}

#===============================================================================
# Set the parameters for the installer
#===============================================================================
# Unless specified, use the installer defaults
# - id: <hostname>
# - master: salt
# - Start the service
$parameters = ""
if($Minion -ne "not-specified") {$parameters = "/minion-name=$Minion"}
if($Master -ne "not-specified") {$parameters = "$parameters /master=$Master"}
if($RunService -eq $false) {$parameters = "$parameters /start-service=0"}

#===============================================================================
# Install minion silently
#===============================================================================
#Wait for process to exit before continuing.
Write-Host "Installing Salt Minion: " -NoNewline
Start-Process $localFile -ArgumentList "/S $parameters" -Wait -NoNewWindow -PassThru | Out-Null

#===============================================================================
# Configure the minion service
#===============================================================================
# Wait for salt-minion service to be registered before trying to start it
$service = Get-Service salt-minion -ErrorAction SilentlyContinue
while (!$service) {
  Start-Sleep -s 2
  $service = Get-Service salt-minion -ErrorAction SilentlyContinue
}
if ( $service ) {
    Write-Host "Success" -ForegroundColor Green
} else {
    Write-Host "Failed" -ForegroundColor Red
    exit 1
}

if($RunService) {
    # Start service
    Write-Host "Starting Service: " -NoNewline
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
    if ($service.Status -eq "Running") {
        Write-Host "Success" -ForegroundColor Green
    } else {
        Write-Host "Failed" -ForegroundColor Red
        exit 1
    }

} else {
    Write-Host "Setting Service to 'Manual': " -NoNewline
    Set-Service "salt-minion" -StartupType "Manual"
    if ( (Get-Service "salt-minion").StartType -eq "Manual" ) {
        Write-Host "Success" -ForegroundColor Green
    } else {
        Write-Host "Failed" -ForegroundColor Red
        exit 1
    }

    Write-Host "Stopping Service: " -NoNewline
    Stop-Service "salt-minion"
    if ( (Get-Service "salt-minion").Status -eq "Stopped" ) {
        Write-Host "Success" -ForegroundColor Green
    } else {
        Write-Host "Failed" -ForegroundColor Red
        exit 1
    }
}

#===============================================================================
# Script Complete
#===============================================================================
Write-Host "-------------------------------------------------------------------------------" -ForegroundColor Yellow
Write-Host "Salt Minion Installed Successfully" -ForegroundColor Green
Write-Host "===============================================================================" -ForegroundColor Yellow
exit 0
