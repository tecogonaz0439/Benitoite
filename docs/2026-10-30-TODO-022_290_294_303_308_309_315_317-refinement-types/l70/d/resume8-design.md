# 再開8: 判定の結果型と欄参照の実装の詳細

## 対象と証拠の区別

今回の表層の規則は、判定の結果の真偽と、元の対象についての述語の一致を結果型に表す。対象の値を直接渡す場合と、レコードの欄を判定する場合を扱う。通常の判断と範囲変数を含む開いた判断に同じ二規則を追加し、性質1、有効範囲、checkerと推論を追随させた。十四関数の各行、内部行の応答と標準表への追加、開いた契約の受理の全体は、[結果](results.md#再開8j70-9)、[内部行の記録](resume8-predicate-rows.md)、[開いた契約の記録](resume8-open-contract.md)に分けて記す。

検査の証拠は三つに分ける。表層の規則と性質1は任意の適切な宣言表・組込みの表について証明する。内部行の全入力の応答は、その行の `Valid` とプログラムの整形式・変性の条件から証明する。実入口の具体例は、有限の入力に対する `checkExpr` と `checkDef` の計算の成功又は拒否を示す。この三つを区別し、小さい具体表の実入口の成功から、未使用の全標準署名を含む `Check.Input.Sound` 全体まで証明したとはしない。

## 結果型と内部の呼出し

結果型は、対象の項を `t`、対応する述語を `p(t)` とすると、次の形である。

```text
Boolean{b | (b = true ∧ p(t)) ∨ (¬(b = true) ∧ ¬p(t))}
```

この篩の自己変数は番号0である。外側の文脈の対象の項は、篩の中へ入れる際に一つ持ち上げる。例えば、対象が表層の局所変数0なら、結果の篩内の対象は変数1になる。対象を持ち上げなければ、文字列や浮動小数点の述語が結果のBoolean自身を参照し、整列の条件を満たさない。

固定する条件は内部行に記録する。`Scope.pathMatches` と `Scope.hostMatches` は解析した絶対形のpattern、`String.charactersIn` は二つの文字リテラル、浮動小数点の分類は幅と分類の種類を記録する。値の直接の行は対象一つを値引数とし、型・行・範囲パラメータを持たない。欄の行は根のレコードの型パラメータと、根の値一つを受け取る。呼出し元の項や範囲変数を内部署名へ埋め込まない。

内部の呼出しは、既存の表層の構文を用いて次の二形で表す。

```text
scalar:
  partialCall (primName internal ts es xs) []
    (expr none 0 target nil) result effect

欄参照:
  partialCall (primName internal ts es xs) []
    (expr none 0 root (expr none 1 source nil)) result effect
```

ここで `source` は元のgetterの式である。番号0の式は実行時の値引数、番号1の式は元の式の型を再検査するための情報である。二形とも穴を持たない。利用者向けに穴のない部分適用の記法を追加するものではない。

元の公開の `primName` による呼出しと、解決後の内部形も区別する。名前の解決は、ラベルと契約位置を検査し、宣言順に並べた引数から固定できる条件を読み取って内部形を作る。動的なpattern又は文字集合の端など、固定できない条件は元の公開呼出しを保ち、結果型は素のBooleanとなる。元の `E_CallDirect` とその脱糖を、任意の組込みの表について内部行が存在する規則へ変更していない。

## 二規則の前提

通常の [Rules.lean](../../../../formal/Benitoite/Release/Refinement/Surface/Rules.lean) と、開いた [OpenSurface.lean](../../../../formal/Benitoite/Release/Refinement/Surface/OpenSurface.lean) に、`E_PredicateCall` と `E_PredicateProject` を追加した。開いた規則では種類列 `ks` を判断に含め、各前提を同じ種類列で読む。

| 前提 | `E_PredicateCall` | `E_PredicateProject` |
|---|---|---|
| 呼出しの頭 | `primName` の `CallHeadTy`。辞書引数は空 | 同じ |
| 実行時の値 | `target.valueOf? = some v` | `root.valueOf? = some v` |
| 元の欄の式 | 前提なし | 同じ文脈で `source : input ! Eff.empty` |
| 依存列の値引数 | 文脈を増やさず、元の文脈の `[v]` を渡す `ValsTel` | 同じ |
| 結果型 | 依存列の戻り値 `r` から注釈 `b` への `Le` | 同じ |
| 効果 | 注釈の効果 `ε` が依存列の効果 `ec` を覆う | 同じ |
| 注釈 | `b` の形成 | 同じ |

`E_PredicateProject` の `input` は、checkerが元の `source` から推論した型である。根のレコードを内部行へ渡せることだけで、元のgetterの型引数を正しいことにはしない。例えば、`Outer[Unit]` の欄を得た後、内側の `Box` のgetterを `String` で具体化すると、保持した元の式の検査が拒否する。

この前提は核の呼出しの型付けの構成には使わないが、表層の元の式の検査を保存するために必要である。`PredicateProjectSource.lean` の通常・開いた `predicateProject_source` は、投影の内部形の型付けから、同じ文脈で元の `source` を純粋に型付けた証拠を取り出す。`E_Sub` による結果型や効果の拡大を重ねても、この結論を保つ。`PredicateProjectionCalls.resolve_source_checked` と `resolve_source_checked_open` が、解決に成功した元のgetterの式にこの性質を適用する。

## 脱糖と性質1

[Desugar.lean](../../../../formal/Benitoite/Release/Refinement/Surface/Desugar.lean) の `directValueCall?` は、内部形の番号0を値へ写し、核の `app (prim ...) [v]` を作る。投影の番号1に保持した元のgetterの式を重ねて評価しない。`desugar_predicateCall` と `desugar_predicateProject` は、この直接の核の呼出しとの等式を示す。

この処理では元の値を一時変数へ置き換えない。一般の直接呼出しのように引数を先に束縛すると、依存する戻り値がその一時変数を参照し、外側の元の項についての事実を取り出せない場合がある。元の値を直接渡すことにより、結果の篩の対象は元の文脈の項になる。String・Floatについて未証明の等号を追加する必要もない。

通常の [Property1.lean](../../../../formal/Benitoite/Release/Refinement/Surface/Property1.lean) は、頭の型付けと `ValsTel` から核の `C_DependentApp` を作り、既存の `C_Sub` で結果型と効果を注釈へ広げる。新しい核の型付け規則とStepの規則は追加しない。

開いた [OpenSurfaceProperty1.lean](../../../../formal/Benitoite/Release/Refinement/Surface/OpenSurfaceProperty1.lean) は、一度の開いた表層の導出を、全ての適格な範囲の具体化へ写す。値の直接の脱糖と範囲の具体化の交換、値引数の依存列、開いた部分型と被覆の具体化を用いて、具体化後の同じ核の呼出しを型付ける。範囲文脈を空に制限する前提は足していない。

有効範囲の証明も通常・開いた判断の両方を追随させた。`Expr.valueOf_scoped` は、値へ写した根又は対象の有効範囲を表層の式の有効範囲へ対応させる。投影の元の `source` の有効範囲は、その型付けの前提から得る。

## 既存の補助四件に加えた前提

既存言明の差六件のうち、受理後の二言明は[開いた契約の記録](resume8-open-contract.md)で説明する。残る四件は、開いた部分適用の脱糖の内部の補助である。

| 補助 | 追加した前提 | 元の読者からの供給 |
|---|---|---|
| `OpenSurface.partialCallDirect_core` | `args.holeTypes ≠ []` | `E_PartialCallDirect` の既存の前提 |
| `OpenSurface.partialCall_core` | 同上 | `E_PartialCall` の既存の前提 |
| `OpenSurface.partialCallDirectDep_core` | 同上 | `E_PartialCallDirectDep` の既存の前提 |
| `OpenSurface.partialCallDep_core` | 同上 | `E_PartialCallDep` の既存の前提 |

穴のない内部形について脱糖に直接の呼出しの分岐を加えたため、内部の補助でも通常の部分適用の穴が非空であることを明記した。この前提がなければ、引数が値一つで穴が空の部分適用を全てラムダへ脱糖する補助の結論は成り立たない。

元の四つの表層の規則は、範囲の有無にかかわらず既にこの非空の前提を持つ。性質1の既存の四場合は、その前提を補助へ渡す。従って、元の表層の規則の前提、利用者の書ける通常の部分適用、得られる核の型付けの形を変更していない。範囲のない判断でも、元の部分適用の同じ前提から元のラムダの脱糖を得る。四補助を穴の空の場合まで一般化して保つために、元の規則を狭めたり、内部形の脱糖をラムダへ戻したりする案は採らなかった。

## 元のgetterの解析

[PredicateAccessorTargets.lean](../../../../formal/Benitoite/Release/Refinement/Surface/PredicateAccessorTargets.lean) は、観測できる値、括弧、生成したgetterの呼出しを解析する。getterの各段で次を照合し、その証拠を `Resolved` に記録する。

1. 同名の利用者の関数の定義がなく、プログラムの `accessors` で同じgetterを引ける。
2. 構成子の宣言と欄の位置が存在する。
3. 選ぶ欄のsortと、型引数の個数が一致する。
4. 引数が `value` 一つの正しい呼出しである。
5. 受け手も同じ規則で解析できる。

解析の結果 `Parsed` は、元のソース、根の式、根の値、観測する項、各段の宣言と参照の列を対応させる。`Resolved.parse` は、これらの照合の証拠から、実際の `parse` が同じ結果を返すことを証明する。具体例ではこの補題を読み、解析の成功の証拠と、実際の解決が同じソースを処理することを照合した。

`Parsed.accessor_conditions` は、プログラムの `WellFormed` から全ての段の既存の `AccessorOk` を得る。型引数の正しさを、解析した隣接する二段の型引数の単純な構文上の等号へ置き換えない。元のgetterの式は表層の型付けとcheckerで再検査するので、既存の部分型の扱いを保ったまま、誤った子の型引数を拒否できる。

内部名の選択では、行の仕様との一致に加え、実際の名前のlookupが同じ仕様を返すことも照合する。同じ内部名を持つ異なる行が並んでも、名前のlookupが選ぶ先頭の行と、仕様を検索して選ぶ行を食い違わせない。scalarと投影の行を同じ `Row` の表で扱う場合も、この照合を共有する。

## 有限の経路の生成と行の条件

[PredicateAccessorPaths.lean](../../../../formal/Benitoite/Release/Refinement/Surface/PredicateAccessorPaths.lean) の `Chain` は、根の宣言の型から各欄の型へ進む構文上の判断である。dataの段では型名・型引数の個数・欄のlookupを要求し、選んだ欄の正規形へ型引数を `substAt` して次の段を読む。篩付きの受け手ではその基の型へ進める。

`checkChain` は、この判断の証拠を持つ `CheckedChain` を有限の照合から構成する。再帰は段の数と入力の型の大きさの辞書式順序で減る。成功した結果に末尾の型と `Chain` の証拠が含まれるので、経路の正しさを新たな独立の信頼条件にはしない。

次に、`Chain.path` は `Program.WellFormed` と各段の `AccessorOk` から、全ての型付きの根の値について使う `AccessPath` を導く。ここでは根の宣言の型パラメータを記号のまま保つ。途中の欄の型を具体化して経路を連結し、型引数が空、型が単相、又はプログラムに外部宣言がないという制限を加えない。

投影の行の `Valid` を得るには、経路以外の条件も必要である。

| 条件 | 構成又は照合 |
|---|---|
| 根と経路の仕様 | `candidate` と実際のlookup |
| 経路が空でない | `candidate` の非空の段 |
| 途中がdata、末尾が対象のsort | `routeSorts` の有限照合と `candidate_sorted` |
| 末尾が内部行の入力の基本型 | `CheckedChain.leaf.norm.core` の照合 |
| 固定した判定の形成 | `Entry.Valid` |
| 内部署名の形成 | `PrimSig.Scoped`。具体例では既存の有限な形成の検査の健全性から構成 |
| 全ての段の取り出しの条件 | `Parsed.accessor_conditions` と `Program.WellFormed` |

`Parsed.valid_projection` はこれらをまとめて `Valid` を返す。その先は投影行の全入力の応答、行の表の `Rows.Valid`、標準表と内部行を合成する定理が読む。元のソースの収集から、各行の `RowValid` を与える段階を省いてCoreの条件を得ることはしない。

任意の整形式の元ソースについて、解析・経路生成・署名の形成の生成が全て成功するという完備性定理は証明していない。`checkChain` は成功時に証拠を返し、プログラムの整形式と合わせてその経路の健全性を示す。これは生成する行ごとの条件であり、主な十言明や核の判断に追加した信頼条件ではない。実用上、行の収集だけで全ての証明義務が自動的に済むとは扱わず、同じ有限表の各行について `RowValid` を構成してから標準表への追加の定理を使う。

## 実入口と拒否の対照

[PredicateProjectionFixture.lean](../../../../formal/Benitoite/Release/Refinement/Surface/PredicateProjectionFixture.lean) は、型パラメータを一つ持つ二つのレコードを定義する。`Box[A]` は String・Float・A の三欄を持ち、`Outer[A]` は `Box[A]` 一つを持つ。String欄、Float欄、内側のBox欄のgetterを宣言し、プログラムの `formed`、`variance`、`data`、型の形成の `formation_sound` を証明した。

[CheckPredicateProjectionExamples.lean](../../../../formal/Benitoite/Release/Refinement/Surface/CheckPredicateProjectionExamples.lean) は、同じfixtureと、標準表へ内部二行を加える `BuiltinSource.predicates` を実入口へ渡す。受理と拒否の対照は次のとおりである。

| 宣言 | 受理又は意味 | 拒否の対照 |
|---|---|---|
| `text_branches` | `Box[Unit]` のString欄を `String.charactersIn` で判定し、真・偽の両枝の事実を受理 | 同じ二枝を素のBoolean条件にすると拒否 |
| `nested_float_branches` | `Outer[Unit]` から二段辿るFloat欄を `Float.isFinite` で判定し、両枝の事実を受理 | 事実のないBoolean条件では拒否 |
| `open_type_arguments` | `Scope.PathIn[R]` をgetterの型引数へ渡す上の二形を、範囲パラメータを持つ関数の `checkDef` で受理 | 次の行で誤った型引数を対照にする |
| `wrong_child_type` | 保持した元のgetterの型引数を実際に検査 | 閉じた入力では `Outer[Unit]` に対する内側を `String` にし、開いた入力では `PathIn[R]` に対する内側を `Unit` にすると拒否 |
| `wrong_receiver_chain` | 二つの正しい経路は `checkChain` の成功から構成 | 異なる型名の受け手から同じ段を構成すると `none` |
| `rows_valid` | 実際の解析結果と有限な経路の生成から内部二行の条件を構成 | 内部名の非衝突も同じ行で照合 |
| `nested_response` | genericな二段の経路の全ての `BuiltinArgs` に対する型付きの応答 | 入力を具体のFloat一つへ限定しない |
| `text_desugar` | 実際の解決の成功から、根の値一つを渡す核の直接呼出しを得る | 元のgetterの式を二度実行しない |
| `text_source_checked`・`open_number_source_checked` | 通常・開いた解決後の型付けから、元の純粋なgetterの型付けを得る | 型引数を保持せず内部行だけを検査する実装ではこの結論を得られない |

枝の例では、`Unit{u | p(field(root))}` と `Unit{u | ¬p(field(root))}` を要求する。既存のString・Floatのgetterの戻り値型は、その結果と元の欄を等号で結んでいない。そのため、getterの結果を直接 `String{p(self)}` 等へ変える例とは分け、今回追加した条件の結果型から元の欄についての事実が得られることを検査した。

この小さいfixtureについて、未使用の全標準署名を含む `Check.Input.Sound` 全体と、全標準宣言を含む `StandardModel.Includes` は主張しない。具体の実入口の成功、fixture自身の整形式・変性、内部行の `Valid` と全入力の応答が証明済みの範囲である。checkerの一般の健全性と、`Includes` を満たすプログラムの標準表へ内部行を追加する一般のCoreの定理は、それぞれの既存の前提を保つ。

## 検査と残る条件

通常・開いた規則、脱糖、性質1、有効範囲、元ソースの型付けの逆転、解析と有限な経路の生成、fixture、投影の実入口の例は、依存順の単独Leanで検査した。最後の `CheckPredicateProjectionExamples.lean` は終了0・警告0である。本番のソースを固定した後の既定ビルド、全宣言の公理監査、台帳とimportの照合は、取りまとめが各一度実行し、結果を主記録へ残す。検査の最終結果と実行条件からの逸脱は、主記録の「写しと作業末の検査」に記した。

投影の型付けの逆転二件では、97規則の構造上の逆転に既定のheartbeatsが不足したため、当該証明だけを400,000とした。具体値の評価、解析、有限な経路の生成、実入口の計算の上限は増やしていない。型引数を記号のまま扱い、長い列や大きな範囲を作る評価を行っていない。

今回追加した生成条件と二規則の前提は、内部行の正しい署名・応答と、元の表層の呼出しの検査を対応させる条件である。任意の元ソースに対する生成の完備性、又は小さいfixtureの全標準署名に対する入力の健全性へ、証明した結論を拡張しない。新しい公理、`sorry`、核のStepの変更、主な十言明の形の変更は要していない。
