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
    ./bootstrap-salt.ps1 -RunService $false
    Specifies the salt-minion service to stop and be set to manual. Useful for
    testing locally from the command line with the --local switch

.EXAMPLE
    ./bootstrap-salt.ps1 -Minion minion-box -Master master-box
    Specifies the minion and master ids in the minion config. Defaults to the
    installer values of host name for the minion id and "salt" for the master.

.EXAMPLE
    ./bootstrap-salt.ps1 -Minion minion-box -Master master-box -Version 3006.7 -RunService $false
    Specifies all the optional parameters in no particular order.

.NOTES
    All of the parameters are optional. The default should be the latest
    version. The architecture is dynamically determined by the script.

.LINK
    Salt Bootstrap GitHub Project (script home) - https://github.com/saltstack/salt-bootstrap
    Original Vagrant Provisioner Project - https://github.com/saltstack/salty-vagrant
    Vagrant Project (utilizes this script) - https://github.com/mitchellh/vagrant
    Salt Download Location - https://packages.broadcom.com/artifactory/saltproject-generic/windows/
    Salt Manual Install Directions (Windows) - https://docs.saltproject.io/salt/install-guide/en/latest/topics/install-by-operating-system/windows.html
#>

#===============================================================================
# Bind Parameters
#===============================================================================
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false, ValueFromPipeline=$True)]
    [Alias("v")]
    # The version of the Salt minion to install. Default is "latest" which will
    # install the latest version of Salt minion available. Doesn't support
    # versions prior to "YYYY.M.R-B"
    [String]$Version = "latest",

    [Parameter(Mandatory=$false, ValueFromPipeline=$True)]
    [Alias("s")]
    # Boolean flag to start or stop the minion service. $true will start the
    # minion service. $false will stop the minion service and set it to "manual".
    # The installer starts it by default.
    [Bool]$RunService = $true,

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
    # URL to the windows packages. Will look for the installer at the root of
    # the URL/Version. Place a folder for each version of Salt in this directory
    # and place the installer binary for each version in its folder.
    # Default is "https://packages.broadcom.com/artifactory/saltproject-generic/windows/"
    [String]$RepoUrl = "https://packages.broadcom.com/artifactory/saltproject-generic/windows/",

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
    [Switch] $Help,

    [Parameter(Mandatory=$false)]
    [Alias("e")]
    # Displays the Version for this script.
    [Switch] $ScriptVersion
)

# We'll check for help first because it really has no requirements
if ($help) {
    # Get the full script name
    $this_script = & {$myInvocation.ScriptName}
    Get-Help $this_script -Detailed
    exit 0
}

$__ScriptVersion = "2024.12.12"
$ScriptName = $myInvocation.MyCommand.Name

