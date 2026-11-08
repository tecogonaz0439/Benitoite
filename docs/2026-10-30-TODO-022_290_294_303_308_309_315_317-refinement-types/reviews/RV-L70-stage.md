# RV-L70-stage: L70 段末レビュー（ChatGPT Pro）

- 対象: `review/l70-stage`（コミット `fd280c1c0ad1c15d0b6ca0f40f6801989db66db2`）。依頼文は取りまとめの案を設計者が了承したもの。

- 回答: 設計者が受け取った回答の `report.md` を、次の「回答」の節にそのまま写した（見出しの段だけを一段下げた）。回答の中のリンクは、回答に添えられたソースの写しを指す相対パスであり、このリポジトリの中では切れている。

- 処置: 末尾の「取りまとめの判断と処置」の節に書く。



## 回答



### レビュー結果

**結論は「条件付き可」です。** 指定コミットの核・表層の主定理について、健全性の破れや、前提を満たせないために主張が空疎になる具体的な反例は見つかりませんでした。

修正が必要なのは主に交換の部分です。**`FieldRef.owner` の名前変換漏れ**と、**`closureOf` の外の宣言が検査結果に影響すること**を確認しました。また、信頼条件と交換入口について、新しい定義に追随していない文書があります。

レビュー対象はコミット `fd280c1c0ad1c15d0b6ca0f40f6801989db66db2` です。定義・定理の型・対応文書を読み、旧保証については段の開始版 `657b3ae713040e78826d2f19cd7b8ac9f415a6d6` の該当する言明とも比較しました。`lake build` と公理監査は独立には再実行していません。以下の具体例は定義を展開して確認したもので、交換 JSON を実入口へ渡す試験を行っていないものは、その旨を記します。

### 所見一覧

| 番号 | 重さ | 要点 |
|---|---|---|
| 1 | 中 | 閉包外の標準 data 宣言が検査結果に影響し、予定する「無読出し又は無影響」は現状のままでは成立しない |
| 2 | 中 | `FieldRef.owner` の名前変換漏れにより、正しい篩付き署名も標準表との比較で拒否される |
| 3 | 中 | 信頼条件・Scope 受理・交換形式について、規範文書に旧記述が残る |
| 4 | 軽 | `dropBound` は外側の篩層だけを処理し、入れ子の依存結果型は期待型なしで拒否されることがある |
| 5 | 軽 | 旧の局所参照保証を「導ける」とする説明には、旧表現の埋め込み像への限定が必要 |
| 6 | 情報 | 主保存定理は状態の型付き性と効果を保存するが、開始時と同じ返却篩型の保存を直接は述べていない |

---

### 1. 閉包外の標準 data 宣言が検査結果に影響する

**重さ：中**

**場所：**

- [CheckInput.lean](sources/formal/Benitoite/Exchange/CheckInput.lean)：93、116、316、433行  
  `surfaceWords`、`closureOf`、全 data 宣言からの材料作成
- [CheckMaterials.lean](sources/formal/Benitoite/Release/Refinement/Surface/CheckMaterials.lean)：124行
- [CheckTables.lean](sources/formal/Benitoite/Release/Refinement/Surface/CheckTables.lean)：11行  
  `Benitoite.Release.Refinement.Surface.CheckTables.checkPreparedProgram`
- [CheckVariance.lean](sources/formal/Benitoite/Release/Refinement/Surface/CheckVariance.lean)：26、165、229行
- [stage-results.md](sources/docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l70/stage-results.md)：259行、後段義務19

### 内容

`closureOf` は、プログラムが参照しない data 宣言を照合対象から外します。一方、検査器の入力には交換した**全 data 宣言・全構成子**の名前が入り、`checkPreparedProgram` は、それらを全件 `CheckVariance.check` に渡します。

したがって、**検査器が読むのに標準表と照らされない行が残ります。さらに、その行は検査結果にも影響します。**

具体例として、標準の `Pair` が使えます。標準宣言は次の形です。これは Option・Result の特殊な境界検査に依存しない例です。

```text
Pair[A, B] = Pair.Pair(A, B)
```

根拠は [ScopeDeclarations.lean](sources/formal/Benitoite/Release/Refinement/ScopeDeclarations.lean)：31行です。

本体は Unit を返すだけで、`Pair` を使わず、参照する組込み・標準関数・実装もない入力を考えます。交換表には `package = "stdlib"`、`builtin = ordinary` の `Pair` 行があり、変性を `[covariant, covariant]` とします。

