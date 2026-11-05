# RV-L60.f1: L60 群 F1（L60.23〜.25、証拠のある宣言・数値・演算子）の独立レビュー

2026-11-05。対象はブランチ `m014/l60.f1` の未コミットの作業木で、基準は `d0f7b3051f74dfefb73a6ef6b3edd59ba734dfb1`（HEAD と一致）である。本書の `<repo>` はレビュー対象の worktree、`<tmp>` は指定の scratchpad を表す。見たものは次のとおりである。

- 本番の変更: `git diff d0f7b305 -- formal docs/design`。既定 import、`StandardModelDeclarations`・`StandardModelSignatures`・`StandardModelPrimitiveLookup`・`StandardDecimalResponse`・`ResourceReleaseLeaves`、01-12・07-04 の差分。
- 未追跡の四モジュール: `StandardModelPureRows`・`StandardModelNumericRows`・`StandardModelOperatorRows`・`StandardModelPureInputs`。
- 群 F1 の記録: `l60/f1/` の results.md、conditions.json、inputs.json、ledger-diff.json、store-signatures.json、readers.json、audit-summary.json、added-declarations.json、declarations-01〜08.json、既定ビルド・公理監査・照合・入力ハッシュの記録、全十二台本と axioms.lean。

読んだもの:

- 依頼文 `<repo>/../Benitoite/work/m014/L60.f1-prompt.md` の作業・完了条件・守ること・止める条件と、[担当の報告](../l60/f1/results.md)。
- `l60/detail.md` の第2.4節（四分類）・第2.5節・F07、L60.23〜.25 と群 F1 の完了条件、第5節の H03・H06・H13・H24・H25・S03・S06・S17〜S22、第6節の O022・O062・O065 と共通の義務、停止条件。`l60/tables.md` の既存証拠 E01〜E15、Rust 登録表、公開モジュール表と四照合の条件。
- `l60/a/standard-contract.md` と ledger-01〜11.json、`l60/b/handoffs.md`、`l60/c/handoffs.md`・conditions.md・conditions.json、`l60/e/resources.json`・reference-signatures.json、`reviews/RV-L60.a.md`〜`RV-L60.c.md` の初回と追記。
- worktree の `plan.md` の「全 L 作業の停止条件」と「計画の変更と取りまとめへの確認点」の先頭、本体の作業木の同節の最新判断（Process.exit を加えないこと、三署名の追加、群 E の記録の追随）。言語の目的は 00-01 で確認した。
- 行の定義と比較対象: `BuiltinResponse.ResponseAssumptions`、`StandardModelResponse`、`StandardOperatorResponse.response`、各数値族の response、`StandardEqualityResponse.fullSignature`・`StandardStructuralEqualityResponse.response`、`PrimSig.StoreShape` と Step の参照・遅延・exit の規則。三署名については Rust の reference.rs・lazy.rs・process.rs と標準ソース Reference.bnt・Lazy.bnt も読んだ。
- 独立集計の入力: tables.md が指定する `l40/e/sources-r4-u28.json` の全 rows、`l40/e/operators-r1-u28.json` の pure-leaf、`l40/g/resume2-operators.json` の全 operators。

git の書き込み操作、本書以外のリポジトリ内のファイルの変更、`lake build`・cargo・`scripts/check.sh` の実行はしていない。Lean は `<repo>/formal/` から `lake env lean -M 12288 <file>` で一つずつ実行し、`-o` は使っていない。確かめの入力と出力は `<tmp>/rv-l60-f1/` に置いた。記録を書き換える verify.py・audit.py・conditions.py などは実行せず、読んで判定した。全環境の公理監査と既定ビルドの結果は担当の記録を読み、本レビューでは代表の公理依存と単独のソース検査を実行した。大きな具体値を作る評価はしていない。

## 結論

**可**（重0・中0・軽4・情報3）。

証明、行の網羅、275行の四分類に、群 F1 の完了を妨げる誤りは見つからなかった。数値166行と演算子109行は、台帳と tables.md が指定する既存証拠から独立に数えて一致した。数値の契約は任意の externals の合成プログラムで、演算子の契約と最初の十六接続は任意の P で成り立つ。入力証人を同じ表の契約へ当てる検査も通った。三署名は既存の StoreShape と専用の Step 規則に一致し、新しい δ・IO の意味は追加していない。

