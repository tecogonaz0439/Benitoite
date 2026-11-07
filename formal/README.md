# formal

形式検証の段階 2 の Lean 4 のプロジェクトである。設計書の[コア計算と脱糖](../docs/design/01-spec/01-12-core-calculus.md)の規則を Lean で定義し、篩付きの核 `Benitoite.Release.Refinement` と篩付きの表層 `Benitoite.Release.Refinement.Surface` について、進行と保存・エフェクトの健全性・対象健全性と、脱糖の型の保存（性質 1）を証明する。あわせて、型検査が使う網羅性の判定の手順の健全性と、表層の型付けを計算する検査の関数と必須の判定の受理の健全性を証明し、処理系の判定と型検査の出力をこれらと比べる（段階 E）。規範とする判断と主定理はこの二つの名前空間に置く。既定の import に残す旧 `Benitoite.Release` と旧 `Benitoite.Surface` のモジュールは、篩付きの核への埋め込みの定義域、共有の定義とその依存、区間の入力の構文に限る（[形式意味論と検証](../docs/design/07-quality/07-04-formal-semantics.md)の「01-12 との対応」）。対象、進め方、仮定、01-12 との対応は同章で定める。形式化した規則は、ここの Lean の定義を正とし、01-12 の規則はその写しである。形式化した規則を変えるときは、Lean の定義と 01-12 の写しを同じ変更で直し（判断の理由は改造のディレクトリと 01-12 に書く）、`lake build` が `sorry` なしで通ることを確かめる。

## 検査

```sh
cd formal
lake build
```

Lean の版は `lean-toolchain` で固定している。ツールチェーンは elan が導入する。`lake build` は、証明を省いた箇所（`sorry`）を警告として示す。`scripts/check.sh` の `formal_build` は、この既定ビルドと `sorry` の拒否だけを行う。Rust との接続を含む全比較は、次の独立した入口で行う。`lakefile.toml` は各 Lean プロセスに `-M 12288`（MiB）を指定する。ファイルを一つ検査する `lake env lean` にも同じ上限を付け、Lean のビルドを並行して走らせない。

Lean と処理系の全比較（07-03「差分テスト」）は、リポジトリの根で次のように走らせる。既定の `lake build`、既存六入口（`desugarDiff`・`builtinCheck`・`coverageDiff`・`coverageProgramDiff`・`surfaceCheck`・`surfaceCheckAll`）と `intervalDiff` のビルド、処理系の書き出し、各独立交換と実ソースの比較を順に行う。区間解析では同じ関係状態から実 CLI もビルドし、閉じた対象入力の評価関係と VM の値・失敗・到達を比較する。所要時間は入力とビルドの状態に依存するため、その実行の記録へ残す。

```sh
scripts/check-formal.sh
```

出力先は三つに分ける。`run-ID` は既定ではシェルのプロセス番号を使い、各環境変数で変更できる。

| 出力 | 既定の出力先 | 環境変数 |
|---|---|---|
| 脱糖・組み込み表・プログラム網羅性・表層検査と機能別の交換 | `target/desugar-diff/run-ID/` | `BENITOITE_DESUGAR_DIFF_DIR` |
| 通常網羅性と view の独立入力 | `target/coverage-diff/run-ID/` | `BENITOITE_COVERAGE_DIFF_DIR` |
| 区間の書き出し・独立比較・Rust/Lean 解析・評価関係/VM・全体の manifest | `target/interval-diff/run-ID/` | `BENITOITE_INTERVAL_DIFF_DIR` |

三出力先は、毎回リポジトリ内の新しい場所、または空のディレクトリを指定する。区間の出力先は `target/interval-diff/` の下に置く。実パスで同じ場所・親子になる場所、`..` を含むパス、古い出力の再利用は拒否する。シンボリックリンクを解決した後もこの条件を要求する。幅の独立交換の `target/p3a-gate/width-exchange/` 等、従来の独立検査の保存先も維持する。

