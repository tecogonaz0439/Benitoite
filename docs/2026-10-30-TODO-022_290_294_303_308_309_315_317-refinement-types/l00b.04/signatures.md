# L00b.04: 閉じた評価の完全署名

2026-10-31。B_WORK は `610bd4ebf54905d36c5ccaeb2f6126d7149448a4`、指定ブランチは `m014/l00b.04` である。git の照合・操作は行わない。本書を実装に先行して置く。共通依頼文、plan の2026-10-31の全行、O046/O169、前群の署名と申し送り、README の設計者の決定、l00a.06a の契約と l00a.16a の補題を継承する。

## 公開する定義と補題

以下の接頭辞は `Benitoite.Release.Refinement`。η は `ObservationEnvModel`、p/q は Pred、t は Term、b は Bool とする。補助の完全な型と全名は実装後の public-api.lean/log に保存する。新しい Lean 公理を置かない。

```text
Observation : Type
  integer Int | character Char | float64 UInt64 | float32 UInt32
  decimal Int Nat | boolean Bool | unitValue | string String
  listValue (List (Option Observation)) | bytesValue (List Nat)
  mapValue (List (Option Observation)) (List (Option Observation))
  setValue (List (Option Observation))
  dataValue ConName (List (Option Observation))
  targetValue (Option PathEnv) Scope.Domain.Target
ObservationEnvModel := Nat → Option Observation
Observation.sort : Observation → Sort
Observation.keyCode? : Observation → Option (List Nat)
Term.interpret : ObservationEnvModel → Term → Option Observation
Pred.interpret : ObservationEnvModel → Pred → Bool
Pred.evalClosed : Pred → Option Bool
Pred.ClosedObservable : Pred → Prop
Pred.evalClosed_sound : p.WF 0 → p.Sorted [] none →
  p.evalClosed = some b → p.interpret (fun _ => none) = b
Pred.evalClosed_complete : p.WF 0 → p.Sorted [] none →
  p.ClosedObservable → p.evalClosed = some (p.interpret (fun _ => none))
Pred.interpret_closed : p.WF 0 → p.interpret η = p.interpret (fun _ => none)
Pred.bind_closed : p.WF 0 → predBind ν p = p
Entails.ground : p.WF 0 → p.Sorted [] none → p.evalClosed = some true → Entails [] p
Entails.sound : Entails Φ p → ∀ η,
  (∀ q ∈ Φ, q.interpret η = true) → p.interpret η = true
KeyTerm : Term → Prop
Key.equal : Term → Term → Option Bool
Key.normalizeMap : List (Option Term) → List (Option Term) →
  Option (List (Term × Option Term))
Key.normalizeSet : List (Option Term) → Option (List Term)
```

`Entails` の既存の全規則を保ち、ground を加える。弱化、cut、bind の ground の枝は、閉じた式が値置換で変わらないことから閉じる。モデルの整数射影は不適格・欠落時に0を使うが、実際の評価器はその値を成功として返さない。And/Or は強いKleeneの三値で評価する。偽とのAndは偽、真とのOrは真となり、左右の順序に依存しない。結果が観測できない側に依存する場合はnoneを保ち、Notもnoneを保つ。evalClosedは式全体のWF/Sortedを先に検査する。

## 外部応答の carrier と受信後の検査

P:Program、B:Builtins、Ψ:StoreTy、v:Val、a:Ty とする。

```text
Ty.carrier : Ty → Ty
Tel.carrier : Tel → Tel
Eff.carrier : Eff → Eff
ExternalCarrier P B Ψ : Val → Ty → Prop
ExternalCarrierEach P B Ψ : List Val → Ty → Prop
ExternalCarrierFields P B Ψ : List Val → List Ty → Prop
externalCheck : Program → Val → Ty → Bool
ExternalCarrier.checked_typed : ExternalCarrier P B Ψ v a →
  externalCheck P v a = true → HasTypeV P B Ψ [] [] [] v a
ExternalCarrierEach.checked_typed : ExternalCarrierEach P B Ψ vs a →
  (∀ v ∈ vs, externalCheck P v a = true) → HasTypeEachQ P B Ψ Qempty [] [] [] vs a
ExternalCarrierFields.checked_typed : ExternalCarrierFields P B Ψ vs as →
  externalCheckFields P vs as = true → HasTypeVsQ P B Ψ Qempty [] [] [] vs as
```

Ty.carrier は全21構成子の子・行・Telから篩を除く。名目 data の欄は型引数の列だけの変換では除けないので、ExternalCarrier は元の構成子宣言を具体化した欄へも再帰する。これはゲストの保証する値構造の判断であり、述語の真を一切要求しない。基本型・Bytes・外部ハンドルは既存の葉の型付け、List/Map/Set/data は全要素・全欄の carrier を要求し、篩は carrier のみを要求する。再構成に必要な元の注釈・鍵の制約・kind・宣言の照合は保持する。篩の結論を前提に入れない。

