# RV-L60.a: L60 群 A（L60.01〜.05、方式と骨格）の独立レビュー

2026-11-05。対象はブランチ `m014/l60.a` の未コミットの作業木で、基準は `80230d96305756057a63a07dc2b0d8aa1ebf3a75`（HEAD と一致）である。見たものは次のとおりである。
- 本番の変更: `git diff 80230d96 -- formal docs/design`（`formal/Benitoite.lean` の import 5行、01-12 の6段落、07-04 の4段落と表の3行）と、未追跡の11モジュール（`BuiltinTypingTransport`・`ExternalSurfaceLeaves`・`ExternalModelResponse`・`ResourceReleaseModel`・`FunctionNameMap`・`StandardModelDeclarations`・`StandardModelSignatures`・`StandardModelPrimitiveLookup`・`StandardModelResponse`・`BuiltinResponseTransport`・`ExternalModelTransport`）。
- 群 A の記録: `l60/a/` の results.md（初回・再開1〜3）、standard-contract.md、stop.md・resume1-stop.md・resume2-stop.md、resume3-closure-summary.json・resume3-classification-summary.json・resume3-proof-limits.json・resume3-closure-seeds.json・閉包の辺と節点の分割記録・ledger の分割記録、台本（closure_inventory.py・composition_inventory.py・body_classification.py・audit_record.py・verify.py・verify_resume3.py）、検査入力（closure-inventory.lean・body-evidence-types.lean・f-signatures.lean・map-filter-composed-trial.lean の冒頭と末尾）。

読んだもの:
- 依頼と報告: 群 A の依頼文（守ること・止める条件）、再開1〜3の依頼文、各回の担当の報告。
- `l60/detail.md`: 第1.1節 C01〜C18、第2.2節（14判断76枝）、第2.4節（12欄と四分類）、第3節 F01〜F08、第4節の L60.01〜.05 と群 A の行・群ごとの完了条件、第6節の O062・O065・O084・O013・O061 の行、第7節 J60-1〜3。`l60/tables.md` の E05・E07 の行。
- `plan.md`: 「全 L 作業の停止条件」、「計画の変更と取りまとめへの確認点」の先頭の4項目（群 A の途中の取りまとめの判断と L60.27 の見込みの見直し）。
- Lean の既存定義: `Syntax.lean` の `Program`、`ScopeSyntax.lean` の `Detail`、`StandardOrdinaryCoreProgram.lean` の `supportDefinitions`・`program`・`all_lookup_typed`、`StandardActualListBodies.lean` の `program`・`model_typed`。

git の書き込み操作、本書以外のファイルの変更、`lake build`、cargo の実行はしていない。Lean の検査は `formal/` で `lake env lean -M 12288` により行い、確かめのファイルは `<tmp>/rv-l60-a/` に置いた。verify.py・verify_resume3.py・composition_inventory.py などの記録を書き換える台本は実行せず、読んで判定した。全環境の公理監査は再実行していない。大きな具体値を作る評価はしていない。

## 結論

**条件付き可**（重0・中2・軽10・情報4）。

証明の側に、群 A の完了を妨げる誤りは見つからなかった。主な点は次のとおりである。
- 既存ファイルの変更は既定 import と 01-12・07-04 の写しだけで、旧 `Release`・型付けの規則・主な十言明・前段の実署名は変わっていない。新しい11モジュールはすべて既定 import の閉包に入る（直接の import 5本と、`StandardModelResponse`・`ExternalModelTransport` からの推移）。`sorry`・`axiom`・`native_decide`・`#eval`・`maxRecDepth`・工程の ID はない。
- `FunctionNames.value`/`computation` などの相互再帰は全構成子を網羅し、変えるのは `fnRef` の名前だけである（`atError` は `Detail` の二つの `Val` 欄 `originalPattern`・`originalTarget` に再帰し、他の七欄は `Val` を持たない）。`Body.definition` は `FunctionNames.definition (rename body.refined) body.original` と定義され、tel・型注釈・本体の構成子は保たれる。`rename` は18組の交換の合成で、各 `refined` について任意の String 上の単射である（`rename_injective`）。
- 閉包の台本は、159出典と追加の helper の元 Def を `isDefEq` で同一視して130個に数え、全60参照辺で参照先が一意であることと、親の写像後の名前が参照先のキーに一致することを照合する（`composition_inventory.py` の辺の照合）。精密 getter 9個は文脈が通常側でも参照を持たない。共有の `Pair.first`・`Pair.second` は通常側と精密側で同じ元 Def である。
- `definitions_iff`・`signatures_iff` は任意の externals・名前・Def/署名について合成表と有限の表の双方向を示す。F07 の `definition_typed`・`program_typed` は本番に置かれず、記録の `f-signatures.lean` で証明先の命題として定義し、全130本体の証明先との同値と、`VarianceValid` を足して Program の証明先へ進む含意だけを示した。記録・standard-contract.md・01-12・07-04 のいずれも、本体の型付けの完成を主張していない。
- 二つの `maxHeartbeats` は既定値で時間切れになり、必要である（検査2）。代表の8宣言の公理依存は許可三公理の部分集合である（検査1(d)）。

