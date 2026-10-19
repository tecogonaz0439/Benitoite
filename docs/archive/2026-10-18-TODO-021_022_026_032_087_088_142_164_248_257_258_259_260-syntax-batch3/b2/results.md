# B2の実装結果

2026-10-18、Codex。B2を完了した。B_WORKは開始時HEADの `8228def7087134cbb0c15e93ba92b0d62555e831`。開始時の作業ツリーに差分はなかった。コミット、docs/todo/、formal/のソース、VM値、GC本体は変更していない。

## 変更したファイル

- `crates/benitoite/src/resolve/{builders,shadow}.rs`と`src/typeck/{builders,calls,mod}.rs`: List/Bytesの専用契約、明示した通常の要素型、種類の一致、専用宣言ノードを接続した。三種類とも同じ通常値化・捕捉境界・引数ラベル・Stateの規則で検査し、型付きの宣言・操作・参照先を保つ。
- `crates/benitoite/src/ir/desugar/builders.rs`: 空List/Bytes、単一/一括追記、copyと長さを既存のセルと純粋演算へ展開する。引数評価→get→合成→setの順と合成内のletの範囲を保ち、Bytesの単一追記では一要素だけをfromListへ渡す。通常の生存判定と根の保存を使い、手動解放を加えていない。
- `crates/benitoite/src/prelude/mod.rs`とdocだけのListBuilder.bnt/BytesBuilder.bnt、Skill生成部・生成物: 明示importする標準モジュールを末尾へ加え、契約を同じ専用表から生成した。通常型・関数の宣言は偽造していない。
- `crates/benitoite/tests/{named_arguments,vm_reference_cells,verify}.rs`と`testdata/builders/list-bytes.*`: 種類と要素型の正負、捕捉・値化の拒否、実行・安全点・制御経路、合成成功後の更新、CLIと独立の参照実行器を検査する。既存assert・期待値・ignoreは変えていない。
- 設計書01-02・01-03・01-06・01-07、02-04・02-05・02-06、03-06、07-04、英語リファレンスとDのdecisions/plan: 三種類の実装済みの契約、共有するReferenceの意味、交換未接続の範囲、R167と検査の基準を反映した。章と既存見出しの名前は保った。

## テストの作成時の関門

| 持ち主の境界 | 契約と捕まえる退行、既存テストだけでは届かない理由 |
|---|---|
| named_argumentsの公開check（49例） | Listの明示要素型・汎用関数内の型パラメータ、BytesのByte、種類違い、import別名、通常値化と外側捕捉の拒否、内側newと先行copyの受理。Stringの既存表は種類と要素型を検査できない。成功例は独立IR検査と必要な命令検証にも通す |
| vm_reference_cellsの既存の実行表へ4例 | List/Bytesの引数評価と評価後のget、copyした構造とReference要素の共有、先行copyのlambda/lazy捕捉、複数セルとresume/drop・節内new、早期return、Fail、開始を同期した子タスクの取消。既存のセルとStringの例は種類別の合成や、セルを保持する新しい継続を通らない。Direct/Requestの両モードで実行する |
| verifyの公開脱糖出力（4契約） | 上限検査のあるList.append/List.concatenate/Bytes.concatenateの成功結果にsetが依存することと、単一ByteのfromListが一要素だけを使うこと。実行時の上限失敗は全体を停止するため、その後の局所セルを外部から読むテストは作れない。既存のCheckedLen境界テストと、このコアの評価順・データ依存を組み合わせる |
| builders/list-bytesのCLI golden | import別名、List/Bytesの実際の出力、先行copyのlazy捕捉と内側newを含むlambdaを、VMと独立の参照実行器で照合する。VMの二モードだけでは参照実行器を通らない |

テスト専用の本番の差し込み口、上限変更、通常値の公開範囲の拡張は加えていない。大きさそのものを作る新しい長時間テストも加えていない。

## 検査

途中は `cargo check -p benitoite`、`cargo test -p benitoite --test named_arguments list_and_bytes_builders -- --nocapture`、`cargo test -p benitoite --test vm_reference_cells scripts_update_values -- --nocapture`、`cargo test -p benitoite --test verify builder_sets -- --nocapture`、`BENITOITE_GOLDEN_FILTER=builders/list-bytes cargo test -p benitoite --test golden golden_suite -- --nocapture` を関係箇所に限って実行し、いずれも成功した。途中の外側の時間は未計時である。生成・整形のために `cargo fmt` と `cargo run -p benitoite --example gen_skill` も実行した。

途中のコンパイル失敗は、Skill生成部のスライスパターンから得た `&&str` と文字列の比較であり、参照を一段外して直した。作業末の最初のworkはfmt成功後、新規IR検査テストのenumワイルドカードをlint_defaultが拒否して停止した。全バリアントを明示し、古くなるfmtと失敗・未実施の単位だけを補完する。既存のテストの期待は緩めていない。最初と補完のworkは、同じ基準・指定に `--dry-run` を付けて選択と理由を確認した（終了0）。

