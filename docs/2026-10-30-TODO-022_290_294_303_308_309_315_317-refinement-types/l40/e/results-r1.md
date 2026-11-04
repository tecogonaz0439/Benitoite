# 群 E：全標準契約と具体の鍵・本体

基準 B_WORK は `548d3fd94a5f1a171c9bc749b3408f8a9f3c08f8`、指定ブランチは `m014/l40.e`。git の操作は行わない。勧告は共通依頼文の照合と判断を継承し、依存更新を相乗りしない。

現状は再開1の部分引渡しである。.24〜.28の境界に依らない成果と全328行の分類を追加し、末尾の全公理監査・全体照合を済ませた。.23の正常関係・FirstReturn・二反例は保持する。境界依存分、精密getter九行と通常契約179行などの独立未完を残し、群E全体又は全APIの完了とはしない。以下は各時点の記録を含み、再開1の最終値は末尾を正とする。

## 単位の時刻（UTC）

開始・終了を各時点で追記する。外側の区間であり、能動時間と待ちは未分離である。RSS は未取得（計画上の非採取）。

| 単位 | 開始 | 終了 | 判定 |
|---|---|---|---|
| L40.21 | 2026-11-03T13:00:25.365623+00:00 | 2026-11-03T13:05:36.996310+00:00 | 担当分完了。局所 Lean と既定ビルド終了0 |
| L40.22 | 2026-11-03T13:05:36.996310+00:00 | 2026-11-03T13:47:51.251652+00:00 | 担当分完了。全有限値の鍵構造・列・縮約の存在、既定ビルド終了0 |
| L40.23 | 2026-11-03T13:47:51.251652+00:00 | 2026-11-03T14:49:14.394627+00:00 | 停止（未完）。末端だけ/最初の同じkでのretの二候補の不足を記録。最終局所Lean/既定全件build終了0 |
| L40.24 | 2026-11-03T15:12:08.108731+00:00 | 2026-11-03T16:29:36.530883+00:00 | 純粋δ二十本と高階四本BodyTyped。正常関係は境界の決定待ち |
| L40.25 | 2026-11-03T16:44:43.923973+00:00 | 2026-11-03T17:20:19.794512+00:00 | 不変欄の連鎖とdecode済みResultの後処理。通常decodeへの接続は境界の決定待ち |
| L40.26 | 2026-11-03T17:25:19+00:00 | 2026-11-03T17:52:06.137035+00:00 | 全19注釈・安全9本BodyTyped。getter九本は静的未証明、19の強い本体は境界の決定待ち |
| L40.27 | 2026-11-03T17:57:33.642034+00:00 | 2026-11-03T18:06:51.063165+00:00 | 全位置の静的受理拒否、依存結果/効果、四像。正常関係の読者は境界の決定待ち |
| L40.28 | 2026-11-03T18:13:45.036614+00:00 | 2026-11-03T19:25:45.097752+00:00 | 全328分類、143通常応答・6本体、群Dの部分表の接続。全APIの閉鎖は0 |

## 具体例の作成時の関門

所有する境界は、実際の標準名と引数列による応答から、同じ値の観測と篩へ進む接続である。二つの String 長の混同、観測できない List 要素の数え落とし、Bytes の要素範囲と長さの混同、表現外の長さの正常値への変換を捕まえる。既存の measure の補題だけでは標準名・実応答・結果の型付けを通らない。試験用の差し込み口や Rust のテストは追加しない。

## L40.23 の静的な区切り

`StandardCollections.sequenceDelta` の concatenate/reverse と型付け・長さの補題を追加した。`StandardListBodies` に実ソースと同じ引数順の map/filter・mapFrom/filterFrom を置き、四本の `Row.BodyTyped` を具体 lookup と宣言から構成した。型付けそのものを入力にする欄はなく、任意の潜在効果へ `Q 0` や無失敗の条件を追加しない。具体の有限宣言と `satB` の表を持つ `ListModel.typed` で四本を適用する。標準表全体の `CoreAssumptions` の充足はこの表の結論に含めない。

途中の局所検査 `unit23-model` は終了0、外側6.370秒。既定 import と01-12・07-04に同じ静的な範囲を写した。以下の既定ビルドはこの区切りの確認であり、L40.23の完了又は独立レビューの完了ではない。正常な任意の実 `Steps` からの長さ・順序と、同じ実行中の acc の動的な要素型の義務は継続中である。

## L40.23 の停止時点の成果と残る義務

正常返却の境界の具体化に、既存の末端 Steps/Runs の正常状態だけを使う案では不十分な実例があるため停止する。固定 F06 自体の偽とは扱わない。根拠・15歩の前後・型と宣言の確認範囲・代案・所要・実用上の影響は [return-boundary.md](return-boundary.md) に保存した。独自 trace を未検証の新しい入力として正常関係の代わりにしていない。

| 対象 | 証明・読者 | 前提と現在の判定 |
|---|---|---|
| prepend/append | 既存 StandardCollections.insert_reply を維持 | 一要素の型付き挿入と n+1。前単位で担当分を終了済み |
| concatenate/reverse | sequenceDelta、concatenate_reply、reverse_reply と Unit の具体例 | 元の要素導出と Annotation。実δの結果型と n+m/n は担当分終了 |
| 四本の通常 core 本体 | listFromBody/listFromDefinition/listFromRow/listHigherRow、listFrom_body_typed/listHigher_body_typed、ListModel.typed の四適用例 | 具体 lookup と Option 宣言/網羅性・空制約の成功。Row.BodyTyped/同じDef.WellTypedは終了。Q0や潜在Eへの無失敗条件なし |
| 一段/有限な一般保存 | FiniteStepPreservation.StateTyE.step_preserved/steps_preserved、concrete_finite_preservation | 元の76葉へ分配。同じPのWellFormed/WellTyped/EffectsOk、BのCoreAssumptions、σ.Valid。新しい意味の信頼欄なし。具体の効果/操作なしの表からEffectsOkを計算した読者あり |
| Some/None の実行 | listFrom_none_steps（五歩）/some_steps（七歩）と実表の適用例 | 同じList.getの署名と応答。Noneは元acc、Someは同じfと実際に閉じた子値へ一度進む |
| callback の実実行の接続 | listFrom_callback_normal/failed と実closureの正常/IntegerOverflowの有限例 | 実子Stepsの事象・理由・ストアを保つ。正常値だけを後続へ一度束縛する。正常応答の存在や全域数学関数を仮定しない |
| 同じ実行中の動的なU型 | list_append_reached_typed と Unit の具体構文への適用例 | 初期StateTyEと同じ実Stepsから一般保存で到達状態を型付け、append[U]の元のHasTypeTelArgsQからy:U.norm/acc各値:U.normを得る。callback結果の型付けを別前提にしない |
| 末端の正常返却の候補 | ListModel.later_return_same_continuation/endpoint_length_not_contract、匿名読者 | 実listFromBody特殊化・実List.getδ・15歩を使用。同じ構造の継続に戻る末端だけでは元の空入力の長さ契約を導けない。確認済み範囲の制限は境界の記録に明記 |
| S14/S15・F06 の全ループ関係 | 未完 | 最初の返却の境界を確定した後に、i+remaining.length=xs.length、map acc.length=i/filter acc.length≤i、元suffixと順序、n/≤nを同じ正常有限実行へ接続する。今回完了とは数えない |

担当内で提示した一般保存補助の案にはEffectsOkが省略されていた。既存のdrop/releaseの四葉が要し、旧主定理にも元からある宣言条件なので、内部補助へ明示した。外部の取りまとめ又は設計者による承認を取得したという意味ではない。差は「内部補助の案への旧EffectsOkの明示」であり、新しい主定理前提・意味の信頼欄ではない。固定F05/F06のRow、安全19契約、旧Release、主な十言明、型付け/部分型の規則は変更していない。

途中のLeanの失敗は、暗黙引数の推定・閉じた型の値代入・ライブラリにないtactic・局所文脈のnoneスロット等の組立ての修正として checks.json に残す。最終の局所検査と既定ビルドの成功だけを現状の検査結果とする。workと全公理依存監査は群末の記録へまとめる。担当による独立レビュー・設計者の受け入れは未実施である。

## 追加試行前の検査の区切り

| label | コマンド（formal/から） | 終了 | 外側の時間 | 生出力 |
|---|---|---|---|---|
| unit23-preservation-finite3 | lake env lean -M 12288 Benitoite/Release/Refinement/FiniteStepPreservation.lean | 0 | 1.393秒 | 0 bytes、SHA-256 e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 |
| unit23-final-local | lake env lean -M 12288 Benitoite/Release/Refinement/StandardListBodies.lean | 0 | 6.503秒 | 0 bytes、SHA-256 e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 |
| unit23-stop-build | lake build（対象指定なしの既定全件） | 0 | 8.101秒 | 43,306 bytes、SHA-256 154462f8d3e0a7d55c77167445b17965b6f3517aa6435d6e497bfbbbf302361d |

本番の変更/新規7ファイルの大きさとSHA-256は [unit23-source-state.json](unit23-source-state.json)、全局所実行の開始・終了・コマンド・結果・生出力の大きさ/ハッシュは [checks.json](checks.json) に保存した。生ログは一時領域へ出し、記録から永続の入力として参照しない。RSSは未取得（計画上の非採取）。基準は冒頭の完全B_WORKを維持し、git操作は行っていない。この検査の区切りの後に担当内の点検で追加試行を行った。最終の対象状態と検査は末尾を正とする。各記録100KB以下を確認した。

## 正常返却の内部関係の短い試行

2026-11-03 14:33 UTC、担当内で停止判定を再点検した。末端だけを使う候補の偽だけでは固定F06の変更必要性は確定しないため、既存Steps内の「同じkで最初のretまで」を内部の有限関係で具体化し、15〜25分の短い本番試行を行った。stop-buildは途中区切りとして保持し、L40.23を継続する。固定署名・主10・安全19・既存Runsを変えず、semanticな信頼欄・callback全域性・無失敗・純粋Eを足さない。

## 追加試行の終了と最終の停止判定

担当内で15〜25分の本番試行を行い、指定kで最初のretまでの有限導出 `FirstReturn` を追加した。これは実Stepと構文上の非返却の証拠だけを持ち、既存Steps・末端のret・有限保存へ射影する。一般Cont等号のBool計算可能性を主張しない。通常のNone五歩の読者を持つ。

実ソースと同じmapFromの一要素入力から、外側Fail handlerがcallbackのFailを捕捉して元の呼出しを再開せずに終了し、外側repeatが空入力の別helperを起動する20歩を構成した。指定kでの最初のretは空列であり、`first_return_length_not_contract` はこの境界だけを受ける長さ1の候補を否定する。FirstReturnの各途中状態に、指定kでretでない証拠を含めた。callbackの依存列での型・helperのBodyTyped・具体のEffectsOk・本体特殊化/実getの等号を匿名読者で照合する。全P.WellFormed/P.WellTyped/CoreAssumptions・始状態全体のStateTyEは両反例で未証明であり、全F06前提を満たす反例又はF06自体の偽とは数えない。

境界の二候補の不足、現在未証明の正常関係の全量化と前提、呼出しの由来又は専用区切りを追う代案・実用影響・暫定時間は return-boundary.md の追加試行以降へ保存した。担当内の点検は14:44 UTCまでに、ここで試行を終えて未完の言明と実行境界の候補を取りまとめへ返すと判断した。新しい意味の信頼欄・純粋E/外側handlerなしの制限・callback全域性を足さず、呼出し由来の新設へ先回りしない。.24以降は未開始である。

反例の作成時の関門として所有する境界は、同じ構造の継続への再到達と、同じ呼出しの正常返却との区別である。既存の長さ・空/consの有限列の検査では、最初の返却の消費と外側handlerでの中断を捕まえられない。15歩と20歩はこの別々の退行を実Stepで検査する。Rustに試験用の差し込み口を追加していない。