# We'll check for the Version next, because it also has no requirements
if ($ScriptVersion) {
    Write-Host $__ScriptVersion
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

function Get-AvailableVersions {
    # Get available versions from a remote location specified in the Source
    # Parameter
    Write-Verbose "Getting version information from the repo"
    Write-Verbose "base_url: $base_url"

    $available_versions = [System.Collections.ArrayList]@()

    if ( $base_url.StartsWith("http") -or $base_url.StartsWith("ftp") ) {
        # We're dealing with HTTP, HTTPS, or FTP
        $response = Invoke-WebRequest "$base_url" -UseBasicParsing
        try {
            $response = Invoke-WebRequest "$base_url" -UseBasicParsing
        } catch {
            Write-Host "Failed to get version information" -ForegroundColor Red
            exit 1
        }

        if ( $response.StatusCode -ne 200 ) {
            Write-Host "There was an error getting version information" -ForegroundColor Red
            Write-Host "Error: $($response.StatusCode)" -ForegroundColor red
            exit 1
        }

        $response.links | ForEach-Object {
            if ( $_.href.Length -gt 8) {
                Write-Host "The content at this location is unexpected" -ForegroundColor Red
                Write-Host "Should be a list of directories where the name is a version of Salt" -ForegroundColor Red
                exit 1
            }
        }

        # Getting available versions from response
        Write-Verbose "Getting available versions from response"
        $filtered = $response.Links | Where-Object -Property href -NE "../"
        $filtered | Select-Object -Property href | ForEach-Object {
            $available_versions.Add($_.href.Trim("/")) | Out-Null
        }
    } elseif ( $base_url.StartsWith("\\") -or $base_url -match "^[A-Za-z]:\\" ) {
        # We're dealing with a local directory or SMB source
        Get-ChildItem -Path $base_url -Directory | ForEach-Object {
            $available_versions.Add($_.Name) | Out-Null
        }
    } else {
        Write-Host "Unknown Source Type" -ForegroundColor Red
        Write-Host "Must be one of HTTP, HTTPS, FTP, SMB Share, Local Directory" -ForegroundColor Red
        exit 1
    }

    Write-Verbose "Available versions:"
    $available_versions | ForEach-Object {
        Write-Verbose "- $_"
    }

    # Get the latest version, should be the last in the list
    Write-Verbose "Getting latest available version"
    $latest = $available_versions | Select-Object -Last 1
    Write-Verbose "Latest available version: $latest"

    # Create a versions table
    # This will have the latest version available, the latest version available
    # for each major version, and every version available. This makes the
    # version lookup logic easier. The contents of the versions table can be
    # found by running -Verbose
    Write-Verbose "Populating the versions table"
    $versions_table = [ordered]@{"latest"=$latest}
    $available_versions | ForEach-Object {
        $versions_table[$(Get-MajorVersion $_)] = $_
        $versions_table[$_.ToLower()] = $_.ToLower()
    }

    Write-Verbose "Versions Table:"
    $versions_table | Sort-Object Name | Out-String | ForEach-Object {
        Write-Verbose "$_"
    }

    return $versions_table
}

function Get-HashFromArtifactory {
    # This function uses the artifactory API to get the SHA265 Hash for the file
    # If Source is NOT artifactory, the sha will not be checked
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String] $SaltVersion,

        [Parameter(Mandatory=$true)]
        [String] $SaltFileName
    )
    if ( $api_url ) {
        $full_url = "$api_url/$SaltVersion/$SaltFileName"
        Write-Verbose "Querying Artifactory API for hash:"
        Write-Verbose $full_url
        try {
            $response = Invoke-RestMethod $full_url -UseBasicParsing
            return $response.checksums.sha256
        } catch {
            Write-Verbose "Artifactory API Not available or file not"
            Write-Verbose "available at specified location"
            Write-Verbose "Hash will not be checked"
            return ""
        }
        Write-Verbose "No hash found for this file: $SaltFileName"
        Write-Verbose "Hash will not be checked"
        return ""
    }
    Write-Verbose "No artifactory API defined"
    Write-Verbose "Hash will not be checked"
    return ""
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
# Check for older versions
#===============================================================================
$majorVersion = Get-MajorVersion -Version $Version
if ($majorVersion -lt "3006") {
    # This is an older version, use the old URL
    Write-Host "Versions older than 3006 are not available" -ForegroundColor Red
    exit 1
}

#===============================================================================
# Declare variables
#===============================================================================
$ConfDir = "$RootDir\conf"
$PkiDir  = "$ConfDir\pki\minion"

$RootDir = "$env:ProgramData\Salt Project\Salt"
# Check for existing installation where RootDir is stored in the registry
$SaltRegKey = "HKLM:\SOFTWARE\Salt Project\Salt"
if (Test-Path -Path $SaltRegKey) {
    if ($null -ne (Get-ItemProperty $SaltRegKey).root_dir) {
        $RootDir = (Get-ItemProperty $SaltRegKey).root_dir
    }
}

# Get repo and api URLs. An artifactory URL will have "artifactory" in it
$domain, $target = $RepoUrl -split "/artifactory/"
if ( $target ) {
    # Create $base_url and $api_url
    $base_url = "$domain/artifactory/$target"
    $api_url = "$domain/artifactory/api/storage/$target"
} else {
    # This is a non-artifactory url, there is no api
    $base_url = $domain
    $api_url = ""
}

