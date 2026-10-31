# RV-L00b.03: 文脈の群（L00b.03）の群末の独立レビュー

2026-10-31。レビュー担当は Opus 5.5 のサブエージェントである。対象はブランチ m014/l00b.03 の未コミットの作業ツリーにある `formal/` の本番の変更である。B_WORK `5016f55f` からの差分は、`formal/Benitoite.lean` の import 4行（と空行1行）の追加と、新規4ファイル（`Release/Refinement/Context/` の `WF.lean`・`Facts.lean`・`Declarations.lean`・`Capture.lean`）から成る。

照合した入力は次のとおりである。

- [レビュー依頼](RV-L00b.03-request.md)
- `l00b.03/` の `signatures.md`・`results.md`・`boundary.lean`・`case-inventory.txt`・`declaration-counts.json`
- plan.md の L00b の作業表の L00b.03 の行、義務の表の O008・O029・O039・O053 の行、2026-10-31 の変更行
- `l00a.06a/contracts.md` の文脈の規約、`l00b.02/signatures.md` の 1134行・1627行・第30節・第31節・「RV-L00b.02b-closuresの義務の対応」の表
- [RV-L00b.02b-values](RV-L00b.02b-values.md) の軽2、[RV-L00b.02b-handlers](RV-L00b.02b-handlers.md) の軽1
- 本番の `Context.lean`・`Typing.lean`・`Semantics.lean`・`Admissible.lean`・`HandlerContracts.lean`・`Declared.lean`・`Kinds.lean`・`KindValues.lean`・`Narrowing.lean`・`TypingShift.lean`・`TypedFacts.lean`、旧 `Release/WellFormed.lean` の `PrimSig.Scoped`

Lean は局所に六つの補助ファイルで実行した。補助のファイルはリポジトリの外（`<tmp>/rv03/`）に置いた。いずれも `cd formal && lake env lean -M 12288 <ファイル>` で、誤り0件、`sorry` なしである。公理の依存は propext・Classical.choice・Quot.sound の範囲である。全体の `lake build` は繰り返していない。

1. `cycle.lean`。自己循環の文脈が `Ordered` を満たさず、`CaptureOk` を満たす（中1）。
2. `forms.lean`。遷移の形の捕捉の延長 `extendHidden`・`extendCont`（中2）。
3. `hide.lean`。`CaptureOk.hide` と E_Lam の先の捕捉 `full_target`（軽4）。
4. `regular.lean`。`Ctx.Regular` の `hideConts`・`bindParams` での保存（軽6）。
5. `kinds.lean`・`counts.lean`。kind の入口の表現力と構成子の数。

## 総評

**条件付き可**である。重の所見はない。読んだ範囲の本番の定義と証明に、定理を偽にする誤りは見つからなかった。`Ordered` は長さの上限でなく循環と後方の参照を排除し、facts の再構成は型付きの値と元の事実だけから導かれ、五つの境界にも触れていない。

条件は中の2件である。中1は `Ordered` が状態のどの判断からも読まれず、`CaptureOk` が循環する文脈を通すことである。O053 の「L20 が全状態の不変条件へ組み込む」には今の決定のままでは道筋がないので、L20 の前に扱いを決める。中2は `CaptureOk.extendNone` の形を実際の遷移が作らず、E_OpFail と E_Op の先の延長が本番にないことである。補題は証明済みなので、本番へ足してからこの群を閉じることを勧める。

## 観点ごとの判定

