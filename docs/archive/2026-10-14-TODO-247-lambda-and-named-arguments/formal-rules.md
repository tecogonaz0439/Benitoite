# 契約名を持つ形式規則と既存モデルの対応

## 目的と範囲

`Benitoite.NamedRelease`・`NamedSurface`・`NamedExchange` の規則を、既存の `Release`・`Surface`・`Exchange` の規則と対応付ける。N2〜N7 は名前付きコア、N8〜N11 は名前付き表層と脱糖の型保存、N12〜N14 は実行可能な検査とその健全性、N15 は新交換形式と六つの入口を実装した。N16 では定義・定理の言明・交換の接続をレビューした。既存モデルの定義・定理・交換形式・六つの入口は維持する。

現在の処理系の実装を説明する `docs/design/01-spec/01-12-core-calculus.md` と `07-quality/07-04-formal-semantics.md` は変更しない。正式モデルに切り替える N34a で規則の写しを移す。以下のパスは `formal/Benitoite/` を基準にする。

## 共有する構文と契約名

`NamedRelease/Syntax.lean` は `Release/Syntax.lean` の全ての構成を維持し、次の欄を加える。

| 元の構成 | 新しい構成・欄 | 名前の対象 |
|---|---|---|
| `Ty.fn params ret eff` | `Ty.fn names params ret eff` | 関数型の宣言順の契約名 |
| `Val.lam params body` | `Val.lam names params body` | ラムダの宣言順の契約名 |
| `Def` | `names : List String` | 関数のパラメータ |
| `OpDecl` | `names : List String` | 利用者が宣言する操作のパラメータ |
| `MethSig` | `names : List String` | 型クラスのメソッドのパラメータ |
| `Typing.PrimSig` | `names : List String` | 組み込みの関数のパラメータ |
| `Typing.OpSig` | `names : List String` | ハンドラが参照する操作のパラメータ |

`NamesWF names params := names.length = params.length ∧ names.Nodup` とする。ゼロ引数の名前は空の並び、一引数でも一つの名前を保持する。名前の綴りを alpha 変換しない。名前の識別子としての字句規則は型付きコアの前に検査し、コアでは `String` として表す。

名前は同じ位置の引数型に対応する。コアの宣言が補助の辞書引数を `params` に含む場合、その位置にも内部名を持つ。利用者の契約名と補助名の生成・区別は表層の作業で接続する。値変数は引き続き de Bruijn の番号で表し、ハンドラの局所束縛名を操作の契約名に固定しない。直接のデータ構成子とパターンの規則は位置指定のままであり、`ConDecl` に名前を加えない。

## 型付けと整形式の規則の写し

| 元の規則・定義 | Named モデルで加えた条件・保持する欄 | 維持した条件・結果 |
|---|---|---|
| `fnTy` | 第一引数 `names` を `Ty.fn` と型の置換の結果に保持する | 引数型・戻り値型・エフェクトの置換 |
| `opSig` | 利用者の `od.names` または組み込みの `s.names` を `OpSig.names` に写す | 型パラメータ・引数型・戻り値型・エフェクトの名前 |
| `Ty.WF` の関数型 | `NamesWF names params` | パラメータと戻り値の型変数の範囲。入れ子の型も再帰して検査する |
| `Ty.VarsIn` の関数型 | `NamesWF names params` | パラメータ・戻り値・エフェクト変数の範囲 |
| `Val.VarsIn` のラムダ | `NamesWF names params` | パラメータの型と本体の変数の範囲 |
| `Def/OpDecl/PrimSig/MethSig.Scoped` | 外側の `NamesWF` を先頭の連言に加える | 宣言と本体の全ての変数の範囲 |
| `V_Fun` | `NamesWF d.names d.params`、結果の型に `d.names` | 宣言の参照、型パラメータの制約、エフェクト引数の個数 |
| `V_Prim` | `NamesWF s.names s.params`、結果の型に `s.names` | 組み込みの参照、型・エフェクト引数の個数、`admits` |
| `V_Op` | `NamesWF od.names od.params`、結果の型に `od.names` | 操作の参照、型パラメータの制約、操作のエフェクト |
| `V_Lam` | `NamesWF names ps`、ラムダと結果の型に同じ `names` | 本体の型付け、継続を隠す環境、戻り値の契約 |
| `C_App` | 呼ぶ値の型は `.fn names as b ε` | 引数は位置順の `HasTypeVs`、戻り値とエフェクト |
| `C_Meth` | `NamesWF ms.names ms.params` | 辞書・クラス・メソッドの参照、型パラメータの制約、引数の位置と型 |
| `HasTypeClauses.cons` | `NamesWF sg.names sg.params` | 操作の参照、引数と型パラメータの個数、節の剛な型、継続と本体 |
| `Def.WellTyped` | `NamesWF d.names d.params` を本体の判断と連言にする | 空のストア、宣言の制約、パラメータと戻り値を持つ本体の判断 |
| `ImplDecl.WellTyped` の各メソッド | `NamesWF ms.names ms.params` を本体の判断と連言にする | メソッド・上位辞書の存在の一致、辞書引数、対象型の置換と本体の判断 |

ほかの型付け規則、ストア・継続・状態の型付け、網羅性の意味としての `Inhabits`・`Exhaustive` は同じ条件を維持する。`Inhabits.fn` は名前を持つ関数型を対象にするが、パターンが関数の内部を調べない意味は変えない。

型の適合は次の形である。二つ目の選択肢は、同じ名前の並び・引数型・戻り値型で、エフェクトだけの包含を認める。名前の順と綴りは両側で等しく、名前を消した型を経由しない。

```lean
Ty.Le a a' :=
  a = a' ∨ ∃ names ps r ε ε',
    a = .fn names ps r ε ∧ a' = .fn names ps r ε' ∧ Eff.Sub ε ε'
```

`NamesWF` を新しい公理や独立した `Builtins.Assumptions` の欄として加えない。宣言の整形式・型付けの前提として検査する。既存の組み込みの境界の `sig_scoped` は、名前を含む `PrimSig.Scoped` を要求し、具体モデルでその条件を証明する。

## 型付けから従うラムダ名と宣言名

G2 の中の指摘には、`NamedRelease/Lemmas/Names.lean` の `HasTypeV.lambdaNamesWF`・`HasTypeC.lambdaNamesWF` で対応する。値のリスト、分岐のガードと本体、操作の節、辞書・メソッドの引数にも再帰し、項に含まれる全ラムダの `NamesWF` を型付けから導く。型・エフェクトの包含を通した判断も対象とする。プログラムの整形式や名前の外部仮定は要らない。

`VarsInNoLamNames` は、既存の `VarsIn` からラムダ自身の `NamesWF` だけを除く。構造的な分解と型付けの補題を合わせた `HasTypeV.varsIn_iff_noLamNames`・`HasTypeC.varsIn_iff_noLamNames` により、型付きの項では両述語が同値となる。`stateTyE_init` はこの同値を通して、ラムダ名を型付けから導く `stateTyE_init_noLamNames` に接続する。既存の最終定理の言明は保持し、同じ結論を外部のラムダ名の条件なしで示す `effect_soundness_noLamNames` も追加する。状態内の型付きの値・計算にも、同じ補題を適用できる。

型注釈の `Ty.VarsIn` は、入れ子の関数型の名前の整形式も含む。項の型付けだけから全ての注釈の整形式が従うとは主張しない。例えば、使われないラムダのパラメータの型は、その本体の型付けだけでは整形式を検査できない。注釈の整形式は既存の範囲条件に保持し、ラムダ自身の名前と区別する。この選択の理由は R35 に記す。

`V_Fun`・`V_Prim`・`V_Op`・`C_Meth`・`HasTypeClauses.cons` の宣言名の `NamesWF` は、プログラムと組み込みの整形式から従う冗長な前提である。順に `Def.Scoped`、`Builtins.Assumptions.sig_scoped`、`OpDecl.Scoped`、`ClassDecl.Scoped` と `MethSig.Scoped`、`opSig_scoped` から得られる。規則の局所的な型付けを記述できるよう明示の前提は保持する。N34a の 01-12 の写しでは、それぞれに「整形式から従う」と書き添え、独立した外部仮定として扱わない。

## 範囲条件に置く名前の条件

`NamedSurface/WellFormed.lean` の範囲条件は、番号の範囲に加え、次の名前の条件を持つ。型付けから従う条件と、型付けだけでは得られない条件を区別する。`NamesWF` は長さの一致と重複の不在だけを表し、識別子の字句規則を表さない。

| 条件を置く箇所 | 名前の条件 | 理由と型付けとの関係 |
|---|---|---|
| 型注釈の `Ty.VarsIn`・`Ty.VarsInList` | 入れ子を含む関数型の `NamesWF` | 使われないパラメータや具体化した型も検査する。全注釈の整形式は本体の型付けだけから従わないため、既存の範囲条件に保持する |
| `Expr.Scoped` の `lam`・`funDicts`・`methName`・`conValue` | その関数値自身の `NamesWF names ps` | 脱糖で作るラムダの名前を範囲保存へ接続する。対応する表層の型付け規則は同じ条件か、それを導く名前の等式・宣言の整形式を要求する。型注釈内部の条件とは区別する |
| `Def.Scoped` の `NamesWF d.names d.params` | 利用者の引数名の長さと一意性 | `Def.WellTyped` も同じ条件を要求する。範囲条件では本体の型付けと独立に宣言を検査する |
| `Def.Scoped` の `NamesWF d.coreNames (d.dictTys ++ d.params)` | `%dict1` 以降の内部名と利用者名を連結した並びの長さと一意性 | `Def.WellTyped` は利用者名の整形式だけを要求するため、この条件はそこから従わない。Lean の利用者名は任意の `String` であり、内部名との衝突を入力の範囲条件で排除する |
| `Program.WellFormed` の `conFields` | 宣言されたフィールド名の `NamesWF names cd.args`、対応する構成子の存在、同じデータ型の構成子の一意性 | 未使用のレコード宣言も整形式にするため、プログラムの全表を検査する。関数本体の型付けだけでは全表の条件を導けない |
| `Program.WellFormed` が呼ぶ `OpDecl.Scoped`・`ClassDecl.Scoped`／`MethSig.Scoped`、組み込みの `sig_scoped` | 宣言自身の名前と、宣言の型に含まれる関数型の `NamesWF` | 未参照の宣言にも要求する。参照の型付け規則の名前の前提は、この宣言の整形式から従うが、全宣言の整形式を参照の型付けだけから導くことはしない |

`d.coreNames` は `internalNames d.dictParams.length ++ d.names` であり、内部名を生成する定義だけでは任意の利用者名との非衝突は保証されない。処理系は `%` を表層の識別子として受理しないが、その字句規則はこの型付きモデルの対象外である。性質 1 は `Program.WellFormed` から連結後の `NamesWF` を受け取り、字句規則を証明したとは扱わない。`E_Fun`・`E_FunDicts` も連結後の条件を局所的な前提として明示する。N34a では、この境界を 01-12 の範囲条件と 07-04 の対応表へ写す。

## ソース位置と宣言位置の値の対応

Z4 は `NamedSurface/Lemmas/Calls.lean` に四つの一般補題を加える。`fieldAt_getElem` は、位置列が一意で値列と同じ長さなら、ソース位置 k の宣言位置を検索すると同じ位置の値が返ることを示す。`recordFields_getElem` は、位置列が全宣言位置の置換であるとき、並べ替え後のその宣言位置にも同じ値があることを示す。どちらも値の型を仮定せず、同じ型の値の取り違えを型保存とは別に排除する。

