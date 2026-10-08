#Requires -Modules @{ ModuleName = "Pester"; ModuleVersion = "5.0.0" }

# Unit tests for the functions in bootstrap-salt.ps1.
#
# The script runs top to bottom when it is invoked and is distributed as a
# single file, so the functions are loaded by parsing it instead of
# dot-sourcing it. Only top-level functions are loaded (nested ones come along
# with their parent).

BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot "..\..\bootstrap-salt.ps1"
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        (Resolve-Path $scriptPath).Path, [ref]$tokens, [ref]$errors)
    if ( $errors.Count -gt 0 ) { throw "bootstrap-salt.ps1 has syntax errors" }

    $functions = $ast.FindAll(
        { param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] },
        $false)
    foreach ( $function in $functions ) {
        . ([scriptblock]::Create($function.Extent.Text))
    }
}

Describe "Get-MajorVersion" {
    It "returns the major version of <version>" -ForEach @(
        @{ version = "3006.7";  expected = "3006" }
        @{ version = "3008.0";  expected = "3008" }
        @{ version = "3007";    expected = "3007" }
        @{ version = "3009.0rc1"; expected = "3009" }
        @{ version = "latest";  expected = "latest" }
    ) {
        Get-MajorVersion -Version $version | Should -Be $expected
    }
}

Describe "Test-SaltOnedirVersionIsGA" {
    It "treats <version> as GA" -ForEach @(
        @{ version = "3006.24" }
        @{ version = "3007.1" }
        @{ version = "3008.0" }
        @{ version = "3008.1-1" }
    ) {
        Test-SaltOnedirVersionIsGA -Version $version | Should -BeTrue
    }

    It "does not treat <version> as GA" -ForEach @(
        @{ version = "3008.0rc1" }
        @{ version = "3009.0rc2" }
        @{ version = "3008" }
        @{ version = "latest" }
    ) {
        Test-SaltOnedirVersionIsGA -Version $version | Should -BeFalse
    }
}

Describe "Compare-SaltCalVer" {
    It "compares <left> to <right> as <expected>" -ForEach @(
        @{ left = "3008.2";   right = "3008.1";   expected = 1 }
        @{ left = "3008.1";   right = "3008.2";   expected = -1 }
        @{ left = "3008.1";   right = "3008.1";   expected = 0 }
        @{ left = "3007.1";   right = "3008.0";   expected = -1 }
        # Numeric, not lexical: 24 is greater than 3
        @{ left = "3006.24";  right = "3006.3";   expected = 1 }
        # A missing component counts as 0
        @{ left = "3008.1";   right = "3008.1.0"; expected = 0 }
        @{ left = "3008.1.1"; right = "3008.1";   expected = 1 }
        # A -N package release is a repackage of the same version
        @{ left = "3008.1-1"; right = "3008.1";   expected = 1 }
        @{ left = "3008.1-2"; right = "3008.1-1"; expected = 1 }
        @{ left = "3008.2";   right = "3008.1-5"; expected = 1 }
    ) {
        Compare-SaltCalVer -Left $left -Right $right | Should -Be $expected
    }
}

Describe "Get-AvailableVersions" {
    BeforeAll {
        # A local directory is a supported RepoUrl source and needs no network
        $repo = Join-Path $TestDrive "repo"
        foreach ( $name in "3006.24", "3007.5", "3008.1", "3008.2", "3009.0rc1" ) {
            New-Item (Join-Path $repo $name) -ItemType Directory -Force | Out-Null
        }
    }

    BeforeEach {
        $base_url = $repo
        $versions = Get-AvailableVersions
    }

    It "resolves latest to the newest GA release, ignoring prereleases" {
        $versions["latest"] | Should -Be "3008.2"
    }

    It "resolves a major version to the newest GA release in that series" {
        $versions["3006"] | Should -Be "3006.24"
        $versions["3007"] | Should -Be "3007.5"
        $versions["3008"] | Should -Be "3008.2"
    }

    It "does not create a major version entry for a prerelease-only series" {
        $versions.Contains("3009") | Should -BeFalse
    }

    It "keeps every directory available by its exact name" {
        $versions["3009.0rc1"] | Should -Be "3009.0rc1"
        $versions["3008.1"] | Should -Be "3008.1"
    }

    It "treats a -N package release as newer than the same version" {
        New-Item (Join-Path $repo "3008.2-1") -ItemType Directory -Force | Out-Null
        try {
            $base_url = $repo
            $result = Get-AvailableVersions
            $result["latest"] | Should -Be "3008.2-1"
            $result["3008"] | Should -Be "3008.2-1"
        } finally {
            Remove-Item (Join-Path $repo "3008.2-1") -Recurse -Force
        }
    }
}

