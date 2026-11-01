import Benitoite.Release.Refinement.TypeRows
import Benitoite.Release.Refinement.LegacyInput
import Benitoite.Release.Refinement.ReferencePreservation
import Benitoite.Release.Model
import Benitoite.Release.ModelTargets
import Benitoite.Release.ModelHttp
import Benitoite.Release.Examples
namespace Benitoite.Release.Refinement.CurrentSignatureRows
noncomputable section
set_option maxHeartbeats 2000000

mutual
  theorem embed_rows {nr nt pe} (a : Benitoite.Release.Ty) (h : a.VarsIn nr nt pe) :
      (embedTy a).RowsIn pe := by
    cases a <;> simp only [Benitoite.Release.Ty.VarsIn] at h <;> simp only [embedTy,Ty.RowsIn]
    all_goals first
      | trivial
      | exact embed_rows _ h
      | exact embed_rows_list _ h
      | skip
    case fn ns ps r e => exact ⟨embed_rows_list ps h.2.1,embed_rows r h.2.2.1,embed_rows_eff e h.2.2.2.1⟩
    case map a b => exact ⟨embed_rows a h.1,embed_rows b h.2⟩
    case tapp i as => exact embed_rows_list as h.2
  theorem embed_rows_list {nr nt pe} (as : List Benitoite.Release.Ty) (h : Benitoite.Release.Ty.VarsInList nr nt pe as) :
      Ty.RowsInList pe (embedTys as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨embed_rows a h.1,embed_rows_list as h.2⟩
  theorem embed_rows_eff {nr nt pe} (e : Benitoite.Release.Eff) (h : e.VarsIn nr nt pe) :
      (embedEff e).RowsIn pe := by
    cases e with
    | mk ats fs => exact ⟨h.1,embed_rows_list fs h.2.1⟩
end

theorem rows_shift {pe : Nat → Prop} {a : Ty} (h : a.RowsIn pe) (k c : Nat) : (a.shiftV k c).RowsIn pe := by
  rw [Ty.rowsIn_iff_support] at h ⊢
  exact (Ty.support_shiftV_iff _ _ _ _).mpr h

theorem signature_rows {pe} (ns : List String) (as : List Ty) (r : Ty) (e : Eff)
    (hs : Ty.RowsInList pe as) (hr : r.RowsIn pe) (he : e.RowsIn pe) :
    (signatureTel ns as r e).RowsIn pe := by
  cases ns <;> cases as <;> simp only [signatureTel,Tel.RowsIn]
  all_goals first | exact ⟨hr,he⟩ | exact ⟨hs.1,signature_rows _ _ _ _ hs.2 hr he⟩

def copiedTel (s : Benitoite.Release.PrimSig) : Tel :=
  signatureTel s.names (embedParameters s.params)
    ((embedTy s.ret).shiftV s.params.length 0) ((embedEff s.eff).shiftV s.params.length 0)

theorem scoped_signature {s : Benitoite.Release.PrimSig} (h : s.Scoped) :
    (copiedTel s).RowsIn (· < s.neffs) := by
  apply signature_rows
  · rw [Ty.RowsInList.iff]
    intro a ha
    obtain ⟨⟨b,i⟩,hb,rfl⟩ := List.mem_map.mp ha
    apply rows_shift
    exact embed_rows b (Benitoite.Release.Ty.VarsInList.iff.mp h.2.1 b
      (List.mem_of_getElem? (List.mem_zipIdx_iff_getElem?.mp hb)))
  · exact rows_shift (embed_rows s.ret h.2.2.1) _ _
  · rw [Eff.rowsIn_iff_support]
    apply (Eff.support_shiftV_iff _ _ _ _).mpr
    exact (Eff.rowsIn_iff_support _ _).mp (embed_rows_eff s.eff h.2.2.2.1)

-- 現行の三モデルの lookup 全件と範囲付きの表15項目を包含する。
theorem model_rows {P : Benitoite.Release.Program} {b s} (h : (Benitoite.Release.Model.builtins).sig b = some s) :
    (copiedTel s).RowsIn (· < s.neffs) :=
  scoped_signature ((Benitoite.Release.Model.assumptions P).sig_scoped b s h)

theorem target_entries_rows : ∀ entry ∈ Benitoite.Release.TargetTable.entries,
    (copiedTel entry.2).RowsIn (· < entry.2.neffs) :=
  fun entry h => scoped_signature (Benitoite.Release.TargetTable.entries_scoped entry h)

theorem model_targets_rows
    {pat : String → Option Scope.Domain.Range} {tgt : String → Option Scope.Domain.Target}
    {P : Benitoite.Release.Program} (hp : Benitoite.Release.ModelTargets.HasResult P) {b s}
    (h : (Benitoite.Release.ModelTargets.builtins pat tgt).sig b = some s) :
    (copiedTel s).RowsIn (· < s.neffs) :=
  scoped_signature ((Benitoite.Release.ModelTargets.assumptions pat tgt P hp).sig_scoped b s h)

theorem model_http_rows
    {hostPat : String → Int → Int → Option Scope.Domain.Range}
    {reqTarget : Benitoite.Release.Val → Option Scope.Domain.Target}
    {P : Benitoite.Release.Program} (hp : Benitoite.Release.ModelHttp.HasHttp P) {b s}
    (h : (Benitoite.Release.ModelHttp.builtins hostPat reqTarget).sig b = some s) :
    (copiedTel s).RowsIn (· < s.neffs) :=
  scoped_signature ((Benitoite.Release.ModelHttp.assumptions hostPat reqTarget P hp).sig_scoped b s h)

theorem examples_scoped {b s} (h : Benitoite.Release.Examples.builtins.sig b = some s) :
    s.Scoped := by
  simp only [Benitoite.Release.Examples.builtins] at h
  split at h <;> first
    | (cases h; simp [Benitoite.Release.Examples.sig,Benitoite.Release.Examples.intTy,
        Benitoite.Release.Examples.unitTy,Benitoite.Release.PrimSig.Scoped,
        Benitoite.Release.PrimSig.nranges,Benitoite.Release.PrimSig.ntys,
        Benitoite.Release.NamesWF,Benitoite.Release.Ty.VarsIn,Benitoite.Release.Ty.VarsInList,
        Benitoite.Release.Eff.VarsIn,Benitoite.Release.Eff.empty,Benitoite.Release.Eff.single,
        Benitoite.Release.Eff.Canonical,Benitoite.Release.Eff.norm])
    | contradiction

theorem examples_rows {b s} (h : Benitoite.Release.Examples.builtins.sig b = some s) :
    (copiedTel s).RowsIn (· < s.neffs) := scoped_signature (examples_scoped h)

-- Reference.new/get/set/update と force は新側の実際の形からも供給する。
example {s : PrimSig} (h : s.StoreShape) (hk : s.kind = .refNew) :
    s.tel.RowsIn (· < s.neffs) := h.sourceTelRows (Or.inl hk)
example {s : PrimSig} (h : s.StoreShape) (hk : s.kind = .refGet) :
    s.tel.RowsIn (· < s.neffs) := h.sourceTelRows (Or.inr (Or.inl hk))
example {s : PrimSig} (h : s.StoreShape) (hk : s.kind = .refSet) :
    s.tel.RowsIn (· < s.neffs) := h.sourceTelRows (Or.inr (Or.inr (Or.inl hk)))
example {s : PrimSig} (h : s.StoreShape) (hk : s.kind = .refUpdate) :
    s.tel.RowsIn (· < s.neffs) := h.sourceTelRows (Or.inr (Or.inr (Or.inr (Or.inl hk))))
example {s : PrimSig} (h : s.StoreShape) (hk : s.kind = .force) :
    s.tel.RowsIn (· < s.neffs) := h.sourceTelRows (Or.inr (Or.inr (Or.inr (Or.inr hk))))

end
end Benitoite.Release.Refinement.CurrentSignatureRows
