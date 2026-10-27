# X05a の結果

3回目の着手: 2026-10-27 02:26:17 JST（最初の時刻保存）。終了（検査・保存・点検）: 2026-10-27 03:16:26 JST。所要時間: **50分09秒**。K1 本体は成功。詳細は末尾の「3回目」に記す。

2回目の着手: 2026-10-27 01:18:18 JST。終了: 2026-10-27 02:03:39 JST。所要時間: 45分21秒。2回目の結論は末尾の「2回目」を参照する。以下の旧記録は1回目のものである。

着手: 2026-10-27 00:00:23 JST（最初の時刻取得）。終了（検査・保管・点検の終了）: 2026-10-27 00:42:24 JST。所要時間: 42分01秒。

## 結論と対象

**K1 は不合格であり、X05a の接続の完了条件は満たしていない。** 一回の全体起動は、区間の実ソース比較の最初の系統で `AssertionError: incomplete enumeration` により終了1となった。外部型を含む4入力・12定義が交換の対象外となっていた。別に、全件 corpus と固定 manifest に1入力の差分も確認した。以下の原因を取りまとめへ返し、Rust・Lean・検査スクリプトを直さず停止する。

B_WORK と対象 HEAD はともに `0414065298d373cdb83838749eaeb1bb256d292e`、ブランチは `mod012/X05a`。着手時は未コミット差分・未追跡入力ともになかった。AGENTS.md、共通依頼文、plan の前提・内部契約・X01〜X05・X05a/X05b/K1/S-X の検査、decisions の D5/D17/D18/D22、study の 9.4、README の設計者の決定、preflight の勧告照合、07-03「結果の保存と引用」、二つの全比較スクリプト、X01a〜X04b の申し送りを読んだ。rtk と japanese-tech-writing を適用した。

X04a の局所40.537秒と計画の全体30〜60分を見積もりとして使い、追加の短い試行は行わなかった。過去の局所結果を K1 の成功として引用していない。今回の K1 本体の33分31.822秒は仮見込みの範囲内である。

## 実行と環境

実行場所は `<repo>`。次の環境変数を指定した。三出力先はいずれも新しい場所である。

```text
CARGO_HOME=<tmp>/benitoite-a01a-cargo
BENITOITE_DESUGAR_DIFF_DIR=target/desugar-diff/x05a-k1-20261027
BENITOITE_COVERAGE_DIFF_DIR=target/coverage-diff/x05a-k1-20261027
BENITOITE_INTERVAL_DIFF_DIR=target/interval-diff/x05a-k1-20261027
```

[run.py](run.py) の `timed k1 scripts/check-formal.sh` を一度起動した。外側は `/usr/bin/time -l`、その内側の子記録器は `scripts/check-formal.sh` を実行して本体の終了状態を保存する。正確な実行引数と時刻は [起動記録](k1-started.json)・[本体の記録](k1-body.json)・[外側の記録](k1.json)、パスを伏せた標準出力・標準エラーは [生ログ](k1.log)にある。K1 に dry-run の入口はないため付けていない。

| 項目 | 結果 |
|---|---|
| K1 本体 | 2026-10-27 00:01:55.729〜00:35:27.553 JST、終了1、外側の単調時計で2011.822秒 |
| time を含む外側 | 終了1、2011.854秒。time の real/user/sys は2011.85 / 2024.93 / 122.68秒 |
| 最大常駐量（maximum resident set size） | **取得不能**。time は `sysctl kern.clockrate: Operation not permitted` を報告し、最大常駐量を表示しなかった |
| メモリ制限による停止 | 終了143の記録はなく、今回の停止は上記の列挙検査の失敗である |
| ツールチェーン | Rust/Cargo 1.98.1、Lean 4.35.0、Lake 5.0.0-src+eb6cafb、elan 4.2.4、Python 3.9.6。macOS 27.0.1 / arm64 |
| 構成 | Cargo の既定構成。Lean の `-M 12288` を維持し、ビルドは逐次実行した。単一ファイル検査・別の Lean ビルド・K1 の再実行はない |

版の詳細は [environment.json](environment.json)、比較用の七実行ファイルと実 CLI の SHA-256 は [executables.json](executables.json)にある。プロセス別の使用量を調べる `ps` もサンドボックスに拒否された。最大常駐量の未取得を0と扱っていない。今回は検査本体も終了1であり、time の制限だけが原因の失敗とはしていない。

## 停止の原因

### 外部型を含む定義が列挙未完了になる

停止箇所は `formal/tests/interval_source_compare.py` の `exercise`（286行）である。最初の `--rust-dir`、すなわち `target/interval-diff/x05a-k1-20261027/programs` の入力を読んだ直後に、型検査が成功した入力全ての `enumerationComplete` が真であるという条件に反した。最初の `source-analysis-*.report.json` を作る前に止まっている。

| 入力（`crates/benitoite/` からの相対パス） | 交換の対象外の定義 | 件数 |
|---|---|---:|
| `testdata/external/resource` | `.createMany`、`.main` | 2 |
| `testdata/external/wit-docs-declarations` | `.main` | 1 |
| `testdata/packages/json-wasm-same` | `.compare`、`.pointers` | 2 |
| `testdata/packages/wasm-regex-same` | `.compare`、`WasmRegex.Pattern.compile`、`isMatch`、`find`、`findAll`、`replaceAll`、`count` | 7 |

12定義の理由はいずれも `external type` である。`tests/desugar_export/exchange.rs` は `TyCon::External` をこの対象外の理由として記録する（426・569行）。`tests/desugar_export/interval/manifest.rs` は、元の定義に `outside` があれば交換本文と別本体の接続を省き、その定義と入力を `enumerationComplete: false` にする（111〜117・172行）。比較器はこの状態を受け入れず、今回その条件が全件で初めて露呈した。

[入力ごとの要約](incomplete-enumeration-summary.json)と[対象外の定義・理由・全体状態](incomplete-enumeration-details.json)を保存した。[diagnose.py](diagnose.py)は巨大な元 manifest を入力ごとに読み、該当4入力の理由を取り出しただけであり、比較や入力の修正はしない。深さ停止・本体予算・全体予算による退避とは区別する。12定義を除いて成功した、あるいは全件が比較済みであるとは結論しない。

### 固定 manifest に新しい golden 入力がない

全件 corpus は1,791入力で、`tests/desugar_export/exchange-manifest.json` の1,790入力より1件多かった。差分は `golden: testdata/warnings/local-width-intervals.bnt` だけであり、欠落は0件である。全件 corpus 本体との直接照合と、同じ入力を列挙する区間要約との照合で確認した。[差分の記録](routing-difference.json)に固定 manifest のハッシュも残した。

この入力は A15a のコミット `8cf22e4df305b4a5983ca4650c5339fd3b50f05e` で加わった。元の関数9個が区間要約にも記録され、列挙は完了している。一方、固定 manifest は第6弾以前のままで、この入力を登録していない。最終の `check_named.py` にある `compare_routing` と `check_programs` は入力の集合の一致を要求するため、先の列挙の問題だけを直しても最終照合は通らない。ただし今回の実行はそこへ到達しておらず、**二つ目の失敗を実行して観測したとは数えない**。ソースと生成済みの入力一覧から確定する食い違いとして報告する。

