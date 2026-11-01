# 群 S 後半の完全署名と補助契約

B_WORK: `42a09116fd2442fca93b38a7e18b8138356a8dcc`。指定ブランチは `m014/l10.s2`。git による照合・操作は行わない。名前空間は `Benitoite.Release.Refinement`。以下は現行の構文に合わせて実装前に確定した署名である。実装に伴う補助の追加は末尾に記録する。

## WF と型移動

```lean
theorem Ty.rawShift_of_wf {nr nv c : Nat} (k : Nat) (a : Ty) (h : a.WF nr c nv) : shiftTypes k c a = a
theorem Ty.rawShiftTys_of_wf {nr nv c : Nat} (k : Nat) (as : List Ty) (h : Ty.WFList nr c nv as) : shiftTypesList k c as = as
theorem Eff.rawShift_of_wf {nr nv c : Nat} (k : Nat) (e : Eff) (h : e.WF nr c nv) : shiftRowsTypes k c e = e
theorem Tel.rawShift_of_wf {nr nv c : Nat} (k : Nat) (t : Tel) (h : t.WF nr c nv) : shiftTelTypes k c t = t
theorem Ty.shift_of_wf {nr nv c : Nat} (k : Nat) (a : Ty) (h : a.WF nr c nv) : Ty.shift k c a = a.norm
theorem Eff.shift_of_wf {nr nv c : Nat} (k : Nat) (e : Eff) (h : e.WF nr c nv) : Eff.shift k c e = e.norm
```

## 一般置換と有限列の形成

```lean
structure SubstEnv.WFImages (nr nt nv mr mt mv : Nat) (θ : SubstEnv) : Prop where
  types : ∀ i, i < nt → (θ.types i).WF mr mt mv
  rows : ∀ e ∈ θ.rows, e.WF mr mt mv
  ranges : ∀ (ix : RangeIx), ix.WF nr → (ix.inst θ.ranges).WF mr
  values : ∀ i, i < nv → ∀ t, θ.values i = some t → termWF mv t
  ordinary : ∀ i, Ordinary (θ.types i)
theorem SubstEnv.WFImages.up {nr nt nv mr mt mv : Nat} {θ : SubstEnv}
    (h : θ.WFImages nr nt nv mr mt mv) : θ.up.WFImages nr nt (nv+1) mr mt (mv+1)
theorem Ty.rawBind_norm_wf {nr nt nv mr mt mv : Nat} {θ : SubstEnv} (a : Ty) (h : a.WF nr nt nv) (hi : θ.WFImages nr nt nv mr mt mv) : (a.rawBind θ).norm.WF mr mt mv
theorem rawBindTys_norm_wf {nr nt nv mr mt mv : Nat} {θ : SubstEnv} (as : List Ty) (h : Ty.WFList nr nt nv as) (hi : θ.WFImages nr nt nv mr mt mv) : Ty.WFList mr mt mv (Ty.normTys (rawBindTys θ as))
theorem Eff.rawBind_norm_wf {nr nt nv mr mt mv : Nat} {θ : SubstEnv} (e : Eff) (h : e.WF nr nt nv) (hi : θ.WFImages nr nt nv mr mt mv) : (Eff.rawBind θ e).norm.WF mr mt mv
theorem Tel.rawBind_norm_wf {nr nt nv mr mt mv : Nat} {θ : SubstEnv} (t : Tel) (h : t.WF nr nt nv) (hi : θ.WFImages nr nt nv mr mt mv) : (Tel.norm (Tel.rawBind θ t)).WF mr mt mv
theorem Ty.bind_wf {nr nt nv mr mt mv : Nat} {θ : SubstEnv} (a : Ty) (h : a.WF nr nt nv) (hi : θ.WFImages nr nt nv mr mt mv) : (a.bind θ).WF mr mt mv
theorem Eff.bind_wf {nr nt nv mr mt mv : Nat} {θ : SubstEnv} (e : Eff) (h : e.WF nr nt nv) (hi : θ.WFImages nr nt nv mr mt mv) : (Eff.bind θ e).WF mr mt mv
theorem typeEnvAt_wfImages {nr n nv : Nat} (c : Nat) (ts : List Ty) (es : List Eff)
    (ht : ∀ a ∈ ts, a.WF nr n nv) (he : ∀ e ∈ es, e.WF nr n nv)
    (ho : ∀ a ∈ ts, Ordinary a) :
    (typeEnvAt c ts es).WFImages nr (c+ts.length) nv nr (n+c) nv
theorem Ty.substAt_wf {nr n nv : Nat} (c : Nat) (ts : List Ty) (es : List Eff)
    (ht : ∀ a ∈ ts, a.WF nr n nv) (he : ∀ e ∈ es, e.WF nr n nv)
    (ho : ∀ a ∈ ts, Ordinary a) (a : Ty) (h : a.WF nr (c+ts.length) nv) :
    (Ty.substAt c ts es a).WF nr (n+c) nv
theorem Ty.subst_wf {nr n nv : Nat} (ts : List Ty) (es : List Eff)
    (ht : ∀ a ∈ ts, a.WF nr n nv) (he : ∀ e ∈ es, e.WF nr n nv)
    (ho : ∀ a ∈ ts, Ordinary a) (a : Ty) (h : a.WF nr ts.length nv) :
    (Ty.subst ts es a).WF nr n nv
theorem Eff.substAt_wf {nr n nv : Nat} (c : Nat) (ts : List Ty) (es : List Eff)
    (ht : ∀ a ∈ ts, a.WF nr n nv) (he : ∀ e ∈ es, e.WF nr n nv)
    (ho : ∀ a ∈ ts, Ordinary a) (e : Eff) (h : e.WF nr (c+ts.length) nv) :
    (Eff.substAt c ts es e).WF nr (n+c) nv
theorem Eff.subst_wf {nr n nv : Nat} (ts : List Ty) (es : List Eff)
    (ht : ∀ a ∈ ts, a.WF nr n nv) (he : ∀ e ∈ es, e.WF nr n nv)
    (ho : ∀ a ∈ ts, Ordinary a) (e : Eff) (h : e.WF nr ts.length nv) :
    (Eff.subst ts es e).WF nr n nv
theorem Ty.substList_wf {nr n nv : Nat} (ts : List Ty) (es : List Eff)
    (ht : ∀ a ∈ ts, a.WF nr n nv) (he : ∀ e ∈ es, e.WF nr n nv)
    (ho : ∀ a ∈ ts, Ordinary a) (as : List Ty) (h : Ty.WFList nr ts.length nv as) :
    Ty.WFList nr n nv (as.map (Ty.subst ts es))
def Eff.AtomsWF (nr : Nat) (e : Eff) : Prop := ∀ l ix, e.mem (.name l ix) → ix.WF nr
theorem Eff.substAt_atoms_wf {nr c : Nat} {ts : List Ty} {es : List Eff} {e : Eff}
    (h : e.AtomsWF nr) (he : ∀ f ∈ es, f.AtomsWF nr) :
    (Eff.substAt c ts es e).AtomsWF nr
theorem Ty.rawShift_eq_rawBind (k c : Nat) (a : Ty) : shiftTypes k c a = (a.rawBind) (SubstEnv.shiftTypes k c)
theorem Ty.rawShiftTys_eq_rawBindTys (k c : Nat) (as : List Ty) : shiftTypesList k c as = (fun θ => rawBindTys θ as) (SubstEnv.shiftTypes k c)
theorem Eff.rawShift_eq_rawBind (k c : Nat) (e : Eff) : shiftRowsTypes k c e = (fun θ => Eff.rawBind θ e) (SubstEnv.shiftTypes k c)
```