区間の四書き出しは identity・manifest・range・vm ごとに逐次実行する。`formal/tests/test_interval_exchange.py` は五 profile（base・flow・width・range・domain）の独立期待値を analyze/eval で比較し、次の10系統をそれぞれ `--rust-dir` から読み、通常解析を照合する。表のパスは区間の出力先からの相対パスである。

| 実ソースの集合 | ディレクトリ |
|---|---|
| 既存の全件と独立プログラム | `programs/`。元の二 corpus の入力名・群・順序を照合して連結する |
| 元 AST と Surface の識別の対応 | `identity/` |
| 全関係定義と予算停止 | `manifest/manifest-interval/` |
| Range の通常解析 | `range/interval/` |
| 算術・フローの元ソースと標識付きソース | `vm/original/`・`vm/instrumented/` |
| Range の元ソースと標識付きソース | `vm/range/original/`・`vm/range/instrumented/` |
| シフトの元ソースと標識付きソース | `vm/shifts/original/`・`vm/shifts/instrumented/` |

独立交換の版は `interval-corpus` 1・Surface 16・走査順1であり、既存の六入口の corpus/sidecar へ解析結果を混ぜない。正常値・警告候補・統合後の利用者向け警告・操作数・最大同時保持・停止位置と分類を Rust/Lean 間で照合し、全関係定義の manifest と未発見・未解析の範囲も確認する。型検査の成功件数、解析の対象外・Top・予算停止と、評価の理由付き除外を分けて読む。空の比較・全 Top だけの一致・解析の深さ除外を成功にしない。