`boundVars_getElem` は、n 個のソース順の計算を束縛した後の k 番目の参照が `.var (n - 1 - k)` であることを示す。`CallOk.recordFields_source` はこれらを接続し、`positions[k] = i` なら、`callComp` が用いる並べ替え後の第 i 成分がその参照となることを示す。評価済みの挿入引数の値は任意とし、挿入なしの通常呼び出し・穴と、位置 0 に一引数を挿入するパイプを含める。明示計算数 n と位置列の長さの一致は、既存の `callComp_typed` が型付きの計算列から導く条件と同じである。

これらは値の配置の等式であり、`desugar_typed` の型保存の言明を変えない。callee の先行評価、引数のソース順の束縛、穴の遅れた評価は脱糖の定義と独立した期待コアの例で確かめる。評価順全体の意味保存を示す定理は追加しない（R44）。

## 実装メソッドの名前を検査する境界

`NamedRelease.ImplDecl.methods` は位置で束縛するコアの本体だけを持ち、実装側の引数名を保持しない。N8〜N11 の `NamedSurface.ImplDecl.methods` も `Block` の表であり、`ImplDecl.WellTyped` は型クラスの `MethSig.params` に従って本体を型付けする。実装側の名前と宣言側の名前の一致を、このモデルで検査済みとは扱わない。

N12 は、位置による束縛へ変換する前の表層の入力に実装側の引数名を保持し、各メソッドの名前の並びを型クラスの `MethSig.names` と比較する。N14 の `NamedSurface/CheckSoundDicts.lean` とプログラム全体の検査の健全性は、検査の成功からこの一致を導いた上で本体の型付けへ接続する。`checkImpl_contracts` と `checkProgram_contracts` は、射影前の実装について名前の一致と整形式を結論する。N15 の独立入力で、名前が違う実装の拒否と一致する実装の受理を確認した。

`MethSig` はメソッド自身の制約による辞書引数も含む。交換形式の実装は利用者の `Header.names` と辞書の `dictParams` を分けるため、N16 で `prepare` を補正した。実装自身の辞書数から `internalNames` を生成し、その後ろに実装自身の利用者名を付けて `MethodInput.names` に渡す。宣言側の名前を転記して比較を済ませない。辞書付きの正常な実装と、利用者名だけが違う同じ実装の拒否も独立入力で検査した（R43）。

## 置換と実行の対応

`NamedRelease/Subst.lean` は N2 の型付け・実行の依存として前倒しした（R25）。全ての既存の置換・変数移動・実体化・パターン照合の定義を保持する。`Ty.shift`・`Ty.substAt` の関数型、`Val.substTyAt`・`Val.rename`・`Val.subst` のラムダは、名前の並びをそのまま返し、型や本体だけを変換する。名前を局所変数の置換の対象にしない。これらの一般的な保存の補題は N3 以降で証明する。

`NamedRelease/Semantics.lean` の全ての遷移規則・実行関数・ストアと継続の定義は既存のものに対応する。`E_Lam` と `step` のラムダの分岐は名前を持つ構文に一致させるが、条件は引数値とパラメータの個数の一致のままである。名前を使って値を並べ替えない。`E_Fun`・`E_Meth`・操作・ハンドラの実行も、型と値を既存の位置に置換する。

`NamedRelease/Assumptions.lean` の全ての境界の仮定と `Program.EffectsOk` は既存モデルに対応する。`PrimSig.StoreShape` には現行の公開宣言の外側の名前を加え、`Reference.update` の内側の関数型を `function(value: T) -> T` とする。

| 組み込みの種類 | 外側の名前 | 元からの型・エフェクトの条件 |
|---|---|---|
| `refNew` | `value` | 維持 |
| `refGet` | `reference` | 維持 |
| `refSet` | `reference, value` | 維持 |
| `refUpdate` | `reference, f` | 維持。内側の関数型に `value` を追加 |
| `force` | `value` | 維持 |

## 証明と具体例の対応

名前空間の接頭辞を `Release` から `NamedRelease` へ変更し、次の既存の定理は名前と前提・結論の役割を保って証明した。

| モジュール | 対応する定理 | 新モデルの差分 |
|---|---|---|
| `Subst` | `selectSlots_map`, `selectSlots_mem` | 型・値の契約名と無関係な独立補題。元の言明・証明を維持 |
| `Typing` | `AltsTy.witness` | 型付きパターンの証人。新しい共有型を使い、言明・証明を維持 |
| `Model` | `sig_cases`, `single_no_rho`, `assumptions` | 組み込みの契約名を保持し、`sig_scoped` とストアの形の条件を証明 |
| `Model` | `emptyProgram_wellFormed`, `emptyProgram_wellTyped`, `emptyProgram_effectsOk` | 空のプログラムで前提が満たせることを維持 |
| `Model` | `classProgram_classes`, `classProgram_impls`, `constSig_scoped`, `classProgram_wellFormed` | 型クラス・実装・空のメソッド契約の整形式を証明 |
| `Model` | `const_body_typed`, `classProgram_wellTyped`, `classProgram_effectsOk`, `super_call_typed` | メソッド契約の整形式を加え、本体・上位辞書・メソッドの型付けを維持 |
| `Model` | 新設 `lambda_names_wellFormed` | ラムダの型付けから名前の整形式を導く。`V_Sub` を経由しても条件が必要であり、重複名を持つラムダの型付けの否定例に使う |

`Model` の最終の `effect_soundness` を使う二つの例は、定理を移す N7 で追加した（R25）。元の二つの例と全ての最終定理は旧モデルでも維持する。N2 の時点では新モデルの保存・進行・エフェクト健全性を証明済みとは扱わず、N7 で揃えた。

追加した例は、ゼロ・一・二引数の整形式、長さの不一致と重複の拒否、コンテナ内の不正な関数型の拒否、名前の読み替え・宣言順の入れ替えの不適合、型引数の置換後の組み込みの契約名、ラムダの型付けと位置による実行を検査する。重複名のラムダは、本体を定数の `return` にしても、型の包含を経由しても型付けできないことを証明した。例の作成時の関門と実行結果は [n2-implementation.md](n2-implementation.md) に記す。

## 置換と変数移動の基礎補題の対応

`NamedRelease/Lemmas/Basic.lean`・`Rename.lean`・`TyLemmas.lean`・`Closed.lean` に、旧モデルの全 111 定理を同じ名前で移した。型・値・計算・分岐・ハンドラの節の全構文を対象とし、操作・辞書・メソッドを除外しない。元の前提・結論の役割と帰納法の場合分けを保つ。関数型の構文を直接書く言明には `names` を加え、同じ名前の並びを両側に残す。

| 旧モジュール → 新モジュール | 定理の対応 | 名前付きモデルで維持する条件 |
|---|---|---|
| `Release/Lemmas/Basic` → `NamedRelease/Lemmas/Basic` | 全 16 定理。`Eff.Sub` と `substRho` の補題、`Ty.Le.refl`・`trans`・`fn_left`・`fn_right`・`eq_of_not_fn`・`eq_of_not_fn_left`・`substAt`・`subst`・`shift` | 型の包含の推移性・反転・置換・移動で、名前の綴りと宣言順を保持する。`fn_left`・`fn_right` は元の `names` を持つ関数型だけを結論にする |
| `Release/Lemmas/Rename` → `NamedRelease/Lemmas/Rename` | 全 38 定理。パターン・値のリスト・環境の長さ、`RenOk`、`handled_renameList`、六つの型付け判断の `rename` と `store`、三つの値の型付け判断の `hide` | ラムダ・関数参照・操作・組み込み・メソッド・ハンドラの節の名前の整形式を、型付けの証拠からそのまま保持する。辞書の引数と上位辞書の移動も維持する |
| `Release/Lemmas/TyLemmas` → `NamedRelease/Lemmas/TyLemmas` | 全 29 定理。エフェクト置換の合成、型構成子の適用、`WF`、`VarsIn.wf`、ずらしの恒等性・整形式、型置換の整形式・閉じた型の恒等性・合成とずらしとの交換 | 関数型の再帰する各位置で同じ `names` を残す。引数型を `map` した後の名前の長さ・一意性は `NamesWF.map` から導く。コンテナ・辞書内の関数型にも再帰する |
| `Release/Lemmas/Closed` → `NamedRelease/Lemmas/Closed` | 全 28 定理。型構成子の `VarsIn`、型・値・計算・分岐・節の型置換、値・計算・分岐・節の単調性・rename・subst、`ClosedSubst` と instantiate | ラムダの契約名の整形式を残し、型置換では引数の個数を維持する。値変数の置換・番号の付け替えは契約名を置換しない。操作・辞書・メソッド内の引数と型も対象とする |
| `Release/Lemmas/TySubst` → `NamedRelease/Lemmas/TyLemmas` | `Eff.RhosIn.mono`・`Ty.VarsIn.mono`・`Ty.VarsInList.mono` の三定理を前倒し | 名前の整形式を保持して、型・エフェクト変数の許される範囲だけを広げる。前倒しの理由と後続の import は R26 に記録した |
| 新設 `NamedRelease/Subst` | `NamesWF.map` | 任意の型変換 `f : Ty → Ty` で、`NamesWF names ps` から `NamesWF names (ps.map f)` を導く。名前の並びを変更しない |

新モデルの四モジュールは `formal/Benitoite.lean` に import してビルド対象とした。N3 の新しい 115 定理の `#print axioms` は Lean の既存の `propext`・`Classical.choice`・`Quot.sound` の範囲であり、新しい公理と `sorryAx` はない。旧モデルと最終定理は変更しない。検査と差分確認は [n3-implementation.md](n3-implementation.md) に記す。

## 型付けの置換・反転・正準形・正則性の補題の対応

N4 は六モジュールの全 146 定理のうち、N3 で前倒しした単調性の三定理を除く 143 定理を、同じ名前で移した。R27 により `OuterC` の七定理も前倒しし、追加は合計 150 定理である。値・計算・値のリスト・分岐・ハンドラの節の各判断と、コンテナ・高カインド・剛な型・操作・辞書・メソッドを含む全ての場合を維持する。

| 旧モジュール → 新モジュール | 対応する定理 | 前提・結論の対応 |
|---|---|---|
| `Release/Lemmas/TySubst` → `NamedRelease/Lemmas/TySubst` | 全 18 定理のうち 15 定理。`NotCont`・`hideConts`・`binds_map`・`shiftEnv_substAt`・エフェクト置換・`StoreFix`・閉じた型の置換 | 閉じた型引数・継続以外の型・ストアの整形式という元の前提を維持し、同じ不変性を結論にする。関数型の名前は置換しない。残る単調性の三定理は N3 の `TyLemmas` から使う |
| `Release/Lemmas/TySubstMain` → `NamedRelease/Lemmas/TySubstMain` | 全 26 定理。型置換の合成、パターン・`Inhabits`・網羅性の置換、操作の範囲、制約・環境・辞書の置換、六つの `substTy` | `substTy` は元と同じプログラム・組み込みの仮定、閉じた型引数、制約の充足、ストアの不変性から、変換した環境・項・型・エフェクトの型付けを導く。`fnTy_substAt` は任意の `names` を両側に保持し、名前の外部仮定を増やさない。`opSig_scoped` は元の型変数の範囲に加え、名前の整形式も宣言から導く |
| `Release/Lemmas/SubstTyping` → `NamedRelease/Lemmas/SubstTyping` | 全 24 定理。rename の恒等性、`ClosedTy`・`SubstOk`、六つの `subst`、値と型の個数、実体化 | 同じ `SubstOk`・`InstOk` から値の置換・実体化後に同じ型とエフェクトが付く。ラムダの名前は型付けの証拠をそのまま再利用する。継続の場所と戻り値の対応も維持する |
| `Release/Lemmas/Inversion` → `NamedRelease/Lemmas/Inversion` | 全 27 定理。`fnTy_eq`、値と計算の全構成子の反転 | 元と同じ型付けと構文の等式から、元の宣言・本体・引数・型・エフェクトの条件を取り出す。`inv_fnRef`・`inv_prim`・`inv_op`・`inv_lam`・`inv_meth` は結論に名前の整形式を加える。`inv_app` は契約名も存在量化し、呼ぶ値の関数型に保持する。包含を経由しても同じ名前を残す |
| `Release/Lemmas/Canonical` → `NamedRelease/Lemmas/Canonical` | 全 32 定理。閉じた値の `Inhabits`、真偽値・セル・遅延値の正準形、値の選択、パターン照合・分岐選択の型付けと閉じた項の性質 | 空の環境での型付け、型付きパターン、照合と選択の結果という元の前提から、同じ正準形と束縛された値の型を導く。関数型の契約名を消して値の形を比較しない |
| `Release/Lemmas/Regularity` → `NamedRelease/Lemmas/Regularity` | 全 19 定理。包含・型置換・環境・定数・パターン・ストア・値・計算・分岐の整形式 | `HasTypeV.wf`・`HasTypeC.wf`・`HasTypeArms.wf` は、元と同じ宣言・環境・ストア・項の前提から、名前を含む結果の型の整形式を導く。補助 `fnTy_wf` には構築する関数型の `NamesWF names ps` を加え、その呼び出しでは `V_Fun`・`V_Prim`・`V_Op` の型付けから得た証拠を渡す。主定理の外部仮定は増やさない |
| `Release/Lemmas/OuterC` → `NamedRelease/Lemmas/OuterC` | 全 7 定理。`SatAll.local` と六つの `outer` | 元と同じ組み込みの仮定・型付け・変数の範囲から、型パラメータの外側に任意の並びを加えても同じ型付けが成立する。ラムダ・操作・メソッド・ハンドラの節の名前の整形式も保持する。N4 に前倒しした依存は R27 に記録した |

