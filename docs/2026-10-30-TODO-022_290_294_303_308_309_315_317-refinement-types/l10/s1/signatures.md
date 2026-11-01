# 群 S 前半の完全署名と補助契約

B_WORK: `78aa5cca81cf24a420c266e6b714934297ce434e`。名前空間は `Benitoite.Release.Refinement`。以下の自由変数はなく、暗黙引数も括弧で明記する。旧 Legacy への三橋は提供しない。

## 支持と収集

```lean
def Ty.Support (p : Atom → Prop) : Ty → Prop
def Ty.SupportList (p : Atom → Prop) : List Ty → Prop
def Eff.Support (p : Atom → Prop) : Eff → Prop
def Tel.Support (p : Atom → Prop) : Tel → Prop
def Ty.Finite (a : Ty) : Prop := ∃ s : List Atom, Ty.Support (· ∈ s) a
def Eff.Finite (a : Eff) : Prop := ∃ s : List Atom, Eff.Support (· ∈ s) a
theorem Ty.SupportList.iff {p : Atom → Prop} {ts : List Ty} : Ty.SupportList p ts ↔ ∀ t ∈ ts, t.Support p
theorem Eff.support_iff {p : Atom → Prop} (e : Eff) : e.Support p ↔ (∀ a, e.test a = true → p a) ∧ Ty.SupportList p e.fails
theorem Ty.support_mono {p q : Atom → Prop} (a : Ty) (h : Ty.Support p a) (hp : ∀ x, p x → q x) : Ty.Support q a
def Ty.collectAtoms (s : List Atom) : Ty → List Atom
theorem Ty.collectAtoms_complete (s : List Atom) (a : Ty) (h : Ty.Support (· ∈ s) a) : Ty.Support (· ∈ Ty.collectAtoms s a) a
theorem Ty.collectAtoms_sound {p : Atom → Prop} (s : List Atom) (a : Ty) (h : Ty.Support p a) : ∀ x ∈ Ty.collectAtoms s a, p x
theorem Ty.collectAtoms_support_iff {s : List Atom} {a : Ty} (hs : Ty.Support (· ∈ s) a) (p : Atom → Prop) : Ty.Support p a ↔ ∀ x ∈ Ty.collectAtoms s a, p x
theorem Ty.norm_support {p : Atom → Prop} (a : Ty) (h : Ty.Support p a) : Ty.Support p (Ty.norm a)
theorem Ty.support_of_norm {p : Atom → Prop} (a : Ty) (h : Ty.Support p (Ty.norm a)) : Ty.Support p a
theorem Ty.supportList_mono {p q : Atom → Prop} (a : List Ty) (h : Ty.SupportList p a) (hp : ∀ x, p x → q x) : Ty.SupportList q a
def Ty.collectAtomsList (s : List Atom) : List Ty → List Atom
theorem Ty.collectAtomsList_complete (s : List Atom) (a : List Ty) (h : Ty.SupportList (· ∈ s) a) : Ty.SupportList (· ∈ Ty.collectAtomsList s a) a
theorem Ty.collectAtomsList_sound {p : Atom → Prop} (s : List Atom) (a : List Ty) (h : Ty.SupportList p a) : ∀ x ∈ Ty.collectAtomsList s a, p x
theorem Ty.collectAtomsList_support_iff {s : List Atom} {a : List Ty} (hs : Ty.SupportList (· ∈ s) a) (p : Atom → Prop) : Ty.SupportList p a ↔ ∀ x ∈ Ty.collectAtomsList s a, p x
theorem Ty.normTys_support {p : Atom → Prop} (a : List Ty) (h : Ty.SupportList p a) : Ty.SupportList p (Ty.normTys a)
theorem Ty.supportList_of_norm {p : Atom → Prop} (a : List Ty) (h : Ty.SupportList p (Ty.normTys a)) : Ty.SupportList p a
theorem Eff.support_mono {p q : Atom → Prop} (a : Eff) (h : Eff.Support p a) (hp : ∀ x, p x → q x) : Eff.Support q a
def Eff.collectAtoms (s : List Atom) : Eff → List Atom
theorem Eff.collectAtoms_complete (s : List Atom) (a : Eff) (h : Eff.Support (· ∈ s) a) : Eff.Support (· ∈ Eff.collectAtoms s a) a
theorem Eff.collectAtoms_sound {p : Atom → Prop} (s : List Atom) (a : Eff) (h : Eff.Support p a) : ∀ x ∈ Eff.collectAtoms s a, p x
theorem Eff.collectAtoms_support_iff {s : List Atom} {a : Eff} (hs : Eff.Support (· ∈ s) a) (p : Atom → Prop) : Eff.Support p a ↔ ∀ x ∈ Eff.collectAtoms s a, p x
theorem Eff.norm_support {p : Atom → Prop} (a : Eff) (h : Eff.Support p a) : Eff.Support p (Eff.norm a)
theorem Eff.support_of_norm {p : Atom → Prop} (a : Eff) (h : Eff.Support p (Eff.norm a)) : Eff.Support p a
theorem Tel.support_mono {p q : Atom → Prop} (a : Tel) (h : Tel.Support p a) (hp : ∀ x, p x → q x) : Tel.Support q a
def Tel.collectAtoms (s : List Atom) : Tel → List Atom
theorem Tel.collectAtoms_complete (s : List Atom) (a : Tel) (h : Tel.Support (· ∈ s) a) : Tel.Support (· ∈ Tel.collectAtoms s a) a
theorem Tel.collectAtoms_sound {p : Atom → Prop} (s : List Atom) (a : Tel) (h : Tel.Support p a) : ∀ x ∈ Tel.collectAtoms s a, p x
theorem Tel.collectAtoms_support_iff {s : List Atom} {a : Tel} (hs : Tel.Support (· ∈ s) a) (p : Atom → Prop) : Tel.Support p a ↔ ∀ x ∈ Tel.collectAtoms s a, p x
theorem Tel.norm_support {p : Atom → Prop} (a : Tel) (h : Tel.Support p a) : Tel.Support p (Tel.norm a)
theorem Tel.support_of_norm {p : Atom → Prop} (a : Tel) (h : Tel.Support p (Tel.norm a)) : Tel.Support p a
theorem Ty.rawShift_support {p : Atom → Prop} (k c : Nat) (a : Ty) (h : Ty.Support p a) : Ty.Support p (shiftTypes k c a)
theorem Ty.rawShiftTys_support {p : Atom → Prop} (k c : Nat) (a : List Ty) (h : Ty.SupportList p a) : Ty.SupportList p (shiftTypesList k c a)
theorem Eff.rawShift_support {p : Atom → Prop} (k c : Nat) (a : Eff) (h : Eff.Support p a) : Eff.Support p (shiftRowsTypes k c a)
theorem Tel.rawShift_support {p : Atom → Prop} (k c : Nat) (a : Tel) (h : Tel.Support p a) : Tel.Support p (shiftTelTypes k c a)
theorem Ty.shift_support {p : Atom → Prop} (k c : Nat) (a : Ty) (h : Ty.Support p a) : Ty.Support p (Ty.shift k c a)
theorem Eff.shift_support {p : Atom → Prop} (k c : Nat) (a : Eff) (h : Eff.Support p a) : Eff.Support p (Eff.shift k c a)
def SupportTransport (p q : Atom → Prop) (θ : SubstEnv) : Prop :=
  (∀ i, (θ.types i).Support q) ∧ (∀ e ∈ θ.rows, e.Support q) ∧
  (∀ a, p a → (Eff.rawBind θ (.mk (fun b => decide (b = a)) [])).Support q)
theorem SupportTransport.up {p q : Atom → Prop} {θ : SubstEnv} (h : SupportTransport p q θ) : SupportTransport p q θ.up
theorem Ty.rawBind_support (p q : Atom → Prop) (θ : SubstEnv) (a : Ty) : Ty.Support p a → SupportTransport p q θ → Ty.Support q (Ty.rawBind θ a)
theorem Ty.rawBindTys_support (p q : Atom → Prop) (θ : SubstEnv) (a : List Ty) : Ty.SupportList p a → SupportTransport p q θ → Ty.SupportList q (rawBindTys θ a)
theorem Eff.rawBind_support (p q : Atom → Prop) (θ : SubstEnv) (a : Eff) : Eff.Support p a → SupportTransport p q θ → Eff.Support q (Eff.rawBind θ a)
theorem Tel.rawBind_support (p q : Atom → Prop) (θ : SubstEnv) (a : Tel) : Tel.Support p a → SupportTransport p q θ → Tel.Support q (Tel.rawBind θ a)
theorem typeEnvAt_support (p q : Atom → Prop) (c : Nat) (ts : List Ty) (es : List Eff)
    (ht : ∀ a ∈ ts, a.Support q) (he : ∀ e ∈ es, e.Support q)
    (ha : ∀ a, p a → (Eff.rawBind (typeEnvAt c ts es) (.mk (fun b => decide (b = a)) [])).Support q) :
    SupportTransport p q (typeEnvAt c ts es)
theorem Ty.substAt_support (p q : Atom → Prop) (c : Nat) (ts : List Ty) (es : List Eff) (a : Ty) (h : Ty.Support p a) (ht : ∀ t ∈ ts, t.Support q) (he : ∀ e ∈ es, e.Support q) (ha : ∀ x, p x → (Eff.rawBind (typeEnvAt c ts es) (.mk (fun b => decide (b = x)) [])).Support q) : Ty.Support q (Ty.substAt c ts es a)
theorem Eff.substAt_support (p q : Atom → Prop) (c : Nat) (ts : List Ty) (es : List Eff) (a : Eff) (h : Eff.Support p a) (ht : ∀ t ∈ ts, t.Support q) (he : ∀ e ∈ es, e.Support q) (ha : ∀ x, p x → (Eff.rawBind (typeEnvAt c ts es) (.mk (fun b => decide (b = x)) [])).Support q) : Eff.Support q (Eff.substAt c ts es a)
theorem Eff.norm_fails_support {p : Atom → Prop} (e : Eff) (h : Ty.SupportList p e.fails) : Ty.SupportList p e.norm.fails
theorem Eff.support_of_sub {p : Atom → Prop} {a b : Eff} (hb : b.Support p) (h : Eff.Sub a b) : a.Support p
```

