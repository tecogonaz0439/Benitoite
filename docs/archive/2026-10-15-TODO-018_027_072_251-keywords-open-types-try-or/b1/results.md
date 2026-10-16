# B1 Lean の die の構文と脱糖の定義

## 実装前の定義・言明の自己確認

開始時の HEAD は `cdd0cdc27914a55b0bfd72c8dd07b7ed7b776cbf`、作業ツリーは clean だった。design.md「Lean の定義と証明」「脱糖とコード生成」、R3・R8・R14〜R16、P2 の差分案を現在の Surface と照合した。

`Expr.tryResultDie t ok err dict show exit input message` と `Expr.tryOptionDie t someCon noneCon exit input message` を直接の構文として追加する。t は成功型であり、囲む関数の戻り値の型ではない。既存の早期リターンの二つの場合と型付け規則は変更しない。辞書は既存の DictEv、表示はメソッド参照、終了は既存の PrimName である。構文を持つだけで辞書や参照の正しさを仮定せず、その型・純粋性・標準の exit との対応の受理条件は B2・B3 に残す。

脱糖は入力を一つの let へ移し、成功側は中身を返す。失敗側は説明（あれば）、原因、exit[T](1) の順で let を組む。Result の原因は辞書のメソッドを失敗値に適用した計算、Option は固定の文字列である。説明は元の環境で脱糖してから入力とパターンの束縛の下へ移す。Result の辞書も同じく移し、説明を束縛した場合は失敗値と辞書をさらに一つずらす。挿入する let の中でもラムダの局所束縛は保護する。原因と説明の計算は残すが、ホストへの報告の情報はコアの外側である。

Scoped と AtomsIn は成功型・辞書・入力・任意の説明を全て検査する。SurfaceCheck の走査も入力と説明を辿り、説明には R=None と String の期待型を渡す。新しい場合を必ず抜ける文と判定しない。checker は両場合を明示的に拒否し、その拒否から健全性の既存の全場合を保つ。新しい HasType の規則がないので、HasType の導出を辿る Scoped・Invariants・型保存の証明や、型の ShiftClean/SubstClean の言明は変更を要しない。

この確認は実装者の自己確認である。所定の外部レビューと設計者の合意は未了であり、R48 に従って引き継ぐ。

## test-audit の作成時の関門

1. 主となる境界は Lean の desugarExpr と、Scoped・AtomsIn・checker の公開入口である。独立した期待コアで評価順、失敗側だけの計算、自由変数と辞書の移動、ラムダの局所束縛を確認する。
2. 捕まえる退行は、説明を成功側や入力より前へ出すこと、Show を説明より先に呼ぶこと、辞書や説明を捕獲すること、Option に辞書を要求すること、新しい子を走査から落とすこと、新しい構文を型規則なしで受理することである。
3. 既存例は return 型の try しか持たず、説明・Show・exit への新しい展開を検査できない。脱糖の既存の独立例と checker の既存の入力表を拡張し、Rust に同じ準備を重ねない。範囲条件は具体的な正負の入力で確認する。SurfaceCheck の走査には、分類に使うノード列と期待型を独立に比較する例を置く。これは脱糖の例では届かない、説明の走査漏れと R の持ち越しを検出する。
4. Rust の公開範囲・本番フラグ・テスト用の差し込み口を増やさない。Lean の新しい構文と補助は後続の型規則と交換形式の接続に用いる。

これは未接続の機能の追加であり、既存の不具合の修正ではない。既存の assert・例・期待値・ignore・対象内件数・除外理由は変更しない。利用者向けの診断の変更はない。

## 変更の範囲

| ファイル | 変更 |
|---|---|
| `formal/Benitoite/Surface/Syntax.lean`・`Desugar.lean` | 二つの die の場合、説明・原因・終了の失敗側を組む `dieFailure` と実際の脱糖 |
| `formal/Benitoite/Surface/WellFormed.lean`・`CheckSupport.lean` | 新しい場合の成功型・辞書・入力・説明を辿る範囲条件 |
| `formal/Benitoite/Surface/Check.lean`・`CheckPredicates.lean`・`CheckSoundControl.lean` | 先行構文の明示的な拒否と、追加した場合についての既存の健全性の維持。型付け規則と受理は追加しない |
| `formal/Benitoite/Surface/Examples.lean`・`CheckExamples.lean` | 四つの独立した期待コア、範囲の正負の例、説明の有無と両入力型の拒否の表 |
| `formal/SurfaceCheck/Walk.lean` | 入力と説明の走査、説明の String の期待型と R=None、両構文のノード列の独立例 |
| `docs/design/01-spec/01-12-core-calculus.md`・`07-quality/07-04-formal-semantics.md` | 実装した先行モデルの写しと未接続の範囲の明記 |
| `decisions.md`・この記録 | R48、自己確認、test-audit の関門、検査結果、後続への引き継ぎ |

