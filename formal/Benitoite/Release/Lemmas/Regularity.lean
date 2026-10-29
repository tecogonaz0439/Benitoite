import Benitoite.Release.Lemmas.Inversion
import Benitoite.Release.Lemmas.Rename
import Benitoite.Release.Lemmas.TyLemmas
import Benitoite.Release.Assumptions
import Benitoite.Release.RangeInst

/-!
# 型の正しさの伝播（契約名を持つコア）

環境・ストアの型付け・項の型が正しいとき、型付けの導出の結果の型も正しい。

関数型の名前の整形式を、環境・宣言・型付けの証拠から導く。型の置換は名前を変更しない
（設計書 01-12「型付け規則」）。
-/

namespace Benitoite.Release

variable {Q : NoFailCtx}


variable {P : Program} {B : Builtins}

/-- 環境の型は、番号が `n` より小さい型の変数だけを使う。 -/
def EnvWF (n : Nat) (Γ : List (Option Ty)) : Prop :=
  ∀ (i : Nat) (x : Ty), Γ[i]? = some (some x) → Ty.WF 0 n x

/-- ストアの型付けの型は、型の変数を含まない。 -/
def StoreTy.WF (Ψ : StoreTy) : Prop := ∀ l x, Ψ l = some x → x.WF

/-- 専用セルを隠すと、残る場所の整形式はそのまま保たれる。 -/
theorem StoreTy.WF.hideBuilders {Ψ : StoreTy} (h : Ψ.WF) : Ψ.hideBuilders.WF :=
  fun l x hx => h l x (hideBuilders_sub Ψ l x hx)


theorem fnTy_wf {n names ps r ε ts es} (hts : ∀ t ∈ ts, Ty.WF 0 n t)
    (hes : ∀ e ∈ es, Eff.WF 0 n e) (hps : Ty.WFList 0 ts.length ps)
    (hr : Ty.WF 0 ts.length r) (he : Eff.WF 0 ts.length ε) (hnames : NamesWF names ps) :
    Ty.WF 0 n (fnTy names ps r ε ts es) := by
  rw [fnTy_eq]
  exact ⟨NamesWF.map hnames _, Ty.substList_wf es hts hes ps hps,
    Ty.subst_wf es hts hes r hr, Eff.subst_wf es hts hes ε he, Eff.norm_idem _⟩

theorem EnvWF.binds' {n as Γ} (has : ∀ a ∈ as, Ty.WF 0 n a) (hΓ : EnvWF n Γ) :
    EnvWF n (Release.binds as ++ Γ) := by
  intro i x hi
  by_cases hlt : i < (Release.binds as).length
  · rw [List.getElem?_append_left hlt] at hi
    simp only [binds, List.getElem?_map, Option.map_eq_some_iff, Option.some.injEq] at hi
    obtain ⟨y, hy, rfl⟩ := hi
    exact has _ (List.mem_reverse.mp (List.mem_of_getElem? hy))
  · rw [List.getElem?_append_right (by omega)] at hi
    exact hΓ _ _ hi

theorem EnvWF.hide {n Γ} (h : EnvWF n Γ) : EnvWF n (hideConts Γ) := by
  intro i x hi
  exact h _ _ (hideConts_get.mp hi).1

theorem EnvWF.shift {n Γ} (k : Nat) (h : EnvWF n Γ) : EnvWF (n + k) (shiftEnv k Γ) := by
  intro i x hi
  simp only [shiftEnv, List.getElem?_map, Option.map_eq_some_iff] at hi
  obtain ⟨o, ho, hox⟩ := hi
  cases o with
  | none => simp at hox
  | some y =>
      simp only [Option.some.injEq] at hox
      obtain ⟨a, rfl, rfl⟩ := hox
      exact Ty.shift_wf k _ (h _ _ ho)

theorem Const.type_wf (c : Const) (n : Nat) : Ty.WF 0 n c.type := by
  cases c <;> simp [Const.type, Ty.WF]

theorem varsInList_mem {n pe} : {as : List Ty} → Ty.VarsInList 0 n pe as → ∀ {a}, a ∈ as → Ty.VarsIn 0 n pe a
  | [], _, _, h => by simp at h
  | b :: bs, w, a, h => by
      simp only [Ty.VarsInList] at w
      rcases List.mem_cons.mp h with rfl | h
      · exact w.1
      · exact varsInList_mem w.2 h

