import Benitoite.Release.Refinement.Surface.TesterTyping
import Benitoite.Release.Refinement.HandlerEffects
import Benitoite.Release.Refinement.Surface.OpenSurfaceScoped

/-!
# 脱糖の型の保存（性質 1）

表層のプログラムが整形式で型付くなら、脱糖したプログラムは整形式で、篩付きの型の判断で型付き、エフェクトの宣言が
整合する（設計書 01-12「確かめる性質」の性質 1）。関数の定義の依存列は表層の宣言の依存列と同じであり、篩付きの
結果型と効果を保つ。組み込みの表の仮定は、値の束縛を移す補題が読む `Builtins.ValueAssumptions` だけを求める
（主な定理の `Builtins.CoreAssumptions` の欄 `CoreAssumptions.values` から得る）。
-/

namespace Benitoite.Release.Refinement.Surface

variable {B : Builtins}

/-- 取り出しの関数の照合の選択肢。 -/
def accessorAlt (c : ConName) (cd : ConDecl) (k : Nat) : Alt :=
  ⟨accessorPattern c cd.args.length k, List.range (accessorPattern c cd.args.length k).binders⟩

/-- 取り出しの関数の照合で、束縛した欄を引数の欄の観測へ結ぶ事実。 -/
def accessorLink (c : ConName) (cd : ConDecl) (k : Nat) (cs : List ConName := []) : FieldLink :=
  ⟨0, 0, [accessorRef c cd k], accessorMeasure cd k, cs⟩

/-- 構成子の欄を取り出す関数を脱糖が生成するための条件。署名の宣言・形成と、欄のパターンの型と網羅性を持つ。
観測できる欄では、照合の経路の事実と欄の関係の事実の形成も求める。 -/
def AccessorOk (D : Declarations) (c : ConName) (cd : ConDecl) (k : Nat) (cs : List ConName := accessorConstructors D.dataConstructors cd k) : Prop :=
  Ty.HasKind D.core (TypeCtx.kinds (accessorDecl c cd k cs).tparams) (.dependentFn (accessorDecl c cd k cs).tel) .value ∧
  Ty.Annotation D.core (accessorDecl c cd k cs).tparams [] (.dependentFn (accessorDecl c cd k cs).tel) ∧
  SignatureScoped D.core (accessorDecl c cd k cs).tparams 0 (accessorDecl c cd k cs).tel ∧
  ∃ field, PatTy D.core (accessorPattern c cd.args.length k) (.data cd.data ((List.range cd.ntys).map Ty.tvar)) [field] ∧
    (field.shiftV 1 0).norm = (accessorBase cd k).norm ∧ Ordinary field ∧
    Exhaustive D.core (.data cd.data ((List.range cd.ntys).map Ty.tvar)) [accessorPattern c cd.args.length k] ∧
    (accessorObserved cd k cs = true → k < cd.args.length ∧
      FactsWF D.core (accessorDecl c cd k cs).tparams (Ctx.extend [] (.data cd.data ((List.range cd.ntys).map Ty.tvar)))
        (pathFacts (some (.var 0)) (matchedTests [accessorAlt c cd k] ++ excludedTests [accessorAlt c cd k])) ∧
      FactsWF D.core (accessorDecl c cd k cs).tparams
        (bindParams (Ctx.extend [] (.data cd.data ((List.range cd.ntys).map Ty.tvar))) [field.shiftV 1 0])
        (fieldFacts 1 (some (.var 0)) [accessorLink c cd k cs]))

theorem sort_shiftV (k c : Nat) : (a : Ty) → (a.shiftV k c).sort? = a.sort?
  | .refined a _ => by simp only [Ty.shiftV, Ty.sort?]; exact sort_shiftV k c a
  | .base _ | .opaque _ _ | .data _ _ | .list _ | .fn _ _ _ _ | .tvar _ | .reference _ | .lazy _ | .cont _ _ _
  | .map _ _ | .set _ | .bytes | .dict _ _ | .tapp _ _ | .ctor _ | .dependentFn _ | .external _ _
  | .scoped _ _ _ | .pathBases | .scopePattern _ => rfl

