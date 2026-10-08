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

.EXAMPLE
    ./bootstrap-salt.ps1 -PipRequirements C:\salt\extensions.txt
    Installs the PyPI packages (for example Salt Extensions) listed in the
    requirements file into Salt using salt-pip. They are installed after Salt
    and before the salt-minion service is first started.

.NOTES
    All of the parameters are optional. The default should be the latest
    version. The architecture is dynamically determined by the script.

    -RepoUrl accepts an HTTP, HTTPS or FTP URL, an SMB share (\\server\share),
    or a local directory (C:\path). Each Salt version needs its own folder
    containing the installer. FTP logins are anonymous unless credentials are
    in the URL (ftp://user:password@host/path/).

    The installer's SHA256 hash is only verified when RepoUrl is an Artifactory
    URL (it contains "/artifactory/"), because the hash comes from the
    Artifactory API. For any other source, including FTP, SMB shares and local
    directories, the hash is NOT checked. Make sure you trust the source.

    -PipRequirements takes the path to a pip requirements file. Pin versions in
    the file (for example "saltext-foo==1.2.3"). A custom or private package
    index can be set with "--index-url" or "--extra-index-url" lines in the
    file, or with the PIP_INDEX_URL and PIP_EXTRA_INDEX_URL environment
    variables. Prefer those over putting credentials on the command line. The
    contents of the file are never printed by this script. Use absolute paths
    for local packages in the file, and do not leave the file in a location
    others can write to, it is installed as administrator. If a package has to
    be compiled, the build tools it needs must already be installed.

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
    # The version of the Salt minion to install. Use "latest" for the most recent
    # GA (general availability) build at RepoUrl; prerelease directories (for
    # example names containing "rc") are ignored for "latest" and for major-series
    # selection. To install a prerelease build, pass the exact directory name
    # shown at RepoUrl (for example "3008.0rc1"). Alternatively, specify a major
    # version for the latest GA in that series (for example "3006"). Versions
    # older than 3006 are not supported.
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
    # Can be an HTTP, HTTPS or FTP URL, an SMB share, or a local directory.
    # The installer's hash is only verified for Artifactory URLs. For any other
    # source it is not checked.
    [String]$RepoUrl = "https://packages.broadcom.com/artifactory/saltproject-generic/windows/",

    [Parameter(Mandatory=$false, ValueFromPipeline=$True)]
    [Alias("c")]
    # Vagrant only
    # Vagrant files are placed in "C:\tmp". Copies Salt config files from
    # Vagrant (C:\tmp) to Salt config locations and exits. Does not run the
    # installer
    [Switch]$ConfigureOnly,

    [Parameter(Mandatory=$false, ValueFromPipeline=$True)]
    [Alias("p")]
    # Path to a pip requirements file listing PyPI packages (for example Salt
    # Extensions) to install into Salt with salt-pip. They are installed after
    # Salt is installed and before the salt-minion service is first started, so
    # they are available the first time Salt runs. Pin versions in the file
    # (for example "saltext-foo==1.2.3"). A custom or private index can be set
    # with "--index-url" or "--extra-index-url" lines in the file, or with the
    # PIP_INDEX_URL and PIP_EXTRA_INDEX_URL environment variables. The file's
    # contents are never printed. Cannot be combined with -ConfigureOnly.
    [String]$PipRequirements = "",

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

$__ScriptVersion = "2026.10.02"
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

function Test-SaltOnedirVersionIsGA {
    # True if the onedir directory name is a GA CalVer, optionally with a -N
    # package-release suffix (e.g. 3008.1 or 3008.1-1). Prerelease dirs (e.g.
    # 3008.0rc1) are not GA; install those only via exact -Version matching
    # the directory name. A -N suffix is a repackage of the same version, not
    # a prerelease, so it counts as GA and participates in latest/major-series
    # selection via Compare-SaltCalVer.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String] $Version
    )
    return [bool]( $Version -match '^\d+\.\d+(\.\d+)*(-\d+)?$' )
}

