# L00b.13: 値の葉の完全署名

2026-11-01。指定ブランチは `m014/l00b.13`、B_WORK は `40311429fea38171b53f7e909096c63222ce06e5` である。実装前に本書を置き、同じ起動で実装する。名前空間の共通接頭辞は `Benitoite.Release.Refinement` とする。暗黙引数 `P B Ψ Q C Γ Φ` は既存の HasTypeVQ と同じ型を持つ。

## 事実の抽出

既存の `HasTypeVQ.assume`、`Ty.LeQ.assume`、`HasTypeVQ.inv_list` を再利用する。篩の述語は正規化した有限列として読む。型の最外の構成子による一段の逆転に限定しない。

```lean
theorem HasTypeVQ.facts {P B Ψ Q C Γ Φ v a t}
  (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (ht : v.toTerm? = some t) :
  ∀ p ∈ a.assume, Entails (Γ.facts ++ Φ) (p.open t)

theorem HasTypeVQ.subtype_facts {P B Ψ Q C Γ Φ v a b t}
  (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hl : Ty.LeQ Γ Φ a b)
  (ht : v.toTerm? = some t) :
  ∀ p ∈ b.assume, Entails (Γ.facts ++ Φ) (p.open t)

theorem HasTypeVQ.inv_const {P B Ψ Q C Γ Φ v T c}
  (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .const c) :
  ConstOK B c ∧ T.norm.core = c.type.norm.core

theorem HasTypeVQ.integer_facts {P B Ψ Q C Γ Φ T n}
  (h : HasTypeVQ P B Ψ Q C Γ Φ (.const (.integer n)) T) :
  ConstOK B (.integer n) ∧ T.norm.core = .base .integer ∧
  ∀ p ∈ T.assume, Entails (Γ.facts ++ Φ) (p.open (.integer n.toInt))

theorem HasTypeEachQ.member {P B Ψ Q C Γ Φ vs a v}
  (h : HasTypeEachQ P B Ψ Q C Γ Φ vs a) (hv : v ∈ vs) :
  HasTypeVQ P B Ψ Q C Γ Φ v a

theorem HasTypeVsQ.get {P B Ψ Q C Γ Φ vs as i a}
  (h : HasTypeVsQ P B Ψ Q C Γ Φ vs as) (ha : as[i]? = some a) :
  ∃ v, vs[i]? = some v ∧ HasTypeVQ P B Ψ Q C Γ Φ v a

theorem HasTypeVQ.list_facts {P B Ψ Q C Γ Φ v T vs}
  (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .list vs) :
  (∃ a b, HasTypeEachQ P B Ψ Q C Γ Φ vs a ∧
    T.listCore = some b ∧ Ty.LeQ Γ Φ a b) ∧
  ∀ p ∈ T.assume, Entails (Γ.facts ++ Φ) (p.open (.listValue (Val.toTermSlots vs)))

theorem HasTypeVQ.inv_con {P B Ψ Q C Γ Φ v T c ts vs}
  (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .con c ts vs) :
  ∃ cd, P.cons c = some cd ∧ ts.length = cd.ntys ∧
    HasTypeVsQ P B Ψ Q C Γ Φ vs (cd.args.map (Ty.subst ts [])) ∧
    T.norm.core = .data cd.data (Ty.normTys ts)

theorem HasTypeVQ.con_field {P B Ψ Q C Γ Φ T c ts vs cd i a}
  (h : HasTypeVQ P B Ψ Q C Γ Φ (.con c ts vs) T)
  (hc : P.cons c = some cd) (ha : cd.args[i]? = some a) :
  ∃ v, vs[i]? = some v ∧ HasTypeVQ P B Ψ Q C Γ Φ v (a.subst ts [])

theorem HasTypeVQ.field_facts {P B Ψ Q C Γ Φ T c ts vs cd i a t}
  (h : HasTypeVQ P B Ψ Q C Γ Φ (.con c ts vs) T)
  (hc : P.cons c = some cd) (ha : cd.args[i]? = some a)
  (ht : (Val.toTermSlots vs)[i]? = some (some t)) :
  ∀ p ∈ (a.subst ts []).assume, Entails (Γ.facts ++ Φ) (p.open t)
```

`inv_const` に使う補助は `Ty.LeQ.constCore` とし、`ConstOK` を保ち、左辺の芯が定数の型の芯なら右辺も同じ芯となることを示す。`inv_con` は既存 `Ty.LeQ.dataCore_source` の順方向版 `dataCore` を使う。data の変性を新設せず、現行の不変な型引数の正規化後の等号を返す。