theorem bindersList_wilds : ∀ ps : List Pat, (∀ p ∈ ps, p = .wild) → Pat.bindersList ps = 0
  | [], _ => rfl
  | p :: ps, h => by
    rw [Pat.bindersList, h p (by simp), bindersList_wilds ps (fun q hq => h q (by simp [hq]))]
    rfl

/-- 取り出しの関数のパターンの欄の束縛は、宣言の位置 k の欄を通る。 -/
theorem accessor_binderPath (c : ConName) (cd : ConDecl) (k : Nat) (hk : k < cd.args.length) :
    BinderPath (accessorPattern c cd.args.length k) 0 [accessorRef c cd k] := by
  have hw : Pat.bindersList (((List.range cd.args.length).map fun i => if i = k then Pat.var else Pat.wild).take k) = 0 := by
    apply bindersList_wilds
    intro p hp
    rw [← List.map_take] at hp
    simp only [List.take_range, List.mem_map, List.mem_range] at hp
    obtain ⟨i, hi, rfl⟩ := hp
    have : i ≠ k := by have := Nat.lt_min.mp hi; omega
    simp [this]
  have h := BinderPath.con (c := c) (ps := (List.range cd.args.length).map fun i => if i = k then Pat.var else Pat.wild)
    (j := k) (p := .var) (i := 0) (route := []) (ref := accessorRef c cd k) (by simp [hk]) rfl rfl .var
  rw [hw] at h
  exact h

/-- 実装の宣言の有効範囲。核の実装の有効範囲と同じ欄を、表層の本体と辞書の根拠で述べる。 -/
def ImplDecl.Scoped (D : Declarations) (id : ImplDecl) : Prop :=
  (∀ p ∈ id.dictParams, p.2 < id.tparams.length) ∧
    id.target.SourceScoped 0 id.tparams.length 0 0 ∧
    Ty.Annotation D.core (TypeCtx.values id.tparams) [] id.target ∧
    TypeAnnotations D.core (TypeCtx.values id.tparams) [] id.dictTys ∧
    (∀ a ∈ id.dictTys, a.HasKind D.core (List.replicate id.tparams.length .value) .value) ∧
    (∀ s u, id.supers s = some u → u.Scoped id.tparams.length 0 id.dictTys.length) ∧
    (∀ cd m ms body, D.classes id.cls = some cd → cd.methods m = some ms → id.methods m = some body →
      body.Scoped (ms.tparams.length + id.tparams.length) ms.neffs (id.dictTys.length + ms.params.length))

/-- 表層のプログラムの整形式。型の宣言の整形式は宣言の表のプログラムで述べる（関数の定義と実装の本体を持たない）。 -/
structure Program.WellFormed (p : Program) : Prop where
  types : p.declarations.core.WellFormed
  defs : ∀ f d, p.defs f = some d → NamesWF d.coreNames d.coreParams ∧
    SignatureScopedR p.declarations.core d.rangeParams d.tparams d.neffs d.toFunDecl.tel ∧
    d.body.Scoped d.tparams.length d.neffs d.coreParams.length (nr := d.rangeParams.length)
  impls : ∀ i id, p.impls i = some id → ImplDecl.Scoped p.declarations id
  accessors : ∀ f c k, p.accessors f = some (c, k) → p.defs f = none → ∀ cd, p.cons c = some cd →
    AccessorOk p.declarations c cd k
  /-- 生成する判定の関数と同名の関数・取り出しの関数を拒む。 -/
  testers : ∀ f c, p.testers f = some c → p.defs f = none ∧ p.accessors f = none ∧
    ∀ cd, p.cons c = some cd → TesterOk p.declarations c cd