条件は中1・中2の処置である。どちらも読めば確定し、証明の変更は要らない。中1は後段への受け口の欠け、中2は記録と本番の食い違いである。

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 中1 | 中 | `StandardModelDeclarations.lean` の `Body.key`、standard-contract.md「元定義と参照先の閉包」、07-04 の76行・01-12 の3110行 | 衝突18名は通常側も精密側も内部名（`%List.map.ordinary` など）へ付け替えたので、合成表には公開名そのもののキーがない。`(StandardModel.program e).defs "List.map" = none`・`"Range.minimum"` も同じ（検査1(a)）。精密側の公開形は U02 の対象であるが、`List.map`・`Range.minimum` などの通常側の公開 API も合成表の上では公開名で引けない。利用者のプログラム（L70 の収集）が `fnRef "List.map"` を書いたとき、どの段がどの内部名へ写すかが、記録・署名表・写しのどこにもない。また `rename` は交換の合成なので、内部名から公開名へ戻す向きも持つ（検査1(b)）。本体が `%…` の内部名を `fnRef` で参照すると公開名へ写るが、現在の130本体の参照辺にその形はない | standard-contract.md と後段への署名表（L70・U02 の受け口）に、(1) 合成表は18名の公開名をキーに持たないこと、(2) 利用者の公開名から内部名への対応を決める段と、通常側の公開名を U02 の回答に依存させない方針、(3) 本体の参照に `%` で始まる内部名がないことを `rename` の前提として台本で確かめていること、を書く。07-04 の該当段落にも「18名の公開名は合成表のキーに現れない」を一文で写す | 読めば確定、実行で確定（検査1(a)(b)） |
| 中2 | 中 | results.md「再開3」の「群Aの完了条件を量化した照合」の後の段落と「本番の宣言・写し・停止条件」、担当の報告の「新12欄の証明先は、型検査だけを根拠に完成や実質とは数えていない」、results.md「再開2」の義務表の O013・O061 の行 | 本番の `ExternalModelTransport.lean` は、三モデルの拡張表について `ExternalModels.model_core`・`targets_core`・`http_core`（`Builtins.CoreAssumptions`、すなわち新しい12欄を含む）と `TargetAgreement` を、定理として証明している（検査1(c)）。12欄は型検査だけの状態ではない。detail.md では、これは L60.12・.13・.22 の主な出力である。記録はこの到達を書かず、12欄の四分類も確定済みと未確認を分けていない。O013（「75条件・12欄の全合成は未完」）・O061（「外部三条件の全表の束ねは未完」）の再開2の判定は、再開3の後の本番と食い違う。後続の群 C・E の範囲と見込みも、この到達を前提にしていない | results.md に、三モデルの Core と対象条件が本番で閉じたことと、12欄の現在の四分類を欄ごとに書く。証明から読めば、external_exists の3欄は定数 err で自明（確定）、Model・Http の release_exists は `Bool.noConfusion` で空疎（確定）、Targets の release_exists は `canonical` で資源値の形を得るので実質（File.Handle の型付き値で前提を満たす例が `ResourceReleaseModel` にある）。external_typed・external_no_targets の6欄は応答の前提を使うが、正常値で前提を満たす入力は L60.11 まで未確認なので、分類を保留する。O013・O061 の判定を更新し、L60.12・.13・.22 の残りの作業（正常応答の非空性、87欄の照合）と見込みを取りまとめが見直せるようにする | 読めば確定、実行で確定（検査1(c)） |
| 軽1 | 軽 | results.md「再開3の最終検査」の後の段落（「精密側のfrom_bodyだけ既定値での時間切れを確認して局所800000を指定した」） | 本番には `StandardModelDeclarations.lean` の `body_lookup` に `maxHeartbeats 800000`、`StandardModelSignatures.lean` の `Primitive.signature` に `1600000` がある。results.md の文は検査入力の `precise-list-copy.lean` のことで、本番の二つを書いていない（resume3-proof-limits.json の `production` 欄にはある）。二つとも既定値では時間切れになり必要であった（検査2） | results.md に本番の二箇所と、既定値での時間切れの確認を書く | 読めば確定、実行で確定（検査2） |
| 軽2 | 軽 | `FunctionNameMap.lean` の `rename_injective`、`StandardModelDeclarations.lean` の `definitions_iff`・`option_declarations` | 既定ビルドの中に読者も具体の適用例もない。`option_declarations` の読者は記録の `map-filter-composed-trial.lean` だけで、既定ビルドの外にある。01-12・07-04 は「単射」「双方向の対応」を性質として写しているので、本番の入口として読者が要る（依頼文「公開した入口には…具体の適用例か本番の読者を置く」） | 三つを使う `example` を既定ビルドに置く（例えば `rename_injective` から二つの衝突名の内部名が異なること、`definitions_iff` から `"%List.mapFrom.ordinary"` の lookup、`option_declarations []`）。使わないなら private にするか除く | 読めば確定 |
| 軽3 | 軽 | results.md「再開3」の「8本の型付け」の行と担当の報告（「全130本体を置いた実際の合成P/Bでも、同じ8本の型付けを確認した」）、`map-filter-composed-trial.lean` の `program` | 試行の表は `StandardModel.program []` で、外部宣言が空の場合に限る。F07 の証明先は任意の externals を量化するが、記録はこの限定を書いていない。また8本の型付けの証明は既定ビルドの外にあり、L60.27 が同じ証明を本番へ移す作業が見込みに入っているかが読み取れない | 「externals = [] の具体の表で8本を確認した。任意の externals への一般化は L60.27」と書く。8本の証明を本番へ移すなら任意の externals で書く | 読めば確定 |
| 軽4 | 軽 | ledger の仮定側154行の `reason` | 154行の理由は、名前の置換を除くと10種の定型文で、すべて「07-04のBuiltinsのδ・IO応答または専用遷移の条件を定理の引数として量化する範囲に属する」と書く。各行が δ・IO 応答・専用の遷移のどれに当たるかを特定しない。`Reference.new`・`Reference.update`・`Lazy.force`・`Process.exit`・`Task.*`・`TaskGroup.*` は δ や IO 応答でなく専用の操作や遷移に当たりうるので、07-04 の仮定のどの欄で量化されるかを行ごとに示さないと、R50 が照合の相手を決められない | 各行に区分（δ・IO 応答・専用の遷移・通常資源の状態）と、該当する Builtins の欄名（`delta`・`ioResponse`・`refGet` など）を一列で加える | 読めば確定 |
| 軽5 | 軽 | results.md の先頭の「単位の時刻と判定」「停止と未完の範囲」（「群Aは未完である」）、stop.md・resume1-stop.md・resume2-stop.md の冒頭、results.md の義務の判定 | 先頭から読むと、初回の停止（L60.04 停止・L60.05 未着手）が先に現れる。stop.md は resume1-stop.md を「現在の停止」と指すが、resume1-stop.md と resume2-stop.md は再開3で解消したことを指さない。義務の最終判定は再開2の表と再開3の文に分かれ、合わせて読まないと現在の状態が分からない。初回・再開1・再開2の監査の要約（audit-summary.json など）が指す declarations-01.json・signatures-01.json は再開3の監査で上書きされ、SHA-256 が一致しない（検査3）。宣言の写しを群末の一回分にした結果としては正しいが、古い要約に注記がない | results.md の冒頭に現在の状態の要約（L60.01〜.05 の最終判定、引用する正の節は「再開3」）を置く。三つの停止記録の冒頭に「再開3で解消した。現在の判定は results.md の再開3」と一行加える。義務27行の最終判定を一つの表にまとめる。古い監査の要約に「分割記録は再開3の監査で置き換えた」と注記する | 読めば確定、実行で確定（検査3） |
| 軽6 | 軽 | results.md「本番の宣言・写し・停止条件」の「O062/O065/O084は…群Aの担当分を閉じた」 | detail.md 第6節の受け持ちの単位は、O062 が .10/.24〜.29、O065 が .21/.23/.29 で、群 A の単位を含まない。群 A の担当は O084（.01〜.05/.36）である。「群Aの担当分を閉じた」は、O062・O065 の受け持ちが進んだと読める | O062・O065 は「群 A は台帳と全 lookup の入力を用意した。行の判定は変えない」とし、閉じた担当分は O084 に限る | 読めば確定 |
| 軽7 | 軽 | 01-12 の3102〜3110行、07-04 の70〜76行 | (a)「七射影」は 01-12 では定義せずに使う（3102行は七欄を列挙するが名付けない）。用語集・基準の版の 01-12・07-04 にもない。(b)「有限台帳」「台帳」は改造の記録の語で、基準の版の 01-12・07-04 にない。本番の対象は `Body.all`・`Primitive.all` の有限の表である。(c)「合成用Def」も記録の語である。(d) 01-12 の「`selectExternal_response` の関係所属の結論には、元の関係の証人の存在を要求する」の「元の」は、同じ B の関係を指すので誤読を招く。(e) 新しい段落を、節の範囲を定める【決定】の段落（01-12「本節から…は定義と規則の写しである」、07-04「`Benitoite.Release.Refinement` は…を持つ」）より前に置いた | (a) 01-12 で「型付けが読む七つの射影（`Builtins.TypingFieldsEq` の七欄）」と一度定義する。(b)(c) 「有限の本体表（`Body.all`）と組込みの表（`Primitive.all`）」「関数参照名を写した Def（`Body.definition`）」と実名で書く。(d)「同じ関係の証人の存在」とする。(e) 新しい段落を【決定】の段落の後へ移す | 読めば確定 |
| 軽8 | 軽 | `ResourceReleaseModel.lean` の `canonical` の docstring | 「資源の名前を持つ閉じた値は…同じopaque定数である」と書くが、前提は `B.valKind o = none` で、`isResource` を読まない。資源への分類は `typed_response` の前提である | 「対象の値型へ分類されない名前 o の opaque 型に型付く閉じた値は、同じ名前の opaque 定数である」とする | 読めば確定 |
| 軽9 | 軽 | standard-contract.md の副条件の表 | `f-signatures.lean` の `program_target_of_definition` は `VarianceValid` を別の前提として受けるが、副条件の表の「データ」の行は名前・arity・kind・欄だけを挙げ、`dataInfo` と変性を挙げない。`StandardModel.program` は `dataInfo` を `StandardOrdinaryCoreProgram.program` から継承し、`ScopeDeclarations.http` から足した構成子のデータに変性の宣言があるかは未確認である | 表の「データ」の行に `VarianceValid`（`dataInfo` と変性）を加え、供給元を L60.29 と書く | 読めば確定 |
| 軽10 | 軽 | `closure-inventory.lean` の `ordinaryContext`、resume3-closure-seeds.json の `context` | 閉包の参照先は、種ごとに台本が選んだ文脈（通常側148行は `StandardOrdinaryCoreProgram.program` の `List.filter`・`List.filterFrom` を差し替えた `ordinaryContext`、精密側11行は `StandardCollectionRefinedBodies.program`）で引いた。既存の証拠の lookup の前提や、固定の P の証拠ではその P から機械的に読んだものではない。例えば E01.109 の証拠 `StandardActualListBodies.model_typed` は `StandardBodies.ListModel.program` を固定するが、その `List.mapFrom` と文脈の `listMapFromDefinition` が同じことは読めば分かるだけで、台本は確かめない。「名前の写像では解けない衝突はない」の根拠はこの文脈の選び方に依存する | results.md に、文脈の選び方と、それが各証拠の P（固定の77件）又は lookup の前提（副条件付きの51件）と一致する根拠を書く。L60.27 の前に、副条件付きの証拠の型から lookup の前提を印字し、文脈の lookup と `isDefEq` で照合する台本を足すとよい | 読めば確定（不一致の反例は見つけていない） |
| 情報1 | 情報 | `StandardModelDeclarations.lean`・`StandardModelSignatures.lean` の `maxHeartbeats` | 二つとも既定値（200000）で時間切れになる（検査2）。依頼文の「証明に不要な上限設定」には当たらない | なし | 実行で確定 |
| 情報2 | 情報 | `source-correspondence-01.lean`・`-02.lean` の160等式 | 等式は `body_lookup` と `rfl` で閉じる。`Body.definition` が写像を当てた元 Def として定義されているので、等式の中身は、各出典の式（E15.047 の `allDefinitions[46]?` など、Body の元定義と別の式を含む）が Body の元定義と定義上等しいことである。「元 Def に写像を当てたもの」を言っている | なし | 読めば確定 |
| 情報3 | 情報 | plan.md の先頭の項目、results.md の L60.27 の行、resume3-classification-summary.json | 三種の件数（2・51・77）と固定の77件の内訳（alias 51・通常 core 10・safe 5・精密 getter 9・Pair 2）は、results.md・分類の要約・plan.md で一致する。120〜210分は、固定の P/B の共通の再証明と lookup・データの供給を見込む定性的な根拠で、8本の試行（外側5分02秒）からの外挿ではない | なし | 読めば確定 |
| 情報4 | 情報 | `l60/a/` の記録 | 183ファイル・約5.4 MB、最大79,997バイトで、各100 KB 以下である。宣言の写し（declarations-01〜08、計2,704行）は再開3の一回分である。生の出力は `<tmp>` にあり、改造には大きさと SHA-256 だけがある。md・json・lean に手元の絶対パスと docs/todo へのリンクはない（担当の報告には手元の絶対パスのリンクがあるが、改造の外である）。`Example.pathBases` が合成表の373署名に入るのは tables.md の E07 のとおりである | なし | 読めば確定 |

