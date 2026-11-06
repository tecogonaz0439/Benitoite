import Benitoite.Release.Refinement.Surface.CheckGuide

/-! 有限の原子の一覧から、検査する案内に現れる型と効果を構成する。 -/
namespace Benitoite.Release.Refinement.Surface.CheckFinite
open Check CheckArguments CheckSubtyping

mutual
  def ty (s : List Atom) : Ty → Ty
    | .base b => .base b
    | .opaque o r => .opaque o r
    | .data d ts => .data d (types s ts)
    | .list a => .list (ty s a)
    | .fn ns ps a e => .fn ns (types s ps) (ty s a) (eff s e)
    | .tvar i => .tvar i
    | .reference a => .reference (ty s a)
    | .lazy a => .lazy (ty s a)
    | .cont a b e => .cont (ty s a) (ty s b) (eff s e)
    | .map a b => .map (ty s a) (ty s b)
    | .set a => .set (ty s a)
    | .bytes => .bytes
    | .dict c a => .dict c (ty s a)
    | .tapp i ts => .tapp i (types s ts)
    | .ctor c => .ctor c
    | .refined a p => .refined (ty s a) p
    | .dependentFn t => .dependentFn (tel s t)
    | .external i ts => .external i (types s ts)
    | .scoped o k i => .scoped o k i
    | .pathBases => .pathBases
    | .scopePattern k => .scopePattern k
  def tel (s : List Atom) : Tel → Tel
    | .done a e => .done (ty s a) (eff s e)
    | .param n a t => .param n (ty s a) (tel s t)
  def types (s : List Atom) : List Ty → List Ty
    | [] => []
    | a :: as => ty s a :: types s as
  def eff (s : List Atom) : Eff → Eff
    | .mk atoms fs => .mk (fun a => atoms a && decide (a ∈ s)) (types s fs)
end

mutual
  theorem ty_support (s : List Atom) (a : Ty) : (ty s a).Support (· ∈ s) := by
    cases a <;> simp only [ty, Ty.Support]
    all_goals try trivial
    all_goals try exact ty_support s _
    all_goals try exact types_support s _
    all_goals try exact tel_support s _
    case fn => exact ⟨types_support s _, ty_support s _, eff_support s _⟩
    case cont => exact ⟨ty_support s _, ty_support s _, eff_support s _⟩
    case map => exact ⟨ty_support s _, ty_support s _⟩
  theorem tel_support (s : List Atom) (t : Tel) : (tel s t).Support (· ∈ s) := by
    cases t with
    | done => exact ⟨ty_support s _, eff_support s _⟩
    | param => exact ⟨ty_support s _, tel_support s _⟩
  theorem types_support (s : List Atom) (as : List Ty) : Ty.SupportList (· ∈ s) (types s as) := by
    cases as with
    | nil => trivial
    | cons => exact ⟨ty_support s _, types_support s _⟩
  theorem eff_support (s : List Atom) (e : Eff) : (eff s e).Support (· ∈ s) := by
    cases e with
    | mk atoms fs =>
      refine ⟨?_, types_support s fs⟩
      intro a ha
      exact of_decide_eq_true (Bool.and_eq_true_iff.mp ha).2
end

