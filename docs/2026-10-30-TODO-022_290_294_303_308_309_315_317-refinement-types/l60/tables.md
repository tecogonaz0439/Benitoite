# L60 第2.5節の表と既存証拠の入力

2026-11-05。[detailの第2.5節](detail.md#25-証拠を合成する行と仮定の側に残す登録)から分けた。登録部分・公開モジュールの既存表を本書へ移し、再開2でLean側の入力と照合条件を固定した。

## 証拠を合成する行と仮定の側に残す登録

公開APIの集計は[L40/g/apis.json](../l40/g/apis.json)の23モジュール328公開API（pure244/core84）であり、名前と証拠は[行別記録](../l40/e/sources-r4-u28.json)の328行にある。これと、Rustの`builtins::funcs::PARTS`の61部分523登録参照を分ける。後者は配列の`::DECL`の静的集計で、http_client::PURE_DECLSはchecked_request::DECLSの3件へ展開した。固有名数や条件付き登録の検査ではない。未登録の%Map.replaceValues・発行・安全な入口は523へ機械的に足さない。

J60-3=(a)により、本書の「全実表」は**既存のLeanの実δ・本体・応答の証拠がある全行を同じP/Bへ合成する表**を指す。本節の「Lean側から固定する既存証拠」のE01〜E15を閉じた入力とし、同じ名前・署名の重なりを除いて合成漏れを0にする。Rustの全登録の意味をこの表へ定義する要求ではない。提供範囲と利用者の書ける形は変えない。

.04はRustの523参照からの展開と、E01〜E15のLean側からの展開を独立に行い、両方を名前へ対応させる台帳を作る。台帳の列は「出典ID・元の登録部分/出典行・Rust名・Lean名・証拠の完全名・証拠への引数/射影・合成/仮定・担当単位・07-04の仮定に入る理由」とする。証拠が複数あれば同じ行に全件を持たせ、別の署名の証拠は子行として保持する。公開名はモジュール単位にまとめず一名一行、資源名も一名一行とする。Rustに登録のない内部名はRust名を「該当なし（内部名）」とし、Rust側の登録一覧から落ちてもLean側の入力から必ず台帳へ入れる。`%Integer.add`のような内部名とRustの登録名が同じか別かも列で明示する。仮定側の理由は、当該名のδ・IO応答又は通常解放が既存の条件で量化される一方、実体の算法・状態に対応するLeanの証拠を持たないことを記す。名前の不在だけで理由を済ませない。重複登録は元の参照を残して同じ名前の行へ対応させる。

Regex・Time・Path・Csv・Task・Encoding・TaskGroup・Json・Hash等の証拠のない公開名と、HttpListener・HttpExchange・TaskGroup等の資源は仮定側に残す。07-04「形式化で仮定するもの」どおり、δ・IO応答の条件は定理の引数として明示し、無矛盾をモデルで確かめる。台帳はその既存境界を記録し、新しい公理やsemantic provider、無条件errの代用を作らない。R50へ名前と理由を渡す。

次の61部分・523参照は台帳の入力であり、各部分の全件を合成する指定ではない。合成側の衝突名（%eq/%ne、List.map等）は採る署名・δを一つに固定し、証拠→lookupとlookup→証拠を照合する。E01〜E15の各出典行に属する全証拠から台帳の合成行への対応も別に照合し、仮定側の全行の証拠の完全名の列が空であることを確認する。

## Rustの登録部分

| 登録部分（Rust funcs/からの相対名） | 登録参照数 |
|---|---:|
| `operators::DECLS` | 43 |
| `integer::DECLS` | 15 |
| `float::DECLS` | 9 |
| `character::DECLS` | 5 |
| `string::DECLS` | 18 |
| `boolean::DECLS` | 1 |
| `byte::DECLS` | 9 |
| `decimal::DECLS` | 8 |
| `list::DECLS` | 18 |
| `map::DECLS` | 3 |
| `set::DECLS` | 3 |
| `io_error::DECLS` | 2 |
| `reference::DECLS` | 4 |
| `lazy::DECLS` | 1 |
| `task::DECLS` | 5 |
| `task_group::DECLS` | 2 |
| `traits::DECLS` | 2 |
| `console::DECLS` | 6 |
| `file::DECLS` | 6 |
| `process::DECLS` | 2 |
| `clock::DECLS` | 2 |
| `assert::DECLS` | 4 |
| `character::UNICODE_DECLS` | 7 |
| `string::UNICODE_DECLS` | 2 |
| `map::MORE_DECLS` | 7 |
| `set::MORE_DECLS` | 7 |
| `string::UTF8_DECLS` | 2 |
| `bytes::DECLS` | 16 |
| `network_error::DECLS` | 2 |
| `console::MORE_DECLS` | 2 |
| `process::ENVIRONMENT_DECLS` | 3 |
| `clock::MORE_DECLS` | 2 |
| `file::PATH_DECLS` | 13 |
| `file::RESOURCE_DECLS` | 6 |
| `process::RUN_DECLS` | 3 |
| `random::DECLS` | 9 |
| `path::DECLS` | 10 |
| `json::DECLS` | 3 |
| `regex::DECLS` | 12 |
| `csv::DECLS` | 5 |
| `time::DECLS` | 11 |
| `encoding::DECLS` | 4 |
| `hash::DECLS` | 1 |
| `http_server::DECLS` | 7 |
| `http_util::DECLS` | 1 |
| `http_client::DECLS` | 1 |
| `operators::signed::DECLS` | 18 |
| `operators::unsigned::DECLS` | 15 |
| `operators::float32::DECLS` | 5 |
| `width::DECLS` | 35 |
| `narrow_integer::DECLS` | 45 |
| `unsigned_integer64::DECLS` | 11 |
| `float32::DECLS` | 11 |
| `width_bits::DECLS` | 39 |
| `scope::DECLS` | 6 |
| `log::DECLS` | 4 |
| `string::DISPLAY_WIDTH_DECLS` | 6 |
| `format::DECLS` | 14 |
| `http_client::PURE_DECLS` | 3 |
| `file::SCOPED_DECLS` | 6 |
| `http_client::SCOPED_DECLS` | 1 |


61部分・523登録参照には、型付けの規則の8kind（pure/io/exit/refNew/refGet/refSet/refUpdate/force）が使われる。PathBasesはL50で置いた9番目のkindであり、現行Rustの登録数に含めない。合成対象の全lookupを9kindへ分解し、pureには実δの存在・型・適格性・非exit、io/exitには同じ関係の全応答と存在・kind・対象条件、残る5種には専用遷移とStoreShapeを供給する。externalはこの9kindに加えず別の宣言表・応答関係のまま保つ。

## L40の公開モジュール

| L40で証明済みの公開モジュール | 行数 | 合成の担当 |
|---|---:|---|
| Byte | 9 | .24/.25 |
| Character | 12 | .24/.25 |
| Float | 9 | .24/.25 |
| Float32 | 12 | .24/.25 |
| Decimal | 8 | .24/.25 |
| String | 28 | .26/.27 |
| Bytes | 16 | .26/.27 |
| List | 21 | .26/.27 |
| Map | 14 | .26/.27 |
| Set | 14 | .26/.27 |
| Range | 13 | .26/.27 |
| NonEmptyList | 5 | .26/.27 |
| Integer | 15 | .24/.25 |
| Integer8 | 17 | .24/.25 |
| Integer16 | 17 | .24/.25 |
| Integer32 | 17 | .24/.25 |
| Integer64 | 15 | .24/.25 |
| UnsignedInteger | 18 | .24/.25 |
| UnsignedInteger8 | 9 | .24/.25 |
| UnsignedInteger16 | 16 | .24/.25 |
| UnsignedInteger32 | 16 | .24/.25 |
| UnsignedInteger64 | 18 | .24/.25 |
| Float64 | 9 | .24/.25 |

この328行の証拠は、新しいP/Bの全表についてはまだ構成されていない。特にcore84行の全`Def.WellTyped`、共有のOption/Result/Pair/Error等の宣言、重複するhelperの選択が残る。`StandardCollectionRefinedBodies.program_typed`は11定義・8署名の具体表の証拠であり、標準全体の証拠ではない。単独の`table_response`を全表の`ResponseAssumptions`として引用しない。

演算子の母集団はL40の107行であり、73既接続＋追加34（整数div/mod14、Float二幅10、Decimal5、String5）である。`%eq/%ne`の全構造値の2行は同じ名前の実装の統一であって、107へ無条件に2を加えない。`Decimal.fromFloat`は`StandardNumericRemainingResponse`の同じbitsからparsedを作る入口を使う。失敗する比較を実装で不具合となるStop::Internalとどう照合するかは、RV-L40.gで処分済みのR50への申し送りを保持し、Leanの関係をL60で勝手に変えない。

.04はJ60-3の結果待ちではなく、決定済みの境界で名前を分類する単位である。仮定側の名前に合成表のlookupや新しい意味を作らない。既存証拠があるのに合成できない行は独立の未完として返し、仮定側へ移して完了にしない。

## Lean側から固定する既存証拠

L60.04で作る一覧の入力は次の15集合に限って列挙し、末尾を「等」で開かない。件数は出典の行又は有限リストの要素数であり、定理の宣言数や重複を除いた登録名数ではない。E01の証拠名は次表で全組を列挙し、各名前への対応は行別記録の`rows`を正とする。E02/E03は旧未完の状態をそのまま継承せず、再開2の記録と組み合わせる。

Leanの定義・証拠の完全名は、表中の`R.`を`Benitoite.Release.Refinement.`へ展開したものとする。実装時の台帳では省略せず、全名と引数/射影を別列に保存する。以下のパスは全てこの改造の保存済み記録又は現行Leanのソースであり、作業用ディレクトリを根拠にしない。

| 出典ID | 一覧を閉じる出どころと選択条件 | 出典別の件数 | 既存の証拠・定義と受け口 |
|---|---|---:|---|
| E01 | [apis.json](../l40/g/apis.json)の23モジュールと[source_recordの実体](../l40/e/sources-r4-u28.json)の全`rows`。`api`と`evidence`を同じ行から取る | 328（pure244/core84） | 下の全証拠組。`.24/.26/.27`へ。集計ファイル単独には328個の名前・証拠は入っていない |
| E02 | [operators-r1-u28.json](../l40/e/operators-r1-u28.json)の`rows`で`ordinary = pure-leaf` | 73（算術25/順序48） | `R.StandardArithmeticResponse.response_math/table_response`、`R.StandardOrderResponse.response_math/table_response`。`.25`へ |
| E03 | [resume2-operators.json](../l40/g/resume2-operators.json)の全`operators`と[StandardOperatorResponse](../../../formal/Benitoite/Release/Refinement/StandardOperatorResponse.lean)の`entries`を照合 | 34（整数14/Float二幅10/Decimal5/String5） | `R.StandardOperatorResponse.entries_count/entries_unique/response/table_response`と、記録の各`response`・`instantiation`。`.25`へ |
| E04 | [構造等号の現行証拠](../../../formal/Benitoite/Release/Refinement/StandardStructuralEqualityResponse.lean)のBool二値、名前は`%eq/%ne`。旧JSONの`full_equality`の不足判定は[L40再開2](../l40/g/results.md#再開2-算術δ構造等号通常decoderの接続)で更新済み | 2 | `R.StandardStructuralEqualityResponse.response/table_response/reply_normal`。旧scalar領域の証拠も対応を保持し、全構造値の証拠を採る。`.25`へ |
| E05 | [ScopeSignatures.entries](../../../formal/Benitoite/Release/Refinement/ScopeSignatures.lean)のpure行：Scope.checkPathIn/pathInValue/widenPathIn、Http.checkRequestIn/requestInValue/widenRequestIn | 6 | [ScopeResponse](../../../formal/Benitoite/Release/Refinement/ScopeResponse.lean)の`R.ScopeResponse.response/delta_typed/outcome_typed/ground/normal_facts`。`.28`へ |
| E06 | 同じentriesのIO行：File.readTextIn/readBytesIn/writeTextIn/writeBytesIn/appendTextIn/appendBytesIn、Http.sendIn | 7 | [ScopedIOResponse](../../../formal/Benitoite/Release/Refinement/ScopedIOResponse.lean)の`R.ScopedIOResponse.response/io_typed/io_exists/io_kind/targetAgreement`、個別七定理。`.28`へ |
| E07 | [Model.entries](../../../formal/Benitoite/Release/Refinement/Model.lean)の全行：Reference.get/set、Example.pathBases | 3 | `R.Model.sig_cases/substitutionAssumptions/scopeConditions`。pure/IO応答の証拠は空疎と分け、参照/発行を`.28`へ、25欄を`.12/.22`へ |
| E08 | [ModelTargets.entries](../../../formal/Benitoite/Release/Refinement/ModelTargets.lean)の全行：E07の3名、print/exit/File.readText、E05のScope三名、E06のFile六名 | 15 | `R.ModelTargets.sig_cases/pure_response/io_typed/io_kind/io_exists/targetAgreement/scopeConditions`。print/exit/File.readTextの応答も`.28`へ、25欄を`.13/.22`へ |
| E09 | [ModelHttp.entries](../../../formal/Benitoite/Release/Refinement/ModelHttpConditions.lean)の全行：E07の3名、E05のHttp三名、Http.sendIn | 7 | `R.ModelHttp.sig_cases/pure_response/io_typed/io_kind/io_exists/targetAgreement/scopeConditions`。`.13/.22/.28`へ |
| E10 | [ModelTargets.builtins](../../../formal/Benitoite/Release/Refinement/ModelTargets.lean)のisResourceがtrueになる通常資源名File.Handle | 1 | `R.ModelTargets.builtins`の分類と同ファイルの「File.Handle は通常資源」の無名例。型付きopaque値と分類の既存証拠であり、新しい解放関係の存在の証明ではない。`.19/.21/.28`へ。無名例は位置と出力命題を記録し、存在しない有名定理を補わない |
| E11 | [StandardSafeBodies](../../../formal/Benitoite/Release/Refinement/StandardSafeBodies.lean)の`R.StandardSafe.bodyRows`全要素 | 7 | `R.StandardSafe.registered_bodies`と個別`head_row_typed/get_row_typed/checked_row_typed/same_row_typed/fromList_row_typed/toList_row_typed/nonempty_head_row_typed`。`.27`へ |
| E12 | 同ファイルの`R.StandardSafe.PreciseGetter.all`全要素 | 9 | `R.StandardSafe.precise_row_typed/precise_rows_typed`。E01の公開名との重なりを保ち、精密署名の子行として`.27`へ |
| E13 | [StandardCollectionRefinedBodies](../../../formal/Benitoite/Release/Refinement/StandardCollectionRefinedBodies.lean)の`coreRows`全要素（先頭7＋API.allの4） | 11 | `R.StandardCollectionRefinedBodies.core_rows_typed/definition_typed/program_typed/seven_public_rows`。公開精密7行は11の内数であり、追加しない。`.27`へ |
| E14 | [StandardMapReplaceValues](../../../formal/Benitoite/Release/Refinement/StandardMapReplaceValues.lean)の`%Map.replaceValues` | 1 | `R.StandardMapReplaceValues.response/delta_aligned`。E01にはない内部のpure名を`.26/.27`へ |
| E15 | [StandardOrdinaryCoreProgram](../../../formal/Benitoite/Release/Refinement/StandardOrdinaryCoreProgram.lean)の`allDefinitions`全要素（API10＋StandardOrdinaryListBodies.definitions10＋StandardOrdinaryCoreBodies.definitions24＋supportDefinitions4） | 48 | `R.StandardOrdinaryCoreProgram.all_lookup_typed`。通常公開27行は内数。Listのhelper、12 getterの内部/公開24行、Pair.first/second、List.map/mapFromを含め、E01/E13との重なりを保って`.27`へ |

出典別の延べ行数は**552＝328＋73＋34＋2＋6＋7＋3＋15＋7＋1＋7＋9＋11＋1＋48**である。三モデルの延べ25登録行と75条件、File.Handleの分類1件、coreの本体行を、pureのAPI件数と同じ意味の件数として合算しない。552は出典からの展開の件数確認にだけ使う。E04の2名は107演算子の外の全構造値の証拠として別に照合するが、%eq/%neと重なる既存証拠を一つのlookupへ対応させ、無条件に109固有名と報告しない。

三モデルの75欄は[ScopeModels.conditions](../../../formal/Benitoite/Release/Refinement/ScopeModels.lean)と[L50/j/conditions](../l50/j/conditions.md)の25×3を閉じた別表とする。既存証拠の各射影を新しいBへ移す一覧へ全75欄を対応させ、552行の登録の展開には加算しない。L60に残る12欄はdetail第2.4節の目標であり、既存75欄へ紛れ込ませない。

E11〜E15は第2.5節で既に要求したcore本体・helper・精密な署名の出典を固定したもので、公開範囲や実装作業を増やすものではない。E01の84 core行にはalias51、通常core27、Listのmap/filter2、Map/Setのmap/filter4が含まれる。alias51はE01の行別記録で閉じ、通常core27とhelperはE15で、精密7公開行とその参照先はE13で照合する。各集合の名前の一致だけで異なる署名・本体の証拠を捨てず、合成表で採る署名と、その証拠が適用できる副条件を台帳に残す。共有のデータ宣言・arity・kindはこれらの証拠が要求する有限表から収集し、応答行数へ加算しない。

### E01の全328行が参照する証拠名の組と件数

次表は行別記録の`evidence`を組ごとに集計した全件である。表中の`R.`は上記の接頭辞へ展開する。`table_response`は元の小表の証拠として記録し、合成表へは同じ行の任意P/Bの応答補題又は本体の証拠から接続する。`.04`で各行のLean名と証拠の所在・全名を照合し、文字列の存在だけを適用可能性の根拠にしない。

| 行数 | 行別記録の証拠の完全名（R.を展開） |
|---:|---|
| 1 | `R.StandardScalarResponse.table_response`、`R.StandardScalarResponse.byteFrom_math` |
| 1 | `R.StandardScalarResponse.table_response`、`R.StandardScalarResponse.byteTo_math` |
| 1 | `R.StandardByteStringResponse.table_response`、`R.StandardByteStringResponse.response` |
| 6 | `R.StandardScalarResponse.table_response`、`R.StandardScalarResponse.byte_bits_math` |
| 1 | `R.StandardScalarResponse.table_response`、`R.StandardScalarResponse.characterTo_math` |
| 1 | `R.StandardScalarResponse.table_response`、`R.StandardScalarResponse.characterFrom_math` |
| 10 | `R.StandardCharacterResponse.table_response`、`R.StandardCharacterResponse.response` |
| 9 | `R.StandardNumericRemainingResponse.table_response`、`R.StandardNumericRemainingResponse.response` |
| 12 | `R.StandardFloatMathResponse.table_response`、`R.StandardFloatMathResponse.response` |
| 3 | `R.StandardScalarResponse.table_response`、`R.StandardScalarResponse.float_class_math` |
| 1 | `R.StandardDecimalResponse.table_response`、`R.StandardDecimalResponse.round_math` |
| 1 | `R.StandardDecimalResponse.table_response`、`R.StandardDecimalResponse.absolute_math` |
| 1 | `R.StandardDecimalResponse.table_response`、`R.StandardDecimalResponse.fromInteger_math` |
| 1 | `R.StandardDecimalResponse.table_response`、`R.StandardDecimalResponse.truncate_math` |
| 1 | `R.StandardDecimalResponse.fromFloat_exit`、`R.StandardNumericRemainingResponse.table_response`、`R.StandardNumericRemainingResponse.fromFloat_parsed`、`R.StandardNumericRemainingResponse.response` |
| 5 | `R.StandardBytesResponse.table_response`、`R.StandardBytesResponse.related_response` |
| 26 | `R.StandardStringOrdinaryResponse.table_response`、`R.StandardStringOrdinaryResponse.response` |
| 13 | `R.StandardBytesOrdinaryResponse.table_response`、`R.StandardBytesOrdinaryResponse.response` |
| 6 | `R.StandardListResponse.table_response`、`R.StandardListResponse.related_response` |
| 7 | `R.StandardListRemainingResponse.table_response`、`R.StandardListRemainingResponse.response` |
| 1 | `R.StandardListRemainingResponse.table_range_response`、`R.StandardListRemainingResponse.range_response` |
| 2 | `R.StandardActualListBodies.model_typed` |
| 27 | `R.StandardOrdinaryCoreProgram.declarations_typed`、`R.StandardOrdinaryCoreProgram.all_lookup_typed` |
| 10 | `R.StandardCollections.map_api_response`、`R.StandardCollectionModel.map_reply` |
| 4 | `R.StandardCollectionModel.typed` |
| 10 | `R.StandardCollections.set_api_response`、`R.StandardCollectionModel.set_reply` |
| 21 | `R.StandardIntegerTextResponse.table_response`、`R.StandardIntegerTextResponse.response` |
| 7 | `R.StandardIntegerAPI.table_response`、`R.StandardIntegerAPI.floor_math`、`R.StandardIntegerAPI.floor_equation` |
| 7 | `R.StandardIntegerAPI.table_response`、`R.StandardIntegerAPI.floor_math`、`R.StandardIntegerAPI.floor_equation`、`R.StandardIntegerAPI.modulo_no_overflow` |
| 7 | `R.StandardIntegerAPI.table_response`、`R.StandardIntegerAPI.absolute_response_math` |
| 14 | `R.StandardIntegerResponse.minMax_model_response`、`R.StandardIntegerResponse.minMax_response` |
| 46 | `R.StandardIntegerAPI.table_response`、`R.StandardIntegerAPI.bits_math` |
| 12 | `R.StandardConversionResponse.table_response`、`R.StandardConversionResponse.fromInteger_math`、`R.StandardConversionResponse.toInteger_math` |
| 51 | `R.StandardAliasBodies.declarations_typed` |
| 1 | `R.StandardDecimalResponse.table_response`、`R.StandardDecimalResponse.toDecimal_math` |
| 1 | `R.StandardDecimalResponse.table_response`、`R.StandardDecimalResponse.fromDecimal_math` |

### L60.04とL60.29で行う照合

L60.04はE01〜E15の552出典行と三モデル75欄のそれぞれに出典行IDを付けて固定する。証拠が指す名前・署名・本体を保持し、Rust名とLean名を対応させる。展開後の件数とハッシュ、重複を除く前後の件数、各出典行から台帳への対応を記録する。Rustの登録からだけ一覧を作らず、E14の内部名やE15のhelperにも行を作る。出典の欠落、証拠名の解決不能、署名の衝突は独立未完として報告し、入力から削って帳尻を合わせない。

L60.29は次の四照合を完了条件とし、入力・結果・件数を群F2の記録に保存する。

1. **全既存証拠 → 合成行**：E01〜E15の全出典行と、その行に属する全証拠を、台帳の合成行へ対応させる。出典別の展開件数が上表と一致し、対応なし0、仮定行への対応0であることを機械的に確認する。三モデル75欄は移送/合成の証拠の一覧へ全件を対応させる。
2. **仮定側の行に証拠名がないこと**：全仮定行の「証拠の完全名」が空であり、そのRust名・Lean名・別名/署名に対応するE01〜E15の証拠も0件であることを独立に照合する。分類時に証拠列を空にするだけでは完了しない。
3. **台帳の合成行 ↔ 合成表のlookup**：各合成行に同じ署名・同じδ/本体/応答・分類のlookupがあり、成功するlookupの全行に台帳の行があることを照合する。複数の証拠が一つのlookupへ対応する場合も、元の証拠ごとの対応を保持する。三モデルの行とFile.Handleはそれぞれ該当モデルのlookup、isResourceの分類にも対応させる。
4. **Rust登録 → 台帳**：61部分523参照を全て台帳へ対応させ、合成/仮定の分類、資源名、仮定の理由の欠落0を確認する。内部名のRust名は該当なしと明記し、無理にRustの登録へ追加しない。

証拠がある名前を仮定側へ分類した場合は1と2の両方が失敗する。既存証拠を合成できない場合は、既存の停止・相談条件に従って未完を返す。