## 実行できた範囲と未実行の範囲

[集計](evidence-summary.json)には、生成済みの報告から得た件数と、未完了の印を残した。

| 対象 | 今回の結果 |
|---|---|
| Lean の既定ビルドと比較用実行ファイル | 成功。既存キャッシュを使い、sorry の検出はない。これだけで K1 成功とはしていない |
| 通常網羅性の独立入力 | 10,020件一致、不一致0、fuelExhausted 0 |
| view を含む独立網羅性 | 10,028件一致、不一致0、fuelExhausted 0 |
| 幅・名前付き・拡張型・try・第2〜4弾の独立交換 | 各検査が終了0で先へ進んだ。個々の出力は生ログにある |
| Rust の coverage 書き出し | 4テスト成功、失敗0、無視0 |
| Rust の全件・独立交換書き出し | 31テスト成功、失敗0、無視0、区間専用4件を除外。全件書き出しのログは1,791入力、1,372 exported、419 excluded、outside 0。この件数は六入口の照合の成功件数ではない |
| Rust の区間専用四書き出し | identity・manifest・range・vm の各1テストが成功 |
| 識別と読者の局所接続 | 195入力・1,381出現、227対象演算、受理された `.point` は1本体。読者の probe の解析済み本体は0であり、実ソースの解析比較へ足していない |
| 算術・フローの評価関係と VM | 39件比較、除外0。標識の出力失敗 R0201 を対象算術の失敗から分ける検査も含む |
| Range の評価関係と VM | 37件比較、評価除外0。事前選別した9本体は理由付きで別に保存。37件へ足していない |
| 案III のシフト | VM 108行のうち、評価関係との比較46行、独立期待値だけの照合62行。後者の理由は unknownFailure 46・notClosedOrFuel 16であり、比較済み件数へ足していない |
| Rust/Lean の実ソース解析・10系統 | 最初の系統の列挙検査で停止。解析比較の報告は0本、比較済み本体も0。残る9系統は未実行 |
| 五 profile の独立解析・評価 | 同じ Python 入口では実ソースの後に置かれているため、今回未実行。`profile-manifest.json` はない |
| 六入口の最終照合・Log の六入口 | 未実行。通常網羅性の先行比較だけを、六入口全体の一致とはしていない |
| 最終 manifest の確定と verify | 未実行。成功を表す `interval/manifest.json` はない。入力用 `input-manifest.json` とは区別する |

VM の有限の比較は A1 の接続の一部であり、元ソース全体の意味保存や全入力での一致の証明ではない。Top だけの一致・成功0件・欠落を受け入れた箇所はなく、全体を不合格としている。

## 永続の証拠と関係状態

三出力先の1,891ファイルを [SHA-256 の索引](k1-records-index.json)に列挙し、うち1,879ファイルを [ZIP](k1-records.zip)へ保存して全項目を読み戻した。[bundle.py](bundle.py)がこの保存と照合を行う。16 MiB を超える再生成可能な入力12ファイルは本文を ZIP に含めず、元の大きさ・SHA-256・`persisted: false` を索引に残した。比較報告とログの省略は0件である。三つの出力先は手元の target に残しているが、その一時ログだけを引用元にしていない。

入力用 manifest は1,220ファイルのハッシュを持ち、ZIP 内の `interval/input-manifest.json` に保存した。元の全件 manifest と巨大な本文を ZIP へ保存済みであるかのようには扱わない。元入力は固定したソース・生成器・設定と、この索引で同定できる。追加の4入力の対象外の理由は上記の小さい詳細記録に本文として残した。ZIP の SHA-256 は `626efcbc9da93ea323317016ab72f7cfa970893a0ad9858f004bfe55af695583`、大きさは11,500,353バイトである。パスを伏せた2ファイルでは元と保存後のハッシュを別に記録した。全記録の手元のパスは `<repo>`・`<home>`・`<tmp>` に伏せた。

[検査前の入力状態](source-state-before.json)には、Rust・Lean・スクリプト・テスト・標準ソース・設定・生成元/生成物・文書例等の追跡対象5,875ファイルの SHA-256 を保存した。[検査後の状態](source-state-after.json)では、この全てが一致し、対象 HEAD も同じで、追跡済みの差分は0件であった。K1 後に追加・変更したのは x05a の結果と保管・調査の記録だけである。

引用の判断者は X05a 担当、日付は2026-10-27である。X05b が引用できるのは、同じ関係状態での**失敗と部分実行の記録**であり、S-X や K1 の成功ではない。別の状態への成功の引用は認めない。修正後は、変更した入力・交換器・固定 manifest 等を取りまとめが確定し、K1 全体を新しい出力先で実行する必要がある。

## 作業末の work

指定された `scripts/check.sh --level work --base 0414065298d373cdb83838749eaeb1bb256d292e` を、同じ指定の dry-run の後に一度実行した。`--test`・`--only` は付けていない。

| 検査 | 結果と外側時間 | 記録 |
|---|---|---|
| 同じ指定の dry-run | 終了0、0.079秒。文書だけの変更で検査対象なし | [記録](work-dry-run.json)・[出力](work-dry-run.log) |
| work 本体 | 終了0、0.080秒。選択0単位・実行0単位、`selected checks passed` | [本体](work-body.json) |
| `/usr/bin/time -l` を含む外側 | 終了1、0.110秒。time の real は0.10秒。最大常駐量は sysctl の拒否で取得不能 | [外側](work.json)・[生ログ](work.log) |

選択0単位は計画どおりであり、Rust の回帰や K1 成功の証拠とは分ける。dry-run と本実行の変更数の差（27件と30件）は、その間に作成した実行記録によるものであり、選択はいずれも0単位であった。計測だけの失敗を理由に work を再実行していない。

最後に [audit.py](audit.py) と [点検結果](self-review.json)で、5,875ソース入力の不変、入力 manifest の1,220ハッシュと保管索引の一致、ZIP のハッシュと収録一覧、記録と ZIP 内のパスの伏せ方、保存用 Python の構文、結果のリンク、git diff --check を確認した。結果と保管・点検の記録以外の差分はない。

## 担当へ戻す範囲

