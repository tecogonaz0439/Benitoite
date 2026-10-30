# RV-L00b.02b-values: 値の葉・既存計算の群（L00b.02b-values）の群末の独立レビュー

2026-10-31。レビュー担当は Opus 5.5 のサブエージェントである。対象はブランチ m014/l00b.02b-values の未コミットの作業ツリーにある `formal/` の本番の変更である。B_WORK `fb9afed8` からの差分は、既存11ファイルの変更と、新規17ファイル（Admissible・AdmissibleMap・BuilderExec・Capture・ConstraintAssumptions・Embedding・KindValues・LocalTransport・MethodArguments・RuntimeMatch・RuntimeSyntax・Semantics・Step・StoreTransport・TelArguments・TypingDeclared・ValueInstantiation）から成る。

照合した入力は次のとおりである。

- [レビュー依頼](RV-L00b.02b-values-request.md)
- `l00b.02/signatures.md` の第12節（第12.2節の `.02b-values` の行）・第21〜23節・第2.2節と R2 の行
- `l00b.02/02b-values-contract.md`、`l00b.02/results.md` の `.02b-values` の節、`l00b.02/02b-values-r2-constraint-boundary.lean`
- plan.md の「計画の変更と取りまとめへの確認点」の 2026-10-31 の各行（特に案 A の行）
- decisions.md の D28・D29・D31、前回の [RV-L00b.02a](RV-L00b.02a.md)
- 旧の `formal/Benitoite/Release/Typing.lean`・`Semantics.lean`（旧の型付けと68遷移との比較のため）
- 設計書 01-06 の高カインド型の節

Lean は局所に二回実行した。どちらも補助のファイルをリポジトリの外に置いた。

1. `cd formal && lake env lean -M 12288 <tmp>/rv02bv/head_model.lean`（終了0、約0.4秒、最大常駐約0.7 GB）。篩を剥いだ最上位の形だけを読む非自明な `sat`（鍵の制約は関数・継続・遅延・参照の形を拒む）が、四条件 `Builtins.ValueAssumptions` を満たすことを証明した。公理の依存は propext・Classical.choice・Quot.sound だけである。
2. `cd formal && lake env lean -M 12288 <tmp>/rv02bv/embed_kind.lean`（終了0）。後述の中1を確かめた。

既定の `lake build` は担当の結果（636 jobs、終了0）を引用し、繰り返していない。この記録のほかにリポジトリのファイルを書き換えていない。

## 総評

**条件付き可。** 案 A の四条件は plan.md の判断の範囲に収まっている。四条件は公理ではなく `CoreAssumptions` の欄であり、補助定理へは引数 `hA` として渡る。新しい `axiom` はない。条件は、篩の述語と値の番号を読まない骨格の `sat` で満たせる（Lean で確かめた）。強すぎることはない。V_Map・V_Set・V_Dict・V_Op・V_Fun・V_Prim・C_Meth の SatAll と admits の移送は四条件だけで閉じており、別の前提で穴を埋めてはいない。

型付けの規則に増えた前提は、旧の型付けの WF を Annotation（WF・Sorted・Declared）へ置き換えたものと、宣言の照合と kind の照合である。表層の型検査を通るプログラムは、脱糖後にこれらを満たす。旧68遷移は名前と順序が一致する（機械的に比べた）。障害例の定理は消えていない。場合の数の主張もコードと一致する。`sorry`・`axiom`・`admit`・`native_decide`・`implemented_by`・`unsafe`・`partial`・`extern` の抜け道はない。

ただし、読めば確定する中の所見が二つある。

- 中1：埋め込みが旧の型クラスの引数と型パラメータの kind をすべて value に写す。そのため、この群で C_Meth・V_Fun に入った kind の照合の下では、旧の高カインド型の導出（`implement Functor[Option]` の上のメソッドの呼出しなど）を新しい体系で型付けできない。
- 中2：V_Fun・V_Prim・V_Op の結果を dependentFn に固定した。`.11` で fn と dependentFn を正規化でそろえるまでは、旧で `fn` 型を受け取っていた位置に関数の参照を渡せない。

どちらも今の定理を偽にはしない。しかし D29 の旧の導出の埋め込みの義務の範囲に関わるので、担当の補助契約で済ませず、取りまとめが範囲を決めて記録する必要がある。

受け入れの条件は次の二つである。(a) 中1について、D29 の対象から旧の高カインド型の導出を外すのか、埋め込みに kind を与える手段（旧の宣言からの kind の推論、または別の入力）を設けるのかを決め、signatures.md の第2.2節の埋め込みの行と義務の対応表に記すこと。(b) 中2の依存を義務の対応表に一行で固定すること。

