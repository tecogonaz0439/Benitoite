# B1の実装結果

2026-10-18、Codex。B1を完了した。B_WORKは開始時HEADの `5affc20397d85c6ecaa26eca0bfa46ba22e835ed`。開始時の作業ツリーは空である。コミットは作らず、docs/todo/とformal/のソースは変更していない。

## 変更したファイル

- `src/resolve/{builders,lookup,mod,shadow,text,walk}.rs`: ロード済みの標準ModuleIdに結び付ける私有の専用契約表、import別名、注釈付きbind、対象のBindingId、宣言元と捕捉境界を保持する。lambda・lazy・部分適用のcalleeと固定引数・通常節とFail節からの外側参照を、通常値の名前解決より先に拒否する。
- `src/typeck/{builders,calls,generate,mod}.rs`: BuilderKind/BuilderDecl/BuilderOperation/BuilderRefsを通常のTyと別の表に保持する。newを含む引数の対応は既存の個数・ラベル・型の検査を使い、全操作へStateを課す。構築器の束縛と対象を普通のlocals/expr_typesへ書かない。
- `src/ir/desugar/{builders,exprs}.rs`と`src/ir/desugar.rs`: 宣言を既存Referenceのセル、操作を引数の一度の評価→get→純粋な合成→setまたはcopy/長さへ移す。newの初期値のletとappendAllの合成内のletは、Surface.BuilderLowerと同じスコープに閉じる。セルと普通の変数は同じ番号の空間を使う。
- `src/prelude/mod.rs`とdocだけの`StringBuilder.bnt`、`src/diag/codes.rs`、Skill生成部・生成物: StringだけをSTDLIBの末尾へ登録し、E0463〜E0466と、doc・専用表から作る参照・索引・bundleを接続する。通常の型・関数の宣言は偽造していない。
- `tests/{named_arguments,vm_reference_cells,fmt_command}.rs`と`testdata/builders/string.*`: 専用規則、実行・安全点、独立の参照実行器、整形の境界を検査する。
- 設計書01-02・01-03・01-06・01-07・01-12、02-04・02-05・02-06、03-06、07-04、英語リファレンス、Dのdesign/decisions/plan: Stringの実装済みの契約、標準モジュールの一覧、未接続の交換比較と検査の割り当てを反映した。英語リファレンス例には空出力・終了0の期待を明記した。

上のsrc/tests/testdataはすべて `crates/benitoite/` の下である。

## テストの作成時の関門

| 持ち主の境界 | 新しく確認する契約と、既存テストだけでは届かない理由 |
|---|---|
| named_argumentsの公開check（42例） | 通常の型・値への混入、注釈/new、import別名、引数ラベル、State、境界のE0465と二つの補助位置、専用操作のE0466、先行copyと内側newの受理。既存の普通の関数の契約は専用分類を持たない |
| vm_reference_cellsの既存の実行表への一行 | Direct/Requestの両モードでcopyの安定性、UTF-8の長さ、通常引数の評価回数、引数中に追記した後のget、安全点を確認する。Reference.updateの既存例は専用展開を通らない |
| builders/stringのCLI golden | 実際のimport・出力と、VMと独立の参照実行器の一致。VMだけの二つの実行モードの比較では参照実行器を通らない |
| fmt_commandの新規例 | import別名、分類注釈、newと名前付き直接操作を整形後も保ち、CLI checkと再整形を通す。既存例には専用分類の注釈がない |

既存テストのassert・期待値・ignoreは変更していない。テスト専用の本番の差し込み口は加えていない。通常の型情報と別の公開出力は後続の脱糖・交換にも必要な情報である。

## 検査

途中は `cargo check -p benitoite`、`cargo test -p benitoite --test named_arguments string_builders -- --nocapture`、`cargo test -p benitoite --test vm_reference_cells scripts_update_values -- --nocapture`、`BENITOITE_GOLDEN_FILTER=builders/string cargo test -p benitoite --test golden golden_suite -- --nocapture`、`cargo test -p benitoite --test fmt_command builder_annotations -- --nocapture` を関係箇所に限って実行し、最終はいずれも成功した。編集の手順として `cargo fmt` と `cargo run -p benitoite --example gen_skill` も実行した。途中の外側の時間は未計時である。

途中の失敗は、新規コードのITyの引数をIArgで書いたコンパイル誤りと、新規テスト入力の補間・lazy・handleの構文、二引数の部分適用のラベル、同じモジュールの重複importであった。それぞれ実際の型の表現・構文・既存のラベル/importの規則に合わせて直した。既存のテストの期待は緩めていない。

作業末はplanのB1行の枠を一度開始した。最初と補完の両方で、表のcheck.shと同じ基準・指定に `--dry-run` を付け、選択と理由を確認した（終了0）。自動選択の通常単位を確認した上で、再帰の枠を変えたためrelease_stackだけを追加した。

