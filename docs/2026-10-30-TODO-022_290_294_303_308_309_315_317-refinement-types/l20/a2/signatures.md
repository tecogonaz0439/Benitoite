# A2 の完全署名と未証明枝

2026-11-02。B_WORK は `3cdec1565a0526a9617e766ca5feb3bbad362ca4`、指定ブランチは `m014/l20.a2`。git による照合・操作はしない。開始時刻は UTC 2026-11-01 17:26:04。実装前に保存した。

現行の型文脈は `List Benitoite.Release.TParam` である。detail の `TypeCtx` は A3 の変更予定であり、A2 では現行の型を明記する。要素を変更せず、同じ C と C.length を使う。以下は証明の目標であり、保存した時点では未証明である。未証明の定理を Lean に宣言しない。

```lean
def CaptureContextRegular (P : Program) (C : List Benitoite.Release.TParam) (Γ : Ctx) : Prop :=
  Ctx.CaptureWF 0 C.length Γ ∧
  ∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) →
    a.CaptureSorted Γ ∧ a.CaptureDeclared P C Γ

theorem open_value_annotation {P : Program} {B : Builtins} {Ψ : StoreTy}
    {Q : Benitoite.Release.NoFailCtx} {C : List Benitoite.Release.TParam} {Γ : Ctx}
    {Φ : List Pred} {v : Val} {a : Ty}
    (hp : P.WellFormed) (ht : P.WellTyped B) (hA : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hΓ : CaptureContextRegular P C Γ) (h : HasTypeVQ P B Ψ Q C Γ Φ v a) :
    Ty.Annotation P C Γ a

theorem open_comp_annotation {P : Program} {B : Builtins} {Ψ : StoreTy}
    {Q : Benitoite.Release.NoFailCtx} {C : List Benitoite.Release.TParam} {Γ : Ctx}
    {Φ : List Pred} {R : Option Ty} {m : Comp} {a : Ty} {e : Eff} {L : LocalCtx}
    (hp : P.WellFormed) (ht : P.WellTyped B) (hA : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hΓ : CaptureContextRegular P C Γ) (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L) :
    Ty.Annotation P C Γ a

theorem let_annotation {P : Program} {C : List Benitoite.Release.TParam} {Γ : Ctx} {a b : Ty}
    (hn : Ty.Annotation P C (Γ.extend a) (b.shiftV 1 0))
    (ha : Ty.Annotation P C Γ a) : Ty.Annotation P C Γ b

theorem builder_annotation {P : Program} {C : List Benitoite.Release.TParam} {Γ : Ctx} {a : Ty}
    (hn : Ty.Annotation P C Γ.extendNone (a.shiftV 1 0))
    (hd : a.Declared P C Γ) : Ty.Annotation P C Γ a

theorem used_annotation {P : Program} {Ψ : StoreTy} {l : Nat} {b t : Ty} {e : Eff}
    {R : Option Ty} {C : List Benitoite.Release.TParam} {Γ : Ctx}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hl : Ψ l = some (.cont b t e R)) : Ty.Annotation P C Γ t

theorem locref_annotation {P : Program} {Ψ : StoreTy} {l : Nat} {a : Ty}
    {C : List Benitoite.Release.TParam} {Γ : Ctx}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hl : Ψ l = some (.ref a)) : Ty.Annotation P C Γ (.reference a)

theorem checked_annotation (P : Program) (C : List Benitoite.Release.TParam) (Γ : Ctx)
    (o : OpaqueName) (k : Scope.Domain.Kind) (r : Scope.Domain.Range) :
    Ty.Annotation P C Γ (.scoped o k (.fixed (.absolute r)))
```

相互帰納の結果は V→Annotation、Vs→TypeAnnotations、Each→非空のとき Annotation、CQ→Annotation、Arms→末尾の Annotation、TelArgs→done の Annotation である。他の8成分は True。Φ の真、CaptureOk、効果全体の独立した注釈は motive に加えない。

