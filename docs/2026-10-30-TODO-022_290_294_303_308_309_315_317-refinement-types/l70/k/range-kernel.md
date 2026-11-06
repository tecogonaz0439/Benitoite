# 利用者の関数の範囲パラメータに要る核の変更（群 K への署名の案）

2026-11-06。群 D の実装担当による案であり、レビュー済みでも実装済みでもない。設計者が案 A（核を広げる）を選び、核の変更は群 K が受け持つ（取りまとめの指示）。数は B_WORK `49f17471442229baf668e7b1f7b6dac8151c6dcf` の `formal/Benitoite/Release/Refinement/` を `grep` で数えた値であり、読者の分類は群 K の最初の棚卸しで確かめる。以下 `R/` は同じディレクトリを指す。

## 1. 変える定義の完全署名の案

```lean
-- R/Syntax.lean
structure Def where
  tparams : List TParamDecl
  neffs : Nat
  /-- 宣言した範囲パラメータの種類。署名と本体の範囲の変数 `rvar i` の i 番目の種類である。 -/
  rkinds : List Scope.Domain.Kind := []
  names : List String
  params : List Ty
  ret : Ty
  eff : Eff
  body : Comp

inductive Val where
  …
  | fnRef (f : FunName) (tys : List Ty) (effs : List Eff) (rs : List RangeExpr := [])
  …

-- R/Typing.lean（V_Prim と同じ順で、型・行の具体化の前に範囲を具体化する）
| V_Fun {Ψ Q C Γ Φ f d ts es rs} : P.defs f = some d → NamesWF d.names d.params →
    Def.RangeAdmissible d rs →
    Admissible B C Γ.length (TypeCtx.constraints d.tparams) d.neffs
      (Qsig d.params d.ret d.eff) Q ts es d.eff →
    SignatureInstance P C Γ (Tel.instR rs d.tel) (TypeCtx.kinds d.tparams) ts es →
    HasTypeVQ P B Ψ Q C Γ Φ (.fnRef f ts es rs)
      (.dependentFn (instantiatedTel (Tel.instR rs d.tel) ts es))

/-- `Builtins.RangeAdmissible` から表の許容（admitsR）を除いた形。利用者の関数はどの範囲の具体化も、種類が合えば許す。 -/
def Def.RangeAdmissible (d : Def) (rs : List RangeExpr) : Prop :=
  rs.length = d.rkinds.length ∧
  (∀ i r k, rs[i]? = some r → d.rkinds[i]? = some k → r.FitsKind k) ∧
  (∀ r ∈ rs, r.WF ∧ r.Canonical)

-- R/ProgramTyping.lean：範囲の変数の上限を d.rkinds.length にする
def Def.WellTyped (P : Program) (B : Builtins) (d : Def) : Prop :=
  NamesWF d.names d.params ∧
  Ty.HasKind P (TypeCtx.kinds d.tparams) (.dependentFn d.tel) .value ∧
  Ty.AnnotationR P d.rkinds.length d.tparams [] (.dependentFn d.tel) ∧
  TelBodyTyR P B StoreTy.empty (QTel d.tel) d.rkinds d.tparams [] [] d.tel d.body
```

`Ty.AnnotationR`・`TelBodyTyR` は、`Ty.Annotation` の `wf` の範囲の上限 0 を `nr` に替えた形である。14判断に範囲の文脈（種類の列）の添字を足すか、本体を範囲の変数のまま型付けて具体化後に読むかは群 K の最初の判断である。後者を推す。理由: 遷移は具体化した本体を走らせ、範囲の文脈を持つ判断を足すと14判断の全76枝の添字が増える。

```lean
-- 範囲の置換（新設。型の側の Ty.substRAt・Tel.substRAt と同じ写しを Comp・Val へ持ち上げる）
mutual
  noncomputable def Val.substR (c : Nat) (rs : List RangeExpr) : Val → Val
  noncomputable def Comp.substR (c : Nat) (rs : List RangeExpr) : Comp → Comp
  -- Clause・Arm・Capture・Closure と各リストの版
end
noncomputable def Comp.instR (rs : List RangeExpr) (m : Comp) : Comp := m.substR 0 rs

-- R/Step.lean の fnRef の適用
| (.app (.fnRef f ts es rs) ws), k, μ =>
    … some (none, .run (Closure.mk (Capture.empty.extendMany ws) ((d.body.instR rs).substTy ts es)) (markPush k) μ)
```