## 有限比較、関数の形、正規化

```lean
def finiteEncodeAtoms (s : List Atom) (f : Atom → Bool) : Benitoite.Release.Atom → Bool
theorem finiteEncodeAtoms_eq (s : List Atom) (f : Atom → Bool) (hf : ∀ a, f a = true → a ∈ s) : finiteEncodeAtoms s f = encodeAtoms f
def tyCompareWith (s : List Atom) : Ty → Ty → Ordering
theorem compareWith_eq_compare (s : List Atom) (a b : Ty) (ha : Ty.Support (· ∈ s) a) (hb : Ty.Support (· ∈ s) b) : tyCompareWith s a b = tyCompare a b
def tysCompareWith (s : List Atom) : List Ty → List Ty → Ordering
theorem tysCompareWith_eq_compare (s : List Atom) (a b : List Ty) (ha : Ty.SupportList (· ∈ s) a) (hb : Ty.SupportList (· ∈ s) b) : tysCompareWith s a b = Order.treesCompare Order.labelCompare (Ty.toTrees a) (Ty.toTrees b)
def effCompareWith (s : List Atom) : Eff → Eff → Ordering
theorem effCompareWith_eq_compare (s : List Atom) (a b : Eff) (ha : Eff.Support (· ∈ s) a) (hb : Eff.Support (· ∈ s) b) : effCompareWith s a b = Order.treeCompare Order.labelCompare (Eff.toTree a) (Eff.toTree b)
def telCompareWith (s : List Atom) : Tel → Tel → Ordering
theorem telCompareWith_eq_compare (s : List Atom) (a b : Tel) (ha : Tel.Support (· ∈ s) a) (hb : Tel.Support (· ∈ s) b) : telCompareWith s a b = Order.treeCompare Order.labelCompare (Tel.toTree a) (Tel.toTree b)
def Tel.fnViewWith? (s : List Atom) (t : Tel) : Option FnView
def Ty.foldFnWith (s : List Atom) (t : Tel) : Ty
theorem Tel.fnViewWith?_eq_some_iff (s : List Atom) (t : Tel) (f : FnView) (ht : t.Support (· ∈ s)) : Tel.fnViewWith? s t = some f ↔ f.toTel = t
theorem Tel.fnViewWith?_eq_fnView? (s : List Atom) (t : Tel) (ht : t.Support (· ∈ s)) : Tel.fnViewWith? s t = t.fnView?
def Ty.normWith (s : List Atom) : Ty → Ty
theorem Ty.normWith_eq_norm (s : List Atom) (a : Ty) (h : Ty.Support (· ∈ s) a) : Ty.normWith s a = Ty.norm a
def Ty.normTysWith (s : List Atom) : List Ty → List Ty
theorem Ty.normTysWith_eq_norm (s : List Atom) (a : List Ty) (h : Ty.SupportList (· ∈ s) a) : Ty.normTysWith s a = Ty.normTys a
def Eff.normWith (s : List Atom) : Eff → Eff
theorem Eff.normWith_eq_norm (s : List Atom) (a : Eff) (h : Eff.Support (· ∈ s) a) : Eff.normWith s a = Eff.norm a
def Tel.normWith (s : List Atom) : Tel → Tel
theorem Tel.normWith_eq_norm (s : List Atom) (a : Tel) (h : Tel.Support (· ∈ s) a) : Tel.normWith s a = Tel.norm a
theorem Eff.normWith_eq_norm_of_fails (s : List Atom) (e : Eff) (h : Ty.SupportList (· ∈ s) e.fails) : e.normWith s = e.norm
theorem Ty.normWith_support (s : List Atom) (a : Ty) (h : a.Support (· ∈ s)) : Ty.Support (· ∈ s) (a.normWith s)
theorem Ty.normWith_canonical (s : List Atom) (a : Ty) (h : a.Support (· ∈ s)) : (a.normWith s).Canonical
theorem Ty.normWith_idem (s : List Atom) (a : Ty) (h : a.Support (· ∈ s)) : (a.normWith s).normWith s = a.normWith s
theorem Ty.normWith_support_independent (s t : List Atom) (a : Ty) (hs : a.Support (· ∈ s)) (ht : a.Support (· ∈ t)) : a.normWith s = a.normWith t
theorem Eff.normWith_support (s : List Atom) (a : Eff) (h : a.Support (· ∈ s)) : Eff.Support (· ∈ s) (a.normWith s)
theorem Eff.normWith_canonical (s : List Atom) (a : Eff) (h : a.Support (· ∈ s)) : (a.normWith s).Canonical
theorem Eff.normWith_idem (s : List Atom) (a : Eff) (h : a.Support (· ∈ s)) : (a.normWith s).normWith s = a.normWith s
theorem Eff.normWith_support_independent (s t : List Atom) (a : Eff) (hs : a.Support (· ∈ s)) (ht : a.Support (· ∈ t)) : a.normWith s = a.normWith t
```

