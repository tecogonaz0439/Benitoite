# RV-L20.a4: 形式化の群 L20 A4（方式の関門 (d)）の独立レビュー

2026-11-02。対象は基準 `d243526e` からの未コミットの作業木（ブランチ `m014/l20.a4`）。依頼の九つの観点を、実装側の判定を前提にせず Lean を読み、補助の入力で確かめた。既存のファイルは変えていない。

## 総合判定

**条件付き可**（重 0、中 1、軽 5）。**関門 (d) の通過の判定に同意する。** Lean の本体に誤りを見つけなかった。条件は計画の文書の整合（中1）であり、本体の変更を要しない。

後続への使える形は、言明の読み取りだけでなく実際に確かめた。`valueMeaning_sub` を使い、値の型付けの全場合（V29・Vs2・Each2）から `ValueMeaning`、さらに `Inhabits P a.norm v` までを補助の入力で閉じた。`sorry` なし、公理は `propext`・`Classical.choice`・`Quot.sound` だけである（付録）。

## 自分で確かめた結果

| 項目 | 結果 |
|---|---|
| 本体の再検査 | 三つの `.lean` を `lake env lean -M 12288` で単独に検査し、全て終了0、誤り・警告なし。各約0.3〜0.5秒、最大常駐量は約0.78〜0.81 GB |
| 検査した状態 | 本体3件・`Benitoite.lean`・01-12・07-04・`axioms.lean` の SHA-256 は results.md の表と一致。`lake build --no-build` は 527 ジョブ全てが最新 |
| S07 の字面 | 計画 S07 の全称を写した `example` が `@valueMeaning_sub` で型検査を通る。前提は `VarianceValid`・`LeQ`・facts の真・元の意味の四つだけである |
| 公理依存 | `valueMeaning_sub`・`outer_complete`・`meaning_order_sound`・`valueMeaning_field_mono`・`field_order`・`ordinary_supply_counterexample` は既定の三公理だけ |
| 抜け道 | 三モジュールの全宣言を環境から走査し、`unsafe`・`partial`・`axiom` は0件。ソースに `decreasing_by`・`termination_by`・`sorry`・`native_decide`・`implemented_by`・`set_option` もない |
| 宣言の数 | MeaningOrder 98・MeaningTransport 32・Obstruction 22。results.md の152件と一致する。全174件の内訳（152＋21＋1）も `axioms.lean` と一致する |
| 既存の不変 | `git diff d243526e -- formal/` は `Benitoite.lean` の4行の import だけである。ほかの Lean は全て新規ファイルであり、主な10言明と旧 `Release` の字面は変わっていない |
| 四族の規則数 | 環境から LeQ 14・TelLe 2・TelClosure 2・TypeArgsLe 4、計22を確認。MeaningLe 13・MeaningArgs 4 |

## 観点ごとの所見（読めば確定する事項）

### 1. `valueMeaning_sub` の言明

前提を足していない。`P.VarianceValid` の使用は `order_data` の経路の `(valid.2 c cd lookup).2 a ha |>.2.2`、すなわち構成子の欄の `VarianceOK P (P.varianceFor cd.data cd.ntys) .positive` だけである。`cd.ntys = ts.length` を `arity` で渡すので、`Ty.LeQ.data` の `P.varianceFor d as.length` と同じ列を読む。metadata のない data は `varianceFor` が全て不変の列を返すので、不変の枝へ落ちる。

### 2. `MeaningLe`・`MeaningArgs`

意味を保つことは `outer_complete` が全構成子について証明している。元の22規則の写しに抜けはない。`of_le` は LeQ の14規則を全て写す。`fn_effect` は `.fn`、`lazy`・`map_value` は内部を捨てる構成子へ写す。`dependentFn` は TelClosure の導出を捨てるので、TelLe・TelClosure の4規則は読まれない。`ValueShapeMeaning.dependentFn`・`fn` が任意の値を認めるので、これで正しい。`of_args` は TypeArgsLe の4規則を写す。