| 交換表の `Pair.Pair` の引数型 | `closure.data` | 閉包上の標準表との比較 | 全件の変性検査 |
|---|---|---|---|
| `[A, B]` | 空 | Pair を照合しない | 成功 |
| `[Reference[A], B]` | 空 | Pair を照合しない | 失敗 |

`dataTypes` に Pair の情報があっても、`surfaceWords` は同欄を除外します。後者の型も通常の型構文として形成できますが、`Reference` の引数は変性検査で `.both` の位置になります。そのため、A を共変とする宣言に反し、`"invalid data variance"` で拒否されます。

この差から、段末資料の義務19にある「閉包の外の行を読まないこと、又は読んでも結果に効かないこと」は、**現在の算法に証明を追加するだけでは達成できません**。

また、`dataStep` が追うのは構成子の引数です。`CheckVariance.metadata` が読む `requirements`・`publicBoundary` からの data 参照は追いません。検査対象を閉包へ縮める方針でも、これらの依存を含める必要があります。

現在の `prepare_agrees` は、この無読出し性を結論していません。[07-04](sources/docs/design/07-quality/07-04-formal-semantics.md)：75行も、その限界を明記しています。したがって、これは既存の `prepare_sound`・`prepare_agrees` の反証ではなく、**後段への接続方針に修正が必要な箇所**です。

### 修正案

次のいずれかを選び、後段義務19の達成条件も合わせてください。

1. 全 data の検査を維持し、その全件を標準表との照合対象にも含める。
2. 全表の形成・整合性検査と本体の型検査を分け、双方の表が全体検査に成功する条件の下で、本体検査に必要な限定された対応を示す。
3. 宣言環境を必要な閉包へ縮める。その場合、`requirements`・`publicBoundary` なども依存に含め、`VarianceValid` 等の全体条件との関係を整える。

現状の「使わない標準行の差で本体検査を妨げない」という目的を維持するなら、2のように保証を分ける方針が検討しやすいと思います。

### 確度

**列挙範囲と結果への影響は、定義の読解で確定します。** 上記の完全な交換 JSON を7入口に渡す再現試験は未実施です。

---

### 2. `FieldRef.owner` が標準名へ変換されない

**重さ：中**

**場所：**

- [CanonicalNames.lean](sources/formal/Benitoite/Exchange/CanonicalNames.lean)：240、253、255行  
  `Benitoite.Exchange.CanonicalNames.renameString`
- [ScopeSyntax.lean](sources/formal/Benitoite/Release/Refinement/ScopeSyntax.lean)：194行  
  `Benitoite.Release.Refinement.FieldRef`
- [StandardHeadTailContracts.lean](sources/formal/Benitoite/Release/Refinement/StandardHeadTailContracts.lean)：12、27行
- [BuiltinAgreement.lean](sources/formal/Benitoite/Exchange/BuiltinAgreement.lean)：47行

### 内容

`FieldRef` は次の二つの名前を持ちます。

- `owner : DataName`
- `constructor : ConName`

JSON の名前変換は `constructor` を書き換えますが、**`owner` を処理する分岐がありません**。`FieldRef` の JSON は構造体から導出されるため、この欄は実際に `"owner"` として運ばれます。

現在の標準 `List.tail` の篩付き署名には、次の欄参照があります。

```lean
⟨"Option", "Option.Some", 0, .list⟩
```

交換入力で、同じ宣言を内部名によって次のように表した場合を考えます。

```lean
⟨"data:199", "ctor:Some", 0, .list⟩
```

宣言から `data:199 → Option`、`ctor:Some → Option.Some` という対応が決まっていても、現在の変換結果は次になります。

```lean
⟨"data:199", "Option.Some", 0, .list⟩
```

返却型本体の `.data` は `"Option"` に変わる一方、述語内の所有者名は内部名のままです。`shapeCheck` は返却型の篩も含めて構造比較するため、標準署名との一致に失敗します。

`List.tail` が当該精密署名を実際に採用していることは、[StandardHeadTailBodies.lean](sources/formal/Benitoite/Release/Refinement/StandardHeadTailBodies.lean)：759行と、[StandardModelSignatures.lean](sources/formal/Benitoite/Release/Refinement/StandardModelSignatures.lean)：1593行から確認できます。

