# Benchmark harness: compares cold + warm install times for npm, pnpm, and bun
# on the same package.json fixture. Captures install time, node_modules size,
# and lockfile size. Writes Markdown results to benchmarks/results.md.

# Note: do NOT set $ErrorActionPreference='Stop'. npm/pnpm .ps1 shims emit
# warnings on stderr which PowerShell wraps as ErrorRecords; with EAP=Stop
# the harness would die on benign output.
$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $MyInvocation.MyCommand.Definition
$fixture = Join-Path $root "package.json"
$bun = "$env:USERPROFILE\.bun\bin\bun.exe"

if (-not (Test-Path $bun)) { throw "bun not found at $bun" }

function Get-DirSize($path) {
  if (-not (Test-Path $path)) { return 0 }
  $sum = (Get-ChildItem -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue |
          Measure-Object -Property Length -Sum).Sum
  if ($null -eq $sum) { return 0 }
  return [math]::Round($sum / 1MB, 2)
}

function Get-FileKB($path) {
  if (-not (Test-Path $path)) { return 0 }
  return [math]::Round((Get-Item -LiteralPath $path).Length / 1KB, 2)
}

function Reset-Dir($dir) {
  if (Test-Path $dir) { Remove-Item -LiteralPath $dir -Recurse -Force }
  New-Item -ItemType Directory -Path $dir | Out-Null
  Copy-Item $fixture (Join-Path $dir "package.json")
}

function Run-Install($name, $dir, $cmd, $coldArgs, $warmArgs, $lockfile) {
  Write-Host "`n=== $name ===" -ForegroundColor Cyan
  Reset-Dir $dir
  Push-Location $dir
  try {
    Write-Host "[$name] cold install (no cache, no lockfile)..."
    # Silence all streams from cache-clean — warnings are not actionable here
    if ($name -eq "npm")       { cmd /c "npm cache clean --force > NUL 2>&1" }
    elseif ($name -eq "pnpm")  { cmd /c "pnpm store prune > NUL 2>&1" }
    elseif ($name -eq "bun")   { cmd /c "`"$bun`" pm cache rm > NUL 2>&1" }

    $coldTime = (Measure-Command { & $cmd @coldArgs *> $null }).TotalSeconds
    $coldSize = Get-DirSize (Join-Path $dir "node_modules")
    $lockKB   = Get-FileKB (Join-Path $dir $lockfile)

    Write-Host "[$name] warm install (lockfile kept, node_modules removed)..."
    Remove-Item -LiteralPath (Join-Path $dir "node_modules") -Recurse -Force
    $warmTime = (Measure-Command { & $cmd @warmArgs *> $null }).TotalSeconds

    [pscustomobject]@{
      Manager      = $name
      ColdSeconds  = [math]::Round($coldTime, 2)
      WarmSeconds  = [math]::Round($warmTime, 2)
      NodeModulesMB = $coldSize
      LockfileKB   = $lockKB
      Lockfile     = $lockfile
    }
  } finally {
    Pop-Location
  }
}

$results = @()
$results += Run-Install -name "npm"  -dir (Join-Path $root "npm-run")  -cmd "npm"  -coldArgs @("install","--no-audit","--no-fund","--loglevel=error") -warmArgs @("ci","--no-audit","--no-fund","--loglevel=error") -lockfile "package-lock.json"
$results += Run-Install -name "pnpm" -dir (Join-Path $root "pnpm-run") -cmd "pnpm" -coldArgs @("install","--reporter=silent") -warmArgs @("install","--frozen-lockfile","--reporter=silent") -lockfile "pnpm-lock.yaml"
$results += Run-Install -name "bun"  -dir (Join-Path $root "bun-run")  -cmd $bun  -coldArgs @("install") -warmArgs @("install","--frozen-lockfile") -lockfile "bun.lock"

Write-Host "`n=== RESULTS ===" -ForegroundColor Green
$results | Format-Table -AutoSize

$md = @()
$md += "# Install Benchmark Results"
$md += ""
$md += "Run date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$md += "Host: $env:COMPUTERNAME"
$md += "Node: $(node --version)  |  npm: $(npm --version)  |  pnpm: $(pnpm --version)  |  bun: $(& $bun --version)"
$md += ""
$md += "| Manager | Cold install (s) | Warm install (s) | node_modules size (MB) | Lockfile size (KB) | Lockfile |"
$md += "|---|---|---|---|---|---|"
foreach ($r in $results) {
  $md += "| $($r.Manager) | $($r.ColdSeconds) | $($r.WarmSeconds) | $($r.NodeModulesMB) | $($r.LockfileKB) | ``$($r.Lockfile)`` |"
}
$md += ""
$md += "**Cold** = no cache, no lockfile, no node_modules. **Warm** = lockfile present, node_modules deleted (simulates CI / fresh clone with cached store)."

$mdPath = Join-Path $root "results.md"
$md | Set-Content -Path $mdPath -Encoding UTF8
Write-Host "`nResults written to $mdPath" -ForegroundColor Green
