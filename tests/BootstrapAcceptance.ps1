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
$entry = Join-Path $SourceDirectory "main.k"
$moduleRoot = Split-Path -Parent $SourceDirectory

$stage1 = Join-Path $OutputDirectory "stage1"
$stage2 = Join-Path $OutputDirectory "stage2"
$stage3 = Join-Path $OutputDirectory "stage3"
$stage4 = Join-Path $OutputDirectory "stage4"
@($stage1, $stage2, $stage3, $stage4) | ForEach-Object {
    [System.IO.Directory]::CreateDirectory($_) | Out-Null
}

$kc1 = Join-Path $stage1 "kc1.exe"
function Build-Stage {
    param(
        [string]$Compiler,
        [string]$Directory,
        [string]$Name
    )
    $ll = Join-Path $Directory "$Name.ll"
    $exe = Join-Path $Directory "$Name.exe"
    & $Compiler $entry $ll $Opt $Clang $StdRuntime $BootstrapRuntime $exe
    if ($LASTEXITCODE -ne 0) {
        Write-Error "$Compiler failed to build $Name"
    }
    return $exe
}

Push-Location $moduleRoot
try {
    & $Kc0 $entry -o $kc1
    if ($LASTEXITCODE -ne 0) { Write-Error "kc0 failed to build kc1" }
    $kc2 = Build-Stage $kc1 $stage2 "kc2"
    $kc3 = Build-Stage $kc2 $stage3 "kc3"
    $kc4 = Build-Stage $kc3 $stage4 "kc4"
} finally {
    Pop-Location
}

$kc3Ll = Join-Path $stage3 "kc3.ll"
$kc4Ll = Join-Path $stage4 "kc4.ll"
if ((Get-FileHash $kc3Ll -Algorithm SHA256).Hash -cne
    (Get-FileHash $kc4Ll -Algorithm SHA256).Hash) {
    Write-Error "bootstrap fixed point differs between kc3 and kc4"
}