| 未証明枝（保存時） | 供給と確認内容 |
|---|---|
| C_Let | 前半の IH から CaptureContextRegular.extend、後半の IH の逆 shift |
| C_BuilderLet | extendNone と None を unit に写す TypeMap、明示 Declared |
| C_ResumeL / V_LocRef | A1 の場所三条件の補題 |
| V_Checked | 固定絶対範囲の定義 |
| V/Vs/Each/CQ/Arms/TelArgs 全枝 | 全53規則＋補助判断の構造帰納。まだ完了としない |
| E_Handle | ε ∪ handled の上限で本体を C_Eff。ClauseSig が同じまま成立することを確認 |
| E_Handle_Fail | E/ec の既存 Annotation、rest の正規化と NoFail、節の eb 依存を確認 |

残りの初期見込みは依頼の 2時間45分〜6時間45分を維持する。60分以内に実際の枝の状態を追記する。新しい前提が必要なら J20-1 に従って停止する。

境界を追加する場合は test-audit の作成時の関門を適用する。所有する契約は開いた結果形成と効果上限の形成である。偽の Φ・None の位置・生の未形成効果と形成済み上限の取り違えを捕まえる。A1 の場所単独の境界と重複させず、実際の型付けと新しい一般定理を接続する。試験専用の本番フックは追加しない。

## 全枝の初回局所確認後の追加署名

最初の局所検査で V29/CQ24 は全枝が閉じた。未証明の本番定理は置いていない。以下の系を追加する。`List TParam` は現行ソースの型である。完全な elaboration 後の署名は、検査時に `public-signatures.log` に保存する。

```lean
open_values_annotation : ∀ {P : Program} {B : Builtins} {Ψ : StoreTy}
  {Q : NoFailCtx} {C : List TParam} {Γ : Ctx} {Φ : List Pred} {vs : List Val} {as : List Ty},
  P.WellFormed → P.WellTyped B → B.CoreAssumptions P →
  Ψ.WF → Ψ.Sorted → StoreTy.Declared P Ψ → CaptureContextRegular P C Γ →
  HasTypeVsQ P B Ψ Q C Γ Φ vs as → TypeAnnotations P C Γ as
open_each_annotation : ∀ {P : Program} {B : Builtins} {Ψ : StoreTy}
  {Q : NoFailCtx} {C : List TParam} {Γ : Ctx} {Φ : List Pred} {vs : List Val} {a : Ty},
  P.WellFormed → P.WellTyped B → B.CoreAssumptions P →
  Ψ.WF → Ψ.Sorted → StoreTy.Declared P Ψ → CaptureContextRegular P C Γ →
  HasTypeEachQ P B Ψ Q C Γ Φ vs a → vs ≠ [] → Ty.Annotation P C Γ a
open_arms_annotation : ∀ {P : Program} {B : Builtins} {Ψ : StoreTy}
  {Q : NoFailCtx} {C : List TParam} {Γ : Ctx} {Φ : List Pred} {R : Option Ty}
  {obs : Option Term} {arms : List Arm} {a b : Ty} {e : Eff} {L : LocalCtx},
  HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b e L → Ty.Annotation P C Γ b
open_telArgs_annotation : ∀ {P : Program} {B : Builtins} {Ψ : StoreTy}
  {Q : NoFailCtx} {C : List TParam} {Γ : Ctx} {Φ : List Pred}
  {vs : List Val} {t : Tel} {a : Ty} {e : Eff},
  HasTypeTelArgsQ P B Ψ Q C Γ Φ vs t a e →
  Ty.Annotation P C Γ (.dependentFn (.done a e))
capture_value_annotation : ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {R : Option Ty}
  {Γ : Ctx} {Φ : List Pred} {cap : Capture} {v : Val} {a : Ty},
  P.WellFormed → P.WellTyped B → B.CoreAssumptions P →
  Ψ.WF → Ψ.Sorted → StoreTy.Declared P Ψ → CaptureOk P B Ψ R Γ Φ cap →
  HasTypeVQ P B Ψ Qempty [] Γ Φ v a → Ty.Annotation P [] [] (cap.closeTy a)
capture_comp_annotation : ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {R : Option Ty}
  {Γ : Ctx} {Φ : List Pred} {cap : Capture} {Rs : Option Ty} {m : Comp} {a : Ty} {e : Eff} {L : LocalCtx},
  P.WellFormed → P.WellTyped B → B.CoreAssumptions P →
  Ψ.WF → Ψ.Sorted → StoreTy.Declared P Ψ → CaptureOk P B Ψ R Γ Φ cap →
  HasTypeCQ P B Ψ Qempty [] Γ Φ Rs m a e L → Ty.Annotation P [] [] (cap.closeTy a)
```