| 観点 | 判定 | 根拠 |
|---|---|---|
| 1. `outer`・`Ordered` の意味 | 可 | `outer i` は 0〜i を None にし、番号と注釈を保つ。`lookup_outer` は同値である。注釈は lookup する文脈の番号で格納するので、外側の参照は j>i に限られる。self と Tel の内部束縛は `References` が `some a :: Γ` と `Γ.extend a` で扱い、外側の番号の判定に混ざらない |
| 1. 循環と後方の参照の排除 | 可（文脈の判断として） | 自己・後方・相互の負例は具体の文脈から矛盾を導いており、空虚でない。`self_cycle_bounded` が長さの WF との差を示す。ただし `CaptureOk` はこの判断を読まない（中1） |
| 1. 正当な文脈を拒まないか | 可 | 依存する引数列（`Tel.regular_context`）、None を挟む文脈（`none_regular`）、`extend`・`extendNone` は本番で通る。`hideConts` と `bindParams` の保存は `regular.lean` で示した（軽6）。`Narrows.here` の b は外側で検査されるので順序を壊さない |
| 1. `CaptureWF` との整合 | 可 | `Regular` は `CaptureOk` に入っていない。`extend` 系は緩い三判断を移すだけで `Ctx.WF` を要求しない。`loose_capture_extended` が重複 Fail の行で確かめる |
| 2. `Pred.Valid`・`FactsWF` | 可（軽3） | 内容は構文の WF・Sorted・Declared だけで、真理を言っていない。閉じた評価の前に先走っていない。名前だけが紛らわしい |
| 2. `Ty.assume_valid`・`Ctx.Regular.facts` | 可 | 篩の self を束縛した文脈へ移し、入れ子の篩も全 assume を扱う。`facts` は `V_Var` と `SubstOk.openValue` から作り、B の性質を読まない |
| 2. facts の再構成 | 可 | `Capture.facts_extend` の前提は元の facts と Φ の閉じた含意と値の型付けだけで、結論を含まない。新しい事実は `assume_optional` から得る。関数の値は `openOptional` で部分観測のまま残り、整数0に潰れない |
| 2. O008 との整合 | 可 | `cap.values.length = Γ.length` と `hh` により、環境を捨てる形は `CaptureOk` を満たさない。facts の補題は環境の像を読む |
| 3. `extendTel` と E_Lam | 可（軽4） | `cap.extendMany vs`・`t.context`・`liftMany` は `Closure.apply` の順序と一致する。`hideConts` と店の移動を前に付ければ、実際の閉包の成分から遷移先の捕捉が作れる（`full_target`） |
| 3. 正例の仮定 | 可 | `beta_capture` は `capture_with_phi` と `arguments_typed` から作り、遷移先を仮定しない。`beta_step` は実際の `Step.E_Lam` である |
| 3. `extendNone` と継続の位置 | **条件付き（中2）** | `Capture.extendNone` を作る遷移がない |
| 4. `TypeArgsKindedAt`・`forget` | 可（軽5） | `forget` は K に宣言の kind 列を入れるだけである。逆向きを主張していない。`kinds.lean` の `exists_decl` により、既存の一つの前提の K は必ず何らかの D で書ける。したがって一つの呼出しを拒まず、狭まるのは前提どうしで K を選び直すことだけである。`exist_value` は既存の入口が同じ C で value を通すことを示し、`value_kind_conflict` との差が本物であることを確かめた |
| 4. 操作の宣言の正則性 | 可 | `CoreAssumptions` は不変である。`ClauseSig.wf` は opSigAt の実体に結び付く。`TargetWF` の形は旧 `PrimSig.Scoped` の「引数の最上位の opaque 以外と操作の結果は範囲の変数を持たない」に対応し、`scoped` の位置を足しただけである。範囲の内容・kind・Canonical を検査したとは書いていない |
| 5. 境界の負例と正例 | 可（軽2） | 負例は具体の定義の矛盾から導き、前提の矛盾で真になっているものはない。正例に結論の仮定はない |
| 5. 場合の数 | 可 | Lean の metadata で Pred14・Ty21・Tel2・Step76・ImageOk3・CaptureOk1 を確かめた。公開定義18・公開定理69・非公開8・境界54も原文と一致する。63は 21×3 の算術であり、証明は `cases a <;> try` の共通の枝で閉じる |
| 6. 五つの境界と抜け道 | 可 | 本番の差分は import の追加と新規4ファイルだけである。新規ファイルに `sorry`・`axiom`・`native_decide`・`implemented_by`・`unsafe`・`partial`・`extern`・`admit` はない。`opaque` の一致は `Declarations.lean` 177行の `Ty.opaque` の型の構成子だけである |