externalCheck は値と型の有限構造に再帰する。data の各欄は元の宣言型を型引数で具体化して調べる。篩は観測が得られる self を代入し、WF/Sorted と evalClosed=some true を照合する。sort を持たない芯では self を使わず既に閉じた述語を照合し、LeQ.introduce から戻す。失敗・篩違反・型構造の不一致は false。独立の固定燃料・内部上限を設けない。

`.05` は external_typed の正常応答を ExternalCarrier と ground の保証に改め、E_External と step の成功に externalCheck を、違反時に err を接続できる。本群は三欄・遷移・主定理の改訂を行わない。

## 場合の数と入口の証拠

予定は Term21、Pred14、Observation14、Measure7、Comparison6、FloatClass6、Ty21/Tel2/Eff1。Entails は既存18に ground を加え19場合とする。外部 carrier は葉3・構造4・篩1の8場合、列は各nil/cons。型付け三族各71とTypedFacts56・Step76は変更しない。

境界入力で、実際の値の Not・加算・length の成功 → ground → V_Refine → 捕捉の facts を通す。全sort、NaNと符号付き0、Decimalの等値、Map/Setの重複縮約、欠けた欄・鍵・自由変数・sort不適格、外部結果の最外・List・Map鍵/値・data欄の篩違反を照合する。正例の結論を仮定しない。test-audit の作成時の関門を適用し、境界の契約と検出する退行を results に記す。

## 補助の契約の決定の記録

| 論点 | 採る案と理由 | 捨てた案 |
|---|---|---|
| 二値のモデルと部分評価 | 有限Observationと全域の射影をモデルに使い、成功の可否は別に検査する | noneをfalseにしてからNotを取る案は、失敗を真にする |
| 観測可能性 | 述語の構造ごとに、各原子の項・欄・鍵・端点が得られるかを検査する | 全域のモデルで真という条件を完全性へ直結する案は前群で却下済み |
| 鍵 | 有限の正準コードを用い、Decimalは末尾の0、Map/Setは順序と重複を縮約する | Termの構造等号・none同士の等号・Mapの生の長さは採らない |
| 外部carrier | 元の型に添字を持つ構造判断でdata宣言の欄まで辿る。元の注釈を再構成に残す | 元のPの下でTy.carrierだけを型付ける案は宣言の欄の篩を消せない。P全体を改変する案は不要な宣言の移送を増やす |
| sortなしの篩 | selfを使わず閉じた述語の成功をLeQ.introduceへ渡す | 観測なしを整数0のselfとみなす案は採らない |

## 残りと送り先

L20 は全遷移の経路条件と捕捉のfactsを本評価器又はbind/cutで閉じ、builderのnormConts・型置換・Regularの形成の前群の義務を受け持つ。L30/.05 は組込みの有限表と実δの観測の一致、L40 は逆転・所属・guard/matchの一般の場合を接続する。O169 の独立評価とReleaseの対応・failed所属は今回の閉じた述語の評価とは別であり、L10/L20/L40/L70へ残す。外部の三モデルはL60、表層・交換はL70/R50へ残す。

## 実装中に確定した補助の署名と決定

`Term.observe : ObservationEnvModel → Term → Option Observation` を部分的な観測とし、`Term.interpret` を演算ごとの既定値を用いる全域のモデルとする。`Term.observe_sound : t.observe η = some o → t.interpret η = some o` を全20構成子で証明する。modelの整数の射影は `Observation.integerD : Option Observation → Int` である。`termReady` と `memberReady` と鍵のコードは observe を使い、原子の真偽のモデルは interpret を使う。欠けた整数欄への加算1をモデルでは1と解釈する一方、評価では失敗する境界も置く。最外でだけnoneを0へ変える案は、演算ごとに既定値を使う契約と一致しないため採らない。

`Entails` の新しい構成子は `closed {Ξ p} : p.WF 0 → p.Sorted [] none → p.evalClosed = some true → Entails Ξ p` とし、空の仮定での入口 `Entails.ground` をその系として公開した。仮定の列を空に固定した構成子だけでは弱化の先の任意の列へ導出を再構成できないためである。ground の利用者の前提と結論は冒頭の署名を保つ。

外部の補助の実際の入口は次である。CarrierEach の検査の前提は、冒頭の各要素の量化と同値な一つのBoolとする。`externalCheckEach_eq_true_iff` が両者を結ぶ。構造的な型付けへ接続するとき、元の列のnil/consを直接使えるためである。