/-- 範囲パラメータを持たないプログラムの整形式は、範囲の深さ0の署名と本体の条件へ戻る。 -/
theorem Program.wellFormed_no_ranges {p : Program}
    (hs : ∀ f d, p.defs f = some d → d.rangeParams = []) :
    p.WellFormed ↔
      p.declarations.core.WellFormed ∧
      (∀ f d, p.defs f = some d → NamesWF d.coreNames d.coreParams ∧
        SignatureScoped p.declarations.core d.tparams d.neffs d.toFunDecl.tel ∧
        d.body.Scoped d.tparams.length d.neffs d.coreParams.length) ∧
      (∀ i id, p.impls i = some id → ImplDecl.Scoped p.declarations id) ∧
      (∀ f c k, p.accessors f = some (c, k) → p.defs f = none → ∀ cd, p.cons c = some cd →
        AccessorOk p.declarations c cd k) ∧
      (∀ f c, p.testers f = some c → p.defs f = none ∧ p.accessors f = none ∧
        ∀ cd, p.cons c = some cd → TesterOk p.declarations c cd) := by
  have hd : ∀ f d (_ : p.defs f = some d),
      (NamesWF d.coreNames d.coreParams ∧
        SignatureScopedR p.declarations.core d.rangeParams d.tparams d.neffs d.toFunDecl.tel ∧
        d.body.Scoped d.tparams.length d.neffs d.coreParams.length (nr := d.rangeParams.length)) ↔
      (NamesWF d.coreNames d.coreParams ∧
        SignatureScoped p.declarations.core d.tparams d.neffs d.toFunDecl.tel ∧
        d.body.Scoped d.tparams.length d.neffs d.coreParams.length) := by
    intro f d h
    simp only [hs f d h, List.length_nil, SignatureScopedR, SignatureScoped, Ty.annotationR_nil]
  constructor
  · intro h
    exact ⟨h.types, fun f d hf => (hd f d hf).mp (h.defs f d hf), h.impls, h.accessors, h.testers⟩
  · rintro ⟨ht, hf, hi, ha, he⟩
    exact ⟨ht, fun f d h => (hd f d h).mpr (hf f d h), hi, ha, he⟩

/-- 表層のプログラムの型付け。関数と実装のメソッドは本体ごとの view で型付ける。 -/
structure Program.WellTyped (p : Program) (B : Builtins) (opPrim : OpPrim) : Prop where
  variance : p.declarations.core.VarianceValid
  defs : ∀ f d, p.defs f = some d → Def.WellTyped (p.declarationsFor (p.functionViews f)) B opPrim d
  impls : ∀ i id, p.impls i = some id → ImplDecl.WellTyped p.declarations B opPrim id (p.methodViews i)
  effects : p.declarations.core.EffectsOk B

theorem declarationsFor_sameTypes (op : OpPrim) (p : Program) (v : CoverageView) :
    (p.declarationsFor v).core.SameTypes (desugarProgram op p) :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl⟩

/-- 脱糖は関数の範囲パラメータを保ち、生成する射影と判定の関数には空の列を置く。 -/
theorem desugarProgram_ranges {op : OpPrim} {p : Program} {v : CoverageView} {f fd d}
    (hf : (p.declarationsFor v).funs f = some fd)
    (hd : (desugarProgram op p).defs f = some d) : d.rkinds = fd.rangeParams := by
  simp only [Program.declarationsFor, Program.lookupFun] at hf
  simp only [desugarProgram, Program.lookupFun] at hd
  cases hdef : p.defs f with
  | some sd =>
    simp only [hdef, Option.some.injEq] at hf hd
    subst hf; subst hd; rfl
  | none =>
    simp only [hdef] at hf hd
    cases ha : p.accessors f with
    | some ck =>
      obtain ⟨c, k⟩ := ck
      simp only [ha] at hf hd
      cases hc : p.cons c with
      | none => simp [hc] at hf
      | some cd =>
        simp only [hc, Option.map_some, Option.some.injEq] at hf hd
        subst hf; subst hd; rfl
    | none =>
      simp only [ha] at hf hd
      cases ht : p.testers f with
      | none => simp [ht] at hf
      | some c =>
        simp only [ht] at hf hd
        cases hc : p.cons c with
        | none => simp [hc] at hf
        | some cd =>
          simp only [hc, Option.map_some, Option.some.injEq] at hf hd
          subst hf; subst hd; rfl