mutual
  /-- 支持を満たす型は、そのままの型へ写る。 -/
  theorem ty_eq (s : List Atom) (a : Ty) (h : a.Support (· ∈ s)) : ty s a = a := by
    cases a <;> simp only [ty, Ty.Support] at h ⊢
    all_goals try rfl
    case data | tapp | external => rw [types_eq s _ h]
    case list | reference | lazy | set | dict | refined => rw [ty_eq s _ h]
    case dependentFn => rw [tel_eq s _ h]
    case fn => rw [types_eq s _ h.1, ty_eq s _ h.2.1, eff_eq s _ h.2.2]
    case cont => rw [ty_eq s _ h.1, ty_eq s _ h.2.1, eff_eq s _ h.2.2]
    case map => rw [ty_eq s _ h.1, ty_eq s _ h.2]
  theorem tel_eq (s : List Atom) (t : Tel) (h : t.Support (· ∈ s)) : tel s t = t := by
    cases t with
    | done => simp only [tel, ty_eq s _ h.1, eff_eq s _ h.2]
    | param => simp only [tel, ty_eq s _ h.1, tel_eq s _ h.2]
  theorem types_eq (s : List Atom) (as : List Ty) (h : Ty.SupportList (· ∈ s) as) : types s as = as := by
    cases as with
    | nil => rfl
    | cons => simp only [types, ty_eq s _ h.1, types_eq s _ h.2]
  theorem eff_eq (s : List Atom) (e : Eff) (h : e.Support (· ∈ s)) : eff s e = e := by
    cases e with
    | mk atoms fs =>
      have ha : (fun a => atoms a && decide (a ∈ s)) = atoms := by
        funext a
        cases hat : atoms a with
        | false => rfl
        | true => simp only [Bool.true_and, decide_eq_true_eq]; exact h.1 a hat
      simp only [eff, ha, types_eq s _ h.2]
end

mutual
  def le (s : List Atom) : LeCertificate → LeCertificate
    | .refl a => .refl (ty s a)
    | .convert a b => .convert (ty s a) (ty s b)
    | .trans a b => .trans (le s a) (le s b)
    | .fnEffect ns ps a e g => .fnEffect ns (types s ps) (ty s a) (eff s e) (eff s g)
    | .list a => .list (le s a)
    | .lazy a => .lazy (le s a)
    | .mapValue k a => .mapValue (ty s k) (le s a)
    | .forget a p => .forget (ty s a) p
    | .introduce a p c => .introduce (ty s a) p c
    | .refine a p q c => .refine (le s a) p q c
    | .dependentFn t => .dependentFn (closure s t)
    | .scoped o k a b => .scoped o k a b
    | .scopedForget o k a => .scopedForget o k a
    | .data d cs => .data d (arguments s cs)
  def telescope (s : List Atom) : TelCertificate → TelCertificate
    | .done a e g => .done (le s a) (eff s e) (eff s g)
    | .param n a t => .param n (le s a) (telescope s t)
  def closure (s : List Atom) : TelClosureCertificate → TelClosureCertificate
    | .refl t => .refl (tel s t)
    | .tail c t => .tail (closure s c) (telescope s t)
  def arguments (s : List Atom) : TypeArgsCertificate → TypeArgsCertificate
    | .nil => .nil
    | .covariant a cs => .covariant (le s a) (arguments s cs)
    | .contravariant a cs => .contravariant (le s a) (arguments s cs)
    | .invariant a b cs => .invariant (ty s a) (ty s b) (arguments s cs)
end

private theorem telTarget {s c} (h : TelCertificate.Supported s c) : c.target.Support (· ∈ s) := by
  cases c <;> exact h.2.1
private theorem closureSource {s c} (h : TelClosureCertificate.Supported s c) : c.source.Support (· ∈ s) := by
  cases c <;> exact h.1
private theorem argsSource {s c} (h : TypeArgsCertificate.Supported s c) : Ty.SupportList (· ∈ s) c.source := by
  cases c <;> exact h.1
private theorem argsTarget {s c} (h : TypeArgsCertificate.Supported s c) : Ty.SupportList (· ∈ s) c.target := by
  cases c <;> exact h.2.1

