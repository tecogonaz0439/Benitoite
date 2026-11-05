# L70 群 U の結果（L70.01・.02）

ブランチ `m014/l70.u`、B_WORK `657b3ae713040e78826d2f19cd7b8ac9f415a6d6`。実装担当（Claude、Opus 5.5）の記録であり、独立レビュー済みを意味しない。git の操作と `scripts/check.sh` は行っていない。

## 単位の時刻

| 単位 | 開始 | 終了 | 外側の時間 |
|---|---|---|---|
| 読み込みと開始状態の既定ビルド | 2026-11-06 01:43:13 | 2026-11-06 01:49:51 | 6分38秒（既定ビルドは錠の下で約6分） |
| L70.01 | 2026-11-06 01:49:51 | 2026-11-06 02:36:23 | 46分32秒（調査、土台、07-04 の写し、群末の検査を含む） |
| L70.02 | 2026-11-06 02:03:00 | 2026-11-06 02:12:00 | 約9分（L70.01 の区間の内数） |

外側の時間は能動時間と待ち時間を分けていない。L70.01 と L70.02 は交互に進めたので、L70.02 の行は対応のモジュールを書いて単独の検査を通すまでの区間である。

## 結論（初回の報告）

この節から「取りまとめに判断を求める点」までは初回の報告（停止の時点）の記録である。停止は再開1で解除した（「再開1」の節）。

- **L70.02 は完了した。** 公開名と内部名・依存列の行・合成表の鍵・組み込み・述語の構成子・型の対応を `R/PublicNames.lean` に置いた。`PrimSig.admits` は `List TParam → List Ty → Prop` なので、`Refinement.check` の型引数 `[T, U]` の形（正規形で `U` が `T` に篩を一つ付けた型）を述語 `checkAdmits` で書ける。型付けの規則を足す必要はない。
- **L70.01 は土台まで行い、`.atError` の値の観測と照合を公開形へ切り替える前で止めた。** 停止条件「U02 の回答に依存する公開形の選択」に当たる。旧 API の `Http.checkRequestIn` が静的添字の拒否で返す At の診断の元の入力を、U02 で決めた公開の `Scope.AtInput`（Text と Pattern の二構成子）で表せない（次節）。
- 土台として、公開の20型（19の data と record、`Scope.PathBases`）の宣言、内部の値からの写し、同じ `P.cons` での型付け・観測・鍵・網羅性、公開形を持つ準備と検査の失敗を `R/ScopePublic.lean`・`R/ScopePublicTyping.lean` に置いた。どの代案でもこの土台を使う。

## 停止の理由

### 読めば確定する食い違い

`R/RequestDelta.lean` の `staticError`（private）は、旧 API `Http.checkRequestIn` の δ（`RequestDelta.run`）が、検査済みの端点が型の範囲の添字 `bound` に入らないとき、又は添字が `based`・`secrets` のときに返す誤りである。

```lean
private def staticError (pattern : String) (lo hi : Integer64Value) (req : Val)
    (checked : Checked.Scope.CheckedEndpoint) : Val :=
  .atError (AtError.save (.list [.const (.string pattern),.const (.integer lo),.const (.integer hi)]) req
    none (some (.absolute (.endpoint (checkedPattern checked))))
    (req.reqTarget.map TargetInput.absolute) .staticIndex)
```

`run` は `error r (scopeError (staticError pattern lo hi req checked))` として `Http.RequestCheckError.Scope(Scope.ScopeError.At(d))` を返す。この `d` の元の pattern は三つ組の列 `[pattern, lo, hi]`、元の対象は要求の値（`Http.ClientRequest` の構成子の値）である。U02 の決定では `Scope.AtInput` は `Text(String)` と `Pattern(RangeExpression)` だけを持ち、`Request` を公開しない。したがって、この診断の元の入力は公開形に写せない（`ScopePublic.inputOfVal` は両方に `none` を返す。`ScopePublicTyping` の例）。