## 観点ごとの根拠

### 1. 合成用の Def と名前の写像

`FunctionNames.rename refined` は `collisionNames` の18組について `swap old ("%" ++ old ++ 接尾辞)` を順に合成したもので、`swap_injective` の合成から単射である。二つの写像（`refined` が真と偽）は別の関数で、本体ごとに `Body.refined` で選ぶ。130のキーが相異なることは、`body_lookup` を全130構成子で `rfl` により示したことから従う（同じキーが二つあれば後の構成子で `find?` が別の Def を返す）。`Body.key_correspondence` はキーが `rename body.refined body.name` であることを全構成子で示す。

`FunctionNames.value` 以下の六つの相互再帰は Val・Comp・Arm・Clause・捕捉の全構成子を網羅し、`fnRef` の名前だけを `ρ` で写す。`prim`・`op`・`externalRef`・`meth` の名前は写さない。型 `Ty` は関数名を持たないので写さない。tel は `definition_tel` で `rfl` である。本体の形・型注釈・算法は変わらない。

閉包の18名は、台本 `closure_inventory.py` が190行（159出典と helper の lookup 31行）を訪問し、同名で `isDefEq` でない元 Def を持つ名前を集めたものである。直接の出典にない helper は通常側の `List.filterFrom` 一つで、`StandardBodies.listFromDefinition true` を `Body.b130` に保持した。参照辺60本はすべて参照先が一つで、辺の照合は親の `refined` の印で写した名前と参照先のキーを比べる。精密 getter（b092〜b100）は種の文脈が通常側だが参照を持たず、影響はない。`Pair.first`・`Pair.second` は通常側の Map の本体からも精密側の Map の本体からも同じ元 Def（b106・b107）を指す。閉包の方法は本体の構文と台本が選んだ文脈に依存し、証拠の前提からは読んでいない（軽10）。