新規モジュールは StandardListBodies.lean・FiniteStepPreservation.lean・FirstReturn.lean、既存の変更は StandardCollections.lean・formal/Benitoite.lean・01-12・07-04である。全三新モジュールを既定importと両写しへ含めた。plan/detail/README/reviews/群A〜D記録・固定安全19・既存Runs/Step・旧Release・処理系Rustへは書いていない。

## L40.23 最終状態の検査

- 最終局所 unit23-handler-stop-local: 終了0、外側6.669秒、生出力0 bytes（SHA-256 e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855）。同じStandardListBodiesには二つの境界の例と全入口の読者を含む。
- 最終既定全件 unit23-handler-stop-build: formal/から対象指定なしのlake build、終了0、外側8.227秒。生出力43,306 bytes、SHA-256 e43986e9777b741ff4268c5a921265c5bb1c920133cf7356ee6fda0cd3323966。
- 実際の終了時刻（UTC）は上表へ記録した。初期開始からの外側の時間であり、能動時間と待ちは未分離。追加試行の開始は14:33 UTC。
- 最終の本番/写しの7ファイルのハッシュはunit23-source-state.json。RSSは未取得（計画上の非採取）。各記録100KB以下。唯一の群末work・全公理依存監査・sources/64義務の記録・verify・独立レビュー・受け入れは群末の担当/設計者の担当であり、今回済んだとは数えない。

この最終既定ビルド後に本番Lean/設計書を変更せず、ハッシュ・結果・実際の終了時刻だけを記録した。L40.23は未完として返し、.24以降は始めていない。この記録の後はリポジトリへの書込みを止める。

## L40.21：長さの局所契約

`StandardCollections` は実際の標準名・型引数の個数・空の行/範囲引数から `lengthDelta` を定義する。String.byteLength は UTF-8 のバイト数、characterCount は文字の列の要素数、List.length は要素を観測できるかによらない列の長さ、Bytes.length は全要素が0〜255である列の長さへ対応する。`string_lengths`・`list_length`・`bytes_length` と各 reply が、同じ項の観測・measure・正常結果の型付けを結ぶ。`é` の2対1、観測不能な関数要素を含むList、Bytesの0/255と256、余分/不足の型引数を既定の具体例で区別した。

`countReply` は数学上のNatをInteger64へ明示変換する。正常な返却値は同じ数学値で非負である。元の列の長さには一律の有限幅上限を課さず、表現外では `err "length does not fit Integer"` を残す。`countReply_stop` と最大値+1の具体例がこの枝を持つ。Rustの `integer_count` の停止の字面と、Stringの二種・List/Bytesの実登録を読む範囲で照合した。Rustのメモリ/ABIや全標準表のF06充足をこの補題の結論とはしていない。

## L40.22：全有限値の鍵とcarrierの各形

`StandardKeySummary` は同じ有限宣言の `dataSummaries` と収束の計算から、成功した要約を同じ構成子の各欄へ移す。等値/鍵の依存位置、merge、型引数への代入は内部の補題で証明し、「全欄の値が鍵になる」という意味の欄を入力へ追加しない。`carrier_core`・`carrier_norm` が篩の除去と正規化を結ぶ。

`StandardKeySound` の名前空間は `StandardKeyTyping` である。固定F05と同じ `Table P B`・`P.VarianceValid`・同じsat成功・閉じた型付き値から、`key_table_sound` が `KeyObservation` を結論する。帰納は型の再帰dataの展開ではなく、有限な値の大きさによる。KeyShapeの全11形、KeySlots/KeyPairsの空/cons、型付きの異種列/同種列、閉じた鍵code、Map/Setの実縮約の存在へ接続した。公開入口は同じ既定モジュール内の読者と具体の判定例を持つ。

| carrier又は値の形 | 今回の扱い | 交換・実物との境界 |
|---|---|---|
| 基底の鍵、七幅の整数、Decimal、Character、String、Byte | 成功したsatから実際の定数のKeyShapeを得る。Decimalの数の同値とcodeは既存KeyContractsへ接続 | Rustの数値表現・codeとの全対応はR50に残る |
| 篩付きの鍵型 | carrierは元の型を保持し、篩だけを除く。`carrier_norm`を用い、同じ型付き値から導く | 篩を理由に受理範囲を減らしていない。実宣言の収集はR50 |
| Float・Float32 | 両幅とも直接の鍵carrierを拒否する。既定の具体判定例を持つ | 浮動小数のABIはこの証明の対象外 |
| 制約付きの型変数 | 要約内のtvar依存を同じ型引数へ代入する。閉じた値の定理では未代入tvarは成功しない | 実際の制約文脈/型引数の収集とRust判定の全入力の照合はR50 |
| List・Map・Set | 入れ子を含む全有限値を帰納。Map自体の鍵化は鍵と値の両方、Mapの縮約の存在は鍵側だけのkey制約を使う | Map値のtoTerm?がnoneでも縮約存在を要求できる。実deltaと大きさ/射影の契約は.24未着手 |
| Bytes | 型付きの全有限byte列の形とKeyShapeへ接続 | 実byte列の表現・ABIはR50 |
| Option・Result・再帰data・record | 特別な名前に限定せず、Tableと同じPの構成子/欄として全有限値を扱う。未使用の関数型引数を持つdataは依存位置に従い受理を保つ | 実Option/Result/record宣言の収集、ID・構成子tag・欄順との全対応はR50 |
| AtErrorの実値 | 型付きdataの形の中で、実際の文字列欄の有限観測からKeyShapeを得る | 標準名・タグの交換はR50 |
| scoped・opaque・external・Reference・Lazy | 直接のcarrierは鍵不可の骨格へ写す。型付き値の証明ではsat成功と両立しない形として排除 | 未使用の型引数に含まれる場合のdataまで一律拒否しない。Rustの各carrierとの全照合はR50 |
| 関数・dependentFn・dict・tapp・ctor・cont・PathBases・ScopePattern等 | carrierのその他の形を鍵不可へ写す。直接の受理を増やしていない | 収集側の型構成子・境界の一致はR50 |

`key_map_normal` は値側にkey制約を要求せず、鍵の型付き列と同じ長さの値列から `Key.normalizeMap` の結果の存在を導く。`key_set_normal` は同じ表の鍵列から `Key.normalizeSet` の結果の存在を導く。Map.sizeや全Map APIの型付けをこの存在定理だけで証明したとはしない。

## 23モジュール328 APIの実ソース照合と未完の分類

[sources.py](sources.py) は、群Aの23モジュール一覧と実際の `.bnt` を読み、全公開関数の原署名、型パラメータと制約、引数名/型、通常結果型、潜在効果、実builtin名又はcore呼先・本体を再収集する。Rustでは対応ファイル内の組込み名の文字列の出現を照合する。結果は [sources.json](sources.json)、原署名全文とcore本体は [api-numeric.json](api-numeric.json) と [api-collections.json](api-collections.json) に分けた。各入力の大きさ/SHA-256をsources.jsonに持つ。

core呼先は原本文からの名前の抽出であり、収集済みIRの対応証明ではない。原本文を同じ記録に保持し、R50の収集・交換と区別する。

| 分類 | 行数 | 停止時点の判定 |
|---|---:|---|
| 全公開API | 328 | 全行の原署名と実呼先を保存 |
| `@builtin` | 244 | 全244名をRust内で確認。登録スキーマ・ABI・意味の同値の証明とは区別 |
| 通常core | 84 | 別名ラッパー51行を含む。実本文を保存 |
| F06の全量化までL40で閉じたAPI行 | 0 | .28未着手。局所の担当単位の完了を全行F06へ繰り上げない |
| L40の義務が未完のAPI行 | 328 | 各行に「未完」を明記。追加S行のないAPIも通常結果型の義務を持つ |
| L40の未完をL50/L60/R40/R50へ確定移管した行 | 0 | 未完の義務を後段へ移管して完了にしない |

S01〜S36のうちoperator族、record/decode、安全な内部入口、範囲付きFile/Httpなど、公開328関数の外にある契約も残る。全量化した実宣言表・BuiltinArgs・全型/行/範囲引数・Outcomeの接続、L50/L60の供給元の最終固定は.28未着手である。L50のFile/Http対象行はこの23モジュールの外にあり、L60の具体モデルの全欄、R40の生成器/本体、R50の宣言と値の交換は、それぞれ元の境界のままである。

## 安全な入口と固定した契約

群Aの [safe-contracts.lean](../a/safe-contracts.lean) の19行の内部契約は変更していない。SHA-256は `b8bc4b877992e4f43560b46cad38151f3825882b2b49f0e1c91d4e28005e9172`。.26は未着手であり、具体NamesのAnnotationから本番の宣言/本体一致へ進む義務は未完である。既存のOption・Result APIを変更していない。公開名と字面はU02に残す。

## 義務・計画との差・取りまとめの判断

[obligations.md](obligations.md) はdetail第7節の64義務を一行ずつ判定する。今回全体を閉鎖した義務は0であり、.21/.22の局所担当分と.23の静的型付け/実保存、未完の全ループ関係を分ける。独立レビューと設計者の受け入れは未実施である。

計画との差は、.23の動的U型の供給に必要な既存76葉の分配と有限保存を内部補助として追加したこと、正常返却の境界で二つの候補の不足を調べ、.23で停止したことである。群A〜Cで確定した後続署名、安全な19契約、既存Runs/Step、主な十言明は変更していない。新しい公理・独立の意味の信頼条件・callbackの全域性/純粋性・利用者の書ける形の制限を追加していない。

取りまとめには、F06の「同じ本体の正常返却」を、捕捉された継続のresume/破棄を含めてどの有限関係で識別するかの判断を求める。二候補の実証範囲、未証明言明の全量化・前提、由来を追う関係と専用区切りの差、未試行の150〜300分の暫定積上げはreturn-boundary.mdにある。固定F06自体を偽とはせず、全P/Core/初期StateTyEを満たした反例とも扱わない。純粋Eや外側handlerなしへの縮小は案として採用していない。

## 群末の監査と唯一のwork

全宣言の監査は終了0。既定の新旧716モジュール・70,137宣言を所属モジュールから再列挙し、private・生成宣言を含めた。今回の新規6モジュールの全460宣言も同じ対象に含む。許可された `propext`・`Classical.choice`・`Quot.sound` 以外の依存、新しい公理は0である。これは独立レビューの代用ではない。

| 新規モジュール | private/生成宣言を含む全件 |
|---|---:|
| FiniteStepPreservation | 4 |
| FirstReturn | 19 |
| StandardCollections | 52 |
| StandardKeySound | 28 |
| StandardKeySummary | 200 |
| StandardListBodies | 157 |

公理監査の外側の時間は39.622秒、生出力12,445,800 bytes、SHA-256 `5e5c3cad91c52db9a125465825a6b903941da1ce539b76843de39c161392e271`。全対象一覧は4,303,948 bytes、SHA-256 `77a344a72678f715794c3da828c63e6b331e40b616f8533b69ae10c3d1baff79`である。生出力と全対象一覧は一時領域へ置き、[audit.py](audit.py)・[axioms.lean](axioms.lean)・[modules.json](modules.json)から再生成できる。[audit-summary.json](audit-summary.json) と各declarations-*.jsonに件数と識別を保存した。

作業末の実workは次の一度だけである。dry-runは選択だけで実検査を行っていない。`--only`は使っていない。

```text
scripts/check.sh --level work --base 548d3fd94a5f1a171c9bc749b3408f8a9f3c08f8
```

終了0、外側7.815秒。仕様対応の集計と自己検査、仕様例の統合テスト7件、formal/からの既定lake buildとsorry拒否が通った。集計は現在の未参照節も列挙しており、全仕様節のテスト参照が揃ったという意味ではない。受け入れ条件の未記入はnoneだった。Rustのlib全件等はこのLean/写しの変更に自動選択されていない。