軽の所見はいずれも説明・写しの修正であり、証明や集合の変更を求めない。群 E の記録の追随は、本体の最新 plan が取りまとめで行うと決めている処置である（情報1）。

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|---|
| 軽1 | 軽 | `StandardModelOperatorRows.lean` 5〜6行、results.md「L60.25 全107演算子と構造等号」、01-12 の3132行 | 「%で始まる組込みの行から %Map.replaceValues を除いた107行」と書くが、この条件には %eq/%ne も入るので109行である。その後に「構造等号の2行」を加える説明は集合を重ねて読ませる。実装の `Primitive.operator` と全場合の証明は109行で正しい。E02の73・E03の34・E04の2は名前の集合が相互に交わらず、今回の実物では107＋2＝109と独立に確認できた | 「%で始まる組込みの行から %Map.replaceValues・%eq・%ne を除いた107行と、%eq/%ne の2行」とする。又は「%Map.replaceValues を除いた109行（うち構造等号2行）」とする | 読めば確定（独立集計で照合） |
| 軽2 | 軽 | `StandardDecimalResponse.lean` 28行の Declarations の docstring、135行の response_of の docstring、01-12 の4366行、07-04 の1307行 | Declarations は Option の二構成子の存在と arity を要求する一方、丸め方式には「lookup できてデータ名が RoundingMode なら、既知の五方式の一つ」という上限だけを要求する。五方式それぞれの存在は要求しない。「Optionと五つの丸め方式の構成子の宣言」「五モードを含む同じ宣言を持つ任意のP」や写しの「OptionとRoundingModeの構成子を宣言し」は、五方式の存在も前提に含むと読める。合成プログラムの五方式の存在は実際に供給され、275行の非空性に問題はない | 一般化した条件を「Option の構成子と arity を持ち、RoundingMode に属する構成子を既知の五方式に限る」とする。合成プログラムと元の固定 program が五方式を全て宣言することは別に書く。証明の前提を増やす必要はない | 読めば確定 |
| 軽3 | 軽 | 01-12 の3132行の追加段落、07-04 の90行と1028行の対応表 | 新しい四モジュールのうち `StandardModelPureInputs` の写しがない。`PureRow.Satisfiable`・`numeric_inputs`・`operator_inputs` と、Decimal.round・構造等号の前提を満たす入力は、両章のどこにも記されていない。依頼は新しいモジュールの追加と同じ変更で写しを直す条件であり、現在は三モジュールの契約だけを写している | 対応表へ StandardModelPureInputs を加え、両章に「数値と演算子の各行で、lookup と同じ署名の BuiltinArgs を満たす入力がある」と短く写す。四分類・件数の集計の説明は記録へ置く | 読めば確定 |
| 軽4 | 軽 | 01-12 の3132行「PureRow.of_row は、台帳の行の出典の表のδが…」 | 改造の記録の語である「台帳」が新しい写しへ入った。本番で量化する対象は `StandardModel.Primitive` の行であり、JSON の台帳を読まない。RV-L60.a の軽7で区別した語が今回の追加文に再び現れている | 「組込みの表の行（Primitive）の出典の表のδが…」とする。本番の docstring も同じ対象名へ揃えると分かりやすい | 読めば確定 |
| 情報1 | 情報 | `ResourceReleaseLeaves.store_transitions`、群 E の resources.json・ledger.py・verify.py・results.md と署名の記録 | 本番の読者は五行へ追随しているが、群 E の資源の記録には消した `no_store_transitions` が残り、三署名を仮定側に置いた時点の分類も残る。F1 の results.md はこの不一致を明記し、前の群の記録を変更しない指示を守っている。本体の最新 plan は群 E の現在の照合と申し送りを追随させると決定済みである | 取りまとめで現在の記録を追随させ、群 E の results.md に置き換えを追記する。過去の宣言の写しを現在の署名と扱わない。F1 の処置を未承認の署名変更として戻す必要はない | 読めば確定 |
| 情報2 | 情報 | `PureRow`、`PureRow.Satisfiable`、conditions.json と results.md「非空性と四分類」 | PureRow は delta_typed の名前を固定し、種類が pure という前提を省いた分だけ強い。今回の275行は全て pure であり、この省略は保証を弱めない。各行の前提の充足と応答証明の使用から全275行を実質とする判定は正しい。ただし全純粋行の delta_typed の充足でも、全入力での正常 val の存在の保証でもない。Satisfiable の存在量化には応答を含めない | 現在の限定を後段でも保つ。全表の欄は残る純粋行と合わせて閉じる。正常値の存在を主張するなら、Outcome が val であることを別に示す | 読めば確定、実行で確定（検査2） |
| 情報3 | 情報 | 群 A の504子キー、F1 の ledger-diff.json、合成プログラムの roundingMode | helper_correspondence の b130 も含めて、群 A は130本体＋373組込み署名＋資源名1＝504キーである。F1 は三署名を加え、130＋376＋1＝507となる。丸め方式の構成子はこの子キーの数え方に含まれない。群 A の記録は保持されているので、後段が504を現在の件数として固定すると食い違う | F2 の四照合では群 A の台帳に F1 の差分を適用し、507キーと照合する。丸め方式は宣言・arity・dataInfo の照合で扱い、応答行数へ足さない | 読めば確定（独立集計で照合） |

