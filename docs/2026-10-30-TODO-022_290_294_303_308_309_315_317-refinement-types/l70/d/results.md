# L70 群 D の結果（L70.20〜.28）

ブランチ `m014/l70.d`、B_WORK `49f17471442229baf668e7b1f7b6dac8151c6dcf`。実装担当（Claude、Opus 5.5）の記録であり、独立レビュー済みを意味しない。git の操作と `scripts/check.sh` は行っていない。生の出力は `<tmp>` に置き、ここには大きさと SHA-256 を残す。

最初の起動では利用者の関数の範囲パラメータを停止条件として止めた（記録は末尾の「最初の起動の停止」）。取りまとめの再開の指示（設計者が案 A を選び、核の変更は群 K が行う。群 D は範囲パラメータを持つ利用者の関数を除いて進め、その表層の規則を置かず、整形式で「まだ受け付けない」と断る定義も置かない。核の変更の署名の案を `range-kernel.md` に書く。確認を求めた四点は推す形で進める。範囲パラメータの種類は host を含む。`C_Match` に照合対象の型の宣言の前提が群 K で加わるので、表層の match の規則はそれを受けられる形にし、核の `C_Match` は変えない）に従って続けた。

## 単位の時刻

外側の時間は能動時間と待ち時間を分けていない。単位ごとの `date` を取り落としたので、単位の境の時刻は作業の記録（ファイルの作成の時刻）から読んだ。最初と最後の時刻、ビルドと監査の時刻は `date` の出力である。

| 単位 | 開始 | 終了 | 外側の時間 |
|---|---|---|---|
| 読み込みと方式の確認（最初の起動、停止） | 2026-11-06 07:02:58 | 07:18:17 | 15分 |
| 再開: 核の変更の署名の案（`range-kernel.md`） | 07:20:50 | 07:22:21 | 2分（host と `C_Match` の注は 08:05 に追記） |
| L70.20 構文の派生の定義と骨格の追加、L70.25 脱糖 | 07:22 | 07:33 | 11分 |
| L70.21・.22 表層の型付けの規則（型の宣言の移送を含む） | 07:33 | 07:46 | 13分 |
| L70.26・.27 性質1の式・文・腕・節・ブロック、定義と実装 | 07:46 | 08:23 | 37分 |
| L70.28 有効範囲の保存とプログラム全体（`desugar_typed`・適用例） | 08:23 | 08:54 | 31分 |
| L70.22・.26・.27 残りの構文（パイプの有効範囲、or die の4規則、リストの展開、文字列補間、部分適用の3規則） | 08:54 | 09:31 | 37分 |
| L70.24 判定の関数と欄の依存の構築・更新、L70.20 の残り（篩の中の名前の写し・束縛名） | 09:31 | 09:48 | 17分 |
| L70.23 別名の展開 | 09:49 | 09:58 | 9分 |
| 写し（07-04）・警告と読者のない定義の除去・ビルド・監査・照合・記録 | 09:58 | 10:07:30 | 10分 |

計 約3時間5分。見込み（10時間30分〜19時間）より短く、中間報告の8時間には達していない。

## 群 D の完了条件の照合

完了条件「新しい表層の型付けと脱糖で性質1が閉じ、篩付きの結果型と効果を保つ」について:

- `Surface.Theorems.desugar_typed`（F05）を `sorry` なしで証明した。表層の規則（相互帰納の 91 構成子、下表）の全場合と、プログラム全体の宣言した関数・実装・フィールドを取り出す関数・構成子の判定の関数の4種を量化する。
- 篩付きの結果型と効果: 関数の定義の依存列は表層の宣言の依存列 `FunDecl.tel` と同じであり（`FunDecl.tel_eq`）、本体は同じ依存列で型付く（`BodyTy.desugar`）。式の性質1 `HasTypeQ.desugar` は、同じ文脈・同じ篩付きの型・同じ効果の核の型付けを結論する。
- 適用例: `Surface.Examples.mainProgram_desugar_typed` は、Unit を返す main だけのプログラムへ、合成表 `StandardModel.builtins` と `StandardModel.substitution_assumptions` で前提を満たして性質1を当てる。
- 除いた範囲: 範囲パラメータを持つ利用者の関数（後述）。断る定義は置いておらず、その宣言を型付ける規則がない。

## F05 の言明

```lean
theorem desugar_typed {p : Program} {B : Builtins} {opPrim : OpPrim}
    (hwf : p.WellFormed) (hwt : p.WellTyped B opPrim)
    (hA : Builtins.ValueAssumptions (desugarProgram opPrim p) B) :
    (desugarProgram opPrim p).WellFormed ∧ (desugarProgram opPrim p).WellTyped B ∧
      (desugarProgram opPrim p).EffectsOk B
```

detail.md の F05 の `hsig : …` に当たる前提は、組み込みの表の仮定のうち値の束縛を移す補題が読む `Builtins.ValueAssumptions` である（主な定理の `CoreAssumptions.values` から得る）。`Program.WellFormed` は、型の宣言の整形式（宣言の表のプログラムの `WellFormed`）、定義の名前・署名の有効範囲・本体の有効範囲、実装の有効範囲、フィールドを取り出す関数の条件（`AccessorOk`）、判定の関数の条件と同名の拒否（`TesterOk`）の5欄である。`Program.WellTyped` は、変性の宣言の妥当性、定義ごとの view での型付け（`Def.WellTyped`）、実装のメソッドごとの view での型付け（`ImplDecl.WellTyped`）、エフェクトの宣言の整合の4欄である。

## 表層の型付けと脱糖の規則の件数

| 判断 | 構成子 |
|---|---:|
| `HasTypeQ`（式） | 68 |
| `HasBlockQ`（ブロック） | 11 |
| `HasTypesQ`（引数の列）・`HasEachQ`（リストの要素） | 2・2 |
| `HasFixedQ`（穴を含む引数の固定の式） | 3 |
| `HasArmsQ`（腕）・`HasClausesQ`（節） | 3・2 |
| 相互帰納の計 | 91 |
| 補助の判断（相互帰納の外） | `DictEv.HasType` 4・`DictEv.HasTypes` 2、`ArgVal` 4・`ArgElems` 2、`ValsTel` 2・`ValsTys` 2、`CallHeadTy` 6、`SpreadTy` 4、`JoinTy` 2、`JoinPartsTy` 3、`InterpTy` 5、`BodyTy` 2 |

表層の `Expr` の 54 構成子のすべてに少なくとも一つの式の規則がある（台本で照合）。旧 Surface の規則に対して分けた・足した規則は、外部関数の名前と呼出し（`E_ExternalName`・`E_CallExternal`）、直接の頭とそうでない頭（`E_CallDirect`/`E_Call`、パイプの4規則、`E_PartialCallDirect`/`E_PartialCall`）、or die の説明の有無（4規則）、欄の依存を持つ record の構築と更新（`E_RecordRefined`・`E_RecordUpdateRefined`）である。脱糖は `desugarExpr`・`desugarExprs`・`desugarHoleArgs`・`desugarArms`・`desugarClauses`・`desugarBlock` の相互6関数と、`desugarDef`・`desugarImpl`・`accessorDef`・`testerDef`・`desugarProgram` である。

## 性質1の結果

- 相互帰納の全 91 構成子について `HasTypeQ.desugar` などを証明した。有効範囲の保存 `HasTypeQ.scoped` なども全構成子で証明した。`sorry` はない。
- 公理: 対象 3,350 件（足した23モジュールの 2,060 件と、変えた `Surface.Syntax` の 1,290 件。private 448）の公理の組は、なし 1,812、propext 535、propext と Quot.sound 71、三公理 932 で、許可した三公理の外の公理と sorryAx はない。`desugar_typed`・`testerDef_wellTyped` は三公理に依存する。
- 相互帰納の性質1（`Property1.lean`）と有効範囲（`ScopedProof.lean`）の二つの定理は、91 構成子の場合の分けで既定の heartbeat の上限（200000）を超えたので、その二箇所だけに `set_option maxHeartbeats 400000 in` を置いた（置かないと二つとも時間切れで止まることを確かめた）。