| 残る作業・検査・レビュー・受け入れ | 提案する担当と範囲 | 見込み |
|---|---|---|
| 外部型12定義の対象外と全件列挙の契約を整合させる | 取りまとめが判断し、X01/X02 の交換・全関係定義を扱う後続作業へ割り当てる。交換側の対応を加えるか、計画の理由付き除外を取りまとめが受け入れるかを決め、入力・manifest・比較器・設計書を同じ契約へそろえる。無条件に assertion を外す、定義を削除する、Top に置き換える修正はしない。Lean の定義・主定理等に及ぶ場合は別に判断する | 不明 |
| 新しい golden 例の固定記録を整合させる | X02 の全件 manifest を扱う後続作業。A15a の入力を保持し、その実際の分類・定義・網羅性の件数と理由を確認して exchange-manifest.json・routing-manifest.json と対応する集計を更新する。A15a のテストの削除では解決しない | 不明 |
| 修正の局所検査・指定 work・独立レビュー・受け入れ | 各修正担当と取りまとめ。変更範囲と全読者に合わせて割り当てを固定する | 不明 |
| 修正後の K1 全体と証拠の照合 | 取りまとめが担当と新しい基準を指定する。今回実行できなかった十系統・五 profile・六入口・最終 manifest を含めて全体を再実行する | 今回の途中停止まで33分32秒。成功までの時間は不明 |
| X05b の集約と S-X のレビュー・受け入れ | 上の問題の解決と K1 の成功後に行う。今回の失敗だけから S-X を閉じない | 不明 |

4時間の中断条件には達していない。今回の停止は、明示された不一致・欠落を完了にしないという条件による。private/ とそこを指すスキルのリンク、担当の委任、git の変更操作、コミット・取り込み・docs/todo の更新・公開は行っていない。Rust・Lean・検査用スクリプト・固定表・入力・期待値を変更していない。

## 取りまとめのレビュー（2026-10-27、最初の起動）

停止は正当である。取りまとめの判断は計画の変更（2026-10-27、X05a の停止を受けて）に置き、作業 X05R の後に K1 を再実行する。外部型の12定義は、Rust の解析が情報を持つ結果を出していない（`informativeBodies` 0、`unsupportedBodies` のみ）ので、計画の「除外の件数と理由を報告し取りまとめが受け入れる」によって理由付きの除外として受け入れる。条件は X05R の行に書いた。K1 の出力（`target/interval-diff/x05a-k1-20261027` の約11GB と `target/desugar-diff` の2.5GB）は、記録をこのディレクトリに保存した後で取りまとめが消した（ディスクの空きが14GB まで減ったため。clean-build の規則）。

## 2回目（X05R の後、2026-10-27）

### 結論と関係状態

**2回目の K1 も不合格であり、X05a と S-X の完了条件は満たしていない。** 一つの関係状態で全体を一度実行し、最初の実ソース系統の負例検査で `AssertionError: missing user warning accepted` により終了1となった。入力選択の原因を保存済み出力で確認し、修正せず取りまとめへ返す。

2回目の着手は2026-10-27 01:18:18 JST（最初の時刻取得）である。終了時刻と所要時間は冒頭の2回目の欄へ記す。B_WORK と HEAD はともに `e895627c1d376aa5d31af82e99fea4465f6d6c8b`、ブランチは `mod012/X05a`。着手時の未コミット差分・未追跡入力はなかった。AGENTS.md、共通依頼文、plan の前提・内部契約・X01〜X05・X05a/X05b/K1/S-X の検査・X05R を置く計画変更、D5/D17/D18/D22、study 9.4、README の設計者の決定、07-03「結果の保存と引用」、全比較の二スクリプト、X01a〜X04b の申し送りと X05R の結果を確認した。rtk と japanese-tech-writing を適用した。

X04a の局所40.537秒、計画の全体30〜60分、1回目の途中停止まで33分32秒を見積もりの根拠にした。全比較の時間・メモリを見積もる追加の短い試行は行っていない。K1 の前の `df -h /` は空き128 GiBであり、20 GB以上の開始条件を満たした（[出力](run2/disk-before.log)・[数値](run2/disk-before.json)）。

### コマンド・終了・時間・環境

実行場所は `<repo>`。三つの出力先は新しい空の場所とし、1回目を上書きしていない。

```text
CARGO_HOME=<tmp>/benitoite-a01a-cargo
BENITOITE_DESUGAR_DIFF_DIR=target/desugar-diff/x05a-k1-run2-20261027
BENITOITE_COVERAGE_DIFF_DIR=target/coverage-diff/x05a-k1-run2-20261027
BENITOITE_INTERVAL_DIFF_DIR=target/interval-diff/x05a-k1-run2-20261027
```

[記録器](run2/run.py)の `timed k1 scripts/check-formal.sh` を一度起動した。外側は `/usr/bin/time -l`、内側で本体の終了状態と単調時計の時間を分けて保存した。K1 に dry-run の入口はない。

| 項目 | 結果と記録 |
|---|---|
| K1 本体 | 2026-10-27 01:19:29.824〜01:57:16.606 JST、**終了1、2266.785秒（37分46.785秒）**。[本体](run2/k1-body.json) |
| time を含む外側 | 終了1、2266.814秒。real/user/sys は2266.80 / 2339.43 / 430.39秒。[起動](run2/k1-started.json)・[外側](run2/k1.json)・[パスを伏せた生ログ](run2/k1.log) |
| 最大常駐量（maximum resident set size） | **取得不能**。`sysctl kern.clockrate: Operation not permitted` が出て最大常駐量は表示されなかった。未取得を0と扱わない |
| メモリの停止・構成 | 終了143はない。Cargo の既定構成、Lean の `-M 12288` を維持し、ビルドは逐次実行した。単一ファイル検査・別の Lean ビルド・K1 の再実行はない |
| ツールチェーン | Rust/Cargo 1.98.1、Lean 4.35.0、Lake 5.0.0-src+eb6cafb、elan 4.2.4、Python 3.9.6、macOS 27.0.1 / arm64。[環境](run2/environment.json)・[七比較実行ファイルと実 CLI の SHA-256](run2/executables.json) |

### 今回の停止の原因

停止した負例は `formal/tests/interval_source_compare.py` の `negative_cases`（215〜228行）である。`observation['warnings']` が空でない最初の入力を選び、警告を空にした観測を `compare_warnings` へ渡し、拒否されることを要求する。

選ばれた入力は `golden:testdata/effects/choose_example.bnt` であり、その警告は `Some(W0501)` の1件だけであった。一方、`compare_warnings`（159〜173行）が照合する診断は `W0401`・`W0402`・`W0404` に限る。この入力では元から対象の警告が0件なので、全警告を空にしても比較結果は空列のまま一致する。負例の選択条件と、比較器が照合するコードの集合が食い違っている。

[読み取りだけの原因確認](run2/diagnose.py)で、保存済みの Rust 観測・manifest・Lean 報告を同じ比較関数へ渡した。W0501 だけの入力では、元の観測も警告を空にした観測も対象警告が0件となり、負例が実際に受け入れられた。対照として `golden:testdata/eval/c12-lazy-deferred.bnt` の W0401（一次位置 `[0,615,616]`）を同様に消すと、`user warnings` の不一致で拒否された。[詳細と元の観測](run2/diagnosis-details.json)・[実行](run2/diagnosis-final.json)・[ログ](run2/diagnosis-final.log)に保存した。新しい Lean 実行や比較用の入力の書き換えは行っていない。