## 保持値と要求

```lean
def Ty.Holds (a : Ty) (o : OpaqueName) (k : Scope.Domain.Kind) (ix : RangeIx) : Prop :=
  a.norm.core = .scoped o k ix ∨ a.norm.core = .opaque o ix

theorem Ty.LeQ.holds {Γ Φ a b o k ix}
  (h : Ty.LeQ Γ Φ a b) (ha : a.Holds o k ix) :
  ∃ jx, b.Holds o k jx ∧ jx.Covers ix

theorem HasTypeVQ.inv_checked {P B Ψ Q C Γ Φ v T target}
  (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .checked target) :
  ∃ o k range ix, B.valKind o = some k ∧ B.valContent o = none ∧
    Scope.Domain.Range.MemK k range target ∧ T.Holds o k ix ∧
    ix.Covers (.fixed (.absolute range))

theorem HasTypeVQ.inv_checkedRequest {P B Ψ Q C Γ Φ v T target req}
  (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .checkedRequest target req) :
  ∃ o range A ix, B.valKind o = some .endpoint ∧ B.valContent o = some A ∧
    HasTypeV P B Ψ [] [] [] req A.norm ∧ groundVal req = true ∧
    req.reqTarget = some target ∧ Scope.Domain.Range.MemK .endpoint range target ∧
    T.Holds o .endpoint ix ∧ ix.Covers (.fixed (.absolute range))

theorem HasTypeVQ.checkedRequest_facts {P B Ψ Q C Γ Φ T target req}
  (h : HasTypeVQ P B Ψ Q C Γ Φ (.checkedRequest target req) T) :
  ∃ A, HasTypeV P B Ψ [] [] [] req A.norm ∧ groundVal req = true ∧
    req.reqTarget = some target ∧
    ∀ t, req.toTerm? = some t → ∀ p ∈ A.assume, Entails [] (p.open t)

theorem HasTypeVQ.checkedRequest_mismatch {P B Ψ Q C Γ Φ T target req}
  (ht : req.reqTarget ≠ some target) :
  ¬ HasTypeVQ P B Ψ Q C Γ Φ (.checkedRequest target req) T
```

`checked_without_request` は、`B.valContent o ≠ none` と型の `Holds o k ix` から `.checked target` の型付けを否定する。裸の `.opaque o id` には `inv_const` が `ConstOK` の両欄を返すため、標準対象の裸 opaque を排除し、通常資源の opaque を残す。

`checked_widen` と `checkedRequest_widen` は、元の所属と範囲の Covers から同じ値の `.scoped o k (.fixed outer)` を作る。`outer = .top` を含む。`scoped_forget` 後にも保持内容は変わらない。範囲を狭める導入は加えない。

## 計算可能な前提と HTTP の接続

D20/O049 は `V_CheckedRequest` の前提を `groundVal req = true` と定めるが、開始版の当該欄は `req.Ground` であった。D20 の承認済みの条件を本番の規則に反映する。`CheckedWitness.request` と、それを構成する `checkedRequest_opaque` / `absolute_request` の同じ欄も揃える。`Typing` は `AtPrepare` の既存の判定を import し、判定の定義を複製しない。Ground を要る既存の葉は `groundVal_ground` で導く。型付きの要求・固定した reqTarget・valContent の正規形・範囲の所属の欄と、主な定理の前提と結論は変えない。

`Refinement.TargetTable.valContent` は旧表の `Option.map embedTy`、`clientRequestTy` は旧表の型の埋め込みとする。`Refinement.ModelHttp.valueRun` は旧モデルと同じ、groundVal を検査して保持要求を返す計算とし、不正な入力の fallback は旧モデルの `defaultRequest` の埋め込みとする。`valueRun_checkedRequest` は判定成功から `.val req` との等号を返す。`valueRun_typed` は `inv_checkedRequest` の同じ A の型付け・Ground・射影結果を返す。旧モデルとの groundVal と射影の交換も埋め込みに対して示す。実表全体の信頼条件の充足は L60 に残す。

## 場合の数と L40 に残す範囲

予定: HasTypeVQ は29構成子、Ty.LeQ は13構成子、HasTypeEachQ/HasTypeVsQ は各2構成子。逆転は29場合を尽くし、該当する葉と三つの包み（Sub/Normal/Refine）以外を形の矛盾で閉じる。LeQ の構造補題は13場合を尽くす。構成子の増減は予定しない。変更した ground の欄に対する既存三族の全76場合もビルドで閉じる。

