# L00b.14d: Lazy の代表の完全署名（レビュー処置後）

2026-11-01。指定ブランチは `m014/l00b.14d`、B_WORK は `66c302eaec9d442d32073515772a0f036fd66762`。初回と再開の両方で git の操作は行わない。本書の公開宣言は定義1・補題19の20件である。暗黙変数も含めた elaboration 後の完全署名は [public-api.log](public-api.log) にあり、以下は本番のソースの署名を群ごとに示す。

## 承認された定義の変更

RV-L00b.14d 中1と plan の先頭の判断に従い、K_Update に閉じた格納型の注釈を加える。

```lean
| K_Update {R ε l k a b Eb Re} : Ψ l = some (.lazy a) →
    Ty.Annotation P [] [] a →
    ContTy P B σ Ψ R ε k a b Eb Re →
    ContTy P B σ Ψ none ε (.update l :: k) a b Eb Re
```

以前は lookup と末尾の ContTy だけであった。StateTyE が量化する ContTy はこの前提によって強くなる。force_thunk_transition が枠を積むとき、thunk の本体の ClosureTy.annotation から注釈を供給する。空のストアから始まる実行や利用者の書ける形は変わらず、新しい公理も要らない。StoreTy 全体に Sorted/Normal を加える案と、CellOk.done から一般の Sorted を導くための別の証明群を先取りする案は採らない。01-12 の K-Update への反映は L00b.15 の入力とし、今回設計書は変更しない。

旧 lazy_update_transition は現在のセルが thunk であるという m/hlcell を持っていた。新しい lazy_update_any_cell は両方を持たず、同じ Step と到達の保存を返す。定数の入口からも m/hlcell を除いた。重複した ClosureTy.return_const と、そのためだけの isRet は削除し、既存の ClosureTy.ret_const を使う。

## 共変な結果型の逆転

```lean
def Ty.lazyCore : Ty → Option Ty
  | .lazy a => some a
  | .refined a _ => a.lazyCore
  | _ => none

theorem Ty.lazyCore_norm (a : Ty) : a.norm.lazyCore = a.lazyCore.map Ty.norm

theorem Ty.LeQ.lazyCore {Γ Φ a b x}
    (h : Ty.LeQ Γ Φ a b) (ha : a.lazyCore = some x) :
    ∃ y, b.lazyCore = some y ∧ Ty.LeQ Γ Φ x y

theorem Ty.LeQ.lazyCore_right {Γ Φ a b y}
    (h : Ty.LeQ Γ Φ a b) (hb : b.lazyCore = some y) :
    ∃ x, a.lazyCore = some x ∧ Ty.LeQ Γ Φ x y

theorem HasTypeVQ.canonical_lazy {P B Ψ Q C Φ v T a}
    (h : HasTypeVQ P B Ψ Q C [] Φ v T) (ha : T.lazyCore = some a) :
    ∃ l b, v = .loc l ∧ Ψ l = some (.lazy b) ∧ Ty.LeQ [] Φ b a
```

## セルと更新枠の契約

```lean
theorem StoreOk.write_done {P B σ Ψ μ l a v}
    (h : StoreOk P B σ Ψ μ) (hl : Ψ l = some (.lazy a))
    (hv : HasTypeV P B Ψ [] [] [] v a) (ha : v.Adequate σ) :
    StoreOk P B σ Ψ (μ.set l (.done v))

theorem StoreOk.allocate_lazy {P B σ Ψ μ l a q}
    (h : StoreOk P B σ Ψ μ) (hA : Builtins.ValueAssumptions P B)
    (hl : μ l = none) (ht : Ty.Annotation P [] [] a)
    (hq : ClosureTy P B (hideBuilders Ψ) [] none q a Eff.empty) (ha : q.Adequate σ) :
    StoreOk P B σ (Ψ.put l (.lazy a)) (μ.set l (.thunk q))

theorem ContTy.update_inv {P B σ Ψ R ε k a b Eb Re l}
    (h : ContTy P B σ Ψ R ε (.update l :: k) a b Eb Re) :
    R = none ∧ ∃ x R', Ψ l = some (.lazy x) ∧ Ty.LeQ [] [] a x ∧
      Ty.Annotation P [] [] x ∧ ContTy P B σ Ψ R' ε k x b Eb Re

theorem lazy_no_sort (a : Ty) : (Ty.lazy a).sort? = none

theorem lazy_no_observation (l : Nat) : (Val.loc l).toTerm? = none

theorem lazy_no_observed_fact (l : Nat) (tests : List PathTest) :
    pathFacts (Val.loc l).toTerm? tests = []
```

## 実際の遷移に対する保存

