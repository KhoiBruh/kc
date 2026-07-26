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
