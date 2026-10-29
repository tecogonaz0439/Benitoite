# UB10.01〜.02 の結果: 利用者のエフェクトの境界の点検（Q9 の (c)、Lean の側）

2026-10-27。plan「本番を変えない並行作業」の UB10.01 と UB10.02 を、この順に一つの作業で行った。担当は Claude のサブエージェントである。作業用のディレクトリは `<wt>`（ブランチ `m013/ub10`）であり、コミットは取りまとめが行う。README の Q9 の決定（(c) 今のままとする）を前提にし、Q9 の答えは再び求めていない。

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | UB10.01（宣言の同一性・操作の名前・具体化した署名）、UB10.02（対象の代数・表の認定元・将来の追加の候補） |
| B_WORK | `ad97eec0c30287a4ef7b9eb7778b3f07db2a0c76`（L00.05 の取り込みの後の本線） |
| 閉じた範囲 | L00.01 の二案（試行の記録と比較用の模型）、L00.02〜.05 の模型（`formal/Benitoite/Scope/` の6ファイル）と本番の `Release` の利用者のエフェクトの定義を読み、(c) の下で利用者の操作が Top の原子のまま扱われること、範囲付きの標準の操作と混ざらないこと、認定元が標準だけであることを点検した。後に (a) を足す位置と、(b) で再設計になる点を表にした。読解で決まらない一部を、リポジトリの外の一時ファイルで Lean に確かめさせた |
| 未完 | なし。Rust の側（UB20）、境界文書と独立レビュー（UB30）は範囲外 |
| 本番の変更 | なし。本番を変える必要は見つからなかった |

## 変更と接続

| ファイル | 変更 |
|---|---|
| `ub10/results.md` | 新規（本書） |
| `ub10/checks.lean`・`ub10/checks.log` | 新規。リポジトリの外で走らせた確かめの一時ファイルの写しと、その出力（下の「検査」） |

`formal/` の Lean、設計書、既定の import は変えていない。利用者の新しい引数、使わない構成子、範囲の変数の先置きは加えていない。

本書の「区分」の列は、定義・記録を読んで確かめたものを「事実」、Lean に確かめさせたものを「事実（Lean）」、読解からの見込みを「推測」と書く。根拠の位置は `formal/Benitoite/` からの相対パスで示す。

## UB10.01 宣言の同一性・操作の名前・具体化した署名

### 利用者の操作が Top の原子のまま扱われ、標準の操作と混ざらないこと

