# L00a.01b: 既定 import と入力・成果物の一覧

2026-10-30 19:51:22（+0900）に、既存の成果物を読み取り専用で照合した。既定8ターゲットが到達する本番モジュール327件すべてに `.olean` があり、ソースより古い成果物は0件だった。各モジュールの完全な一覧は [inventory.json.gz](inventory.json.gz)（取りまとめが手元のパスを `<repo>`・`<home>` に置き換えて gzip で圧縮した。圧縮の前の SHA-256 は cb4f897ba5dbfd7f04a82853334e59d08c570dd425b7308719b1ac9a038950cb） の `modules` に置く。

保存した JSON は695,038バイト、SHA-256 は `37800dc300bfdf9d4b14c1d9206eca3804879fda81769c5498a9a9260c5667b9` である。再生成すると採取日時等も変わるため、この値は今回の保存物を識別する。

## 対象と照合方法

B0 は `80e8127a4f7edff946529153b2002666cc35edc1`、B_WORK と照合時の HEAD は `9506fb623d9b26750177521933b50a9f67dd0346` である。B0→B_WORK の `formal/` の差分、B_WORK→作業ツリーの `formal/`・`scripts/check.sh` の差分はともに0件だった。

[inventory.py](inventory.py) は `formal/lakefile.toml` の既定ターゲットを起点として、本番ソースの直接の import を再帰的にたどる。既定ライブラリの起点は `formal/Benitoite.lean`、実行ファイルの起点は次表の `root` である。コメントを除いて import のモジュール名を読み、各モジュールについて次を保存した。

| JSON の欄 | 保存した内容 |
|---|---|
| `modules[].module`・`imports` | モジュールの完全名と直接の import 一覧。これにより import の木の共有する依存を再構成できる |
| `modules[].source` | ソースのリポジトリ相対パス、バイト数、SHA-256、UTC の更新時刻、`mtime_ns` |
| `modules[].olean` | 対応する `.olean` の相対パス、バイト数、SHA-256、UTC の更新時刻、`mtime_ns` |
| `modules[].not_older_than_source` | `.olean` が存在し、成果物の `mtime_ns >= source.mtime_ns` なら true |
| `inputs_at_B_WORK` | B_WORK の改造文書582件・`formal/` 401件・検査入口1件の全984件。Git blob ID、実行可能ビット、SHA-256、現在の内容との一致 |
| `toolchain`・`tools` | 固定版・実行した版確認の出力・Lean/Lake の実行ファイルのハッシュ |
| `external_direct_imports` | 本番ソースから直接 import する配布物の `Lean`・`Std` のソースと `.olean` |
| `wl0_record`・`inventory_script` | 取りまとめの元記録と、今回使った一覧台本の SHA-256 |

対応するパスは、モジュール名の `.` を `/` に変え、ソースは `formal/<module>.lean`、成果物は `formal/.lake/build/lib/lean/<module>.olean` とする。台本はビルドや Lean ファイルの再検査を行わず、既存ファイルを読んで隣の JSON だけを書く。この lakefile で使う文字列・配列・`[[lean_exe]]` の形を対象とし、汎用の TOML 解析器とはしない。

## 既定ターゲット

| `defaultTargets` | import をたどる起点 |
|---|---|
| `Benitoite` | `Benitoite`（`formal/Benitoite.lean`） |
| `desugarDiff` | `DesugarDiff.Main` |
| `builtinCheck` | `BuiltinCheck.Main` |
| `coverageDiff` | `CoverageDiff.Main` |
| `coverageProgramDiff` | `CoverageProgramDiff.Main` |
| `surfaceCheck` | `SurfaceCheck.Main` |
| `surfaceCheckAll` | `SurfaceCheck.All` |
| `intervalDiff` | `IntervalDiff.Main` |

`SurfaceCheck` にはライブラリの定義もあるが、`defaultTargets` の独立の要素ではない。既定実行ファイルの import の到達集合に `SurfaceCheck` 配下の5モジュールが含まれる。`moreLeanArgs` は `-M 12288`、`lake-manifest.json` の `packages` は空である。

## モジュール別の集計

| モジュールの群 | ソースと `.olean` の対応件数 |
|---|---:|
| `Benitoite`（集約モジュール） | 1 |
| `Benitoite.Checked` | 6 |
| `Benitoite.Core` | 16 |
| `Benitoite.Exchange` | 12 |
| `Benitoite.Interval` | 64 |
| `Benitoite.Library` | 1 |
| `Benitoite.Release` | 108 |
| `Benitoite.Scope` | 12 |
| `Benitoite.Surface` | 97 |
| `BuiltinCheck.Main` | 1 |
| `CoverageDiff.Main` | 1 |
| `CoverageProgramDiff.Main` | 1 |
| `DesugarDiff.Main` | 1 |
| `IntervalDiff.Main` | 1 |
| `SurfaceCheck` 配下 | 5 |
| **計** | **327** |

