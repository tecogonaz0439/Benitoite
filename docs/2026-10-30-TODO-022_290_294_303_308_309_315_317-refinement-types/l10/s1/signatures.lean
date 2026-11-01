import Lean
import Benitoite
namespace Benitoite.Release.Refinement

-- Ty.Support
noncomputable def signature001 : ∀ (_p : Atom → Prop), Ty → Prop := @Ty.Support

-- Ty.SupportList
noncomputable def signature002 : ∀ (_p : Atom → Prop), List Ty → Prop := @Ty.SupportList

-- Eff.Support
noncomputable def signature003 : ∀ (_p : Atom → Prop), Eff → Prop := @Eff.Support

-- Tel.Support
noncomputable def signature004 : ∀ (_p : Atom → Prop), Tel → Prop := @Tel.Support

-- Ty.Finite
noncomputable def signature005 : ∀ (_a : Ty), Prop := @Ty.Finite

-- Eff.Finite
noncomputable def signature006 : ∀ (_a : Eff), Prop := @Eff.Finite

-- Ty.SupportList.iff
noncomputable def signature007 : ∀ {p : Atom → Prop} {ts : List Ty}, Ty.SupportList p ts ↔ ∀ t ∈ ts, t.Support p := @Ty.SupportList.iff

-- Eff.support_iff
noncomputable def signature008 : ∀ {p : Atom → Prop} (e : Eff), e.Support p ↔ (∀ a, e.test a = true → p a) ∧ Ty.SupportList p e.fails := @Eff.support_iff

-- Ty.support_mono
noncomputable def signature009 : ∀ {p q : Atom → Prop} (a : Ty) (_h : Ty.Support p a) (_hp : ∀ x, p x → q x), Ty.Support q a := @Ty.support_mono

-- Ty.collectAtoms
noncomputable def signature010 : ∀ (_s : List Atom), Ty → List Atom := @Ty.collectAtoms

-- Ty.collectAtoms_complete
noncomputable def signature011 : ∀ (s : List Atom) (a : Ty) (_h : Ty.Support (· ∈ s) a), Ty.Support (· ∈ Ty.collectAtoms s a) a := @Ty.collectAtoms_complete

-- Ty.collectAtoms_sound
noncomputable def signature012 : ∀ {p : Atom → Prop} (s : List Atom) (a : Ty) (_h : Ty.Support p a), ∀ x ∈ Ty.collectAtoms s a, p x := @Ty.collectAtoms_sound

-- Ty.collectAtoms_support_iff
noncomputable def signature013 : ∀ {s : List Atom} {a : Ty} (_hs : Ty.Support (· ∈ s) a) (p : Atom → Prop), Ty.Support p a ↔ ∀ x ∈ Ty.collectAtoms s a, p x := @Ty.collectAtoms_support_iff

-- Ty.norm_support
noncomputable def signature014 : ∀ {p : Atom → Prop} (a : Ty) (_h : Ty.Support p a), Ty.Support p (Ty.norm a) := @Ty.norm_support

-- Ty.support_of_norm
noncomputable def signature015 : ∀ {p : Atom → Prop} (a : Ty) (_h : Ty.Support p (Ty.norm a)), Ty.Support p a := @Ty.support_of_norm

-- Ty.supportList_mono
noncomputable def signature016 : ∀ {p q : Atom → Prop} (a : List Ty) (_h : Ty.SupportList p a) (_hp : ∀ x, p x → q x), Ty.SupportList q a := @Ty.supportList_mono

-- Ty.collectAtomsList
noncomputable def signature017 : ∀ (_s : List Atom), List Ty → List Atom := @Ty.collectAtomsList

-- Ty.collectAtomsList_complete
noncomputable def signature018 : ∀ (s : List Atom) (a : List Ty) (_h : Ty.SupportList (· ∈ s) a), Ty.SupportList (· ∈ Ty.collectAtomsList s a) a := @Ty.collectAtomsList_complete

