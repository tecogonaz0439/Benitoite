# P2 定義・定理と六入口の対応

## 提案の範囲

これは design.md「形式化と受け渡し」「Lean の定義と証明」と R8〜R10 を、P2 時点の定義・言明へ対応付けた差分案である。P2 では Lean のコード・証明を変更しておらず、以下の新しい定義名・補題名は候補としていた。D1 で追加した実際の宣言は「D1 で追加した定義と言明」に記す。P2 時点の宣言と行番号は [uses.json](uses.json) の formal_coverage/formal_surface に残す。古い study/formal.md の Other 流用案は採らず、R9 の Future/future を使う。

Lean のパスは `formal/` からの相対であり、`Release/`・`Surface/`・`Exchange/` はその下の `Benitoite/` を省略する。Rust の `tests/` は `crates/benitoite/tests/` を指す。A の字句・return 直後の物理改行、or の境界、属性の綴りと適用先の解析は形式化の外側である。A3/A4・D6c/B13 で 07-04 の対応を更新する。D のソース照合の受理条件、B の die の型・辞書・脱糖は内側であり、Rust の意味変更より先に Lean と 01-12 の写しを揃える。

## D の定義と規則の差分案

| 現在の定義・規則 | 加える情報と変更案 | 担当 |
|---|---|---|
| `Benitoite/Release/Coverage.lean:166` Shape、`:22` CoverageWitness | 両方へ `future (d : DataName)`。Shape.fields は空、specialize は wild/var のみ成功。other の既存の意味は維持 | D1 |
| `Coverage.lean:193` shapes、`:299` usefulFuel、`:364` fuelFor、overlapsFuel/useful/overlaps/coveringAlternatives/checkMatch/irrefutable | `CoverageView := DataName → Bool` を一つの探索へ明示する。閉じた view は全て false。data d の既知の shapes を残し、view d のときだけ future d を追加。再帰・予算・反例へ同じ view を渡す | D1→D2a |
| `Release/CoverageShow.lean:7` CoverageDisplay | 現在の ConName の表示表を保持。DataName ごとの typeName/isRecord の表を追加し、future d を constructor/shape の反例へ表示する | D1 |
| `Surface/Syntax.lean:492` Declarations、`:503` patternProgram | 本体に有効な view を追加（既定は閉じた view）。patternProgram は cons/ops/effects/classes 等だけを射影し view をコアへ渡さない | D2b |
| `Surface/CheckPatterns.lean:217` exhaustive、matchExhaustive/bindingExhaustive | source の match/bind は D の view を使う。受理した有用性の判定から現在の値についての Exhaustive を得る | D2b |
| 同ファイルの tryResultExhaustive/tryOptionExhaustive/recordUpdateExhaustive と getter の生成 | 合成した内部の照合は明示的な閉じた view を使う。R2 の外部 record の source pattern と生成 getter/update を混同しない | D2b |
| `Surface/Typing.lean` の match/bind と CheckPredicates/Check | ソース照合の受理条件を追加。現在の Exhaustive を削る代わりに、view 付き条件から導く。構成子が現在の値を型付けする規則は維持 | D2b |
| `Surface/Syntax.lean:527` Program、`:551` Program.declarations | 関数・実装メソッドそれぞれの有効な view を持たせ、declarationsFor で選ぶ。`Surface/Lemmas/Program.lean`・Typing の Def/ImplDecl.WellTyped・checker の各本体入口で同じ view を使う | D2c |
| Exchange/Syntax・Convert・CheckInput、CoverageDiff・CoverageProgramDiff | 属性の宣言情報と本体に有効な view を別の欄へ出す。DataName の表示表を網羅性 3 の必須欄にする | D3、D6b |

view 付き受理条件の候補を、次のように具体化できる（擬似定義であり、未検証の Lean コードではない）。

```text
ViewExhaustive(D, view, a, ps) :=
  ある ctors が存在し、CtorsComplete(D.patternProgram, ctors) かつ
  useful(D.patternProgram, ctors, view, [a], singletonRows(ps), [wild]) = none

source match: HasType(operand, a)・HasArms(arms)・
              ViewExhaustive(D, D.view, a, unguardedPatterns(arms))
source bind:  PatTy(pattern, a, binders)・ViewExhaustive(D, D.view, a, [pattern])
internal try/getter/update: 従来の Exhaustive、checker は closedView で判定
```