名前の整形式は `names.length = params.length ∧ names.Nodup` である。反転はこの両条件を型付けから導き、型置換は引数型の `map` が長さを変えないことから保持する。ハンドラの局所変数は de Bruijn の番号のままとし、契約名への読み替えを要求しない。高カインドの `tapp`・`ctor`、節内の剛な型パラメータの下での置換、エフェクトの置換は、元と同じ規則と帰納法で証明した。

七モジュールは `formal/Benitoite.lean` に import してビルド対象とした。追加した全 150 定理の `#print axioms` は `propext`・`Classical.choice`・`Quot.sound` の範囲であり、新しい公理と `sorryAx` はない。新モデルの保存・進行の最終定理は後続作業の範囲である。検査と差分確認は [n4-implementation.md](n4-implementation.md) に記す。


## ストア・継続・辞書の補題の対応

N5 は `StoreLemmas`・`ContLemmas`・`Dict` の全 43 定理を、同じ名前で名前付きの共有型へ移した。`OuterC` の七定理は R27 により N4 で実装済みであり、再定義せず利用する。R28 に従って辞書の証明に必要な保存の補助の 11 定理を前倒しし、追加は合計 54 定理である。

| 旧モジュール → 新モジュール | 対応する定理 | 前提・結論の対応 |
|---|---|---|
| `Release/Lemmas/StoreLemmas` → `NamedRelease/Lemmas/StoreLemmas` | 全 8 定理。`StoreTy.set_sub`、`CellOk.store`、`StoreOk.set`・`wf`・`fresh`・`cell`、`Store.Closed.set`、`HasTypeV.notCont` | 元と同じストアの拡大・場所の更新・セルの型付けの前提から、更新後の型付け・整形式・閉じた項の性質を導く。セル・遅延値・継続の中の関数型は名前を含めて維持し、`notCont` は名前を持つ関数型も継続の型でないことを示す |
| `Release/Lemmas/ContLemmas` → `NamedRelease/Lemmas/ContLemmas` | 全 20 定理。`ContTy.store`・`name_end`・`state_end`、`handled_state`、八つの `inv_*`、`EndsWithHandle.tail`・`tail'`、`resume_append`・`split`・`framesOk`・`prepend_releases`・`drop_releases`、`releases_sub` | 全ての枠と元の前提・結論を維持する。再開時の継続の接続、操作時のハンドラでの分割、解放と `drop` の列の型付け、`State` を含むエフェクトの包含を保つ。関数型を含む継続の入出力にも名前を残す |
| `Release/Lemmas/Dict` → `NamedRelease/Lemmas/Dict` | 全 15 定理。エフェクトと型の置換の合成、`ImplDecl.methTy_subst`・`dictTys_subst`、`SatAll.append`、プログラムの実装・メソッドの取り出し、`Val.superStep_super_of_not_dict` と三つの `superStep_*typed` | 元と同じ型変数の範囲・宣言・型付け・ストアの整形式・閉じた値の前提から、型引数を置換したメソッド・辞書の型と上位辞書の一歩の型保存を導く。関数型の再帰位置で同じ契約名を両側に残す。`MethSig.Scoped` の名前の整形式も保持し、保証を弱める外部仮定を加えない |
| `Release/Lemmas/PresHelpers` → `NamedRelease/Lemmas/PresHelpers` | `HasTypeVs.get`・`Val.VarsInList.get`・`InstOk.of_values` の 3 定理 | 型付き・閉じた値の並びから位置ごとの値と型を取り出し、元と同じ実体化の前提を満たす。名前の追加による言明の変更はない |
| `Release/Lemmas/Preservation` → `NamedRelease/Lemmas/Preservation` | `closedArgs_of`・`envWF_nil` の 2 定理 | 元と同じ変数の範囲から閉じた型引数を導き、空の環境の整形式を示す。名前付きの関数型も対象に含む |
| `Release/Lemmas/PresBase` → `NamedRelease/Lemmas/PresBase` | 五つの `VarsIn.toTrue` と `HasTypeVs.wf_all` の 6 定理 | エフェクト変数の範囲だけを広げ、項の型変数の範囲とラムダの名前の整形式を保つ。閉じた値の並びの型の整形式は、元と同じ宣言・組み込み・ストアの仮定から導く |

ハンドラの局所変数は引き続き de Bruijn の番号で表す。操作の契約名に局所名の綴りを固定する前提は加えない。`ContTy.split` と `resume_append` はハンドラの型付きの節をそのまま保持し、網羅性・エフェクトの条件を削っていない。網羅性の定義と実行時補題の移植は N5a・N5b、保存・遷移の主定理は N6 に残す。

六つの新モジュールを `formal/Benitoite.lean` に登録した。追加した全 54 定理の `#print axioms` は既存の `propext`・`Classical.choice`・`Quot.sound` の範囲であり、新しい公理と `sorryAx` はない。検査と後続作業の依存は [n5-implementation.md](n5-implementation.md) に記す。

## 網羅性判定の定義・基礎補題・表示の対応

N5a は `Release/Coverage.lean` の判定・反例・分岐位置の全定義と、`listBounds_spec` までの基礎補題 34 定理を `NamedRelease/Coverage.lean` に移した。`CoverageExamples.ctors_complete` も含め、今回の追加は全 35 定理である。構成子の列挙・区間・リストの特殊化・燃料・ガード・選択肢の順序・反例の判定結果を維持する。

| 旧定義・補題 → Named モデルの同名定義・補題 | 前提・結論と名前の対応 |
|---|---|
| `Coverage.substTy`・`substTys`、`substTy_eq`・`substTys_eq`（2 定理） | 型引数だけの評価用置換がコアの `Ty.subst ts []` と一致する。関数型の `names` をそのまま残し、引数型・戻り値型だけを再帰して置換する。コンテナと構成子のフィールド内の関数型も対象にする |
| 照合と値の並びの補題（13 定理、`matchList_cons`〜`matchVal_list`） | 同じパターン照合の成功・並びの長さ・`InhabitsAll`・`InhabitsEach` の前提から、同じ分割・連結・ワイルドカードの照合とリストの前後の照合を導く。値と型は名前付きの共有型を使う |
| 区間の端と列挙の補題（12 定理、`snoc_induction`〜`segments_cover`） | 整列への所属、上下端の極値、問いの端を含む区間の被覆について、元の前提・結論をそのまま維持する |
| リストの前後の特殊化の補題（7 定理、`padded_match`〜`listBounds_spec`） | 元と同じ長さ・前後の上限・型・照合の前提から、特殊化した値の並びの長さ・型・照合と、列全体の上限を導く |
| `CoverageExamples.ctors_complete`（1 定理） | 具体的なプログラムの全構成子が一覧にあることを、同じ宣言と一覧から証明する |
| `CoverageShow` の `CoverageDisplay`・`CoverageWitness.show`・`showWitnesses` | 新しい反例の型を使い、宣言側の表示名・レコードのフィールド名と位置順の引数を表示する。表示の定義は名前空間以外を変更しない |

旧 `Coverage` の評価例 31 件と旧 `CoverageShow` の表示例 8 件は、同じ入力・期待結果・証明のまま新モデルへ写した。既存の例・定理は旧モデルにも保持する。二モジュールを `formal/Benitoite.lean` に登録し、35 定理の公理依存は既存の `propext`・`Classical.choice`・`Quot.sound` の範囲であることを確認した。新しい公理と `sorryAx` はない。

N5a の移植の境界は `listBounds_spec` の直後とした。`Represents`・`ShapeStep` は証明のための定義なので、対応する証明とともに N5b に残し、次節のとおり追加した。未移植の定理を宣言する仮置きは行っていない。N5a の検査と差分確認は [n5a-implementation.md](n5a-implementation.md) に記す。

## 網羅性の健全性と実行時補題の対応

N5b は `Release/Coverage.lean` の残る全 30 定理と `Release/Lemmas/CoverageRuntime.lean` の全 10 定理を、同じ名前で新モデルに移した。N5a と合わせて `Coverage` の全 65 定理が揃い、型は契約名を含む共有型を使う。追加した証明の本文は、名前空間の変更を除いて旧モデルと一致する。整形式の条件や新しい外部仮定を追加せず、元の前提・結論を維持する。

| 旧定義・定理 → Named モデルの同名定義・定理 | 前提・結論と名前の対応 |
|---|---|
| `Coverage.Represents`・`ShapeStep`、`Represents.length`・`interval_integer_sound`・`interval_character_sound`・`Represents.restore`・`specialize_wild`（5 定理） | 形が表す値と特殊化した引数の対応を定義し、長さと元のパターンへの照合の復元を証明する。構成子のフィールドの型に含まれる契約名を保持する |
| `integer_interval_of_match`・`character_interval_of_match`・`shapes_interval_cover`・`char_scalar`、`shapeStep_wild`・`shapeStep_other`・`shapeStep_integer`・`shapeStep_character`・`shapeStep_list`・`shapeStep_con`・`shapeStep_boolean`・`shapeStep_unit`・`shapeStep_string`、`shapes_cover`（14 定理） | 同じ構成子一覧の完全性・所属・型の値・照合の前提から、その値に対応する形と特殊化した問いを導く。関数型を含む全ての `Inhabits` の場合を維持する |
| `firstUseful_none`・`specializeRows_restore`・`usefulFuel_none_sound`（3 定理） | 任意の燃料について、有用でないという結果から、その問いが照合する値を覆う既存の行を導く。パターンの型付けや行の長さの整合を外部の前提に加えない。燃料切れを有用側に倒す判定を維持する |
| `useful_none_sound`・`useful_singleton_none_sound`・`checkMatch_exhaustive_sound`・`irrefutable_sound`（4 定理） | 元と同じ構成子一覧の完全性を前提に、行列の被覆、ガードのない分岐の網羅性、束縛の左辺の網羅性を導く |
| `mem_unguardedPats`・`precedingPats_mem`・`checkMatch_unreachable_lookup`・`checkMatch_unreachable_sound`（4 定理） | 報告した位置にある選択肢と先行する行を結び付け、その選択肢が `AlternativeSelected` の意味で選ばれないことを示す。分岐・選択肢の順とガードの扱いを維持する |
| `CoverageShow` | N5a の表示の定義と全 8 例をそのまま使用する。健全性証明の追加後も同じ反例の型を受け取り、表示名・フィールド名・位置順の引数と期待結果を保持する |
| `CoverageRuntime` の `SlotsOk`・`RuntimeSelected`、`Pat.matchVal_length`・`Pat.matchList_length`・`selectSlots_isSome_of_lt`・`HasTypeArms.slotsOk`（4 定理） | 型を仮定しない照合の束縛数と、分岐の型付けから導く slots の整合を保持する。契約名を追加の slots や局所束縛名として使わない |
| `firstAlt_none_of_slotsOk`・`mem_unguardedPats_iff`・`firstAlt_eq_selectSlots_of_take`・`RuntimeSelected.alternativeSelected`（4 定理） | slots の整合のもとで `firstAlt` の失敗と照合の接頭部を結び付け、実行時の選択条件からパターンだけによる選択条件を導く。実際の到達可能性を結論に加えない |
| `checkMatch_unreachable_runtime`・`checkMatch_unreachable_runtime_of_C_Match`（2 定理） | 選ばれない選択肢の判定を `RuntimeSelected` の否定に接続する。後者の値・分岐の型付けと `Exhaustive` の前提を維持し、slots の整合は分岐の型付けから導く |

