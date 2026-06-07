# アルゴリズム・スナップショット一覧

バックテストのチューニングを繰り返すとエントリーアルゴリズム（.mq5/.mqh）が
上書きされていく。成績が良かった時点のソース一式をこのフォルダに保全し、
後から確実にその版へ戻せるようにするための運用ツール一式。

## 運用ルール
- 合言葉 **「アルゴリズム保存」** で、現在の作業ツリーが自動でスナップショット化される。
- 各スナップショットは `<版>_<日付>_<ラベル>/` フォルダに保存され、配下に以下を含む:
  - `src/MochipoyoEA.mq5`
  - `src/Include/MochipoyoMTF.mqh`
  - `src/Include/MochipoyoSignal.mqh`
  - `src/Include/MochipoyoRisk.mqh`
  - `SNAPSHOT.md`（メタ情報・指標・パラメータ・復元方法）
- 保存後は SNAPSHOT.md の主要指標欄を記入し、この INDEX.md に1行追記する。
- git tag はメインセッションが別途作成する（例: `git tag snapshot/<版>_<日付>_<ラベル>`）。

## save-snapshot.ps1 の使い方
```
powershell -File algorithm-snapshots\save-snapshot.ps1 -Version v1.2 -Test pre-v1.3 -Label baseline
```
- `-Version` 仕様バージョン（例: v1.2）※必須
- `-Test`    対応バックテスト（例: test009a / baseline）※必須
- `-Label`   ラベル（例: h4-lookback-50）※必須
- 保存先フォルダ名は `<Version>_<実行日YYYY-MM-DD>_<Label>` で自動生成される。

## 復元方法
- 対象スナップショットの `src/` 配下4ファイルをプロジェクトの該当場所へ上書きコピーする。
- または対応する git tag から復元する。

## スナップショット一覧
| 版 | 保存日 | ラベル | 対応テスト | PF | ロング勝率 | 相場特性 | gitタグ | 状態 |
|---|---|---|---|---|---|---|---|---|
| [v1.0](v1.0_2026-05-12_test004-PF1.27/) | 2026-05-12 | test004-PF1.27 | test004 | **1.27** | 57.1% | 📈 上昇 | snapshot/v1.0_2026-05-12_test004-PF1.27 | ✅ 全テスト中最高PF（git遡及保全） |
| [v1.2](v1.2_2026-06-07_baseline/) | 2026-06-07 | baseline | pre-v1.3 | — | — | — | snapshot/v1.2_2026-06-07_baseline | v1.3開発前ベースライン |