$validFixtures = @(
    "hello.k", "functions.k", "control_flow.k", "aggregates.k",
    "generics.k", "generics_multiple.k", "generic_nullable.k",
    "generic_structs.k", "integer_casts.k", "integer_cast_panic.k",
    "float_casts.k", "float_cast_panic.k", "float_cast_nan_panic.k",
    "float_cast_infinity_panic.k", "float_cast_boundaries.k",
    "short_circuit.k", "loop_control.k"
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
    if ($fixtureName -eq "integer_casts.k" -and $stage1Exit -ne 42) {
        Write-Error "checked integer cast fixture did not return 42"
    }
    if ($fixtureName -eq "integer_cast_panic.k" -and $stage1Exit -ne 2) {
        Write-Error "out-of-range integer cast did not panic with exit code 2"
    }
    if ($fixtureName -eq "float_casts.k" -and $stage1Exit -ne 42) {
        Write-Error "float cast fixture did not return 42"
    }
    if ($fixtureName -eq "float_cast_panic.k" -and $stage1Exit -ne 2) {
        Write-Error "out-of-range float cast did not panic with exit code 2"
    }
    if ($fixtureName -eq "float_cast_nan_panic.k" -and $stage1Exit -ne 2) {
        Write-Error "NaN float cast did not panic with exit code 2"
    }
    if ($fixtureName -eq "float_cast_infinity_panic.k" -and $stage1Exit -ne 2) {
        Write-Error "infinite float cast did not panic with exit code 2"
    }
    if ($fixtureName -eq "float_cast_boundaries.k" -and $stage1Exit -ne 42) {
        Write-Error "float cast boundary fixture did not return 42"
    }
    if ($fixtureName -eq "short_circuit.k" -and $stage1Exit -ne 42) {
        Write-Error "short-circuit fixture evaluated a skipped RHS"
    }
    if ($fixtureName -eq "loop_control.k" -and $stage1Exit -ne 42) {
        Write-Error "nested break/continue fixture returned incorrectly"
    }
    if ($fixtureName -eq "float_cast_boundaries.k") {
        $hashes = @($stage1Ll, $stage2Ll, $stage3Ll, $stage4Ll) |
            ForEach-Object { (Get-FileHash $_ -Algorithm SHA256).Hash }
        if (($hashes | Select-Object -Unique).Count -ne 1) {
            Write-Error "float cast boundary IR differs across bootstrap stages"
        }
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

function Assert-BootstrapExitCode {
    param(
        [string]$Compiler,
        [object[]]$CompilerArguments,
        [int]$Expected,
        [string]$CaseName,
        [string]$ExpectedMessage = ""
    )
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $Compiler @CompilerArguments 2>&1
        $actual = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorAction
    }
    if ($actual -ne $Expected) {
        Write-Error "$Compiler returned $actual for $CaseName; expected $Expected"
    }
    if ($ExpectedMessage.Length -ne 0) {
        $messages = @($output | ForEach-Object { $_.ToString() } |
            Where-Object { $_ -like "*$ExpectedMessage*" })
        if ($messages.Count -ne 1 -or
            [string]$messages[0] -cne $ExpectedMessage) {
            Write-Error "$Compiler did not report the expected message for $CaseName"
        }
    }
}

$cliFixture = Join-Path $FixtureDirectory "hello.k"
$invalidSourceFixture = Join-Path $InvalidFixtureDirectory "bootstrap-semantic-unknown.k"
$missingInput = Join-Path $OutputDirectory "missing-input.k"
$missingTool = Join-Path $OutputDirectory "missing-tool.exe"
$missingRuntime = Join-Path $OutputDirectory "missing-runtime.lib"
$nonKInput = Join-Path $OutputDirectory "input.txt"
foreach ($moduleStage in $moduleStages) {
    $compiler = $moduleStage[0]
    $directory = $moduleStage[1]
    $ll = Join-Path $directory "exit-code.ll"
    $exe = Join-Path $directory "exit-code.exe"
    $validArguments = @(
        $cliFixture, $ll, $Opt, $Clang,
        $StdRuntime, $BootstrapRuntime, $exe)
    Assert-BootstrapExitCode $compiler @() 1 "missing arguments" `
        "error: expected 7 arguments"
    Assert-BootstrapExitCode $compiler ($validArguments + "extra") 1 `
        "extra arguments" "error: expected 7 arguments"
    Assert-BootstrapExitCode $compiler @(
        $nonKInput, $ll, $Opt, $Clang,
        $StdRuntime, $BootstrapRuntime, $exe) 1 "non-K input" `
        "error: input must use .k extension"
    Assert-BootstrapExitCode $compiler @(
        $cliFixture, '""', $Opt, $Clang,
        $StdRuntime, $BootstrapRuntime, $exe) 1 "empty output path" `
        "error: paths must not be empty"
    Assert-BootstrapExitCode $compiler @(
        $missingInput, $ll, $Opt, $Clang,
        $StdRuntime, $BootstrapRuntime, $exe) 1 "missing entry file" `
        "error: cannot load input"
    Assert-BootstrapExitCode $compiler @(
        $cliFixture, (Join-Path $directory "missing/exit.ll"), $Opt, $Clang,
        $StdRuntime, $BootstrapRuntime, $exe) 1 "unwritable output" `
        "error: cannot write LLVM output"
    Assert-BootstrapExitCode $compiler @(
        $cliFixture, $ll, $missingTool, $Clang,
        $StdRuntime, $BootstrapRuntime, $exe) 1 "missing opt executable" `
        "error: cannot launch opt"
    Assert-BootstrapExitCode $compiler @(
        $cliFixture, $ll, $Opt, $missingTool,
        $StdRuntime, $BootstrapRuntime, $exe) 1 "missing clang executable" `
        "error: cannot launch clang"
    Assert-BootstrapExitCode $compiler @(
        $invalidSourceFixture, $ll, $Opt, $Clang,
        $StdRuntime, $BootstrapRuntime, $exe) 2 "source diagnostic"
    Assert-BootstrapExitCode $compiler @(
        $cliFixture, $ll, $Opt, $Clang,
        $missingRuntime, $BootstrapRuntime, $exe) 2 "linker diagnostic"
}

foreach ($moduleFixture in @("diamond", "wildcard", "cycle")) {
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

$semanticModuleEntry = Join-Path $moduleRoot "semantic_error/main.k"
$semanticModulePath = [System.IO.Path]::GetFullPath(
    (Join-Path $moduleRoot "semantic_error/bad.k"))
$semanticExpected = "${semanticModulePath}:3:26: error: unknown identifier"
Push-Location $moduleRoot
try {
    foreach ($moduleStage in $moduleStages) {
        $previousErrorAction = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $diagnostic = & $moduleStage[0] $semanticModuleEntry `
                (Join-Path $moduleStage[1] "module-semantic-error.ll") `
                $Opt $Clang $StdRuntime $BootstrapRuntime `
                (Join-Path $moduleStage[1] "module-semantic-error.exe") 2>&1
            $diagnosticExit = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $previousErrorAction
        }
        if ($diagnosticExit -ne 2) {
            Write-Error "$($moduleStage[0]) returned the wrong module diagnostic exit code"
        }
        if ([string]($diagnostic -join "`n") -notlike "*$semanticExpected*") {
            Write-Error "$($moduleStage[0]) did not map the dependency diagnostic"
        }
    }
} finally {
    Pop-Location
}

$missingModuleEntry = Join-Path $moduleRoot "missing/main.k"
$missingModulePath = [System.IO.Path]::GetFullPath($missingModuleEntry)
$missingExpected = "${missingModulePath}:2:1: error: cannot resolve import"
Push-Location $moduleRoot
try {
    foreach ($moduleStage in $moduleStages) {
        $previousErrorAction = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $diagnostic = & $moduleStage[0] $missingModuleEntry `
                (Join-Path $moduleStage[1] "module-missing.ll") `
                $Opt $Clang $StdRuntime $BootstrapRuntime `
                (Join-Path $moduleStage[1] "module-missing.exe") 2>&1
            $diagnosticExit = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $previousErrorAction
        }
        if ($diagnosticExit -ne 2) {
            Write-Error "$($moduleStage[0]) returned the wrong missing-module exit code"
        }
        if ([string]($diagnostic -join "`n") -notlike "*$missingExpected*") {
            Write-Error "$($moduleStage[0]) did not position the import diagnostic"
        }
    }
} finally {
    Pop-Location
}