この原因確認は、すべての警告比較が正しいことの証明ではない。今回の停止は、対象外の警告しかない入力を「対象の警告を消す負例」に選んだことによるものと確認できる。負例を削る・期待を弱める・警告を抑える修正は行っていない。修正候補は、負例の選択にも同じ対象コードの集合を使い、対象の警告が実際に消えた入力で拒否を確認することである。比較器・負例を扱う X02b の後続作業の担当と範囲を取りまとめが決めることを提案する。

### 実行できた範囲と未実行

| 対象 | 2回目の結果 |
|---|---|
| Lean の既定ビルド・比較実行ファイル | 成功。sorry の検出なし。これだけで全比較の成功とはしていない |
| 通常網羅性・view 付き独立入力 | それぞれ10,020件・10,028件一致。不一致0、fuelExhausted 0 |
| 幅・名前付き・拡張型・try・第2〜4弾の独立交換 | すべて終了0で先へ進んだ。出力は生ログに保存 |
| Rust coverage 書き出し | 4件成功、失敗0 |
| Rust 全件・独立交換書き出し | 31件成功、失敗0。区間専用4件を別起動し、各1件成功。全件は1,791入力で、旧コア交換の exported 1,372・excluded 419・outside 0を記録。これを六入口の最終成功件数へ転用しない |
| 識別・読者の局所接続 | 195入力・1,381出現・227対象演算。受理された `.point` は1本体。上限0の probe の解析済み0本体を通常解析の成功に足さない |
| 算術・フローと VM | 39件比較、評価除外0。標識出力の R0201 を分ける検査を含む |
| Range と VM | 37件比較、評価除外0。理由付きで事前選別した9本体を比較済みへ足さない |
| 案III のシフト | VM 108行のうち評価関係との比較46行、独立期待値だけ62行（unknownFailure 46・notClosedOrFuel 16）。後者を比較済みへ足さない |
| 実ソース解析の最初の系統 `programs` | 1,403入力の個別報告が生成され、**99,989本体一致、情報を持つ結果78,978本体**。深さ除外0・段の深さ停止0。全Topだけの一致ではない。個別報告の全件照合と警告比較の後、負例検査で失敗したため、この系統の最終要約は未生成 |
| 型検査・全本体・除外の内訳 | 旧全件1,791入力の型検査成功1,402・失敗389、別の独立プログラム1入力成功。合計100,005解析済み本体から理由付き除外16本体を引いた99,989本体を比較。旧全件の未対応71,223本体、Top 21,011本体、Bottom 74,942本体を区別する（分類は重なる）。本体上限・全体上限による未着手・番号未取得・未解析はこの系統では0件 |
| 残る9系統・五 profile の独立解析と評価 | 今回未実行。意図した予算停止を含む後続の manifest 系統も未実行。先行作業の局所結果で代用しない |
| 既存六入口・Log 公開利用の最終照合 | 未実行。先行の通常網羅性・独立交換だけで六入口全体の成功とはしない |
| 最終 manifest・verify | 未実行。成功を表す `interval/manifest.json` はない。実行前の `input-manifest.json` は保存済み |

個別報告の合計は[原因確認の詳細](run2/diagnosis-details.json)に、先行報告と実行環境・容量の要約は[集計](run2/evidence-summary.json)に残した。追加された `testdata/warnings/local-width-intervals.bnt` は、今回の書き出しで9定義・列挙完了として現れた（[入力の要約](run2/width-input-summary.json)）。固定表との最終照合の成功は、未実行である。

### X05R の理由付き除外の照合

四入力の manifest と各 `source-analysis-*.report.json` に、次の定義・件数・理由 `externalType` が一致して残っていることを確認した。除外した元定義とその別本体を消していない。詳細の `bodies` に Rust の観測を、`excluded` に manifest と報告に共通する定義と本体の一覧を保存した。

| 入力 | 除外する元定義 | 元定義 / 別本体を含む本体 |
|---|---|---:|
| `testdata/external/resource` | `.createMany`、`.main` | 2 / 2 |
| `testdata/external/wit-docs-declarations` | `.main` | 1 / 1 |
| `testdata/packages/json-wasm-same` | `.compare`、`.pointers` | 2 / 5 |
| `testdata/packages/wasm-regex-same` | `.compare`、`WasmRegex.Pattern` の `compile`・`isMatch`・`find`・`findAll`・`replaceAll`・`count` | 7 / 8 |
| 合計 | 理由は全て `externalType` | **12 / 16** |

保存済みの全16本体へ本物の `exclusions` を適用し、親の警告候補0、Top・Bottom 以外の整数区間0、独立入力の警告候補0、発見・待ち行列・別本体の列挙完了を確認した。四つの報告の `excludedDefinitions`・`excludedBodies` と、各報告の `inputs[0].excluded` も manifest と一致した。同じ入力に残る定義を元の予算状態で比較した報告と計上記録も ZIP に保存した。除外した本体自体を Rust/Lean 比較済みへ足していない。外部型の四つの改変負例は、今回の停止位置より後なので K1 内では未実行である。X05R の局所負例の成功を今回の実行済みへ足さない。

### 容量・永続の証拠・引用の範囲

[実容量](run2/output-size.json)は次のとおりである。`du` は KiB 単位の実使用量、バイト数はファイルの論理サイズの和である。

| 出力先 | ファイル数 | 論理バイト数 | du（KiB） |
|---|---:|---:|---:|
| `target/interval-diff/x05a-k1-run2-20261027` | 6,753 | **608,212,413** | 607,268 |
| `target/desugar-diff/x05a-k1-run2-20261027` | 1,109 | 2,648,742,041 | 2,611,216 |
| `target/coverage-diff/x05a-k1-run2-20261027` | 5 | 69,623,196 | 68,004 |
| `target/interval-diff` 全体 | — | — | 607,268 |

区間出力は今回の途中停止時点で2,000,000,000バイト以下である。ただし、残る9系統・独立入力・最終 manifest が未生成なので、成功した K1 一回分の容量目標を実測して満たしたとは結論しない。

三出力先の7,867ファイルを[ハッシュ索引](run2/k1-records-index.json)に記録し、7,859ファイルを ZIP（取りまとめがリポジトリの外の `<repo>/work/m012/records/x05a-run2-k1-records.zip` へ移した。gitignore）へ保存して全項目を読み戻した。[保存用の記録器](run2/bundle.py)を用いた。16 MiB を超える再生成可能な入力8ファイルは本文を省き、元の大きさ・SHA-256・`persisted: false`・理由を索引へ残した。報告・ログの省略は0件である。保存時にパスを伏せた1ファイルは、元と保存後のハッシュを分けた。ZIP は73,802,707バイト、SHA-256 は `5aaaffc02becc497da7e34840c5e6330f18dc14f77575e4a369af1e3d88fb1b8`。実行前の入力 manifest も ZIP へ保存した。生ログと要約を target だけに置いていない。

