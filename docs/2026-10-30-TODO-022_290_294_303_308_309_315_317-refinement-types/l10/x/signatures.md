# 群 X の完全署名と決定の記録

2026-11-01。ブランチの指定は `m014/l10.x`、B_WORK は `efbc8ebf58b0a64320f375e663ad929a29e73e86` である。git の操作による照合はしていない。実装開始前に現行のソースと detail の署名を合わせて記録し、その後の補助の契約の決定を下に追記した。本書は最終の契約を示す。名前空間は `Benitoite.Release.Refinement` とする。

公的な定義・補題の完全な型は、[signatures.lean](signatures.lean) の `#check @…` と [signatures-output.txt](signatures-output.txt) に保存する。定義の全構成子は以下のとおりである。private の証明の補助は公的な契約から除くが、公理依存の検査からは除かない。

## 自己の観測と篩の可能性

```lean
noncomputable def selfObservation (v : Val) : Option Observation :=
  v.toTerm?.bind (Term.observe (fun _ => none))
noncomputable def selfModel (η : ObservationEnvModel) (v : Val) : ObservationEnvModel :=
  fun | 0 => selfObservation v | i+1 => η i
noncomputable def RefinementPossible (p : Pred) (v : Val) : Prop :=
  p.evalWith (selfModel (fun _ => none) v) ≠ some false

```

## パターンと所属

```lean
mutual
  inductive PatTy (P : Program) : Pat → Ty → List Ty → Prop where
    | P_Wild {a} : PatTy P .wild a []
    | P_Var {a} : PatTy P .var a [a]
    | P_Const {c} : c.patternAllowed = true → PatTy P (.const c) (embedConst c).type []
    | P_RangeInt {lo hi : Integer64Value} :
        PatTy P (.range (.integer lo) (.integer hi)) (.base .integer) []
    | P_RangeChar {lo hi : Char} :
        PatTy P (.range (.character lo) (.character hi)) (.base .character) []
    | P_List {before rest after a δb δa} :
        PatTys P before (List.replicate before.length a) δb →
        PatTys P after (List.replicate after.length a) δa →
        (rest = none → after = []) →
        PatTy P (.list before rest after) (.list a) (δb ++ restTys rest a ++ δa)
    | P_Convert {p a b δ} : a.norm = b.norm → PatTy P p a δ → PatTy P p b (δ.map Ty.norm)
    | P_Refined {p a φ δ} : PatTy P p a δ → PatTy P p (.refined a φ) δ
    | P_Con {c ps cd ts δ} : P.cons c = some cd → ts.length = cd.ntys →
        (∀ a ∈ cd.args, a.WF 0 cd.ntys 0) →
        PatTys P ps (cd.args.map (Ty.subst ts [])) δ →
        PatTy P (.con c ps) (.data cd.data ts) δ
  inductive PatTys (P : Program) : List Pat → List Ty → List Ty → Prop where
    | nil : PatTys P [] [] []
    | cons {p ps a as δ δs} : PatTy P p a δ → PatTys P ps as δs →
        PatTys P (p :: ps) (a :: as) (δ ++ δs)
end

/- 構成子の一覧は型付けと同じP.consを読む。篩は self で false と確定する値だけを除く。 -/
mutual
  inductive Inhabits (P : Program) : Ty → Val → Prop where
    | const {c} : Inhabits P c.type (.const c)
    | con {c ts tys args cd} : P.cons c = some cd → cd.ntys = ts.length →
        (∀ a ∈ cd.args, a.WF 0 cd.ntys 0) →
        InhabitsAll P (cd.args.map (Ty.subst ts [])) args →
        Inhabits P (.data cd.data ts) (.con c tys args)
    | atError {detail} : ResultShape.StandardError P
        ⟨"Result", "Ok", "Error", atErrorType⟩ →
        Inhabits P atErrorType (.atError detail)
    | list {a elems} : InhabitsEach P a elems → Inhabits P (.list a) (.list elems)
    | fn {ns ps r e v} : Inhabits P (.fn ns ps r e) v
    | dependentFn {t v} : Inhabits P (.dependentFn t) v
    | tvar {i v} : Inhabits P (.tvar i) v
    | reference {a v} : Inhabits P (.reference a) v
    | lazy {a v} : Inhabits P (.lazy a) v
    | cont {b t e v} : Inhabits P (.cont b t e) v
    | map {a b v} : Inhabits P (.map a b) v
    | set {a v} : Inhabits P (.set a) v
    | bytes {v} : Inhabits P .bytes v
    | dict {cl a v} : Inhabits P (.dict cl a) v
    | tapp {i as v} : Inhabits P (.tapp i as) v
    | ctor {c v} : Inhabits P (.ctor c) v
    | external {id ts v} : Inhabits P (.external id ts) v
    | scoped {o k ix v} : Inhabits P (.scoped o k ix) v
    | pathBases {v} : Inhabits P .pathBases v
    | scopePattern {k v} : Inhabits P (.scopePattern k) v
    | refined {a p v} : Inhabits P a v → RefinementPossible p v → Inhabits P (.refined a p) v
    | checked {o r t} : Inhabits P (.opaque o (.fixed r)) (.checked t)
    | checkedRequest {o r t req} : Inhabits P (.opaque o (.fixed r)) (.checkedRequest t req)
    | checkedAtOpaque {o ix r snapshot target req} :
        Inhabits P (.opaque o ix) (.checkedAt r snapshot target req)
  inductive InhabitsAll (P : Program) : List Ty → List Val → Prop where
    | nil : InhabitsAll P [] []
    | cons {a as v vs} : Inhabits P a v → InhabitsAll P as vs → InhabitsAll P (a :: as) (v :: vs)
  inductive InhabitsEach (P : Program) : Ty → List Val → Prop where
    | nil {a} : InhabitsEach P a []
    | cons {a v vs} : Inhabits P a v → InhabitsEach P a vs → InhabitsEach P a (v :: vs)
end

def Exhaustive (P : Program) (a : Ty) (ps : List Pat) : Prop :=
  ∀ v, Inhabits P a.norm v → ∃ p ∈ ps, (matchVal p v).isSome
```

