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