## 行と四名前空間の再帰条件

既存の Admissible の RowsIn 四族を再定義しない。VarsIn は WF・RowsIn・既存の RangesScoped を束ねる。nr は範囲、nt は型、pe は行、nv は値と self の上限である。

```lean
def Ty.VarsIn (nr nt nv : Nat) (pe : Nat → Prop) (a : Ty) : Prop := a.WF nr nt nv ∧ a.RowsIn pe ∧ a.RangesScoped nr
def Eff.VarsIn (nr nt nv : Nat) (pe : Nat → Prop) (e : Eff) : Prop := e.WF nr nt nv ∧ e.RowsIn pe ∧ e.RangesScoped nr
def Tel.VarsIn (nr nt nv : Nat) (pe : Nat → Prop) (t : Tel) : Prop := t.WF nr nt nv ∧ t.RowsIn pe ∧ t.RangesScoped nr
def Ty.VarsInList (nr nt nv : Nat) (pe : Nat → Prop) (as : List Ty) : Prop := ∀ a ∈ as, a.VarsIn nr nt nv pe
theorem Ty.RowsInList.iff {pe : Nat → Prop} {as : List Ty} : Ty.RowsInList pe as ↔ ∀ a ∈ as, a.RowsIn pe
theorem Ty.VarsInList.iff {nr nt nv : Nat} {pe : Nat → Prop} {as : List Ty} : Ty.VarsInList nr nt nv pe as ↔ ∀ a ∈ as, a.VarsIn nr nt nv pe
theorem Ty.RowsIn.mono {pe pf : Nat → Prop} (hp : ∀ i, pe i → pf i) (a : Ty) (h : a.RowsIn pe) : a.RowsIn pf
theorem Ty.norm_rowsIn {pe : Nat → Prop} (a : Ty) (h : a.RowsIn pe) : (Ty.norm a).RowsIn pe
theorem Ty.rowsIn_true (a : Ty) : a.RowsIn (fun _ => True)
theorem Ty.VarsIn.wf {nr nt nv : Nat} {pe : Nat → Prop} (a : Ty) (h : a.VarsIn nr nt nv pe) : a.WF nr nt nv
theorem Ty.VarsIn.rows {nr nt nv : Nat} {pe : Nat → Prop} (a : Ty) (h : a.VarsIn nr nt nv pe) : a.RowsIn pe
theorem Ty.VarsIn.mono {nr nt nv mt mv : Nat} {pe pf : Nat → Prop}
    (ht : nt ≤ mt) (hv : nv ≤ mv) (hp : ∀ i, pe i → pf i) (a : Ty) (h : a.VarsIn nr nt nv pe) : a.VarsIn nr mt mv pf
theorem Ty.norm_VarsIn {nr nt nv : Nat} {pe : Nat → Prop} (a : Ty) (h : a.VarsIn nr nt nv pe) : (Ty.norm a).VarsIn nr nt nv pe
theorem Eff.RowsIn.mono {pe pf : Nat → Prop} (hp : ∀ i, pe i → pf i) (e : Eff) (h : e.RowsIn pe) : e.RowsIn pf
theorem Eff.norm_rowsIn {pe : Nat → Prop} (e : Eff) (h : e.RowsIn pe) : (Eff.norm e).RowsIn pe
theorem Eff.rowsIn_true (e : Eff) : e.RowsIn (fun _ => True)
theorem Eff.VarsIn.wf {nr nt nv : Nat} {pe : Nat → Prop} (e : Eff) (h : e.VarsIn nr nt nv pe) : e.WF nr nt nv
theorem Eff.VarsIn.rows {nr nt nv : Nat} {pe : Nat → Prop} (e : Eff) (h : e.VarsIn nr nt nv pe) : e.RowsIn pe
theorem Eff.VarsIn.mono {nr nt nv mt mv : Nat} {pe pf : Nat → Prop}
    (ht : nt ≤ mt) (hv : nv ≤ mv) (hp : ∀ i, pe i → pf i) (e : Eff) (h : e.VarsIn nr nt nv pe) : e.VarsIn nr mt mv pf
theorem Eff.norm_VarsIn {nr nt nv : Nat} {pe : Nat → Prop} (e : Eff) (h : e.VarsIn nr nt nv pe) : (Eff.norm e).VarsIn nr nt nv pe
theorem Tel.RowsIn.mono {pe pf : Nat → Prop} (hp : ∀ i, pe i → pf i) (t : Tel) (h : t.RowsIn pe) : t.RowsIn pf
theorem Tel.norm_rowsIn {pe : Nat → Prop} (t : Tel) (h : t.RowsIn pe) : (Tel.norm t).RowsIn pe
theorem Tel.rowsIn_true (t : Tel) : t.RowsIn (fun _ => True)
theorem Tel.VarsIn.wf {nr nt nv : Nat} {pe : Nat → Prop} (t : Tel) (h : t.VarsIn nr nt nv pe) : t.WF nr nt nv
theorem Tel.VarsIn.rows {nr nt nv : Nat} {pe : Nat → Prop} (t : Tel) (h : t.VarsIn nr nt nv pe) : t.RowsIn pe
theorem Tel.VarsIn.mono {nr nt nv mt mv : Nat} {pe pf : Nat → Prop}
    (ht : nt ≤ mt) (hv : nv ≤ mv) (hp : ∀ i, pe i → pf i) (t : Tel) (h : t.VarsIn nr nt nv pe) : t.VarsIn nr mt mv pf
theorem Tel.norm_VarsIn {nr nt nv : Nat} {pe : Nat → Prop} (t : Tel) (h : t.VarsIn nr nt nv pe) : (Tel.norm t).VarsIn nr nt nv pe
theorem Ty.RowsInList.mono {pe pf : Nat → Prop} (hp : ∀ i, pe i → pf i) (as : List Ty) (h : Ty.RowsInList pe as) : Ty.RowsInList pf as
theorem Ty.normTys_rowsIn {pe : Nat → Prop} (as : List Ty) (h : Ty.RowsInList pe as) : Ty.RowsInList pe (Ty.normTys as)
theorem Ty.rowsInList_true (as : List Ty) : Ty.RowsInList (fun _ => True) as
theorem Ty.VarsInList.wf {nr nt nv : Nat} {pe : Nat → Prop} (as : List Ty) (h : Ty.VarsInList nr nt nv pe as) : Ty.WFList nr nt nv as
theorem Ty.VarsInList.rows {nr nt nv : Nat} {pe : Nat → Prop} (as : List Ty) (h : Ty.VarsInList nr nt nv pe as) : Ty.RowsInList pe as
theorem Ty.VarsInList.mono {nr nt nv mt mv : Nat} {pe pf : Nat → Prop}
    (ht : nt ≤ mt) (hv : nv ≤ mv) (hp : ∀ i, pe i → pf i) (as : List Ty) (h : Ty.VarsInList nr nt nv pe as) : Ty.VarsInList nr mt mv pf as
```

