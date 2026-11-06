# 組込みの署名の範囲の有効範囲と全具体化

2026-11-06。B_WORK は `e70794188e24de95b5bb424f9d75090f77d1c703`。再開6は案 A の型引数の許容と制約の照合を前提として検討した。これらとは別に、使用する組込みの署名自身の範囲の有効範囲が必要であることを反例で確認した。追加の型付けの条件は実装していない。

## 反例の対象

反例は、現在の `BodyTy` から全具体化の核の本体の型付けを導く言明についてのものである。案 A の有限の開いた表層の導出は、まだ実装していない。案 A によって強める `PrimSig.admits` と `B.sat` の条件だけでは、既存の組込み参照の葉に残るこの不足を解消できないことを示す。新しい導出そのものの反例、範囲のない現在の性質1の反例、合成表の実在する組込みの不具合とは区別する。

完全名の共通の名前空間は `Benitoite.Release.Refinement.Surface.RangeSignatureExample` である。本番のモジュール `Surface/RangeSignatureExample.lean` を `Surface.Examples` から import した。再開5の `RangeAdmissibilityExample` は変更せず、その空のプログラム・宣言の表と、潜在効果に範囲変数を持つ関数型だけを再利用する。

| 入力 | 形と役割 |
|---|---|
| `argument` | `() -> Unit uses Read[ρ₀]` に当たる関数型。値・型・行の自由変数はない |
| `signature` | 型・行・範囲のパラメータと値引数がすべて空。結果は `Reference[argument]`、効果は空、`admits := fun _ _ => True` |
| `builtins` | `probe` に上の署名を持つ。`sat` は常に真。δ と外部の応答は使わない |
| `source`・`body` | `probe` の参照と、それを末尾で返すブロック。型・行・範囲の実引数は空 |
| `resultType`・`telescope` | `probe` の依存列の関数型と、それを結果に持つ本体の依存列 |
| 具体化 | `[RangeExpr.top]`。`RangesFit [RangeExpr.top] [.path]` を満たす |

`values` は既存の `Builtins.ValueAssumptions` の全4欄を満たす。`admits_and_sat` は、任意の型引数列・型・制約・範囲列について、具体化前後とも `admits` と `sat` が成立することを示す。実際の参照では型・行・範囲の実引数を一つも渡していない。再開5の反例と異なり、許容される型引数が具体化後に拒否されることを原因にしていない。

`surface_typed`・`body_typed` は既存の表層の規則による型付けである。`code_sourceScoped` と `telescope_sourceScoped` は、本体のコードと依存列の両方を呼出し元の範囲深さ1で形成できることを示す。一方、`signature_not_scoped` は、組込みの署名が自身の宣言した範囲深さ0での `PrimSig.Scoped` を満たさないことを示す。潜在効果の名前の原子の範囲は `Ty.WF` だけでは上限を検査せず、`RangesScoped` が別に検査するため、既存の `SignatureInstance` の葉とこの不成立は両立する。

## 否定の証明

呼出し元の範囲を Top に具体化しても、空の実引数を持つ核の `.prim "probe" [] [] []` は変わらない。核の `V_Prim` が読む表の署名も固定したままであり、結果型は `Reference[() -> Unit uses Read[ρ₀]]` のままになる。一方、呼出し元の依存列を具体化した期待型では、内容の関数型の効果は `Read[Top]` となる。

`instantiated_value_rejected` は、核の `HasTypeVQ.inv_prim` から元の署名と結果への `TelClosure` を取り出し、`TelClosure.done_outputs` から結果の部分型関係を得る。`Ty.LeQ.refCore` が参照型の内容に要求する正規形の等号は、`Read[ρ₀]` と `Read[Top]` の原子を区別すると成り立たない。単なる型の字面の差ではなく、`V_Sub`・`V_Normal`・`V_Refine` を経由する全導出も核の逆転によって否定する。`instantiated_body_rejected` は本体から計算・値の型付けを取り出し、この否定へ接続する。

全体の証人は次である。

```lean
Benitoite.Release.Refinement.Surface.RangeSignatureExample.admissibility_premises_insufficient
```

同じ名前空間の下の完全な言明は次のとおりである。