workの生出力5,847 bytes、SHA-256 `8bcdcaf37ec504aff8d0602df2fa40b1ecf641a1deb845d4478d9d987b04fc1c`。全実行の日時・コマンド・終了・外側時間・生出力の識別はchecks.jsonに残す。RSSは計画どおり未取得である。

最後の[verify.py](verify.py)は終了0。全新モジュールの既定import、群Dの既定全モジュールの保持、追加モジュール/ソースの件数、再生成した全宣言、328 API、64義務、唯一のwork、各記録100KB以下・リンク・手元の絶対パスと工程IDの混入を照合した。全formalソースは727ファイル、ソース上の公開定義/定理等62、名前付きprivate100、匿名の具体例41である。環境上のprivate/生成宣言を含む460件とは数え方を分ける。最終結果と全formalソースの一覧の識別は[inputs.json](inputs.json)に保存した。

停止は正常返却の境界の未確定によるものであり、時間上限への到達ではない。L40.21開始から.23終了までの外側区間は約1時間49分で、先行の依頼文/設計/レビューの読取りと、群末の記録・監査・workの時間は別である。能動時間と待ちを分離していないため、未経験の正常関係の証明へ一律の比で外挿しない。

## 再開1：境界に依らない部分

2026-11-04（日本時間）、設計者の追加依頼により再開する。準備開始は2026-11-03T15:10:13.758664+00:00。正常返却の境界は取りまとめの独立調査・判断を待つ。L40.23の正常関係とそれを使う部分、FirstReturnと二つの反例を含む既存の宣言には手を付けない。既存ファイルを改名しない。今回の実行記録はchecks-r1.jsonに分け、先のwork一度の記録を保持する。この再開ではworkを実行しない。

再開時の既存6モジュールと共通依頼文・plan・README・detail・群A〜D記録・既存レビューの識別をr1-start.jsonへ保存した。本番の追記は新しいモジュールを基本とし、既存宣言を変更しない。共有作業木を読む別のレビュー担当の作業へ書き込まない。

| 範囲 | 境界に依らず進める理由 | 決定待ちとして残す部分 |
|---|---|---|
| L40.24のMap/Setの純粋δ・各枝 | 同じ有限値に対するδの等号・型・縮約・個数を直接証明し、coreの正常返却を前提にしない | Map/Set.map/filterの正常返却からの個数・順序の関係 |
| L40.24の高階本体4本のRow.BodyTyped | 同じ構文と宣言から静的なDef.WellTypedを構成し、実行の末端を用いない | 4本の正常関係は境界の決定待ち |
| L40.25の不変欄・decode後の検査列 | 同じPの欄・構築の型付け、実δの検査結果と宣言順の静的な列を扱う | 任意の正常返却を境界から抽出する必要のある接続は境界の決定待ち |
| L40.26の固定19行・安全な参照 | Annotation、宣言表、同じ有限列の添字・欄の型付けは実行境界を用いない | NonEmptyList.map等でList.mapの正常関係を使う証明は境界の決定待ち |
| L40.27の高階の全位置 | LeQ・Covers・型付き実引数の静的な受理/拒否・代入を扱う | 正常関係を使う追加読者は境界の決定待ち |
| L40.28の328行の分類と群D部分表の接続 | 実署名・δ・BuiltinArgs・型/行/範囲引数と通常結果型を照合する | coreの正常返却の関係を閉じる行は境界の決定待ち |

各単位の開始・終了を着手時・終了時に追記し、進めた部分と境界の決定待ちを分けて判定する。区切りの検査はformal/からの対象指定なしの既定lake buildと、private・生成宣言を含む公理監査である。RSSは計画上の非採取を維持する。

### L40.24 の開始

開始（UTC）: 2026-11-03T15:12:08.108731+00:00。純粋δの構築・型付け・個数と四本の通常本体の静的型付けは、呼出しの正常返却の境界を使わないため実装する。四本の正常関係は境界の決定待ちであり、既存の六モジュールを変更しない。Leanの具体例にはtest-auditの作成時の関門を適用し、同鍵の元表現保持、鍵順、値の観測不能、引数の不一致を実応答の境界で確認する。

- L40.24 小区間1: `StandardMapSet.lean` に20本の純粋δ、正規化・更新・削除・射影・集合演算の型／個数、元キー保持、Ground/Adequate補題を追加した（`r1-u24-setready1` 成功）。callback遷移を使わないため返り境界に依存しない。全BuiltinArgsからの総括的応答接続と具体表読者は継続中である。
- L40.24 小区間2: `StandardCollectionBodies.lean` の4本の `Row.BodyTyped` を静的規則だけから構成した（`r1-u24-higher4` 成功）。List側は既存署名を呼ぶ。Map.mapはPair.first二回・Pair.second一回・callback一回の順を保つ。正常関係4本は境界の決定待ちである。現在、Setの証明に不要なPair前提を要求しない形へ補助を整理している。

- L40.24 小区間3: `StandardCollectionResponse.lean` でMap 10本・Set 10本の全 `BuiltinArgs` から、同じ有限宣言の構成子列を用いる具体δの存在、`Outcome.Typed`（Groundを含む）、`AdequateResult`、非exitを構成した（`r1-u24-setfull1` 成功）。入力は任意の型付き実値であり、Map値の観測を要求しない。純粋δの形状反転・欄の選択・有限正規化だけを使うため返り境界に依存しない。具体表の全20宣言への適用と最終照合記録を継続している。

- L40.24 小区間4: 正規化したentriesのキーcode整合・重複なしから、返したMap/Setの再正規化と実measureへの接続を証明した（`r1-u24-measure3`）。Map.set/removeとSet.add/removeの一致/不一致は同じn/n+1/n−1であり、集合演算のmeasure・コード所属・和の下限も実δの出力へ接続した。値の有限構文と純粋δだけを使うため返り境界に依存しない。
- L40.24 小区間5: `StandardCollectionExamples.lean` の具体P/Bで全20署名と同じδの全BuiltinArgs応答、四本BodyTyped、更新/削除/集合演算のmeasureと包含を読む（`r1-u24-measurereaders1`）。Pairの射影は元ソースの片側wildcardへ合わせ、List公開定義と既存rowの等号を確認した。初期のsize専用の重複した署名/入口は、全20本のMapAPI/SetAPIへ統一した。正常関係四本は境界の決定待ち。

### L40.24 の終了と受渡し

実終了（UTC）: `2026-11-03T16:29:36.530883+00:00`。開始から `77.47` 分。開始後60分の再評価で示した85〜105分の見込み以内に、境界非依存部分の実装と局所の検査を終えた。この記録の後はリポジトリへの書込みを止める。

| 新モジュール | 今回の性質 | 最終の検査 |
|---|---|---|
| StandardMapSet | 元Valの保持、縮約と整列、純粋20δ、型と個数、コード包含・和の上下限、再正規化後の実measure | `r1-u24-measure3`、`r1-u24-build-final` |
| StandardCollectionBodies | Map/Set.map/filter四本の通常coreとRow.BodyTyped、元の型・引数名・効果、List側の同一定義 | `r1-u24-bodiesfinal1`、`r1-u24-build-final` |
| StandardCollectionResponse | Map10本・Set10本の全BuiltinArgsから、同じδの存在・Outcome.Typed/Ground・AdequateResult・非exit | `r1-u24-responsesfinal`、`r1-u24-build-final` |
| StandardCollectionExamples | 同じ有限P/Bの全20署名と応答、四本BodyTyped、実measure・包含の読者、30個の既定例 | `r1-u24-measurereaders1`、`r1-u24-build-final` |

全量化する純粋入力は P/B・StoreTy・ts/es/rs/ws・結果型・効果である。BuiltinArgsの型付け・許容・注釈を反転し、同じTableとP.VarianceValidから鍵のコードと正規化の存在を得る。Map値の観測・鍵化、callbackの全域性・正常値の型・意味上の保存を新しい前提や未検査欄にしていない。MapのPair/Option入力は構成子・欄・arityの構文上の宣言である。具体表読者は同じ有限宣言からsatBと構成子列を作り、Map/Set各10宣言のlookupと同じδへ適用する。これは閉じたConstだけの例による代用ではない。

実ソースとの照合・SHA-256・各24行と全public宣言の読者は [sources-r1-u24.json](sources-r1-u24.json)、再作成の台本は [sources-r1-u24.py](sources-r1-u24.py) に保存した。照合一覧は100KB未満である。比較木は同じ型K内の数値・文字列/Bytes・構成子と欄・List/Map/Setの辞書順を構成する。Key.normalizeMap/Setの挿入順とRustの鍵順の射影を同一視しない。任意csに成立する型と個数の証明、同じtable.declarationsへcsを結ぶ具体読者、R50の実ID/tag収集と全体の順序対応を区別する。実ID/tagの対応を新しいProp欄へ置いていない。

既定importは formal/Benitoite.lean の末尾へ四行を追記し、01-12と07-04へ現在の性質を写した。O022/O034/O062/O065/O080/O131/O133/O134/O144を現状に合わせた。六つの旧Eモジュール、FirstReturn・二反例・L40.23の既存宣言、A〜Dの記録は変更していない。再開開始時のA〜Dと六LeanのSHA照合、64義務の保持、四つの既定import、検査済みolean、禁止構文と記録サイズを [verify-r1-u24.json](verify-r1-u24.json) と [台本](verify-r1-u24.py) で確認した。旧run.py/checks.jsonは保持し、今回の過程と最終結果はchecks-r1.jsonへ追記した。

| 残す作業 | 状態と所要 |
|---|---|
| 今回の境界非依存実装 | 完了。追加の実装時間は0分 |
| Map/Set.map/filter四本の正常関係とList側の正常関係 | 境界の決定待ち。今回の証明は依存しない。決定と実装の所要は不明 |
| R50の実ID/tag/順序収集、全328行の合成、全モデルCoreAssumptions | 未完。既定の後続担当へ残す。所要は当該計画で扱う |
| 区切りの全公理監査・全既存Leanとroot旧prefixの照合、独立レビュー・受入れ | 親の担当へ受渡し。所要は不明。今回の局所検査で完了とはしない |

この再開ではwork/dry-runと全公理監査を実行していない。Rust、plan/detail/README/reviews、既存Leanモジュールの改名・編集、git操作は行っていない。

### L40.24 の区切りの監査

引渡し後の既定全720モジュール・70,955宣言の公理監査は終了0。private・生成宣言を含み、今回の四モジュールは818宣言、初回分を含むEの十モジュールは1,278宣言だった。依存は `propext`・`Classical.choice`・`Quot.sound` の範囲内で、新しい公理は0である。[audit-summary-r1-u24.json](audit-summary-r1-u24.json) と各declarations-r1-u24記録に保存した。[audit-r1.py](audit-r1.py)・[axioms-r1.lean](axioms-r1.lean)・[modules-r1.json](modules-r1.json)で全対象を再生成できる。監査は39.353秒、生出力12,775,382 bytes・SHA-256 `f48f14a8af4161ef170e22ba06066e81d3441a44e6073f97a6df31ccf0c0cb0b`、対象一覧4,381,983 bytes・SHA-256 `ab6f31ca316286b5ae493d00b3e53bf363de155380b5eef3ad9f4bb6e28a0e0e`。生出力は一時領域に置いた。

[verify-r1.py](verify-r1.py)は終了0。731個の全Leanソース、既存727個の本文（rootは旧本文のprefix）、十モジュールの既定import・監査対象・olean、328 API、64義務、各記録100KB以下を照合した。初期117入力のうち115個は一致し、共有作業木でplan.mdとdetail.mdの更新を検出した。当担当はこの二ファイルを編集していない。前後の識別と観測時刻を [r1-input-updates.json](r1-input-updates.json)に記録し、その二入力だけを識別付きで照合する。再開依頼の境界に関する制約は維持する。検査台本で実行ラベルの一意性を仮定していた点は、同名の再試行を保持する実記録に合わせ、ラベルと開始時刻の組で照合する形に修正した。