[検査前](run2/source-state-before.json)・[検査後](run2/source-state-after.json)の5,984ソース入力の SHA-256 は一致し、HEAD も同じである。最初の状態の照会は差分なしであり、記録器を作った後の snapshot の status には新しい run2 のみが現れる。以後の差分は x05a の results.md と今回の実行・調査・保管・点検の記録だけである。1回目の節と旧記録を保持し、[旧ファイルのハッシュ](run2/first-run-files.json)も保存した。

引用の判断者は X05a 担当、日付は2026-10-27である。X05b が引用できるのは、この関係状態での**失敗と部分実行の記録**であり、K1 成功や S-X の受け入れではない。入力の一覧とハッシュ、実行した道具の版・ハッシュ、具体的なコマンドと終了状態、対象件数、時間、環境の制限を上記の記録へ残した。別の状態への成功の引用は認めない。修正後の全体起動は、取りまとめが担当と基準を新たに指定する必要がある。

### 作業末の work と最終点検

同じ基準の `scripts/check.sh --level work --base e895627c1d376aa5d31af82e99fea4465f6d6c8b` を、同じ指定の dry-run の後に一度実行した。`--test`・`--only` は付けていない。

| 検査 | 結果と外側時間 | 記録 |
|---|---|---|
| dry-run | 終了0、0.087秒。文書だけの変更で選択0単位 | [起動](run2/work-dry-run.json)・[選択と理由](run2/work-dry-run.log) |
| work 本体 | **終了0、0.087秒**。選択0単位・実行0単位、`selected checks passed` | [本体](run2/work-body.json) |
| time を含む外側 | 終了1、0.114秒。最大常駐量は sysctl の拒否により取得不能 | [外側](run2/work.json)・[生ログ](run2/work.log) |

選択0単位は計画どおりであり、Rust の回帰や K1 の成功の証拠とは分ける。dry-run の42件と本実行の45件の変更数の差は、その間に作った実行記録による。最大常駐量の取得だけを理由に work を再実行していない。work 後は結果・保管・点検の記録だけを更新した。

[最終点検器](run2/audit.py)で、5,984ソース入力の不変、旧33ファイルと1回目の本文の保持、ZIP のハッシュと収録一覧、1,487圧縮入力を含む手元のパスの伏せ方、記録の構文と56リンク、git diff --check を確認した。点検は終了0・1.594秒である。[点検結果](run2/self-review.json)・[起動](run2/audit.json)・[ログ](run2/audit.log)へ保存した。

記録用の原因確認器は、初回に型検査失敗の行にも `input` 欄を要求して止まり、`get` で欠落を扱うよう直した（[初回](run2/diagnosis-initial.json)）。次に詳細 JSON と起動記録の名前が重なったため、詳細の保存名を分けて保存済み出力を読み直した（[記録名の修正](run2/diagnosis-record-correction.json)）。これらは記録用の読み取り器だけの修正であり、K1・Lean・比較器の再実行や修正は行っていない。

### 取りまとめへ戻す範囲

| 残る作業・検査・レビュー・受け入れ | 提案する担当と範囲 | 見込み |
|---|---|---|
| 対象外の警告しかない入力を選ぶ負例の修正 | 取りまとめが X02b の比較器・負例を扱う後続作業へ割り当てる。選択条件を対象コードの集合へそろえ、対象警告の欠落は拒否され、W0501 だけの入力を当該負例に選ばないことを確認する | 不明 |
| 修正の局所検査・指定 work・独立レビュー・受け入れ | 修正担当と取りまとめ。対象警告と対象外警告の混在を含む入力選択を、実ソース・独立期待値の双方と整合させる。期待の緩和や負例の削除で通さない | 不明 |
| 修正後の K1 全体・実容量・件数・manifest の照合 | 取りまとめが担当と新しい基準を指定する。今回未実行の9系統・五 profile・六入口・全件の負例・最終 manifest と verify を含め、全体を新しい出力先で実行する | 今回は停止まで37分47秒。成功までの時間は不明（計画の仮30〜60分） |
| X05b の集約・S-X のレビュー・受け入れ | K1 の成功後に元の永続記録から集約する。今回の部分成功だけでは閉じない | 不明 |

4時間の中断条件には達していない。今回の停止は負例検査の失敗による。Rust・Lean・検査用スクリプト・固定表・入力・期待値は変更していない。private/ とそれを指すリンク、担当の委任、git の変更操作、コミット・取り込み・docs/todo の更新・公開は行っていない。今回の後続の原因確認と記録の点検は保存済み出力の読み取りであり、追加の Lean 実行・短い比較試行・K1 の再実行ではない。

## 取りまとめのレビュー（2026-10-27、2回目）

停止は正当である。`negative_cases` の `userWarnings` の負例は、観測の警告が空でない最初の入力を選ぶが、`compare_warnings` は W0401・W0402・W0404 だけを照合するので、W0501 だけの入力を選ぶと負例が成り立たない。修正の作業 X05S を置き、負例の選択を照合する警告の集合にそろえる（plan.md「計画の変更（2026-10-27、X05a の2回目の停止を受けて）」）。1回目は外部型の列挙未完で止まり、この負例まで進んでいなかった。

2回目の生の記録の ZIP（73,802,707バイト、SHA-256 `5aaaffc02becc497da7e34840c5e6330f18dc14f77575e4a369af1e3d88fb1b8`）は、公開のリポジトリに置くには大きいので、取りまとめがリポジトリの外（`<repo>/work/m012/records/`、gitignore）へ移した。索引・ログ・要約・原因確認は run2/ に残す。以後の K1 の生の記録の ZIP も同じ場所に置き、リポジトリには索引とハッシュを残す。

## 3回目（X05S の後、2026-10-27）

### 結論と関係状態

**3回目の K1 本体は終了0で成功し、X05a の全比較の実行と接続証拠の条件を満たした。** 一つの関係状態で全体を一度実行し、既存六入口、独立入力、全関係定義、Rust/Lean の解析、対象構文の評価関係と VM、Range、案III、最終 manifest の全件・ハッシュ・件数の照合を通した。S-X の集約と独立レビュー・受け入れは X05b と取りまとめへ渡す。

着手: 2026-10-27 02:26:17 JST。終了（検査・保存・点検）: 2026-10-27 03:16:26 JST。所要時間: 50分09秒（[終了記録](run3/session-end.json)）。B_WORK と HEAD はともに `d62dbaa1c9293bd32e3dbb1b65b1efbc90a6d44b`、ブランチは `mod012/X05a`。着手時は未コミット差分・未追跡入力ともになかった。1回目・2回目の本文と記録を保持する。[着手記録](run3/session-start.json)・[旧83ファイルのハッシュ](run3/prior-files.json)も保存した。

AGENTS.md、共通依頼文、plan の前提・内部契約・X01〜X05・X05a/X05b/K1/S-X の検査、X05R/X05S の計画変更と結果、D5/D17/D18/D22、study 9.4、README の設計者の決定、07-03「結果の保存と引用」、二つの全比較スクリプト、X01a〜X04b の申し送りを確認した。rtk と japanese-tech-writing を適用した。言語・Lean の規則を判断し直す作業はない。

