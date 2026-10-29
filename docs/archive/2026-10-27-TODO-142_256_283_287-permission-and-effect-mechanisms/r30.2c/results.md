# R30.2c: File から Trait への読み込みの費用

## 作業と状態

B_WORK は `42d22f72f0e1719f39d26abb9fa75c95d1b1f2ab`、ブランチは `m013/r30.2c` である。開始時の差分はない。2026-10-29 05:38 UTC に開始した。初回は宣言情報の JSON の範囲未対応で停止した。設計者が R30.2d で編集範囲の拡張と範囲の保持を決定し、停止の原因を修正して検査を再開した。最終W-Rが成功し、担当する実装・検査は完了した。[停止と解決の記録](inventory-blocker.md)、[範囲対応の設計](../r30.2d/design.md)、[再開後の結果](../r30.2d/results.md)を参照する。以下の初回の失敗と計時は履歴として残す。最終の完了検査は末尾の「再開後の完了検査」にまとめる。

`private/`・そこを指すリンク・`docs/todo/` は読まず、状態を変える git 操作は行っていない。Lean・scripts・依存・ツールチェーンは変更していない。初回実装の追跡済みの変更は標準ソース2ファイル、Rust のテスト2ファイル、設計書2ファイルの計6ファイルであった。再開後は R30.2d の出力器・生成道具・検査・文書・生成記録の変更を加えた。[差分](changes.patch)と[行数](diff-counts.json)を保存した。本番の Rust は増減0行、標準ソースは46行移動して差し引き0行、テストは28行追加・2行削除である。

## 方式

`Show[Scope.ScopeError]` と、その実装だけが使う引用・切り詰めの私有関数を `Trait.bnt` へ移す。Scope に残る処理は文字列の引用を使わない。`Trait.bnt` から Scope を import し、Scope から Trait への import を除く。

01-06「型クラス」は、型クラスの宣言元か対象型の宣言元に implement を置けると定める。`typeck/traits/impls.rs` も同じ条件を検査する。01-03「循環する import」は循環を拒否する。Scope は prelude のモジュールだけを使うため、依存を反転しても循環しない。Trait の実装はプログラム全体で有効になるので、呼び出し側の import の順序は変えなくてよい。

比較した案は次のとおりである。

| 案 | 判断 |
|---|---|
| Show と私有の表示関数を一緒に Trait へ移す | 採用。公開宣言・表示アルゴリズム・組み込みの登録を変えずに依存を除ける |
| Show だけを Trait へ移し、Scope に引用処理を残す | 不採用。Scope の私有関数を Trait から呼べず、新しい公開関数や組み込みの追加が必要になる |
| PathIn と ScopeError を小さなモジュールに分ける | 不採用。公開名を維持する別名や登録の追随が増え、今回の小さい修正に必要ない |
| 標準モジュールの解析・型検査をキャッシュする | 不採用。今回の範囲を超える |

## 検査の割り当て

関連する既存の runtime_builtins の Scope 検査を途中に実行する。生成は `cargo run -p benitoite --example gen_skill` を使う。比較器 README の自己検査を一度実行する。作業末は指定の B_WORK に対する W-R dry-run の後、同じ指定を `/usr/bin/time -p` で一度実行する。lib 全件・全統合ターゲット・clippy・fmt などの選択を dry-run と照合する。

`check-formal.sh`・`lake build`・short は実行しない。ヒープの表現・不変条件・安全点を変えないため、追加のヒープ検査は対象外である。依存・ツールチェーンは変更せず、共通依頼文の勧告照合と設計者の「組み込まない」の判断を引き継ぐ。

## 公開名と表示の互換性

`Scope.PathIn`・`Scope.ScopeError` とその六構成子、公開の検査・射影・拡大の宣言と本体を維持した。組み込みの登録、型とエフェクトの規則、File・Http の実装は変えていない。移した私有関数と Show の本体は、`Trait.Show` を `Show` へ、`ScopeError` を `Scope.ScopeError` へ修飾し直しただけである。[照合の台本](validate-compatibility.py)がこの対応を基準版のソースと突き合わせる。

