# A1 の完全署名

B_WORK: `67135be26f4a1ceab11d25e23effbb4285ddda71`。指定ブランチ: `m014/l20.a1`。Git 操作による照合は行わない。実装前に固定した。名前空間は `Benitoite.Release.Refinement`、`TParam` と `Qempty` は既存の共有名である。

S00 の定義をそのまま用いる。`r` の Sorted は要求しない。新規公開補題の全引数を以下へ記す。`hideBuilders` は既存の Typing にあるため、二つの hide は StateTyping に置く。閉じた Sorted の移送に WF は不要である。

```lean
def LocTy.Sorted : LocTy → Prop
  | .builder (.list a) | .ref a | .lazy a => a.Sorted []
  | .builder .string | .builder .bytes => True
  | .cont b t e _ => b.Sorted [] ∧ t.Sorted [] ∧ sortedEff [] e

def StoreTy.Sorted (Ψ : StoreTy) : Prop :=
  ∀ (l : Nat) (x : LocTy), Ψ l = some x → x.Sorted

theorem StoreTy.Sorted.empty : StoreTy.Sorted StoreTy.empty

theorem StoreTy.Sorted.hide {Ψ : StoreTy} (h : Ψ.Sorted) : (hideBuilders Ψ).Sorted

theorem StoreTy.Declared.hide {P : Program} {Ψ : StoreTy}
    (h : StoreTy.Declared P Ψ) : StoreTy.Declared P (hideBuilders Ψ)

def StoreOk (P : Program) (B : Builtins) (σ : PathEnv)
    (Ψ : StoreTy) (μ : Store) : Prop :=
  (∃ n, ∀ l, n ≤ l → μ l = none) ∧ Ψ.WF ∧ Ψ.Sorted ∧
  StoreTy.Declared P Ψ ∧ (∀ l x, Ψ l = some x → μ l ≠ none) ∧
  (∀ l c, μ l = some c → CellOk P B σ Ψ l c)

theorem Ty.Sorted.closed_context {a : Ty} {Γ : Ctx}
    (h : a.Sorted []) : a.Sorted Γ

theorem Ty.WF.closed_context {a : Ty} {C : List TParam} {Γ : Ctx}
    (h : a.WF 0 0 0) : a.WF 0 C.length Γ.length

theorem Ty.Annotation.closed_context {P : Program} {a : Ty}
    {C : List TParam} {Γ : Ctx} (h : Ty.Annotation P [] [] a) : Ty.Annotation P C Γ a

theorem StoreOk.finite {P : Program} {B : Builtins} {σ : PathEnv}
    {Ψ : StoreTy} {μ : Store} (h : StoreOk P B σ Ψ μ) :
    ∃ n, ∀ l, n ≤ l → μ l = none

theorem StoreOk.sorted {P : Program} {B : Builtins} {σ : PathEnv}
    {Ψ : StoreTy} {μ : Store} (h : StoreOk P B σ Ψ μ) : Ψ.Sorted

theorem StoreOk.domain {P : Program} {B : Builtins} {σ : PathEnv}
    {Ψ : StoreTy} {μ : Store} (h : StoreOk P B σ Ψ μ) :
    ∀ l x, Ψ l = some x → μ l ≠ none

theorem StoreOk.cell {P : Program} {B : Builtins} {σ : PathEnv}
    {Ψ : StoreTy} {μ : Store} (h : StoreOk P B σ Ψ μ) :
    ∀ l c, μ l = some c → CellOk P B σ Ψ l c

theorem StoreOk.reference_annotation {P : Program} {B : Builtins} {σ : PathEnv}
    {Ψ : StoreTy} {μ : Store} {l : Nat} {a : Ty} {C : List TParam} {Γ : Ctx}
    (h : StoreOk P B σ Ψ μ) (hl : Ψ l = some (.ref a)) : Ty.Annotation P C Γ a

theorem StoreOk.lazy_annotation {P : Program} {B : Builtins} {σ : PathEnv}
    {Ψ : StoreTy} {μ : Store} {l : Nat} {a : Ty} {C : List TParam} {Γ : Ctx}
    (h : StoreOk P B σ Ψ μ) (hl : Ψ l = some (.lazy a)) : Ty.Annotation P C Γ a

theorem StoreOk.cont_result_annotation {P : Program} {B : Builtins} {σ : PathEnv}
    {Ψ : StoreTy} {μ : Store} {l : Nat} {b t : Ty} {e : Eff} {r : Option Ty}
    {C : List TParam} {Γ : Ctx} (h : StoreOk P B σ Ψ μ)
    (hl : Ψ l = some (.cont b t e r)) : Ty.Annotation P C Γ t

theorem StoreOk.cont_annotation {P : Program} {B : Builtins} {σ : PathEnv}
    {Ψ : StoreTy} {μ : Store} {l : Nat} {b t : Ty} {e : Eff} {r : Option Ty}
    (h : StoreOk P B σ Ψ μ) (hl : Ψ l = some (.cont b t e r)) :
    Ty.Annotation P [] [] (.dependentFn (.done t e))

theorem StoreOk.no_unsorted_cont_result {P : Program} {B : Builtins} {σ : PathEnv}
    {Ψ : StoreTy} {μ : Store} {l : Nat} {b t : Ty} {e : Eff} {r : Option Ty}
    (hl : Ψ l = some (.cont b t e r)) (ht : ¬ t.Sorted []) : ¬ StoreOk P B σ Ψ μ

theorem StoreOk.allocate_continuation {P : Program} {B : Builtins} {σ : PathEnv}
    {Ψ : StoreTy} {μ : Store} {l : Nat} {a t : Ty} {ec : Eff} {R : Option Ty} {saved : Cont}
    (h : StoreOk P B σ Ψ μ) (hA : Builtins.ValueAssumptions P B)
    (hl : μ l = none) (hw : LocTy.WF (.cont a t ec R))
    (ha : a.Sorted []) (ht : t.Sorted []) (he : sortedEff [] ec)
    (hd : LocTy.Declared P (.cont a t ec R)) (hend : EndsWithHandle saved)
    (hk : ∃ R0 e0, ContTy P B σ Ψ R0 e0 saved a t ec R) :
    StoreOk P B σ (Ψ.put l (.cont a t ec R)) (μ.set l (.cont saved))
```