## 移動の比較・正規形・整列

```lean
theorem shiftIndex_compare (k c i j : Nat) : compare (shiftIndex k c i) (shiftIndex k c j) = compare i j
theorem Ty.rawShift_canonical (k c : Nat) {a : Ty} (h : a.Canonical) : (shiftTypes k c a).Canonical
theorem Ty.shift_canonical (k c : Nat) (a : Ty) : (Ty.shift k c a).Canonical
theorem Ty.shift_zero_norm (c : Nat) (a : Ty) : Ty.shift 0 c a = a.norm
theorem Eff.rawShift_canonical (k c : Nat) {e : Eff} (h : e.Canonical) : (shiftRowsTypes k c e).Canonical
theorem Eff.shift_canonical (k c : Nat) (e : Eff) : (Eff.shift k c e).Canonical
theorem Eff.shift_zero_norm (c : Nat) (e : Eff) : Eff.shift 0 c e = e.norm
theorem Ty.shift_compare_norm (k c : Nat) (a b : Ty) : tyCompare (a.shift k c) (b.shift k c) = tyCompare a.norm b.norm
theorem Ty.shift_compare (k c : Nat) (a b : Ty) (ha : a.Canonical) (hb : b.Canonical) : tyCompare (a.shift k c) (b.shift k c) = tyCompare a b
theorem shift_map (k c : Nat) (as : List Ty) (ha : ∀ a ∈ as, a.Canonical) : as.map (Ty.shift k c) = as.map (shiftTypes k c)
theorem Ty.shift_compareList (k c : Nat) (as bs : List Ty) (ha : ∀ a ∈ as, a.Canonical) (hb : ∀ b ∈ bs, b.Canonical) :
    Order.treesCompare Order.labelCompare (Ty.toTrees (as.map (Ty.shift k c))) (Ty.toTrees (bs.map (Ty.shift k c))) =
    Order.treesCompare Order.labelCompare (Ty.toTrees as) (Ty.toTrees bs)
theorem Ty.sortUnique_shift (k c : Nat) (as : List Ty) (ha : ∀ a ∈ as, a.Canonical) :
    Order.sortUnique tyCompare (as.map (Ty.shift k c)) = (Order.sortUnique tyCompare as).map (Ty.shift k c)
```