| 点検の項目 | 結果 | 区分 | 根拠 |
|---|---|---|---|
| 操作の参照の同一性 | 本番の操作の参照 `OpRef` は `user o`・`prim b`・`fail` の別の構成子である。節の照合 `handles`・`findClause` は `c.op == o` で比べるので、同じ綴りの利用者の操作と組み込みの操作の節は混ざらない。Surface の `Clauses` も同じ `Release.OpRef` を持つ | 事実（Lean） | `Release/Syntax.lean` の `OpRef`、`Release/Typing.lean` の `handles`、`Release/Semantics.lean` の `findClause`・`SplitAt`、`Surface/Syntax.lean` の `Clauses`。`checks.lean` の 1 で `OpRef.user "File.writeTextIn" == .prim "File.writeTextIn"` が偽であることを確かめた |
| エフェクトの名前の同一性 | `effOps` は利用者の表 `P.effects` を先に引くが、`Program.EffectsOk` の第三の連言が「利用者が宣言したエフェクトの名前は組み込みのエフェクトの名前と重ならない」を要求する。名前全体の除去 `handled` は `effOps` を通すので、名前ごとに一方の操作の一覧だけを使う | 事実（Lean） | `Release/Assumptions.lean` の `Program.EffectsOk`、`Release/Typing.lean` の `effOps`・`handled`。`checks.lean` の 1 で第三の連言の取り出しを確かめた |
| 利用者の操作の効果 | 本番の `V_Op` は `Eff.single od.eff`（名前だけの一原子）を生じる。案 (i) の試行は `Eff.single l` を Top の原子 `.nameTop l` の一原子のまま保った。案 (ii) の試行は `OpDecl.eff`・`Program.effects`・`Declarations.effects` の鍵を元の名前にし、`V_Op` を Top の原子のまま保った | 事実 | `Release/Typing.lean` の `V_Op`（`checks.lean` の 1 で型を確かめた）、[l00.01/candidate-i/results.md](../l00.01/candidate-i/results.md) の「`Eff.single l` は `.nameTop l` の一原子のまま」、[l00.01/candidate-ii/results.md](../l00.01/candidate-ii/results.md) の「所有元の差」の行 |
| 利用者の操作の節の型 | 本番の節の型付け `HasTypeClausesQ` は `opSig P B o` の署名で節を検査し、`.user o` の腕は宣言の型そのものを返す。(c) では利用者の操作の節に範囲の添字 S を選ぶ規則（L00.03 の `clauseIndex`）は要らず、宣言に書いた固定の型で節を型付ける | 事実（定義）・推測（`clauseIndex` を使わないこと） | `Release/Typing.lean` の `opSig`・`HasTypeClausesQ.cons`、判断 11 は新しい標準の操作の節の規則である |
| `main` の上限 | `StateTy` の一部の `BuiltinOnly` は、継続の末尾の効果の各原子に `P.effects l = none` を求める（E0506 の Lean の側）。L00.04 の推す案 BB は、この定義の意味を Top の像の上で保つ。処理した利用者のエフェクトは上限に残らない | 事実 | `Release/Semantics.lean` の `BuiltinOnly`、[l00.04/results.md](../l00.04/results.md) の「L00.01 の申し送り 2」 |
| 署名表の鍵 | L00.03 の `Table.sig` の鍵は組み込みの操作の名前である。操作の一覧 `effects`、種類 `effKind`・`valKind`、制約 `admitsR`、資源 `isResource`、形の検査 `shapeOk`、信頼条件 `CoreAssumptions`・`TargetAgreement` は、すべて組み込みの表 `Table` の欄だけを読む。利用者の宣言の欄はない | 事実（Lean） | `Scope/SignatureExamples.lean`。`checks.lean` の 2 で、利用者のエフェクトの名前を `opEff` に持つ項目と、表の一覧にない操作の名前が `shapeOk` を通らないこと、`effKind`・`valKind` が利用者の名前に `none` を返すことを確かめた |
| 範囲の数だけ鍵を増やさない | 具体化は名前・`opEff`・種類・形を変えない（L00.03 の `Entry.inst_names`・`inst_opEff`・`writeTextIn_key_independent`、案 (i) の模型の `readTextIn_op`、案 (ii) の模型の `callSig_same_key`・`handled_scope`）。後に (a) を足しても、利用者の操作の名前（鍵）は範囲によらない形を保てる | 事実・推測（(a) の部分） | 各模型 |
| 範囲の変数の置き場所 | L00.03 の `Ix.rvar` の説明は「範囲の変数は組み込みの署名の中だけに現れる」とする。ただし模型には、利用者の宣言に `rvar` が現れないことを強制する整形式性はない（模型は利用者の宣言を持たない） | 事実 | `Scope/SignatureExamples.lean` の `Ix` の説明。本番の `OpDecl.Scoped` は型の変数の番号だけを確かめる（`Release/WellFormed.lean`） |
| 固定の範囲を持つ引数 | (c) は利用者の操作の通常の引数に `Scope.PathIn["/data/reports/**"]` のような固定の範囲の型を書くことを認める（user-effect-scopes の (c) の例）。案 (i) では `Ty.opaque o r` の r、案 (ii) では `OpaqueDesc.index` に閉じた範囲を置けば、`V_Op` の `fnTy` の引数型にそのまま入る | 推測 | L00 の模型は利用者の操作を写していないので、例はない（下の「未確認」） |

結論: (c) の下で、利用者の操作は二案のどちらでも Top の原子のまま扱われ、範囲付きの標準の操作とは、操作の参照の構成子（照合）、エフェクトの名前の互いに素な表（鍵と名前全体の除去）、組み込みの表だけを読む形の検査と信頼条件（署名と認定）の三点で分かれる。L00.01〜.05 の骨格に、この分離を崩す定義は見つからなかった。

### 後に (a) を足すときの挿入位置

(a) は user-effect-scopes の最小案（一宣言に標準の種類の範囲パラメータを一つ、各操作に R を持つ認定値の引数を一箇所、結果に R を持たない、節の S は判断 11 と同じ規則）とする。下の表は挿入位置の見込みであり、L00 の骨格で試していない。