これは、現段階の Rust がまだ篩を出力しないことによる既知の差とは別に残る問題です。**正しい篩を内部名で出力するようになった後も、Lean 側が拒否する原因になります。**

### 修正案

`FieldRef.owner` を data 名として変換してください。

保守性を考えると、あらゆる JSON の `"owner"` を無条件に置換するより、`FieldRef` の文脈を認識するか、型付きの `FieldRef`・`Term`・`Pred` に対する名前変換を用意する方が確実です。

確認例としては、次の二つが有効です。

- 内部名で表した `List.tail` の署名が、変換後に標準署名と一致する。
- 値としての文字列 `"data:199"` は置換されない。

### 確度

**読めば確定します。** 欠けている分岐、JSON の欄名、標準署名での利用を確認しました。実入口を使う再現試験は未実施です。

---

### 3. 信頼条件と交換入口について、規範文書に旧記述が残る

**重さ：中**

**場所：**

- [07-04-formal-semantics.md](sources/docs/design/07-quality/07-04-formal-semantics.md)：670、672、768、788行
- [01-12-core-calculus.md](sources/docs/design/01-spec/01-12-core-calculus.md)：3418行
- [Typing.lean](sources/formal/Benitoite/Release/Refinement/Typing.lean)：194、198行
- [Observe.lean](sources/formal/Benitoite/Exchange/Observe.lean)：227行

### 内容

特に重要なのは、07-04の「形式化で仮定するもの」にある、要求を保持する値の説明です。

672行目には、次の趣旨が残っています。

- 要求なしの `V-Checked` を `RequestIn` として作らない保証は、一般の値の型付けではなく Rust の構築経路に置く。
- 一般の `V-CheckedRequest` は、要求の URL から得た端点と保持対象との一致までは求めない。

現在の規則は、この説明より強い条件を持っています。

| 現在の規則 | 明示された前提 |
|---|---|
| `HasTypeVQ.V_Checked` | `B.valContent o = none` |
| `HasTypeVQ.V_CheckedRequest` | 内容型での閉じた型付け、`groundVal req = true`、`req.reqTarget = some target` |

したがって、要求内容を持つ標準 `RequestIn` を、要求なしの `.checked` でこの規則から型付けすることはできません。また、形式化内の `reqTarget` と保持対象の一致は、一般規則が既に要求しています。07-04の115行目は新規則を正しく説明しており、同じ文書内でも矛盾しています。

ほかにも、交換の保証の読み方に影響する旧記述があります。

| 場所 | 残っている記述 | 現在の定義 |
|---|---|---|
| 01-12：3418行 | `acceptInput` は `ok := "Ok"` を使う | `none`・`some` の両方で `"Result.Ok"` を使う |
| 07-04：768行 | Scope の解析表を信頼して規則を作るという説明 | `ScopeSound.agreed` が形式化した解析との一致を確かめ、一致しない項目を未知にする |
| 07-04：788行 | 篩付き交換版は仮の版で、既存入口は読まない | 今回切り替えた入口が corpus 16・sidecar 8 を読む |

Scope の成功構成子の違いは、空疎性の評価に直結します。文書どおり `"Ok"` を使うなら、本番 δ の `"Result.Ok"` の成功値に関する前提が成立しません。しかし、**指定コミットの実入口は `"Result.Ok"` を使っており、この理由による空疎性はありません**。07-04の774行目はこちらの現状を正しく説明しています。

解析表の扱いも、[ScopeSound.lean](sources/formal/Benitoite/Release/Refinement/Surface/ScopeSound.lean)：80、247行で確認できます。

### 修正案

信頼境界の説明を、新しい規則にそろえてください。要求と対象については、次のように分けるのが適切です。

> 形式化内では、保持要求の `reqTarget` と保持対象の一致を型付け規則が要求する。`reqTarget` が意図した URL 解析を表すこと、および Rust の保持・射影・送信経路がこれに対応することは、処理系との照合事項として残る。

Scope については、交換名の正規化後の成功構成子が `"Result.Ok"` であることと、解析表の食い違いを未知へ落とすことを統一して記述してください。788行目の「既存入口は読まない」も更新が必要です。

### 確度

**読めば確定します。** 文書と定義、および文書内の新旧記述の直接の不一致です。

---

### 4. `dropBound` は入れ子の篩を除去しない

**重さ：軽**

**場所：**