[表示の入力](scope-show.bnt)は、六構成子、空文字列、引用符・逆斜線・改行・NUL・ドル記号・Unicode、引用後2000バイトと入力4096バイトの境目、長い多バイト文字列と制御文字列を含む。通常の関数を経由した `checkPath` と `checkPathIn` の三種類の実行時エラーも表示する。基準版と修正版の19行・10,861バイトの出力は全バイトが一致した。SHA-256 は両版とも `05001ee53014a2ea1e5064fdb5cf283340662ff5c48c086957075bba6e9c41e6` である。[照合結果](show-compatibility.json)、[基準版の出力](scope-show-before.txt)、[修正版の出力](scope-show-after.txt)を保存した。入力の先頭では、既存どおり Scope、Trait の順で import している。

既存の `runtime_builtins::scope_checked_values_preserve_inputs_and_runtime_errors` も成功した。Direct と Request の両実行方式で、保存値・失敗・Show・長さ制限・完成したエスケープと区切りを検査している。既存の振る舞いの期待値と ignore は変えていない。標準ソースと型検査の辞書を照合する既存の `standard_library_sources_and_dictionary_contracts` は、Trait 内63→64件、全体77→78件へ追随した。従来の入力は Scope を読まなかったため、ScopeError の辞書がこの入力でも読まれる分だけ増えた。AST の全実装と型検査の全辞書・各メソッド・上位制約の対応を確認する本体は保ち、件数を緩めていない。

追加は公開 loader の `file_and_scope_do_not_load_standard_traits` 一つである。作成時の四問はテストの直前にも記し、余分な読み込みでは既存の表示テストが失敗しないこと、新しい差し込み口を要しないことを確認した。修正前は `Benitoite.Unofficial.IO.File loaded Trait` で失敗し、修正後は File・Scope の両入力で成功した。

03-06 に実装の配置と依存の向き、Show の一覧を、03-07 に File が Scope を読むことと Trait を読まないことを反映した。Http の宣言・依存は変わらず、03-09 の変更は不要だった。R30.3 と並行する03-09の編集は加えていない。`gen_skill` は再生成したが、公開宣言と説明が同じなので Skill と bundle の生成物に差分はなかった。

私有関数の移動に伴い、`Trait.limited` を名指ししたときは E0303「no member」から E0330「not public」へ変わり、`<benitoite>/Trait.bnt:99` を指す。`Scope.limited` は移動後に「no member」となる。これは私有関数への参照の診断の変化であり、公開の契約は変わらない（[独立レビュー](../reviews/RV-R30.2d.md)）。

## import だけの check の費用

既定構成の最適化したビルドを、同じ通常の `target/` を使って B_WORK、修正版の順に作った。基準版のソースを変更する前に CLI と共通探査を `target/r30.2c/before/` へ保存し、修正版を `target/r30.2c/after/` へ保存した。[ビルドとバイナリのハッシュ](snapshots.json)を残した。新しい `CARGO_TARGET_DIR` は設定していない。

[計時の台本](measure-imports.py)は共通比較器の `execute` と `clean_env` を使う。入力は import 一つと `main` の `return ()` だけであり、空の対照入力も使う。各入力・各版・各計測方式を3回ずつ準備実行し、31回ずつ計時した。各組で版の順を交互に反転し、入力の順も一巡ごとにずらした。CLI と探査は別プロセスの別実行であり、全実行の終了0と診断なしを確認した。探査の errors も全て0である。

環境は macOS 27.0.1 arm64、Rust/Cargo 1.98.1、Python 3.9.6、`BENITOITE_DEV_IO_MODE=direct` である。CPU の取得不能は後述する。計時中にこの担当のビルド・検査は走らせなかった。別ディレクトリの R30.3 のレビューは依頼に記された並行作業であり、計算機全体の無負荷は確認していない。[全標本・コマンド・環境・集計](import-measurements.json.gz)を保存した。最終計時の外側は13.043秒である。

単位は ms、時間は31標本の中央値、IQR は inclusive 法の四分位範囲である。

| import | B_WORK | 修正版 | 差 | 変化率 | IQR（B_WORK / 修正版） |
|---|---:|---:|---:|---:|---:|
| なし | 12.84 | 12.92 | +0.08 | +0.6% | 0.36 / 0.29 |
| `Benitoite.Unofficial.IO.File` | 19.29 | 14.15 | -5.14 | -26.6% | 0.43 / 0.34 |
| `Benitoite.Unofficial.Scope` | 19.09 | 13.85 | -5.24 | -27.4% | 0.43 / 0.42 |
| `Benitoite.Trait` | 17.46 | 19.16 | +1.71 | +9.8% | 0.36 / 0.37 |
| `Benitoite.Unofficial.Network.Http` | 20.48 | 20.51 | +0.03 | +0.1% | 0.44 / 0.29 |