ctors の存在は信頼する外部仮定ではなく、checker が検査した宣言表から証拠を構成する案である。D2b で実際の型付け規則と定義名をレビューして確定する。重要な導出は `ViewExhaustive D view a ps → Exhaustive D.patternProgram a ps` であり、ソースの追加条件をコアの型保存へ渡せることを示す。将来の形には実在の値を割り当てず、既知の各値に対応する元の shape が追加後の一覧にも残る補題を先に示す。未来のすべての拡張に対する実行結果の同一性までは主張しない。

## D の定理の対応

### D1 で追加した定義と言明

D1 は既存の呼び出しを切り替えず、次の宣言を先行追加した。D2a で Release の判定へ接続した。Surface への接続は D2b で追加した。Program の本体ごとの指定は D2c、交換形式は D3 で接続した。定義・言明のレビューへ渡す範囲と自己確認は [D1 の記録](../d1/results.md) に記す。

| 宣言 | 言明・用途 |
|---|---|
| `CoverageView`、`closedView` | データ名ごとの有効な指定。閉じた view は全て false |
| `Coverage.shapesWithView` | 従来の shapes の末尾に、指定された data の `future d` を追加 |
| `Coverage.shapesWithView_closed` | 任意の型・列・宣言表について、閉じた view の列挙が従来の列挙と等しい |
| `Coverage.mem_shapesWithView` | 任意の view で元の shapes の全要素が残る。既知の構成子とその欄も保持 |
| `Coverage.specialize_future`、`specialize_future_iff` | 将来の形は欄を持たず、変数と `_` だけが覆う |
| `Coverage.shapesWithView_cover` | 既存の shapes_cover と同じ前提から、任意の view の列挙に属する形・現在の値の Represents・欄の InhabitsAll・問いの特殊化と照合の証拠が得られる |
| `CoverageTypeDisplay`、`CoverageWitness.showWithTypes`、`showWitnessesWithTypes` | DataName ごとの型名と record の印を使って、入れ子の future も表示する。旧 show/showWitnesses は空の型表示表を渡す |

`CtorsComplete`、`Inhabits`、`Exhaustive`、既存の補題 U・健全性定理・実行時の系の言明は変更していない。六入口の交換形式は 8/2/2 のままである。

### D2a で接続した定義と言明

Release の判定と証明だけに view を接続した。既存の入口はすべて `closedView` を渡す互換ラッパーとして保持し、Surface と Exchange は引き続き旧入口を使う。実装前の自己確認とレビューへの申し送りは [D2a の記録](../d2a/results.md) と R27 に記す。

| 宣言 | 言明・用途 |
|---|---|
| `Coverage.usefulFuelWithView`、`usefulReportWithView`、`usefulWithView` | 入力の燃料を保ち、全再帰で同じ view を使う。形の列挙は `shapesWithView` |
| `Coverage.overlapsFuelWithView`、`overlapsWithView`、`coveringAlternativesWithView` | 覆う単独行・接頭辞の選択と、重なりの再帰でも同じ view を使う |
| `checkMatchWithView`、`irrefutableWithView` | 反例・到達不能位置・覆う分岐・燃料切れ、および束縛の左辺を判定 |
| `Coverage.usefulFuelWithView_none_sound` | 任意の view・燃料で、現在の型の値の並びが問いに照合し、判定が none なら元の行にも照合する。CtorsComplete を維持 |
| `usefulWithView_none_sound`、`usefulWithView_singleton_none_sound` | view が閉じているという前提を加えず、元の補題 U と単列の結論を導く |
| `checkMatchWithView_exhaustive_sound`、`irrefutableWithView_sound` | 任意の view で判定が成功すれば、現在の値についての元の Exhaustive が成り立つ |
| `checkMatchWithView_unreachable_lookup`、`checkMatchWithView_unreachable_sound` | 報告された位置の選択肢と同じ view の none を取り出し、現在の値の AlternativeSelected を否定 |
| `checkMatchWithView_unreachable_runtime`、`checkMatchWithView_unreachable_runtime_of_C_Match` | 元の SlotsOk・C_Match の前提を維持し、RuntimeSelected を否定 |
| 各 `*WithView_closed` | 閉じた互換入口と結果全体が等しい。形の列挙の従来の手順との一致は D1 の shapesWithView_closed |

