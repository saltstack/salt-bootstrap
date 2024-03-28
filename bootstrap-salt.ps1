<#
.SYNOPSIS
    A simple Powershell script to download and install a Salt minion on Windows.

.DESCRIPTION
    The script will download the official Salt package from SaltProject. It will
    install a specific package version and accept parameters for the master and
    minion IDs. Finally, it can stop and set the Windows service to "manual" for
    local testing.

.EXAMPLE
    ./bootstrap-salt.ps1
    Runs without any parameters. Uses all the default values/settings. Will
    install the latest version of Salt

.EXAMPLE
    ./bootstrap-salt.ps1 -Version 3006.7
    Specifies a particular version of the installer.

.EXAMPLE
    ./bootstrap-salt.ps1 -RunService false
    Specifies the salt-minion service to stop and be set to manual. Useful for
    testing locally from the command line with the --local switch

.EXAMPLE
    ./bootstrap-salt.ps1 -Minion minion-box -Master master-box
    Specifies the minion and master ids in the minion config. Defaults to the
    installer values of host name for the minion id and "salt" for the master.

.EXAMPLE
    ./bootstrap-salt.ps1 -Minion minion-box -Master master-box -Version 3006.7 -RunService false
    Specifies all the optional parameters in no particular order.

.NOTES
    All of the parameters are optional. The default should be the latest
    version. The architecture is dynamically determined by the script.

.LINK
    Salt Bootstrap GitHub Project (script home) - https://github.com/saltstack/salt-bootstrap
    Original Vagrant Provisioner Project - https://github.com/saltstack/salty-vagrant
    Vagrant Project (utilizes this script) - https://github.com/mitchellh/vagrant
    Salt Download Location - https://repo.saltproject.io/salt/py3/windows
#>

#===============================================================================
# Bind Parameters
#===============================================================================
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false, ValueFromPipeline=$True)]
    [ValidatePattern('^(\d{4}(\.\d{1,2}){0,2}(\-\d{1})?)|(latest)$', Options=1)]
    [Alias("v")]
    # The version of the Salt minion to install. Default is "latest" which will
    # install the latest version of Salt minion available. Doesn't support
    # versions prior to "YYYY.M.R-B"
    [String]$Version = "latest",

    [Parameter(Mandatory=$false, ValueFromPipeline=$True)]
    [ValidateSet("true","false")]
    [Alias("s")]
    # Boolean flag to start or stop the minion service. True will start the
    # minion service. False will stop the minion service and set it to "manual".
    # The installer starts it by default.
    [String]$RunService = "true",

    [Parameter(Mandatory=$false, ValueFromPipeline=$True)]
    [Alias("m")]
    # Name of the minion being installed on this host. Installer defaults to the
    # host name.
    [String]$Minion = "not-specified",

    [Parameter(Mandatory=$false, ValueFromPipeline=$True)]
    [Alias("a")]
    #Name or IP of the master server. Installer defaults to "salt".
    [String]$Master = "not-specified",

    [Parameter(Mandatory=$false, ValueFromPipeline=$True)]
    [Alias("r")]
    # URL to the windows packages. Will look for a file named repo.json at the
    # root of the URL. This file is used to determine the name and location of
    # the installer in the repo. If repo.json is not found, it will look for the
    # file under the minor directory.
    # Default is "https://repo.saltproject.io/salt/py3/windows"
    [String]$RepoUrl = "https://repo.saltproject.io/salt/py3/windows",

    [Parameter(Mandatory=$false, ValueFromPipeline=$True)]
    [Alias("c")]
    # Vagrant only
    # Vagrant files are placed in "C:\tmp". Copies Salt config files from
    # Vagrant (C:\tmp) to Salt config locations and exits. Does not run the
    # installer
    [Switch]$ConfigureOnly,

    [Parameter(Mandatory=$false)]
    [Alias("h")]
    # Displays help for this script.
    [Switch] $Help
)