## 新しい所見

### 重

なし。

### 中

#### 中1. `Ordered` を読む判断がなく、`CaptureOk` は循環する文脈を通す。O053 の L20 の行に道筋がない（読めば確定する。反例は Lean で示した）

- 場所: `Context/WF.lean` 67〜69行・175〜179行、`Typing.lean` 347〜357行の `CaptureOk`、plan.md の O053、`l00b.03/results.md` の O053 の行、`l00b.02/signatures.md` 1134行。
- 問題: `Ctx.Ordered` と `Ctx.Regular` は、型付け・状態・`CaptureOk` のどれからも読まれない。`Ctx.Regular.facts` の証明も `ordered` の欄を使わない。`CaptureOk` は長さの一致と型付き像だけを見るので、O053 が拒むとした自己循環の文脈を通す。`l00b.02/signatures.md` 1134行は `CaptureOk` が「外側参照順」を持つと書くが、定義にその欄はない。
- 反例: `<tmp>/rv03/cycle.lean`。`selfCycle = [some (same 0)]`（注釈 i=0 が自分の位置を読む）と値7の捕捉について、`not_ordered` と `cycle_capture : CaptureOk P B Ψ none selfCycle [] cap0` が同時に成り立つ。閉じた像は7であり、事実は `7 = 7` に閉じるので、健全性の反例ではない。
- 影響: 今の定理は偽にならない。ただし results.md の「L20 が全状態の文脈不変条件へ組み込む」は、次の理由でそのまま実行できない。`Ordered` は `Ty.References` を読むので継続の行も読む。行を読まないことが `.02b-closures` の決定であり（`CaptureOk` に `Regular` を足さない）、`Ordered` をそのまま `CaptureOk` へ足すと同じ問題が戻る。
- 修正案: L20 の前に次のどちらかを設計者か取りまとめが決め、O053 の行と 1134行を直す。(a) 継続の項目で入力と結果の型だけを読む `Ctx.CaptureOrdered` を `CaptureOk` の欄に足す。この場合は `CaptureOk` の定義の変更になり、全ての構成の箇所へ供給が要る。(b) 順序はソースの注釈の判断であり、閉じた像を持つ捕捉の文脈には要らないと決め、O053 の残りを「`HasTypeCQ` の文脈の形成で `Regular` が保たれること」に改める。レビュー担当は (b) を推す。閉じた像があれば循環は意味上無害であり、状態の定義を増やさずに済むからである。

#### 中2. `CaptureOk.extendNone` の形を作る遷移がなく、E_OpFail と E_Op の先の延長が本番にない（読めば確定する。代わりの補題は Lean で示した）

- 場所: `Context/Capture.lean` 132〜188行、`Capture.lean` 28行の `Capture.extendNone`、`Semantics.lean` 303・309・316行、`HandlerContracts.lean` 80行の `failureContext` と77行の `OpSig.context`、`boundary.lean` 160〜163行・315〜320行、`l00b.02/signatures.md` 1627行。
- 問題: `Capture.extendNone` を作る遷移はない（`Semantics.lean`・`Step.lean` に出現しない）。実際の None の位置には値が残る。E_OpFail の先は `hcap.extendMany [v, .loc κ]` であり、型の側は `failureContext Γ E` の `.extendNone` である。つまり要るのは `Γ.extendNone` と `cap.extend (.loc κ)` の組である。1627行は `.03` の具体化の範囲として「None の位置を詰めず、そこに残る実行値は通常値の型付き像や事実として読まない」と書いている。`extendNone` はこの「残る実行値」を扱わず、境界の `none_capture` も遷移に対応しない。E_Op と E_OpPrim の先は `extendMany (ws ++ [.loc κ])` であり、最後の継続の位置は `HasTypeVQ` で型付かないので、`CaptureOk.extend` では作れない（`hv.notContCore` で Ordinary を要求する）。
- 確認: `<tmp>/rv03/forms.lean` で次の二つを本番の補題だけから証明した。定義の変更は要らない。

