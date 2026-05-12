# new-backtest.ps1 - 新しいバックテスト用フォルダを自動作成するスクリプト

$backtestsDir = Join-Path $PSScriptRoot "backtests"
$lastTestNumberFile = Join-Path $backtestsDir ".last-test-number"

# 最後のテスト番号を読み込む
$lastNum = 3
if (Test-Path $lastTestNumberFile) {
    $lastNum = [int](Get-Content -Path $lastTestNumberFile -Raw).Trim()
}

# 次の連番を決定
$nextNum = $lastNum + 1
$numStr = $nextNum.ToString("000")

# ラベル入力
$label = Read-Host "ラベルを入力してください（例: short-disable, lot-fix-v2）"
if ([string]::IsNullOrWhiteSpace($label)) { $label = "test" }
$label = $label -replace '[\\/:*?"<>| ]', '-'

# フォルダ作成
$today = Get-Date -Format "yyyy-MM-dd"
$folderName = "${numStr}_${today}_${label}"
$folderPath = Join-Path $backtestsDir $folderName
New-Item -ItemType Directory -Path $folderPath | Out-Null

# notes.md テンプレート生成
$notesContent = @"
# テスト $numStr - $label

- 日時: $today
- 期間: （テスト後に記入）
- シンボル: XAUUSD（GOLD）
- 初期資金: `$10,000

## 修正内容
- （変更内容を記入）

## 仮説
（この修正で何が改善されると期待しているか）

## 結果サマリー
（Claude が分析後に記入）

## 問題点
（Claude が分析後に記入）

## 次のアクション
（Claude が分析後に記入）
"@
$notesContent | Out-File -FilePath (Join-Path $folderPath "notes.md") -Encoding utf8

# パスをクリップボードにコピー
$folderPath | Set-Clipboard

Write-Host ""
Write-Host "✅ フォルダを作成しました:" -ForegroundColor Green
Write-Host "   $folderPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 パスをクリップボードにコピーしました。" -ForegroundColor Yellow
Write-Host "   MT5エクスポート時に Ctrl+V で貼り付けてください。" -ForegroundColor Yellow
Write-Host ""

# テスト番号を記録
$nextNum | Out-File -FilePath $lastTestNumberFile -Encoding utf8 -NoNewline

# 次のテスト用フォルダを作成するか聞く
Write-Host ""
$createNext = Read-Host "次のテスト用フォルダ($($($nextNum + 1).ToString('000')))も作成しますか？ [y/n]"

if($createNext -eq 'y' -or $createNext -eq 'Y')
{
    # 次のテストの設定
    $nextNextNum = $nextNum + 1
    $nextNumStr = $nextNextNum.ToString("000")
    $nextToday = Get-Date -Format "yyyy-MM-dd"

    # ラベル入力
    Write-Host ""
    $nextLabel = Read-Host "次のテスト用ラベルを入力してください"
    if ([string]::IsNullOrWhiteSpace($nextLabel)) { $nextLabel = "test" }
    $nextLabel = $nextLabel -replace '[\\/:*?"<>| ]', '-'

    # フォルダ作成
    $nextFolderName = "${nextNumStr}_${nextToday}_${nextLabel}"
    $nextFolderPath = Join-Path $backtestsDir $nextFolderName
    New-Item -ItemType Directory -Path $nextFolderPath | Out-Null

    # notes.md テンプレート生成
    $nextNotesContent = @"
# テスト $nextNumStr - $nextLabel

- 日時: $nextToday
- 期間: （テスト後に記入）
- シンボル: XAUUSD（GOLD）
- 初期資金: `$10,000

## 修正内容
- （変更内容を記入）

## 仮説
（この修正で何が改善されると期待しているか）

## 結果サマリー
（Claude が分析後に記入）

## 問題点
（Claude が分析後に記入）

## 次のアクション
（Claude が分析後に記入）
"@
    $nextNotesContent | Out-File -FilePath (Join-Path $nextFolderPath "notes.md") -Encoding utf8

    # パスをクリップボードにコピー
    $nextFolderPath | Set-Clipboard

    Write-Host ""
    Write-Host "✅ テスト $nextNumStr 用フォルダを作成しました:" -ForegroundColor Green
    Write-Host "   $nextFolderPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📋 パスをクリップボードにコピーしました。" -ForegroundColor Yellow

    # テスト番号を更新
    $nextNextNum | Out-File -FilePath $lastTestNumberFile -Encoding utf8 -NoNewline
}

Write-Host ""
Write-Host "Enterキーを押して終了..."
Read-Host