元の健全性定理の型と結論を保ち、view 付き定理の閉じた系として導く。`CtorsComplete`・`Inhabits`・`Exhaustive`・`AlternativeSelected`・`RuntimeSelected` は変更していない。型保存・checker・六入口の版や対象範囲にも変更はない。

### D2b で接続した定義と言明

`Declarations.view` の既定は `closedView` とし、Program と Exchange の既存の構築を保った。自己確認と所定のレビューへの申し送りは [D2b の記録](../d2b/results.md) と R28 に記す。

| 宣言 | 言明・用途 |
|---|---|
| `ViewExhaustive D view a ps` | 完全な構成子の一覧が存在し、同じ view の単列の有用性が none であること。外部の答えを新しい仮定にしない |
| `ViewExhaustive.exhaustive` | 任意の view の追加条件から現在の値についての `Exhaustive D.patternProgram a ps` を導く |
| `HasType.E_Match`・`HasBlock.B_LastPat/B_BindPat` | ソースの match と bind/shadow に D.view の `ViewExhaustive` を要求。型保存では `.exhaustive` を通して元のコアへ接続 |
| `exhaustiveWithView_view`・`exhaustive_view`・`matchExhaustive_view`・`bindingExhaustive_view` | 宣言表の完全性と実際の判定の成功から追加条件の証拠を構成し、checker の健全性へ渡す |
| 既存の `exhaustive_sound`・`matchExhaustive_sound`・`bindingExhaustive_sound` | 元の現在の値についての結論を維持 |
| `tryResultExhaustive`・`tryOptionExhaustive`・`recordUpdateExhaustive` | D.view を使わず、明示的な closedView で内部の合成照合を判定。getter は現在のコアを直接生成し、単一構成子の Exhaustive を維持 |
| `Declarations.withView_*` | patternProgram と funs/cons/conFields/ops/effects/classes/impls の射影が view に依存しない |
| `Input.Sound.withView`・`constructors_withView_sound` | 本体の指定を替えても原子集合と構成子の完全性を保つ。後者は有限の材料からの input_sound に接続 |

Program の本体ごとの宣言表への切り替えは D2c、六入口への指定の受け渡しは D3 に残す。六入口は閉じた既定で 8/2/2 のままであり、現在の値の定義・定理の結論と Rust の実装は変更していない。

### D2c で接続した定義と言明

`Program.functionViews`・`methodViews` と `Materials` の同じ欄で、関数・実装メソッドごとの指定を保持する。既定は全て `closedView` である。`Program.declarationsFor view` は宣言表の view だけを選び、`declarationsFor_*` は全射影と patternProgram の一致を示す。`declarations` は閉じた互換入口として残す。

`Program.WellTyped` と `CheckedUnder` は同じ本体の指定で型付けする。全体の checker は名前と本体を同じ探索から渡し、`checkNamed_key_sound` から指定付きの検査成功を取り出す。メソッドの型付けと検査にはメソッド名ごとの指定を渡す。`Input.Sound.withView` により、新しい健全性の仮定を加えずに各本体の checker の型付けを導く。`checkProgram_sound`・`checkProgram_empty` と、実名一致を含む各 contracts 定理の前提・結論を保つ。

型保存と型の範囲の補題は、`p.declarationsFor view` の型付けに対して一般化した。`desugar_wellTyped` は関数・実装メソッドそれぞれの指定でこの補題を使う。`desugar_typed` と `surface_effect_soundness` の前提・結論は変わらない。将来の形を現在の値とする仮定も加えていない。

D2a〜D2c の接続は完了し、独立例で一つのプログラム内の作者・外部の関数とメソッドを確認した。実装・参照一覧・検査・レビューへの申し送りは [D2c の記録](../d2c/results.md) に記す。D3 の交換形式と Rust の実装は未接続であり、六入口は引き続き閉じた既定の 8/2/2 を使う。