保存の補題（新設。`TypeSubstTyping.lean` の型の置換の保存と同じ構成）:

```lean
theorem TelBodyTy.instR {P B Ψ Q C Γ Φ t body rs kinds}
    (h : TelBodyTyR P B Ψ Q kinds C Γ Φ t body) (hrs : RangesFit rs kinds) :
    TelBodyTy P B Ψ Q C Γ Φ (Tel.instR rs t) (body.instR rs)
-- 14判断（HasTypeVQ・HasTypeVsQ・HasTypeEachQ・HasTypeCQ・HasTypeTelArgsQ・TelBodyTy・CaptureOk・
-- DependentClosureTy・CheckedWitness・AtCallAdmissible・HasTypeArmsQ・HasTypeClausesQ・HasFailureClause・ImageOk）
-- の相互帰納による同じ形の補題
```

範囲パラメータの種類は `Scope.Domain.Kind` の全体（path・host・endpoint）とし、path・endpoint に限らない。核の範囲の種類の照合（`FitsKind`）は種類を区別せずに扱い、host に固有の性質は群 F1 の `R/HostRangeParams.lean` の `fitsKind_host_iff`・`single_host_iff`・`covers_host_iff` が与える（未取り込み）。`Def.RangeAdmissible` の種類の照合はこれらを読む。

## 2. 波及する読者の数（grep で数えた値）

| 対象 | ファイル数 | 出現 | 内容 |
|---|---:|---:|---|
| `fnRef` を書く・照合するファイル（R/） | 44 | 118 | 構成子の引数が増えるので、照合と構成の全箇所。置換・改名・閉性・観測・遷移・選択・合成表を含む |
| `V_Fun` を読むファイル（R/） | 61 | — | 移送・逆転・置換・改名・表の欄の移送。群 A の `AtCallAdmissible` の拡張（26ファイル）と同じ型の機械的な場合の追加 |
| `Def.WellTyped` か `.tel` を読むファイル（R/） | 120 | — | 大半は `PrimSig.tel`・`MethSig.tel` の読者で、`Def` の範囲の上限を読むのはその一部（群 K の棚卸しで数える） |
| 型の置換の保存（参考の規模） | 17（`TypeSubst*`） | 3,000 行超 | 範囲の置換の保存も同じ程度の相互帰納を要する見込み |
| 交換・区間の `fnRef` | 2 | — | `Exchange`・`Interval` の読者 |
| 保存 C01（`StateTyE.step_preserved`）の `fnRef` の適用の枝 | 1 枝 | — | 本体の範囲の具体化を `TelBodyTy.instR` で閉じる。主定理の群 B の葉に当たる |

## 3. 表層（群 D の後）への申し送り

群 K の核が決まった後に、群 D の残りとして次を置く（群 D の results.md の未了の一覧と同じ）。

- 表層の構文: `Expr.funName`・`funDicts` に範囲の具体化の列を足す（`primName` と同じ形）。`FunDecl.rangeParams` を `Def.rkinds` へ写す。
- 表層の型付け: E_Fun・E_FunDicts の範囲の具体化と `Def.RangeAdmissible`、範囲パラメータの使う位置（S9）、関数の中の範囲パラメータと閉じた原子の混在（R4）、関数の R を型の別名へ渡す使い方（R5）。
- 性質1: 上の規則の場合と、関数の定義の型付け（`Def.WellTyped` の範囲の上限）。

群 K が `C_Match` に照合する型の宣言の前提を足す変更（群 C の停止の結果）について: 群 D の表層の照合の規則（E_Match・B_LastPat・B_BindPat・try の各規則）は、照合する型の注釈 `Ty.Annotation D.core C Γ a`（宣言済みを含む）を前提に持つので、新しい前提はこの注釈を照合する値の束縛の下へ移して供給できる。群 D は核の `C_Match` を変えない。
