param(
    [Parameter(Mandatory)]
    [string]$Compiler,

    [Parameter(Mandatory)]
    [string]$TokenDump,

    [Parameter(Mandatory)]
    [string]$SourceModule,

    [Parameter(Mandatory)]
    [string]$Token,

    [Parameter(Mandatory)]
    [string]$Containers,

    [Parameter(Mandatory)]
    [string]$Lexer,

    [Parameter(Mandatory)]
    [string]$Main,

    [Parameter(Mandatory)]
    [string]$Fixture,

    [Parameter(Mandatory)]
    [string]$Output
)

$ErrorActionPreference = "Stop"

$combined = "$Output.combined.k"
$parts = @($SourceModule, $Token, $Containers, $Lexer, $Main)
$source = ($parts | ForEach-Object { [System.IO.File]::ReadAllText($_) }) -join "`n"
[System.IO.File]::WriteAllText($combined, $source)

& $Compiler $combined -o $Output
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$expected = & $TokenDump $Fixture
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$actual = & $Output $Fixture
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

if ($actual -cne $expected) {
    Write-Error "Lexer output mismatch.`nExpected: $expected`nActual:   $actual"
}