- `.tvar`: `MeaningEnvRel.param` が `vs[i]?` の変性と `accepts` を読む。共変は positive、反変は negative、不変はどちらも受け、不変の成分は `convert` で正規形の等号を比較へ持ち上げる。
- 反変: `PolarArgs .negative` は左右の列を入れ替える。`PolarArgs.cons` の共変・反変・不変の全組を確かめた。正の欄の `D2 [tvar 0]` で D2 が反変なら合成は negative になり、`MeaningArgs` の反変の成分 `b ≤ a` と向きが合う。
- 不変の位置: `MeaningArgs.invariant_cons` の前提は元と同じ正規形の等号であり、緩めていない。`reference`・`set`・`dict`・`cont`・`external`・`tapp` は `VarianceOK` が `.both` を要求し、`Ty.VarianceOK.invariant` の等号を `of_norm_eq` で渡す。これらに専用の `MeaningLe` の構成子はない。
- 緩めた箇所: `MeaningLe.lazy`・`map`・`fn`・`dependentFn` は内部を比較せず、`map` は鍵の型の等号も持たない。これは `LeQ` より広いが、対応する形の意味が値を読まないので健全である。設計書も型付けの判断でないと明記している。
- `refined`: 基底へ下り、`he.values` で述語を揃え、`.refine hr (.hyp mem_cons_self)` で同じ述語を保つ。元の `.refine` が要求する `Sorted` を要求しないのが、Ordinary を避けられた理由である。
- `opaque`・`scoped`: `he.ranges` による等号で閉じる。`scoped`・`scoped_forget` は既存の `ValueMeaning.scoped_covers`・`scoped_forget` を使う。

### 3. 外側の帰納

`outer_complete` は `Nat.strongRecOn` であり、`Below n` は `sizeOf w < n` に限って `Outer (sizeOf w)` を与える。子値の大きさは `Val.con.sizeOf_spec`・`Val.list.sizeOf_spec` と `List.sizeOf_lt_of_mem`、`omega` で導いている。`order_step` の内側は `MeaningLe.rec` の13枝を全て閉じ、`motive_2` は True である。`.data` と `.list` は内側の IH を使わず外側の IH だけを使う。`.trans`・`.refine` だけが同じ値の内側の IH を使う。元導出の IH と新導出の誤認はない。

### 4. `.refine`・`.trans`・`.data`

- `.trans`: 同じ η・facts の下で合成する。中間型の形成を使わない。
- `.refine`: `valueMeaning_refine` は `refined_iff` で基底と p に分ける。基底の真は `Ty.assume_eq_predicates`（Ordinary のとき）か `assume_eq_nil`（継続のとき）で分け、facts は `Pred.lift` の `interpret_lift_self` で `selfModel` へ移す。`Entails.sound` は `selfModel η v` で適用している。
- `.data`: `field_order` は同じ Γ・Φ のまま比較を作り、`ValueMeanings` は同じ η で下る。この経路に文脈の変わる位置はない。元の `variance_field_mono` が `lift` を要した関数の下は、`MeaningLe.fn` が内部を読まないので現れない。子の事実は同じ η を読むので、`Γ.facts ++ Φ` の前提もそのまま子へ下りる。`atError` の枝は `bs = []` を長さから導き、`const` の枝は全ての `Const` を反転する。

### 5. 後続への使える形

使える形である。付録の `typed_meaning` は、`match` が全場合を網羅したうえで次を証明した。

```lean
theorem probe_inhabits_of_typed {P : Program} {B Ψ v a} (valid : P.VarianceValid)
    (h : HasTypeVQ P B Ψ Qempty [] [] [] v a) : Inhabits P a.norm v
```