-- Ty.collectAtomsList_sound
noncomputable def signature019 : ∀ {p : Atom → Prop} (s : List Atom) (a : List Ty) (_h : Ty.SupportList p a), ∀ x ∈ Ty.collectAtomsList s a, p x := @Ty.collectAtomsList_sound

-- Ty.collectAtomsList_support_iff
noncomputable def signature020 : ∀ {s : List Atom} {a : List Ty} (_hs : Ty.SupportList (· ∈ s) a) (p : Atom → Prop), Ty.SupportList p a ↔ ∀ x ∈ Ty.collectAtomsList s a, p x := @Ty.collectAtomsList_support_iff

-- Ty.normTys_support
noncomputable def signature021 : ∀ {p : Atom → Prop} (a : List Ty) (_h : Ty.SupportList p a), Ty.SupportList p (Ty.normTys a) := @Ty.normTys_support

-- Ty.supportList_of_norm
noncomputable def signature022 : ∀ {p : Atom → Prop} (a : List Ty) (_h : Ty.SupportList p (Ty.normTys a)), Ty.SupportList p a := @Ty.supportList_of_norm

-- Eff.support_mono
noncomputable def signature023 : ∀ {p q : Atom → Prop} (a : Eff) (_h : Eff.Support p a) (_hp : ∀ x, p x → q x), Eff.Support q a := @Eff.support_mono

-- Eff.collectAtoms
noncomputable def signature024 : ∀ (_s : List Atom), Eff → List Atom := @Eff.collectAtoms

-- Eff.collectAtoms_complete
noncomputable def signature025 : ∀ (s : List Atom) (a : Eff) (_h : Eff.Support (· ∈ s) a), Eff.Support (· ∈ Eff.collectAtoms s a) a := @Eff.collectAtoms_complete

-- Eff.collectAtoms_sound
noncomputable def signature026 : ∀ {p : Atom → Prop} (s : List Atom) (a : Eff) (_h : Eff.Support p a), ∀ x ∈ Eff.collectAtoms s a, p x := @Eff.collectAtoms_sound

-- Eff.collectAtoms_support_iff
noncomputable def signature027 : ∀ {s : List Atom} {a : Eff} (_hs : Eff.Support (· ∈ s) a) (p : Atom → Prop), Eff.Support p a ↔ ∀ x ∈ Eff.collectAtoms s a, p x := @Eff.collectAtoms_support_iff

-- Eff.norm_support
noncomputable def signature028 : ∀ {p : Atom → Prop} (a : Eff) (_h : Eff.Support p a), Eff.Support p (Eff.norm a) := @Eff.norm_support

-- Eff.support_of_norm
noncomputable def signature029 : ∀ {p : Atom → Prop} (a : Eff) (_h : Eff.Support p (Eff.norm a)), Eff.Support p a := @Eff.support_of_norm

-- Tel.support_mono
noncomputable def signature030 : ∀ {p q : Atom → Prop} (a : Tel) (_h : Tel.Support p a) (_hp : ∀ x, p x → q x), Tel.Support q a := @Tel.support_mono

-- Tel.collectAtoms
noncomputable def signature031 : ∀ (_s : List Atom), Tel → List Atom := @Tel.collectAtoms

-- Tel.collectAtoms_complete
noncomputable def signature032 : ∀ (s : List Atom) (a : Tel) (_h : Tel.Support (· ∈ s) a), Tel.Support (· ∈ Tel.collectAtoms s a) a := @Tel.collectAtoms_complete

-- Tel.collectAtoms_sound
noncomputable def signature033 : ∀ {p : Atom → Prop} (s : List Atom) (a : Tel) (_h : Tel.Support p a), ∀ x ∈ Tel.collectAtoms s a, p x := @Tel.collectAtoms_sound

-- Tel.collectAtoms_support_iff
noncomputable def signature034 : ∀ {s : List Atom} {a : Tel} (_hs : Tel.Support (· ∈ s) a) (p : Atom → Prop), Tel.Support p a ↔ ∀ x ∈ Tel.collectAtoms s a, p x := @Tel.collectAtoms_support_iff