- [CheckInfer.lean](sources/formal/Benitoite/Release/Refinement/Surface/CheckInfer.lean)：64、69、357、674行
- [CheckOpenInfer.lean](sources/formal/Benitoite/Release/Refinement/Surface/CheckOpenInfer.lean)：67行
- [Check.lean](sources/formal/Benitoite/Release/Refinement/Surface/Check.lean)：296行
- [stage-results.md](sources/docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l70/stage-results.md)：332行、設計判断6
- 07-04：447行、01-12：3786行

### 内容

`dropBound` が再帰するのは、型の外側から連続する `.refined` だけです。`.list`、data の型引数などに入った篩は、そのまま返します。その後、`outerType` は型全体に `unshiftValue n 0` を適用します。

例えば、型の略記で次の署名を考えます。

```text
singleton(n : Integer) : List[{v : Integer | v = n}]
```

引数を一つ束縛した内部文脈で、結果型が次の形になった場合です。

```lean
.list (.refined (.base .integer)
  (.compare .integer .eq (.var 0) (.var 1)))
```

`dropBound 1` は外側が `.list` なので何も除去しません。続く番号の移動では、篩の自己変数を保つ処理と自然数の切り詰めにより、述語の `.var 1` が外側にも残ります。外側の文脈が空なら、この結果型は整形式ではありません。

期待型のない `.lastDiscard` などでは、この候補が再検査されて拒否されます。一方、期待型を `List[Integer]` とすれば、元の結果型から List の共変性と篩の忘却によって包含を作る経路があります。

これは健全性を崩しません。[CheckEntrypoints.lean](sources/formal/Benitoite/Release/Refinement/Surface/CheckEntrypoints.lean)：43、81行の再検査と、`E_CallDirect` の外側文脈での注釈検査が、不適切な候補の受理を防ぎます。

ただし、「束縛した値を指す篩の層を除いてから番号を戻す」という説明は、現実の適用範囲より広く読めます。TODO-328の「実引数との関係を外側へ残す」問題に加え、**入れ子の篩を安全に忘れる処理も現在は限定されています。**

### 修正案

現状を維持する場合は、次を明記してください。

- 除去するのは、型の外側に連続する篩層。
- 入れ子の依存結果型は、期待型がない位置で拒否されることがある。

受理範囲を広げる場合は、変性と束縛を考慮し、元の型から外側の候補型への包含を確認できる近似を使うのが適切です。List の共変位置には拡張の余地がありますが、関数の引数や不変位置まで一律に篩を捨てる変更は避けるべきです。

### 確度

**非再帰範囲、残る変数、再検査による拒否は定義から確認できます。** 上記の署名を持つ完全なソース・交換入力による実入口の試験は未実施です。

---

### 5. 旧の局所参照保証の照合理由には、旧表現への限定が必要

**重さ：軽**

**場所：**

- [h3/legacy-recheck.md](sources/docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l70/h3/legacy-recheck.md)：57、60行
- [ReadLocalRefs.lean](sources/formal/Benitoite/Release/Refinement/ReadLocalRefs.lean)：96行
- [HiddenCaptureBoundary.lean](sources/formal/Benitoite/Release/Refinement/HiddenCaptureBoundary.lean)：38、60行
- [Embedding.lean](sources/formal/Benitoite/Release/Refinement/Embedding.lean)：14、90、127行

### 内容

旧の `Val.LocalRefs` は、ラムダ本体を含む構文を再帰的に調べる条件でした。新しい `Capture.LocalRefs` は、捕捉元文脈で通常値として型が付いた位置について、捕捉値の局所参照を調べます。隠された全位置を同じ条件で再帰検査するものではありません。

この限界は、現在の形式化にも反例として明示されています。

```text
Benitoite.Release.Refinement.CaptureLocalRefsBoundary.hidden_slot_read_localrefs
```

この定理は、`LocalStateInvariant` が成立する状態でも、隠れた捕捉位置の専用参照が実在セルを指す条件は成立しない例を示します。

そのため、照合表の「前提・結論・量化は同じ」「旧の結論を含む」という説明は、新しい実行時閉包の全域まで同じ保証があるように読むと過大です。

一方、旧の値・状態の埋め込みでは空の捕捉が使われます。上記の隠れた捕捉の反例は、その旧像には属しません。**この反例から旧入力について保証が失われたとは判断できず、「導ける」という分類そのものを否定する根拠にはなりません。**