mutual
  theorem le_support (s : List Atom) (c : LeCertificate) : (le s c).Supported s := by
    cases c <;> simp only [le, LeCertificate.Supported, LeCertificate.source, LeCertificate.target,
      Ty.Support]
    all_goals first | exact ⟨ty_support s _, ty_support s _, trivial⟩ | skip
    case trans a b => exact ⟨(LeCertificate.source_supported (le_support s a)), (LeCertificate.target_supported (le_support s b)), le_support s a, le_support s b⟩
    case fnEffect => exact ⟨⟨types_support s _, ty_support s _, eff_support s _⟩,
      ⟨types_support s _, ty_support s _, eff_support s _⟩, trivial⟩
    case list a | lazy a => exact ⟨(LeCertificate.source_supported (le_support s a)), (LeCertificate.target_supported (le_support s a)), le_support s a⟩
    case mapValue k a => exact ⟨⟨ty_support s k, (LeCertificate.source_supported (le_support s a))⟩,
      ⟨ty_support s k, (LeCertificate.target_supported (le_support s a))⟩, le_support s a⟩
    case refine c p q proof => exact ⟨LeCertificate.source_supported (le_support s c), LeCertificate.target_supported (le_support s c), le_support s c⟩
    case dependentFn t => exact ⟨(closureSource (closure_support s t)), (TelClosureCertificate.target_supported (closure_support s t)), closure_support s t⟩
    case «scoped» | scopedForget => trivial
    case data d cs => exact ⟨(argsSource (arguments_support s cs)), (argsTarget (arguments_support s cs)), arguments_support s cs⟩
  theorem telescope_support (s : List Atom) (c : TelCertificate) : (telescope s c).Supported s := by
    cases c with
    | done a e g => exact ⟨⟨(LeCertificate.source_supported (le_support s a)), eff_support s e⟩,
        ⟨(LeCertificate.target_supported (le_support s a)), eff_support s g⟩, le_support s a⟩
    | param n a t => exact ⟨⟨(LeCertificate.target_supported (le_support s a)), (TelCertificate.source_supported (telescope_support s t))⟩,
        ⟨(LeCertificate.source_supported (le_support s a)), (telTarget (telescope_support s t))⟩, le_support s a, telescope_support s t⟩
  theorem closure_support (s : List Atom) (c : TelClosureCertificate) : (closure s c).Supported s := by
    cases c with
    | refl t => exact ⟨tel_support s t, tel_support s t, trivial⟩
    | tail c t =>
        change (closure s c).source.Support (· ∈ s) ∧ (telescope s t).target.Support (· ∈ s) ∧ _
        exact ⟨(closureSource (closure_support s c)), (telTarget (telescope_support s t)),
        closure_support s c, telescope_support s t⟩
  theorem arguments_support (s : List Atom) (c : TypeArgsCertificate) : (arguments s c).Supported s := by
    cases c with
    | nil => trivial
    | covariant a cs => exact ⟨⟨(LeCertificate.source_supported (le_support s a)), (argsSource (arguments_support s cs))⟩,
        ⟨(LeCertificate.target_supported (le_support s a)), (argsTarget (arguments_support s cs))⟩, le_support s a, arguments_support s cs⟩
    | contravariant a cs => exact ⟨⟨(LeCertificate.target_supported (le_support s a)), (argsSource (arguments_support s cs))⟩,
        ⟨(LeCertificate.source_supported (le_support s a)), (argsTarget (arguments_support s cs))⟩, le_support s a, arguments_support s cs⟩
    | invariant a b cs => exact ⟨⟨ty_support s a, (argsSource (arguments_support s cs))⟩,
        ⟨ty_support s b, (argsTarget (arguments_support s cs))⟩, arguments_support s cs⟩
end

mutual
  def dictionary (s : List Atom) : DictEv → DictEv
    | .local i => .local i
    | .clause a b c => .clause a b c
    | .impl i ts ds => .impl i (types s ts) (dictionaries s ds)
    | .super d c => .super (dictionary s d) c
  def dictionaries (s : List Atom) : List DictEv → List DictEv
    | [] => []
    | d :: ds => dictionary s d :: dictionaries s ds
end

mutual
  theorem dictionary_support (s : List Atom) (d : DictEv) : DictSupport s (dictionary s d) := by
    cases d with
    | «local» | clause => trivial
    | impl i ts ds => exact ⟨types_support s ts, dictionaries_support s ds⟩
    | super d => exact dictionary_support s d
  theorem dictionaries_support (s : List Atom) (ds : List DictEv) : DictsSupport s (dictionaries s ds) := by
    cases ds with
    | nil => trivial
    | cons d ds => exact ⟨dictionary_support s d, dictionaries_support s ds⟩