## 観点ごとの根拠

### 1. 行の契約と全場合

`PureRow P b` は、任意の Ψ・署名・型引数・行引数・範囲引数・値引数・結果型・効果を量化する。前提は `(builtins P).sig b = some sg` と、同じ P/B/b/sg の `BuiltinArgs` である。結論の δ・型付け・AdequateResult も同じ引数を使う。`ResponseAssumptions.delta_typed` との差は情報2の種類の前提だけで、元の欄へそのまま当てられることを検査2で確かめた。

`PureRow.of_row` は `row_lookup` の一意な署名へ引数を戻し、`primitive_lookup` で合成表の δ を同じ行の provider の δ に書き換える。`of_response` は名前・署名・δ の一致を使って既存の応答を適用する。結果の定数を任意に選んだり、別の表の BuiltinArgs へ移したりしていない。四モジュールの証明に部分表の `table_response` の適用はない。

`first_sixteen` は任意の P と、entries.take 16 の任意の所属要素を量化する。`first_sixteen_entries` が並びを固定し、七整数型の div/mod と Float の add/subtract を `PureRow.operator` から任意 P/B の `StandardOperatorResponse.response` へ接続する。operator_rows の対応する十六枝は first_sixteen を読み、残りの枝で数え直していない。

独立集計では、F1 の rows.py・conditions.py を入力に使わず、tables.md の指定した L40 の記録と群 A の台帳から期待集合を作った。次の件数と名前の集合が、Primitive.numeric/operator、全場合の証明、入力証人、ledger-diff.json、conditions.json のそれぞれと一致した。

| 対象 | 独立に数えた出典・集合 | 件数と結果 |
|---|---|---|
| 数値 | E01 の公開 API のうち、Byte・Character・Float・Float32・Decimal・Integer と実表の整数各幅の pure-local。別名の core は除く | 166。全て pure-local、漏れ0・重複0 |
| 演算子 | E02 の pure-leaf 73、E03 の全34、E04 の %eq/%ne | 73＋34＋2＝109。三集合の交わり0、漏れ0・重複0 |
| 単位ごとの接続 | 先行16、数値166、演算子の残り109−16 | L60.23 が16、.24 が166、.25 が93、和集合275 |

数値の公開モジュール別は Byte 9・Character 12・Decimal 8・Float 9・Float32 12・Integer 15・Integer8/16/32 各17・UnsignedInteger16/32 各16・UnsignedInteger64 18である。Integer64・UnsignedInteger・UnsignedInteger8・Float64 の別名は本体側へ対応し、この166行へ再加算しない。

族別も、Scalar 13・ByteString 1・Character 10・NumericRemaining 10・IntegerAPI 67・IntegerText 21・Conversion 12・Decimal 6・FloatMath 12・MinMax 14で166となる。演算子は Arithmetic 25・Order 48・Operator 34・Structural 2で109となる。API の利用可能性と Ordered の副条件は実引数で閉じる。Decimal.fromFloat は NumericRemaining の同じ bits から作る δ を使い、自由な parsed を足していない。

