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
    [string]$FixtureDirectory,

    [Parameter(Mandatory)]
    [string]$InvalidFixtureDirectory,

    [Parameter(Mandatory)]
    [string]$OutputDirectory
)

$ErrorActionPreference = "Stop"

[System.IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$combined = Join-Path $OutputDirectory "compiler.k"
$modules = @(
    "source.k", "token.k", "containers.k", "lexer.k", "ast.k", "parser.k",
    "types.k", "diagnostic.k", "semantic.k", "llvm_text.k", "compiler.k",
    "main.k"
)
$source = ($modules | ForEach-Object {
    [System.IO.File]::ReadAllText((Join-Path $SourceDirectory $_))
}) -join "`n"
[System.IO.File]::WriteAllText($combined, $source)

$stage1 = Join-Path $OutputDirectory "stage1"
$stage2 = Join-Path $OutputDirectory "stage2"
$stage3 = Join-Path $OutputDirectory "stage3"
@($stage1, $stage2, $stage3) | ForEach-Object {
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

$validFixtures = @(
    "hello.k", "functions.k", "control_flow.k", "aggregates.k",
    "generics.k", "generics_multiple.k", "generic_nullable.k"
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

    $stage1Output = & $stage1Exe
    $stage1Exit = $LASTEXITCODE
    $stage2Output = & $stage2Exe
    $stage2Exit = $LASTEXITCODE
    $stage3Output = & $stage3Exe
    $stage3Exit = $LASTEXITCODE
    if ($stage1Exit -ne $stage2Exit -or
        $stage1Exit -ne $stage3Exit -or
        $stage1Output -cne $stage2Output -or
        $stage1Output -cne $stage3Output) {
        Write-Error "bootstrap stage behavior differs for $fixtureName"
    }
    & $Opt -passes=verify -disable-output $stage1Ll
    if ($LASTEXITCODE -ne 0) { Write-Error "kc1 IR failed verification" }
    & $Opt -passes=verify -disable-output $stage2Ll
    if ($LASTEXITCODE -ne 0) { Write-Error "kc2 IR failed verification" }
    & $Opt -passes=verify -disable-output $stage3Ll
    if ($LASTEXITCODE -ne 0) { Write-Error "kc3 IR failed verification" }
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
    $oneText = [string]($one -join "`n")
    $twoText = [string]($two -join "`n")
    if ($oneExit -ne 2 -or $twoExit -ne 2 -or $oneText -cne $twoText) {
        Write-Error "bootstrap diagnostic parity failed for $fixtureName"
    }
}

if ((Test-Path $kc1) -eq $false -or
    (Test-Path $kc2) -eq $false -or
    (Test-Path $kc3) -eq $false) {
    Write-Error "bootstrap stage artifact is missing"
}

exit 0
