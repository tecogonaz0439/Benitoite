# `.02b-closures` の再レビューに向けた公開宣言と補助判断

共通接頭辞は `Benitoite.Release.Refinement.` である。前回の[公開宣言の一覧](02b-closures-public-api.md)に対する修正を示す。今回は本番8ファイルを変更し、新しい本番ファイルはない。[全変更のハッシュ](02b-closures-r2-source-changes.json)は再開時点からの比較であり、B_WORKからの全差分ではない。

| 本番モジュール | 新しい手書きの宣言 |
|---|---|
| [Typing](../../../formal/Benitoite/Release/Refinement/Typing.lean) | `StoreTy.CaptureView`、`LocalCtx.NoBuilders`、`StoreTy.shiftBuilders`、`Comp.BuilderLocFree`、`Arms.BuilderLocFree`、`OpenCodeTy`、`OpenArmsTy` |
| [ClosureTyping](../../../formal/Benitoite/Release/Refinement/ClosureTyping.lean) | `StoreTy.CaptureView.refl`、`StoreTy.CaptureView.shift`、`StoreTy.shiftBuilders_of_wf`、`StoreTy.shiftBuilders_zero`、`LocalCtx.NoBuilders.empty`、`LocalCtx.NoBuilders.localExtend`、`ClosureTy.capture_open`、`ClosureTy.capture` |
| [EffectCover](../../../formal/Benitoite/Release/Refinement/EffectCover.lean) | `Eff.sub_norm_left`、`Eff.sub_norm_right`、`Eff.Sub.bind` |
| [Shift](../../../formal/Benitoite/Release/Refinement/Shift.lean) | `Eff.Sub.shiftV` |
| [TypeShiftContracts](../../../formal/Benitoite/Release/Refinement/TypeShiftContracts.lean) | `Eff.Sub.shiftTypes` |

| 改めた宣言・入口 | 修正 |
|---|---|
| `ClosureTy.mk` | ソースの `ss` と `bindParams Γ ss`、捕捉後の `ss.map cap.closeTy`、未束縛入力を残す `CaptureView`、`OpenCodeTy`、Noneだけの局所文脈を使う。結果・効果・R、両側のDeclaredは保持する |
| `ClosureTy.pure` | `Ψ.WF` を受け取り、元のCQを実行コードの判断に含める。初期ストアは `StoreTy.WF.empty` で満たせる |
| `ClosureTy.annotation` / `ClosureTy.store` | 出力型は同じ。改めた構成子から注釈を取り出し、ソース側を保持したまま実行時のストアの側を拡張する |
| `ContTy.K_Guard` | ソースの `Ψs` と `CaptureView`、`OpenArmsTy` を保持する。guardとbodyは同じソースのストアの見方を使う。`hideBuilders` をguardだけに適用しない |
| `StateTyE.matchRun` | `v = closeVal cap vs` のソースの値の証人を保持し、`match vs arms` を検査する。実行値のGroundとソースの腕の閉性を分ける |
| `HasTypeCQ.C_Handle` / `C_Handle_Fail` | 包含を `Eff.Sub` へ戻す。K_HandleのSubは保持する |
| `HasTypeCQ.shift_values` / `shift_types` / `subst` / `narrow` | 2種類のhandlerの場合を新しいSubの前提で再検査した。substは `Eff.Sub.bind`、narrowは同じ構造上の包含を使う。後二者は型からの再選択で閉じ、ファイルの文字列の変更は不要であった |

OpenCodeTyは11構成子（typed、builderOp、builderLet、letIn、ite、match、use、handle、handleFail、sub、eff）、OpenArmsTyは4構成子（typed、nil、plain、guarded）である。これらは実行コードの検査の補助であり、ソースの型付けの構成子71や、値・計算・状態の構文の数へ加算しない。typedの前提を省いて任意のCQを使うことはできない。ソースのストアが閉じたWFを満たすか、コードが構築器の場所を読まないことを検査する。

完全な型は[照合入力](02b-closures-r2-public-api.lean)と本番の定義を正とする。`#print`の全出力は104,637バイトなので`<tmp>`に保存し、[large-records](large-records.md)にハッシュを残した。98モジュールの生成宣言・非公開の補助も含めた公理依存は[A-L入力](02b-closures-r2-axioms.lean)と[集計](02b-closures-r2-axioms-summary.json)で確認できる。

CQ21場合との接続は次のとおりである。Return/App/DependentApp/Lazy/Escape/Resume/ResumeL/Meth/External/IssuePathBases/CheckAtの11場合は、構築器の場所を直接読む計算の子を持たず、BuilderLocFreeによるtypedを使える。Lazyの本体と、値の関数の本体は、元の規則でbuilderを隠す。残るBuilderLet/BuilderOp/Let/If/Match/Use/Handle/Handle_Fail/Sub/Effの10場合には、対応する10構成子を置いた。したがってOpenCodeTyの件数11はtypedとこの10場合である。OpenArmsTyは元のnil/plain/guardedにtypedを加えた4場合である。
