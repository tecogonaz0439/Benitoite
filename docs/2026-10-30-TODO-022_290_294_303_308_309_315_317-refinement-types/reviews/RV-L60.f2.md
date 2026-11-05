# RV-L60.f2: L60 群 F2（L60.26〜.29、証拠のある構造値・本体・IO と合成）の独立レビュー

2026-11-05。対象はブランチ `m014/l60.f2` の未コミットの作業木である。基準は `25ea27a0f15bd9010e302bde340c7f1cd767319b` で、HEAD と一致する。本書の `<repo>` はレビュー対象の worktree、`<tmp>` は指定の scratchpad、C は本書を置く改造ディレクトリを表す。本レビューは群 F2 の本レビュー一回であり、再レビューが必要な場合は重・中の処置の確認に限る。

読んだもの:

- 依頼文 `L60.f2-prompt.md` の作業・完了条件・守ること・止める条件と、[担当の報告](../l60/f2/results.md)。
- `l60/detail.md` の第2.4節（四分類）・第2.5節・F07、L60.26〜.29、群 F2 の完了条件、第5節・第6節の該当する H・S・O 行、停止条件。`l60/tables.md` の E01〜E15、三モデル75欄、Rust の登録部分と四照合の条件。
- `l60/a/standard-contract.md`、ledger-01〜11.json、evidence・rust・conditions の分割記録、resume3-body-classification.json、本体の証拠の型と集計の台本。`l60/f1/ledger-diff.json` と、[前例のレビュー](RV-L60.f1.md)の初回部分と処置の記録。
- worktree の `plan.md` の「全 L 作業の停止条件」と「計画の変更と取りまとめへの確認点」。本体の作業木の同節の先頭にある、2026-11-05 の群 F2 の判断点六つとレビュー回数の決定。言語の目的と保証の範囲は 00-01 で確認した。
- `l60/f2/` の全十一 Python 台本、axioms.lean、tables-check.json・conditions.json・ledger-diff.json・assumptions.json・body-methods.json、保存された宣言と依存、読者・入力ハッシュ・ビルド・公理監査・照合の記録。
- `git diff 25ea27a0 -- formal docs/design` と、新規十二モジュール `StandardModelCollectionRows`・`StandardModelListBodies`・`StandardModelCoreBodies`・`StandardModelSafeBodies`・`StandardModelCollectionBodies`・`StandardModelProgram`・`StandardModelIORows`・`StandardModelSubstitution`・`StandardModelCoreRows`・`StandardModelScoped`・`StandardModelCore`・`StandardModelWellFormed`。比較対象として、各既存 response、通常の core・List・getter・別名・安全な入口の証明、`StandardKeyTyping.Table`、`StandardModelResponse`、`CoreAssumptions`・`ResponseAssumptions`・`TargetAgreement` の定義を読んだ。
- 独立集計の入力として、tables.md が指定する L40 の全 API 行・演算子行、現行 Lean の有限リストと名前の定義、Rust の `funcs::PARTS` と各登録配列を読んだ。

本書以外のリポジトリ内のファイルは変更していない。git の書き込み操作、`lake build`・cargo・`scripts/check.sh` の実行はしていない。Lean は `<repo>/formal/` から `lake env lean -M 12288 <file>` で一つずつ実行し、`-o` は使っていない。確認用ファイルとログは `<tmp>/rv-l60-f2/` に置いた。verify.py など記録を書き換える台本は実行せず、読んで判定した。既定ビルドと全環境の公理監査は担当の保存記録と生出力を照合し、本レビューで新たに実行した検査とは区別した。大きな具体値を作る評価はしていない。

## 結論

**条件付き可**（重0・中2・軽2・情報2）。

本番の主な言明、全場合の量化、既存証拠の合成範囲に、群 F2 の結論を妨げる誤りは見つからなかった。`core`・`targets`・`body_typed` は任意の externals について成り立ち、`program_typed`・`program_wellFormed` は同じ任意の externals の `ExternalWF` を受け取る。純粋な全361行、全130本体、9 kind、28+1欄は同じ合成表の上で構成されている。新規十二本と変更済み八本のソースの写しは、単独 Lean で全て通った。