-- Tel.norm_support
noncomputable def signature035 : ∀ {p : Atom → Prop} (a : Tel) (_h : Tel.Support p a), Tel.Support p (Tel.norm a) := @Tel.norm_support

-- Tel.support_of_norm
noncomputable def signature036 : ∀ {p : Atom → Prop} (a : Tel) (_h : Tel.Support p (Tel.norm a)), Tel.Support p a := @Tel.support_of_norm

-- Ty.rawShift_support
noncomputable def signature037 : ∀ {p : Atom → Prop} (k c : Nat) (a : Ty) (_h : Ty.Support p a), Ty.Support p (shiftTypes k c a) := @Ty.rawShift_support

-- Ty.rawShiftTys_support
noncomputable def signature038 : ∀ {p : Atom → Prop} (k c : Nat) (a : List Ty) (_h : Ty.SupportList p a), Ty.SupportList p (shiftTypesList k c a) := @Ty.rawShiftTys_support

-- Eff.rawShift_support
noncomputable def signature039 : ∀ {p : Atom → Prop} (k c : Nat) (a : Eff) (_h : Eff.Support p a), Eff.Support p (shiftRowsTypes k c a) := @Eff.rawShift_support

-- Tel.rawShift_support
noncomputable def signature040 : ∀ {p : Atom → Prop} (k c : Nat) (a : Tel) (_h : Tel.Support p a), Tel.Support p (shiftTelTypes k c a) := @Tel.rawShift_support

-- Ty.shift_support
noncomputable def signature041 : ∀ {p : Atom → Prop} (k c : Nat) (a : Ty) (_h : Ty.Support p a), Ty.Support p (Ty.shift k c a) := @Ty.shift_support

-- Eff.shift_support
noncomputable def signature042 : ∀ {p : Atom → Prop} (k c : Nat) (a : Eff) (_h : Eff.Support p a), Eff.Support p (Eff.shift k c a) := @Eff.shift_support

-- SupportTransport
noncomputable def signature043 : ∀ (_p _q : Atom → Prop) (_θ : SubstEnv), Prop := @SupportTransport

-- SupportTransport.up
noncomputable def signature044 : ∀ {p q : Atom → Prop} {θ : SubstEnv} (_h : SupportTransport p q θ), SupportTransport p q θ.up := @SupportTransport.up

-- Ty.rawBind_support
noncomputable def signature045 : ∀ (p q : Atom → Prop) (θ : SubstEnv) (a : Ty), Ty.Support p a → SupportTransport p q θ → Ty.Support q (Ty.rawBind θ a) := @Ty.rawBind_support

-- Ty.rawBindTys_support
noncomputable def signature046 : ∀ (p q : Atom → Prop) (θ : SubstEnv) (a : List Ty), Ty.SupportList p a → SupportTransport p q θ → Ty.SupportList q (rawBindTys θ a) := @Ty.rawBindTys_support

-- Eff.rawBind_support
noncomputable def signature047 : ∀ (p q : Atom → Prop) (θ : SubstEnv) (a : Eff), Eff.Support p a → SupportTransport p q θ → Eff.Support q (Eff.rawBind θ a) := @Eff.rawBind_support

-- Tel.rawBind_support
noncomputable def signature048 : ∀ (p q : Atom → Prop) (θ : SubstEnv) (a : Tel), Tel.Support p a → SupportTransport p q θ → Tel.Support q (Tel.rawBind θ a) := @Tel.rawBind_support

-- typeEnvAt_support
noncomputable def signature049 : ∀ (p q : Atom → Prop) (c : Nat) (ts : List Ty) (es : List Eff)
    (_ht : ∀ a ∈ ts, a.Support q) (_he : ∀ e ∈ es, e.Support q)
    (_ha : ∀ a, p a → (Eff.rawBind (typeEnvAt c ts es) (.mk (fun b => decide (b = a)) [])).Support q), SupportTransport p q (typeEnvAt c ts es) := @typeEnvAt_support