内部名は `%` で始まる既存の内部名の書き方に揃い、台帳の Rust 名の列は18名について「Rust の組込み登録なし」である。U02 の公開形は選んでいない。ただし、通常側の公開名も合成表のキーから消えたことと、公開名から内部名への対応の受け口がない（中1）。

### 2. 完了の主張の量化

- L60.04: `definitions_iff`（任意の externals・f・d）、`signatures_iff`（任意の名前・署名）、`resource_iff`（任意の名前）が Lean の全称の言明である。台帳と表の名前の対応は台本で照合する（依頼文のとおり Lean の評価でなく台本）。照合は Lean のソースの文字列と分割記録の比較で、両方向の集合の一致・仮定側の名前が表のキーにないこと・仮定側に証拠名がないことを含む。
- L60.05: `HasTypeVQ.of_fields` ほか14判断、`ExternalCarrier.of_fields` ほか三族12構成子、`BuiltinArgs`・`ExternalArgs`・`Outcome.Typed`・`Outcome.Carrier`、`ModelScopeConditions.of_responses`（25欄）は、任意の P・B・B'・添字を量化する本番の定理である。F07 の証明先は記録の中の命題で、`definition_target_iff` は全130本体の証明先との同値、`program_target_of_definition` は `VarianceValid` を受ける含意である。本体の型付けそのものは示していない。この区別は standard-contract.md、results.md、01-12（3110行）、07-04（76行）で保たれている。
- 群 A の完了条件: 8本の試行は外部宣言が空の表に限る（軽3）。12欄は型検査を超えて証明済みである（中2）。

