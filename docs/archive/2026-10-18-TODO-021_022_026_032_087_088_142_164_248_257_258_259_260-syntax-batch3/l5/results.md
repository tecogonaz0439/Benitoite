# L5 実装結果

2026-10-18、Codex。L5を完了した。基準B_WORKは `234006521fef80e881e9cba982e9e128c6a8ff40`（L4c取り込み後の開始版）。開始時の作業ツリーはクリーンだった。コミットとdocs/todo/の変更は行っていない。

## 変更

- `Surface/BuilderSyntax.lean`・`Syntax.lean`・`Typing.lean`: Expr.builderOp、通常引数と結果の契約、E_BuilderOpを追加した。専用位置はΔから読み、通常引数の効果にStateを加える。専用名を普通のlocalとして読める規則は加えていない。congrΔと旧構文のBuilderFreeによる七判断の意味保存も接続した。
- 新規`Surface/BuilderLower.lean`・`Lemmas/BuilderLower.lean`と`Desugar.lean`・型保存の読者: 引数を一度ソース順に評価してからgetし、純粋な合成が成功してからsetする。三種類・四操作の型保存を、Refs.Ok・整列・通常引数の帰納の結論からbuilderOp_desugar_typedで導いた。copy/lengthも同じ既存のReferenceへ写す。clean・scopedとfillBuildersの型保存をそろえた。
- 新規`Surface/BuilderCheck.lean`と`Check.lean`・CheckCompute/CheckSound群: 全参照の宣言・種類・署名の範囲・型引数・制約・辞書と行の不在・具体化後の型と単一Failを有限検査し、Refs.Okへ接続した。strict/relaxedの支持保存とstrictの健全性に通常引数の帰納を追加した。公開11件・単一Fail・programと性質1の言明を維持した。
- `WellFormed.lean`・`CheckSupport.lean`・`CheckPredicates.lean`・`SurfaceCheck/Walk.lean`・`Batch.lean`: 参照先と通常引数の範囲/支持、述語の新しい場合、引数の走査と組み込み参照の収集、診断用のタグを追加した。`Surface/Examples.lean`の二つの既存の補助証明へ新構成子の矛盾の分岐を足した。既存の例の命題・期待値は保った。
- 新規`Surface/BuilderExamples.lean`と正式import: 三種類×四操作×strict/relaxedの24通り、異なる5種類の拒否、引数内の追記の一度の評価とgetの順序、純粋な合成の失敗時のセル保存を8個のexampleで確認した。
- 01-12・07-04の写しを更新し、「専用操作の規則と脱糖の補題まで。宣言はL6」を明記した。実装時の具体化と全読者の補完をdecisions.mdのR151・R152へ記録した。

[規則・全読者・関門K・test-auditの照合](rule-review.md)を保存した。Rust本体・Rustテストの差分は0行。形式化ソースは追加677行・削除102行（新規4ファイルを含む）。既存のassert削除、期待値の緩和、ignoreの追加は0件である。

## 言明と定義の意味・公理

[contracts-comparison.json](contracts-comparison.json)は、公開の健全性11件・単一Fail2件、programの6件、性質1と表層のエフェクト健全性の計21言明と、Input.Sound・BuilderInvariant・Def/ImplDecl/Program.WellTyped・Program.WellFormedの6定義が開始版と一致することを記録する。ScopedとAtomsInは新構成子を参照先・通常引数も含めて扱う。七判断の新規則を除く旧規則全体と、Check.leanの新分岐/importを除く旧処理全体は一致する。公開の保証へ構築器を除外する前提を加えていない。

既存の例7ファイルは開始版とバイト単位で一致する。残るExamples.leanは二つの補助証明へ各一行を加えただけであり、その二行を除くと開始版と一致する。例の命題・期待値や、補助定理の前提と結論は変えていない。

[README全30定理の公理依存](axioms.txt)は、[開始版に含まれるL4cの出力の写し](axioms-start.txt)とL1のaxioms-before.txtにバイト単位で一致する。[入力](axioms.lean)もREADMEの一覧とL4cの入力に一致する。[新補題等15件](internal-axioms.txt)は別に確認した。いずれもpropext・Classical.choice・Quot.soundの範囲内で、sorryAx・Lean.ofReduceBool・独自公理はない。[公理の比較](axioms-comparison.json)を保存した。開始版の保存出力は比較用であり、今回のビルド結果の代わりに引用していない。

