# kind 表と旧導出の入力の完全署名

2026-11-01。指定ブランチ `m014/l10.k`、B_WORK `99ff1579586c5b62db54c00b1fbb673b96d02dc4`。git は使わない。本番への追加前に以下の署名と補助の契約を固定する。名前空間は `Benitoite.Release.Refinement`、Old は `Benitoite.Release` の説明用の略記である。最終の完全な定義・規則と補題の型も本書へ転記する。

## 決定の記録

1. 宣言の写しは既存の全 value 版を保持して WithKinds 版を別名で足す。zip の長さを WF で照合し、constraints と kind の両投影の等号を証明する。型・効果の値依存の移動は既存の embedParameters と ret/eff の shiftV をそのまま使う。
2. LegacyTypeInput は構文だけを読み、HasKind・WF nr kinds.length nv・Sorted・Declared・RangesScoped を要求する。旧型には値を読む述語がないため、Sorted/Declared の文脈は nv 個の none とする。実際の Γ の Annotation は別の文脈入力でも検査する。kind と制約の長さ一致は LegacyContextInput と各 node に置く。
3. 行は Fail の全型と全原子の範囲を調べ、Canonical を要求する。行変数の上限は LegacyInputCtx にないためここで創作しない。宣言の neffs と旧規則の許容を局所規則で保持する。
4. checked は同じ旧名と旧範囲に対する新しい所属を検査する。checkedRequest は空の型・値文脈で内容へ再帰し、valContent の写し・groundVal・同じ reqTarget を要求する。新 HasType を入力へ入れない。
5. メソッドの構文は受け手の型を持たないため、候補のクラス・メソッドを存在量化し、局所規則 C_Meth と各 node の型で実際の宣言を固定する。通常節の型文脈は操作の宣言の value kind 列を先頭へ足し、Fail は value を一つ足す。use の本体は現行構文と旧 C_Use に従って同じ nv とする（detail の束縛の表の nv+1 は旧実装と一致しない）。
6. LegacyRule は旧7判断46規則を一つずつ列挙する。旧の型付け前提だけを children へ移し、旧の局所前提はすべて保持する。親子の κ は同じ列、通常節では value 列の延長、Fail では value 一つ、保持要求の内容では空列に固定する。
7. LegacyNodeRegular は全 C/κ/Γ/Ψ/結果/行/R/局所の型を検査する。LegacyOutputInput は局所規則・node の適格性・全子の入力を持つ帰納述語とする。旧判断への復元は旧規則を再構成し、新判断を仮定しない。
8. LegacyTables は署名の形と admits/sat/範囲の表・保持対象の表の対応、constructor の同名 arity と全欄の Annotation/HasKind を持つ。delta/IO の全量化、新しい型付け・状態・遷移の結論は入力にしない。
9. 宣言の署名・実装の対象と辞書型・本体の構文入力を別の LegacyDeclarationsInput に集める。ソース専用のプログラムを埋め込む後段は既存の SourceScoped の条件も供給する。全状態の入力と全埋め込みは L20 に残す。embedStep は追加しない。
10. 四つの値の葉、正規化の限定等号、scoped_forget を使う旧 opaque への葉を証明する。既存の embedLe は既に P 付きであり、その署名を維持する。

## 完全な定義と署名

以下は現行の本番七ファイルの完全な宣言である。暗黙変数と定義の本体、46局所規則も省略していない。初回には本文の契約を先に記し、各モジュールの追加前に署名を追記してから実装した。型推論・構文の局所修正と補助契約の詳細化を反映した最終の転記である。

追加の判断は次のとおりである。

- メソッドの構文にある型引数について、候補の存在だけで実際の宣言の kind を代用しない。C_Meth の局所規則にも、選ばれたクラスとメソッドに対する LegacyTypesInput を持たせる。
- 表のデータとその系を LegacyTables と LegacyTableFacts に分ける。constructorScope は既存の宣言の行なし・範囲の上限を記録する。型付けの結論は加えない。
- LegacyHeldTypeInput は選ばれた型名と範囲の一致も各値 node で確認する。内容の型付けは子判断に残す。
- LegacyStateInput はこの群に置かず、状態の全コード・frame・store の型付き入力を具体化する L20、及び受渡しを確定する L10.55 へ残す。

旧型に対する WF の値深さへの非依存、Sorted、Declared の文脈への非依存も構文への再帰で閉じた。LegacyTypeInput.annotation_at と annotation_normal はこの事実を使い、任意の値文脈へ注釈を渡す。

最終の自己照合で、具体化前の署名の形成を明示した。関数・組み込み・操作・辞書の構文入力は参照先の元の署名・対象・辞書型を宣言側の文脈で検査し、C_Meth は実際に選ばれた元のメソッド署名も検査する。新型付けの結論を仮定せず、未設定の型変数が具体化後だけ適格になる入力を受け入れない。

## レビュー後の補助契約の確定

2026-11-01。RV-L10.k の中1・軽2を処置した。

- LegacyClausesInput の通常節は、opSig で得た元の署名を `List.replicate k .value`、`sg.tparams`、nr=0、nv=0 で LegacyTypeInput に渡す。外側の制約列を混ぜない。ClauseSig の範囲 S へ移す WF は、同じ長さの範囲の列についての構文上の補題から供給する。
- LegacyPrimSignature.admits、LegacyTables.sat、LegacyTables.ranges は、全て旧の受理から新の受理への含意とする。新しい受理の増加を禁じる逆向きは持たない。
- detail の use の nv+1 は誤りであり、旧・新の規則と一致する同じ nv の実装を正とする。
- 全埋め込みの局所文脈と宣言本体の三つの親判断の受渡しは、下の欄を正とする。

## L20 の局所文脈の橋渡し

旧の LocalCtx.extend n [] は [] を保ち、新の localExtend n [] は none を n 個持つ。したがって `L.map (Option.map embedBuilderKind)` と延長後の表を構文の等号で同一視しない。C_Let と腕の子では、既存の LocalCtx.Shift.empty を k=0 で使う局所文脈の移送を L20 で閉じる。Ty/Eff/Pred の shiftV_zero と shiftIndex_zero で値・型・効果の移動を消す。一般の HasTypeCQ.shift_values は Builtins.ValueAssumptions・StoreTy.WF・FullShiftMap・事実の含意を要求するため、そのまま任意の旧埋め込みへ適用できるとはしない。必要な前提を入口から供給できなければ、k=0 の局所文脈だけを変える補助を別に証明し、Builtins.ValueAssumptions を埋め込みの新しい独立前提にしない。既存の主な十言明は変えない。

## L10.55 へ渡す宣言本体の親判断

[handoff.lean](handoff.lean) の三つの Prop の定義を型検査した。新型付けを前提にせず、旧 Def.WellTyped/ImplDecl.WellTyped が持つ親判断をそのまま LegacyOutputInput の添字にする。関数は lookup f/d、メソッドは impl・class・method・body の lookup、上位の辞書は s の所属と value の lookup を対応させて全称化する。LegacyDeclarationsInput は構文だけの入力であり、三つの導出全体の入力を代用しない。

```lean
/-- P0.defs f = some d の関数本体。 -/
def functionBodyInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) (f : FunName) (d : Benitoite.Release.Def) : Prop :=
  LegacyOutputInput K P0 B0 B (.comp (K.functionParams f) Benitoite.Release.StoreTy.empty
    (Benitoite.Release.Qsig d.params d.ret d.eff) d.tparams (Benitoite.Release.binds d.params)
    (some d.ret) d.body d.ret d.eff [])

/-- P0.impls i = some id、クラスとメソッドの lookup、id.methods m = some body の本体。 -/
def methodBodyInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) (id : Benitoite.Release.ImplDecl)
    (m : MethName) (ms : Benitoite.Release.MethSig) (body : Benitoite.Release.Comp) : Prop :=
  LegacyOutputInput K P0 B0 B
    (.comp (K.methodParams id.cls m ++ List.replicate id.tparams.length .value)
      Benitoite.Release.StoreTy.empty (Benitoite.Release.Qsig ms.params ms.ret ms.eff)
      (ms.tparams ++ id.tparams)
      (Benitoite.Release.binds (id.dictTys.map (Benitoite.Release.Ty.shift ms.tparams.length 0) ++
        ms.params.map (id.methTy ms)))
      (some (id.methTy ms ms.ret)) body (id.methTy ms ms.ret)
      (Benitoite.Release.Eff.substAt ms.tparams.length [id.target] [] ms.eff) [])

/-- s ∈ cd.supers と id.supers s = some value の上位の辞書。 -/
def superBodyInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) (id : Benitoite.Release.ImplDecl)
    (s : ClassName) (value : Benitoite.Release.Val) : Prop :=
  LegacyOutputInput K P0 B0 B
    (.value (List.replicate id.tparams.length .value) Benitoite.Release.StoreTy.empty Benitoite.Release.Qempty
      id.tparams (Benitoite.Release.binds id.dictTys) value (.dict s id.target))
```

## LegacyKinds

```lean
import Benitoite.Release.Refinement.Embedding
import Benitoite.Release.Refinement.Admissible

/-! # 旧宣言の kind を保持する写し（設計書 01-12「旧判断の適格な入力」） -/
namespace Benitoite.Release.Refinement
noncomputable section

structure DeclarationKinds where
  classArgument : ClassName → TyKind
  functionParams : FunName → List TyKind
  methodParams : ClassName → MethName → List TyKind

def DeclarationKinds.WF (K : DeclarationKinds) (P : Benitoite.Release.Program) : Prop :=
  (∀ f d, P.defs f = some d → (K.functionParams f).length = d.tparams.length) ∧
  (∀ cl cd m ms, P.classes cl = some cd → cd.methods m = some ms →
    (K.methodParams cl m).length = ms.tparams.length)

def embedTParamsWithKinds (ps : List Benitoite.Release.TParam) (ks : List TyKind) : List TParamDecl :=
  (ps.zip ks).map fun (p, k) => ⟨p, k⟩

theorem embedTParamsWithKinds_constraints (ps : List Benitoite.Release.TParam) (ks : List TyKind)
    (h : ks.length = ps.length) :
    (embedTParamsWithKinds ps ks).map TParamDecl.constraints = ps := by
  induction ps generalizing ks with
  | nil => cases ks <;> simp_all [embedTParamsWithKinds]
  | cons p ps ih =>
    cases ks with
    | nil => simp at h
    | cons k ks => simpa only [embedTParamsWithKinds, List.zip_cons_cons, List.map_cons] using
          (congrArg (p :: ·) (ih ks (Nat.succ.inj h)))

theorem embedTParamsWithKinds_kinds (ps : List Benitoite.Release.TParam) (ks : List TyKind)
    (h : ks.length = ps.length) :
    (embedTParamsWithKinds ps ks).map TParamDecl.kind = ks := by
  induction ps generalizing ks with
  | nil => cases ks <;> simp_all [embedTParamsWithKinds]
  | cons p ps ih =>
    cases ks with
    | nil => simp at h
    | cons k ks => simpa only [embedTParamsWithKinds, List.zip_cons_cons, List.map_cons] using
          (congrArg (k :: ·) (ih ks (Nat.succ.inj h)))

def embedDefWithKinds (ks : List TyKind) (d : Benitoite.Release.Def) : Def :=
  { embedDef d with tparams := embedTParamsWithKinds d.tparams ks }

def embedMethSigWithKinds (ks : List TyKind) (d : Benitoite.Release.MethSig) : MethSig :=
  { embedMethSig d with tparams := embedTParamsWithKinds d.tparams ks }

def embedClassDeclWithKinds (K : DeclarationKinds) (cl : ClassName)
    (d : Benitoite.Release.ClassDecl) : ClassDecl :=
  { argumentKind := K.classArgument cl, supers := d.supers,
    methods := fun m => (d.methods m).map (embedMethSigWithKinds (K.methodParams cl m)) }

def embedProgramWithKinds (K : DeclarationKinds) (P : Benitoite.Release.Program) : Program :=
  { embedProgram P with
    defs := fun f => (P.defs f).map (embedDefWithKinds (K.functionParams f))
    classes := fun cl => (P.classes cl).map (embedClassDeclWithKinds K cl) }

@[simp] theorem embedProgramWithKinds_defs (K : DeclarationKinds) (P : Benitoite.Release.Program) (f : FunName) :
    (embedProgramWithKinds K P).defs f = (P.defs f).map (embedDefWithKinds (K.functionParams f)) := rfl
@[simp] theorem embedProgramWithKinds_classes (K : DeclarationKinds) (P : Benitoite.Release.Program) (cl : ClassName) :
    (embedProgramWithKinds K P).classes cl = (P.classes cl).map (embedClassDeclWithKinds K cl) := rfl
@[simp] theorem embedClassDeclWithKinds_methods (K : DeclarationKinds) (cl : ClassName)
    (cd : Benitoite.Release.ClassDecl) (m : MethName) :
    (embedClassDeclWithKinds K cl cd).methods m =
      (cd.methods m).map (embedMethSigWithKinds (K.methodParams cl m)) := rfl
@[simp] theorem embedProgramWithKinds_cons (K : DeclarationKinds) (P : Benitoite.Release.Program) (c : ConName) :
    (embedProgramWithKinds K P).cons c = (P.cons c).map embedConDecl := rfl
@[simp] theorem embedProgramWithKinds_ops (K : DeclarationKinds) (P : Benitoite.Release.Program) (o : OpName) :
    (embedProgramWithKinds K P).ops o = (P.ops o).map embedOpDecl := rfl
@[simp] theorem embedProgramWithKinds_impls (K : DeclarationKinds) (P : Benitoite.Release.Program) (i : ImplName) :
    (embedProgramWithKinds K P).impls i = (P.impls i).map embedImplDecl := rfl
@[simp] theorem embedProgramWithKinds_effects (K : DeclarationKinds) (P : Benitoite.Release.Program) :
    (embedProgramWithKinds K P).effects = P.effects := rfl
@[simp] theorem embedProgramWithKinds_externals (K : DeclarationKinds) (P : Benitoite.Release.Program) :
    (embedProgramWithKinds K P).externals = [] := rfl
@[simp] theorem embedProgramWithKinds_dataInfo (K : DeclarationKinds) (P : Benitoite.Release.Program) :
    (embedProgramWithKinds K P).dataInfo = (fun _ => none) := rfl
@[simp] theorem embedProgramWithKinds_varianceFor (K : DeclarationKinds) (P : Benitoite.Release.Program)
    (d : DataName) (n : Nat) :
    (embedProgramWithKinds K P).varianceFor d n = List.replicate n .invariant := rfl

end
end Benitoite.Release.Refinement
```