$positionedModuleErrors = @(
    @("lexer_error", "bad.k", "3:30: error: unterminated string"),
    @("parser_error", "bad.k", "3:29: error: expected ';'")
)
Push-Location $moduleRoot
try {
    foreach ($positionedCase in $positionedModuleErrors) {
        $positionedEntry = Join-Path $moduleRoot "$($positionedCase[0])/main.k"
        $positionedPath = [System.IO.Path]::GetFullPath(
            (Join-Path $moduleRoot "$($positionedCase[0])/$($positionedCase[1])"))
        $positionedExpected = "${positionedPath}:$($positionedCase[2])"
        foreach ($moduleStage in $moduleStages) {
            $previousErrorAction = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            try {
                $diagnostic = & $moduleStage[0] $positionedEntry `
                    (Join-Path $moduleStage[1] "module-$($positionedCase[0]).ll") `
                    $Opt $Clang $StdRuntime $BootstrapRuntime `
                    (Join-Path $moduleStage[1] "module-$($positionedCase[0]).exe") 2>&1
                $diagnosticExit = $LASTEXITCODE
            } finally {
                $ErrorActionPreference = $previousErrorAction
            }
            if ($diagnosticExit -ne 2 -or
                [string]($diagnostic -join "`n") -notlike "*$positionedExpected*") {
                Write-Error "$($moduleStage[0]) failed positioned $($positionedCase[0]) parity"
            }
        }
    }
} finally {
    Pop-Location
}

$generatedModuleRoot = Join-Path $OutputDirectory "generated-modules"
[System.IO.Directory]::CreateDirectory($generatedModuleRoot) | Out-Null
function Write-DepthFixture {
    param([string]$Name, [int]$LastModule)
    $directory = Join-Path $generatedModuleRoot $Name
    [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    for ($index = 0; $index -le $LastModule; ++$index) {
        $lines = @("module $Name.m$index;")
        if ($index -lt $LastModule) {
            $next = $index + 1
            $lines += "import $Name.m$next.depthFn$next;"
        }
        $lines += ""
        if ($index -eq 0) {
            $lines += "fn main(): i32 { return depthFn1(); }"
        } elseif ($index -lt $LastModule) {
            $next = $index + 1
            $lines += "fn depthFn$index(): i32 { return depthFn$next(); }"
        } else {
            $lines += "fn depthFn$index(): i32 { return 42; }"
        }
        [System.IO.File]::WriteAllText(
            (Join-Path $directory "m$index.k"), ($lines -join "`n"))
    }
}

Write-DepthFixture -Name "depth_ok" -LastModule 64
Write-DepthFixture -Name "depth_fail" -LastModule 65
Push-Location $generatedModuleRoot
try {
    $depthOkEntry = Join-Path $generatedModuleRoot "depth_ok/m0.k"
    foreach ($moduleStage in $moduleStages) {
        $depthLl = Join-Path $moduleStage[1] "module-depth-ok.ll"
        $depthExe = Join-Path $moduleStage[1] "module-depth-ok.exe"
        & $moduleStage[0] $depthOkEntry $depthLl $Opt $Clang `
            $StdRuntime $BootstrapRuntime $depthExe
        if ($LASTEXITCODE -ne 0) { Write-Error "depth-64 boundary was rejected" }
        & $Opt -passes=verify -disable-output $depthLl
        if ($LASTEXITCODE -ne 0) { Write-Error "depth-64 IR failed verification" }
        & $depthExe
        if ($LASTEXITCODE -ne 42) { Write-Error "depth-64 executable returned incorrectly" }
    }

    $depthFailEntry = Join-Path $generatedModuleRoot "depth_fail/m0.k"
    $depthFailPath = [System.IO.Path]::GetFullPath(
        (Join-Path $generatedModuleRoot "depth_fail/m64.k"))
    $depthExpected = "${depthFailPath}:2:1: error: module import depth exceeded"
    foreach ($moduleStage in $moduleStages) {
        $previousErrorAction = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $diagnostic = & $moduleStage[0] $depthFailEntry `
                (Join-Path $moduleStage[1] "module-depth-fail.ll") `
                $Opt $Clang $StdRuntime $BootstrapRuntime `
                (Join-Path $moduleStage[1] "module-depth-fail.exe") 2>&1
            $diagnosticExit = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $previousErrorAction
        }
        if ($diagnosticExit -ne 2 -or
            [string]($diagnostic -join "`n") -notlike "*$depthExpected*") {
            Write-Error "$($moduleStage[0]) failed depth-limit parity"
        }
    }
} finally {
    Pop-Location
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