新しい `CoverageRuntime` を `formal/Benitoite.lean` に登録した。N12 の CheckTools が使う `Coverage`・`CoverageShow` と、網羅性・束縛の左辺の健全性の入口は、新モデルの型と名前空間で import・参照できる。CheckTools 自体の移植や新しい比較入口は今回追加しない。

追加した全 40 定理の `#print axioms` は既存の `propext`・`Classical.choice`・`Quot.sound` の範囲であり、新しい公理と `sorryAx` はない。旧モデル・全入口・交換形式を変更せず、旧形式の差分検査を維持する。検査と後続作業は [n5b-implementation.md](n5b-implementation.md) に記す。

## コアの保存と遷移の健全性の対応

N6 は保存と遷移の健全性の五モジュールの全 47 定理を揃えた。このうち 11 定理は R28 により N5 で実装済みであり、その言明・証明を維持する。残る 36 定理と R29 の前倒しの二補題を加え、新しい証明は合計 38 定理である。型と項は契約名を含む共有型を使い、名前を消した旧モデルへの変換はしない。

| 旧モジュール → 新モジュール | 対応する定理・定義 | 前提・結論と名前の対応 |
|---|---|---|
| `Release/Lemmas/PresHelpers` → `NamedRelease/Lemmas/PresHelpers` | 全 13 定理と `StateTyE`。N5 の三定理を除く 10 定理を追加 | `StateTyE` は実行・分岐選択・エラー・終了の四状態を対象とし、継続の末尾で許すエフェクトを固定する。`stateTy_iff`・分岐の接頭部・閉じた継続・継続の戻り値の整形式・`markPush`・節の探索は、元と同じ型付けと閉じた項の条件から同じ結論を導く。節の探索は名前の整形式を含む型付けから本体の位置ごとの型を取り出す |
| `Release/Lemmas/Preservation` → `NamedRelease/Lemmas/Preservation` | 全 12 定理。N5 の二定理を除く 10 定理を追加 | `Ty.Le.fn_fn'` は元の引数型・戻り値型の等式とエフェクトの包含に、契約名の並びの等式を加える。`inv_prim_app`・`inv_op_app` はこの等式を使い、宣言順の引数の型を型付けから導く。`pres_op_common` は同じ宣言・ストア・継続・節・閉じた引数の条件から、操作を処理した後の `StateTyE` を導く。局所名の綴りを操作の契約名に固定する前提は加えない |
| `Release/Lemmas/PresBase` → `NamedRelease/Lemmas/PresBase` | 全 16 定理。N5 の六定理を除く 10 定理を追加 | ストアの同じ場所の更新、エラー・終了・値の返却、継続の解放、セル・遅延値の組み込みの型付けの前提・結論を維持する。`refUpdate_typed` の関数引数は Q10 の `value` を持つ型を使い、組み込みの名前の整形式は既存の `sig_scoped` から導く |
| `Release/Lemmas/PresMain` → `NamedRelease/Lemmas/PresMain` | `preservationE` | 元と同じプログラムの整形式・型付け・エフェクト宣言の整合・組み込みの仮定と、一歩の `Step`・遷移前の `StateTyE` から、同じ末尾エフェクトの遷移後の `StateTyE` を導く。全 64 遷移の場合を保持し、ラムダ・宣言した関数・操作・メソッド・辞書・ハンドラ・再開・セル・遅延値・分岐・エラー・終了・解放を含める |
| `Release/Lemmas/StepSound` → `NamedRelease/Lemmas/StepSound` | 全 5 定理。ハンドラの分割の二定理、`releaseStep_cases`・`rel_resp`・`step_soundE` | 元と同じ型付きの状態、可能な IO と解放の応答を選ぶ条件、有限なストアの空き場所を選ぶ条件から、`step` が返した遷移が `Step` に属することを導く。四状態と全構文の場合を維持する。名前を実行の分岐に使う条件は加えない |
| `Release/Lemmas/Progress` → `NamedRelease/Lemmas/Progress` | `HasTypeV.canonical_fn`・`HasTypeC.resume_form` の二補題を前倒し | 関数型の閉じた値の四つの形と、`resume` の第一引数が変数か場所であることを、元と同じ型付けの前提から導く。関数型とラムダの存在量化には契約名も保持する。依存の補正は R29 に記録した |

`preservationE` と `step_soundE` が N6 の主定理である。`StateTy` に対する旧 `preservation`・`step_sound` の言明は、`stateTy_iff` を使う元と同じ証明で導けることも一時ファイルで確認した。最終の `Theorems` と進行・エフェクト健全性の証明は N7 に残す。

`PresMain`・`Progress`・`StepSound` を `formal/Benitoite.lean` に登録した。五モジュールと前倒しの二補題の全 49 定理について、`#print axioms` は旧モデルの同名定理と一致し、既存の `propext`・`Classical.choice`・`Quot.sound` の範囲である。新しい公理と `sorryAx` はない。検査と後続作業は [n6-implementation.md](n6-implementation.md) に記す。

## 進行・エフェクト健全性とコアの最終定理の対応

N7 は `Progress` の残る 17 定理、`EffectSound` の全 6 定理、`Theorems` の全 4 定理を加えた。R29 の二補題は再定義せず、その言明・証明を保持した。最終定理は契約名を含む `Ty`・`Val`・型付け判断・状態・遷移を直接使う。

| 旧モジュール → 新モジュール | 対応する定理・定義 | 前提・結論と名前の対応 |
|---|---|---|
| `Release/Lemmas/Progress` → `NamedRelease/Lemmas/Progress` | 全 19 定理。閉じた関数・辞書・再開の形、ストアの三種のセル、ハンドラの探索、未処理の利用者操作の否定、返却・脱出・エラー・終了・IO・組み込み・適用・実行・`progressE` | 元と同じ型付け・宣言・組み込みの仮定・末尾エフェクトの条件から、四状態について最終状態か遷移が存在することを導く。`canonical_fn` は名前付き関数型と名前付きラムダを扱う。適用の証明は `Ty.Le.fn_fn'` から名前と引数型の対応を保ち、実行に必要な個数の一致を導く |
| `Release/Lemmas/EffectSound` → `NamedRelease/Lemmas/EffectSound` | `builtinOnly_empty`・`ContTy.end_of_noHandler`・`no_event`・`no_unhandledOp`・`stateTyE_init`・`steps_preserve` | 全て元と同じ前提・結論の形である。末尾エフェクトが空なら全ての IO・終了・解放の事象が起きず、組み込みだけを許す末尾から利用者の未処理の操作を呼ばない。初期状態の型付けと任意の有限な遷移列での保存も維持する |
| `Release/Theorems` → `NamedRelease/Theorems` | `step_sound`・`progress`・`preservation`・`effect_soundness` | 四定理の明示・暗黙の引数と結論の形は元と同じであり、共有型を新しいものに移す。`stateTy_iff` と名前付きコアの主定理から導く。`EffectSound` を直接 import する |
| `Release/Examples` → `NamedRelease/Examples` | 全 26 例と補助 `wildAltsTy` | 実行結果・事象の数・パターンの束縛とガード・型付け・幅付き定数のパターンの拒否を維持する。組み込み・関数・操作・メソッド・ラムダに契約名を加え、入力と期待結果のほかの部分は変更しない |
| `Release/BuiltinTable` → `NamedRelease/BuiltinTable` | 全ての定義と全 17 例 | 名前を持つ関数型でも、関数が等値・鍵を持たず、内側の型をデータ型の要約の依存に加えない規則を維持する。例の一引数関数型には Q10 の `value` を与える |
| `Release/Model` → `NamedRelease/Model` | 最終定理を使う二例を追加 | 空のプログラムと上位辞書からのメソッド呼び出しについて、元と同じ前提を具体的に満たし、任意の到達状態で事象と未処理の操作がないことを示す |

`progress` は元と同じ `WellTyped`・`EffectsOk`・`Builtins.Assumptions` と `StateTy` から、最終状態か一歩の遷移を導く。`preservation` はさらに元と同じ `WellFormed` を使い、遷移先の `StateTy` を導く。`effect_soundness` は空のエフェクトで型の付いた、エフェクト変数を含まない初期計算から、任意の到達状態の無事象と未処理の操作の否定を導く。新たな名前の正しさを外部の仮定として加えない。

`Examples.builtins` の二項演算は `left, right`、`new` は `value`、`get` は `reference`、`set` は `reference, value`、`update` は `reference, f` と内側の `value`、`force` は `value` とする。IO の例の `print` は `text`、`exit` は `code`、メソッド `combine` は `x, y` とし、元の型と応答を維持する。ゼロ引数の関数・操作・メソッドは名前も空の並びとする。組み込み制約の表と交換形式のシグネチャの表の区別は R30 に記した。

進行・エフェクト健全性・最終定理の全 29 定理は、旧モデルの同名定理と公理依存が一致した。前提・結論の文章上の差は、共有型の名前空間と、R29 で移した `canonical_fn` の名前の欄だけである。コアの定義と言明のレビューは [reviews/N7-core-report.md](reviews/N7-core-report.md)、作成時の関門と検査は [n7-implementation.md](n7-implementation.md) に記す。


## 名前付き表層の定義と脱糖の対応

N8 は `Surface/Syntax.lean`・`Typing.lean`・`WellFormed.lean`・`Desugar.lean` の全定義を、それぞれ `NamedSurface/` の同名モジュールへ移した。共有型・値・計算・宣言・組み込みの型付けは `NamedRelease` を直接使う。旧型への変換や契約名を消す処理はない。旧モジュールと交換形式の入口は維持する。