`Exhaustive` は `Inhabits P a.norm v` を読むので、`coverage v (probe_inhabits_of_typed ...)` でそのまま照合の成功が得られる。`Capture.meaning_coverage` の入力の形も `ValueMeaning P (fun _ => none) ...` で一致する。`V_AtError` は `shape.Declared` の `standard` から、構成子の要求する `StandardError` を作れる（`StandardError` は名前を読まず `errorType` だけを読む）。`V_Refine` は既存の補題になかった、閉じた項を開いた述語の二値の解釈と `selfModel` の解釈の一致を要するが、付録の `bridge_term`・`bridge_pred`・`refine_bridge` で短く閉じた。07-04・01-12 の「全域の解釈の既定値について無条件の不変性は要求しない」は情報の順序の話であり、この等号は全域の代入（全ての変数に項がある）なので妨げにならない。

継続型の上側近似は網羅性の健全性を損なわない。`Exhaustive` の入口は `Inhabits` であり、`ValueMeaning ⊂ Inhabits` は既に証明済みである。`cont` の形は任意の値を認めるので、継続型の入力に対する `Exhaustive` は全ての値の照合を要求し、より厳しい方向に働く。上側近似で受理の判定が甘くなる経路はない。data の欄の継続の型引数も同じである。

`MeaningTransportObstruction` の扱いも適切である。反例の型 `data MeaningBox [refined K p]` は `V_Con` の `TypeArgsKinded` で値の型付けを持たないが、この反例は S07 の前提だけからの供給を否定するものであり、言明もそう書いている。`axioms.lean` の `a4_nonordinary_transport` が S07 を同じ例へ適用して通ることも確かめた。全意味移送の反例と誤読される書き方はない。

なお、補助の入力の証明は `B.CoreAssumptions` を使っていない。S07 の `typed_value_meaning_closed` の署名のこの前提は不要である（観点9の補足）。

### 6. 字面・公理・import

上の表のとおり。既定の import に三モジュールがある。`sorry` と新しい公理はない。

### 7. 設計書の写し

定義・規則・定理名は Lean と一致する。`field_order`・`variance_meaning`・`order_refine`・`outer_complete`・反例の条件の記述に誤りはない。不足は軽2・軽3に書く。

### 8. 規約

手元の絶対パス・docs/todo へのリンク・`work/` を出どころとする参照・「費用」の語・100 KB を超えるファイルは、`l20/a4/`・本体・設計書の差分に見つからなかった。設計書の差分に変更の経緯の文もない。造語は軽4に書く。

### 9. 群 H の差し引き

| 単位 | 判定 | 根拠 |
|---|---|---|
| L20.85 refl/convert/trans | **済み** | `of_le`、`order_step` の `convert`・`trans`、`order_trans` |
| L20.86 data/List | **済み** | `order_data`・`list_shape_meaning`。ただし `variance_field_mono` でなく `field_order` を使う（中1） |
| L20.87 篩と範囲 | **済み** | `forget`・`introduce`・`order_refine`・`scoped`・`scoped_forget`。`interpret` の真だけを扱い評価不能を真にしない |
| L20.88 全部分型 | **済み** | `valueMeaning_sub`。`fn_effect`・`lazy`・`map_value` の枝を閉じ、TelLe・TelClosure は `dependentFn` で読まれない |

**群 H の4単位（2時間45分〜6時間15分）は全て差し引ける。** `.85` の依存にあった `.55〜.60` も要らなくなる。証明は `Ty.LeQ` の bind を使わないからである。

補足として、群 I1 の依存も変わる。`.89〜.91` の依存は `.88` だけなので、`.27` の直後へ前倒しできる。付録で `.89〜.91` と `.93` の所属の系の核はできている。本番化に残るのは、`TypedMeaning.lean` への配置、`inhabits_of_typed_raw`（`Inhabits.norm_all_iff` の一行）、S07 の署名の前提の扱い、`.93` の Month・空型・非空 List・unknown への適用である。`.92` は S05（`.74〜.77`）に依存するので残る。