%eq/%ne の行は、Equality の制約を持つ一つの型パラメータの `fullSignature signatureBase.sat` である。`builtins P` の sat はこの同じ sat なので `StandardStructuralEqualityResponse.response` をそのまま当てられる。旧 scalar の証拠を別の署名へ分裂させていない。不適格な構造の比較の InternalComparison と Rust の Stop::Internal の比較は、R50 の申し送りとして保持されている。

### 2. 前提を満たす入力と四分類

入力証人の全場合の枝は、契約の全場合の枝と同じ集合である。数値は unary 68・binary 72・Option 25・round 1、演算子は unary 7・binary 100・equality 2である。合計は unary 75・binary 172・Option 25・round 1・equality 2＝275となり、inputs.json の内訳とも一致する。

`unary_arguments`・`binary_arguments`・`option_arguments` は、RowTransport・範囲許容・型/行の適用・実引数列の型付け・Ground・正規化した結果型/効果まで、BuiltinArgs の全欄を構成する。binary の名前の相異、Option の arity も供給する。`sample_typed` の定数は各型の ConstOK を満たす。round_arguments は実際に宣言した HalfToEven と Decimal・Integer の定数を使い、equality_arguments は型引数 Integer と同じ sat の Equality 制約を満たす。lookup はいずれも同じ行の row_lookup である。

したがって前提は空疎ではなく、結論も固定の err だけで閉じる形ではない。応答は各族の既存証明から、同じ入力の実 δ の値として得る。conditions.json の全275行を実質とする判定は、detail 第2.4節の定義に合う。三モデルの87欄（実質76・空疎8・自明3）は群 C/E の別の表であり、ここへ加算していない。行ごとの証明を全表の delta_typed 完成とする記述もない。

検査2では任意の row と分類の証拠を保ったまま、numeric_inputs/operator_inputs の全存在引数を取り出して numeric_rows/operator_rows へ当て、同じ δ の存在・非exit・型付け・適格性を得た。個別の定数の計算による全称の代用はしていない。

### 3. 三署名と群 E の追随

三署名は、Rust 登録の呼出し区分と引数数、標準ソースの型パラメータ・名前・引数型・結果型・効果と合う。Reference.new は `[value] → Reference[T]` と State、Reference.update は Reference[T] と純粋な `function(value: T) -> T` から Unit と State、Lazy.force は Lazy[T] から T と空効果である。型引数の種類はいずれも value で、opEff はない。

Primitive.p374〜p376 は署名を直接持ち、provider は既存の signatureBase である。StandardModelResponse の δ・IO 応答の定義は変更されていない。これらの名前で provider が δ・IO 応答を返す枝もない。実行は、作成が E_RefNew、更新が E_RefUpdate、遅延が E_ForceDone/E_Force であり、δ・IO 応答を前提に取らない。更新先は B.refGet/refSet の既存の名前である。

Primitive.store_rows は全行の場合分けから五行を特定する。store_lookup は refGet/refSet に絞って ModelTargets の同じ署名を返し、store_transitions は新しい三種類の lookup を名前と署名へ戻す。store_shape は五種類を全て扱い、reference_rows は StoreShape・value kind・元の依存列の RowsIn・opEff=none を同じ lookup から返す。変更した本番の読者と適用例は追随し、九つの単独ソース検査も通った。群 E の過去の記録の扱いは情報1のとおりである。

Process.exit を加えない判定は正しい。ハンドラのない exit は E_Exit/E_IOErr が同じ B.ioResponse を読み、ハンドラのある場合は E_OpPrim が節へ移る。種類の署名だけでは io_exists の全型付き入力に応答を供給できない。既存のモデルの exit は全整数を exitCode へ写すが、Rust の Process.exit は `u8::try_from` で0〜255の外を ArgumentOutOfDomain とするため、このモデルを実 API の証拠に流用できない。本体の最新 plan は、この理由で仮定側に残す判断を既に記している。

### 4. 前段の契約・有限表・停止条件