function Compare-SaltCalVer {
    # Compare two GA CalVer strings, each optionally carrying a -N
    # package-release suffix (e.g. 3006.24, 3008.1-1). Returns 1 if Left is
    # greater than Right, -1 if less, 0 if equal. The dotted version is
    # compared first; a missing -N suffix is treated as release 0, so
    # 3008.1-1 compares greater than 3008.1.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String] $Left,
        [Parameter(Mandatory=$true)]
        [String] $Right
    )
    function Get-CalVerParts {
        param([String] $Version)
        $release = 0
        $dotted = $Version
        if ( $Version -match '^(.+)-(\d+)$' ) {
            $dotted = $Matches[1]
            $release = [int]$Matches[2]
        }
        return @{
            Dotted  = @( ($dotted -split '\.') | ForEach-Object { [int]$_ } )
            Release = $release
        }
    }
    $left_parts = Get-CalVerParts $Left
    $right_parts = Get-CalVerParts $Right
    $max_len = [Math]::Max($left_parts.Dotted.Count, $right_parts.Dotted.Count)
    for ( $i = 0; $i -lt $max_len; $i++ ) {
        $a = if ( $i -lt $left_parts.Dotted.Count ) { $left_parts.Dotted[$i] } else { 0 }
        $b = if ( $i -lt $right_parts.Dotted.Count ) { $right_parts.Dotted[$i] } else { 0 }
        if ( $a -gt $b ) { return 1 }
        if ( $a -lt $b ) { return -1 }
    }
    if ( $left_parts.Release -gt $right_parts.Release ) { return 1 }
    if ( $left_parts.Release -lt $right_parts.Release ) { return -1 }
    return 0
}

function Get-FtpDirectoryNames {
    # Returns the names of the entries in an FTP directory. Credentials can be
    # given in the URL (ftp://user:password@host/path/); otherwise the login is
    # anonymous.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [String] $Url
    )
    if ( !$Url.EndsWith("/") ) { $Url = "$Url/" }
    $request = [System.Net.FtpWebRequest]::Create($Url)
    $request.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectory
    $response = $request.GetResponse()
    try {
        $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
        while ( $null -ne ($line = $reader.ReadLine()) ) {
            # Some servers return the full path of each entry, keep the name
            $name = ( $line.Trim() -split "/" )[-1]
            if ( $name ) { $name }
        }
    } finally {
        if ( $null -ne $reader ) { $reader.Close() }
        $response.Close()
    }
}