## 所見

いずれも読めば確定する事項である。推測による所見はない。

### 中1: 計画の義務の字面と本番の経路が食い違い、記録が義務の側を扱っていない

- 場所: `l20/detail.md` の 382 行（S07「現在の `variance_field_mono` を使う」）、406・428 行（S07a の `Ty.LeQ` の motive と `.data` の経路）、1327・1387 行（L20.26・.86）、1554 行（O005・A「定義と欄単調性を再実装しない」）。`l20/a4/gate.md` の 36 行、`results.md` の 20 行。
- 問題点: `variance_meaning` は `variance_field_mono` と同じ型の構造を別の関係で辿るので、欄単調性の再実装に当たる。r1 の指示と Ordinary の反例から、この選択自体は正当である。しかし gate.md と results.md は「O005・A … を閉じた」と書くだけで、O005・A の「再実装しない」との関係を述べていない。計画の字面のままでは、後の照合で義務の未達と読まれる。
- 修正案: 取りまとめが detail.md の上記の行を改める。S07・S07a の motive を `MeaningLe` の経路へ改め、O005・A の「再実装しない」に、`variance_field_mono` が値の型付けを要する Ordinary の入力を要求するため意味の側で別に持つという例外と理由を書く。あわせて群 H の4行を済みとし、依存（`.89` は `.27` へ）と 1465 行の G09 の積上げを直す。

### 軽1: 証明に使わない宣言を、証明の一部のように記している

- 場所: `MeaningTransport.lean` の 11〜25 行（`MLe`・`MTelLe`・`MTelClosure`・`MTypeArgs`）と 43〜50 行（`field_inputs`）、`gate.md` の 11 行、`signatures.md` の 34 行、`results.md` の 11 行、07-04 の 92 行。
- 問題点: これらの参照は `axioms.lean` の `#check` だけで、証明は使わない。gate.md の「元の相互四族の TelLe・TelClosure の成分は…True のままである」は、そのような帰納が存在するかのように読める。実際の帰納は `MeaningLe` だけである。
- 修正案: 四つの定義を消すか、「S07a の元の署名の控えで証明では使わない」と記す。`field_inputs` は `order_data` の内側の取り出しに使うか、消す。

### 軽2: 内部を読まない比較の列挙に `dependentFn` がない

- 場所: 01-12 の 3293 行、07-04 の 90 行、`gate.md` の 7 行、`signatures.md` の 58 行、`results.md` の 32 行。
- 問題点: 「関数・lazy・map」と書くが、`MeaningLe.dependentFn` も同じ扱いである。依存関数を「関数」に含めると読めなくはないが、TelLe・TelClosure が読まれない理由に当たるので明示がよい。
- 修正案: 「関数・依存関数・lazy・map」と書く。

### 軽3: `V_Sub` の代表の記述が全移送の後に残る

- 場所: 01-12 の 3299 行「現在の証明には…`V_Sub` の代表」、07-04 の 88 行。
- 問題点: 偽ではないが、全移送の証明を述べる新しい段の直後で、代表だけがあるように読める。
- 修正案: `valueMeaning_refine` を全移送の `refine` の枝として位置付ける。

### 軽4: 造語

- 場所: 01-12 の 3291 行と 07-04 の 92・815 行の「総称欄」、07-04 の 94・96・815 行の「全意味移送」。
- 問題点: どちらも用語集になく、この変更の前の 01-12・07-04 にもない。規約は独自の用語を避けることを求める。
- 修正案: 「総称欄」は「構成子の宣言の欄」、「全意味移送」は「任意の部分型に対する意味の移送」と書く。残すなら用語集へ加える。

### 軽5: 最大常駐量を記録していない

