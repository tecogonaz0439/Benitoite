# 再開9: 実入口と転送の受理

本書は [results.md](results.md) の「再開9」の詳細である。対象は [RV-L70.d3](../../reviews/RV-L70.d3.md) の処置である。以下の名前で `S` は `Benitoite.Release.Refinement.Surface` を表す。

## 公開ソースと型付けの入口

`S.CheckPreparation.prepare` は、元のプログラムと有限な定義・実装・メソッドの一覧から全本体の出現を集め、`PredicateRowCollection.collect` の同じ行表で全本体を解決する。名前の一覧の完全性は既存の `NamesComplete` と `ImplNamesComplete` を使う。`resolveProgram_declarations` は関数・実装・外部宣言を含む全宣言の保存を示す。内部行は `Check.BuiltinSource.resolved` の署名とδの欄へ追加し、元の表のその他の欄を保つ。元の `Input.Sound` から `input_sound`・`prepare_sound` が準備後の健全性を構成する。標準の構成データを持つ表を解決し、独自の表には標準名の意味を仮定しない。収集行が空の入力は恒等である。

`S.CheckTables.checkProgram` は準備後の入力とプログラムを `checkPreparedProgram` へ渡す。`S.CheckAccept.checkProgramAccepted` はこの型付けの入口に続き、元の本体で必須の判定を受理する。型付けの結論は準備後のプログラム、受理の結論 `Accepted A q p` と診断の鍵は元のプログラムである。解決が出現の番号を変えても、必須の判定の診断位置を内部形の番号へ置き換えない。

| 実入口の例（いずれも公開呼出しのままのプログラム） | 検査の成功と拒否の対照 |
|---|---|
| `S.CheckPredicateProgramExamples.path_entry` | `checkProgram` と `checkProgramAccepted` の双方が成功。真枝で所属・偽枝で非所属を要求する。同じ枝を素のBooleanの条件へ替えると型検査が拒否 |
| `S.CheckPredicateProgramExamples.host_entry` | hostの真偽両枝を実入口が受理し、素のBooleanの対照を拒否 |
| `S.CheckPredicateProgramExamples.characters_entry` | 文字集合の真偽両枝を実入口が受理し、素のBooleanの対照を拒否 |
| `S.CheckPredicateProgramExamples.floating_entry width test` | Float・Float32の六分類ずつを実入口が受理し、素のBooleanの対照を拒否。十四関数のほかFloat32.isInfiniteも含む |
| `S.CheckPredicateProjectionExamples.source_entry` | 公開のString欄の判定を持つ全プログラムを両実入口が受理し、素のBooleanの対照を拒否 |

十四関数は所属二つ・文字集合一つ・Floatの六分類・Float32の五分類である。Float32.isInfiniteの追加で、例が扱う公開名は合計十五である。元の `CheckPredicateExamples` の内部形を直接検査する例は、内部の二規則の例として保つ。

## プログラムの意味と性質1

レビュー重1の代案のうち、公開名の解決を型付けより前に行い、言語の意味を解決後のプログラムで定める案を採る。公開ソースに直接通常の脱糖を当てた旧表での実行と、解決後の内部形の実行の間の双模倣を追加したのではない。この選択を01-12と07-04にも明記した。

- `S.PredicateProgramSemantics.meaning q p` は、`prepare q p` に続く通常の `desugarProgram` である。
- `S.PredicateProgramSemantics.core ready` は、解決済みの入力とプログラムから作る同じ核である。
- `S.PredicateProgramSemantics.observations_preserved` は、この二つの意味で同じ事象列と同じ最終状態を持つ有限実行、終端の観測、同じ各段のラベルを持つ無限実行を同値で結ぶ。最終状態そのものを保つので、正常値・失敗のpayload・終了値・ストアも保つ。この対応は意味の定義からの等号であり、旧表に対する未証明の書き換え保存を信頼条件にしない。
- 同じ言明の `PublicDeltaAgreement` は、`path_delta`・`host_delta`・`characters_delta`・`floating_delta` と、投影の読み取り後の同じscalarのδの等式を `public_deltas` から受け取る。δの等式には本番の言明の読者がある。
- `S.PredicateProgramSemantics.accepted_property1` は、実入口の受理から、解決後の表層の `Program.WellTyped`、元の本体の `Accepted`、同じ核の `WellFormed`・`WellTyped`・`EffectsOk` を導く。

