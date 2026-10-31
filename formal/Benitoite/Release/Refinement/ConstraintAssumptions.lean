import Benitoite.Release.Refinement.TypeRenaming
import Benitoite.Release.Refinement.TypedFacts
import Benitoite.Release.Refinement.ExternalResponse
import Benitoite.Release.Refinement.BuiltinResponse
import Benitoite.Release.Refinement.Semantics

/-!
# 組込みの制約と値注釈の移送の条件

表のsat/admits自体は任意の述語であるため、保存則を証拠として明示する。
モデルは篩の条件と値の番号を読まないcarrierの骨格からこの証拠を作る。
-/
namespace Benitoite.Release.Refinement

def TypedValueImages (P : Program) (B : Builtins) (Ψ : StoreTy) (Q : NoFailCtx)
    (C : List TParam) (Γ Δ : Ctx) (Ξ : List Pred) (ν : Nat → Val) : Prop :=
  ∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) → a.Ordinary →
    HasTypeVQ P B Ψ Q C Δ Ξ (ν i) (substTyValues ν a)

structure Builtins.ValueAssumptions (P : Program) (B : Builtins) : Prop where
  sat_rename : ∀ C Γ Δ a p (ξ : Nat → Nat), (∀ i j, i < j → ξ i < ξ j) →
    Ty.Annotation P C Γ a → Ty.Annotation P C Δ (renameTy ξ a) →
    B.sat C a p → B.sat C (renameTy ξ a) p
  admits_rename : ∀ b sg C Γ Δ ts (ξ : Nat → Nat), B.sig b = some sg →
    (∀ i j, i < j → ξ i < ξ j) → TypeAnnotations P C Γ ts →
    TypeAnnotations P C Δ (ts.map (renameTy ξ)) →
    sg.admits C ts → sg.admits C (ts.map (renameTy ξ))
  sat_values : ∀ Ψ Q C Γ Δ Ξ ν a p, TypedValueImages P B Ψ Q C Γ Δ Ξ ν →
    Ty.Annotation P C Γ a → B.sat C a p → B.sat C (substTyValues ν a) p
  admits_values : ∀ b sg Ψ Q C Γ Δ Ξ ν ts, B.sig b = some sg →
    TypedValueImages P B Ψ Q C Γ Δ Ξ ν → TypeAnnotations P C Γ ts →
    sg.admits C ts → sg.admits C (ts.map (substTyValues ν))