## LegacyDeclarations

```lean
import Benitoite.Release.Refinement.LegacyKinds

/-! # kind 表から宣言と署名の入口への接続 -/
namespace Benitoite.Release.Refinement
noncomputable section

/-- 制約の長さだけでなく、同じ呼出し元の kind 列で照合する。 -/
def LegacyKindArgs (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (κ : KindCtx) (ts : List Benitoite.Release.Ty) (ks : List TyKind) : Prop :=
  ts.length = ks.length ∧ ∀ (i : Nat) (a : Benitoite.Release.Ty) (k : TyKind),
    ts[i]? = some a → ks[i]? = some k → (embedTy a).HasKind (embedProgramWithKinds K P0) κ k

theorem LegacyKindArgs.kinded {K P0 κ ts ks C}
    (h : LegacyKindArgs K P0 κ ts ks) (hc : κ.length = C.length) :
    TypeArgsKinded (embedProgramWithKinds K P0) C (embedTys ts) ks := by
  refine ⟨by simpa using h.1, κ, hc, ?_⟩
  intro i a k ha hk
  obtain ⟨b, hb, rfl⟩ := Option.map_eq_some_iff.mp
    (by simpa only [embedTys_eq_map, List.getElem?_map] using ha)
  exact h.2 i b k hb hk

theorem embedDefWithKinds_parameters {K P0 f d} (wf : DeclarationKinds.WF K P0)
    (hd : P0.defs f = some d) :
    (embedDefWithKinds (K.functionParams f) d).tparams.map TParamDecl.constraints = d.tparams ∧
    (embedDefWithKinds (K.functionParams f) d).tparams.map TParamDecl.kind = K.functionParams f :=
  ⟨embedTParamsWithKinds_constraints _ _ (wf.1 f d hd),
    embedTParamsWithKinds_kinds _ _ (wf.1 f d hd)⟩

theorem embedMethSigWithKinds_parameters {K P0 cl cd m ms} (wf : DeclarationKinds.WF K P0)
    (hc : P0.classes cl = some cd) (hm : cd.methods m = some ms) :
    (embedMethSigWithKinds (K.methodParams cl m) ms).tparams.map TParamDecl.constraints = ms.tparams ∧
    (embedMethSigWithKinds (K.methodParams cl m) ms).tparams.map TParamDecl.kind = K.methodParams cl m :=
  ⟨embedTParamsWithKinds_constraints _ _ (wf.2 cl cd m ms hc hm),
    embedTParamsWithKinds_kinds _ _ (wf.2 cl cd m ms hc hm)⟩

theorem embedProgramWithKinds_def {K P0 f d} (hd : P0.defs f = some d) :
    (embedProgramWithKinds K P0).defs f = some (embedDefWithKinds (K.functionParams f) d) := by
  simp only [embedProgramWithKinds_defs, hd, Option.map_some]

theorem embedProgramWithKinds_class {K P0 cl cd} (hc : P0.classes cl = some cd) :
    (embedProgramWithKinds K P0).classes cl = some (embedClassDeclWithKinds K cl cd) := by
  simp only [embedProgramWithKinds_classes, hc, Option.map_some]

theorem embedProgramWithKinds_method {K P0 cl cd m ms}
    (hc : P0.classes cl = some cd) (hm : cd.methods m = some ms) :
    (embedProgramWithKinds K P0).classes cl = some (embedClassDeclWithKinds K cl cd) ∧
    (embedClassDeclWithKinds K cl cd).methods m = some (embedMethSigWithKinds (K.methodParams cl m) ms) :=
  ⟨embedProgramWithKinds_class hc, by simp only [embedClassDeclWithKinds_methods, hm, Option.map_some]⟩

theorem embed_dictionary_kind {K P0 κ cl cd a}
    (hc : P0.classes cl = some cd)
    (ha : (embedTy a).HasKind (embedProgramWithKinds K P0) κ (K.classArgument cl)) :
    (embedTy (.dict cl a)).HasKind (embedProgramWithKinds K P0) κ .value :=
  ⟨embedClassDeclWithKinds K cl cd, embedProgramWithKinds_class hc, ha⟩

/-- 形成の前提と kind の前提を分け、同じ宣言の依存列へ渡す。 -/
theorem legacy_signatureInstance {K : DeclarationKinds} {P0 : Benitoite.Release.Program}
    {κ : KindCtx} {C : List Benitoite.Release.TParam} {Γ : Ctx} {t : Tel}
    {ts : List Benitoite.Release.Ty} {es : List Benitoite.Release.Eff} {ks : List TyKind}
    (hc : κ.length = C.length)
    (source : (Ty.dependentFn t).WF 0 ks.length 0)
    (types : TypeAnnotations (embedProgramWithKinds K P0) C Γ (embedTys ts))
    (args : LegacyKindArgs K P0 κ ts ks)
    (rows : RowAnnotations (embedProgramWithKinds K P0) C Γ (es.map embedEff))
    (result : Ty.Annotation (embedProgramWithKinds K P0) C Γ
      (.dependentFn (instantiatedTel t (embedTys ts) (es.map embedEff)))) :
    SignatureInstance (embedProgramWithKinds K P0) C Γ t ks (embedTys ts) (es.map embedEff) :=
  ⟨source, types, args.kinded hc, rows, result⟩

/-- 関数の実際の宣言が読む kind 列へ同じ入力を接続する。 -/
theorem embedDefWithKinds_signatureInstance {K P0 κ C Γ f d ts}
    {es : List Benitoite.Release.Eff}
    (wf : K.WF P0) (hd : P0.defs f = some d) (hc : κ.length = C.length)
    (source : (Ty.dependentFn (embedDefWithKinds (K.functionParams f) d).tel).WF 0 (K.functionParams f).length 0)
    (types : TypeAnnotations (embedProgramWithKinds K P0) C Γ (embedTys ts))
    (args : LegacyKindArgs K P0 κ ts (K.functionParams f))
    (rows : RowAnnotations (embedProgramWithKinds K P0) C Γ (es.map embedEff))
    (result : Ty.Annotation (embedProgramWithKinds K P0) C Γ
      (.dependentFn (instantiatedTel (embedDefWithKinds (K.functionParams f) d).tel (embedTys ts) (es.map embedEff)))) :
    SignatureInstance (embedProgramWithKinds K P0) C Γ (embedDefWithKinds (K.functionParams f) d).tel
      ((embedDefWithKinds (K.functionParams f) d).tparams.map TParamDecl.kind) (embedTys ts) (es.map embedEff) := by
  rw [(embedDefWithKinds_parameters wf hd).2]
  exact legacy_signatureInstance hc source types args rows result

/-- メソッド自身のパラメータの後に、クラス引数の kind を置く。 -/
theorem embedMethSigWithKinds_signatureInstance {K P0 κ C Γ cl cd m ms ts}
    {es : List Benitoite.Release.Eff}
    (wf : K.WF P0) (hcl : P0.classes cl = some cd) (hm : cd.methods m = some ms)
    (hc : κ.length = C.length)
    (source : (Ty.dependentFn (embedMethSigWithKinds (K.methodParams cl m) ms).tel).WF 0
      (K.methodParams cl m ++ [K.classArgument cl]).length 0)
    (types : TypeAnnotations (embedProgramWithKinds K P0) C Γ (embedTys ts))
    (args : LegacyKindArgs K P0 κ ts (K.methodParams cl m ++ [K.classArgument cl]))
    (rows : RowAnnotations (embedProgramWithKinds K P0) C Γ (es.map embedEff))
    (result : Ty.Annotation (embedProgramWithKinds K P0) C Γ
      (.dependentFn (instantiatedTel (embedMethSigWithKinds (K.methodParams cl m) ms).tel (embedTys ts) (es.map embedEff)))) :
    SignatureInstance (embedProgramWithKinds K P0) C Γ (embedMethSigWithKinds (K.methodParams cl m) ms).tel
      ((embedMethSigWithKinds (K.methodParams cl m) ms).tparams.map TParamDecl.kind ++
        [(embedClassDeclWithKinds K cl cd).argumentKind]) (embedTys ts) (es.map embedEff) := by
  rw [(embedMethSigWithKinds_parameters wf hcl hm).2]
  exact legacy_signatureInstance hc source types args rows result

end
end Benitoite.Release.Refinement
```

## LegacyInput