あわせて、旧 API の `Scope.checkPathIn` の δ（`ScopeDelta.run`）も、型の範囲の添字に入らない対象に `Scope.ScopeError.At(d)`（`failure = .staticIndex`）を返す（`ScopeDelta.staticError`）。こちらの元の入力は文字列なので公開形に写せる。ただし、U02 の決定（README「設計者の決定」2026-11-05 の (2)）は理由として「旧 API は旧6構成子だけを、At API は At だけを返す」と述べており、L50 で受け入れた Lean の δ と食い違う。

### 差

現在の内部の観測（`Detail.textFields` の七欄の文字列）は元の入力を観測しないので、この食い違いは表に出ていない。公開形の九欄は元の入力を `Scope.AtInput` で読むので、`.atError` の観測を公開形へ切り替えると、旧 Http の静的拒否の診断について何を観測させるかを決める必要がある。決めないと照合の値（`Detail.values`）を全値で定義できず、`V_AtError` は全ての診断を型付けるので、型付け・照合・網羅性の全体が閉じない。

### 代案

| 案 | 内容 | 影響 | 所要（能動時間、見込み） |
|---|---|---|---|
| A | 旧 API（`Scope.checkPathIn`・`Http.checkRequestIn`）の静的添字の拒否を旧6構成子で返す。U02 の (2) の理由に合わせる | δ の変更。静的添字の拒否と動的な不所属を旧 API では区別できなくなる（D61 は At の失敗について両者の区別を保存すると定めている）。どの旧構成子へ写すか（`OutsideScope`・`PortOutsideScope` など）の選択が別に要る。`ScopeDelta`・`RequestDelta` の拒否の証明と読者の追随 | 1〜2時間＋切替の本体 |
| B | 旧 API は At を返したまま、元の入力が公開形を持たない診断を代わりの値で観測させる（例: 要求の URL や pattern の文字列を Text にする） | 公開の観測が保存値の一部を落とす。D61 の「保存値を切り詰めない」は保存値には保たれるが、利用者は要求の5欄と端点の範囲を読めない | 切替の本体だけ |
| C | `Scope.AtInput` に要求の構成子を戻す（U02 の Q1・S16 の選び直し） | Scope と Http の import の循環を、candidates.md S16 の B（`ClientRequest` を Scope 側へ移し Http に別名を置く）か C（第三のモジュール）で解く必要がある。公開型の数と完全な宣言が変わる | 30分〜1時間＋切替の本体 |
| D | 旧 Http の静的拒否が保存する元の入力を、Text と Pattern で表せる形（pattern の文字列と URL の文字列）に変える | 保存値の変更（D61 の要求の5欄の保存に反する） | 1時間＋切替の本体 |

どの案でも、核の At（`Comp.checkAt`）は種類 endpoint で要求の値を対象に取れる。公開の入口（`Scope.checkPathInAt`）はパスだけなので、この経路の診断は公開されないが、`.atError` の観測は全値で定める必要がある。この内部の経路の元の入力をどう観測させるかも、切替のときに決める（公開の選択ではないが、記録に残す）。

切替の本体の所要は、能動時間で4〜7時間と見込む（実測ではない）。触るのは、`Detail.values` と `Val.toTerm?` の `atError` の枝（Syntax）、`atErrorFields`・`ResultShape.StandardError`（AtContracts。`Program.HasScopePublic` を足す）、AtTyping・AtPatterns・AtErrorReaders・AtTargets（`Detail.originals_unobserved` は公開形では成り立たないので、元の入力を `AtInput` で読む言明へ改める）・MatchFacts・PatternBindingSupport・PatternBindings・PatternMatchAnnotations・PatternBindingsAdequate・PatternBindingsGround・CanonicalValues・CaptureApplicationAlgebra・TypedFacts・StandardKeySound・LegacyPatternMatch・LegacyPatternCoverage・LegacyPatternExamples・LegacyEmbeddingExamples・LogicKernelExamples・NormalReplyExamples・ScopeDeclarations・ScopeDelta、合成表の宣言を列挙する証明（StandardModelDeclarations・StandardModelWellFormed・StandardModelCollectionRows）の約28ファイルである。合成表は19型の宣言を足し、`AtFailure.outsideScope` は返す枝がないので内部の型から除けば写しが全域になる（`AtPrepare.no_outsideScope`・`ScopePublic.checkAt_no_outsideScope`）。実用への影響は、案を決めるまで At の失敗の診断を利用者が型付きで読めないことである。言明（主な10言明）・公理・型付けの規則・提供範囲は、切替で変える必要がない。