File の短縮は5.14 msであり、修正版の空入力との差は1.22 msである。R30.1 の既存記録12.57 msに対しては1.58 ms高い。ただし、その記録は今回と同時の交互測定ではない。File は引き続き Scope の検査・型の宣言を読むため、その費用は残る。Trait だけの利用には、Scope と ScopeError の表示を読む1.71 msの追加費用がある。この差は両版のIQRの和より大きい。Http はもともと Json 経由で Trait を読み、Scope も読むため、依存の向きだけが変わる。Http と空入力の小さい差は今回のばらつきの内側である。

追加費用は Trait を直接 import する利用者だけに限られず、Trait を import する次の標準モジュールを使い、従来は Scope を読まなかったプログラムにも及ぶ。対象は `git grep -n '^import Benitoite.Trait' -- crates/benitoite/src/prelude/stdlib` の全5件である。レビューアの独立測定は各組31回の交互計測の中央値（ms）であり、上の担当の測定とは別に示す。

| Trait を import する標準モジュール | レビューアの B_WORK | レビューアの修正版 | 差 | Scope の読み込み |
|---|---:|---:|---:|---|
| `Benitoite.Unofficial.Json` | 18.66 | 20.05 | +1.39 | 新たに読む |
| `Benitoite.Unofficial.Json.Codec` | 未測定 | 未測定 | 未測定 | 新たに読む |
| `Benitoite.Unofficial.Csv` | 18.22 | 19.64 | +1.42 | 新たに読む |
| `Benitoite.Unofficial.Range` | 未測定 | 未測定 | 未測定 | 新たに読む |
| `Benitoite.Unofficial.NonEmptyList` | 未測定 | 未測定 | 未測定 | 新たに読む |

Trait から Scope を読むため、これらを使うプログラムも新たに Scope を読み、Json は +1.39 ms、Csv は +1.42 ms 遅くなる。残る3件も同じ依存による追加費用の対象だが、時間は実測していない。既に別の依存から Scope を読むプログラムに、この追加費用を重ねて見込まない。設計者はこの影響範囲を知ったうえで手当てを採った（2026-10-29）。測定と判断の根拠は[独立レビュー](../reviews/RV-R30.2d.md)、再現の入力と出力は [rv-probes](../r30.2d/rv-probes/) にある。

共通探査の段別時間も、各版31回の交互計測の中央値である。単位は ms。表の各欄は「B_WORK → 修正版」を示す。

| import | 読み込みと解析 `load_parse` | 名前解決 `resolve` | 型検査 `typeck` | 同じバイト列の再解析 `reparse` |
|---|---:|---:|---:|---:|
| なし | 1.836 → 1.838 | 0.890 → 0.885 | 5.572 → 5.554 | 1.428 → 1.424 |
| File | 2.705 → 2.065 | 1.345 → 1.030 | 10.613 → 6.428 | 2.257 → 1.620 |
| Scope | 2.588 → 1.961 | 1.261 → 0.963 | 10.439 → 6.260 | 2.151 → 1.545 |
| Trait | 2.401 → 2.594 | 1.169 → 1.283 | 9.278 → 10.527 | 1.995 → 2.187 |
| Http | 2.788 → 2.817 | 1.400 → 1.419 | 11.517 → 11.581 | 2.353 → 2.369 |

File では型検査が約4.18 ms減り、読み込みと解析も約0.64 ms減った。探査は公開 loader の読み込みと lex/parse を一つの区間で測る。reparse は同じ読み込み済みバイト列の別の解析であり、load_parse や CLI の時間へ加算しない。CLI と探査の差から未計測の区間の原因を断定しない。CPU プロファイルや新しい short は今回の依頼範囲で取得していない。

## 探査

Rust の公開の型・構造体・関数形式を変えていないため、`tools/bench/compare/timing_probe.rs` の追随は不要だった。比較器 README の自己検査を一度実行し、39件成功・失敗0件、終了0、外側385.558秒だった。[ログ](compare-selftest.log)・[計時](compare-selftest.json)を保存した。自己検査が開始版 `6124775788579e60530f55fb85570f26ef7fa900` と B_WORK の両方の探査をビルド・実行したことは、[ビルドの証拠](probe-builds.json)に残した。他の互換検査用の版も自己検査の通常の対象である。short の標本採取や性能判定は行っていない。