## 値についての判断の相互四族

```lean
/-- 範囲付き型の意味に使う成功値の形。範囲の所属そのものは型付けが保持する。 -/
inductive ScopedValue : RangeIx → Val → Prop where
  | checked {r target} : ScopedValue (.fixed r) (.checked target)
  | checkedRequest {r target req} : ScopedValue (.fixed r) (.checkedRequest target req)
  | checkedAt {ix r snapshot target req} : ScopedValue ix (.checkedAt r snapshot target req)

theorem ScopedValue.covers {outer inner v} (hc : RangeIx.Covers outer inner)
    (h : ScopedValue inner v) : ScopedValue outer v := by
  cases outer <;> cases inner <;> simp only [RangeIx.Covers] at hc
  · cases h <;> first | exact .checked | exact .checkedRequest | exact .checkedAt
  · subst hc; exact h

mutual
  inductive ValueMeaning (P : Program) (η : ObservationEnvModel) : Ty → Val → Prop where
    | mk {a v} : ValueShapeMeaning P η a.norm.core v →
        (∀ p ∈ a.norm.refinementPredicates, p.interpret (selfModel η v) = true) → ValueMeaning P η a v
  inductive ValueShapeMeaning (P : Program) (η : ObservationEnvModel) : Ty → Val → Prop where
    | const {c} : ValueShapeMeaning P η c.type (.const c)
    | con {c ts tys args cd} : P.cons c = some cd → cd.ntys = ts.length →
        (∀ a ∈ cd.args, a.WF 0 cd.ntys 0) →
        ValueMeanings P η (cd.args.map (Ty.subst ts [])) args →
        ValueShapeMeaning P η (.data cd.data ts) (.con c tys args)
    | atError {detail} : ResultShape.StandardError P
        ⟨"Result", "Ok", "Error", atErrorType⟩ →
        ValueShapeMeaning P η atErrorType (.atError detail)
    | list {a elems} : ValueMeaningEach P η a elems → ValueShapeMeaning P η (.list a) (.list elems)
    | fn {ns ps r e v} : ValueShapeMeaning P η (.fn ns ps r e) v
    | dependentFn {t v} : ValueShapeMeaning P η (.dependentFn t) v
    | tvar {i v} : ValueShapeMeaning P η (.tvar i) v
    | reference {a v} : ValueShapeMeaning P η (.reference a) v
    | lazy {a v} : ValueShapeMeaning P η (.lazy a) v
    | cont {b t e v} : ValueShapeMeaning P η (.cont b t e) v
    | map {a b v} : ValueShapeMeaning P η (.map a b) v
    | set {a v} : ValueShapeMeaning P η (.set a) v
    | bytes {v} : ValueShapeMeaning P η .bytes v
    | dict {cl a v} : ValueShapeMeaning P η (.dict cl a) v
    | tapp {i as v} : ValueShapeMeaning P η (.tapp i as) v
    | ctor {c v} : ValueShapeMeaning P η (.ctor c) v
    | external {id ts v} : ValueShapeMeaning P η (.external id ts) v
    | scoped {o k ix v} : ScopedValue ix v → ValueShapeMeaning P η (.scoped o k ix) v
    | pathBases {v} : ValueShapeMeaning P η .pathBases v
    | scopePattern {k v} : ValueShapeMeaning P η (.scopePattern k) v
    | checked {o r t} : ValueShapeMeaning P η (.opaque o (.fixed r)) (.checked t)
    | checkedRequest {o r t req} : ValueShapeMeaning P η (.opaque o (.fixed r)) (.checkedRequest t req)
    | checkedAtOpaque {o ix r snapshot target req} :
        ValueShapeMeaning P η (.opaque o ix) (.checkedAt r snapshot target req)
  inductive ValueMeanings (P : Program) (η : ObservationEnvModel) : List Ty → List Val → Prop where
    | nil : ValueMeanings P η [] []
    | cons {a as v vs} : ValueMeaning P η a v → ValueMeanings P η as vs → ValueMeanings P η (a :: as) (v :: vs)
  inductive ValueMeaningEach (P : Program) (η : ObservationEnvModel) : Ty → List Val → Prop where
    | nil {a} : ValueMeaningEach P η a []
    | cons {a v vs} : ValueMeaning P η a v → ValueMeaningEach P η a vs → ValueMeaningEach P η a (v :: vs)
end
```