-- Ty.substAt_support
noncomputable def signature050 : ∀ (p q : Atom → Prop) (c : Nat) (ts : List Ty) (es : List Eff) (a : Ty) (_h : Ty.Support p a) (_ht : ∀ t ∈ ts, t.Support q) (_he : ∀ e ∈ es, e.Support q) (_ha : ∀ x, p x → (Eff.rawBind (typeEnvAt c ts es) (.mk (fun b => decide (b = x)) [])).Support q), Ty.Support q (Ty.substAt c ts es a) := @Ty.substAt_support

-- Eff.substAt_support
noncomputable def signature051 : ∀ (p q : Atom → Prop) (c : Nat) (ts : List Ty) (es : List Eff) (a : Eff) (_h : Eff.Support p a) (_ht : ∀ t ∈ ts, t.Support q) (_he : ∀ e ∈ es, e.Support q) (_ha : ∀ x, p x → (Eff.rawBind (typeEnvAt c ts es) (.mk (fun b => decide (b = x)) [])).Support q), Eff.Support q (Eff.substAt c ts es a) := @Eff.substAt_support

-- Eff.norm_fails_support
noncomputable def signature052 : ∀ {p : Atom → Prop} (e : Eff) (_h : Ty.SupportList p e.fails), Ty.SupportList p e.norm.fails := @Eff.norm_fails_support

-- Eff.support_of_sub
noncomputable def signature053 : ∀ {p : Atom → Prop} {a b : Eff} (_hb : b.Support p) (_h : Eff.Sub a b), a.Support p := @Eff.support_of_sub

-- finiteEncodeAtoms
noncomputable def signature054 : ∀ (_s : List Atom) (_f : Atom → Bool), Benitoite.Release.Atom → Bool := @finiteEncodeAtoms

-- finiteEncodeAtoms_eq
noncomputable def signature055 : ∀ (s : List Atom) (f : Atom → Bool) (_hf : ∀ a, f a = true → a ∈ s), finiteEncodeAtoms s f = encodeAtoms f := @finiteEncodeAtoms_eq

-- tyCompareWith
noncomputable def signature056 : ∀ (_s : List Atom), Ty → Ty → Ordering := @tyCompareWith

-- compareWith_eq_compare
noncomputable def signature057 : ∀ (s : List Atom) (a b : Ty) (_ha : Ty.Support (· ∈ s) a) (_hb : Ty.Support (· ∈ s) b), tyCompareWith s a b = tyCompare a b := @compareWith_eq_compare

-- tysCompareWith
noncomputable def signature058 : ∀ (_s : List Atom), List Ty → List Ty → Ordering := @tysCompareWith

-- tysCompareWith_eq_compare
noncomputable def signature059 : ∀ (s : List Atom) (a b : List Ty) (_ha : Ty.SupportList (· ∈ s) a) (_hb : Ty.SupportList (· ∈ s) b), tysCompareWith s a b = Order.treesCompare Order.labelCompare (Ty.toTrees a) (Ty.toTrees b) := @tysCompareWith_eq_compare

-- effCompareWith
noncomputable def signature060 : ∀ (_s : List Atom), Eff → Eff → Ordering := @effCompareWith

-- effCompareWith_eq_compare
noncomputable def signature061 : ∀ (s : List Atom) (a b : Eff) (_ha : Eff.Support (· ∈ s) a) (_hb : Eff.Support (· ∈ s) b), effCompareWith s a b = Order.treeCompare Order.labelCompare (Eff.toTree a) (Eff.toTree b) := @effCompareWith_eq_compare

-- telCompareWith
noncomputable def signature062 : ∀ (_s : List Atom), Tel → Tel → Ordering := @telCompareWith