O030/O047 は今回の値の葉と facts の接続を閉じ、L40 に全 canonical forms（閉じた値から値の形を得る向き、関数・Map/Set・辞書・参照・lazy 等）、全 δ/return/状態に対する合成を残す。O049 は今回、保持要求の逆転・計算可能な前提・固定 reqTarget・HTTP 射影を閉じ、L10/L50 に旧導出の適格な埋め込みと全対象の具体化、L60 に三モデルの条件の充足を残す。L00b.14a には進まない。

## 補助契約の決定の記録

| 論点 | 採る案・理由・捨てる案 |
|---|---|
| 実観測の facts | `toTerm? = some t` から既存 assume を特殊化する。欠落を整数0に置き換えて成功と呼ぶ案は採らない。一般の assume の署名は保つ |
| data の欄 | 実際の値の構成子 c と P.cons c の欄を読む。別の構成子の同じ位置の欄を読む案は採らない。複数構成子を持つ data にも適用できる |
| 保持値の部分型 | 正規化した芯の二形と、元の添字からの Covers を返す。全ての型の等号を返す案と、opaque への忘却で保持要求を捨てる案は採らない |
| Ground と判定 | D20 の bool の成功を規則から保持し、Ground は既存補題で導く。一般の Ground から bool の成功を要求する補題は偽なので置かない。これは新たな主定理の仮定ではなく、既に承認された葉の条件である |
| HTTP の配置 | 並置体系に同じ射影を置き、旧計算との交換を示す。旧モデルの信頼条件を直接新体系の証拠として使う案は採らない |

補助の選択は主定理が量化する一般の Γ/Φ/型像を制限しない。新しい公理、精密な外部状態、実表の追加の信頼条件は置かない。受信前の Outcome.Carrier から facts を直接取り出さず、受信後の元の型付けに葉を適用する。

## 実装中に具体化した補助署名

固定した範囲添字の WF は定義上 True なので、widen の補助に `outer.WF` を要求しない。範囲が構文上適格であることと、固定添字が変数の上限内にあることを混ぜないためである。主定理や利用者の形への追加条件を避ける選択である。

`HasTypeVQ.inv_checkedAt` は、同じ r/snapshot/target/request の `CheckedWitness` と、最終型の Holds および添字の Covers を返す。`CheckedWitness.request_content` は request=some req を反転し、valContent と元の型付け・bool の成功・固定 reqTarget を返す。`checkedAt_request_mismatch` と `checkedAt_without_request` は、それぞれ端点不一致と valContent の区分から型付けを否定する。旧来の checkedRequest だけに逆転を限る案は、At の遷移の到達値に使えないので採らない。

`HasTypeVQ.checkedRequest_content` は、`h : HasTypeVQ ... (.checkedRequest target req) T`、`ht : T.Holds o .endpoint ix`、`hc : B.valContent o = some A` から `HasTypeV ... req A.norm ∧ groundVal req = true ∧ req.reqTarget = some target` を返す。逆転が返す名前を Holds の一意性で固定するための補助であり、範囲の拡大や opaque への忘却を通った値にも使える。`ModelHttp.valueRun_request` は同じ前提から射影結果とその型付けを返す。存在量化した内容の型を、既知の標準表の型へ固定する入口を用意する選択であり、表の単射性を仮定する案は採らない。


## At の保持要求と射影

At が作る `.checkedAt r snapshot target (some req)` も、同じ `groundVal req = true` の成功から `.val req` を返す。射影の定義のこの枝と `valueRun_checkedAt`、`valueRun_checkedAt_typed`、`valueRun_checkedAt_request` を加える。後二つは `inv_checkedAt` と `CheckedWitness.request_content` を使い、同じ要求の型付け・Ground・固定 reqTarget を返す。既知の表の型を指定する版は Holds と valContent で内容の型を固定する。

旧値の埋め込みには checkedAt がないため、`valueRun_embed` の等号はそのまま保つ。At の新しい保持値を既定要求に置き換える案は、射影で要求全体を保つ契約を満たさないので採らない。旧モデルの変更、主定理の変更、外部状態の追加は要らない。


## 完成した公開宣言の全署名

下記は本番ソースの宣言の型である。暗黙引数・名前空間を含む Lean の解釈結果と、変更した既存四宣言の型は [public-api.log](public-api.log)、列挙の入口は [public-api.lean](public-api.lean) に置く。新規47宣言と既存四宣言を照合する。主な定理の前提と結論は変えていない。