```lean
import Benitoite.Release.Refinement.LegacyDeclarations
import Benitoite.Release.Refinement.ProgramWellFormed

/-! # 旧構文の表現・注釈・束縛の入力 -/
namespace Benitoite.Release.Refinement
noncomputable section

structure LegacyInputCtx where
  kinds : List TyKind
  constraints : List Benitoite.Release.TParam
  nr : Nat
  nv : Nat

def LegacyInputCtx.values (Δ : LegacyInputCtx) (n : Nat) : LegacyInputCtx :=
  { Δ with nv := Δ.nv + n }
def LegacyInputCtx.types (Δ : LegacyInputCtx) (ps : List Benitoite.Release.TParam)
    (ks : List TyKind) : LegacyInputCtx :=
  { Δ with kinds := ks ++ Δ.kinds, constraints := ps ++ Δ.constraints }
def LegacyInputCtx.closed : LegacyInputCtx := ⟨[], [], 0, 0⟩

def LegacyTypeInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (Δ : LegacyInputCtx) (a : Benitoite.Release.Ty) (kind : TyKind) : Prop :=
  (embedTy a).HasKind (embedProgramWithKinds K P0) Δ.kinds kind ∧
  (embedTy a).WF Δ.nr Δ.kinds.length Δ.nv ∧
  (embedTy a).Sorted (List.replicate Δ.nv none) ∧
  (embedTy a).Declared (embedProgramWithKinds K P0) Δ.constraints (List.replicate Δ.nv none) ∧
  (embedTy a).RangesScoped Δ.nr

def LegacyTypesInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (Δ : LegacyInputCtx) (ts : List Benitoite.Release.Ty) (ks : List TyKind) : Prop :=
  ts.length = ks.length ∧ ∀ (i : Nat) (a : Benitoite.Release.Ty) (k : TyKind),
    ts[i]? = some a → ks[i]? = some k → LegacyTypeInput K P0 Δ a k

def LegacyRowsInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (Δ : LegacyInputCtx) (es : List Benitoite.Release.Eff) : Prop :=
  ∀ e ∈ es, LegacyTypeInput K P0 Δ (.fn [] [] (.base .unit) e) .value

def LegacyBuilderInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (Δ : LegacyInputCtx) (k : Benitoite.Release.BuilderKind) : Prop :=
  LegacyTypeInput K P0 Δ k.contents .value

mutual
  def LegacyValueInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
      (B0 : Benitoite.Release.Builtins) (B : Builtins)
      (Δ : LegacyInputCtx) : Benitoite.Release.Val → Prop
    | .var _ | .loc _ => True
    | .const c => ConstOK B (embedConst c)
    | .bytesV bs => ∀ b ∈ bs, b ≤ 255
    | .fnRef f ts es => ∃ fd, P0.defs f = some fd ∧
        LegacyTypeInput K P0 ⟨K.functionParams f, fd.tparams, 0, 0⟩
          (.fn fd.names fd.params fd.ret fd.eff) .value ∧
        LegacyTypesInput K P0 Δ ts (K.functionParams f) ∧ LegacyRowsInput K P0 Δ es
    | .prim b ts es rs => ∃ s0 s, B0.sig b = some s0 ∧ B.sig b = some s ∧
        s.tparams.length = s0.tparams.length ∧
        LegacyTypeInput K P0 ⟨s.tparams.map TParamDecl.kind, s0.tparams, s0.nranges, 0⟩
          (.fn s0.names s0.params s0.ret s0.eff) .value ∧
        LegacyTypesInput K P0 Δ ts (s.tparams.map TParamDecl.kind) ∧ LegacyRowsInput K P0 Δ es ∧
        (∀ r ∈ rs, (embedRange r).WF ∧ (embedRange r).Canonical)
    | .op o ts => ∃ od, P0.ops o = some od ∧
        LegacyTypeInput K P0 ⟨List.replicate od.tparams.length .value, od.tparams, 0, 0⟩
          (.fn od.names od.params od.ret (Benitoite.Release.Eff.single od.eff)) .value ∧
        LegacyTypesInput K P0 Δ ts (List.replicate od.tparams.length .value)
    | .raise a e => LegacyTypeInput K P0 Δ a .value ∧ LegacyTypeInput K P0 Δ e .value
    | .lam ns ps body => Benitoite.Release.NamesWF ns ps ∧
        (∀ a ∈ ps, LegacyTypeInput K P0 Δ a .value) ∧ LegacyCompInput K P0 B0 B (Δ.values ps.length) body
    | .con c ts vs => (∃ cd, P0.cons c = some cd ∧
        LegacyTypesInput K P0 Δ ts (List.replicate cd.ntys .value)) ∧ LegacyValuesInput K P0 B0 B Δ vs
    | .dict i ts vs => (∃ id, P0.impls i = some id ∧
        LegacyTypeInput K P0 ⟨List.replicate id.tparams.length .value, id.tparams, 0, 0⟩
          id.target (K.classArgument id.cls) ∧
        (∀ a ∈ id.dictTys, LegacyTypeInput K P0
          ⟨List.replicate id.tparams.length .value, id.tparams, 0, 0⟩ a .value) ∧
        LegacyTypesInput K P0 Δ ts (List.replicate id.tparams.length .value)) ∧ LegacyValuesInput K P0 B0 B Δ vs
    | .list vs | .setV vs => LegacyValuesInput K P0 B0 B Δ vs
    | .mapV ks vs => LegacyValuesInput K P0 B0 B Δ ks ∧ LegacyValuesInput K P0 B0 B Δ vs
    | .super v _ => LegacyValueInput K P0 B0 B Δ v
    | .checked target => ∃ o, B0.valKind o = some target.kind ∧
        B.valKind o = some target.kind ∧ B.valContent o = none
    | .checkedRequest target req => LegacyValueInput K P0 B0 B .closed req ∧
        groundVal (embedVal req) = true ∧ (embedVal req).reqTarget = some target ∧
        (∃ o T0, B0.valKind o = some .endpoint ∧ B.valKind o = some .endpoint ∧
          B0.valContent o = some T0 ∧ B.valContent o = some (embedTy T0))
  def LegacyValuesInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
      (B0 : Benitoite.Release.Builtins) (B : Builtins)
      (Δ : LegacyInputCtx) : List Benitoite.Release.Val → Prop
    | [] => True
    | v :: vs => LegacyValueInput K P0 B0 B Δ v ∧ LegacyValuesInput K P0 B0 B Δ vs
  def LegacyCompInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
      (B0 : Benitoite.Release.Builtins) (B : Builtins)
      (Δ : LegacyInputCtx) : Benitoite.Release.Comp → Prop
    | .builderLet k body => LegacyBuilderInput K P0 Δ k ∧ LegacyCompInput K P0 B0 B (Δ.values 1) body
    | .builderOp k _ _ vs => LegacyBuilderInput K P0 Δ k ∧ LegacyValuesInput K P0 B0 B Δ vs
    | .ret v | .escape v => LegacyValueInput K P0 B0 B Δ v
    | .letIn m n => LegacyCompInput K P0 B0 B Δ m ∧ LegacyCompInput K P0 B0 B (Δ.values 1) n
    | .app v vs => LegacyValueInput K P0 B0 B Δ v ∧ LegacyValuesInput K P0 B0 B Δ vs
    | .ite v m n => LegacyValueInput K P0 B0 B Δ v ∧ LegacyCompInput K P0 B0 B Δ m ∧ LegacyCompInput K P0 B0 B Δ n
    | .match v arms => LegacyValueInput K P0 B0 B Δ v ∧ LegacyArmsInput K P0 B0 B Δ arms
    | .lazyC m => LegacyCompInput K P0 B0 B Δ m
    | .use v m => LegacyValueInput K P0 B0 B Δ v ∧ LegacyCompInput K P0 B0 B Δ m
    | .handle m cs => LegacyCompInput K P0 B0 B Δ m ∧ LegacyClausesInput K P0 B0 B Δ cs
    | .resume k v => LegacyValueInput K P0 B0 B Δ k ∧ LegacyValueInput K P0 B0 B Δ v
    | .meth v m ts es vs => LegacyValueInput K P0 B0 B Δ v ∧
        (∃ cl cd ms, P0.classes cl = some cd ∧ cd.methods m = some ms ∧
          LegacyTypeInput K P0 ⟨K.methodParams cl m ++ [K.classArgument cl],
            ms.tparams ++ [({} : Benitoite.Release.TParam)], 0, 0⟩
            (.fn ms.names ms.params ms.ret ms.eff) .value ∧
          LegacyTypesInput K P0 Δ ts (K.methodParams cl m)) ∧
        LegacyRowsInput K P0 Δ es ∧ LegacyValuesInput K P0 B0 B Δ vs
  def LegacyArmsInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
      (B0 : Benitoite.Release.Builtins) (B : Builtins)
      (Δ : LegacyInputCtx) : List Benitoite.Release.Arm → Prop
    | [] => True
    | .mk alts guard body :: arms =>
        (match guard with | none => True
                          | some g => LegacyCompInput K P0 B0 B (Δ.values (Benitoite.Release.Arm.bindersOf alts)) g) ∧
        LegacyCompInput K P0 B0 B (Δ.values (Benitoite.Release.Arm.bindersOf alts)) body ∧
        LegacyArmsInput K P0 B0 B Δ arms
  def LegacyClausesInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
      (B0 : Benitoite.Release.Builtins) (B : Builtins)
      (Δ : LegacyInputCtx) : List Benitoite.Release.Clause → Prop
    | [] => True
    | .mk o n k body :: cs =>
        (∃ sg, Benitoite.Release.opSig P0 B0 o = some sg ∧
          k = sg.tparams.length ∧ n = sg.params.length ∧
          LegacyTypeInput K P0 ⟨List.replicate k .value, sg.tparams, 0, 0⟩
            (.fn sg.names sg.params sg.ret (Benitoite.Release.Eff.single sg.eff)) .value ∧
          LegacyCompInput K P0 B0 B ((Δ.types sg.tparams (List.replicate k .value)).values (n+1)) body) ∧
        LegacyClausesInput K P0 B0 B Δ cs
    | .fail e body :: cs => LegacyTypeInput K P0 Δ e .value ∧
        LegacyCompInput K P0 B0 B ((Δ.types [({} : Benitoite.Release.TParam)] [.value]).values 2) body ∧
        LegacyClausesInput K P0 B0 B Δ cs
end

/-- 実際に選ばれた旧の保持値の型との対応。構文側の存在量化だけでは代用しない。 -/
def LegacyHeldTypeInput (B0 : Benitoite.Release.Builtins) (B : Builtins)
    (v : Benitoite.Release.Val) (a : Benitoite.Release.Ty) : Prop :=
  match v with
  | .checked target => ∃ o range, a = .opaque o (.fixed range) ∧
      B0.valKind o = some target.kind ∧ B.valKind o = some target.kind ∧ B.valContent o = none ∧
      Scope.Domain.Range.MemK target.kind range target
  | .checkedRequest target _ => ∃ o range T0, a = .opaque o (.fixed range) ∧
      B0.valKind o = some .endpoint ∧ B.valKind o = some .endpoint ∧
      B0.valContent o = some T0 ∧ B.valContent o = some (embedTy T0) ∧
      Scope.Domain.Range.MemK .endpoint range target
  | .var _ | .const _ | .fnRef _ _ _ | .prim _ _ _ _ | .lam _ _ _ | .con _ _ _ |
      .list _ | .op _ _ | .raise _ _ | .loc _ | .mapV _ _ | .setV _ | .bytesV _ |
      .dict _ _ _ | .super _ _ => True

def LegacyLocInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (Δ : LegacyInputCtx) : Benitoite.Release.LocTy → Prop
  | .builder k => LegacyBuilderInput K P0 Δ k
  | .ref a | .lazy a => LegacyTypeInput K P0 Δ a .value
  | .cont a b e r => LegacyTypeInput K P0 Δ a .value ∧ LegacyTypeInput K P0 Δ b .value ∧
      LegacyRowsInput K P0 Δ [e] ∧ (∀ t ∈ r.toList, LegacyTypeInput K P0 Δ t .value)

def LegacyContextInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (Ψ : Benitoite.Release.StoreTy) (C : List Benitoite.Release.TParam)
    (Γ : List (Option Benitoite.Release.Ty)) (Δ : LegacyInputCtx) : Prop :=
  Δ.constraints = C ∧ Δ.nv = Γ.length ∧ Δ.kinds.length = C.length ∧
  (∀ l lt, Ψ l = some lt → LegacyLocInput K P0 .closed lt) ∧
  (∀ (i : Nat) (a : Benitoite.Release.Ty), Γ[i]? = some (some a) → LegacyTypeInput K P0 Δ a .value ∧
    Ty.Annotation (embedProgramWithKinds K P0) C (Γ.map (Option.map embedTy)) (embedTy a))

/-- 宣言本体を構文として走査する。型付き本体の結論を入力にしない。 -/
def LegacyDeclarationsInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) : Prop :=
  (∀ f fd, P0.defs f = some fd →
    LegacyTypeInput K P0 ⟨K.functionParams f, fd.tparams, 0, 0⟩
      (.fn fd.names fd.params fd.ret fd.eff) .value ∧
    LegacyCompInput K P0 B0 B ⟨K.functionParams f, fd.tparams, 0, fd.params.length⟩ fd.body) ∧
  (∀ o od, P0.ops o = some od →
    LegacyTypeInput K P0 ⟨List.replicate od.tparams.length .value, od.tparams, 0, 0⟩
      (.fn od.names od.params od.ret (Benitoite.Release.Eff.single od.eff)) .value) ∧
  (∀ cl cd m ms, P0.classes cl = some cd → cd.methods m = some ms →
    LegacyTypeInput K P0 ⟨K.methodParams cl m ++ [K.classArgument cl], ms.tparams ++ [({} : Benitoite.Release.TParam)], 0, 0⟩
      (.fn ms.names ms.params ms.ret ms.eff) .value) ∧
  (∀ i id, P0.impls i = some id →
    LegacyTypeInput K P0 ⟨List.replicate id.tparams.length .value, id.tparams, 0, 0⟩
      id.target (K.classArgument id.cls) ∧
    (∀ a ∈ id.dictTys, LegacyTypeInput K P0
      ⟨List.replicate id.tparams.length .value, id.tparams, 0, 0⟩ a .value) ∧
    (∀ s v, id.supers s = some v → LegacyValueInput K P0 B0 B
      ⟨List.replicate id.tparams.length .value, id.tparams, 0, id.dictTys.length⟩ v) ∧
    (∀ cl m ms body, P0.classes id.cls = some cl → cl.methods m = some ms → id.methods m = some body →
      LegacyCompInput K P0 B0 B
        ⟨K.methodParams id.cls m ++ List.replicate id.tparams.length .value,
          ms.tparams ++ id.tparams, 0, id.dictTys.length + ms.params.length⟩ body))

end
end Benitoite.Release.Refinement
```