条件は、最終の仮定一覧へ群 F1 の訂正を反映すること（中1）と、閉じた三欄の四分類を定義に合わせて直すこと（中2）である。両方とも記録と集計の修正であり、主な言明・型付け・Step・提供範囲の変更を求めない。保留15欄と96行の入力証人を群 G の L60.32 で確定する割り当ては、最新の取りまとめ判断として認める。

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|---|
| 中1 | 中 | `l60/f2/tables_check.py` の最終台帳の構成と149行以降、`assumptions.json` の L518（282行以降）と by_kind、results.md「仮定側の全名前と理由」 | 群 F1 の差分の `moved` は重ねるが、`corrected` にある L518 `Process.exit` の理由の訂正を重ねていない。そのため、最終の一覧へ「専用の遷移」という古い分類と理由を戻し、IO応答46・専用の遷移1と報告している。F1 は、同じ ioResponse を読む exit を δ・IO応答のない専用遷移から区別し、IO応答の仮定へ訂正済みである。150名と合成・仮定の境界は変わらないが、R50 への理由と内訳が誤る | F2 の台帳構成で F1 の `corrected` も適用し、L518 の kind・detail・reason を IO応答の仮定へ揃える。assumptions.json と results.md の内訳を δ80・IO応答47・通常資源の状態16・形式化の外7・専用の遷移0へ直す。前の群の記録は変更しない | 読めば確定 |
| 中2 | 中 | `l60/f2/conditions.py` の `state_effect`・`ref_get`・`ref_set`、conditions.json の同三欄、results.md「欄の四分類」 | この三欄を「前提を持たない閉じた命題」であることを理由に実質へ数えている。`state_effect` は任意の P で `rfl`、参照二欄は固定の署名を証人にし、固定表の lookup の証明だけで閉じる。入力の型・形・応答の証拠に依存しないため、第2.4節の自明の定義に当たる。単に証明が短いという判定ではなく、同じ固定の証人と閉じた証明を任意の P へ使えることを確認した | 同三欄を自明にし、他の判定を保持した場合の内訳を実質9・自明5・保留15へ直す。理由・集計・報告を揃え、群 G の全欄の照合へ渡す。前段の75欄などをこの修正のために書き換えない | 読めば確定、実行で確定（検査3） |
| 軽1 | 軽 | `StandardModelProgram.lean` 175行の example の docstring | 「外部関数を持つ宣言表でも」とあるが、実際の適用例は `program []` である | 空の外部宣言表の例と書くか、説明に合う非空の例にする。全称定理は既に成立している | 読めば確定 |
| 軽2 | 軽 | `StandardModelSafeBodies.lean` の `annotation_17`（206行）・`annotation_18`（217行）と declarations_annotation の候補列 | 言明と証明がそれぞれ annotation_01・annotation_03 と同じで、先行候補が成功するため完成した証明からの依存もない | 後の二補題と到達しない候補を除く | 読めば確定 |
| 情報1 | 情報 | conditions.json の保留15欄・行の契約96行、最新の取りまとめ判断(1)、L60.32 | 15欄と96行は契約の証明未完ではなく、同じ合成表の上で前提を満たす入力証人をまだ確認していない状態である。保留の解消は群 G へ明示的に割り当てられている | L60.32 で入力証人と四分類を確定する。中2の三欄の訂正も引き継ぎ、保留を実質や空疎へ推測で移さない | 読めば確定 |
| 情報2 | 情報 | `constructorNames`・precisionProvider・collectionProvider、最新の取りまとめ判断(3) | Map・Set・%Map.replaceValues は既存の算法に合成プログラムの構成子の並びを渡す。新しい算法の定義はないが、処理系の構成子の順序との一致は、この Lean の型付けだけでは示していない | 決定済みの R50 の照合対象として、同じ構成子の順序と鍵の符号化を保持する。本レビューで Rust の意味との一致まで確認したとは扱わない | 読めば確定 |

## 観点ごとの根拠

### 1. 主な結論と全場合の量化

`StandardModel.core externals` は、同じ `program externals` と `builtins (program externals)` に対し、置換8・外部3・応答4・独自13の全28欄を構成する。`targets externals` も同じ P/B の `TargetAgreement` を返す。任意の externals を先に量化し、外部宣言が空であるという仮定はない。使わない `hw` を除いた core・definition_typed は、元の `hw` を受ける形からも適用できる。