| 旧定義 → 新定義 | 名前・位置と既存の保証の対応 |
|---|---|
| `Expr`・`Exprs`・`HoleArgs`・`Arms`・`Clauses`・`Block` と宣言 | 全構文を維持する。通常呼び出しにソース順のラベルと位置、穴の各要素にラベルと位置、ラムダと生成する関数値に契約名を持たせる。宣言の関数名は値引数だけを数え、辞書の内部名を利用者の並びに混ぜない |
| `CallOk`・`sourceTypes`（新設） | 名前の長さ・一意性、ラベルと契約位置の一致、位置の全域性・単射性・範囲を入力側で検査する。一引数の位置指定以外には明示ラベルを要求する。挿入時は位置 0 と明示位置の並びが全位置の置換になることを要求し、重複も排除する。期待型は宣言順からソース順に取り出す |
| `HasType`・`HasTypes`・`HasHoleArgs`・`HasEach`・`HasArms`・`HasClauses`・`HasBlock` | 既存の全規則を維持する。通常・操作・辞書を通すメソッドの呼び出し、穴、パイプも名前付きの共有型を使う。元の型・エフェクト・最も内側の戻り値型・末尾位置・継続の制限を保つ。宣言・組み込み・操作・メソッド・ラムダの名前の整形式も要求する。ハンドラの局所名の綴りは制約しない |
| `E_Call`・`E_PipeCall`・`E_PartialCall` | `CallOk` とソース順の期待型を使う。パイプは左辺を位置 0 に挿入する。穴の名前と型はソース順であり、callee と固定式を新しいラムダの戻り値型のもとで検査する。元の契約注釈は callee の型と一致させる |
| `E_ConValue`・`E_PartialCon`・`accessorDecl` | 位置構成子の関数値と直接の穴には元の宣言位置から `argN` を付ける。レコード構成子の関数値は宣言順のフィールド名と照合し、直接のレコードの穴は排除する。取り出す関数は `value` を持つ。宣言の名前の表は R31 で補った |
| `Expr.Scoped`・`HoleArgs.Scoped`・`Def.Scoped`・`Program.WellFormed` など | 型・エフェクト・局所番号の範囲を入力の木で検査する。関数値の名前の整形式、宣言の利用者名と内部辞書名の整合、レコードの名前の表の整形式を加える。脱糖の出力が正しいという外部の前提は加えない |
| `callComp`・`desugarExpr`・`desugarHoleArgs` | callee を先に、引数の式をソース順で一度ずつ束縛する。直接の頭と辞書は元と同じく値として扱う。全束縛の後、位置順に並べるのは値の参照だけである。パイプ左辺は callee より前に束縛し、位置 0 に渡す。部分適用ではこの束縛列全体をラムダの内側に置き、固定式の評価を作成時へ早めない |
| `desugarDef`・`desugarImpl`・`accessorDef`・`desugarProgram` | 関数の利用者の契約名を保持し、辞書の内部名 `%dict1` からの並びを先頭に加える。操作とメソッドの宣言は名前付きのまま写す。レコード・制御・コレクション・return・try・with・lazy・handle・resume の脱糖は元と同じである |

四モジュールを `formal/Benitoite.lean` に登録した。通常・穴・パイプ・操作・メソッド・構成子の型付け例、誤った対応を拒否する例、callee・引数の評価順と参照の配置を確認するコアの等式を、新しいモデル自身でビルドする。具体入力の等式の期待結果は手で書き、脱糖器から作っていない。

N8 は定義と具体例の確認であり、一般の脱糖の型保存の証明を終えたとは扱わない。変数移動と文の列の補題は N9、呼び出し・パイプ・穴の型保存は N10、全範囲の性質 1 は N11、実行可能な checker と交換形式は N12〜N15 に残す。作成時の関門・検査・申し送りは [n8-implementation.md](n8-implementation.md) に記す。

## 表層の変数移動・範囲保存・文の列の対応

N9 は七モジュールの全 83 定理を同じ名前・順で新モデルへ移し、依存と文の列・return・try のための 21 定理を四つの補助モジュールに加えた。全 104 定理のうち、元から非公開の `cleanList_replicate` を除く 103 定理について `#print axioms` を確認し、依存は既存の `propext`・`Classical.choice`・`Quot.sound` の範囲である。移した既存の公開 82 定理は旧モデルと公理依存が一致した。

| 旧モジュール → 新モジュール | 定理と前提・結論の対応 |
|---|---|
| `Surface/Lemmas/ShiftClean`・`SubstClean` → `NamedSurface/Lemmas/` の同名モジュール | 各 2 定理。型変数の移動・置換の範囲と継続型を含まない条件を保つ。関数型の名前は変えず、型の並びの長さが map で不変であることから名前の整形式を保持する |
| `Invariants` → 同名モジュール | 全 28 定理。環境・辞書・宣言・穴・全ての式と文の結果型の不変条件を維持する。`fnTy_clean` は関数型に加わった名前の整形式を受け取り、各使用箇所では型付けの証拠から与える。新しい全構文を含む帰納法で証明する |
| `ScopedRename` → 同名モジュール | 全 5 定理。値・計算・分岐・節の型変数とエフェクト変数の範囲を番号の付け替えで保持する。ラムダの契約名と整形式の証拠をそのまま保持する |
| `Sequence` → 同名モジュール | 全 27 定理と `CompTypes`。任意の長さの計算列をソース順に束縛し、各計算を既に挿入した束縛数だけ移す。`letChain_typed`・`sequence_typed` は元と同じ型付けから同じ結果型と許容エフェクトを導く。長さや移動量の上限を加えない |
| `ExtensionsScoped` → 同名モジュール | 全 7 定理。リストの展開と文字列補間の全ての場合で、型・エフェクト変数の範囲を保つ。内部の call の位置は式の順序を変える条件にしない |
| `Scoped` → 同名モジュール | 全 12 定理。式・式の列・穴・分岐・節・文の列を含む元の全範囲を維持する。call のラベル・位置、穴の契約注釈を保持し、`CallOk` と名前の整形式の前提を持つ新しい判断で帰納法を行う。ラムダ・生成する関数値には入力から得た名前の整形式を付ける |
| `Calls`・`Records` の範囲保存 → `ScopedSupport` | 9 定理と `CallHead.Scoped` を前倒しする。`callComp_scoped` は位置順に並べる値の参照の範囲も `recordFields_scoped` で示す。ラベルと位置の正しさや引数の型保存をこの定理で代用しない |
| `Patterns` の文の束縛用の基礎 → `PatternSupport` | 7 定理。パターン・値の所属・網羅性の構成子表に関する合同性と、パターンの束縛を保護する `HasTypeC.shiftPattern` を前倒しする |
| `Typing` の文の列 → `BlockSequence.HasBlock.desugar_of_expr` | 式の型保存を組み立ての前提として、元の全 11 個の B 規則を扱う。単文・束縛・捨てる文・通常の文・パターンの束縛・包含と、束縛の作用先・最内の R を保つ。式全体の型保存と性質 1 は N10・N11 の証明で完成する |
| `Typing` の return・try → `ReturnTry` | 四補題。末尾の return は子の計算の型付けを保持し、非末尾は同じ最内の R に escape する。Result は同じエラー型、Option は同じ戻り先の型を保持する。子の計算の型付け・結果型の範囲・構成子の宣言・網羅性は元の導出から得る |

十一モジュールを lake のルートへ登録した。旧モデル・旧入口・交換形式・Rust の入力と期待値は維持する。短いラムダの解析境界、実行時の IO 順全体、全範囲の性質 1 は今回の証明の結論に含めない。R32 に依存と証明の分割の補正、[n9-implementation.md](n9-implementation.md) に検査と後続作業を記す。

## 呼び出し・穴・パイプの型保存の対応

N10 は四モジュールに 36 の公開補題を追加した。通常・穴・パイプの八つの呼び出し規則を、子の計算の型付けから組み立てる。一般の呼び出しは callee を先に束縛し、引数の計算をソース順の let に置く。直接の関数・操作・メソッドは計算を持たない頭を使う。並べ替えるのは全束縛の後の値の参照だけであり、計算の可換性は仮定しない。

| 旧モジュール・定理 → 新モジュール・定理 | 前提・結論・範囲の対応 |
|---|---|
| `Surface/Lemmas/Calls` の `CallHead.HasType` と `apply`・`rename`・`weakenEff` → 同名モジュールと定理 | 頭の判断に値引数の契約名を保持する。app は内部辞書の名前と値引数の名前を連結した関数型、meth は宣言の名前から辞書数を除いた契約を持つ。型付けにある名前の整形式を使い、同じ値引数・結果型・許容エフェクトで apply・変数移動・エフェクトの拡大を示す |
| `Calls.desugarClauses_handles`・`desugarClauses_handled` → 同名モジュールと定理 | 元と同じ操作の節と handled の等式を維持する。節の本体の型付けを前倒しせず、N11 がこの等式を使う |
| `Records.fieldAt_typed`・`valueMaps_typed`・`map_range_getD`・`recordFields_typed` → `Calls` の同名定理 | ソース位置ごとの型付けと、全宣言位置の置換から、宣言順の参照の型付けを導く。値・計算・型のデータ構造を旧モデルへ戻さず、名前付きの共有型で証明する。N11 の Records はこの四補題を再定義せず使う |
| 新しい `Calls.CallOk.positions`・`sourceTypes_length`・`sourceTypes_append` | `CallOk` の置換から、挿入位置を含む位置列の単射性・範囲・全域性を導く。ソース型の並びの長さと連結を示し、callee の全引数型とソース順の型を区別する |
| `Calls.callComp_typed` → 同名モジュールと定理 | 元の callee・挿入済みの値・引数計算・範囲・許容エフェクトの前提を名前と位置対応に拡張する。全位置の置換と `sourceTypes` を使い、直接の頭と先に callee を束縛する値呼び出しの両方で型を保存する。ソース順の let の移動量に上限を付けない |
| `Surface/Lemmas/CallHead` の全八定理 → 同名モジュールと定理 | 宣言・辞書のコアへの対応、辞書付きの関数とメソッドの導出の逆転、直接の頭の型付けを維持する。`funDecl_desugared` はコアの内部辞書名と利用者の名の連結も示し、逆転は名前の整形式・位置ごとの名前を保持する。追加の `DictEv.toValList_length` は、辞書の値化で名前の drop の位置を変えないことに使う |
| `Surface/Lemmas/Dict` の全三定理 → `DictSupport` | 辞書の局所番号を保つ継続の隠蔽と、エフェクト引数に依存しない辞書型の置換。CallHead と後続の値化した関数・メソッドに必要な依存だけを前倒しする |
| `Typing.HasTypes.desugar`・`HasEach.desugar`・`HasHoleArgs.desugar` → `desugar_of_expr` の三補題 | R33 に従い、式の帰納法の結論から元と同じ列の型保存・結果型の範囲を組み立てる。穴の列は左で通った prior と残る穴のソース順の型を連結し、穴の番号と固定式の変数移動を保持する。式全体の保存を外部仮定にした最終定理とはしない |
| `Typing` の `E_Call`・`E_PipeCall`・`E_PipeApply`・`E_PartialCall` → `HasType.desugar_call`・`desugar_pipeCall`・`desugar_pipeApply`・`desugar_partialCall` | 子の計算の型付け、表層の callee の判断、対応表、範囲の補題から各場合の型保存を組み立てる。パイプ左辺は最初の let として位置 0 を占める。穴は `holeNames`・`holeTypes` のソース順の契約を持つラムダを返し、callee と固定式は本体の内側に置く。括弧・穴付き右辺へのパイプは一引数適用を維持する |
| `Typing` の `E_ConCall`・`E_PartialCon`・`E_PipeConCall`・`E_PipeConValue` → `HasType.desugar_conCall`・`desugar_partialCon`・`desugar_pipeConCall`・`desugar_pipeConValue` | 構成子の直接構築の位置指定・型引数・戻り値型・許容エフェクトを維持する。穴のラムダは位置由来の argN の契約を保持し、固定式を作成時に評価しない。直接パイプは左辺の値を先頭のフィールドへ一度だけ渡す |

四モジュールを lake のルートに登録した。`Typing.CallExamples` の三例は、型の異なる逆順の二引数、エフェクトを持つ固定引数を挟んだ穴 b・a、位置 0 をパイプで挿入して残る二引数を逆順指定する場合について、一般の補題から実際の脱糖結果の型付けを導く。既存の脱糖の等式の例は変更していない。