## L70.01 で置いたもの（土台）

宣言の数は群末の公理監査で数えた（下の「検査」と `audit-summary.json`）。

| 定義・定理 | 内容 |
|---|---|
| `ScopePublic.declarations` | 新しい19の公開の data と record の宣言（構成子と欄の型）。`scopeErrorDecl` は旧6構成子と `At(AtDetail)` |
| `ScopePublic.declarations_shape`・`fields_declared`・`record_fields`・`field_names` | 19型、52構成子、名前の重複なし、欄が読むデータ名がすべて宣言にあること、record の欄の名前と欄の数、改めた欄の名前 |
| `ScopePublic.PublicTree`・`PublicTree.Typed` | 公開の値の木と、宣言の欄の型への型付け（静的） |
| 写し（`pathBaseTree` から `targetInputTree`、`atFailureTree?`、`detailTree?`） | 内部の型の構成子を一対一に公開の構成子へ写す。単語は文字列の列、IP の値は網のバイト順のバイト列、ポートと接頭辞の長さは Integer |
| `ScopePublic.detail_typed`・`detail_public`・`atFailure_public` | 元の入力の写しが AtInput の型を持てば九欄の公開形は AtDetail の型を持つこと、公開形がある条件（`outsideScope` 以外、元の入力が写せる） |
| `ScopePublic.names`・`names_cover`・`pathBaseNames`・`pathBase_names` | 内部名と公開名の19行の対応、PathBase の5構成子とパス変数の綴り |
| `Program.HasScopePublic`・`Program.ScopePublicComplete` | 公開の宣言の全体と Option を同じ `P.cons` に持つこと、19型に宣言にない構成子がないこと |
| `PublicTree.Typed.val`・`toVal_toTerm`・`Typed.observed`・`toVal_ground`・`toVal_adequate`・`Typed.key` | 同じ P での型付け、項の観測の一致と `Term.Declared`、閉性、全環境の適格性、鍵の観測 |
| `constructor_match`・`constructor_exhaustive` | 構成子のパターンの全欄の束縛と、19型の構成子のパターン列の網羅性 |
| `ScopePublic.program`・`program_public` | 公開の宣言と Option だけを持つプログラムが両条件を満たす（適用例） |
| `inputOfVal`・`checkAt_no_outsideScope`・`prepare_public`・`check_public` | 文字列か解析済みの pattern を元の入力に持つ準備と検査の失敗が公開形を持つこと |
| `AtPrepare.no_outsideScope`（既存の AtPrepare に追加） | 準備の失敗は `outsideScope` を返さない |

## L70.02 の対応

| 区分 | 件数 | Lean の定義 |
|---|---:|---|
| 安全な入口の行（既存15、まとめた2、新しい2） | 19 | `PublicNames.safeEntries`。行名は `InternalContracts.all` と同じ順（`safeEntries_rows`）。まとめた2行は同じ依存列（`unified_same_tel`）。衝突18名の行は精密側の鍵（`collision_refined`）。合成表の鍵の lookup（`composed_lookup`）。精密側の本体を持たないのは `safeTail`・`NonEmptyList.tail` の2行（`composed_missing`） |
| 起点・発行・At | 3 | `pathBasesType`（`Ty.pathBases`）、`processPathBases`（内部名 `ScopeSignatures.pathBasesName` = `Example.pathBases`、`C_IssuePathBases` の前提の形を `processPathBases_signature` で確かめた）、`checkPathInAt`（`Comp.checkAt .path "Scope.PathIn" ScopeDelta.resultShape`） |
| 一般の check | 3 | `checkName`、`checkErrorDecl`（`Refinement.CheckError { expected: String }`）、`checkAdmits`（受理1・拒否2の例）。名前は既存の表と重ならない（`check_names_fresh`） |
| Float と Float32 の分類 | 7名 | `floatClasses`・`floatPredicate`。6類と一対一、`isInfinite` は二類の `or`。足す名前は Float 6・Float32 5（`float_names`） |
| 述語へ写す関数 | 4 | `charactersInPredicate`（リテラルの両端）、`memberPredicate`（`Scope.pathMatches`・`Scope.hostMatches`、リテラルの絶対形で種類が合うときだけ）、`constructorPredicate` |
| 公開型の名前（L70.01） | 19＋PathBases | `ScopePublic.names`、PathBase の5構成子、record の欄6、改めた欄5 |