function Get-AvailableVersions {
    # Get available versions from a remote location specified in the Source
    # Parameter
    Write-Verbose "Getting version information from the repo"
    Write-Verbose "base_url: $base_url"

    $available_versions = [System.Collections.ArrayList]@()

    if ( $base_url -match "^ftp://" ) {
        # We're dealing with FTP. Invoke-WebRequest does not support FTP, so
        # list the directory names directly.
        try {
            Get-FtpDirectoryNames $base_url | ForEach-Object {
                # Salt dirs: 3006.24, 3008.0, 3008.0rc1, etc. Skip anything else.
                if ( $_ -match '^\d+\.\d+' ) {
                    $available_versions.Add($_) | Out-Null
                }
            }
        } catch {
            Write-Host "Failed to get version information" -ForegroundColor Red
            Write-Host "Error: $_" -ForegroundColor Red
            exit 1
        }
    } elseif ( $base_url.StartsWith("http") ) {
        # We're dealing with HTTP or HTTPS
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

        # Getting available versions from response (Salt dirs: 3006.24, 3008.0,
        # 3008.0rc1, etc.). Skip non-version links from the index page.
        Write-Verbose "Getting available versions from response"
        $filtered = $response.Links | Where-Object -Property href -NE "../"
        $filtered | ForEach-Object {
            $name = $_.href.Trim("/")
            if ( $name -match '^\d+\.\d+' ) {
                $available_versions.Add($name) | Out-Null
            }
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

    if ( $available_versions.Count -eq 0 ) {
        Write-Host "No version directories found at RepoUrl" -ForegroundColor Red
        Write-Host "base_url: $base_url" -ForegroundColor Red
        exit 1
    }

    Write-Verbose "Available versions:"
    $available_versions | ForEach-Object {
        Write-Verbose "- $_"
    }

    # Create a versions table
    # "latest" and each major-series key (3006, 3007, ...) use the newest GA
    # build only; prerelease dirs still appear under their exact names. Every
    # discovered directory name is also stored lowercased for lookup. The
    # contents of the versions table can be found by running -Verbose
    Write-Verbose "Populating the versions table"
    $versions_table = [ordered]@{}
    $available_versions | ForEach-Object {
        $major_version = $(Get-MajorVersion $_)
        if ( Test-SaltOnedirVersionIsGA $_ ) {
            if ( $versions_table.Keys -contains $major_version ) {
                if ( (Compare-SaltCalVer $_ $versions_table[$major_version]) -gt 0 ) {
                    $versions_table[$major_version] = $_
                }
            } else {
                $versions_table[$major_version] = $_
            }

            if ( $versions_table.Keys -contains "latest" ) {
                if ( (Compare-SaltCalVer $_ $versions_table["latest"]) -gt 0 ) {
                    $versions_table["latest"] = $_
                }
            } else {
                $versions_table["latest"] = $_
            }
        }

        $versions_table[$_.ToLower()] = $_.ToLower()
    }

    Write-Verbose "Versions Table:"
    $versions_table.GetEnumerator() | Sort-Object Name | Out-String | ForEach-Object {
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
                "SHA256",
                "SHA384",
                "SHA512",
                # https://serverfault.com/questions/820300/
                # why-isnt-mactripledes-algorithm-output-in-powershell-stable
                "MACTripleDES", # don't use
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

function Resolve-PipRequirementsFile {
    # Checks the file passed with -PipRequirements and returns its full path.
    # Throws if it is not a file, or lists no packages (pip refuses to run
    # with nothing to install).
    param(
        [Parameter(Mandatory=$true)]
        [String] $Path
    )

    if ( !(Test-Path -LiteralPath $Path -PathType Leaf) ) {
        throw "The requirements file does not exist: $Path"
    }

    $fullPath = (Resolve-Path -LiteralPath $Path).ProviderPath
    $package = Get-Content -LiteralPath $fullPath |
        Where-Object { $_ -notmatch '^\s*(#|$)' } |
        Select-Object -First 1
    if ( !$package ) {
        throw "The requirements file does not list any packages: $fullPath"
    }

    return $fullPath
}

function Get-SaltPipPath {
    # Returns the default location of salt-pip.exe. ProgramW6432 is the 64-bit
    # Program Files even when this runs in a 32-bit PowerShell.
    if ( $env:ProgramW6432 ) {
        $programFiles = $env:ProgramW6432
    } else {
        $programFiles = $env:ProgramFiles
    }
    return Join-Path $programFiles "Salt Project\Salt\salt-pip.exe"
}

function Install-PipRequirements {
    # Installs the packages in a requirements file with salt-pip and returns its
    # exit code. Throws if salt-pip is missing.
    #
    # It runs from the Windows directory, not the file's directory:
    # "python -m pip" puts the working directory at the front of sys.path, so a
    # directory others can write to would let them run code as administrator by
    # planting a module there. Nested -r files still resolve against the
    # requirements file, but local package paths in it need to be absolute.
    param(
        [Parameter(Mandatory=$true)]
        [String] $Path,

        [Parameter(Mandatory=$false)]
        [String] $SaltPip = ""
    )

    if ( !$SaltPip ) { $SaltPip = Get-SaltPipPath }
    if ( !(Test-Path -LiteralPath $SaltPip) ) {
        throw "salt-pip was not found at: $SaltPip"
    }

    Write-Verbose "salt-pip: $SaltPip"
    Write-Verbose "Requirements file: $Path"
    $process = Start-Process $SaltPip `
        -WorkingDirectory $env:SystemRoot `
        -ArgumentList "install -r `"$Path`"" `
        -NoNewWindow -Wait -PassThru
    return $process.ExitCode
}

#===============================================================================
# Validate the pip requirements file
#===============================================================================
# This is done before the elevation check below so a relative path is resolved
# from where the script was started. The elevated copy of the script starts in
# a different directory.
if ( $PipRequirements ) {
    if ( $ConfigureOnly ) {
        Write-Host "-PipRequirements cannot be used with -ConfigureOnly, no Salt is installed" -ForegroundColor Red
        exit 1
    }
    try {
        $PipRequirements = Resolve-PipRequirementsFile -Path $PipRequirements
    } catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
    # Hand the resolved path to the elevated copy of the script
    $PSBoundParameters["PipRequirements"] = $PipRequirements
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
$RootDir = "$env:ProgramData\Salt Project\Salt"
# Check for existing installation where RootDir is stored in the registry
$SaltRegKey = "HKLM:\SOFTWARE\Salt Project\Salt"
if (Test-Path -Path $SaltRegKey) {
    if ($null -ne (Get-ItemProperty $SaltRegKey).root_dir) {
        $RootDir = (Get-ItemProperty $SaltRegKey).root_dir
    }
}

# These depend on RootDir, so they must be set after it is final
$ConfDir = "$RootDir\conf"
$PkiDir  = "$ConfDir\pki\minion"

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
Write-Verbose "PipRequirements: $PipRequirements"

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
        Write-Host "No configuration or keys were copied over." -ForegroundColor Yellow
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
# A local directory or SMB share is copied, not downloaded; Invoke-WebRequest
# only handles http(s). Matches the source types in Get-AvailableVersions.
$isLocalSource = $base_url.StartsWith("\\") -or $base_url -match "^[A-Za-z]:\\"
if ( $isLocalSource ) {
    $saltFileUrl = Join-Path (Join-Path $base_url $Version) $saltFileName
} else {
    # RepoUrl usually ends in "/", avoid a double slash in the file URL
    $saltFileUrl = "$($base_url.TrimEnd('/'))/$Version/$saltFileName"
}
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

# Download (or copy, for a local/SMB source) the file
if ( $isLocalSource ) {
    if ( !(Test-Path -Path $saltFileUrl) ) {
        Write-Host "Failed" -ForegroundColor Red
        Write-Host "Installer not found: $saltFileUrl" -ForegroundColor Red
        exit 1
    }
    Copy-Item -Path $saltFileUrl -Destination $localFile -Force
} else {
    if ( $saltFileUrl -match "^ftp://" ) {
        # Invoke-WebRequest does not support FTP, WebClient does
        (New-Object System.Net.WebClient).DownloadFile($saltFileUrl, $localFile)
    } else {
        Invoke-WebRequest -Uri $saltFileUrl -OutFile $localFile
    }
}
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
# Install PyPI packages (for example Salt Extensions)
#===============================================================================
# The installer ran with /start-service=0, so the service has not started yet.
# Installing here means the packages are in place the first time Salt runs.
if ( $PipRequirements ) {
    Write-Host "Installing Python packages from the requirements file:"
    try {
        $pipExitCode = Install-PipRequirements -Path $PipRequirements
    } catch {
        Write-Host "Failed" -ForegroundColor Red
        Write-Host $_.Exception.Message
        exit 1
    }
    if ( $pipExitCode -ne 0 ) {
        Write-Host "Failed" -ForegroundColor Red
        Write-Host "salt-pip exited with code $pipExitCode"
        Write-Host "If a package has to be compiled, its build tools must already be installed"
        exit 1
    }
    Write-Host "Success" -ForegroundColor Green
}

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
