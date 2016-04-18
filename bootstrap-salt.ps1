<#
.SYNOPSIS
A simple Powershell script to download and install a salt minion on windows.

.DESCRIPTION
The script will download the official salt package from saltstack. It will install a specific
package version and accept parameters for the master and minion ids. Finally, it can stop and
set the windows service to "manual" for local testing. 

.EXAMPLE
./bootstrap-salt.ps1 
Runs without any parameters. Uses all the default values/settings.

.EXAMPLE
./bootstrap-salt.ps1 -version 2015.4.1-3
Specifies a particular version of the installer.

.EXAMPLE
./bootstrap-salt.ps1 -runservice false
Specifies the salt-minion service to stop and be set to manual.
Useful for testing locally from the command line with the --local switch

.EXAMPLE
./bootstrap-salt.ps1 -minion minion-box -master master-box
Specifies the minion and master ids in the minion config. 
Defaults to the installer values of "minion" and "master".

.EXAMPLE
./bootstrap-salt.ps1 -minion minion-box -master master-box -version 2015.5.2 -runservice false
Specifies all the optional parameters in no particular order.

.PARAMETER version - Default version defined in this script. 

.PARAMETER runservice - Boolean flag to stop the windows service and set to "manual". 
                        Installer starts it by default. 

.PARAMETER minion - Name of the minion being installed on this host. 
                    Installer defaults to "minion".

.PARAMETER master - Name or IP of the master server the minion. Installer defaults to "master".

.NOTES
All of the parameters are optional. The default should be the latest version. The architecture
is dynamically determined by the script.

.LINK
Bootstrap GitHub Project (script home) - https://github.com/saltstack/salt-windows-bootstrap
Original Vagrant Provisioner Project -https://github.com/saltstack/salty-vagrant
Vagrant Project (utilizes this script) - https://github.com/mitchellh/vagrant
SaltStack Download Location - https://repo.saltstack.com/windows/
#>
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$false,ValueFromPipeline=$true)]
  # Doesn't support versions prior to "YYYY.M.R-B" 
  [ValidatePattern('^(201[0-9]\.[0-9]\.[0-9](\-\d{1})?)$')]
  [string]$version = '',
  
  [Parameter(Mandatory=$false,ValueFromPipeline=$true)] 
  [ValidateSet("true","false")] 
  [string]$runservice = "true",

  [Parameter(Mandatory=$false,ValueFromPipeline=$true)] 
  [string]$minion = "salt-minion",
  
  [Parameter(Mandatory=$false,ValueFromPipeline=$true)] 
  [string]$master = "master"
)

Write-Verbose "Parameters passed in:"
Write-Verbose "version: $version"
Write-Verbose "runservice: $runservice"
Write-Verbose "master: $master"
Write-Verbose "minion: $minion"

If ($runservice.ToLower() -eq "true"){
  Write-Verbose "Windows service will be set to run"
  [bool]$runservice = $True
}
ElseIf ($runservice.ToLower() -eq "false"){
  Write-Verbose "Windows service will be stopped and set to manual"
  [bool]$runservice = $False
}
Else {
  # Param passed in wasn't clear so defaulting to true.
   Write-Verbose "Windows service defaulting to run automatically"
  [bool]$runservice = $True
}

# Create C:\tmp\ - if Vagrant doesn't upload keys and/or config it might not exist
New-Item C:\tmp\ -ItemType directory -force | out-null

# Copy minion keys & config to correct location
New-Item C:\salt\conf\pki\minion\ -ItemType directory -force | out-null

# Check if minion keys have been uploaded
If (Test-Path C:\tmp\minion.pem) {
  cp C:\tmp\minion.pem C:\salt\conf\pki\minion\
  cp C:\tmp\minion.pub C:\salt\conf\pki\minion\
}

# Detect architecture
If ([IntPtr]::Size -eq 4) {
  $arch = "x86"
} Else {
  $arch = "AMD64"
}

# If version isn't supplied, use latest.
if (!$version) {
    # Find latest version of Salt Minion 
    $repo = Invoke-Restmethod 'http://repo.saltstack.com/windows/'
    $regex = "<\s*a\s*[^>]*?href\s*=\s*[`"']*([^`"'>]+)[^>]*?>"
    $returnMatches = new-object System.Collections.ArrayList
    $resultingMatches = [Regex]::Matches($repo, $regex, "IgnoreCase")
    foreach($match in $resultingMatches)
    {
        $cleanedMatch = $match.Groups[1].Value.Trim()
        [void] $returnMatches.Add($cleanedMatch)
    } 
    if ($arch -eq 'x86') {$returnMatches = $returnMatches | Where {$_ -like "Salt-Minion*x86-Setup.exe"}}
    else {$returnMatches = $returnMatches | Where {$_ -like "Salt-Minion*AMD64-Setup.exe"}}
    
    $version = $(($returnMatches | Sort-Object -Descending)[0]).Split('-')[2]
}

# Download minion setup file
Write-Output -NoNewline "Downloading Salt minion installer Salt-Minion-$version-$arch-Setup.exe"
$webclient = New-Object System.Net.WebClient
$url = "https://repo.saltstack.com/windows/Salt-Minion-$version-$arch-Setup.exe"
$file = "C:\tmp\salt.exe"
$webclient.DownloadFile($url, $file)

# Install minion silently
Write-Output -NoNewline "Installing Salt minion"
#Wait for process to exit before continuing.
C:\tmp\salt.exe /S /minion-name=$minion /master=$master | Out-Null


# Check if minion config has been uploaded
If (Test-Path C:\tmp\minion) {
  cp C:\tmp\minion C:\salt\conf\
}

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
  Set-Service "salt-minion" -startupType "Manual"
  Stop-Service "salt-minion"
}

Write-Output "Salt minion successfully installed"