確かめた結果と残り:

- `checkAdmits` の置換の契約（`admits_rename`・`admits_values`・`admits_renameTypes`・`admits_subst`・`admits_sat`）は、δ の行を合成表へ入れる単位（L70.38）が閉じる。`Ty.substAt_norm_source`（置換は正規化を吸収する）から、`u.norm = (Ty.refined t p).norm` の形は型の置換の後も同じ形の `p` で保たれると見込む（未証明）。
- 合成表の発行の内部名は `Example.pathBases` であり、公開名 `Process.pathBases` との対応は表で持つ。内部名を改めるかは R40 の判断とする。
- `safeTail` と `NonEmptyList.tail` は合成表に精密側の本体を持たない（L60 の合成表の範囲）。依存列（`InternalContracts.safeTail`）は持つ。

## 義務・申し送りの判定

| 行 | 内容 | 判定 | 証拠 | 残る段 |
|---|---|---|---|---|
| L50-H20 | Detail 九欄から公開 shape・reader へ | 部分 | `ScopePublic.detailTree?`・`detail_typed`・`PublicTree.Typed.observed`・`constructor_exhaustive`。`.atError` の観測の切替は停止 | 切替（停止の解除後）、R30/R60 |
| L50-H21 | `ResultShape.Declared`・`Program.StandardErrorComplete` の公開写し | 未了 | 公開側の条件 `Program.HasScopePublic`・`Program.ScopePublicComplete` は置いた。`ResultShape.StandardError` と `StandardErrorComplete` は内部の七欄のまま | 切替、R60 |
| L50-受口2 | Detail・AtError・ResultShape・StandardErrorComplete の公開形（J50-1） | 部分 | 同上 | 切替 |
| U02-署名 | 新しい関数の完全署名 | 完了（L70.02 の分） | `PublicNames` の全定義と定理 | δ の行は L70.37・.38 |
| O097 | At 用の公開構成子と Detail の写し | 部分 | 同 L50-H20 | 切替、R30/R60 |
| O142 | NonEmptyList の篩付き別名と公開名の対応 | 部分（L70.02 の分は完了） | `safeEntries`・`unified_same_tel` | L70.19、R10b/R40/R50/V10 |
| O143 | `Range.getFrom` の対応 | 部分（L70.02 の分は完了） | `safeEntries` の `sameLengthGet` 行と `composed_lookup` | L70.19、R10b/R40/R50/V10 |

## 条件と前提の四分類

正常値で前提を満たす入力の証人は、`ScopePublic.program`（`program_public`）と `ScopePublicTyping` の末尾の例（文字列の元の入力の準備の失敗、起点のない secrets の検査の失敗）で示した。

| 条件・前提 | 分類 | 証人 |
|---|---|---|
| `HasScopePublic` の5欄（arity・cons・Option の arity と二構成子） | 実質 | `program_public.1` |
| `ScopePublicComplete` | 実質 | `program_public.2` |
| `detail_typed` の元の入力の型付けの前提 | 実質 | `inputOfVal_typed` |
| `detail_public` の三前提 | 実質 | 末尾の例（`prepare_public` の前提） |
| `prepare_public`・`check_public` の元の入力の前提 | 実質 | 末尾の例 |
| `constructor_exhaustive` の完全性 | 実質 | `program_public.2` |

不成立・空疎・自明に当たる前提はない。

## 計画からのずれ