E_Handle の候補は `safe := Eff.mk eb.atoms ec.fails` とする。raw の eb を形成済みとは主張しない。元の eb の原子を保つため `ClauseSig.same_atoms` が使える。上限を丸ごと置き換えて非Topの ClauseIxOk を壊す必要がない。E_Handle_Fail は `NoFail Q rest` が rest.fails=[] を持つので、E の注釈から `singleFail E ∪ rest` の注釈を得る。両候補は既存の C_Eff で同じコードを型付けする補助であり、規則の変更ではない。

## 効果の供給の完全署名（実装前）

safe の候補より直接の経路を先に検査する。閉じた上限の Annotation と Fail の包含から、正規化済みの閉じた内側の行の Annotation を得られる。`cap.closeEff` は常に正規化するため、開いた生の eb の注釈を仮定する必要がない。これが閉じれば、handler の節は元の eb のままでよく、C_Eff の上限を変えて ClauseSig を作り直す必要もなくなる。正規化する場合の整合も別に証明する。

```lean
capture_handle_body_annotation : ∀ {P : Program} {B : Builtins} {cap : Capture}
  {t : Ty} {eb ec : Eff} {h : List Clause},
  Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy t) (cap.closeEff ec))) →
  Eff.Sub eb (Eff.union ec (handled P B h)) →
  Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy t) (cap.closeEff eb)))
failure_effect_upper_annotation : ∀ {P : Program} {C : List TParam} {Γ : Ctx}
  {Q : NoFailCtx} {t E : Ty} {rest : Eff},
  Ty.Annotation P C Γ t → Ty.Annotation P C Γ E → NoFail Q rest →
  Ty.Annotation P C Γ (.dependentFn (.done t (Eff.union (Eff.singleFail E) rest)))
capture_failure_body_annotation : ∀ {P : Program} {B : Builtins} {Ψ : StoreTy}
  {cap : Capture} {Γ : Ctx} {Φ : List Pred} {R : Option Ty} {Rs : Option Ty}
  {t E : Ty} {eb rest ec : Eff} {h : List Clause} {L : LocalCtx},
  CaptureOk P B Ψ R Γ Φ cap →
  HasFailureClause P B Ψ Qempty [] Γ Φ E Rs h t ec L →
  NoFail Qempty rest → Eff.Sub eb (Eff.union (Eff.singleFail E) rest) →
  Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy t) (cap.closeEff eb)))
HasTypeClausesQ.same_input_atoms : ∀ {P : Program} {B : Builtins} {Ψ : StoreTy}
  {Q : NoFailCtx} {C : List TParam} {Γ : Ctx} {Φ : List Pred} {R : Option Ty}
  {eb eb' ec : Eff} {h : List Clause} {t : Ty} {L : LocalCtx},
  HasTypeClausesQ P B Ψ Q C Γ Φ R eb h t ec L → eb'.atoms = eb.atoms →
  HasTypeClausesQ P B Ψ Q C Γ Φ R eb' h t ec L
handle_body_normalize : ∀ {P : Program} {B : Builtins} {Ψ : StoreTy}
  {Q : NoFailCtx} {C : List TParam} {Γ : Ctx} {Φ : List Pred} {R : Option Ty}
  {m : Comp} {t : Ty} {eb ec : Eff} {h : List Clause} {L : LocalCtx},
  HasTypeCQ P B Ψ Q C Γ Φ R m t eb L → Eff.Sub eb (Eff.union ec (handled P B h)) →
  HasTypeClausesQ P B Ψ Q C Γ Φ R eb h t ec L →
  HasTypeCQ P B Ψ Q C Γ Φ R m t eb.norm L ∧
  Eff.Sub eb.norm (Eff.union ec (handled P B h)) ∧
  HasTypeClausesQ P B Ψ Q C Γ Φ R eb.norm h t ec L
failure_body_widen : ∀ {P : Program} {B : Builtins} {Ψ : StoreTy}
  {Q : NoFailCtx} {C : List TParam} {Γ : Ctx} {Φ : List Pred} {R : Option Ty}
  {m : Comp} {t E : Ty} {eb rest : Eff} {L : LocalCtx},
  HasTypeCQ P B Ψ Q C Γ Φ R m t eb L → Eff.Sub eb (Eff.union (Eff.singleFail E) rest) →
  HasTypeCQ P B Ψ Q C Γ Φ R m t (Eff.union (Eff.singleFail E) rest) L
```