StandardDecimalResponse の変更は、固定 program の証明を Declarations P の下の response_of へ一般化し、元の response を program_declarations で適用する形である。元の response と round_math などの外から見える署名は変わっていない。検査2でも元の response の完全な型を使って適用した。停止条件に当たる既存署名の変更ではない。Declarations が要求する範囲の説明だけは軽2に挙げた。

roundingMode の追加は declarations の末尾の構成子宣言である。program の defs、Body の元定義と参照名の写像、definitions_iff の署名は変わらず、任意の externals/f/d の双方向対応も検査2で使えた。宣言が増えるため signatureBase.sat が読むデータの要約も増えるが、既存の応答と新しい合成の証明は同じ sat を使っている。F07 の証明先は任意の externals と ExternalWF のままである。

台帳の親640行は保持し、L494・L495・L496 の三行だけを仮定から合成へ移すので、合成486→489・仮定154→151は正しい。Rust 参照も各行一つなので合成369→372・仮定154→151となる。L518 の Process.exit は仮定のまま理由だけを訂正している。既存275接続は親行の composition_lookup と同じ Primitive 行である。子キーの504→507は情報3に書いた。

群 A〜E の記録への差分はない。旧 Release、主な十言明、型付けの規則、外部宣言・篩・σ の規則の変更もない。新公理、独立の信頼条件、精密な外部状態、P を外部宣言なしへ限定する変更は見つからなかった。丸め方式の処理系の型名への対応は既存の Lean 名を保持したまま L70/R50 の申し送りであり、公開構文の選択を今回行っていない。

### 5. 守ること・写し・記録

新しい四モジュールと差分には、sorry・新しい axiom・native_decide・#eval、新しい maxHeartbeats/maxRecDepth、工程の ID はない。StandardModelDeclarations の body_lookup の800000と StandardModelSignatures の Primitive.signature の1600000は基準の版からある設定で、今回追加していない。private の補助は δ の一致、空の範囲、依存列の具体化を読む実際の証明で使われる。公開43入口も名前付きの読者38又は既定ビルドの適用例7を持ち、両方を持つ重なりを二重に入口数へ加えていない。重複した例だけを保つための本番定義は見つからなかった。

写しの差分は参照の五行・純粋応答の契約・Decimal の一般化と対応表に限る。経緯、工程の ID、四分類の集計は追加していない。内容上の修正点は軽1〜4に挙げた。新しい用語を選ぶ必要のある変更はない。

記録は36ファイル・907,590バイト、最大84,155バイトで、各100 KB 以下である。宣言の写しは群末の167宣言の八分割一回分で、private は54件である。生成された長い型4件は大きさとハッシュだけを持つ。分割記録のハッシュは全て一致した。tools.json が記す本番・台本・写しの入力ハッシュにも、現在のファイルとの差はなかった。担当の全環境監査は84,025宣言・許可三公理の部分集合・sorryAx 0・新公理0と記録され、台本は所属モジュールから private と生成宣言を含む閉包を求める。宣言名の接頭辞だけで対象を絞っていない。本レビューでの代表8定理の公理依存も同じ範囲である。

verify.py は記録の整合、全場合の枝の集合、既定 import、読者の依存、台帳差分の証拠名、ファイルの大きさを照合する。一方、conditions.py は全行の判定を実質として書く台本であり、それ自体は分類の証明ではない。本レビューでは証明と前提の証人、既存証拠からの独立集計を根拠にした。群 E の照合が現在のままでは通らないことも、実行せずに消した名前と照合の入力を読んで確定した。

義務の判定では、O062 は数値・演算子の担当分だけ、O065 は五行の StoreShape と共有宣言だけを進め、全行の判定を .29 へ残している。H13/S18 の構成子 lookup と arity、S20 の同じ bits、S21 の任意 P/B の証拠の使用、S22 の演算子の接続は供給されている。O022/H03/S03 の同じ out/toTerm? から facts を作る接続は今回実装されず、results.md は未実施であることと .29 への残りを記す。行の契約の完成を facts の完成とはしていない。S19 の生 lambda/closure の扱いと R50 の比較も後段に残る。全体の義務を閉じたという誤った判定はない。

## 実行した検査