### D3 で接続した交換契約

`Exchange/Syntax` に型の宣言の情報 `DataTypeInfo` と `SurfaceDef.coverageView` を加えた。`Exchange/Version` は corpus 9・型表 3・網羅性 3 の必須欄を補完せずに読み、未知・閉じた型・重複を含む view を拒否する。閉じた 8/2/2 は、新版の欄を持たない場合だけ互換入力として読み、属性なしの閉じた既定を補う。型表を受け取る入口では corpus の全宣言の情報との一致も検査する。

`Convert.operationProgram` と `CheckInput.prepare` は関数・実装メソッドごとの指定を Program と Materials に渡す。上位辞書の合成単位を関数名として扱わない。Coverage の二入口は網羅性・束縛・到達不能・反例・燃料の監査へ同じ view を渡す。`surfaceCheck` の個別の定義と `surfaceCheckAll` の関数・メソッドも同じ本体の指定で検査する。

D3 では定理・証明・型付け規則の変更はない。`CtorsComplete`・現在の値についての健全性・型保存の前提と結論を維持する。現在の Rust は閉じた 8/2/2 を出力し、新版は独立入力から検査する。実際の欄配置と独立検査は R30 と [D3 の記録](../d3/results.md) に記す。

### 後続の接続と保持する結論

| 現在の言明 | 差分案と保持する結論 |
|---|---|
| `Coverage.lean:17` CtorsComplete | `P.cons c = some cd → c ∈ ctors cd.data` を変更しない。future を cons の実在する構成子として要求しない |
| `:1115` shapes_cover | view を追加しても、Inhabits P ty v を満たす現在の値は元の shape に対応する。既知の shape の包含補題を使う |
| `:1182,1375,1384` usefulFuel_none_sound/useful_none_sound/useful_singleton_none_sound | 判定の引数へ view を追加。CtorsComplete と判定の成功から、現在の値が既存の行に照合するという結論を保つ。view が閉じているという前提を足さない |
| `:1397,1410` checkMatch_exhaustive_sound/irrefutable_sound | 任意の view で成功した判定から `Exhaustive P a ps`。現在の Inhabits/Exhaustive の定義を弱めない |
| `:1457,1482` checkMatch_unreachable_lookup/sound、`Release/Lemmas/CoverageRuntime.lean:197,207` の runtime 系 | 同じ view の選ばれない選択肢を現在の値の非選択へ接続。型付き runtime の前提・結論を保つ。future のために必要な包括分岐を選ばれないとしない |
| `Surface/CheckPatterns.lean` の exhaustive_sound と各 *_sound | source は view 付き成功→ViewExhaustive→既存 Exhaustive。合成した照合は closedView で同じ結論。checker の宣言表の完全性を省略しない |
| `Surface/Lemmas/Program.lean` の宣言と脱糖の対応 | declarationsFor の funs/cons/conFields/ops/effects/classes/impls と patternProgram は元の宣言表と一致する補題を用意。型・操作・クラスの射影は view に依存しない |
| `Surface/Theorems.lean:18,30` desugar_typed/surface_effect_soundness | WellTyped の source 条件を反映しつつ、前者の WellFormed∧WellTyped∧EffectsOk、後者の純粋な main の効果健全性を保持。別途の「Rust が網羅と判定した」仮定は加えない |
| `Surface/CheckSound.lean:9` checkExpr_sound、`CheckProgramSound.lean:153,195` checkProgram_sound/contracts | view を持つ本体宣言表で同じ型付けと契約を導く。全体に一つの bool を代用しない |

### D4 の自己確認と公理依存

D1〜D3 の実際の前提・結論・対象範囲を [D4 の対応表](../d4/contracts.md) にまとめた。旧入口と最終定理・checker の既存の宣言 28 件のうち、27 件のシグネチャは空白の正規化後に一致し、`checkImpl_sound` だけが任意の本体ごとの `views` を明示する形へ変わった。表層の `WellTyped`・`CheckedUnder` の意味にはソースの `ViewExhaustive` が加わっており、旧表層の型付けとの同値性を主張しない。コアの型保存・エフェクトの健全性の結論、現在の値と実行の規則は保つ。