## 継続・let・依存列への供給（実装前）

```lean
CaptureOk.continuation_annotation : ∀ {P : Program} {B : Builtins} {Ψ : StoreTy}
  {R : Option Ty} {Γ : Ctx} {Φ : List Pred} {cap : Capture} {i : Nat}
  {b t : Ty} {e : Eff},
  CaptureOk P B Ψ R Γ Φ cap → Ψ.WF → Ψ.Sorted → StoreTy.Declared P Ψ →
  Γ[i]? = some (some (.cont b t e)) →
  Ty.Annotation P [] [] (cap.closeTy (.cont b t e))
CaptureOk.continuation_result_effect : ∀ {P : Program} {B : Builtins} {Ψ : StoreTy}
  {R : Option Ty} {Γ : Ctx} {Φ : List Pred} {cap : Capture} {i : Nat}
  {b t : Ty} {e : Eff},
  CaptureOk P B Ψ R Γ Φ cap → Ψ.WF → Ψ.Sorted → StoreTy.Declared P Ψ →
  Γ[i]? = some (some (.cont b t e)) →
  Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy t) (cap.closeEff e)))
capture_let_effect_annotations : ∀ {P : Program} {B : Builtins} {Ψ : StoreTy}
  {R Rs : Option Ty} {Γ : Ctx} {Φ : List Pred} {cap : Capture}
  {m : Comp} {a b : Ty} {e : Eff} {L : LocalCtx},
  P.WellFormed → P.WellTyped B → B.CoreAssumptions P →
  Ψ.WF → Ψ.Sorted → StoreTy.Declared P Ψ → CaptureOk P B Ψ R Γ Φ cap →
  HasTypeCQ P B Ψ Qempty [] Γ Φ Rs m a e L →
  Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy b) (cap.closeEff e))) →
  Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy a) (cap.closeEff e))) ∧
  Ty.Annotation P [] (bindParams [] [cap.closeTy a])
    (.dependentFn (.done (cap.closeTyAt 1 (b.shiftV 1 0)) (cap.closeEffAt 1 (e.shiftV 1 0))))
capture_tel_annotation : ∀ {P : Program} {B : Builtins} {Ψ : StoreTy}
  {R : Option Ty} {Γ : Ctx} {Φ : List Pred} {cap : Capture} {t : Tel},
  CaptureOk P B Ψ R Γ Φ cap → Ty.Annotation P [] Γ (.dependentFn t) →
  Ty.Annotation P [] [] (.dependentFn (cap.closeTel t))
```

E_Lam は全体の関数型の既存注釈の値置換、E_DependentLam は capture_tel_annotation、その後の全引数は open_telArgs_annotation を使う。具体化する引数の型付け自体は G02 に残る。効果の形成を、その全β保存と同一視しない。