`program_typed externals hw` は変性を `variance_valid`、全定義を `definition_typed`、外部宣言の検証を `hw` で供給する。`program_wellFormed externals hw` は、同じ全定義の Scoped、全構成子の DataArity と Scoped、空の操作・クラス・実装・dataInfo、外部宣言の検証を構成する。WellTyped と WellFormed を別の小表の成功で代用していない。dataInfo が空であることだけで変性全体を済ませず、全構成子の欄の注釈・kind・既定の変性も `variance_valid` で証明している。

`body_typed` と `body_scoped` は、Body の b001〜b130 の全場合を持つ。成功した任意の defs lookup は `lookup_body` でこの同じ Body へ戻るため、特定の公開名や八本の試行だけに結論を限っていない。`Def.scoped_of_typed` は、型付けから注釈と kind を読み、別に証明した `BodyScoped` から行・範囲・本体の深さの条件を供給する。WellFormed のために型付けを仮定へ戻す循環はない。

検査1では、任意の externals の core・targets・全 Body の型付け・ExternalWF の下の WellTyped/WellFormed を一つの命題として適用した。元の definition_typed の形、種類 pure の任意の行、種類 io/exit の任意の行、任意の Body の Scoped も適用できた。代表十二定理の公理依存は許可された三公理だけであった。

### 2. 純粋行・本体・9 kind の範囲

純粋な79行は、F2 の分類台本を使わず、E01 の String・Bytes・List・Map・Set の actual_builtin と E14 の %Map.replaceValues から名前の期待集合を作った。これが Primitive.collection、collection_rows の全場合、F2 の接続記録の集合と一致した。族別は String26・BytesOrdinary13・Map8・Set8・Bytes5・List5・ListRemaining5・precision4・headTail2・replaceValues1・append1・range1で79である。

`PureRow.of_response` と `PureRow.of_row` は、合成表の同じ lookup へ署名を戻し、同じ provider の δ について既存 response を適用する。新しい表の BuiltinArgs を、旧表の BuiltinArgs へ無条件に読み替えていない。Option の構成子と arity、MapSetDeclarations、鍵の Table、VarianceValid は合成プログラムから供給する。応答の型と AdequateResult は任意のストア・全引数の既存の結論を保持する。部分表の table_response の使用はない。

純粋な全体は、数値166・演算子109・collection79・scopePure7の交わらない四集合で361行となる。最後の7は範囲付き6と %List.getFront である。`pure_classes` が、種類 pure の任意の Primitive をこの四集合のいずれかへ戻す。`pure_rows` はその分類から同じ PureRow の契約を供給する。有限の代表例から361行への外挿はしていない。

本体の三種と方法は、群 A の全130本体の分類、body_typed の各枝、body-methods.json を照合して一致した。

| 元の証拠の三種 | 合成表での方法 | 件数 |
|---|---|---:|
| 任意の P/B 2 | head と toList の既存の任意 P/B の証拠を直接使う | 2 |
| 副条件付き51 | 記録型の宣言を受ける一般化を getter の内部・公開へ使う | 24 |
| 副条件付き51 | 通常 List の helper と公開五組へ Inputs を供給する | 10 |
| 副条件付き51 | 通常・精密 List 八本、通常・精密 Map/Set 八本、非空 map 一本の証明の構成を合成先で閉じる | 17 |
| 固定の P/B 77 | 別名51・通常 core10・Pair 二射影を一般化した証明へ合成先の副条件を供給する | 63 |
| 固定の P/B 77 | 安全な入口四本と精密 getter 九本を合成先で閉じる | 13 |
| 固定の P/B 77 | 同じ head 本体である Internal.NonEmptyList.head へ任意 P/B の証拠を直接使う | 1 |

合計は一般化87・副条件の供給10・写し30・直接3で130である。通常・精密の同名本体は群 A のキーと名前の写像を保ち、通常側に精密な toList を使う箇所では、部分型の忘却を実際の型付け導出として構成している。一般の表拡張の単調性は使っていない。core の Context、List の Inputs、Records は、同じ合成表の宣言・署名・参照 lookup から供給される副条件である。