#===============================================================================
# Verify Parameters
#===============================================================================
Write-Verbose "Running Script: $ScriptName"
Write-Verbose "Script Version: $__ScriptVersion"
Write-Verbose "Parameters passed in:"
Write-Verbose "version: $Version"
Write-Verbose "runservice: $RunService"
Write-Verbose "master: $Master"
Write-Verbose "minion: $Minion"
Write-Verbose "repourl: $base_url"
Write-Verbose "apiurl: $api_url"
Write-Verbose "ConfDir: $ConfDir"
Write-Verbose "RootDir: $RootDir"

if ($RunService) {
    Write-Verbose "Windows service will be set to run"
    [bool]$RunService = $True
} else {
    Write-Verbose "Windows service will be stopped and set to manual"
    [bool]$RunService = $False
}

#===============================================================================
# Copy Vagrant Files to their proper location.
#===============================================================================

$ConfiguredAnything = $False

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
if ([IntPtr]::Size -eq 4) { $arch = "x86" } else { $arch = "AMD64" }

#===============================================================================
# Getting version information from the repo
#===============================================================================
$versions = Get-AvailableVersions

#===============================================================================
# Validate passed version
#===============================================================================
Write-Verbose "Looking up version: $Version"
if ( $versions.Contains($Version.ToLower()) ) {
    $Version = $versions[$Version.ToLower()]
    Write-Verbose "Found version: $Version"
} else {
    Write-Host "Version $Version is not available" -ForegroundColor Red
    Write-Host "Available versions are:" -ForegroundColor Yellow
    $versions
    exit 1
}

#===============================================================================
# Get file url and sha256
#===============================================================================
$saltFileName = "Salt-Minion-$Version-Py3-$arch-Setup.exe"
$saltFileUrl = "$base_url/$Version/$saltFileName"
$saltSha256 = Get-HashFromArtifactory -SaltVersion $Version -SaltFileName $saltFileName

#===============================================================================
# Download minion setup file
#===============================================================================
Write-Host "===============================================================================" -ForegroundColor Yellow
Write-Host " Bootstrapping Salt Minion" -ForegroundColor Green
Write-Host " - version: $Version"
Write-Host " - file name: $saltFileName"
Write-Host " - file url : $saltFileUrl"
Write-Host " - file hash: $saltSha256"
Write-Host " - master: $Master"
Write-Host " - minion id: $Minion"
Write-Host " - start service: $RunService"
Write-Host "-------------------------------------------------------------------------------" -ForegroundColor Yellow

$localFile = "$env:TEMP\$saltFileName"

Write-Host "Downloading Installer: " -NoNewline
Write-Verbose ""
Write-Verbose "Salt File URL: $saltFileUrl"
Write-Verbose "Local File: $localFile"

# Remove existing local file
if ( Test-Path -Path $localFile ) { Remove-Item -Path $localFile -Force }

# Download the file
Invoke-WebRequest -Uri $saltFileUrl -OutFile $localFile
if ( Test-Path -Path $localFile ) {
    Write-Host "Success" -ForegroundColor Green
} else {
    Write-Host "Failed" -ForegroundColor Red
    exit 1
}

# Compare the hash if there is a hash to compare
if ( $saltSha256 ) {
    $localSha256 = (Get-FileHash -Path $localFile -Algorithm SHA256).Hash
    Write-Host "Comparing Hash: " -NoNewline
    Write-Verbose ""
    Write-Verbose "Local Hash: $localSha256"
    Write-Verbose "Remote Hash: $saltSha256"
    if ( $localSha256 -eq $saltSha256 ) {
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
Write-Verbose "Waiting for installer to finish"
$process | Wait-Process -Timeout 300 -ErrorAction SilentlyContinue
$process.Refresh()

if ( !$process.HasExited ) {
    Write-Verbose "Installer Timeout"
    Write-Host ""
    Write-Host "Killing hung installer: " -NoNewline
    $process | Stop-Process
    $process.Refresh()
    if ( $process.HasExited ) {
        Write-Host "Success" -ForegroundColor Green
    } else {
        Write-Host "Failed" -ForegroundColor Red
        exit 1
    }
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
        Write-Host "Timeout waiting for the salt-minion service to be installed"
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
    if ( $service.Status -ne "Running" ) {
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
        Write-Host "Success" -ForegroundColor Green
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