## 観測の情報の順序

```lean
mutual
  inductive Observation.InfoLE : Observation → Observation → Prop where
    | refl (o) : InfoLE o o
    | list {xs ys} : Observation.SlotsInfoLE xs ys → InfoLE (.listValue xs) (.listValue ys)
    | map {ks ls vs ws} : Observation.SlotsInfoLE ks ls → Observation.SlotsInfoLE vs ws →
        InfoLE (.mapValue ks vs) (.mapValue ls ws)
    | set {xs ys} : Observation.SlotsInfoLE xs ys → InfoLE (.setValue xs) (.setValue ys)
    | data {c xs ys} : Observation.SlotsInfoLE xs ys → InfoLE (.dataValue c xs) (.dataValue c ys)
  inductive Observation.OptionInfoLE : Option Observation → Option Observation → Prop where
    | none (o) : OptionInfoLE none o
    | some {o p} : Observation.InfoLE o p → OptionInfoLE (some o) (some p)
  inductive Observation.SlotsInfoLE : List (Option Observation) → List (Option Observation) → Prop where
    | nil : SlotsInfoLE [] []
    | cons {x y xs ys} : Observation.OptionInfoLE x y → SlotsInfoLE xs ys →
        SlotsInfoLE (x::xs) (y::ys)
end

def ObservationEnvModel.InfoLE (η ξ : ObservationEnvModel) : Prop :=
  ∀ i, Observation.OptionInfoLE (η i) (ξ i)
```

反射性・推移性・反対称性、slot の位置と数、sort、鍵コードと大きさ、Term の観測、Pred の確定値の単調性を証明する。値の像を束縛する部分的な項と既定値を使う項を区別した `Term.bind_observe_info` から、`Pred.close_preserves_decided` を導く。無条件の `Term.interpret` の不変性は置かない。

## G09 へ残す完全署名

以下は未実装の契約である。Lean に axiom や未証明の theorem として追加しない。現在の `CoreAssumptions` に `sig_scoped` を加える G08 の接続も引き継ぐ。