### 修正案

照合表の理由に、次の限定を加えてください。

> 旧構文と空捕捉による実行時表現の対応の範囲で旧保証を回収する。新しい実行時閉包の全域では、保証の対象は型付きの捕捉位置であり、隠れた全位置の構文的な専用参照禁止までは結論しない。

「導ける」を将来も機械的に確認したい場合は、旧像に限定した対応補題を残すと有用です。

### 確度

**新旧の定義の違いと、新しい全域での反例は読めば確定します。** 旧像に限定した回収補題を今回新たに証明したわけではありません。重・中の保証喪失としては扱いません。

---

### 6. 主保存定理から、開始時と同じ返却篩型の保証は直接には得られない

**重さ：情報**

**場所：**

- [StateTyping.lean](sources/formal/Benitoite/Release/Refinement/StateTyping.lean)：158行
- [MainStatements.lean](sources/formal/Benitoite/Release/Refinement/MainStatements.lean)：64、69、80行
- [FiniteStepPreservation.lean](sources/formal/Benitoite/Release/Refinement/FiniteStepPreservation.lean)：9、124行
- [TypedMeaning.lean](sources/formal/Benitoite/Release/Refinement/TypedMeaning.lean)：176行

### 内容

`StateTyE P B σ Eb s` は、末尾の効果 `Eb` をパラメータとして固定します。一方、継続の最終結果型 `b` は、状態ごとの存在量化に入っています。

主保存定理が直接述べるのは、概略として次の形です。

```text
ある型で型付く状態
  → 遷移
  → ある型で型付く状態
```

効果を固定した内部の保存定理でも、固定する添字は `Eb` です。したがって、これらの言明だけから、

```text
開始計算の結果型が {v : Integer | 0 < v}
  → 正常終了した値も同じ篩型に属する
```

という結論をそのまま読み取ることはできません。

`typed_value_meaning_closed` は、**既にその型で値が型付くこと**から `ValueMeaning` を導くので、開始時の型から最終値までを接続する部分は別に必要です。

01-12は保存を「遷移先の状態も型が付く」と明示しているため、現在の規範との食い違いとは判定しません。また、実際に返却篩を破る実行を見つけたという指摘でもありません。

### 修正案

篩型の保証を利用者に直接示すために、結果型も添字として固定した状態保存と、正常返却値についての系を加えると有用です。例えば、必要な正規化・ストア条件を伴う形で、

```text
初期計算が A で型付く
かつ、正常返却まで実行する
ならば、返却値は A の意味を満たす
```

をまとめると、主定理と値の篩の意味との関係が明確になります。

### 確度

**主定理の言明の範囲は読めば確定します。** 核の保存・Steps・FirstReturn 関連を調べた範囲では、この形を既に直接与える別定理は見つかりませんでした。

---

### 重点項目についての評価

### 主定理の言明と空疎性

進行・保存・エフェクト健全性・対象健全性は、特定の具体値を評価して得た結果だけに限定されていません。任意のプログラム・表・起点環境や任意の実行列を量化し、明記された条件から結論します。`step_sound` も、選択条件を満たす実行関数の返した遷移が関係の遷移である、という範囲を正確に述べています。[MainStatements.lean](sources/formal/Benitoite/Release/Refinement/MainStatements.lean)

前提の充足例も、空のプログラムだけではありません。

- `Surface.CheckedMainExamples.entry_succeeds` と `main_guarantees` は、標準関数 `Range.checkInteger` を呼ぶ main について、検査入口の成功と主定理への接続を同時に構成しています。[SurfaceCheckedMainExamples.lean](sources/formal/Benitoite/Release/Refinement/SurfaceCheckedMainExamples.lean)：526、530行
- `Surface.TargetObservedExamples.main_observed` は、観測 `/data/a.txt` を持つ IO 事象への実際の到達と、その観測が宣言効果に許されることを示します。[SurfaceTargetObservedExamples.lean](sources/formal/Benitoite/Release/Refinement/SurfaceTargetObservedExamples.lean)：229行
- `StandardModel.ApplicationExamples.user_guarantees` は、完成表の下で追加した利用者関数に保証一式を適用します。そこで使う `noAssumptions` は仮定側の追加行を空にするもので、合成済みの標準表まで空にするものではありません。[StandardModelApplicationExamples.lean](sources/formal/Benitoite/Release/Refinement/StandardModelApplicationExamples.lean)：141、148行

