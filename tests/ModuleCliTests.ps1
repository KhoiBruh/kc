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
