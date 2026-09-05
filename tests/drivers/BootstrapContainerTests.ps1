param(
    [Parameter(Mandatory)]
    [string]$Compiler,

    [Parameter(Mandatory)]
    [string]$Token,

    [Parameter(Mandatory)]
    [string]$Heap,

    [Parameter(Mandatory)]
    [string]$List,

    [Parameter(Mandatory)]
    [string]$Library,

    [Parameter(Mandatory)]
    [string]$TestSource,

    [Parameter(Mandatory)]
    [string]$Output
)

$ErrorActionPreference = "Stop"

$combined = "$Output.combined.k"
$tokenText = [System.IO.File]::ReadAllText($Token)
$heapText = [System.IO.File]::ReadAllText($Heap)
$listText = [System.IO.File]::ReadAllText($List)
$libraryText = [System.IO.File]::ReadAllText($Library)
$testText = [System.IO.File]::ReadAllText($TestSource)
[System.IO.File]::WriteAllText(
    $combined, $tokenText + "`n" + $heapText + "`n" + $listText + "`n" + $libraryText + "`n" + $testText)

& $Compiler $combined -o $Output
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

& $Output
exit $LASTEXITCODE