### 3. 四分類

旧75欄は `scope_conditions` で七射影と δ・IO・refGet・refSet・effKind の等号から移すので、Model の6欄の空疎（pure・io・exit の署名がない）はそのまま保たれ、69実質・6空疎を保持する。移送の25条件は元の欄をそのまま移すので、新しい分類は生じない。新しい12欄は本番で証明されたが、記録は分類を確定していない（中2）。external_exists の3欄が定数 err で閉じることは、記録も自明と書いている。

### 4. 台帳の双方向照合

`composition_inventory.py` の `verify_tables` は、件数（552・640・523・75・130・373）、合成486・仮定154、台帳の内部名の集合と表のキーの集合（504）の一致、仮定側の名前と表のキーの交わりが空であること、仮定側の証拠・証拠行が空で理由があること、全出典が合成の親行に入り元 Def を持つ出典の内部名と Body の構成子が一致すること、参照辺の照合、Lean のソースの各行の存在、署名の木の再生成を確かめる。Rust の523参照と台帳の対応は `verify_resume3.py` が `rust_inventory.registrations()` と突き合わせる。無条件の err で埋めた行は、合成表の δ・IO が既存の提供元をそのまま読む定義（`StandardModel.delta`・`ioResponse`）なので生じない。仮定側の理由は定型文である（軽4）。

### 5. 停止条件と守ること

主な十言明・型付けの規則・書ける形・提供範囲・旧 `Release`・前段の実署名の変更はない（差分は既定 import と写しだけ）。外部宣言のない P への制限もない（`ExternalModels.targets_core` などは任意の P を量化し、元と同じ `HasFile`・`HasHttp` だけを受ける）。精密な外部状態は足していない（`ResourceRelease.response` は値の形と分類だけを読む）。読者のない公開の入口が三つある（軽2）。docstring の一つが前提と合わない（軽8）。本番のコメントに工程の ID はない（検索で0件）。

### 6. 写し

01-12・07-04 の新しい段落は、本番の名前（`Builtins.TypingFieldsEq`・`ExternalSurface.ref_typed/call_typed`・`ExternalModel.response/builtins/external_assumptions`・`Builtins.selectExternal`・`FunctionNames.rename/definition`・`StandardModel.program/builtins`・`ResourceRelease.response/canonical/typed_response`・`ModelScopeConditions.of_responses`）と前提に一致する。25条件・12構成子・七欄の数も本番と一致する。経緯の文と段名はない。記録の語と未定義の語が入った（軽7）。中1の受け口の一文がない。