-- パターンが束縛する変数の型の正しさ。
mutual
  theorem PatTy.wf {n : Nat} (hwf : P.WellFormed) {p a δ} (hp : PatTy P p a δ) (ha : Ty.WF 0 n a) :
      ∀ x ∈ δ, Ty.WF 0 n x := by
    match hp with
    | .P_Wild => simp
    | .P_Var => simpa using ha
    | .P_Const _ => simp
    | .P_RangeInt => simp
    | .P_RangeChar => simp
    | .P_List (rest := rest) hb ht _ =>
        intro x hx
        rcases List.mem_append.mp hx with hx | hx
        · rcases List.mem_append.mp hx with hx | hx
          · exact PatTys.wf hwf hb (fun y hy => by
              have he := (List.mem_replicate.mp hy).2; subst y; exact ha) x hx
          · cases rest with
            | none => simp [restTys] at hx
            | some r => cases r with
              | skip => simp [restTys] at hx
              | bind => simp [restTys] at hx; subst x; exact ha
        · exact PatTys.wf hwf ht (fun y hy => by
            have he := (List.mem_replicate.mp hy).2; subst y; exact ha) x hx
    | .P_Con (cd := cd) (ts := ts) hc hts hps =>
        simp only [Ty.WF] at ha
        refine PatTys.wf hwf hps ?_
        intro x hx
        obtain ⟨y, hy, rfl⟩ := List.mem_map.mp hx
        have hs : Ty.WF 0 cd.ntys y := Ty.VarsIn.wf y (varsInList_mem (hwf.2.1 _ _ hc) hy)
        exact Ty.subst_wf [] (Ty.WFList.iff.mp ha) (by simp) y (by rw [hts]; exact hs)

  theorem PatTys.wf {n : Nat} (hwf : P.WellFormed) {ps as δ} (hps : PatTys P ps as δ)
      (has : ∀ x ∈ as, Ty.WF 0 n x) : ∀ x ∈ δ, Ty.WF 0 n x := by
    match hps with
    | .nil => simp
    | .cons hp hps' =>
        intro x hx
        rcases List.mem_append.mp hx with hx | hx
        · exact PatTy.wf hwf hp (has _ (by simp)) x hx
        · exact PatTys.wf hwf hps' (fun y hy => has y (by simp [hy])) x hx
end

theorem AltsTy.wf {n alts a δ} (hwf : P.WellFormed) (h : AltsTy P alts a δ)
    (ha : Ty.WF 0 n a) : ∀ x ∈ δ, Ty.WF 0 n x := by
  obtain ⟨p, γ, slots, hp, hs⟩ := h.witness
  intro x hx
  exact PatTy.wf hwf hp ha x (selectSlots_mem hs x hx)

theorem LocTy.WF.ref {Ψ : StoreTy} (hΨ : StoreTy.WF Ψ) {l a} (h : Ψ l = some (.ref a)) (n : Nat) :
    Ty.WF 0 n a := Ty.WF.mono (Nat.zero_le _) _ (hΨ _ _ h)

theorem LocTy.WF.lazy {Ψ : StoreTy} (hΨ : StoreTy.WF Ψ) {l a} (h : Ψ l = some (.lazy a)) (n : Nat) :
    Ty.WF 0 n a := Ty.WF.mono (Nat.zero_le _) _ (hΨ _ _ h)

theorem LocTy.WF.contT {Ψ : StoreTy} (hΨ : StoreTy.WF Ψ) {l b t ε r} (h : Ψ l = some (.cont b t ε r))
    (n : Nat) : Ty.WF 0 n t := Ty.WF.mono (Nat.zero_le _) _ (hΨ _ _ h).2.1