変更した 35 モジュールの 7,003 宣言を調べ、公理依存は従来の `propext`・`Quot.sound`・`Classical.choice` の範囲だけだった。交換の定義と六入口も含む。モジュール別の実測・再現手順と信頼範囲は対応表に記す。この集計は D4 時点の自己確認である。G2 の所定レビューと設計者の合意（2026-10-16）を受け、Z2 で指摘を修正した。追加した定理と交換契約は上の Z2 の節に記す。修正後の確認をオーケストレータへ渡す。

## Z2 の拡張健全性と交換の補正

`Release/CoverageExtension.lean` の `ConstructorExtension P P' view` は、既存の構成子の宣言を変えず、`P.cons c = none` である新しい構成子を view が真の型にだけ追加する関係である。構成子以外の表は `Inhabits` が参照しないため制約しない。

`usefulWithView_extension_exhaustive` は、`CtorsComplete P ctors`、`CtorsComplete P' ctors'`、この拡張関係、および `usefulWithView P ctors view [A] (ps.map (fun p => [p])) [wild] = none` から `Exhaustive P' A ps` を導く。入れ子とリストを含み、将来の実行結果の一致は主張しない。`Represents.future` は証明内で追加後の値を将来の形に対応させる関係であり、現在の `Val` と `Inhabits` には新しい場合を足さない。

corpus 9 の `Input.dataTypes` は、型の識別名ごとの `name`・`typeName`・`isRecord`・`extensible`・`package`・`builtin` を必須とし、属性しか使われない宣言も含む。`package` は解決済みの所属パッケージの識別名である。`builtin` は表示名とは独立した標準型の識別（`"result"`・`"option"`、それ以外は `"ordinary"`）であり、標準の Result・Option に extensible を指定した入力を Lean でも拒否する。型表 3 の `DataEntry` に同じ情報を保持し、型表を使う入口では corpus と全件・順序を含めて一致を確かめる。D6b は同じ宣言の並びから両方を出力する。

record の印は構成子のフィールドの有無と照合する。`SurfaceDef.coverageView` は関数・実装メソッドごとの型の識別名（`DataTypeInfo.name`）の一覧であり、表示名 `typeName` は使わない。

各 `SurfaceDef.package` と `ConstantEntry.package` は本体の宣言側の所属である。網羅性 3 は独立入力の各 case、プログラム単位の各 match/binding に `package` と同じ一覧を持つ。Lean は宣言の extensible が真で所属が本体と異なる型を計算し、受け取った view の集合と完全に一致することを検査する。未知・閉じた型・重複・指定漏れ・作者側の余分な指定を拒否する。関数名、実装名とメソッド名の組に重複した view も拒否する。

原ソースから所属・標準型の識別を解決するのは Rust の責務であり、その解決自体は証明しない。corpus 9 は型引数や定数の本体を含め、入力に現れる data 型がすべて dataTypes にあることを検査する。旧版は形式ごとの既知の欄を辿って閉じた既定を補い、新版の必須欄を補完しない。

定数は `public const` によってパッケージの外から参照できる。ただし、Rust の定数式の形の検査（`typeck/consts.rs` の `bad_shape`）は `match`・`if`・ラムダ等を E0433 で拒否する。

Lean の `E_Const` は定数式の形の制限を形式化せず、使用側の `D.view` で展開した本体を検査する。したがって任意の交換入力では、宣言側の view で検査する Rust と同じ受理結果を保証しない。現在の Rust が書き出す定数にはソース照合がなく、この違いは拡張可能型の網羅性の結果を変えない。corpus 9 の `ConstantEntry.package` は宣言側の所属を保持するが、`E_Const` の指定の切り替えには使わない。

## B の型付き表層と脱糖の差分案

既存 `Surface/Syntax.lean:344,346` の tryResult/tryOption は維持する。裸と明示 return はこれらへ同じように書き出す。新しい場合の候補は tryResultDie/tryOptionDie であり、成功型 T、Result/Option の実際の構成子参照、入力、任意の説明、標準 exit の参照を保持する。Result 側には Show の DictEv と実際の show のメソッド参照を追加する。表示関数だけを無条件に信頼する形にはしない。