Describe "Get-HashFromArtifactory" {
    BeforeAll {
        $api_url = "https://example.com/artifactory/api/storage/saltproject-generic/windows"
    }

    It "returns the sha256 reported by the Artifactory API" {
        Mock Invoke-RestMethod { [pscustomobject]@{ checksums = [pscustomobject]@{ sha256 = "abc123" } } }
        Get-HashFromArtifactory -SaltVersion "3008.2" -SaltFileName "Salt-Minion-3008.2-Py3-AMD64-Setup.exe" |
            Should -Be "abc123"
        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
            $Uri -like "*/windows/3008.2/Salt-Minion-3008.2-Py3-AMD64-Setup.exe"
        }
    }

    It "returns an empty string when the API is not available" {
        Mock Invoke-RestMethod { throw "404" }
        Get-HashFromArtifactory -SaltVersion "3008.2" -SaltFileName "x.exe" | Should -Be ""
    }

    It "does not query anything for a non-Artifactory source" {
        Mock Invoke-RestMethod { }
        $api_url = ""
        Get-HashFromArtifactory -SaltVersion "3008.2" -SaltFileName "x.exe" | Should -Be ""
        Should -Invoke Invoke-RestMethod -Times 0
    }
}

Describe "Resolve-PipRequirementsFile" {
    BeforeAll {
        $requirements = Join-Path $TestDrive "requirements.txt"
        Set-Content -Path $requirements -Value "# Salt Extensions", "saltext-foo==1.2.3"
    }

    It "returns the full path of a requirements file" {
        Resolve-PipRequirementsFile -Path $requirements |
            Should -Be (Resolve-Path $requirements).ProviderPath
    }

    It "resolves a relative path" {
        Push-Location $TestDrive
        try {
            Resolve-PipRequirementsFile -Path "./requirements.txt" |
                Should -Be (Resolve-Path $requirements).ProviderPath
        } finally {
            Pop-Location
        }
    }

    It "accepts a file with an index option and a package" {
        $file = Join-Path $TestDrive "index.txt"
        Set-Content -Path $file -Value "--index-url https://pypi.example.com/simple", "saltext-foo"
        { Resolve-PipRequirementsFile -Path $file } | Should -Not -Throw
    }

    It "throws when the file does not exist" {
        { Resolve-PipRequirementsFile -Path (Join-Path $TestDrive "missing.txt") } |
            Should -Throw "*does not exist*"
    }

    It "throws for a directory" {
        { Resolve-PipRequirementsFile -Path $TestDrive } | Should -Throw "*does not exist*"
    }

    It "throws when the file only has comments and blank lines" {
        $file = Join-Path $TestDrive "empty.txt"
        Set-Content -Path $file -Value "# nothing here", "", "   ", "  # still nothing"
        { Resolve-PipRequirementsFile -Path $file } | Should -Throw "*does not list any packages*"
    }
}

Describe "Get-SaltPipPath" {
    BeforeEach {
        $savedW6432 = $env:ProgramW6432
        $savedProgramFiles = $env:ProgramFiles
    }

    AfterEach {
        $env:ProgramW6432 = $savedW6432
        $env:ProgramFiles = $savedProgramFiles
    }

    It "uses the 64-bit Program Files when it is set" {
        $env:ProgramW6432 = Join-Path $TestDrive "Program Files"
        $env:ProgramFiles = Join-Path $TestDrive "Program Files (x86)"
        Get-SaltPipPath | Should -Be (Join-Path $env:ProgramW6432 "Salt Project\Salt\salt-pip.exe")
    }

    It "falls back to Program Files" {
        $env:ProgramW6432 = ""
        $env:ProgramFiles = Join-Path $TestDrive "Program Files"
        Get-SaltPipPath | Should -Be (Join-Path $env:ProgramFiles "Salt Project\Salt\salt-pip.exe")
    }
}

Describe "Install-PipRequirements" {
    BeforeAll {
        $requirements = Join-Path $TestDrive "requirements.txt"
        Set-Content -Path $requirements -Value "saltext-foo==1.2.3"
        $saltPip = Join-Path $TestDrive "salt-pip.exe"
        Set-Content -Path $saltPip -Value ""
        # Always set on Windows. Only needed so the tests also run elsewhere.
        $setSystemRoot = !$env:SystemRoot
        if ( $setSystemRoot ) { $env:SystemRoot = Join-Path $TestDrive "Windows" }
    }

    AfterAll {
        if ( $setSystemRoot ) { $env:SystemRoot = $null }
    }

    It "runs salt-pip install -r" {
        Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }
        Install-PipRequirements -Path $requirements -SaltPip $saltPip | Should -Be 0
        Should -Invoke Start-Process -Times 1 -ParameterFilter {
            $FilePath -eq $saltPip -and
            $ArgumentList -eq "install -r `"$requirements`""
        }
    }

    # "python -m pip" puts the working directory first on sys.path, so running
    # it from the directory of the file would let anyone who can write there
    # run code as administrator
    It "does not run salt-pip from the directory of the requirements file" {
        Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }
        Install-PipRequirements -Path $requirements -SaltPip $saltPip | Out-Null
        Should -Invoke Start-Process -Times 1 -ParameterFilter {
            $WorkingDirectory -eq $env:SystemRoot -and
            $WorkingDirectory -ne (Split-Path $requirements -Parent)
        }
    }

    It "returns the exit code of salt-pip" {
        Mock Start-Process { [pscustomobject]@{ ExitCode = 1 } }
        Install-PipRequirements -Path $requirements -SaltPip $saltPip | Should -Be 1
    }

    It "throws when salt-pip is missing" {
        Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }
        { Install-PipRequirements -Path $requirements -SaltPip (Join-Path $TestDrive "missing.exe") } |
            Should -Throw "*salt-pip was not found*"
        Should -Invoke Start-Process -Times 0
    }
}