mutual
  /-- 型付けの結果の型の正しさ（値）。 -/
  theorem HasTypeVQ.wf {depth : Nat} (hwf : P.WellFormed) (hb : B.CoreAssumptions P) {Ψ C Γ v a}
      (h : HasTypeVQ P B Ψ Q C Γ v a) (hΓ : EnvWF C.length Γ) (hΨ : StoreTy.WF Ψ)
      (hv : Val.VarsIn C.length (fun _ => True) v depth) : Ty.WF 0 C.length a := by
    match h with
    | .V_Var hi _ => exact hΓ _ _ hi
    | .V_Const => exact Const.type_wf _ _
    | .V_Fun hd hnames had =>
        have hts := had.types
        simp only [Val.VarsIn] at hv
        have hsc := hwf.1 _ _ hd
        unfold Def.Scoped at hsc
        obtain ⟨_, hsc⟩ := hsc
        have hl : _ = _ := hts.1
        refine fnTy_wf (hnames := hnames) (Ty.WFList.iff.mp (Ty.VarsInList.wf _ hv.1))
          (fun e he => Eff.VarsIn.wf e (Eff.VarsInList.iff.mp hv.2 e he)) ?_ ?_ ?_
        · rw [hl]; exact Ty.VarsInList.wf _ hsc.1
        · rw [hl]; exact Ty.VarsIn.wf _ hsc.2.1
        · rw [hl]; exact Eff.VarsIn.wf _ hsc.2.2.1
    | .V_Prim hs hrs hnames had =>
        have hts := had.typeCount
        simp only [Val.VarsIn] at hv
        have hsc := (hb.sig_scoped _ _ hs).inst_wf_zero hrs.nranges_le
        refine fnTy_wf (hnames := hnames) (Ty.WFList.iff.mp (Ty.VarsInList.wf _ hv.1))
          (fun e he => Eff.VarsIn.wf e (Eff.VarsInList.iff.mp hv.2 e he)) ?_ ?_ ?_
        · rw [hts]; exact hsc.1
        · rw [hts]; exact hsc.2.1
        · rw [hts]; exact hsc.2.2
    | .V_Op hod hnames hts =>
        simp only [Val.VarsIn] at hv
        have hsc := hwf.2.2.1 _ _ hod
        unfold OpDecl.Scoped at hsc
        obtain ⟨_, hsc⟩ := hsc
        have hl : _ = _ := hts.1
        refine fnTy_wf (hnames := hnames) (Ty.WFList.iff.mp (Ty.VarsInList.wf _ hv)) (by simp) ?_ ?_ (by simp [Eff.single, Eff.ofAtoms, Eff.WF, Ty.WFList])
        · rw [hl]; exact Ty.VarsInList.wf _ hsc.1
        · rw [hl]; exact Ty.VarsIn.wf _ hsc.2
    | .V_Raise ht he =>
        exact ⟨by simp [NamesWF], ⟨he, trivial⟩, ht,
          ⟨Ty.norm_WF _ he, trivial⟩, by
            simp [Eff.Canonical, Eff.singleFail, Eff.norm, Ty.norm_idem]⟩
    | .V_Lam _ hw _ => exact hw
    | .V_Con hc hts _ =>
        simp only [Val.VarsIn] at hv
        simp only [Ty.WF]; exact Ty.VarsInList.wf _ hv.1
    | .V_List _ hw => simpa [Ty.WF] using hw
    | .V_LocRef hl => simpa [Ty.WF] using LocTy.WF.ref hΨ hl C.length
    | .V_LocLazy hl => simpa [Ty.WF] using LocTy.WF.lazy hΨ hl C.length
    | .V_Map _ _ _ _ hwa hwb => simp only [Ty.WF]; exact ⟨hwa, hwb⟩
    | .V_Set _ _ hw => simpa [Ty.WF] using hw
    | .V_Bytes => simp [Ty.WF]
    | .V_Dict (id := id) hi hts _ =>
        simp only [Val.VarsIn] at hv
        have hsc := (hwf.2.2.2.2 _ _ hi).2.1
        have hl : _ = _ := hts.1
        simp only [Ty.WF]
        exact Ty.subst_wf [] (Ty.WFList.iff.mp (Ty.VarsInList.wf _ hv.1)) (by simp) _
          (by rw [hl]; exact Ty.VarsIn.wf _ hsc)
    | .V_Super hv' _ _ =>
        simp only [Val.VarsIn] at hv
        have := HasTypeVQ.wf (depth := _) hwf hb hv' hΓ hΨ hv
        simpa [Ty.WF] using this
    | .V_Sub _ _ hw => exact hw
    | .V_Checked _ _ => simp [Ty.WF]
    | .V_CheckedRequest _ _ _ _ => simp [Ty.WF]

  /-- 型付けの結果の型の正しさ（計算）。 -/
  theorem HasTypeCQ.wf {Δl : LocalCtx} {depth : Nat} (hwf : P.WellFormed) (hb : B.CoreAssumptions P) {Ψ C Γ R m a ε}
      (h : HasTypeCQ P B Ψ Q C Γ R m a ε Δl) (hΓ : EnvWF C.length Γ) (hΨ : StoreTy.WF Ψ)
      (hm : Comp.VarsIn C.length (fun _ => True) m depth) : Ty.WF 0 C.length a := by
    match h with
    | .C_BuilderLet _ hbBody =>
        refine HasTypeCQ.wf (depth := depth + 1) hwf hb hbBody ?_ hΨ hm.2
        intro i x hi
        cases i with
        | zero => simp at hi
        | succ i => exact hΓ i x (by simpa using hi)
    | .C_BuilderOp (kind := kind) (op := op) hw _ _ =>
        cases op <;> simp_all [BuilderOp.result, Ty.WF]
    | .C_Return hv => simp only [Comp.VarsIn] at hm; exact HasTypeVQ.wf (depth := _) hwf hb hv hΓ hΨ hm
    | .C_Sub _ _ _ hw => exact hw
    | .C_Eff h _ => exact HasTypeCQ.wf (depth := _) hwf hb h hΓ hΨ hm
    | .C_Let hm' hn =>
        simp only [Comp.VarsIn] at hm
        have ha := HasTypeCQ.wf (depth := _) hwf hb hm' hΓ hΨ hm.1
        refine HasTypeCQ.wf (depth := _) hwf hb hn ?_ hΨ hm.2
        have := EnvWF.binds' (as := [_]) (by simpa using ha) hΓ
        simpa [Release.binds] using this
    | .C_App hf _ =>
        simp only [Comp.VarsIn] at hm
        have := HasTypeVQ.wf (depth := _) hwf hb hf hΓ hΨ hm.1
        simp only [Ty.WF] at this; exact this.2.2.1
    | .C_If _ hm' _ => simp only [Comp.VarsIn] at hm; exact HasTypeCQ.wf (depth := _) hwf hb hm' hΓ hΨ hm.2.1
    | .C_Match hv harms _ =>
        simp only [Comp.VarsIn] at hm
        exact HasTypeArmsQ.wf (depth := _) hwf hb harms (HasTypeVQ.wf (depth := _) hwf hb hv hΓ hΨ hm.1) hΓ hΨ hm.2
    | .C_Lazy hm' =>
        simp only [Comp.VarsIn] at hm
        simpa [Ty.WF] using HasTypeCQ.wf (depth := _) hwf hb hm' hΓ.hide hΨ.hideBuilders hm
    | .C_Escape _ hw => exact hw
    | .C_Use _ _ hm' _ => simp only [Comp.VarsIn] at hm; exact HasTypeCQ.wf (depth := _) hwf hb hm' hΓ hΨ hm.2
    | .C_Handle hm' _ _ => simp only [Comp.VarsIn] at hm; exact HasTypeCQ.wf (depth := _) hwf hb hm' hΓ hΨ hm.1
    | .C_Handle_Fail hm' _ _ _ => exact HasTypeCQ.wf (depth := _) hwf hb hm' hΓ hΨ hm.1
    | .C_Resume hi _ =>
        have := hΓ _ _ hi
        simp only [Ty.WF] at this; exact this.2.1
    | .C_ResumeL hl _ => exact LocTy.WF.contT hΨ hl C.length
    | .C_Meth (τ := τ) (ms := ms) hv hc hmeth hnames hts _ _ _ =>
        simp only [Comp.VarsIn] at hm
        have hτ : Ty.WF 0 C.length τ := by
          have := HasTypeVQ.wf (depth := _) hwf hb hv hΓ hΨ hm.1
          simpa [Ty.WF] using this
        have hsc := hwf.2.2.2.1 _ _ hc _ _ hmeth
        have hl : _ = _ := hts.1
        refine Ty.subst_wf _ ?_ ?_ _ ?_
        · intro t ht
          rcases List.mem_append.mp ht with ht | ht
          · exact Ty.WFList.iff.mp (Ty.VarsInList.wf _ hm.2.1) t ht
          · simp at ht; rw [ht]; exact hτ
        · intro e he
          exact Eff.VarsIn.wf e (Eff.VarsInList.iff.mp hm.2.2.1 e he)
        · simp only [List.length_append, List.length_singleton, hl]
          exact Ty.VarsIn.wf _ hsc.2.2.1

  theorem HasTypeArmsQ.wf {Δl : LocalCtx} {depth : Nat} (hwf : P.WellFormed) (hb : B.CoreAssumptions P) {Ψ C Γ R arms a b ε}
      (h : HasTypeArmsQ P B Ψ Q C Γ R arms a b ε Δl) (ha : Ty.WF 0 C.length a) (hΓ : EnvWF C.length Γ)
      (hΨ : StoreTy.WF Ψ) (harms : Arm.VarsInList C.length (fun _ => True) arms depth) :
      Ty.WF 0 C.length b := by
    match h with
    | .nil hw => exact hw
    | .plain hp hbody _ =>
        simp only [Arm.VarsInList] at harms
        exact HasTypeCQ.wf (depth := _) hwf hb hbody (EnvWF.binds' (AltsTy.wf hwf hp ha) hΓ) hΨ harms.1
    | .guarded hp _ hbody _ =>
        simp only [Arm.VarsInList] at harms
        exact HasTypeCQ.wf (depth := _) hwf hb hbody (EnvWF.binds' (AltsTy.wf hwf hp ha) hΓ) hΨ harms.2.1

end

end Benitoite.Release