## U02 の決定の表層の受け持ち

| 項目 | 結果 | Lean |
|---|---|---|
| S1・S2・S3 の束縛名の同名の拒否（R1） | 済み（定義と受理・拒否の両例）。表層の型は束縛名を持たないので、名前の上の判定として置いた | `RefinementBinderOk` |
| S4 述語の判定の綴りの写し | 済み。Float と Float32 の分類（6類。`isInfinite` は二類の和）、端がリテラルの `String.charactersIn`、生成した判定の関数を写す。`pathMatches`・`hostMatches` は δ の行の群（F2）の担当とし、ここに置かない | `predicateOfCall`・`floatClassesOf` |
| S5 record 全体の条件、S6・S7 値引数、R2 全 sort | 済み。別名の展開を型引数・値引数・範囲の置換で定め、値引数の置換が注釈の整形式を保つことを全 sort で示した（像の条件 `Term.ImagesSorted` が sort を量化する）。型パラメータを持たない別名は宣言の整形式から展開の整形式が従い、`Window(10)` に当てた | `AliasDecl.expand`・`aliasValues_annotation`・`AliasDecl.expandValues_annotation_monomorphic`・`window_expandValues_annotation` |
| S8・S9・R4（関数の中）・R5（関数の範囲を別名へ） | 除いた（後述）。R5 の閉じた範囲の場合は、展開が範囲変数を残さないことを示した | `AliasDecl.expand_wf` |
| R3 host | 組み込みの関数の範囲の具体化は種類を限らず `B.RangeAdmissible` と `Tel.instR` で読む（`CallHeadTy.prim`）。利用者の関数の範囲パラメータの種類は群 K の核の変更に入る | — |
| S10・R6・R7 `@proofSteps` | 骨格の欄（群 A）。表層の型付けと脱糖は読まない | `FunDecl.proofSteps` |
| R9(a) 構成子の判定の関数 | 生成（`testerDecl`・`testerDef`、`lookupFun` の三番目の優先順）、同名の拒否（`Program.WellFormed.testers`）、述語への写し（`predicateOfCall`）、結果の篩（`testerPred`。照合の経路の事実から型付く `testerDef_wellTyped`）を済ませた。signatures.md の「本体の結果と述語の閉じた評価の一致の補題」は、判定の関数が δ の行でなく利用者の定義の脱糖なので、結果の篩の型付け（主定理の保存で値が篩を満たす）で受け、別の補題を置いていない | `testerPred`・`testerDef_wellTyped` |
| R10 record の欄の参照 | 構築と更新は済み（欄の篩を record 全体の値の欄の観測へ写した篩を持つ型。核の `ConDecl` は変えない）。射影の結果の型は欄の基の型のままで、欄の観測との等号の篩は付けていない（判断を求める点2） | `RecordDecl.refinement`・`RecordDecl.conDecl`・`E_RecordRefined`・`E_RecordUpdateRefined` |
| R11 不透明な record の射影 | 済み。公開の射影を欄の観測 `Term.field` へ写す | `fieldTermOf` |
| J70-9 if の事実 | 済み。`if`・`else if`・`and`・`or`・`not` の規則は、条件の値を束縛した文脈で真偽から導ける事実を枝に加える。判定の関数の結果の篩がこの事実を与える | `E_If` ほか、`testerPred` |

## 範囲パラメータを持つ利用者の関数（除いた範囲）

核の `Def` と `Val.fnRef` が範囲の引数を持たないので、次の形の規則と性質1の場合を置いていない。核の変更の署名の案は `range-kernel.md` にある。

| 表層の形 | 影響する規則 | 性質1の場合 |
|---|---|---|
| 範囲パラメータを持つ関数の参照と直接の呼出し | `CallHeadTy.fn`・`CallHeadTy.fnDicts` の2構成子（範囲の具体化の列がない）と、これを読む `E_Fun`・`E_FunDicts`・`E_CallDirect`・`E_PipeCallDirect`・`E_PipeApplyDirect`・`E_PartialCallDirect` の6規則 | `CallHeadTy.glue`・`CallHeadTy.app_value` の fn・fnDicts の4場合と、上の6規則の場合 |
| 範囲パラメータを持つ関数の定義 | `Def.WellTyped`（`BodyTy`）が範囲の変数の文脈を持たない | `Def.WellTyped.desugar` の1場合 |
| 関数の範囲パラメータを型の別名へ渡す形（R5） | 別名の展開は閉じた範囲の列だけを受ける | `AliasDecl.expand_wf` の前提 |

範囲パラメータを持たない関数、組み込みの関数の範囲の具体化（`primName` の範囲の列と、閉じた原子との混在）、閉じた範囲での別名の展開は、上の規則と性質1に含まれる。表層の match の規則（`E_Match`・or die・try・ブロックのパターン）は照合対象の型の注釈（`Ty.Annotation`）を前提に持つので、群 K が `C_Match` に加える型の宣言の前提はこの注釈から供給できる。

## 足した・変えた宣言

足したモジュール（23、計 約6,100行）: `Surface.Basic`（派生の定義・欄の依存・判定の関数の宣言）、`Desugar`、`Transport`（同じ型の宣言を持つプログラムの間の移送）、`Rules`、`LetChain`、`Property1Base`、`Property1Calls`、`Property1Control`、`Property1Match`、`Property1Die`、`Property1Spread`、`Property1Interp`、`Property1Partial`、`Property1`、`Program`、`ScopeShift`、`Scoped`、`ScopedProof`、`TesterTyping`、`Theorems`、`Examples`、`Predicates`、`Aliases`。モジュールごとの宣言の件数は `audit-summary.json` の `axioms.modules` にある。

変えた既存のモジュール: `Surface/Syntax.lean`（群 A の骨格）に行の追加だけ（`Expr.externalName`、`Declarations`・`Program` の `externals`・`dataInfo` の欄。既定値つき）。根の `formal/Benitoite.lean` に import の行の追加だけ（23行）。核・旧 Release・旧 Surface は変えていない。

写し: 07-04「篩を含む形式化の範囲」の `Surface.Syntax` の段落（式の構成子と宣言の表の欄）を直し、表層の規則、脱糖と性質1、名前の写しと別名の展開の3段落を足した。「01-12 との対応」の表に4行を足した。01-12 の「篩を含むコア計算の形式化」以下は核の写しで表層の文法を持たないので、変えていない。

## 既定ビルド・公理監査・照合

既定ビルド: `formal/` から `lockf` の下で既定の `lake build`（対象の指定なし）。終了0、1,365 ジョブ、エラーなし、足したモジュールと変えたモジュールの警告なし。10:02:55〜10:03:33（38秒）。生の出力 46,925 バイト、SHA-256 `81a91caa8dd757f5cc798b0eae14a227bc3ec605f60eb9fdfd16812310d39296`。

公理監査: `lockf` の下で `lake env lean -M 12288 ../docs/…/l70/d/axioms.lean`（`formal/` から）。1回目は必須の名前の一覧の誤り（`Program.SameTypes` の名前空間を `Surface` と書いた）で止まった。直した2回目は終了0、10:04:15〜10:04:29（14秒）、最大常駐量 1,936,719,872 バイト。生の出力 1,119,189 バイト、SHA-256 `1e858c3466990bde203273107ecd2f74a20ecb1b59f130a36311f18731f4590b`。対象は `audit-modules.json`（verify が git の差分から作り直して照合する）の24モジュールの全宣言（private・生成宣言を含む）、必須の名前は `required-names.json` の55件。

