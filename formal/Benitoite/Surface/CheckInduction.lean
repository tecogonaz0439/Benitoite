import Benitoite.Surface.CheckLemmas

/-! 場合別の証明が仮定する、構文の各部分に対する検査の契約。
内部の状態・環境・戻り値・経路・並びの添字を量化し、子の検査に適用できる。
探索の型付けは要求せず、厳密な検査の型付けと原子集合の保存を同時に要求する。
-/
namespace Benitoite.Surface.Check
open Benitoite.Release Benitoite.Surface.CheckTools

def ExprSound (q : Input) (e : Expr) : Prop :=
  ∀ C Γ R p path s s' a ε, q.Sound → e.AtomsIn q.atoms → Env.AtomsIn q.atoms Γ →
    ReturnAtoms q.atoms R → checkExprR q .strict C Γ R p path e s = .ok ((a, ε), s') →
    HasType q.D q.B q.opPrim C Γ R p e a ε ∧ a.AtomsIn q.atoms ∧ ε.AtomsIn q.atoms

def BlockSound (q : Input) (body : Block) : Prop :=
  ∀ C Γ R p path s s' a ε, q.Sound → body.AtomsIn q.atoms → Env.AtomsIn q.atoms Γ →
    ReturnAtoms q.atoms R → checkBlockR q .strict C Γ R p path body s = .ok ((a, ε), s') →
    HasBlock q.D q.B q.opPrim C Γ R p body a ε ∧ a.AtomsIn q.atoms ∧ ε.AtomsIn q.atoms

def TypesSound (q : Input) (es : Exprs) : Prop :=
  ∀ C Γ R path index ts s s' ε, q.Sound → es.AtomsIn q.atoms → Env.AtomsIn q.atoms Γ →
    ReturnAtoms q.atoms R → Tys.AtomsIn q.atoms ts →
    checkTypesR q .strict C Γ R path index es ts s = .ok (ε, s') →
    HasTypes q.D q.B q.opPrim C Γ R es ts ε ∧ ε.AtomsIn q.atoms

def EachSound (q : Input) (es : Exprs) : Prop :=
  ∀ C Γ R path index a s s' ε, q.Sound → es.AtomsIn q.atoms → Env.AtomsIn q.atoms Γ →
    ReturnAtoms q.atoms R → a.AtomsIn q.atoms →
    checkEachR q .strict C Γ R path index es a s = .ok (ε, s') →
    HasEach q.D q.B q.opPrim C Γ R es a ε ∧ ε.AtomsIn q.atoms

def HoleArgsSound (q : Input) (args : HoleArgs) : Prop :=
  ∀ C Γ R path index ts s s' ε, q.Sound → args.AtomsIn q.atoms → Env.AtomsIn q.atoms Γ →
    ReturnAtoms q.atoms R → Tys.AtomsIn q.atoms ts →
    checkHoleArgsR q .strict C Γ R path index args ts s = .ok (ε, s') →
    HasHoleArgs q.D q.B q.opPrim C Γ R args ts ε ∧ ε.AtomsIn q.atoms

def ArmsSound (q : Input) (arms : Arms) : Prop :=
  ∀ C Γ R p path a b s s' ε, q.Sound → arms.AtomsIn q.atoms → Env.AtomsIn q.atoms Γ →
    ReturnAtoms q.atoms R → a.AtomsIn q.atoms → b.AtomsIn q.atoms →
    checkArmsR q .strict C Γ R p path arms a b s = .ok (ε, s') →
    HasArms q.D q.B q.opPrim C Γ R p arms a b ε ∧ ε.AtomsIn q.atoms

def ClausesSound (q : Input) (cs : Clauses) : Prop :=
  ∀ C Γ R path t ε s s' actual, q.Sound → cs.AtomsIn q.atoms → Env.AtomsIn q.atoms Γ →
    ReturnAtoms q.atoms R → t.AtomsIn q.atoms → ε.AtomsIn q.atoms →
    checkClausesR q .strict C Γ R path cs t ε s = .ok (actual, s') →
    HasClauses q.D q.B q.opPrim C Γ R cs t ε ∧ Eff.Sub actual ε ∧ actual.AtomsIn q.atoms

def ClauseTypesAtoms (q : Input) (cs : Clauses) : Prop :=
  ∀ C Γ R path t ε s s' out, t.AtomsIn q.atoms →
    inferClauseTypesR q C Γ R path cs t ε s = .ok (out, s') → out.AtomsIn q.atoms

/-- Exprs の帰納法の仮定は二つの検査の契約、Clauses は厳密な契約と探索の保存。
Expr・Exprs・HoleArgs・Arms・Clauses・Block に対する相互帰納法の motive とする。
Arms の Option Expr の子には GuardSound を使い、some の場合だけ ExprSound を得る。
-/
def ExprsSound (q : Input) (es : Exprs) : Prop := TypesSound q es ∧ EachSound q es

def ClauseChecksSound (q : Input) (cs : Clauses) : Prop := ClausesSound q cs ∧ ClauseTypesAtoms q cs

def GuardSound (q : Input) (g : Option Expr) : Prop := ∀ e, g = some e → ExprSound q e

structure MutualSoundness (q : Input) : Prop where
  expr : ∀ e, ExprSound q e
  exprs : ∀ es, ExprsSound q es
  holes : ∀ args, HoleArgsSound q args
  arms : ∀ arms, ArmsSound q arms
  clauses : ∀ cs, ClauseChecksSound q cs
  block : ∀ body, BlockSound q body

/-- 六つの構文の帰納を一つの命題として扱う。並びと節は二つの検査をまとめる。 -/
inductive CheckNode where
  | expr (e : Expr)
  | exprs (es : Exprs)
  | holes (args : HoleArgs)
  | arms (arms : Arms)
  | clauses (cs : Clauses)
  | block (body : Block)

/-- 帰納法の尺度だけに使う。構文の自動生成の sizeOf は実行コードを持たない。 -/
noncomputable def CheckNode.size : CheckNode → Nat
  | .expr e => sizeOf e
  | .exprs es => sizeOf es
  | .holes args => sizeOf args
  | .arms as_ => sizeOf as_
  | .clauses cs => sizeOf cs
  | .block body => sizeOf body

def NodeSound (q : Input) : CheckNode → Prop
  | .expr e => ExprSound q e
  | .exprs es => ExprsSound q es
  | .holes args => HoleArgsSound q args
  | .arms arms => ArmsSound q arms
  | .clauses cs => ClauseChecksSound q cs
  | .block body => BlockSound q body

/-- pipe の右辺の call・conCall の子も使えるよう、大きさによる強い相互帰納法を使う。
子の契約は環境・位置・状態・添字を量化済みなので、親で変えた引数に適用できる。
-/
def CaseHypotheses (q : Input) (parent : CheckNode) : Prop :=
  ∀ child, child.size < parent.size → NodeSound q child

def CaseSound (q : Input) (node : CheckNode) : Prop := CaseHypotheses q node → NodeSound q node

/-- E2b-2 の場合別の補題をこの前提にまとめる。ここでは前提そのものを証明しない。 -/
def CheckCasesSound (q : Input) : Prop := ∀ node, CaseSound q node

theorem MutualSoundness.of_cases {q} (hc : CheckCasesSound q) : MutualSoundness q := by
  have all : ∀ node, NodeSound q node := by
    intro node
    induction node using (measure CheckNode.size).wf.induction with
    | h node ih => exact hc node ih
  exact ⟨fun e => all (.expr e), fun es => all (.exprs es), fun args => all (.holes args),
    fun arms => all (.arms arms), fun cs => all (.clauses cs), fun body => all (.block body)⟩

/-- 単純な場合も、葉では仮定を使わず、子を持つ場合は CaseHypotheses を引数に取る。
例えばラムダの補題の結論は CaseSound q (.expr (.lam ps r ε body)) であり、
以下で得た BlockSound を、binds ps ++ hideConts Γ・some r・tail・任意の状態へ適用する。
-/
theorem lam_case_ih {q ps r ε body}
    (ih : CaseHypotheses q (.expr (.lam ps r ε body))) : BlockSound q body := by
  apply ih (.block body)
  simp only [CheckNode.size, Expr.lam.sizeOf_spec]
  omega

theorem handle_case_ih {q body cs}
    (ih : CaseHypotheses q (.expr (.handleE body cs))) :
    BlockSound q body ∧ ClauseChecksSound q cs := by
  constructor
  · apply ih (.block body)
    simp only [CheckNode.size, Expr.handleE.sizeOf_spec]; omega
  · apply ih (.clauses cs)
    simp only [CheckNode.size, Expr.handleE.sizeOf_spec]; omega

theorem clauses_case_ih {q o n ntys body rest}
    (ih : CaseHypotheses q (.clauses (.cons o n ntys body rest))) :
    BlockSound q body ∧ ClauseChecksSound q rest := by
  constructor
  · apply ih (.block body)
    simp only [CheckNode.size, Clauses.cons.sizeOf_spec]; omega
  · apply ih (.clauses rest)
    simp only [CheckNode.size, Clauses.cons.sizeOf_spec]; omega

theorem arms_case_ih {q alts guard body rest}
    (ih : CaseHypotheses q (.arms (.cons alts guard body rest))) :
    GuardSound q guard ∧ BlockSound q body ∧ ArmsSound q rest := by
  refine ⟨?_, ?_, ?_⟩
  · intro e he; subst guard
    apply ih (.expr e)
    simp only [CheckNode.size, Arms.cons.sizeOf_spec, Option.some.sizeOf_spec]; omega
  · apply ih (.block body)
    simp only [CheckNode.size, Arms.cons.sizeOf_spec]; omega
  · apply ih (.arms rest)
    simp only [CheckNode.size, Arms.cons.sizeOf_spec]; omega

theorem pipe_case_ih {q lhs rhs} (ih : CaseHypotheses q (.expr (.pipe lhs rhs))) :
    ExprSound q lhs ∧ ExprSound q rhs := by
  constructor
  · apply ih (.expr lhs)
    simp only [CheckNode.size, Expr.pipe.sizeOf_spec]; omega
  · apply ih (.expr rhs)
    simp only [CheckNode.size, Expr.pipe.sizeOf_spec]; omega

theorem pipe_call_case_ih {q lhs callee args}
    (ih : CaseHypotheses q (.expr (.pipe lhs (.call callee args)))) :
    ExprSound q callee ∧ ExprsSound q args := by
  constructor
  · apply ih (.expr callee)
    simp only [CheckNode.size, Expr.pipe.sizeOf_spec, Expr.call.sizeOf_spec]; omega
  · apply ih (.exprs args)
    simp only [CheckNode.size, Expr.pipe.sizeOf_spec, Expr.call.sizeOf_spec]; omega

theorem pipe_conCall_case_ih {q lhs c ts args}
    (ih : CaseHypotheses q (.expr (.pipe lhs (.conCall c ts args)))) : ExprsSound q args := by
  apply ih (.exprs args)
  simp only [CheckNode.size, Expr.pipe.sizeOf_spec, Expr.conCall.sizeOf_spec]; omega

/-- ClauseTypesAtoms の場合は探索の保存補題から直接埋められる。 -/
theorem clauseTypesAtoms (q : Input) (cs : Clauses) : ClauseTypesAtoms q cs :=
  fun _ _ _ _ _ _ _ _ _ ht h => inferClauseTypesR_atoms ht h

def DictSound (q : Input) (d : DictEv) : Prop :=
  ∀ C Γ path a, q.Sound → d.AtomsIn q.atoms → Env.AtomsIn q.atoms Γ →
    checkDict q C Γ path d = .ok a → DictEv.HasType q.D q.B C Γ d a ∧ a.AtomsIn q.atoms

def DictsSound (q : Input) (ds : List DictEv) : Prop :=
  ∀ C Γ path index ts, q.Sound → DictEvs.AtomsIn q.atoms ds → Env.AtomsIn q.atoms Γ →
    Tys.AtomsIn q.atoms ts → checkDictsAt q C Γ path index ds ts = .ok () →
    DictEv.HasTypes q.D q.B C Γ ds ts

/-- 辞書は式と独立の相互帰納法で証明する。 -/
structure DictionarySoundness (q : Input) : Prop where
  dict : ∀ d, DictSound q d
  dicts : ∀ ds, DictsSound q ds

structure CheckerSoundness (q : Input) : Prop where
  surface : MutualSoundness q
  dictionaries : DictionarySoundness q

theorem checkExpr_of_mutual {q C Γ R p path e a ε} (hs : MutualSoundness q)
    (hq : q.Sound) (he : e.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (hR : ReturnAtoms q.atoms R)
    (h : checkExpr q .strict C Γ R p path e = .ok (a, ε)) :
    HasType q.D q.B q.opPrim C Γ R p e a ε ∧ a.AtomsIn q.atoms ∧ ε.AtomsIn q.atoms := by
  obtain ⟨s', hh⟩ := run'_ok h
  exact hs.expr e C Γ R p path {} s' a ε hq he hΓ hR hh

theorem checkBlock_of_mutual {q C Γ R p path body a ε} (hs : MutualSoundness q)
    (hq : q.Sound) (hb : body.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (hR : ReturnAtoms q.atoms R)
    (h : checkBlock q .strict C Γ R p path body = .ok (a, ε)) :
    HasBlock q.D q.B q.opPrim C Γ R p body a ε ∧ a.AtomsIn q.atoms ∧ ε.AtomsIn q.atoms := by
  obtain ⟨s', hh⟩ := run'_ok h
  exact hs.block body C Γ R p path {} s' a ε hq hb hΓ hR hh

theorem checkArms_of_mutual {q C Γ R p path arms a b ε} (hs : MutualSoundness q)
    (hq : q.Sound) (ha : arms.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (hR : ReturnAtoms q.atoms R) (hin : a.AtomsIn q.atoms) (hout : b.AtomsIn q.atoms)
    (h : checkArms q .strict C Γ R p path arms a b = .ok ε) :
    HasArms q.D q.B q.opPrim C Γ R p arms a b ε ∧ ε.AtomsIn q.atoms := by
  obtain ⟨s', hh⟩ := run'_ok h
  exact hs.arms arms C Γ R p path a b {} s' ε hq ha hΓ hR hin hout hh

theorem checkClauses_of_mutual {q C Γ R path cs t ε actual} (hs : MutualSoundness q)
    (hq : q.Sound) (hc : cs.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (hR : ReturnAtoms q.atoms R) (ht : t.AtomsIn q.atoms) (hε : ε.AtomsIn q.atoms)
    (h : checkClauses q .strict C Γ R path cs t ε = .ok actual) :
    HasClauses q.D q.B q.opPrim C Γ R cs t ε ∧ Eff.Sub actual ε ∧ actual.AtomsIn q.atoms := by
  obtain ⟨s', hh⟩ := run'_ok h
  exact (hs.clauses cs).1 C Γ R path t ε {} s' actual hq hc hΓ hR ht hε hh

theorem checkTypes_of_mutual {q C Γ R path es ts ε} (hs : MutualSoundness q)
    (hq : q.Sound) (he : es.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (hR : ReturnAtoms q.atoms R) (ht : Tys.AtomsIn q.atoms ts)
    (h : checkTypes q .strict C Γ R path es ts = .ok ε) :
    HasTypes q.D q.B q.opPrim C Γ R es ts ε ∧ ε.AtomsIn q.atoms := by
  obtain ⟨s', hh⟩ := run'_ok h
  exact (hs.exprs es).1 C Γ R path 0 ts {} s' ε hq he hΓ hR ht hh

theorem checkEach_of_mutual {q C Γ R path es a ε} (hs : MutualSoundness q)
    (hq : q.Sound) (he : es.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (hR : ReturnAtoms q.atoms R) (ha : a.AtomsIn q.atoms)
    (h : checkEach q .strict C Γ R path es a = .ok ε) :
    HasEach q.D q.B q.opPrim C Γ R es a ε ∧ ε.AtomsIn q.atoms := by
  obtain ⟨s', hh⟩ := run'_ok h
  exact (hs.exprs es).2 C Γ R path 0 a {} s' ε hq he hΓ hR ha hh

theorem checkHoleArgs_of_mutual {q C Γ R path args ts ε} (hs : MutualSoundness q)
    (hq : q.Sound) (ha : args.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (hR : ReturnAtoms q.atoms R) (ht : Tys.AtomsIn q.atoms ts)
    (h : checkHoleArgs q .strict C Γ R path args ts = .ok ε) :
    HasHoleArgs q.D q.B q.opPrim C Γ R args ts ε ∧ ε.AtomsIn q.atoms := by
  obtain ⟨s', hh⟩ := run'_ok h
  exact hs.holes args C Γ R path 0 ts {} s' ε hq ha hΓ hR ht hh

theorem checkDict_of_dictionary {q C Γ path d a} (hs : DictionarySoundness q)
    (hq : q.Sound) (hd : d.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (h : checkDict q C Γ path d = .ok a) :
    DictEv.HasType q.D q.B C Γ d a ∧ a.AtomsIn q.atoms := hs.dict d C Γ path a hq hd hΓ h

theorem checkDicts_of_dictionary {q C Γ path ds ts} (hs : DictionarySoundness q)
    (hq : q.Sound) (hd : DictEvs.AtomsIn q.atoms ds) (hΓ : Env.AtomsIn q.atoms Γ)
    (ht : Tys.AtomsIn q.atoms ts) (h : checkDicts q C Γ path ds ts = .ok ()) :
    DictEv.HasTypes q.D q.B C Γ ds ts := hs.dicts ds C Γ path 0 ts hq hd hΓ ht h

theorem checkDef_of_mutual {q path d} (hs : MutualSoundness q)
    (hq : q.Sound) (hd : d.AtomsIn q.atoms) (h : checkDef q path d = .ok ()) :
    Def.WellTyped q.D q.B q.opPrim d := by
  obtain ⟨u, hu, h⟩ := bind_ok h
  obtain ⟨v, hv, h⟩ := bind_ok h
  obtain ⟨ε, hacc, heff⟩ := bind_ok h
  have hb := checkBlock_of_mutual hs hq hd.2 (Env.atoms_binds hd.1.1)
    (fun t ht => by cases ht; exact hd.1.2.1) hv
  refine ⟨(lamBodyOk_spec _ _).mp (require_ok hu).1, ?_⟩
  exact accept_block_eff hb.1 hb.2.1 hd.1.2.1 hb.2.2 hacc heff

/-- 有限の名前一覧の成功を、一覧外の空欄の契約と合わせて全称判断へ戻す。 -/
theorem checkImpl_of_checker {q methods supers path id} (hs : CheckerSoundness q)
    (hq : q.Sound) (hi : id.AtomsIn q.atoms) (hn : ImplNamesComplete q id methods supers)
    (h : checkImpl q methods supers path id = .ok ()) :
    ImplDecl.WellTyped q.D q.B q.opPrim id := by
  obtain ⟨cd, hc, h⟩ := bind_ok h
  obtain ⟨u1, hm, h⟩ := bind_ok h
  obtain ⟨u2, hf, h⟩ := bind_ok h
  obtain ⟨u3, hall, hd⟩ := bind_ok h
  have hcd := lookup_ok hc
  have complete : ∀ s ∈ cd.supers, s ∈ supers := by
    intro s hmem
    exact List.mem_of_elem_eq_true (List.all_eq_true.mp (require_ok hall).1 s hmem)
  have methodEntry := checkMethods_entry (by cases u1; exact hm)
  have flags := checkSuperFlags_entry (by cases u2; exact hf)
  refine ⟨cd, hcd, ?_, ?_, ?_, ?_⟩
  · intro m
    by_cases hmem : m ∈ methods
    · exact (methodEntry m hmem).1
    · rw [hn.1 cd hcd m hmem, hn.2.1 m hmem]; rfl
  · intro s
    by_cases hmem : s ∈ supers
    · exact flags s hmem
    · have hnot : s ∉ cd.supers := fun h => hmem (complete s h)
      simp [hn.2.2 s hmem, hnot]
  · intro m ms hms
    have hmem : m ∈ methods := by
      by_cases hmem : m ∈ methods
      · exact hmem
      · have he := hn.1 cd hcd m hmem
        rw [hms] at he; contradiction
    obtain ⟨body, hb, path', a, ε, out, hExit, hBlock, hAccept, hEff⟩ :=
      (methodEntry m hmem).2 ms hms
    have msAtoms := hq.declarations.2.2.2.1 id.cls cd m ms hcd hms
    have resultAtoms := substTyAt_atoms msAtoms.2.1 (atoms := q.atoms)
      (ts := [id.target]) (es := []) ⟨hi.1, trivial⟩ (by simp) ms.tparams.length
    have paramsAtoms := tysAtoms_map msAtoms.1
      (fun _ h => substTyAt_atoms h (ts := [id.target]) (es := [])
        ⟨hi.1, trivial⟩ (by simp) ms.tparams.length)
    have dictAtoms := tysAtoms_map hi.2.1
      (fun _ h => shiftTy_atoms h ms.tparams.length 0)
    have hb' := checkBlock_of_mutual hs.surface hq (hi.2.2.2 m body hb)
      (Env.atoms_binds (tysAtoms_append dictAtoms paramsAtoms))
      (fun t ht => by cases ht; exact resultAtoms) hBlock
    have typed := accept_block_eff hb'.1 hb'.2.1 resultAtoms hb'.2.2 hAccept hEff
    refine ⟨body, hb, ?_, ?_⟩
    · simpa only [substTyAt_eq, ImplDecl.methTy] using (lamBodyOk_spec _ _).mp hExit
    · simpa only [substTyAt_fun_eq, shiftTy_fun_eq, methTy_fun_eq] using typed
  · intro s hmem
    obtain ⟨d, dictPath, a, hds, ha, he⟩ := checkSuperDicts_entry hd s hmem
    have ht := checkDict_of_dictionary hs.dictionaries hq (hi.2.2.1 s d hds)
      (Env.atoms_binds hi.2.1) ha
    have eqTy := tyEq_sound ht.2 (b := .dict s id.target) hi.1 he
    exact ⟨d, hds, by rw [← eqTy]; exact ht.1⟩

end Benitoite.Surface.Check