| 確認 | 件数・時刻 |
|---|---|
| 既定 import が到達する本番ソース | 327件 |
| 対応する `.olean` | 327件 |
| `.olean` の欠落 | 0件 |
| ソースより古い `.olean` | 0件 |
| 現在の出力先にある、到達集合に対応しない `.olean` | 0件 |
| W-L0 の実行区間外の更新時刻を持つ本番 `.olean` | 0件 |
| `.olean` の最古の更新時刻 | 2026-10-30 19:44:32.142288（+0900） |
| `.olean` の最新の更新時刻 | 2026-10-30 19:47:57.943292（+0900） |
| B_WORK の984入力と現在の内容・実行可能ビットの不一致 | 0件 |

本番の Lean ソース全体は328件であり、既定 import の外には `Benitoite.Release.LegacyCheck` が1件ある。このファイルも B0/B_WORK から未変更である。今回 import から外したものではなく、今回の327件の成功へ含めない。P3/P4 の試作ファイルは改造文書の側にあり、本番の既定 import に含めない。

時刻だけからソースと成果物の意味上の一致を推定したものではない。[W-L0 の記録](../l00a.01a/wl0-measure.md)にある空の出力先でのビルドと、現在のソースの内容一致を組み合わせて判断した。以後の変更を検出するため、ソースと成果物の両方のハッシュも保存した。

## 固定版と実行した版確認

| 対象 | 確認結果 |
|---|---|
| `formal/lean-toolchain` | `leanprover/lean4:v4.34.1` |
| `formal/` で実行した `lean --version` | `Lean (version 4.34.1, arm64-apple-darwin24.6.0, commit 5045d0056413266e57c625dcd7c365b10e377c52, Release)`、終了0 |
| `formal/` で実行した `lake --version` | `Lake version 5.0.0-src+5045d00 (Lean version 4.34.1)`、終了0 |
| `formal/` で実行した `elan --version` | `elan 4.2.4 (227caca13 2026-08-25)`、終了0 |
| `lean --print-prefix` | 配布済みの `leanprover--lean4---v4.34.1` のディレクトリ、終了0。実パスと実行ファイルのハッシュは JSON に保存 |
| 一覧台本 | Python 3.9.6。追加の依存なし |

W-L0 の元記録には Lean の版出力を独立に保存していない。上表は再ビルド後の現在の環境で実際に実行した版確認であり、W-L0 の時点で版出力も採取したという意味ではない。固定版・設定は B0/B_WORK から未変更であり、現在の版確認は固定版と一致する。

本番から配布物へ直接 import するのは `Lean` と `Std` である。両者は固定ツールチェーンに同梱されており、今回の clean で作り直す本番327モジュールとは分けて記録した。配布物の推移的な内部モジュール全体を今回再ビルドしたとは扱わない。

## P4 と P3b の過去の証拠

以下は [spikes/P4/checks.md](../spikes/P4/checks.md) と各試行の JSON に保存された過去の結果である。今回の W-L0 と一覧の根拠を置き換えず、過去の古い成果物の問題を再び未解決とはしない。今回これらの試作を再実行していない。

| 過去の試行 | 本体の終了 | 計測器の終了 | 外側の時間 | 根拠と扱い |
|---|---|---|---|---|
| P4 `build-head` | 不明（単独の終了コード未保存） | 1 | 204.00871375秒 | [JSON](../spikes/P4/checks/build-head.json)。ログは573 jobsの成功を記録したが、本体の終了コードを補って0としない |
| P4 `build-head-exit-fallback` | 0 | 1 | 0.183361875秒 | [JSON](../spikes/P4/checks/build-head-exit-fallback.json)。再ビルド後の増分ビルド。本体の終了を別保存して確認 |
| P3b Nat 代表の再検査 | 0 | 1 | 0.457871958秒 | [JSON](../spikes/P4/checks/recheck-p3b-nat.json)。`lake env lean -M 12288 …/spikes/P3/P3b-Nat.lean` |
| P3b 境界代表の再検査 | 0 | 1 | 0.454948583秒 | [JSON](../spikes/P4/checks/recheck-p3b-boundary.json)。`lake env lean -M 12288 …/spikes/P3/P3b-BoundaryProofs.lean` |

過去の4試行の最大常駐量はすべて取得不能である。計測器の終了1は sandbox の `sysctl kern.clockrate` 制限によるもので、明示保存された本体の終了0と区別する。Nat 代表のログは5補題、境界代表のログは2補題の公理依存を出力しているが、本番の全保存や型付き表層の完成を意味しない。

以後の Lean ビルドは、W-L0 で作り直した `formal/.lake/build` に対する**増分ビルド**である。計測のためだけの clean や、今回の W-L0 の再実行は追加しない。現在の一致確認と過去の P3b の代表の成功を区別したまま、L00a.06a へ渡す。
