param(
    [Parameter(Mandatory)]
    [string]$Kc0,

    [Parameter(Mandatory)]
    [string]$Opt,

    [Parameter(Mandatory)]
    [string]$Clang,

    [Parameter(Mandatory)]
    [string]$StdRuntime,

    [Parameter(Mandatory)]
    [string]$BootstrapRuntime,

    [Parameter(Mandatory)]
    [string]$SourceDirectory,

    [Parameter(Mandatory)]
    [string]$CasesDirectory,

    [Parameter(Mandatory)]
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'

$moduleRoot = Split-Path -Parent $SourceDirectory
[System.IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$entry = Join-Path $SourceDirectory 'main.k'
$seedDirectory = Join-Path $OutputDirectory 'kc1'
[System.IO.Directory]::CreateDirectory($seedDirectory) | Out-Null
$kc1 = Join-Path $seedDirectory 'kc1.exe'

Push-Location $moduleRoot
try {
    cmd /c "`"$Kc0`" `"$entry`" -o `"$kc1`" > nul 2>&1"
    if ($LASTEXITCODE -ne 0) { Write-Error 'kc0 failed to seed kc1' }
} finally {
    Pop-Location
}

function Invoke-CaseProgram([string]$executable, [string]$outputRoot) {
    $stdoutFile = "$outputRoot.stdout.txt"
    $stderrFile = "$outputRoot.stderr.txt"
    Remove-Item $stdoutFile, $stderrFile -ErrorAction SilentlyContinue
    cmd /c "`"$executable`" > `"$stdoutFile`" 2> `"$stderrFile`""
    $exitCode = $LASTEXITCODE
    $stdout = ''
    $stderr = ''
    if (Test-Path $stdoutFile) {
        $stdout = (Get-Content $stdoutFile -Raw) -replace "`r`n", "`n"
    }
    if (Test-Path $stderrFile) {
        $stderr = (Get-Content $stderrFile -Raw) -replace "`r`n", "`n"
    }
    return @{
        Exit = $exitCode
        Stdout = $stdout
        Stderr = $stderr
    }
}

$fixtures = Get-ChildItem $CasesDirectory -Filter '*.k' | Sort-Object Name
$irLog = Join-Path $OutputDirectory 'ir-hashes.txt'
$report = Join-Path $OutputDirectory 'differential-report.txt'
Remove-Item $irLog, $report -ErrorAction SilentlyContinue
$failures = 0
$total = 0
$results = @()

foreach ($fixture in $fixtures) {
    $name = $fixture.BaseName
    $total++
    $kc0Exe = Join-Path $OutputDirectory "$name-kc0.exe"
    $kc1Executable = Join-Path $OutputDirectory "$name-kc1.exe"
    $kc1Ll = Join-Path $OutputDirectory "$name-kc1.ll"

    Push-Location $moduleRoot
    try {
        cmd /c "`"$Kc0`" `"$($fixture.FullName)`" -o `"$kc0Exe`" > nul 2>&1"
        $kc0Build = $LASTEXITCODE
        cmd /c "`"$kc1`" `"$($fixture.FullName)`" `"$kc1Ll`" `"$Opt`" `"$Clang`" `"$StdRuntime`" `"$BootstrapRuntime`" `"$kc1Executable`" > nul 2>&1"
        $kc1Build = $LASTEXITCODE
    } finally {
        Pop-Location
    }

    if ($kc0Build -ne 0 -or $kc1Build -ne 0) {
        $failures++
        $line = "FAIL $name compile kc0=$kc0Build kc1=$kc1Build"
        $results += $line
        Write-Host $line
        continue
    }

    if (Test-Path $kc1Ll) {
        $hash = (Get-FileHash $kc1Ll -Algorithm SHA256).Hash.Substring(0, 12)
        Add-Content -Path $irLog -Value "$name kc1=$hash"
    }

    $kc0Result = Invoke-CaseProgram $kc0Exe (Join-Path $OutputDirectory "$name-kc0")
    $kc1Result = Invoke-CaseProgram $kc1Executable (Join-Path $OutputDirectory "$name-kc1")

    $mismatch = @()
    if ($kc0Result.Exit -ne $kc1Result.Exit) {
        $mismatch += "exit $($kc0Result.Exit) vs $($kc1Result.Exit)"
    }
    if ($kc0Result.Stdout -cne $kc1Result.Stdout) {
        $mismatch += 'stdout'
    }
    if ($kc0Result.Stderr -cne $kc1Result.Stderr) {
        $mismatch += 'stderr'
    }

    if ($mismatch.Count -gt 0) {
        $failures++
        $line = "FAIL $name run: $($mismatch -join ', ')"
        $results += $line
        Write-Host $line
    } else {
        $results += "PASS $name exit=$($kc0Result.Exit)"
    }
}

$summary = Join-Path $OutputDirectory 'summary.txt'
$head = "total=$total failures=$failures"
$results += $head
$results | Set-Content $summary
Write-Host $head
if ($failures -gt 0) {
    Write-Error "differential harness found $failures divergences (details: $report)"
}
exit $(if ($failures -gt 0) { 1 } else { 0 })