これらは、主定理の前提が同時には成立しないという疑いを退ける証拠になります。ただし、全標準行の全入力が正常終了することまで示すものではありません。

性質1は、型情報付き表層の型付けから、同じ型・効果を保つ脱糖へ接続しています。検査器も、推論器が出した候補を証明書として再検査する構造です。調べた一般定理について、`decide` や大きな具体値の評価によって対象を有限の例だけに狭め、それを一般的な健全性として扱っている箇所は確認しませんでした。[Property1.lean](sources/formal/Benitoite/Release/Refinement/Surface/Property1.lean)、[CheckEntrypoints.lean](sources/formal/Benitoite/Release/Refinement/Surface/CheckEntrypoints.lean)

### 仮定と信頼条件

`CoreAssumptions`、`ValueAssumptions`、`TargetAgreement`、開始条件、標準表の完成・包含・宣言実現の条件を追った範囲では、**文書にない独立した強い意味論的前提を追加で見つけることはありませんでした**。

ただし、交換から主定理への接続には、明記された未完了部分があります。

- `prepare_sound` が供給するのは `Check.Input.Sound`。
- 全プログラムの検査器の健全性には、定義・実装本体の支持なども必要。
- `prepare_agrees` は、改名・正規化した照合用の表についての有限範囲の一致。
- それだけで `q.B = complete L T A`、実行意味の一致、宣言の実現などは得られない。

この区別は、07-04の62〜75行に相当する説明と、段末資料の義務18・20・21で適切に開示されています。**ここを「交換入口の成功から標準完成表での実行の健全性まで無条件に得られる」と拡張して読むことはできません。** 所見1は、この開示済みの接続課題について、現在の算法に合わせた義務の修正が必要だという追加指摘です。[CheckInput.lean](sources/formal/Benitoite/Exchange/CheckInput.lean)：499、534行

対象健全性も、IO事象が**報告した観測**を、対応する効果名の原子が許すことを述べています。外部処理が実際に作用した対象を漏れなく報告する完全性は、別の実装照合事項です。07-04はこの境界を明示しており、観測の完全性を隠れた Lean の前提にしていません。

### 篩の論理・番号・NaN・data・欄の取り出し

この部分では、疑わしく見える規則にも、適用を制限する条件が確認できました。

| 論点 | 評価 |
|---|---|
| 自然数の引き算 | `FieldLink.predicate` の `n - 1 - slot` には `slot < n` がある。`upSubst` は `i < k` を先に分ける。核で無条件の切り詰めを正しい束縛除去として扱う例は見つからない。表層の `dropBound` の限定は所見4。 |
| 束縛番号 | 自己変数を保つ持ち上げと、依存する引数列の一段ずつの文脈拡張を区別している。型付き置換の経路では、観測可能な像の存在と sort の一致を要求する。 |
| NaN と反射則 | `Entails.eq_refl` の `Pred.eq` は、整形式な述語では整数 sort に限定される。Float の比較は別の `Pred.compare` であり、NaN の場合は `.ne` だけが真になる。 |
| Float の欄の関係 | IEEE 等号または両辺 NaN に加え、六分類の一致を要求する。`+0.0` と `-0.0` も分類で区別する。通常の Float 等号を反射的に変更していない。 |
| data の欄の関係 | 有限列に含む構成子判定の一致であり、内部の全欄の構造的等号を意味しない。移送規則もその列に含む構成子の判定に制限される。 |

根拠は、[FieldFacts.lean](sources/formal/Benitoite/Release/Refinement/FieldFacts.lean)：27、43行、[Subst.lean](sources/formal/Benitoite/Release/Refinement/Subst.lean)：106行、[Context.lean](sources/formal/Benitoite/Release/Refinement/Context.lean)：105行、[ClosedEvaluation.lean](sources/formal/Benitoite/Release/Refinement/ClosedEvaluation.lean)：26行、[FieldRelationSyntax.lean](sources/formal/Benitoite/Release/Refinement/FieldRelationSyntax.lean)：11、18行です。

例えば `Box 0` と `Box 1` が同じ構成子判定を持つことから、内部の整数まで等しいとは結論できません。現在の欄関係は、その弱い情報に対応した原子だけを移送しており、安全な近似として妥当です。より精密な record の入れ子の関係が必要なら、検証した欄経路を増やす方向が適切です。

