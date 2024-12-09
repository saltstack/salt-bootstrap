<#
.SYNOPSIS
    A simple Powershell script to quickly start using Salt.

.DESCRIPTION
    This script will download the latest onedir version of Salt and extract it
    into the same directory where the script is run. The script sets up an
    environment that will allow you to run salt-call commands. To remove, just
    delete the `salt` directory. The environment variables will only be set for
    the current powershell session.

.EXAMPLE
    ./salt-quick-start.ps1

.LINK
    Salt Bootstrap GitHub Project (script home) - https://github.com/saltstack/salt-bootstrap
    Original Vagrant Provisioner Project - https://github.com/saltstack/salty-vagrant
    Vagrant Project (utilizes this script) - https://github.com/mitchellh/vagrant
    Salt Download Location - https://packages.broadcom.com/artifactory/saltproject-generic/windows/
    Salt Manual Install Directions (Windows) - https://docs.saltproject.io/salt/install-guide/en/latest/topics/install-by-operating-system/windows.html
#>

# This is so the -Verbose parameter will work
[CmdletBinding()] param()

function Expand-ZipFile {
    # Extract a zip file
    #
    # Args:
    #     ZipFile (string): The file to extract
    #     Destination (string): The location to extract to
    #
    # Error:
    #     Sets the failed status and exits with a scriptFailed exit code
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ZipFile,

        [Parameter(Mandatory = $true)]
        [string] $Destination
    )

    if (!(Test-Path -Path $Destination)) {
        Write-Debug "Creating missing directory: $Destination"
        New-Item -ItemType directory -Path $Destination
    }
    Write-Debug "Unzipping '$ZipFile' to '$Destination'"
    if ($PSVersionTable.PSVersion.Major -ge 5) {
        # PowerShell 5 introduced Expand-Archive
        Write-Debug "Using Expand-Archive to unzip"
        try{
            Expand-Archive -Path $ZipFile -DestinationPath $Destination -Force
        } catch {
            Write-Debug "Failed to unzip $ZipFile : $_"
            exit 1
        }
    } else {
        # This method will work with older versions of powershell, but it is
        # slow
        Write-Debug "Using Shell.Application to unzip"
        $objShell = New-Object -Com Shell.Application
        $objZip = $objShell.NameSpace($ZipFile)
        try{
            foreach ($item in $objZip.Items()) {
                $objShell.Namespace($Destination).CopyHere($item, 0x14)
            }
        } catch {
            Write-Debug "Failed to unzip $ZipFile : $_"
            exit 1
        }
    }
    Write-Debug "Finished unzipping '$ZipFile' to '$Destination'"
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
# Script settings
#===============================================================================
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]'Tls12'
$global:ProgressPreference = 'SilentlyContinue'

#===============================================================================
# Declare Variables
#===============================================================================
$ApiUrl  = "https://packages.broadcom.com/artifactory/api/storage/saltproject-generic/onedir"
# Detect architecture ($arch)
if ([IntPtr]::Size -eq 4) { $arch = "x86" } else { $arch = "amd64" }

#===============================================================================
# Setting up quickstart environment
#===============================================================================
Write-Host ""
Write-Host "Setting up quickstart environment for Salt" -ForegroundColor Cyan

Write-Verbose "Getting version information from Artifactory"
$response = Invoke-WebRequest $ApiUrl -UseBasicParsing
# Convert the output to a powershell object
$psobj = $response.ToString() | ConvertFrom-Json
$Version = $psobj.children[-1].uri.Trim("/")

Write-Verbose "Getting sha256 hash and download url from Artifactory"
$saltFileName = "salt-$Version-onedir-windows-$arch.zip"
$response = Invoke-WebRequest "$ApiUrl/$Version/$saltFileName" -UseBasicParsing
$psobj = $response.ToString() | ConvertFrom-Json
$saltFileUrl = $psobj.downloadUri
$saltSha256  = $psobj.checksums.sha256

Write-Verbose "URL: $saltFileUrl"
Write-Host "*  INFO: Downloading Salt: " -NoNewline
Invoke-WebRequest -Uri $saltFileUrl -OutFile .\salt.zip
if ( Test-Path -Path .\salt.zip ) {
    Write-Host "Success" -ForegroundColor Green
} else {
    Write-Host "Failed" -ForegroundColor Red
    exit 1
}
$localSha256 = (Get-FileHash -Path .\salt.zip -Algorithm SHA256).Hash
Write-Verbose "Local Hash: $localSha256"
Write-Verbose "Remote Hash: $saltSha256"

Write-Host "*  INFO: Comparing Hash: " -NoNewline
if ( $localSha256 -eq $saltSha256 ) {
    Write-Host "Success" -ForegroundColor Green
} else {
    Write-Host "Failed" -ForegroundColor Red
    exit 1
}

Write-Host "*  INFO: Extracting Salt: " -NoNewline
Expand-ZipFile -ZipFile .\salt.zip -Destination .
if ( Test-Path -Path .\salt\Scripts\python.exe ) {
    Write-Host "Success" -ForegroundColor Green
} else {
    Write-Host "Failed" -ForegroundColor Red
    exit 1
}

Write-Host "*  INFO: Creating Saltfile: " -NoNewline
$PATH = $(Get-Location).Path
$saltfile_contents = @"
salt-call:
  local: True
  config_dir: $PATH\salt\conf
  log_file: $PATH\salt\var\log\salt\minion
  cachedir: $PATH\salt\var\cache\salt
  file_root: $PATH\salt\srv\salt
"@
Set-Content -Path .\salt\Saltfile -Value $saltfile_contents
if ( Test-Path -Path .\salt\Saltfile ) {
    Write-Host "Success" -ForegroundColor Green
} else {
    Write-Host "Failed" -ForegroundColor Red
    exit 1
}

New-Item -Path "$PATH\salt\var\log\salt" -Type Directory -Force | Out-Null
New-Item -Path "$PATH\salt\conf" -Type Directory -Force | Out-Null
New-Item -Path "$PATH\salt\var\cache\salt" -Type Directory -Force | Out-Null
New-Item -Path "$PATH\salt\srv\salt" -Type Directory -Force | Out-Null

Write-Host "*  INFO: Adding Salt to current path: " -NoNewline
$env:Path = "$PATH\salt;$env:PATH"
Write-Verbose $env:Path
if ( $env:PATH -Like "*$PATH\salt*" ) {
    Write-Host "Success" -ForegroundColor Green
} else {
    Write-Host "Failed" -ForegroundColor Red
    exit 1
}
Write-Host "*  INFO:   $PATH\salt"

Write-Host "*  INFO: Setting the SALT_SALTFILE environment variable: "-NoNewline
$env:SALT_SALTFILE="$PATH\salt\Saltfile"
if ( Test-Path -Path $env:SALT_SALTFILE ) {
    Write-Host "Success" -ForegroundColor Green
} else {
    Write-Host "Failed" -ForegroundColor Red
    exit 1
}
Write-Host "*  INFO:   $PATH\salt\Saltfile"

Write-Host ""
Write-Host "You can now run simple salt-call commands" -ForegroundColor Cyan
Write-Host "*  INFO: Create Salt states in $PATH\salt\srv\salt"
Write-Host "*  INFO: Try running salt-call test.ping"
Write-Host ""