型付けの前提の差分案は次のとおりである。

| 要素 | Result の die | Option の die |
|---|---|---|
| 入力 | Γ,R で Result[T,E]、効果 ε | Γ,R で Option[T]、効果 ε |
| 囲む戻り値 R | 任意。既存 tryResult の `R = some Result[U,E]` を新しい場合には要求しない | 任意。`R = some Option[U]` を要求しない |
| 表示 | 既存の辞書検査で E:Show を確認し、show の適用は String、効果は空 | 辞書不要、固定の String |
| 説明 | あれば String、効果は空、R=None、外側の継続を隠した文脈 | 同左 |
| 終了 | 参照先の操作の引数名/型引数/型/効果を既存の宣言表で検査し、`exit[T](1)` が T と Process.Exit を持つ | 同左 |
| 内部の二分岐 | closedView の既存の tryResultExhaustive を使う | closedView の tryOptionExhaustive を使う |
| 式の結論 | 型 T、効果 ε ∪ Process.Exit | 同左 |

説明の R=None は直接の escape を防ぐ型付け文脈であり、内側の lambda は自分の R を設定できる。文字列から直接 return/try を拒否する parser は外側の実装である。exit の操作・Show の辞書の整合性を checker が確認し、任意の E の表示や任意の exit 参照を新しい外部仮定にしない。

`Surface/Desugar.lean:297` 付近に、入力の let 一つと二分岐を追加する。成功側は中身を返し、失敗側は説明の let（あれば）→Show の let（Option は固定原因）→既存 exit の呼び出しとする。原因/説明の計算はコアから消さない。ホストへの報告欄だけは交換するコアの外側である。

| 変更する定義・証明 | 作業と保持する性質 |
|---|---|
| Syntax/Desugar、Exchange/Syntax・Convert の lambdaEffects、SurfaceCheck/Walk | B1/B4。新しい二場合の全走査と説明/辞書を接続 |
| `Surface/Typing.lean:308` 以降、`Lemmas/ReturnTry.lean:25,65` | B2。既存の tryResult_typed/tryOption_typed を残し、新しい二場合の型保存補題を追加。入力の型・純粋な説明/表示・既存 exit から型 T を導く |
| Surface の Scoped*、ShiftClean/SubstClean、Invariants、Extensions*、Lemmas/Typing/Program、WellFormed | B1/B2。本体の入れ子と辞書/説明の置換・範囲条件を揃え、値の添字・型の引数・契約名を落とさない |
| Check/CheckPredicates/CheckSoundControl/CheckInduction/CheckProgramSound、CheckInput | B3/B4。受理の前提を型付けへ導き、構成子・show・exit の参照や純粋性を改変した独立入力を拒否 |
| desugar_typed/surface_effect_soundness/checkProgram_sound/contracts | B2/B3。D と同じ最終の前提・結論を保つ。新しい axiom/sorry/admit/native_decide、結論の対象縮小は認めない |
| `Release/Typing.lean:30,40` の BuiltinResult.exit/BuiltinKind.exit と既存の E-Exit・解放遷移 | 今回の新しい操作・Never は不要。抽象的な exit と解放の既存の性質を使う |

評価回数・成功時の説明/Show の未評価・説明→Show の順序・タスクの取消・報告の採用/一回性は、この型保存の結論には含まれない。B12 の公開の実行境界と、B10a-2 の独立した期待コアで確認する。

## 交換形式と六入口

P2 時点の入口は corpus 8・sidecar 2・網羅性 2 を要求していた。D3 で Lean は corpus 9・型表 3・網羅性 3 と、8/2/2 の閉じた互換入力を読むようになった。現行の Rust の書き出しは 8/2/2 であり、D6b で 9/3/3 へ揃える。B4/B10a-3 は corpus 10・型表 3・網羅性 3 へ揃える。stdlib sidecar も現在 2 であり、新しい必須情報を含める場合は型表とともに 3 へ揃えて検査する。旧版専用の入力と新版の必須欄欠落を混同しない。

