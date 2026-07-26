param(
    [Parameter(Mandatory)]
    [string]$SourceDirectory,

    [Parameter(Mandatory)]
    [string]$Manifest
)

$ErrorActionPreference = "Stop"

$entries = Get-Content $Manifest | Where-Object { $_.Trim().Length -ne 0 }
if ($entries.Count -eq 0) { Write-Error "bootstrap manifest is empty" }
if (($entries | Select-Object -Unique).Count -ne $entries.Count) {
    Write-Error "bootstrap manifest contains duplicate modules"
}

$expected = Get-ChildItem $SourceDirectory -Filter *.k -File |
    ForEach-Object { $_.Name } |
    Sort-Object
$actual = $entries | ForEach-Object { $_.Trim() } | Sort-Object
if (Compare-Object $expected $actual) {
    Write-Error "bootstrap manifest must list every K source exactly once"
}

foreach ($entry in $actual) {
    if ((Test-Path (Join-Path $SourceDirectory $entry) -PathType Leaf) -eq $false) {
        Write-Error "bootstrap manifest module is missing: $entry"
    }
}