## 補助契約の決定

- rawShift の移植先の対象は現行の shiftTypes/shiftTypesList/shiftRowsTypes/shiftTelTypes とする。公開 shift は正規化後の支持を示す。
- 一般置換は p から q への SupportTransport を使う。typeEnvAt と substAt は型像・行像の支持に加え、p に属する単一原子の像の支持を明示する。行を置き換えた後も同じ原子が残るとは仮定しない。
- Pred と RangeExpr 内の値参照は原子の支持に数えない。Eff の最上位は候補列で filter し、Fail 内部へ再帰する。
- 比較の eq が構造等号を意味するのは両辺の支持が候補に入る場合に限る。型全域の DecidableEq は提供しない。
- 有限 fnView の候補は後続から一束縛ずつ `unshiftValue 1 0` で戻す。深さをまとめて戻す代わりの実装であり、任意の toTel の往復で確かめる。NamesWF と再構築を検査する。有限比較の候補はsをそのまま使い、既存の意味は一致定理にだけ現れる。
- normWith は子、Fail の整列、篩の平坦化、関数の畳込みの順で実行する。最上位の効果関数は変えないため、Eff の一致は Fail 内部の支持だけでも示す。

補助補題の追加は各単位で記録する。主定理・公理・提供範囲・書ける形・精密な外部状態の五境界は変更しない。

