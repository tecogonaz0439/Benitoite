import Benitoite.Release.Refinement.LegacyTables

/-! # 旧宣言の本体とソースの入力（設計書 01-12「旧判断の適格な入力」） -/
namespace Benitoite.Release.Refinement
noncomputable section

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


def declarationBodyInputs (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) : Prop :=
  (∀ f d, P0.defs f = some d → functionBodyInput K P0 B0 B f d) ∧
  (∀ i id cd m ms body, P0.impls i = some id → P0.classes id.cls = some cd →
    cd.methods m = some ms → id.methods m = some body →
    methodBodyInput K P0 B0 B id m ms body) ∧
  (∀ i id cd s value, P0.impls i = some id → P0.classes id.cls = some cd →
    s ∈ cd.supers → id.supers s = some value → superBodyInput K P0 B0 B id s value)

structure LegacyDeclarationInputs (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) : Prop where
  declarations : LegacyDeclarationsInput K P0 B0 B
  bodies : declarationBodyInputs K P0 B0 B
  functions : ∀ f d, P0.defs f = some d →
    (embedComp d.body).SourceScoped 0 d.tparams.length d.neffs d.params.length
  methods : ∀ i id cd m ms body, P0.impls i = some id → P0.classes id.cls = some cd →
    cd.methods m = some ms → id.methods m = some body →
    (embedComp body).SourceScoped 0 (ms.tparams.length + id.tparams.length)
      ms.neffs (id.dictTys.length + ms.params.length)
  supers : ∀ i id s value, P0.impls i = some id → id.supers s = some value →
    (embedVal value).SourceScoped 0 id.tparams.length 0 id.dictTys.length


theorem LegacyDeclarationInputs.function_body {K P0 B0 B f d}
    (h : LegacyDeclarationInputs K P0 B0 B) (hd : P0.defs f = some d) :
    functionBodyInput K P0 B0 B f d ∧
      (embedComp d.body).SourceScoped 0 d.tparams.length d.neffs d.params.length :=
  ⟨h.bodies.1 f d hd,h.functions f d hd⟩

theorem LegacyDeclarationInputs.method_body {K P0 B0 B i id cd m ms body}
    (h : LegacyDeclarationInputs K P0 B0 B) (hi : P0.impls i = some id)
    (hc : P0.classes id.cls = some cd) (hm : cd.methods m = some ms)
    (hb : id.methods m = some body) :
    methodBodyInput K P0 B0 B id m ms body ∧
      (embedComp body).SourceScoped 0 (ms.tparams.length + id.tparams.length)
        ms.neffs (id.dictTys.length + ms.params.length) :=
  ⟨h.bodies.2.1 i id cd m ms body hi hc hm hb,h.methods i id cd m ms body hi hc hm hb⟩

theorem LegacyDeclarationInputs.super_body {K P0 B0 B i id cd s value}
    (h : LegacyDeclarationInputs K P0 B0 B) (hi : P0.impls i = some id)
    (hc : P0.classes id.cls = some cd) (hs : s ∈ cd.supers)
    (hv : id.supers s = some value) :
    superBodyInput K P0 B0 B id s value ∧
      (embedVal value).SourceScoped 0 id.tparams.length 0 id.dictTys.length :=
  ⟨h.bodies.2.2 i id cd s value hi hc hs hv,h.supers i id s value hi hv⟩

end
end Benitoite.Release.Refinement