## lambda と失敗節の投影（実装前）

```lean
capture_function_result_effect : ∀ {P : Program} {B : Builtins} {Ψ : StoreTy}
  {R : Option Ty} {Γ : Ctx} {Φ : List Pred} {cap : Capture}
  {ns : List String} {ps : List Ty} {r : Ty} {e : Eff},
  CaptureOk P B Ψ R Γ Φ cap → Ty.Annotation P [] Γ (.fn ns ps r e) →
  Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy r) (cap.closeEff e)))
HasFailureClause.capture_result_effect : ∀ {P : Program} {B : Builtins} {Ψ : StoreTy}
  {cap : Capture} {Γ : Ctx} {Φ : List Pred} {R Rs : Option Ty}
  {E t : Ty} {ec : Eff} {h : List Clause} {L : LocalCtx},
  CaptureOk P B Ψ R Γ Φ cap → HasFailureClause P B Ψ Qempty [] Γ Φ E Rs h t ec L →
  Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy t) (cap.closeEff ec)))
```

## 60分以内の見直し

更新時刻は `2026-11-01T17:42:33.339536+00:00`（開始から外側 989.3 秒）。全53規則と Vs/Each/Arms/TelArgs の全枝、捕捉への二系、弱い5 case、extendNone を含む逆 shift、S01b の必要な効果供給は本番で閉じた。未証明の A2 の枝は0である。完全署名の Lean 印字は [public-signatures.log](public-signatures.log) に33件を保存した。宣言一覧は [declarations.json](declarations.json)。実装時の型推論の明示化は行ったが、既存の型付け・状態・移送の署名と定義は変えていない。

最初の未証明枝の表は保存時点の記録として保つ。現在の各行の判定は [gate.md](gate.md) と [annotation-sources.md](annotation-sources.md) を正とする。初期の safe 候補は使わず、閉じた Fail の包含から元の本体行の形成を得た。新たな型付けの規則や独立仮定を必要としない。

作業末の work は終了0（8.212秒）、公理依存は終了0（1.897秒）。残りは成果物の自己照合・結果文書の保存で10〜20分の見込み、独立レビュー・取り込み・受け入れは不明である。今回の短い実績を、未経験の後続の型置換・全状態保存へ倍率として適用しない。

## r1: レビュー対応の署名（実装前）

2026-11-02。使用しない Program.WellFormed・WellTyped・CoreAssumptions の三前提の削除は、RV-L20.a2 軽4と今回の依頼で承認された変更である。型付けの主定理・規則の前提は変更しない。HasTypeClausesQ.same_input_atoms・handle_body_normalize・failure_body_widen は使用先がないため除く。新規の証明はレビュー付録 inv1/let1/rest を本番へ移す。

境界の契約は、非空の実際の捕捉を介する結果形成と hide の下の適用である。捕捉の射影の誤接続・三条件の hide の欠落を捕まえ、空の文脈だけの既存境界では届かない。試験専用の本番フックは不要である。test-audit の作成時の関門をこの二境界に適用する。

```lean
theorem open_value_annotation {P : Program} {B : Builtins} {Ψ : StoreTy}
    {Q : NoFailCtx} {C : List TParam} {Γ : Ctx} {Φ : List Pred} {v : Val} {a : Ty}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hΓ : CaptureContextRegular P C Γ) (h : HasTypeVQ P B Ψ Q C Γ Φ v a) :
    Ty.Annotation P C Γ a
```

```lean
theorem open_comp_annotation {P : Program} {B : Builtins} {Ψ : StoreTy}
    {Q : NoFailCtx} {C : List TParam} {Γ : Ctx} {Φ : List Pred}
    {R : Option Ty} {m : Comp} {a : Ty} {e : Eff} {L : LocalCtx}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hΓ : CaptureContextRegular P C Γ) (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L) :
    Ty.Annotation P C Γ a
```

