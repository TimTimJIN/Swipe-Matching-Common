# 解析とテストをまとめて実行する。結果を一覧にし、1つでも失敗したら終了コード 1 を返す。
# 起動中のアプリ（Claude Code など）は Flutter 導入前の PATH を持ち続けることがあるため、
# レジストリから PATH を読み直してから実行する。
$ErrorActionPreference = 'Continue'

$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host 'flutter が見つかりません。Flutter SDK を導入し、PATH に追加してください。'
    exit 1
}

$root = Split-Path -Parent $PSScriptRoot
$steps = @(
    @{ Name = 'dart analyze packages apps'; Dir = $root; Exe = 'dart'; Args = @('analyze', 'packages', 'apps') },
    @{ Name = 'swipe_core: dart test'; Dir = (Join-Path $root 'packages/swipe_core'); Exe = 'dart'; Args = @('test') },
    @{ Name = 'swipe_ui: flutter test'; Dir = (Join-Path $root 'packages/swipe_ui'); Exe = 'flutter'; Args = @('test') }
)

$results = @()
foreach ($s in $steps) {
    Write-Host "=== $($s.Name)"
    Push-Location $s.Dir
    & $s.Exe @($s.Args)
    $code = $LASTEXITCODE
    Pop-Location
    $results += [pscustomobject]@{ Step = $s.Name; ExitCode = $code; Result = $(if ($code -eq 0) { 'OK' } else { 'FAILED' }) }
}

Write-Host ''
$results | Format-Table -AutoSize | Out-String | Write-Host
if (@($results | Where-Object { $_.ExitCode -ne 0 }).Count -gt 0) { exit 1 }
exit 0