| 定義 | 範囲の引数が入る位置 | 案 (i)（構成子の引数） | 案 (ii)（名前の記述と署名表） | 区分 |
|---|---|---|---|---|
| 宣言の範囲の束縛（種類・個数） | `Program`（と Surface の `Declarations`）に、エフェクトの名前から範囲の種類への表を加えるか、`OpDecl` に `nranges` と種類の欄を加える。L00.03 の `Table.effKind` に当たる表を利用者の側にも持ち、`effOps` と同じく利用者の表と組み込みの表を順に引く一つの関数にする | 差なし | 差なし | 推測 |
| 対象の位置 | `OpDecl` に、L00.03 の `IOShape.single k pos` に当たる認定値の引数の位置を加える | 差なし | 試行の `Sig.target : Option Nat` と同じ形で足りる（最小案は一箇所） | 推測 |
| 操作の引数型の範囲の変数 | `OpDecl.params` の型の範囲の位置。範囲の変数を型に置く案（L00.03 の `Ix`）なら、宣言のデータに `opaque "Scope.PathIn" (rvar 0)` を書ける。表の項目を範囲の列からの関数として持つ案なら、利用者の宣言から関数を作る変換が要る | `Ty.opaque o ix` | `OpaqueDesc.index : Ix` | 推測 |
| 整形式性 | `Ix` の案では、`OpDecl.Scoped` に「範囲の変数の番号が `nranges` より小さい」を加える。(c) の間は利用者の宣言の `rvar` を拒否する条件が要る（同じ欄の 0 の場合） | 差なし | 差なし | 推測 |
| 操作の効果 | `V_Op` の `Eff.single od.eff` を、範囲の変数を持つ一原子の具体化へ変える | `Atom.name l ix` | `Atom.name ⟨l, ix⟩` | 推測 |
| 呼び出しの具体化 | `V_Op` に範囲の列と、L00.03 の `RangeAdmissible` に当たる条件（個数・`Range.WF`・`Range.FitsKind`）を加える。項 `.op o ts` に範囲を持たせるかは、組み込みの `.prim` について L00.08 が選ぶ形に揃える | 差なし | 試行は `V_Prim` の暗黙の R で項を変えなかった | 推測 |
| 署名の取り出し | `opSig` の `.user` の腕と `OpSig` に、範囲の変数の数と具体化を加える。L00.03 の `Entry.inst` と同じ具体化を共有できる | 差なし | 差なし | 推測 |
| 節の添字と節の引数 | `HasTypeClausesQ` の署名を `clauseIndex` の S で具体化する。`clauseIndex` と `clause_arg_typed` は名前 l と値型の名前 o を全称で量化し、組み込みの表を読まないので、利用者の名前の原子にそのまま当てられる | 差なし | 差なし | 事実（Lean。定義が名前によらないこと）・推測（本番への接続） |
| 名前全体の除去 | `handled`・`effOps` は変えない。範囲によらず名前の全操作の節で除く | 腕に束縛を一つ足す | `handled_scope` が `rfl` で成り立つ形 | 事実（模型）・推測（(a)） |
| 操作の捕捉の意味 | `E_Op` の節の本体へ範囲の代入は要らない見込み（S は型検査器が選ぶ閉じた範囲で、節の型に範囲の変数が残らない） | 差なし | 差なし | 推測 |
| 信頼条件 | 足さない。利用者の操作は IO を行わず、`CoreAssumptions`・`TargetAgreement` は組み込みの表の欄だけである。R→S の所属の移し替えは `clause_arg_typed` と同じく値の型付けと範囲の包含から証明する | 差なし | 差なし | 事実（模型の欄）・推測（(a) で足りること） |
| `main` の上限（`BuiltinOnly`、E0506） | 変えない | 差なし | 差なし | 推測 |
| 局所解析（L00.05） | 変えない。R は認定された値の型の添字から型検査が決め、利用者の宣言を規則の表に入れない | 差なし | 差なし | 推測 |

### 二案のどちらで足しやすいか

