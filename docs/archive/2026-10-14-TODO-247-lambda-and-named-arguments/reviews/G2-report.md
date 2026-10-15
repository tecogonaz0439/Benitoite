### レビューの記録

全体: 計画を外れた弱化や抜けはない。定義（NamesWF が Ty.WF・VarsIn・各宣言の Scoped・V_Fun・V_Prim・V_Op・V_Lam・C_Meth・HasTypeClauses.cons・Def.WellTyped・ImplDecl.WellTyped に入る、Ty.Le は名前の並びの一致を求める、実行は位置）、定理の言明（preservationE・step_soundE・stateTy_iff・網羅性の全定理は旧と字句まで同じ。変わった約 30 件は names の欄の追加か結論の強化か補助の前提の追加）、axiom・sorry・native_decide なし、Coverage は旧と同じ保証、01-12・07-04 は計画どおり、前倒しの補題（R26〜R29）の重なりなし。N7 は Progress.lean の canonical_fn・resume_form を二重定義しないこと。

- 中: NamedRelease/WellFormed.lean の Val.VarsIn（.lam）と Ty.VarsIn（.fn）が NamesWF を混ぜている。そのため StateTyE の Comp.VarsIn・Store.Closed・Cont.Closed や N7 の effect_soundness の初期の前提（Comp.ClosedNoEffVars）が名前の整形式を前提に含む。型付けから導けば冗長だが、それを示す補題がない。design.md の「既存の定理の前提へ『必要な名前は全部正しい』という新たな外部の仮定を足して済ませない」に形の上で反する。修正案: 「HasTypeC・HasTypeV が付くなら項の中のラムダはすべて NamesWF を満たす」補題を示して最終定理の前提の名前の部分を型付けから導く、または NamesWF を VarsIn から外して別の述語にする。
- 低: Typing.lean の V_Fun・V_Prim・V_Op・C_Meth・HasTypeClauses.cons の前提 NamesWF は Program.WellFormed と sig_scoped から導ける冗長な前提。修正案: 前提を消して反転の補題で Scoped から導くか、N34a の写しに「整形式から従う」と書き添える（後者なら formal-rules.md と plan.md の N34a に申し送りを書く）。
- 低: ImplDecl のメソッドは引数の名前を持たず、実装側の名前と型クラスの宣言の名前の一致がコアで検査されない。修正案: N8 以降の表層（NamedSurface の型付けと CheckSoundDicts）で一致を検査すると formal-rules.md か plan.md に明記し、既に N8〜N11 で入っているならそれを確かめて記録する。
- 低: NamedRelease/Model.lean に、呼び出しで名前の違う関数値を渡すと拒否される C_App の否定例がない（例: Reference.update に .lam ["x"] … を渡す）。修正案: 否定例を一つ加える。

### 注意
formal/ で lake build（sorry なし）と scripts/check-formal.sh を通す。定理を弱めない。

## 対応

- 中（VarsIn の名前の前提）: `NamedRelease/Lemmas/Names.lean` で全ラムダ名を型付けから導き、範囲述語との同値を証明した。`EffectSound.lean` の初期状態と `Theorems.lean` の同じエフェクト健全性の保証へ接続し、型注釈の整形式を保持する理由は R35 と `formal-rules.md` に記した。
- 低（宣言名の冗長な前提）: 規則の前提は保持し、`formal-rules.md` に各 `Scoped`・`sig_scoped`・`opSig_scoped` から従うことと、`plan.md` の N34a に写しへの注記を申し送った。
- 低（実装メソッドの名前の一致）: N8〜N11 の表層も実装側の名前を持たず未検査であることを確認し、`formal-rules.md`・`plan.md` の N12・N14 に実名の比較と `CheckSoundDicts` への接続、N15 に独立入力の接続を申し送った（R35）。
- 低（C-App の否定例）: `NamedRelease/Model.lean` に契約名だけが異なるラムダを高階の引数へ渡す呼び出しの否定例と、名前が一致する呼び出しの受理例を加えた。

例の作成時の関門: 守る契約は、型付けと型の包含を経ても、高階の引数の契約名を読み替えないことである。名前を無視した引数の適合を認める退行で否定例が成り立たなくなる。既存の例は `Ty.Le` 単体の不適合と重複名のラムダの拒否を確かめるが、この `C_App` の境界を扱わない。新しい公開 API やテスト専用のフラグは追加しない。名前が一致する同じ型・本体の受理例も示し、別の理由による拒否ではないことを確かめた。

検査: `cargo test -p benitoite --lib` は 1,129 成功、既存の ignore は 21 件。`cargo clippy --all-targets`・`cargo fmt --check`・`formal/` の `lake build`（159 対象）は成功した。追加した補題・定理など 16 件の `#print axioms` は Lean の標準公理の範囲で、`sorryAx` はない。`scripts/check-formal.sh` は終了状態 0、関係する `coverage_export` 1 テストと `desugar_export` 6 テスト、幅付き型の交換形式の Python テスト 4 件も成功した。脱糖は golden 337 プログラム・910 関数、生成した 1,000 プログラム・72,218 関数で一致し、網羅性の差分は 10,020 件一致、組み込み宣言表は 71,914 比較で一致、プログラム内の網羅性は 22,430 件一致、表層は 51,036 件一致した。不一致と準備の失敗は 0、既存の対象外 19 件と q11 1 件は保持した。記録は `target/desugar-diff/run-47847/` と `target/coverage-diff/run-47847/` にある。依頼に従い `scripts/check.sh` と gc-stress の構成の検査は実行していない。コミットせず、`docs/todo/` に触れていない。
