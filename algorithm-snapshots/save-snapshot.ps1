#requires -Version 5.1
<#
.SYNOPSIS
    アルゴリズム・スナップショット保存システム
.DESCRIPTION
    成績が良かった時点のEAソース一式(.mq5/.mqh)をフォルダにコピー保全し、
    後から確実にその版へ戻せるようにする運用ツール。
    EAロジックは一切変更しない（コピーのみ）。
.PARAMETER Version
    仕様バージョン（例: v1.2）
.PARAMETER Test
    対応バックテスト（例: test009a / baseline）
.PARAMETER Label
    ラベル（例: h4-lookback-50）
.EXAMPLE
    powershell -File algorithm-snapshots\save-snapshot.ps1 -Version v1.2 -Test pre-v1.3 -Label baseline
#>
param(
    [Parameter(Mandatory = $true)][string]$Version,
    [Parameter(Mandatory = $true)][string]$Test,
    [Parameter(Mandatory = $true)][string]$Label
)

$ErrorActionPreference = 'Stop'

# プロジェクトルート = このスクリプトの1つ上の階層
$ProjectRoot = Split-Path $PSScriptRoot -Parent
$Date = Get-Date -Format 'yyyy-MM-dd'

# 保存先フォルダ名: <Version>_<日付YYYY-MM-DD>_<Label>
$DestName = "${Version}_${Date}_${Label}"
$DestDir = Join-Path $PSScriptRoot $DestName
$DestSrc = Join-Path $DestDir 'src'
$DestInclude = Join-Path $DestSrc 'Include'

# コピー対象ソース（プロジェクトルート基準）
$SourceFiles = @(
    @{ Src = (Join-Path $ProjectRoot 'MochipoyoEA.mq5');                 Dst = (Join-Path $DestSrc 'MochipoyoEA.mq5') },
    @{ Src = (Join-Path $ProjectRoot 'Include\MochipoyoMTF.mqh');        Dst = (Join-Path $DestInclude 'MochipoyoMTF.mqh') },
    @{ Src = (Join-Path $ProjectRoot 'Include\MochipoyoSignal.mqh');     Dst = (Join-Path $DestInclude 'MochipoyoSignal.mqh') },
    @{ Src = (Join-Path $ProjectRoot 'Include\MochipoyoRisk.mqh');       Dst = (Join-Path $DestInclude 'MochipoyoRisk.mqh') }
)

# 事前チェック: ソースの存在確認
foreach ($f in $SourceFiles) {
    if (-not (Test-Path $f.Src)) {
        Write-Error "ソースファイルが見つかりません: $($f.Src)"
        exit 1
    }
}

if (Test-Path $DestDir) {
    Write-Error "保存先が既に存在します: $DestDir （Label/Versionを変えるか手動で削除してください）"
    exit 1
}

# 1. フォルダ作成
New-Item -ItemType Directory -Path $DestSrc -Force | Out-Null
New-Item -ItemType Directory -Path $DestInclude -Force | Out-Null

# 2. 4ファイルをコピー
foreach ($f in $SourceFiles) {
    Copy-Item -Path $f.Src -Destination $f.Dst -Force
    Write-Host "  copied: $(Split-Path $f.Src -Leaf)"
}

# 3. 現在のgitコミットハッシュを取得
try {
    Push-Location $ProjectRoot
    $GitHash = (git rev-parse --short HEAD).Trim()
    Pop-Location
}
catch {
    $GitHash = '(取得失敗)'
}
if ([string]::IsNullOrWhiteSpace($GitHash)) { $GitHash = '(取得失敗)' }

# 4. SNAPSHOT.md を生成（テンプレートのプレースホルダを埋める）
$TemplatePath = Join-Path $PSScriptRoot 'SNAPSHOT_TEMPLATE.md'
if (-not (Test-Path $TemplatePath)) {
    Write-Error "テンプレートが見つかりません: $TemplatePath"
    exit 1
}
$Template = Get-Content -Path $TemplatePath -Raw -Encoding UTF8
$Content = $Template.Replace('{VERSION}', $Version).Replace('{DATE}', $Date).Replace('{GITHASH}', $GitHash).Replace('{TEST}', $Test).Replace('{LABEL}', $Label)
$SnapshotPath = Join-Path $DestDir 'SNAPSHOT.md'
$Content | Out-File -FilePath $SnapshotPath -Encoding utf8

# 5. 完了メッセージと次の手順
Write-Host ''
Write-Host '======================================================'
Write-Host " スナップショット保存完了: $DestName"
Write-Host '======================================================'
Write-Host " 保存先 : $DestDir"
Write-Host " git    : $GitHash"
Write-Host ''
Write-Host '次の手順:'
Write-Host "  1. $SnapshotPath を開き、主要指標欄(PF/勝率/DD/損益など)を記入する"
Write-Host "  2. algorithm-snapshots\INDEX.md に1行追記する"
Write-Host "  3. メインセッションで git tag を作成する（例: git tag snapshot/$DestName）"
Write-Host ''