最後の定理の前提は、元の `Input.Sound` と名前の一覧の完全性、準備後の本体の有限支持、実装名の完全性、準備後の宣言表の一致、受理の一覧の完全性、準備後の `Program.WellFormed`、同じ核と表の既存の `Builtins.ValueAssumptions` である。型付けを前提にはしない。`prepare_sound` が元の入力から準備後の入力の健全性を構成する。通常の性質1の前提を、応答の健全性や整形式と混同しない。外部宣言のないプログラムへの制限も、新しい独立の信頼条件も置かない。

## Input.Soundと実際の型付け

`PredicateStandardAtoms`・`PredicateStandardFamilies`・`PredicateStandardSupport1`〜`4`・`PredicateStandardSupport` は、標準の全392行の署名の有限支持を構成する。各行はAPIの族の補題を参照し、最後の表の補題は392行を読む。大きな具体範囲や長い列をLeanで評価していない。件数と連番の照合は `resume9/verify.py` が行う。

| 証人又は導出 | 届く結論 |
|---|---|
| `S.CheckPredicateProgramExamples.input_sound`・`prepared_input_sound` | 標準表と、実入口が加えた内部行の入力の全 `Input.Sound` |
| `S.CheckPredicateProgramExamples.path_typed` | 公開のpath判定の実入口の成功から、準備後の全プログラムの `CheckedUnder` |
| `S.CheckPredicateProjectionExamples.input_sound` | fixtureの構成子・getterと標準全行・投影内部行について、形成・全表の支持・sat・型引数と範囲引数の許容・演算子の全条件 |
| `S.CheckPredicateProjectionExamples.text_condition_typed` | 実際の `checkExpr` の成功と同じ入力の健全性から、閉じたString欄の条件の `HasTypeQ` |
| `S.CheckPredicateProjectionExamples.text_source_derivation` | `text_source_checked` の型付けの仮定を上の導出で満たし、元のgetterの型付けを得る |
| `S.CheckPredicateProjectionExamples.open_number_condition_typed` | 型引数に範囲変数を持つ二段のFloat欄を、生成した案内と開いた入力の健全性から `OpenSurface.HasTypeQ` へ移す |
| `S.CheckPredicateProjectionExamples.open_number_source_derivation` | `open_number_source_checked` の仮定を上の導出で満たす |
| `CheckPredicateProjectionExamples.lean` のprivateな `source_input_sound` と公開の `S.CheckPredicateProjectionExamples.source_typed` | 元の公開の欄の判定を含むプログラムの入力と、実入口が解決した同じプログラムの全体の型付け |

fixtureの `constructors_complete` と `funs_support` は、実際の二構成子と三getterから構成した。入力の支持やgetterの型付けを未充足の仮定で残していない。標準表の `Includes` や `Builtins.ValueAssumptions` 全体を、これらの具体例の `Input.Sound` から導いたとは主張しない。

## 受理する転送の形

`OpenScopeAccept.selections` は全出現と元のパラメータの文脈を同じ先行順で対応させる。局所束縛は未知の型の位置を追加し、元のパラメータ参照の番号だけをずらす。局所の注釈から新しい由来を作らない。呼出しの引数の並べ替えを読み、固定十一規則の対象の引数が元のパラメータ参照なら、型が保持する `RangeIx` を選ぶ。

| 受理する形 | 例 | 異なる範囲変数の対照 |
|---|---|---|
| 直接の末尾呼出し | `Scope.widenPathIn[R,R](p)` | パラメータはR0、契約はR1 |
| 束縛を前置きした末尾呼出し | `let u = (); Scope.widenPathIn[R,R](p)` | 位置をずらした同じpにR1を指定 |
| 呼出しの結果を束縛して返す本体 | `let q = Scope.widenPathIn[R,R](p); q` | 右辺の契約をR1へ替える |
| ブロックの末尾 | `{ Scope.widenPathIn[R,R](p) }` | 内側の末尾の契約をR1へ替える |
| 範囲を持つ引数がパラメータ参照である複数引数の呼出し | `File.writeTextIn[R](text: text, path: p)` | pathのパラメータはR0、契約はR1。実際の例は引数の順序も入れ替える |
| 範囲パラメータがなく、固定範囲を保持する同じ五形 | `Scope.widenPathIn["/a","/a"](p)`、`p : PathIn["/a"]` | 開いた五形の取り違えの対照と同じ選択器を使う |

`S.OpenScopeForwardExamples.open_entry` と `closed_entry` は `Form` の全五形について `checkProgramAccepted` の成功を示す。`range_decision_sound` と `closed_entry` は、合成表の実際の `ScopeSignatures.admitsR` が閉じた呼出しの許容を満たすことも示す。任意の表を「標準」と呼んだ例ではない。