```text
externalCheckEach : Program → List Val → Ty → Bool
externalCheckFields : Program → List Val → List Ty → Bool
externalCheckEach_eq_true_iff (P) (vs) (a) :
  externalCheckEach P vs a = true ↔ ∀ v ∈ vs, externalCheck P v a = true
ExternalCarrierEach.checked_typed : ExternalCarrierEach P B Ψ vs a →
  externalCheckEach P vs a = true → HasTypeEachQ P B Ψ Qempty [] [] [] vs a
Pred.closedTrue : Pred → Bool
Pred.closedTrue_entails : p.closedTrue = true → p.WF 0 ∧ p.Sorted [] none ∧ Entails [] p
Outcome.Carrier : Program → Builtins → StoreTy → Outcome → Ty → Prop
externalCheckedOutcome : Program → Ty → Outcome → Outcome
externalCheckedOutcome_typed : Outcome.Carrier P B Ψ out a →
  Outcome.Typed P B Ψ (externalCheckedOutcome P a out) a
externalCheckedOutcome_reject : externalCheck P v a = false →
  externalCheckedOutcome P a (.val v) = .err "ExternalRefinement"
```

Outcome.Carrier のvalは `ExternalCarrier P B Ψ v a ∧ v.Ground`、err/exitはTrueである。no-exitは既存のexternal_typedの独立の条件として `.05` でも保つ。externalCheckedOutcome はvalにだけ受信後の検査を行い、失敗又は偽なら `ExternalRefinement` のerrへ写す。元のerr/exitはそのまま写す。これは `.05` への補助であり、今回E_Externalや信頼条件を改訂したという意味ではない。

Ty/Tel/Effのcarrierには冪等性と、全入れ子に篩がないことを表す `RefinementFree` の証明を置く。dataの宣言欄を含む値の所属にはExternalCarrierを使う。`HasTypeV P ... v a.carrier` だけをゲストへの保証にすると、同じPの構成子宣言の欄には篩が残る。このため `.05` の外部の正常結果の保証には Outcome.Carrier を使い、検査後に externalCheckedOutcome_typed 又は ExternalCarrier.checked_typed を適用する。

鍵の正準コードと既存δの鍵の等値との一致、Map/Setの表現可能な型付きの全入力で観測が得られることは O022 の `.05`/L30/L50 の担当である。今回のコードをその一致の証明済みと数えない。Key.equal_sound が保証するのは、成功時に両辺の有限コードが得られ、そのコードの等号を返すことである。

すべての公開する補助の完全名と型を public-targets.txt と public-api.lean/log に保存する。本番の7新モジュールと既存Logic/Basicの生成・非公開を含む全宣言は axioms.lean の対象とする。予定数の誤記を訂正する。Termは21ではなく20、旧Entailsは18ではなく17であり、closed追加後は18である。残りはcase-inventory.txtを正とする。

## 群末レビューの軽の所見への対応（2026-10-31）

中1は2026-10-31の設計者の決定に従い、強いKleeneの三値へ改めた。`Pred.evalWith` のAnd/Orを更新し、Notは既存のOption.map Bool.notが同じ規則を満たすため保つ。新しい受理の補題は、すべての必要な篩の閉じた評価が既に成功する範囲について述べ、一般のHasTypeVだけから受理できるとは主張しない。

軽2には、`RefinementSucceeded v a p`（sortがあれば実際のtoTerm?の像で開いた述語、なければ閉じた述語のevalClosed=some true）と、値の構造に沿う `ExternalPredicates P v a` / Each / Fields を置く。これらは検査のBoolを前提にしない。`ExternalCarrier.accepted : ExternalCarrier P B Ψ v a → ExternalPredicates P v a → externalCheck P v a = true` と、列の二つのacceptedを証明する。基本型・Bytes・外部ハンドルの値の形は、元のHasTypeVから篩を通る部分型の全場合を辿って導く。外から形の仮定を足さない。再帰するdataの2段目の篩の成功から受理し、同じ位置を0へ変えた値はcarrierを満たしても拒否する正負の例をr2-boundary.leanへ置く。

軽3には `Key.ClosedSlots xs := ∀ o ∈ xs, ∀ t, o = some t → t.Closed` を前提とする一致を置く。

```text
Key.normalizeMap_length (η) (ks vs) : Key.ClosedSlots ks →
  (mapKeys (observeSlots η ks) (observeSlots η vs)).map List.length =
    (Key.normalizeMap ks vs).map List.length
Key.normalizeSet_length (η) (xs) : Key.ClosedSlots xs →
  (keySetCodes (observeSlots η xs) []).map List.length =
    (Key.normalizeSet xs).map List.length
```

この等式は成功後の長さとnoneの失敗の両方を含む。Mapの値のスロットには閉性も観測成功も要求しない。内部の正規化はコードを保持する補助へ分け、挿入と観測への写しが交換することを証明する。元の鍵と後の値、順序、重複の扱いは保つ。非閉な鍵まで無条件に等式を主張する案は、Key.code?の閉性検査と観測側の違いがあるため採らない。