| 観点 | 案 (i) | 案 (ii) | 判定 |
|---|---|---|---|
| 原子と型への範囲の格納 | `Atom.name l ix`・`Ty.opaque o ix`。利用者の原子にも同じ構成子で範囲を置ける | `EffDesc`・`OpaqueDesc` の欄に置ける。鍵を元の名前に分けているので、名前全体の除去が範囲によらないことを `rfl` で得る | 差は小さい |
| Top への黙った狭め | 明示の構築関数を使えば、Top に特化した箇所が差分に列挙される。(a) で非 Top を許す箇所を探しやすい | `String` からの暗黙の変換を置くと、利用者の原子が黙って Top になっても検出しにくい（L00.01 の記録の2件の例と同じ危険） | 変換を置かなければ差は小さい。(ii) を採るなら変換を置かないことが (a) にも要る |
| 署名の範囲の変数（L00.03 の `Ix` と関数の案） | 二案に共通の選択 | 二案に共通の選択。試行の `Sig.target` と `withIndex` の形は (a) の最小案には足りるが、範囲が二つの宣言や結果に R を持つ形を表せない | 足しやすさを主に決めるのはこちらで、`Ix` の案が有利（宣言をデータのまま持て、`shapeOk` と同じ Bool の検査で宣言の整形式を書ける） |

結論: 格納方式 (i)・(ii) の差は、(a) の足しやすさについては小さい。(a) を足しやすくするのは、L00.08 で選ぶ範囲の変数の表し方を `Ix` にすることである。関数の案を採っても (a) の道は閉じないが、利用者の宣言から関数を作る変換と全称の命題の検査が加わる。いずれも推測であり、本番で試していない。

## UB10.02 対象の代数・表の認定元・将来の追加の候補

### 認定元が標準の操作だけであること

| 点検の項目 | 結果 | 区分 | 根拠 |
|---|---|---|---|
| 対象の代数の独立 | `Scope/Domain.lean` は `import Std` だけに依存し、`Range`・`Kind`・`Target` とその所属・正規化・整形式性は名前（エフェクト・型・操作）を引数に持たない閉じた帰納型と述語である。`Kind` は `path`・`host`・`endpoint` の三つだけ | 事実 | `Scope/Domain.lean`、[l00.02/results.md](../l00.02/results.md) |
| 名前と種類の対応 | `Range.FitsKind r k` は種類の一致だけを見る。名前と種類の対応は署名の表が持つ（L00.02 の申し送り 1） | 事実 | 同上 |
| 値型の所属の認定 | L00.03 の値の型付けは、範囲付きの値の所属を `K o = some t.kind ∧ r.Mem t` で与え、`K` は組み込みの表の `valKind` である。利用者の不透明型の名前では所属が成り立たない | 事実（Lean） | `Scope/SignatureExamples.lean` の `HasTypeV`。`checks.lean` の 2 の `user_opaque_not_scoped`（公理は `propext`・`Classical.choice`・`Quot.sound` だけ） |
| 形の検査と制約の認定 | `shapeOk`・`RangeAdmissible`（`admitsR`）・資源の判定は組み込みの表の欄で決まる | 事実（Lean） | 同上、`checks.lean` の 2 |
| 局所解析の認定 | L00.05 の規則の表は、出現の同定 `apiAt`（解決済みの宣言）と宣言の名前から規則への `rules` の二段で引く。評価関係の構成子は `apply` 一つで、同定されない出現には規則を適用できない（`evalScope_unidentified`）。例の `keyUser`（同じ綴りの利用者の関数の出現）は同定されず、由来を作らない | 事実（Lean） | `Scope/InferenceExamples.lean`。`checks.lean` の 4 で `toyTable.ruleAt keyUser = none` を確かめた |
| 同定の性質の置き場所 | 「利用者の関数は `apiAt` に現れない」は表の値の性質であり、型では強制していない。既存の区間解析の `ConcreteEnv.standardAt` も、`apiAt` と `standards` の一覧で同じ形をとる | 事実 | `Scope/InferenceExamples.lean` の `ScopeTable`、`Interval/Eval.lean` の `ConcreteEnv.standardAt` |
| 規則の追加 | 規則の追加は表の項目と `RuleSound` の補題の追加で済む（`apply_sound`）。利用者の宣言を規則の表の項目にする経路は模型にない | 事実 | `Scope/InferenceExamples.lean` |
| 表の追加の分割 | 署名表に項目を一つ加えた表の欄は、元の表の欄と加えた項目の条件に分かれる（`fieldNew_extend`）。旧の項目だけなら量化を広げた欄は旧の欄と同値（`fieldNew_iff_old`） | 事実 | `Scope/SignatureExamples.lean` |