## LegacyRegularity

```lean
import Benitoite.Release.Refinement.LegacyInput

/-! # 旧七判断の全中間判断と局所規則 -/
namespace Benitoite.Release.Refinement
noncomputable section

inductive LegacyJudgment where
  | value : KindCtx → Benitoite.Release.StoreTy → Benitoite.Release.NoFailCtx → List Benitoite.Release.TParam → List (Option Benitoite.Release.Ty) → Benitoite.Release.Val → Benitoite.Release.Ty → LegacyJudgment
  | values : KindCtx → Benitoite.Release.StoreTy → Benitoite.Release.NoFailCtx → List Benitoite.Release.TParam → List (Option Benitoite.Release.Ty) → List Benitoite.Release.Val → List Benitoite.Release.Ty → LegacyJudgment
  | each : KindCtx → Benitoite.Release.StoreTy → Benitoite.Release.NoFailCtx → List Benitoite.Release.TParam → List (Option Benitoite.Release.Ty) → List Benitoite.Release.Val → Benitoite.Release.Ty → LegacyJudgment
  | comp : KindCtx → Benitoite.Release.StoreTy → Benitoite.Release.NoFailCtx → List Benitoite.Release.TParam → List (Option Benitoite.Release.Ty) → Option Benitoite.Release.Ty → Benitoite.Release.Comp → Benitoite.Release.Ty → Benitoite.Release.Eff → Benitoite.Release.LocalCtx → LegacyJudgment
  | arms : KindCtx → Benitoite.Release.StoreTy → Benitoite.Release.NoFailCtx → List Benitoite.Release.TParam → List (Option Benitoite.Release.Ty) → Option Benitoite.Release.Ty → List Benitoite.Release.Arm → Benitoite.Release.Ty → Benitoite.Release.Ty → Benitoite.Release.Eff → Benitoite.Release.LocalCtx → LegacyJudgment
  | clauses : KindCtx → Benitoite.Release.StoreTy → Benitoite.Release.NoFailCtx → List Benitoite.Release.TParam → List (Option Benitoite.Release.Ty) → Option Benitoite.Release.Ty → Benitoite.Release.Eff → List Benitoite.Release.Clause → Benitoite.Release.Ty → Benitoite.Release.Eff → Benitoite.Release.LocalCtx → LegacyJudgment
  | failure : KindCtx → Benitoite.Release.StoreTy → Benitoite.Release.NoFailCtx → List Benitoite.Release.TParam → List (Option Benitoite.Release.Ty) → Benitoite.Release.Ty → Option Benitoite.Release.Ty → List Benitoite.Release.Clause → Benitoite.Release.Ty → Benitoite.Release.Eff → Benitoite.Release.LocalCtx → LegacyJudgment

def LegacyJudgment.OldHolds (P0 : Benitoite.Release.Program) (B0 : Benitoite.Release.Builtins) : LegacyJudgment → Prop
  | .value _ Ψ Q C Γ v a => Benitoite.Release.HasTypeVQ P0 B0 Ψ Q C Γ v a
  | .values _ Ψ Q C Γ vs ts => Benitoite.Release.HasTypeVsQ P0 B0 Ψ Q C Γ vs ts
  | .each _ Ψ Q C Γ vs a => Benitoite.Release.HasTypeEachQ P0 B0 Ψ Q C Γ vs a
  | .comp _ Ψ Q C Γ R m a e L => Benitoite.Release.HasTypeCQ P0 B0 Ψ Q C Γ R m a e L
  | .arms _ Ψ Q C Γ R xs a b e L => Benitoite.Release.HasTypeArmsQ P0 B0 Ψ Q C Γ R xs a b e L
  | .clauses _ Ψ Q C Γ R eb cs a e L => Benitoite.Release.HasTypeClausesQ P0 B0 Ψ Q C Γ R eb cs a e L
  | .failure _ Ψ Q C Γ E R cs a e L => Benitoite.Release.HasFailureClause P0 B0 Ψ Q C Γ E R cs a e L

/-- 型文脈・値文脈と閉じたストアを同時に検査する。 -/
def LegacyNodeContext (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (κ : KindCtx) (Ψ : Benitoite.Release.StoreTy) (C : List Benitoite.Release.TParam)
    (Γ : List (Option Benitoite.Release.Ty)) : Prop :=
  LegacyContextInput K P0 Ψ C Γ ⟨κ, C, 0, Γ.length⟩

def LegacyNodeTypes (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (κ : KindCtx) (C : List Benitoite.Release.TParam) (nv : Nat)
    (as : List Benitoite.Release.Ty) : Prop :=
  ∀ a ∈ as, LegacyTypeInput K P0 ⟨κ, C, 0, nv⟩ a .value

def LegacyNodeLocal (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (κ : KindCtx) (C : List Benitoite.Release.TParam) (nv : Nat)
    (L : Benitoite.Release.LocalCtx) : Prop :=
  ∀ item ∈ L, ∀ k ∈ item.toList, LegacyBuilderInput K P0 ⟨κ, C, 0, nv⟩ k

def LegacyNodeRegular (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) : LegacyJudgment → Prop
  | .value κ Ψ _Q C Γ v a =>
      LegacyNodeContext K P0 κ Ψ C Γ ∧ LegacyValueInput K P0 B0 B ⟨κ, C, 0, Γ.length⟩ v ∧ LegacyHeldTypeInput B0 B v a ∧
      LegacyNodeTypes K P0 κ C Γ.length [a]
  | .values κ Ψ _Q C Γ vs ts =>
      LegacyNodeContext K P0 κ Ψ C Γ ∧ LegacyValuesInput K P0 B0 B ⟨κ, C, 0, Γ.length⟩ vs ∧
      LegacyNodeTypes K P0 κ C Γ.length ts
  | .each κ Ψ _Q C Γ vs a =>
      LegacyNodeContext K P0 κ Ψ C Γ ∧ LegacyValuesInput K P0 B0 B ⟨κ, C, 0, Γ.length⟩ vs ∧
      LegacyNodeTypes K P0 κ C Γ.length [a]
  | .comp κ Ψ _Q C Γ R m a e L =>
      LegacyNodeContext K P0 κ Ψ C Γ ∧ LegacyCompInput K P0 B0 B ⟨κ, C, 0, Γ.length⟩ m ∧
      LegacyNodeTypes K P0 κ C Γ.length (a :: R.toList) ∧
      LegacyRowsInput K P0 ⟨κ, C, 0, Γ.length⟩ [e] ∧ LegacyNodeLocal K P0 κ C Γ.length L
  | .arms κ Ψ _Q C Γ R arms a b e L =>
      LegacyNodeContext K P0 κ Ψ C Γ ∧ LegacyArmsInput K P0 B0 B ⟨κ, C, 0, Γ.length⟩ arms ∧
      LegacyNodeTypes K P0 κ C Γ.length (a :: b :: R.toList) ∧
      LegacyRowsInput K P0 ⟨κ, C, 0, Γ.length⟩ [e] ∧ LegacyNodeLocal K P0 κ C Γ.length L
  | .clauses κ Ψ _Q C Γ R eb cs a e L =>
      LegacyNodeContext K P0 κ Ψ C Γ ∧ LegacyClausesInput K P0 B0 B ⟨κ, C, 0, Γ.length⟩ cs ∧
      LegacyNodeTypes K P0 κ C Γ.length (a :: R.toList) ∧
      LegacyRowsInput K P0 ⟨κ, C, 0, Γ.length⟩ [eb, e] ∧ LegacyNodeLocal K P0 κ C Γ.length L
  | .failure κ Ψ _Q C Γ E R cs a e L =>
      LegacyNodeContext K P0 κ Ψ C Γ ∧ LegacyClausesInput K P0 B0 B ⟨κ, C, 0, Γ.length⟩ cs ∧
      LegacyNodeTypes K P0 κ C Γ.length (E :: a :: R.toList) ∧
      LegacyRowsInput K P0 ⟨κ, C, 0, Γ.length⟩ [e] ∧ LegacyNodeLocal K P0 κ C Γ.length L

inductive LegacyRule (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) : LegacyJudgment → List LegacyJudgment → Prop where
  | V_Var {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ i a} :
      Γ[i]? = some (some a) →
      (∀ b t ε, a ≠ .cont b t ε) →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.var i) a) []
  | V_Const {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ c} :
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.const c) c.type) []
  | V_Fun {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ f d ts es} :
      P0.defs f = some d →
      Benitoite.Release.NamesWF d.names d.params →
      Benitoite.Release.Admissible B0 C d.tparams d.neffs (Benitoite.Release.Qsig d.params d.ret d.eff) Q ts es d.eff →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.fnRef f ts es) (Benitoite.Release.fnTy d.names d.params d.ret d.eff ts es)) []
  | V_Prim {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ b s rs ts es} :
      B0.sig b = some s →
      B0.RangeAdmissible b s rs →
      Benitoite.Release.NamesWF (s.inst rs).names (s.inst rs).params →
      Benitoite.Release.PrimitiveAdmissible C (s.inst rs) Q ts es →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.prim b ts es rs) (Benitoite.Release.fnTy (s.inst rs).names (s.inst rs).params (s.inst rs).ret (s.inst rs).eff ts es)) []
  | V_Op {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ o od ts} :
      P0.ops o = some od →
      Benitoite.Release.NamesWF od.names od.params →
      Benitoite.Release.SatAll B0 C ts od.tparams →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.op o ts) (Benitoite.Release.fnTy od.names od.params od.ret (Benitoite.Release.Eff.single od.eff) ts [])) []
  | V_Raise {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ T E} :
      Benitoite.Release.Ty.WF 0 C.length T →
      Benitoite.Release.Ty.WF 0 C.length E →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.raise T E) (.fn ["error"] [E] T (Benitoite.Release.Eff.singleFail E))) []
  | V_Lam {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ names ps body r ε} :
      Benitoite.Release.NamesWF names ps →
      Benitoite.Release.Ty.WF 0 C.length (.fn names ps r ε) →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.lam names ps body) (.fn names ps r ε)) [(.comp κ Ψ.hideBuilders Q C (Benitoite.Release.binds ps ++ Benitoite.Release.hideConts Γ) (some r) body r ε [])]
  | V_Con {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ c ts args cd} :
      P0.cons c = some cd →
      ts.length = cd.ntys →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.con c ts args) (.data cd.data ts)) [(.values κ Ψ Q C Γ args (cd.args.map (Benitoite.Release.Ty.subst ts [])))]
  | V_List {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ elems a} :
      Benitoite.Release.Ty.WF 0 C.length a →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.list elems) (.list a)) [(.each κ Ψ Q C Γ elems a)]
  | V_LocRef {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ l a} :
      Ψ l = some (.ref a) →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.loc l) (.reference a)) []
  | V_LocLazy {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ l a} :
      Ψ l = some (.lazy a) →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.loc l) (.lazy a)) []
  | V_Map {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ ks vs a b} :
      ks.length = vs.length →
      B0.sat C a Benitoite.Release.TParam.keyC →
      Benitoite.Release.Ty.WF 0 C.length a →
      Benitoite.Release.Ty.WF 0 C.length b →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.mapV ks vs) (.map a b)) [(.each κ Ψ Q C Γ ks a), (.each κ Ψ Q C Γ vs b)]
  | V_Set {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ elems a} :
      B0.sat C a Benitoite.Release.TParam.keyC →
      Benitoite.Release.Ty.WF 0 C.length a →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.setV elems) (.set a)) [(.each κ Ψ Q C Γ elems a)]
  | V_Bytes {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ bs} :
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.bytesV bs) .bytes) []
  | V_Dict {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ i ts vs id} :
      P0.impls i = some id →
      Benitoite.Release.SatAll B0 C ts id.tparams →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.dict i ts vs) (.dict id.cls (id.target.subst ts []))) [(.values κ Ψ Q C Γ vs (id.dictTys.map (Benitoite.Release.Ty.subst ts [])))]
  | V_Super {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ v cl τ cd s} :
      P0.classes cl = some cd →
      s ∈ cd.supers →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.super v s) (.dict s τ)) [(.value κ Ψ Q C Γ v (.dict cl τ))]
  | V_Sub {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ v a a'} :
      Benitoite.Release.Ty.Le a a' →
      Benitoite.Release.Ty.WF 0 C.length a' →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ v a') [(.value κ Ψ Q C Γ v a)]
  | V_Checked {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ o R t} :
      B0.valKind o = some t.kind →
      R.Mem t →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.checked t) (.opaque o (.fixed R))) []
  | V_CheckedRequest {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ o R t req T} :
      B0.valKind o = some t.kind →
      R.Mem t →
      B0.valContent o = some T →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.checkedRequest t req) (.opaque o (.fixed R))) [(.value [] Ψ Benitoite.Release.Qempty [] [] req T)]
  | Vs_nil {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ} :
      LegacyRule K P0 B0 (.values κ Ψ Q C Γ [] []) []
  | Vs_cons {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ v vs a as} :
      LegacyRule K P0 B0 (.values κ Ψ Q C Γ (v :: vs) (a :: as)) [(.value κ Ψ Q C Γ v a), (.values κ Ψ Q C Γ vs as)]
  | Each_nil {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ a} :
      LegacyRule K P0 B0 (.each κ Ψ Q C Γ [] a) []
  | Each_cons {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ v vs a} :
      LegacyRule K P0 B0 (.each κ Ψ Q C Γ (v :: vs) a) [(.value κ Ψ Q C Γ v a), (.each κ Ψ Q C Γ vs a)]
  | C_BuilderLet {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R kind body a ε} :
      Benitoite.Release.Ty.WF 0 C.length kind.contents →
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R (.builderLet kind body) a ε Δ) [(.comp κ Ψ Q C (none :: Γ) R body a ε (some kind :: Δ))]
  | C_BuilderOp {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R kind op ref args} :
      Benitoite.Release.Ty.WF 0 C.length kind.contents →
      Benitoite.Release.LocalRef.HasKind Ψ Δ ref kind →
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R (.builderOp kind op ref args) (op.result kind) Benitoite.Release.Eff.empty Δ) [(.values κ Ψ Q C Γ args (op.params kind))]
  | C_Return {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R v a} :
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R (.ret v) a Benitoite.Release.Eff.empty Δ) [(.value κ Ψ Q C Γ v a)]
  | C_Sub {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R m a a' ε ε'} :
      Benitoite.Release.Ty.Le a a' →
      Benitoite.Release.Eff.Covers ε' ε →
      Benitoite.Release.Ty.WF 0 C.length a' →
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R m a' ε' Δ) [(.comp κ Ψ Q C Γ R m a ε Δ)]
  | C_Eff {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R m a ε ε'} :
      Benitoite.Release.Eff.Covers ε' ε →
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R m a ε' Δ) [(.comp κ Ψ Q C Γ R m a ε Δ)]
  | C_Let {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R m n a b ε} :
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R (.letIn m n) b ε Δ) [(.comp κ Ψ Q C Γ R m a ε Δ), (.comp κ Ψ Q C (some a :: Γ) R n b ε (Benitoite.Release.LocalCtx.extend 1 Δ))]
  | C_App {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R f args names as b ε} :
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R (.app f args) b ε Δ) [(.value κ Ψ Q C Γ f (.fn names as b ε)), (.values κ Ψ Q C Γ args as)]
  | C_If {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R v m n a ε} :
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R (.ite v m n) a ε Δ) [(.value κ Ψ Q C Γ v (.base .boolean)), (.comp κ Ψ Q C Γ R m a ε Δ), (.comp κ Ψ Q C Γ R n a ε Δ)]
  | C_Match {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R v arms a b ε} :
      Benitoite.Release.Exhaustive P0 a (Benitoite.Release.unguardedPats arms) →
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R (.match v arms) b ε Δ) [(.value κ Ψ Q C Γ v a), (.arms κ Ψ Q C Γ R arms a b ε Δ)]
  | C_Lazy {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R m a} :
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R (.lazyC m) (.lazy a) Benitoite.Release.Eff.empty Δ) [(.comp κ Ψ.hideBuilders Q C (Benitoite.Release.hideConts Γ) none m a Benitoite.Release.Eff.empty [])]
  | C_Escape {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ r v a ε} :
      Benitoite.Release.Ty.WF 0 C.length a →
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ (some r) (.escape v) a ε Δ) [(.value κ Ψ Q C Γ v r)]
  | C_Use {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R v o m b ε} :
      B0.isResource o = true →
      Benitoite.Release.Eff.mem ε (.nameTop Benitoite.Release.stateEff) →
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R (.use v m) b ε Δ) [(.value κ Ψ Q C Γ v (.opaqueTop o)), (.comp κ Ψ Q C Γ R m b ε Δ)]
  | C_Handle {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R m h t εm ε} :
      Benitoite.Release.Eff.Sub εm (Benitoite.Release.Eff.union ε (Benitoite.Release.handled P0 B0 h)) →
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R (.handle m h) t ε Δ) [(.comp κ Ψ Q C Γ R m t εm Δ), (.clauses κ Ψ Q C Γ R εm h t ε Δ)]
  | C_Handle_Fail {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R m h t E eb Rest ec} :
      Benitoite.Release.Eff.Sub eb (Benitoite.Release.Eff.union (Benitoite.Release.Eff.singleFail E) Rest) →
      Benitoite.Release.NoFail Q Rest →
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R (.handle m h) t (Benitoite.Release.Eff.union Rest ec) Δ) [(.comp κ Ψ Q C Γ R m t eb Δ), (.failure κ Ψ Q C Γ E R h t ec Δ)]
  | C_Resume {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R i v b t ε} :
      Γ[i]? = some (some (.cont b t ε)) →
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R (.resume (.var i) v) t ε Δ) [(.value κ Ψ Q C Γ v b)]
  | C_ResumeL {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R l v b t ε} :
      Ψ l = some (.cont b t ε R) →
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R (.resume (.loc l) v) t ε Δ) [(.value κ Ψ Q C Γ v b)]
  | C_Meth {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R v cl τ cd m ms ss es ws} :
      P0.classes cl = some cd →
      cd.methods m = some ms →
      Benitoite.Release.NamesWF ms.names ms.params →
      Benitoite.Release.SatAll B0 C ss ms.tparams →
      (∀ t ∈ ss ++ [τ], Benitoite.Release.Ty.WF 0 C.length t ∧ ∀ b r e, t ≠ .cont b r e) →
      Benitoite.Release.MethodRowsAdmissible C Q ms es →
      LegacyTypeInput K P0 ⟨K.methodParams cl m ++ [K.classArgument cl],
        ms.tparams ++ [({} : Benitoite.Release.TParam)], 0, 0⟩
        (.fn ms.names ms.params ms.ret ms.eff) .value →
      LegacyTypesInput K P0 ⟨κ, C, 0, Γ.length⟩ ss (K.methodParams cl m) →
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R (.meth v m ss es ws) (ms.ret.subst (ss ++ [τ]) es) (Benitoite.Release.Eff.substAt 0 (ss ++ [τ]) es ms.eff) Δ) [(.value κ Ψ Q C Γ v (.dict cl τ)), (.values κ Ψ Q C Γ ws (ms.params.map (Benitoite.Release.Ty.subst (ss ++ [τ]) es)))]
  | Arms_nil {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R a b ε} :
      Benitoite.Release.Ty.WF 0 C.length b →
      LegacyRule K P0 B0 (.arms κ Ψ Q C Γ R [] a b ε Δ) []
  | Arms_plain {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R alts body arms a b ε δ} :
      Benitoite.Release.AltsTy P0 alts a δ →
      LegacyRule K P0 B0 (.arms κ Ψ Q C Γ R (.mk alts none body :: arms) a b ε Δ) [(.comp κ Ψ Q C (Benitoite.Release.binds δ ++ Γ) R body b ε (Benitoite.Release.LocalCtx.extend δ.length Δ)), (.arms κ Ψ Q C Γ R arms a b ε Δ)]
  | Arms_guarded {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R alts guard body arms a b ε δ} :
      Benitoite.Release.AltsTy P0 alts a δ →
      LegacyRule K P0 B0 (.arms κ Ψ Q C Γ R (.mk alts (some guard) body :: arms) a b ε Δ) [(.comp κ Ψ Q C (Benitoite.Release.hideConts (Benitoite.Release.binds δ ++ Γ)) none guard (.base .boolean) Benitoite.Release.Eff.empty (Benitoite.Release.LocalCtx.extend δ.length Δ)), (.comp κ Ψ Q C (Benitoite.Release.binds δ ++ Γ) R body b ε (Benitoite.Release.LocalCtx.extend δ.length Δ)), (.arms κ Ψ Q C Γ R arms a b ε Δ)]
  | Clauses_nil {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R εb t ε} :
      LegacyRule K P0 B0 (.clauses κ Ψ Q C Γ R εb [] t ε Δ) []
  | Clauses_cons {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R εb o n k body cs t ε sg} :
      Benitoite.Release.ClauseSig P0 B0 εb o sg →
      Benitoite.Release.NamesWF sg.names sg.params →
      n = sg.params.length →
      k = sg.tparams.length →
      Benitoite.Release.Eff.WF 0 C.length ε →
      LegacyRule K P0 B0 (.clauses κ Ψ Q C Γ R εb (.mk o n k body :: cs) t ε Δ) [(.comp (List.replicate sg.tparams.length .value ++ κ) Ψ.hideBuilders Q (sg.tparams ++ C) (some (.cont sg.ret (t.shift k 0) (Benitoite.Release.Eff.shift k 0 ε)) :: (Benitoite.Release.binds sg.params ++ Benitoite.Release.shiftEnv k Γ)) (R.map (Benitoite.Release.Ty.shift k 0)) body (t.shift k 0) (Benitoite.Release.Eff.shift k 0 ε) []), (.clauses κ Ψ Q C Γ R εb cs t ε Δ)]
  | Failure_one {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ E R body t ec} :
      Benitoite.Release.Ty.WF 0 C.length E →
      Benitoite.Release.Ty.WF 0 C.length t →
      Benitoite.Release.Eff.WF 0 C.length ec →
      LegacyRule K P0 B0 (.failure κ Ψ Q C Γ E R [.fail E body] t ec Δ) [(.comp (.value :: κ) Ψ.hideBuilders Q (({} : Benitoite.Release.TParam) :: C) (none :: some (E.shift 1 0) :: Benitoite.Release.shiftEnv 1 Γ) (R.map (Benitoite.Release.Ty.shift 1 0)) body (t.shift 1 0) (Benitoite.Release.Eff.shift 1 0 ec) [])]

inductive LegacyOutputInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) : LegacyJudgment → Prop where
  | node {j children} : LegacyRule K P0 B0 j children →
      LegacyNodeRegular K P0 B0 B j →
      (∀ child ∈ children, LegacyOutputInput K P0 B0 B child) →
      LegacyOutputInput K P0 B0 B j

theorem LegacyRule.old (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (j : LegacyJudgment) (children : List LegacyJudgment)
    (h : LegacyRule K P0 B0 j children)
    (hc : ∀ child ∈ children, child.OldHolds P0 B0) : j.OldHolds P0 B0 := by
  cases h with
  | @V_Var κ Ψ Q C Γ i a p0 p1 => exact Benitoite.Release.HasTypeVQ.V_Var p0 p1
  | @V_Const κ Ψ Q C Γ c => exact Benitoite.Release.HasTypeVQ.V_Const
  | @V_Fun κ Ψ Q C Γ f d ts es p0 p1 p2 => exact Benitoite.Release.HasTypeVQ.V_Fun p0 p1 p2
  | @V_Prim κ Ψ Q C Γ b s rs ts es p0 p1 p2 p3 => exact Benitoite.Release.HasTypeVQ.V_Prim p0 p1 p2 p3
  | @V_Op κ Ψ Q C Γ o od ts p0 p1 p2 => exact Benitoite.Release.HasTypeVQ.V_Op p0 p1 p2
  | @V_Raise κ Ψ Q C Γ T E p0 p1 => exact Benitoite.Release.HasTypeVQ.V_Raise p0 p1
  | @V_Lam κ Ψ Q C Γ names ps body r ε p0 p1 => exact Benitoite.Release.HasTypeVQ.V_Lam p0 p1 (hc (.comp κ Ψ.hideBuilders Q C (Benitoite.Release.binds ps ++ Benitoite.Release.hideConts Γ) (some r) body r ε []) (by simp))
  | @V_Con κ Ψ Q C Γ c ts args cd p0 p1 => exact Benitoite.Release.HasTypeVQ.V_Con p0 p1 (hc (.values κ Ψ Q C Γ args (cd.args.map (Benitoite.Release.Ty.subst ts []))) (by simp))
  | @V_List κ Ψ Q C Γ elems a p0 => exact Benitoite.Release.HasTypeVQ.V_List (hc (.each κ Ψ Q C Γ elems a) (by simp)) p0
  | @V_LocRef κ Ψ Q C Γ l a p0 => exact Benitoite.Release.HasTypeVQ.V_LocRef p0
  | @V_LocLazy κ Ψ Q C Γ l a p0 => exact Benitoite.Release.HasTypeVQ.V_LocLazy p0
  | @V_Map κ Ψ Q C Γ ks vs a b p0 p1 p2 p3 => exact Benitoite.Release.HasTypeVQ.V_Map (hc (.each κ Ψ Q C Γ ks a) (by simp)) (hc (.each κ Ψ Q C Γ vs b) (by simp)) p0 p1 p2 p3
  | @V_Set κ Ψ Q C Γ elems a p0 p1 => exact Benitoite.Release.HasTypeVQ.V_Set (hc (.each κ Ψ Q C Γ elems a) (by simp)) p0 p1
  | @V_Bytes κ Ψ Q C Γ bs => exact Benitoite.Release.HasTypeVQ.V_Bytes
  | @V_Dict κ Ψ Q C Γ i ts vs id p0 p1 => exact Benitoite.Release.HasTypeVQ.V_Dict p0 p1 (hc (.values κ Ψ Q C Γ vs (id.dictTys.map (Benitoite.Release.Ty.subst ts []))) (by simp))
  | @V_Super κ Ψ Q C Γ v cl τ cd s p0 p1 => exact Benitoite.Release.HasTypeVQ.V_Super (hc (.value κ Ψ Q C Γ v (.dict cl τ)) (by simp)) p0 p1
  | @V_Sub κ Ψ Q C Γ v a a' p0 p1 => exact Benitoite.Release.HasTypeVQ.V_Sub (hc (.value κ Ψ Q C Γ v a) (by simp)) p0 p1
  | @V_Checked κ Ψ Q C Γ o R t p0 p1 => exact Benitoite.Release.HasTypeVQ.V_Checked p0 p1
  | @V_CheckedRequest κ Ψ Q C Γ o R t req T p0 p1 p2 => exact Benitoite.Release.HasTypeVQ.V_CheckedRequest p0 p1 p2 (hc (.value [] Ψ Benitoite.Release.Qempty [] [] req T) (by simp))
  | @Vs_nil κ Ψ Q C Γ => exact Benitoite.Release.HasTypeVsQ.nil
  | @Vs_cons κ Ψ Q C Γ v vs a as => exact Benitoite.Release.HasTypeVsQ.cons (hc (.value κ Ψ Q C Γ v a) (by simp)) (hc (.values κ Ψ Q C Γ vs as) (by simp))
  | @Each_nil κ Ψ Q C Γ a => exact Benitoite.Release.HasTypeEachQ.nil
  | @Each_cons κ Ψ Q C Γ v vs a => exact Benitoite.Release.HasTypeEachQ.cons (hc (.value κ Ψ Q C Γ v a) (by simp)) (hc (.each κ Ψ Q C Γ vs a) (by simp))
  | @C_BuilderLet κ Ψ Q C Δ Γ R kind body a ε p0 => exact Benitoite.Release.HasTypeCQ.C_BuilderLet p0 (hc (.comp κ Ψ Q C (none :: Γ) R body a ε (some kind :: Δ)) (by simp))
  | @C_BuilderOp κ Ψ Q C Δ Γ R kind op ref args p0 p1 => exact Benitoite.Release.HasTypeCQ.C_BuilderOp p0 p1 (hc (.values κ Ψ Q C Γ args (op.params kind)) (by simp))
  | @C_Return κ Ψ Q C Δ Γ R v a => exact Benitoite.Release.HasTypeCQ.C_Return (hc (.value κ Ψ Q C Γ v a) (by simp))
  | @C_Sub κ Ψ Q C Δ Γ R m a a' ε ε' p0 p1 p2 => exact Benitoite.Release.HasTypeCQ.C_Sub (hc (.comp κ Ψ Q C Γ R m a ε Δ) (by simp)) p0 p1 p2
  | @C_Eff κ Ψ Q C Δ Γ R m a ε ε' p0 => exact Benitoite.Release.HasTypeCQ.C_Eff (hc (.comp κ Ψ Q C Γ R m a ε Δ) (by simp)) p0
  | @C_Let κ Ψ Q C Δ Γ R m n a b ε => exact Benitoite.Release.HasTypeCQ.C_Let (hc (.comp κ Ψ Q C Γ R m a ε Δ) (by simp)) (hc (.comp κ Ψ Q C (some a :: Γ) R n b ε (Benitoite.Release.LocalCtx.extend 1 Δ)) (by simp))
  | @C_App κ Ψ Q C Δ Γ R f args names as b ε => exact Benitoite.Release.HasTypeCQ.C_App (hc (.value κ Ψ Q C Γ f (.fn names as b ε)) (by simp)) (hc (.values κ Ψ Q C Γ args as) (by simp))
  | @C_If κ Ψ Q C Δ Γ R v m n a ε => exact Benitoite.Release.HasTypeCQ.C_If (hc (.value κ Ψ Q C Γ v (.base .boolean)) (by simp)) (hc (.comp κ Ψ Q C Γ R m a ε Δ) (by simp)) (hc (.comp κ Ψ Q C Γ R n a ε Δ) (by simp))
  | @C_Match κ Ψ Q C Δ Γ R v arms a b ε p0 => exact Benitoite.Release.HasTypeCQ.C_Match (hc (.value κ Ψ Q C Γ v a) (by simp)) (hc (.arms κ Ψ Q C Γ R arms a b ε Δ) (by simp)) p0
  | @C_Lazy κ Ψ Q C Δ Γ R m a => exact Benitoite.Release.HasTypeCQ.C_Lazy (hc (.comp κ Ψ.hideBuilders Q C (Benitoite.Release.hideConts Γ) none m a Benitoite.Release.Eff.empty []) (by simp))
  | @C_Escape κ Ψ Q C Δ Γ r v a ε p0 => exact Benitoite.Release.HasTypeCQ.C_Escape (hc (.value κ Ψ Q C Γ v r) (by simp)) p0
  | @C_Use κ Ψ Q C Δ Γ R v o m b ε p0 p1 => exact Benitoite.Release.HasTypeCQ.C_Use (hc (.value κ Ψ Q C Γ v (.opaqueTop o)) (by simp)) p0 (hc (.comp κ Ψ Q C Γ R m b ε Δ) (by simp)) p1
  | @C_Handle κ Ψ Q C Δ Γ R m h t εm ε p0 => exact Benitoite.Release.HasTypeCQ.C_Handle (hc (.comp κ Ψ Q C Γ R m t εm Δ) (by simp)) p0 (hc (.clauses κ Ψ Q C Γ R εm h t ε Δ) (by simp))
  | @C_Handle_Fail κ Ψ Q C Δ Γ R m h t E eb Rest ec p0 p1 => exact Benitoite.Release.HasTypeCQ.C_Handle_Fail (hc (.comp κ Ψ Q C Γ R m t eb Δ) (by simp)) p0 p1 (hc (.failure κ Ψ Q C Γ E R h t ec Δ) (by simp))
  | @C_Resume κ Ψ Q C Δ Γ R i v b t ε p0 => exact Benitoite.Release.HasTypeCQ.C_Resume p0 (hc (.value κ Ψ Q C Γ v b) (by simp))
  | @C_ResumeL κ Ψ Q C Δ Γ R l v b t ε p0 => exact Benitoite.Release.HasTypeCQ.C_ResumeL p0 (hc (.value κ Ψ Q C Γ v b) (by simp))
  | @C_Meth κ Ψ Q C Δ Γ R v cl τ cd m ms ss es ws p0 p1 p2 p3 p4 p5 _p6 _p7 => exact Benitoite.Release.HasTypeCQ.C_Meth (hc (.value κ Ψ Q C Γ v (.dict cl τ)) (by simp)) p0 p1 p2 p3 p4 p5 (hc (.values κ Ψ Q C Γ ws (ms.params.map (Benitoite.Release.Ty.subst (ss ++ [τ]) es))) (by simp))
  | @Arms_nil κ Ψ Q C Δ Γ R a b ε p0 => exact Benitoite.Release.HasTypeArmsQ.nil p0
  | @Arms_plain κ Ψ Q C Δ Γ R alts body arms a b ε δ p0 => exact Benitoite.Release.HasTypeArmsQ.plain p0 (hc (.comp κ Ψ Q C (Benitoite.Release.binds δ ++ Γ) R body b ε (Benitoite.Release.LocalCtx.extend δ.length Δ)) (by simp)) (hc (.arms κ Ψ Q C Γ R arms a b ε Δ) (by simp))
  | @Arms_guarded κ Ψ Q C Δ Γ R alts guard body arms a b ε δ p0 => exact Benitoite.Release.HasTypeArmsQ.guarded p0 (hc (.comp κ Ψ Q C (Benitoite.Release.hideConts (Benitoite.Release.binds δ ++ Γ)) none guard (.base .boolean) Benitoite.Release.Eff.empty (Benitoite.Release.LocalCtx.extend δ.length Δ)) (by simp)) (hc (.comp κ Ψ Q C (Benitoite.Release.binds δ ++ Γ) R body b ε (Benitoite.Release.LocalCtx.extend δ.length Δ)) (by simp)) (hc (.arms κ Ψ Q C Γ R arms a b ε Δ) (by simp))
  | @Clauses_nil κ Ψ Q C Δ Γ R εb t ε => exact Benitoite.Release.HasTypeClausesQ.nil
  | @Clauses_cons κ Ψ Q C Δ Γ R εb o n k body cs t ε sg p0 p1 p2 p3 p4 => exact Benitoite.Release.HasTypeClausesQ.cons p0 p1 p2 p3 p4 (hc (.comp (List.replicate sg.tparams.length .value ++ κ) Ψ.hideBuilders Q (sg.tparams ++ C) (some (.cont sg.ret (t.shift k 0) (Benitoite.Release.Eff.shift k 0 ε)) :: (Benitoite.Release.binds sg.params ++ Benitoite.Release.shiftEnv k Γ)) (R.map (Benitoite.Release.Ty.shift k 0)) body (t.shift k 0) (Benitoite.Release.Eff.shift k 0 ε) []) (by simp)) (hc (.clauses κ Ψ Q C Γ R εb cs t ε Δ) (by simp))
  | @Failure_one κ Ψ Q C Δ Γ E R body t ec p0 p1 p2 => exact Benitoite.Release.HasFailureClause.one p0 p1 p2 (hc (.comp (.value :: κ) Ψ.hideBuilders Q (({} : Benitoite.Release.TParam) :: C) (none :: some (E.shift 1 0) :: Benitoite.Release.shiftEnv 1 Γ) (R.map (Benitoite.Release.Ty.shift 1 0)) body (t.shift 1 0) (Benitoite.Release.Eff.shift 1 0 ec) []) (by simp))

theorem LegacyOutputInput.old {K P0 B0 B j}
    (h : LegacyOutputInput K P0 B0 B j) : j.OldHolds P0 B0 := by
  induction h with
  | node rule _ _ ih => exact rule.old K P0 B0 _ _ ih

theorem LegacyOutputInput.regular {K P0 B0 B j}
    (h : LegacyOutputInput K P0 B0 B j) : LegacyNodeRegular K P0 B0 B j := by
  cases h with
  | node _ regular _ => exact regular

end
end Benitoite.Release.Refinement
```

