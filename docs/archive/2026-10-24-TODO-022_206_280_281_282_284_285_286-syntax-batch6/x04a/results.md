# X04a の結果

着手: 2026-10-26 23:26:16 JST（14:26:16 UTC）。終了: 2026-10-26 23:46:10 JST（2026-10-26 14:46:10 UTC）。所要時間: 19分54秒。

## 対象と変更

B_WORK と HEAD は `0b5afe5d5feb3370e6570c8314eb6e4b885d2587`、ブランチは `mod012/X04a`。着手時に差分はなかった。AGENTS.md、共通依頼文、plan の前提・内部契約・X01〜X05・X04a/X05a/K1 の検査、decisions の独立交換と評価の範囲、README の設計者の決定、07-03、既存の全比較と方針自己検査、X01a〜X03c の申し送りを確認した。rtk・test-audit・japanese-tech-writing を適用した。

| ファイル | 変更 |
|---|---|
| `scripts/check-formal.sh` | intervalDiff のビルド、区間専用の四書き出し、独立期待値・実ソース・evalClosed/VM の比較を接続した。既存六入口・各独立交換・最後の check_named を維持した。既定の出力先は `target/interval-diff/run-$$`。実 CLI も同じ関係状態からビルドする |
| `scripts/check/formal_interval.py` | 準備・収集・manifest の確定・読み戻しを実装した。三出力先の同一・親子・リンクによる衝突と古い出力の再利用を拒む。旧二 corpus の入力順を区間の一覧と照合し、実行前の入力128ファイルのハッシュと、実行後の全報告・入力のハッシュ、件数、profile、VM 比較と除外を別に保存して照合する。128は今回の局所試行での件数であり固定条件ではない |
| `scripts/check/test_policy.py` | 既存の接続・失敗伝播のテストを拡張した。四書き出しの出力先、10系統の実ソース、VM 比較、manifest の最後の照合、CLI のビルドを観測する。新設した二テストは、実際のパスによる出力先の分離と、実ファイルの改変・欠落の拒否を確かめる。三シェルの構文検査も維持した |

区間の四書き出しは、identity・manifest・range・vm ごとに独立した出力先へ逐次実行する。従来の全件書き出しではこの四件だけを skip し、直後の段で各一度実行する。旧六入口の件数や入力は減らしていない。旧全件と独立プログラムの区間データを `programs/` へコピーして連結するのは、独立プログラムの identity が単独では全 Top になるためである。元の二 corpus と順序を照合し、そのファイル自体は移動・変更しない。

`Log.formatRecord` は既存の `batch3/g2` の実交換の call と、その入力ハッシュを持つ六入口の成功報告を照合する。全件の既存検証を行った後に三出力先の全ファイルを manifest にまとめ、追加・欠落・ハッシュ・件数の相違を拒む。旧比較の非0が残った場合には、成功の manifest を確定しない。

本番 Rust、Rust のテスト・比較器、Lean の定義・定理・公理、予算の固定表、`scripts/check.sh` は変更していない。`formal_build` は既定の Lean ビルドのままである。仕様の変更や Rust の型・署名の変更を要する点、判断待ちの停止条件はない。

## 作成時の関門

| 観点 | 今回の回答 |
|---|---|
| 守る契約 | 全比較が区間の独立入力・全実ソース・VM を一度ずつ呼び、出力先を隔て、途中の失敗と成果物の欠落・改変を成功にしないこと |
| 捕まえる退行 | 新入口の呼び忘れ、比較器へ渡すディレクトリの欠落・重複、共通の出力先への誤書き込み、最後の成功による失敗の上書き、古い報告の再利用、実ファイルの変更 |
| 既存検査との差 | 既存の接続テストの同じ境界へ区間の観測を足した。旧比較器の単独テストでは、シェルがそれを実際に呼ぶことや出力先を渡すことは確かめられない。パスと manifest は新しい補助スクリプトの境界へ置いた |
| 差し込み口 | 本番 Rust には追加しない。外部プロセスだけを既存のダブルで観測し、パス・ハッシュの検査は実ファイルを使う |

既存のテストを一つ改名・拡張し、二つ追加した。既存の契約を削除したテストはない。新しい固定の宣言一覧や自己比較によって言語処理系の正しさを主張していない。

