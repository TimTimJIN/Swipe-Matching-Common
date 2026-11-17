# 解析とテストをまとめて実行する。結果を一覧にし、1つでも失敗したら終了コード 1 を返す。
# 起動中のアプリ（Claude Code など）は Flutter 導入前の PATH を持ち続けることがあるため、
# レジストリの PATH を今の PATH に追記してから実行する（今の PATH は消さない）。
$ErrorActionPreference = 'Continue'

$env:Path = $env:Path + ';' + [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
foreach ($exe in 'flutter', 'dart') {
    if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) {
        Write-Host "$exe が見つかりません。Flutter SDK を導入し、PATH に追加してください。"
        exit 1
    }
}

$root = Split-Path -Parent $PSScriptRoot
$steps = @(
    # --fatal-infos：info レベルの指摘も失敗として扱う（「解析問題なし」を一括実行で保証する）。
    @{ Name = 'dart analyze packages apps'; Dir = $root; Exe = 'dart'; Args = @('analyze', '--fatal-infos', 'packages', 'apps') },
    @{ Name = 'swipe_core: dart test'; Dir = (Join-Path $root 'packages/swipe_core'); Exe = 'dart'; Args = @('test') },
    @{ Name = 'swipe_ui: flutter test'; Dir = (Join-Path $root 'packages/swipe_ui'); Exe = 'flutter'; Args = @('test') }
)

$results = @()
foreach ($s in $steps) {
    Write-Host "=== $($s.Name)"
    # 前のコマンドの終了コードが残らないよう、失敗を既定にしてから実行する。
    $code = -1
    try {
        Push-Location $s.Dir -ErrorAction Stop
        try {
            & $s.Exe @($s.Args)
            $code = $LASTEXITCODE
        } finally { Pop-Location }
    } catch {
        Write-Host "実行できませんでした：$($_.Exception.Message)"
        $code = -1
    }
    if ($null -eq $code) { $code = -1 }
    $results += [pscustomobject]@{ Step = $s.Name; ExitCode = $code; Result = $(if ($code -eq 0) { 'OK' } else { 'FAILED' }) }
}

Write-Host ''
$results | Format-Table -AutoSize | Out-String | Write-Host
if (@($results | Where-Object { $_.ExitCode -ne 0 }).Count -gt 0) { exit 1 }
exit 0