全 36 公開補題の `#print axioms` を確認し、依存は既存の `propext`・`Classical.choice`・`Quot.sound` の範囲である。旧モデルに同名の定理がある 21 補題は公理依存が一致した。新しい公理・sorry・既存の定理やテストの弱化はない。式全体・制御・コレクション・辞書の残る証明とプログラム全体の性質 1 は N11、checker と新しい交換形式は N12〜N15 に残す。検査と後続作業は [n10-implementation.md](n10-implementation.md) に記す。

## 制御・コレクション・辞書と全範囲の性質 1 の対応

N11 は残る補題と、全七判断の脱糖の型保存を接続した。全 49 公開定理は旧 `Surface` の同名定理に対応する。操作・ハンドラ・型クラス・コレクション・レコードを除外せず、対象の型を狭める追加の述語や、式の保存を仮定する前提を最終定理に加えていない。前倒し済みの補題の配置は R34 に記す。

| 旧モジュール・定理 → 新モジュール・定理 | 前提・結論・契約名の対応 |
|---|---|
| `Surface/Lemmas/Extensions` → `NamedSurface/Lemmas/Extensions` | 全 13 定理と `StrHeadsTyped`。計算列・同じ型の値列の連結、take/drop、リストの展開、補間と左からの文字列の連結の型保存を維持する。List.concat の頭は xs・ys、補間の変換関数は value、文字列の加算は left・right の契約を保持する。`stringAdd_typed` の名前の整形式は既存の `StringAddOk` の関数型の等式から導く |
| `Surface/Lemmas/Patterns` → `NamedSurface/Lemmas/Patterns` | 残る全 6 定理。単一の分岐、選択肢の型付けの合同性と範囲、照合対象の let を挿入する際の束縛・ガードの保護、脱糖後の未ガードのパターン列の一致を維持する。N9 の `PatternSupport` の 7 定理は再定義しない |
| `Surface/Lemmas/Records` → `NamedSurface/Lemmas/Records` | 残る全 17 定理と `retainedTypes`。取得関数の範囲と型付け、単一構成子の網羅性、型変数の恒等置換、更新で残す値の型付けを維持する。関数型の名前は恒等置換で変わらず、取得関数は value の契約を持つ。範囲保存と位置対応の型付けは `ScopedSupport`・`Calls` の前倒し済みの補題を使う |
| `Surface/Lemmas/Dict` → `NamedSurface/Lemmas/Dict`・`DictSupport` | `Dict` は `DictSupport` を import する。N10 の辞書の隠蔽・置換の全三定理をそのまま使い、重複を作らない。辞書の値化と直接の頭の補題は `CallHead` に接続済みである |
| `Surface/Lemmas/Typing` → `NamedSurface/Lemmas/Typing` | `HasType.desugar`・`HasTypes.desugar`・`HasEach.desugar`・`HasHoleArgs.desugar`・`HasArms.desugar`・`HasClauses.desugar`・`HasBlock.desugar` の全七定理。元と同じ型付き入力・番号の範囲・環境の条件・最内の戻り値型の条件から、実際の脱糖結果の型付けを導く。全構文の構造的な相互帰納法であり、式の型保存を外部仮定に残さない。呼び出し・穴・パイプの各場合は N10 の組み立て補題を使う |
| `Surface/Lemmas/Program` → `NamedSurface/Lemmas/Program` | `desugar_wellFormed`・`desugar_wellTyped`・`desugar_effectsOk`・`main_typed` の全四定理。利用者の関数・生成される取得関数・型クラスの実装と上位辞書・操作・メソッド・入口を含め、元と同じ保証を導く。コアの関数には内部辞書名と利用者名、メソッドには元の宣言の名前を、入力の整形式・型付けの証拠から与える |
| `Surface/Theorems` → `NamedSurface/Theorems` | `desugar_typed`（性質 1）は元と同じ三前提から、脱糖後の整形式・型付け・エフェクト宣言の整合の三結論を導く。`surface_effect_soundness` は元と同じ四前提と main の開始状態から、任意の到達状態での無事象と未処理の操作の否定を導く。組み込みの動作の仮定は後者だけが使う |

七つの追加モジュールを lake のルートに登録した。`NamedSurface/Examples` は、名前付きの操作・再開するハンドラ・逆順指定のメソッド呼び出し・型クラスの実装を含むプログラムで、性質 1 と表層のエフェクト健全性の前提を具体的に満たす。また、if とリストの型保存、および期待型の契約名だけが異なるラムダの拒否を、全構文の型保存定理から導く。旧モデルの全例と既存の Named の例は変更しない。

全 49 公開定理は、旧モデルの同名定理と公理依存が一致した。依存は既存の `propext`・`Classical.choice`・`Quot.sound` の範囲であり、新しい公理と `sorryAx` はない。

性質 1 は型保存の定理であり、短いラムダの解析境界や実行時の IO 順全体の保証には広げない。実行可能な checker と新形式の交換の接続は N12 以降に残す。検査と後続作業は [n11-implementation.md](n11-implementation.md) に記す。

## 実行可能な名前付き表層の検査と基礎補題の対応

N12 は旧 checker の七モジュールの構文と検査を Named の型へ移し、契約名とソース順の対応の検査を追加した。既存の公開 99 定理を同じ名前で維持し、三つの新しい判定の同値を証明した。`checkExprR` などの全構文の健全性の主定理は N13・N14 に残す。

| 旧モジュール → 新モジュール | 前提・結論・名前と位置の対応 |
|---|---|
| `Surface/CheckTools` → `NamedSurface/CheckTools` | 全 43 公開定理。型と型の列の比較、型の包含、変数移動、型・エフェクトの置換、有限の原子集合、制約の判定の保証を維持する。関数型の比較と包含は名前の並び全体を比較し、変数移動と置換は名前を変えない。名前の正しさを外部仮定へ追加しない |
| `CheckPredicates` → 同名モジュール | 既存の全 25 公開定理。`wfTy_spec` は関数型の `NamesWF` も検査する。`stringAddOk_sound` は left・right の契約を含む既存の `StringAddOk` を導く。新しい `namesWF_spec`・`callOk_spec`・`constructorHolesOk_spec` は、それぞれ `NamesWF`・`CallOk`・`HoleArgs.ConstructorOk` と判定の成功の同値である。追加の前提はない |
| `CheckPatterns` → 同名モジュール | 全 14 公開定理。パターンの束縛型と型付け、選択肢の対応、match・try・束縛・レコード更新の網羅性を維持する。N5b の Named の Coverage を使い、型の中の契約名を消さない |
| `CheckSupport` → 同名モジュール | 全 15 公開定理。型の合流、エフェクトの差、環境・宣言・全構文の原子集合の補題を維持する。関数型の合流には同じ名前と引数型と戻り値型を要求する。`AtomsIn` に名前の正しさの外部条件を追加しない |
| `Check` → 同名モジュール | 制御・コレクション・辞書・ハンドラを含む旧 checker の全構文を維持する。通常呼び出しは callee の契約と `callOk` を照合し、引数の型を `sourceTypes` でソース順へ対応させる。穴は callee の契約注釈・各ラベルと位置を検査し、生成する名前と型を穴の出現順にする。パイプ挿入は位置 0 の重複も拒否する。ラムダ・宣言・操作・メソッドの名前も検査する |
| `CheckTables` → 同名モジュール | 表の探索の二定理を維持する。R36 の Named の型付き材料を使い、関数・構成子のフィールド名・操作・クラス・実装を失わず表へ移す。実装メソッドは `MethodInput.names` と `MethSig.names` の並び全体を比較してから位置の環境で本体を検査する。`checkProgram` は元の材料を受け取るため、実名を消した `ImplDecl` だけで検査を済ませない |
| `CheckToolsExamples` → 同名モジュール | 旧 130 例を名前付きの型へ移して維持する。checker の公開入口で 42 例を追加し、正常な逆順指定・穴・パイプ・操作・メソッド・辞書付き関数、ラベル・位置・型・ラムダ名・メソッド実名の拒否を具体的に計算する。失敗例は経路と理由の両方に一致させる |

七モジュールを lake のルートへ登録した。全 99 組の公開定理は旧モデルと公理依存が一致し、三つの新しい同値定理も既存の `propext`・`Classical.choice`・`Quot.sound` の範囲である。sorry と新しい公理はない。新しい checker が受理した全入力の型付けの導出は N13・N14、corpus 8・型表 2・網羅性 2 と六つの入口への接続は N15 に残す。検査と申し送りは [n12-implementation.md](n12-implementation.md) に記す。

## 基本の式・呼び出しと検査成功の健全性の対応

N13 は六モジュールに 130 の公開定理を追加した。128 定理は旧モデルの同名定理に対応し、残る二定理は契約名の整形式とソース順の型の原子集合を接続する。場合別の補題は小さい子に対する健全性を構造的な帰納法の仮定として使う。全構文についてその仮定を解消する相互帰納法は N14 に残す。

| 旧モジュール・定理 → 新モジュール・定理 | 前提・結論・名前と位置の対応 |
|---|---|
| `Surface/CheckLemmas` → `NamedSurface/CheckLemmas` | 既存の 56 公開定理と新しい二定理。成功経路・状態・型の受け入れ・エフェクトの包含・原子集合の保証を維持する。`fnView_ok` は名前・型・戻り値・エフェクトの四要素を保持する。`fnTyCheck_namesWF` は具体化後の型の等式と既知の契約の整形式から元の契約の整形式を導く。二項演算子では実際に検査した left・right の等式を使う。`sourceTypes_atoms` はソース順で取り出した各引数型の原子集合を保存する |
| `CheckInduction` → 同名モジュール | 既存の 19 定理と全六構文の帰納法の契約。環境・戻り値・位置・状態・添字を元と同じく全称量化し、`Input.Sound` に名前・ラベル・位置の正しさを外部条件として加えない。`checkDef_of_mutual` は関数名の整形式も検査成功から導く |
| `CheckSoundDicts` → `CheckDictSupport` | 全三定理を前倒しする。辞書と辞書引数の独立した相互帰納法は、局所・実装・上位辞書を含む。関数値・メソッド値の証明が使い、N14 は再定義しない |
| `CheckSoundBasicExpr` → 同名モジュール | 全 24 定理。リテラル・局所・定数・括弧・宣言された関数・組み込み・操作・構成子・辞書付き関数・メソッド・論理演算・数値演算の型付けと原子集合を維持する。名前の整形式と注釈の一致は `namesWF`・名前の比較の成功から導く。構成子の関数値はレコードのフィールド名か位置由来の argN と照合する |
| `CheckSoundSequence` → 同名モジュール | 全 14 定理。型の列・同一型の列・穴・文の列の全場合を扱う。固定式の型とエフェクト、穴の包含、束縛・パターン・網羅性・終了条件を維持する。穴のラベル・位置は構文に残し、全体の対応は呼び出し側で検査する |
| `CheckSoundCalls` → 同名モジュール | 全 12 定理。`call_case`・`pipe_call_case`・`partialCall_case` は `callOk_spec` から `CallOk` を導き、契約名の長さ・一意性、位置の全域性・単射性、ラベルとの対応を型付けへ接続する。引数の型は宣言順に戻さず `sourceTypes` のソース順で検査する。穴は callee の契約注釈・生成する名前の整形式・出現順の型、直接の構成子の穴はラベルなしの宣言順と argN を保持する。通常の値へのパイプは一つの名前と一つの引数型を検査成功から導く |

`CheckLemmas` の実装メソッド・上位辞書の三つの成功分解定理と `CheckInduction.checkImpl_of_checker` は、R36 の `ImplInput` と実名の一致を扱う N14 に残す。旧モデルの定理は削除・変更していない。前倒しした依存の理由は R37 に記す。

N13 の証明で、直接のレコード構文の穴を拒否する検査の不足が判明した。R38 に従って checker に `conFields` の空欄の検査を加え、`partialCon_case` はその成功から既存の `E_PartialCon` の前提を導く。型付け規則を弱めたり、入力の整形式の外部仮定で不足を補ったりしない。既存の穴の三例は位置構成子へ入力を補正して期待値を保持し、レコードの拒否を一例追加した。

