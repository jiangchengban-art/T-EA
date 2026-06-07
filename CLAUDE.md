# MochipoyoEA — Claude Code 作業ガイド

## エージェント役割分担
- **メインセッション**: コードを書かない。読み取り・調査・サブセッションへの指示出し専任。
- **サブセッション（Agentツール）**: 実際のコード編集・ファイル作成を担当。

## 仕様書（唯一の真実）
- `../mochipoyo-spec.md` — ロジック変更前に必ずこちらを先に確認・更新すること。
- コードが仕様書と矛盾する場合は仕様書を優先する。

## ファイル構成
```
mochipoyo-ea/
  MochipoyoEA.mq5              メインEA（OnTick・エントリー制御）
  Include/
    MochipoyoMTF.mqh           EMA/MACDハンドル管理・値取得
    MochipoyoSignal.mqh        スコアリング・RCI・ダウ理論・グランビル・ダイバージェンス
                               v1.3: IsH4TrendUp/IsH4TrendDown 新追加
    MochipoyoRisk.mqh          ロット計算・SL/TP・ポジション管理・ニュース回避
  algorithm-snapshots/         ← NEW: アルゴリズム保存システム（v1.0 test004+ v1.2 baseline）
    save-snapshot.ps1          スナップショット自動保存スクリプト
    SNAPSHOT_TEMPLATE.md
    INDEX.md
    v1.0_2026-05-12_test004-PF1.27/
    v1.2_2026-06-07_baseline/
  backtests/                   バックテスト結果管理
    001_2026-05-09_baseline/   テスト結果ディレクトリ
    002_2026-05-10_lot-fix-v1/
    003_2026-05-12_debug-log/
    004_2026-05-12_lot-fixed/
    005-008_2026-05-12/        各期間別テスト結果
    009_2026-05-13_long-block-v1/
    009a_2026-06-07_h4-lookback-50/
    009b_2026-06-07_h4-hybrid/  ← NEW: v1.3下落相場テスト（成功 PF 0.83→1.07）
    009c_2026-06-07_h4-hybrid-5year/ ← NEW: v1.3回帰テスト（実行待機）
    new-backtest.ps1           テスト実行用PowerShellスクリプト
    INDEX.md                   全テスト履歴・比較表
  backtest-notes.md            バックテスト手順と結果記録（参考）
  CLAUDE.md                    本ファイル
```

## MT5 ファイル配置
1. MT5の「ファイル→データフォルダを開く」を実行
2. `MQL5/Experts/Mochipoyo/MochipoyoEA.mq5` を配置
3. `MQL5/Include/Mochipoyo/` に 3つの .mqh を配置
4. MetaEditor で `MochipoyoEA.mq5` を開き F7 でコンパイル（エラー0・警告0）

## コンパイル確認
- エラー0・警告0 が合格ライン
- コンパイル後は MT5 のエキスパートタブでログを確認する

## 絶対に守るルール
- ナンピン・両建て禁止（1シンボル1ポジション固定）
- 実口座投入前にデモ口座で3ヶ月以上のフォワードテストを実施すること
- リスクは1トレード1%以下を厳守
- ロジック変更時は必ず `../mochipoyo-spec.md` を先に更新する

## スコアリング（12点満点、閾値: InpMinScore=9※v1.1以降）
| # | 判定項目 | 点数 | タイムフレーム | v1.3更新 |
|---|---|---|---|---|
| 1 | **H4ダウ理論トレンド** | +2 | H4 | ✅ ハイブリッド判定（窓化スイング AND EMA） |
| 2 | M15/M5トレンド一致 | +2 | M15+M5 | — |
| 3 | EMAパーフェクトオーダー | +1 | M15 | — |
| 4 | グランビル反発 | +1 | M5 | — |
| 5 | RCI過熱域（9/14/18） | +2 | M5 | — |
| 6 | RCI反転 | +1 | M5 | — |
| 7 | ヒドゥンダイバージェンス | +2 | M15 | — |
| 8 | ラウンドナンバー接近 | +1 | — | — |

### v1.3 H4判定の詳細（重要）
**v1.3から：** H4判定を「窓化スイング AND EMA」ハイブリッド方式に変更

```
IsH4TrendUp(): 上昇判定
  = [窓化スイング上昇] AND [EMA上昇]
  窓化: lookback 50本を前半(3-25)・後半(25-50)に分割 → 極値比較
  EMA: EMA20>EMA40 かつ EMA40が上向き(3本前比)

IsH4TrendDown(): 下降判定
  = [窓化スイング下降] AND [EMA下降]
  （鏡像ロジック）

効果: 下落相場の押し目反発による偽トレンド検出を排除
  テスト009b実績: PF 0.78→1.07 / ロング勝率 33.3%→45.57%
```

**実装ファイル**: `Include/MochipoyoSignal.mqh` 行167-225 (IsH4TrendUp/Down)

## 対象通貨ペア
GBPJPY / GBPUSD / XAUUSD（デイトレ: H4上位 / M15中位 / M5下位）

## 主要パラメーター
| パラメーター | 既定値 | 意味 |
|---|---|---|
| InpRiskPercent | 1.0 | 1トレードリスク% |
| InpMinScore | 9 | エントリー閾値（12点満点、v1.1以降） |
| InpTargetRR | 1.2 | 利確目標RR |
| InpMinRR | 1.0 | 最小許容RR |
| InpTrailByEMA40 | false | EMA40追従トレーリング |
| InpBufferPips | 5 | SLバッファ（GOLDは0.5$固定） |