377組込みの種類の内訳は pure361・io9・exit1・pathBases1・refGet1・refSet1・refNew1・refUpdate1・force1であり、9 kind を覆う。IO/exit の10行は、全 BuiltinArgs と全ての同じ IO応答の関係について、型・適格性・kind・対象を示し、同じ関係の応答存在も返す。response_classes は io_kind の前提に kind がなくても、実際に IO応答を持つ行をその10行へ戻す。発行の八欄と効果の所属、参照・明示遅延五行の StoreShape と専用遷移、通常資源 File.Handle の解放も同じ P/B で読む。io_exists と external_exists は別の関係と欄のままである。

### 3. 四照合と最終台帳

E01 は指定の L40 の全 rows、E02 は ordinary=pure-leaf、E03 は全 operators から再集計した。他の集合も、tables.md が名指す ScopeSignatures、三モデルの entries、bodyRows、PreciseGetter.all、coreRows、allDefinitions の構成を確認した。E01〜E03 の名前の多重集合も群 A の出典記録と一致した。

| 出典 | 独立に確認した件数 |
|---|---:|
| E01 | 328（pure244・core84） |
| E02・E03・E04 | 73・34・2 |
| E05・E06 | 6・7 |
| E07・E08・E09・E10 | 3・15・7・1 |
| E11・E12・E13・E14・E15 | 7・9・11・1・48 |
| 延べ出典行 | 552 |

群 A の640親行へ F1 の三移動と F2 の一移動を重ねると、合成490・仮定150となる。全552出典行は合成側へ対応し、対応なし・仮定側への対応は0であった。75条件は三モデルの25欄ずつの別集合として保持され、群 E の同じ欄と読者へ対応する。552へ75や130本体を重ねて加算していない。

各合成親行の name_correspondence と helper_correspondence、差分による追加から lookup を独立に集めると、377署名・130本体・資源名1の508キーとなった。空の対応を持つ合成親行はなく、表のキーと集めたキーの双方向の差集合は空である。F1 の275接続と F2 の233接続の和集合も同じ508キーになる。F1 で移した三署名は F2 のストア五行の内数であり、もう一度加算しない。F2 の233接続は215親行に属するので、親490と子508を同じ意味の件数として扱っていない。

仮定150行の証拠名・出典行・名前の対応は空で、出典の名前の集合及び合成表の組込み名・本体キーとの交わりも空であった。Rust は PARTS の61部分から各配列の DECL 参照を読み直し、http_client::PURE_DECLS は checked_request::DECLS へ展開した。配列ごとの順序・参照名・添字の523件は群 A の Rust 記録と全件一致し、全て親台帳へ対応する。最終の分類は合成373・仮定150である。

この四照合の件数は正しい。ただし、名前と分類だけを重ねた現行の tables_check.py は、F1 の理由の訂正を反映していない。中1はこの最終台帳の内容に関する所見であり、552・490・508・523の計算自体の誤りではない。

### 4. 前段の署名・規則・意味への影響

既存の公開定理の宣言を開始版と比較すると、getter_reference の承認済みの置き換えを除き、名前と型は保持されている。StandardAliasBodies.body_typed の型の字面にあった private の P は program へ置き換えられたが、元の P は program の定義なので型は同じである。getter_typed・projection_typed・通常 core の body_typed は、一般化した補題を元の条件へ適用する形で残っている。通常 List の Inputs は構成子表全体の等号から必要な Option の宣言へ弱められ、元の読者へその宣言が供給されている。

definition_typed と core の hw の除去は、前提を弱めて結論を保つ承認済みの変更である。program_typed と program_wellFormed の hw は実際に external 欄へ使われるので残る。検査1でも元の hw を受ける全称の形から definition_typed を適用できた。外部宣言の構造検証の変更や、新しい意味上の仮定の追加はない。

ByteOrder は Bytes の署名が読むデータ宣言の追加で、arity と全構成子の形成の証明も同じ表で供給される。precisionProvider と collectionProvider は、既存の mapDelta・setDelta・StandardMapReplaceValues.delta の引数を constructorNames へ揃える。既存の算法の本体は変更していない。provider 全体の補完の枝に依存せず、採用した各 row の名前の δ について既存 response を当てている。処理系の構成子の順序との照合は情報2の境界である。

%List.getFront は E11・E12 の本体の参照先であり、既存の StandardSafe.front_response が同じ frontSig/frontDelta の全 BuiltinArgs の契約を持つ。合成側へ移した L489 は提供範囲を狭めず、既存証拠を仮定側へ移して済ませたものでもない。仮定側の Process.exit と、合成表の既存モデルの exit は混同していない。Process.exit の理由の記録だけが中1に該当する。