既存公開署名は `allocate_continuation` の上記三引数だけを変更する。他の既存宣言と、主な十言明の前提・結論は不変である。追加の読者を全検索したところ、S00 表の八ファイルのほか ReferencePreservation の領域射影一箇所と LazyPreservation のセル射影二箇所・領域射影一箇所がある。これらも同じ名前付き補題へ追随する。型付け規則と四移送は変更しない。

境界の所有者は StoreOk の新不変条件と、hideBuilders 後の三条件である。正例は新鮮な ref/lazy/cont の割当てと更新、Sorted でない r の許容、閉じた篩の任意 Γ への移送を扱う。負例はレビューの `.used` の同じ badT の拒否と、hideBuilders へ StoreOk を要求できない builder 入力を扱う。既存ビルドは定理の使用だけを検査し、この具体的な境界を扱わない。テスト専用の本番引数・公理は追加しない。

## r1: 三条件を受ける形成の補題

RV-L20.a1 の中1・軽1を同じ群で処置する。以下の六つの完全署名を実装前に固定する。既存の四つの StoreOk 版の署名は保ち、この三条件の版の包装にする。cont_type_annotation は ImageOk.contLoc が使う閉じた WF を含む全 Annotation を返し、任意 C/Γ へも移せる。builder_list_annotation は場所の型から要素型の三条件を読む本番の補題である。

```lean
theorem StoreTy.reference_annotation {P : Program} {Ψ : StoreTy} {l : Nat}
    {a : Ty} {C : List TParam} {Γ : Ctx}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hl : Ψ l = some (.ref a)) : Ty.Annotation P C Γ a

theorem StoreTy.lazy_annotation {P : Program} {Ψ : StoreTy} {l : Nat}
    {a : Ty} {C : List TParam} {Γ : Ctx}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hl : Ψ l = some (.lazy a)) : Ty.Annotation P C Γ a

theorem StoreTy.cont_result_annotation {P : Program} {Ψ : StoreTy} {l : Nat}
    {b t : Ty} {e : Eff} {r : Option Ty} {C : List TParam} {Γ : Ctx}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hl : Ψ l = some (.cont b t e r)) : Ty.Annotation P C Γ t

theorem StoreTy.cont_annotation {P : Program} {Ψ : StoreTy} {l : Nat}
    {b t : Ty} {e : Eff} {r : Option Ty}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hl : Ψ l = some (.cont b t e r)) :
    Ty.Annotation P [] [] (.dependentFn (.done t e))

theorem StoreTy.cont_type_annotation {P : Program} {Ψ : StoreTy} {l : Nat}
    {b t : Ty} {e : Eff} {r : Option Ty} {C : List TParam} {Γ : Ctx}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hl : Ψ l = some (.cont b t e r)) : Ty.Annotation P C Γ (.cont b t e)

theorem StoreTy.builder_list_annotation {P : Program} {Ψ : StoreTy} {l : Nat}
    {a : Ty} {C : List TParam} {Γ : Ctx}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hl : Ψ l = some (.builder (.list a))) : Ty.Annotation P C Γ a
```

境界は既存の同じ badT を再使用し、cont の b/e・ref・lazy・List builder の五つの拒否を加える。t の既存負例と合わせて、S00 の型を読む全欄を守る。hide 後の場所から三条件の公開補題で注釈を得て、ImageOk.contLoc と再開の結果の形成へ渡す正例を加える。テスト専用の本番引数は追加しない。