```lean
theorem open_values_annotation {P B Ψ Q C Γ Φ vs as}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hΓ : CaptureContextRegular P C Γ) (h : HasTypeVsQ P B Ψ Q C Γ Φ vs as) :
    TypeAnnotations P C Γ as
```

```lean
theorem open_each_annotation {P B Ψ Q C Γ Φ vs a}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hΓ : CaptureContextRegular P C Γ) (h : HasTypeEachQ P B Ψ Q C Γ Φ vs a)
    (hne : vs ≠ []) : Ty.Annotation P C Γ a
```

```lean
theorem capture_value_annotation {P B Ψ R Γ Φ cap v a}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap) (hv : HasTypeVQ P B Ψ Qempty [] Γ Φ v a) :
    Ty.Annotation P [] [] (cap.closeTy a)
```

```lean
theorem capture_comp_annotation {P B Ψ R Γ Φ cap Rs m a e L}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap) (hm : HasTypeCQ P B Ψ Qempty [] Γ Φ Rs m a e L) :
    Ty.Annotation P [] [] (cap.closeTy a)
```

```lean
theorem capture_let_effect_annotations {P B Ψ R Rs Γ Φ cap m a b e L}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap) (hm : HasTypeCQ P B Ψ Qempty [] Γ Φ Rs m a e L)
    (ha : Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy b) (cap.closeEff e)))) :
    Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy a) (cap.closeEff e))) ∧
    Ty.Annotation P [] (bindParams [] [cap.closeTy a])
      (.dependentFn (.done (cap.closeTyAt 1 (b.shiftV 1 0)) (cap.closeEffAt 1 (e.shiftV 1 0))))
```

```lean
private theorem cover_close {Γ Φ outer inner} (cap : Capture) (h : Eff.Covers Γ Φ outer inner) :
    Eff.Covers [] [] (cap.closeEff outer) (cap.closeEff inner)
```

```lean
theorem done_inner {P cap Γ Φ a b outer inner}
    (ha : Ty.Annotation P [] [] (.dependentFn (.done a (Capture.closeEff cap outer))))
    (hb : Ty.Annotation P [] [] b) (hc : Eff.Covers Γ Φ outer inner) :
    Ty.Annotation P [] [] (.dependentFn (.done b (Capture.closeEff cap inner)))
```

```lean
theorem handle_inv {P B Ψ Q C Γ Φ Rs code m h a e L}
    (hm : HasTypeCQ P B Ψ Q C Γ Φ Rs code a e L) (hcode : code = .handle m h) :
    (∃ t εm ε, HasTypeCQ P B Ψ Q C Γ Φ Rs m t εm L ∧
      Eff.Sub εm (Eff.union ε (handled P B h)) ∧
      HasTypeClausesQ P B Ψ Q C Γ Φ Rs εm h t ε L ∧
      Eff.Covers Γ Φ e ε ∧ Ty.LeQ P Γ Φ t a) ∨
    (∃ t E eb rest ec, HasTypeCQ P B Ψ Q C Γ Φ Rs m t eb L ∧
      Eff.Sub eb (Eff.union (Eff.singleFail E) rest) ∧ NoFail Q rest ∧
      HasFailureClause P B Ψ Q C Γ Φ E Rs h t ec L ∧
      Eff.Covers Γ Φ e (Eff.union rest ec) ∧ Ty.LeQ P Γ Φ t a)
```