- 場所: `results.md` の 50 行。
- 問題点: 計画の結果の記録としては「未取得と理由」で足りるが、設計者の Lean の作業の決まりは作業末の最大常駐量の記録を求める。前の群では記録している。
- 修正案: 記録する。参考に、三つのファイルの単独の検査はそれぞれ約0.78〜0.81 GB だった。

## 付録: 補助の入力

`formal/` で `lake env lean -M 12288 <入力>` を実行し、終了0、`probe_inhabits_of_typed` の公理依存は既定の三公理だけだった。本番のコードではなく、関門の判断の根拠として残す。

```lean
import Lean
import Benitoite
open Benitoite.Release.Refinement Lean

-- 字面: 計画の S07 をそのまま写す
example : ∀ {P Γ Φ a b v η},
  Program.VarianceValid P → Ty.LeQ P Γ Φ a b →
  (∀ p ∈ Ctx.facts Γ ++ Φ, Pred.interpret η p = true) →
  ValueMeaning P η a v → ValueMeaning P η b v := @valueMeaning_sub

#print axioms valueMeaning_sub
#print axioms MeaningTransport.outer_complete
#print axioms MeaningTransport.meaning_order_sound
#print axioms MeaningTransport.valueMeaning_field_mono
#print axioms MeaningTransport.field_order
#print axioms MeaningTransportObstruction.ordinary_supply_counterexample

run_cmd do
  let env ← getEnv
  for n in [``Ty.LeQ, ``TelLe, ``TelClosure, ``TypeArgsLe, ``MeaningTransport.MeaningLe, ``MeaningTransport.MeaningArgs] do
    match env.find? n with
    | some (.inductInfo i) => logInfo m!"{n}: ctors={i.ctors.length} unsafe={i.isUnsafe}"
    | _ => throwError "none {n}"
  for mod in [`Benitoite.Release.Refinement.MeaningOrder, `Benitoite.Release.Refinement.MeaningTransport, `Benitoite.Release.Refinement.MeaningTransportObstruction] do
    let some idx := env.getModuleIdx? mod | throwError "x"
    let mut c : Nat := 0
    for (name, ci) in env.constants.toList do
      if env.getModuleIdxFor? name == some idx then
        c := c + 1
        if ci.isUnsafe || ci.isPartial then logInfo m!"UNSAFE {name}"
        if let .axiomInfo _ := ci then logInfo m!"AXIOM {name}"
    logInfo m!"{mod}: {c}"

namespace Benitoite.Release.Refinement
noncomputable section

-- 網羅性の後続: 意味→部分型→網羅へ
theorem probe_cover {P : Program} {a b v ps} (valid : P.VarianceValid)
    (sub : Ty.LeQ P [] [] a b) (m : ValueMeaning P (fun _ => none) a v) (cov : Exhaustive P b ps) :
    ∃ p ∈ ps, (matchVal p v).isSome :=
  cov v (valueMeaning_inhabits_normal (valueMeaning_sub valid sub (by simp [Ctx.facts]) m))

-- V_Con の段: 子の意味から data の意味
theorem probe_con {P η c cd ts tys vs}
    (lookup : P.cons c = some cd) (n : ts.length = cd.ntys)
    (wf : ∀ t ∈ cd.args, t.WF 0 cd.ntys 0)
    (fields : ValueMeanings P η (cd.args.map (Ty.subst ts [])) vs) :
    ValueMeaning P η (.data cd.data ts) (.con c tys vs) := by
  refine .mk ?_ (by intro p hp; cases hp)
  refine .con lookup (by simp [Ty.normTys_eq_map, n]) wf ?_
  have he : Ty.subst (Ty.normTys ts) [] = Ty.subst ts [] := funext (fun a => Ty.subst_norm_images a ts)
  rw [he]; exact fields