end

mutual
  def dictionaryGuide (s : List Atom) : DictGuide → DictGuide
    | .local => .local
    | .clause => .clause
    | .impl gs => .impl (dictionaryGuides s gs)
    | .super c a g => .super c (ty s a) (dictionaryGuide s g)
  def dictionaryGuides (s : List Atom) : List DictGuide → List DictGuide
    | [] => []
    | g :: gs => dictionaryGuide s g :: dictionaryGuides s gs
end

mutual
  theorem dictionaryGuide_support (s : List Atom) (g : DictGuide) : (dictionaryGuide s g).Support s := by
    cases g with
    | «local» | clause => trivial
    | impl gs => exact dictionaryGuides_support s gs
    | super c a g => exact ⟨ty_support s a, dictionaryGuide_support s g⟩
  theorem dictionaryGuides_support (s : List Atom) (gs : List DictGuide) : DictGuidesSupport s (dictionaryGuides s gs) := by
    cases gs with
    | nil => trivial
    | cons g gs => exact ⟨dictionaryGuide_support s g, dictionaryGuides_support s gs⟩
end

mutual
  def argument (s : List Atom) : ArgGuide → ArgGuide
    | .var => .var
    | .const => .const
    | .dictionary d a g => .dictionary (dictionary s d) (ty s a) (dictionaryGuide s g)
    | .list gs => .list (elements s gs)
    | .refine a p sort proof g => .refine (ty s a) p sort proof (argument s g)
  def element (s : List Atom) : ElemGuide → ElemGuide
    | .mk a g c => .mk (ty s a) (argument s g) (le s c)
  def elements (s : List Atom) : List ElemGuide → List ElemGuide
    | [] => []
    | g :: gs => element s g :: elements s gs
end

mutual
  theorem argument_support (s : List Atom) (g : ArgGuide) : (argument s g).Support s := by
    cases g with
    | var | const => trivial
    | dictionary d a g => exact ⟨dictionary_support s d, ty_support s a, dictionaryGuide_support s g⟩
    | list gs => exact elements_support s gs
    | refine a p sort proof g => exact ⟨ty_support s a, argument_support s g⟩
  theorem element_support (s : List Atom) (g : ElemGuide) : (element s g).Support s := by
    cases g with
    | mk a g c => exact ⟨ty_support s a, argument_support s g, le_support s c⟩
  theorem elements_support (s : List Atom) (gs : List ElemGuide) : ElemGuidesSupport s (elements s gs) := by
    cases gs with
    | nil => trivial
    | cons g gs => exact ⟨element_support s g, elements_support s gs⟩
end

def head (s : List Atom) : HeadGuide → HeadGuide
  | .plain => .plain
  | .method owner a g => .method owner (ty s a) (dictionaryGuide s g)

theorem head_support (s : List Atom) (g : HeadGuide) : (head s g).Support s := by
  cases g with
  | plain => trivial
  | method owner a g => exact ⟨ty_support s a, dictionaryGuide_support s g⟩

def hints (s : List Atom) (h : Hints) : Hints :=
  { h with
    types := types s h.types
    typeLists := h.typeLists.map (types s)
    effects := h.effects.map (eff s)
    signatures := h.signatures.map (tel s)
    subtypes := h.subtypes.map (le s)
    arguments := h.arguments.map (elements s)
    heads := h.heads.map (head s) }

theorem hints_support (s : List Atom) (h : Hints) : (hints s h).Support s := by
  refine ⟨types_support s h.types, ?_, ?_, ?_, ?_, ?_, ?_⟩
  all_goals
    intro x hx
    obtain ⟨y, _, rfl⟩ := List.mem_map.mp hx
    first | exact types_support s y | exact eff_support s y | exact tel_support s y
          | exact le_support s y | exact elements_support s y | exact head_support s y