L40.24の通常本体の正常関係四本とList側の正常関係は、引き続き境界の決定待ちである。この区切りでworkとdry-runは実行していない。今回の検査は独立レビュー・受入れの完了を意味しない。

### L40.25 の開始

開始（UTC）: `2026-11-03T16:44:43.923973+00:00`。境界に依らない不変欄連鎖、比較の実δ、decode済みResultからの追加検査本体を担当する。正常返却の既存関係・FirstReturn・二反例は保持し、任意のdecode実行との接続は境界の決定待ちとする。最初の15〜25分で依存Bool比較の型付けを確認する。

- L40.25 小区間1（UTC 2026-11-03T17:04:15.568183+00:00）: `StandardRecordFields`の同じ有限P.VarianceValid、篩付き二欄と外側recordの構築・型付き二段連鎖が通過した。`StandardDecodeComparison`は同じ%Integer.lessOrEqualの全BuiltinArgs→実δ→Outcome.Typed/Ground/AdequateResultを証明する。現行Rustの通常Booleanと追加する内部精密契約を区別する。比較δの契約に、その場で構築する同じconstructor式の欄比較も含めて全整数入力で証明し、`StandardDecodeBodies.checks_typed`のC_Let/C_If三組と成功枝が実際にその事実を読んで、返すEnvelope自身の全体条件へ導入する（`r1-u25-checks02` 終了0）。selectorの簡約を新しい型規則として追加していない。正常境界は使っていない。最初の比較接続の試行から残りの65〜115分見込みを維持し、Result/Rawの外枠、Row、payload/直接Step、照合を続ける。

L40.25のセッションは2026-11-03T17:04:54+00:00の観測時点でモデルの混雑（`Selected model is at capacity`）により終了した。単位の完了ではなく、同じ指定モデルの新規セッションへ引き継ぐ中断として記録する。小区間1の三モジュールと直近の検査結果は [unit25-interruption.json](unit25-interruption.json) に識別を保存する。残る外枠・Row・payload・照合・既定ビルド・全公理監査は未完であり、旧宣言を変更して穴を埋めない。

L40.25再開（UTC）: `2026-11-03T17:07:29.236833+00:00`。同じ単位の継続であり、元の開始時刻を維持する。三つの途中成果と中断識別を確認した。今回も正常境界を使わない後処理の本体・Row・具体遷移を対象とし、work/dry-runとgit操作は行わない。


### L40.25 継続の区切り

終了（UTC）: `2026-11-03T17:19:25.384002+00:00`。元の開始 `2026-11-03T16:44:43.923973+00:00` からの外側の時間は 2081.460 秒であり、モデル混雑による中断と再開の読み直しを含む。能動時間と同一視しない。開始を上書きせず、再開時刻と中断識別を上の履歴へ残した。機械の最大常駐量は未取得（計画上の非採取）。この区切りは、境界に依存しない担当分の完了であり、L40.25全体又は群Eの完了ではない。識別は [unit25-continuation.json](unit25-continuation.json) に保存した。

今回の三モジュールは `StandardRecordFields`、`StandardDecodeComparison`、`StandardDecodeBodies` である。前の区切りの十モジュールを保持して [modules-r1.json](modules-r1.json) に累積した。元のmodules.jsonは変更していない。既定rootに三つを含め、01-12の同じ節と07-04の対応表に実装した範囲を書いた。

| 担当の証拠 | 今回の到達点と実際の読者 |
|---|---|
| 同じPの不変欄 | recordDeclarationsの全構成子についてrecord_validを証明。checked_constructが非負の二欄を要求し、record_chainが型付きEnvelope→Checked→二欄の型付けを返す。既定例が構築と連鎖を適用する。Person.addressの位置1→Address.cityの位置0のTerm.Declaredも同じ有限Pで検査する |
| 構築するrecord全体の述語 | wholeTypeはEnvelope自身の二段欄lo≤hi。whole_constructは構築する同じconstructor式の比較を要求する。checksBodyの成功枝はcomparison_known→comparison_whole_true→whole_constructを読み、別の入力lo/hiだけの篩へ結果型を弱めない |
| 比較の実δ | %Integer.lessOrEqual、引数名left/right、実integerDeltaを保持。全StoreTy/型/行/範囲/値引数のBuiltinArgsからOutcome.Typed（Groundを含む）/AdequateResult/非exitを構成。recordBuiltinsの同じsig/deltaへcomparison_model_responseを適用し、同じP/Bの後処理がcomparison_functionをC_DependentAppで読む |
| 開いた後処理の本体 | postprocess_typedはResult[Raw,ConversionError]の入力からError/Ok・Raw二欄match・三つのC_Let/C_Ifを型付ける。postprocess_wellTypedが同じTelBodyTyからDef.WellTypedを構成し、postprocess_row_typedが同じRow.definitionを用いてBodyTypedを返す。既定例がRowとtelの等号を読む。通常decoder全体の型付けや検査成功を前提にして同じ結論を返す補題ではない |
| payloadと具体遷移 | postprocess_error_stepsは任意payloadを二歩で同じErrorへ返す。postprocess_raw_stepsは同じRaw二欄を五歩で捕捉する。(-1,-2)、(2,-1)、(5,2)、(2,5)の四つの既定例は、後処理入口から実比較δを含む9/13/17/17歩でそれぞれlo Error、hi Error、全体Error、同じ二欄のOkを返す。事象列は空、同じ継続・ストアを保持する。ErrorはState.errorへ読み替えない |
| Sourceとの照合 | Codecのpath/expected/found/reason、FieldとKey、decodeFieldの両枝、Peopleの六欄とdecodeObject→全通常欄→rejectExtra→構築の順、derive.pyの同じ順、実Rust比較名/引数名/通常Booleanを読み取って照合。原文の必要部分と入力SHAはsource-evidence-u25.json、対応と限界はsources-u25.mdに保存 |

Raw/Checked/Envelopeおよび有限表の `.Make` 名は内部代表である。People/Codecの原Sourceの名前や欄と写像を持つが、Rustの解決済み構成子IDとの等号又は現行生成decodeへの篩検査実装を主張しない。比較の精密結果型はrecordProgramのconstructor式を含む局所の追加契約であり、通常の全プログラム共通Rust schemaや全モデルの実宣言表そのものではない。実際に同じrecordProgram/recordBuiltinsの全BuiltinArgsを証明し、そのP/BのpostprocessRowが読む範囲に限る。

後処理Rowは同じcons表とBに対してBodyTypedまで構成した。P.defsへ通常decoder又は後処理Defを登録した入口の証明は含めない。通常decodeの任意のRunsから入力Resultを得る接続、全本体末端の同じ正常返却との関係は **境界の決定待ち** である。.23の正常関係・既存FirstReturn・二反例を変更していない。新公理・sorry・新しい信頼条件・型規則・主言明の変更はない。今回の対象内で別の静的な穴は発見していないが、全実宣言の収集、全328 APIの照合、生成器全体、全モデル充足は.28/R40/R50/L60へ残し、内部の一helperで代用しない。

検査のコマンド・開始終了・終了値・外側時間・生出力の大きさ/SHAは [checks-r1-u25.json](checks-r1-u25.json) に全試行を残した。Result外枠はr1-u25-outer04、Rowはr1-u25-row04、直接Stepsはr1-u25-steps02、四枝はr1-u25-branches02でそれぞれ終了0。最終の既定ビルドr1-u25-default02はformal/から対象指定なしのlake buildで終了0、全984ジョブ、3.437秒。新三モジュールの未使用simp警告を整理した後の状態であり、既存モジュールの警告は保持した。生出力は43389 bytes・SHA-256 `31aa068a9a75361ab4e856a3686b3d8d3cf5d797d1225199a0a4578240e55499`。生出力は一時領域に置き、永続の根拠リンクにしない。

r1-u25-sourceverify03は終了0、0.075秒。旧731Leanの本文とroot既存部分、新734Lean、三モジュールの既定import/olean/写し、原Sourceの順序・名前・四欄、各記録100KB以下を局所照合した。根拠の必要部分を [source-evidence-u25.json](source-evidence-u25.json) に保存し、台本 [verify-u25.py](verify-u25.py) も残した。これは独立レビュー又は全公理監査ではない。今回の三モジュールを含む全private/生成宣言の公理監査と全体verify-r1は、当担当が主木の書込みを止めた後、取りまとめが行う。

O022/O033/O034/O050/O062/O065/O080/O135/O144と共通O016/O027/O118を [obligations.md](obligations.md) の各行で更新した。64行を保持し、全体を閉鎖した義務は0である。先頭の.24〜.28未着手という古い概要は、.24/.25の今回の局所成果と.26〜.28未着手へ更新した。Rust・.bnt・共有plan/detail/README・reviews・A〜D・既存731Leanは編集していない（root末尾のimport追記を除く）。work/dry-runとgit操作は一切行っていない。

| 残る担当 | 見込みと状態 |
|---|---|
| 取りまとめの全private/生成宣言の公理監査・全体照合 | 不明。今回の識別と最終既定ビルドを渡して実施 |
| 通常decodeとの任意実行の接続・正常返却の関係 | 境界の決定待ち。決定前の見込みは出さない |
| 全実宣言/全328行・生成器・全モデル | .28/R40/R50/L60の元の担当。今回の部分で閉鎖しない |
| 独立レビュー・設計者の受け入れ | 不明。未実施 |

最終の記録整合の終了（UTC）: `2026-11-03T17:20:19.794512+00:00`。r1-u25-sourceverify05は終了0、64義務行の一意性、記録100KB以下、実作業ディレクトリの絶対パスが記録にないこと、Markdownの相対リンクも照合した。通常decodeの順の照合は原Sourceの対応確認であり、Rustの実行テストとは区別する。これ以降、当担当は主木の書込みを止め、全公理監査と全体照合を取りまとめへ渡す。元開始からの外側の時間は2135.871秒（中断を含む）である。

### L40.25 の区切りの監査

既定全723モジュール・71,191宣言の公理監査は終了0。追加三モジュールはStandardRecordFields 71件、StandardDecodeComparison 72件、StandardDecodeBodies 93件の計236件で、private・生成宣言を含む。初回からのE十三モジュールは1,514件、この再開の七モジュールは1,054件である。許可三公理以外の依存と新しい公理は0だった。[audit-summary-r1-u25.json](audit-summary-r1-u25.json) と各declarations-r1-u25記録へ保存した。台本はaudit-r1.py/axioms-r1.lean/modules-r1.jsonであり、同じ所属モジュールから全対象を再列挙できる。

監査本体は40.856秒、外側は41.247秒。生出力12,879,700 bytes・SHA-256 `5842eacb5a608bc567a6a69f7600d4e8e57a9b9cb5f65efec7ce72ef0bcc424e`、対象一覧4,407,244 bytes・SHA-256 `5841fcdbe8d5abfc6859a8e77f3714f85058d6d89abb1ac05a9f01fcb190f599`。生出力は一時領域に置き、識別だけを記録した。

verify-r1.pyも終了0。全734Lean、初回の727本文とroot旧prefix、全十三モジュールの既定import・監査・olean、328 API・64義務・100KB上限を確認した。既に監査済みの区切りのソースも、それぞれの監査記録のSHAとrootの該当prefixで再照合する。共有plan/detail二入力以外の初期115入力を保持した。この再開のwork/dry-runは0回である。初回L40.21の開始から四時間を超える区切りとして、ここまでの既定ビルドと全監査の結果を途中報告し、境界に依らない後続へ進む。能動時間と待ちの分離はしていない。

### L40.26 の開始

開始（UTC）: `2026-11-03T17:25:19+00:00`。具体NamesとAnnotationのWF/Sorted/Declaredを実宣言へ結び、固定19行の本体との一致を先に確かめる。正常返却の関係は境界の決定待ちとし、.23、FirstReturn、二反例を変更しない。欄の等号が不足するgetterは必要なEntailsの反例を残して停止し、独立する安全な入口を進める。