```lean
theorem Benitoite.Release.Refinement.HasTypeVQ.facts {P B Ψ Q C Γ Φ v a t}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (ht : v.toTerm? = some t) :
    ∀ p ∈ a.assume, Entails (Γ.facts ++ Φ) (p.open t)

theorem Benitoite.Release.Refinement.HasTypeVQ.subtype_facts {P B Ψ Q C Γ Φ v a b t}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hl : Ty.LeQ Γ Φ a b)
    (ht : v.toTerm? = some t) :
    ∀ p ∈ b.assume, Entails (Γ.facts ++ Φ) (p.open t)

theorem Benitoite.Release.Refinement.Ty.LeQ.dataCore {Γ Φ a b d ts} (h : Ty.LeQ Γ Φ a b)
    (hd : a.norm.core = .data d ts) : b.norm.core = .data d ts

theorem Benitoite.Release.Refinement.Ty.LeQ.constCore {Γ Φ a b} {c : Const} (h : Ty.LeQ Γ Φ a b)
    (ha : a.norm.core = c.type.norm.core) : b.norm.core = c.type.norm.core

theorem Benitoite.Release.Refinement.HasTypeVQ.inv_const {P B Ψ Q C Γ Φ v T c}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .const c) :
    ConstOK B c ∧ T.norm.core = c.type.norm.core

theorem Benitoite.Release.Refinement.HasTypeVQ.integer_facts {P B Ψ Q C Γ Φ T n}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.const (.integer n)) T) :
    ConstOK B (.integer n) ∧ T.norm.core = .base .integer ∧
    ∀ p ∈ T.assume, Entails (Γ.facts ++ Φ) (p.open (.integer n.toInt))

theorem Benitoite.Release.Refinement.HasTypeEachQ.member {P B Ψ Q C Γ Φ vs a v}
    (h : HasTypeEachQ P B Ψ Q C Γ Φ vs a) (hv : v ∈ vs) :
    HasTypeVQ P B Ψ Q C Γ Φ v a

theorem Benitoite.Release.Refinement.HasTypeVsQ.get {P B Ψ Q C Γ Φ vs as} {i : Nat} {a : Ty}
    (h : HasTypeVsQ P B Ψ Q C Γ Φ vs as) (ha : as[i]? = some a) :
    ∃ v, vs[i]? = some v ∧ HasTypeVQ P B Ψ Q C Γ Φ v a

theorem Benitoite.Release.Refinement.HasTypeVQ.list_facts {P B Ψ Q C Γ Φ v T vs}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .list vs) :
    (∃ a b, HasTypeEachQ P B Ψ Q C Γ Φ vs a ∧
      T.listCore = some b ∧ Ty.LeQ Γ Φ a b) ∧
    ∀ p ∈ T.assume, Entails (Γ.facts ++ Φ) (p.open (.listValue (Val.toTermSlots vs)))

theorem Benitoite.Release.Refinement.HasTypeVQ.inv_con {P B Ψ Q C Γ Φ v T c ts vs}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .con c ts vs) :
    ∃ cd, P.cons c = some cd ∧ ts.length = cd.ntys ∧
      HasTypeVsQ P B Ψ Q C Γ Φ vs (cd.args.map (Ty.subst ts [])) ∧
      T.norm.core = .data cd.data (Ty.normTys ts)

theorem Benitoite.Release.Refinement.HasTypeVQ.con_field {P B Ψ Q C Γ Φ T c ts vs cd} {i : Nat} {a : Ty}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.con c ts vs) T)
    (hc : P.cons c = some cd) (ha : cd.args[i]? = some a) :
    ∃ v, vs[i]? = some v ∧ HasTypeVQ P B Ψ Q C Γ Φ v (a.subst ts [])

theorem Benitoite.Release.Refinement.HasTypeVQ.field_facts {P B Ψ Q C Γ Φ T c ts vs cd} {i : Nat} {a : Ty} {t : Term}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.con c ts vs) T)
    (hc : P.cons c = some cd) (ha : cd.args[i]? = some a)
    (ht : (Val.toTermSlots vs)[i]? = some (some t)) :
    ∀ p ∈ (a.subst ts []).assume, Entails (Γ.facts ++ Φ) (p.open t)

def Benitoite.Release.Refinement.Ty.Holds (a : Ty) (o : OpaqueName) (k : Scope.Domain.Kind) (ix : RangeIx) : Prop

theorem Benitoite.Release.Refinement.RangeIx.Covers.refl (ix : RangeIx) : ix.Covers ix

theorem Benitoite.Release.Refinement.RangeIx.Covers.trans {a b c : RangeIx} (h : a.Covers b) (g : b.Covers c) : a.Covers c

theorem Benitoite.Release.Refinement.Ty.holds_norm (a : Ty) (o k ix) : a.norm.Holds o k ix ↔ a.Holds o k ix

theorem Benitoite.Release.Refinement.Ty.holds_refined (a : Ty) (p : Pred) (o k ix) :
    (Ty.refined a p).Holds o k ix ↔ a.Holds o k ix

theorem Benitoite.Release.Refinement.Ty.Holds.unique_name {a : Ty} {o k ix o' k' ix'} (h : a.Holds o k ix)
    (g : a.Holds o' k' ix') : o = o'

theorem Benitoite.Release.Refinement.Ty.LeQ.holds {Γ Φ a b o k ix}
    (h : Ty.LeQ Γ Φ a b) (ha : a.Holds o k ix) :
    ∃ jx, b.Holds o k jx ∧ jx.Covers ix

theorem Benitoite.Release.Refinement.HasTypeVQ.inv_checked {P B Ψ Q C Γ Φ v T target}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .checked target) :
    ∃ o k range ix, B.valKind o = some k ∧ B.valContent o = none ∧
      Scope.Domain.Range.MemK k range target ∧ T.Holds o k ix ∧
      ix.Covers (.fixed (.absolute range))

theorem Benitoite.Release.Refinement.HasTypeVQ.inv_checkedRequest {P B Ψ Q C Γ Φ v T target req}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .checkedRequest target req) :
    ∃ o range A ix, B.valKind o = some .endpoint ∧ B.valContent o = some A ∧
      HasTypeV P B Ψ [] [] [] req A.norm ∧ groundVal req = true ∧
      req.reqTarget = some target ∧ Scope.Domain.Range.MemK .endpoint range target ∧
      T.Holds o .endpoint ix ∧ ix.Covers (.fixed (.absolute range))

theorem Benitoite.Release.Refinement.HasTypeVQ.checkedRequest_facts {P B Ψ Q C Γ Φ T target req}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.checkedRequest target req) T) :
    ∃ A : Ty, HasTypeV P B Ψ [] [] [] req A.norm ∧ groundVal req = true ∧
      req.reqTarget = some target ∧
      ∀ t, req.toTerm? = some t → ∀ p ∈ A.assume, Entails [] (p.open t)

theorem Benitoite.Release.Refinement.HasTypeVQ.checkedRequest_content {P B Ψ Q C Γ Φ T target req o ix A}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.checkedRequest target req) T)
    (ht : T.Holds o .endpoint ix) (hc : B.valContent o = some A) :
    HasTypeV P B Ψ [] [] [] req A.norm ∧ groundVal req = true ∧ req.reqTarget = some target

theorem Benitoite.Release.Refinement.HasTypeVQ.checkedRequest_mismatch {P B Ψ Q C Γ Φ T target req}
    (ht : req.reqTarget ≠ some target) :
    ¬ HasTypeVQ P B Ψ Q C Γ Φ (.checkedRequest target req) T

theorem Benitoite.Release.Refinement.HasTypeVQ.checked_without_request {P B Ψ Q C Γ Φ T target o k ix}
    (hc : B.valContent o ≠ none) (ht : T.Holds o k ix) :
    ¬ HasTypeVQ P B Ψ Q C Γ Φ (.checked target) T

theorem Benitoite.Release.Refinement.HasTypeVQ.checked_widen {P B Ψ Q C Γ Φ o k r t outer}
    (hk : B.valKind o = some k) (hc : B.valContent o = none)
    (hm : Scope.Domain.Range.MemK k r t) (hw : outer.Covers (.absolute r)) :
    HasTypeVQ P B Ψ Q C Γ Φ (.checked t) (.scoped o k (.fixed outer))

theorem Benitoite.Release.Refinement.HasTypeVQ.checkedRequest_widen {P B Ψ Q C Γ Φ o r t req A outer}
    (hk : B.valKind o = some .endpoint) (hc : B.valContent o = some A)
    (hh : HasTypeV P B Ψ [] [] [] req A.norm) (hg : groundVal req = true)
    (ht : req.reqTarget = some t) (hm : Scope.Domain.Range.MemK .endpoint r t)
    (hw : outer.Covers (.absolute r)) :
    HasTypeVQ P B Ψ Q C Γ Φ (.checkedRequest t req) (.scoped o .endpoint (.fixed outer))

theorem Benitoite.Release.Refinement.HasTypeVQ.inv_checkedAt {P B Ψ Q C Γ Φ v T r snapshot target req}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .checkedAt r snapshot target req) :
    ∃ o k ix, CheckedWitness P B Ψ o k r snapshot target req ∧
      T.Holds o k ix ∧ ix.Covers (.fixed r)

theorem Benitoite.Release.Refinement.CheckedWitness.request_content {P B Ψ o k r snapshot target req}
    (h : CheckedWitness P B Ψ o k r snapshot target (some req)) :
    k = .endpoint ∧ ∃ A, B.valContent o = some A ∧
      HasTypeV P B Ψ [] [] [] req A.norm ∧ groundVal req = true ∧ req.reqTarget = some target

theorem Benitoite.Release.Refinement.HasTypeVQ.checkedAt_request_mismatch {P B Ψ Q C Γ Φ T r snapshot target req}
    (ht : req.reqTarget ≠ some target) :
    ¬ HasTypeVQ P B Ψ Q C Γ Φ (.checkedAt r snapshot target (some req)) T

theorem Benitoite.Release.Refinement.HasTypeVQ.checkedAt_without_request {P B Ψ Q C Γ Φ T r snapshot target o k ix}
    (hc : B.valContent o ≠ none) (ht : T.Holds o k ix) :
    ¬ HasTypeVQ P B Ψ Q C Γ Φ (.checkedAt r snapshot target none) T

def Benitoite.Release.Refinement.TargetTable.clientRequestTy : Ty

def Benitoite.Release.Refinement.TargetTable.valContent (o : OpaqueName) : Option Ty

theorem Benitoite.Release.Refinement.TargetTable.request_content : valContent "Http.RequestIn" = some clientRequestTy

theorem Benitoite.Release.Refinement.TargetTable.path_content : valContent "Scope.PathIn" = none

def Benitoite.Release.Refinement.ModelHttp.valueRun : List Val → Outcome

theorem Benitoite.Release.Refinement.ModelHttp.valueRun_checkedRequest {target req} (hg : groundVal req = true) :
    valueRun [.checkedRequest target req] = .val req

theorem Benitoite.Release.Refinement.ModelHttp.valueRun_typed {P B Ψ Q C Γ Φ T target req}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.checkedRequest target req) T) :
    valueRun [.checkedRequest target req] = .val req ∧
      ∃ o A range ix, B.valContent o = some A ∧ HasTypeV P B Ψ [] [] [] req A.norm ∧
        req.Ground ∧ req.reqTarget = some target ∧
        Scope.Domain.Range.MemK .endpoint range target ∧ T.Holds o .endpoint ix ∧
        ix.Covers (.fixed (.absolute range))

theorem Benitoite.Release.Refinement.ModelHttp.valueRun_request {P B Ψ Q C Γ Φ T target req o ix A}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.checkedRequest target req) T)
    (ht : T.Holds o .endpoint ix) (hc : B.valContent o = some A) :
    valueRun [.checkedRequest target req] = .val req ∧
      HasTypeV P B Ψ [] [] [] req A.norm ∧ req.Ground ∧ req.reqTarget = some target

theorem Benitoite.Release.Refinement.ModelHttp.valueRun_checkedAt {r snapshot target req} (hg : groundVal req = true) :
    valueRun [.checkedAt r snapshot target (some req)] = .val req

theorem Benitoite.Release.Refinement.ModelHttp.valueRun_checkedAt_typed {P B Ψ Q C Γ Φ T r snapshot target req}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.checkedAt r snapshot target (some req)) T) :
    valueRun [.checkedAt r snapshot target (some req)] = .val req ∧
      ∃ o A, B.valContent o = some A ∧ HasTypeV P B Ψ [] [] [] req A.norm ∧
        req.Ground ∧ req.reqTarget = some target

theorem Benitoite.Release.Refinement.ModelHttp.valueRun_checkedAt_request {P B Ψ Q C Γ Φ T r snapshot target req o ix A}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.checkedAt r snapshot target (some req)) T)
    (ht : T.Holds o .endpoint ix) (hc : B.valContent o = some A) :
    valueRun [.checkedAt r snapshot target (some req)] = .val req ∧
      HasTypeV P B Ψ [] [] [] req A.norm ∧ req.Ground ∧ req.reqTarget = some target

theorem Benitoite.Release.Refinement.ModelHttp.groundTy_embed (a : Benitoite.Release.Ty) :
      groundTy (embedTy a) = Benitoite.Release.ModelHttp.groundTy a

theorem Benitoite.Release.Refinement.ModelHttp.groundTys_embed (as : List Benitoite.Release.Ty) :
      groundTys (embedTys as) = Benitoite.Release.ModelHttp.groundTys as

theorem Benitoite.Release.Refinement.ModelHttp.groundVal_embed (v : Benitoite.Release.Val) :
      groundVal (embedVal v) = Benitoite.Release.ModelHttp.groundVal v

theorem Benitoite.Release.Refinement.ModelHttp.groundVals_embed (vs : List Benitoite.Release.Val) :
      groundVals (embedVals vs) = Benitoite.Release.ModelHttp.groundVals vs

theorem Benitoite.Release.Refinement.ModelHttp.valueRun_embed (vs : List Benitoite.Release.Val) :
    valueRun (embedVals vs) = embedOutcome (Benitoite.Release.ModelHttp.valueRun vs)
```