```lean
theorem BuiltinArgs.force {P B Ψ b s ts es rs l r e}
    (h : BuiltinArgs P B Ψ b s ts es rs [.loc l] r e)
    (hs : s.StoreShape) (hk : s.kind = .force) :
    ∃ a, Ty.Annotation P [] [] a ∧ a.Normal ∧
      HasTypeV P B Ψ [] [] [] (.loc l) (.lazy a) ∧ r = a ∧ e = Eff.empty

theorem StateTyE.force_done_transition {P B σ Eb b ts es rs l k μ s v}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run (Closure.pure (.app (.prim b ts es rs) [.loc l])) k μ))
    (hs : B.sig b = some s) (hk : s.kind = .force) (hl : μ l = some (.done v)) :
    Step P B σ (.run (Closure.pure (.app (.prim b ts es rs) [.loc l])) k μ) none
      (.run (Closure.pure (.ret v)) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k μ)

theorem StateTyE.force_thunk_transition {P B σ Eb b ts es rs l k μ s m}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run (Closure.pure (.app (.prim b ts es rs) [.loc l])) k μ))
    (hs : B.sig b = some s) (hk : s.kind = .force) (hl : μ l = some (.thunk m)) :
    Step P B σ (.run (Closure.pure (.app (.prim b ts es rs) [.loc l])) k μ) none
      (.run m (.update l :: k) μ) ∧
    StateTyE P B σ Eb (.run m (.update l :: k) μ)

theorem ClosureTy.lazy_body {P B Ψ R q a e m}
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF)
    (h : ClosureTy P B Ψ [] R q a e) (hv : q.view = .lazyC m) :
    ∃ x, Ty.Annotation P [] [] x ∧
      ClosureTy P B (hideBuilders Ψ) [] none (.mk q.capture m) x Eff.empty ∧
      Ty.LeQ [] [] (.lazy x) a

theorem StateTyE.lazy_transition {P B σ Eb q m k μ l}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.view = .lazyC m) (hl : μ l = none) :
    Step P B σ (.run q k μ) none
      (.run (Closure.pure (.ret (.loc l))) k (μ.set l (.thunk (.mk q.capture m)))) ∧
    StateTyE P B σ Eb
      (.run (Closure.pure (.ret (.loc l))) k (μ.set l (.thunk (.mk q.capture m))))

theorem StateTyE.lazy_update_any_cell {P B σ Eb v l k μ}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run (Closure.pure (.ret v)) (.update l :: k) μ))
    (hc : closeVal Capture.empty v = v) :
    Step P B σ (.run (Closure.pure (.ret v)) (.update l :: k) μ) none
      (.run (Closure.pure (.ret v)) k (μ.set l (.done v))) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k (μ.set l (.done v)))

theorem StateTyE.lazy_update_const_transition {P B σ Eb q c l k μ}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run q (.update l :: k) μ))
    (hv : q.view = .ret (.const c)) :
    Step P B σ (.run q (.update l :: k) μ) none
      (.run (Closure.pure (.ret (.const c))) k (μ.set l (.done (.const c)))) ∧
    StateTyE P B σ Eb
      (.run (Closure.pure (.ret (.const c))) k (μ.set l (.done (.const c))))

theorem StateTyE.lazy_update_pop_error {P B σ Eb rs l k μ}
    (h : StateTyE P B σ Eb (.error rs (.update l :: k) μ)) :
    Step P B σ (.error rs (.update l :: k) μ) none (.error rs k μ) ∧
    StateTyE P B σ Eb (.error rs k μ)

theorem StateTyE.lazy_update_pop_exit {P B σ Eb n rs l k μ}
    (h : StateTyE P B σ Eb (.exit n rs (.update l :: k) μ)) :
    Step P B σ (.exit n rs (.update l :: k) μ) none (.exit n rs k μ) ∧
    StateTyE P B σ Eb (.exit n rs k μ)
```

## 場合の数と提供する代表

| 群 | 場合の数と範囲 |
|---|---|
| Lazy の実際の遷移 | E_Lazy・E_ForceDone・E_Force・E_Update・E_ErrPopUpdate・E_ExitPopUpdate の6種類。従来の4に、更新枠を降ろす2種類を加えた |
| 値・計算・LeQ | 29・24・13構成子。初回の LeQ=14 は誤数であり、13が正しい |
| ContTy | 10構成子。構成子を増減せず、K_Update の入力を一つ加えた |
| セルの移送 | 既存の6形を CellOk.store で移す。ReferenceStore の ContTy.store も注釈をそのまま移す |
| 相互三族・Step | 76・76のまま。規則の数と今回の代表の数を区別する |
| 公開宣言 | 旧19から return_const を1件削除し、更新枠を降ろす補題を2件追加した20件。旧 update の名前は any_cell へ置き換えた |