- L40.26 検査手順の是正: 局所確認で対象指定のlake buildを23回使った。対象指定なしという指示に反する実行であり、記録はchecks-r1-u26.jsonに保持する。以後の単独確認はlake env lean -M 12288、依存成果物と最終確認は新モジュールを既定importへ含めた対象指定なしlake buildへ是正する。この実行方法の誤りを成功の主張から省略しない。

- L40.26 小区間1: 具体Names/6構成子/全19Annotationは実tparams数で検査し、19はrow0とneffs1を維持した。安全7行のRow.BodyTypedを同じ固定Telで構成した（単独Lean r1-u26-bodies13 終了0）。get/同長参照は既存getFrontを使う新しい内部本体であり、公開BNTのラベルや旧nominalNEの現行本体と同一とはしない。正常関係を使わない。
- 検査実行器run-r1.pyへ、formal/以外又は対象/オプション付きのlake buildを実行前拒否する条件を追加した。単独lake env leanにもformal/と-M12288を必須とした。5拒否・3許可をsubprocessを一切起動せず確認した。既存の23回の対象指定buildは不適合な途中検査としてそのまま残す。

- L40.26 tail短試行の開始（UTC）: `2026-11-03T17:37:59+00:00`。既存sliceの通常引数と有限列drop/takeの同じδから正確な長さを供給する経路を試す。getter9行の不足とは分け、15〜25分を上限として見通しを判断する。固定19行や型規則は変更しない。


### L40.26 の担当範囲と区切り

今回の新モジュールはStandardSafeContracts、StandardSafeAnnotations、StandardSafeAccess、StandardSafeBodies、StandardSafeFieldGap、StandardSafeSliceの6本である。累積modules-r1.jsonに追記し、初回modules.jsonは保持した。固定19契約はimport以外の本文が元のsafe-contracts.leanと同一である。具体6構成子の同じ表に対し、全19行のWF・Sorted・Declaredを実tparams数で証明した。19もrow0/neffs1で検査しており、emptyに限定していない。

| 担当の証拠 | 今回の到達点と読者 |
|---|---|
| 具体Namesと宣言 | CheckedIntegerの0型引数/3整数欄、CheckedLengthの1型引数/3整数+List欄、CheckedIndexの1型引数/List+Integer+T欄、Resultの2型引数/Ok・Error、EmptyListErrorの0型引数/EmptyListを同じcons表で保持。全19Annotationはdefsを任意に差し替えた同じcons表へ適用する。DataArityと欄宣言を検査し、R50の実BindingId/tagとの同一性とは分ける |
| 独立する安全7本 | safeHead/Get、CheckedIndex.get、sameLengthGet、NE fromList/toList/headを同じ固定TelからTelBodyTy/Def.WellTyped/Row.BodyTypedへ構成。registered_bodiesは同じP.defsのlookup・Row.definition・d.tel・実型付けを返す。head_reference_bodyは同じP.defsの定義をV_Fun/C_DependentAppで実際に参照する |
| 同じList・別の同長List | front_responseは既存%List.getFrontの全BuiltinArgsから同じδの型/Ground/AdequateResult/非exitを構成。front_safeGetは変換可能な正常枝の同じxs[i]、front_sameLengthは元xsのT型要素と別ysの同添字U型要素を区別する。固定Telへu32上限を追加しない。Stopは保持する |
| tailの別経路 | slice_responseは通常3引数の同じ%List.slice δについて、全BuiltinArgsから長さn−front−backの精密結果、Ground/AdequateResult/非exitを構成する。負値/u32域外/切出し範囲外のStopを保持する。tail_row_typedはslice(xs,1,0)の同じ本体をC_DependentAppと既存CertificateKernelの有限証明書で固定safeTailのn−1へ接続する。registered_tailsは二つの内部名を同じP.defsから読む |
| 精密getterの静的接続 | 06〜14の9行は未証明のまま停止。StandardSafeFieldGapは同じPのminimum getterと同じΓ/actualΦで、元CI篩/整数域を含む全仮定が真、必要な欄等号が偽となるηを検査する。否定は当該V_RefineのEntailsに限る。固定契約の偽、全HasTypeCQの不可能性、実getterの誤実行とは記録しない |
| 一般Eと正常境界 | 19の一般row0 Annotationは検査した。非空・同長の強いBodyTypedとList.mapの正常関係への接続は境界の決定待ち。callbackの全域性・無失敗・pure Eを追加せず、.23の宣言・FirstReturn・二反例を変更していない |

安全9本は、それぞれの同じP/Bで検査している。7本のP/Bとtail2本のP/Bは、同じ6構成子を使う二つの有限表である。全19APIを含む単一Program.WellTyped又は全328API・全モデルCoreAssumptionsの証明と数えない。公開名/字面のU02、旧nominalNEからNE[T]別名へのR40変換、Rustのheap値と有限列・実ID/tagのR50接続も未完である。

全19行の判定、範囲ごとに正常境界を要しない理由、未証明の欄等号・代案・追加所要/実用影響は[sources-u26.md](sources-u26.md)に記録した。Rangeの公開関数のvalue、NE.fromListのvalues、NE各関数のvalueと固定Telのchecked/xsの差を[source-evidence-u26.json](source-evidence-u26.json)へ保存した。公開ラベルをfn部分型でrenameしていない。現行ListのOption、Result、RangeError APIを変更していない。

最初のtail短試行は実UTC `2026-11-03T17:37:59+00:00` に始め、`r1-u26-tail02` の終了 `2026-11-03T17:44:02.720830+00:00` に固定BodyTypedまで成功した。外側は363.721秒で、15〜25分の上限より短く閉じた。getter9本の静的接続と分離して試した結果であり、当初の11本を一律に未完とはしていない。

検査の全試行は[checks-r1-u26.json](checks-r1-u26.json)に保持した。対象指定なしの既定ビルド `r1-u26-default03` はformal/から `lake build` を実行して終了0、全990ジョブ、8.793秒。生出力43939 bytes・SHA-256 `2acc34ef7998dd5c3955c44ddd30af1b1b922868a525bc4630597aac844bfd37`。生出力は一時領域に置き、永久の根拠リンクにはしない。RSSは未取得（計画上の非採取）。Lean段階の成功をRust/Leanの全比較済みとは数えない。

`r1-u26-sourceverify03` は終了0、0.216秒。[verify-u26.py](verify-u26.py)は固定19本文、旧734Leanの全本文とroot旧prefix、現在740Lean、新6モジュールの既定import/olean/写し、全public宣言の既定内の読者、64義務行、原Sourceの欄順/引数ラベル/旧Option、各記録100KB以下と相対リンクを局所照合した。入力の捕捉値は[inputs-r1-u26.json](inputs-r1-u26.json)と分割記録へ残し、分割しても各SHAを維持した。公理依存の全監査と全体verify-r1は取りまとめが担当する。

手順の不適合は対象指定lake buildの23回である。[command-deviations-r1.json](command-deviations-r1.json)に元record/label/start/command/exitを再収集し、元checksを書き換えていない。run-r1.pyはformal/の引数なしlake buildだけを許可し、単独Leanにもformal/と-M12288を要求するよう是正した。5拒否/3許可は不適合コマンドを実行せず検査し、その後の追加逸脱は0である。検査記録の整合終了0と、指示への不適合23件を分ける。手順を全て順守したとは報告しない。

O034/O062/O065/O080/O142/O143/O144と共通O016/O027/O118を今回の部分証拠へ更新した。64行を保持し、全体の閉鎖は0行である。Rust・.bnt・plan/detail/README・reviews・A〜D・既存734Lean本文を編集していない（root末尾の新import追記を除く）。work/dry-runとgit全操作は行っていない。

| 残る作業 | 見込みと担当 |
|---|---|
| 精密getter06〜14の開いた束縛と欄等号の静的接続 | 未証明。追加所要は不明。型規則を変える場合は設計者の判断が先行する |
| 19の強いBodyTypedとList.mapの正常関係 | 境界の決定待ち。決定前の所要は不明 |
| U02の公開入口、R40のNE別名変換、R50の実ID/値の交換、全328行/全モデル | 元の後続担当へ残す。今回の局所証拠で閉鎖しない |
| 全private/生成宣言の公理監査・全体verify-r1 | 取りまとめへ受渡し。所要は不明 |
| 独立レビュー・設計者の受け入れ | 未実施。所要は不明 |

実終了（UTC）: `2026-11-03T17:52:06.137035+00:00`。元開始からの外側の時間は1607.137秒（26.79分）である。見込み50〜95分とtail短試行の上限内で、今回の境界非依存分を区切った。単位全体の完了ではない。最終局所照合r1-u26-sourceverify-finalは終了0、0.217秒。識別は[unit26-handoff.json](unit26-handoff.json)に保存した。この記録の後、当担当は主木への書込みを止める。

### L40.26 の区切りの監査

既定全729モジュール・71,649宣言の公理監査は終了0。新六モジュールはContracts 50件、Annotations 94件、Access 30件、Bodies 155件、FieldGap 32件、Slice 97件の計458件で、private・生成宣言を含む。初回からのE十九モジュールは1,972件、この再開の十三モジュールは1,512件である。許可三公理以外の依存と新しい公理は0だった。[audit-summary-r1-u26.json](audit-summary-r1-u26.json) と各declarations-r1-u26記録へ保存し、audit-r1.py/axioms-r1.lean/modules-r1.jsonから全対象を再生成できる。

監査本体42.999秒、外側43.397秒。生出力13,061,346 bytes・SHA-256 `e67d249c641cb089194757c0704c5b334fb3a9b606cf56f7b3774ad6ad36f6b9`、対象一覧4,449,859 bytes・SHA-256 `42bc991190f35e80d0eddc848fed423943cbe94e61cbe2aec8c43f69a6475110`。生出力は一時領域に置いた。

verify-r1.pyは終了0。740Lean、既定importと監査対象、以前の区切りの各本文・root prefixを含む45組のソース識別、64義務、328 API、各記録100KB以下を照合した。途中の対象指定ビルド23件はcommand-deviations-r1.jsonと元記録の全欄で一致し、その後の追加逸脱は0件だった。この終了0は検査記録の整合であり、対象指定23件が指示に適合したことを意味しない。再開後のwork/dry-runは引き続き0回である。精密getter九行の未証明と19の境界の決定待ちは残し、高階の静的な受理・拒否へ進む。

### L40.27 の開始

開始（UTC）: `2026-11-03T17:57:33.642034+00:00`。準備済みの静的な全位置の受理・拒否を本番へ統合し、同じ実引数の依存結果・潜在効果と四種の置換像の利用を照合する。準備の単独検査を本番統合の時間と混同しない。正常返却を使う追加の接続は **境界の決定待ち** とし、.23・FirstReturn・二反例は変更しない。work/dry-runとgit全操作は行わない。

2026-11-03T18:00:34+00:00の観測時点で、このセッションもモデルの混雑（`Selected model is at capacity`）で中断した。StandardHigherPositionsの全位置・注釈を含む単独検査annotations01は終了0、未使用simp整理後のclean01は終了1であり、修正と既定ビルド・写し・記録・全監査は未完である。同じ指定モデルの新しいセッションへ引き継ぎ、開始時刻は保持する。

継続の再開: 同じ指定モデルの新しいセッションで既存成果を引き継いだ。再開直後の実UTCは未取得であり、この継続で最初に取得した実UTCは `2026-11-03T18:02:15+00:00` である。元開始と中断の記録は保持する。

### L40.27 の静的な担当範囲と区切り