## 実装で追加した補助の完全署名

```lean
theorem Ty.support_renameValues_iff (p : Atom → Prop) (a : Ty) (ξ : Nat → Nat) : Ty.Support p (Ty.renameValues ξ a) ↔ Ty.Support p a
theorem Ty.supportList_renameValues_iff (p : Atom → Prop) (a : List Ty) (ξ : Nat → Nat) : Ty.SupportList p (renameValueTys ξ a) ↔ Ty.SupportList p a
theorem Eff.support_renameValues_iff (p : Atom → Prop) (a : Eff) (ξ : Nat → Nat) : Eff.Support p (Eff.renameValues ξ a) ↔ Eff.Support p a
theorem Tel.support_renameValues_iff (p : Atom → Prop) (a : Tel) (ξ : Nat → Nat) : Tel.Support p (Tel.renameValues ξ a) ↔ Tel.Support p a
theorem Ty.support_shiftV_iff (p : Atom → Prop) (a : Ty) (k c : Nat) : Ty.Support p (Ty.shiftV k c a) ↔ Ty.Support p a
theorem Eff.support_shiftV_iff (p : Atom → Prop) (a : Eff) (k c : Nat) : Eff.Support p (Eff.shiftV k c a) ↔ Eff.Support p a
theorem Ty.supportList_shiftV_iff (p : Atom → Prop) (a : List Ty) (k c : Nat) : Ty.SupportList p (shiftVTys k c a) ↔ Ty.SupportList p a
theorem Ty.support_toTel_iff (p : Atom → Prop) (ns : List String) (ps : List Ty) (r : Ty) (e : Eff) (hn : NamesWF ns ps) : (Ty.toTel ns ps r e).Support p ↔ Ty.SupportList p ps ∧ r.Support p ∧ e.Support p
theorem Ty.support_foldFn_iff (p : Atom → Prop) (t : Tel) : (Ty.foldFn t).Support p ↔ t.Support p
theorem Ty.support_core_iff (p : Atom → Prop) (a : Ty) : a.core.Support p ↔ a.Support p
theorem Ty.support_refineNorm_iff (p : Atom → Prop) (a : Ty) (q : Pred) : (a.refineNorm q).Support p ↔ a.Support p
theorem rawApply_support {p : Atom → Prop} (a : Ty) (as : List Ty) (h : a.Support p) (hs : Ty.SupportList p as) : (rawApply a as).Support p
theorem telCompareWith_eq_iff (s : List Atom) (t u : Tel) (ht : t.Support (· ∈ s)) (hu : u.Support (· ∈ s)) : telCompareWith s t u = .eq ↔ t = u
theorem Ty.foldFnWith_eq_foldFn (s : List Atom) (t : Tel) (ht : t.Support (· ∈ s)) : Ty.foldFnWith s t = Ty.foldFn t
theorem Ty.normTysWith_eq_map (s : List Atom) (ts : List Ty) : Ty.normTysWith s ts = ts.map (Ty.normWith s)
```

