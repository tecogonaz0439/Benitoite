# L40 段末の照合と受け入れ資料

2026-11-04。群 G の実装担当による自己点検である。L40.36〜.38 と .40 の証拠をまとめる。L40.39 の独立レビュー応答は別の起動とし、設計者の受け入れは未実施である。ブランチの指定は `m014/l40.g`、B_WORK は `fcde6fe216d35c3c74fcaa8d28164df063b6aa8b`。Git の状態を変える操作は行っていない。

## 群G再開2

2026-11-04。三つの独立未完を閉じた。以下と[再開2の記録](g/results.md#再開2-算術δ構造等号通常decoderの接続)を現在の判定とし、後に残す初回・再開1の停止の記述は履歴として読む。自己点検であり、独立レビューと設計者の受け入れは未実施である。

| 対象 | 現在の結果 |
|---|---|
| 演算子34行 | 整数14・Float二幅10・Decimal5・String5。原署名の全BuiltinArgsから実名のδと型・Ground・AdequateResult・非exit。全34実名の表と重複なしを証明 |
| 構造等号 | Full署名の型引数・Equality sat・注釈を保持。scalar-domainの前提なし。既存の構造走査、正常値Boolean、失敗InternalComparison。Boolean を結論するのは正常の枝だけであり、型の付いた Equality の入力で `structuralEqual` が `none` を返す失敗の枝が起きないことは結論しない。 |
| O135 | 同じ通常実行の型付きResultから、同じError又は宣言順の検査済み構築値へ接続。事象列・更新後のストア、通常decoder自身のStopを保持 |
| 64義務 | 技術50の局所照合、独立未完0。O022/O034/O062/O065/O135/O144の6行を一部から更新。継承6・運用3・他段1・共通4、全体閉鎖0 |
| 33申し送り | 今回25・継承3・他段5を維持し、H02/H03の不足を解消 |
| 本番への追加 | 8モジュール・314宣言（private・生成を含む）。既存モジュールの追加と環境の実体化を合わせた全監査の増加は355宣言 |
| 全環境の公理監査 | 終了0、79.311秒。999モジュール・79,156宣言、実体化2周。変更337モジュール14,015宣言、新311モジュール11,209宣言を区別 |
| 公理依存 | none 36,808、Classical.choice 1、三公理すべて19,784、Classical.choice+propext 2、Quot.sound 9、Quot.sound+propext 3,848、propext 18,704。新公理・sorryAxは0 |
| 実署名 | 最新の段末監査から170件。全名・場所・型はaudit-summary.jsonと宣言・署名の分割記録 |
| work | 指定base・onlyなしで一回、終了0、8.990秒。仕様対応の自己検査・集計、仕様例7成功・失敗0・無視0、既定lake buildとsorry拒否 |
| 既定ビルド | 今回のworkがformal_buildを選択して実行。成功時のlake出力はcheck.shが非表示にするためjobs数は未取得。独立の既定ビルドを重ねていない |

生出力の識別は次のとおりである。全名の写しは最新の段末監査一回分に置き換えた。

| 出力 | bytes | SHA-256 |
|---|---:|---|
| 公理監査 | 17,135,923 | `c7d4bf43918285f102588efa9c5d09adf678234bdf16cd1d42cd899a34df6da4` |
| 全対象一覧 | 5,176,154 | `f78f2b5f64dd96f18c32b00ddc32e0b089cfa95a389d05d180775d8c615b3f15` |
| work | 5,848 | `2092a30587ef37a7f6d195c8b0dce38a4dbdf01f8fa12154f8de911974d26be5` |

取りまとめには、今回の指定どおり、算術δ追加の方針を設計者の見直しの対象として渡す。新たな停止条件に当たる変更の判断は求めない。R50には、FloatのModelとRustのf64/f32の算術・NaN、Decimalの係数/scaleとWideの拒否、Stringの上限・順序、全構造等号とmalformed拒否を渡す。R40には生成器全体との接続、L60には全実表のCoreAssumptionsを保持する。今回の応答契約を、これらの比較・充足・受け入れが済んだ証拠としない。

正式RSS・全比較・独立レビュー・受け入れは未実施である。最終の記録照合は[resume2-verification.json](g/resume2-verification.json)と[台本](g/verify-resume2.py)を正とする。

## 群G再開3（L40.39）

[独立レビュー](../reviews/RV-L40.g.md)への[応答](g/review-response.md)を作成した。現在の契約の範囲・受渡しは、再開2の結果へ本節と後段の表の補足を合わせて読む。レビューの原本は変更していない。取りまとめによる独立の再確認と設計者の受け入れは未実施である。

中1は (a) の深さ・列の部分試行を行い、残りの型付き全構造の観測と Map の縮約・整列・燃料の証明を2時間30分〜4時間と見積もって、指定条件に従い (b) を選んだ。正常枝でだけ Boolean を結論し、型付き Equality で structuralEqual が none にならないことは R50 に残す。応答契約の局所証拠を、処理系の Stop::Internal の排除の証拠としない。

中2は算術 δ の追加を見直しの表と一覧へ補った。軽1〜4は義務ごとの証拠・後段の表・StandardDecode の全名・確定値の参照と対照の改名を処置した。情報1〜3は NaN の具体例・Decimal の到達しない分岐・decoded の型付けの供給と任意の record への一般化を後段の表へ加えた。情報4は処置不要で集計を維持する。最新の群末検査と時刻は g/results.md「再開3（L40.39）」に記す。

既定 lake build は終了0（1260 jobs）、段末の公理監査は終了0（999モジュール・79,156宣言、75.661秒、170署名、新公理・sorryAx は0）、指定の work は一回で終了0（4.292秒、仕様対応表の自己検査・集計、仕様例7成功、既定 lake build と sorry 拒否）であった。監査の宣言・署名の写しは audit-summary.json が指す最新の一回分を正とする。部分試行と改名後の対照も `lake env lean -M 12288` で終了0である。最終の入力・参照・記録の照合は g/resume3-verification.json を正とする。

## 全場合と義務・申し送り

[全場合の一行ずつの対応](g/cases.md)、[64義務の段別証拠と残る段](g/obligations.md)、[33申し送りの処分](g/handoffs.md)を正とする。具体の宣言と所在は [単位の証拠](g/unit-evidence.json)。全体の義務を今回閉鎖した行は0である。

| 母集団 | 照合結果 | 根拠 |
|---|---|---|
| plan の L40 担当 | 56行 | 担当欄から抽出。一般の本文の言及は数えない |
| L20 段末で L40 が残る行 | 37行 | 残る段の欄から抽出 |
| L30 段末で L40 が残る行 | 21行 | 同上 |
| 上記の和集合 | 60行 | 重複を義務番号で除く |
| plan との差 | O006/O015/O050/O054 の4行 | 脱落・二重計上なし |
| 全 L 共通の追加 | O016/O027/O084/O118 の4行 | 上記60行と重ならない |
| 照合対象全体 | 64行 | 技術50・継承6・運用3・他段1・共通4 |
| 申し送り | 今回25・継承3・他段5、計33行 | 出どころの行を保ち、同じ実装の利用を課題数へ加えない |
| 実行 | 76葉、継承69＋追加7、Stepを返す60＋到達型16 | 群 C の76行と現在の Step の全構成子が一致 |
| 独立評価 | 69＋4＋4＋6×3＋14＝109場合 | EvalStandard7は別の母集団。F1の同じ失敗成分の証明へ対応 |
| 同種の移植 | 旧31＝旧移植14＋既済み7＋供給側10、N_V=N_C=N_g=0 | var の移植1は A。新2目的 dependentLam/raise は旧移植へ加算しない |

O135 の通常decoderの接続は、群G再開2で `StandardDecode.decodeThen_normal/decodeThen_firstReturn`（StandardDecodeConnection）と `StandardDecode.postprocess_all`（StandardDecodeBodies） により閉じた。同じlet枠で通常実行が返した型付きResultをそのまま後処理へ渡し、Errorの同じpayload又はlo→hi→全体条件を検査した構築値を得る。事象列・更新後のストアを保持する。通常decoderの型付けから合成本体も型付け、通常decoder自身のStopは同じ理由列で外へ伝える。同じ有限なrecord宣言でのcoreの接続であり、生成器全体・全プログラムの宣言収集・Rustとの全比較は元の後段に残す。

328公開APIの外の演算子34行（整数div/mod14・Float二幅10・Decimal5・String5）も、再開2で原署名の全BuiltinArgsから同じ名前付きδのOutcome.Typed/Ground/AdequateResult/非exitへ接続した。[実名と原署名の対応](g/resume2-operators.json)と[写したRustの関数](g/resume2-sources.md)を参照する。`StandardOperatorResponse.table_response` は34実名の表のlookupと応答を結び、名前の重複がないことも証明する。`StandardStructuralEqualityResponse.table_response` は元のFull署名とT・Equality satを保持し、scalar-domainの前提なしで構造走査へ接続する。正常値はBoolean、構造の失敗はInternalComparisonである。Boolean を結論するのは正常の枝だけであり、型の付いた Equality の入力で `structuralEqual` が `none` を返す失敗の枝が起きないことは結論しない。通常179行、全328公開API、この34行は別の母集団として保持する。[旧不足と再開2の処置](g/additional-unresolved.json)には履歴を残す。

技術50行のうち、再開2でO022/O034/O062/O065/O135/O144の6行を「一部」から「担当分の局所証拠を照合」へ変更し、局所照合50・独立未完0とした。継承6・運用3・他段1・共通4の分類は維持する。申し送りは今回25・継承3・他段5の計33行を維持し、H02/H03の独立未完を閉じた。この集計は義務全体を閉鎖した行数ではない。全体の閉鎖は0行であり、段末の独立レビュー・正式RSS・設計者の受け入れは未実施である。

O005/O033 の全宣言の収集、O057〜O060 の主定理、O064 の実資源表の存在、O091/O169 の全表層と親実行の分解を、L40 の局所の証拠から全体の閉鎖へ繰り上げない。提供範囲 O124〜O144 は、各 R 段の型付け・本体、R50 の交換、V10 の実 CLI の判定を残す。

## F01〜F07 の現在の署名

以下の名前は `Benitoite.Release.Refinement.` を先頭に付けた完全名である。実際の暗黙引数・前提・存在量化・結論は環境監査で印字した署名の分割記録を正とする。場所は全宣言の一覧の source と line に対応する。

| 入口 | 現在の宣言と型の要点 | 固定時との差・受け手 |
|---|---|---|
| F01 | `HasTypeVQ.inv_var/inv_fnRef/inv_prim/inv_op/inv_lam/inv_dependentLam/inv_raise/inv_dict/inv_super`、CollectionInversion の `inv_mapV/inv_setV/inv_bytesV`。元の直接前提と芯の関係。関数は `fnCore` と `TelClosure`、Map鍵・Set要素・辞書は不変の等号 | A の再開で元の型全体から T への LeQ を芯と facts に改めた。L50/L60/L70はこの形を使う |
| F02 | `TelClosure.apply`。`Ctx.WF 0 C.length Γ`、元列 t の Annotation、`TelClosure P Γ Φ t u`、同じ ws の u に対する `HasTypeTelArgsQ` から、同じ ws の t への型付け・結果 `Ty.LeQ b a`・`Eff.Covers e f` | A で Ctx.WF を追加、B で使わない四前提（P.WellFormed・CoreAssumptions・Ψ.WF・u の Annotation）を除いた。全開始の形成は `StateTyE.*_contract_inputs` と `app_inputs` が供給 |
| F03 | `HasTypeVQ.canonical_scalar/canonical_boolean/canonical_list/canonical_data/canonical_function`、専用 `inv_atError`、`StoreOk.ref_cell/lazy_cell/cont_cell/builder_cell`、`HasTypeCQ.inputs`・`StateTyE.inputs/lambda_inputs/match_inputs/if_inputs/guard_op_inputs` | app は無条件の直接二枝と形成付き `HasTypeCQ.app_tel` を分ける。全 Val25/Comp16/State4/Frame7/Cell6とB15全22行の供給側を保持。全有効σ・応答存在はL50/L60 |
| F04 | `normal_reply_facts/normal_reply_facts_at`。既存 CoreAssumptions、pure の署名、同じ BuiltinArgs、実 δ の同じ正常値と `toTerm?` の等号から、結果型の各最外の事実を Entails [] にする | 一般の応答契約を使う入口であり、具体 δ と算術の一致を推測しない。各 Standard*Response が具体の入力・δ・応答を供給 |
| F05 | `StandardKeyTyping.Table/KeyObservation/key_table_sound/key_values_sound/key_each_sound/key_closed_slots/key_map_normal/key_set_normal`。同じ有限宣言と P.cons、収束した要約、B.sat=satB、同じ P.VarianceValid、閉じた型付き値・sat成功から鍵の観測と構造を結論 | KeyObservation は Table の未検査欄ではない。有限な値で帰納。Mapのsizeへ値側の鍵化を要求しない。表層から同じ表を収集する接続はL70/R10b |
| F06 | `StandardContracts.Row/Row.BodyTyped`、各 `Standard*Response.response`（整数算術は `response_math`、min/max は `minMax_response`、List.range は `range_response`）、`StandardCollectionRefinedBodies.program_typed/response_assumptions/seven_public_rows`、`StandardSafe.precise_rows_typed`、`StandardMapReplaceValues.response/delta_aligned` | 通常328APIはpure244/core84、未接続0。328外の演算子34行とFull構造Equalityも再開2で接続。精密な七公開行＋九getterを別に証明。長さ・大きさはtelの篩とDef.WellTypedで検査し、callback順序はR40へ。全328を一つの新しいP/Bへ収集したことや全CoreAssumptionsの充足とは区別 |
| F07 | `tracked_failure_sound`、`IntervalFlowLeaves.joinV/normalF/returnF/seqF/joinF` と局所の所属、`IntervalConnection.H04.FirstFailureHandoff/first_failure_handoff/first_error/pure_failure`、`IntervalControlLeaves.normal_state_member/escape_mark_member/typed_first_failure` | 第一候補は全 Parameters のまま成立。第二候補は最初の位置だけ。旧 OldH04 の否定と同じ反例の受理を保持。分岐6入口は条件の h を含む seqF に揃い、error二葉は error_let_typed/error_mark_typed。全体合成はL70 |

## J40 の判定と設計者の見直し

| 項目 | 現在の判定 | 残る判断 |
|---|---|---|
| J40-1 | 同じ宣言の五代表で satB と Rust の型検査・IR 検査が一致。全有限値の鍵構造と具体 δ の局所応答を本番から証明。新公理・独立の信頼欄なし | 全実宣言の収集、三モデルの全欄、実 Rust との全比較は各後段。O135のcore接続は再開2で閉鎖。生成器全体はR40 |
| J40-2 | 第一候補は任意 Parameters で証明。第二候補は最初の失敗の位置へ限定した現行署名で本番化。局所正常/returnedを実構成から作る | 実 δ の理由と integerDelta の接続、親実行・表層・実解析の returned の供給はL70 |
| J40-3 | 同じ19行の内部契約の引数・結果を保持。NonEmptyList.fromListは Result[NE[T],EmptyListError]。旧Option/Resultを保つ | 公開名と字面はU02。NonEmptyの別名・名目性・表示・実IDはR40/D10 |
| J40-4 | 枠15〜35時間（中心25）を維持。個別積上げ22時間40分〜44時間25分は情報。c_V/c_Cは未取得。N_g=0 | 外側の時間を能動時間へ代入しない。Eの増えた作業と中断を含め、取りまとめが見込みを集約 |

設計者の見直しの対象と、既に設計者が決めたものを次表で分ける。L20/L30 の受け入れに含まれた以前の判断は再承認待ちへ戻さない。

| 対象・出どころ | 変更と実用への影響 | 現在の扱い |
|---|---|---|
| J40-3、plan 2026-11-03・RV-L40.a追記 | 安全19契約の呼び方。利用者の新しい安全な入口の字面に関わる | 設計者の見直し、U02へ同じ19行の表を提示 |
| E_Lam、plan 2026-11-03・群C | 捕捉から読んだ生lambdaを空捕捉でclosureへ閉じて適用。Stepの構成子は76のまま。実行関数と保存の葉も追随 | 取りまとめが採択、設計者の見直しの対象 |
| coreの正常関係、plan 2026-11-04・E再開2を含む | Stepsの返却関係から精密telの型付けへ。List/Map/Setのmap/filterの長さ・大きさを型で利用可能にする。callback順序はLeanの義務からR40の実行検査へ | 取りまとめが採択、設計者の見直しの対象。List.get/加算の精密署名の案は後の決定で不採用 |
| 腕の欄の等号とhead/tail、plan 2026-11-04 | 整数欄の値とList欄の長さの等号を単一の構成子パターンで供給。head/tailのhelperへ変更。型付けの規則の内容が変わる | 設計者の明示の決定済み。新しい再承認待ちにはしない。主な十言明の字面は不変 |
| %Map.replaceValues、plan 2026-11-04・E再開6 | Map.mapの同じキーと大きさを保つ新規の非公開組み込み。公開引数・型付けの規則は変えない | 取りまとめが採択、設計者の見直しの対象。R40で登録・署名・Rust実装を要する |
| 算術 δ の追加（plan 2026-11-04、群 G 再開2） | 演算子34行の δ を Float の標準の模型と処理系の Decimal・String の算法の写しで定める。Float の模型は NaN の payload と符号を正準化し、Rust と一致しない（R50 で照合）。型付けの規則・公開の署名は変えない | 取りまとめが採択、設計者の見直しの対象 |
| F2の再開1・2の計画との差 | 不足していた12入口と具体の読者、overflowの値域外条件、通常商の境界、分岐6入口のseqF統一、error二葉の改名 | 指定所見の処置。新しい仕様判断・主な十言明・型付け規則の変更なし。other Result二構成子はL70へ保持 |

## 後段への実署名と申し送り

| 受け手 | 本番の署名・証拠 | 残る作業・受け入れの境界 |
|---|---|---|
| L50 | F01〜F03、`StateTyE.primitive_contract_inputs/externalRef_contract_inputs`、HeldValues、ModelHttpの同じ要求、F04の正常値のfacts | 全有効σ、PathBases/At、Fileの6本とHttp.sendIn、shapeAt/TargetAgreement/io_exists。Topだけ・空ストアだけへ量化を縮めない |
| L60 | F02、`HasTypeVQ.inv_externalRef/inv_externalHandle`、各全BuiltinArgsのresponse、F05、`program_typed/response_assumptions` | borrow/own/State、external_typed/exists/no_targets、通常資源のrelease_exists、Model/ModelHttp/ModelTargets全欄。Decimal.fromFloatのparsedはStandardNumericRemainingResponseで同じbitsから供給する実装を利用。生lambda/closureの二表現をδ等が区別しない条件・比較の要否も確認。`StandardOperatorResponse.response` と `StandardStructuralEqualityResponse.response` は任意の P/B の元の全 BuiltinArgs を受け、L60 の合成に使う実署名である。それぞれの `table`/`table_response` は sig を置き換えた単独の表であり、328 API の表との合成は L60 が行う |
| L70 | F01〜F07、76葉とB15全22行、第一候補・最初の実失敗・局所二成分 | 主定理・効果・対象・表層・消去、実解析のreturned供給、親実行の分解、腕の束縛数、other Resultのtag/payload、全宣言の収集。`matchOtherNormal/matchOtherFailed` は選択腕の導出を持たないため局所join/seqだけで同じ値を結論しない。`StandardDecode.decodeThen_normal/decodeThen_firstReturn` の返却値 `decoded` の型付けは現在の前提であり、L70 の主定理の合成で通常 decoder の型付けと保存の定理から供給する |
| L70 | `IntervalConnection.H04.pure_failure/first_failure_handoff` と `StandardScalar.integerDelta`、`StandardIntegerFailure` | 最初の失敗の位置のδを、integerDeltaの具体のIntegerOverflow/DivisionByZero/ArgumentOutOfDomainの理由へ結ぶ。今回の二定理の並置をこの接続の完了とはしない |
| R40 | 精密telの17行、十一core定義と八純粋署名、`StandardMapReplaceValues.signature/delta/response/delta_aligned` | E results.md「署名の差」「本体の字面」の同じ依存列・本体へ標準ソースを揃える。非公開@builtin宣言の読込み・利用者からの名前呼出しの禁止を最初に確認。長さ不一致はStop::Internal、キーの表現・順を保って値だけ位置で入れ替える |
| R40 | `FieldLink/fieldFacts/LinksValid/FactsWF`、`CaptureOk.field_facts`・`MatchFacts.field_equality_true`、plain/guarded | 構成子の欄だけを経る全変数束縛から、整数は値の等号、Listは長さの等号を一つずつすべて生成。raw/slot・n−1−slot・n+i・同じ宣言表・sort・観測none・or除外・guard成功/失敗の条件を揃える。型パラメータのsort不明を整数扱いしない |
| R40 | head/tailによるmapFrom/filterFrom、Map.mapの内部補助 | callback順・回数・効果・失敗・結果値を実行検査。tailの部分列生成を含む性能と確保回数を測り、退行は設計者へ報告。篩付きList.get/加算の不採用案を復活させない |
| R50 | StandardByteString/Character/IntegerText/FloatMath/NumericRemaining/StringOrdinary/BytesOrdinary/ListRemainingResponse の一般response、`StandardStructuralEqualityResponse.response` | 型付き入力にmalformedのerrが出ないことを照合。資源上限の正規のerrと分ける。現在のF06の証明をこの追加照合済みの証拠としない。型の付いた Equality の値で `structuralEqual` が `none` にならないことも照合する（処理系では `Stop::Internal` に当たり、言語の停止ではない）。`values_equal` との共有の走査・深さの境界と snapshotDepth の燃料の十分性を含む |
| R50 | `StandardFloatOperatorResponse`・`StandardDecimalOperatorResponse`・`StandardStringOperatorResponse`・`StandardStructuralEqualityResponse` | Float.Model/Float32.Model と Rust の f64/f32 の算術・NaN、Decimal の Nat の正確な計算と Wide の256ビットの拒否、String の上限と順序、構造等号と values_equal を照合する。レビューの arm64 の具体例では、nan1=`0x7ff8000000000001` に対し Rust の nan1+1 は payload を保ち、−nan1 は `0xfff8000000000001`、Lean は両方 `0x7ff8000000000000`。Float32 の入力 `0x7fc00001` の負号は Rust `0xffc00001`、Lean `0x7fc00000`。正準 NaN の負号も符号が異なる。Decimal の divDigits は roundMagnitude が none なら Lean では全体を overflow にするが、Rust は候補を更新せず続ける。直前の q≤limit・r<d により到達しない分岐として読み替える。negate の make も表現可能な入力では失敗しないが、未証明であり照合時の注記とする |
| R40 | `StandardDecode.decodeThen`・`decodeThen_normal/decodeThen_firstReturn`・`postprocess_all` | 生成器が通常 decoder の後に同じ後処理を lo→hi→全体条件の順で置く。現在の代表は二つの Integer 欄と一つの全体条件を持つ record であり、任意の record 宣言（欄の数・型・複数の条件）への一般化は生成器が担う。後処理を Def に登録して呼ぶ形なら、decodeThen の let の合成と同じであることを確かめる |
| R10b/R50 | 具体TableとsatBの五代表・全carrier、非計算的checkIn、全署名 | 解決済みID/tag/型引数/ABI、型変数の依存位置、全有限交換表と上層の証明を照合。raw再生だけを全表比較と呼ばない |
| L70/R10b/R50 | Reference.updateの引数名、篩付きPairのRequest/At、短絡の脱糖 | 既存の申し送り5行を保持。未再現の不一致を断定しない。短絡をCompの新構文にしない |
| D10/V10/K10 | U02/U05の公開形、実CLI、関係状態と検査の引用 | 表示・互換登録・別本体/欠落拒否・候補の受け入れ。全比較の実行はL70/R50等の既存担当へ残す |

## 定義・言明・仮定の一覧と検査

段末の公理監査の確定値と宣言一覧は「群G再開2」と「初回の段末監査と作業末の検査」にある。再開3の再監査は「群G再開3（L40.39）」を正とする。各名前の完全名・所属モジュール・宣言の種類・source/line、使用する実署名を保存する。private・生成宣言を含む。生成宣言に個別の行情報がないときは所属ソースを所在とし、行番号を作らない。旧Releaseの主定理・モデルと未知の失敗例を既定importから外さない。

## 見込みと実績

群別の外側の時間と、単位の区間・計算待ち・レビューの時間は別に示す。外側の時間から能動時間を確定しない。確定値は「群ごとの外側の時間」と「群G再開2」、再開3の実績は「群G再開3（L40.39）」と g/results.md にある。

## 独立レビュー応答と受け入れ

[L40.39 の受け口](g/review-intake.md)に対し、[独立レビュー](../reviews/RV-L40.g.md)を受領した。所見ごとの request/report/response/handling は[応答](g/review-response.md)に記す。レビューの原本は変更せず、独立の再確認と受け入れは取りまとめ・設計者に残す。O016/O027/O084/O118 の共通4行は、監査・検査・写し・自己点検と、独立レビュー・正式RSS・設計者の受け入れを分けて判定する。段全体の閉鎖・設計者の受け入れ済みとの記載はしない。

設計者は 2026-11-04 に L40 の段末を受け入れた（README「設計者の決定」）。受け入れは、上の「設計者の見直しの対象」の表の項目を含む。安全な入口19行の公開名と字面は U02 で別に決める。

## 初回の段末監査と作業末の検査

以下は初回の履歴である。再開2の入力・公理監査・検査の確定値は「群G再開2」にある。最新の監査は「群G再開3（L40.39）」を正とし、宣言一覧の写しとaudit-summary.jsonは再開3の一回分へ更新する。

[監査の台本](audit.py)と[Lean入力](axioms.lean)で全名を作り直せる。再生成は `python3 -B <改造>/l40/audit.py --tmp <tmp>`。監査済みの同じ生出力から一覧の分割だけを作り直すときは `--collect` を付ける。全78,801対象は一時領域に置き、段末にはその大きさとSHA-256を残す。宣言の一覧の写しは今回の一回分である。

| 監査の対象 | 件数・結果 |
|---|---|
| Benitoiteの既定の新旧モジュール | 991 |
| 全名と#print axiomsの一対一一致 | 78,801 |
| 印字時の実体化を追った周回 | 2 |
| 変更329モジュールの宣言（使用定義を含む） | 13,660 |
| 新303モジュールの宣言 | 10,854 |
| 新しい公理 | 0 |

依存の集合ごとの宣言数は次のとおりである。許可した三公理以外の依存、sorryAx、未検査の公理の宣言は0。

| 公理の依存集合 | 宣言数 |
|---|---:|
| none | 36,607 |
| Classical.choice | 1 |
| Classical.choice + Quot.sound + propext | 19,734 |
| Classical.choice + propext | 2 |
| Quot.sound | 9 |
| Quot.sound + propext | 3,848 |
| propext | 18,600 |

完全名・種類・所在の一覧は [audit-summary.json](g/audit-summary.json) の declaration_parts が指す `g/declarations-part-*.json` にある。各要素は所属moduleとsourceを持ち、columnsの順に `[完全名, 種類, 行番号]` を列挙する。生成宣言の個別の行がない場合はnullとし、sourceを所在とする。変更26モジュールの既存の定義も使用定義として含めたため、13,660件すべてを新規宣言数とは呼ばない。全991モジュールの使用定義は全監査の対象に含む。

匿名の example は環境に保持される名前付きの宣言と別に、既定ビルドの中で検査する。import の読者一覧は g/readers-part-*.json、表の各行が使う完全名と所在は g/case-evidence.json、単位が使う完全名と所在は g/unit-evidence.json にある。各一覧の名前は全監査の環境に実在することを照合した。importの一覧だけを定理の適用の証明としない。

| 主要な定義・仮定の完全名 | 所在・扱い |
|---|---|
| Benitoite.Release.Refinement.Builtins.CoreAssumptions | formal/Benitoite/Release/Refinement/ConstraintAssumptions.lean:108。定理の条件を束ねる構造体であり、新しいLean公理ではない |
| Benitoite.Release.Refinement.Builtins.ResponseAssumptions | formal/Benitoite/Release/Refinement/BuiltinResponse.lean:47。純粋・IO等の応答の条件。精密な八署名の表について response_assumptions を証明済み |
| Benitoite.Release.Refinement.Program.WellFormed | formal/Benitoite/Release/Refinement/ProgramWellFormed.lean:52。同じ宣言表の形成 |
| Benitoite.Release.Refinement.Program.WellTyped | formal/Benitoite/Release/Refinement/ProgramTyping.lean:81。同じ定義・実装の型付け |
| Benitoite.Release.Refinement.StateTyE | formal/Benitoite/Release/Refinement/StateTyping.lean:158。固定σ・元状態のストアと継続を保つ判断 |
| Benitoite.Release.Refinement.StandardKeyTyping.Table | formal/Benitoite/Release/Refinement/StandardKeyTyping.lean。同じ有限宣言・収束した計算・satの等号を持ち、鍵の意味の結論を未検査欄にしない |
| Benitoite.Release.Refinement.InternalContracts.all | formal/Benitoite/Release/Refinement/StandardSafeContracts.lean。安全19行の依存列。具体のNamesとAnnotation、本体の証拠を分ける |

実際の153署名は [前半](g/signatures-part-01.md)・[後半](g/signatures-part-02.md)、入口・定義・腕の二規則の15実型は [定義の署名](g/signatures-definitions.md)。暗黙引数を含む印字はLeanの環境から得ている。公理依存と条件付きの定理の前提を分け、CoreAssumptionsをLeanの公理と呼ばない。

| 保持した旧宣言の完全名 | 所在 |
|---|---|
| Benitoite.Release.step_sound | formal/Benitoite/Release/Theorems.lean:26 |
| Benitoite.Release.progress | formal/Benitoite/Release/Theorems.lean:39 |
| Benitoite.Release.preservation | formal/Benitoite/Release/Theorems.lean:46 |
| Benitoite.Release.effect_soundness | formal/Benitoite/Release/Theorems.lean:56 |
| Benitoite.Release.effect_soundness_noLamNames | formal/Benitoite/Release/Theorems.lean:66 |
| Benitoite.Release.Model.assumptions | formal/Benitoite/Release/Model.lean:81 |
| Benitoite.Release.ModelTargets.assumptions | formal/Benitoite/Release/ModelTargets.lean:346 |
| Benitoite.Release.ModelHttp.assumptions | formal/Benitoite/Release/ModelHttp.lean:444 |

未知の失敗の既存の例は IntervalConnectionExamples.lean の Examples 内の private failed_eval（287行）とその匿名の具体適用、DomainExamples.lean 等を保持する。全名の監査には private も含めた。未知の失敗を TrackedFailure に加えたり、その例を既定から外したりしていない。

| 検査 | 結果と内容 | 外側の時間 |
|---|---|---:|
| 補足の単独Lean | 終了0。15の入口・定義・腕の二規則の実型、-M12288 | 0.698秒 |
| 既定lake build | 終了0。formal/から対象指定なし、既定8対象・1252 jobs | 0.265秒 |
| workの選択確認 | 終了0。spec_tally・spec_examples。formal_buildは今回の文書差分からは選ばれない | 0.119秒 |
| 最後のwork（一回） | 終了0。仕様対応の自己検査・集計、仕様例7成功・失敗0・無視0。--onlyなし | 7.424秒 |
| 段末の公理監査 | 終了0。991モジュール・78,801宣言、許可三公理だけ | 71.187秒 |

既定ビルドは増分であり、clean buildではない。workが既定ビルドを選ばなかったので、それとは別の一回の `lake build` が既定ビルドの証拠である。旧記録のworkの内容を今回の選択へ写していない。buildには既存のリンク時の `-L/usr/local/lib` の警告が出るが、終了0・1252 jobsである。検査後に本番Leanと写しを変更しない。Rust全lib・clippy・全比較・大きな具体値を作る評価は行っていない。正式RSSは未取得（取りまとめが別に採取する指定）。

| 生の出力・一覧 | bytes | SHA-256 |
|---|---:|---|
| 公理監査の生出力 | 16,967,327 | `75e1535eb61c1821348576b445efa608649c0f9759935ea2799c6d798c79a435` |
| 全対象一覧 | 5,144,266 | `3155dd9dcb642cc1ce1b2ba377ac9586e44c1c95bebf14f69e0639f6874f0014` |
| signatures | 12,150 | `25dcbf883c70cc81570fe60e76f16fc88aa145a96ec374cebaadf03079f1c70d` |
| build | 45,471 | `ffb80606d417a2161f51931150f034e6a179f5ad62377ac8dce63f55093d49ac` |
| selection | 592 | `48703e82a41bbc3f6212768a54463775032995cf094d65be24182af53e49e85c` |
| work | 5,664 | `99315d3aa1c237787ac380ba8f714242ea2d7d1d9aa93f758efe594613d50e90` |

初回の監査入力は複数の実行ファイルを同時importしたためmainが衝突し、監査前に終了1（0.583秒）。次の入力はCommandElabMからppExprを直接呼んだ型の誤りで監査前に終了1（0.769秒）。前例どおりBenitoiteをimportし、式のメッセージによる型の印字へ直した最終監査は完走した。既定8対象のソースの閉包は別途すべて照合し、既定ビルド対象からの除外は0。補足署名の初回ではnormal_reply_factsの名前空間を誤記し、実際のRefinement直下へ修正して再確認した。本番の定義を変えて合わせていない。失敗の終了・時間・bytes/SHA-256は g の audit-initial-failure.json・audit-type-failure.json・signatures-initial-failure.json に保存する。

監査の宣言一覧は、完走済みの同じ出力を--collectで再集計し、同じmodule/sourceを宣言ごとに重ねない形へ変えた。Leanの全監査は再実行していない。全対象一覧のSHA-256は群F2の最終値とも一致するが、その古い監査を今回の実行の代わりにはしていない。

## 群ごとの外側の時間

出どころは取りまとめの effort-ledger.md の L40 の各行と、各群 results の時刻である。台帳の約の値と秒単位の区間の精度を混ぜない。群の外側の概数は次のとおりである。能動時間・ビルド待ち・モデル待ちの全分離はできず、c_V/c_Cと群別の能動時間は未取得。

| 群 | 積上げの見込み | 担当の外側の時間の概数 | 算入範囲・未取得 |
|---|---|---:|---|
| A・F1 | 3時間5分〜6時間＋F1 2時間15分〜4時間20分 | 約1時間54分30秒 | 約66＋15＋30＋3分30秒。A/F1は分離不能。初期単位の開始・終了は未採取。能動・待ちは未分離 |
| B | 3時間5分〜6時間5分 | 約1時間14分10秒 | 約23＋41＋7分30秒＋2分40秒。単位区間とは別の群の外側。能動・待ちは未分離 |
| C | 2時間15分〜4時間25分 | 約1時間2分 | 約25＋32＋5分。反例の独立調査17分と群レビュー12分は別。能動・待ちは未分離 |
| D | 3時間〜5時間50分 | 約1時間15分 | 約55＋20分。単位区間約32分42秒とは区別。能動・待ちは未分離 |
| E | 5時間〜10時間5分 | 約12時間2分 | 約2時間3分＋4時間37分＋1時間42分＋20分＋11分＋24分＋2時間40分＋5分。混雑・起動失敗を含む。能動・待ちは未分離 |
| F2 | 2時間15分〜4時間30分 | 約39分 | 約26＋10＋3分。四単位の初回区間約13分47秒とは区別。能動・待ちは未分離 |
| G | 1時間45分〜3時間10分、上限6時間20分 | 群 G results の開始〜終了を正とする | 独立レビュー応答と受け入れ待ちを含まない |

A〜F2の担当の概数は合計約18時間6分40秒であり、G・計画・独立レビュー・取りまとめの検査を含めない。詳細計画の下書きとr1は約28＋25＝53分。レビュー・独立調査は台帳の外側の値の合計約2時間28分50秒（plan初回12分・再レビュー2分30秒、A13分・4分20秒・3分、B9分、Cの調査17分・レビュー12分、D9分・6分、Eの調査12分・レビュー23分・再開6のレビュー15分、F2のレビュー9分・2分。e6は本文約15分と外側約11分の両記録があり、ここでは15分を使う）。レビューの待ちを担当の能動時間に加算しない。

取りまとめの既定ビルドを含む work の外側は、A163.44秒、B166.38秒、C169.97秒、D173.27秒、E419.31秒、F2 420.51秒である。各群の正式RSSは各群の結果を参照し、今回未取得のGへ代入しない。担当の外側に既に含まれる局所検査と群末検査を、群の時間へもう一度足さない。

Eの再開5の後の追加見込みは、規則1とgetterで5〜10時間、規則2まで7〜15時間。再開6の外側約2時間40分をその能動時間の実測に読み替えない。通常契約179行の追加・型付けの規則の追随・Unicode有限表・%Map.replaceValuesは当初の群Eの積上げだけからは読めない差である。J40-4の枠を短縮せず、取りまとめの集約へ残す。

## 初回に取りまとめへ確認した点

次表の独立未完三件は再開2で閉じた。現在の判断と申し送りは「群G再開2」を正とする。

| 項目 | 現在の証拠・不足・差 | 代案と所要 | 実用への影響 |
|---|---|---|---|
| O135とO022/O034/O144、L40.25の通常decoder接続 | postprocess_wellTyped/postprocess_row_typed、同じRaw/Errorからの実行、欄順と全体条件はある。未証明なのは「通常decoderの同じResultへの実行を、後処理の入口と結び、同じError又は検査済みの構築値を得る」接続である。recordProgram.defsはnoneであり、通常decoderや後処理Defを登録して呼び出す全体の入口を示していない。Eの16行の再開とこの未完を混同しない | 推す扱いはL40.25の未完として保持し、取りまとめが具体の完了条件・署名・担当を確定すること。追加実装の所要は未試行で不明。15〜25分の読取り調査で必要な接続と既存の型付けの利用を確かめ、その後に見積もる。自動的にL70/R40へ移管して完了としない | 現在の局所証明を、任意の通常decodeと篩付きの生成本体全体の保証へ拡張して案内できない。提供範囲を削る判断は今回行わない |
| O062/O065と全契約、L40.28の328外の演算子・構造Equality | 旧表は演算子73/107を接続、34を独立未完とする。構造Equalityは12scalar領域の条件付きpartialであり、List/data/Bytes/Map/Set等の全入力の応答契約を結論しない。通常179行の完了と、全328APIの未接続0を、この別母集団の閉鎖へ適用できない | 既に閉じた証拠があるなら34行・%eq/%neへ対応表を補う。なければL40.28の独立未完として保持し、元の実署名から具体δと全BuiltinArgsの応答契約を実装する単位を取りまとめが確定する。所要は未試行で不明、最初の20〜30分で一族の供給元と残りを見積もる。L60へ自動移管しない | 328行の公開APIの通常型は保持するが、全演算子を含む具体の表の充足とモデル全体を完了とは案内できない |
| 設計者の見直しの一覧 | 上表のJ40-3・E_Lam・精密telと順序の扱い・%Map.replaceValues・算術 δ の追加（plan 2026-11-04、群 G 再開2。Float の模型による NaN の payload と符号の正準化を含む） | 取りまとめが設計者へ提示。判断待ちの時間は不明。欄の等号とhead/tailは既に設計者が明示決定したものとして区別 | 新しい安全APIの呼び方、実行規則、標準本体・内部組み込みへの波及 |
| 段末の独立レビューと受け入れ | L40.39は受け口のみ。O016/O084/O118の独立の確認とO027の正式RSSが未了 | 取りまとめが依頼し、別起動で応答。所要は不明 | L40全体を受け入れ済みとは扱わない。Rust開始条件を満たしたとの判定もしない |

今回、主な十言明・型付けの規則・新公理・独立の信頼条件・精密な外部状態を変更する提案は加えていない。内部の補題の追加も0。写しの修正は工程略号4箇所だけである。群 E/F2 の計画との差はそれぞれ上の判断・受渡しへ集め、取りまとめが指定したものと今回新しく選んだものを区別した。

## 群 G の外側の時間と最終照合

群 G は2026-11-04 12:45:39〜2026-11-04 13:21:14 JST、外側35分35秒。単位ごとの開始・終了は [g/results.md](g/results.md)、秒単位の差は [times.json](g/times.json)。能動時間と待ちは未分離である。L40.39の別起動と設計者の受け入れは含まない。

[最終照合](g/verification.json)は、本番Lean1002ファイルと保護対象6029ファイルの開始時からの不変、59行・64義務・33申し送り、全名と所在、各記録100KB以下を検査する。Gの記録は約3.0MB、最大約90KBである。既定ビルド・workの後に本番Leanと二つの写しの変更は0。共通依頼文・detail・plan・README・レビュー・各群の記録・処理系は変更していない。


## 群G再開1の停止（2026-11-04）

[再開1の記録](g/results.md#再開1-既存-δ-の算術名の受け口の調査)。群Dの既存float64Delta/decimalDeltaについて、原署名のBuiltinArgsを持つゼロ入力でも%Float.add/%Decimal.addの応答が存在しないことを旧入力のLeanの反例（現在の[対照](g/resume2-contrast.lean)とは異なる）で確認した。現在のファイルは再開2で対照へ置き換えた。旧内容の識別は g/results.md「旧反例の置き換え前の識別」にある。停止条件に従って新しい算術δ・算法は追加していない。O022/O034/O062/O065/O135/O144の6行の「一部」と、申し送り33行の処分は維持する。演算子34行・構造Equality全入力・O135の通常decoder接続をL50/L60/L70/Rへ移して閉じた行は0である。O135の15〜25分調査は未着手。本番モジュールと宣言の追加0のため、01-12/07-04の写しは変えていない。反例台本7宣言の公理依存の確認と、段末の全環境監査の再実行（今回未実施）を区別する。