- L70.01 を切替の前で止めた（前節）。
- 依頼文の範囲を広げた点: 返す枝のない `AtFailure.outsideScope` を公開しないことの根拠として、既存の `AtPrepare.lean` に `AtPrepare.no_outsideScope` と private の補題2つを足した（内部の補助の補題の追加）。既存の行は消していない。
- 前段の署名は変えていない。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 開始状態の既定ビルド | `formal/` で錠の下の `lake build` | 0 | 約6分（1330 jobs、85件を再ビルド） | 生の出力 49621 バイト、SHA-256 `530f75185f7ad0d26934848c5c7b639fe92ef2a7534927b05589d7ba24ca98ee` |
| 途中の既定ビルド（AtPrepare の変更の後） | 同上 | 0 | 12分11秒（1333 jobs） | 群末の検査の前に古くなった |
| 単独の検査 | `lake env lean -M 12288 <file>`（一時の場所の olean を使い、既定の出力を上書きしない） | 0 | 1件数秒 | — |
| 群末の既定ビルド | 同上 | 0 | 8秒（1333 jobs。足した三つを再ビルド） | `audit-summary.json` の `build` |
| 公理監査 | 錠の下で `lake env lean -M 12288 l70/u/axioms.lean`（`formal/` から） | 0 | 12秒 | `audit-summary.json` の `axioms` |
| 照合 | `python3 l70/u/verify.py --tmp <tmp>` | 0 | 1秒未満 | `audit-summary.json` |

公理監査の対象は、足した三つのモジュールと補題を足した `AtPrepare` の全宣言（private・生成宣言を含む）856件である。足した宣言は、三つのモジュールの667件（ScopePublic 361、ScopePublicTyping 211、PublicNames 95）と AtPrepare の3件の、計670件である。公理の組は、なし565、propext 168、propext と Quot.sound 20、三公理103で、許可した三公理の外の公理と sorryAx はない。必須の名前81件はすべて対象にある。`verify.py` は、B_WORK からの変更の範囲（追跡済みの変更は AtPrepare・根の import・07-04 だけ、未追跡は足した三モジュールと本ディレクトリだけ）、根の import に三つが一度ずつ現れること、AtPrepare の差分が追加だけであること、足したモジュールの警告・`sorry`・`#eval`・工程の ID がないこと、記録の大きさと手元の絶対パスと docs/todo へのリンクがないことを照合した。

`scripts/check.sh` の work は取りまとめが群末に実行する（Lean と文書だけの群なので formal_build と文書の検査が選ばれる見込み）。01-12 は規則を変えていないので写しを変えていない。07-04 は足したモジュールの段落2つと表の2行を足した。

## 取りまとめに判断を求める点

1. 停止の解除: 代案 A〜D のどれを採るか（設計者の判断）。U02 の (2) の理由と L50 の δ の食い違いをどう扱うかを含む。
2. 切替の担当と枠: 切替の本体（約28ファイル、能動時間4〜7時間の見込み）を群 U の続きとして行うか、群 A の前に別の単位として置くか。
3. 内部の要求の At の経路（核の `Comp.checkAt` で種類 endpoint）の診断の元の入力の観測の扱い（公開の選択ではない）。
4. `AtFailure.outsideScope` を内部の型から除くか（返す枝がないことは示した）。除けば写しが全域になる。

## 再開1

2026-11-06 02:44 開始。設計者が代案 A を選んだ（本体の作業木の plan.md「計画の変更と取りまとめへの確認点」の先頭）。取りまとめの指示で、(1) δ の変更（案 A）、(2) 切り替えの本体、(3) 申し送りの記録を行った。

| 単位 | 開始 | 終了 | 外側の時間 |
|---|---|---|---|
| 再開1-1 δ の変更（案 A） | 02:44 | 02:53（既定ビルド終了0） | 9分 |
| 再開1-2 切り替えの本体 | 02:53 | 03:47（既定ビルド終了0） | 54分（既定ビルド6回の待ちを含む） |
| 再開1 群末の検査と記録 | 03:47 | 03:58 | 11分（既定ビルド2回と監査の待ちを含む） |

### 1. δ の変更（案 A）

旧 API の二つの δ が、結果の型の静的な範囲に入らない値を拒否するときに、At(StaticIndex) でなく旧構成子を返すよう改めた。Step の構成子・前提・量化と型付けの規則は変えていない。