### 網羅性と旧保証の削除

網羅性は、抽象的な `Inhabits` だけで閉じず、型付き値から `ValueMeaning`・`Inhabits` への接続があります。また、実行時の非選択に必要な `SlotsOk` は、腕の型付けから供給されています。

旧保証の照合では、最終追記後の版を採用すると、追加の重・中の保証喪失は確認しませんでした。特に、次は復元を確認できています。

- 任意の腕の型 `a` ごとの実行時非選択は、`checkMatchWithView_unreachable_runtime_of_arms` と `checkMatch_unreachable_runtime_of_arms` が担う。[CoverageRuntime.lean](sources/formal/Benitoite/Release/Refinement/CoverageRuntime.lean)：251、260行
- 明示拡大の範囲列と行き先の一意性は、新しい `ScopeWiden` に同じ対象範囲の言明がある。[ScopeWiden.lean](sources/formal/Benitoite/Release/Refinement/ScopeWiden.lean)
- H4の最終形には、範囲付き書込みと実際の書込み事象への到達を持つ例がある。初期の読取り例への置換だけを見て、書込みの保証が失われたと判定すべきではない。[SurfaceTargetWriteExamples.lean](sources/formal/Benitoite/Release/Refinement/SurfaceTargetWriteExamples.lean)

「旧の判断どうしの同値」9行を現在の言語の保証喪失に数えない整理も、D29で双方向の全域同値を要求しないという範囲では妥当です。局所参照の項目だけは、所見5のように表現対応の限定を説明に残す方が正確です。

### `unknownBuiltins` の判断

`unknownBuiltins` を直ちに拒否せず記録する判断は、**交換表の下での相対的な検査器健全性**という現在の保証と両立します。未知の行について標準完成表との意味的一致まで得たとはしておらず、07-04と段末義務23もその限界を明示しています。[CheckInput.lean](sources/formal/Benitoite/Exchange/CheckInput.lean)：445行

したがって、この判断自体を健全性の欠陥とは評価しません。完成表との接続を行う段では、既に予定されているとおり、合成済みの行・明示した仮定側の行・それ以外を区別し、最後のものを拒否する方針が適切です。

### 全体の結論

**条件付き可。**

条件は次のとおりです。

1. **`FieldRef.owner` の名前変換漏れを修正すること。** 内部名を使った篩付き標準署名の比較例で確認してください。
2. **`closureOf` と全件の宣言検査の関係を整理すること。** 現状の無読出し・無影響性は成立しないため、照合範囲を広げるか、全体検査と本体検査を分けた条件付きの接続へ義務を改めてください。
3. **信頼条件・Scope の成功構成子・交換版の文書を現行定義に合わせること。**
4. **`dropBound` と旧局所参照保証の適用範囲を明記すること。** これらは現時点では健全性の修正条件ではなく、受理範囲と保証範囲を正しく伝えるための条件です。

固定した返却篩型についての系を加える所見6は、追加の推奨です。

以上を満たすなら、今回の段を、**篩付き判断の条件付き健全性を形式化し、交換表に相対的な検査へ7入口を切り替えた段**として受け入れられます。標準完成表および処理系全体への接続は、文書に列挙された後段義務として扱う必要があります。

## 取りまとめの判断と処置

判断は 2026-11-08 の取りまとめの判断（plan.md「計画の変更と取りまとめへの確認点」の同日の項目。設計者の指示「推奨の方法で進める」に従う）である。全件を L70.48 で処置した。Lean の変更は Lean の担当（Claude、Opus 5.5）の記録 [../l70/l48/results-lean.md](../l70/l48/results-lean.md) にあり、文書の変更は文書の担当（Claude、Opus 5.5）が行った。