新モジュールはStandardHigherPositionsの1本である。旧名のファイルを改名せず、rootの末尾へimportを追加し、累積modules-r1.jsonへ追記した。内部の具体的な型位置の模型として、同じP・元型を持つΓ・変数0について受理と拒否を検査する。全標準宣言のProgram.WellTyped又は全モデルCoreAssumptionsを満たしたとは数えない。基準の完全IDは `548d3fd94a5f1a171c9bc749b3408f8a9f3c08f8`、開始時の旧740Leanの全識別は[inputs-r1-u27.json](inputs-r1-u27.json)と同記録の三分割入力を正とする。

| 静的な証拠 | 到達した範囲 |
|---|---|
| 同じ変数の受理と拒否 | 関数の入力反変・結果共変・潜在効果共変、List内関数、実Optionの共変と実Consumerの反変を検査。両型のWF・Sorted・Declaredは元変数の文脈で形成する。拒否はinv_var/coreの逆転から、実Γで自己8又はFail所属の不一致へ帰着する |
| 不変な位置 | ReferenceとFailは通常関数/依存関数の同じ正規形を受理し、篩を忘れる変換は拒否。名前と個数の異なる型もNamesWFが真であることを保ち、改名と追加引数だけの変換を拒否する |
| 同時代入 | dep_applyは反変入力のTelClosureへ同じ実引数[2,5]を適用し、依存結果と非空の潜在Failを同時に得る。10*2+5の算術構文を25の正規形と偽らず、逆順10*5+2を実25の型として拒否する |
| 四種の像 | 既存length_leへ四種の像を持つθとTransportを実適用し、元Γとの差を補う。移送先のvar2+1=7から正数性を供給する。条件なしの拒否は元Γの空List/n=0だけとし、移送先で正数性を除いた拒否を作らない。型・行・範囲を含む既存の開いた関数型/行の導出も別読者で読む |

全公開入口には、同じ既定ビルド内で実際に適用する読者を置いた。新しい主定理の前提、型規則、信頼条件、sorry/axiomを追加せず、既存の一般の帰納証明を再実装していない。既存.23の正常関係・使用部分、FirstReturn、二反例、固定19契約は変更していない。01-12と07-04へ今回の具体模型と保証範囲を写した。詳細な対照とテスト監査の関門は[sources-u27.md](sources-u27.md)、準備の入力と最終単独検査の識別は[preparation-u27.json](preparation-u27.json)に保存した。一時領域へ恒久的な根拠リンクを置いていない。

- 正常返却を使う追加の読者は**境界の決定待ち**である。今回の静的な型変換・代入・Transportはその関係を前提にしない。
- 精密getter06〜14の9行は、今回の型変換と実引数適用の前提に欄等号を使わないため独立である。[前の所見](sources-u26.md)の静的接続の未証明を保持する。
- 固定19行のmapの強いBodyTypedは今回の読者から使わず、List.mapとの正常関係は**境界の決定待ち**として保持する。

