# K4: Rangeと共有する公開境界の接続

基準のコミット（B_WORK）と対象HEADは `1bba862b44c13ad78aafeb2273778ebd3a5da637`（K3取り込み後）である。コミットとdocs/todo/の変更は行わない。

## 実装と契約

`prelude/stdlib/Range.bnt`にCheckedIntegerの三欄、checkInteger・minimum・maximum・valueの四つの公開関数、閉じたRangeErrorと手書きShowを追加し、非公式の標準モジュール表へ登録した。逆転した端点を先に返し、その後に両端を含む比較だけで検査する。三入力をそのまま保存し、上端に1を加えない。RangeをScope/Regexの定数拒否表へ追加していない。

01-06の型の保証との境界、03-06のモジュール表とRangeの節、英語リファレンスと実行例を追加した。gen_skillでRangeの参照・索引・埋め込みbundleを生成した。日本語訳と版の切り替えはV1へ残す。

## テストの関門とL1との対応

| 持ち主の境界 | 守る契約と捕まえる退行 | 既存の検査では足りない点 |
|---|---|---|
| CLIのgolden `stdlib/range.bnt` | 両端と中間の成功・逆転優先・上下の範囲外・全保存欄・Show・再検査・Option変換。定数の失敗も実行でき、VMと参照実行器が同じ出力になる | Scopeはポートに0〜65535の制限を持つため、Rangeの符号付き64ビット全域と通常の定数Errorを通らない |
| 公開checkの `range_checked_integer_hides_all_representation_operations` | 外部の構築・更新・パターン・三アクセサ・構築子値化の七例をE0340だけで拒否 | K1の一般のopaqueとScopeだけではRangeの属性・登録の漏れを捕まえない |
| `desugar_export`の `export_batch3_range` | 通常のCall/Result・射影・再検査が対象内に残り、型付き表層と脱糖後のコア型検査へ接続される | 実行結果だけでは交換の対象外への脱落を検出できない |

すべて実際の公開入口を使い、独立した期待値を置く。新しい差し込み口・公開APIの拡大・本番のテスト専用コードは加えない。既存のassertの削除・期待値の緩和・ignoreの追加はない。

L1のIntモデルへの対応は、すべての入力が符号付き64ビットで表現可能であることを条件に、次の独立期待値で照合した。

| 小モデルの性質 | 実装側の入力・期待 |
|---|---|
| make_ok・三入力と射影の保存・erase_make | 0,10,10／0,10,0／0,10,5でOkの全三欄を出力 |
| make_invalidBounds_iffと優先順 | 10,0,5と最大値,最小値,0はInvalidBoundsの二端点を保持 |
| make_outOfRange_iff | 0,10,11／0,10,-1／-10,-1,-11／-10,-1,0でOutOfRangeの全三入力を保持 |
| singleton_ok | -7、および最小値・最大値それぞれの一点区間で三欄が一致 |
| minInteger_endpoint_ok・maxInteger_endpoint_ok | [-9223372036854775808,9223372036854775807]の両端でOk。上端+1を要しない |
| project_minimum/maximum/valueと再検査 | 三射影を使う同一区間への再検査はOk、[0,9]への再検査はOutOfRange、[10,10]への再検査はOk |

これはAPI固有の小モデルに対応する期待値との照合であり、.bnt実装全体のLeanでの証明や本体の全形式化比較を完了したとは扱わない。formal/・主定理・公理・Builtins.Assumptions、ヒープの不変条件、安全点を越える値の保存は変更していない。

## 検査

途中は変更箇所に関係する次の検査だけを実施した。局所検査の外側の時間は未計時である。

- `BENITOITE_GOLDEN_FILTER=stdlib/range cargo test -p benitoite --test golden -- --nocapture`: 最終は0、部品検査を含む2テスト成功。1ケースのCLI二方式・フォーマッタ・VM/参照実行器の差分比較に成功。最初は下書きが存在しないBoolean.toStringを呼びE0303となった。診断を確認するため同じ失敗を生出力で再確認し、Trait.Show.showへ直して成功した。既存テストの期待は変えていない。
- `cargo test -p benitoite --test checked_args range_checked_integer -- --nocapture`: 0、七つの拒否例を含む1テスト成功。
- `cargo test -p benitoite --test desugar_export export_batch3_range -- --nocapture`: 0、1テスト成功。7定義がすべて対象内。