生の比較・norm交換・zeroのFND118〜123/128〜130は、既存のTypeShiftOrder/TypeSubstの宣言をそのまま再利用する。完全署名の機械照合にはそれらも含める。

## 効果と行の置換

```lean
def Eff.Allows (σ : PathEnv) (κ : EffName → Option Scope.Domain.Kind) (e : Eff)
    (l : EffName) (t : Scope.Domain.Target) : Prop :=
  ∃ k r, κ l = some k ∧ e.mem (.name l (.fixed r)) ∧ r.Mem σ k t
def Atom.TopImage : Atom → Prop
  | .rho _ => True
  | .name _ ix => ix = .top
def Eff.TopAtoms (e : Eff) : Prop := ∀ a, e.mem a → a.TopImage
noncomputable def Eff.substRho (es : List Eff) (e : Eff) : Eff := Eff.subst [] es e
theorem Eff.memFail_singleFail (a b : Ty) : (Eff.singleFail a).memFail b ↔ a.norm = b.norm
theorem Eff.eq_of_sub_of_sub {e f : Eff} (he : e.Canonical) (hf : f.Canonical) (hef : Eff.Sub e f) (hfe : Eff.Sub f e) : e = f
theorem Eff.allows_norm {σ : PathEnv} {κ : EffName → Option Scope.Domain.Kind} {e : Eff} {l : EffName} {t : Scope.Domain.Target} :
    Eff.Allows σ κ e.norm l t ↔ Eff.Allows σ κ e l t
theorem Eff.TopAtoms.norm {e : Eff} (h : e.TopAtoms) : e.norm.TopAtoms
theorem Eff.substRho_empty (es : List Eff) : Eff.substRho es Eff.empty = Eff.empty
theorem Eff.substRho_name {es : List Eff} {e : Eff} {l : EffName} {ix : RangeIx} (h : e.mem (.name l ix)) :
    (Eff.substRho es e).mem (.name l ix)
```

## 補助契約の決定の記録

1. WFから型全体のCanonicalを導かない。rawの移動はshiftTypes、公開のshiftの恒等式はnormを結論する。
2. 生のbindの旧RawWFの三件は、rawBindの正規化後の新WFとして移す。RawWF又は同等のscope専用層を新設しない。像のWF・Ordinary・範囲像・値像をWFImagesへ集め、依存列のparamと篩のselfをそれぞれupで越える。型構成子のarityとkindの適格性は既存のProperApply/HasKindへ残す。
3. substAtはnrを保ち、c個の内側の型束縛を残す。型像の上限nを0に限定せず、結果はn+cとする。行像は同じ型深さへ移す。値深さnvは独立で、型のcutoffに加算しない。
4. RowsInは既存のAdmissibleの再帰を使い、Supportの行原子への射影と同値であることを証明する。範囲のWFと混同しない。
5. VarsInはWF/RowsIn/RangesScopedを束ね、既存SourceScopedの意味を保つ。AnnotationとHasKind.valueは継続型を許すため、非継続の代わりには使わない。承認された再開の変更でTypeArgsKinded/TypeArgsKindedAtのvalue kindの型引数とV_Raiseの二型にOrdinaryを要求する。constructor kindは形からOrdinaryを導く。SignatureInstanceの利用規則、構成子・辞書・builder、LegacyInputから、型置換の像のOrdinaryを供給する。新VarsInからOrdinaryを導く言明は作らない。
6. Allowsは固定したσでRangeExpr.Memを読む。κがnoneの効果名又はrvarの原子から対象の許可は生じない。型付け・Covers・Subにσを追加しない。TopAtomsは最上位の原子だけを読み、Failの型には制限しない。
7. 効果の構造等号には両辺のCanonicalと双方向のSubを要求する。双方向のCoversで代替しない。Failは正規化後の型等号で不変のままである。

五つの境界（主な定理の前提と結論、新しい公理、提供範囲、利用者の書ける形、精密な外部状態）を変更しない。主な定理と既存の定義の意味を変える必要が生じたら停止する。

負例による確認: [boundary.lean](boundary.lean) の `wf_not_canonical` と `public_shift_not_identity` は、WFの `Integer{true}` についてCanonicalと元への公開shiftの恒等式が偽であることを示す。`bad_refined_cont` と `le_does_not_supply_target_wf` / `le_does_not_supply_source_wf` は、篩の導入・除去の導出だけから両側のWFを得る旧言明が偽になる形を示す。`ordinary_needed_for_bind` はWFだけの継続型の像を篩へ挿入した反例である。`raw_bind_not_wf` と `normalized_bind_wf` は、WFの未整列の行像を潜在効果へ入れたとき、生の結果のWFを結論できず、正規化後ならWFを得ることを示す。このため、RawWFを再設置せず、像の条件と正規化後のWFへ直接置き換えた。いずれも既存の定義の意味を変更する理由には使っていない。

## RV-L10.s2 の再開で承認された規則変更

2026-11-01。重1について、TypeArgsKindedのvalue kindの型引数へOrdinaryを追加する案1が承認された。以下の変更を実装前に固定する。主な十言明の前提と結論は維持する。

```lean
def TypeArgsKinded (P : Program) (C : List TParam) (ts : List Ty) (ks : List TyKind) : Prop :=
  ts.length = ks.length ∧ ∃ K : KindCtx, K.length = C.length ∧
    ∀ (i : Nat) (a : Ty) (k : TyKind), ts[i]? = some a → ks[i]? = some k →
      a.HasKind P K k ∧ (k = .value → Ordinary a)
-- TypeArgsKindedAtも、宣言から得た同じkind文脈について同じ二条件を要求する。
theorem HasTypeVQ.V_Raise {P : Program} {B : Builtins} {Ψ : StoreTy}
    {Q : NoFailCtx} {C : List TParam} {Γ : Ctx} {Φ : List Pred} {t e : Ty} :
    Ty.Annotation P C Γ (.fn ["error"] [e] t (Eff.singleFail e)) →
    Ordinary t → Ordinary e →
    HasTypeVQ P B Ψ Q C Γ Φ (.raise t e) (.fn ["error"] [e] t (Eff.singleFail e))
```