| 番号 | 検査 | 結果 |
|---|---|---|
| 1 | `<repo>/formal/` で `lake env lean -M 12288 Benitoite/Release/Refinement/<module>.lean`。対象は StandardModelDeclarations、StandardModelSignatures、StandardModelPrimitiveLookup、StandardDecimalResponse、ResourceReleaseLeaves、新しい四モジュールの計9件。単独で順に実行し、既定ビルドの出力を書き出さない | 全件終了0、出力0バイト。順に17.50・12.05・73.91・1.34・8.35・1.44・4.98・3.70・4.63秒、計約128秒。出力と source-checks.json は `<tmp>/rv-l60-f1/` に保存 |
| 2 | `<tmp>/rv-l60-f1/probe.lean`（import Benitoite）を同じ単独 Lean で検査。任意の行について契約と入力証人を組み合わせる二つの例、delta_typed の当該行への適用、元の Decimal.response の署名、三署名の StoreShape、definitions_iff の任意 lookup。代表8定理の #print axioms | 最終版は終了0、約0.75秒。公理依存は propext・Classical.choice・Quot.sound の部分集合だけ。初版はレビュー用入力の PrimName と decimalDelta の名前解決二箇所を誤り、完全名へ直した。本番の変更はない。最終入力の SHA-256 は `d67557ccc84644226ddedd466c8d67279822e021130c24825c9b67e137eb0167` |
| 3 | 読み取りだけの Python で、群 A の台帳・L40 の E01/E02/E03 の入力・Primitive の名前と分類・証明と入力証人の枝・conditions.json・ledger-diff.json を独立集計 | 数値166、演算子109、先行16と残り93、重複・漏れ0。入力の形275、全行実質275。親640行の三行移動と、helper を含む子504→507を確認 |
| 4 | 読み取りだけの Python と git diff で、宣言分割の件数・サイズ・ハッシュ、tools.json の入力ハッシュ、群 A〜E の記録の不変、禁止構文と import を確認 | 宣言167・private54、記録36ファイル。宣言分割と記録された入力のハッシュは全件一致。群 A〜E の差分0。新しい四モジュールは既定 import に含まれる |

実行環境のプロセス一覧の取得は権限で拒否されたため、その結果を検証の根拠に使っていない。自分が起動した Lean は、一つの実行の終了を受け取ってから次を起動した。

## 再開1の再レビュー

2026-11-05。**可**。軽1〜4・情報1・情報3の処置を確認した。新しい所見は重0・中0・軽0・情報0である。情報2の限定は引き続き保持されている。