```lean
extendHidden : CaptureOk P B Ψ R Γ Φ cap → (w : Val) → w.Ground →
  CaptureOk P B Ψ R Γ.extendNone (Φ.map Pred.lift) (cap.extend w)
extendCont : CaptureOk P B Ψ R Γ Φ cap → (Ty.cont b t e).CaptureWF 0 0 Γ.length →
  (Ty.cont b t e).CaptureSorted Γ → (Ty.cont b t e).CaptureDeclared P [] Γ →
  cap.closeTy (.cont b t e) = .cont b' t' e' → (cap.closeTy (.cont b t e)).WF 0 0 0 →
  Ψ l = some (.cont b' t' e' R) → (∀ r, R = some r → r.WF 0 0 0) →
  CaptureOk P B Ψ R (Γ.extend (.cont b t e)) (Φ.map Pred.lift) (cap.extend (.loc l))
```

- 影響: 今の定理は偽にならない。`extendNone` は定理として正しいが、捕捉の延長の入口が揃ったと読むと E_Op の群で詰まる。
- 修正案: 二つの補題を本番の `Context/Capture.lean` へ移し、`extendHidden` の境界の正例を E_OpFail の形（値と `.loc` の順）で足す。`CaptureOk.extendNone` は、使う遷移がなければ消すか、`extendHidden` と Option の値でまとめる。

### 軽

#### 軽1. `no_dependency_cycle` は `Ordered` を読まない

- 場所: `Context/WF.lean` 137〜144行、`results.md` の「`no_dependency_cycle` はその参照関係の任意の非空の有限の連鎖の自己への復帰を排除する」。
- 問題: 定理の関係は `i < j ∧ Readable j` であり、`<` の性質だけで閉じる。注釈の参照関係とは定理の上で結ばれていない。接続は `refined_outer` が最外の篩について言うだけである。排除の中身は `Ordered` の定義にあり、この定理は証拠を足さない。
- 修正案: 依存の関係 `Depends Γ i j`（注釈 i の外側の自由変数 j）を定め、`Ordered` から包含を示す。または定理を消し、results.md の文を `Ordered` の定義と負例の説明へ改める。

#### 軽2. `future_input_rejected` は長さで拒まれており、順序の負例ではない

- 場所: `boundary.lean` 412〜417行、`results.md` の「循環と後方参照」の行。
- 問題: 空の文脈の第一引数の `var 1` が `Pred.WF 1` に反するだけである。de Bruijn の番号では、第一引数の型が後の引数を指す形そのものがない。外側のある文脈なら同じ番号は外側を指す。
- 修正案: 行の説明を「番号の範囲外の拒否」に改める。

#### 軽3. `Pred.Valid` の名前と重複の欄

- 場所: `Context/Facts.lean` 35〜38行。
- 問題: 論理の Valid は「全てのモデルで真」を指すので、L00b.04 の閉じた評価と並ぶと含意と読み違える。`wf` は `Pred.Sorted.wf_none` から導ける。`CaptureOk` の第5欄は同じ三つ組を別の形で持つ。
- 修正案: L00b.04 が使い始める前に `Pred.WellFormed` などへ改名する。欄は `CaptureOk` の形に揃えるために残してよい。

#### 軽4. 境界の依存βは `hideConts Γ = Γ` の場合だけである