照合: `python3 l70/d/verify.py --tmp <tmp>` 終了0。変更の範囲、根の import の差分が足した23モジュールの import の行だけで一度ずつ現れること、骨格の差分が行の追加だけであること、ビルドの警告、公理の組と対象の数と必須の名前、足したモジュールに `sorry`・`#eval`・`#check`・`#print`・`maxRecDepth`・工程の ID がなく `maxHeartbeats` が上の二箇所だけであること、記録の大きさと手元の絶対パスと docs/todo へのリンクがないことを確かめ、`audit-summary.json` に書いた。

## 条件の四分類

| 前提 | 分類 | 根拠 |
|---|---|---|
| `desugar_typed` の `p.WellFormed` | 実質 | 型の宣言の整形式・本体の有効範囲・生成する関数の条件を求める。適用例で満たす |
| `desugar_typed` の `p.WellTyped B opPrim` | 実質 | 全定義・全実装の表層の型付け。適用例で main の本体を `B_Empty` で型付ける |
| `desugar_typed` の `Builtins.ValueAssumptions` | 実質 | 値の束縛を移す補題が読む。合成表で満たす |
| `TesterOk` の4欄（署名の kind・注釈・有効範囲、構成子のパターンの型） | 実質 | 宣言から決まり、判定の関数の型付けが読む |
| `AliasArgs` の4欄 | 実質 | `windowAlias_args` で値 10 について満たす |

保留の条件はない。

## 義務と申し送りの判定

| 行 | 判定 | 根拠 |
|---|---|---|
| O005・O033 data 宣言の変性を性質1の前提に | 済み | `Program.WellTyped.variance`（宣言の表のプログラムの `VarianceValid`）を脱糖したプログラムへ移す |
| O012・O037 literal の値域 | 済み | `E_Literal` と幅つきの負のリテラルの規則が `ConstOK` を求め、性質1は `V_Const` で受ける |
| O056・O138 if・短絡・guard・match の事実 | 表層と性質1の分は済み（網羅性は群 E） | 条件の真偽の事実（`ite_typed`）、腕の経路の事実（判定の関数） |
| O066 篩付きの型と効果の保存 | 表層の分は済み（checker・網羅性・消去は群 E） | 上の完了条件 |
| O068 try/or return/or die/パイプの期待型 | 済み | `E_TryResult`・`E_TryOption`・or die の4規則・パイプの6規則 |
| O136 値依存の端点と線形関係 | 表層と性質1の分は済み | 篩付きの型は依存列と事実の列で受け、`Entails` で読む |
| O139・O140 名前付き関数とラムダの部分型、F3 の各位置 | 済み | 関数の参照は依存列の型（`CallHeadTy`）、呼出しは `ValsTel`、部分型は `Ty.LeQ` |
| O167 束縛名の同名 R1・範囲パラメータの宣言 | R1 は済み、範囲パラメータは除いた範囲 | `RefinementBinderOk`、上の表 |
| O003・O029・O053・O054 文脈の形成 | 済み | 事実の列は束縛の下で持ち上げ（`liftMany`）、継続を隠す位置は `hideConts`、文脈の順は `bindParams` |
| O046 有限論理と正常葉の合成 | 群 D の分なし | 規則は `Entails` を前提に読むだけである |
| O135 R10 の欄の依存 | 構築と更新は済み、射影は判断を求める点2 | 上の表 |
| L60-受口2 外部の場合・名前付き引数・穴・評価順・`.lam`/`.dependentLam` | 外部・名前付き・穴・評価順は済み。部分適用は非依存の `.lam` だけ | `E_CallExternal`・`E_PartialCall*`。判断を求める点1 |
| L60-群D `ExternalSurfaceLeaves` の旧 `recordFields` | 未着手 | 新しい表層の `recordFields` は `Surface.Basic` にある。読者の置き換えは並行の群も読む核のモジュールを変えるので、旧 Surface を消す単位（L70.44）と合わせる |
| L40-後段3 短絡の脱糖 | 済み | `and`・`or` は `ite` へ脱糖し、Comp の新しい構文を足さない |
| L30-A4 ソース別名の実像 | 済み | `AliasDecl.expand` |
| L30-転記・L20-J2・J3・L00b-表層 | 済み | 性質1の呼出し（多相・辞書・メソッド・外部・組み込み）の場合 |
| L20-J7 合法ソースの kind | 済み | 型の宣言の照合は `D.core` の同じ kind の表を読む（`TypeArgsKinded`・`Ty.HasKind`） |
| plan-1101 辞書制約と変性の照合 | Lean の分は済み | 変性の前提を `Program.WellTyped.variance` に明記した |

## 計画からのずれ

- 範囲パラメータを持つ利用者の関数を除いた（取りまとめの指示による）。
- 群 A の骨格へ行を足した（`Expr.externalName`、`externals`・`dataInfo`）。事前に伝えた点2のとおり。
- 型の宣言の照合は宣言の表から作るプログラム `D.core` で行い、移送の補題で脱糖したプログラムへ移す（案 T）。
- `ViewExhaustive` を宣言的に定めた（既定の閉じた view で核の網羅性と同値）。
- 旧規則の `SingleTy`・`SingleEff` を写さなかった（受理を広げる向き）。分岐と try の規則に `Ordinary`、record の更新に位置の数の前提を足し、try の規則はパターンの型の前提で書いた。
- or die の表示と終了は呼出しと同じ照合で読み、終了の効果は被覆で比べる（旧は効果の名前を和で足した）。
- 文字列補間の規則は、旧の `InterpPart.Allowed` と式の型の一致（`as = InterpPart.exprTypes parts`）の前提を残し、変換の頭の型は呼出しと同じ照合で読む。読者のなくなった補助の定義（変換の型の列・部分の数・変換の名前・全頭の直接性）は置いていない。
- 部分適用の結果は非依存の関数の型（`.fn`）だけで、`.dependentLam` を選ぶ脱糖は置いていない（判断を求める点1）。
- R10 の射影の結果の型に欄の観測との等号の篩を付けていない（判断を求める点2）。
- 単位ごとの `date` を取り落とし、境の時刻を作業の記録から読んだ。

## 取りまとめに判断を求める点

1. **部分適用の `.lam` と `.dependentLam` の選択（L60-受口2、RV-L60.d 情報2）。** 今の脱糖は処理系と同じ非依存の `.lam` を作り、規則は穴の宣言の型（外側の文脈の型）から依存列の各位置へ部分型で渡す。呼ぶ関数が依存列を持っても、穴の型が依存列の具体化の部分型であれば型付く。結果型が穴の値に依存する部分適用（`.dependentLam` が要る形）は型付けない。処理系の脱糖を変えずにこれを受けるには、脱糖が依存列の形から `.dependentLam` を選ぶ規則が要り、処理系の脱糖と食い違う。今の形で進めるか、処理系の脱糖とともに後の群で足すかの判断を求める。
2. **R10 の射影。** 欄の依存を持つ record の値の篩は、値を束縛した文脈で事実として読めるが、射影の呼出しの結果（取り出しの関数の戻り値）は欄の観測 `Term.field` と結び付かないので、射影の結果に依存の事実は流れない。取り出しの関数の結果型に整数の欄の観測との等号の篩（`eq (var 0) (field ref (var 1))`。核の欄の事実 `FieldLink` は整数の欄の値とリストの長さだけを結ぶ）を付ければ閉じられる見込みで、核の変更は要らない（証明は判定の関数と同じ形で、照合の経路の事実と欄の事実を使う。所要は1〜2時間の見込み）。群 D の追加として行うか、群 E の checker の受理と合わせるかの判断を求める。
3. **heartbeat の上限。** 性質1と有効範囲の相互帰納の二つの定理に `set_option maxHeartbeats 400000 in` を置いた（91構成子の場合の分けのため）。依頼文の「証明に不要な」に当たらないと判断したが、場合の証明を補題へ分けて上限を戻す形を求めるなら指示がほしい（所要は1時間程度の見込み）。

