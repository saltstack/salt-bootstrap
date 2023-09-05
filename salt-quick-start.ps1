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

function Expand-ZipFile {
    # Extract a zip file
    #
    # Used by:
    # - Install-SaltMinion
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
        Write-Host "Creating missing directory: $Destination"
        New-Item -ItemType directory -Path $Destination
    }
    Write-Host "Unzipping '$ZipFile' to '$Destination'"
    if ($PSVersionTable.PSVersion.Major -ge 5) {
        # PowerShell 5 introduced Expand-Archive
        Write-Host "Using Expand-Archive to unzip"
        try{
            Expand-Archive -Path $ZipFile -DestinationPath $Destination -Force
        } catch {
            Write-Host "Failed to unzip $ZipFile : $_"
            exit 1
        }
    } else {
        # This method will work with older versions of powershell, but it is
        # slow
        Write-Host "Using Shell.Application to unzip"
        $objShell = New-Object -Com Shell.Application
        $objZip = $objShell.NameSpace($ZipFile)
        try{
            foreach ($item in $objZip.Items()) {
                $objShell.Namespace($Destination).CopyHere($item, 0x14)
            }
        } catch {
            Write-Host "Failed to unzip $ZipFile : $_"
            exit 1
        }
    }
    Write-Host "Finished unzipping '$ZipFile' to '$Destination'"
}


[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]'Tls12'

$ProgressPreference = 'SilentlyContinue'

$RepoUrl = "https://repo.saltproject.io/salt/py3/onedir"

if ([IntPtr]::Size -eq 4) {
    $arch = "x86"
} else {
    $arch = "amd64"
}
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
    Write-Host "repo.json not found at: $RepoUrl"
    $hash = @{}
}
$searchVersion = "latest"
if ( $hash.Contains($searchVersion)) {
    foreach ($item in $hash.($searchVersion).Keys) {
        if ( $item.EndsWith(".zip") ) {
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

Write-Host "Download Salt"
Invoke-WebRequest -Uri $saltFileUrl -OutFile .\salt.zip

Write-Host "Extracting Salt"
Expand-ZipFile -ZipFile .\salt.zip -Destination .

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

New-Item -Path "$PATH\salt\var\log\salt" -Type Directory -Force | Out-Null
New-Item -Path "$PATH\salt\conf" -Type Directory -Force | Out-Null
New-Item -Path "$PATH\salt\var\cache\salt" -Type Directory -Force | Out-Null
New-Item -Path "$PATH\salt\srv\salt" -Type Directory -Force | Out-Null

Write-Host "Adding $PATH\salt to PATH"
$env:Path = "$PATH\salt;" + $env:Path

$env:SALT_SALTFILE="$PATH\salt\Saltfile"