実行前の `df -h /` は空き119 GiBであり、20 GB以上の開始条件を満たした（[出力](run3/disk-before.log)・[数値](run3/disk-before.json)）。X04a の局所40.537秒と計画の全体30〜60分を見積もりに使い、追加の短い試行は行っていない。

### 実行・時間・環境

実行場所は `<repo>`。三つの新しい空の出力先を使い、以前の実行を上書きしていない。

```text
CARGO_HOME=<tmp>/benitoite-a01a-cargo
BENITOITE_DESUGAR_DIFF_DIR=target/desugar-diff/x05a-k1-run3-20261027
BENITOITE_COVERAGE_DIFF_DIR=target/coverage-diff/x05a-k1-run3-20261027
BENITOITE_INTERVAL_DIFF_DIR=target/interval-diff/x05a-k1-run3-20261027
```

[記録器](run3/run.py)の `timed k1 scripts/check-formal.sh` を一度起動した。外側は `/usr/bin/time -l python3 <記録器> child k1 scripts/check-formal.sh`、内側は `scripts/check-formal.sh` である。実際の引数と時刻は[起動](run3/k1-started.json)・[本体](run3/k1-body.json)・[外側](run3/k1.json)、パスを伏せた標準出力・標準エラーは[生ログ](run3/k1.log)に保存した。記録中の `python3` は起動に使った解釈器のパスを伏せた表記であり、版は下記に記録した。K1 には dry-run の入口がない。

| 項目 | 3回目の結果 |
|---|---|
| K1 本体 | 2026-10-27 02:26:27.007〜03:10:23.802 JST、**終了0、2636.796秒（43分56.796秒）** |
| time を含む外側 | 終了1、2636.823秒。real/user/sys は2636.81 / 2303.27 / 331.24秒 |
| 最大常駐量（maximum resident set size） | **取得不能**。本体成功後に `sysctl kern.clockrate: Operation not permitted` が出て、最大常駐量を表示しなかった。未取得を0と扱わない |
| メモリの停止・構成 | 終了143はない。Cargo の既定構成、Lean の `-M 12288` を維持し、ビルドは逐次実行した。単一ファイルの検査・別の Lean ビルド・K1 の再実行はない |
| ツールチェーン | Rust/Cargo 1.98.1、**Lean 4.34.1**、Lake 5.0.0-src+5045d00、elan 4.2.4、Python 3.9.6、macOS 27.0.1 / arm64 |

[環境の詳細](run3/environment.json)・[七比較実行ファイルと実 CLI の SHA-256](run3/executables.json)を保存した。Lean 4.34.1 は今回の HEAD の `formal/lean-toolchain` と一致する。過去の結果の4.35.0を今回の版として転記せず、この版の全比較を実行した。計測の制限だけを理由に K1 を再実行していない。[進行記録](run3/progress.jsonl)には出力容量と個別報告の生成数も残した。

### 比較件数と除外・停止

詳細は[全体の集計](run3/evidence-summary.json)と[六入口・独立評価の要約](run3/legacy-and-eval-summary.json)にある。表の件数は対象が異なり、互いに足し合わせない。

| 対象 | 今回の結果 |
|---|---|
| Lean の既定ビルドと七つの比較実行ファイル | 成功、sorry の検出なし。これだけを K1 の成功に代用していない |
| 独立網羅性 | 通常10,020件、view 付き10,028件が一致。不一致・fuelExhausted は0 |
| 幅・名前付き・拡張型・try・第2〜5弾の交換 | 独立入力と割り当てられた Rust 出力を含め、各入口が成功 |
| Rust の書き出し | coverage 4テスト、全件・独立交換31テスト、区間専用四書き出し各1テストが成功。失敗0。全件は1,791入力、旧コア交換の exported 1,372・excluded 419・outside 0 |
| 脱糖 | golden 372＋random 1,000プログラム、定義1,071＋72,778＝73,849件一致。不一致0。旧コアの型検査失敗419入力は成功へ足さない |
| 組み込み表 | 1,372入力、142,092比較、不一致0、未収束0、欠けた組み込み・構築子0。変換できないもの等の内訳は元報告に保持 |
| プログラム網羅性 | 22,483件（match 16,444・束縛6,039）一致。不一致・対象外・fuelExhausted は0 |
| surfaceCheck / surfaceCheckAll と最終対応 | 1,791入力の単独検査と固定 manifest の対応が一致。全体報告は51,758分類（matched 51,738・outOfScope 19・Q11 1）、mismatched・preparationFailure・requiresReview は0。Q11 は所定の置換と一致 |
| Log 公開利用 | `log-standard` の `Log.formatRecord` 直接 call、六入口の成功、corpus・builtins・stdlib・coverage・coverage-program の五つの SHA-256 を照合 |
| 算術・フローの評価関係と VM | 39件比較、評価除外0。標識出力の R0201 を算術の失敗から分けた |
| Range の評価関係と VM | 37件比較、評価除外0。同定・三欄・射影・逆転の優先を比較。事前選別した9本体（parameterOrGeneralCall 3・observationOnly 6）を比較済みへ足さない |
| 案III のシフト | VM 108行のうち評価関係との比較46行、独立期待値だけ62行。後者は unknownFailure 46・notClosedOrFuel 16であり、評価関係と比較済みの46行へ足さない |
| 最終 manifest / verify | 10系統・五 profile・全関係定義・入力と報告のハッシュと件数を照合し、`all inputs, reports, hashes and counts agree` で成功 |

実ソースの通常解析の比較は次のとおりである。全10系統で `rustLeanMatched: true`、深さ除外0・段の深さ停止0であり、情報を持つ結果が0本体の系統はない。

| 系統 | 型検査成功入力 | 比較本体 | 情報を持つ本体 |
|---|---:|---:|---:|
| programs | 1,403 | 99,989 | 78,978 |
| identity | 24 | 198 | 195 |
| manifest/manifest-interval | 15 | 325 | 249 |
| range/interval | 11 | 65 | 65 |
| vm/original | 1 | 39 | 39 |
| vm/instrumented | 1 | 39 | 39 |
| vm/range/original | 1 | 46 | 46 |
| vm/range/instrumented | 1 | 46 | 46 |
| vm/shifts/original | 1 | 108 | 108 |
| vm/shifts/instrumented | 1 | 108 | 108 |

`programs` は旧全件1,791入力と独立プログラム1入力を含む。区間用の型検査成功1,403・失敗389、元定義64,024、全100,005解析済み本体から外部型の16本体を引いた99,989本体を比較した。未対応71,223、Top 21,011、Bottom 74,943を別に保存し、情報を持つ本体78,978を確認した。これらの分類は重なる。本体上限・全体上限による未着手・番号未取得・未解析はこの系統では0件である。

意図的な予算入力を持つ `manifest/manifest-interval` は全347本体、解析済み341、理由付き除外16、比較325、未解析6である。本体上限10件、全体上限による未着手7件を別に保存した。発見10・待ち行列10の本体操作上限、全体駆動1・別本体1の全体操作上限の停止位置が一致した。残る元定義6・未生成本体6を比較成功へ足していない。