## 再開1（2026-11-06 10:09〜）

取りまとめの決定（判断を求めた3点を推す方法で進める）に従った。この節の内容は、前の節の「部分適用は非依存の `.lam` だけ」「R10 の射影は未完」「取りまとめに判断を求める点」と、規則の件数（式 68・相互帰納 91）を置き換える。

| 単位 | 開始 | 終了 | 外側の時間 |
|---|---|---|---|
| R10 の射影（取り出しの関数の結果の篩） | 10:10:05 | 10:19 | 9分 |
| 部分適用の依存するラムダ | 10:19 | 10:24 | 5分 |
| 写し・ビルド・監査・照合・記録 | 10:24 | 10:34 | 10分 |

### 処置

1. **部分適用の `.lam` と `.dependentLam` の選択。** 部分適用の結果型と効果（`Expr.partialCall` の `ret`・`eff`）は穴の束縛の下で読む。脱糖 `holeLam` は、それらが穴の数だけずらした外側の型と効果として書けるなら非依存の `.lam` を、書けなければ穴を引数とする依存列 `holeTel` の `.dependentLam` を作る（判定は古典論理の命題による。そのため脱糖の定義は計算しない定義の区間に置いた）。非依存の規則 `E_PartialCallDirect`・`E_PartialCall` は結論の `ret`・`eff` をずらした外側の型と効果とし、依存する規則 `E_PartialCallDirectDep`・`E_PartialCallDep` を足した（結果の型は `.dependentFn (holeTel …)`。固定の式と呼ぶ値は戻り値型を持たない継続を隠した文脈で型付け、その効果を結果の効果で被覆する）。性質1は `V_DependentLam` と `holeTel_body`（穴を順に束縛した文脈の本体から依存列の本体の型付け）で閉じ、有効範囲は `Expr.Scoped` の部分適用の欄に依存列の有効範囲を足して閉じた。構成子の部分適用は結果型の欄を持たないので非依存のまま。**R10b・R50 への申し送り:** 処理系の脱糖は部分適用に常に非依存のラムダを作り、`ret` を外側の文脈の型として書く。新しい表層では `ret`・`eff` を穴の束縛の下で読み、依存する場合に `.dependentLam` を選ぶので、交換の書き出しと処理系の脱糖の対応（`ret` の読み方と依存の判定）を照合の対象とする。
2. **R10 の射影。** フィールドを取り出す関数の結果型を `accessorRet` とした。整数の欄（基の型の sort が整数）では欄の基の型に `eq (var 0) (field ⟨data, C, k, integer⟩ (var 1))` の篩を付け、それ以外の欄は基の型のままである。型付け `accessorDef_wellTyped` は、整数の欄では照合する値を観測し（`obs := some (var 0)`）、束縛した欄と欄の観測の等号の事実（`FieldLink`、経路 `accessor_binderPath`）から `V_Refine` で結果の篩を導く。核は変えていない。`AccessorOk` に、整数の欄のとき欄の位置が範囲内であることと、照合の経路の事実・欄の事実の整形式（実質の条件）を足した。`spanRecord` の `high` の取り出しの結果型を例に置いた。
3. **heartbeat の上限。** 二つの `set_option maxHeartbeats 400000 in` は証明に要るものとして残した。理由: 相互帰納の性質1と有効範囲の定理は 93 構成子の場合の分けで既定の上限（200000）を超え、外すと二つとも時間切れで止まる。

規則の件数は、式 70・相互帰納 93 になった（`HasTypeQ` に依存する部分適用の2規則を足した）。U02 の R10 の行は「構築・更新・射影は済み」、L60-受口2 の行は「`.lam`/`.dependentLam` の選択は済み。処理系との対応は R10b・R50 へ申し送り」、O135 の行は「済み」に改める。

### 検査

| 検査 | 結果 |
|---|---|
| 既定ビルド（`lockf` の下、`formal/` から既定の `lake build`） | 終了0、1,365 ジョブ、足したモジュールと変えたモジュールの警告なし。10:24:20〜10:32:26（8分6秒。脱糖の変更で読者が再ビルドされた）。生の出力 46,848 バイト、SHA-256 `491f151f6187c1cb61ea4a9068c97d273d3c29a42b91839ab323b6b23d8acfdf` |
| 公理監査（`lockf` の下、`lake env lean -M 12288 ../docs/…/l70/d/axioms.lean`） | 終了0、10:32:26〜10:32:40（14秒）、最大常駐量 1,939,275,776 バイト。対象 3,402 件（足したモジュール 2,112、private 458）、公理の組はなし 1,826、propext 557、propext と Quot.sound 75、三公理 944。許可した三公理の外の公理と sorryAx はない。必須の名前は62件（`holeLam`・`holeTel`・`holeTel_body`・`holeLam_dependent`・`accessorRet`・`AccessorOk`・`accessor_binderPath` を足した）。生の出力 1,140,024 バイト、SHA-256 `18cd30f5eef357b85b75813a45be301a2e49c26e0304d5c1ffb23ddf63816055` |
| 照合（`python3 l70/d/verify.py --tmp <tmp>`） | 終了0。`audit-summary.json` を書き直した |

## RV-L70.d の処置（2026-11-06 10:52〜）

独立レビュー（不可、重5）の所見を、保存定理の結論を弱めず、形を提供範囲から除かずに処置した。固定した判断の署名（群 A の判断の型）と核の規則は変えていない。この節は前の節の規則の件数（式 70・相互帰納 93）、R10 の射影・別名の範囲パラメータ・外部の部分適用の判定を置き換える。

| 単位 | 開始 | 終了 | 外側の時間 |
|---|---|---|---|
| 読み込み・重5（外部の頭） | 10:52 | 10:57 | 5分 |
| 重4（List の欄の射影） | 10:57 | 10:58 | 1分 |
| 重1（値の観測による篩の導入） | 10:58 | 11:03 | 5分 |
| 重2（腕の事実）と例 | 11:03 | 11:11 | 8分 |
| 重3（別名の範囲パラメータ） | 11:11 | 11:16 | 5分 |
| 写し・ビルド・監査・照合・記録 | 11:16 | 11:20 | 4分 |

### 処置