## 検査

実行場所は `<repo>`。コマンド・終了状態・外側時間・パスを伏せた出力は [run.py](run.py) と各 JSON/log に保存した。Cargo は `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を使った。局所比較は既存の intervalDiff と六入口の実行ファイルを逐次起動し、別の Lean ビルドを起動していない。最後の work の Lean ビルドも並行させず、背景へ置いて別の作業をしていない。

| 検査・コマンド | 結果 |
|---|---|
| `BENITOITE_DESUGAR_DIFF_DIR=target/interval-diff/x04a-local/identity cargo test --test desugar_export export_interval_identity -- --nocapture` | 成功1件、終了0、外側9.892秒。[記録](local-exports.json) |
| manifest・range・vm・independent-program・Log の各局所書き出し | 各フィルタ1件成功、合計5件、終了0、外側10.734秒。[正確な逐次コマンド](local-other-exports.json)。Log は後述の出力先を直して一度書き直した（終了0、0.562秒。[記録](log-export-corrected.json)） |
| `python3 -B x04a/local_probe.py`（パスは本改造のディレクトリを補う） | 最終試行は終了0、外側40.537秒。[実行](local-comparison-third.json)・[出力](local-comparison-third.log)。interval の検査器が記録した279起動に加え、全定義の manifest を10系統、Log を六入口で照合した |
| 接続・パス・入力ハッシュの局所 policy 検査 | 3件成功、終了0、外側9.668秒。[コマンドと結果](local-policy.json) |
| `scripts/check.sh --level work --base 0b5afe5d5feb3370e6570c8314eb6e4b885d2587 --dry-run` | 生成物の誤配置を直した後は終了0、0.092秒。`policy_selftest` と `formal_build` の二単位だけを選択。[記録](work-dry-run-corrected.json) |
| `/usr/bin/time -l scripts/check.sh --level work --base 0b5afe5d5feb3370e6570c8314eb6e4b885d2587` | **検査本体は二単位成功**。方針自己検査は28件成功、25.294秒。Lean 既定ビルドは成功し、最後に `selected checks passed` を出した。外側25.588秒。time の終了状態については次段落。[実行](work.json)・[出力](work.log) |
| manifest の件数を一つ増やす追加の短い試行 | `manifest counts differ` で拒否し、原本を戻した後は成功。終了0、1.035秒。[記録](count-probe.json)・[出力](count-probe.log) |

指定 work は `--test` を付けず、一度だけ実行した。`/usr/bin/time -l` は検査本体の成功後に `sysctl kern.clockrate: Operation not permitted` を出した。このため **外側の終了状態は1** である。検査の失敗として隠さず、計測の失敗と区別する。maximum resident set size は出力されず、サンドボックスの制限で取得できなかった。time の real は25.58秒、上表の外側時間は run.py の単調時計で測った値である。計測だけの問題を理由に、成功した work を重ねて実行していない。

## 局所比較の範囲

全件 corpus の書き出しと K1 は実行していない。[local_probe.py](local_probe.py) は、実際の CorpusStream が書いた manifest の通常7入力と、独立プログラム1入力を全件の代わりに使う。予算停止の補助入力は元の manifest の系統で別に比較する。`check-formal.sh` 全体を実プロセスで走らせた成功とは数えない。policy 検査内の全体起動では、外部プロセスをダブルへ置き換えて接続と失敗伝播だけを観測した。

- 五 profile の独立解析174本体と、容器の追加1本体が一致した。各 profile は非 Top の結果を含み、解析の深さ除外は0件。独立した閉じた評価は109本体を比較し、理由付きの65本体の除外を別に残した。
- 通常解析は10系統、延べ58成功入力・869本体を Rust/Lean 間で比較した。同じ入力を別系統でも扱うため、固有の入力数という意味ではない。各系統の値・警告候補・統合後の警告・消費・停止と全定義の manifest が一致した。深さ除外・段の深さ停止は0件、各系統に非 Top の結果がある。
- VM と評価関係の比較は算術39件、Range37件、シフト46件。シフトの62件は独立期待値だけとの照合であり、VM と評価関係との一致へ足していない。Range の9本体の事前選別も理由を残した。
- `Log.formatRecord` を直接使う1入力・11定義が、脱糖・組み込み・通常網羅性・プログラム網羅性・surfaceCheck・surfaceCheckAll の六入口で一致した。
- 実行前の入力ハッシュ128件と、実行後の全入力・全報告等1,797ファイルの manifest を照合した。報告と入力をそれぞれ書き換える・削除する四試行はすべて拒否し、戻した後に成功した。件数の改変も別に拒否した。

局所試行の全入力・全報告・manifest 等1,798ファイル（manifest 自身を含む）は [local-records.zip](local-records.zip) に保存した。[SHA-256 の索引](local-records-index.json)と [集計](local-summary.json)を添え、[bundle.py](bundle.py) で全項目を読み戻した。伏せる必要のある手元のパスを含むファイルは0件であり、索引の保存後のハッシュと元のハッシュは同じである。一時的な target のログだけを証拠にしていない。この記録を全件 K1 の代わりとして引用しない。

## 初回の失敗と修正

1. 新しいハッシュ検査の局所テストの初回は、macOS の一時パスの別名と解決後のパスを混ぜた準備のため失敗した。テストの根を `resolve()` し、実行用と同じ条件へ揃えた。修正後の三件と最後の28件は成功した。
2. 実入力の初回は、Python 3.9 に `hashlib.file_digest` がないため収集で停止した。1 MiB ずつ読む SHA-256 計算へ直した。[初回の実行と出力](local-comparison.json)に失敗を残す。
3. 次の局所試行は interval 比較の完走後、Log の出力が見つからず停止した。既存 batch3 の書き出し器は相対出力先をクレート基準で扱うためであった。Log を絶対化した出力先へ再度書き出し、最終試行は全て成功した。[二回目の実行](local-comparison-second.json)。全比較のシェルは最初から絶対化して渡しており、この問題を理由に Rust の書き出し器を変更していない。
4. work の初回 dry-run は、3で誤配置した `crates/benitoite/target/...` の生成物を Rust 変更として拾った。生成物だけをルートの target へ移し、再度の dry-run で予定の二単位を確認してから work を実行した。[初回の選択](work-dry-run.json)・[移動の記録](misplaced-output-relocation.json)。余計に選ばれた Rust 全件検査は実行していない。

## 計画との差と申し送り

計画の二つの既存ファイルに加え、manifest と出力先の検証をシェルへ埋め込まず保守するため、補助の `scripts/check/formal_interval.py` を一つ追加した。処理系や Lean の定義へ担当を広げていない。[実装3ファイルのハッシュ](implementation-hashes.json)を保存し、work の後は結果と保管用の記録だけを追加した。Rust・formal/・check.sh の基準からの差分は0である。4時間の中断条件には達していない。

private/ とそこを指すリンク、git の変更操作、担当の委任、コミット・取り込み・docs/todo の更新・公開は行っていない。stage・change・release と、実際の全比較 K1 は本枝では実行していない。

| 残る手順 | 担当と内容 | 見込み |
|---|---|---|
| X04a の独立レビュー・受け入れ | 取りまとめ。出力先の分離、既存六入口と独立交換、manifest、途中失敗と欠落の拒否、計測の制限を確認する | 不明 |
| 全比較の説明の同期 | X04b。07-03・07-04・formal/README.md に新入口、10系統、三出力先、実行前後の manifest、Log 公開利用を反映する。指定する出力先は毎回新しい空の場所にする | 計画は1〜2時間 |
| K1 全体の検査・レビュー・受け入れ | X05a と取りまとめ。実際の全件 corpus を含め `scripts/check-formal.sh` を一つの関係状態で実行し、三出力先の manifest と件数を永続の記録へ残す。時間・メモリは局所40.537秒から全件を断定せず、最初の全件入力を観測する | 全体は不明。計画の仮見込み30〜60分を実測で更新する |

## 取りまとめのレビュー（2026-10-26）

受け入れる。`check-formal.sh` の全比較に区間解析の独立入口・Rust の通常解析・評価と VM の比較を加え、出力は既存と別の置き場所に置く。`check.sh` の formal_build は変わらず、全比較へすり替えていない。方針の自己検査（28件）が三シェルの構文と出力先の分離・改変の拒否を確かめる。短い試行は一致した。K1 の全体は X05a で一度走らせる。X04b へ進む。
