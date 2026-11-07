import Benitoite.Exchange.FormationTypes
import Benitoite.Exchange.Builtins

/-! # 交換から作る宣言材料と組み込みの表の有限支持

交換の型と効果を有限の原子の一覧に対する支持の証拠とともに形成し（`Exchange.FormationTypes`）、宣言材料の全ての
署名の支持から、検査器の入力の表の支持（`CheckArguments.HeadTableSupport`）を導く。型付けの正しさは含まない
（設計書 07-04「篩を含む形式化の範囲」）。
-/
namespace Benitoite.Exchange.CheckSupport
open Benitoite.Release.Refinement.Surface.CheckTables (Materials ClassMaterial ImplMaterial lookup lookup_mem lookup_map)

namespace R
export Benitoite.Release.Refinement (Ty Eff Atom Tel ConDecl OpDecl MethSig PrimSig ExternalDecl ExternalKey signatureTel)
end R

/-- 引数・結果・効果の支持。 -/
def SigSupport (atoms : List R.Atom) (ps : List R.Ty) (r : R.Ty) (e : R.Eff) : Prop :=
  Benitoite.Release.Refinement.Ty.SupportList (· ∈ atoms) ps ∧ r.Support (· ∈ atoms) ∧ e.Support (· ∈ atoms)

theorem signatureTel_support {atoms : List R.Atom} :
    ∀ (names : List String) (ps : List R.Ty) (r : R.Ty) (e : R.Eff), SigSupport atoms ps r e →
      (R.signatureTel names ps r e).Support (· ∈ atoms)
  | [], _, _, _, h => ⟨h.2.1, h.2.2⟩
  | _ :: _, [], _, _, h => ⟨h.2.1, h.2.2⟩
  | _ :: names, _ :: ps, r, e, h => ⟨h.1.1, signatureTel_support names ps r e ⟨h.1.2, h.2.1, h.2.2⟩⟩

/-- 引数・結果・効果の支持から、依存列を含む署名の支持を得る。 -/
theorem signatureSupport {atoms : List R.Atom} {names : List String} {ps : List R.Ty} {r : R.Ty} {e : R.Eff}
    (h : SigSupport atoms ps r e) :
    Benitoite.Release.Refinement.Surface.CheckArguments.SignatureSupport atoms ps r e (R.signatureTel names ps r e) :=
  ⟨h.1, h.2.1, h.2.2, signatureTel_support names ps r e h⟩

theorem supportList_append {atoms : List R.Atom} {as bs : List R.Ty}
    (ha : Benitoite.Release.Refinement.Ty.SupportList (· ∈ atoms) as)
    (hb : Benitoite.Release.Refinement.Ty.SupportList (· ∈ atoms) bs) :
    Benitoite.Release.Refinement.Ty.SupportList (· ∈ atoms) (as ++ bs) := by
  rw [Benitoite.Release.Refinement.Ty.SupportList.iff] at ha hb ⊢
  intro t ht
  rcases List.mem_append.mp ht with h | h
  · exact ha t h
  · exact hb t h

/-- 辞書の引数の型（`.dict c (.tvar i)`）は効果を含まない。 -/
theorem dictTys_support (atoms : List R.Atom) (ds : List (String × Nat)) :
    Benitoite.Release.Refinement.Ty.SupportList (· ∈ atoms)
      (ds.map fun p => (Benitoite.Release.Refinement.Ty.dict p.1 (.tvar p.2))) := by
  rw [Benitoite.Release.Refinement.Ty.SupportList.iff]
  intro t ht
  obtain ⟨p, _, rfl⟩ := List.mem_map.mp ht
  exact trivial

theorem empty_support (atoms : List R.Atom) : Benitoite.Release.Refinement.Eff.empty.Support (· ∈ atoms) := by
  simp [Benitoite.Release.Refinement.Eff.empty, Benitoite.Release.Refinement.Eff.Support,
    Benitoite.Release.Refinement.Ty.SupportList]

/-- 関数の宣言の引数・結果・効果の支持から、辞書を含む核の署名の支持を得る。 -/
theorem funDecl_support {atoms : List R.Atom} {d : Benitoite.Release.Refinement.Surface.FunDecl}
    (h : SigSupport atoms d.params d.ret d.eff) :
    Benitoite.Release.Refinement.Surface.CheckArguments.SignatureSupport atoms d.coreParams d.ret d.eff d.tel :=
  signatureSupport ⟨supportList_append (dictTys_support atoms d.dictParams) h.1, h.2.1, h.2.2⟩