| 所見 | 処置 | Lean |
|---|---|---|
| 重1 | 脱糖が値をそのまま返す式（局所の名前・リテラル・符号付きのリテラル・Unit・引数のない構成子。`Expr.valueOf?`）に、値の項について篩が事実から導けるとき篩付きの型を与える規則 `E_Refine` を足し、核の `V_Refine` へ接続した（`desugar_valueOf`、`HasTypeCQ.ret_value`）。要素を束縛した後のリストの値の篩の導入 `E_ListRefined` も足した。呼出しの実引数 `ArgVal` に篩の導入 `refine` を足し、`ValsTel`・`ValsTys` を通る全呼出し・構成子・リスト要素の実引数で値の事実を使えるようにした。受理: `false_notTrue`（任意の宣言表・組み込みの表・演算子の表で `false : Boolean{r \| not(r = true)}`）。拒否: `true_not_notTrue`（誤った値 `true` には導入の前提が含意の健全性から成り立たない）。一般の保存は性質1の `E_Refine`・`E_ListRefined`・`ArgVal.refine` の場合で、開いた文脈・引数・結果について示した | `Rules.lean`・`Property1Base.lean`・`Property1.lean`・`Examples.lean` |
| 重2 | 腕の判断の文脈の番号 0 を照合する値とした（`E_Match` は照合する値を束縛した文脈で腕を型付ける）。腕の規則に、照合する値の観測 `scrutObs`（値の型が sort を持つとき `some (var 0)`）、照合の経路の事実（matched）、欄の対応 `links` と欄の事実、ガードの結果の篩 `q` を置き、本体に経路・欄の事実とガードが真の事実を、後続の腕に除外の事実（excluded）を渡す。核の腕の型付けと同じ事実なので、性質1は核の `plain`・`guarded` へそのまま写る（ずらしの補題が要らなくなり、`shift_guard` 等を除いた）。腕のガードと本体は照合する値の束縛の下で書くので、脱糖は腕の本体を移さない。例: 通常の腕 `notTrueArms_typed`（`true` の腕の後の腕で、照合する値 x が除外の事実 `not(x = true)` から `Boolean{r \| not(r = true)}` を持つ）、ガード `guardArms_typed`（ガードの結果の篩から得る事実で、照合する値が `Boolean{r \| r = true}` を持つ） | `Rules.lean`・`Desugar.lean`・`Scoped.lean`・`Property1.lean`・`ScopedProof.lean`・`Examples.lean` |
| 重3 | 別名の宣言の整形式を、本体を型パラメータ・範囲パラメータ・値引数の文脈で形成する形にした（`bodyWF` の範囲の上限は範囲パラメータの数）。範囲の実引数 `AliasDecl.RangeArgs`（同じ数の、整形式で種類の合う閉じた範囲）で具体化した後の注釈の整形式を `instR_annotation` で示した（核の `Ty.Sorted.rawMapRanges`・`Ty.Declared.rawMapRanges`・`SubstEnv.rangesOnly_wfImages` を使う）。展開は型引数・範囲・値引数の順にし、型パラメータを持たない別名の展開の注釈の整形式 `AliasDecl.expand_annotation_monomorphic` を、範囲パラメータを持つ別名を含めて示した。例: `pathAlias`（`[range R: path]`、本体 `Scope.PathIn[R]`）の整形式と、`InPath[/**]` の展開の注釈の整形式（`pathAlias_expand_annotation`）。核の `Ty.Annotation` の範囲の上限は変えていない。関数由来の開いた範囲を別名へ渡す形だけが群 K の後に残る | `Aliases.lean` |
| 重4 | 取り出しの関数の結果の篩を、整数の欄（値の等号）に加えて List の欄（長さの等号 `List.length(r) = List.length(field(value))`）に付けた（`accessorRet`・`accessorPred`・`accessorMeasure`）。型付けは核の欄の事実 `FieldLink` の `measure := some .listLength` で閉じた。例: `Sized` の全体の篩と `xs` の射影の結果型（`Predicates.lean`）。観測可能な欄の棚卸し: 核の `FieldLink` が欄と束縛を結ぶのは、値の整数の等号（`Pred.eq` は整数の sort）と List の長さの等号だけである。Character・Float64・Float32・Decimal・Boolean・String・Unit の値、String の長さ（`stringBytes`・`stringCharacters`）、Bytes・Map・Set の大きさ、data・対象の欄は、核の欄の事実を持たないので射影の結果は基の型のままである（扱うには `FieldLink` の比較の種類と測度を核で広げる必要がある） | `Basic.lean`・`Theorems.lean`・`Predicates.lean` |
| 重5 | 直接の頭の依存列の照合 `CallHeadTy` に外部関数の構成子 `external` を足した（宣言の依存列を型引数で具体化。外部の依存列は閉じているので束縛の下へ移しても変わらない `external_tel_shift`）。これで裸の外部関数を頭とする部分適用（非依存・依存の直接の規則）、パイプの外部の場合、直接の呼出しが、`ExternalSurface.partial_call` と同じ外部宣言・依存列（`Tel.bind (typeEnv ts) d.parameters`）・効果（被覆）で型付き、`CallHeadTy.glue` の外部の場合が核の `C_External` へ写す。非穴式は従来どおりラムダの本体で書いた順に評価する | `Rules.lean`・`Property1Calls.lean` |

規則の件数は、式 72・ブロック 11・引数の列 2・リストの要素 2・固定の式 3・腕 3・節 2 の相互帰納 95 になった。補助の判断は `ArgVal` 5・`CallHeadTy` 7 になった。U02 の R10 の行は「構築・更新・射影（整数と List の欄）は済み。他の観測は核の欄の事実の範囲外」、R5 の行は「別名自身の範囲パラメータは済み。関数由来の開いた範囲は群 K の後」、O056・O138 の行は「表層の腕の事実まで済み」、L60-受口2 の外部の行は「外部の頭の部分適用・パイプは済み」に改める。

**R10b・R50 への申し送り（追加）:** match の腕のガードと本体は、照合する値の束縛の下で書く（新しい表層の約束）。処理系の書き出しは照合する値を含まない番号で書くので、部分適用の `ret` の読み方とあわせて照合の対象とする。

### 検査

| 検査 | 結果 |
|---|---|
| 既定ビルド（`lockf` の下、`formal/` から既定の `lake build`） | 終了0、1,365 ジョブ、足したモジュールと変えたモジュールの警告なし。11:16:53〜11:17:31（38秒）。生の出力 46,846 バイト、SHA-256 `132627f21e590887b4788de447df66e1ef64c897637330c292c2927ec3bac330` |
| 公理監査（`lockf` の下、`lake env lean -M 12288 ../docs/…/l70/d/axioms.lean`） | 終了0、11:17:31〜11:17:44（13秒）、最大常駐量 1,939,931,136 バイト。対象 3,521 件（足したモジュール 2,231、private 501）、公理の組はなし 1,863、propext 599、propext と Quot.sound 75、三公理 984。許可した三公理の外の公理と sorryAx はない。必須の名前は69件（例と新しい補題を足し、消した補題を除いた）。生の出力 1,189,776 バイト、SHA-256 `18f920a802728078fd8b9a14f24c8fea2f2ecfcb426e293058a35147e0143019` |
| 照合（`python3 l70/d/verify.py --tmp <tmp>`） | 1回目は終了1（取りまとめが置いたレビューの記録 `reviews/RV-L70.d.md` を未追跡の変更として数えた）。この記録を照合の外とする行を足した2回目は終了0。`audit-summary.json` を書き直した |

## 最初の起動の停止（07:18 の記録の要約）

依頼文の「止める条件」に当たる項目として、利用者の関数の範囲パラメータ（U02 の S8・S9、関数の中の R4、関数の範囲パラメータを別名へ渡す R5）を挙げて止めた。核の `Def` は範囲パラメータの種類の列を持たず、`Val.fnRef` は範囲の具体化の列を持たず、`V_Fun` と `Def.WellTyped` は範囲の変数の上限 0 で読むので、範囲パラメータを持つ関数を含むプログラムは `Def.WellTyped` を満たさない（反例: `function readAll[range R: path](p: Scope.PathIn[R]) -> String uses File.Read[R]`）。代案は、核を広げる案 A（`range-kernel.md` に署名の案）、脱糖で特殊化する案 B、今回の範囲から外す案 C だった。設計者は案 A を選び、核の変更は群 K が行う。

## 再レビューの残りの処置

開始: 2026-11-06 11:24:45 JST。基準は `49f17471442229baf668e7b1f7b6dac8151c6dcf`。再レビューに残った重1・重3の二件だけを扱う。核の規則・固定済みの判断の署名は変更しない。

| 単位 | 開始 | 終了 | 外側の時間 |
|---|---|---|---|
| 二件の処置・局所検査・写し | 11:24:45 | 11:37:01 | 12分16秒 |
| 既定ビルド・公理監査・照合・最終確認 | 11:37:01 | 11:48:55 | 11分54秒 |

### 二件の処置