## 初回実装の検査のコマンドと結果

表はリポジトリの根から実行した対象コマンドである。`run-record.py <ラベル> <対象コマンド>` が `/usr/bin/time -p` の内側で子を実行し、その子の戻り値を `check_exit_code` として直接記録する。外側の単調時計と time の real/user/sys も分けて残す。`time -l` は使っていない。正確なラッパーの起動形式・構成・時間・最大常駐量は、各ラベルの JSON と `*-time.log` に保存した。

| 対象 | 対象コマンド | 終了・外側の秒 | 記録 |
|---|---|---:|---|
| B_WORK の release ビルド | `cargo build --release --locked -p benitoite` | 0・122.447 | [ログ](build-before.log)・[計時](build-before.json) |
| 修正版の最終 release ビルド | 同上 | 0・30.128 | [ログ](build-after-final.log)・[計時](build-after-final.json) |
| loader の退行テスト、修正前 | `cargo test -p benitoite --lib modules::tests::file_and_scope_do_not_load_standard_traits -- --exact --nocapture` | 101・76.149 | [ログ](loader-before.log)・[計時](loader-before.json) |
| loader の退行テスト、修正後 | 同上 | 0・11.924 | [ログ](loader-after.log)・[計時](loader-after.json) |
| 既存の Scope の実行検査 | `cargo test -p benitoite --test runtime_builtins scope_checked_values_preserve_inputs_and_runtime_errors -- --exact --nocapture` | 0・44.904 | [ログ](runtime-scope.log)・[計時](runtime-scope.json) |
| Skill の再生成 | `cargo run -p benitoite --example gen_skill` | 0・43.235 | [ログ](generate.log)・[計時](generate.json) |
| 比較器の自己検査 | `env PYTHONPYCACHEPREFIX=target/bench/pycache python3 -m unittest discover -s tools/bench/compare -p 'test_*.py'` | 0・385.558 | [ログ](compare-selftest.log)・[計時](compare-selftest.json) |
| release の探査の準備 | `env PYTHONDONTWRITEBYTECODE=1 python3 docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/r30.2c/snapshot.py before`、同じ台本の `after` | 0・3.672 / 1.459 | [基準版](snapshot-before.json)・[修正版](snapshot-after-final.json) |
| 表示の最終照合 | `env PYTHONDONTWRITEBYTECODE=1 python3 docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/r30.2c/validate-compatibility.py` | 0・0.384 | [ログ](compatibility-final-source.log)・[計時](compatibility-final-source.json) |
| 最終の交互計時 | `env PYTHONDONTWRITEBYTECODE=1 python3 docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/r30.2c/measure-imports.py` | 0・13.043 | [ログ](import-timing.log)・[計時](import-timing.json) |
| 辞書の集計の失敗の再現 | `cargo test -p benitoite --lib typeck::traits::tests::standard_library_sources_and_dictionary_contracts -- --exact --nocapture` | 101・0.238 | [ログ](dictionary-before.log)・[計時](dictionary-before.json) |
| 同じ集計の追随後 | 同上 | 0・5.556 | [ログ](dictionary-after.log)・[計時](dictionary-after.json) |
| 修正後の W-R dry-run | `scripts/check.sh --level work --base 42d22f72f0e1719f39d26abb9fa75c95d1b1f2ab --dry-run` | 0・0.154 | [選択](work-recheck-dry.log)・[計時](work-recheck-dry.json) |
| W-R 初回 | `scripts/check.sh --level work --base 42d22f72f0e1719f39d26abb9fa75c95d1b1f2ab` | 1・118.882 | [ログ](work.log)・[計時](work.json) |
| W-R の辞書の集計修正後 | 同上 | 1・151.187 | [ログ](work-recheck.log)・[計時](work-recheck.json) |

dry-run は既定 lib 全件、全統合ターゲット、examples を含む clippy、fmt、ソース規約、Skill 生成物、仕様の集計を選んだ。`spec_examples`・`reference_examples`・`coverage_export` も全統合ターゲットに含まれる。Rust の直接の lib 全件をこの入口と別に実行していない。追加の無視・対象縮小・時間制限の緩和は行っていない。