/-- 範囲パラメータのない表層のプログラムは、空の範囲列を持つ核へ写る。 -/
theorem desugarProgram_ranges_no_ranges {op : OpPrim} {p : Program} {f d}
    (hs : ∀ f sd, p.defs f = some sd → sd.rangeParams = [])
    (hd : (desugarProgram op p).defs f = some d) : d.rkinds = [] := by
  simp only [desugarProgram, Program.lookupFun] at hd
  cases hdef : p.defs f with
  | some sd =>
    simp only [hdef, Option.some.injEq] at hd
    subst d
    exact hs f sd hdef
  | none =>
    simp only [hdef] at hd
    cases ha : p.accessors f with
    | some ck =>
      obtain ⟨c, k⟩ := ck
      simp only [ha] at hd
      cases hc : p.cons c with
      | none => simp [hc] at hd
      | some cd =>
        simp only [hc, Option.map_some, Option.some.injEq] at hd
        subst d
        rfl
    | none =>
      simp only [ha] at hd
      cases ht : p.testers f with
      | none => simp [ht] at hd
      | some c =>
        simp only [ht] at hd
        cases hc : p.cons c with
        | none => simp [hc] at hd
        | some cd =>
          simp only [hc, Option.map_some, Option.some.injEq] at hd
          subst d
          rfl

theorem declarationsFor_realizes {op : OpPrim} {p : Program} (hwf : p.WellFormed) (v : CoverageView) :
    (p.declarationsFor v).Realizes (desugarProgram op p) := by
  refine ⟨declarationsFor_sameTypes op p v, ?_, ?_, hwf.types.external.sameTypes (declarationsFor_sameTypes op p closedView), ?_⟩
  · intro f fd hf
    simp only [Program.declarationsFor, Program.lookupFun] at hf
    simp only [desugarProgram, Program.lookupFun]
    cases hd : p.defs f with
    | some d =>
      simp only [hd, Option.some.injEq] at hf ⊢
      subst hf
      exact ⟨_, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩
    | none =>
      simp only [hd] at hf ⊢
      cases ha : p.accessors f with
      | none =>
        simp only [ha] at hf ⊢
        cases ht : p.testers f with
        | none => simp [ht] at hf
        | some c =>
          simp only [ht] at hf ⊢
          cases hc : p.cons c with
          | none => simp [hc] at hf
          | some cd =>
            simp only [hc, Option.map_some, Option.some.injEq] at hf ⊢
            subst hf
            exact ⟨_, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩
      | some ck =>
        obtain ⟨c, k⟩ := ck
        simp only [ha] at hf ⊢
        cases hc : p.cons c with
        | none => simp [hc] at hf
        | some cd =>
          simp only [hc, Option.map_some, Option.some.injEq] at hf ⊢
          subst hf
          exact ⟨_, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩
  · intro i is hi
    simp only [Program.declarationsFor, Option.map_eq_some_iff] at hi
    obtain ⟨id, hid, rfl⟩ := hi
    exact ⟨desugarImpl op id, by simp [desugarProgram, hid], rfl, rfl, rfl, rfl⟩
  · intro f fd hf d hd
    exact desugarProgram_ranges hf hd

theorem BodyTy.scoped_ranges {D op Q C Γ Φ t body ne nr} (h : BodyTy D B op Q C Γ Φ t body)
    (hs : body.Scoped C.length ne (Γ.length + telBinders t) (nr := nr)) :
    (desugarBlock op .tail body).SourceScoped nr C.length ne (Γ.length + telBinders t) := by
  induction h with
  | done hb => exact hb.scoped_ranges hs
  | param _ ih =>
    have := ih (by simpa [telBinders, Ctx.extend, Nat.add_assoc, Nat.add_comm 1] using hs)
    simpa [telBinders, Ctx.extend, Nat.add_assoc, Nat.add_comm 1] using this

theorem BodyTy.scoped {D op Q C Γ Φ t body ne} (h : BodyTy D B op Q C Γ Φ t body)
    (hs : body.Scoped C.length ne (Γ.length + telBinders t)) :
    (desugarBlock op .tail body).SourceScoped 0 C.length ne (Γ.length + telBinders t) :=
  h.scoped_ranges hs

/-- 関数の範囲文脈の下でも、元のソースの四名前空間の深さを保つ。 -/
theorem BodyTyR.scoped {D op Q ks C Γ Φ t body ne} (h : BodyTyR D B op Q ks C Γ Φ t body)
    (hs : body.Scoped C.length ne (Γ.length + telBinders t) (nr := ks.length)) :
    (desugarBlock op .tail body).SourceScoped ks.length C.length ne (Γ.length + telBinders t) := by
  by_cases hk : ks = []
  · subst ks
    exact (bodyTyR_nil.mp h).scoped hs
  · exact (by simpa only [BodyTyR, hk, ite_false] using h : OpenSurface.BodyTy D B ks op Q C Γ Φ t body).scoped hs