| 枠・対象 | 実行したコマンド | 終了状態 | 外側の時間 |
|---|---|---:|---:|
| 初回の検査枠・work | `scripts/check.sh --level work --base 5affc20397d85c6ecaa26eca0bfa46ba22e835ed --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally,release_stack --test '*'` | 1 | 301.860秒 |
| 初回の検査枠・clippy_all_targets | `cargo clippy --all-targets` | 0 | 15.601秒 |
| 初回の検査枠・heap | `cargo test -p benitoite --no-default-features --features gc-mark-sweep,heap-verify --test vm_reference_cells --test named_arguments` | 0 | 63.080秒 |
| 初回の検査枠・stress | `cargo test -p benitoite --no-default-features --features gc-mark-sweep,heap-verify,gc-stress --test vm_reference_cells --test named_arguments` | 0 | 63.673秒 |
| 初回の検査枠・doc | `cargo test --workspace --doc` | 0 | 4.816秒 |
| 修正後の補完・remaining_work | `scripts/check.sh --level work --base 5affc20397d85c6ecaa26eca0bfa46ba22e835ed --only fmt,tests_related,source_rules,skill_generated,spec_tally,release_stack --test reference_examples --test runtime_builtins --test skill_docs --test skill_examples --test spec_examples --test test_command --test verify --test vm_handlers --test vm_lazy --test vm_reference_cells` | 0 | 178.850秒 |
| 修正後の補完・clippy_all_targets | `cargo clippy --all-targets` | 0 | 10.078秒 |
| 修正後の補完・golden | `BENITOITE_GOLDEN_FILTER=builders/string cargo test -p benitoite --test golden golden_suite` | 0 | 4.883秒 |
| 修正後の補完・heap | `cargo test -p benitoite --no-default-features --features gc-mark-sweep,heap-verify --test vm_reference_cells --test named_arguments` | 0 | 50.559秒 |
| 修正後の補完・stress | `cargo test -p benitoite --no-default-features --features gc-mark-sweep,heap-verify,gc-stress --test vm_reference_cells --test named_arguments` | 0 | 50.080秒 |

初回のworkはlib 1211件成功・21件の既存ignore、通常構成の統合29ターゲットの成功後、reference_examplesで停止した。新規のbenitoite例にoutputブロックがなかったことが原因である。空の標準出力・標準エラーと終了0を明記し、失敗したターゲットから後ろの10ターゲットと、まだ走っていない単位を補完した。通常の全統合は39ターゲットを完了し、release_stackは指定の10件が成功した。通常構成の既存ignoreはそのままである。

最終の照合では、newの初期値とappendAllの合成のletのスコープをLeanの定義へそろえ、newの引数も共通の契約検査へ接続した。変更した専用経路に関係するnamed_argumentsの構築器42例は、上の途中用の直接指定で再確認した（終了0）。最終のclippy、局所golden、heap/stressを表の補完で更新した。heap/stressは各構成でnamed_arguments 19件・vm_reference_cells 2件、計21件が成功した。文書テストはcompile_failを含む17件が成功した。

libと先に通った普通の統合入力は、専用宣言・操作の新しい二つの展開とnewの引数検査を使わないため再実行しない。VM/参照の専用入力と局所特殊構成は修正後の結果で確認する。リファレンス例を第19節の標準ライブラリへ配置し、標準モジュール一覧へ行を加えた最後の文書編集は、実行例のソースと期待を変えていない。formal/の規則を変えておらず、lake buildと全形式化比較は今回実行していない。

## 計画からの具体化と申し送り

R166に、型や普通の宣言を偽造せず引数の対応検査を共有する内部スロット、g/fの部分適用例へ既存規則のラベルを付ける判断、B_WORK、release_stackとclippyの補完を記録した。B1の公開範囲・State・捕捉境界・評価順は変えていない。Leanの定理・公理・Builtins.AssumptionsとVMの値は変更していない。

B2はList/Bytesのdocだけのソース・STDLIB登録・種類別の引数と参照先を接続する。B1はStringの操作だけを公開している。BuilderKindは三種類を表せるが、List/Bytesの専用名・未実装の公開操作は登録していない。B2の継続・失敗/取消・共有の観察と、B3の共有番号・専用情報を持つ交換版12・独立入力との全経路の比較は未実施であり、完了したとは扱わない。Rust側には専用宣言・対象のBindingId・操作・種類・ソース順の通常引数・標準参照先が残っている。交換版の読者はB3でこの表から書き出す。

本番Rust（生成bundleを除く）は追加823行・削除25行、統合テストRustは追加334行・削除0行である。別途、docだけの標準ソースとgoldenの入力・期待・生成物・文書を追加更新した。