`different_source` は五形の全てで受理の単位が正確に `unknownSource` を返すことを示す。`different_entry` は同じ五形の実入口が `.typing` の `.rejected` で拒否することを示す。この二段を区別する。型付けを通ってから記号側だけが断った例とはしていない。

範囲パラメータの有無による逆転は、固定範囲と変数を同じ選択器で読むことで解消した。パラメータの型の範囲は、定義の型付けで検査済みの事実である。実引数の値がこの型に合うことは呼出し側の型付けが保証する。「注釈を信用しない」は、未検査の注釈や局所の束縛の注釈だけから新しい由来を認定しない意味である。この理由を01-12へ写した。

分岐・ラムダ・一般の引数式の内側、再包装した値、局所の注釈だけに依存する転送は記号側では選ばない。選べない出現は同じ局所解析の `acceptOccurrence` へ渡し、そこで認定できない狭い契約が `unknownSource` となる。既存のリテラルとconstの由来を捨てない。内部契約を誤りの側へ倒す範囲であり、書ける形は狭めない。

パイプ `x |> Float.isFinite` は、公開の関数値の署名で型付け、素のBooleanとなる。直接の呼出しの解決へ無条件に変換すると、評価順と引数位置の扱いを別に証明する必要があるため、今回は既存の意味を保つ。動的なpatternと端、値として受ける公開関数も、公開のBooleanの行を使う。`Float32.isInfinite` は `CheckPredicateExamples.float32_infinite_branches` と上の `floating_entry` で受理する。

## 既存言明の差

開始時のSurface全1,948言明を比較する。変更20件、追加477件、削除0件である。ここで件数は明示した `theorem` の見出しの比較であり、生成宣言とprivateを含む全宣言の公理監査とは別である。

| 場所と件数 | 差 | 元の形との関係 |
|---|---|---|
| `CheckTables.checkProgram_unknown`（1） | 準備後の入力と本体の停止を返す | `checkPreparedProgram_unknown` が元の言明を名前だけ変えて保持 |
| `CheckTables.checkProgram_sound`・`empty`・`contracts`・`sound_contracts`・`empty_contracts`（CheckProgramSound.lean）（5） | 準備後の入力・本体・宣言の前提と結論 | 同じ五つの `checkPreparedProgram_*` が元の形を保持 |
| `CheckTables.program_parts`（CheckProgramSound.lean）（private、1） | 生の全件検査の成功を分解 | 読者は同じ内部の健全性の証明 |
| `CheckAccept.checkProgramAccepted_sound`・`empty`・`unknown`（3） | 型付けと停止は準備後、必須の判定の受理は元の本体 | 準備が恒等なら元の形へ簡約 |
| `CheckTables.Materials.checkProgram_sound`（CheckMaterialsSound.lean）・`empty`・`sound_contracts`・`empty_contracts`・`checkProgramAccepted_sound`・`empty`（6） | 有限材料から得る一覧を準備後へ移す | 材料の全件性を独立の信頼条件にしない。準備が恒等なら元の形 |
| `OpenScopeAccept.acceptBody_no_ranges`・`CheckAccept.acceptDef_no_ranges`・`Accepted.def_body_no_ranges`・`Accepted.def_ranges_no_ranges`（4） | 空の種類列に加え、記号側の選択が無い本体で旧閉じた由来の結論を返す | 固定範囲の転送も新しい選択の対象となるため、空の種類列だけでは旧の閉じた由来の結論を断定しない |

旧の六言明は、名前の `checkPreparedProgram` を `checkProgram` に戻した見出しのSHA-256が開始時と一致することを `verify.py` で照合する。範囲のない旧の規則を削らず、準備が恒等のときに同じ検査を使う。記号側で選ぶ範囲を持たない本体では、四つの `no_ranges` の系が元の閉じた由来を返す。固定範囲を持つ転送の受理の追加を、旧の閉じた由来の結論で説明しない。

群Dの旧308件は、承認済み二差以外に追加差0。群Eの旧617件では累計18件が異なり、再開8の二件に加えて、実入口と材料の接続等の16件が変わる。再開8で新設した三つの `no_ranges` と `OpenScopeAccept.acceptBody_no_ranges` の差を加えると、開始時との今回の差20件になる。主な十言明の形、核のStep、通常と開いた表層の97規則の名前と順序は変えない。不要になったprivateな定義 `chosenAt` は削除し、未使用の補題として残さない。

