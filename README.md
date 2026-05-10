# MochipoyoEA

もちぽよ手法（ダウ理論＋グランビルの法則＋EMA/RCI/MACD マルチタイムフレーム分析）の
MetaTrader5 フル自動売買EA。

対象通貨ペア: GBPJPY / GBPUSD / XAUUSD
標準スタイル: デイトレ（H4上位 / M15中位 / M5下位）

判定ロジックの真実の源: `../mochipoyo-spec.md`

## ファイル構成

```
mochipoyo-ea/
  MochipoyoEA.mq5                 メインEA
  Include/
    MochipoyoMTF.mqh              MTFヘルパー
    MochipoyoSignal.mqh           シグナル判定・RCI・ダイバージェンス
    MochipoyoRisk.mqh             ロット・SL/TP・フィルタ
  backtest-notes.md               バックテスト手順
  README.md                       本ファイル
```

## セットアップ

1. MT5 の `ファイル -> データフォルダを開く` を実行
2. `MQL5/Experts/Mochipoyo/` を作成し `MochipoyoEA.mq5` を配置
3. `MQL5/Include/Mochipoyo/` を作成し 3つの .mqh を配置
   - あるいは EA と同階層の `Include/` フォルダ構造をそのまま配置可
4. MetaEditor を起動し `MochipoyoEA.mq5` を開く
5. `F7` でコンパイル（エラー0・警告0を確認）
6. MT5 に戻り、ナビゲーター `Experts` から対象チャートへドラッグ＆ドロップ
7. 「自動売買」ボタンをONにする

## 入力パラメーター

| パラメーター | 既定値 | 意味 |
|---|---|---|
| InpRiskPercent | 1.0 | 1トレードで許容する口座残高リスク% |
| InpMinRR | 1.0 | 最小リスクリワード比 |
| InpTargetRR | 1.2 | 利確目標のRR |
| InpMinScore | 8 | 12点満点中のエントリー最低スコア |
| InpMagicNumber | 20260411 | マジックナンバー |
| InpMaxSpreadPoints | 50 | 最大許容スプレッド(ポイント) |
| InpSlippagePoints | 20 | スリッページ(ポイント) |
| InpNewsAvoidHours | "" | 指標回避時間 `Mon21:30-22:30;Wed15:00-15:30` |
| InpEnableTrading | true | 自動売買ON/OFF |
| InpBufferPips | 5 | 損切バッファ(pips、GOLDは内部で0.5$固定) |
| InpTrailByEMA40 | false | EMA40追従トレーリング |

## 判定フロー

1. M15 バー確定時に1回評価
2. ゲート: ニュース時間／スプレッド／既存ポジ
3. ロング・ショートそれぞれで 8項目スコアを算出（最大12点）
4. スコア >= InpMinScore かつ 非レンジ かつ RR >= InpMinRR ならエントリー
5. 各判定結果は Print でログ出力（テスター/エキスパートタブで確認）

## 注意事項

- 実口座投入前に **デモ口座で3か月以上のフォワードテスト** を実施すること
- 実運用リスクは **1%以下** を強く推奨
- 経済指標・要人発言時は `InpNewsAvoidHours` を必ず設定する
- ナンピン・両建ては禁止（1シンボル1ポジ）
- ロジック変更時は必ず `mochipoyo-spec.md` を先に更新する

## 参考

- 仕様書: `../mochipoyo-spec.md`
- バックテスト手順: `backtest-notes.md`