結論: L00.02 の `Range` と L00.05 の規則の表は標準の操作だけを認定元とし、利用者の定義した名前は、値型の所属・形の検査・制約・局所解析の規則のどれにも入らない。ただし局所解析の出現の同定から利用者の関数を除くことは、表を作る側（Surface の解決と Rust の解決器）の性質であり、その確かめは L40・UB20・K10 に残る。

### (a)・(b) で足すことになる候補

「閉じていない」は、0.0.13 の骨格の定義を変えずに、拡張（欄・表の項目・条件の追加）で足せる見込みを表す。「再設計が要る」は、骨格の中心の定義の形を変える必要がある見込みを表す。どちらも推測であり、試していない。

| 候補 | (a) 標準の範囲引数だけ | (b) 型引数と範囲引数 | 理由・関係する定義 |
|---|---|---|---|
| 宣言の構文（`effect Report[scope R: Path]`、`effect Store[T, scope R: Path]`） | 閉じていない。Lean の Surface は宣言の構文を持たず、解決済みの宣言表を持つので、`Declarations` と `Program` に範囲の束縛の欄を足す | 再設計が要る。エフェクトの宣言の型パラメータを操作間で共有する欄と、操作自身の型パラメータとの二段の束縛が要り、`HasTypeClausesQ` の剛な型の束縛（`sg.tparams ++ C`）と番号のずらしを変える | `Release/Syntax.lean` の `OpDecl`・`Program`、`Surface/Syntax.lean` の `Declarations`、`Release/Typing.lean` の `HasTypeClausesQ`。構文そのものは Rust の側（UB20） |
| 型の添字（範囲の種類） | 閉じていない。標準の `Kind` だけを使うので `Domain` は変えない。`Ix` の案なら利用者の宣言の型に `rvar` を置け、`OpDecl.Scoped` の条件を足す | 範囲の部分は (a) と同じ。型引数の部分は下の「原子の表現」 | 利用者が範囲付きの値型や独自の対象の種類を定義することは三案とも対象外であり、`valKind` に利用者の名前を入れる経路は作らない |
| 原子の表現 | 閉じていない。二案とも原子は型を含まず、範囲（`Range`）だけを持つ | 再設計が要る。型引数を持つ原子は「原子は型を含まない」分離（`Release/Atom.lean`）を変える。`Eff.fails` と同じ別成分に置く案でも、原子の符号と順序（`Order/Atoms`）、正規化、包含、代入、整形式性を作り直す | `Release/Atom.lean`、`Release/Types.lean` の `EffR`（`atoms` と `fails`） |
| ハンドラの節の範囲 | 閉じていない。`clauseIndex`・`clause_arg_typed` は名前によらない。`opSig` の `.user` の腕の具体化と、保存の定理の `E_Op` の場合の R→S の所属（被覆の健全性と継続の型からの導出。組み込みの `E_OpPrim` と同じ義務）を足す | 再設計が要る。名前全体の除去で T の全ての具体化を処理し、同名で T の違う原子を Top とするには、`clauseIndex` が型の等号を比べ、`handled` が型付きの原子を扱う必要がある | `Scope/SignatureExamples.lean` の `clauseIndex`・`clause_arg_typed`、`Release/Typing.lean` の `handled`・`HasTypeClausesQ`、`Release/Semantics.lean` の `E_Op` |
| 署名の具体化と許容 | 閉じていない（`Ix` の案）。`Entry.inst` と `RangeAdmissible` を利用者の `OpDecl` に共有する。関数の案なら変換と全称の検査が加わり費用が増える | 範囲の部分は (a) と同じ。型の部分は既存の型代入に、エフェクトの宣言の型引数の代入が加わる | `Scope/SignatureExamples.lean` の `Entry.inst`・`RangeAdmissible`、L00.03 の「署名の範囲の変数の表し方」 |
| 局所解析の規則 | 閉じていない。規則の表に利用者の宣言を加えない。R は認定値の型の添字から型検査が決める | (a) と同じ | `Scope/InferenceExamples.lean`。判断 7 は局所の束縛の一般の定数伝播を加えない |
| 信頼条件 | 閉じていない。欄を足さない（利用者の操作は IO を行わない）。利用者の宣言に健全性を仮定する欄を作らない | (a) と同じ | L00.03 の分離の候補 S1（`CoreAssumptions`・`TargetAgreement` は組み込みの表の欄） |
| 観測と対象の健全性（L00.04） | 閉じていない。観測は組み込みの IO の事象だけが持ち、利用者の操作の捕捉の遷移は事象を出さない。節の範囲付きの IO は既存の言明のまま外側の上限で追う | (a) と同じ | `Scope/TargetExamples.lean`、`Release/Semantics.lean` の `E_Op`（事象は `none`） |
| `main` の上限と表示 | 変えない。処理した名前は `main` の型から消える（docs/todo の TODO-054・302 は (a) でも解決しない） | (a) と同じ | `BuiltinOnly`、判断 13・17 |

