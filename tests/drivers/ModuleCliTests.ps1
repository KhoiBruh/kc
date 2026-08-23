param(
    [Parameter(Mandatory)] [string]$Compiler,
    [Parameter(Mandatory)] [string]$Fixture,
    [Parameter(Mandatory)] [string]$Output
)

$ErrorActionPreference = "Stop"
$moduleRoot = Split-Path -Parent (Split-Path -Parent $Fixture)
Push-Location $moduleRoot
& $Compiler "diamond/main.k" -o $Output
$compileExit = $LASTEXITCODE
Pop-Location
if ($compileExit -ne 0) { Write-Error "module fixture did not compile" }
& $Output
if ($LASTEXITCODE -ne 42) { Write-Error "module fixture returned $LASTEXITCODE" }

Push-Location $moduleRoot
& $Compiler "enum_import/main.k" -o $Output
$enumCompileExit = $LASTEXITCODE
Pop-Location
if ($enumCompileExit -ne 0) { Write-Error "imported enum fixture did not compile" }
& $Output
if ($LASTEXITCODE -ne 42) { Write-Error "imported enum fixture returned $LASTEXITCODE" }

Push-Location $moduleRoot
& $Compiler "flat_visibility/main.k" -o $Output
$flatVisibilityCompileExit = $LASTEXITCODE
Pop-Location
if ($flatVisibilityCompileExit -ne 0) { Write-Error "flat visibility fixture did not compile" }
& $Output
if ($LASTEXITCODE -ne 42) { Write-Error "flat visibility fixture returned $LASTEXITCODE" }

Push-Location $moduleRoot
& $Compiler --emit-llvm "unused_module/main.k" -o "$Output.unused.ll"
$unusedEmitExit = $LASTEXITCODE
Pop-Location
if ($unusedEmitExit -ne 0) { Write-Error "unused module fixture did not emit llvm" }
$unusedIr = Get-Content "$Output.unused.ll" -Raw
if ($unusedIr -notmatch "define i32 @main") { Write-Error "unused module fixture omitted main" }
if ($unusedIr -match "define i32 @someFunc") { Write-Error "unused module fixture compiled unreachable function" }
Remove-Item "$Output.unused.ll"

Push-Location $moduleRoot
& $Compiler "unused_module/main.k" -o $Output
$unusedCompileExit = $LASTEXITCODE
Pop-Location
if ($unusedCompileExit -ne 0) { Write-Error "unused module fixture did not compile" }
& $Output
if ($LASTEXITCODE -ne 1) { Write-Error "unused module fixture returned $LASTEXITCODE" }

Push-Location $moduleRoot
& $Compiler --emit-llvm "wildcard_unused/main.k" -o "$Output.wildcard-unused.ll"
$wildcardUnusedEmitExit = $LASTEXITCODE
Pop-Location
if ($wildcardUnusedEmitExit -ne 0) { Write-Error "unused wildcard fixture did not emit llvm" }
$wildcardUnusedIr = Get-Content "$Output.wildcard-unused.ll" -Raw
if ($wildcardUnusedIr -notmatch "define i32 @main") { Write-Error "unused wildcard fixture omitted main" }
if ($wildcardUnusedIr -match "define i32 @answer") { Write-Error "unused wildcard import compiled the whole module" }
Remove-Item "$Output.wildcard-unused.ll"

Push-Location $moduleRoot
& $Compiler --emit-llvm "wildcard_partial/main.k" -o "$Output.wildcard-partial.ll"
$wildcardPartialEmitExit = $LASTEXITCODE
Pop-Location
if ($wildcardPartialEmitExit -ne 0) { Write-Error "partial wildcard fixture did not emit llvm" }
$wildcardPartialIr = Get-Content "$Output.wildcard-partial.ll" -Raw
if ($wildcardPartialIr -notmatch "define i32 @main") { Write-Error "partial wildcard fixture omitted main" }
if ($wildcardPartialIr -notmatch "define i32 @answer") { Write-Error "partial wildcard fixture omitted referenced function" }
if ($wildcardPartialIr -match "define i32 @helper") { Write-Error "partial wildcard fixture compiled unreferenced function" }
Remove-Item "$Output.wildcard-partial.ll"

Push-Location $moduleRoot
& $Compiler "wildcard_partial/main.k" -o $Output
$wildcardPartialCompileExit = $LASTEXITCODE
Pop-Location
if ($wildcardPartialCompileExit -ne 0) { Write-Error "partial wildcard fixture did not compile" }
& $Output
if ($LASTEXITCODE -ne 42) { Write-Error "partial wildcard fixture returned $LASTEXITCODE" }