mutual
  def guide (s : List Atom) : Guide → Guide
    | .unknown => .unknown
    | .failure error => .failure error
    | .node r h gs => .node r (hints s h) (guides s gs)
  def guides (s : List Atom) : List Guide → List Guide
    | [] => []
    | g :: gs => guide s g :: guides s gs
end

mutual
  theorem guide_support (s : List Atom) (g : Guide) : (guide s g).Support s := by
    cases g with
    | unknown => trivial
    | failure _ => trivial
    | node r h gs => exact ⟨hints_support s h, guides_support s gs⟩
  theorem guides_support (s : List Atom) (gs : List Guide) : GuidesSupport s (guides s gs) := by
    cases gs with
    | nil => trivial
    | cons g gs => exact ⟨guide_support s g, guides_support s gs⟩
end


mutual
  private theorem le_eq (s : List Atom) (c : LeCertificate) (h : c.Supported s) : le s c = c := by
    cases c with
    | refl a => simp only [le, ty_eq s a h.1]
    | convert a b => simp only [le, ty_eq s a h.1, ty_eq s b h.2.1]
    | trans a b => simp only [le, le_eq s a h.2.2.1, le_eq s b h.2.2.2]
    | fnEffect ns ps a e f => simp only [le, types_eq s ps h.1.1,
        ty_eq s a h.1.2.1, eff_eq s e h.1.2.2, eff_eq s f h.2.1.2.2]
    | list a | lazy a => simp only [le, le_eq s a h.2.2]
    | mapValue k a => simp only [le, ty_eq s k h.1.1, le_eq s a h.2.2]
    | forget a p | introduce a p _ => simp only [le, ty_eq s a h.1]
    | refine a p q proof => simp only [le, le_eq s a h.2.2]
    | dependentFn c => simp only [le, closure_eq s c h.2.2]
    | «scoped» | scopedForget => rfl
    | data d cs => simp only [le, arguments_eq s cs h.2.2]
  private theorem telescope_eq (s : List Atom) (c : TelCertificate) (h : c.Supported s) : telescope s c = c := by
    cases c with
    | done a e f => simp only [telescope, le_eq s a h.2.2, eff_eq s e h.1.2, eff_eq s f h.2.1.2]
    | param n a t => simp only [telescope, le_eq s a h.2.2.1, telescope_eq s t h.2.2.2]
  private theorem closure_eq (s : List Atom) (c : TelClosureCertificate) (h : c.Supported s) : closure s c = c := by
    cases c with
    | refl t => simp only [closure, tel_eq s t h.1]
    | tail c t => simp only [closure, closure_eq s c h.2.2.1, telescope_eq s t h.2.2.2]
  private theorem arguments_eq (s : List Atom) (c : TypeArgsCertificate) (h : c.Supported s) : arguments s c = c := by
    cases c with
    | nil => rfl
    | covariant a cs | contravariant a cs =>
        simp only [arguments, le_eq s a h.2.2.1, arguments_eq s cs h.2.2.2]
    | invariant a b cs => simp only [arguments, ty_eq s a h.1.1,
        ty_eq s b h.2.1.1, arguments_eq s cs h.2.2]
end

mutual
  private theorem dictionary_eq (s : List Atom) (d : DictEv) (h : DictSupport s d) : dictionary s d = d := by
    cases d with
    | «local» | clause => rfl
    | impl i ts ds => simp only [dictionary, types_eq s ts h.1, dictionaries_eq s ds h.2]
    | super d c => simp only [dictionary, dictionary_eq s d h]
  private theorem dictionaries_eq (s : List Atom) (ds : List DictEv) (h : DictsSupport s ds) : dictionaries s ds = ds := by
    cases ds with
    | nil => rfl
    | cons d ds => simp only [dictionaries, dictionary_eq s d h.1, dictionaries_eq s ds h.2]
end