-- V_Refine の橋
mutual
  theorem bridge_term (u : Term) (ν : ObservationEnv) (ξ ζ : ObservationEnvModel)
      (h : ∀ i, ∃ s, ν i = some s ∧ s.observe ξ = ζ i ∧ s.interpret ξ = ζ i) :
      ∃ s, termBind? ν u = some s ∧ s.observe ξ = u.observe ζ ∧ s.interpret ξ = u.interpret ζ := by
    cases u with
    | var i => obtain ⟨s,a,b,c⟩ := h i; exact ⟨s,a,by simpa [Term.observe] using b,by simpa [Term.interpret] using c⟩
    | listValue xs => exact ⟨_,rfl,by simp [Term.observe,bridge_slots xs ν ξ ζ h],by simp [Term.interpret,bridge_slots xs ν ξ ζ h]⟩
    | setValue xs => exact ⟨_,rfl,by simp [Term.observe,bridge_slots xs ν ξ ζ h],by simp [Term.interpret,bridge_slots xs ν ξ ζ h]⟩
    | dataValue c xs => exact ⟨_,rfl,by simp [Term.observe,bridge_slots xs ν ξ ζ h],by simp [Term.interpret,bridge_slots xs ν ξ ζ h]⟩
    | mapValue ks vs => exact ⟨_,rfl,by simp [Term.observe,bridge_slots ks ν ξ ζ h,bridge_slots vs ν ξ ζ h],by simp [Term.interpret,bridge_slots ks ν ξ ζ h,bridge_slots vs ν ξ ζ h]⟩
    | field r t =>
      obtain ⟨s,a,b,c⟩ := bridge_term t ν ξ ζ h
      exact ⟨.field r s,by simp [termBind?,a],by simp only [Term.observe,b],by simp only [Term.interpret,c]⟩
    | measure m t =>
      obtain ⟨s,a,b,c⟩ := bridge_term t ν ξ ζ h
      exact ⟨.measure m s,by simp [termBind?,a],by simp only [Term.observe,b],by simp only [Term.interpret,c]⟩
    | add x y =>
      obtain ⟨s,a,b,c⟩ := bridge_term x ν ξ ζ h
      obtain ⟨s',a',b',c'⟩ := bridge_term y ν ξ ζ h
      exact ⟨.add s s',by simp [termBind?,a,a'],by simp only [Term.observe,b,b'],by simp only [Term.interpret,c,c']⟩
    | neg t =>
      obtain ⟨s,a,b,c⟩ := bridge_term t ν ξ ζ h
      exact ⟨.neg s,by simp [termBind?,a],by simp only [Term.observe,b],by simp only [Term.interpret,c]⟩
    | scale k t =>
      obtain ⟨s,a,b,c⟩ := bridge_term t ν ξ ζ h
      exact ⟨.scale k s,by simp [termBind?,a],by simp only [Term.observe,b],by simp only [Term.interpret,c]⟩
    | _ => exact ⟨_,rfl,rfl,rfl⟩
  theorem bridge_slots (xs : List (Option Term)) (ν : ObservationEnv) (ξ ζ : ObservationEnvModel)
      (h : ∀ i, ∃ s, ν i = some s ∧ s.observe ξ = ζ i ∧ s.interpret ξ = ζ i) :
      observeSlots ξ (bindSlots ν xs) = observeSlots ζ xs := by
    cases xs with
    | nil => rfl
    | cons x xs =>
      cases x with
      | none => simp [bindSlots,slotBind,observeSlots,bridge_slots xs ν ξ ζ h]
      | some t =>
        obtain ⟨s,a,b,_⟩ := bridge_term t ν ξ ζ h
        simp [bindSlots,slotBind,a,observeSlots,b,bridge_slots xs ν ξ ζ h]
end

theorem bridge_bind (u : Term) (ν ξ ζ) (h : ∀ i, ∃ s, ν i = some s ∧ Term.observe ξ s = ζ i ∧ Term.interpret ξ s = ζ i) :
    (termBind ν u).interpret ξ = u.interpret ζ := by
  obtain ⟨s,a,_,c⟩ := bridge_term u ν ξ ζ h
  simp [termBind,a,c]