| δ | 拒否の枝 | 返す値 |
|---|---|---|
| `Scope.checkPathIn`（`ScopeDelta.run`） | 絶対形の上限に入らない、上限が記号付き（based・secrets） | `OutsideScope(pattern, target)`。動的な不所属と同じ `ScopeDelta.errorValue … (.outsideScope …)` で作る（`ScopeDelta.staticError`） |
| `Http.checkRequestIn`（`RequestDelta.run`） | 同上 | 上限が端点の条件でホストが合う（ポートだけが外れる）とき `PortOutsideScope(上限の minimum, 上限の maximum, 端点の port)`。それ以外（ホストが外れる、上限がパス・ホストの種類、記号付き）は `OutsideScope(元のホスト条件, ホストの綴り)`。どちらも `ScopeDelta.errorValue` で作る（`RequestDelta.staticError`） |

変えた δ の行は2（拒否の枝は各2、計4）。読者は ScopeDelta の6（`staticError`・`static_safe`・`run_safe` の静的拒否の3枝・`run_absolute` の言明・例3）、RequestDelta の5（`staticError`・`static_safe`（新）・`run_safe` の2枝・`run_endpoint` の言明・例1を新設）である。ModelTargetsApplications の例は `run_absolute` の Ok の枝だけを読み、本文は変えていない。読者のなくなった `RequestDelta.checkedPattern`（private）を除いた。新しい例は、ポートだけが外れる端点が上限のポート範囲の `PortOutsideScope` に、ホストが外れる端点が `OutsideScope` になることを示す。01-12「…の具体の δ」の2段落と 07-04 の該当の段落を直した。

### 2. 切り替えの本体

`.atError` の観測と照合、`ResultShape.Declared`（`ResultShape.StandardError`）、網羅性を公開形へ写した。

- 核（Syntax）: `Detail.publicTree`（九欄の公開形。公開形を持たない診断は固定の値 `ScopePublic.unreachableTree`）、`Detail.values = [d.publicTree.toVal]`、`Val.toTerm?` の `atError` の枝、`ScopePublic.PublicTree.toVal`・`inputOfVal` を置いた。`Detail.textFields`（reprStr の七欄）を除いた。
- AtContracts: `atErrorFields = [atDetailType]`、`Program.HasScopePublic`（公開の宣言の全体と Option を同じ `P.cons` に持つ）を `ResultShape.StandardError` の4つ目の条件にした。
- 宣言の表: `ScopeDeclarations.http` に Option と19の公開の宣言を足した（`base` は従来の宣言）。合成表は19の宣言を構成子の並びの最後に置き、既存の構成子の並び（Map・Set の鍵の順序が読む）を保つ。Option は標準の宣言を使う。
- 返す枝のない内部の `AtFailure.outsideScope` は内部の型から除いていない（取りまとめの判断）。準備と検査の失敗がこの種別を返さないこと（`AtPrepare.no_outsideScope`・`ScopePublic.checkAt_no_outsideScope`）と、内容型を持たない名前の At では型付きの状態の閉じた元入力が文字列か pattern であること（`StateTyE.at_public_inputs`）から、その At の準備と検査の失敗は固定の値でなく AtDetail の型を持つ九欄の公開形で観測される（`StateTyE.at_prepare_public`・`StateTyE.at_check_public`、公開の入口の形について `PublicNames.checkPathInAt_public`）。
- 要求の At: 公開の入口 `Scope.checkPathInAt` は内容型を持たない名前 `Scope.PathIn` を使い、要求の名前 `Http.RequestIn` は内容型を持つ（`PublicNames.at_names`）。固定の値で観測されるのは、公開の入口を持たない要求の At の失敗に限られ、その観測は公開形の対象にしない。
- 元入力の観測: 公開形では元入力を AtInput で観測するので、`Detail.originals_unobserved`（元入力を任意に置き換えても観測が変わらない）は成り立たない。`Detail.originals_observed`（公開形が同じ元入力への置換は、九欄の公開形・項観測・束縛列の項観測を変えない）に改めた。

#### 前段の署名の差（J50-1 の写しとして取りまとめが指示した変更）