## 依頼の観点ごとの判定

| 観点 | 判定 | 根拠と補足 |
|---|---|---|
| 1. 案 A と D28（四条件の量化・注釈の範囲・単調な改名・供給の経路） | 可（軽3を参照） | `Builtins.ValueAssumptions`（ConstraintAssumptions.lean 16〜29行）は第22節の表示と一致する。改名は厳密に増加する写像に限り、`shiftIndex_strict` で供給している。注釈の三性質は移動の構文の補題から、TypedValueImages は SubstOk の像から供給している。Γ・Φ の意味の充足を外から受け取る前提はない。`CoreAssumptions` は `ValueAssumptions` を含むだけで、`.values` で取り出す。四条件は葉ごとの閉包性ではなく、組込みの表全体の性質である。案 C への置き換えにはなっていない。境界入力は、外側の番号を区別する表が `ValueAssumptions` を満たさないことを示している（`bad_table_excluded`・`bad_admits_excluded`）。三モデルの充足は L50 へ未完のまま残すと明記しており、完了とは数えていない |
| 2. Declared・正則性・of_value と書ける形 | 可（中2・軽4を参照） | 下の「型付けの規則へ足した前提の判定」 |
| 3. 宣言の kind と名目型 | **条件付き（中1）** | 新しい規則は宣言の kind 列を使う。V_Fun・V_Prim は `TParamDecl.kind`、C_Meth はクラスの `argumentKind`、V_Op・V_Con・V_Dict は value を使う。01-06 は、型構成子を表す型パラメータを型クラスの引数と関数の型パラメータにだけ許す。この割り当てはそれと一致する。V_Con は data・arity・欄の WF・具体化した全欄の型付けを照合する。ただし埋め込みの側で kind が失われる。`TypeArgsKinded` の K は前提ごとに選べる（軽2） |
| 4. 局所参照・ストア・None | 可 | `LocalCtx.extend` は既存の要素の kind を `renameKind (shiftIndex 1 0)` で移す（Typing.lean）。空の L でも None の位置を保つ。`LocalSubstOk` は、像の参照が `substKind ν b` の種類を持つことを照合する。値の三判断が任意の ρ を保つ根拠は、V_Lam と C_Lazy が本体を局所文脈 `[]` と `hideBuilders` で検査することである。そのため、値の中から外側の builder を参照できない。値の移動には PreservesNormals、計算の移動には Extends を要求し、hide は `PreservesNormals.hide` で Extends へ移す。場所を消すストアへ移せないことは、境界入力の `cannot_erase_location` と `empty_no_location` が示す。CQ/None の R0 の拘束を handlers に残したことも記録どおりである |
| 5. 依存するメソッド引数 | 可 | `Tel.arguments` は先行する実引数の `toTerm?` で後続を具体化する。長さが合わないときは none を返すので、C_Meth はこれを通じて arity を照合する。`arguments_subst`・`arguments_map`・`arguments_shift`・`bind_open_exchange` は、Option の観測の像（none を含む）のまま交換を言明している。C_Meth の型・行引数は SignatureInstance で呼出し側の Γ の Annotation を照合するので、外側の値への依存も移送の対象に入る |
| 6. 閉包と68遷移 | 可（軽5を参照） | 旧と新の Step の構成子の名前と順序は68個とも一致した（両ファイルから抜き出して diff で比べた）。`Closure.view` は一歩で読む値だけを `closeVal` で閉じ、内側の code を元の Capture とともに残す。let・guard・handler・thunk の枠は、捕捉時の Capture を持つ（E_Let・E_MatchGuard・E_Handle・E_Lazy）。引数は E_Return・E_Lam で一度だけ `extendMany` する。`foldl` で積むので、番号0が最後の引数になる。旧の `instSubst` の `ws.reverse` と同じ向きである。σ は全遷移で固定の引数である。解放・error・exit・drop の各遷移は旧と同じ順序と同じ枠の扱いを保つ。`releases` も旧と同じく release と drop だけを残す。`lambdaShape` の終端 unit・empty は、E_Lam では arity にだけ使い、結果型の証拠には使っていない |
| 7. 検査の境界 | 可 | 重複する鍵の Map（`duplicate_map_typed`）、依存する鍵型の型付けと置換（`dependent_map_substituted`）、場所の削除、捕捉した値の参照（`let_capture_preserved`・`captured_outer_after_application`）は、本番の型付けと遷移を使う補助入力である。results.md は、これを状態の保存の証明や核の型検査と区別して記録している |
| 8. 場合の数・抜け道 | 可 | 次節 |