```lean
theorem admissibility_premises_insufficient (op : OpPrim) :
    declarations.Realizes program ∧ builtins.ValueAssumptions program ∧
    (∀ C ts rs a p, signature.admits C ts ∧ signature.admits C (ts.map (Ty.instR rs)) ∧
      builtins.sat C a p ∧ builtins.sat C (a.instR rs) p) ∧
    BodyTy declarations builtins op Qempty [] [] [] telescope body ∧
    (desugarBlock op .tail body).SourceScoped 1 0 0 0 ∧
    (Ty.dependentFn telescope).SourceScoped 1 0 0 0 ∧
    ¬ signature.Scoped program ∧
    RangesFit [RangeExpr.top] [.path] ∧
    ¬ TelBodyTy program builtins StoreTy.empty Qempty [] [] []
      (rangeTel [RangeExpr.top] telescope) ((desugarBlock op .tail body).instR [RangeExpr.top])
```

## 必要な差と止める条件

既存の `PrimitiveAdmissible` は署名の行変数の上限を `sourceTelRows` で読むが、範囲変数について同じ条件を持たない。`SignatureInstance.source` は `WF 0` を求めるが、効果の名前の原子の範囲を別に検査する `RangesScoped` は含まない。`Builtins.ValueAssumptions` にも署名の有効範囲の欄はない。

少なくとも、新しい開いた導出の組込みの葉に、使用する署名の `s.tel.RangesScoped s.rkinds.length`、又はそれを導く既存の `s.Scoped P` の構文上の証拠を求める必要がある。この反例が必要性を示すのは範囲の有効範囲の条件であり、`PrimSig.Scoped` の全欄が最小であることまでは示していない。

これは `PrimSig.admits`・`B.sat` を全具体化で要求する変更とは別の前提である。型付けの規則の変更の例外は「この許容の前提の追加に限り」と指定されているので、その前提を追加する前に止めた。核・主な十言明・`ValueAssumptions` に条件を追加せず、全具体化の核の型付けを表層の規則の前提として仮定してもいない。

| 対象 | 現在 | 必要な差の候補 | 今回の扱い |
|---|---|---|---|
| 開いた組込みの参照の葉 | 型引数の許容・制約の全具体化を要求する案 A | 使用する署名の宣言した範囲深さでの形成も要求する | 型付けの規則への別の前提なので未実装 |
| `desugar_typed` など既存の群 D の定理 | 現在の署名と規則 | 範囲なしの元の形を保つことが必要 | 全288既存定理の言明は変更しない |
| 核・主な十言明・`ValueAssumptions` | 既存の形 | 変更しない案を推す | 変更なし |

## 代案と実用への影響

| 案 | 必要な変更 | 実用への影響と残る所要 |
|---|---|---|
| 使用する組込みの葉に署名の範囲の有効範囲を求める（推す） | 新しい開いた導出の葉に構文上の条件を追加する。空の範囲文脈では従来の規則をそのまま使う系を示す。核と既存の信頼条件は変えない | 未宣言の範囲変数を持つ表の署名が範囲パラメータの関数に取り込まれる形を拒む。合成表の実在する署名は既存の `StandardModel.sig_scoped` が全lookupを量化して `PrimSig.Scoped` を示すので、この反例による追加の拒否はない。最初の完全署名と一つの保存の場合の確認30〜60分。その後の全場合・検査・レビューの総所要は不明 |
| 性質1の前提に表全体の `sig_scoped` を足す | 既存の定理への前提追加。使用しない署名まで制約する | 宣言済みの性質1の前提が変わる。今回採らない。所要不明 |
| 組込みの署名も呼出し元の範囲で暗黙に具体化する | 核の `V_Prim` と署名の解釈を変える | 署名と呼出し元の範囲変数の所属が混ざる。核の変更を要し、今回採らない。所要不明 |

合成表の `admits`・`sat` の具体化による保存を各組込みについて証明する作業は未実施である。`sig_scoped` の既存の証明を、その許容条件の保存の証明として数えない。制約のため渡せなくなる実在の型引数の一覧も未確定である。外部宣言のあるプログラム、関数型の中の範囲、host・endpoint、範囲のない場合を提供範囲から除く提案はしない。

## 例の作成時の関門

| 関門 | 答え |
|---|---|
| 守る境界 | 使用する組込みの署名の範囲変数と呼出し元の範囲変数を、全具体化の性質1で混同しないこと |
| 捕まえる誤り | 型引数の許容と制約を全具体化で検査すれば、署名に残った未宣言の範囲変数も自動的に具体化されるとすること |
| 既存の例との差 | 再開5は型引数の許容の失敗である。今回は実引数三列が空で許容も制約も常に真であり、署名の結果だけが原因になる |
| 差し込み口 | 新設しない。既存の表・表層の規則・値の置換の仮定・核の逆転と参照型の不変性を使う |