E_Lazy は任意の捕捉を開始から逆転する。force の呼出し元は pure とし、格納された thunk 自体の捕捉、継続の末尾、最終の結果型と Eb は任意である。E_Update の pure ret は closeVal の一致を実際の Step の照合に使う。定数の入口は任意の捕捉の view を扱う。いずれも到達の型付けや Φ を補助入力として仮定しない。

## 補助の契約の決定の記録

| 採る案 | 理由 | 捨てる案 |
|---|---|---|
| K_Update に Annotation を保持する | 実行が枠を作る force で導け、書戻し時に格納型の Sorted が得られる。承認済みの変更である | StoreTy 全体の強化、done への書戻しを L20 へ送る |
| any_cell は返り値の型 a で normal_return_tail を呼ぶ | 格納型 x の Normal は要らず、x への包含と注釈だけで値を書ける | 格納型を正規形に限定する |
| 定数の返却は ret_const を再利用する | より弱い既存の SubstitutionAssumptions で閉じた値の型付けが得られる | CoreAssumptions を受ける重複の return_const を残す |
| エラー・終了は更新枠だけを降ろす | 実際の2規則はストアを変えない。thunk の再評価の方針を新設しない | 失敗時に done を書く、形式のセルの状態を増やす |
| .force の StoreShape に kind の条件を足さない | force は新しい組み込み呼出しを合成しない。抽象の B の型付き入力と既存の表の条件で全補題が閉じ、前提の追加が不要である | 参照4項目との見かけの統一のために value kind を追加する |
| Lazy の格納型から呼出しの結果型を LeQ でつなぐ | Lazy の結果型の共変性を保つ | Reference と同じ正規化後等号を要求する |
| 捕捉の Φ は既存の閉じた導出で保持する | CaptureOk は実ストアを引数に取らず、set や done の上書きで事実を失わない | 状態へ別の経路条件や精密な外部状態を加える |
| 任意の継続末尾で mark を構成し直す | K_Sub の下の非正規形の mark でも返り値の正規形の型で受け取れる | 末尾を空に限定する、状態へ Normal を足す |
| data の部分的な像を保つ | 根と隣の不変な欄を残し、Lazy 欄だけを none にする | Lazy 欄を既定の整数で埋める、data 全体の観測を捨てる |

## 再入の記録と VM との照合

[01-12「ストア：可変のセルと明示遅延」](../../design/01-spec/01-12-core-calculus.md)は、ソースから始まる thunk の実行中に同じ場所を force することはないと定める。[02-08「明示遅延」](../../design/02-impl/02-08-vm.md#明示遅延)は、同じタスクの再入が起きたときは処理系の不具合とする。一方、型付きの抽象状態を量化する補題は、ソースからの到達を要求しない。boundary の Reentry と done の上書きは、この広い量化に含まれる形を確かめるものであり、仕様の到達不能の主張を変更しない。

VM は「評価の途中」に評価するタスクと待つタスクを持ち、別タスクの FORCE を待たせる。形式の Cell は thunk/done であり、この途中の状態とタスク待ちを直接持たない。到達不能の主張、同じタスクの不具合の扱い、別タスクの待機、取消・終了時の状態の戻し方を、L30 の同じ照合の入力とする。

## 境界の作成時の関門

test-audit の関門: 格納の篩、Lazy の共変性、捕捉の閉じた事実、done の上書き、エラー・終了でのセルの保持を守る。契約の消失、hlcell の再導入、書戻しの欠落、更新枠の残留、Lazy 欄の不正な観測という退行を捕まえる。初回の境界は done からの上書きと更新枠を降ろす入口を使わなかったため、UpdateCases を追加した。実際の StateTyE と Step を使い、専用の本番の差込み口は作らない。

## 分類と L20／L30／L40 へ残す分

分類は plan の指定どおり「一部」のままとする。現在のセルを限定しない書戻しと更新枠を降ろす保存は今回閉じ、L20 の残件から除いた。L20 へ残る任意の ret の view の closeVal の型保存は E_Return/E_Mark/E_HRet/E_Drop と共通であり、捕捉を持つ force の呼出し元も Reference の s4/s7 と同じ形である。二つとも L20 の全ストア・閉包・継続の保存の枠の内数として一度だけ数え、Lazy の追加見込みを計上しない。

L30 は上記の VM との対応と実表・Rust の共変性と観測を照合する。L40 は canonical_lazy と領域条件からセルが thunk/done であることを導いて進行へ合成する。全状態の保存・進行の完成とはしない。