-- telCompareWith_eq_compare
noncomputable def signature063 : ∀ (s : List Atom) (a b : Tel) (_ha : Tel.Support (· ∈ s) a) (_hb : Tel.Support (· ∈ s) b), telCompareWith s a b = Order.treeCompare Order.labelCompare (Tel.toTree a) (Tel.toTree b) := @telCompareWith_eq_compare

-- Tel.fnViewWith?
noncomputable def signature064 : ∀ (_s : List Atom) (_t : Tel), Option FnView := @Tel.fnViewWith?

-- Ty.foldFnWith
noncomputable def signature065 : ∀ (_s : List Atom) (_t : Tel), Ty := @Ty.foldFnWith

-- Tel.fnViewWith?_eq_some_iff
noncomputable def signature066 : ∀ (s : List Atom) (t : Tel) (f : FnView) (_ht : t.Support (· ∈ s)), Tel.fnViewWith? s t = some f ↔ f.toTel = t := @Tel.fnViewWith?_eq_some_iff

-- Tel.fnViewWith?_eq_fnView?
noncomputable def signature067 : ∀ (s : List Atom) (t : Tel) (_ht : t.Support (· ∈ s)), Tel.fnViewWith? s t = t.fnView? := @Tel.fnViewWith?_eq_fnView?

-- Ty.normWith
noncomputable def signature068 : ∀ (_s : List Atom), Ty → Ty := @Ty.normWith

-- Ty.normWith_eq_norm
noncomputable def signature069 : ∀ (s : List Atom) (a : Ty) (_h : Ty.Support (· ∈ s) a), Ty.normWith s a = Ty.norm a := @Ty.normWith_eq_norm

-- Ty.normTysWith
noncomputable def signature070 : ∀ (_s : List Atom), List Ty → List Ty := @Ty.normTysWith

-- Ty.normTysWith_eq_norm
noncomputable def signature071 : ∀ (s : List Atom) (a : List Ty) (_h : Ty.SupportList (· ∈ s) a), Ty.normTysWith s a = Ty.normTys a := @Ty.normTysWith_eq_norm

-- Eff.normWith
noncomputable def signature072 : ∀ (_s : List Atom), Eff → Eff := @Eff.normWith

-- Eff.normWith_eq_norm
noncomputable def signature073 : ∀ (s : List Atom) (a : Eff) (_h : Eff.Support (· ∈ s) a), Eff.normWith s a = Eff.norm a := @Eff.normWith_eq_norm

-- Tel.normWith
noncomputable def signature074 : ∀ (_s : List Atom), Tel → Tel := @Tel.normWith

-- Tel.normWith_eq_norm
noncomputable def signature075 : ∀ (s : List Atom) (a : Tel) (_h : Tel.Support (· ∈ s) a), Tel.normWith s a = Tel.norm a := @Tel.normWith_eq_norm

-- Eff.normWith_eq_norm_of_fails
noncomputable def signature076 : ∀ (s : List Atom) (e : Eff) (_h : Ty.SupportList (· ∈ s) e.fails), e.normWith s = e.norm := @Eff.normWith_eq_norm_of_fails

-- Ty.normWith_support
noncomputable def signature077 : ∀ (s : List Atom) (a : Ty) (_h : a.Support (· ∈ s)), Ty.Support (· ∈ s) (a.normWith s) := @Ty.normWith_support

-- Ty.normWith_canonical
noncomputable def signature078 : ∀ (s : List Atom) (a : Ty) (_h : a.Support (· ∈ s)), (a.normWith s).Canonical := @Ty.normWith_canonical

-- Ty.normWith_idem
noncomputable def signature079 : ∀ (s : List Atom) (a : Ty) (_h : a.Support (· ∈ s)), (a.normWith s).normWith s = a.normWith s := @Ty.normWith_idem

-- Ty.normWith_support_independent
noncomputable def signature080 : ∀ (s t : List Atom) (a : Ty) (_hs : a.Support (· ∈ s)) (_ht : a.Support (· ∈ t)), a.normWith s = a.normWith t := @Ty.normWith_support_independent