| 独立 profile | 解析の比較本体 / 情報を持つ本体 | 評価の比較本体 / 除外 |
|---|---:|---:|
| base | 8 / 6 | 8 / 0 |
| flow | 10 / 8 | 7 / 3 |
| width | 41 / 41 | 41 / 0 |
| range | 7 / 2 | 7 / 0 |
| domain | 108 / 54 | 46 / 62 |

独立解析の除外は五 profile とも0である。評価の除外は解析の深さ除外と区別する。flow の3本体は `M.independent`・`M.lazy` の notClosedOrFuel 2本体と `M.lazy%body:1:0` の embeddedEnvironment 1本体、domain の62本体は上記シフトの未知の境界である。定義名・理由を[要約](run3/legacy-and-eval-summary.json)に保持し、比較済みへ足していない。追加の flow-containers は深さ40での除外1を記録し、所定の fuel 選択で80にして除外0・1本体一致となった。五 profile の初回 fuel はそれぞれ132・292・580・200・2192で成功し、予算は緩めていない。

操作上限0の全列挙用の読者は、所定どおり終了1・matched true・accepted false・比較0件である。これは manifest の列挙の照合だけであり、通常解析の成功件数へ足していない。各系統の集合全体で非 Top の結果を要求し、空・全 Top の個別入力も所定の非受け入れとして区別した。有限の VM 比較を、元ソース全体の意味保存や全入力での一致の証明にはしていない。

### X05R/X05S 後の確認

[除外の確認器](run3/exclusions.py)で今回の生成済み manifest・Rust 観測・解析報告を読んだ。全16本体について親の警告候補0、Top・Bottom 以外の整数区間0、独立入力の警告候補0、発見・待ち行列の完了、manifest と報告の定義・本体・理由の一致を確認した。[除外の詳細](run3/exclusion-details.json)には各本体の元の観測も保存した。

| 入力 | 除外した元定義 | 元定義 / 別本体を含む本体 |
|---|---|---:|
| testdata/external/resource | `.createMany`、`.main` | 2 / 2 |
| testdata/external/wit-docs-declarations | `.main` | 1 / 1 |
| testdata/packages/json-wasm-same | `.compare`、`.pointers` | 2 / 5 |
| testdata/packages/wasm-regex-same | `.compare`、`WasmRegex.Pattern` の `compile`・`isMatch`・`find`・`findAll`・`replaceAll`・`count` | 7 / 8 |
| 合計 | 全て理由 `externalType` | **12 / 16** |

同じ除外は manifest 系統にも残り、他の8系統には除外がない。除外した定義を消す、Top に置き換える、除外した本体を Lean と比較済みへ数える操作はない。K1 内でも candidates・integer・width・independent の四改変負例を拒否した。追加の `testdata/warnings/local-width-intervals.bnt` は9定義・列挙完了・全9本体解析済みとして現れ、固定表との最終照合も通った。

X05S が直した `userWarnings` の負例は10系統すべてで成功した。最初の系統の警告比較38件・親候補19件・独立入力の候補5件を照合した後、負例も通過し、残る9系統・五 profile・最終 manifest へ到達した。今回、Rust・Lean・比較器・固定表・入力・期待値の修正は行っていない。

### 容量・永続の証拠と引用

[実容量](run3/output-size.json)は次のとおりである。バイト数は論理サイズの和、du は KiB 単位の実使用量である。

| 出力先 | ファイル数 | 論理バイト数 | du（KiB） |
|---|---:|---:|---:|
| target/interval-diff/x05a-k1-run3-20261027 | 8,074 | **683,963,047** | 684,868 |
| target/desugar-diff/x05a-k1-run3-20261027 | 3,981 | 2,679,668,234 | 2,650,168 |
| target/coverage-diff/x05a-k1-run3-20261027 | 9 | 69,642,636 | 68,036 |
| target/interval-diff 全体（以前の出力を含む） | — | — | 1,292,136 |

今回の K1 一回分の区間出力は2,000,000,000バイト以下の目標を満たした。最終 manifest は12,063ファイルを列挙し、自身を除く全出力のハッシュを照合した。SHA-256 は `352d37abc00cc6d37878d9bc04a57279e6976b50cefa9d4d620d12ba68c5a5b2`。実行前の入力 manifest は1,220ファイルのハッシュを持ち、比較後も一致した。五 profile・全関係定義の manifest 比較、Log の六入口と五入力ハッシュも同じ最終記録に含む。

[保存器](run3/bundle.py)で三出力先の12,064ファイルを[ハッシュ索引](run3/k1-records-index.json)へ記録し、12,055ファイルを `<repo>/work/m012/records/x05a-run3-k1-records.zip`（gitignore）へ保存して全項目を読み戻した。ZIP は80,046,150バイト、SHA-256 は **`6986e19acfa40abad5507cca1583c7240f417ee96504b58b4ddd4da0e8e4aa9e`**。16 MiB を超える再生成可能な入力9ファイルは本文を省き、元の大きさ・SHA-256・`persisted: false`・理由を索引へ残した。報告・ログの省略は0件。元と保存後でパスを伏せた1ファイルはハッシュを分けた。K1 の生ログも本 run3 に保存し、target の一時的なログだけを引用元にしていない。1 MB を超える生の記録の ZIP を追跡対象へ置いていない。

[検査前](run3/source-state-before.json)・[検査後](run3/source-state-after.json)の5,995ソース入力の SHA-256 と HEAD は一致し、関係するソース・標準ソース・テスト・期待値・生成元/生成物・設定・文書例・交換器の変更はない。以後の差分は本 results.md と run3 の実行・保存・点検の記録だけである。パスは `<repo>`・`<home>`・`<tmp>` に伏せた。具体的なコマンド・構成・ツールチェーンと実行ファイルのハッシュ・件数・除外・停止・時間・環境の制限を上記の記録へ残した。

引用の判断者は X05a 担当、日付は2026-10-27である。X05b はこの関係状態の K1 成功と今回の元記録を引用できる。集約のための記録の更新だけは解析と比較の入力に影響しない。別の状態への引用では07-03に従い、未コミット差分・未追跡入力を含む全入力と道具の差を確認し、影響を説明できなければ全比較を再実行する。1回目・2回目の失敗を今回の成功へ書き換えていない。

### 作業末の work と点検

指定の `scripts/check.sh --level work --base d62dbaa1c9293bd32e3dbb1b65b1efbc90a6d44b` を、同じ指定の dry-run の後に一度実行した。`--test`・`--only` は付けていない。

| 検査 | 結果と外側時間 | 記録 |
|---|---|---|
| dry-run | 終了0、0.095秒。文書だけの変更で選択0単位 | [起動](run3/work-dry-run.json)・[選択と理由](run3/work-dry-run.log) |
| work 本体 | **終了0、0.074秒**。選択0単位・実行0単位、`selected checks passed` | [本体](run3/work-body.json) |
| time を含む外側 | 終了1、0.102秒。real/user/sys は0.09 / 0.04 / 0.13秒。最大常駐量は sysctl の拒否で取得不能 | [外側](run3/work.json)・[生ログ](run3/work.log) |