| 所見 | 処置と根拠 | 判定 |
|---|---|---|
| 重1の残り | `Expr.valueOf?` に `negDecimal`・`negInteger8`・`negInteger16`・`negInteger32`・`negFloat32` を足した。返す値は専用の脱糖の分岐と同じ定数である。`desugar_valueOf` の構造的な場合分けは五つの分岐も証明し、`HasTypeQ.desugar` の `E_Refine` は同じ値を核の `V_Refine` へ渡す。`HasTypeQ.scoped` の `E_Refine` は基の導出への帰納で全ての値に共通して成り立ち、二つの保存定理の署名と証明の変更は不要だった。`Examples.negDecimal_singleton`・`negIntegers_singleton`・`negFloat32_singleton` が、専用の五構成子のまま正確な値との等号の篩を導入する。特に空の文脈の `negDecimal 1 0` は `Decimal{d | d = -1}` に型付く | 実質 |
| 重3の残り | `AliasDecl.subst_formation` は、宣言の整形式と `P.VarianceValid`、`AliasTypeArgs`（型引数の数・kind・各像の整形式・整列・宣言）から、`a.body.subst ts []` の形成を、型引数を置換した `a.typeContext ts` で導く。文脈の値の番号を保ち、正規化前の型の像を格納する。`AliasDecl.expand_annotation` は、この形成を閉じた範囲で具体化した `a.instantiatedContext ts rs` の下の `AliasArgs` を要求し、展開先の文脈で注釈の整形式を結論する。型パラメータが空という前提はない。補助の相互帰納は型構成子の適用、依存列、失敗型を含む全ての型構成子を扱い、型・値・範囲の変数を含む型引数の像を除外しない。`sizedPathAlias` は型 A・値 n・範囲 R を持ち、本体に長さ n の List[A] と Scope.PathIn[R] を使う。宣言の整形式・三種類の実引数・一般の定理の適用を示し、宣言を持たない具体のプログラムでも前提を満たす例を置いた | 実質 |

型・値・閉じた範囲の三種類の実引数を持つ別名の展開について、R5 の表層の受け持ちを済みとする。関数由来の開いた範囲を別名へ渡す形だけは、従来どおり群 K の後の未了である。`P.VarianceValid` は既存の `Pred.Declared.typesOnly` が欄の宣言の移送に使う構文上の検証であり、新しい信頼条件ではない。`AliasDecl.expand_annotation_monomorphic` は既存の読者と署名を保つ。

01-12 に値の取り出しと別名の形成の定義・言明を写し、07-04 の対応を一般の別名の展開へ揃えた。`verify.py` の変更範囲の一覧に、依頼文が本番の定義と同時の更新を求める 01-12 を加えた。その他の照合条件は変えていない。核の規則・固定済みの判断の署名・主な言明・提供範囲は変更していない。

### 局所検査

Lean のプロセスは同時に一つとし、全て `-M 12288` を指定した。途中の `Desugar.lean` の .olean は一時領域だけへ出力し、既定のビルド出力は上書きしていない。その像を読む `Property1Base.lean`・`Property1.lean`・`ScopedProof.lean` と、新しい五構成子の例を抜き出した入力は終了0。`Aliases.lean` も終了0、警告なし。途中の構文・暗黙引数・具体例の証明の誤りは局所検査で直した。最大常駐量は計画上の非採取により未取得である。既定ビルド・監査・照合の結果は下に記す。

### 宣言の完全名

変更した定義:

- `Benitoite.Release.Refinement.Surface.Expr.valueOf?`

追加した公開の定義・定理・構造:

- `Benitoite.Release.Refinement.Surface.AliasDecl.typeContext`
- `Benitoite.Release.Refinement.Surface.AliasDecl.instantiatedContext`
- `Benitoite.Release.Refinement.Surface.AliasTypeArgs`
- `Benitoite.Release.Refinement.Surface.AliasDecl.subst_formation`
- `Benitoite.Release.Refinement.Surface.AliasDecl.expand_annotation`
- `Benitoite.Release.Refinement.Surface.sizedPathAlias`
- `Benitoite.Release.Refinement.Surface.sizedPathAlias_wellFormed`
- `Benitoite.Release.Refinement.Surface.sizedPathAlias_typeArgs`
- `Benitoite.Release.Refinement.Surface.sizedPathAlias_args`
- `Benitoite.Release.Refinement.Surface.sizedPathAlias_expand_annotation`
- `Benitoite.Release.Refinement.Surface.Examples.negDecimal_singleton`
- `Benitoite.Release.Refinement.Surface.Examples.negIntegers_singleton`
- `Benitoite.Release.Refinement.Surface.Examples.negFloat32_singleton`

追加した private の補助定理（生成宣言も監査の対象に含む）:

```lean
_private.Benitoite.Release.Refinement.Surface.Aliases.0.Benitoite.Release.Refinement.Surface.alias_declared_apply
_private.Benitoite.Release.Refinement.Surface.Aliases.0.Benitoite.Release.Refinement.Surface.alias_declared_eff
_private.Benitoite.Release.Refinement.Surface.Aliases.0.Benitoite.Release.Refinement.Surface.alias_declared_tel
_private.Benitoite.Release.Refinement.Surface.Aliases.0.Benitoite.Release.Refinement.Surface.alias_declared_types
_private.Benitoite.Release.Refinement.Surface.Aliases.0.Benitoite.Release.Refinement.Surface.alias_declared_tys
_private.Benitoite.Release.Refinement.Surface.Aliases.0.Benitoite.Release.Refinement.Surface.alias_sorted_apply
_private.Benitoite.Release.Refinement.Surface.Aliases.0.Benitoite.Release.Refinement.Surface.alias_sorted_eff
_private.Benitoite.Release.Refinement.Surface.Aliases.0.Benitoite.Release.Refinement.Surface.alias_sorted_tel
_private.Benitoite.Release.Refinement.Surface.Aliases.0.Benitoite.Release.Refinement.Surface.alias_sorted_types
_private.Benitoite.Release.Refinement.Surface.Aliases.0.Benitoite.Release.Refinement.Surface.alias_sorted_tys
```

### 最終検査と取りまとめへの申し送り

既定ビルドと公理監査は `formal/` から指定の `lockf -t 3600 <共有ロック>` の下で各一度実行した。既定ビルドは対象を指定していない。

| 検査 | コマンド（共有ロックの下では、その内側のコマンド） | 結果・外側の時間 |
|---|---|---|
| 既定ビルド | `lake build` | 終了0、1,365ジョブ。11:37:17〜11:47:20、602.842秒。変更した表層のモジュールの警告なし。既存の変更していないモジュールの警告は残る |
| 全宣言の公理監査 | `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l70/d/axioms.lean` | 終了0。11:47:28〜11:47:42、13.956秒。対象3,605件（追加したモジュールの宣言2,315件、private 556件）。公理なし1,897件、propextだけ606件、propextとQuot.sound 75件、三公理1,027件。許可した三公理の外の公理とsorryAxはない。必須の名前83件 |
| 記録の照合 | `python3 docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l70/d/verify.py --tmp <tmp>` | 一度実行し終了0。11:47:55、0.322秒。既定import、変更範囲、全宣言と公理、禁止の形、記録の大きさ、24ソースのSHA-256を照合し、`audit-summary.json`を更新した |

生の出力は一時領域へ置き、ビルドは52,360バイト・SHA-256 `0b90f3318cad7b12b9d8e1517f63c60e18c03f5e806405a1d6b4c37f71995081`、監査は1,234,232バイト・SHA-256 `ec08e9a4d15dddf72f12acbe821a876aa7291747793f04712935152957d81cc1` である。最大常駐量は計画上の非採取により未取得。所要は待ちを含む外側の時間であり、能動時間とは分けていない。

二件の処置を完了した。新たに取りまとめの判断を求める点はない。関数由来の開いた範囲を別名へ渡す形は、群 K の後の追随に残す。01-12 の写しの追加に伴う照合対象の追加以外に、今回の範囲の変更はない。独立レビューの記録は変更していない。`scripts/check.sh` と Git の操作は行っていない（指定された `verify.py` 内の読み取りによる Git の照会だけを実行した）。