-- Eff.normWith_support
noncomputable def signature081 : ∀ (s : List Atom) (a : Eff) (_h : a.Support (· ∈ s)), Eff.Support (· ∈ s) (a.normWith s) := @Eff.normWith_support

-- Eff.normWith_canonical
noncomputable def signature082 : ∀ (s : List Atom) (a : Eff) (_h : a.Support (· ∈ s)), (a.normWith s).Canonical := @Eff.normWith_canonical

-- Eff.normWith_idem
noncomputable def signature083 : ∀ (s : List Atom) (a : Eff) (_h : a.Support (· ∈ s)), (a.normWith s).normWith s = a.normWith s := @Eff.normWith_idem

-- Eff.normWith_support_independent
noncomputable def signature084 : ∀ (s t : List Atom) (a : Eff) (_hs : a.Support (· ∈ s)) (_ht : a.Support (· ∈ t)), a.normWith s = a.normWith t := @Eff.normWith_support_independent

-- Ty.support_renameValues_iff
noncomputable def signature085 : ∀ (p : Atom → Prop) (a : Ty) (ξ : Nat → Nat), Ty.Support p (Ty.renameValues ξ a) ↔ Ty.Support p a := @Ty.support_renameValues_iff

-- Ty.supportList_renameValues_iff
noncomputable def signature086 : ∀ (p : Atom → Prop) (a : List Ty) (ξ : Nat → Nat), Ty.SupportList p (renameValueTys ξ a) ↔ Ty.SupportList p a := @Ty.supportList_renameValues_iff

-- Eff.support_renameValues_iff
noncomputable def signature087 : ∀ (p : Atom → Prop) (a : Eff) (ξ : Nat → Nat), Eff.Support p (Eff.renameValues ξ a) ↔ Eff.Support p a := @Eff.support_renameValues_iff

-- Tel.support_renameValues_iff
noncomputable def signature088 : ∀ (p : Atom → Prop) (a : Tel) (ξ : Nat → Nat), Tel.Support p (Tel.renameValues ξ a) ↔ Tel.Support p a := @Tel.support_renameValues_iff

-- Ty.support_shiftV_iff
noncomputable def signature089 : ∀ (p : Atom → Prop) (a : Ty) (k c : Nat), Ty.Support p (Ty.shiftV k c a) ↔ Ty.Support p a := @Ty.support_shiftV_iff

-- Eff.support_shiftV_iff
noncomputable def signature090 : ∀ (p : Atom → Prop) (a : Eff) (k c : Nat), Eff.Support p (Eff.shiftV k c a) ↔ Eff.Support p a := @Eff.support_shiftV_iff

-- Ty.supportList_shiftV_iff
noncomputable def signature091 : ∀ (p : Atom → Prop) (a : List Ty) (k c : Nat), Ty.SupportList p (shiftVTys k c a) ↔ Ty.SupportList p a := @Ty.supportList_shiftV_iff

-- Ty.support_toTel_iff
noncomputable def signature092 : ∀ (p : Atom → Prop) (ns : List String) (ps : List Ty) (r : Ty) (e : Eff) (_hn : NamesWF ns ps), (Ty.toTel ns ps r e).Support p ↔ Ty.SupportList p ps ∧ r.Support p ∧ e.Support p := @Ty.support_toTel_iff

-- Ty.support_foldFn_iff
noncomputable def signature093 : ∀ (p : Atom → Prop) (t : Tel), (Ty.foldFn t).Support p ↔ t.Support p := @Ty.support_foldFn_iff

-- Ty.support_core_iff
noncomputable def signature094 : ∀ (p : Atom → Prop) (a : Ty), a.core.Support p ↔ a.Support p := @Ty.support_core_iff

-- Ty.support_refineNorm_iff
noncomputable def signature095 : ∀ (p : Atom → Prop) (a : Ty) (q : Pred), (a.refineNorm q).Support p ↔ a.Support p := @Ty.support_refineNorm_iff