軽4には `termReady_observation : termReady η s t = true → ∃ o, t.observe η = some o ∧ o.sort = s ∧ t.interpret η = some o ∧ observeAs η s t = o` を置く。Term.observe_soundを本番の証明から使い、モデルの既定値との区別を言明する。

### .05と後続段へ残す義務

| 所見・送り先 | 義務 |
|---|---|
| 軽1・.05 | `Ty.carrier`は検査の定義から読まれない。「型の篩を除いた構文」（Ty.carrier）と「元の型aを添字に持つ値構造の所属」（ExternalCarrier/Outcome.Carrier）を区別し、改訂するexternal_typedの結論を `Outcome.Carrier P B Ψ out a` と明記する。Ty.carrierが接続でも不要なら削除するか利用箇所を決め、両者を同じ型付けと説明しない |
| 軽5・.05 | Tel.argumentsEnvで結果型を具体化して受信検査へ渡す経路について、sortを持つ型の閉じた型付き値のtoTerm?がsomeになることを証明し、termBindのgetD(integer 0)が成功の観測として届かないことを確認する。snapshotのnoneの保持と、根の全域化を分ける |
| 軽6・L70/R50 | 受信後の篩の検査で拒否した結果に含まれるownハンドルを、実装が値を捨てる際に解放することを受信経路・表層・交換で照合する。今回の形式化へ所有権ヒープや新しい状態は足さない |

軽2〜4の正確な公開署名と公理依存はr2-public-api.log、r2-axioms-summary.jsonを正とする。初回の記録は当時の状態として保つ。


## 強いKleeneの三値の署名と決定（2026-10-31）

`Pred.evalWith : ObservationEnvModel → Pred → Option Bool` の型は保つ。AndとOrは各9場合、Notは3場合である。`some false`とのAnd、`some true`とのOrは左右いずれでも結果が決まる。それ以外は既知の値同士でのみ決まり、noneを真偽の既定値へ変えない。`Pred.evalClosed_sound`・`Pred.evalClosed_complete`・`Entails.closed`・`Entails.ground`と、受信検査・型付け・応答の補題の前提と結論は保つ。

`ClosedObservable`は原子、And、Or、Notの4場合を保ち、And/Orの両側の観測を要求する。完全性はこの十分条件の範囲で述べる。片側で決まる場合は次の署名で別に提供する（`η : ObservationEnvModel`、`p q : Pred`）。

```lean
Pred.evalWith_and_false_left  : p.evalWith η = some false → (p.and q).evalWith η = some false
Pred.evalWith_and_false_right : q.evalWith η = some false → (p.and q).evalWith η = some false
Pred.evalWith_or_true_left    : p.evalWith η = some true  → (p.or q).evalWith η = some true
Pred.evalWith_or_true_right   : q.evalWith η = some true  → (p.or q).evalWith η = some true
Pred.evalClosed_and_false_left  : (p.and q).WF 0 → (p.and q).Sorted [] none →
  p.evalClosed = some false → (p.and q).evalClosed = some false
Pred.evalClosed_and_false_right : (p.and q).WF 0 → (p.and q).Sorted [] none →
  q.evalClosed = some false → (p.and q).evalClosed = some false
Pred.evalClosed_or_true_left  : (p.or q).WF 0 → (p.or q).Sorted [] none →
  p.evalClosed = some true → (p.or q).evalClosed = some true
Pred.evalClosed_or_true_right : (p.or q).WF 0 → (p.or q).Sorted [] none →
  q.evalClosed = some true → (p.or q).evalClosed = some true
```

採った案は、README「設計者の決定」の強いKleeneの三値である。片側が欠けても二値のinterpretで結果が一定となる場合だけ決定でき、健全性の言明を保てる。旧案の「両側の成功を必須にする」は、Noneを許すOptの述語を受信検査が拒むため捨てた。通常の左からの短絡だけを行う案は、左右の順序で受理が変わるため採らない。noneをfalseへ置き換える案はNotが観測失敗を真へ変えるため引き続き採らない。ClosedObservableを成功の必要十分条件へ拡張する案は不要であり、既存の完全性と片側の補題を分ける。

| 送り先 | 残る義務 |
|---|---|
| L00b.05 | external_typedとE_Externalの接続で、この三値評価によるevalClosedのsome trueだけを受理する。unknownが結果に影響する場合と式全体のsort不適格は受理しない |
| 処理系の受信検査（R50、L70の照合） | And/Orの左右対称な強いKleeneの三値とNotのunknown保存を同じ規則で実装する。通常の左からの短絡との差を、None/Someと左右反転の境界でLeanと照合する |