## LegacyTables

```lean
import Benitoite.Release.Refinement.LegacyRegularity
import Benitoite.Release.WellFormed

/-! # 旧表との対応と構成子の形成 -/
namespace Benitoite.Release.Refinement
noncomputable section

structure LegacyPrimSignature (s0 : Benitoite.Release.PrimSig) (s : PrimSig) : Prop where
  constraints : s.tparams.map TParamDecl.constraints = s0.tparams
  neffs : s.neffs = s0.neffs
  names : s.names = s0.names
  params : s.params = embedParameters s0.params
  ret : s.ret = (embedTy s0.ret).shiftV s0.params.length 0
  eff : s.eff = (embedEff s0.eff).shiftV s0.params.length 0
  kind : s.kind = embedPrimKind s0.kind
  opEff : s.opEff = s0.opEff
  rkinds : s.rkinds = s0.rkinds
  shape : s.shape = s0.shape
  admits : ∀ C ts, s0.admits C ts → s.admits C (Ty.normTys (embedTys ts))

/-- 新型付けや遷移の結論ではなく、表の各位置の対応を読む。 -/
structure LegacyTables (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) : Prop where
  primitives : ∀ b s0, B0.sig b = some s0 → ∃ s, B.sig b = some s ∧ LegacyPrimSignature s0 s
  sat : ∀ C a p, B0.sat C a p → B.sat C (embedTy a).norm p
  resources : B.isResource = B0.isResource
  effects : B.effects = B0.effects
  refGet : B.refGet = B0.refGet
  refSet : B.refSet = B0.refSet
  effKind : B.effKind = B0.effKind
  valKind : B.valKind = B0.valKind
  valContent : ∀ o, B.valContent o = (B0.valContent o).map embedTy
  ranges : ∀ b rs, B0.admitsR b rs → B.admitsR b (rs.map embedRange)
  constructorArity : ∀ c cd c' cd', P0.cons c = some cd → P0.cons c' = some cd' →
    cd.data = cd'.data → cd.ntys = cd'.ntys
  constructorFields : ∀ c cd, P0.cons c = some cd → ∀ a ∈ cd.args,
    Ty.Annotation (embedProgramWithKinds K P0) (List.replicate cd.ntys ({} : TParam)) [] (embedTy a) ∧
    Ty.HasKind (embedProgramWithKinds K P0) (List.replicate cd.ntys .value) (embedTy a) .value
  constructorScope : ∀ c cd, P0.cons c = some cd → ∀ a ∈ cd.args,
    (embedTy a).SourceScoped 0 cd.ntys 0 0

end
end Benitoite.Release.Refinement
```