/-- 型パラメータの制約を保つ改名と、閉じた型による具体化の条件。 -/
structure Builtins.TypeAssumptions (P : Program) (B : Builtins) : Prop where
  sat_renameTypes : ∀ C C' Γ Δ a p ρ, TypeParamRenaming C C' ρ →
    Ty.Annotation P C Γ a → Ty.Annotation P C' Δ (a.renameTypes ρ) →
    B.sat C a p → B.sat C' (a.renameTypes ρ) p
  admits_renameTypes : ∀ b sg C C' Γ Δ ts ρ, B.sig b = some sg → TypeParamRenaming C C' ρ →
    TypeAnnotations P C Γ ts → TypeAnnotations P C' Δ (ts.map (fun a => a.renameTypes ρ)) →
    sg.admits C ts → sg.admits C' (ts.map (fun a => a.renameTypes ρ))
  sat_subst : ∀ C0 C1 a p ts es,
    B.sat (C1 ++ C0) a p →
    (∀ t ∈ ts, t.WF 0 0 0) → SatAll B C1 ts C0 → ts.length = C0.length →
    B.sat C1 (a.substAt C1.length ts es) p
  admits_subst : ∀ b sg C0 C1 ts ts' es', B.sig b = some sg → sg.admits (C1 ++ C0) ts →
    (∀ t ∈ ts', t.WF 0 0 0) → SatAll B C1 ts' C0 → ts'.length = C0.length →
    sg.admits C1 (ts.map (Ty.substAt C1.length ts' es'))

/-- 値の置換が多相節の下へ入るときに使う二種類の保存則。 -/
structure Builtins.SubstitutionAssumptions (P : Program) (B : Builtins) : Prop extends
    Builtins.ValueAssumptions P B, Builtins.TypeAssumptions P B


theorem Builtins.TypeAssumptions.sat_shiftTypes {P B} (h : Builtins.TypeAssumptions P B)
    {C Γ Δ a p} (extra : List TParam) (ha : Ty.Annotation P C Γ a)
    (hb : Ty.Annotation P (extra ++ C) Δ (a.shift extra.length 0)) (hs : B.sat C a p) :
    B.sat (extra ++ C) (a.shift extra.length 0) p := by
  have hr : TypeParamRenaming C (extra ++ C) (shiftIndex extra.length 0) := by
    simpa only [List.nil_append, List.length_nil] using TypeParamRenaming.insert [] extra C
  simpa only [Ty.renameTypes_shift] using
    h.sat_renameTypes C (extra ++ C) Γ Δ a p _ hr ha (by simpa only [Ty.renameTypes_shift] using hb) hs

theorem Builtins.TypeAssumptions.admits_shiftTypes {P B} (h : Builtins.TypeAssumptions P B)
    {C Γ Δ ts b sg} (extra : List TParam) (hl : B.sig b = some sg)
    (ha : TypeAnnotations P C Γ ts)
    (hb : TypeAnnotations P (extra ++ C) Δ (ts.map (Ty.shift extra.length 0)))
    (hs : sg.admits C ts) : sg.admits (extra ++ C) (ts.map (Ty.shift extra.length 0)) := by
  have hr : TypeParamRenaming C (extra ++ C) (shiftIndex extra.length 0) := by
    simpa only [List.nil_append, List.length_nil] using TypeParamRenaming.insert [] extra C
  simpa only [Ty.renameTypes_shift] using
    h.admits_renameTypes b sg C (extra ++ C) Γ Δ ts _ hl hr ha
      (by simpa only [Ty.renameTypes_shift] using hb) hs

/-- 旧の外側への延長は、恒等の型改名から得る。注釈の照合を明示する。 -/
theorem Builtins.TypeAssumptions.sat_local {P B} (h : Builtins.TypeAssumptions P B)
    {C Γ a p} (extra : List TParam) (ha : Ty.Annotation P C Γ a)
    (hb : Ty.Annotation P (C ++ extra) Γ a) (hs : B.sat C a p) : B.sat (C ++ extra) a p := by
  have hn : a.norm = a := Ty.canonical_of_wf ha.wf
  simpa only [Ty.renameTypes_id_eq_norm, hn] using h.sat_renameTypes C (C ++ extra) Γ Γ a p id
    (TypeParamRenaming.suffix C extra) ha (by simpa only [Ty.renameTypes_id_eq_norm, hn] using hb) hs

theorem Builtins.TypeAssumptions.admits_local {P B} (h : Builtins.TypeAssumptions P B)
    {C Γ ts b sg} (extra : List TParam) (hl : B.sig b = some sg)
    (ha : TypeAnnotations P C Γ ts) (hb : TypeAnnotations P (C ++ extra) Γ ts)
    (hs : sg.admits C ts) : sg.admits (C ++ extra) ts := by
  have hn : ts.map (fun a => a.renameTypes id) = ts := by
    calc
      ts.map (fun a => a.renameTypes id) = ts.map id := List.map_congr_left (fun a hm =>
        (Ty.renameTypes_id_eq_norm a).trans (Ty.canonical_of_wf (ha a hm).wf))
      _ = ts := List.map_id ts
  simpa only [hn] using h.admits_renameTypes b sg C (C ++ extra) Γ Γ ts id hl
    (TypeParamRenaming.suffix C extra) ha (by simpa only [hn] using hb) hs

theorem SatAll.map {B C ts tps} (h : SatAll B C ts tps) (f : Ty → Ty)
    (hf : ∀ a ∈ ts, ∀ p, B.sat C a p → B.sat C (f a) p) : SatAll B C (ts.map f) tps := by
  refine ⟨by simpa using h.1, ?_⟩
  intro i a p hi hp
  rw [List.getElem?_map] at hi
  obtain ⟨x, hx, rfl⟩ := Option.map_eq_some_iff.mp hi
  exact hf x (List.mem_of_getElem? hx) p (h.2 i x p hx hp)

/-- PathBasesの発行が要求する閉じた、引数のない署名。 -/
structure PrimSig.PathBasesShape (s : PrimSig) : Prop where
  types : s.tparams = []
  rows : s.neffs = 0
  ranges : s.rkinds = []
  arguments : s.params = []
  result : s.ret = .pathBases
  effect : s.eff = Eff.single processEnvironmentEff
  operation : s.opEff = some processEnvironmentEff

/-- 可変のセルと明示遅延の項目の形。PathBasesはこの分類へ入れない。 -/
def PrimSig.StoreShape (s : PrimSig) : Prop :=
  match s.kind with
  | .refNew => s.names = ["value"] ∧ s.tparams.length = 1 ∧ s.neffs = 0 ∧
      s.params = [.tvar 0] ∧ s.ret = .reference (.tvar 0) ∧
      s.eff = Eff.single stateEff ∧ s.rkinds = []
  | .refGet => s.names = ["reference"] ∧ s.tparams.length = 1 ∧ s.neffs = 0 ∧
      s.params = [.reference (.tvar 0)] ∧ s.ret = .tvar 0 ∧
      s.eff = Eff.single stateEff ∧ s.rkinds = []
  | .refSet => s.names = ["reference", "value"] ∧ s.tparams.length = 1 ∧ s.neffs = 0 ∧
      s.params = [.reference (.tvar 0), .tvar 0] ∧ s.ret = .base .unit ∧
      s.eff = Eff.single stateEff ∧ s.rkinds = []
  | .refUpdate => s.names = ["reference", "f"] ∧ s.tparams.length = 1 ∧ s.neffs = 0 ∧
      s.params = [.reference (.tvar 0), .fn ["value"] [.tvar 0] (.tvar 0) Eff.empty] ∧
      s.ret = .base .unit ∧ s.eff = Eff.single stateEff ∧ s.rkinds = []
  | .force => s.names = ["value"] ∧ s.tparams.length = 1 ∧ s.neffs = 0 ∧
      s.params = [.lazy (.tvar 0)] ∧ s.ret = .tvar 0 ∧ s.eff = Eff.empty ∧ s.rkinds = []
  | .pathBases => False
  | .pure | .io | .exit => True

/-- D28の信頼条件。旧欄の残りは担当する後続の群で加える。 -/
structure Builtins.CoreAssumptions (P : Program) (B : Builtins) : Prop extends
    Builtins.SubstitutionAssumptions P B, Builtins.ExternalAssumptions P B, Builtins.ResponseAssumptions P B where
  /-- σを発行する項目はC_IssuePathBasesと実行器の空引数の検査を満たす。 -/
  pathBases_shape : ∀ b s, B.sig b = some s → s.kind = .pathBases → s.PathBasesShape
  /-- 操作の分類には専用のσ発行も含む。IO応答の分類は変更しない。 -/
  opEff_io : ∀ b s l, B.sig b = some s → s.opEff = some l →
    s.kind = .io ∨ s.kind = .exit ∨ s.kind = .pathBases
  effect_ops : ∀ l bs b, B.effects l = some bs → b ∈ bs →
    ∃ s, B.sig b = some s ∧ (s.kind = .io ∨ s.kind = .exit ∨ s.kind = .pathBases) ∧ s.opEff = some l
  store_shape : ∀ b s, B.sig b = some s → s.kind ≠ .pathBases → s.StoreShape
  store_admits : ∀ b s C ts, B.sig b = some s → s.kind ≠ .pure → s.kind ≠ .io →
    s.kind ≠ .exit → s.kind ≠ .pathBases → ts.length = s.tparams.length → s.admits C ts

/-- 主定理のCoreAssumptionsから、補助の移送が使う四条件を供給する。 -/
theorem Builtins.CoreAssumptions.values {P B} (h : Builtins.CoreAssumptions P B) :
    Builtins.ValueAssumptions P B := h.toValueAssumptions

/-- 型付き像を多相節へ移すための、承認済みの保存則を取り出す。 -/
theorem Builtins.CoreAssumptions.substitutions {P B} (h : Builtins.CoreAssumptions P B) :
    Builtins.SubstitutionAssumptions P B := h.toSubstitutionAssumptions

/-- 主定理が使う応答の条件を同じ束から取り出す。 -/
theorem Builtins.CoreAssumptions.responses {P B} (h : Builtins.CoreAssumptions P B) :
    Builtins.ResponseAssumptions P B := h.toResponseAssumptions

/-- E_PathBasesApplyの署名とkindから、遷移先の計算の型付けを得る。 -/
theorem Builtins.CoreAssumptions.issuePathBases_typed {P B Ψ Q C Γ Φ R Δ b s}
    (h : Builtins.CoreAssumptions P B) (hs : B.sig b = some s) (hk : s.kind = .pathBases) :
    HasTypeCQ P B Ψ Q C Γ Φ R (.issuePathBases b) .pathBases (Eff.single processEnvironmentEff) Δ := by
  have sh := h.pathBases_shape b s hs hk
  exact .C_IssuePathBases b s hs hk sh.operation sh.arguments sh.result sh.effect

/-- 型・行・範囲の個数が合うPathBasesの呼出しは、実行器の空の具体化の検査を通る。 -/
theorem Builtins.CoreAssumptions.pathBases_empty_arguments {P B C nv s b Q ts es rs}
    (h : Builtins.CoreAssumptions P B) (hs : B.sig b = some s) (hk : s.kind = .pathBases)
    (ha : PrimitiveAdmissible C nv s Q ts es) (hr : B.RangeAdmissible b s rs) :
    ts = [] ∧ es = [] ∧ rs = [] := by
  have sh := h.pathBases_shape b s hs hk
  have ht := ha.typeCount
  have he := ha.rowCount
  have hrr := hr.1
  rw [sh.types] at ht
  rw [sh.rows] at he
  rw [sh.ranges] at hrr
  exact ⟨List.length_eq_zero_iff.mp ht, List.length_eq_zero_iff.mp he, List.length_eq_zero_iff.mp hrr⟩

/-- 型付きの引数の束も、引数なしの署名では空になる。 -/
theorem Builtins.CoreAssumptions.pathBases_empty_values {P B Ψ Q C Γ Φ s b ts es rs ws a e}
    (h : Builtins.CoreAssumptions P B) (hs : B.sig b = some s) (hk : s.kind = .pathBases)
    (ha : HasTypeTelArgsQ P B Ψ Q C Γ Φ ws
      (instantiatedTel (Tel.instR rs s.tel) ts es) a e) : ws = [] := by
  have sh := h.pathBases_shape b s hs hk
  have ht : s.tel = .done s.ret s.eff := by
    cases hn : s.names <;> simp [PrimSig.tel, signatureTel, sh.arguments, hn]
  simp only [ht, Tel.instR, instantiatedTel, Tel.bind] at ha
  cases ha
  rfl

/-- E_PathBasesApplyの実際の遷移から到達先のviewを反転する局所の場合。 -/
theorem Builtins.CoreAssumptions.pathBases_apply_destination {P B σ q b s k μ}
    (h : Builtins.CoreAssumptions P B) (hv : q.view = .app (.prim b [] [] []) [])
    (hs : B.sig b = some s) (hk : s.kind = .pathBases) (hn : NoHandler k (.prim b)) :
    Step P B σ (.run q k μ) none (.run (.mk q.capture (.issuePathBases b)) k μ) ∧
    ∀ Ψ Q C Γ Φ R Δ, HasTypeCQ P B Ψ Q C Γ Φ R
      (.issuePathBases b) .pathBases (Eff.single processEnvironmentEff) Δ :=
  ⟨.E_PathBasesApply hv hs hk hn, fun _ _ _ _ _ _ _ => h.issuePathBases_typed hs hk⟩

end Benitoite.Release.Refinement
