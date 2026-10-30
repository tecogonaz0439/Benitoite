# `.02a` の参照の保存と継続を隠す移動の公開条件

2026-10-31。B_WORKは `2c8b9cc5380dc2956e245cb95d7849ad98c4bcdf`、ブランチは起動指定の `m014/l00b.02`。gitによる照合や状態変更は行っていない。

## 今回の到達点と停止の理由

取りまとめが採ったWFの候補(1)(2)をsignatures第3.4節へ反映し、本番の現行Term3/Pred8/Ty16へ独立した参照の判断を置いた。参照からWFを導く入口も本番へ置き、旧整数だけのtermWF_of_sortedを置き換えた。全Term20/Pred14と部分的な観測像の代数的な補題は [型検査用の下書き](02a-term-syntax-draft.lean) で確認した。この下書きは本番へ接続しておらず、`.02a`の完了とは扱わない。

**停止の理由は、someの全位置への参照と、既存ShiftMapによる継続のhideを同時に保存する公開条件が足りないことである。** 今回認められた参照の判断は `∃ a, Γ[i]? = some (some a)` とした。V_VarのOrdinaryを暗黙に足していない。この判断ではsome contへの参照も許される。一方、ShiftMap.lookupはOrdinaryの位置しか保存せず、hideContsはsome contをNoneに変える。既存の公開の補助の形のまま、今回の参照の保存を導くことはできない。

これは旧整数sortの既存の定理や主定理の反例ではない。旧termSortedは整数の型の位置しか許さない。新しいsnapshotのsort検査へ今回の参照の判断を含める際の、一般の補助定理の接続の不足である。主定理へ新しい前提を加える案や、書ける形を狭める案を実装したものでもない。

## 本番の関係を使った確認

[02a-reference-map-boundary.lean](02a-reference-map-boundary.lean)は、本番のSubstTypingをimportする。次の5定理を証明した。

| 定理 | 確認した命題 |
|---|---|
| transport_accepts_nonvalue_position | Γ=[some fn]、Δ=[none]、θ.values i=var 0で現行Transportが成立する。var 0はsourceの参照の判断を満たし、targetの判断を満たさない |
| shiftMap_can_hide_a_referenced_position | Γ=[some cont]、Δ=[none]で現行ShiftMap 0 0が成立し、var 0の参照は保存されない |
| hideConts_erases_continuation | hideConts [some cont]=[none]。上の変換は実際のhideと一致する |
| no_transport_reference_preservation | 現行Transportだけから全項の参照の保存を導く全称命題の否定 |
| no_shiftMap_reference_preservation | 現行ShiftMap 0 0だけから全項の参照の保存を導く全称命題の否定 |

sourceのfn/contはどちらもsomeであり、Noneの参照を禁じる今回の条件を破っていない。targetの長さは1なので、像var 0はWFの上限も満たす。したがって、今回追加した「someなら観測像の上限を満たす」という条件だけでは、この参照の保存は回復しない。

## 拡張snapshotのsort保存の境界

[下書き](02a-term-syntax-draft.lean)のReferenceBoundaryは、確認済みの全Termの構文・部分置換・VarsInを使い、Carrierの4形と、var/integer/listValue/measureに必要なsort規則だけを別に定義した。これを全HasSortの本番実装や、全型付き導出の反例とは扱わない。

対象の項は `measure listLength (listValue [some (var 0)])` である。listValueは要素のsortに依存せず根のlist sortを持つが、someスロット内の参照は検査する。

- transport_sort_boundary: source=[some function]、target=[none]、像ν i=some(var 0)で、sourceの参照とinteger sort、全sortの像の条件、some位置の像のWFが成立する。置換後も同じ項で、targetの参照を満たさないためsortを失う。functionはsortを持たず、像の全sort条件はその位置で空に成立する。
- hide_reference_boundary: source=[some continuation]で同じsnapshotの参照とinteger sortが成立し、target=[none]では成立しない。

整数を根に持つmeasureでも、子snapshotの参照の保存は必要である。Transport.valuesを整数から全sortへ広げるだけでは、sortのない型の位置の像に何も要求できない。TransportへTerm.ImageReferencesに相当する条件を具体的に渡すことは必要だが、それだけでは次のShiftMapとの接続を閉じられない。

## 修正候補と対象の署名

