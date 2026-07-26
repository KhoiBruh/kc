param(
    [Parameter(Mandatory)]
    [string]$Compiler,

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
    [string]$Fixture,

    [Parameter(Mandatory)]
    [string]$FunctionsFixture,

    [Parameter(Mandatory)]
    [string]$ControlFlowFixture,

    [Parameter(Mandatory)]
    [string]$AggregatesFixture,

    [Parameter(Mandatory)]
    [string]$GenericsFixture,

    [Parameter(Mandatory)]
    [string]$MultipleGenericsFixture,

    [Parameter(Mandatory)]
    [string]$GenericNullableFixture,

    [Parameter(Mandatory)]
    [string]$GenericStructsFixture,

    [Parameter(Mandatory)]
    [string]$Output
)

$ErrorActionPreference = "Stop"

$combined = "$Output.combined.k"
$modules = @(
    "source.k", "token.k", "containers.k", "lexer.k", "ast.k", "parser.k",
    "types.k", "diagnostic.k", "semantic.k", "llvm_text.k", "compiler.k",
    "loader.k", "main.k"
)
$source = ($modules | ForEach-Object {
    [System.IO.File]::ReadAllText((Join-Path $SourceDirectory $_))
}) -join "`n"
[System.IO.File]::WriteAllText($combined, $source)

& $Compiler $combined -o $Output
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$ir = "$Output.hello.ll"
$helloExe = "$Output.hello.exe"
& $Output $Fixture $ir $Opt $Clang $StdRuntime $BootstrapRuntime $helloExe
if ($LASTEXITCODE -ne 0) {
    Write-Error "Bootstrap compiler failed to emit LLVM IR"
}
& $Opt -passes=verify -disable-output $ir
if ($LASTEXITCODE -ne 0) {
    Write-Error "Bootstrap compiler emitted invalid LLVM IR"
}
$expectedHelloExe = "$Output.hello.kc0.exe"
& $Compiler $Fixture -o $expectedHelloExe
if ($LASTEXITCODE -ne 0) { Write-Error "kc0 failed to compile hello fixture" }
$expectedHello = & $expectedHelloExe
$expectedHelloExit = $LASTEXITCODE
$actualHello = & $helloExe
if ($LASTEXITCODE -ne $expectedHelloExit -or $actualHello -cne $expectedHello) {
    Write-Error "Hello fixture behavior differs from kc0"
}

$functionsIr = "$Output.functions.ll"
$functionsExe = "$Output.functions.exe"
& $Output $FunctionsFixture $functionsIr $Opt $Clang $StdRuntime $BootstrapRuntime $functionsExe
if ($LASTEXITCODE -ne 0) {
    Write-Error "Bootstrap compiler failed to emit functions LLVM IR"
}
& $Opt -passes=verify -disable-output $functionsIr
if ($LASTEXITCODE -ne 0) {
    Write-Error "Bootstrap compiler emitted invalid functions LLVM IR"
}
& $functionsExe
$actualFunctionsExit = $LASTEXITCODE
$expectedFunctionsExe = "$Output.functions.kc0.exe"
& $Compiler $FunctionsFixture -o $expectedFunctionsExe
if ($LASTEXITCODE -ne 0) { Write-Error "kc0 failed to compile functions fixture" }
& $expectedFunctionsExe
if ($LASTEXITCODE -ne $actualFunctionsExit) {
    Write-Error "Functions fixture behavior differs from kc0"
}

$controlIr = "$Output.control.ll"
$controlExe = "$Output.control.exe"
& $Output $ControlFlowFixture $controlIr $Opt $Clang $StdRuntime $BootstrapRuntime $controlExe
if ($LASTEXITCODE -ne 0) {
    Write-Error "Bootstrap compiler failed to emit control-flow LLVM IR"
}
& $Opt -passes=verify -disable-output $controlIr
if ($LASTEXITCODE -ne 0) {
    Write-Error "Bootstrap compiler emitted invalid control-flow LLVM IR"
}
& $controlExe
$actualControlExit = $LASTEXITCODE
$expectedControlExe = "$Output.control.kc0.exe"
& $Compiler $ControlFlowFixture -o $expectedControlExe
if ($LASTEXITCODE -ne 0) { Write-Error "kc0 failed to compile control-flow fixture" }
& $expectedControlExe
if ($LASTEXITCODE -ne $actualControlExit) {
    Write-Error "Control-flow fixture behavior differs from kc0"
}

