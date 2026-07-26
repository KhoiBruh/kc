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

$moduleRoot = Split-Path -Parent $SourceDirectory
$pending = [System.Collections.Generic.Queue[string]]::new()
$pending.Enqueue([System.IO.Path]::GetFullPath((Join-Path $SourceDirectory "main.k")))
$reachable = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase)
while ($pending.Count -ne 0) {
    $path = $pending.Dequeue()
    if ($reachable.Add($path) -eq $false) { continue }
    $text = [System.IO.File]::ReadAllText($path)
    $imports = [regex]::Matches(
        $text,
        '(?m)^\s*import\s+([A-Za-z_][A-Za-z0-9_.]*?)(\.\*)?\s*;')
    foreach ($import in $imports) {
        $parts = @($import.Groups[1].Value.Split('.'))
        if ($import.Groups[2].Success) {
            $relative = Join-Path ($parts -join '/') "mod.k"
        } else {
            if ($parts.Count -lt 2) {
                Write-Error "bootstrap import is missing a module path: $($import.Value)"
            }
            $relative = (($parts[0..($parts.Count - 2)] -join '/') + '.k')
        }
        $dependency = [System.IO.Path]::GetFullPath(
            (Join-Path $moduleRoot $relative))
        if ((Test-Path $dependency -PathType Leaf) -eq $false) {
            Write-Error "bootstrap import is unresolved: $($import.Value)"
        }
        $pending.Enqueue($dependency)
    }
}

foreach ($entry in $actual) {
    $path = [System.IO.Path]::GetFullPath((Join-Path $SourceDirectory $entry))
    if ($reachable.Contains($path) -eq $false) {
        Write-Error "bootstrap manifest module is unreachable from main.k: $entry"
    }
}