/-- 部分型の一覧の要素は、その性質を持つ。 -/
theorem mem_val {α : Type} {P : α → Prop} {xs : List {a // P a}} {a : α} (h : a ∈ xs.map Subtype.val) : P a := by
  obtain ⟨y, _, rfl⟩ := List.mem_map.mp h
  exact y.property

theorem lookup_eq_mem {α β : Type} [BEq α] [LawfulBEq α] {xs : List (α × β)} {k : α} {v : β}
    (h : xs.lookup k = some v) : (k, v) ∈ xs := by
  induction xs with
  | nil => cases h
  | cons p rest ih =>
    rcases p with ⟨k', v'⟩
    by_cases hk : k = k'
    · subst hk
      simp only [List.lookup, beq_self_eq_true, Option.some.injEq] at h
      subst h
      exact List.mem_cons_self
    · have hb : (k == k') = false := beq_false_of_ne hk
      simp only [List.lookup, hb] at h
      exact List.mem_cons_of_mem _ (ih h)

/-- 外部の関数の宣言の依存列の支持。外部の型の宣言は型を持たない。 -/
def ExternalSupport (atoms : List R.Atom) : R.ExternalDecl → Prop
  | .type _ => True
  | .function _ d => d.parameters.Support (· ∈ atoms)

/-- 宣言材料の全ての署名の支持。検査器の入力の表の支持の材料側の前提である。 -/
structure MaterialSupport (atoms : List R.Atom) (m : Materials) : Prop where
  defs : ∀ x ∈ m.defs, SigSupport atoms x.2.params x.2.ret x.2.eff
  cons : ∀ x ∈ m.cons, Benitoite.Release.Refinement.Ty.SupportList (· ∈ atoms) x.2.args
  ops : ∀ x ∈ m.ops, SigSupport atoms x.2.params x.2.ret Benitoite.Release.Refinement.Eff.empty ∧
    Benitoite.Release.Refinement.Atom.nameTop x.2.eff ∈ atoms
  methods : ∀ c ∈ m.classes, ∀ x ∈ c.2.methods, SigSupport atoms x.2.params x.2.ret x.2.eff
  impls : ∀ x ∈ m.impls, x.2.signature.target.Support (· ∈ atoms)
  trustedFuns : ∀ x ∈ m.trustedFuns, SigSupport atoms x.2.params x.2.ret x.2.eff
  trustedImpls : ∀ x ∈ m.trustedImpls, x.2.target.Support (· ∈ atoms)
  externals : ∀ x ∈ m.externals, ExternalSupport atoms x.2

/-- 取得関数の結果型は、構成子の欄の型の支持を持つ。 -/
private theorem accessorRet_support {atoms : List R.Atom} {c : String} {cd : R.ConDecl} {k : Nat} {cs : List String}
    (h : Benitoite.Release.Refinement.Ty.SupportList (· ∈ atoms) cd.args) :
    (Benitoite.Release.Refinement.Surface.accessorRet c cd k cs).Support (· ∈ atoms) := by
  have hb : (Benitoite.Release.Refinement.Surface.accessorBase cd k).Support (· ∈ atoms) := by
    unfold Benitoite.Release.Refinement.Surface.accessorBase
    rw [Benitoite.Release.Refinement.Ty.support_shiftV_iff]
    cases ha : cd.args[k]? with
    | none => exact trivial
    | some a => exact (Benitoite.Release.Refinement.Ty.SupportList.iff.mp h) a (List.mem_of_getElem? ha)
  unfold Benitoite.Release.Refinement.Surface.accessorRet
  split
  · exact hb
  · exact hb

/-- data の型の引数が型変数だけの型は、効果を含まない。 -/
private theorem dataVars_support (atoms : List R.Atom) (d : String) (n : Nat) :
    Benitoite.Release.Refinement.Ty.SupportList (· ∈ atoms)
      [Benitoite.Release.Refinement.Ty.data d ((List.range n).map Benitoite.Release.Refinement.Ty.tvar)] := by
  refine ⟨?_, trivial⟩
  show Benitoite.Release.Refinement.Ty.SupportList (· ∈ atoms) ((List.range n).map Benitoite.Release.Refinement.Ty.tvar)
  rw [Benitoite.Release.Refinement.Ty.SupportList.iff]
  intro t ht
  obtain ⟨i, _, rfl⟩ := List.mem_map.mp ht
  exact trivial

/-- 宣言材料の署名の支持と組み込みの署名の支持から、検査器の入力の表の支持を得る。 -/
theorem Materials.headTableSupport {atoms : List R.Atom} {m : Materials} {B : Benitoite.Release.Refinement.Builtins}
    (hm : MaterialSupport atoms m)
    (hp : ∀ b s, B.sig b = some s → SigSupport atoms s.params s.ret s.eff) :
    Benitoite.Release.Refinement.Surface.CheckArguments.HeadTableSupport atoms m.declarations B where
  dictionaries := ⟨by
    intro i d hd
    change ((lookup (m.impls.map (fun (n, im) => (n, im.decl))) i).map
      Benitoite.Release.Refinement.Surface.ImplDecl.toImplSig).or (lookup m.trustedImpls i) = some d at hd
    rw [lookup_map] at hd
    cases hl : lookup m.impls i with
    | some im =>
      simp only [hl, Option.map_some] at hd
      cases hd
      exact ⟨dictTys_support atoms _, hm.impls _ (lookup_mem hl)⟩
    | none =>
      simp only [hl, Option.map_none, Option.none_or] at hd
      exact ⟨dictTys_support atoms _, hm.trustedImpls _ (lookup_mem hd)⟩⟩
  funs := by
    intro f fd hd
    change (m.program.lookupFun Benitoite.Release.Refinement.Surface.Def.toFunDecl
      (@Benitoite.Release.Refinement.Surface.accessorDecl) Benitoite.Release.Refinement.Surface.testerDecl f).or
      (lookup m.trustedFuns f) = some fd at hd
    cases hl : m.program.lookupFun Benitoite.Release.Refinement.Surface.Def.toFunDecl
        (@Benitoite.Release.Refinement.Surface.accessorDecl) Benitoite.Release.Refinement.Surface.testerDecl f with
    | none =>
      simp only [hl, Option.none_or] at hd
      exact funDecl_support (hm.trustedFuns _ (lookup_mem hd))
    | some fd' =>
      simp only [hl] at hd
      cases hd
      unfold Benitoite.Release.Refinement.Surface.Program.lookupFun at hl
      cases hdef : m.program.defs f with
      | some d =>
        simp only [hdef, Option.some.injEq] at hl
        subst fd
        exact funDecl_support (hm.defs _ (lookup_mem hdef))
      | none =>
        simp only [hdef] at hl
        cases hacc : m.program.accessors f with
        | some ck =>
          rcases ck with ⟨c, k⟩
          simp only [hacc] at hl
          obtain ⟨cd, hcd, rfl⟩ := Option.map_eq_some_iff.mp hl
          have hc := hm.cons _ (lookup_mem hcd)
          exact funDecl_support ⟨dataVars_support atoms _ _, accessorRet_support hc, empty_support atoms⟩
        | none =>
          simp only [hacc] at hl
          cases ht : m.program.testers f with
          | none => simp only [ht] at hl; cases hl
          | some c =>
            simp only [ht] at hl
            obtain ⟨cd, _, rfl⟩ := Option.map_eq_some_iff.mp hl
            exact funDecl_support ⟨dataVars_support atoms _ _, trivial, empty_support atoms⟩
  prims := by
    intro b s hs
    exact signatureSupport (hp b s hs)
  ops := by
    intro o d hd
    have hx := hm.ops _ (lookup_mem hd)
    refine signatureSupport ⟨hx.1.1, hx.1.2.1, ⟨?_, trivial⟩⟩
    intro a ha
    rcases a with ⟨n, ix⟩ | i
    · rcases ix with r | i
      · rcases r with r | _ | _
        · by_cases hr : r = .top
          · subst hr
            have hn : n = d.eff := of_decide_eq_true ha
            subst hn
            exact hx.2
          · simp [hr] at ha
        · cases ha
        · cases ha
      · cases ha
    · cases ha
  methods := by
    intro c cd n ms hc hms
    change lookup (m.classes.map (fun (n, c) => (n, c.decl))) c = some cd at hc
    rw [lookup_map] at hc
    obtain ⟨cm, hcm, rfl⟩ := Option.map_eq_some_iff.mp hc
    exact signatureSupport (hm.methods _ (lookup_mem hcm) _ (lookup_mem hms))
  externals := by
    intro f d hd
    unfold Benitoite.Release.Refinement.Program.externalFunction at hd
    split at hd
    · next d' hl =>
      cases hd
      exact hm.externals _ (lookup_eq_mem hl)
    · cases hd

/-- 宣言の表の構成子の欄の型の支持（`CheckFormation.Input.Sound` の欄 `fields`）。 -/
theorem Materials.fieldsSupport {atoms : List R.Atom} {m : Materials} (hm : MaterialSupport atoms m) :
    ∀ c cd, m.declarations.core.cons c = some cd →
      Benitoite.Release.Refinement.Ty.SupportList (· ∈ atoms) cd.args :=
  fun _ _ h => hm.cons _ (lookup_mem h)

/-- 演算子の表の型引数は、演算子の型だけである（`Check.Input.Sound` の欄 `operators`）。 -/
theorem makeOpPrim_support (atoms : Eff) (entries : List OperatorEntry) (s : List R.Atom) :
    ∀ o t b ts, makeOpPrim atoms entries o t = some (b, ts) → t.Support (· ∈ s) →
      Benitoite.Release.Refinement.Ty.SupportList (· ∈ s) ts := by
  intro o t b ts h ht
  unfold makeOpPrim at h
  obtain ⟨name, _, he⟩ := Option.map_eq_some_iff.mp h
  cases he
  rcases o with op | _
  · cases op <;> first | exact ⟨ht, trivial⟩ | exact trivial
  · exact trivial

/-! ## 支持の証拠を持つ変換 -/

/-- 宣言の頭部の引数・結果・効果を、支持の証拠とともに形成する。 -/
def formedHeader (atoms : List R.Atom) (h : Header) :
    Except String {x : List R.Ty × R.Ty × R.Eff // SigSupport atoms x.1 x.2.1 x.2.2} := do
  let ps ← FormationTypes.formedTys atoms h.params
  let r ← FormationTypes.formedTy atoms h.ret
  let e ← FormationTypes.formedEff atoms h.eff
  return ⟨(ps.val, r.val, e.val), ps.property, r.property, e.property⟩

/-- data の宣言の構成子。欄の名前の数は引数の数と一致する。 -/
def formedConstructors (atoms : List R.Atom) (d : DataEntry) :
    Except String (List {x : String × R.ConDecl // Benitoite.Release.Refinement.Ty.SupportList (· ∈ atoms) x.2.args}) :=
  d.ctors.mapM fun c => do
    if let some fs := c.fields then checkNames fs c.args.length
    let args ← FormationTypes.formedTys atoms c.args
    return ⟨(c.name, { data := d.name, ntys := d.ntys, args := args.val }), args.property⟩

/-- 組み込みの項目の材料。引数・結果・効果は支持の証拠とともに形成する。 -/
def formedMaterial (atoms : List R.Atom) (p : BuiltinEntry) :
    Except String {x : BuiltinEntry × PrimMaterial // SigSupport atoms x.2.params x.2.ret x.2.eff} := do
  let m ← p.toMaterial
  let ps ← FormationTypes.formedTys atoms p.params
  let r ← FormationTypes.formedTy atoms p.ret
  let e ← FormationTypes.formedEff atoms p.eff
  return ⟨(p, { m with params := ps.val, ret := r.val, eff := e.val }), ps.property, r.property, e.property⟩

/-- 対象外の印のない prim の項目の材料の表（`BuiltinInput.primMaterials` と同じ項目）。 -/
def formedMaterials (atoms : List R.Atom) (b : BuiltinInput) :
    Except String (List {x : BuiltinEntry × PrimMaterial // SigSupport atoms x.2.params x.2.ret x.2.eff}) :=
  (b.prims.filter fun p => p.unconvertibleTypes.isEmpty && p.classConstraints.isEmpty).mapM (formedMaterial atoms)

/-- 支持の証拠を持つ材料から作る組み込みの表の署名は、同じ支持を持つ。 -/
theorem builtinsOf_support {atoms : List R.Atom} (b : BuiltinInput) (S : Benitoite.Release.SummaryTable)
    (ms : List {x : BuiltinEntry × PrimMaterial // SigSupport atoms x.2.params x.2.ret x.2.eff}) :
    ∀ name s, (builtinsOf b S (ms.map Subtype.val)).sig name = some s → SigSupport atoms s.params s.ret s.eff := by
  intro name s hs
  simp only [builtinsOf] at hs
  obtain ⟨⟨p, m⟩, hl, rfl⟩ := Option.map_eq_some_iff.mp hs
  unfold primLookup at hl
  exact mem_val (P := fun x : BuiltinEntry × PrimMaterial => SigSupport atoms x.2.params x.2.ret x.2.eff)
    (List.mem_of_find?_eq_some hl)

/-- 外部の宣言。関数の依存列は支持の証拠とともに形成する。 -/
def formedExternal (atoms : List R.Atom) (e : ExternalEntry) :
    Except String {x : R.ExternalKey × R.ExternalDecl // ExternalSupport atoms x.2} := do
  match ← e.toRelease, e with
  | (k, .type t), _ => return ⟨(k, .type t), trivial⟩
  | (k, .function f d), .function _ _ _ h _ =>
    let x ← formedHeader atoms h
    return ⟨(k, .function f { d with parameters := R.signatureTel h.names x.val.1 x.val.2.1 x.val.2.2 }),
      signatureTel_support _ _ _ _ x.property⟩
  | _, _ => throw "external declaration kind mismatch"

end Benitoite.Exchange.CheckSupport