### 7. 記録

大きさ・写しの回数・生の出力の扱いは情報4のとおりである。停止記録と最終の状態の関係が冒頭から読み取りにくく、古い監査の要約のハッシュが上書き後の分割記録と合わない（軽5）。単位の区間は L60.04（09:23:42〜09:56:47）と L60.05（09:31:04〜10:01:34）が重なり、results.md は着手時刻を実行記録から転記したと書いている。L60.27 の見込みの根拠は情報3のとおりで、results.md と plan.md は一致する。

## 実行した検査

| 番号 | 内容 | 結果 |
|---|---|---|
| 1 | `<tmp>/rv-l60-a/Probe.lean`（`StandardModelResponse` を import）を `formal/` で `lake env lean -M 12288` により検査した（終了0、約1.2秒、最大常駐量約1.7 GB）。次を確かめた。<br>(a) `(StandardModel.program e).defs "List.map" = none` と `"Range.minimum"` の同じ等式を、`lookup_body` と130構成子の `simp` で証明した。<br>(b) `FunctionNames.rename false "%List.map.ordinary" = "List.map"` と `rename false "List.fold" = "List.fold"` を `decide` で証明した。<br>(c) `#check` で `ExternalModels.model_core`・`targets_core`・`http_core` が `Builtins.CoreAssumptions` を結論し、`CoreAssumptions.release_exists`・`ExternalAssumptions.external_exists` の型を確かめた。<br>(d) `#print axioms` を `StandardModel.definitions_iff`・`body_lookup`・`signatures_iff`・`FunctionNames.rename_injective`・`ExternalModels.targets_core`・`HasTypeCQ.of_fields`・`ModelScopeConditions.of_responses`・`ResourceRelease.typed_response` に実行した | (a) 中1の根拠。(b) 中1の内部名から公開名へ戻す向き。(c) 中2の根拠。(d) いずれも propext・Quot.sound・Classical.choice の部分集合 |
| 2 | `StandardModelDeclarations.lean` と `StandardModelSignatures.lean` から `set_option maxHeartbeats` の一行だけを除いた写しを `<tmp>/rv-l60-a/` に作り、同じ方法で検査した | どちらも終了1。`body_lookup`（703行）と `Primitive.signature`（1539行・1596行）が既定の200000で時間切れ（それぞれ約8秒・約7秒）。軽1・情報1の根拠 |
| 3 | 群 A の監査と台帳の要約（audit-summary.json・resume1〜3-audit-summary.json・ledger-summary.json・resume3-closure-summary.json）が指す分割記録の SHA-256 を Python で照合した | 再開3・台帳・閉包の要約は全件一致。初回・再開1・再開2の監査の要約が指す declarations-01.json・signatures-01.json は不一致（軽5） |
| 4 | 新しい11モジュールを `set_option`・`sorry`・`native_decide`・`axiom`・`#eval`・`#print`・`decide`・`implemented_by`・`unsafe`・`maxRecDepth`・工程の ID・`旧`・`TODO`・手元の絶対パスで検索し、公開の入口の名前で formal 全体の読者を検索した | `maxHeartbeats` 2件（検査2）と `of_decide_eq_true` 1件のほかは0件。`rename_injective`・`definitions_iff`・`StandardModel.option_declarations` は既定ビルドに読者なし（軽2） |
| 5 | 閉包の種・節点・辺の記録を Python で読み、文脈の内訳、`refined` の印と文脈の対応、精密 getter の参照、`Pair.*` の参照先を数えた。台帳の仮定側154行の理由を名前を除いて型ごとに数えた | 文脈は通常側173・精密側17。印と文脈が異なるのは精密 getter 9個で、参照は0。理由は10種の定型文（軽4・軽10） |
| 6 | `git diff 80230d96 -- formal docs/design` の全行を読み、写しの語を基準の版の 01-12・07-04・用語集で数えた | 変更は3ファイル28行の追加だけ。「七射影」「台帳」「合成用Def」は基準の版になく、用語集にもない（軽7） |

## 再開1の再レビュー

2026-11-05。対象は同じブランチの未コミットの作業木で、基準は同じ `80230d96`（HEAD と一致）である。読んだものは次のとおりである。
- 担当の再開4の依頼文と報告。
- `plan.md`「計画の変更と取りまとめへの確認点」の先頭の二項目。
- `l60/a/` の results.md の「現在の状態」と「再開4（RV-L60.a の処置）」、actual-definition-correspondence.md、standard-contract.md の「後段へ渡す署名と受け口」と副条件の表、三つの停止記録の冒頭、古い三つの監査の要約の注記、assumption_inventory.py、evidence-context.lean。
- `git diff 80230d96 -- formal docs/design` と、未追跡の11モジュールの前回からの差。前回の状態は、`<tmp>/rv-l60-a/` の写し（上限設定の1行を除いた `StandardModelDeclarations`）と記録の `function-name-map.lean` で比べた。