mutual
  private theorem dictionaryGuide_eq (s : List Atom) (g : DictGuide) (h : g.Support s) : dictionaryGuide s g = g := by
    cases g with
    | «local» | clause => rfl
    | impl gs => simp only [dictionaryGuide, dictionaryGuides_eq s gs h]
    | super c a g => simp only [dictionaryGuide, ty_eq s a h.1, dictionaryGuide_eq s g h.2]
  private theorem dictionaryGuides_eq (s : List Atom) (gs : List DictGuide) (h : DictGuidesSupport s gs) : dictionaryGuides s gs = gs := by
    cases gs with
    | nil => rfl
    | cons g gs => simp only [dictionaryGuides, dictionaryGuide_eq s g h.1, dictionaryGuides_eq s gs h.2]
end

mutual
  private theorem argument_eq (s : List Atom) (g : ArgGuide) (h : g.Support s) : argument s g = g := by
    cases g with
    | var | const => rfl
    | dictionary d a g => simp only [argument, dictionary_eq s d h.1, ty_eq s a h.2.1, dictionaryGuide_eq s g h.2.2]
    | list gs => simp only [argument, elements_eq s gs h]
    | refine a p sort proof g => simp only [argument, ty_eq s a h.1, argument_eq s g h.2]
  private theorem element_eq (s : List Atom) (g : ElemGuide) (h : g.Support s) : element s g = g := by
    cases g with
    | mk a g c => simp only [element, ty_eq s a h.1, argument_eq s g h.2.1, le_eq s c h.2.2]
  private theorem elements_eq (s : List Atom) (gs : List ElemGuide) (h : ElemGuidesSupport s gs) : elements s gs = gs := by
    cases gs with
    | nil => rfl
    | cons g gs => simp only [elements, element_eq s g h.1, elements_eq s gs h.2]
end

private theorem head_eq (s : List Atom) (g : HeadGuide) (h : g.Support s) : head s g = g := by
  cases g with
  | plain => rfl
  | method owner a g => simp only [head, ty_eq s a h.1, dictionaryGuide_eq s g h.2]

private theorem map_eq_of_mem (f : α → α) (xs : List α) (h : ∀ x ∈ xs, f x = x) : xs.map f = xs := by
  calc
    xs.map f = xs.map id := List.map_congr_left h
    _ = xs := List.map_id xs

private theorem hints_eq (s : List Atom) (h : Hints) (hs : h.Support s) : hints s h = h := by
  have htypes := types_eq s h.types hs.types
  have hlists := map_eq_of_mem (types s) h.typeLists (fun x hx => types_eq s x (hs.typeLists x hx))
  have heffects := map_eq_of_mem (eff s) h.effects (fun x hx => eff_eq s x (hs.effects x hx))
  have htels := map_eq_of_mem (tel s) h.signatures (fun x hx => tel_eq s x (hs.signatures x hx))
  have hsubtypes := map_eq_of_mem (le s) h.subtypes (fun x hx => le_eq s x (hs.subtypes x hx))
  have harguments := map_eq_of_mem (elements s) h.arguments (fun x hx => elements_eq s x (hs.arguments x hx))
  have hheads := map_eq_of_mem (head s) h.heads (fun x hx => head_eq s x (hs.heads x hx))
  simp only [hints, htypes, hlists, heffects, htels, hsubtypes, harguments, hheads]

mutual
  /-- 支持を満たす案内は、規則・中間型・効果・証明書・子の位置をすべて保つ。 -/
  theorem guide_eq (s : List Atom) (g : Guide) (hs : g.Support s) : guide s g = g := by
    cases g with
    | unknown => rfl
    | failure _ => rfl
    | node r h gs => simp only [guide, hints_eq s h hs.1, guides_eq s gs hs.2]
  private theorem guides_eq (s : List Atom) (gs : List Guide) (h : GuidesSupport s gs) : guides s gs = gs := by
    cases gs with
    | nil => rfl
    | cons g gs => simp only [guides, guide_eq s g h.1, guides_eq s gs h.2]
end

end Benitoite.Release.Refinement.Surface.CheckFinite