補完workはlib1211件と先行22統合ターゲットの成功後、named_argumentsの既存ordinary-targetでE0464の欠落を検出して停止した。対象の宣言がない場合のcopyの返り値を早く誤り型にしたため、呼び出しの計画が消え、対象の診断前に戻っていた。対象の誤りを回復用の通常型で保留してラベル・個数の検査後にE0464を出すよう直し、List/Bytesにも通常値のcopy/appendの拒否例を追加した。修正前の既存テストで失敗を確認し、修正後の構築器2テストは成功した。最終の補完はこの専用経路を使う入力に限り、成功済みの全libと通常の先行入力を重ねない。

| Check | Command | Exit | Elapsed (seconds) |
|---|---|---:|---:|
| work | `scripts/check.sh --level work --base 8228def7087134cbb0c15e93ba92b0d62555e831 --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally,release_stack --test '*'` | 1 | 15.760 |
| remaining_work | `scripts/check.sh --level work --base 8228def7087134cbb0c15e93ba92b0d62555e831 --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally,release_stack --test '*'` | 1 | 266.158 |
| remaining_after_target_fix | `scripts/check.sh --level work --base 8228def7087134cbb0c15e93ba92b0d62555e831 --only fmt,lint_default,tests_related,source_rules,skill_generated,spec_tally,release_stack --test named_arguments --test network_faults --test open_062 --test open_062_http --test package_command --test property_library --test random_programs --test reference_examples --test runtime_builtins --test skill_docs --test skill_examples --test spec_examples --test test_command --test verify --test vm_handlers --test vm_lazy --test vm_reference_cells` | 0 | 245.165 |
| clippy_all_targets | `cargo clippy --all-targets` | 0 | 16.433 |
| heap | `cargo test -p benitoite --no-default-features --features gc-mark-sweep,heap-verify --test vm_reference_cells --test vm_handlers --test vm_lazy --test named_arguments --test verify` | 0 | 176.618 |
| stress | `cargo test -p benitoite --no-default-features --features gc-mark-sweep,heap-verify,gc-stress --test vm_reference_cells --test vm_handlers --test vm_lazy --test named_arguments --test verify` | 0 | 176.352 |
| doc | `cargo test --workspace --doc` | 0 | 6.994 |
| builder_golden | `BENITOITE_GOLDEN_FILTER=builders cargo test -p benitoite --test golden golden_suite` | 0 | 2.544 |

最終的に、libは1211件成功・既存ignore21件、通常構成の全統合39ターゲットは成功した。release_stackは指定の10件が成功した。局所heap/stressは各構成でnamed_arguments20件・verify2件・vm_handlers2件・vm_lazy1件・vm_reference_cells2件、合計27件が成功した。文書テストは通常17件とcompile_fail17件の合計34件が成功し、既存ignore1件はそのままである。fmt・二つの対象範囲のclippy・ソース規約・Skill生成物の一致・仕様対応の集計も成功した。最後の専用goldenはStringとList/Bytesの2入力をVMと参照実行器で確認した。

作業末の検査枠の外側の時間は、失敗と補完を含め合計906.024秒である。途中の調査・実装・限定テストの時間は含めない。再実行の範囲はplanの補完行に記録した。libと先行の通常入力は専用操作を使わず、修正した対象診断に依存しない。関係する構築器の正負・VM/参照・特殊構成は修正後の結果で確認した。

本番のsrc（docだけの標準ソースと生成bundleを含む）は402行追加・88行削除、tests/testdataは529行追加・削除0行である。テストを削除・弱化していない。

## 計画からのずれと申し送り

R167に専用の参照先の具体化、上限失敗と更新順の検査方法、lazyの既存の純粋さの規則を記録した。List注釈の走査と種類別の展開で再帰の枠を変えるため、通常workの全単位を保持してrelease_stackを加えた。追加のclippyはR156と同じ扱いである。初回lintの失敗後の補完はplanの検査表にも記録した。

B3には、BuilderClass/BuilderKind.Listの通常要素型、宣言のbindノード、BuilderRefsのsingle/emptyと種類別join、引数のソース順を渡す。corpus12への構築器の書き出し・全読者の切り替え・局所形式化比較はB3の担当であり、B2では成功済みとしない。新しいdocだけの標準モジュールは2件で、通常の関数定義は増やしていない。goldenはbuilders/list-bytesの1入力（mainと内側lambda）を追加した。交換の固定件数を更新するときはこの入力の増分も集計する。日本語訳と最終の移行案内はV1へ渡す。
