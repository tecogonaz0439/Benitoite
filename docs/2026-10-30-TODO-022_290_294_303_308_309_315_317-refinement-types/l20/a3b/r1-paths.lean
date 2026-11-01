import Benitoite.Release.Refinement.TypeSubstFormation
namespace Benitoite.Release.Refinement.A3bR1

theorem fun_source {P : Program} {f d es} (hp : P.WellFormed) (hd : P.defs f = some d) :
    TypeSubstCode es (fun nr nt ne nv => d.body.SourceScoped nr nt ne nv) :=
  Or.inr ⟨0, d.ntys, d.neffs, d.params.length, (hp.defs f d hd).2.2⟩

theorem fun_body {P : Program} {B : Builtins} {f d es}
    (hp : P.WellFormed) (ht : P.WellTyped B) (hd : P.defs f = some d) :
    TypeSubstCode es (fun nr nt ne nv => d.body.SourceScoped nr nt ne nv) ∧
    TelBodyTy P B StoreTy.empty (QTel d.tel) d.tparams [] [] d.tel d.body :=
  ⟨fun_source hp hd, (ht.defs f d hd).2.2.2⟩

theorem method_source {P : Program} {i id cd m ms body es}
    (hp : P.WellFormed) (hi : P.impls i = some id) (hc : P.classes id.cls = some cd)
    (hm : cd.methods m = some ms) (hb : id.methods m = some body) :
    TypeSubstCode es (fun nr nt ne nv => body.SourceScoped nr nt ne nv) := by
  have hs := (hp.impls i id hi).2.2.2.2.2.2 cd m ms body hc hm hb
  exact Or.inr ⟨0, ms.tparams.length + id.tparams.length, ms.neffs,
    id.dictTys.length + ms.params.length, hs⟩

theorem op_source (body : Comp) : TypeSubstCode [] (fun nr nt ne nv => body.SourceScoped nr nt ne nv) := Or.inl rfl

theorem opfail_source (body : Comp) : TypeSubstCode [] (fun nr nt ne nv => body.SourceScoped nr nt ne nv) := Or.inl rfl

-- レビューの loc 反例の行像は、新しい前提を満たさない。
theorem rejects_review_loc :
    ¬ TypeSubstCode [Eff.empty] (fun nr nt ne nv => (Val.loc 0).SourceScoped nr nt ne nv) := by
  rintro (h | ⟨nr, nt, ne, nv, h⟩)
  · cases h
  · exact h

theorem rejects_closure (t : Tel) (q : Closure) :
    ¬ TypeSubstCode [Eff.empty] (fun nr nt ne nv => (Val.closure t q).SourceScoped nr nt ne nv) := by
  rintro (h | ⟨nr, nt, ne, nv, h⟩)
  · cases h
  · exact h

#print axioms fun_body
#print axioms method_source
#print axioms op_source
#print axioms opfail_source
#print axioms rejects_review_loc
#print axioms rejects_closure
end Benitoite.Release.Refinement.A3bR1