```lean
valueMeaning_sub : ∀ {P : Program} {Γ : Ctx} {Φ : List Pred}
    {a b : Ty} {v : Val} {η : ObservationEnvModel},
  P.VarianceValid → Ty.LeQ P Γ Φ a b →
  (∀ p ∈ Γ.facts ++ Φ, p.interpret η = true) →
  ValueMeaning P η a v → ValueMeaning P η b v

typed_value_meaning_closed : ∀ {P : Program} {B : Builtins} {Ψ : StoreTy}
    {v : Val} {a : Ty},
  P.VarianceValid → B.CoreAssumptions P →
  HasTypeVQ P B Ψ Qempty [] [] [] v a → ValueMeaning P (fun _ => none) a v

inhabits_of_typed : ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {v : Val} {a : Ty},
  P.VarianceValid → B.CoreAssumptions P →
  HasTypeVQ P B Ψ Qempty [] [] [] v a → Inhabits P a.norm v

inhabits_of_typed_raw : ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {v : Val} {a : Ty},
  P.VarianceValid → B.CoreAssumptions P →
  HasTypeVQ P B Ψ Qempty [] [] [] v a → Inhabits P a v
```

G09 は閉じた型付けの全導出への帰納で意味を構成し、意味から所属への証明済みの系を使う。部分型の全移送では、data/List の子値への下降と `Ty.LeQ` の導出への下降を区別する。群 X の `valueMeaning_refine` と `HasTypeVQ.sub_refine_representative` は、基底の意味の移送を帰納仮定として受ける refine の場合を閉じる。`CaptureOk.variable_coverage` の意味への含意は、意味を新しい前提とする主な定理を作るためではなく、この G09 の供給箇所を明示するための接続である。

## 補助の契約で決めたこと

1. `ValueMeaning` の入口を正規形とし、子の意味は相互族で保持する。data/List の子は完全な意味を要求する。`scoped` は `ScopedValue ix v` に絞り、fixed の添字に `checked` と `checkedRequest`、任意の添字に `checkedAt` を認める。それ以外の、照合が内部を観測しない型の形の上側近似は現行 `Inhabits` の core と一致させる。意味の独立の仮定を主な定理へ加えない。
2. 情報の順序は内部の slot を同じ長さで比較し、scalar と snapshot は等号で固定する。sort・constructor・鍵の確定した符号を保つ。
3. `Inhabits` の正規化と値置換の反映では、full type と述語の評価を使う。core だけから篩を復元する補題は廃止する。
4. 予定の `valueMeaning_sub` と `typed_value_meaning_closed` は G09 の未実装の契約であり、axiom や未証明の theorem として Lean に追加しない。L10 は refine の代表に加え、`Ty.LeQ.scoped` と `scoped_forget` に対応する意味の移送を証明する。
5. 全型付けの10本の主署名と結論は維持する。`Exhaustive` の B・Γ・Φ の増加は0。新しい公理、提供範囲、書ける形の制限、精密な外部状態は追加しない。

6. 意味の事実は `a.norm.refinementPredicates` の全てを真とする。detail の `assume` は継続型の事実を空にするが、`Ty.norm` は不適格な継続型上の篩を消さない。そのままでは `ValueMeaning … (Cont{false}) v` が空の事実から作れて所属への系が偽になる。全述語を要求すれば、適格な型では `Ty.assume_eq_predicates` によって予定と一致し、不適格な内部型についても所属への系を保てる。利用者の書ける形と主な定理の前提は変えない。

7. パターンの補助判断へ正規形の等号による変換を追加する。完全署名は `PatTy.P_Convert {p a b δ} : a.norm = b.norm → PatTy P p a δ → PatTy P p b (δ.map Ty.norm)` とする。指定の `P_Refined` の署名は維持する。予定10規則は実際11規則になる。理由: `P_Refined P_Var` が中間の篩型を束縛する場合、篩の平坦化でその型が構文上の部分型から消え、元の10規則だけでは既存の `PatTy.subst_values` の結論が偽になる。型付けの補助判断を、既存の `Ty.LeQ.convert` と同じ正規形の等号で移す。主な定理の前提・結論、新しい公理、提供範囲、利用者の書ける形、精密な外部状態は変えない。新しい構文上の部分型や述語の含意を許す規則ではない。

8. `Inhabits.norm_all_iff` は実装した族について任意の型で閉じた。要求された `Inhabits.norm_iff` の公的な入口は WF を明示する署名を維持し、raw な結論を必要とする後段には `norm_all_iff` を使える。G09 の `inhabits_of_typed_raw` からは不要な WF の前提を外す。篩の列の真を省く補題ではない。
9. 捕捉の全ての値の型付けを先取りしない。`Capture.meaning_coverage` は任意の開いた型・捕捉について意味から所属の反映を閉じ、`CaptureOk.variable_coverage` は実際の型付き像と条件から閉じた変数の型付けを供給する。任意の `closeVal` の型保存と全腕は G09 に残す。