## 検査

計画指定の作業末の三単位を一度実行した。formal_buildの失敗を修正した後は、古くなったformal_buildだけを再実行した。完全な引数、作業ディレクトリ、終了状態、外側の時間は[check-times.json](check-times.json)を正とする。Dは本改造のディレクトリである。

| 検査 | 終了状態・外側の時間 | 結果 |
|---|---|---|
| `scripts/check.sh --level work --base 234006521fef80e881e9cba982e9e128c6a8ff40 --only formal_build,spec_examples,spec_tally --dry-run` | 0、0.011秒 | [指定した三単位を選択](work-dry-run.txt) |
| 同じ指定から`--dry-run`を除いたwork | 1、44.181秒 | [spec_tally自己検査・集計は成功。仕様例7件成功・失敗0・ignore0。formal_buildは既存の補助証明2件で制限時間](work.txt) |
| `scripts/check.sh --level work --base 234006521fef80e881e9cba982e9e128c6a8ff40 --only formal_build --dry-run` | 0、0.010秒 | [修正で古くなった単位だけを選択](formal-retry-dry-run.txt) |
| 同じ指定から`--dry-run`を除いたformal_build | 0、0.785秒 | [既定のlake build成功・sorryなし](formal-retry.txt) |
| `lake env lean <D>/l5/axioms.lean`（formal/） | 0、0.696秒 | 全30件の依存が開始版と一致 |
| `lake env lean <D>/l5/internal-axioms.lean`（formal/） | 0、0.656秒 | 新規・接続補題15件が標準三公理の範囲内 |
| `git diff --check`、規則・文書・前提の読み取り照合 | 0 | 差分、対応に問題なし |

最初のformal_buildでは、Surface.ExamplesのnoReturnWithoutTargetとresume_requires_bindingがE_BuilderOpの分岐を持たず、Leanのwhnfで200000 heartbeatsに達した。形の相違による矛盾の分岐を追加し、命題・期待値と制限時間を変えずに対象モジュールの成功を確認した（R152）。仕様例と集計は修正で古くならないため再実行していない。リンク時には既存環境の`/usr/local/lib`不在の警告があったが、実行ファイルの生成は成功した。

途中は`lake build`でBuilderLower、型保存、BuilderCheck、CheckSound、CheckProgramSound、Theorems、SurfaceCheck.Batch、BuilderExamplesとその依存対象に限定した。型の明示、空の行引数の明示、参照先のcoverage viewの一般化、Scoped/AtomsInの分解、具体例の宣言の欄と構文の修正で局所ビルドを閉じた。途中の外側の時間は未集計である。rtk proxyはOperation not permittedで起動できず、スキルのフォールバックに従って通常のコマンドを使った。

Rustは変更していないため、Rust全lib・全統合・clippy・fmt・gc-stress・check-formal全体は実行していない。構文の章・標準ソース・診断表には変更がなく、gen_skillの再生成は不要である。

## 計画からのずれと申し送り

R151は、四操作を共通の一規則で表すこと、新規ファイルの分割、参照先の型付けの補助をdeclarationsFor viewへ一般化すること、新構文に対して偽になる無条件のBuilderFreeの一時補題を除くことを記録した。R152は最終検査で見つかった既存の補助証明の全読者の補完である。公理、Builtins.Assumptions、主定理の前提と結論、公開の保証、検査の割り当ては変えていない。

次はL6。Block.builderBindを、通常の型と専用分類を分けたまま接続する。BuilderRefs.check/check_soundとForRefs、builderOp_desugar_typed、既存のBuilderInvariantとfillBuildersの補題を使える。専用操作の通常引数は同じΔ、捕捉境界は空Δのままである。公開の空Δでの任意の専用操作の拒否はbuilderOp_empty_rejectedで示した。現段階では専用宣言を持たず、構築器を作るプログラムは構成できない。L6の完了時に01-12と07-04の中間状態の一文を消す。コアの捕捉禁止、専用宣言・handle・保存継続を含む有限実行、交換版12とRustとの接続は後続作業へ残す。
