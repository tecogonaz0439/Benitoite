### 契約名を持つ関数と呼び出し

【決定】段階 B 以降の正式モデル `Benitoite.Release`・`Surface`・`Exchange` は、次の名前付きの規則を使う。本節は、前節までの関数型・関数値・宣言・呼び出しの記述を、契約名を保持する形へ置き換える。段階 A の `Benitoite.Core` はそのまま保持する。

#### 契約名と型付け

関数型を `function(n1: A1, …, nk: Ak) -> B uses ε`、コアの型を `Ty.fn names params ret eff` とする。ラムダ `Val.lam names params body` と、関数・操作・メソッド・組み込みの宣言も、宣言順の名前 `names : List String` を保持する。`NamesWF names params := names.length = params.length ∧ names.Nodup` である。ゼロ引数では空の並び、一引数でも一つの名前を保持する。契約名は局所変数の de Bruijn の番号と独立であり、局所変数の付け替えや型の置換で変更しない。直接の構成子の呼び出しとパターンは、引き続き位置指定とする。

型の適合 `Ty.Le a a'` は、型が等しいか、同じ `names`・`params`・`ret` を持つ関数型の外側のエフェクトだけが包含されることである。名前の綴りと順を比較し、名前を消した型を経由しない。

| 規則・定義 | 名前に関する前提と結論 |
|---|---|
| `Ty.WF`・`Ty.VarsIn` | 関数型ごとに `NamesWF names params`。入れ子の型にも再帰する |
| `V_Lam` | `NamesWF names ps`。ラムダと結果の関数型の名前は同じ |
| `V_Fun` | `NamesWF d.names d.params`（整形式から従う）。結果の `fnTy` に `d.names` を保持する |
| `V_Prim` | `NamesWF s.names s.params`（整形式から従う）。結果の `fnTy` に `s.names` を保持する |
| `V_Op` | `NamesWF od.names od.params`（整形式から従う）。結果の `fnTy` に `od.names` を保持する |
| `C_App` | 呼ぶ値の型は `.fn names ps r ε`。値の引数は既に宣言順に並んでいる |
| `C_Meth` | `NamesWF ms.names ms.params`（整形式から従う）。辞書と値の引数の既存の型付けを保持する |
| `HasTypeClauses.cons` | `NamesWF sg.names sg.params`（整形式から従う）。節の局所束縛名は操作の契約名と区別する |
| `Def.WellTyped` | 宣言の `NamesWF d.names d.params` と、既存の本体の型付け |
| `ImplDecl.WellTyped` | 宣言側の `NamesWF ms.names ms.params` と、既存のメソッド・上位辞書の本体の型付け |

`V_Fun`・`V_Prim`・`V_Op`・`C_Meth`・`HasTypeClauses.cons` の前提は、順に `Def.Scoped`、`Builtins.Assumptions.sig_scoped`、`OpDecl.Scoped`、`ClassDecl.Scoped` と `MethSig.Scoped`、`opSig_scoped` から得られる。これらを独立した外部仮定として扱わない。型付けされた項に含まれるラムダ自身の名前の整形式は、`HasTypeV.lambdaNamesWF`・`HasTypeC.lambdaNamesWF` から従う。`effect_soundness_noLamNames` は、ラムダ名の条件だけを除いた変数の範囲条件から、同じエフェクト健全性を示す。

#### 表層の契約と値の配置

通常呼び出し `Expr.call f labels positions args` は、引数のラベル・宣言位置・式をソース順に保持する。`CallOk names ps inserted labels positions` は、名前の整形式、位置とラベルの一致、位置の重複の不在と宣言位置の網羅を要求する。位置指定だけの一引数ではラベルを `none` とし、宣言の位置 0 に対応させる。名前付きのラベルは対応する位置の契約名と一致しなければならない。`sourceTypes ps positions` は、各ソース位置に対応する宣言位置の型を返す。