## 未確認

| 事項 | 確かめられなかったこと |
|---|---|
| (a) の本番の成立 | 上の挿入位置で、部分ハンドラ・関数値になった操作・未処理の操作・継続とストア・Surface の検査と脱糖まで主定理を保てること。L00 の骨格では試していない |
| (b) の再設計の規模 | 型付きの原子の表現の選択と、作り直す定義と証明の範囲 |
| 項に範囲を持たせるか | L00.03 の模型の δ は範囲の列を引数に取り（`delta b rs ws`）、L00.05 の推す案 A は実行時に具体化した R を確かめる。一方、L00.01 の案 (ii) の試行は `V_Prim` の暗黙の R で項 `.prim b ts es` を変えなかった。どちらに揃えるかは L00.08 の決定待ちであり、`.op` への影響もそれに従う |
| `Ix` の案の整形式性 | 本番の `OpDecl.Scoped`・`Ty.WF` に、(c) の間の「利用者の宣言に `rvar` が現れない」をどう入れるか。未設計 |
| 固定の範囲を持つ利用者の操作の引数 | (c) の例（利用者の操作の引数に `PathIn["/data/reports/**"]`、節で `File.writeTextIn` へ転送）を写した Lean の例はない。本番の `V_Op` の型にそのまま入るという読解だけである |
| 出現の同定の正しさ | `apiAt`・`standards` に利用者の関数が入らないことは、Surface の解決と Rust の解決器・交換で確かめる必要がある |
| `E_Op` の範囲の代入 | (a) で節の本体へ範囲の代入が要らないという見込み |
| 交換の形式 | 利用者の原子を Top（旧の名前だけ）として書き出すこと。`Exchange/*` は点検していない（L50） |

## 申し送り

本番を変える必要は見つからなかったので、L/R の担当へ変更の依頼はない。以下は点検の結果から渡す事項である。

### L00.07（非空例と切り替えの整合）へ

1. (c) の利用者の操作の例を、非空例の一つとして置くことを推す。利用者の操作の引数に固定の範囲の型を書き、節で範囲付きの標準の IO へ転送し、処理した後の上限に `File.Write[R]` が残り利用者の名前が残らない例である（user-effect-scopes の (c) の `saveToFile`）。既存の構成子だけで書け、新しい引数や構成子を要しない。
2. `Ix` の案を候補に残すなら、範囲の変数が組み込みの署名の中だけに現れる条件を、どの整形式性に置くかを例と合わせて示す。

### L00.08（骨格のレビュー・一括の問い・最終配置）へ

1. 範囲の変数の表し方（`Ix` か関数か）の判断材料に、後の (a) の足しやすさ（`Ix` が有利）を加える。格納方式 (i)・(ii) の差は (a) については小さい。
2. 案 (ii) を採る場合は、`String` から Top の記述への暗黙の変換を置かない（L00.01 の推す形）。利用者の原子が黙って Top に狭まる箇所を残さないためでもある。
3. 項に範囲を持たせるか（`.prim`）を決めるとき、後の (a) の `.op` も同じ形に揃える前提で決める。0.0.13 では `.op` を変えない。
4. 信頼条件の分離（S1〜S3）を選ぶとき、信頼条件を組み込みの表の欄に限り、利用者の宣言に仮定の欄を作らないことを確かめる。
5. エフェクトの名前から範囲の種類を引く表（L00.03 の `effKind`）は、0.0.13 では組み込みの表だけに置く。(a) のときに `effOps` と同じ順で利用者の表を引く関数を一つ足せる形にするが、利用者の側の欄を先置きしない。