-- rawApply_support
noncomputable def signature096 : ∀ {p : Atom → Prop} (a : Ty) (as : List Ty) (_h : a.Support p) (_hs : Ty.SupportList p as), (rawApply a as).Support p := @rawApply_support

-- telCompareWith_eq_iff
noncomputable def signature097 : ∀ (s : List Atom) (t u : Tel) (_ht : t.Support (· ∈ s)) (_hu : u.Support (· ∈ s)), telCompareWith s t u = .eq ↔ t = u := @telCompareWith_eq_iff

-- Ty.foldFnWith_eq_foldFn
noncomputable def signature098 : ∀ (s : List Atom) (t : Tel) (_ht : t.Support (· ∈ s)), Ty.foldFnWith s t = Ty.foldFn t := @Ty.foldFnWith_eq_foldFn

-- Ty.normTysWith_eq_map
noncomputable def signature099 : ∀ (s : List Atom) (ts : List Ty), Ty.normTysWith s ts = ts.map (Ty.normWith s) := @Ty.normTysWith_eq_map

-- typeEnvAt_atom
noncomputable def signature100 : ∀ {p q : Atom → Prop} (c : Nat) (ts : List Ty) (es : List Eff)
    (_he : ∀ e ∈ es, e.Support q) (_hpq : ∀ x, p x → q x) (a : Atom) (_ha : p a), (Eff.rawBind (typeEnvAt c ts es) (.mk (fun b => decide (b = a)) [])).Support q := @typeEnvAt_atom

-- typeEnvAt_support_of_imp
noncomputable def signature101 : ∀ {p q : Atom → Prop} (c : Nat) (ts : List Ty) (es : List Eff)
    (_ht : ∀ t ∈ ts, t.Support q) (_he : ∀ e ∈ es, e.Support q) (_hpq : ∀ x, p x → q x), SupportTransport p q (typeEnvAt c ts es) := @typeEnvAt_support_of_imp

-- Ty.substAt_support_of_imp
noncomputable def signature102 : ∀ {p q : Atom → Prop} (c : Nat) (ts : List Ty) (es : List Eff)
    (a : Ty) (_h : a.Support p) (_ht : ∀ t ∈ ts, t.Support q) (_he : ∀ e ∈ es, e.Support q)
    (_hpq : ∀ x, p x → q x), (a.substAt c ts es).Support q := @Ty.substAt_support_of_imp

-- Eff.substAt_support_of_imp
noncomputable def signature103 : ∀ {p q : Atom → Prop} (c : Nat) (ts : List Ty) (es : List Eff)
    (a : Eff) (_h : a.Support p) (_ht : ∀ t ∈ ts, t.Support q) (_he : ∀ e ∈ es, e.Support q)
    (_hpq : ∀ x, p x → q x), (Eff.substAt c ts es a).Support q := @Eff.substAt_support_of_imp

-- Ty.substAt_support_same
noncomputable def signature104 : ∀ {p : Atom → Prop} (c : Nat) (ts : List Ty) (es : List Eff)
    (a : Ty) (_h : a.Support p) (_ht : ∀ t ∈ ts, t.Support p) (_he : ∀ e ∈ es, e.Support p), (a.substAt c ts es).Support p := @Ty.substAt_support_same

-- Eff.substAt_support_same
noncomputable def signature105 : ∀ {p : Atom → Prop} (c : Nat) (ts : List Ty) (es : List Eff)
    (a : Eff) (_h : a.Support p) (_ht : ∀ t ∈ ts, t.Support p) (_he : ∀ e ∈ es, e.Support p), (Eff.substAt c ts es a).Support p := @Eff.substAt_support_same

end Benitoite.Release.Refinement

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := (env.constants.toList.filterMap fun (name, _) =>
    if (env.getModuleIdxFor? name).isNone then some name else none).mergeSort
      (fun a b => a.toString < b.toString)
  logInfo m!"LOCAL_CONSTANTS {names.length}"
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