`E_Call` は、呼ぶ式を `.fn names ps a εcall` で、引数列を `sourceTypes ps positions` で検査し、`CallOk names ps false labels positions` を求める。結果は a、エフェクトは呼ぶ式・引数列・呼び出しの和である。`E_PipeCall` は左辺を先に検査し、宣言位置 0 に挿入した型を含む契約に対して `CallOk ... true ...` を求める。右辺が呼び出しの構文でないパイプは `E_PipeApply` とし、一引数の関数値に適用する。

`E_PartialCall` は元の契約名と `HoleArgs` のソース順の位置・ラベルを保持する。穴のある呼び出し全体をラムダとして検査し、結果の関数型の名前は `args.holeNames names`、型は `args.holeTypes` とする。穴の名前はソース順であり、宣言順へ並べ替えない。直接の代数的データ構成子の穴には `positionalNames`（`arg1` 以降）を使う。レコードの構成子値はフィールド名を保持し、名前付きの関数値として検査する。

脱糖の `callComp` は、必要な場合に呼ぶ式を先に評価し、明示引数をソース順に一度ずつ束縛する。呼び出しの時点で、保存した値の参照だけを `recordFields positions` により宣言順へ配置する。パイプの左辺は最初に評価して位置 0 に挿入し、再び束縛しない。穴を含む呼び出しでは、呼ぶ式と穴以外の式の計算をラムダの本体に置き、そのラムダを呼んだときに評価する。

`CallOk.recordFields_source` は、ソース位置 k の宣言位置が i なら、配置後の第 i 成分がそのソース位置の保存値の参照であることを示す。挿入引数も含む。この定理は値の配置の等式である。呼ぶ式の先行評価・引数のソース順の束縛・穴の遅れた評価は、脱糖の定義と独立した期待コアの具体例で確認する。性質 1 は型の保存であり、IO を含む評価順全体の意味保存の証明とはしない。

#### 範囲条件と実装の名前の検査

表層の `Program.WellFormed` は、次の名前の範囲条件も持つ。

| 箇所 | 条件と型付けとの関係 |
|---|---|
| 型注釈の `Ty.VarsIn`・`Ty.VarsInList` | 入れ子の関数型の `NamesWF`。使われないパラメータも含む全注釈の整形式は、本体の型付けだけから従わない |
| `Expr.Scoped` の `lam`・`funDicts`・`methName`・`conValue` | その関数値自身の `NamesWF names ps`。対応する型付けは同じ条件か、それを導く等式・宣言の整形式を要求する |
| `Def.Scoped` の利用者名 | `NamesWF d.names d.params`。`Def.WellTyped` も要求する |
| `Def.Scoped` の `coreNames` | `NamesWF d.coreNames (d.dictTys ++ d.params)`。`d.coreNames = internalNames d.dictParams.length ++ d.names` であり、利用者名だけの整形式からは従わない |
| `Program.WellFormed` の `conFields` | 全宣言のフィールド名の `NamesWF names cd.args`、対応する構成子の存在、同じ型の構成子の一意性。未使用の宣言にも要求する |
| 操作・クラス・組み込みの宣言 | 宣言自身と型注釈内部の名前の整形式。未参照の宣言にも要求する |

`%dict1` 以降の内部名と利用者名の非衝突を支える字句規則は、型付きモデルの対象外である。型保存は、連結後の `coreNames` の整形式を範囲条件から受け取る。`E_Fun`・`E_FunDicts` もこの条件を局所的な前提に持つ。未使用の `conFields` と連結後の名前の条件を、関数本体の型付けだけから導いたとは扱わない。

コアの実装メソッドと `Surface.ImplDecl` は位置による本体を持つため、実装側の実名と宣言名の一致は `ImplDecl.WellTyped` の射影だけからは得られない。実行可能な表層検査の `MethodInput.names` は射影前の実装側の名前を持ち、`checkImpl_contracts`・`checkProgram_contracts` は検査成功から実名の一致と整形式を保証する。実装側の名前へ宣言側の名前を転記して検査を済ませない。メソッド自身の制約の辞書には内部名を前置し、実装自身の辞書の個数と混同しない。