## 最終の補助契約の補足

Holds の scoped の枝は名前・kind・添字を比較し、opaque の枝は名前と添字だけを比較する。opaque の kind をこの判断から復元せず、元の型付けの valKind の証拠を使う。名前を固定する補題は kind の一致を主張しない。

固定した添字の WF は True である。widen は元の所属と Covers だけを受け取り、範囲の WF や Normal を新しい入力条件にしない。値の最外の篩の facts は事実抽出へ、保持の型・要求・範囲の情報は逆転へ分けて返す。二つを独立に使えるので、主定理の導出へ新しい制約を加えない。

新規の逆転五本は各29場合（計145）、LeQ の構造補題三本は各13場合（計39）である。既存の assume と List の逆転を呼ぶ補題は、その証明の場合を複製していない。規則は増やさず、既存三族76場合と Step76場合を保つ。


## RV-L00b.13 の対応契約（2026-11-01）

中1は groundTy の refined の枝で基底型の判定と `decide (p.WF 1)` を連言する。述語は self だけを参照でき、外側の値を参照する述語は拒む。既存の構成的な Pred.wfDecidable を使う。groundTy_wf の既存の署名を保ち、判定成功から NotContCore を得る補助と、p.WF 1 の上限の拡大で追加の場合を閉じる。旧モデルを変更せず groundTy_embed 等の交換を保つ。

