import Benitoite.Release.Refinement.SubstitutionContracts
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

/-- 恒等の型改名は正規化を含む。外側への延長でも正規化した型を返す。 -/
theorem Builtins.TypeAssumptions.sat_local {P B} (h : Builtins.TypeAssumptions P B)
    {C Γ a p} (extra : List TParam) (ha : Ty.Annotation P C Γ a)
    (hb : Ty.Annotation P (C ++ extra) Γ a) (hs : B.sat C a p) : B.sat (C ++ extra) a.norm p := by
  simpa only [Ty.renameTypes_id_eq_norm] using h.sat_renameTypes C (C ++ extra) Γ Γ a p id
    (TypeParamRenaming.suffix C extra) ha
      (by simpa only [Ty.renameTypes_id_eq_norm] using hb.norm) hs

theorem Builtins.TypeAssumptions.admits_local {P B} (h : Builtins.TypeAssumptions P B)
    {C Γ ts b sg} (extra : List TParam) (hl : B.sig b = some sg)
    (ha : TypeAnnotations P C Γ ts) (hb : TypeAnnotations P (C ++ extra) Γ ts)
    (hs : sg.admits C ts) : sg.admits (C ++ extra) (ts.map Ty.norm) := by
  simpa only [Ty.renameTypes_id_eq_norm] using
    h.admits_renameTypes b sg C (C ++ extra) Γ Γ ts id hl
      (TypeParamRenaming.suffix C extra) ha (by
        intro a ha
        obtain ⟨x, hx, rfl⟩ := List.mem_map.mp ha
        simpa only [Ty.renameTypes_id_eq_norm] using (hb x hx).norm) hs

theorem SatAll.map {B C ts tps} (h : SatAll B C ts tps) (f : Ty → Ty)
    (hf : ∀ a ∈ ts, ∀ p, B.sat C a.norm p → B.sat C (f a).norm p) : SatAll B C (ts.map f) tps := by
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
      s.eff = Eff.single stateEff ∧ s.rkinds = [] ∧ s.tparams.map TParamDecl.kind = [.value]
  | .refGet => s.names = ["reference"] ∧ s.tparams.length = 1 ∧ s.neffs = 0 ∧
      s.params = [.reference (.tvar 0)] ∧ s.ret = .tvar 0 ∧
      s.eff = Eff.single stateEff ∧ s.rkinds = [] ∧ s.tparams.map TParamDecl.kind = [.value]
  | .refSet => s.names = ["reference", "value"] ∧ s.tparams.length = 1 ∧ s.neffs = 0 ∧
      s.params = [.reference (.tvar 0), .tvar 0] ∧ s.ret = .base .unit ∧
      s.eff = Eff.single stateEff ∧ s.rkinds = [] ∧ s.tparams.map TParamDecl.kind = [.value]
  | .refUpdate => s.names = ["reference", "f"] ∧ s.tparams.length = 1 ∧ s.neffs = 0 ∧
      s.params = [.reference (.tvar 0), .fn ["value"] [.tvar 0] (.tvar 0) Eff.empty] ∧
      s.ret = .base .unit ∧ s.eff = Eff.single stateEff ∧ s.rkinds = [] ∧
      s.tparams.map TParamDecl.kind = [.value]
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
  ref_get : ∃ s, B.sig B.refGet = some s ∧ s.kind = .refGet
  ref_set : ∃ s, B.sig B.refSet = some s ∧ s.kind = .refSet
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