### 型付けの規則へ足した前提の判定

旧の型付け（`Release/Typing.lean`）と比べ、規則ごとに増えた前提を挙げる。

| 規則 | 旧からの差 | 書ける形への影響 |
|---|---|---|
| V_Lam | 末尾に `Ty.Declared P C Γ (.fn ns ps r ε)` を加えた。本体は `bindParams (hideConts Γ) ps` で検査する | Declared が要求するのは、data の名前の arity、述語の欄参照の宣言照合、`constructorIs` の構成子の所属、読める変数の参照だけである。表層は未宣言の名前と不適格な欄の参照を名前解決の段で拒むので、脱糖後の注釈はこれを満たす。狭めない |
| V_List | `Ty.Sorted`・`Ty.Declared` を加えた | 空のリストの要素の型は脱糖時に解決済みの型である。上と同じ理由で狭めない |
| V_Map・V_Set | 鍵と値の型の WF を Annotation に替えた | 同上 |
| V_Raise | WF を、関数型全体の Annotation に替えた | 同上 |
| V_Con | `TypeArgsKinded`（value）、欄の型の `WF 0 cd.ntys 0`、結果の Annotation を加えた | data の型パラメータは、01-06 により値の型に限る。欄の WF は宣言表の性質であり、`.03` で Program.WellTyped から供給する。FieldRef.Declared（.02a）と同じく、欄の型は他の欄の値を参照しない形である |
| V_Dict | 型引数の Annotation と `TypeArgsKinded`（value）、dictTys と target の WF、結果の Annotation を加えた | 実装の型パラメータは値の型だけである（01-06）。`implement Functor[Option]` の target `.ctor (.data Option)` は、Declared の `∃ n, DataArity` で通る。kind は Annotation に含めず、引数の位置で照合するので、構成子を target に書く形を拒まない |
| V_Super・V_LocRef・V_LocLazy | Declared を加えた | V_Super の Declared は部分導出から正則性で導ける。ストアの型の Declared は、型付き状態の不変条件として L20 で保つ必要がある。いずれも利用者が書く形ではない |
| V_Fun・V_Prim・V_Op | Admissible の scope に Γ.length を与え、SignatureInstance を加えた。結果を `dependentFn` にした | 宣言の閉性・kind・注釈・結果の Annotation は表層の型検査が保証する。結果の形は中2 |
| C_Let | `Ty.Declared P C Γ b` を加えた | 推論した結果の型も解決済みの名前だけを含むので、狭めない。shift した本体の型から逆向きに取り出す補題を避けるための明示であり、署名の第23.3節と一致する |
| C_BuilderLet・C_BuilderOp | 内容型の Annotation と `TypeArgsKinded`、C_BuilderLet の結果の Declared を加えた。本体を `Γ.extendNone` と shift した R・a・ε で検査する | 旧は値の依存がないので shift がなかった。builder の要素型は値の型である。狭めない |
| C_Lazy・C_Escape | 結果の型の Annotation を加えた（旧の C_Lazy には WF もなかった） | 同上 |
| C_Meth | SignatureInstance、`Tel.arguments` による逐次の具体化、結果の Annotation を加えた | 旧は `ms.params.map (subst …)` の非依存な型列で検査した。新しい規則は、非依存の宣言ではそれと同じ型列を返す。中1の埋め込みの問題を除き、狭めない |

主な定理（進行・保存・エフェクトの健全性）の言明は今回の差分に現れない。新しい公理はない。提供範囲と精密な外部状態に触れる定義もない。

### 場合の数の照合

`HasTypeVQ` は Var・Const・Lam・Fun・Prim・Op・Map・Set・Dict・Raise・LocRef・LocLazy・Bytes・Con・Super・List・Sub・Refine の18、`HasTypeCQ` は BuilderLet・BuilderOp・Return・Let・App・If・Lazy・Escape・Use・Meth・Sub・Eff の12である。Vs と Each は各2なので、合計34になる。TypingShift・SubstTyping・Narrowing の各族は、名前付きの30の腕と nil・cons の4の腕を持ち、いずれも34場合である。TypedFacts の予定の2入口（observation・assume）は各18で36場合になる。補助の入口は assume_optional 18・data_observation 18・observation_declared 22・observation_references 22 の計80場合である。いずれも主張と一致する。網羅性は Lean が構造再帰の match で検査している。

基準からの削除の宣言は、`substKind`・`Def.ntys`・`ImplDecl.dictTys` の private から public への変更だけである。障害例の定理は一つも消えていない。