終了: 2026-11-06 11:48:55 JST。全体の外側の所要: 24分10秒。

## 群 D の作業末の work の検査（取りまとめ）

- 基準: `49f17471442229baf668e7b1f7b6dac8151c6dcf`（HEAD と一致）。作業木は再レビューの残りの処置の後の未コミットの状態（worktree）。並行の群 K と錠で順番を取った。
- 事前に `formal/.lake/build/lib/lean/Benitoite/Release/Refinement` と `formal/.lake/build/ir/Benitoite/Release/Refinement` を消した。
- コマンド: `scripts/check.sh --level work --base 49f17471442229baf668e7b1f7b6dac8151c6dcf`（`/usr/bin/time -l` で測定）。選ばれた検査は spec_tally・spec_examples（01-12 の変更による）・formal_build。
- 終了状態 0（selected checks passed。spec_examples は 7 件成功）。外側の時間 965.78秒（11:50〜12:06）、最大常駐量 4,236,165,120 バイト。
- 生の記録は `<tmp>` に置いた（6,624 バイト、SHA-256 `015fc69a6a6cb064293f575de776222468cae415fd6276769b566bc5da07a6ab`）。
- 計画からのずれ: なし。検査の後に変えたのは RV-L70.d.md の追記と本節だけである（Lean と設計書は変えていない）。

## 再開5（範囲パラメータを持つ利用者の関数）