本書の節の追加のほか、ファイルは変えていない。git の書き込み、`lake build`、cargo、記録を書き換える台本の実行はしていない。

### 結論

元の所見の中1・中2・軽1〜軽10はすべて解消した。新しい所見は軽2・情報1件で、どれも群 A の受け入れを妨げない。判定は**可**とする（新しい所見は重0・中0・軽2・情報1）。

本番の変更が所見の箇所に限られることを確かめた。前回の状態との差は、`FunctionNameMap.lean` の `example` 一つ、`StandardModelDeclarations.lean` の `example` 二つ、`ResourceReleaseModel.lean` の `canonical` の docstring だけである。三ファイルを単独で検査し、いずれも終了0だった（検査1）。設計書の差分は 01-12・07-04 の該当段落と表の行だけで、ほかの節の変更はない。

### 所見ごとの確認

| 元の所見 | 判定 | 根拠 |
|---|---|---|
| 中1 | 解消 | (1)〜(3) は standard-contract.md の「後段へ渡す署名と受け口」の L70 と U02 の行に入った。「18名の公開名は合成表のキーに現れない」は 07-04 の二段落と 01-12 の段落に一文ずつ入った。18名の対応表の行番号を処理系のソースで確かめた（List.bnt 67・71・81・85、Map.bnt 44・49、Set.bnt 44・49、NonEmptyList.bnt 59、Range.bnt 92・97・102・141・146・151・156・182・187）。どの行も同名の関数の宣言である。List は `get`・添字 `i`・`append` による再帰、NonEmptyList は `first` への適用と `rest` の `List.map`、Range は `CheckedInteger.minimum(value)` などの欄の読み出しで、記録の「通常側」の判定と合う。精密側に当たる定義は処理系にない。内部名を参照していないことの確かめは `evidence-context.lean` が担い、`resume3-body-classification.json` の全130行を回る。各行で元の本体の `fnRef` を再抽出し、保存済みの参照列との一致と、`%` で始まる名前がないことを確かめる。全130本体を量化している |
| 中2 | 解消 | results.md の12欄の表は、前回読んだ本番の証明と一致する。external_exists の3欄は定数 err で自明、Model と Http の release_exists は `Bool.noConfusion` で空疎、Targets の release_exists は `canonical` で実質、external_typed・external_no_targets の6欄は保留である。保留は「第五の性質ではなく、四分類をまだ確定していないこと」と書き、実質へ数えていない。87欄の集計（空疎8・自明3・実質70・保留6）も実質76の目標と分けている。O013・O061 は三モデルの Core の到達と、未完の部分（正常入力・全標準表）に分けて更新した。L60.12・.13・.22 の見込みの変更案は、plan.md の先頭の項目に取りまとめの判断として入った |
| 軽1 | 解消 | 本番の二箇所の上限と、既定値での時間切れ（本書の検査2の引用）を書いた |
| 軽2 | 解消 | 三つの適用例は既定ビルドのモジュールの中にある。`rename_injective` からは二つの公開名の写像先が異なることを、`definitions_iff` の逆向きからは `Body.b001` の lookup を、`option_declarations []` からは空の外部宣言の表の Option 宣言を得る。三つとも入口を実際に使う形で、大きな具体値を作らない。三つ目は具体化だけだが、入口の型を既定ビルドで読むので足りる |
| 軽3 | 解消 | standard-contract.md と results.md に、8本の試行は `externals = []` に限ること、任意の externals への一般化と本番への移植は L60.27 が受け持つことを書いた |
| 軽4 | 解消（新軽2） | 仮定側の154行に `assumption_kind`・`builtins_fields`・`assumption_detail` の列が付いた。区分は δ 81・IO 応答 46・通常資源の状態 16・専用の遷移 11 である。`assumption_inventory.py` は Rust の登録の `pure`/`io`/`state` と名前から区分を決める。欄名は `Builtins` 構造体の欄に限り、照合の時に各行の値が台本の出力と一致しなければ拒む。`verify_resume4.py` はこれを呼ぶ |
| 軽5 | 解消 | results.md の冒頭に現在の状態の表がある。三つの停止記録の冒頭に「再開3で解消した」の一行がある。古い三つの監査の要約に `snapshot_note` がある。27義務の判定は再開4の一つの表に集まった |
| 軽6 | 解消 | O062・O065 は「入力を用意した。行の判定は変えない」とし、閉じた担当分は O084 に限った |
| 軽7 | 解消（新軽1） | 七つの射影の定義、`Body.all`・`Primitive.all`・`Body.definition` の実名、「同じ関係の証人」への修正が入った。段落は 01-12・07-04 とも【決定】の段落の後へ移った。07-04 の表の一行に「有限台帳」が残る |
| 軽8 | 解消 | docstring が前提 `B.valKind o = none` に合った |
| 軽9 | 解消 | 副条件の表の「データ」の行と L60.29 の受け口に `VarianceValid`（`dataInfo` と変性）を加えた |
| 軽10 | 解消 | `evidence-context.lean` は証拠の型を読み、有限の列挙型の引数を具体化して、結論の元 Def と `isDefEq` になる組を選ぶ。副条件付きの証拠では、前提と `Inputs` の欄の下にある `P.defs name = some d` を取り出し、閉包の文脈の `defs name` と `isDefEq` で比べる。本体の全参照が前提で覆われることも確かめる。固定の P の証拠では、本体の参照名ごとに `P.defs name` と文脈の `defs name` を比べる。比較は副条件付き51件で101、固定77件で13の計114で、lookup を持たない行（12件と71件）も省かずに数えた。任意の P/B の2件は参照の再抽出だけを行う。130本体を覆う |

