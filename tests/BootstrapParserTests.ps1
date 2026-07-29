param(
    [Parameter(Mandatory)]
    [string]$Compiler,

    [Parameter(Mandatory)]
    [string]$AstDump,

    [Parameter(Mandatory)]
    [string]$SourceDirectory,

    [Parameter(Mandatory)]
    [string]$Main,

    [Parameter(Mandatory)]
    [string]$Fixture,

    [Parameter(Mandatory)]
    [string]$SecondFixture,

    [Parameter(Mandatory)]
    [string]$InvalidDirectory,

    [Parameter(Mandatory)]
    [string]$Output
)

$ErrorActionPreference = "Stop"

$combined = "$Output.combined.k"
$modules = @(
    "source.k",
    "token.k",
    "list.k",
    "containers.k",
    "lexer.k",
    "ast.k",
    "parser.k"
)
$source = ($modules | ForEach-Object {
    [System.IO.File]::ReadAllText((Join-Path $SourceDirectory $_))
}) -join "`n"
$source += "`n" + [System.IO.File]::ReadAllText($Main)
[System.IO.File]::WriteAllText($combined, $source)

& $Compiler $combined -o $Output
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$expected = & $AstDump $Fixture
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
$dump = & $Output $Fixture
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
if ($dump -cne $expected) {
    Write-Error "Parser AST mismatch.`nExpected: $expected`nActual:   $dump"
}

$expected = & $AstDump $SecondFixture
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
$dump = & $Output $SecondFixture
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
if ($dump -cne $expected) {
    Write-Error "Parser AST mismatch for second fixture.`nExpected: $expected`nActual:   $dump"
}

$invalidFixtures = @(
    "bootstrap-invalid-byte.k",
    "bootstrap-unterminated-string.k",
    "bootstrap-missing-delimiter.k",
    "bootstrap-missing-semicolon.k",
    "bootstrap-invalid-assignment.k"
)
foreach ($name in $invalidFixtures) {
    $path = Join-Path $InvalidDirectory $name
    $ErrorActionPreference = "Continue"
    $null = & $Compiler --check $path 2>&1
    $compilerExitCode = $LASTEXITCODE
    $ErrorActionPreference = "Stop"
    if ($compilerExitCode -ne 2) {
        Write-Error "C++ frontend accepted malformed fixture $name"
    }
    $diagnostic = & $Output $path
    if ($LASTEXITCODE -ne 2) {
        Write-Error "K frontend accepted malformed fixture $name"
    }
    if ($diagnostic -notmatch "^error:[0-9]+$") {
        Write-Error "K frontend did not produce a positioned diagnostic for $name"
    }
}