許容の保存の反例を確認して停止した。[停止の根拠](resume5-obstruction.md)と[詳細・時刻・検査](resume5-7-details.md#再開5範囲パラメータを持つ利用者の関数)を参照。

## 再開6（範囲パラメータを持つ利用者の関数、案 A）

署名自身の範囲の有効範囲が必要な反例を確認して停止した。[停止の根拠](resume6-obstruction.md)と[詳細・時刻・検査](resume5-7-details.md#再開6範囲パラメータを持つ利用者の関数案-a)を参照。

## 再開7（範囲パラメータを持つ利用者の関数）

三つの形の規則と全具体化の性質1を実装した。既定ビルド・4,590宣言の公理監査・照合は終了0。[詳細・時刻・検査](resume5-7-details.md#再開7範囲パラメータを持つ利用者の関数)を参照。独立レビュー RV-L70.d2 は重1・中2・軽2を指摘した。処置は[結合の記録](../d-int/results.md)に記す。

### 葉の条件と合成表

表中の新しい条件は、開いた表層の使用箇所の葉に置いた。表全体への独立した信頼条件にしていない。

| 葉の条件 | 一度の有限な検査・供給元 | 全具体化の葉又は形成への接続 |
|---|---|---|
| `Primitive` | 開いた型・行の形成と個数、元の正規化した型引数の許容、行・Q・NoFailを `OpenLeafFormation.PrimitiveCheck` にまとめる | `RangeStandard.primitive_of_check` が `admits_instR` を読み、全欄を供給。任意の表の範囲閉の型引数には `OpenLeafFormation.primitive_of_closed` |
| `Satisfies` | 元の開いた型の正規形に `SatAll` を一度照合する | `RangeStandard.satisfies_of_check` → `sat_range_norm` → `sat_instR`。範囲閉の型引数には `OpenLeafFormation.satisfies_of_closed` |
| `Admits` | 開いた深さの型・行、元の `SatAll`、個数・行・Q・NoFailを `OpenLeafFormation.AdmitsCheck` にまとめる | `RangeStandard.admits_of_check`。範囲閉の型引数には `OpenLeafFormation.admits_of_closed` |
| `Signature` | 元の依存列の開いた深さでの `WF`、型・行と具体化結果の `AnnotationR`、kindを `OpenLeafFormation.SignatureCheck` にまとめる | `OpenLeafFormation.SignatureCheck.sound`。具体化と型・行の代入の交換、注釈の形成保存を使う |
| `MethodRows` | `OpenLeafFormation.MethodRowsCheck` が開いた行の形成と個数・宣言の行・Q・NoFailを読む | `OpenLeafFormation.MethodRowsCheck.sound` |
| `ExternalAdmits` | 当該外部署名の `tparams=[]` と元の `ExternalCallAdmissible` | `OpenLeafFormation.external_of_check`。単相の外部署名では型引数列が空なので任意の表で成立する |
| `RangesAdmit` | 標準表では種類列との `RangeArguments` と `RangeStandard.RangeCheck`（全Top・一引数の対象操作・widenの被覆又は外側Top） | `RangeStandard.ranges_of_check`。任意の表の固定範囲には `OpenLeafFormation.ranges_of_fixed`。`RangeIx.Covers.inst` を使い、未束縛の変数をTopに替えて受理しない |
| `Annotations`・`RowAnnotations` | 型と行の `AnnotationR`。群 E の `CheckOpenFormation` が深さ付きの `wfTy`・sort・宣言・kindを検査する | `OpenSurface.annotation` と `OpenLeafFormation.SignatureCheck.sound` が、同じ具体化の注釈へ移す |
| 範囲引数の種類と上限 `RangeArguments` | `.rvar` の位置と種類、固定範囲の整形式・正準形・種類を要素ごとに照合する | `RangeArgument.close`・`OpenSurface.ranges_fit_close` |
| 組込みの `PrimSig.Scoped` | 使用する署名の深さ・型と行の形成・kind・宣言の検査 | 標準表は `StandardModel.sig_scoped`。範囲の部分は `RangeStandard.signature_ranges` |
| 関数の依存列の宣言した深さでの `RangesScoped`・`WF` | 当該関数の署名の有限な形成 | 標準表は `RangeStandard.function_formation` |
| 操作・メソッドの依存列の範囲深さ0の `RangesScoped`・`WF` | 当該署名の有限な形成。効果の原子の範囲は `OpenRangeFormationCheck.tel` で支持を走査する | 標準表の操作・型クラス・実装は `RangeStandard.declarations_empty`。利用者の宣言は当該署名を検査する |
| 辞書の型列と実装の対象型、構成子の欄の形成 | 型の構造の検査。必要な範囲閉性は `OpenRangeFormationCheck.ty`、型列は `tys`、効果は `eff` で検査する | 各 `_sound` が `RangesScoped` を供給する。標準表の実装は空で、構成子は `StandardModel.cons_scoped` |
| 照合・パターン束縛の `PatternRangesClosed` | 全構成子の有限一覧について欄の範囲閉性を検査し、一覧の完全性で全lookupへ戻す | 標準表は `RangeStandard.pattern_ranges_closed`。群 E の本番の検査は、完全性とBool成功から葉を供給する |
| 節の署名の範囲閉性 `ClauseSyntax` | 各引数型と結果型を範囲深さ0で検査する。正規形を要求しない | 標準の組込みの節は `RangeStandard.clause_formation`・`OpenStandardClauses.standard_clauseSig_prim`。利用者の操作も同じ有限な閉性を検査する |
| 当該外部署名の依存列の `RangesScoped 0` | `OpenRangeFormationCheck.tel` による当該署名の検査 | 標準の固定表に外部宣言がないことは `RangeStandard.external_signature_formation`。利用者の外部宣言を持つプログラム全体は除かない |

全名の接頭辞は `Benitoite.Release.Refinement.Surface.`（核の補題 `StandardModel`・`RangeIx.Covers.inst` を除く）である。群 E の具体の接点と最終の検査の結果は[結合の記録](../d-int/results.md)を参照する。元の保存補題を例だけから読む形にはせず、上表の標準表の導入補題が本番で合成する。

全377組込みのlookupについて、許容と制約の保存を証明した。この二条件によって渡せなくなる標準の組込み名・型引数の形は0件である。標準操作の節についても、範囲閉性を満たさない署名はない。外部関数の葉は、当該外部署名に未宣言の範囲変数が残る形を受けない。外部宣言を持つP全体を除く条件は置いていない。この外部宣言の条件と、標準の固定表の充足は区別して受け入れ時に確認する。

`OpenPatterns` はパターンの型付け・`Exhaustive`・`ViewExhaustive` の範囲写像と具体化の保存を証明する。具体化で型を満たす値の形が増える場合は、同じ値を戻すのではなく、元の型の別の値へ反映し、述語の確定値とパターンの成功を保つ。将来の拡張では、範囲を持つ未知の欄だけを同じ欄数の任意の値を含む関数型へ写し、既存の宣言と公開の診断の宣言を保つ。網羅性を全具体化で仮定し直す条件は加えていない。

### 言明の差

266件の台帳と、結合・再開5・6を含む開始時の全308言明を比較した。既存306言明は同じで、変更は次の2件だけである。いずれも新しい種類列を読むことで元の言明が一般には偽になり、列の対応又は空の列の宣言を加える差である。

| 入口 | 元の署名 | 新しい署名・強いられる理由 | 元の形に戻る場合 |
|---|---|---|---|
| `desugarProgram_ranges` | 脱糖した関数のlookupから `d.rkinds = []` | 表層の対応するfdのlookupも受け、`d.rkinds = fd.rangeParams`。非空の列を核へ写すため、常に空という結論は偽 | `desugarProgram_ranges_no_ranges` が、表層の全関数の種類列が空のとき、元のkernel lookupから空の列を返す |
| `Declarations.realizes_no_ranges` | 核の全関数の種類列が空なら、Realizesと元の四条件が同値 | 表層の全関数の種類列が空という宣言hsも受ける。対応の定義が `rkinds = fd.rangeParams` なので、核だけが空では対応を導けない | 表層と核の種類列がともに空のとき元の四条件との同値を返す |
| `desugar_typed`・`Def.WellTyped.desugar`・通常の `BodyTy.desugar` | 元の型保存の言明 | 同じ。定義の `WellTyped` が宣言の範囲文脈を読む変更は、前記の表に明記した | `Def.wellTyped_no_ranges` と `bodyTyR_nil` が元の名前・kind・注釈・本体の形を返す |
| `HasTypeQ.desugar`・列・腕・節・ブロック、`CallHeadTy.app_value`・`glue` | 元の表層の性質1の言明 | 同じ。新しい開いた判断の保存は `OpenSurface` の別の入口 | 元の入口をそのまま使える |
| `AliasDecl.expand_annotation` など別名の旧入口 | 閉じた範囲の形成と展開の言明 | 同じ。開いた範囲の入口を別に追加 | 元の入口をそのまま使える |
| `ScopedProof` の19言明と `BodyTy.scoped` | 範囲深さ0の元の言明 | **すべて同じ**。一般化した証明は `_ranges` 名へ分け、旧名は元の署名の系として残した | `NoRangeScopedExamples` の19例と `Examples` の本体の例が旧名へ直接適用する |

範囲のない部分も含む、定義・構文・規則の差は次のとおりである。署名の308件の照合とは分けて記す。

| 定義・規則 | 元の形 | 現在の形と理由 | 範囲のない場合 |
|---|---|---|---|
| `Expr.primName` | 範囲欄は `List Scope.Domain.Range` | `List RangeIx`。開いた添字と `RangeExpr` の固定範囲を保持する | 旧列 `rs` は `rs.map (RangeIx.fixed ∘ RangeExpr.absolute)` |
| `Expr.funName` | 範囲欄なし | 省略可能な `List RangeIx := []` を末尾に持つ | 空の列で元の呼出し形 |
| `Expr.funDicts` | 範囲欄なし | 辞書・実名・引数型の後に同じ範囲欄を持つ | 同上 |
| 通常の `CallHeadTy.prim` | 絶対範囲の列を具体化 | 閉じた `RangeExpr` 列を `RangeIx.fixed` で包み、`B.RangeAdmissible` と `Tel.instR` を読む。`based`・`secrets` も受ける | 絶対範囲を埋め込めば元の前提・結論を得る |
| 通常の `CallHeadTy.fn` | 具体化前の `fd.tel` で署名を照合 | `RangesFit rs fd.rangeParams`、`rangeTel rs fd.tel`、ソースのfixed列を要求する | `fd.rangeParams=[]` なら個数条件から `rs=[]`、`rangeTel [] fd.tel=fd.tel` |
| 通常の `CallHeadTy.fnDicts` | 同上、辞書を持つ | 同じ範囲の適合と具体化を、辞書の本数・実名・型の条件と併用する | 同上 |
| `CallHeadTy` を読む通常の `E_Fun`・`E_FunDicts` と直接呼出し・pipe・部分適用 | 関数に範囲欄なし | 同じ頭を通じて範囲欄を保持する | 範囲欄が空のとき元の頭を読む |
| `directCallee`・`desugarExpr` | 関数の範囲引数を持たない | 関数の範囲欄を核の `Val.fnRef` へ渡す。組込みの範囲欄は `RangeIx` のまま渡す | 空列又は旧絶対範囲の埋込みで元の値 |
| `desugarDef` | 核の `rkinds=[]` | 表層の `d.rangeParams` を保持する | 空列なら元の定義 |
| `Def.WellTyped` | 通常の `Annotation` と `BodyTy` | 種類列の下の `AnnotationR` と `BodyTyR` | `Def.wellTyped_no_ranges` |
| `Program.WellFormed.defs` | `SignatureScoped` と深さ0の本体の `Scoped` | `SignatureScopedR` と `nr=d.rangeParams.length` の本体 | `Program.wellFormed_no_ranges` が他の四欄も含めた元の五条件との同値を返す |
| `Declarations.Realizes.ranges` | 核の種類列が空 | 対応する表層の `fd.rangeParams` と一致 | `Declarations.realizes_no_ranges` |
| `Expr/Block/Clauses/DictEv` 等の `Scoped` | 範囲深さ0 | 省略可能な範囲深さ `nr:=0` を持つ | 引数を省けば元の意味。既存のスコープの定理の署名は保つ |
| 通常の `HasClausesQ.cons` | 発行専用の節も受ける | `ClauseAllowed` を要求し、選んだ組込みの一覧の発行専用の節を断る | 効かない形の拒否という承認済みの差。利用者の操作を断らない |
| 開いた `HasClausesQ.cons` | 各引数型と結果型の範囲閉性と正規性を要求 | 範囲閉性だけを要求し、正規形の等しい文脈を移送する | `HasClausesQ.closed` が空の種類列で通常の全節列を受ける |


一般化19件は `DictEv.Scoped.toVal`・`DictEv.ScopedList.toValList`・`directCallee_scoped`・`recordUpdateValues_scoped`・`exitCall_scoped`・`recordUpdateValues_scoped'`・`spreadFinish_scoped`・`JoinTy.scoped`・`JoinPartsTy.scoped`・`InterpTy.scoped`・`holeTypes_scoped`・`argVals_scoped`・`fixedShift_scoped`・`HasTypeQ.scoped`・`HasFixedQ.scoped`・`HasTypesQ.scoped`・`HasArmsQ.scoped`・`HasClausesQ.scoped`・`HasBlockQ.scoped` である。これらの旧headerは開始時のSHA-256と一致する。`ScopedList nt ne nv ds` の旧呼出し形も、追加のnrをdsの後の省略可能引数に置いて維持した。

`resume7-signature-differences.json` は2件を一行ずつ元・新の指紋で記録する。`resume7-signatures.json` は開始時の308件、266件の元の台帳は結合の記録を読む。前段の固定した核の署名と主な十言明には差を作っていない。