### UB20（Rust の側の点検）へ

1. 標準の認定（`effKind`・`valKind`・`admitsR`・局所解析の規則の表に当たるもの）が一箇所の分類と署名表に集まり、利用者の名前がその表に入らないこと。出現の同定（`apiAt`・`standards` に当たる解決）が同じ綴りの利用者の関数を標準に解決しないこと。
2. 利用者のエフェクトの名前と組み込みのエフェクトの名前の重なりを拒否すること（`Program.EffectsOk` の第三の連言の Rust の側）。範囲引数を書いた利用者のエフェクトの参照を E0513 で拒否すること（判断 12）。
3. 節の照合で利用者の操作と組み込みの操作を区別すること（`OpRef` の `user`・`prim` に当たる区別）。
4. 交換と表示で、利用者の原子を範囲なし（Top）として扱い、処理済みの名前を `effects.bounds` や権限の項目へ戻さないこと（判断 13・17）。
5. (c) の例（利用者の操作の引数に固定の範囲の型）を受理し、処理した後の上限に節の範囲付きの標準の IO だけが残ること。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 確かめの一時ファイル（1回目） | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <一時ディレクトリ>/ub10_checks.lean` | 1（下の「失敗と修正」） | 0.88 秒 | 本書 |
| 確かめの一時ファイル（2回目） | 同じ | 0。出力なし | 0.84 秒 | 本書 |
| 確かめの一時ファイル（3回目、`#print axioms` を加えた最終） | 同じ | 0。`user_opaque_not_scoped` の公理は `propext`・`Classical.choice`・`Quot.sound` だけ | 0.83 秒 | [checks.lean](checks.lean)・[checks.log](checks.log) |
| work の dry-run | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base ad97eec0c30287a4ef7b9eb7778b3f07db2a0c76 --dry-run` | 0。変更4件（本書・`checks.lean`・`checks.log`・dry-run の記録）を文書と分類し、選択なし（`nothing to check: only documents changed`） | 0.07 秒 | [work-check-dry-run.log](work-check-dry-run.log) |

一時ファイルは、作業用のディレクトリの既存の生成物（`formal/.lake` の中のもの。記録上は本線の取り込みのときに作られたもの）を読み込んだ。全体の `lake build` は走らせていない。読み込んだモジュールの元のファイルは B_WORK から変わっていない（`git status` が空）。

依頼のとおり、検査は dry-run だけを走らせた。

## 最大常駐量

`/usr/bin/time -l`（macOS）の `maximum resident set size` の原値（バイト）。一度に一つのプロセスだけを走らせた。

| 実行 | 原値 | MiB | GiB |
|---|---:|---:|---:|
| 確かめの一時ファイル（最大、3回目） | 766230528 | 730.7 | 0.71 |
| work の dry-run | 10256384 | 9.8 | 0.01 |

`-M 12288` は変えていない。

## 失敗と修正

- 確かめの一時ファイルの1回目が終了1。`#guard` の前に文書のコメント（`/-- … -/`）を置いたため、構文の誤りになった。行のコメント（`--`）に改めた2回目は終了0。3回目は公理の確かめを加えた最終の状態での再実行である。

## ずれと申し送り

計画からのずれはない。依頼文が許す範囲（`ub10/` と、リポジトリの外の一時ファイル）だけに書いた。docs/todo への転記の案は UB30 の担当が用意する（plan の UB30 の行）。

## 時間

| 項目 | 時刻・時間 |
|---|---|
| 開始 | 19:26（JST） |
| 終了 | 19:34（本書の作成まで） |
| 外側の所要 | 約8分（記録した開始から）。開始の記録の前に、依頼文・共通依頼文・README・decisions・plan を読んだ数分があり、計っていない |
| 能動時間 | 約10分（読む約5分、一時ファイル約1分、本書約4分。開始の記録の前の読みを含む見積もり） |
| 検査 | 一時ファイル 3回で計約3秒、dry-run 0.07 秒 |
| 見込みとの比較 | 見込み 1〜3時間（各枝 0.5〜1.5時間）に収まった。上端の2倍（6時間）を超えていない。区切りの提案はない |