Rust・Exchange・六入口の入力一覧と版・標準ライブラリ・診断の表は変更していない。Skill の再生成が必要な生成元にも変更はない。Lean の実装・補助証明は 75 行追加、独立例は 119 行追加、削除はともに 0 行である。テストを削除・弱化していない。コミットと docs/todo/ の変更は行っていない。

## 検査

実行前に検査の内容と見込みを報告した。依頼に従い `scripts/check.sh`（dry-run を含む）と gc-stress は実行していない。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 成功。1,162 passed、既存の ignored 21、73.81 秒 |
| `cargo test -p benitoite --test spec_examples --test skill_docs` | 成功。15 passed、2 suites、3.41 秒 |
| `cargo clippy --workspace --all-targets` | 成功、指摘なし |
| `cargo fmt --all --check` | 成功 |
| `formal/` で `lake build` | 成功。162 jobs。最終の Lean のツリーでも check-formal の先頭で成功 |
| `bash scripts/check-formal.sh` | 成功、終了状態 0。coverage_export 2 件・desugar_export 17 件、交換形式の Python 4＋12＋22 検査と最終の六入口の照合を含む |
| 主要四定理の `#print axioms` | 成功。`desugar_typed`・`surface_effect_soundness`・`Check.checkCasesSound`・`CheckTables.checkProgram_sound` は `propext`・`Classical.choice`・`Quot.sound` のみ |
| `git diff --check` | 成功 |

最初の `lake build` では、走査の Option の型推論と拒否の健全性の証明の `intro` の個数で失敗した。型注釈と式の書き方、導入する引数の個数を直した。範囲の独立例の `by decide` は Decidable を合成できなかったため、同じ命題を定義の簡約で証明した。いずれも形式化の表現の都合であり、規則・定理の前提・結論・期待コアを弱めていない。公理の確認の初回は最後の宣言の名前空間を誤記して失敗し、実際の `CheckTables` を指定して全件を再確認した。新しい axiom・sorry・admit・native_decide はない。

### 六入口の件数と分類

最終の検査の出力は `target/desugar-diff/run-17923/` と `target/coverage-diff/run-17923/` にある。ログは `target/desugar-diff/run-17923/b1-check-formal.log` に保持する。corpus・型表・網羅性の版は 9/3/3 のままである。

| 入口 | 確認した結果 |
|---|---|
| desugarDiff | golden 968 定義＋random 72,778 定義＝73,746 定義が一致。定義の不一致・対象外・除外は全て 0。プログラムは golden matched 349・excluded 386、random matched 1,000・excluded 0 |
| builtinCheck | 対象 1,349 入力、72,468 比較、不一致・非収束 0 |
| coverageDiff | 閉じた境界 20＋random 10,000＝10,020 件と、view 付きの境界 28＋random 10,000＝10,028 件が一致。不一致・燃料切れ 0。最終段で独立入力の識別子と件数も manifest と照合 |
| coverageProgramDiff | match 16,417＋binding 6,036＝22,453 件が一致。不一致・対象外・燃料切れ 0 |
| surfaceCheck | 全 1,735 入力の単一入口の結果が固定 manifest と一致。既存の個別の失敗は理由を含めて完全一致 |
| surfaceCheckAll | matched 51,645・outOfScope 19・q11 1。不一致・準備失敗・lazyRestriction 0。対象外と q11 の全入力・定義・理由も manifest と完全一致 |

開始時の二つの manifest を一切変更せず、1,735 入力・73,746 定義・22,453 網羅性入力の識別子・分類・件数を照合した。新しい対象外理由はなく、対象内件数を下げていない。契約の破損 3 件、hole/pipe の破損 6 件、named export の破損 6 件と、外部の標準型の view の欠落も意図した理由で拒否した。交換形式の Python 4＋12＋22 検査も全て成功した。書き出しには 555.84 秒、脱糖の比較 26 秒、組み込みの比較 17 秒、網羅性の比較 1 秒、表層の全件検査 19 秒、最終照合 192 秒を要した。

## 計画との差と申し送り

所定の外部レビューと設計者の合意を先行させる順序は未充足であり、R48 に記録した。自己確認はその代替とせず、B2 の型付け規則の接続より先にオーケストレータ側で済ませる。型付き表層へ場合を加えるために必要な checker の拒否・全場合の健全性と SurfaceCheck の走査を同じ変更に含めた。構文・脱糖の内容と公開の受け渡しに、それ以外の計画との差はない。

B2 は新しい HasType の二場合と型保存を加え、説明を C・hideConts Γ・R=None・非末尾位置で純粋な String として検査する。Result の Show の辞書・メソッドと exit の参照の整合性も検査し、囲む戻り値 R を限定しない。B3 は現在の明示的な拒否を正式な受理とその健全性に置き換える。B4 で Exchange と corpus 10 へ接続する。説明と Show の評価回数・報告の採用は、後続の実行検査でも確認する。`scripts/check.sh` と gc-stress は依頼どおりオーケストレータへ引き継ぐ。