中2は次の補題を本番に置く。主定理と信頼条件を変更しない。

```lean
theorem AtPrepared.request {B cap kind name bases pattern input index snapshot pat target bound T}
  (hc : B.valContent name = some T)
  (h : AtPrepared B cap kind name bases pattern input index snapshot pat target bound) :
  groundVal (closeVal cap input) = true ∧
    ∃ t, (closeVal cap input).reqTarget = some t ∧ target = .absolute t

theorem Val.reqTarget_kind {v t} (h : v.reqTarget = some t) : t.kind = .endpoint

theorem checkAt.absolute {snapshot kind pat t0 bound t}
  (h : checkAt snapshot kind pat (.absolute t0) bound = .ok t) : t = t0
```

AtPrepared の要求・checkAt の成功・型付きの閉じた入力から CheckedWitness を作る補題も AtTyping に置く。準備から得る ground と reqTarget、URL の kind を別の仮定にしない。List 要素と型の側の data 引数の facts は rv-13-w2 の署名を保って ValueFacts に移す。非公開の補助の細部は、本番の定義を使う有限の逆転として確定する。

| 所見と送り先 | 残る義務 |
|---|---|
| 軽2・L40 | integer_facts は Integer 専用である。各幅の整数・Byte は inv_const と facts を接続し、各幅の契約の葉を置く |
| 軽4・L50 | PathIn の通常の checked を Top へ広げて inv_checked で逆転する正例、および checkedRequest_facts の直接の入口を確認する |
| 軽6・L50 | 標準表の valKind を旧 TargetTable.valKind と同じ形で並置し、valContent と合わせて具体化する |
| 軽7・L40 | atError の dataValue の観測と欄の facts を含む canonical forms を閉じる。inv_con の対象は con の値であり、atError は含まない |
| 中1・L00b.15 | D20/D28 の新旧対照へ、groundTy/groundVal が閉じた refined 型引数を受理する変更と、p.WF 1 の範囲を記録する |
| 中1・L30以降 | Pair[String{true},String] と空でない閉じた篩の型引数を持つ要求、開いた述語を持つ要求の比較入力を Rust/Lean の比較に送る。Rust の同じ入力の結果は今回未実行 |
| 中2・L40/L50 | 今回の準備・端点・checkAt の三補題と E_AtOk の代表を使い、全状態・全対象の保存へ合成する。三補題自体を未完へ戻さない |