## 止めずに進めた変更

| 対象 | 反例又は理由 | 選んだ案 | 退けた案 | 範囲のない場合の系 |
|---|---|---|---|---|
| 公開プログラムの意味 | 型付けだけ内部行へ変えると、実行が読む表とずれる | 収集・解決を型付けと通常の脱糖の前に定義し、全プログラムの観測を同じ核へ結ぶ | 未証明の旧脱糖との双模倣を信頼する、局所のδだけで意味保存を断定する | 同じ準備を使う。行のない入力は恒等で、元の通常の脱糖と同じ |
| `checkProgram` と材料の前段の署名 | 元の入力だけの型付けでは解決済みの本体を表せない | 準備後の入力と本体を結論にし、宣言と一覧の保存を証明 | `Input.Sound` や一覧の完全性を新しく仮定、外部宣言のないPへ制限 | 元の六言明を `checkPreparedProgram_*` へ保持し、準備が恒等なら元の形 |
| `checkProgramAccepted` の公開契約 | 解決後の番号を受理の鍵に使うと元ソースの診断がずれる | 型付けは準備後、受理と診断は元の本体 | 解決後の出現番号を利用者に返す、受理を省く | 恒等の準備では同じ型付けと元の受理 |
| `BuiltinSource.resolved` と開いた引数 | 標準表を独自の表へ包むと、許容の具体化の保存を失う | 元の構成と範囲・satの欄を保持し、内部行だけ型引数の個数を検査 | 任意の表の保存を独立に信頼、標準の範囲規則を省く | 範囲引数のない内部行と元の表の許容を使い、通常の検査にも同じ入力を渡す |
| 閉じた範囲の転送 | 同じ転送が範囲パラメータの有無で逆転する | 固定範囲と範囲変数を同じ型付け済みのパラメータから選ぶ | 範囲パラメータを無意味に足させる、固定範囲をTopへ捨てる | 型に範囲を持たず記号側で選ばない本体は元の `acceptOccurrence` と `no_ranges` の系 |
| 全出現の選択と十一規則 | 結果の束縛・前置き・書き込みを単一の末尾呼出しでは扱えない | 元のパラメータ参照を文列で追い、全出現を検査。書き込み四行と引数の並べ替えを扱う | 局所注釈を由来として信頼、末尾以外の呼出しを見落とす | 記号側の選択が無い本体の同じ閉じた受理。固定範囲の新しい受理は同じ新規則の適用 |
| `DefinitionRanges` と四つの互換の系 | 閉じた範囲のパラメータは旧の局所解析ではTopとなる | 全出現で記号側の全具体化か閉じた由来かを分け、互換の系へ選択無しを明記 | 新しい受理から旧BodyRangesを誤って断定 | 空の種類列かつ選択無しで元の結論。元の `ScopeAccept` 自体は変更しない |

いずれも新しい規則の前提、保守的な内部契約、前段の署名又は群の境界の小さい接続である。新しい公理・sorry・独立の信頼条件、主な十言明の変更、利用者の書ける形の削減、合成表が満たさない前提は足さない。

## 例と検査の設計

作成前に `test-audit` の関門を適用した。実入口へ公開呼出しを渡す例は、手で解決して単一式・定義を検査する既存例では捉えられない境界を対象とする。転送の五形は旧の選択器で失敗が確認された形と引数の並べ替えを扱い、形ごとに異なる範囲変数を選ぶ拒否の対照を持つ。新しい本番のフックを例のためだけに加えない。標準表の支持の補題は具体の `Input.Sound` が読む。

途中のLeanは `formal/` から `lake env lean -M 12288` を一つずつ実行した。標準全行を個別に展開する初期の試行は遅いため、当該sessionだけを中断し、APIの族の記号的な支持の補題へ置き換えた。大きな具体値の生成や証明の上限の追加で解決していない。依存先を含む最後の単独確認は6モジュール、終了0、85.646秒だった。これは既定ビルドの代わりには数えない。

最終の既定ビルド・全環境の公理監査・照合は、[results.md](results.md) と `resume9/*-summary.json` に記す。監査対象は再開8の50モジュールと今回の追加・変更の和集合66モジュールであり、全環境からprivate・生成宣言も含めて列挙する。台本は [inventory.py](resume9/inventory.py)・[axioms.lean](resume9/axioms.lean)・[verify.py](resume9/verify.py)・[run_check.py](resume9/run_check.py)。大きな生出力と開始時の指紋は一時領域に置き、改造には件数・大きさ・SHA-256を残す。