## LegacyTableFacts

```lean
import Benitoite.Release.Refinement.LegacyTables

/-! # 旧表から構成子の形成と不変の変性を導く -/
namespace Benitoite.Release.Refinement
noncomputable section

private theorem legacy_varianceArgs_iff (P : Program) (vs : List Variance) (p : Polarity) (as : List Ty) :
    varianceArgsOK P vs p (List.replicate as.length .invariant) as ↔ varianceTysOK P vs .both as := by
  induction as with
  | nil => rfl
  | cons a as ih => simp only [List.length_cons, List.replicate_succ, varianceArgsOK,
      Polarity.compose, varianceTysOK, ih]

mutual
  theorem embedTy_invariantVariance {K P0 n} (a : Benitoite.Release.Ty)
      (h : (embedTy a).WF 0 n 0) (p : Polarity) :
      Ty.VarianceOK (embedProgramWithKinds K P0) (List.replicate n .invariant) p (embedTy a) := by
    cases a with
    | base _ | «opaque» _ _ | bytes | ctor _ => trivial
    | tvar i => exact ⟨.invariant, by simp [show i < n from h], by cases p <;> trivial⟩
    | list a | reference a | lazy a | set a | dict _ a => exact embedTy_invariantVariance a h _
    | data d as =>
      simp only [embedTy, Ty.VarianceOK, embedProgramWithKinds_varianceFor]
      rw [legacy_varianceArgs_iff]
      exact embedTys_invariantVariance as h .both
    | fn ns ps r e =>
      exact ⟨embedTys_invariantVariance ps h.2.1 _, embedTy_invariantVariance r h.2.2.1 _,
        embedEff_invariantVariance e h.2.2.2.1 _⟩
    | cont a b e => exact ⟨embedTy_invariantVariance a h.1 _, embedTy_invariantVariance b h.2.1 _,
        embedEff_invariantVariance e h.2.2.1 _⟩
    | map a b => exact ⟨embedTy_invariantVariance a h.1 _, embedTy_invariantVariance b h.2 _⟩
    | tapp i as => exact ⟨⟨.invariant, by simp [h.1], trivial⟩,
        embedTys_invariantVariance as h.2 .both⟩
  theorem embedTys_invariantVariance {K P0 n} (as : List Benitoite.Release.Ty)
      (h : Ty.WFList 0 n 0 (embedTys as)) (p : Polarity) :
      varianceTysOK (embedProgramWithKinds K P0) (List.replicate n .invariant) p (embedTys as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨embedTy_invariantVariance a h.1 p, embedTys_invariantVariance as h.2 p⟩
  theorem embedEff_invariantVariance {K P0 n} (e : Benitoite.Release.Eff)
      (h : (embedEff e).WF 0 n 0) (p : Polarity) :
      Eff.VarianceOK (embedProgramWithKinds K P0) (List.replicate n .invariant) p (embedEff e) := by
    cases e; exact embedTys_invariantVariance _ h .both
end

theorem LegacyTables.dataArity {K P0 B0 B} (tables : LegacyTables K P0 B0 B)
    {c cd} (hc : P0.cons c = some cd) :
    (embedProgramWithKinds K P0).DataArity cd.data cd.ntys := by
  refine ⟨⟨c, embedConDecl cd, by simp only [embedProgramWithKinds_cons, hc, Option.map_some], rfl⟩, ?_⟩
  intro c' cd' hc' hd
  obtain ⟨old, ho, rfl⟩ := Option.map_eq_some_iff.mp hc'
  exact tables.constructorArity c' old c cd ho hc hd

theorem LegacyTables.constructor_scoped {K P0 B0 B} (tables : LegacyTables K P0 B0 B)
    {c cd} (hc : P0.cons c = some cd) :
    (embedConDecl cd).Scoped (embedProgramWithKinds K P0) := by
  intro a ha
  obtain ⟨old, hold, rfl⟩ := List.mem_map.mp (by simpa [embedConDecl] using ha)
  exact ⟨tables.constructorScope c cd hc old hold, tables.constructorFields c cd hc old hold⟩

theorem LegacyTables.varianceValid {K P0 B0 B} (tables : LegacyTables K P0 B0 B) :
    (embedProgramWithKinds K P0).VarianceValid := by
  constructor
  · intro d info h; cases h
  · intro c cd hc
    obtain ⟨old, ho, rfl⟩ := Option.map_eq_some_iff.mp hc
    refine ⟨?_, ?_⟩
    · intro info h; cases h
    · intro a ha
      obtain ⟨oldA, hA, rfl⟩ := List.mem_map.mp (by simpa [embedConDecl] using ha)
      obtain ⟨annotation, kind⟩ := tables.constructorFields c old ho oldA hA
      refine ⟨annotation, kind, ?_⟩
      exact embedTy_invariantVariance oldA
        (by simpa only [List.length_replicate, List.length_nil, embedConDecl] using annotation.wf) .positive

end
end Benitoite.Release.Refinement
```