| 入口（lakefile.toml の root） | 読むもの／Rust 側の主な生成元 | 変更時に照合する対象 |
|---|---|---|
| desugarDiff（DesugarDiff.Main） | named-programs-corpus.json、`tests/desugar_export/{exchange,named}.rs` | source view と新二場合を残した表層の脱糖と独立の期待コア。裸/return の既存入力も維持 |
| builtinCheck（BuiltinCheck.Main） | 同 corpus と named-programs-builtins.json、`desugar_export/builtins.rs` | show の辞書・メソッド・型引数と標準 exit の操作の型/効果の対応 |
| coverageDiff（CoverageDiff.Main） | named-all-corpus.json、`tests/coverage_export.rs` | view・DataName の表示表・Future と Other を区別した反例、作者/外部、match/bind/unreachable/covering |
| coverageProgramDiff（CoverageProgramDiff.Main） | named-programs-coverage.json と builtins、`desugar_export/{exchange,named}.rs` | プログラムの各本体由来の view と宣言表。属性だけの入力も落とさない |
| surfaceCheck（SurfaceCheck.Main） | corpus・builtins・stdlib と group/name（単一入力）、同 exchange/builtins | 新規の正常入力と、view/辞書/説明/exit/版を壊した入力の拒否 |
| surfaceCheckAll（SurfaceCheck.All） | corpus・builtins・stdlib（全件） | 関数/実装メソッドごとの対象内/対象外、全定義の checker 受理と契約名 |

`scripts/check-formal.sh` は各実行ファイルの build、coverage_export と desugar_export の ignore を含む出力、width/named の独立入力、最終の `tests/desugar_export/check_named.py` を順に実行する。surfaceCheck の単独の破損入力検査も Python 側が呼ぶ。単に五つの集計コマンドの終了状態だけを見る構成にはしない。

P2 時点の `tests/desugar_export/exchange-manifest.json` に固定されていた期待件数は次のとおりである。P2 で六入口を再実行して測定した件数ではない。D1 では R26 の既存の負の入力一件の欠落を補正し、総入力が 1,727、golden の除外が 381 になった。受理された定義・網羅性・表層検査の件数は変わらない。D3/B4 はこの既存の入力集合を残したうえで、新機能の追加分を区別して記録する。

| 入口/集計 | 現行 manifest の期待値 |
|---|---|
| desugarDiff | golden の定義 matched 955、random 72,778（合計 73,733）、両方とも outside/mismatched/excluded 0。プログラム単位は golden matched 346・excluded 380、random matched 1,000・excluded 0 |
| builtinCheck と各単独入力 | 全 1,726 プログラムの対応は routing-manifest と programs の group/name/excluded を照合。named の独立入力 7 件の定義数は 1・2・5・3・1・2・1 |
| coverageDiff | named は 2、named-all は境界 20＋random 10,000＝10,020。mismatched/fuelExhausted 0 |
| coverageProgramDiff | matched 22,438、mismatched/outOfScope/fuelExhausted 0 |
| surfaceCheck | 単独の正常/破損入力は check_named.py と formal/tests が group/name と意図した理由を照合。件数を surfaceCheckAll の matched に代用しない |
| surfaceCheckAll | 全検査 51,656。matched 51,636、outOfScope 19、q11 1、preparationFailure/mismatched/lazyRestriction 0 |

件数・除外理由・破損入力の持ち主は `crates/benitoite/tests/desugar_export/` の manifest と `check_named.py`、`formal/tests/test_{named,width}_exchange.py` である。D3/B4 では新しい独立入力を `tests/` または `formal/tests/` へ追加し、この改造ディレクトリへ検査の依存を作らない。各六入口の旧件数・追加件数・合計、対象外理由別件数、破損入力の拒否件数を実行結果から記録する。既存件数の引き下げ、指定付き型/try die を新しい除外理由へ移すこと、燃料切れを網羅と扱うことは認めない。

P2 は形式化を変更していないため六入口を実行しておらず、新版の件数や証明の成功は未検証である。D1〜D4 と B1〜B5 で定義・言明のレビュー、01-12/07-04 の更新、lake build/check-formal と公理依存の確認を行う。P2 の通常構成の coverage_export/desugar_export の結果は [results.md](results.md) に区別して記す。