全 130 公開定理に `#print axioms` を適用し、依存は既存の `propext`・`Classical.choice`・`Quot.sound` の範囲である。対応する旧 128 定理とは公理依存が一致する。sorry と新しい公理はない。全六モジュールを lake のルートへ登録した。全構文・実装・プログラム全体の checker の健全性は N14、新形式の入力の接続は N15 に残す。検査と後続作業は [n13-implementation.md](n13-implementation.md) に記す。

## 全範囲・実装・プログラムの検査成功の健全性の対応

N14 は八モジュールを追加し、既存の `CheckTables` に演算子の選択と型引数の構築を分ける入口を加えた。六つの証明モジュールに 58 の公開定理があり、55 定理は旧モデルの同名定理に対応する。新しい三定理は `checkImpl_contracts`・`program_impl_input`・`checkProgram_contracts` である。旧モデルの規則・言明・証明・例は変更していない。

| 旧モジュール・定理 → 新モジュール・定理 | 前提・結論・名前と位置の対応 |
|---|---|
| `CheckSoundCollections` → 同名モジュール | 全 9 定理。補間・一覧・一覧の展開・レコードの構築と更新・match の型付けと原子集合を維持する。展開の連結関数は xs・ys の契約を含む期待型で検査する。レコードの位置と式はソース順を保つ |
| `CheckSoundControl` → 同名モジュール | 全 18 定理。ラムダ・条件分岐・return・try・with・lazy・resume・ハンドラの全場合を型付けへ接続する。ラムダと操作の名前の整形式は検査成功から導く。`checkCasesSound` は全六構文の全構成子を列挙し、`mutualSoundness` で子の健全性の帰納法の仮定を解消する。ハンドラの実際のエフェクトの和が許容エフェクトの部分集合であるという結論も維持する |
| `CheckLemmas` の実装の三定理と `CheckInduction.checkImpl_of_checker` → `CheckSoundDicts` | 旧の四定理と新しい `checkImpl_contracts`。`checkMethods_entry` は名前の並び全体の一致と `NamesWF`、本体の検査・受け入れ・エフェクトの検査の成功を同時に導く。`checkImpl_of_checker` は原子集合と従来の有限な一覧の完全性を前提に、`ImplInput.decl` の全メソッド本体・上位辞書の型付けを導く。`checkImpl_contracts` は名前の一致と整形式を独立した結論にし、型や名前の正しさの外部仮定を使わない。辞書自身の三定理は N13 の `CheckDictSupport` を使う |
| `CheckSound` → 同名モジュール | 全 11 定理。式・ブロック・分岐・節・並び・穴・辞書・定義・実装の公開入口の健全性を維持する。`Input.Sound` は従来の六条件のままで、全構文に対する相互帰納法の仮定を含まない。実装の原子集合と型付けの結論は本体の射影を使い、実名の一致は前段の検査から得る |
| `CheckTablesSound` → 同名モジュール | 全 7 定理。有限の材料から、制約の判定・構成子の列挙・レコードの宣言・実装の名前一覧・`Input.Sound` を導く。`opPrim_sound` は R39 の組み込み名の選択の結果によらず、構築した型引数が規則に一致することを証明する。旧 JSON や新たな正しさの外部仮定を使わない |
| `CheckProgramSound` → 同名モジュール | 旧の 6 公開定理と二つの新定理。`program_impl_input` は同じ材料の実名付き入力と本体の射影を対応させる。`checkProgram_under`・`checkProgram_sound` は全関数・全実装の型付け、宣言表の拡張、組み込みとのエフェクト名の重複がないことを維持する。共有表の同一性には `conFields` も含む。`checkProgram_empty` は信頼する宣言が空なら元の `Program.WellTyped` を結論する。新しい `checkProgram_contracts` は全実装の実引数名の一致と整形式を、材料の名前一覧と検査の成功だけから導く |
| `CheckExamples`・`CheckCounterexamples` → 同名モジュール | R40 の独立した型付き材料で新しい 24 例を検査し、旧の穴の四例は名前と位置だけを補って同じ経路・理由・成功期待を維持する。旧の例と N12・N13 の例は残す。実装の実名付き材料から全プログラムの検査と全実装の名前の保証までを接続する |

全 58 定理へ `#print axioms` を適用した。依存は既存の `propext`・`Classical.choice`・`Quot.sound` の範囲である。対応する旧 55 組のうち 54 組は公理依存が一致し、`opPrim_sound` だけは旧の `propext`・`Quot.sound` から `propext` だけへ減った。sorry と新しい公理はない。名前付きコアの最終定理と表層の性質 1 を含め、全八モジュールを登録した `lake build` が通る。

checker の全範囲の健全性は今回で完成し、新交換形式の入力の接続は N15 に残す。新しい入力から名前を消して旧形式へ通す処理は加えていない。検査と申し送りは [n14-implementation.md](n14-implementation.md) に記す。

## N16 の最終定理の前提・結論・範囲の照合

以下の表は N15 までを実装した後の対応である。前節までの「後続に残す」という記述は各作業時点の記録であり、N16 の未完事項ではない。証明の移設・分割の対応は前節までの表、定義と言明のレビューの所見と検査は [G4-report.md](reviews/G4-report.md) に記す。

表の接頭辞 `Release`・`Surface` は旧モデル、`NamedRelease`・`NamedSurface` は新モデルである。同じ役割の前提は名前付きの共有型で解釈し、旧モデルへ名前を消して渡さない。新たな名前・ラベル・位置の条件は型付けと検査の定義に置き、主定理へ独立した正しさの仮定として追加しない。

| 元の定理 → 新しい定理 | 前提の対応 | 結論と範囲の対応 |
|---|---|---|
| `Release.step_sound` → `NamedRelease.step_sound` | `B.Assumptions P`、可能な IO・解放の応答と空き場所を選ぶ条件、`StateTy`、`step = some (l,s')` を維持 | `Step P B s l s'`。全遷移の列挙や `step` の完全性は主張しない |
| `Release.progress` → `NamedRelease.progress` | `P.WellTyped B`・`P.EffectsOk B`・`B.Assumptions P` と `StateTy` を維持 | 最終状態または次の遷移の存在。辞書・操作・再開・エラー・終了・解放を除外しない |
| `Release.preservation` → `NamedRelease.preservation` | `P.WellFormed`・`WellTyped`・`EffectsOk`・`B.Assumptions P`、元の状態の型付けと一遷移を維持 | 遷移先の `StateTy`。名前付きの型・値・ストア・継続を使う |
| `Release.effect_soundness` → `NamedRelease.effect_soundness` | 同じ四つのプログラム・組み込みの条件、空の環境・ストア・エフェクト、`R = none` の型付け、`ClosedNoEffVars`、初期状態からの `Steps` を維持 | 任意の到達状態で事象を伴う遷移がなく、未処理の操作もない |
| 旧の初期状態の範囲条件 → `NamedRelease.effect_soundness_noLamNames` | ラムダ自身の `NamesWF` を除いた `Comp.VarsInNoLamNames` を受け取り、型付けからその整形式を導く。型注釈内部の整形式は維持 | 元と同じ無事象・未処理操作の否定。G2 のラムダ名の追加仮定の指摘を解消する |
| `Surface.desugar_typed` → `NamedSurface.desugar_typed` | `p.WellFormed`・`p.WellTyped B opPrim`・全組み込みの `sig_scoped` の三前提を維持 | 脱糖後の `WellFormed ∧ WellTyped B ∧ EffectsOk B`。型の範囲や扱う構文を狭めない |
| `Surface.surface_effect_soundness` → `NamedSurface.surface_effect_soundness` | 表層の整形式・型付け、脱糖後の組み込みの動作の仮定、`HasMain Eff.empty` を維持 | `main[;]()` の開始状態からの全到達状態で無事象・未処理操作なし。停止性は結論に含まない |
| `Surface.Check.checkExpr_sound`・`checkBlock_sound` ほか → `NamedSurface.Check` の同名定理 | `Input.Sound`、入力・環境・戻り値の有限な原子集合、strict な検査の成功を維持 | 同じ式・ブロック・分岐・節・引数列・穴・辞書・定義の宣言的な型付けと原子集合。契約名・位置の検査成功を外部から仮定しない |
| `Surface.Check.checkImpl_sound` → `NamedSurface.Check.checkImpl_sound` | 同じ原子集合・有限な一覧の完全性・検査成功を、実名を持つ `ImplInput` について受け取る | `id.decl` の全本体と上位辞書の型付け。実名の保証は次の定理で射影前に保持する |
| 対応する旧定理なし → `Check.checkImpl_contracts`・`CheckTables.checkProgram_contracts` | 検査成功と、全メソッドを走査する有限な一覧の完全性。Materials の全件の定理では `implNamesOk` から完全性を導く | `ImplInput.ContractsMatch`。宣言の全メソッドで実装名の一致と宣言名の整形式を結論する |
| `Surface.CheckTables.checkProgram_sound` → `NamedSurface.CheckTables.checkProgram_sound` | 宣言・組み込み・本体の原子集合、構成子の列挙と実装の有限一覧の検査、プログラム検査の成功を維持。演算子は R39 の構築入口を使う | `CheckedUnder`。全利用者関数・実装の型付けと宣言表の拡張・エフェクト名の非重複。信頼する標準ライブラリの本体の証明には拡張しない |
| `Surface.CheckTables.checkProgram_empty` → `NamedSurface.CheckTables.checkProgram_empty` | 前行に加え、信頼する関数・実装の表が空である二前提を維持 | プログラム自身の宣言表のもとでの `Program.WellTyped` |
| 対応する旧定理なし → `CheckTables.checkProgram_sound_contracts`・`checkProgram_empty_contracts` | それぞれ `checkProgram_sound`・`checkProgram_empty` と同じ前提。名前の正しさの仮定を追加しない | 元の型付けの結論と、射影前の全実装の `ContractsMatch` の連言。Z5 で追加した系であり、型付けと実名一致を一つの結論として利用できる |
| `Release/Coverage`・`CoverageRuntime` の定理群 → `NamedRelease` の同名定理群 | 型付きパターン・構成子表の完全性・範囲・燃料に関する従来の条件を維持。関数型には名前がある | 有用性・網羅性・冗長性・実行時の照合の保証を維持。関数の内部を調べるパターンは加えない |

`Check.Input.Sound` は従来の六条件（宣言と組み込みの原子集合、制約と admits の判定の健全性、演算子の型引数、構成子の列挙の完全性）を持つ。`NamesWF`・`CallOk`・実装名の一致を一括して仮定する欄はない。`input_sound` が型付き材料から判定の接続を証明するが、JSON の全ての型注釈の範囲や組み込みの動作までを証明する定理ではない。これらの境界は旧モデルと同じである。

## N16 の呼び出し・脱糖・交換の規則の照合

