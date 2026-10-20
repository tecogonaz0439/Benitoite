# 未採用の型付けの試行

`typing-draft.patch` は、今回の正式なソースに対して適用する未採用の差分である。既定ビルドを通した完成版ではない。ファイルは typing-draft-files.txt の五件であり、適用前の既定ビルドが今回の区切りである。

## 試した内容と局所で通った範囲

- C_BuilderLet は kind.contents の Ty.WF と、Γ の none・Δ の some kind を先頭に追加した本体の型付けを前提とする。C_BuilderOp は kind.contents の Ty.WF、LocalRef.HasKind、通常引数の型付けを要求し、通常効果を空とする。
- LocalTyping を Rename より前から使うため、StoreTy.Sub の定義を Typing へ移し、LocalTyping の import を Typing に替える。包含の定義自体は同じである。
- HasTypeCQ.rename と分岐・節は、対象の局所環境と LocalRenOk を通常の RenOk の後に受け取る。対象の既定値は元の表、LocalRenOk の既定の証明は空の表用である。通常の再帰には hL、通常束縛には extend、専用束縛には builder を渡す。lam/lazy/節では空の表用の既定値を使う。値の公開の rename の型は変えない。
- 計算の store と q_mono に新しい二場合を加える。
- LocalScope の二場合は型付けの分類から Allowed を導き、builderLet の body へ depth+1 を明記する。値の自由な局所参照の不在もこの新規則のもとで局所ビルドが通った。

`lake build Benitoite.Release.Lemmas.Rename`、続く `lake build Benitoite.Release.LocalScope Benitoite.Release.Lemmas.NoFailContext` の両対象、最後の `lake build Benitoite.Release.LocalScope` が成功した。最後の LocalScope の修正前に複数対象の実行で NoFailContext だけが成功し、その後に LocalScope を修正して局所で成功を確認した。Rename の HasFailureClause.rename の hL が未使用という警告が一件残る。これらの途中の時間と全出力は保存していない。

## まだ通らない読者と次の順

1. Inversion の not_builderLet/not_builderOp は新規則の下では偽なので、再証明しない。inv_builderLet/inv_builderOp を導入し、既存の逆転には専用項の不可能な構文の場合を明記する。既存の期待値や主定理を弱めて置き換えない。最後に試した Inversion は inv_meth の場合分けと旧 not_builder の不足・heartbeat で失敗した。
2. SubstTyping は通常の SubstOk に加えて LocalSubstOk を受け取り、対象の Δ も変えられるようにする。通常値の捕捉境界の置換は空 Δ 同士の系である。instantiate の中間の一般化は、Δ.extend n から Δ へ instLocalSubst n を通す形にする。実行中の空 Δ の入口は保つ。
3. Irrelevant.subst_congr の計算の補助は、任意のρ/ηの一致を結論できなくなる。分類された位置での局所の像の一致を前提にする。値の場合は捕捉境界の空Δから閉じる。
4. Regularity は builderLet で none を加えた EnvWF、builderOp で kind.contents の WF から op.result の WF を使う。OuterC は種類の WF の単調性を通す。型代入は List の要素型を Δ 内の種類にも写す必要がある。Type* と TySubstMain/StoreFix の全読者へ接続する。
5. 新しい逆転と new の σ/ρ の保存から Progress/PresMain を接続する。正式なソースにある E_BuilderNew/E_BuilderOp/E_BuilderErr の不可能性による枝は、この段階で置き換える。builderApply_total_typed と builderApply_closed は、既に正式なソースで証明済みである。
6. 保存継続・Fail/escape/release と有限接頭辞の local_steps_invariant を全主定理へ接続し、既存の表層・モデル・01-12/07-04 をそろえる。表層は L4a まで Reference 脱糖を保つ。

主定理の前提・結論、公理、Builtins.Assumptions を変える必要があれば依頼の停止条件に従う。保存した差分の状態には未証明の宣言、sorry、公理追加、既定 import の除外はないが、全読者の型検査は未完了である。