constructor kindの型引数はHasKindの形からctor又はtvarであり、Ordinaryを導ける。したがってvalueの条件と合わせて、TypeArgsKindedから全型引数のOrdinaryを導く。C_Methのss++[τ]のWFとOrdinaryはSignatureInstanceのtypesとkindsから供給し、同じ条件を重複した規則の前提にはしない。V_ConのsourceOrdも新しいkindsの欄から導く。

LegacyInputでは型引数・raiseの二型・builderの内容型へOrdinaryを保持する。一般のLegacyTypeInputや継続を格納する文脈を一律にOrdinaryにはしない。旧型引数のNotContだけからembedTyのOrdinaryを導く。閉性を要求しないiff_of_notContにより、型変数を含む多相の本体でも適格な旧入力の範囲を変えないことを証明する。


## 再レビューの決定の記録

2026-11-01。raise_subst_wf/leは、E_OpFailが `.raise T E′` から作る `body.substTy [T] []` に合わせ、結果型Tの像を使う。エラー型E′の像ではない。raise_typeScopeの結果型側のWFとOrdinaryを供給し、型付け規則は変更しない。

LegacyTypesInputの同値は `∀ t ∈ ts, NotCont t` だけを前提にするiff_of_notContへ替える。旧ClosedArgsが持つWF 0 0は要求しない。旧VarsInとVarsInListから各型のNotContを得る補題を添え、型変数を持つ旧導出にも適用する。

Ordinaryは篩を外した芯の最上位だけを読み、入れ子の継続を検査しない。したがって `.op "o" [.list k0]` は引き続き型付く。旧ClosedArgsのNotContも最上位だけであり、旧VarsInの再帰的な継続の禁止とは区別する。型置換の代表ではOrdinaryの保存が成り立ち、継続型の閉じた値を作る規則もないため、規則を再帰的な禁止へ強めない。全状態で害がないことの確認はG03の入力とする。

## 実装で追加した補助と既存の再使用

以下は初版の署名に加えた補助である。RowsInとRangesScopedの定義は既存のままとし、支持との同値を証明した。生の移動のWF四族は、TypeShiftContextに同じ証明があるため、それを再使用する。新しい同名の相互証明は追加しない。