| 対象 | 型付き表層と脱糖の規則 | 独立した検査と交換の保持 |
|---|---|---|
| 関数型・ラムダ・高階の適合 | `Ty.Le` は同じ宣言順の名前を保ち、型と項の置換は名前を変えない | `Ty.fn.names`・表層とコアの `lam.names` を必須とする。内側の関数型も検査し、正規化で名前を削らない |
| 通常呼び出し | `CallOk` は名前の長さ・一意性、ラベルと位置の長さ、全宣言位置の置換、位置ごとの名前一致を要求する。位置指定の例外は一引数だけ | `callOk_spec` は検査と規則の同値。`labels`・`positions`・式をソース順で受け取り、Rust が渡す対応を再検査する |
| 評価順 | `callComp` は一般の callee を先に束縛し、明示引数をソース順に `letChain` で束縛する。最後に値の参照だけを宣言順へ移す | 独立した期待コアと比較する。名前・位置・式のソース順を変更した入力が不一致になる。性質 1 自体は型保存であり、IO 順全体の定理とはしない |
| パイプ | 左辺を一度束縛し、位置 0 を占める。`CallOk` の置換条件で明示の位置 0 の重複を排除する。括弧・穴付き右辺は一引数適用 | 挿入は `pipe` の構成子自体で表す。右辺の call のラベルと位置には明示引数だけを書く |
| 穴 | 元の契約名の注釈を callee と照合する。`holeNames` と `holeTypes` は穴の出現順。callee と固定式は生成するラムダの本体で評価する | 各穴・固定式に必須の `label`・`position` を持つ。名前なしでも `null` を明示する。元の契約を創作しない |
| 構成子とレコード | 直接構築とパターンは従来の位置。直接の穴は位置構成子だけで argN、関数値は位置構成子の argN またはレコードの宣言順の欄名 | `conFields` を型表の `DataCtorEntry.fields` から作る。取得関数の宣言との一致も調べる。レコードの直接の穴は R38 の検査で拒否する |
| 操作・ハンドラ | 操作の名前は宣言に保持し、通常の呼び出し規則を使う。ハンドラの局所束縛は de Bruijn の番号であり契約名の綴りに固定しない | 利用者の `OpEntry` と組み込みの `PrimOpEntry` に名前を保持する。組み込み型表の契約と操作の一覧も比較する |
| メソッド・辞書 | メソッド値は内部辞書の位置を除いた利用者の契約を返す。実装は射影前の `MethodInput` で名前全体を比較し、射影した本体の型付けを導く | メソッド宣言は辞書込み、実装の Header は利用者の引数だけ。R43 に従い、実装自身の辞書数から内部名を作って実名の前に付ける |
| 組み込み・標準ライブラリ | 外側は既存宣言の名前、内側のコールバックは Q10、演算子は left・right または value を使う | 独立入力の代表例と `StoreShape` を照合した。全 Rust 宣言からの型表の出力と全件の照合は後続の接続作業で行う |

六つの対応する入口は次のとおりである。新旧を入力ごとに選ぶ接続は N21b 以降の作業であり、N16 の新入力は手で記述した独立入力である。

| 旧入口 | 新入口 | 新入力と検査する契約 |
|---|---|---|
| `desugarDiff` | `namedDesugarDiff` | corpus 8。名前付きの表層からのコアと、独立した期待コアを比較 |
| `builtinCheck` | `namedBuiltinCheck` | corpus 8 と組み込み型表 2。宣言・参照・操作と型表の整合 |
| `coverageDiff` | `namedCoverageDiff` | 網羅性 2。`kind: function` の names・params・ret・eff を含む生成入力 |
| `coverageProgramDiff` | `namedCoverageProgramDiff` | 網羅性 2 と型表 2。corpus と同じ型の形式を使うプログラム内の照合・束縛 |
| `surfaceCheck` | `namedSurfaceCheck` | corpus 8・型表 2・標準ライブラリ型表 2。選んだ入力または定義を検査 |
| `surfaceCheckAll` | `namedSurfaceCheckAll` | 同じ三形式。全定義と実装を検査し、既存の分類と補正の件数も照合 |

名前の欠落と不正、偽ラベル、逆・重複の位置はそれぞれの入口で拒否する。網羅性の関数型の長さ・一意性の不正を、既存の対象外へ分類しない。正規化はエフェクト原子の順序と基本型の別名だけを揃え、契約名・ラベル・位置・式・辞書の内部名を保持する。欄と引数の完全な一覧は [独立入力の説明](../../formal/tests/named-exchange/README.md) に記す。

対象外は design.md「対象の判定」と既存の境界を維持する。字句・解析・名前解決・型推論・移行の診断、外部宣言と WIT の接続、コード生成・VM・GC・OS の権限制御は、これらの型付きモデルの証明には含まれない。型付きの関数・通常呼び出し・穴・パイプ・操作・メソッドまでを対象外に広げない。N34a で正式モデルと 01-12・07-04 を同時に切り替えるまでは、現在の設計書へ新規則を写さない。


## 通常の名前付き呼び出しの一般入力との接続

N21b では、一般の解析が作る Arg::Named と、型検査の CallPlan を実行と corpus 8 の両方へ渡す。ソース順のラベル・式と source_to_param の位置を保ち、対応表を連番で作り直さない。引数内の return・try・実行時の停止は、後の引数を評価しない。同じ入力を CLI の二方式と参照インタプリタで比較する。

プログラム単位の振り分けは AST に名前付きの引数があるかで決める。新しい入力には依存する関数・ラムダ・組み込み表の実名も含め、Legacy の型を新形式へ読み替えない。旧入力は corpus 7・型表 1・網羅性 1 に残す。名前付きの成功入力を対象外へ回さず、同じ入力が両版に現れないことも検査する。

[新旧の manifest](n21b/exchange-manifest.json) に、旧件数と追加した 4 入力の識別子・定義数・網羅性の件数を記す。新しい 4 入力・15 定義は callee と逆順の引数、局所の関数値、return・try・ゼロ除算による中止、末尾再帰を含む。関数型とラムダの契約名は実際の処理系から出す。型表 2 の組み込み操作の names も OpDef と Scheme の一致を確かめて出す。対応する追加モデルの定義・型付け・主定理は変更しない。

check-formal.sh は、既存の全件の旧比較と、N19〜N21a の独立入力・静的な穴と挿入の検査を維持する。追加入力の単件・全件の表層検査、脱糖・型表・プログラム中の網羅性を Named の入口へ渡す。網羅性の独立入力は引き続き namedCoverageDiff へ渡す。旧の単件の入口 surfaceCheck も通常の位置指定の入力で検査する。未確定契約は N22、一般の名前付きの穴とパイプは N23、利用者の操作・ハンドラ・メソッドの全経路は N24 へ申し送る。

## 名前付きの穴・パイプ・構成子値の一般入力との接続

N23 は CallPlan の位置 0 の挿入、ソース順の穴名と生成する関数型を、本番の型検査・脱糖から新形式へ渡す。元の契約が未確定の間は生成する契約も連動して保留し、後の制約で確定してから名前を取り出す。穴から元の宣言順を推測しない。固定引数と callee の評価は生成するラムダ内に置き、return・try・resume の境界を維持する。

[新旧の manifest](n23/exchange-manifest.json) は、前作業の 5 入力に、部分適用とパイプの 9 定義、レコード構成子値と取り出す関数の 4 定義を加える。脱糖では通常の定義と accessor の計 32 定義を比較し、表層検査では表層を持つ 30 定義を検査する。位置構成子の argN、レコードの宣言順の欄名、ソース順の穴名と必須の conValue.names を保持する。レコードの取り出す関数の二定義は、既存の accessor の規則とその型表で比較する。旧入力の分類と出力は維持し、新しい入力を対象外へ回さない。

Arg::Named がなくても、名前付きの型注釈から Named の部分適用を作った位置構成子の入力は新形式へ渡す。別の最小入力の一定義で、直接の `Pair.Pair(1, _)` が arg2 を保持することを本番の出力と独立した入口で比較する。前作業までの静的な穴・挿入の三定義と、不正なラベル・位置・元の穴契約・挿入を拒否する検査はそのまま残す。Lean の規則・定理・証明は変更しない。

## 操作・メソッド・辞書の一般入力との接続

N24 は利用者の操作の宣言名、メソッド値と辞書付き関数値の names、実装自身の利用者の名前を corpus 8 へ出す。メソッド宣言とコアのヘッダでは、辞書の個数から作る内部名 %dict1 以降を利用者の名前の前に付ける。実装の表層のヘッダには利用者の名前だけを保持し、Named の独立した入口が宣言の並びと比較する。ハンドラの局所名は既存の変数番号へ写し、操作の契約名に読み替えない。

[新旧の manifest](n24/exchange-manifest.json) は既存の七入力の件数を保ち、操作の二定義、辞書・実装を含む八定義を加える。脱糖は accessor を含む九入力・42 定義を比較する。表層は通常の 36 定義と二実装を検査し、実装のメソッドと上位辞書の単位を重ねて数えない。プログラム内の網羅性の六項目と、独立した網羅性二件も新形式で検査する。実装の実名、辞書の内部名、操作の宣言名だけを変えた三つの不正入力は、それぞれ契約名の不一致として拒否する。

外部の宣言・WIT の照合とコード生成は既存の対象外の境界を維持する。Rust の実行検査では、WIT と異なる Benitoite の宣言名から位置へ対応付けた直接呼び出し・関数値・部分適用・パイプを確認する。VM に名前の検索や引数の辞書は追加しない。Lean の規則・定理・証明は変更しない。

## 全経路と六入口の件数の照合

N25 は [新旧の manifest](n25/exchange-manifest.json) と [入力ごとの対応表](n25/routing-manifest.json) で、旧新の和集合の全 1,724 入力を照合する。旧形式は golden の対象内 337 入力・生成 1,000 入力・除外 378 入力、新形式は移行済みの九入力である。入力の識別子・版・除外理由・定義の対象内と対象外の分類・網羅性の件数を保持し、現在の testdata の列挙と生成 seed の全件とも照合する。型表・標準宣言表・網羅性の識別子は、それぞれの版の成功入力と一致しなければならない。N19〜N23 の最小・静的な五入力は一般の九入力と分け、既存の独立した入口で検査する。

check-formal.sh は旧入口の全件の報告が揃ってから、版別の六入口の照合を行う。旧脱糖は golden 910 定義・生成 72,218 定義、旧表層は 51,036 成功・対象外 19 件・Q11 一件を維持する。表層の対象外と Q11 は入力・定義・理由も維持する。独立した旧網羅性は 10,020 件、旧プログラム内の網羅性は 22,430 件である。新形式の九入力は脱糖 42 定義、表層 36 定義と二実装、プログラム内の網羅性六項目であり、独立した新網羅性二件も比較する。単件の surfaceCheck と namedSurfaceCheck、組み込みの型表の検査も省かない。

静的な穴・挿入の六つの改ざん検査と操作・実装名の三つの改ざん検査を維持し、一般の named_partials の実出力にも六つを追加する。穴のラベル・位置・元の契約名とパイプのラベル・位置の不正は表層の検査が契約の誤りとして拒否する。穴のソース順の変更は、正規化後も契約名と順を保ち、元のコアとの不一致になる。モデルの定義・定理・証明の変更は不要であり、正式モデルと 01-12・07-04 の切り替えは N34a に残す。

## 全入力の新形式への統一と正式化の準備

N34 は一般入力 1,726 件を全件 corpus 8 に統一し、成功入力の型表とプログラム内の網羅性を版 2 に揃える。N33 の旧形式の成功 19 件と除外 380 件も新形式へ移す。入力識別子・除外理由・対象外理由・定義数・網羅性の件数は N33 の基準を保持する。一般入力の定義は合計 73,733 件、表層の検査単位は 51,656 件、プログラム内の網羅性は 22,438 件である。

独立した網羅性の全 10,020 件と、関数型の名前を検査する二件も版 2 で比較する。幅付きの Rust の三入力・30 定義は、出力先を width-smoke/ に分け、一般入力の全件の出力に上書きされないようにする。既存の境界値・ビット・件数の assertion と、静的な入力と一般入力の破損の拒否理由は保持する。

正式モデルと規則の写しは、この準備の取り込みだけでは切り替えない。旧六入口には独立した照合を含む一関数と網羅性の一件を渡し、幅付きの旧形式の手書きの検査も維持する。全件の manifest と切り替え patch・機械的な移動のハッシュ・定理の言明の対応・削除対象は [N34 の成果物](n34/README.md) に記す。正式モデルを切り替える N34a では、これらの独立した旧入力の登録を外し、同じ全件を正式な六入口へ渡す。