`NamesWF ns ps` の決定インスタンスは、長さの等号と String の列の Nodup だけを計算する。型の要素の等号を判定しない。非公開補助は、原子を持たない木の比較、原子の有限符号化の支持、fnParts の逆移動・支持・往復、再構築の健全性、支持上の sortUnique の比較の交換である。これらは提供する型規則を変えない。

有限比較の型列の一致先は、現行の木列比較 `Order.treesCompare` とする。初版の完全署名のこの欄に書いた `List.compareLex` を、現行ソースと同じ名前に訂正した。両者は同じ辞書式比較だが、提供する補題の右辺の関数名を一致させた。

完全署名は [signatures.lean](signatures.lean) が各宣言の型へそのまま照合する。暗黙の型引数を含めて Lean が型検査する。

## レビューで追加した支持補助の完全署名

```lean
theorem typeEnvAt_atom {p q : Atom → Prop} (c : Nat) (ts : List Ty) (es : List Eff)
    (he : ∀ e ∈ es, e.Support q) (hpq : ∀ x, p x → q x) (a : Atom) (ha : p a) :
    (Eff.rawBind (typeEnvAt c ts es) (.mk (fun b => decide (b = a)) [])).Support q
theorem typeEnvAt_support_of_imp {p q : Atom → Prop} (c : Nat) (ts : List Ty) (es : List Eff)
    (ht : ∀ t ∈ ts, t.Support q) (he : ∀ e ∈ es, e.Support q) (hpq : ∀ x, p x → q x) :
    SupportTransport p q (typeEnvAt c ts es)
theorem Ty.substAt_support_of_imp {p q : Atom → Prop} (c : Nat) (ts : List Ty) (es : List Eff)
    (a : Ty) (h : a.Support p) (ht : ∀ t ∈ ts, t.Support q) (he : ∀ e ∈ es, e.Support q)
    (hpq : ∀ x, p x → q x) : (a.substAt c ts es).Support q
theorem Eff.substAt_support_of_imp {p q : Atom → Prop} (c : Nat) (ts : List Ty) (es : List Eff)
    (a : Eff) (h : a.Support p) (ht : ∀ t ∈ ts, t.Support q) (he : ∀ e ∈ es, e.Support q)
    (hpq : ∀ x, p x → q x) : (Eff.substAt c ts es a).Support q
theorem Ty.substAt_support_same {p : Atom → Prop} (c : Nat) (ts : List Ty) (es : List Eff)
    (a : Ty) (h : a.Support p) (ht : ∀ t ∈ ts, t.Support p) (he : ∀ e ∈ es, e.Support p) :
    (a.substAt c ts es).Support p
theorem Eff.substAt_support_same {p : Atom → Prop} (c : Nat) (ts : List Ty) (es : List Eff)
    (a : Eff) (h : a.Support p) (ht : ∀ t ∈ ts, t.Support p) (he : ∀ e ∈ es, e.Support p) :
    (Eff.substAt c ts es a).Support p
```

レビュー後の決定: 比較四族の再帰引数を `termination_by structural a _ => a` で指定する。実行結果と一致の言明は保ち、rfl/decideによるカーネルの簡約を使えるようにする。fnViewWith?の比較候補はsだけを使い、viewSupportと二つの補助を削除した。collectAtoms sの和は候補不足を補わず、重複を増やすだけだったためである。これはdetailの予定の一文からの変更であり、支持下の一致は変えない。

typeEnvAtは範囲像が空なので、単一原子の条件はp→qと行の像の支持から導ける。一般のSubstEnvのための元のha付きAPIは維持し、呼出し側にはof_imp/sameを追加する。fnViewの支持前提なしの一般定理の追加はG07へ申し送る。現在の支持付きの言明を、本群で無条件の定理へ変えたとはしない。