10. `P_Convert` の束縛型は `δ.map Ty.norm` とする。raw な束縛型を任意の正規形の入力へ渡す規則にしない。値置換の出力は既に正規形なので、既存の移送の結論は変わらない。値・型の移動では正規化との交換を使う。

11. RV-L10.x の中1を受け、`scoped` の意味を成功値の形と範囲の添字を結ぶ `ScopedValue` に絞る。`Inhabits`・`Exhaustive`・`PatTy` は変えない。`ScopedValue.covers`、`ScopedValue.forget`、`ValueMeaning.scoped_covers`、`ValueMeaning.scoped_forget` を本番の定理として証明した。境界の `scoped_forget_sub_contract` は G09 の `valueMeaning_sub` の完全署名を scoped_forget に特殊化したものであり、追加の前提を要さない。全ての部分型に対する移送は引き続き G09 に残す。

## レビュー後に閉じた範囲の移送の完全署名

```lean
theorem ScopedValue.forget {ix v} (P : Program) (η : ObservationEnvModel) (o : OpaqueName)
    (h : ScopedValue ix v) : ValueShapeMeaning P η (.opaque o ix) v := by
  cases h <;> first | exact .checked | exact .checkedRequest | exact .checkedAtOpaque

theorem ValueShapeMeaning.scoped_inv {P η a v} (h : ValueShapeMeaning P η a v) :
    ∀ o k ix, a = .scoped o k ix → ScopedValue ix v := by
  match h with
  | .scoped hs => intro o k ix he; cases he; exact hs
  | .const (c := c) => intro o k ix he; cases c <;> cases he
  | .con .. | .atError .. | .list .. | .fn | .dependentFn | .tvar | .reference | .lazy | .cont |
    .map | .set | .bytes | .dict | .tapp | .ctor | .external | .pathBases | .scopePattern |
    .checked | .checkedRequest | .checkedAtOpaque => intro o k ix he; cases he

theorem ValueMeaning.of_scoped {P η o k ix v} (h : ScopedValue ix v) :
    ValueMeaning P η (.scoped o k ix) v := .mk (.scoped h) (by intro p hp; cases hp)

theorem ValueMeaning.scoped_inv {P η o k ix v} (h : ValueMeaning P η (.scoped o k ix) v) :
    ScopedValue ix v := by
  cases h with
  | mk hs _ => exact hs.scoped_inv o k ix rfl

/-- 範囲を広げる部分型は、成功値の形を保つ。 -/
theorem ValueMeaning.scoped_covers {P η o k inner outer v}
    (hc : RangeIx.Covers outer inner) (h : ValueMeaning P η (.scoped o k inner) v) :
    ValueMeaning P η (.scoped o k outer) v := .of_scoped (h.scoped_inv.covers hc)

/-- scoped から opaque への部分型は、同じ添字の成功値の意味を持つ。 -/
theorem ValueMeaning.scoped_forget {P η o k ix v}
    (h : ValueMeaning P η (.scoped o k ix) v) : ValueMeaning P η (.opaque o ix) v :=
  .mk (h.scoped_inv.forget P η o) (by intro p hp; cases hp)

```

## 後段への補助契約の申し送り

- G03: `PatTy`・`AltsTy`・`Exhaustive` の型置換を閉じる。網羅性の義務は旧 `Exhaustive.substAt` に当たる。所属の型置換の反映も必要である。群 X で閉じた値置換・値移動・型移動と取り違えない。
- G06: パターン束縛の型保存は、`PatTy P p a δ` と正規形での入力の型付け `HasTypeVQ … v a.norm`、照合の成功から、捕捉した値の型付けを `δ.map Ty.norm` について結論する形を基準とする。`v : a.norm` だけから raw な `δ` の型付けを要求しない。raw な束縛型を結論する場合は、その型の形成の証拠を別に供給する。`P_Var`・`P_Refined`・`P_Convert` の三場合を含める。
- L70/R10b: Rust が束縛へ付ける型を、Lean の `P_Var`・`P_Refined`・`P_Convert` と照合する。途中の篩を保持する場合と `δ.map Ty.norm` に正規化する場合を、構文上の同じ型と仮定しない。