今回の対象は、[担当の再開1の記録](../l60/f1/results.md#再開1rv-l60f1-の処置)、所見に対応する docstring、01-12・07-04 の該当段落と対応表、群 E の二つの記録と照合台本、F1 の台帳差分・照合台本・入力ハッシュ・ビルドと監査の記録である。本体の作業木の `plan.md`「計画の変更と取りまとめへの確認点」の先頭にある、群末の照合台本の扱いの最新判断も読んだ。Lean・lake・verify.py・scripts/check.sh は実行していない。以下の判定は差分と記録の読解、および読み取りだけの Python によるハッシュ・文字列・件数の照合に基づく。再開1の既定ビルドと公理監査の成功は担当の保存記録によるもので、本レビューの再実行結果ではない。

| 所見 | 確認した処置と判定 |
|---|---|
| 軽1 | `StandardModelOperatorRows` の冒頭、`Primitive.operator` の docstring、F1 の「L60.25」、01-12 は、%Map.replaceValues・%eq・%ne を除いた107行と %eq/%ne の2行、又は %Map.replaceValues だけを除いた109行と書き分けている。`StandardModelPureInputs` も107行に当てる基本型の補題と %eq/%ne の専用の補題を分けている。集合の重なりを生む説明は解消した。 |
| 軽2 | `Declarations`・`response_of` の docstring と両章は、Option の二構成子と arity、RoundingMode の構成子の上限という条件に一致した。五方式の各構成子の存在を要求しないことを明記し、固定の program と合成プログラムが全五方式を宣言する事実を分けている。前提を増やす処置はない。 |
| 軽3 | 01-12 に `PureRow.Satisfiable`・`numeric_inputs`・`operator_inputs` と、Decimal.round の丸め方式の構成子、%eq/%ne の型引数 Integer が追加された。07-04 の段落と対応表にも `StandardModelPureInputs` と各行の契約の前提を満たす入力が加わった。lookup と同じ署名の `BuiltinArgs` を満たすという範囲であり、正常値の存在や全表の完成へ保証を広げていない。 |
| 軽4 | 01-12 と `PureRow.of_row` の docstring は、対象を組込みの表の行（`StandardModel.Primitive`、同じ名前空間内では `Primitive`）とした。本番の契約と記録の台帳を区別できる。 |
| 情報1 | 群 E の `resources.json` は、証拠名 `StandardModel.no_store_transitions` の3箇所を `StandardModel.store_transitions` へ置き換えただけである。逆置換したバイト列は基準版と一致した。`results.md` は基準版の全文を保持し、末尾に空行と指定の一行だけを追加している。分類・理由・過去の宣言の写し、ledger.py・verify.py を含む他の群 E の記録への差分はない。 |
| 情報3 | `ledger-diff.json` の `summary.composition_child_keys` と F1 の「台帳の差分」に、504→507、本体130・組込み署名373→376・資源名1が明記された。読み取りだけで `Body.all` の130行、`Primitive` の376構成子、群 A の504キーを数え直して一致した。丸め方式の構成子を加算していない。三行の移動、親640行、接続275行の既存の判定は保持されている。 |

変更範囲の説明と照合台本にも、所見に対応しない拡張は見つからなかった。`design_copies.py` の置換表を静的に読み、両章の置換を逆に戻すと基準版の全文に一致することを確かめた。F1 の `tools.json` が保存した本番・写し・台本の入力ハッシュは現在のファイルと全件一致した。Lean の処置箇所は説明であり、契約の型・値や数値166行・演算子109行の集合を変更する処置は見つからなかった。

F1 の `verify.py` に追加した群 E の照合は、変更を許す既存ファイルへ二つの記録だけを加え、資源の記録を逆置換し、結果の記録から固定の末尾一行を除いて、それぞれ開始時のハッシュへ戻す形である。今回の実差分を独立に基準版と比較した結果も同じであり、群 E の分類や理由まで書き換えることを許す照合ではない。子キーの集計を足した `ledger_diff.py` も、本体と署名の実ソースと群 A の集計を入力にしている。

群 E の `verify.py` を群末の記録として保持する取りまとめの判断は妥当である。同台本の第1段は群 E の開始時の全ファイルと群末の追加ファイルの集合を固定し、第2段と第5段は群 E の監査出力の対象宣言を読む。したがって、後から群 D・F1 を加えた状態の照合へ、そのまま適用できない。`no_store_transitions` の字面を台本自身は持たず、資源の記録から証拠名を読むので、字面だけを置き換える修正も不要である。担当が記録した終了1は第1段の追加ファイルの照合によるもので、旧名の残存による失敗とする説明は解消している。

ただし、群 E の保存済み監査には新しい `store_transitions` がないため、現在の `resources.json` を群 E の過去の監査だけで検証済みとは扱えない。再開1はこの区別を記し、F1 の現在の監査を使った証拠名23件の照合を別に報告している。置換先は F1 の宣言記録にも実在する。群 E の分類と理由は当時の記録として残し、現在の三行の分類と署名は F1 の台帳差分・署名の照合・監査で引き継ぎ、段全体の照合は群 H に割り当てるという最新判断に不足はない。

本節の追記だけを行い、他のファイルの変更と git の書き込み操作は行っていない。

## 取りまとめの追記

2026-11-05。群 F1 は Claude の実装担当が実装し、独立レビューは Codex が行った（plan.md の担当の割り当ての決定）。軽1〜4・情報1・情報3は再開1で処置し、再レビューは可であった。`Process.exit` を仮定側に残す判断と、前の群の `verify.py` を群末の記録として残す判断は、plan.md の「計画の変更と取りまとめへの確認点」に記録した。再開1の後に取りまとめが `scripts/check.sh --level work --base d0f7b3051f74dfefb73a6ef6b3edd59ba734dfb1` を実行し、終了0（630.68秒）であった。