追跡差分に旧 Release、主な十言明、型付けの規則、Step の規則の変更はない。一般の P を外部宣言なしへ制限する変更、篩付き入力・全 σ・任意ストアの量化の削減、精密な外部状態の新設も見つからなかった。利用者 P への収集・切替と Rust/Lean の全比較を今回済ませたとは記していない。

### 5. 四分類と後段の受け口

不成立と空疎を0とし、未確認の入力証人を保留へ残す方針は、最新の取りまとめ判断に従っている。delta_typed の前提は群 F1 の numeric_inputs・operator_inputs で同じ表の上に満たせる。sig_scoped、発行と IO の形、操作と効果、StoreShape の非空な場合も、合成表の lookup と分類から確認できる。release_exists は resource_input による型付きの File.Handle と、資源値の正準形を使う release_all を読む。全値に none を許す関係へ戻していない。

一方、前提のない三欄を実質に置くことは、中2のとおり分類の定義と合わない。検査3は、state_effect を rfl で閉じ、ref_get/ref_set には固定の Primitive.p279/p280.signature を証人にして、P に依存しない `row_lookup (program [])` を使えることを示した。これらは任意 P について成り立つが、入力の型・形・応答の証拠を使う欄ではない。「表の内容を読む」という説明だけで実質へ移すと、同じ記録で自明とした sat_unconstrained との判定基準も揃わない。

保留15欄は置換8・external_typed・external_no_targets・admits_sat・io_typed・io_kind・io_exists・io_targetである。保留96行は純粋86（collection79・範囲付き6・front1）と IO/exit10で、conditions.json の行の集合・件数は一致する。これらの契約は全場合で証明されている。L60.32 での入力証人と分類の確定を残しているという説明は適切であり、保留であることを証明不能や空疎と扱わない。

H03/H04/H19、O022/O034/O035/O049 は同じ δ・要求・応答の既存証拠を合成表で読む受け口として残る。H06/S01/S17/O065 は全署名の PrimSig.Scoped、全本体の SourceScoped、StoreShape と操作の種類により供給される。H09/H10 は ModelConstraints の保存則を再利用し、独立の sat_local を加えていない。S04 の算法一致と S19 の生 lambda/closure の差の照合は群 G の担当として明示され、型付けだけから算法一致や全実行の健全性を主張していない。主定理の合成・切替は L70、実登録と鍵の順序・仮定側の名前の比較は R50 に残る。

### 6. 公理・上限設定・写し・記録

新規十二モジュールの本文に sorry・新しい axiom・native_decide・#eval・#reduce はない。既定 import の閉包をソースから独立に辿ると1066モジュールで、新規十二本は全て入る。担当の全環境監査の生出力と記録のハッシュは一致し、対象85,209宣言とその公理出力の対応も全件一致した。許可された propext・Classical.choice・Quot.sound の外、sorryAx、新しい公理は0である。今回の十二モジュールの1151宣言の分割記録と保存された型のハッシュも一致した。本レビューでの十二定理の公理検査も同じ範囲である。

新しいモジュールに残る上限設定は maxHeartbeats の五箇所だけで、maxRecDepth は残っていない。対象は CoreBodies の toList_typed、ListBodies の from_body、CollectionBodies の精密側の設定と通常側の list_function、CoreRows の io_classes である。検査4で、現在のソースから各一箇所だけを外すと、五箇所とも既定の200000で deterministic timeout になることを確認した。現行の証明には設定が必要である。設定値の最小性や速度の最適性までを判定する検査ではない。

公開入口の読者と適用例は、保存された依存と本番の使用箇所から確認した。private の候補にはマクロの展開器や帰納型の生成宣言もあるので、単なる参照名の出現回数0を誤りとしなかった。手で書いた二つの注釈補題については、言明・証明の同一性と完成した証明の依存を確認し、軽2にまとめた。

01-12 の追加二段落と07-04の追加段落・対応表は、全純粋行、IO、全本体、置換、署名の形成、28+1欄、WellTyped/WellFormed、ByteOrder と構成子の並びの現行定義に対応する。ExternalWF の必要な前提も分けて書かれている。差分は今回の追加箇所だけで、工程の ID、四分類の件数、未実施の全比較を成功とする記述を足していない。