$aggregatesIr = "$Output.aggregates.ll"
$aggregatesExe = "$Output.aggregates.exe"
& $Output $AggregatesFixture $aggregatesIr $Opt $Clang $StdRuntime $BootstrapRuntime $aggregatesExe
if ($LASTEXITCODE -ne 0) {
    Write-Error "Bootstrap compiler failed to compile aggregate fixture"
}
& $Opt -passes=verify -disable-output $aggregatesIr
if ($LASTEXITCODE -ne 0) {
    Write-Error "Bootstrap compiler emitted invalid aggregate LLVM IR"
}
& $aggregatesExe
$actualAggregatesExit = $LASTEXITCODE
$expectedAggregatesExe = "$Output.aggregates.kc0.exe"
& $Compiler $AggregatesFixture -o $expectedAggregatesExe
if ($LASTEXITCODE -ne 0) { Write-Error "kc0 failed to compile aggregate fixture" }
& $expectedAggregatesExe
if ($LASTEXITCODE -ne $actualAggregatesExit) {
    Write-Error "Aggregate fixture behavior differs from kc0"
}

$genericsIr = "$Output.generics.ll"
$genericsExe = "$Output.generics.exe"
& $Output $GenericsFixture $genericsIr $Opt $Clang $StdRuntime $BootstrapRuntime $genericsExe
if ($LASTEXITCODE -ne 0) {
    Write-Error "Bootstrap compiler failed to compile generic fixture"
}
& $Opt -passes=verify -disable-output $genericsIr
if ($LASTEXITCODE -ne 0) {
    Write-Error "Bootstrap compiler emitted invalid generic LLVM IR"
}
& $genericsExe
$actualGenericsExit = $LASTEXITCODE
$expectedGenericsExe = "$Output.generics.kc0.exe"
& $Compiler $GenericsFixture -o $expectedGenericsExe
if ($LASTEXITCODE -ne 0) { Write-Error "kc0 failed to compile generic fixture" }
& $expectedGenericsExe
if ($LASTEXITCODE -ne $actualGenericsExit) {
    Write-Error "Generic fixture behavior differs from kc0"
}

$multipleGenericsIr = "$Output.generics-multiple.ll"
$multipleGenericsExe = "$Output.generics-multiple.exe"
& $Output $MultipleGenericsFixture $multipleGenericsIr $Opt $Clang $StdRuntime $BootstrapRuntime $multipleGenericsExe
if ($LASTEXITCODE -ne 0) {
    Write-Error "Bootstrap compiler failed to compile multiple generic fixture"
}
& $Opt -passes=verify -disable-output $multipleGenericsIr
if ($LASTEXITCODE -ne 0) {
    Write-Error "Bootstrap compiler emitted invalid multiple generic LLVM IR"
}
& $multipleGenericsExe
$actualMultipleGenericsExit = $LASTEXITCODE
$expectedMultipleGenericsExe = "$Output.generics-multiple.kc0.exe"
& $Compiler $MultipleGenericsFixture -o $expectedMultipleGenericsExe
if ($LASTEXITCODE -ne 0) {
    Write-Error "kc0 failed to compile multiple generic fixture"
}
& $expectedMultipleGenericsExe
if ($LASTEXITCODE -ne $actualMultipleGenericsExit) {
    Write-Error "Multiple generic fixture behavior differs from kc0"
}

$nullableIr = "$Output.generic-nullable.ll"
$nullableExe = "$Output.generic-nullable.exe"
& $Output $GenericNullableFixture $nullableIr $Opt $Clang $StdRuntime $BootstrapRuntime $nullableExe
if ($LASTEXITCODE -ne 0) {
    Write-Error "Bootstrap compiler failed to compile generic nullable fixture"
}
& $Opt -passes=verify -disable-output $nullableIr
if ($LASTEXITCODE -ne 0) {
    Write-Error "Bootstrap compiler emitted invalid generic nullable LLVM IR"
}
& $nullableExe
$actualNullableExit = $LASTEXITCODE
$expectedNullableExe = "$Output.generic-nullable.kc0.exe"
& $Compiler $GenericNullableFixture -o $expectedNullableExe
if ($LASTEXITCODE -ne 0) { Write-Error "kc0 failed to compile generic nullable fixture" }
& $expectedNullableExe
if ($LASTEXITCODE -ne $actualNullableExit) {
    Write-Error "Generic nullable fixture behavior differs from kc0"
}

$structsIr = "$Output.generic-structs.ll"
$structsExe = "$Output.generic-structs.exe"
& $Output $GenericStructsFixture $structsIr $Opt $Clang $StdRuntime $BootstrapRuntime $structsExe
if ($LASTEXITCODE -ne 0) {
    Write-Error "Bootstrap compiler failed to compile generic structs fixture"
}
& $Opt -passes=verify -disable-output $structsIr
if ($LASTEXITCODE -ne 0) {
    Write-Error "Bootstrap compiler emitted invalid generic structs LLVM IR"
}
& $structsExe
$actualStructsExit = $LASTEXITCODE
$expectedStructsExe = "$Output.generic-structs.kc0.exe"
& $Compiler $GenericStructsFixture -o $expectedStructsExe
if ($LASTEXITCODE -ne 0) { Write-Error "kc0 failed to compile generic structs fixture" }
& $expectedStructsExe
if ($LASTEXITCODE -ne $actualStructsExit) {
    Write-Error "Generic structs fixture behavior differs from kc0"
}