| 宣言 | 前段（L50 など） | 今 |
|---|---|---|
| `Detail.textFields` | 七欄の reprStr | 削除（`Detail.publicTree` に置き換え） |
| `Detail.values` | 七つの文字列の値 | `[d.publicTree.toVal]` |
| `Val.toTerm?` の `atError` | 七つの文字列の欄 | 一つの公開形の欄 |
| `atErrorFields` | String が7 | `[atDetailType]` |
| `ResultShape.StandardError` | 3条件 | `Program.HasScopePublic` を加えた4条件（`.2.2` を読む読者は `.2.2.1` へ） |
| `ResultShape.Declared.error_data`・`error_observation_declared` | 七欄の項 | 公開形の項 |
| `Detail.values_typed`・`Detail.match_pattern_typed` | 前提なし | `P.HasScopePublic` を前提に足す |
| `atErrorPattern` | 変数7 | 変数1 |
| `Detail.originals_unobserved` | 任意の置換で不変 | `Detail.originals_observed`（公開形が同じ置換で不変） |
| `atError_declaration`（PatternBindingSupport） | ConDecl の3条件 | `P.HasScopePublic` を結論に足す |
| `ScopeDelta.result_declared` | `HasFile P` | `HasHttp P`（読者を `PublicNames.checkPathInAt_result` に置いた） |
| `ScopeDeclarations.http`・`program` の証明 | 5宣言・列挙の証明 | 既存5に Option 1と新公開19を足した25宣言（追加20）、名前の重複のない表からの一般の証明 |
| `StandardModel.declarations` | 末尾が RoundingMode | `baseDeclarations ++ ScopeDeclarations.publicDecls` |
| 例のプログラム（LegacyPatternExamples の `oldProgram`、NormalReplyExamples の `modelProgram`、LogicKernelExamples の欄の例） | At だけ・七欄 | 公開の宣言と Option を持つ。欄の例は `InvalidPattern` の文字列の欄を使う |

主な10言明・Step の構成子・型付けの規則の構成子（`V_AtError` の本文を含む）は変えていない。公理は足していない。

#### 足した宣言

足したモジュールは4つ（ScopePublic・ScopePublicValues・ScopePublicTyping・PublicNames）、変えた Refinement のモジュールは33である（監査の対象は追加4＋変更33＝37モジュール）。監査の対象の数は「検査」の表と `audit-summary.json` にある。

### 3. 申し送り

| 先 | 内容 |
|---|---|
| L70.38 | `PublicNames.checkAdmits` の置換の契約（`admits_rename`・`admits_values`・`admits_renameTypes`・`admits_subst`・`admits_sat`）。`Ty.substAt_norm_source` から同じ形が保たれる見込み（未証明） |
| R40 | 合成表の発行の内部名 `Example.pathBases` の改名（公開名 `Process.pathBases`） |
| R30・R60 | 公開形の値（`Detail.publicTree`）を処理系の値・Show・JSON と照合する。旧 API の静的拒否は旧構成子（上の表） |
| R50 | 合成表の構成子の並びの最後に19の公開の宣言を置いた。鍵の順序を処理系の構成子の順序と照合する |
| 後の L70 の単位 | 公開形への写しの単射性（保存値を切り詰めないこと）は証明していない。整数の欄は Integer の上端に飽和する |

### 再開1の検査

初回の「検査」の節の件数は初回の状態のもので、再開1の後はこの表を正とする。

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| δ の変更の後の既定ビルド | 錠の下の `lake build` | 0 | 4分45秒 | 区切りの確認（途中の記録） |
| 切り替えの途中の既定ビルド | 同上 | 1→0 | 6回（各1〜10分） | 失敗は ValueBinding・ScopeDeclarations・LegacyPattern*・NormalReplyExamples・ExternalModelExamples・StandardModel* の追随で、各回に直した |
| 群末の既定ビルド | 同上 | 0 | 4分58秒（1334 jobs） | `audit-summary.json` の `build`（49704 バイト、SHA-256 `19763d30e717f13c045947978cfa69e296f43bcfa67587565342345cd0742b1c`） |
| 公理監査 | 錠の下で `lake env lean -M 12288 l70/u/axioms.lean`（`formal/` から） | 0 | 14秒 | `audit-summary.json` の `axioms`（2023274 バイト、SHA-256 `a5731dfaa2590335e0ff9d577c01e6615db500fe10bb459c28aa594632163d88`） |
| 照合 | `python3 l70/u/verify.py --tmp <tmp>` | 0 | 1秒未満 | `audit-summary.json` |