二つの候補のどちらを採るかを、取りまとめの公開契約の判断へ返す。今回の承認をOrdinaryの追加までと解釈して先に進めない。

| 候補 | 公開の判断・補題への変更 | 接続で確かめる義務 |
|---|---|---|
| (A) 論理から読める参照をsomeかつOrdinaryの位置へ限定 | Term.References等の変数の場合を強める。snapshotのsomeスロットにも適用する。Transportへ、許される参照の位置の像の参照保存を追加 | V_Varは既にOrdinaryを要求するので、実際の通常値の観測との整合を示す。型・行置換で参照可能な位置の型がcontに変わる場合の条件も公開kindとそろえる。利用者の書ける形を変えないことは取りまとめが確認する |
| (B) 今回のsome全位置の参照を維持 | 一般のshift/hideのsort保存に、隠す継続位置をその項・型・Φが読まない条件を追加。Transportの像の参照条件も明示する | sourceの述語・注釈と型付きの観測から、その非参照条件を導く内部判断が必要。HasTypeVQ.hide_contextの相互証明と、捕捉の下のSubstOk.hideまでそろえ、主定理の外側へ条件を残さない |

単にShiftMap.lookupをsomeの全位置へ強める案は、hideConts [some cont]=[none]に使えなくなる。ShiftMap.transportだけを直してhide側をそのままにする案も閉じない。

少なくとも次を一組として確認する必要がある。

| 署名・定義 | 必要な確認 |
|---|---|
| Term/Pred/Ty/Eff.ReferencesとTerm.HasSort/Pred.Sorted | some contの参照を許すか、通常値の位置に限るか |
| Transportの欄、Term.hasSort_bind、Pred.sorted_bind | sortを持たない位置も含む像の参照条件 |
| ShiftMap.transport/values、HasTypeVQ.shift_values | hideも許す一般の文脈関係から、どの項・型の参照を保存できるか |
| HasTypeVQ.hide_context、SubstOk.hide | 継続を隠す前に、対象の注釈・Φ・観測がその位置を読まない証拠をどこから得るか |
| 型・行の置換/kind | Ordinaryを参照条件に使う案では、像でその条件を保存する根拠 |

追加の公開前提を担当の判断で足さず、「ほかに署名の範囲を超える契約の変更が要るときだけ、ビルドが通る区切りで止める」という起動指定に従って停止する。L00bの上端77時間、全体見込みの上端、時間超過を停止理由にしていない。

## 検査と引継ぎ

全既定 `lake build` は604ジョブで終了0。変更対象のScopeSyntax/Context/ValueRegularityの1063宣言を、定義元のモジュールからprivate・生成宣言も含めて抽出した。依存はpropext・Quot.sound・Classical.choiceの範囲内で、sorryAxを含む未許可公理0件。本番のRefinementソースにsorry/admit/axiomの語の該当0件。補助5定理、全Term/Pred下書きも `lake env lean -M 12288` で終了0。原出力・時間・ハッシュは [02a-r3-commands.json](02a-r3-commands.json)、[集計](02a-r3-validation.json)に保存した。workは依頼どおり取りまとめへ残した。

本番に追加した参照の判断は現行構文を対象とする。全Term/Predの下書きと、未完のTy21/Tel2/Atom2/Const16、全sortの型付き観測、有限置換、WF/sort/移動/置換/narrowing/埋め込みの追随は、同じ`.02a`の担当へ残す。後の群へ送って完了としない。

| 残る作業 | 能動時間の見込み | 待ち |
|---|---:|---|
| 候補の契約判断・公開署名の確定（取りまとめ） | 不明 | 設計者への確認が必要かも取りまとめが判断 |
| 追加の参照条件とhide/型付き像の接続の最初の確認 | 0.5〜1時間の見込み。確定契約で再評価 | 不明 |
| 残りの`.02a`本番統合・全場合・既定ビルド/公理検査・記録 | 当初3〜5時間の枠は未検証。上の0.5〜1時間を単純加算して確定見込みとしない | ビルドは今回6.1942秒だが増分後は不明 |
| 群末の独立レビュー・受け入れ（取りまとめ/設計者） | 不明 | 不明 |

新しい範囲の実装はこの判断が確定してから再開する。今回の小さい境界の証明の所要から、全構文の証明単価や能動時間を外挿しない。