theorem bridge_bind_o (u : Term) (ν ξ ζ) (h : ∀ i, ∃ s, ν i = some s ∧ Term.observe ξ s = ζ i ∧ Term.interpret ξ s = ζ i) :
    (termBind ν u).observe ξ = u.observe ζ := by
  obtain ⟨s,a,b,_⟩ := bridge_term u ν ξ ζ h
  simp [termBind,a,b]


theorem bridge_pred (p : Pred) (ν ξ ζ) (h : ∀ i, ∃ s, ν i = some s ∧ Term.observe ξ s = ζ i ∧ Term.interpret ξ s = ζ i) :
    (predBind ν p).interpret ξ = p.interpret ζ := by
  have key := fun u => bridge_bind u ν ξ ζ h
  induction p with
  | and p q a b => simp only [predBind,Pred.interpret,a,b]
  | or p q a b => simp only [predBind,Pred.interpret,a,b]
  | not p a => simp only [predBind,Pred.interpret,a]
  | _ => simp only [predBind,Pred.interpret,Pred.atomValue,integerAs,observeAs,key] <;> (try rfl)

/-- 値の項の最上位は field 等の演算を含まない -/
theorem toTerm_interpret {v : Val} {t : Term} (ht : v.toTerm? = some t) (η) : t.interpret η = t.observe η := by
  unfold Val.toTerm? at ht
  split at ht <;> cases ht <;> rfl

theorem refine_bridge {v t η} {p : Pred} (ht : v.toTerm? = some t) (hc : t.Closed)
    (hp : (p.open t).interpret η = true) : p.interpret (selfModel η v) = true := by
  have := bridge_pred p (fun i => match i with | 0 => some t | j+1 => some (.var j)) η (selfModel η v) (by
    intro i; cases i with
    | zero =>
      refine ⟨t,rfl,?_,?_⟩
      · simp [selfModel,selfObservation,ht,Term.observe_closed hc η]
      · rw [toTerm_interpret ht]; simp [selfModel,selfObservation,ht,Term.observe_closed hc η]
    | succ j => exact ⟨.var j,rfl,rfl,rfl⟩)
  rw [← this]; exact hp


theorem const_norm (c : Const) : (Const.type c).norm = Const.type c := by cases c <;> rfl
theorem const_meaning (P η) (c : Const) : ValueMeaning P η (Const.type c) (.const c) := by
  refine .mk ?_ ?_
  · rw [const_norm]; cases c <;> exact .const
  · rw [const_norm]; cases c <;> (intro p hp; cases hp)

theorem closed_of_refs {t : Term} (h : t.References []) : t.Closed :=
  Term.varsIn_mono h (fun i hi => by obtain ⟨a,ha,_⟩ := hi; simp at ha)

