# L2 の実装結果

## 基準と変更

- 基準 B_WORK・開始時 HEAD: `f5deca1f7ff7e92a9c6899465db944cd0f6d663e`（`git merge-base HEAD san_benito`）。2026-10-19、作業開始時の差分はなかった。コミットと docs/todo/ の変更は行っていない。
- `Release/Coverage.lean` に integerBounds・integerAtoms・integerCovered・integerHasOther を加えた。min64 と max64+1 を含む全域内の最小区間を分割したまま使い、未被覆の区間がある場合だけ先頭に other を残す。境界の計算は Int であり、max64+1 を有界定数へ戻さない。
- 最小区間への所属の一意性（integer_partition_unique）、被覆の同値（integer_covered_iff）、小区間か other への所属の存在と一意性（integer_atoms_partition）、全域の被覆と other の不要性との同値（integer_full_no_other）、列挙の完全性（integer_shapes_complete）を証明した。shapeStep_integer と shapes_interval_cover を新しい列挙へ接続した。
- 既存の補題 U、網羅性・束縛・非選択・実行時の非選択・構成子追加後の網羅性の系、表層 checker は、定義と主定理の前提・結論を変えずに新しい列挙を使う。公理と Builtins.Assumptions は追加していない。CoverageExtension・CoverageTypes・Order・CoverageRuntime は既存の定義と証明で接続でき、変更を要さなかった。
- `Release/CoverageIntegerExamples.lean` に独立した期待値を持つ10例を加え、Benitoite.lean の既定 import に含めた。全域・重なり・両端と内側の一点の穴・ガード・覆う分岐の説明・複数欄と入れ子の相関・リスト・将来の構成子・燃料切れを確かめる。
- 01-12・02-05・07-04 に実装済みの Lean の規則を写し、現在の Rust が常に other を残すことも明記した。formal/README に追加定理の公理確認一覧を加えた。構文・標準ソース・診断表は変更せず、生成 Skill の入力に変更はない。

## テストの関門と既存の期待値

新しい例の持ち主は Coverage の公開する判定の入口である。旧例だけでは検出できない全域時の other の残り、境界のあふれ、一点の穴の欠落、欄どうしの相関の喪失、ガード行の無条件被覆、燃料切れの誤受理を検出する。準備と期待値は判定から生成せず、既存の例の補助を再利用し、本番のテスト専用の入口は加えていない。入力は小さい固定例であり、深い再帰・長いリスト・大きな共有構造を加えていない。

既存の irrefutable の表のうち、Integer の全域 `[-9223372036854775808, 9223372036854775807]` だけを false から true に変えた。これは L1 が旧結果で保持し、L2 が変更するよう plan に指定された意味の変更である。等値比較を保ち、Character の二つの期待値は変えていない。既存の assert の削除、期待値の緩和、ignore の追加はない。

## 検査

途中は関係する Lean の局所対象だけをビルドした。最終の局所成功は `lake build Benitoite.Release.CoverageIntegerExamples Benitoite.Release.Lemmas.CoverageRuntime`（Coverage と CoverageExtension を含む）である。それ以前に Coverage・CoverageExtension・CoverageRuntime の三対象と、独立例の対象も局所確認した。外側の時間は未計測である。補題を編集中の構文・パターン・簡約の誤りはこの局所ビルドで修正し、期待値を緩めず通した。

完了検査は次の work を一度だけ実行した。Rust のソースは変更していないため、lib 全件・clippy・fmt・特殊構成は追加していない。scripts/check.sh の全体と check-formal.sh は実行していない。

```sh
scripts/check.sh --level work --base f5deca1f7ff7e92a9c6899465db944cd0f6d663e --only formal_build,spec_examples,spec_tally --dry-run
scripts/check.sh --level work --base f5deca1f7ff7e92a9c6899465db944cd0f6d663e --only formal_build,spec_examples,spec_tally
```

| 検査 | 終了状態と結果 | 外側の時間 |
|---|---|---|
| 上記 dry-run | 0。指定した3単位だけを選択 | 0.011秒 |
| 上記 work | 0。spec_tally の自己検査と集計、spec_examples 7件、formal/ の既定 lake build。sorry の警告なし | 67.884秒 |
| formal/ で `lake env lean /private/tmp/batch4-axioms.lean`（開始前／終了後） | ともに0。README の従来一覧40件の公理出力が完全一致 | 0.673秒／0.796秒 |
| formal/ で `lake env lean /private/tmp/batch4-integer-axioms.lean` | 0。L1 の境界3件も L1 終了時の保存出力と完全一致。対象の定義は今回変更していない | 0.789秒 |
| formal/ で `lake env lean /private/tmp/batch4-coverage-axioms.lean` | 0。追加補題9件と構成子追加後の網羅性1件。propext・Classical.choice・Quot.sound の範囲を保つ | 0.789秒 |
| 既存定理の言明・文書リンク | Coverage の既存63件の言明に変更なし。変更した現行文書と formal/README の相対リンク193件の参照先が存在 | 未計測 |

work の全出力と時間は [work.log](work.log)・[work-timing.json](work-timing.json)、選択は [dry-run.log](dry-run.log) に保存した。公理確認の正確な入力と出力は [axioms.lean](axioms.lean)・[axioms-before.txt](axioms-before.txt)・[axioms-after.txt](axioms-after.txt)、[integer-axioms.lean](integer-axioms.lean)・[integer-axioms.txt](integer-axioms.txt)、[coverage-axioms.lean](coverage-axioms.lean)・[coverage-axioms.txt](coverage-axioms.txt) に保存した。toolchain は `leanprover/lean4:v4.34.1` である。開始前の40件と、終了後の40+3+10件に sorryAx やプロジェクト独自の新しい公理はない。

spec_tally は既存の仕様節のテスト参照不足も表示するが、未記入の初回リリースの完了条件はなく、終了0である。見出しの追加・改名はしていない。最後の `git diff --check` も終了0である。既存の例を削除せず、テスト行数は新規ファイルの94行増である。Coverage 本体の差分は +195/-30行（既存例の期待値とコメントの置換を含む）である。

work 後は結果記録と公理確認の入力・出力だけを追記した。検査した Lean と仕様例の入力は同一である。

## 計画との対応と申し送り

- 範囲・保証の変更はない。分割の具体化と Lean 先行時の写しの扱いは decisions の R142 に記録した。
- L3a はこの既定 import 全体が通る状態を基準に進められる。新たな公理・仮定、未証明の宣言、既定 import から除いたファイル、未採用の証明案はない。
- T1 は integerBounds/Atoms の小区間の列と順序、全域時だけ other を除く条件を Rust へ移し、coverage_export と独立交換を接続する。今回の成功を Rust の全比較の成功とはしない。独立交換の版13/5と正式な件数照合は計画どおり L7 および後続の Rust 作業へ渡す。