選択0単位は計画どおりであり、Rust の回帰検査や K1 の成功件数とは分ける。dry-run の41ファイルと本実行の44ファイルの差は、その間に作成した実行記録による。最大常駐量の取得だけを理由に work を再実行していない。work 後は結果と保管・点検の記録だけを更新した。

[最終点検器](run3/audit.py)は終了0・2.370秒で、5,995ソース入力の不変、旧83ファイルと1回目・2回目の本文の保持、ZIP のハッシュと収録一覧、1,627圧縮入力を含むパスの伏せ方、Python・JSON の構文、本文85リンク、`git diff --check` を確認した。[点検結果](run3/self-review.json)・[起動](run3/audit.json)・[ログ](run3/audit.log)に保存した。点検後は終了時刻と点検結果の記述だけを更新した。

| 残る作業・検査・レビュー・受け入れ | 担当と受け渡す範囲 | 見込み |
|---|---|---|
| X05a の独立レビューと受け入れ | 取りまとめ。今回の関係状態・K1 本体終了0・全件 manifest・理由付き除外・容量・永続記録を確認する | 不明 |
| 接続の証拠の集約と S-X のレビュー・受け入れ | X05b と取りまとめ。元の永続記録・ハッシュ・件数を引用し、x05/results.md・改造 results.md・reviews へ集約する。評価の除外と予算による未着手を成功へ足さない | X05b の記録1〜2時間、レビュー・受け入れは不明 |
| 最終関係状態の K2 と公開候補の受け入れ | Z01b と取りまとめ。K1 後の入力・道具・構成の変更を照合し、07-03の全欄で引用できなければ K2 を実行する。候補の release と手動照合は別の担当範囲である | K1 は43分57秒。K2 の実行要否・最終時間は関係状態を確定して判断する |

計画の範囲の変更はない。4時間の停止条件には達していない。Rust・Lean・比較器・検査用スクリプト・固定表・入力・期待値を変更していない。今回の追加は results.md と run3 の記録だけである。private/ とそれを指すリンク、担当の委任、git の変更操作、コミット・取り込み・docs/todo の更新・公開は行っていない。追加の短い比較試行・K1 の再実行・別の Lean ビルドもない。

## 取りまとめのレビュー（2026-10-27、3回目）

受け入れる。K1 本体は終了0で、六入口・独立入力・10系統の Rust/Lean の解析・評価関係と VM・最終 manifest の照合が一つの関係状態（`d62dbaa1`）で通った。最大の系統で比較した99,989本体のうち78,978本体が情報を持つ結果であり、全ての結果が Top であるだけの成功ではない。深さ除外と段の深さ停止は0件である。外部型の理由付き除外は4入力・12元定義・16本体で、除外の条件を満たしている。区間の出力は約0.68GBで、X05R の目標（2GB以下）を満たした。最大常駐量の未取得（サンドボックスの `sysctl` の拒否）は記録の欠けとして残し、K1 の成否に関わらない。生の記録の ZIP（80,046,150バイト）は `<repo>/work/m012/records/` に置き、索引と SHA-256 を run3/ に残した。

## RV-X05 による訂正（2026-10-27）

元の本文・表・取りまとめのレビューは実行時の記録として保持する。以下は RV-X05-response.md の判断に従う訂正であり、3回目 K1 を再実行した記録ではない。

「情報を持つ本体」は従来の非 Top の分類であり、Bottom を含む。3回目とその取りまとめのレビューの件数は、次のように分けて読む。`return` の返す区間は交換・比較しておらず、`return` だけで抜ける本体の正常な継続の成分は Bottom になる。

| 系統 | 非 Top の本体 | うち Bottom | Bottom 以外 | 比較した利用者の警告 |
|---|---:|---:|---:|---:|
| programs | 78,978 | 74,943 | 4,035 | 38 |
| identity | 195 | 192 | 3 | 68 |
| manifest/manifest-interval | 249 | 238 | 11 | 8 |
| range/interval | 65 | 65 | 0 | 6 |
| vm/original | 39 | 39 | 0 | 20 |
| vm/instrumented | 39 | 39 | 0 | 14 |
| vm/range/original | 46 | 46 | 0 | 4 |
| vm/range/instrumented | 46 | 46 | 0 | 2 |
| vm/shifts/original | 108 | 108 | 0 | 54 |
| vm/shifts/instrumented | 108 | 108 | 0 | 54 |

10系統の Bottom 以外の本体は延べ4,049件であり、うち programs は4,035件である。他の7系統にはこの本体がない。比較が空虚でないことは、Bottom 以外の本体に加え、上表の位置まで照合した利用者の警告と、比較済み独立入力の値を根拠とする。Bottom だけで満たせる従来の関門では十分でなかったため、X05T で全体と系統ごとの関門を加えた。

`rustLeanMatched: true` と、除外を含む報告の `matched: true` は途中の assert を通った後の定数である。「各系統の比較器が終了まで走った」という記録として読む。独立の件数の証拠は、個別報告の比較数・manifest の解析済み数から除外数を引いた数・集約の件数の照合である。

外部型で除外した4入力・12元定義・16本体について、「Top・Bottom 以外の整数区間0」は本体自身の値に限る。除外した本体の独立入力355件中14件は Top でも Bottom でもない整数区間を持ち、本体14件は Bottom である。これらの正常値は Lean と未比較で残る。除外を認める根拠は親候補・独立入力の候補がともに0件であり、利用者の警告を落とさないことである。「情報を持つ解析や候補を隠さず」などの表現を、正常値全般が比較済みであるとの根拠に使わない。同じ除外は programs と manifest 系統に現れるが、固有の未比較件数へ二重に足さない。

Lean の版の注: 2回目と X05S の環境の「Lean 4.35.0・Lake 5.0.0-src+eb6cafb」は固定したプロジェクトの版の表記として誤りである。`formal/lean-toolchain` の固定版は Lean 4.34.1 であり、3回目の `formal/` で取得した版は Lean 4.34.1・Lake 5.0.0-src+5045d00 である。3回目の [環境記録](run3/environment.json)を参照する。記録した比較実行ファイルの SHA-256 は一致しており、この版の表記の訂正で比較結果を変えない。以前の版の取得場所を原因と断定しない。

X05T で変更した関門・負例・警告の照合の保存済み出力への適用は [X05T の結果](../x05t/results.md)に記す。比較器の関係状態が変わるため、以前の「関係状態が同じ」との説明を X05T 後へそのまま引用しない。S-X は3回目 K1 と X05T の追加照合を合わせて取りまとめが確認する。最終関係状態の K2 全体は Z01b で実行する。戻り値の区間の比較・外部型の交換・観測入口の機能による分離の検討は、取りまとめが後片付けで docs/todo へ登録する。