公理監査の対象は、足した4モジュールと変えた33モジュール（計37）の全宣言（private・生成宣言を含む）5989件（private 1460）である。足したモジュールの宣言は780件（ScopePublic 402、ScopePublicValues 200、ScopePublicTyping 81、PublicNames 97）。公理の組は、なし3770、propext 1256、propext と Quot.sound 106、三公理857で、許可した三公理の外の公理と sorryAx はない。必須の名前124件はすべて対象にある。`verify.py` は、変更の範囲（Refinement のモジュール・根の import・01-12・07-04 だけ）、根の import に4つが一度ずつ現れること、AtPrepare の差分が追加だけであること、足したモジュールの警告がなく変えたモジュールの警告が開始状態の既定ビルドにあったものに限ること、`sorry`・`#eval`・工程の ID がないこと、記録の大きさと手元の絶対パスと docs/todo へのリンクがないことを照合した。

`scripts/check.sh` の work は取りまとめが群末に実行する。01-12 の text の例は変えていないが、01-12 の本文を変えたので spec_examples の選択は取りまとめの dry-run で確かめる。

### 再開1の義務・申し送りの判定

| 行 | 判定 | 証拠 | 残る段 |
|---|---|---|---|
| L50-H20 | 完了（L70 の分） | `Detail.publicTree`・`Detail.values_typed`・`ScopePublic.PublicTree.Typed.observed`・`Detail.originals_observed`・`StateTyE.at_prepare_public`・`StateTyE.at_check_public` | R30/R60 |
| L50-H21 | 完了（L70 の分） | `ResultShape.StandardError`（`Program.HasScopePublic` を含む）・`Exhaustive.atError`・`ScopePublic.constructor_exhaustive`・`ScopeDeclarations.HasHttp.scopePublic` | R60 |
| L50-受口2 | 完了（L70 の分） | 同上 | R30/R60 |
| U02-署名 | 完了（L70.02 の分） | `PublicNames` | L70.37・.38 |
| O097 | 完了（L70 の分） | 同 L50-H20 | R30/R60 |
| O142・O143 | 部分（L70.02 の分は完了） | `PublicNames.safeEntries` ほか | L70.19 |

条件の四分類: `Program.HasScopePublic` の5欄と `Program.ScopePublicComplete` は実質（証人 `ScopePublic.program`・`ScopeDeclarations.program`（`HasHttp.scopePublic`）・合成表（`http_declarations`））。`StateTyE.at_*_public` の前提 `B.valContent name = none` は実質（証人 `ScopeSignatures.builtins` の `Scope.PathIn`、`PublicNames.at_names`）。

## 群 U の作業末の work の検査（取りまとめ）

- 基準: `657b3ae713040e78826d2f19cd7b8ac9f415a6d6`（HEAD と一致）。作業木は再開1と RV-L70.u の処置の後の未コミットの状態（worktree）。
- 事前に `formal/.lake/build/lib/lean/Benitoite/Release/Refinement` と `formal/.lake/build/ir/Benitoite/Release/Refinement` を消した。
- コマンド: `scripts/check.sh --level work --base 657b3ae713040e78826d2f19cd7b8ac9f415a6d6`（`/usr/bin/time -l` で測定）。選ばれた検査は spec_tally・spec_examples・formal_build。
- 終了状態 0（selected checks passed）。外側の時間 810.23秒（04:12:46〜04:26:17）、最大常駐量 4,223,844,352 バイト。
- 生の記録は `<tmp>` に置いた（6,624 バイト、SHA-256 `2273d851818ec5bac674c2627e9f89890064ffdd996b56cc8aabd53e33c44b35`）。
- 計画からのずれ: 最初の起動は基準の ID を誤って渡し、分類の前に終了3で止まった（検査は走っていない）。正しい完全な ID で一度実行した。群末の `verify.py` は群末の記録であり、後から置いたレビューの記録 `reviews/RV-L70.u.md` を未追跡の変更として数えて止まる（plan.md の群の verify.py の扱いのとおり、追随させない）。