二回目は fmt・clippy・lib 全件に成功し、42統合ターゲットのうち6ターゲットまで実行した。lib は1,392件成功・22件無視、統合は84件成功・2件失敗・7件無視であり、合計1,476件成功・2件失敗・29件無視である。[対象別の集計と未到達の一覧](test-counts.json)を保存した。`declarations` の二つの JSON 出力の検査で停止したため、残り36統合ターゲット、ソース規約、入口による Skill 生成物の照合と仕様の集計は未実行である。途中に単独で実行した Scope の実行テストと Skill の再生成を、これら全体の成功の代わりにはしない。

## 最大常駐量

W-R 初回の補助値は原値2,472,296,448バイト、2,357.765625 MiB（約2.303 GiB）であった。辞書の集計を直した後の W-R は原値1,544,355,840バイト、1,472.8125 MiB（約1.438 GiB）であった。`getrusage(RUSAGE_CHILDREN).ru_maxrss` で検査の子を待った後の値であり、子孫の最大値を表す補助値である。並行する全プロセスの常駐量の合計ではない。

外側の `/usr/bin/time -p` は初回と再検査で別々に残した。初回の real/user/sys は118.87/564.31/22.91秒、再検査は151.18/656.75/29.95秒である。どちらも check.sh 自身の終了1を子の戻り値で直接記録しており、ラッパーの終了から成功と推測していない。

## 初回の失敗と修正

- loader の新しい退行テストの修正前の終了101は意図した失敗であり、ログを[修正前](loader-before.log)・[修正後](loader-after.log)に残した。
- 最初の記録ファイルをシェルの here-document で作る試行は文字コードの SyntaxError で失敗し、続く記録器の起動もファイル未作成で終了2となった。ファイルを書き込む前の失敗であり、apply_patch とコピーに切り替えた。
- 記録器へコピー元の表示名が残ったため、最初のビルドの JSON の `time_command` の表示を実際の `r30.2c/run-record.py` へ訂正した。実際の起動・終了状態・時間は変えていない。
- 表示の照合と snapshot の補助記録が、同じラベルの検査の計時 JSON と衝突した。証拠用の名前を分け、表示の照合を再実行した。snapshot は保存したバイナリ・ソースのハッシュと初回の標準出力を再照合して証拠を回復した。回復の最初の試行は探査のコンパイル警告も辞書として読んで失敗したため、状態名で始まる行だけを読むよう直した。
- 最初の計時の後の `git diff --check` は Scope の末尾の余分な空行で終了2となった。空行を除き、release ビルド・snapshot・表示照合・計時を最終のソースで取り直した。最初の計時は `initial-import-measurements.json` と `initial-import-timing.*` に別保存し、最終の表と合算しない。
- 初回の W-R は lib 1,391件成功・1件失敗・22件無視の時点で終了1、外側118.882秒だった。失敗は標準ソースと辞書の照合の固定件数63であり、単独実行でも実測64との差を再現した。Trait と全体の件数を64・78へ直し、単独実行で成功を確認した。変更は `#[cfg(test)]` の既存の単体テストだけであり、計時した Scope・Trait のソースと release の意味は変わらない。この失敗により fmt・clippy・lib の証拠が古くなり、統合テスト・ソース規約・生成物・仕様集計は未到達だった。全て再確認を要するため、同じ W-R の指定で再検査した。初回の[ログ](work.log)・[計時](work.json)と、辞書の[再現](dictionary-before.log)・[修正後](dictionary-after.log)を残した。
- 二回目の W-R は既存の宣言情報の JSON の検査2件で終了1となった。期待値を変えて通す修正はせず、出力側と受け取り側を調べ、許可範囲外の対応が必要なことを[停止の根拠](inventory-blocker.md)へ記した。
- CPU 名の `sysctl` は実行環境の制限で拒否された。CPU 名は依頼に示された Apple M4 であり、今回の自動照合では取得不能である。計時の環境記録に終了と理由を残した。

## 初回停止の条件・ずれと再開

BNT の公開名、Show の出力、型とエフェクトの意味を変える修正は行っていない。Lean の規則・主定理・Assumptions・保証の変更も不要であり、これらの停止条件には該当していない。停止した理由は、追加で判明した JSON の退行を範囲情報を保って直すには、編集許可の外まで変更が必要になることである。W-R 本検査は当初の一度の実行に加え、固定件数の失敗を直した後に必要な再検査を一度行った。どちらの失敗も残し、完了扱いにしていない。