## 新しい所見

### 重

なし。

### 中

#### 中1. 埋め込みが旧の kind をすべて value に写すため、旧の高カインド型の導出が C_Meth・V_Fun の kind の照合を通らない（読めば確定し、Lean で確かめた）

- 場所: Refinement の `Syntax.lean` 217行の `embedClassDecl`（`argumentKind := .value`）、`Types.lean` 18行の `embedTParam`（kind を value に固定）、`Typing.lean` 104行の V_Fun と214行の C_Meth（`SignatureInstance … kinds`）、`KindValues.lean` 87行の `TypeArgsKinded`。
- 問題: 旧の型付けは `.ctor` と `.tapp` を持つ。旧の C_Meth は `ss ++ [τ]` に WF と継続でないことだけを求めるので、`τ = .ctor (.data Option)`（`implement Functor[Option]` の上のメソッドの呼出し）を型付けできる。新しい C_Meth は `TypeArgsKinded P C (ss ++ [τ]) (… ++ [cd.argumentKind])` を要求する。埋め込んだプログラムでは `argumentKind = .value` で、`Ty.HasKind P K (.ctor _) .value` は False である。そのため、埋め込んだ旧の導出に対応する新しい導出がない。V_Fun も同じで、旧の `[F[_]: Functor]` の関数を `Option` で具体化する呼出しは、`embedTParam` の value の kind と衝突する。
- 確かめたこと（`<tmp>/rv02bv/embed_kind.lean`、終了0）: `(embedClassDecl d).argumentKind = .value`（rfl）と、`embedDef` の全型パラメータの kind が value であることを示した。さらに、任意の P・C・d・ts について `¬ TypeArgsKinded P C (ts ++ [.ctor (.data d)]) (List.replicate ts.length .value ++ [.value])` を証明した。
- 影響: 今の定理は偽にならない。results.md 482行は「旧 Release の kind を持たない情報から高カインドの宣言を推測する操作はしない」とし、署名の第2.2節も旧の全型付けの保存の完成とは区別している。ただし、この群で kind の照合を C_Meth・V_Fun に接続したので、D29（適格な旧導出の埋め込み）の L20・L70 の義務は、このままでは高カインド型を含む旧の導出について証明できない。これは旧の定理の範囲の決定であり、補助契約の細部では済まない。
- 修正案: 次のどちらかを取りまとめが決め、signatures.md の第2.2節の埋め込みの行と義務の対応表に記す。(i) D29 の「表現可能性」の対象から、kind を推論できない旧の高カインド型の導出を明示して外す。(ii) `.02a` の `KindInference`（宣言の出現からの推論）で旧の宣言の kind を求めて埋め込む。または、埋め込みに kind の割り当てを引数として与え、旧の導出の埋め込みの言明にその割り当ての適格性を前提として置く。(ii) なら旧の定理の範囲を保てる。

#### 中2. V_Fun・V_Prim・V_Op の結果が dependentFn だけになり、`.11` まで旧の fn 型の位置と相互に変換できない（読めば確定。後続の義務の依存）

- 場所: `Typing.lean` 104〜117行（三規則の結果 `.dependentFn (instantiatedTel …)`）、`Le.lean` の `Ty.LeQ`（fn と dependentFn の間の規則がない）、signatures.md 第23.1節と R2 の行。
- 問題: 旧の V_Fun は `fnTy …`（非依存の `.fn`）を返し、関数の参照を C_App で呼べた。`.fn` を引数型に持つ高階の関数へ渡すことも、ラムダと分岐で合流させることもできた。新しい体系には次の二つがまだない。C_DependentApp（`.02b-closures` で加える）と、fn と `dependentFn (toTel …)` をそろえる正規化（`.11`）である。そのため、関数の参照・組込みの関数・操作の値は、この群の終わりの時点では呼出しにも fn の位置にも使えない。C_DependentApp を加えた後も、`.fn` を期待する位置へ関数の参照を渡す形は `.11` の正規化まで型付けできない。
- 影響: 健全性の言明は影響を受けない。予定の段の途中の不完全さであり、署名の R2 も「.11まで C_App/C_DependentApp を並置し、完全性を主張しない」としている。ただし、署名の第23.1節は非依存の宣言にも dependentFn を返すことを補助契約として決めた。そのため、D29 の埋め込みが `.11` の正規化後の等号に依存することが新しく生じた。
- 修正案: 義務の対応表に次の一行を加える。「旧の V_Fun・V_Prim・V_Op 由来の fn 型の位置（高階の引数、分岐の合流、C_App）の埋め込みは、`.02b-closures` の C_DependentApp と `.11` の fn と dependentFn の正規化後の等号に依存する」。`.11` がこの等号を採らない場合は、非依存の宣言に `.fn` を返す V_Fun の入口を並置する案に戻る、という条件も書いておくとよい。