群 A〜F1 の記録に差分はない。F2 の記録は40ファイル・1,486,952バイトで、最大97,933バイト、各100 KB 以下である。tools.json が記録する38入力の大きさと SHA-256 は現在のファイルと全て一致した。記録を書き換える台本の成功を、本レビューでの独立集計や Lean の証明の代用にはしていない。

## 実行した検査

全て指定の worktree で行い、Lean の同時実行は一つに限った。

| 番号 | 内容・入力 | 結果 |
|---|---|---|
| 1 | `<tmp>/rv-l60-f2/Main.lean` を `lake env lean -M 12288` で検査。任意 externals の主な五入口、元の definition_typed の形、全 pure・io/exit 行、全 BodyScoped の適用と、代表十二定理の `#print axioms` | 終了0。公理は許可三公理の範囲内 |
| 2 | 新規十二本・変更済み八本のソースをそのまま `<tmp>/rv-l60-f2/` へ写し、各ファイルを `lake env lean -M 12288 <写し>` で順次検査 | 20本全て終了0、出力・警告なし。合計513.15秒、最長134.63秒。既定のビルド出力は上書きしていない |
| 3 | `<tmp>/rv-l60-f2/ClosedFields.lean`。任意 P の state_effect を rfl、ref_get/ref_set を固定の署名と固定表の lookup で構成 | 修正後終了0。中2の三欄が入力の前提を読まずに閉じることを確認 |
| 4 | 現在のソースから残る上限五箇所を一つずつ外した写しを、同じ単独 Lean で検査 | 五試行とも200000 heartbeats で deterministic timeout。合計146.60秒。設定を保持したソースの成功は検査2で確認済み |
| 5 | 記録を変更しない Python の独立集計。指定の L40 の入力、現行の Lean の有限リスト・全場合の枝、群 A の台帳と F1/F2 の差分、Rust の全登録配列、保存された依存とハッシュを照合 | 出典552・合成490/仮定150・lookup508・Rust523・純粋79・全本体130が一致。中1・中2、軽2は本文のとおり |
| 6 | 読み取りだけの git の照会、ソースの import 閉包、禁止した構文・追加された写し・記録サイズ・入力ハッシュ・保存された監査の生出力を照合 | 基準HEAD・新規十二本の既定import・前の群の記録不変を確認。既定ビルドと公理監査の保存ログの大きさ・ハッシュが一致 |

検査3の初稿二回は、確認用入力で使った識別子の誤りと、lookup の等式を rfl だけで済ませようとしたため失敗した。既存の row_lookup の固定表での証明を使う形へ直して通った。本番ソースの失敗としては数えていない。

| 上限を外した場所 | 外した値 | 結果 | 所要 |
|---|---:|---|---:|
| StandardModelCoreBodies 100行 | 4000000 | deterministic timeout（whnf） | 13.39秒 |
| StandardModelListBodies 918行 | 800000 | deterministic timeout（whnf） | 24.17秒 |
| StandardModelCollectionBodies 11行 | 4000000 | deterministic timeout（isDefEq） | 27.71秒 |
| StandardModelCollectionBodies 608行 | 2000000 | deterministic timeout（simp） | 68.32秒 |
| StandardModelCoreRows 33行 | 4000000 | deterministic timeout（whnf） | 13.01秒 |

## 取りまとめの追記

2026-11-05。群 F2 は Claude の実装担当が実装し、独立レビューは Codex が行った（plan.md の担当の割り当ての決定）。レビューは設計者の決定に従い本レビューの一回とし、再レビューを起こさなかった。中1・軽1・軽2は再開1で処置し、取りまとめが `assumptions.json` の内訳（δ80・IO応答47・通常資源の状態16・形式化の外7）と前の群の記録が変わっていないことを確かめた。中2は、`state_effect`・`ref_get`・`ref_set` を実質に数える判定が L50 で受け入れた分類と plan.md の群 E の取りまとめの判断に従うので直さず、群 G の L60.32 の照合へ論点として渡した。情報1（保留15欄と行の契約96）は群 G の L60.32 が入力の証人を足して確定する。情報2は R50 の照合の対象である。処置の後に取りまとめが `scripts/check.sh --level work --base 25ea27a0f15bd9010e302bde340c7f1cd767319b` を実行し、終了0（877.69秒）であった。