設計者は2026-10-29に、Trait の import だけで追加される約1.71 msの費用を含めてこの方式を採り、宣言情報を情報を失わないJSONへ拡張することを決定した。編集範囲を広げた R30.2d で停止原因を修正した。short・Rust/Lean の全比較・公開候補の照合は担当と時期を変えず、取りまとめと後続が受け持つ。

基準版のソースを target 外へ展開しておらず、target 外の一時ビルドも作っていない。自己検査の一時入力は TemporaryDirectory の終了時に片付く。`target/` 内の通常のビルド、比較器の標準キャッシュ、二つの保存バイナリは残した。[片付けの記録](cleanup.json)のとおり、外部の片付けは残っていない。

## 初回実装の時間

最初の時計は2026-10-29 05:38:14 UTC（14:38:14 JST）であり、停止後の記録の最終確認を含めた外側は約25分である。最終確認の日時は [final-validation.json](final-validation.json) に残した。能動時間は概算18〜20分であり、厳密な分離計時は行っていない。ビルド・検査中にも記録と調査を行ったため、表の経過時間を能動時間へ単純に加算しない。

主な別計測の外側は、初回 release ビルド122.447秒、比較器の自己検査385.558秒、最終の交互計時13.043秒、W-R 初回118.882秒、再検査151.187秒である。回答待ちはない。1〜3時間の見込みと3時間の上限は超えていない。停止の理由は時間ではなく、編集範囲外までの宣言情報の対応が必要になったことである。

## 再開後の完了検査

設計者は2026-10-29に、今回のShowの配置変更を採り、宣言情報へ範囲を保持する対応を加えると決定した。R30.2dでJSONの版を4へ上げ、RustとPythonの出力・検証・意味ハッシュ・表示をそろえた。範囲の変数をTopに置き換えず、通常の関数を一覧から除いていない。元の二つの宣言情報の検査、標準署名の独立期待値、File・Scope・Httpを加えた例のpreview/check、範囲変数を持つカスタム署名の拒否、deriveの全50件の自己検査が成功した。

再開後のW-R初回はclippyのenum分岐二箇所で終了1、外側3.810秒だった。分岐を明示して直した二回目はgoldenで終了1、外側299.032秒だった。後者はTraitへ加えたimportと空行によるE0701のsecondary位置のずれである。Showの原文の位置を独立に照合し、期待値だけを2行・35バイト追随した。診断コード・文言・primaryは保った。これらの失敗と修正も[再開後の結果](../r30.2d/results.md#初回の失敗と修正)へ残した。

| 完了対象 | 最終の結果 |
|---|---|
| W-R | `scripts/check.sh --level work --base 42d22f72f0e1719f39d26abb9fa75c95d1b1f2ab`。check自身の終了0、外側467.756秒 |
| 既定lib全件 | 1,392件成功、失敗0件、22件無視 |
| 全42統合ターゲット | 465件成功、失敗0件、10件無視。初回未到達の36ターゲットも全件実行 |
| fmt・clippy・ソース規約・Skill生成物・仕様集計 | 全て成功。Skillとbundleに追加差分なし |
| Python関連 | 構文検査、source-migrate 6件、try-actions-migrate 10件に成功。W-Rが選ばないderiveの自己検査は別に全50件成功 |
| 計時と最大常駐量 | `/usr/bin/time -p` のreal/user/sysは467.75/1472.88/29.15秒。getrusageの補助値は1,423,327,232バイト、1,357.390625 MiB |

[dry-runの選択と理由](../r30.2d/work-final-dry.log)、[W-Rの全ログ](../r30.2d/work-final.log)、[checkの戻り値・外側の時間・最大常駐量](../r30.2d/work-final.json)、[全対象と旧未到達一覧の照合](../r30.2d/test-counts.json)を最終の根拠とする。追加のignore、対象の縮小、時間制限の緩和は行っていない。途中の失敗ログを成功へ置き換えたり、各回の時間を合算したりしない。

R30.2cの実装・計時と今回のJSON対応・検査を完了し、[停止原因は解決済み](inventory-blocker.md)である。公開名・Showの出力・型とエフェクトの意味、Leanの定義・主定理・Assumptionsは変えていない。取りまとめによる独立レビュー・受け入れ、取り込み後のshort、Rust/Lean全比較、公開候補の照合は従来の担当と時期を保つ。Gitの状態を変える操作は行っていない。再開後の見込みと実績、片付けは[R30.2dの結果](../r30.2d/results.md)にまとめた。