/-- 同じ型の宣言を持つプログラムへ、範囲文脈の署名の形成を移す。 -/
theorem signatureScopedR_sameTypes {P P' : Refinement.Program} {ks C ne t}
    (h : SignatureScopedR P ks C ne t) (hs : P.SameTypes P') : SignatureScopedR P' ks C ne t :=
  ⟨h.1, h.2.1, h.2.2.1.sameTypes hs, ⟨h.2.2.2.wf, h.2.2.2.sorted, h.2.2.2.declared.sameTypes hs⟩⟩

theorem telBinders_signatureTel : ∀ (ns : List String) (ps : List Ty) (r : Ty) (e : Eff), ns.length = ps.length →
    telBinders (signatureTel ns ps r e) = ps.length
  | [], [], _, _, _ => rfl
  | _ :: ns, _ :: ps, r, e, h => by
    simp only [signatureTel, telBinders, List.length_cons]
    rw [telBinders_signatureTel ns ps r e (by simpa using h)]
  | [], _ :: _, _, _, h => by simp at h
  | _ :: _, [], _, _, h => by simp at h

/-- フィールドを取り出す関数の型付け。整数の欄では、照合する値を観測し、束縛した欄と欄の観測の等号の事実から結果の篩を
導く。 -/
theorem accessorDef_wellTyped {P : Refinement.Program} {D : Declarations} {c cd k cs}
    (hR : D.Realizes P) (h : AccessorOk D c cd k cs) :
    Refinement.Def.WellTyped P B (accessorDef c cd k cs) := by
  obtain ⟨hk, ha, -, field, hp, hn, ho, hex, hobs⟩ := h
  have ha' := ha.sameTypes hR.types
  refine ⟨by simp [accessorDef, accessorDecl, NamesWF], hk.sameTypes hR.types, Ty.annotationR_nil.mpr ha', ?_⟩
  let dt := Ty.data cd.data ((List.range cd.ntys).map Ty.tvar)
  let ret := (accessorDecl c cd k cs).ret
  have hdt : Ty.Annotation P (accessorDecl c cd k cs).tparams [] dt :=
    ⟨ha'.wf.1, ha'.sorted.1, ha'.declared.1⟩
  have hret : Ty.Annotation P (accessorDecl c cd k cs).tparams (Ctx.extend [] dt) ret :=
    ⟨ha'.wf.2.1, ha'.sorted.2.1, ha'.declared.2.1⟩
  apply telBodyTyR_nil.mpr
  refine .param (.done ?_)
  simp only [accessorDef, mkArm]
  by_cases hob : accessorObserved cd k cs = true
  · obtain ⟨hlt, hpw, hfw⟩ := hobs hob
    have hretEq : ret = .refined (accessorBase cd k) (accessorPred c cd k cs) := by
      simp [ret, accessorDecl, accessorRet, hob]
    have hA1 := hret.under [field.shiftV 1 0]
    rw [hretEq, shiftV_refined] at hA1
    simp only [bindParams_single, List.length_cons, List.length_nil, Nat.zero_add] at hA1
    have hB : Ty.Annotation P (accessorDecl c cd k cs).tparams ((Ctx.extend [] dt).extend (field.shiftV 1 0))
        ((accessorBase cd k).shiftV 1 0) := ⟨hA1.wf.1, hA1.sorted.1, hA1.declared.1⟩
    have hsort : ((accessorBase cd k).shiftV 1 0).HasSort (accessorSort cd k) := by
      unfold Ty.HasSort
      rw [sort_shiftV]
      cases hs : (accessorBase cd k).sort? with
      | none => simp [accessorObserved, hs] at hob
      | some s => simp [accessorSort, hs]
    refine .C_Match (obs := some (.var 0)) (.V_Var (a := dt.shiftV 1 0) (by simp [Ctx.extend]; rfl)
      (by intro b t e; simp [Ty.core, Ty.shiftV, dt])) (fun t ht => ?_) ?_
      (by simpa [bindParams_single] using (hdt.under [dt]).declared) ((hex.sameTypes hR.types).shiftV 1 0)
    · cases ht
      exact ⟨rfl, .data, by simp [Term.HasSort, Term.References, Term.Shape, Ctx.extend, Ty.HasSort, Ty.sort?,
        Ty.shiftV, Term.VarsIn, Ctx.Readable]⟩
    · refine HasTypeArmsQ.plain (links := [accessorLink c cd k cs])
        (AltsTy.single ((hp.sameTypes hR.types).shift_values 1 0))
        (fun l hl => ?_) ?_ (hpw.sameTypes hR.types) ?_ (.nil hret)
      · simp only [List.mem_singleton] at hl
        subst hl
        have hb1 : (accessorPattern c cd.args.length k).binders = 1 := by
          simpa using (MatchFacts.PatTy.binders_length hp).symm
        refine ⟨_, rfl, ⟨c, _, rfl⟩, by simp [accessorLink], by simp [accessorLink, hb1], ?_,
          by simp [accessorLink], ?_⟩
        · simpa [accessorLink] using accessor_binderPath c cd k hlt
        · simp only [accessorLink, FieldLink.sort, List.getLast?_cons, List.getLast?_nil,
            Option.map_some, Option.getD_some, accessorRef]
          unfold accessorMeasure
          cases hs : (accessorBase cd k).sort? with
          | none => simp [accessorObserved, hs] at hob
          | some s =>
            cases s <;> simp_all [accessorSort, FieldRelation.Valid, accessorObserved, Measure.input]
      · simpa using (hfw.sameTypes hR.types)
      · have hent : Entails (((Ctx.extend [] dt).extend (field.shiftV 1 0)).facts ++
            (fieldFacts 1 (some (.var 0)) [accessorLink c cd k cs] ++
              List.map Pred.lift (pathFacts (some (.var 0)) (matchedTests [accessorAlt c cd k]))))
            ((liftRef 1 (accessorPred c cd k cs)).open (.var 0)) := by
          refine .hyp (List.mem_append_right _ (List.mem_append_left _ ?_))
          simp [fieldFacts, FieldLink.predicate, FieldLink.sort, accessorLink, accessorPred,
            accessorRef, routeTerm, liftRef, Pred.open, fieldRelation_bind, termBind, termBind?]
        have hretEq' : (accessorDecl c cd k cs).ret = .refined (accessorBase cd k) (accessorPred c cd k cs) := hretEq
        simp only [hretEq', shiftV_refined, Option.map_some,
          List.map_nil, List.append_nil]
        refine .C_Eff (.C_Return ?_) (Eff.covers_empty _ _ _)
        exact .V_Refine (.V_Sub (.V_Var (a := (field.shiftV 1 0).shiftV 1 0) (by simp [Ctx.extend])
            ((Ty.ordinary_shiftV _ _ _).mpr ((Ty.ordinary_shiftV _ _ _).mpr ho)))
          (.convert (by rw [Ty.norm_shiftV, hn, ← Ty.norm_shiftV]; rfl)) hB.wf hB.sorted hB.declared)
          hsort rfl hA1.sorted.2 hA1.wf.2.1 hent hB.declared hA1.declared.2
  · have hretEq : ret = accessorBase cd k := by
      simp [ret, accessorDecl, accessorRet, hob]
    refine .C_Match (obs := none) (.V_Var (a := dt.shiftV 1 0) (by simp [Ctx.extend]; rfl)
      (by intro b t e; simp [Ty.core, Ty.shiftV, dt])) (fun _ h => by cases h) ?_
      (by simpa [bindParams_single] using (hdt.under [dt]).declared) ((hex.sameTypes hR.types).shiftV 1 0)
    refine HasTypeArmsQ.plainEmpty (AltsTy.single ((hp.sameTypes hR.types).shift_values 1 0))
      (by intro q hq; cases hq) ?_ (.nil hret)
    simp only [List.map_cons, List.map_nil, List.length_cons, List.length_nil, Nat.zero_add, bindParams_single]
    have hA1 := hret.under [field.shiftV 1 0]
    simp only [bindParams_single, List.length_cons, List.length_nil, Nat.zero_add] at hA1
    have hretEq' : (accessorDecl c cd k cs).ret = accessorBase cd k := hretEq
    rw [hretEq] at hA1
    try rw [hretEq']
    exact .C_Eff (.C_Return (.V_Sub (.V_Var (a := (field.shiftV 1 0).shiftV 1 0) (by simp [Ctx.extend])
      ((Ty.ordinary_shiftV _ _ _).mpr ((Ty.ordinary_shiftV _ _ _).mpr ho)))
      (.convert (by rw [Ty.norm_shiftV, hn, ← Ty.norm_shiftV])) hA1.wf hA1.sorted hA1.declared)) (Eff.covers_empty _ _ _)

theorem lookupFun_desugar {op : OpPrim} {p : Program} {f d}
    (h : (desugarProgram op p).defs f = some d) :
    (∃ sd, p.defs f = some sd ∧ d = desugarDef op sd) ∨
      (p.defs f = none ∧ ∃ c k cd, p.accessors f = some (c, k) ∧ p.cons c = some cd ∧ d = accessorDef c cd k (accessorConstructors p.dataConstructors cd k)) ∨
      (p.defs f = none ∧ p.accessors f = none ∧ ∃ c cd, p.testers f = some c ∧ p.cons c = some cd ∧
        d = testerDef c cd) := by
  simp only [desugarProgram, Program.lookupFun] at h
  cases hd : p.defs f with
  | some sd => simp only [hd, Option.some.injEq] at h; exact .inl ⟨sd, rfl, h.symm⟩
  | none =>
    simp only [hd] at h
    cases ha : p.accessors f with
    | none =>
      simp only [ha] at h
      cases ht : p.testers f with
      | none => simp [ht] at h
      | some c =>
        simp only [ht] at h
        cases hc : p.cons c with
        | none => simp [hc] at h
        | some cd =>
          simp only [hc, Option.map_some, Option.some.injEq] at h
          exact .inr (.inr ⟨rfl, rfl, c, cd, rfl, hc, h.symm⟩)
    | some ck =>
      obtain ⟨c, k⟩ := ck
      simp only [ha] at h
      cases hc : p.cons c with
      | none => simp [hc] at h
      | some cd => simp only [hc, Option.map_some, Option.some.injEq] at h; exact .inr (.inl ⟨rfl, c, k, cd, rfl, hc, h.symm⟩)

/-- 01-12「確かめる性質」の性質 1。 -/
theorem desugar_typed {p : Program} {B : Builtins} {opPrim : OpPrim}
    (hwf : p.WellFormed) (hwt : p.WellTyped B opPrim)
    (hA : Builtins.ValueAssumptions (desugarProgram opPrim p) B) :
    (desugarProgram opPrim p).WellFormed ∧ (desugarProgram opPrim p).WellTyped B ∧
      (desugarProgram opPrim p).EffectsOk B := by
  have hR : ∀ v, (p.declarationsFor v).Realizes (desugarProgram opPrim p) := declarationsFor_realizes hwf
  have hS := declarationsFor_sameTypes opPrim p closedView
  have hT := hwf.types
  refine ⟨⟨?_, ?_, ?_, ?_, ?_, hT.metadata.sameTypes hS, hT.external.sameTypes hS⟩,
    ⟨hwt.variance.sameTypes hS, hT.external.sameTypes hS, ?_, ?_⟩, hwt.effects⟩
  · intro f d hd
    rcases lookupFun_desugar hd with ⟨sd, hsd, rfl⟩ | ⟨hnd, c, k, cd, ha, hc, rfl⟩ | ⟨hnd, hna, c, cd, ht, hc, rfl⟩
    · obtain ⟨hn, hsig, hsc⟩ := hwf.defs f sd hsd
      obtain ⟨-, -, -, hb⟩ := hwt.defs f sd hsd
      refine ⟨hn, signatureScopedR_sameTypes hsig hS, ?_⟩
      have h := hb.scoped (ne := sd.neffs) (by
        simpa [FunDecl.tel, telBinders_signatureTel _ _ _ _ hn.1] using hsc)
      simpa [FunDecl.tel, telBinders_signatureTel _ _ _ _ hn.1, desugarDef, Refinement.Def.ntys] using h
    · obtain ⟨-, -, hsig, -⟩ := hwf.accessors f c k ha hnd cd hc
      refine ⟨by simp [accessorDef, accessorDecl, NamesWF], by
        have hs := hsig.sameTypes hS
        exact ⟨hs.1, hs.2.1, hs.2.2.1, Ty.annotationR_nil.mpr hs.2.2.2⟩, ?_⟩
      simp only [accessorDef, mkArm, Comp.SourceScoped, Val.SourceScoped, scopedArms]
      exact ⟨by simp [accessorDecl], trivial, by simp only [accessorDecl, List.length_cons, List.length_nil]; omega, trivial⟩
    · obtain ⟨-, -, hok⟩ := hwf.testers f c ht
      obtain ⟨-, -, hsig, -⟩ := hok cd hc
      refine ⟨by simp [testerDef, testerDecl, NamesWF], by
        have hs := hsig.sameTypes hS
        exact ⟨hs.1, hs.2.1, hs.2.2.1, Ty.annotationR_nil.mpr hs.2.2.2⟩, ?_⟩
      simp only [testerDef, mkArm, Comp.SourceScoped, Val.SourceScoped, scopedArms]
      exact ⟨by simp [testerDecl], trivial, trivial, trivial, trivial, trivial⟩
  · intro c cd hc
    obtain ⟨h1, h2⟩ := hT.cons c cd hc
    exact ⟨(hS.dataArity _ _).mp h1, h2.sameTypes hS⟩
  · intro o od ho
    exact (hT.ops o od ho).sameTypes hS
  · intro cl cd hc
    exact (hT.classes cl cd hc).sameTypes hS
  · intro i id hid
    simp only [desugarProgram, Option.map_eq_some_iff] at hid
    obtain ⟨sid, hsid, rfl⟩ := hid
    obtain ⟨h1, h2, h3, h4, h5, h6, h7⟩ := hwf.impls i sid hsid
    obtain ⟨cd0, hcd0, -, -, -, -, hbodies, -⟩ := hwt.impls i sid hsid
    refine ⟨h1, h2, h3.sameTypes hS, h4.sameTypes hS, fun a ha => (h5 a ha).sameTypes hS, ?_, ?_⟩
    · intro s u hu
      simp only [desugarImpl, Option.map_eq_some_iff] at hu
      obtain ⟨d, hd, rfl⟩ := hu
      exact DictEv.Scoped.toVal (h6 s d hd)
    · intro cd m ms body hcd hms hbody
      simp only [desugarImpl, Option.map_eq_some_iff] at hbody
      obtain ⟨sb, hsb, rfl⟩ := hbody
      have hcd' : p.declarations.classes sid.cls = some cd := hcd
      rw [hcd0] at hcd'
      cases hcd'
      obtain ⟨sb', hsb', hn, hbt⟩ := hbodies m ms hms
      rw [hsb] at hsb'
      cases hsb'
      have hlen : ∀ k, telBinders (Tel.shiftV k 0
          (Tel.bind (typeEnvAt ms.tparams.length [sid.target] []) ms.tel)) = ms.params.length := by
        intro k
        rw [telBinders_shiftV, telBinders_bind, MethSig.tel, telBinders_signatureTel _ _ _ _ hn.1]
      have h := hbt.scoped (ne := ms.neffs) (by
        simpa [hlen, bindParams, TypeCtx.values, ImplSig.dictTys] using h7 cd0 m ms sb hcd0 hms hsb)
      simpa [hlen, bindParams, TypeCtx.values, ImplSig.dictTys, ImplDecl.dictTys, desugarImpl] using h
  · intro f d hd
    rcases lookupFun_desugar hd with ⟨sd, hsd, rfl⟩ | ⟨hnd, c, k, cd, ha, hc, rfl⟩ | ⟨hnd, hna, c, cd, ht, hc, rfl⟩
    · exact (hwt.defs f sd hsd).desugar (hR _) hA
    · exact accessorDef_wellTyped (hR closedView) (hwf.accessors f c k ha hnd cd hc)
    · exact testerDef_wellTyped (hR closedView) (by simpa [desugarProgram] using hc)
        ((hwf.testers f c ht).2.2 cd hc)
  · intro i id hid
    simp only [desugarProgram, Option.map_eq_some_iff] at hid
    obtain ⟨sid, hsid, rfl⟩ := hid
    exact (hwt.impls i sid hsid).desugar (fun v => hR v) (hR closedView) hA

end Benitoite.Release.Refinement.Surface