## LegacyValues

```lean
import Benitoite.Release.Refinement.LegacyTables

/-! # 旧構文からの値の葉と正規化の限定等号 -/
namespace Benitoite.Release.Refinement
noncomputable section

variable {P : Program} {B : Builtins} {Ψ : StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : List TParam} {Γ : Ctx} {Φ : List Pred}

theorem embed_const (c : Benitoite.Release.Const) (hc : ConstOK B (embedConst c)) :
    HasTypeVQ P B Ψ Q C Γ Φ (.const (embedConst c)) (embedTy c.type) := by
  rw [← Const.type_embed]; exact .V_Const hc

theorem embed_bytes (bs : List Nat) (hb : ∀ b ∈ bs, b ≤ 255) :
    HasTypeVQ P B Ψ Q C Γ Φ (.bytesV bs) .bytes := .V_Bytes hb

theorem embed_checked {o k range target}
    (hk : B.valKind o = some k) (hc : B.valContent o = none)
    (hm : Scope.Domain.Range.MemK k range target) :
    HasTypeVQ P B Ψ Q C Γ Φ (.checked target) (.scoped o k (.fixed (.absolute range))) :=
  .V_Checked hk hc hm

theorem embed_checkedRequest {o range target req T}
    (hk : B.valKind o = some .endpoint) (hc : B.valContent o = some T)
    (ht : HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] [] (embedVal req) T.norm)
    (hg : groundVal (embedVal req) = true) (he : (embedVal req).reqTarget = some target)
    (hm : Scope.Domain.Range.MemK .endpoint range target) :
    HasTypeVQ P B Ψ Q C Γ Φ (.checkedRequest target (embedVal req))
      (.scoped o .endpoint (.fixed (.absolute range))) := .V_CheckedRequest hk hc ht hg he hm

theorem embed_checked_opaque {o k range target}
    (hk : B.valKind o = some k) (hc : B.valContent o = none)
    (hm : Scope.Domain.Range.MemK k range target) :
    HasTypeVQ P B Ψ Q C Γ Φ (embedVal (.checked target)) (embedTy (.opaque o (.fixed range))) :=
  .V_Sub (embed_checked hk hc hm) .scoped_forget trivial trivial trivial

theorem embed_checkedRequest_opaque {o range target req T}
    (hk : B.valKind o = some .endpoint) (hc : B.valContent o = some T)
    (ht : HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] [] (embedVal req) T.norm)
    (hg : groundVal (embedVal req) = true) (he : (embedVal req).reqTarget = some target)
    (hm : Scope.Domain.Range.MemK .endpoint range target) :
    HasTypeVQ P B Ψ Q C Γ Φ (embedVal (.checkedRequest target req)) (embedTy (.opaque o (.fixed range))) :=
  .V_Sub (embed_checkedRequest hk hc ht hg he hm) .scoped_forget trivial trivial trivial

theorem embed_normal_eq_iff (a b : Benitoite.Release.Ty) :
    (embedTy a).norm = (embedTy b).norm ↔ a.norm = b.norm := by
  constructor
  · intro h; exact embedTy_injective (by simpa only [embedTy_norm] using h)
  · intro h; rw [← embedTy_norm, ← embedTy_norm, h]

/- 旧型には値を読む述語がない。文脈の長さと内容への非依存を構文で示す。 -/
mutual
  theorem embedTy_wf_values (a : Benitoite.Release.Ty) (nr nt n m : Nat) :
      (embedTy a).WF nr nt n ↔ (embedTy a).WF nr nt m := by
    cases a <;> simp only [embedTy, Ty.WF, (fun a => embedTy_wf_values a nr nt n m), (fun as => embedTys_wf_values as nr nt n m), (fun e => embedEff_wf_values e nr nt n m)]
  theorem embedTys_wf_values (as : List Benitoite.Release.Ty) (nr nt n m : Nat) :
      Ty.WFList nr nt n (embedTys as) ↔ Ty.WFList nr nt m (embedTys as) := by
    cases as <;> simp only [embedTys, Ty.WFList, (fun a => embedTy_wf_values a nr nt n m), (fun as => embedTys_wf_values as nr nt n m)]
  theorem embedEff_wf_values (e : Benitoite.Release.Eff) (nr nt n m : Nat) :
      (embedEff e).WF nr nt n ↔ (embedEff e).WF nr nt m := by
    cases e; exact embedTys_wf_values _ nr nt n m
end

mutual
  theorem embedTy_sorted (a : Benitoite.Release.Ty) (Γ : Ctx) : (embedTy a).Sorted Γ := by
    cases a <;> simp only [embedTy, Ty.Sorted]
    all_goals first | trivial | exact embedTy_sorted _ Γ | exact embedTys_sorted _ Γ | skip
    case fn ns ps r e => exact ⟨embedTys_sorted ps Γ, embedTy_sorted r Γ, embedEff_sorted e Γ⟩
    case cont a b e => exact ⟨embedTy_sorted a Γ, embedTy_sorted b Γ, embedEff_sorted e Γ⟩
    case map a b => exact ⟨embedTy_sorted a Γ, embedTy_sorted b Γ⟩
  theorem embedTys_sorted (as : List Benitoite.Release.Ty) (Γ : Ctx) : sortedTys Γ (embedTys as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨embedTy_sorted a Γ, embedTys_sorted as Γ⟩
  theorem embedEff_sorted (e : Benitoite.Release.Eff) (Γ : Ctx) : sortedEff Γ (embedEff e) := by
    cases e; exact embedTys_sorted _ Γ
end

mutual
  theorem embedTy_declared_context (a : Benitoite.Release.Ty) (P : Program)
      (C D : List TParam) (Γ Δ : Ctx) :
      (embedTy a).Declared P C Γ ↔ (embedTy a).Declared P D Δ := by
    cases a <;> simp only [embedTy, Ty.Declared, (fun a => embedTy_declared_context a P C D Γ Δ), (fun as => embedTys_declared_context as P C D Γ Δ),
      (fun e => embedEff_declared_context e P C D Γ Δ)]
    case ctor c => cases c <;> rfl
  theorem embedTys_declared_context (as : List Benitoite.Release.Ty) (P : Program)
      (C D : List TParam) (Γ Δ : Ctx) :
      declaredTys P C Γ (embedTys as) ↔ declaredTys P D Δ (embedTys as) := by
    cases as <;> simp only [embedTys, declaredTys, (fun a => embedTy_declared_context a P C D Γ Δ), (fun as => embedTys_declared_context as P C D Γ Δ)]
  theorem embedEff_declared_context (e : Benitoite.Release.Eff) (P : Program)
      (C D : List TParam) (Γ Δ : Ctx) :
      declaredEff P C Γ (embedEff e) ↔ declaredEff P D Δ (embedEff e) := by
    cases e; exact embedTys_declared_context _ P C D Γ Δ
end

theorem LegacyTypesInput.kindArgs {K P0 Δ ts ks} (h : LegacyTypesInput K P0 Δ ts ks) :
    LegacyKindArgs K P0 Δ.kinds ts ks :=
  ⟨h.1, fun i a k ha hk => (h.2 i a k ha hk).1⟩

theorem LegacyTypeInput.annotation {K P0 Δ a k} (h : LegacyTypeInput K P0 Δ a k)
    (nr : Δ.nr = 0) (count : Δ.kinds.length = Δ.constraints.length) :
    Ty.Annotation (embedProgramWithKinds K P0) Δ.constraints (List.replicate Δ.nv none) (embedTy a) :=
  ⟨by simpa only [nr, List.length_replicate, count] using h.2.1, h.2.2.1, h.2.2.2.1⟩

theorem LegacyTypeInput.normal_kind {K P0 Δ a k} (h : LegacyTypeInput K P0 Δ a k) :
    (embedTy a).norm.HasKind (embedProgramWithKinds K P0) Δ.kinds k := h.1.norm

theorem LegacyTypeInput.annotation_at {K P0 Δ a k} (h : LegacyTypeInput K P0 Δ a k)
    (nr : Δ.nr = 0) (count : Δ.kinds.length = Δ.constraints.length) (Γ : Ctx) :
    Ty.Annotation (embedProgramWithKinds K P0) Δ.constraints Γ (embedTy a) := by
  refine ⟨?_, embedTy_sorted a Γ, ?_⟩
  · have moved := (embedTy_wf_values a Δ.nr Δ.kinds.length Δ.nv Γ.length).mp h.2.1
    simpa only [nr, count] using moved
  · exact (embedTy_declared_context a _ _ _ _ _).mp h.2.2.2.1

theorem LegacyTypeInput.annotation_normal {K P0 Δ a k} (h : LegacyTypeInput K P0 Δ a k)
    (nr : Δ.nr = 0) (count : Δ.kinds.length = Δ.constraints.length) (Γ : Ctx) :
    Ty.Annotation (embedProgramWithKinds K P0) Δ.constraints Γ (embedTy a).norm :=
  (h.annotation_at nr count Γ).norm

/-- 最上位の範囲の具体化は、同じ長さの列どうしで WF を保つ。型変数は変えない。 -/
theorem embed_instTarget_wf_iff (a : Benitoite.Release.Ty)
    {rs qs : List Scope.Domain.Range} (count : rs.length = qs.length) (nr nt nv : Nat) :
    (embedTy (a.instTarget rs)).WF nr nt nv ↔ (embedTy (a.instTarget qs)).WF nr nt nv := by
  cases a with
  | «opaque» o ix =>
    cases ix with
    | fixed r => rfl
    | rvar i =>
      cases hs : rs[i]? with
      | none =>
        cases ht : qs[i]? with
        | none => simp only [Benitoite.Release.Ty.instTarget, Scope.Signature.Ix.inst, hs, ht]
        | some r =>
          have hle := List.getElem?_eq_none_iff.mp hs
          have hlt := (List.getElem?_eq_some_iff.mp ht).1
          omega
      | some r =>
        cases ht : qs[i]? with
        | none =>
          have hle := List.getElem?_eq_none_iff.mp ht
          have hlt := (List.getElem?_eq_some_iff.mp hs).1
          omega
        | some q => simp only [Benitoite.Release.Ty.instTarget, Scope.Signature.Ix.inst, hs, ht,
            embedTy, embedIx, Ty.WF, RangeIx.WF]
  | _ => rfl

theorem embed_instTargetList_wf_iff (as : List Benitoite.Release.Ty)
    {rs qs : List Scope.Domain.Range} (count : rs.length = qs.length) (nr nt nv : Nat) :
    Ty.WFList nr nt nv (embedTys (as.map (Benitoite.Release.Ty.instTarget rs))) ↔
      Ty.WFList nr nt nv (embedTys (as.map (Benitoite.Release.Ty.instTarget qs))) := by
  induction as with
  | nil => rfl
  | cons a as ih => simp only [List.map_cons, embedTys, Ty.WFList,
      embed_instTarget_wf_iff a count nr nt nv, ih]

/-- Top と同じ個数の節の範囲 S は、署名の引数の形成を保持する。 -/
theorem embed_clause_signature_wf (names : List String) (params : List Benitoite.Release.Ty)
    (ret : Benitoite.Release.Ty) (eff : Benitoite.Release.Eff)
    (rs qs : List Scope.Domain.Range) (count : rs.length = qs.length) (nr nt nv : Nat)
    (h : (embedTy (.fn names (params.map (Benitoite.Release.Ty.instTarget rs)) ret eff)).WF nr nt nv) :
    (embedTy (.fn names (params.map (Benitoite.Release.Ty.instTarget qs)) ret eff)).WF nr nt nv := by
  refine ⟨?_, (embed_instTargetList_wf_iff params count nr nt nv).mp h.2.1, h.2.2⟩
  simpa only [NamesWF, embedTys_eq_map, List.length_map] using h.1

/-- opSig の Top に対する形成を、実際に選んだ節の範囲へ渡す。 -/
theorem legacy_opSigAt_signature_wf {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins}
    {o : Benitoite.Release.OpRef} {topSig selected : Benitoite.Release.OpSig} {S : Scope.Domain.Range}
    (source : Benitoite.Release.opSig P0 B0 o = some topSig)
    (target : Benitoite.Release.opSigAt P0 B0 S o = some selected)
    (h : (embedTy (.fn topSig.names topSig.params topSig.ret
      (Benitoite.Release.Eff.single topSig.eff))).WF 0 topSig.tparams.length 0) :
    (embedTy (.fn selected.names selected.params selected.ret
      (Benitoite.Release.Eff.single selected.eff))).WF 0 selected.tparams.length 0 := by
  cases o with
  | fail => cases source
  | user o =>
    cases ho : P0.ops o with
    | none => simp [Benitoite.Release.opSig, ho] at source
    | some od =>
      simp only [Benitoite.Release.opSig, Benitoite.Release.opSigAt, ho, Option.map_some, Option.some.injEq] at source target
      subst topSig; subst selected; exact h
  | prim b =>
    cases hb : B0.sig b with
    | none => simp [Benitoite.Release.opSig, hb] at source
    | some sg =>
      cases he : sg.opEff with
      | none => simp [Benitoite.Release.opSig, hb, he] at source
      | some effect =>
        simp only [Benitoite.Release.opSig, Benitoite.Release.opSigAt, hb, he, Option.some.injEq] at source target
        subst topSig; subst selected
        exact embed_clause_signature_wf sg.names sg.params sg.ret (Benitoite.Release.Eff.single effect)
          sg.topRanges (List.replicate sg.nranges S) (by simp [Benitoite.Release.PrimSig.topRanges]) 0 sg.tparams.length 0 h

theorem LegacyClausesInput.signature_wf {K P0 B0 B Δ o n k body cs}
    (input : LegacyClausesInput K P0 B0 B Δ (.mk o n k body :: cs))
    {S : Scope.Domain.Range} {sg : Benitoite.Release.OpSig}
    (lookup : Benitoite.Release.opSigAt P0 B0 S o = some sg) :
    (embedTy (.fn sg.names sg.params sg.ret (Benitoite.Release.Eff.single sg.eff))).WF 0 sg.tparams.length 0 := by
  obtain ⟨⟨topSig, hs, hk, _, annotation, _⟩, _⟩ := input
  apply legacy_opSigAt_signature_wf hs lookup
  simpa only [List.length_replicate, hk] using annotation.2.1

end
end Benitoite.Release.Refinement
```