編集の手順として既存CLIのfmtでRange.bntを整形し、`cargo run -p benitoite --example gen_skill`と`cargo fmt`を実行した。

作業末は計画のworkを一度実行し、R156・R162に従ってall-targetsのclippyだけを補完した。workがlib全件・全統合・fmtを含むので、入口の外で重ねていない。

| コマンド | 終了状態・結果 | 外側の時間 |
|---|---|---|
| `scripts/check.sh --level work --base 1bba862b44c13ad78aafeb2273778ebd3a5da637 --test '*' --dry-run` | 0。fmt・lint_default・lib_default・tests_related・source_rules・skill_generated・spec_tallyを選択 | 未計時 |
| 同じ指定（`--dry-run`なし） | 0。libは1211件成功・失敗0・既存ignored 21件。39統合ターゲットは280件成功・失敗0・既存ignored 7件。選択した七単位がすべて成功 | 382.575秒 |
| `cargo clippy --all-targets` | 0。警告なし | 10.291秒 |
| `git diff --check` | 0 | 未計時 |

workは最初の一回で成功した。通常のlintは `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep`、libは `cargo test -p benitoite --lib`、統合は `cargo test -p benitoite --test '*'`、fmtは `cargo fmt --all --check` である。既定のgc-mark-sweep構成を使い、テストのフィルタは付けていない。spec_tallyは既存の未参照の節を表示したが終了0であり、初回リリースの完了条件の未記入はない。特殊構成・formal_build・check-formal.sh・長い対象のみ・全ターゲットのテストは追加していない。

Rustの差分は本番10行追加・削除0行、テスト35行追加・削除0行である。Range.bntは48行、goldenのソースは37行、局所交換のソースは32行追加した。生成参照と結果の記録はこの行数へ含めない。

## stage3へ渡す検査状態

入力の状態・差分一覧・未追跡入力を含む15ファイルの個別SHA-256・未コミットの入力差分のSHA-256・ソース集合の集約ハッシュ・設定と道具の版は [verification-inputs.json](verification-inputs.json) に保存した。変更のない入力は冒頭の基準コミットで固定する。各ターゲットの件数とコマンド・構成・外側の時間は [verification-results.json](verification-results.json) に保存した。元の結果の記録は本書とこのJSONであり、一時的なtarget/のログだけを引用元にしない。

| stage3の対象 | workでの成功／失敗／ignored |
|---|---|
| golden | 2／0／0 |
| declarations | 6／0／0 |
| runtime_builtins | 10／0／0 |
| reference_examples | 1／0／0 |
| skill_docs | 8／0／0 |

判断者と日付はCodex、2026-10-18である。このworkはK1〜K3を取り込んだHEADとK4の全入力を使い、stage3の五対象をすべて実行した。検査後はK4の結果の記録だけを追記し、入力の個別ハッシュと未コミット差分のハッシュが変わらないことを照合した。記録の追記はコンパイラ・標準ソース・golden・文書例・設定の入力を変えない。同じ関係状態ならstage3へ引用できると判断し、重ねて実行しなかった。取りまとめ時に入力が異なる場合は、影響する対象を再実行する。

## 計画との差と申し送り

B_WORKの固定・追加clippy・stage3への証拠の引き渡しはdecisions.mdのR162に記録した。公開API・失敗順・保証の範囲に計画との差はない。stage3のgolden・declarations・runtime_builtins・reference_examples・skill_docsはworkの全統合に含まれる。同じ関係状態での引用は取りまとめが判断する。変更後の関係状態が異なる場合は、該当ターゲットを再実行する。

取りまとめ用の交換の増分は、Range標準ソースの公開関数4・Showのメソッド1・recordの自動アクセサ3、CheckedIntegerのrecord宣言1とRangeErrorのdata宣言1（構成子2）、golden `stdlib/range.bnt`の2定義・match 2箇所、局所交換 `batch3/range.bnt`の7定義・match 1箇所である。局所の7定義はすべて対象内として `target/formal-batch3/k4/` に書き出した。exchange-manifest.json・routing-manifest.jsonの再集計は計画どおり取りまとめへ渡す。