```lean
theorem observationWF_up {nv mv : Nat} {ν : ObservationEnv}
    (h : ∀ i, i < nv → ∀ t, ν i = some t → termWF mv t) : ∀ i, i < nv+1 → ∀ t, upValues ν i = some t → termWF (mv+1) t
theorem rawApply_notContCore {t : Ty} (h : t.NotContCore) (as : List Ty) : (rawApply t as).NotContCore
theorem rawApply_wf {nr nt nv : Nat} {t : Ty} (ht : t.WF nr nt nv) (as : List Ty)
    (hs : Ty.WFList nr nt nv as) : (rawApply t as).WF nr nt nv
theorem Tel.bind_wf {nr nt nv mr mt mv : Nat} {θ : SubstEnv} (t : Tel)
    (h : t.WF nr nt nv) (hi : θ.WFImages nr nt nv mr mt mv) : (Tel.bind θ t).WF mr mt mv
theorem Tel.substAt_wf {nr n nv : Nat} (c : Nat) (ts : List Ty) (es : List Eff)
    (ht : ∀ a ∈ ts, a.WF nr n nv) (he : ∀ e ∈ es, e.WF nr n nv)
    (ho : ∀ a ∈ ts, Ordinary a) (t : Tel) (h : t.WF nr (c+ts.length) nv) : (Tel.substAt c ts es t).WF nr (n+c) nv
theorem typeEnvAt_agrees_id_below (c : Nat) (ts : List Ty) : SubstEnv.AgreesBelow c (typeEnvAt c ts []) (renEnv id)
theorem Ty.substAt_nil_of_wf {nr nv c : Nat} (ts : List Ty) (a : Ty)
    (h : a.WF nr c nv) : a.substAt c ts [] = a.norm
theorem Eff.substAt_nil_of_wf {nr nv c : Nat} (ts : List Ty) (e : Eff)
    (h : e.WF nr c nv) : Eff.substAt c ts [] e = e.norm
theorem Tel.substAt_nil_of_wf {nr nv c : Nat} (ts : List Ty) (t : Tel)
    (h : t.WF nr c nv) : Tel.substAt c ts [] t = Tel.norm t
def rowCondition (pe : Nat → Prop) : Atom → Prop
theorem Ty.rowsIn_iff_support (pe : Nat → Prop) (a : Ty) : a.RowsIn pe ↔ a.Support (rowCondition pe)
theorem Ty.rowsInList_iff_support (pe : Nat → Prop) (as : List Ty) : Ty.RowsInList pe as ↔ Ty.SupportList (rowCondition pe) as
theorem Eff.rowsIn_iff_support (pe : Nat → Prop) (e : Eff) : e.RowsIn pe ↔ e.Support (rowCondition pe)
theorem Tel.rowsIn_iff_support (pe : Nat → Prop) (t : Tel) : t.RowsIn pe ↔ t.Support (rowCondition pe)
def rangeCondition (nr : Nat) : Atom → Prop
theorem Ty.rangesScoped_iff_support {nr nt nv : Nat} (a : Ty) (hw : a.WF nr nt nv) : a.RangesScoped nr ↔ a.Support (rangeCondition nr)
theorem rangesScopedTypes_iff_support {nr nt nv : Nat} (as : List Ty)
      (hw : Ty.WFList nr nt nv as) : rangesScopedTypes nr as ↔ Ty.SupportList (rangeCondition nr) as
theorem Eff.rangesScoped_iff_support {nr nt nv : Nat} (e : Eff) (hw : e.WF nr nt nv) : e.RangesScoped nr ↔ e.Support (rangeCondition nr)
theorem Tel.rangesScoped_iff_support {nr nt nv : Nat} (t : Tel) (hw : t.WF nr nt nv) : t.RangesScoped nr ↔ t.Support (rangeCondition nr)
theorem Ty.varsIn_iff_sourceScoped (nr nt ne nv : Nat) (a : Ty) : a.VarsIn nr nt nv (· < ne) ↔ a.SourceScoped nr nt ne nv
theorem Eff.varsIn_iff_sourceScoped (nr nt ne nv : Nat) (e : Eff) : e.VarsIn nr nt nv (· < ne) ↔ e.SourceScoped nr nt ne nv
theorem substAtoms_false (es : List Eff) : substAtoms es (fun _ => false) = fun _ => false
theorem rowFails_false (es : List Eff) : rowFails es (fun _ => false) = []
theorem HasTypeVQ.dict_typeScope {P B Ψ Q C Γ Φ v a i ts vs}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hv : v = .dict i ts vs) : ∀ t ∈ ts, t.WF 0 C.length Γ.length ∧ Ordinary t
theorem SignatureInstance.method_typeScope {P C Γ t ss τ es} {ms : MethSig} {cd : ClassDecl}
    (h : SignatureInstance P C Γ t (ms.tparams.map TParamDecl.kind ++ [cd.argumentKind]) (ss ++ [τ]) es) : ∀ a ∈ ss ++ [τ], a.WF 0 C.length Γ.length ∧ Ordinary a
theorem HasTypeCQ.method_body_typeScope {P B Ψ Q C Γ Φ R m a e D i ts vs name ss es ws}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e D)
    (hm : m = .meth (.dict i ts vs) name ss es ws) : (∀ t ∈ ss ++ ts, t.WF 0 C.length Γ.length ∧ Ordinary t) ∧
    (∀ f ∈ es, f.WF 0 C.length Γ.length)
theorem HasTypeVQ.raise_typeScope {P B Ψ Q C Γ Φ v a t e}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hv : v = .raise t e) : (t.WF 0 C.length Γ.length ∧ Ordinary t) ∧ (e.WF 0 C.length Γ.length ∧ Ordinary e)
theorem HasTypeVQ.raise_subst_wf {P B Ψ Q C Γ Φ t e T} {a : Ty}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.raise t e) T) (ha : a.WF 0 1 Γ.length) : (a.subst [t] []).WF 0 C.length Γ.length
theorem HasTypeVQ.raise_subst_le {P B Ψ Q C Γ Φ t e T a b}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.raise t e) T) (hl : Ty.LeQ P Γ Φ a b) : Ty.LeQ P (Γ.bindTypes (typeEnvAt 0 [t] [])) Φ (a.subst [t] []) (b.subst [t] [])
theorem HasTypeVQ.op_subst_wf {P B Ψ Q C Γ Φ o ts T} {a : Ty}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.op o ts) T) (ha : a.WF 0 ts.length Γ.length) : (a.subst ts []).WF 0 C.length Γ.length
theorem HasTypeVQ.op_subst_le {P B Ψ Q C Γ Φ o ts T a b}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.op o ts) T) (hl : Ty.LeQ P Γ Φ a b) : Ty.LeQ P (Γ.bindTypes (typeEnvAt 0 ts [])) Φ (a.subst ts []) (b.subst ts [])
theorem HasTypeVQ.op_return_subst {P B Ψ Q C Γ Φ o ts T}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.op o ts) T) : HasTypeCQ P B Ψ Q C (Ctx.bindTypes [some (.tvar 0)] (typeEnvAt 0 ts [])) Φ none
      ((Comp.ret (.var 0)).substTy ts []) ((Ty.tvar 0).subst ts []) Eff.empty []
theorem HasTypeCQ.method_subst_wf {P B Ψ Q C Γ Φ R i ts vs name ss es ws T e D} {a : Ty}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R (.meth (.dict i ts vs) name ss es ws) T e D)
    (ha : a.WF 0 (ss++ts).length Γ.length) : (a.subst (ss++ts) es).WF 0 C.length Γ.length
theorem HasTypeCQ.method_subst_le {P B Ψ Q C Γ Φ R i ts vs name ss es ws T e D a b}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R (.meth (.dict i ts vs) name ss es ws) T e D)
    (hl : Ty.LeQ P Γ Φ a b) : Ty.LeQ P (Γ.bindTypes (typeEnvAt 0 (ss++ts) es)) Φ (a.subst (ss++ts) es) (b.subst (ss++ts) es)
theorem HasTypeCQ.method_return_subst {P B Ψ Q C Γ Φ R i ts vs name ss es ws T e D}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R (.meth (.dict i ts vs) name ss es ws) T e D) : HasTypeCQ P B Ψ Q C (Ctx.bindTypes [some (.tvar 0)] (typeEnvAt 0 (ss++ts) es)) Φ none
      ((Comp.ret (.var 0)).substTy (ss++ts) es) ((Ty.tvar 0).subst (ss++ts) es) Eff.empty []
theorem embedTy_ordinary_iff (a : Benitoite.Release.Ty) : Ordinary (embedTy a) ↔ a.NotCont
theorem LegacyTypesInput.of_notCont {K P0 Δ ts ks}
    (hc : ∀ t ∈ ts, Benitoite.Release.Ty.NotCont t)
    (h : ts.length = ks.length ∧ ∀ (i : Nat) (a : Benitoite.Release.Ty) (k : TyKind), ts[i]? = some a → ks[i]? = some k → LegacyTypeInput K P0 Δ a k) : LegacyTypesInput K P0 Δ ts ks
theorem LegacyTypesInput.iff_of_notCont {K P0 Δ ts ks} (hc : ∀ t ∈ ts, Benitoite.Release.Ty.NotCont t) : LegacyTypesInput K P0 Δ ts ks ↔
      ts.length = ks.length ∧ ∀ (i : Nat) (a : Benitoite.Release.Ty) (k : TyKind), ts[i]? = some a → ks[i]? = some k → LegacyTypeInput K P0 Δ a k
theorem notCont_of_legacyVarsIn {nr nt : Nat} {pe : Nat → Prop} {a : Benitoite.Release.Ty}
    (h : a.VarsIn nr nt pe) : a.NotCont
theorem notCont_of_legacyVarsInList {nr nt : Nat} {pe : Nat → Prop} {ts : List Benitoite.Release.Ty}
    (h : Benitoite.Release.Ty.VarsInList nr nt pe ts) : ∀ a ∈ ts, a.NotCont
theorem embedTy_ordinary_of_varsIn {nr nt : Nat} {pe : Nat → Prop} {a : Benitoite.Release.Ty}
    (h : a.VarsIn nr nt pe) : Ordinary (embedTy a)
theorem LegacyBuilderInput.iff_of_notCont {K P0 Δ k}
    (h : Benitoite.Release.Ty.NotCont k.contents) : LegacyBuilderInput K P0 Δ k ↔ LegacyTypeInput K P0 Δ k.contents .value
theorem LegacyValueInput.raise_of_varsIn {K P0 B0 B Δ a e}
    (h : Benitoite.Release.Val.VarsIn Δ.kinds.length (fun _ => True) (.raise a e))
    (ha : LegacyTypeInput K P0 Δ a .value) (he : LegacyTypeInput K P0 Δ e .value) : LegacyValueInput K P0 B0 B Δ (.raise a e)
theorem LegacyBuilderInput.iff {K P0 Δ k} : LegacyBuilderInput K P0 Δ k ↔ LegacyTypeInput K P0 Δ k.contents .value
theorem Ty.HasKind.constructor_ordinary {P K a n} (h : Ty.HasKind P K a (.constructor n)) : Ordinary a
theorem TypeArgsKinded.ordinary {P C ts ks} (h : TypeArgsKinded P C ts ks) : ∀ a ∈ ts, Ordinary a
theorem TypeArgsKinded.shift {P C ts ks} (h : TypeArgsKinded P C ts ks) (k c : Nat) : TypeArgsKinded P C (ts.map (Ty.shiftV k c)) ks
theorem TypeArgsKinded.subst {P C ts ks} (h : TypeArgsKinded P C ts ks) (ν : Nat → Val) : TypeArgsKinded P C (ts.map (substTyValues ν)) ks
theorem Ty.ordinary_bind_values (a : Ty) (σ : Nat → Val) : (substTyValues σ a).Ordinary ↔ a.Ordinary
theorem TypeArgsKinded.shiftTypes {P C C' ts ks} (h : TypeArgsKinded P C ts ks)
    (k c : Nat) (hn : C'.length=C.length+k) : TypeArgsKinded P C' (ts.map (shiftTypes k c)) ks
theorem TypeArgsKinded.norm {P C ts ks} (h : TypeArgsKinded P C ts ks) : TypeArgsKinded P C (Ty.normTys ts) ks
theorem SignatureInstance.ordinary {P C Γ t ks ts es}
    (h : SignatureInstance P C Γ t ks ts es) : ∀ a ∈ ts, Ordinary a
theorem SignatureInstance.typeScope {P C Γ t ks ts es}
    (h : SignatureInstance P C Γ t ks ts es) : ∀ a ∈ ts, a.WF 0 C.length Γ.length ∧ Ordinary a
def TypeArgsKindedAt (P : Program) (D : List TParamDecl) (ts : List Ty) (ks : List TyKind) : Prop
theorem TypeArgsKindedAt.forget {P D ts ks} (h : TypeArgsKindedAt P D ts ks) : TypeArgsKinded P (D.map TParamDecl.constraints) ts ks
theorem TypeArgsKindedAt.shift {P D ts ks} (h : TypeArgsKindedAt P D ts ks) (k c : Nat) : TypeArgsKindedAt P D (ts.map (Ty.shiftV k c)) ks
theorem TypeArgsKindedAt.subst {P D ts ks} (h : TypeArgsKindedAt P D ts ks) (ν : Nat → Val) : TypeArgsKindedAt P D (ts.map (substTyValues ν)) ks
theorem HasTypeCQ.operation_call {P B Ψ R o v a e L od ts}
    (h : HasTypeCQ P B Ψ Qempty [] [] [] R (.app (.op o ts) [v]) a e L)
    (hd : P.ops o = some od) : ∃ r f, HasTypeTelArgsQ P B Ψ Qempty [] [] [] [v]
      (instantiatedTel od.tel ts []) r f ∧
      Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e f
theorem ClosureTy.pure_operation {P B Ψ R a e o v od ts}
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF)
    (h : ClosureTy P B Ψ [] R (Closure.pure (.app (.op o ts) [v])) a e)
    (hd : P.ops o = some od) : ∃ r f, HasTypeTelArgsQ P B Ψ Qempty [] [] [] [v]
      (instantiatedTel od.tel ts []) r f ∧
      Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e f
theorem ClosureTy.pure_operation_signature {P B Ψ R a e o v od ts}
    (h : ClosureTy P B Ψ [] R (Closure.pure (.app (.op o ts) [v])) a e)
    (hd : P.ops o = some od) : Ty.Annotation P [] [] (.dependentFn (instantiatedTel od.tel ts []))
theorem HasTypeVQ.op_typeScope {P B Ψ Q C Γ Φ o ts a}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.op o ts) a) : ∀ t ∈ ts, t.WF 0 C.length Γ.length ∧ Ordinary t
theorem ClosureTy.pure_operation_typeScope {P B Ψ R a e o v ts}
    (h : ClosureTy P B Ψ [] R (Closure.pure (.app (.op o ts) [v])) a e) : ∀ t ∈ ts, t.WF 0 0 0 ∧ Ordinary t
theorem StateTyE.operation_typeScope {P B σ Eb o ts v k μ}
    (h : StateTyE P B σ Eb (.run (Closure.pure (.app (.op o ts) [v])) k μ)) : ∀ t ∈ ts, t.WF 0 0 0 ∧ Ordinary t
def LegacyKindArgs (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (κ : KindCtx) (ts : List Benitoite.Release.Ty) (ks : List TyKind) : Prop
def LegacyTypesInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (Δ : LegacyInputCtx) (ts : List Benitoite.Release.Ty) (ks : List TyKind) : Prop
def LegacyBuilderInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (Δ : LegacyInputCtx) (k : Benitoite.Release.BuilderKind) : Prop
theorem HasTypeVQ.constructor_field_inputs {P B Ψ Q C Γ Φ T c ts vs cd us} {i : Nat} {a : Ty}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.con c ts vs) T) (hc : P.cons c = some cd)
    (hT : T.norm.core = .data cd.data us) (ha : cd.args[i]? = some a)
    (valid : P.VarianceValid)
    (targetTypes : TypeAnnotations P C Γ us) (targetOrd : ∀ t ∈ us, Ordinary t) : Ty.Annotation P C Γ (a.subst ts []) ∧ Ty.Annotation P C Γ (a.subst us []) ∧
      VarianceSubstInput P C Γ (P.varianceFor cd.data ts.length) (Ty.normTys ts) us
theorem HasTypeVQ.con_field_by_type {P B Ψ Q C Γ Φ T c ts vs cd us} {i : Nat} {a : Ty}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.con c ts vs) T) (hc : P.cons c = some cd)
    (hT : T.norm.core = .data cd.data us) (ha : cd.args[i]? = some a)
    (valid : P.VarianceValid)
    (targetTypes : TypeAnnotations P C Γ us) (targetOrd : ∀ t ∈ us, Ordinary t) : ∃ v, vs[i]? = some v ∧ HasTypeVQ P B Ψ Q C Γ Φ v (a.subst us [])
theorem HasTypeVQ.field_facts_by_type {P B Ψ Q C Γ Φ T c ts vs cd us} {i : Nat} {a : Ty} {t : Term}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.con c ts vs) T) (hc : P.cons c = some cd)
    (hT : T.norm.core = .data cd.data us) (ha : cd.args[i]? = some a)
    (valid : P.VarianceValid)
    (targetTypes : TypeAnnotations P C Γ us) (targetOrd : ∀ t ∈ us, Ordinary t)
    (hs : (Val.toTermSlots vs)[i]? = some (some t)) : ∀ p ∈ (a.subst us []).assume, Entails (Γ.facts ++ Φ) (p.open t)
theorem Ty.shiftTypes_compare (k c : Nat) (a b : Ty) : tyCompare (shiftTypes k c a) (shiftTypes k c b) = tyCompare a b
theorem Ty.trees_shiftTypes_compare (k c : Nat) (as bs : List Ty) :
    Order.treesCompare Order.labelCompare (Ty.toTrees (shiftTypesList k c as)) (Ty.toTrees (shiftTypesList k c bs)) =
    Order.treesCompare Order.labelCompare (Ty.toTrees as) (Ty.toTrees bs)
theorem Eff.tree_shiftTypes_compare (k c : Nat) (e f : Eff) :
    Order.treeCompare Order.labelCompare (Eff.toTree (shiftRowsTypes k c e)) (Eff.toTree (shiftRowsTypes k c f)) =
    Order.treeCompare Order.labelCompare (Eff.toTree e) (Eff.toTree f)
theorem Ty.norm_shiftTypes (a : Ty) (k c : Nat) : (shiftTypes k c a).norm = shiftTypes k c a.norm
theorem Ty.normTys_shiftTypes (as : List Ty) (k c : Nat) : Ty.normTys (shiftTypesList k c as) = shiftTypesList k c (Ty.normTys as)
theorem Eff.norm_shiftTypes (e : Eff) (k c : Nat) : (shiftRowsTypes k c e).norm = shiftRowsTypes k c e.norm
theorem shiftTypes_zero (a : Ty) (c : Nat) : shiftTypes 0 c a = a
theorem shiftTypesList_zero (as : List Ty) (c : Nat) : shiftTypesList 0 c as = as
theorem shiftRowsTypes_zero (e : Eff) (c : Nat) : shiftRowsTypes 0 c e = e
```

完全署名は [signatures.lean](signatures.lean) が各宣言の型へ照合する。構造体WFImagesの各欄は本番のstructure宣言をカーネルが検査し、同じ型を前提としてupと置換を証明する。