全試行は[checks-r1-u27.json](checks-r1-u27.json)へ追記した。中断前のannotations01は終了0、整理ミスのclean01と継続のclean03は閉じ括弧を失った構文エラーだった。clean02で当該ブロックだけを復元し、隣接削除範囲を併合したclean04で整理後の証明も通った。意味上の未使用前提と未使用simp引数を区別し、証明の前提・言明は緩めていない。最終単独readers01は終了0、0.958秒、生出力0 bytes（空ファイルのSHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`）である。

最終の既定ビルドr1-u27-default01はformal/から対象指定なしlake build、991ジョブ、終了0、1.788秒。生出力43712 bytes・SHA-256 `89f38441eba7df47541dcea1d35edbd8d93156701c0ec23906b6f2ecb4a7946e`。生出力は一時領域に置き、識別だけを記録した。RSSは未取得（計画上の非採取）。Rust/Leanの全比較、全公理監査、独立レビュー又は受け入れの成功として数えない。

r1-u27-sourceverify01は終了0、0.142秒。[verify-u27.py](verify-u27.py)は旧740Leanの全本文とroot旧prefix、新741Lean、1本の新既定import/olean、全public宣言の使用と具体定理の同じ既定内の読者、64義務行、各記録100KB以下、相対リンク、対象指定buildの追加逸脱0を局所照合する。証拠は[source-evidence-u27.json](source-evidence-u27.json)へ保存する。以前の不適合23件はcommand-deviations-r1.jsonと元checksに保持し、今回追加0という値で取り消していない。

O005/O006/O033/O034/O043/O050/O065/O069/O070/O167と共通O016/O027/O118を[obligations.md](obligations.md)で更新した。64行を維持し、全体の閉鎖は0行である。Rust・.bnt・共有plan/detail/README・reviews・A〜D・旧740Leanの本文は編集していない（root末尾の新importのみ追記）。work/dry-runとgit全操作は行っていない。

| 残る作業 | 見込みと担当 |
|---|---|
| 正常境界を使う追加読者と.23の正常返却の関係 | 境界の決定待ち。決定前の見込みは出さない |
| getter9行の静的接続と19の強い本体 | 未証明・境界の決定待ちを保持。今回の静的証拠で閉じない |
| .28の全実宣言・328行・生成器・全モデルの照合 | 元の後続担当。所要不明 |
| 全private/生成宣言の公理監査と全体verify-r1 | 取りまとめ。主木のwriter停止後に実施。所要不明 |
| 独立レビュー・設計者の受け入れ | 未実施。所要不明 |

実終了（UTC）: `2026-11-03T18:06:51.063165+00:00`。元開始からの外側の時間は557.421秒（9.29分、中断を含む）である。先行する準備証明を含まない本番統合の区間であり、元の見込み30〜55分の上端を下回った。最終局所照合r1-u27-sourceverify-finalは終了0、0.139秒。識別は[unit27-handoff.json](unit27-handoff.json)へ保存した。正常境界依存分は未完であり、単位全体の完了ではない。この記録の後、当担当は主木への書込みを止め、全公理監査と全体照合を取りまとめへ渡す。

### L40.27 の区切りの監査

既定全730モジュール・71,757宣言の公理監査は終了0。StandardHigherPositionsはprivate・生成宣言を含む108件で、E二十モジュールは2,080件、この再開の十四モジュールは1,620件となる。許可三公理以外の依存、新しい公理は0。[audit-summary-r1-u27.json](audit-summary-r1-u27.json) と各declarations-r1-u27記録へ保存し、同じ台本と所属モジュール一覧から再生成できる。

監査本体42.081秒、外側42.479秒。生出力13,109,268 bytes・SHA-256 `9a70263cff85f2e77073e63244c7638b3663a7f541a586cb0ac7780654c15917`、対象一覧4,461,095 bytes・SHA-256 `ec18e8ea35a712a9018a0326ef831974dd90a305984a793d480a785bc8c7bfa1`。生出力は一時領域へ置いた。

引渡し後の義務表の照合で、O114/O136/O139/O140の判定に未着手の記述が残っていたため、今回の同じ変数の対照・依存結果と非空Fail・四像・全位置の証拠へ更新した。本番ソースや言明は変更していない。verify-r1.pyは終了0で、741Lean、既定importと全監査対象、以前の区切りを含む66組のソース識別、328 API、64義務、記録100KB以下を照合した。対象指定の既知23件を保持し、追加の逸脱と再開後のwork/dry-runは0回である。正常境界依存分と精密getter九行は未完のまま、全標準行の分類と既存部分表の接続へ進む。

### L40.28 の開始

開始（UTC）: `2026-11-03T18:13:45.036614+00:00`。全328 APIを実宣言のまま分類し、既存Dの数値部分表と全BuiltinArgsの接続を進める。通常型、追加関係、具体δの有無、供給先、独立未完、境界の決定待ちを区別する。先行準備の所要はこの区間に含めない。既存741 Lean本文と.23の正常関係・FirstReturn・二反例を保持し、work/dry-runとgit全操作は行わない。

L40.28の開始後、取りまとめが全体照合の出力名と.26/.27のbaseline集約名の衝突を発見した。元の分割入力は全件保持されており、元partsのSHA・件数とhandoffの実開始からbaseline-r1-u26.json/同u27を再構成した。元集約indexの完全本文/SHAと追加欄は不明と明記する。.26の元partsには旧734formal Leanに加え、変更しないA〜D等を含む835入力がある。既存global出力inputs-r1-u26.json/同u27と元partsは変更せず、局所verifyの入力pathだけを別名へ変更した。今後のverify-r1.pyの出力と自己除外はglobal-inputs-{tag}.jsonへ分離する。これは記録名の修復であり、Lean証明や型規則の変更ではない。

2026-11-03T19:20:30+00:00の観測時点で、このセッションもモデルの混雑（`Selected model is at capacity`）で中断した。r1-u28-final-default01とr1-u28-evidence-final01は終了0だが、結果・義務表の最終記録と全公理監査は未完である。新十二モジュールと検査記録の識別を [unit28-interruption.json](unit28-interruption.json) へ保存し、同じ指定モデルの新セッションへ残る記録・照合を引き継ぐ。元開始時刻を保持し、本番の提供範囲や証明を広げない。


継続の再開: 同じ指定モデルの新しいセッションへ既存成果を引き継いだ。この継続で最初に取得した実UTCは `2026-11-03T19:22:07+00:00` である。中断の観測から再開までの差は97秒であり、能動時間とモデル待ち時間を厳密に分離した値ではない。元開始 `2026-11-03T18:13:45.036614+00:00` と中断記録を保持する。再開後は実装・証明探索を増やさず、記録と局所照合だけを仕上げた。

### L40.28 の担当範囲と局所成果

基準の完全IDは `548d3fd94a5f1a171c9bc749b3408f8a9f3c08f8` である。開始時の旧741 Leanの全本文とrootの旧prefixは[baseline-r1-u28.json](baseline-r1-u28.json)と四つの分割入力に捕捉した。群Eの既存20モジュールを保持し、新12モジュールを既定importと累積[modules-r1.json](modules-r1.json)へ追加した。累積は32モジュール、現在のformalソースは753 Leanである。最終コードは中断記録と同じSHAであり、継続でLeanの変更は行っていない。

| 新モジュール | bytes | SHA-256 |
|---|---:|---|
| StandardIntegerResponse | 7918 | `975a0b01895e3d1a038c710e3ccfdaef5c40eeb2a9f0c16eba5b53e63893231c` |
| StandardIntegerAPI | 38757 | `f509826e7afe0dc564c9ae506323a972868746c741381d88ffd1d4484ac0f821` |
| StandardConversionResponse | 13305 | `8815cc80cfba8085c55f838a9b35a3c16b4ff6276d12ad994c3caff7750f26f7` |
| StandardScalarResponse | 33104 | `fdb5d8c1e1123a4489c18fc73b324acc0c6b9021726ce6f0ade857f78eaa71ef` |
| StandardDecimalResponse | 28128 | `78be8a751ad918b8b29cce23812b59beebbbf67ccb7cf8e4dada0d8ac9a6701f` |
| StandardListResponse | 14716 | `399093408e40385375a0c8efaeced93e9d0d7ecaa62c9738944edf9dc20009b3` |
| StandardBytesResponse | 15010 | `b0657c1d7aca7f98d73fcd9adc1842fce687bb129a968cdb479bf386429f9430` |
| StandardActualListBodies | 25636 | `b9441b3194c6e1d56c7a33f94c79a61368499f556ea1a6fb888abe6387f55a7d` |
| StandardSignatureExamples | 61743 | `c6bde352a2d6a9c0ebd2d044c564a9b5c8bc9f97c82cb891fd5b885508353269` |
| StandardArithmeticResponse | 24849 | `8db658b499b7d1d9d9012c91604ab0f6bb0e014b9caca5dac903e4b7e7ded148` |
| StandardOrderResponse | 39153 | `4bf2729a8cd8a18d0072a7b1c8fc6771e94f1f80a75ea95b7412754f1fc6e4cb` |
| StandardEqualityResponse | 21850 | `053ca3765e377445085e2a5e32585be41b24ea9c0c7e8678339cf6cd12b7b70c` |

全公開入口は同じ既定ビルド内で実際に適用する読者を持つ。原Sourceの全署名と実名を検査するStandardSignatureExamplesも既定に含む。01-12の写しと07-04の対応には、今回の具体表・局所契約と保証範囲だけを反映した。主10言明、型規則、固定A〜B〜C後続署名、固定safe19契約、新しい信頼条件、sorry/axiomを変更していない。.23の正常関係・使用部分・宣言、FirstReturn、二反例も保持した。これらの保持は局所照合の範囲であり、全private/生成宣言の公理監査は取りまとめへ渡す。

### 全328 APIの分類と閉鎖の基準

母集団は原標準23モジュール・328公開API、内訳は244 builtinと84 coreである。coreのうち51行は四モジュールの別名ラッパーである。全行の判定は[sources-r1-u28.json](sources-r1-u28.json)、原候補と署名は[api-connections-r1-u28.json](api-connections-r1-u28.json)、説明は[sources-u28.md](sources-u28.md)へ保存した。通常の型契約、追加関係、全API又は全モデルの充足は別々に判定する。

| 通常契約の分類 | 行数 | 今回の証拠又は残り |
|---|---:|---|
| pure-local | 143 | 原署名の全ts/es/rs/ws/Ψ/a/eについて、全BuiltinArgsから同じnamed δの応答存在・Outcome.Typed・Ground・AdequateResult・非exitを導く。出力Typedや正常値を前提にせず、CoreAssumptions.delta_typedを使って具体表の充足を結論しない |
| core-local | 6 | List.map/filter 2本と既存Map/Set.map/filter 4本の同じComp/Rowを、各有限な同じP/BでBodyTypedへ接続。正常返却の関係は境界待ちとして残る |
| open | 179 | 100 builtinの全入力契約、Decimal.fromFloatの実bits由来parsed供給1行、51別名ラッパー、その他core27行。今回の担当内の独立未完であり、後段へ移して完了にしない |

143行は整数81、整数変換12、Byte/Character10、Float分類3、Decimal6、長さ5、List列操作4、Bytes変換2、既存Map/Set20である。既存Map/Setの証拠名は実際のnamespace `StandardCollections.map_api_response` / `set_api_response` を使う。

| 追加関係の分類 | 行数 | 判定の範囲 |
|---|---:|---|
| same-input-local | 109 | 同じwsと同じoutから、数値・bit・変換・長さ・同列などの関係を読む |
| same-input-leaf | 14 | 七幅の床除算/床剰余の局所数学関係。商のoverflow条件の全整理を残す |
| none | 111 | 当該行へ追加関係を割り当てていない分類。通常契約の閉鎖数とは異なる |
| local-partial | 25 | 既存局所関係を保持し、全実表への収集などを残す |
| boundary-wait | 7 | List/Map/Setのmap/filterとNonEmptyList.mapの正常関係 |
| core-static-open | 9 | S31だけのList.fold/forEach/any/all/find、Map.fold/forEach、Set.fold/forEach。実本体への静的適用とBodyTypedが独立未完 |
| core-open | 53 | 別名や現行nominalなどのcore接続が独立未完 |

「pure-local 143行」を「143 APIの全契約を閉鎖した」とは数えない。型付き応答・追加関係・原実装との同一性・全Program/CoreAssumptionsの充足が全てそろったという結論は出していない。全API、全S行、全体O行の閉鎖数はいずれも0である。

### 数学関係・通常本体・演算子の接続

整数のmin/max14は同じ二値の一方を選び数学上のmin/maxと一致する。整数変換12はSomeの同じ数学値と対象幅、Noneの域外、小幅の全域拡大とu64のOptionを分ける。床14は同じtdiv/tmodと符号補正、q*b+r、zero、補正結果の幅外とerr、正常値の同一性へ接続し、床剰余を商のoverflowだけでは拒否しない。商のoverflowを符号付き最小値÷−1だけへ整理する一般化は元.29に残す。

absolute7は正常値の絶対値・非負性・対象幅、overflow iff 符号付き最小値、unsignedでは元の同じ値を証明する。整数bitwise/shift46とByte6は同じ幅のbit列・符号復元・wrapする値・同じcountと域外errを保持する。bit演算を線形整数の一般推論へ加えていない。Byte/Character四変換のSome/None、同code、surrogate域外、Float三分類の同bitsとNaN/二∞orも同ws/outへ接続した。

Decimal六実名は同じPの五丸めモードを使い、places域外・係数overflow・96bit仮数/scale・TowardZero・整数からの同値・u64整数性とSome/Noneを区別する。fromFloatは全BuiltinArgsから元のbitsとOption結果を回収した後、任意parsedの再検査出口へ接続するだけである。同じbitsに由来するparsedの実供給は未接続であり、parsedを原署名の引数へ増やしていない。

List六実名とString/Bytes五実名は、同じ列・同じ要素・n+1/n+m/n・二つのString長・同じbyte列と長さを同じδへ接続する。countReplyの表現外errを保持し、有限列に一律のInteger上限を仮定しない。凍結したlistIndexAddSigのa/bを変更せず、StandardActualListBodiesは実%Integer.addのleft/rightで既存mapFrom/filterFrom/map/filterの同じComp/RowをV_Prim/C_Appから直接型付ける。List公開2本に加え内部helper2本を型付けたが、公開API件数へ加えるのは2行だけである。一つのBへ相反する二lookupを仮定せず、fnNamesの改名を部分型として導入していない。

328の外の[operators-r1-u28.json](operators-r1-u28.json)にはRustのOPERATORS全107実名を収集した。整数加減乗21・負号4と、整数七幅/Byte/Character/Float二幅/Decimalの四比較48、計73行は原引数名・全BuiltinArgsから同じδ・数学値又は比較述語・型/Ground/Adequate/非exitへ接続する。StandardSignatureExamplesと演算子の読者は原スキーマの全欄と実名等号を既定内で検査する。残る34行は整数intDiv/mod14、Float算術等10、Decimal算術等5、String5で独立未完である。

%eq/%neはこの107とは別に記録する。全Equality署名の一value型引数T、Equality制約、left/right、Boolean、空row/rangeを維持した。元の篩付きTの注釈・Ordinary・Equality satを全BuiltinArgsから回収し、12scalar領域×2名の条件付きpartialを同じTで既存δへ接続する。List/data/Bytes/Map/Set等の構造Equalityの全入力契約は未証明である。署名を基本型へ狭めず、常時errや型付け済みの返却値を供給する関数で補っていない。

### 全S行と後段への受渡し

[relations-r1-u28.json](relations-r1-u28.json)はS01〜S36の原文・対応API・供給先・残りを全36行で保持する。次表は各行の到達範囲をまとめたものであり、行の閉鎖を意味しない。

| 関係 | 現在の供給と未完 |
|---|---|
| S01/S02/S03 | 328外25算術と48比較を接続。intDiv/mod14と構造Equalityは独立未完 |
| S04/S05/S06/S07 | Byte/Character・Float分類・Decimalの同入力応答を接続。UInt8/Float64別名、String文字列API、fromFloatの実供給などは独立未完。全bit丸め/表記/Unicode全分類の元境界を保持 |
| S08/S09/S10/S11/S12/S13 | 二長、byte列、List長/空/列操作の同入力・同出力関係を接続。表現外errを保持 |
| S14/S15/S16 | List2と内部helper2の静的本体を接続。map/filter正常関係は境界待ち。公開head/tail/getの全入力契約は内部safe9本と別の独立未完 |
| S17/S18/S19/S20 | 既存Map10応答と縮約/同entries/更新削除・二高階本体を収集。map/filter正常関係は境界待ち |
| S21/S22/S23 | 既存Set10応答と縮約/更新削除/集合上下限・二高階本体を収集。map/filter正常関係は境界待ち |
| S24/S25 | 328外recordの同Pの不変欄・連鎖・構築条件とdecode後処理を保持。通常decodeとの全接続は境界待ち |
| S26/S27/S28/S29/S30 | 内部safe19の全Annotation、安全9本、同List/同element/別の同長Listを区別する証拠を保持。getter06〜14は静的未証明、19の強い本体/正常関係は境界待ち。現行nominalNEのmap以外4行は公開ラベル・別名変換を含む独立未完 |
| S31 | .27の全位置受理拒否・依存結果/潜在効果・四像を保持。S31だけのfold等9行の静的本体は独立未完 |
| S32 | 元のHeldValues/ModelHttpの保持値/同要求/同対象を供給。対象付きFile6/Http.sendInは328外で元のL50担当 |
| S33 | 正常/returned/failedの全合成、区間・警告・第一失敗は元.29〜35。今回のpure err/非exitから閉鎖しない |
| S34/S35/S36 | 全幅の変換/床/absolute/min-max/bit-shiftを前記の同入力関係へ接続。床の商overflowの全一般化と区間等は元.29〜35。alias/fromFloatの独立未完を保持 |

L60へ渡すのは実際に証明した具体δと本体契約だけである。L50のFile/Http、R40の生成器・NonEmpty別名変換、R50の実ID/ABI/鍵・値の交換は元の担当を保持する。100未接続API・51別名・その他core27・fromFloat実供給・構造EqualityはL40の独立未完のままであり、これらをL50/L60/R40/R50へ移してL40完了としない。正常境界待ち7公開行、328外mapFrom/filterFromと通常decode接続、safe19の未完を分け、既存境界への判断を待つ。

### 原ソースの照合・検査・記録の限界

原Source328行の型引数制約・引数ラベル・結果・効果・builtin名/core呼先/本体は、既存[api-numeric.json](api-numeric.json)と[api-collections.json](api-collections.json)から照合した。実.bnt入力はsources.jsonに捕捉したSHAと一致する。Declaredの型をstdlib原宣言が与えること、Rustのoperator/Equality/list-patternスキーマ、value/left/right等の定数、OptionとRoundingModeの構成子順は[source-evidence-u28.json](source-evidence-u28.json)へ必要な原文とSHAを残した。全型付けの実行、Rust登録ID・ABI・heap値・鍵・停止のRust/Lean全比較は未実施である。原文と有限表の対応を実行全比較と数えない。

全検査はrun-r1.pyを通し、単独Leanはformal/から `lake env lean -M 12288`、既定は同所の対象・オプションなし `lake build` を使った。最終既定ビルド `r1-u28-final-default01` はUTC `2026-11-03T19:18:48.940417+00:00`〜`19:18:49.093995+00:00`、1003ジョブ、終了0、0.153537333秒。生出力43628 bytes・SHA-256 `466ff1f4408adfbef6917ce76bb52d340bb5c413633ec5aabae308f228aada80` である。既存結果を再生したジョブを含む既定ビルドであり、clean buildの所要とは数えない。生出力に既存のリンク探索警告があるが、ビルドの終了は0である。RSSは未取得（計画上の非採取）。再開後はLeanが同じSHAなので既定ビルドを重ねていない。

全証拠宣言名を解決する `r1-u28-evidence-names01` は終了0、0.739245625秒、生出力81341 bytes・SHA-256 `343e044e60670bb996076275ad6f35cfa1eae245bdd8638b77fc0f7af037b3bd`。元の.26の対象指定build23件は[command-deviations-r1.json](command-deviations-r1.json)と元checksに保持し、以後の追加逸脱0と区別する。work/dry-runとgitの全操作は行っていない。

元の全試行は[checks-r1-u28.json](checks-r1-u28.json)、[checks-r1-u28-relation.json](checks-r1-u28-relation.json)、[checks-r1-u28-operators.json](checks-r1-u28-operators.json)に保持した。中断前は計95試行・終了1が34試行であり、初回の型/証明/記録の不一致を削除せず成功の再確認を続けた。localverify01のフィールド記法API.isBitsの検出とlocalverify02の内容同一再生成に対するmtime判定は検査側を修正し、コードの使用と同じSHA・既定buildの時系列へ照合を改めた。初回失敗を成功へ書き換えていない。最終localverify03は終了0、0.193722834秒だった。追加の最終照合は別記録へ保存する。

中断前のcatalog-final01とevidence-final01も終了0で、各0.039652708秒/0.038078625秒、生出力121 bytes・SHA-256 `767d4fdd9205ed16d9d78ef8edd767425e403595a6a089459ff96140c5284738` と646 bytes・SHA-256 `767c9e0828f2585d592362a950b707146d9fd9e1a8dd46bb18d901f85e977d8e`。生出力は一時領域に置き、根拠のリンクにせず大きさとSHAを記録した。

[verify-u28.py](verify-u28.py)の最終局所照合は、旧741本文/root prefix、新12の中断SHA・import/olean/既定内読者・現753Lean、原328行/原文断片/実107演算子、143署名/73スキーマ/全証拠名、全S36/義務64、各記録100KB以下・相対リンク・追加逸脱0を対象にする。全private/生成宣言の公理依存、全標準表/全モデル、Rust/Lean全比較、独立レビュー・受け入れは含めない。再開で追加したのは記録の識別を照合するPythonと文書だけであり、新しい処理系テストや証明探索を追加していない。

義務表は全64行を一行ずつ照合し、.28の該当行に通常型/追加関係/残りを記録した。.27後に取りまとめが直したO114/O136/O139/O140を保持する。全体の閉鎖は0行。Rust・.bnt・共有plan/detail/README・reviews・A〜Dと旧741Lean本文を編集していない（元unitでroot末尾へ新importを追記）。原baseline集約の再構成は前記の記録名修復の範囲に限り、不明な元index本文/SHAを復元したとは扱わない。unit28-progress.jsonは途中時点の履歴として保持する。

| 残る作業・受け入れ | 見込みと担当 |
|---|---|
| .23正常関係/使用部分、7公開行とhelper/decode、safe19の境界依存分 | 設計者の境界の決定待ち。決定前の所要は不明 |
| 179通常契約、構造Equalityと演算子34、getter9・静的本体等の独立未完 | L40の未完として保持。新しい実装範囲へ広げず、取りまとめが別単位の内容と見込みを確定。追加所要は不明 |
| 全private/生成宣言の公理監査、全体verify-r1 | 当担当の書込み停止後に取りまとめ。所要不明 |
| 元のL50/L60/R40/R50と区間.29〜35の接続 | 元の計画上の担当。今回の証拠で完了へ繰り上げない。所要不明 |
| 独立レビューと設計者の受け入れ | 未実施。取りまとめ/設計者が担当。所要不明 |

単位の元見込み30〜55分に対し、中断前の約1時間の実績はunit28-progress.jsonで観測し、コードを増やさず既定ビルドが通る区切りへ進めた。元見込み上端の2倍110分を超えた値としては記録しない。継続の見込み10〜15分の記録照合と1〜3分の局所確認を置き、能動時間と待ちを分離したとは数えない。完了とするのは境界を要しない今回の局所成果と最終記録の範囲だけであり、全E・全F06・全モデル・全義務又は単位全体の完了ではない。


最終局所照合 `r1-u28-sourceverify-final01` は終了0、0.195080458秒、生出力1437 bytes・SHA-256 `73eeb4f0e647e4396ff7e06ad898ae04cdb5909ca18f5f137eeaeaab47dfc83d`。記録は[checks-r1-u28-final.json](checks-r1-u28-final.json)、照合値は[local-verification-u28.json](local-verification-u28.json)、入力と出力の識別・未完の受渡しは[unit28-handoff.json](unit28-handoff.json)へ保存した。この継続の最終検査はこの1回であり、終了0の後にLean又は原Sourceを変更していない。

実終了（UTC）: `2026-11-03T19:25:45.097752+00:00`。元開始からの外側の時間は4320.061138秒（72.00分、中断を含む）、継続の初取得UTCからは218.097752秒である。能動時間・計算待ち・モデル待ちを分離できる記録ではない。元の見込み上端55分を超え、2倍110分未満で通る区切りに到達した。未完を残した部分引渡しであり、境界の決定、全公理監査、全体照合、独立レビュー、受け入れは未実施のまま取りまとめへ渡す。この記録の後、当担当は主木への書込みを止める。


## 再開1の最終監査と全体照合

取りまとめによる最終検査の開始はUTC `2026-11-03T19:26:16.001432+00:00`。本番writerの停止を確認してから実施した。新旧既定742モジュール・73,116環境宣言を所属モジュールから再列挙し、private・生成宣言を含めて監査した。群E累積32モジュールの3,439宣言、そのうち再開26モジュールの2,979宣言を含む。全モジュールの依存は既存の `propext`・`Classical.choice`・`Quot.sound` の範囲にあり、追加の公理・許可外依存はいずれも0である。ソース上の名前付き公開483、private570、匿名example385と、環境宣言数は別々に数える。

[audit-summary-r1-u28.json](audit-summary-r1-u28.json) に件数・全入力識別を保存し、[audit-r1.py](audit-r1.py) と [modules-r1.json](modules-r1.json) から全対象を再生成できる。監査本体43.637979209秒、生出力13,659,536 bytes・SHA-256 `19746b1b5d704a1e14a57379a4c324571d38f7f45d1bebaccf4f80a41c96596f`、対象一覧4,591,323 bytes・SHA-256 `7d0101764ace6722108f3a00854435a393f05559d0a08d4eb0e5c32e6f7dc0c5`。生出力と全対象一覧は一時領域に置いた。

最初の監査集計は、StandardSignatureExamplesが匿名example216本だけで環境宣言0件となる形を想定せず、集計のassertで終了1となった。Leanの監査走行後の集計失敗であり、公理を検出した失敗ではない。集計を0件の所属モジュールも一覧へ含める形へ修正し、全監査を再実行して `r1-u28-axioms02` が終了0となった。0件のJSONも残し、当モジュールの既定importと216本のカーネル検査は既定ビルドで確認する。最初の失敗は削除しない。

最終ソースに対する取りまとめの既定 `lake build` はformal/から対象・optionなしで実行し、`r1-u28-root-default01` が1003ジョブ・終了0、0.166722958秒。UTC `2026-11-03T19:31:46.389737+00:00`〜`19:31:46.556496+00:00`、生出力43,628 bytes・SHA-256 `466ff1f4408adfbef6917ce76bb52d340bb5c413633ec5aabae308f228aada80`。キャッシュの再生を含み、clean buildの所要ではない。既存のリンク探索警告を保持する。

全体照合の初回は監査集計の完了前に起動して要約不足で停止し、集計後にはArithmeticResponse/OrderResponseのmtime比較で停止した。この二つは同じ本文を再生成したためソース時刻だけが新しく、既定ビルドは内容が同じと判定していた。単独Leanの終了0だけでキャッシュ一致とは扱わず、[verify-artifacts-r1.py](verify-artifacts-r1.py) で既定と同じLake setup・固定Lean・`-M 12288`を使い、一時領域へ両oleanを再生成した。両方とも既定成果物とbytes/SHAが一致した。[content-checks-r1-u28.json](content-checks-r1-u28.json) に現ソース・setup・既定/再生成成果物の識別と検査labelを保存する。setupを付けない先行試行のoleanはpackage情報が異なり、同一とは数えず試行記録を残した。現在のverifyは、mtimeの古い二成果物にはこの内容一致と成功記録を要求する。

全体 `r1-u28-globalverify01` は終了0、0.194423791秒。新32モジュールの既定importと全宣言一覧、現753 Lean、初回727 Leanの本文/root旧prefix、各区切りを含む99組のソース識別、保持115入力と外部更新を記録した共有文書2件、328 API、64義務、全記録100KB以下と相対リンクを照合した。[global-inputs-r1-u28.json](global-inputs-r1-u28.json) に対象状態を保存する。[verify.py](verify.py) は再開後の最新監査を選んで [verify-r1.py](verify-r1.py) へ進む入口とし、既定importの照合が初回六モジュールに留まらないようにした。初回の検査実装も同じファイルに保持する。最終文書の追記後、この入口から `r1-u28-entryverify-final01` を実行し、終了0、0.253469709秒となった。UTC `2026-11-03T19:39:52.997428+00:00`〜`19:39:53.250948+00:00`、生出力838 bytes・SHA-256 `1479e359e96bd0de9d87f5d987d4cbd3efc7d7a9dbcdf38062c7eb5a73d3e7b1`。この終了記録の追記後は同じ入口で記録を再照合する。本番Lean・写し・API分類をこの最終監査以降変更していない。検査の全日時・コマンド・終了・生出力識別は [checks-r1-u28-final.json](checks-r1-u28-final.json) に保存する。

実行方法の逸脱は、.26で対象指定のlake buildを23回行った点である。発見後に停止し、run-r1.pyで対象・option付きbuildと根からのbuildを拒否するようにした。元23件・失敗を保持し、以後の追加逸脱0を照合した。再開1でwork/dry-runは0回、初回のwork1回は過去記録として保持する。全体verifyの終了0は、既知の逸脱を含む記録の整合を表し、全実行が指示どおりだったという意味ではない。既存の集約index二件との名前衝突は前記のとおり元partsから別名indexを再構成し、元indexの本文/SHAは不明と明記する。既存ファイル名を変更せず、今後の全体出力名を分けた。本番Leanの内容には影響していない。

| 完了条件の照合 | 再開1の最終判定 |
|---|---|
| 境界に依らない部分を進め、その理由を各単位に記す | .24は単独の純粋δと静的本体、.25は不変欄とdecode済みResult、.26は注釈と静的安全本体、.27は静的位置と代入、.28は実署名/同δ応答と行分類。各節に根拠を記録 |
| .23とFirstReturn・二反例の保持 | 初回の全formal本文と区切り入力のSHAで保持を照合。正常関係の新実装なし |
| 固定19契約と具体Namesからの宣言対応 | 原19行は同じSHA。全19Annotationを供給し、本体9本を固定契約へ接続。getter06〜14の静的未証明、19の強い本体の境界待ちは残る |
| 境界待ちをresults/obligationsに明示 | 公開List/Map/Set.map/filter六行とNonEmptyList.map一行。328外helper二本、通常decodeへの接続、正常関係を使う読者も境界の決定待ち |
| 全328分類と群D部分表の接続 | 通常143応答・6本体・179独立未完、追加関係109同ws/out・14局所葉などを全行保存。全API/全S/全体Oの閉鎖0。未完を後段へ移して完了にしない |
| 原ソース・写し・公開入口・記録 | 原.bnt/Rustの照合範囲と限界を保持。新32既定import・01-12/07-04の対応、読者、全公理監査を確認。Rust/Lean全実行比較は未実施 |
| 今回の検査と受け入れ | 既定ビルド・全公理監査・全体照合は終了0。work再実行なし。独立レビューと設計者の受け入れは未実施 |

残る境界非依存の未完も明示して引き渡す。getter九本はP_Conの束縛値と欄の等値を結ぶ必要なEntailsの反例を保存し、新規則・契約変更を足していない。取りまとめには正常返却の境界のほか、この静的接続を既存導出で進めるかの判断を求める。反例は当該Entailsに限り、HasTypeCQ全体や契約自体の不可能性とはしない。

| 残る作業・検査・受け入れ | 見込み |
|---|---|
| 境界決定後の.23正常関係、公開七行/helper/decode/安全19の接続 | 方式の決定待ちで不明。独立調査の結論後に積み上げ直す |
| 精密getter九行の既存導出・代案の調査 | 最初の短い調査15〜25分、その後の実装・検査の全所要は不明。契約又は規則の変更前に判断を仰ぐ |
| 通常179行、構造Equality、演算子34、S31九本等の独立未完 | 不明。同種性のない未完を一律の係数で外挿しない |
| 残る変更後の既定ビルド・全公理監査・全体照合、群末のwork一度 | 変更量に依り不明。今回の監査本体43.64秒は実績であり、残工数の見積もりではない |
| 独立レビュー・設計者の受け入れ | 不明。今回の検査で代替しない |