- 場所: `boundary.lean` 154〜158行・175〜181行、`Typing.lean` 359〜365行、`l00b.02/signatures.md` の「軽2 / CaptureOkのhide」の行。
- 問題: `DependentClosureTy` の本体は `hideConts Γ` で、捕捉は `hideBuilders Ψ`・`R = none` である。遷移先は本体の文脈・元の Ψ・任意の R を要求する。境界の `initial` は継続を持たないので、この差が現れない。`CaptureOk` の hide の義務は L20 の表に既にあるが、向きは「Ψ を hideBuilders Ψ へ、R を none へ」であり、E_Lam に要る向きは逆である。
- 確認: `<tmp>/rv03/hide.lean` の `CaptureOk.hide`（R は任意へ移せる）と `full_target` が、`ValueAssumptions` と `Ψ.WF` の下で実際の成分から `t.context (hideConts Γ)` の捕捉を作る。`extendTel` の形は足りている。
- 修正案: L20 の行に向きを足す。余裕があれば `CaptureOk.hide` を本番へ置く。

#### 軽5. `TypeArgsKindedAt` に型の束縛を越える移動がない

- 場所: `Context/Declarations.lean` 123〜135行、`TypeShiftKinds.lean` 71行の `TypeArgsKinded.shiftTypes`。
- 問題: 既存は `insertKinds` で K を作り直して型の束縛を越える。固定した D には `shift`（値）と `subst`（値）しかない。節の本体（`sg.tparams ++ C`）へ入る導出を D で読むには、D を延ばす版が要る。節の文脈の `C : List TParam` は kind を持たないので、D は呼出し元から受け取る必要がある。
- 修正案: RV-values 軽2 の行の残りとして、L20/L70 の義務に「`TypeArgsKindedAt` の型の shift と置換、節と Fail 節の文脈の D の与え方」を足す。

#### 軽6. `Ctx.Regular` の保存が型付けの文脈の形成を覆っていない

- 場所: `Context/WF.lean` 184〜222行、`Context/Declarations.lean` 29〜33行。
- 問題: 本番の保存は `extend`・`extendNone`・`extendMany` だけである。型付けの規則は `hideConts`・`bindParams`・`shiftE`・`OpSig.context`・`failureContext` も作る。`bindParams` は依存しない引数列であり、宣言順の `extendMany` とは形が違う。`Narrows.here` の a は WF だけで Sorted を持たないので、narrowing の先の `Regular` は別の前提が要る。
- 確認: `<tmp>/rv03/regular.lean` の `regular_hide`・`regular_bindParams` は本番の補題だけから閉じた。`shiftE` と `Narrows` の場合は実行していない。
- 修正案: 中1で (b) を採るなら、これらの保存が O053 の残りの本体になるので、L20 の行に列挙する。

## 実行しないと分からない疑いの扱い

`Ctx.Regular` の `shiftE`・`OpSig.context`・`failureContext`・`Narrows` での保存は未確認である。`CaptureOk.hide`・`extendHidden`・`extendCont` から実際の E_Lam・E_Op・E_OpFail の保存まで閉じるかは、ClosureTy の残りの欄と型の置換を含むので L20 の範囲である。Function の値を捕捉した部分観測の具体例は境界にないが、一般の補題は `openOptional` で閉じている。

## 申し送り

取りまとめへ返す判断は次のとおりである。中2の二つの補題と正例を本番へ足すよう実装担当へ返す。中1の (a)・(b) は状態の定義に関わるので、設計者か取りまとめが決め、O053 と `l00b.02/signatures.md` 1134行を直す。軽1〜3は文書と境界の入力の修正で足り、軽4〜6は L20/L70 の義務の行へ載せる。補助の入力を残すなら、`<tmp>/rv03/` の `cycle.lean`・`forms.lean`・`hide.lean`・`regular.lean`・`kinds.lean` を `l00b.03/` へ写す。

## 取りまとめの追記

2026-10-31。補助の入力を `l00b.03/rv-03-*.lean` へ写した（`cycle`・`forms`・`hide`・`regular`・`kinds`・`counts`）。所見の判断は plan.md の「計画の変更と取りまとめへの確認点」に書いた。