| 所見 | 処置 | 変えた場所 | 理由 |
|---|---|---|---|
| 1（中） | 検査器の算法（全件の data に `CheckVariance.check` を掛ける）は変えない。閉包の data の段 `dataStep` が、構成子の引数に加えて変性の検査が読む `requirements`・`publicBoundary` の型の data も辿るようにした（`CheckInput.dataDeclStrings`）。1,455入力の準備の段の件数は変わらない（1,399 が通り 56 を断る。今の書き出しの data の宣言は制約と公開境界を持たない）。義務19の達成の条件を修正案2の形に改めた: (a) 全表の形成と整合の検査（全件の変性の検査を含む）と (b) 本体の型検査に分け、交換の表と完成表の双方が (a) に成功する条件の下で、(b) に要る閉包の上の限られた対応を示す。07-04 に、閉包の外の data の行も変性の検査を通じて検査の結果に効くことと、定理がその関係を述べないことを書いた | Lean: `Exchange/CheckInput.lean`。文書: stage-results.md の義務19と設計判断3、07-04「交換と7入口」の `closureOf` の data の説明と `prepare_agrees` の段落 | 修正案2は使わない標準の行の差で本体の検査を妨げない目的を保てる。退けた案（全件の照合、宣言の環境を閉包へ縮める）は plan.md の同日の項目のとおり |
| 2（中） | 型付きの写し `CanonicalNames.fieldRef`・`term`・`slots`・`pred` を置き、JSON の写しは欄 `predicate` の述語と、四つの欄だけを持つ欄の参照の対象を型付きの写しで写す。あらゆる `"owner"` は置き換えない。例 `CanonicalNamesExamples.tail_predicate_renamed`・`internalSomeField_renamed`・`string_value_kept` と、入れ替えの性質 `resultConstructors_*_twice`・`resultConstructors_fieldRef_owner` を置いた | Lean: `Exchange/CanonicalNames.lean`・`Exchange/CanonicalNamesExamples.lean`（新規）。文書: 07-04「交換と7入口」の `standardCheck` の段落、`formal/README.md` の構成の表 | 修正案のとおり、文脈を判定して写す。固定入力の交換の試験は全て通った |
| 3（中） | 修正案に沿って直した。要求を保持する値は、形式化の中では `V_Checked` の `valContent o = none` と `V_CheckedRequest` の `req.reqTarget = some target` が要求し、`reqTarget` が意図した URL の解析を表すことと Rust の経路の対応を処理系との照合の事項とした。01-12 の `acceptInput` の成功の構成子の名前を `"Result.Ok"` に直した。Scope の解析の表は `ScopeSound.agreed` が形式化した解析との一致を確かめ、合わない項目を未知にすると書いた。交換の版は7入口が corpus 16・sidecar 8 を読むと書いた | 07-04 の670・672・768・788行付近、01-12 の3418行付近 | 名前と規則は作業木の `Typing.lean`・`Observe.lean`・`ScopeSound.lean`・`Version.lean` で確かめた |
| 4（軽） | 除くのは型の外側に連続する篩の層だけであることと、入れ子の依存する結果型が期待型のない位置で断られることがあることを書いた | 07-04 の447行付近、01-12 の3786行付近、stage-results.md の設計判断6 | 健全性ではなく受理の範囲の記述の正確さの問題である |
| 5（軽） | 旧の像に限った補題を置いた: `embedState_capturesEmpty`（旧の構文の状態の像の捕捉は全て空）、`embedState_local_invariant`（型付きの像は `LocalStateInvariant` を満たし捕捉が空）、`hidden_capture_not_embedded`（隠れた位置の反例は像でない）。照合表の2行（番号1・12）の理由に、旧の構文と空の捕捉による実行時の表現の対応の範囲で回収することと、新しい実行時の閉包の全域では隠れた全位置の専用参照の禁止までは結論しないことを足し、補題を引いた。削除した旧の構文上の述語との対応と、像から実行した後の状態は、この補題の範囲の外である | Lean: `Release/Refinement/EmbeddedLocalRefs.lean`（新規）。文書: h3/legacy-recheck.md の番号1・12の理由、07-04・01-12 の `LocalInvariant` の段落、`formal/README.md` の構成の表 | 取りまとめの判断で、理由は今の補題の範囲で書く |
| 6（情報） | 系は置けなかった。状態の型付けが継続の結果型を存在量化に置くので、結果型を添字に固定した保存を葉の定理の全てについて述べ直す必要がある。設計者の決定により docs/todo の TODO-332 へ（系に要る結果型を固定した保存の補題と見込みは [l48/results-lean.md](../l70/l48/results-lean.md)）。設計書には、保存の定理が結果型を固定しないことを今の性質として書いた | 01-12・07-04 の `StateTyE` の段落 | 主な言明を変えず新しい定理として足せるが、上限4時間の中では置けない |

段の記録（h3/）は Lean の担当が最終版から作り直し、stage-results.md の件数をその値に直した。