### 軽

#### 軽1. narrowing・hide・空ストアからの弱化が、型を変えないのに `ValueAssumptions` を要求する

- 場所: `Narrowing.lean` 288・303行、`SubstTyping.lean` 115・128・136行、`SubstTypingObstruction.lean` の `substituted_*`・`narrowed_*`。
- 問題: これらは型を変えないので sat・admits の移送は要らない。それでも、`shift_values`（k=0）を経由するので `hA` を受け取る。そのため、障害例のファイルにある「修正後は使える」ことを示す正の例も、任意の B から `ValueAssumptions` を満たす B へ弱まった。主な定理では CoreAssumptions から供給できるので、実害はない。
- 修正案: 残すなら、署名の第23節に「改名の補題の再利用による前提であり、意味上の必要ではない」と一言書く。後で型を変えない ContextMap の専用の補題に分ければ、前提を外せる。

#### 軽2. `TypeArgsKinded` の kind の文脈 K は前提ごとに存在量化され、C の型変数の宣言の kind と結び付かない

- 場所: `KindValues.lean` 87〜89行。
- 問題: `∃ K, K.length = C.length ∧ …` なので、同じ導出の別の前提で、同じ型変数を value とも constructor とも見なせる。`C : List TParam` が kind を持たないためである。実行時は C が空で型引数が閉じているので、E_Fun の具体化の健全性には影響しないと読める。ただし、開いた文脈での kind の一貫性は検査していない。
- 修正案: `.03` の Program.WellTyped との接続の義務に、「外側の型パラメータの kind を宣言から与え、K をそれに固定する」ことを一行加える。

#### 軽3. 境界入力が示すモデルは `sat = True` だけである。L50 の骨格のモデルは Fail 列の重複の除去に注意が要る

- 場所: `02b-values-r2-constraint-boundary.lean` 139〜145行（`goodB`・`good_conditions`）、`Normalize.lean` の `Eff.norm`（`sortUnique tyCompare`）。
- 問題: 本レビューでは、篩を剥いだ最上位の形だけを読む非自明な `sat` が四条件を満たすことを確かめた（`<tmp>/rv02bv/head_model.lean`）。条件が強すぎないことの証拠にはなる。一方、`substTyValues` は `Ty.bind` の正規化で Fail 列を整列し、重複を除く。たとえば `{x: Integer | x = y}` と `{x: Integer | x = 0}` の Fail は、y を 0 に置換すると一つになる。そのため、Fail 列の個数や順序まで写す骨格を `sat` が読むと、sat_values が成り立たない（実行しないと分からない疑い）。鍵と等値の制約は関数型を拒むので、実際の表がエフェクトを読む必要はないと考えられる。
- 修正案: L50 の三モデルの義務の行に、「骨格はエフェクトを読まないか、集合として読む」ことを書く。

#### 軽4. V_LocRef・V_LocLazy の Declared は、型付き状態の不変条件に宣言の照合を足すことを求める

- 場所: `Typing.lean` 135〜138行、`StoreTransport.lean` の `LocTy.WF`。
- 問題: `StoreTy.WF` は閉じた WF だけを持ち、Declared を含まない。保存の証明（L20）で、E_RefNew・E_Lazy が作る場所の型の Declared を StoreOk 等で保つ必要がある。results.md と署名の第23.2節にこの義務の記述が見当たらない。
- 修正案: closures・L20 の StoreOk の義務の行に「場所の型の Declared」を加える。

#### 軽5. 旧 lam の arity が、名前と引数の型の数が違う形では旧と異なる

- 場所: `Capture.lean` 23行の `lambdaShape`、`Telescope.lean` 16〜18行の `Ty.toTel`（短い方で止まる）、`Semantics.lean` 65行の E_Lam（`ws.length = signature.arity`）。
- 問題: 旧の E_Lam は `ws.length = ps.length` で判断する。新しい E_Lam は `toTel` の名前の数で判断するので、`ns.length ≠ ps.length` の型の付かない状態では遷移が旧と変わる。型付けの V_Lam が `NamesWF` を要求するので、型の付いた状態では一致する。
- 修正案: 旧の遷移の埋め込みを言明するとき（L20・L70）に、`NamesWF` を前提として置くと記しておく。本番を直す必要はない。