### レビュー対応の確定した署名と補助の選択

新規の公開補題は次の8本である。初回分と合わせた55宣言、意味の変わる ground 判断等を含む12宣言、旧モデルとの交換5本の完全な型を public-api.log に列挙する。準備の非公開の末尾の検査を finishPreparation へ分け、元と同じ分岐と誤りを保った。prepareCore は Except.bind で三つの段階を明記し、成功する bind の逆転と末尾の結果の一致から AtPrepared.request を証明する。do の展開と全パターンを一度に逆転する案は、不必要な解析と分岐を展開するので採らない。公開する AtPrepare/AtPrepared の型は変えない。

```lean
theorem Benitoite.Release.Refinement.groundTy_notContCore {a : Ty} (h : groundTy a = true) : a.NotContCore

theorem Benitoite.Release.Refinement.AtPrepared.request {B cap kind name bases pattern input index snapshot pat target bound T}
    (hc : B.valContent name = some T)
    (h : AtPrepared B cap kind name bases pattern input index snapshot pat target bound) :
    groundVal (closeVal cap input) = true ∧
      ∃ t, (closeVal cap input).reqTarget = some t ∧ target = .absolute t

theorem Benitoite.Release.Refinement.parseUrlTarget_kind {s t} (h : parseUrlTarget s = some t) : t.kind = .endpoint

theorem Benitoite.Release.Refinement.Val.reqTarget_kind {v : Val} {t : Target} (h : v.reqTarget = some t) : t.kind = .endpoint

theorem Benitoite.Release.Refinement.checkAt.absolute {snapshot kind pat t0 bound t}
    (h : checkAt snapshot kind pat (.absolute t0) bound = .ok t) : t = t0

theorem Benitoite.Release.Refinement.CheckedWitness.of_prepared_request
    {P B Ψ cap name kind T bases pattern input index snapshot pat target bound t}
    (hk : B.valKind name = some kind) (hc : B.valContent name = some T)
    (hi : HasTypeV P B Ψ [] [] [] (closeVal cap input) T.norm)
    (hp : AtPrepared B cap kind name bases pattern input index snapshot pat target bound)
    (hv : ∀ σ, snapshot = some σ → σ.Valid)
    (ha : checkAt snapshot kind pat target bound = .ok t) :
    CheckedWitness P B Ψ name kind bound snapshot t (AtRequest B name (closeVal cap input))

theorem Benitoite.Release.Refinement.HasTypeVQ.list_element_facts {P B Ψ Q C Γ Φ T vs b v t}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.list vs) T) (hb : T.listCore = some b) (hv : v ∈ vs)
    (ht : v.toTerm? = some t) : ∀ p ∈ b.assume, Entails (Γ.facts ++ Φ) (p.open t)

theorem Benitoite.Release.Refinement.HasTypeVQ.field_facts_by_type {P B Ψ Q C Γ Φ T c ts vs cd us} {i : Nat} {a : Ty} {t : Term}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.con c ts vs) T) (hc : P.cons c = some cd)
    (hT : T.norm.core = .data cd.data us) (ha : cd.args[i]? = some a)
    (hs : (Val.toTermSlots vs)[i]? = some (some t)) :
    ∀ p ∈ (a.subst us []).assume, Entails (Γ.facts ++ Φ) (p.open t)
```

中1の true の例は標準の Http.ClientRequest の欄と Pair[String,String] の型付けを使う。空でない閉じた述語の例は `0 ≤ 1` を保持し、正規化でも述語を消さない。この例では、その型引数に合う欄型を宣言する。現行の data の不変性を共変へ変えてはいない。標準の欄への拡大を含む比較は L40 の変性と L30 以降の Rust/Lean の比較へ送る。

E_AtOk の例は cap の var 0 が返す生の要求を使い、準備の成功を実際に計算する。準備後の要求や URL の kind を補助の入力にせず、E_AtOk の前提から CheckedWitness.of_prepared_request で証拠を作る。遷移の出力に含まれる checkedAt の値を型付け、その値に ModelHttp.valueRun_checkedAt_typed を適用する。StateTy 内部の導出を取り出す一般定理は L40 に残る。