mutual
  theorem typed_meaning {P : Program} {B Ψ Q C Γ Φ v a} (valid : P.VarianceValid)
      (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hΓ : Γ = []) (hΦ : Φ = []) :
      ValueMeaning P (fun _ => none) a v := by
    match h with
    | .V_Var hg _ => subst hΓ; simp at hg
    | .V_Const _ => exact const_meaning P _ _
    | .V_Lam .. => exact .mk .fn (by intro p hp; cases hp)
    | .V_DependentLam .. | .V_Closure .. | .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. =>
      exact MeaningTransport.dependentFn_meaning
    | .V_ExternalHandle .. => exact .mk .external (by intro p hp; cases hp)
    | .V_PathBases .. => exact .mk .pathBases (by intro p hp; cases hp)
    | .V_ScopePattern .. => exact .mk .scopePattern (by intro p hp; cases hp)
    | .V_Checked .. => exact .of_scoped .checked
    | .V_CheckedRequest .. => exact .of_scoped .checkedRequest
    | .V_CheckedAt .. => exact .of_scoped .checkedAt
    | .V_AtError hs =>
      rw [hs.errorType_eq]
      exact .mk (.atError ⟨rfl,hs.standard.2⟩) (by intro p hp; cases hp)
    | .V_Map .. => exact .mk .map (by intro p hp; cases hp)
    | .V_Set .. => exact .mk .set (by intro p hp; cases hp)
    | .V_Dict .. => exact .mk .dict (by intro p hp; cases hp)
    | .V_Raise .. => exact .mk .fn (by intro p hp; cases hp)
    | .V_LocRef .. => exact .mk .reference (by intro p hp; cases hp)
    | .V_LocLazy .. => exact .mk .lazy (by intro p hp; cases hp)
    | .V_Bytes .. => exact .mk .bytes (by intro p hp; cases hp)
    | .V_Con lookup n _ wf hs _ =>
      exact probe_con lookup n wf (typed_meanings valid hs hΓ hΦ)
    | .V_Super .. => exact .mk .dict (by intro p hp; cases hp)
    | .V_List hs .. =>
      exact .mk (.list (typed_each_norm valid hs hΓ hΦ)) (by intro p hp; cases hp)
    | .V_Sub hv sub .. =>
      have m := typed_meaning valid hv hΓ hΦ
      subst hΓ hΦ
      exact valueMeaning_sub valid sub (by simp [Ctx.facts]) m
    | .V_Normal hv => exact (ValueMeaning.norm_iff _ _ _ _).mpr (typed_meaning valid hv hΓ hΦ)
    | .V_Refine hv _ ht _ _ he .. =>
      have m := typed_meaning valid hv hΓ hΦ
      subst hΓ hΦ
      refine ValueMeaning.refined_iff.mpr ⟨m, ?_⟩
      have href := hv.observation_references ht
      exact refine_bridge ht (closed_of_refs href) (he.sound _ (by simp [Ctx.facts]))
  theorem typed_meanings {P : Program} {B Ψ Q C Γ Φ vs as} (valid : P.VarianceValid)
      (h : HasTypeVsQ P B Ψ Q C Γ Φ vs as) (hΓ : Γ = []) (hΦ : Φ = []) :
      ValueMeanings P (fun _ => none) as vs := by
    match h with
    | .nil => exact .nil
    | .cons hv hs => exact .cons (typed_meaning valid hv hΓ hΦ) (typed_meanings valid hs hΓ hΦ)
  theorem typed_each_norm {P : Program} {B Ψ Q C Γ Φ vs a} (valid : P.VarianceValid)
      (h : HasTypeEachQ P B Ψ Q C Γ Φ vs a) (hΓ : Γ = []) (hΦ : Φ = []) :
      ValueMeaningEach P (fun _ => none) a.norm vs := by
    match h with
    | .nil => exact .nil
    | .cons hv hs =>
      exact .cons ((ValueMeaning.norm_iff _ _ _ _).mpr (typed_meaning valid hv hΓ hΦ))
        (typed_each_norm valid hs hΓ hΦ)
end

theorem probe_inhabits_of_typed {P : Program} {B Ψ v a} (valid : P.VarianceValid)
    (h : HasTypeVQ P B Ψ Qempty [] [] [] v a) : Inhabits P a.norm v :=
  valueMeaning_inhabits_normal (typed_meaning valid h rfl rfl)

end
end Benitoite.Release.Refinement

#print axioms Benitoite.Release.Refinement.refine_bridge
#print axioms Benitoite.Release.Refinement.probe_con
#print axioms Benitoite.Release.Refinement.probe_cover
#print axioms Benitoite.Release.Refinement.probe_inhabits_of_typed
```

## 取りまとめの追記

全所見を群 A4 の再開で処置した。関門 (d) は通過とする。L20.85〜.88 は済みとして見込みから差し引いた。全33場合の型付けからの所属は L20.89〜.93 の担当である。