```lean
theorem e_handle_supply {P B Ψ R q m h a e1}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hq : ClosureTy P B Ψ [] R q a e1) (hv : q.view = .handle m h) :
    ∃ cap Γ Φ Rs m0 h0 L ρ, q = .mk cap (Comp.handle m0 h0 |>.resolveLocals ρ) ∧
      CaptureOk P B Ψ R Γ Φ cap ∧ CaptureLocals Ψ cap.env L ρ ∧
      ((∃ t εm ε, HasTypeCQ P B Ψ Benitoite.Release.Qempty [] Γ Φ Rs m0 t εm L ∧
          Eff.Sub εm (Eff.union ε (handled P B h0)) ∧
          HasTypeClausesQ P B Ψ Benitoite.Release.Qempty [] Γ Φ Rs εm h0 t ε L ∧
          Eff.Covers [] [] e1 (cap.closeEff ε) ∧
          Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy t) (cap.closeEff ε))) ∧
          Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy t) (cap.closeEff εm)))) ∨
       (∃ t E eb rest ec, HasTypeCQ P B Ψ Benitoite.Release.Qempty [] Γ Φ Rs m0 t eb L ∧
          Eff.Sub eb (Eff.union (Eff.singleFail E) rest) ∧ NoFail Benitoite.Release.Qempty rest ∧
          HasFailureClause P B Ψ Benitoite.Release.Qempty [] Γ Φ E Rs h0 t ec L ∧
          Eff.Covers [] [] e1 (cap.closeEff (Eff.union rest ec)) ∧
          Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy t) (cap.closeEff ec))) ∧
          Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy t) (cap.closeEff eb)))))
```

```lean
private theorem let_inv {P B Ψ Q C Γ Φ Rs code m n a e L}
    (hm : HasTypeCQ P B Ψ Q C Γ Φ Rs code a e L) (hcode : code = .letIn m n) :
    ∃ a0 b ε, HasTypeCQ P B Ψ Q C Γ Φ Rs m a0 ε L ∧
      HasTypeCQ P B Ψ Q C (Γ.extend a0) (Φ.map Pred.lift) (Rs.map (Ty.shiftV 1 0))
        n (b.shiftV 1 0) (Eff.shiftV 1 0 ε) (localExtend 1 L) ∧
      Ty.Declared P C Γ b ∧ HasTypeCQ P B Ψ Q C Γ Φ Rs (.letIn m n) b ε L ∧
      Eff.Covers Γ Φ e ε ∧ Ty.LeQ P Γ Φ b a
```

```lean
theorem ContTy.return_wf {P B σ Ψ R ε k a b Eb Re} (h : ContTy P B σ Ψ R ε k a b Eb Re)
    (hRe : Re = none) : ∀ r, R = some r → r.WF 0 0 0
```

```lean
theorem e_let_post {P B σ Ψ R q m n a e1 e k b Eb}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hq : ClosureTy P B Ψ [] R q a e1) (hsub : Eff.Sub e1 e)
    (hk : ContTy P B σ Ψ R e k a b Eb none)
    (hv : q.view = .letIn m n) (had : (Closure.mk q.capture n).Adequate σ) :
    ∃ a' e1', ClosureTy P B Ψ [] R (.mk q.capture m) a' e1' ∧ Eff.Sub e1' e ∧
      ContTy P B σ Ψ R e (.letF (.mk q.capture n) :: k) a' b Eb none
```

```lean
theorem split_fail_annotated {P B σ Ψ R ε k a b Eb Re cap E0 body k1 k2}
    (h : ContTy P B σ Ψ R ε k a b Eb Re)
    (he : k = k1 ++ .handleF cap [.fail E0 body] :: k2) :
    ∃ t ec et Rh, ContTy P B σ Ψ R ε (k1 ++ [.handleF cap [.fail E0 body]]) a t (.mk et.atoms ec.fails) Rh ∧
      ContTy P B σ Ψ Rh et k2 t b Eb Re ∧ Eff.Covers [] [] et ec ∧ Eff.Sub (.mk et.atoms ec.fails) et ∧
        Ty.Annotation P [] [] (.dependentFn (.done t ec))
```


## r1 の局所確認

新しい本番の補題は最初の局所型検査で終了0、局所ビルドは182 jobs・終了0。公開36宣言の現行の完全署名は [r1/public-signatures.log](r1/public-signatures.log) に保存した。初回の33署名のログは当時の記録として保持する。使用しない三前提を外す公開署名は open_value_annotation・open_comp_annotation・open_values_annotation・open_each_annotation・capture_value_annotation・capture_comp_annotation・capture_let_effect_annotations の7件である。主な十移送と状態の定義の署名は変更していない。