### 新しい所見

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 新軽1 | 軽 | 07-04 の表の1007行（`FunctionNameMap`・`StandardModel*` の行）、01-12 の3110行・07-04 の76行の「18名」 | (a) 表の行に「有限台帳と全lookupの双方向の対応」が残る。軽7(b) の処置は段落だけを直した。(b) 写しの「18名の公開名」は、どの18名かを写しの中で特定していない | (a)「有限の本体表（`Body.all`）と組込みの表（`Primitive.all`）に対する全lookupの双方向の対応」とする。(b)「同じ名前に異なる元 Def を持つ18名（`FunctionNames.collisionNames`）」とする | 読めば確定 |
| 新軽2 | 軽 | ledger の仮定側の「専用の遷移」11行、`assumption_inventory.py` の `metadata` の Task・TaskGroup と `state` の既定の枝 | 11行のうち `Task.*` 5行と `TaskGroup.*` 2行は、`assumption_detail` 自身が「現在のPrimKind/StepにTask専用欄・遷移はなく…並行実行の状態は形式化外」と書く。対応する Builtins の欄も Step の規則もないので、07-04 の「仮定として量化する範囲」には入らない。それでも「専用の遷移」と区分するので、ほかの4行（`Reference.new`・`Reference.update`・`Lazy.force`・`Process.exit`。Step の規則がある）と同じ扱いに読める。`state` の既定の枝も同じ区分になる | 区分に「形式化の外（対応する欄・遷移なし）」を加えて7行（と既定の枝）をそこへ移す。理由の文は、R50 が形式化の内外を確かめる行であることを書く | 読めば確定 |
| 新情報1 | 情報 | actual-definition-correspondence.md の集計 | 18名の実際の定義はすべて通常側で、精密側の元 Def（`%…refined` のキー）に当たる処理系の定義はない。精密側は L40 で受け入れた安全な入口の内部契約で、U02 の後に公開形が決まる。L70 が公開名から内部名への対応を作るとき、U02 の回答の前に `%…refined` を公開名へ割り当てない、という受け口の(2)と整合する | なし | 読めば確定 |

### 実行した検査

| 番号 | 内容 | 結果 |
|---|---|---|
| 1 | `FunctionNameMap.lean`・`StandardModelDeclarations.lean`・`ResourceReleaseModel.lean` を `formal/` で `lake env lean -M 12288` により単独で検査した（olean を書かない） | 三つとも終了0（約0.4秒・17.5秒・0.7秒）。追加した三つの `example` が型検査を通る |
| 2 | 前回の状態の写し（上限設定の1行を除いた `StandardModelDeclarations`、記録の `function-name-map.lean`）と現在の本番を `diff` で比べ、`find -newer` で前回の確かめの後に変わった Lean のファイルを数えた。`git diff 80230d96 -- formal docs/design` の追加と削除の行を読んだ | 変わったのは本番の3ファイルだけで、差は三つの `example` と docstring。設計書の差は該当段落と表の3行だけ |
| 3 | 処理系の標準ライブラリの18行（List・Map・Set・NonEmptyList・Range の `.bnt`）と、List の `map`/`mapFrom`/`filter`/`filterFrom`、NonEmptyList の `map`、Range の `minimum`/`maximum`/`value` の本体を読んだ | 中1の対応表の行番号と判定を支える |
| 4 | 仮定側154行の区分・欄名・理由を Python で数え、代表の13名の値を読んだ | 区分の件数は記録と一致した。理由は15種の文型に分かれる。新軽2の根拠 |

## 取りまとめの追記

2026-11-05。初回の所見（中2・軽10）は再開4、再レビューの新軽1・新軽2は再開5で処置した（`l60/a/results.md` の「再開4」「再開5」）。中1の受け口の方針、L60.27 の見込み（120〜210分）、L60.12・.13・.22 の見込みの短縮は、plan.md の「計画の変更と取りまとめへの確認点」に記録した。中1は設計者の見直しの対象とした。新情報1（精密側の元 Def に当たる処理系の定義はない）は受け口の(2)と整合するので処置しない。再開5の後に取りまとめが `scripts/check.sh --level work --base 80230d96305756057a63a07dc2b0d8aa1ebf3a75` を実行し、終了0（542.96秒）であった（`l60/a/results.md` の「群 A の作業末の work の検査（取りまとめ）」）。
