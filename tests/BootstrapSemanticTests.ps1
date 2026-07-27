param(
    [Parameter(Mandatory)]
    [string]$Compiler,

    [Parameter(Mandatory)]
    [string]$SemanticDump,

    [Parameter(Mandatory)]
    [string]$SourceDirectory,

    [Parameter(Mandatory)]
    [string]$Main,

    [Parameter(Mandatory)]
    [string]$FixtureDirectory,

    [Parameter(Mandatory)]
    [string]$Output
)

$ErrorActionPreference = "Stop"

$combined = "$Output.combined.k"
$modules = @(
    "source.k", "token.k", "containers.k", "lexer.k", "ast.k", "parser.k",
    "types.k", "diagnostic.k", "semantic.k"
)
$source = ($modules | ForEach-Object {
    [System.IO.File]::ReadAllText((Join-Path $SourceDirectory $_))
}) -join "`n"
$source += "`n" + [System.IO.File]::ReadAllText($Main)
[System.IO.File]::WriteAllText($combined, $source)

& $Compiler $combined -o $Output
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$valid = Join-Path $FixtureDirectory "bootstrap-semantic-valid.k"
$null = & $Output $valid
if ($LASTEXITCODE -ne 0) {
    Write-Error "K semantic analyzer rejected the valid fixture"
}

$genericValid = Join-Path $FixtureDirectory "bootstrap-semantic-generic-valid.k"
$null = & $Output $genericValid
if ($LASTEXITCODE -ne 0) {
    Write-Error "K semantic analyzer rejected the valid generic fixture"
}

$multipleGenericValid = Join-Path $FixtureDirectory "bootstrap-semantic-generic-multiple-valid.k"
$null = & $Output $multipleGenericValid
if ($LASTEXITCODE -ne 0) {
    Write-Error "K semantic analyzer rejected the valid multiple generic fixture"
}

$cases = @(
    @("bootstrap-semantic-duplicate.k", 1),
    @("bootstrap-semantic-unknown.k", 2),
    @("bootstrap-semantic-arity.k", 3),
    @("bootstrap-semantic-type.k", 4),
    @("bootstrap-semantic-return.k", 5),
    @("bootstrap-semantic-condition.k", 6),
    @("bootstrap-semantic-logical-type.k", 4),
    @("bootstrap-semantic-immutable.k", 7),
    @("bootstrap-semantic-access.k", 8),
    @("bootstrap-semantic-cast-range.k", 4),
    @("bootstrap-semantic-cast-negative.k", 4),
    @("bootstrap-semantic-cast-overflow.k", 4),
    @("bootstrap-semantic-cast-float-range.k", 4),
    @("bootstrap-semantic-cast-float-u8-negative.k", 4),
    @("bootstrap-semantic-cast-float-u32-range.k", 4),
    @("bootstrap-semantic-cast-float-i64-range.k", 4),
    @("bootstrap-semantic-cast-float-u64-range.k", 4),
    @("bootstrap-semantic-generic-multiple-unresolved.k", 4)
)
foreach ($case in $cases) {
    $path = Join-Path $FixtureDirectory $case[0]
    $expected = & $SemanticDump $path
    if ($LASTEXITCODE -ne 2) {
        Write-Error "C++ semantic analyzer accepted $($case[0])"
    }
    $diagnostic = & $Output $path
    if ($LASTEXITCODE -ne 2) {
        Write-Error "K semantic analyzer accepted $($case[0])"
    }
    if ($diagnostic -notmatch "^$($case[1]):[0-9]+:[0-9]+$") {
        Write-Error "Unexpected K diagnostic for $($case[0]): $diagnostic"
    }
    if ($diagnostic -cne $expected) {
        Write-Error "Semantic diagnostic mismatch for $($case[0]). Expected $expected, got $diagnostic"
    }
}