比較の出力は `comparison/` に置く。五 profile の両モードは `profile-manifest.json`、10系統の解析は `real-source-summary.json`、評価関係と実 VM は `vm/vm-summary.json`・`vm/range/range-vm-summary.json`・`vm/shifts/shift-vm-summary.json` にまとめる（いずれも `comparison/` 配下）。シフトの域内と Byte・UnsignedInteger8 の入力は独立期待値による VM の照合として分け、評価関係との一致件数に加えない。Range の三欄・同じ成功値の射影・逆転の優先を含む比較範囲と A1 の限界は [07-04「区間解析の対象構文の評価関係」](../docs/design/07-quality/07-04-formal-semantics.md#区間解析の対象構文の評価関係)に従う。

全比較の最後に `scripts/check/formal_interval.py` が三出力先の全入力・全報告と件数を照合する。区間の出力先の `input-manifest.json` は比較前の入力ハッシュ、`manifest-comparison.json` は独立入力と10系統の全定義の対応、`manifest.json` は実行後の全ファイルのハッシュと比較件数を持つ。manifest 自身はハッシュの一覧から除く。既存六入口の最終照合が成功してから確定し、読み戻して追加・欠落・改変・件数の相違を拒否する。`Log.formatRecord` の公開利用も、脱糖の出力先の `batch3/g2/corpus.json` の `log-standard` に直接の call があることと、`batch3/g2-exchange-results.json` の六入口の成功・入力ハッシュで照合する。

全比較は Rust と Lean の接続を閉じる区切りと最終の関係状態に割り当てる。既定ビルド・独立入力だけの検査・全件を使わない局所比較の成功は、それぞれの範囲の証拠である。全比較の結果を保存・引用するときは、一時的な `target/` のログだけに依存せず、入力一覧・ハッシュ・各入口の件数・除外理由・実行状態を永続の記録へ残す。具体的な割り当てと引用条件は [07-03「実装の規約と静的な検査」](../docs/design/07-quality/07-03-compiler-testing.md#実装の規約と静的な検査)に従う。

定理が仮定する公理は、次のように確かめる。Lean の標準の公理（`propext`・`Quot.sound`・`Classical.choice`）のほかに `sorryAx` などが現れたら、証明が完了していない。一覧は、篩付きの核と表層の主定理（[07-04「証明する性質」](../docs/design/07-quality/07-04-formal-semantics.md#証明する性質)）と、それを支える主な補題（性質 1 の相互帰納、検査器と受理と網羅性の健全性、構築器の葉、交換の入力の準備）である。

```sh
cat > /tmp/axioms.lean <<'LEAN'
import Benitoite
#print axioms Benitoite.Release.Refinement.progress
#print axioms Benitoite.Release.Refinement.preservation
#print axioms Benitoite.Release.Refinement.steps_preservation
#print axioms Benitoite.Release.Refinement.step_sound
#print axioms Benitoite.Release.Refinement.initial_typing
#print axioms Benitoite.Release.Refinement.effect_soundness
#print axioms Benitoite.Release.Refinement.effect_soundness_noLamNames
#print axioms Benitoite.Release.Refinement.step_target_sound
#print axioms Benitoite.Release.Refinement.reachable_target_sound
#print axioms Benitoite.Release.Refinement.reachable_target_sound_event
#print axioms Benitoite.Release.Refinement.Surface.desugar_typed
#print axioms Benitoite.Release.Refinement.Surface.HasTypeQ.desugar
#print axioms Benitoite.Release.Refinement.Surface.HasBlockQ.desugar
#print axioms Benitoite.Release.Refinement.Surface.surface_effect_soundness
#print axioms Benitoite.Release.Refinement.Surface.surface_target_sound
#print axioms Benitoite.Release.Refinement.StandardModel.included_guarantees
#print axioms Benitoite.Release.Refinement.Surface.surface_guarantees
#print axioms Benitoite.Release.Refinement.Surface.linked_main
#print axioms Benitoite.Release.Refinement.Surface.checkProgramAccepted_main
#print axioms Benitoite.Release.Refinement.Surface.Check.checkExprAt_sound
#print axioms Benitoite.Release.Refinement.Surface.Check.checkBlockAt_sound
#print axioms Benitoite.Release.Refinement.Surface.CheckTables.checkProgram_sound
#print axioms Benitoite.Release.Refinement.Surface.CheckAccept.checkProgramAccepted_sound
#print axioms Benitoite.Release.Refinement.Surface.CheckAccept.acceptProgram_sound
#print axioms Benitoite.Release.Refinement.Surface.ScopeSound.productionRules_sound
#print axioms Benitoite.Release.Refinement.Coverage.coverage_sound
#print axioms Benitoite.Release.Refinement.Coverage.coverage_extension_sound
#print axioms Benitoite.Release.Refinement.checkMatchWithView_exhaustive_sound
#print axioms Benitoite.Release.Refinement.irrefutableWithView_sound
#print axioms Benitoite.Release.Refinement.checkMatchWithView_unreachable_sound
#print axioms Benitoite.Release.Refinement.usefulWithView_extension_exhaustive
#print axioms Benitoite.Release.Refinement.builderApply_value_typed
#print axioms Benitoite.Release.Refinement.StateTyE.builder_new
#print axioms Benitoite.Release.Refinement.StateTyE.builder_operation
#print axioms Benitoite.Release.Refinement.StateTyE.builder_error
#print axioms Benitoite.Release.Refinement.StateTyE.builder_progress
#print axioms Benitoite.Release.Refinement.StateTyE.builder_live
#print axioms Benitoite.Exchange.CheckInput.prepare_sound
#print axioms Benitoite.Exchange.CheckInput.prepare_agrees
#print axioms Benitoite.Exchange.CheckInput.prepare_entry
#print axioms Benitoite.Exchange.BuiltinAgreement.standardCheck_sound
LEAN
lake env lean -M 12288 /tmp/axioms.lean
```

主定理の一覧とは別に、独立した小証明と共有の定義の補題を確かめる。これらは主定理の前提と結論に入らない。

```sh
cat > /tmp/side-axioms.lean <<'LEAN'
import Benitoite
#print axioms Benitoite.Checked.ListIndex.checkIndex_failure_iff
#print axioms Benitoite.Checked.ListIndex.checkIndex_projection
#print axioms Benitoite.Checked.ListIndex.checkIndex_success_iff
#print axioms Benitoite.Checked.ListIndex.checkedIndex_get_eq
#print axioms Benitoite.Checked.ListLength.checkLength_invalid_first
#print axioms Benitoite.Checked.ListLength.checkLength_invalid_iff
#print axioms Benitoite.Checked.ListLength.checkLength_outOfRange_iff
#print axioms Benitoite.Checked.ListLength.checkLength_projection
#print axioms Benitoite.Checked.ListLength.checkLength_success_iff
#print axioms Benitoite.Checked.NonEmptyList.nonEmpty_failure_iff
#print axioms Benitoite.Checked.NonEmptyList.nonEmpty_from_to
#print axioms Benitoite.Checked.NonEmptyList.nonEmpty_head_tail
#print axioms Benitoite.Checked.NonEmptyList.nonEmpty_map
#print axioms Benitoite.Checked.NonEmptyList.nonEmpty_success_iff
#print axioms Benitoite.Checked.NonEmptyList.nonEmpty_to_from
#print axioms Benitoite.Checked.Range.erase_make
#print axioms Benitoite.Checked.Scope.erase_makeEndpoint
#print axioms Benitoite.Library.ResultLaws.flatMap_left_identity
#print axioms Benitoite.Library.ResultLaws.flatMap_right_identity
#print axioms Benitoite.Release.Coverage.integer_atom_query
#print axioms Benitoite.Release.Coverage.integer_atoms_partition
#print axioms Benitoite.Release.Coverage.integer_covered_iff
#print axioms Benitoite.Release.Coverage.integer_full_no_other
#print axioms Benitoite.Release.Coverage.integer_interval_bounds
#print axioms Benitoite.Release.Coverage.integer_partition_unique
#print axioms Benitoite.Release.Coverage.integer_shapes_complete
#print axioms Benitoite.Release.Coverage.segments_ends
#print axioms Benitoite.Release.Coverage.segments_unique
#print axioms Benitoite.Release.Integer64Literal.toValue
#print axioms Benitoite.Release.Integer64Magnitude.negValue
#print axioms Benitoite.Release.Integer64Value.toInt_bounds
LEAN
lake env lean -M 12288 /tmp/side-axioms.lean
```

## 状態

既定の `lake build` は、篩付きの核と表層の主定理（上の一覧）を `sorry` なしで検査する。旧 `Core`、旧 `Surface` の判断・検査・定理と、旧 `Release` の判断の主定理とそれだけが読むモジュールは削除した。既定の import に残す旧 `Release` の74モジュールと旧 `Surface` の3モジュールの役割と読者は、[07-04「01-12 との対応」](../docs/design/07-quality/07-04-formal-semantics.md#01-12-との対応)の表に記す。

交換の読者は corpus 16 と、builtins・stdlib・coverage・coverage-program の各 8 だけを受理する（07-04「交換の形式の版」）。七つの実行ファイル（`desugarDiff`・`builtinCheck`・`coverageDiff`・`coverageProgramDiff`・`surfaceCheck`・`surfaceCheckAll`・`intervalDiff`）は、篩付きの検査器・受理・網羅性・脱糖を呼ぶ。手書きの独立入力は次の試験で六入口と `intervalDiff` へ渡す。既定ビルドと独立入力の試験と公理の確かめは Lean 段の証拠であり、`scripts/check-formal.sh` による Rust との全比較の証拠とは区別する。

```sh
python3 -B formal/tests/test_batch2_exchange.py
python3 -B formal/tests/test_batch3_exchange.py
python3 -B formal/tests/test_batch4_exchange.py
python3 -B formal/tests/test_batch5_exchange.py
python3 -B formal/tests/test_named_exchange.py
python3 -B formal/tests/test_extensible_exchange.py
python3 -B formal/tests/test_try_exchange.py
python3 -B formal/tests/test_width_exchange.py
python3 -B formal/tests/test_range_exchange.py
python3 -B formal/tests/test_interval_exchange.py
```

## 構成

| ディレクトリ・ファイル | 内容 | 01-12 の節 |
|---|---|---|
| `Benitoite/Release/Refinement/` | 篩付きの核。構文（`Syntax`）、型付け（`Typing`）、遷移（`Semantics`）、状態の型付け（`StateTyping`）、信頼条件、標準の宣言と組み込みの表のモデル、網羅性（`Coverage`・`CoverageInitial`・`CoverageExtension`）、旧の判断の埋め込み（`Legacy*`） | 「篩を含むコア計算の形式化」から「篩を含む状態の型付け」まで |
| `Benitoite/Release/Refinement/MainStatements.lean` / `MainTheorems.lean` / `MainEffects.lean` | 性質 2・3 と対象健全性の言明と証明 | 確かめる性質 |
| `Benitoite/Release/Refinement/StandardModelApplication.lean` / `SurfaceLibrary.lean` / `SurfaceMain.lean` | 標準の宣言を含むプログラムへの主定理の適用、表層の main についての主定理 | 確かめる性質 |
| `Benitoite/Release/Refinement/Surface/` | 篩付きの表層の構文・型付け・脱糖・性質 1（`Property1*`・`Theorems`）、検査器と健全性（`Check*`）、範囲を具体化する表層（`OpenSurface*`）、Scope の局所解析と必須の判定の受理（`Scope*`・`CheckAccept*`） | 型の情報を付けた表層の構文と型付け、篩を含む表層の検査と受理、Scope の局所解析の節 |
| `Benitoite/Release/` の直下と `Release/Lemmas/`・`Release/Order/` | 旧 `Release` の74モジュール。篩付きの核への埋め込みの定義域、共有の定義とその依存、保持するモジュールの全宣言の依存 | 07-04「01-12 との対応」 |
| `Benitoite/Surface/` | 区間の入力の構文の3モジュール（`Syntax`・`BuilderSyntax`・`FormatSpec`） | 区間解析の対象構文の評価関係 |
| `Benitoite/Exchange/` | 交換の形式の読み書き、篩付きの表層への変換、検査の入力の準備（`CheckInput`）、標準表との照合（`BuiltinAgreement`）、必須の判定の入力（`Observe`） | 07-04「交換の形式の版」 |
| `Benitoite/Interval/` | 区間解析の評価関係・解析・予算と、篩付きの表層との接続 | 区間解析の節 |
| `Benitoite/Scope/` | 操作の対象の範囲の領域と被覆、局所解析の採用定義 | 操作の対象の範囲の領域と被覆 |
| `Benitoite/Checked/` / `Benitoite/Library/ResultLaws.lean` / `Benitoite/Shared/` | 検査済みの値の独立した小モデル、Result の法則の小証明、区間と近似の共有の定義 | 検査済みの値の独立した小モデル、Resultの法則と二引数辞書の具体例 |
| `DesugarDiff/` / `BuiltinCheck/` / `CoverageDiff/` / `CoverageProgramDiff/` / `SurfaceCheck/` / `IntervalDiff/` | 七つの実行ファイル（`lakefile.toml` の `lean_exe`） | |

定義の名前は 01-12 の規則の名前に対応させる（規則 `E-Return` は構成子 `Step.E_Return`、規則 `C-Sub` は `HasTypeCQ.C_Sub`、規則 `K-Let` は `ContTy.K_Let`）。

## レビュー

定義と言明のレビューの依頼と回答は、改造のディレクトリの `reviews/` に置き、改造を終えたら改造のディレクトリと一緒に `docs/archive/` へ移す。これまでの記録は次の場所にある。段階 A・B は `docs/archive/2026-10-09-implement-first-release/formal-reviews/`、段階 C1〜C3 は `docs/archive/2026-10-09-TODO-162-desugar-formalization/reviews/`、段階 C4〜C7 は `docs/archive/2026-10-10-TODO-162-desugar-formalization-phase2/reviews/`、段階 E1・E2 は `docs/archive/2026-10-10-TODO-162-desugar-formalization-phase3/reviews/`。これらの記録に残る ADR・OPEN の番号は、初回リリース版の設計書の写し（`docs/archive/2026-10-09-design-first-release/` の `decisions/` と `open-issues.md`）を指す。

レビューでは、定義が変更の理由と 01-12 の規則の意図と一致すること、01-12 の写しが定義と一致すること、定理の言明が 01-12 の性質と一致すること、仮定が 07-04 に挙げたものに限られることを確かめる。証明の本体は、`lake build` を通ればレビューしない（07-04「レビューと、見つかった誤りの扱い」）。