# We'll check for help first because it really has no requirements
if ($help) {
    # Get the full script name
    $this_script = & {$myInvocation.ScriptName}
    Get-Help $this_script -Detailed
    exit 0
}

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
        Write-Verbose "ERROR: $_"
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
if ( [Uri]($RepoUrl).AbsoluteUri -eq $defaultUrl ) {
    # No customURL passed, let's check for a pre 3006 version
    if ($majorVersion -lt "3006") {
        # This is an older version, use the old URL
        $RepoUrl = $oldRepoUrl
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

# Detect older version of Salt to determing default RootDir
if ($majorVersion -lt 3004) {
    $RootDir = "$env:SystemDrive`:\salt"
} else {
    $RootDir = "$env:ProgramData\Salt Project\Salt"
}

# Check for existing installation where RootDir is stored in the registry
$SaltRegKey = "HKLM:\SOFTWARE\Salt Project\Salt"
if (Test-Path -Path $SaltRegKey) {
    if ($null -ne (Get-ItemProperty $SaltRegKey).root_dir) {
        $RootDir = (Get-ItemProperty $SaltRegKey).root_dir
    }
}

$ConfDir = "$RootDir\conf"
$PkiDir = "$ConfDir\pki\minion"
Write-Verbose "ConfDir: $ConfDir"

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
# Look for a repo.json file
try {
    Write-Verbose "Looking for $RepoUrl/repo.json"
    $response = Invoke-WebRequest "$RepoUrl/repo.json" `
    -DisableKeepAlive `
    -UseBasicParsing `
    -Method Head
    if ( $response.StatusCode -eq "200" ) {
        Write-Verbose "Found $RepoUrl/repo.json"
        # This URL contains a repo.json file, let's use it
        $use_repo_json = $true
    } else {
        Write-Verbose "Did not find $RepoUrl/repo.json"
        # No repo.json file found at the default location
        $use_repo_json = $false
    }
} catch {
    Write-Verbose "There was an error looking up $RepoUrl/repo.json"
    Write-Verbose "ERROR: $_"
    $use_repo_json = $false
}
if ( $use_repo_json ) {
    # We will use the json file to get the name of the installer
    $enc = [System.Text.Encoding]::UTF8
    try {
        Write-Verbose "Downloading $RepoUrl/repo.json"
        $response = Invoke-WebRequest -Uri "$RepoUrl/repo.json" -UseBasicParsing
        if ($response.Content.GetType().Name -eq "Byte[]") {
            $psobj = $enc.GetString($response.Content) | ConvertFrom-Json
        } else {
            $psobj = $response.Content | ConvertFrom-Json
        }
        $hash = Convert-PSObjectToHashtable $psobj
    } catch {
        Write-Verbose "repo.json not found at: $RepoUrl"
        Write-Host "ERROR: $_"
        $hash = @{}
    }

    $searchVersion = $Version.ToLower()
    if ( $hash.Contains($searchVersion)) {
        Write-Verbose "Found $searchVersion in $RepoUrl/repo.json"
        foreach ($item in $hash.($searchVersion).Keys) {
            if ( $item.ToLower().EndsWith(".exe") ) {
                if ( $item.ToLower().Contains($arch.ToLower()) ) {
                    $saltFileName = $hash.($searchVersion).($item).name
                    $saltVersion = $hash.($searchVersion).($item).version
                    $saltSha512 = $hash.($searchVersion).($item).SHA512
                }
            }
        }
    } else {
        try {
            Write-Verbose "Searching for $searchVersion in $RepoUrl/minor/repo.json"
            $response = Invoke-WebRequest -Uri "$RepoUrl/minor/repo.json" -UseBasicParsing
            if ($response.Content.GetType().Name -eq "Byte[]") {
                $psobj = $enc.GetString($response.Content) | ConvertFrom-Json
            } else {
                $psobj = $response.Content | ConvertFrom-Json
            }
            $hash = Convert-PSObjectToHashtable $psobj
        } catch {
            Write-Verbose "repo.json not found at: $RepoUrl/minor/repo.json"
            Write-Verbose "ERROR: $_"
            $hash = @{}
        }
        if ( $hash.Contains($searchVersion)) {
            Write-Verbose "Found $searchVersion in $RepoUrl/minor/repo.json"
            foreach ($item in $hash.($searchVersion).Keys) {
                if ( $item.ToLower().EndsWith(".exe") ) {
                    if ( $item.ToLower().Contains($arch.ToLower()) ) {
                        $saltFileName = $hash.($searchVersion).($item).name
                        $saltVersion = $hash.($searchVersion).($item).version
                        $saltSha512 = $hash.($searchVersion).($item).SHA512
                    }
                }
            }
        } else {
            Write-Verbose "Version not found in $RepoUrl/minor/repo.json"
        }
    }
}

if ( $saltFileName -and $saltVersion -and $saltSha512 ) {
    Write-Verbose "Found Name, Version, and Sha"
} else {
    # We will guess the name of the installer
    Write-Verbose "Failed to get Name, Version, and Sha from repo.json"
    Write-Verbose "We'll try to find the file in standard paths"
    $saltFileName = "Salt-Minion-$Version-Py3-$arch-Setup.exe"
    $saltVersion = $Version
}

Write-Verbose "Creating list of urls using the following:"
Write-Verbose "RepoUrl: $RepoUrl"
Write-Verbose "Version: $saltVersion"
Write-Verbose "File Name: $saltFileName"
$urls = $(@($RepoUrl, $saltVersion, $saltFileName) -join "/"),
        $(@($RepoUrl, "minor", $saltVersion, $saltFileName) -join "/"),
        $(@($RepoUrl, $saltFileName) -join "/"),
        $(@($oldRepoUrl, $saltFileName) -join "/")

$saltFileUrl = $null

foreach ($url in $urls) {
    try {
        Write-Verbose "Looking for installer at: $url"
        $response = Invoke-WebRequest "$url" `
                    -DisableKeepAlive `
                    -UseBasicParsing `
                    -Method Head
        if ( $response.StatusCode -eq "200" ) {
            Write-Verbose "Found installer"
            # This URL contains a repo.json file, let's use it
            $saltFileUrl = $url
            break
        } else {
            Write-Verbose "Installer not found: $url"
        }
    } catch {
        Write-Verbose "ERROR: $url"
    }
}

if ( !$saltFileUrl ) {
    Write-Host "Could not find an installer:"
    Write-Verbose "Here are the urls searched:"
    foreach ($url in $urls) {
        Write-Verbose $url
    }
    exit 1
}


#===============================================================================
# Download minion setup file
#===============================================================================
Write-Host "===============================================================================" -ForegroundColor Yellow
Write-Host " Bootstrapping Salt Minion" -ForegroundColor Green
Write-Host " - version: $Version"
Write-Host " - file name: $saltFileName"
Write-Host " - file url: $saltFileUrl"
Write-Host " - master: $Master"
Write-Host " - minion id: $Minion"
Write-Host " - start service: $RunService"
Write-Host "-------------------------------------------------------------------------------" -ForegroundColor Yellow

$localFile = "$env:TEMP\$saltFileName"

Write-Host "Downloading Installer: " -NoNewline
Write-Verbose ""
Write-Verbose "Salt File URL: $saltFileUrl"
Write-Verbose "Local File: $localFile"

$webclient = New-Object System.Net.WebClient
$webclient.DownloadFile($saltFileUrl, $localFile)

if ( Test-Path -Path $localFile ) {
    Write-Host "Success" -ForegroundColor Green
} else {
    Write-Host "Failed" -ForegroundColor Red
}

if ( $saltSha512 ) {
    $localSha512 = (Get-FileHash -Path $localFile -Algorithm SHA512).Hash
    Write-Host "Comparing Hash: " -NoNewline
    Write-Verbose ""
    Write-Verbose "Local Hash: $localSha512"
    Write-Verbose "Remote Hash: $saltSha512"
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

#===============================================================================
# Install minion silently
#===============================================================================
Write-Host "Installing Salt Minion (5 min timeout): " -NoNewline
Write-Verbose ""
Write-Verbose "Local File: $localFile"
Write-Verbose "Parameters: $parameters"
$process = Start-Process $localFile `
    -WorkingDirectory $(Split-Path $localFile -Parent) `
    -ArgumentList "/S /start-service=0 $parameters" `
    -NoNewWindow -PassThru

# Sometimes the installer hangs... we'll wait 5 minutes and then kill it
Write-Verbose ""
Write-Verbose "Waiting for installer to finish"
$process | Wait-Process -Timeout 300 -ErrorAction SilentlyContinue
$process.Refresh()

if ( !$process.HasExited ) {
    Write-Host "Timedout" -ForegroundColor Yellow
    Write-Host "Killing hung installer: " -NoNewline
    $process | Stop-Process
    $process.Refresh()
    if ( $process.HasExited ) {
        Write-Host "Success" -ForegroundColor Green
    } else {
        Write-Host "Failed" -ForegroundColor Red
        exit 1
    }

    Write-Host "Checking installed service: " -NoNewline
}

# Wait for salt-minion service to be registered to verify successful
# installation
$service = Get-Service salt-minion -ErrorAction SilentlyContinue
$tries = 0
$max_tries = 15 # We'll try for 30 seconds
Write-Verbose "Checking that the service is installed"
while ( ! $service ) {
    # We'll keep trying to get a service object until we're successful, or we
    # reach max_tries
    if ( $tries -le $max_tries ) {
        $service = Get-Service salt-minion -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        $tries += 1
    } else {
        # If the salt-minion service is still not running, something
        # probably went wrong and user intervention is required - report
        # failure.
        Write-Host "Failed" -ForegroundColor Red
        Write-Host "Timed out waiting for the salt-minion service to be installed"
        exit 1
    }
}
# If we get this far, the service was installed, we have a service object
Write-Host "Success" -ForegroundColor Green

#===============================================================================
# Configure the minion service
#===============================================================================
if( $RunService ) {
    # Start the service
    Write-Host "Starting Service: " -NoNewline
    Write-Verbose ""
    $tries = 0
    # We'll try for 2 minutes, sometimes the minion takes that long to start as
    # it compiles python code for the first time
    $max_tries = 60
    while ( $service.Status -ne "Running" ) {
        if ( $service.Status -eq "Stopped" ) {
            Start-Service -Name "salt-minion" -ErrorAction SilentlyContinue
        }
        Start-Sleep -Seconds 2
        Write-Verbose "Checking the service status"
        $service.Refresh()
        if ( $service.Status -eq "Running" ) {
            Write-Host "Success" -ForegroundColor Green
        } else {
            if ( $tries -le $max_tries ) {
                $tries += 1
            } else {
                # If the salt-minion service is still not running, something
                # probably went wrong and user intervention is required - report
                # failure.
                Write-Host "Failed" -ForegroundColor Red
                Write-Host "Timed out waiting for the salt-minion service to start"
                exit 1
            }
        }
    }
} else {
    # Set the service to manual start
    $service.Refresh()
    if ( $service.StartType -ne "Manual" ) {
        Write-Host "Setting Service Start Type to 'Manual': " -NoNewline
        Set-Service "salt-minion" -StartupType "Manual"
        $service.Refresh()
        if ( $service.StartType -eq "Manual" ) {
            Write-Host "Success" -ForegroundColor Green
        } else {
            Write-Host "Failed" -ForegroundColor Red
            exit 1
        }
    }
    # The installer should have installed the service stopped, but we'll make
    # sure it is stopped here
    if ( $service.Status -ne "Stopped" ) {
        Write-Host "Stopping Service: " -NoNewline
        Stop-Service "salt-minion"
        $service.Refresh()
        if ( $service.Status -eq "Stopped" ) {
            Write-Host "Success" -ForegroundColor Green
        } else {
            Write-Host "Failed" -ForegroundColor Red
            exit 1
        }
    }
}

#===============================================================================
# Script Complete
#===============================================================================
Write-Host "-------------------------------------------------------------------------------" -ForegroundColor Yellow
Write-Host "Salt Minion Installed Successfully" -ForegroundColor Green
Write-Host "===============================================================================" -ForegroundColor Yellow
exit 0
