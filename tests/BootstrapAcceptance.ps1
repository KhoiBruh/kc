param(
    [Parameter(Mandatory)]
    [string]$Kc0,

    [Parameter(Mandatory)]
    [string]$Opt,

    [Parameter(Mandatory)]
    [string]$Clang,

    [Parameter(Mandatory)]
    [string]$StdRuntime,

    [Parameter(Mandatory)]
    [string]$BootstrapRuntime,

    [Parameter(Mandatory)]
    [string]$SourceDirectory,

    [Parameter(Mandatory)]
    [string]$Manifest,

    [Parameter(Mandatory)]
    [string]$FixtureDirectory,

    [Parameter(Mandatory)]
    [string]$InvalidFixtureDirectory,

    [Parameter(Mandatory)]
    [string]$OutputDirectory
)

$ErrorActionPreference = "Stop"

[System.IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$combined = Join-Path $OutputDirectory "compiler.k"
$modules = Get-Content $Manifest | Where-Object { $_.Trim().Length -ne 0 }
$source = ($modules | ForEach-Object {
    [System.IO.File]::ReadAllText((Join-Path $SourceDirectory $_))
}) -join "`n"
[System.IO.File]::WriteAllText($combined, $source)

$stage1 = Join-Path $OutputDirectory "stage1"
$stage2 = Join-Path $OutputDirectory "stage2"
$stage3 = Join-Path $OutputDirectory "stage3"
$stage4 = Join-Path $OutputDirectory "stage4"
@($stage1, $stage2, $stage3, $stage4) | ForEach-Object {
    [System.IO.Directory]::CreateDirectory($_) | Out-Null
}

$kc1 = Join-Path $stage1 "kc1.exe"
& $Kc0 $combined -o $kc1
if ($LASTEXITCODE -ne 0) { Write-Error "kc0 failed to build kc1" }
function Build-Stage {
    param(
        [string]$Compiler,
        [string]$Directory,
        [string]$Name
    )
    $ll = Join-Path $Directory "$Name.ll"
    $exe = Join-Path $Directory "$Name.exe"
    & $Compiler $combined $ll $Opt $Clang $StdRuntime $BootstrapRuntime $exe
    if ($LASTEXITCODE -ne 0) {
        Write-Error "$Compiler failed to build $Name"
    }
    return $exe
}

$kc2 = Build-Stage $kc1 $stage2 "kc2"
$kc3 = Build-Stage $kc2 $stage3 "kc3"
$kc4 = Build-Stage $kc3 $stage4 "kc4"

$kc3Ll = Join-Path $stage3 "kc3.ll"
$kc4Ll = Join-Path $stage4 "kc4.ll"
if ((Get-FileHash $kc3Ll -Algorithm SHA256).Hash -cne
    (Get-FileHash $kc4Ll -Algorithm SHA256).Hash) {
    Write-Error "bootstrap fixed point differs between kc3 and kc4"
}

$validFixtures = @(
    "hello.k", "functions.k", "control_flow.k", "aggregates.k",
    "generics.k", "generics_multiple.k", "generic_nullable.k",
    "generic_structs.k"
)
foreach ($fixtureName in $validFixtures) {
    $fixture = Join-Path $FixtureDirectory $fixtureName
    $stage1Ll = Join-Path $stage1 "$fixtureName.ll"
    $stage1Exe = Join-Path $stage1 "$fixtureName.exe"
    & $kc1 $fixture $stage1Ll $Opt $Clang $StdRuntime $BootstrapRuntime $stage1Exe
    if ($LASTEXITCODE -ne 0) { Write-Error "kc1 rejected $fixtureName" }
    $stage2Ll = Join-Path $stage2 "$fixtureName.ll"
    $stage2Exe = Join-Path $stage2 "$fixtureName.exe"
    & $kc2 $fixture $stage2Ll $Opt $Clang $StdRuntime $BootstrapRuntime $stage2Exe
    if ($LASTEXITCODE -ne 0) { Write-Error "kc2 rejected $fixtureName" }
    $stage3Ll = Join-Path $stage3 "$fixtureName.ll"
    $stage3Exe = Join-Path $stage3 "$fixtureName.exe"
    & $kc3 $fixture $stage3Ll $Opt $Clang $StdRuntime $BootstrapRuntime $stage3Exe
    if ($LASTEXITCODE -ne 0) { Write-Error "kc3 rejected $fixtureName" }
    $stage4Ll = Join-Path $stage4 "$fixtureName.ll"
    $stage4Exe = Join-Path $stage4 "$fixtureName.exe"
    & $kc4 $fixture $stage4Ll $Opt $Clang $StdRuntime $BootstrapRuntime $stage4Exe
    if ($LASTEXITCODE -ne 0) { Write-Error "kc4 rejected $fixtureName" }

    $stage1Output = & $stage1Exe
    $stage1Exit = $LASTEXITCODE
    $stage2Output = & $stage2Exe
    $stage2Exit = $LASTEXITCODE
    $stage3Output = & $stage3Exe
    $stage3Exit = $LASTEXITCODE
    $stage4Output = & $stage4Exe
    $stage4Exit = $LASTEXITCODE
    if ($stage1Exit -ne $stage2Exit -or
        $stage1Exit -ne $stage3Exit -or
        $stage1Exit -ne $stage4Exit -or
        $stage1Output -cne $stage2Output -or
        $stage1Output -cne $stage3Output -or
        $stage1Output -cne $stage4Output) {
        Write-Error "bootstrap stage behavior differs for $fixtureName"
    }
    & $Opt -passes=verify -disable-output $stage1Ll
    if ($LASTEXITCODE -ne 0) { Write-Error "kc1 IR failed verification" }
    & $Opt -passes=verify -disable-output $stage2Ll
    if ($LASTEXITCODE -ne 0) { Write-Error "kc2 IR failed verification" }
    & $Opt -passes=verify -disable-output $stage3Ll
    if ($LASTEXITCODE -ne 0) { Write-Error "kc3 IR failed verification" }
    & $Opt -passes=verify -disable-output $stage4Ll
    if ($LASTEXITCODE -ne 0) { Write-Error "kc4 IR failed verification" }
}

$moduleRoot = Join-Path $InvalidFixtureDirectory "modules"
$moduleStages = @(
    @($kc1, $stage1), @($kc2, $stage2),
    @($kc3, $stage3), @($kc4, $stage4)
)
foreach ($moduleFixture in @("diamond", "wildcard")) {
    $moduleEntry = Join-Path $moduleRoot "$moduleFixture/main.k"
    $moduleResults = @()
    Push-Location $moduleRoot
    try {
        foreach ($moduleStage in $moduleStages) {
            $moduleLl = Join-Path $moduleStage[1] "module-$moduleFixture.ll"
            $moduleExe = Join-Path $moduleStage[1] "module-$moduleFixture.exe"
            & $moduleStage[0] $moduleEntry $moduleLl $Opt $Clang `
                $StdRuntime $BootstrapRuntime $moduleExe
            if ($LASTEXITCODE -ne 0) {
                Write-Error "$($moduleStage[0]) rejected module $moduleFixture fixture"
            }
            & $Opt -passes=verify -disable-output $moduleLl
            if ($LASTEXITCODE -ne 0) {
                Write-Error "module $moduleFixture IR failed verification"
            }
            & $moduleExe
            $moduleResults += $LASTEXITCODE
        }
    } finally {
        Pop-Location
    }
    if (($moduleResults | Where-Object { $_ -ne 42 }).Count -ne 0) {
        Write-Error "bootstrap module $moduleFixture behavior differs"
    }
}

$invalidFixtures = @(
    "bootstrap-semantic-duplicate.k",
    "bootstrap-semantic-unknown.k",
    "bootstrap-semantic-arity.k",
    "bootstrap-semantic-type.k",
    "bootstrap-semantic-return.k",
    "bootstrap-semantic-condition.k",
    "bootstrap-semantic-immutable.k",
    "bootstrap-semantic-access.k"
)
foreach ($fixtureName in $invalidFixtures) {
    $fixture = Join-Path $InvalidFixtureDirectory $fixtureName
    $one = & $kc1 $fixture (Join-Path $stage1 "invalid.ll") $Opt $Clang $StdRuntime $BootstrapRuntime (Join-Path $stage1 "invalid.exe")
    $oneExit = $LASTEXITCODE
    $two = & $kc2 $fixture (Join-Path $stage2 "invalid.ll") $Opt $Clang $StdRuntime $BootstrapRuntime (Join-Path $stage2 "invalid.exe")
    $twoExit = $LASTEXITCODE
    $three = & $kc3 $fixture (Join-Path $stage3 "invalid.ll") $Opt $Clang $StdRuntime $BootstrapRuntime (Join-Path $stage3 "invalid.exe")
    $threeExit = $LASTEXITCODE
    $four = & $kc4 $fixture (Join-Path $stage4 "invalid.ll") $Opt $Clang $StdRuntime $BootstrapRuntime (Join-Path $stage4 "invalid.exe")
    $fourExit = $LASTEXITCODE
    $oneText = [string]($one -join "`n")
    $twoText = [string]($two -join "`n")
    $threeText = [string]($three -join "`n")
    $fourText = [string]($four -join "`n")
    if ($oneExit -ne 2 -or $twoExit -ne 2 -or $threeExit -ne 2 -or $fourExit -ne 2 -or
        $oneText -cne $twoText -or $oneText -cne $threeText -or $oneText -cne $fourText) {
        Write-Error "bootstrap diagnostic parity failed for $fixtureName"
    }
}

if ((Test-Path $kc1) -eq $false -or
    (Test-Path $kc2) -eq $false -or
    (Test-Path $kc3) -eq $false -or
    (Test-Path $kc4) -eq $false) {
    Write-Error "bootstrap stage artifact is missing"
}

exit 0
