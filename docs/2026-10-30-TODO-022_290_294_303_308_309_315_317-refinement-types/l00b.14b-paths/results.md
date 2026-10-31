# L00b.14b-paths: 経路条件の規則の結果

2026-11-01。**分類は「閉じた（本書に列挙した規則と代表の言明が閉じた）」である。** 独立レビューの中1・軽1〜5と、再レビューの再中1・再軽1に対応した。match で作る事実を広げ、実際の firstAlt の成功・失敗から事実が真であることを本番で証明した。相互三族の主な操作と旧導出の読み替えは維持した。全状態の保存、一般のパターン束縛を含む E_MatchBody/E_MatchGuard の開始状態からの保存は L20 に残す。

指定ブランチは `m014/l00b.14b-paths`、B_WORK は `467575dab0a8b524ba72a0c75e79a2963ef1ebaf` である。依頼の値を使い、git による照合・切替・作成・コミットは行っていない。観測の添字は前回の取りまとめで承認された変更であり、続き2でその規則のもとに事実の種類を追加し、今回の続き3で除外の補助入力を根の形へ替えた。D19 が破れた反例は得ていない。

## 規則の新旧と今回足した事実

| 規則 | 開始版 | 最終の規則 |
|---|---|---|
| C_If | 両枝へ同じ Φ | 条件の観測 t を共有し、真枝へ boolCond t true、偽枝へ boolCond t false を足す |
| 短絡 | 専用 Comp はない | and/or は if に脱糖する。今回、let c = if a then b else false; if c … の真枝が a を読む境界を追加した |
| C_Match | 入力型だけを腕と共有 | Option Term の観測を HasTypeArmsQ と共有。some なら実際の観測と sort、none なら事実なし |
| plain | 本体・残りとも同じ Φ | 本体へ matchedTests の事実、後続へ excludedTests の事実を足す |
| guarded | guard は Boolean、本体・残りも同じ Φ | guard は Boolean{p}。guard へ照合の事実、本体へさらに p.open true。後続には guard の偽も除外も渡さない |
| K_Guard | 評価前から本体の ClosureTy を要求 | 条件前の CaptureOk と条件下のソースの本体の導出を GuardBodyTy に保持。true で条件を足して ClosureTy を作る |

今回の plain/guarded の本体側の照合の事実と、無 guard の plain の後続側の事実は、次の一覧に限る。前回は根の構成子・非空・引数なし構成子の除外だけだった。

| パターン | 成功した本体へ | 失敗した後続へ |
|---|---|---|
| Integer、Character、Boolean、String、Unit のリテラル | 等しい事実。整数は eq、他は対応する sort の compare eq | その Not |
| Integer/Character の範囲 | 両端を含む二つの le の And | その Not |
| 空 List | List の長さ = 0 | 非空（0 < 長さ） |
| 前又は後に要素を要求する List | 非空 | 追加なし |
| 構成子 | 根の constructorIs | 全欄が wild/var のときだけ、その Not。引数なしも含む |
| or パターン | 全選択肢が事実を作るとき、その Or。同一なら単一事実を保つ | 各選択肢について作れた否定をすべて並べる |

Float/Decimal/Byte/幅別整数/opaque など、現行の PatTy がリテラルのパターンとして許さない種類には事実を作らない。根の構成子の事実は欄を絞るパターンでも成功時に成立するが、その失敗から根は除かない。入れ子の構成子が唯一の構成子かどうかは調べず、除外できる欄を構文の wild/var に限った。ワイルドカード・変数だけのパターン、事実を作らない選択肢を含む or の本体へは事実を追加しない。

新しい公理、主な VQ/CQ の前提と結論の変更、利用者の書ける形の制限、提供範囲の変更、精密な外部状態の新設はない。別名の観測付き判断は置いていない。

## 閉じた定義・補題

本作業の新規の本番モジュールは PathConditions、PathFacts、ClosedCapture、MatchPaths、今回追加の MatchFacts の5本である。書き込み対象は既定 import を含む17ソースで、[source-delta.json](source-delta.json) に一覧と最終ハッシュを記録した。これは git の差分を取得した記録ではない。完全署名は [signatures.md](signatures.md) と、171署名の出力 [1](public-api-1.log)・[2](public-api-2.log) にある。

| 群 | 閉じたもの |
|---|---|
| 事実の生成・変換 | PathLiteral、PathTest、pathLiteral?、patternTest?、alternativesTest、irrefutableField、matchedTests、excludedTest?、excludedTests、PathTest.bind/root_sorted、pathFacts_bind、bind_paths、rename_paths |
| 照合成功の健全性 | MatchFacts の con_root、list_root、literal_test_true、range_test_true、empty_root、pattern_test_true、alternatives_test_true、matched_true、matched_evalClosed_true、matched_paths_true |
| 照合失敗の健全性 | literal_test_false、range_test_false、constructor_test_false、empty_test_excluded、pattern_excluded_true、excluded_true、excluded_evalClosed_true、excluded_paths_true |
| 照合の補助 | PatTy/PatTys.binders_length、matchVal/matchList_binders、selectSlots_total、firstAlt_none_all、firstAlt_some_mem、RootShape.scalar/list/data、typed_values_length、PatTys.arity_length、irrefutable_fields_match |
| 弱化・旧導出 | VQ/CQ/ArmsQ/ImageOk の weaken_conditions、if_legacy、plain_legacy、guarded_legacy、match_legacy |
| if の保存 | boolCond_wellFormed、ite_branch、boolCond_evaluates、ClosureTy.branch/ite_selected、StateTyE/StateTy.if_true/if_false |
| guard の保存 | GuardBodyTy の input_annotation/result_annotation/of_true、ClosureTy.ret_const、ContTy.guard_true/guard_false、StateTyE/StateTy.guard_true/guard_false |
| match の逆転・捕捉 | 腕の sub_result/normal_result/eff_result、HasTypeCQ.match_arms、ClosureTy.open_zero/match_source、HasTypeArmsQ.capture_plain（任意の δ）。利用先のない guard_context は再レビューで削除 |
| 実際の値の閉性 | Capture.Closed.env、Capture.Adequate.env、closeVal_adequate、close_annotations、VQ/VsQ/EachQ.close_ground |
| match の状態の代表 | StateTyE/StateTy の match_start、match_skip、match_body_zero、MatchPrefix.advance、addEvaluatedFacts、paths_evaluate |
| 根の形と型付けの入口 | RootShape、RootShape.core/refineNorm/norm/subtype、rootShape_of_typing、excluded_true_of_typing、excluded_evalClosed_true_of_typing、excluded_paths_true_of_typing |
| 相互操作 | subst・subst_under_none・shift_values・shift_types・narrow の全相互場合と既存の利用先 |

matched_true は、実際の firstAlt の成功・事実列の membership・実際の toTerm? の観測だけから evalWith = some true を返す。excluded_true は、さらに同じ入力型の AltsTy と RootShape を使う。evalClosed 版は閉じた WF 0 と Sorted [] none を使う。**事実の評価成功・Entails・本体又は到達の型付けをこれらの健全性の仮定に置いていない。**

失敗の側では、slots の失敗とパターンの失敗を区別した。AltsTy の permutation と、実際の束縛数を示す補題から selectSlots の全域性を導き、firstAlt の失敗が全選択肢の失敗であることを示した。リテラルの値幅、構成子の欄数、At の欄数は RootShape と PatTy から読む。rootShape_of_typing は閉じた値の型付けから RootShape を構成し、V_AtError では shape.Declared にある7欄の宣言を使う。List の要素や構成子の欄の再帰的な型適合は要求しない。観測の sort だけを値の型適合の代わりに使っていない。

if/guard の保存は開始の StateTyE を入力とし、C_Sub・C_Normal・C_Eff、継続の K_Sub を逆転する。guard_true は既存の Builtins.SubstitutionAssumptions も使う。match_body_zero は開始の StateTyE と束縛数0の選択した腕を入力とし、評価だけの補助入力 MatchPathsEvaluated から本体を閉じる。この補助入力を開始の状態の型付けから一般に構成する合成は L20 に残した。

**閉じた条件は addEvaluated/addEntailed で CaptureOk の証拠を構成するために使う。到達する状態に経路条件を残す欄は追加していない。**

## 場合の数の予定と実際

| 対象 | 予定 | 実際 |
|---|---:|---:|
| 相互三族 | 14族・76場合 | 14族・76場合 |
| HasTypeVQ / HasTypeCQ | 29 / 24 | 同じ |
| Step / ContTy | 76 / 10 | 同じ |
| PathTest / PathLiteral / GuardBodyTy | 今回9 / 5 / 1 | 9 / 5 / 1（PathTest は前回3） |
| E_IfT/F・E_GuardT/F の開始状態からの保存 | 4 | 4 |
| match の開始・skip・本体の代表 | 3 | 3。本体は束縛数0と評価の補助入力 |
| 旧導出の読み替え | if・plain・guarded・match | 4入口 |
| 新しい match の正負の対 | 9形 × 本体/後続 | 18組。ほかに Or、束縛あり・観測あり、guard・観測あり |
| 境界の公理依存 | 両入力の全宣言 | 249 + 180 = 429宣言 |

実数は [case-inventory.txt](case-inventory.txt) にある。PathTest は相互三族の外の定義である。場合の数を足して全状態の保存を主張していない。

## 境界の正例と負例

[boundary.lean](boundary.lean) と [match-boundary.lean](match-boundary.lean) の既存の正例は、具体の宣言・空のストア・パターンの型付けから構成する。今回の CheckedAt の代表は、保持を示す CheckedWitness と opaque の注釈を補助入力に、scoped_forget を通した List/構成子の値の型付けを構成する。除外の評価の結論は仮定しない。負例は事実を外した本体の型付けを、ret_value/facts と具体の論理の解釈で否定する。

| 入力・入口 | 検査した内容 |
|---|---|
| 既存 boundary の if | 条件を読んでこそ型付く真枝と負例。実際の真偽の遷移の前後の StateTy。開始導出の C_Sub/C_Normal/C_Eff |
| Match / Match.Excluded / Nonempty | constructorIs、先行の引数なし構成子の否定、非空を読む腕。事実を外す負例。E_Match・E_MatchSkip・束縛数0の E_MatchBody の前後 |
| Guard の x=3 / x=9 | 局所宣言の比較結果型を C_DependentApp で読む。E_MatchGuard 前後、E_Prim、ret true/false 直後の途中状態、E_GuardT/F と到達を型付ける。x=9 の本体には ClosureTy がない負例 |
| Guard.let_if_connect | apart は現行の Entails では導けない（rv-14bp-t2）。L30 の規則を足した後の接続の形を検査する条件付きの定理で、現在適用できる導出ではない |
| ShortCircuit.short_circuit_reads_left | let c = if a then b else false; if c … の真枝で a を読む。apart を仮定しない |
| BoundObservation.arms_typed | Box(y) を照合し、一束縛の liftMany で持ち上げた constructorIs を本体が読む |
| BoundObservation.observed_guarded_arm | 束縛あり・観測ありで M が guard と本体の両方へ入る。guard_requires_match は M を外す負例 |
| match-boundary の9形 | true/false、整数、文字、文字列、整数範囲、文字範囲、空 List、Box(_) の各々について、本体/後続を新 plain と C_Match で型付け、事実を外す負例を対にする |
| match-boundary の actual_matched/excluded_fact | 各9形の実際の firstAlt の成否から、本番の健全性の補題を通して閉じた評価を得る。RootShape・WF/Sorted も具体に構成する |
| OrPattern | 1 又は3の腕が Or を読む正例と、Or を外す負例。二番目での照合成功と2での全選択肢の失敗から、Or と全否定の閉じた評価を得る |
| Unit と非対応種類 | Unit の事実の生成と評価。Decimal/Byte/Integer8 の事実はないこと |
| constrained_field_counterexample | Box(4) が Box(3) に失敗しても、根の否定の閉じた評価は false。excludedTests は空。constrained_field_not_entailed はその否定が導けないこと |
| CheckedAt.list_example / box_example | V_CheckedAt と scoped_forget を通る閉じた値から、実際の firstAlt の失敗と型付けだけを使い、空 List の後続の非空と Box(_) の後続の構成子の否定を得る。List の正規化を通る根の形も検査 |
| CheckedAt の負例 | checkedAt_not_inhabits と list_checkedAt_not_inhabits は維持した Inhabits の不足を示す。除外の新しい入力には使わない |
| 観測の喪失 | termBind? が失敗したら事実列を落とし、整数0の既定値へ事実を付けない |

Guard.Bg の値・型の置換に関する既存の仮定は例の宣言から構成した。標準組み込みの実表や全応答の保存の証明ではない。結果型の偽の側を not(self=true) で書けば、真枝は apart なしで閉じる。O054 が必須になるのは、self=false の宣言を真枝で読む場合と、変数の条件の偽枝を読む場合である。短絡の偽側を変数の条件から読む部分も後者に含める。

## レビュー所見ごとの処置と補助の契約

| 所見 | 処置 |
|---|---|
| 中1 | リテラル・範囲・空 List・wild/var 欄の構成子の除外・Or を追加。既存の根・非空・除外を含め、成功/失敗からの健全性を MatchFacts へ実装。正負例と実際の照合を追加。O056/O138 の主張を本書の一覧に限定した |
| 軽1 | apart の現行の導出不可と let_if_connect が L30 後の形であることを文書・境界に明記。O054 が必須となる二つの範囲を記した |
| 軽2 | rv-14bp-t3 の短絡の真側の代表を境界へ移した。偽側は O054/L30 へ残した |
| 軽3 | capture_plain_zero を任意の δ の capture_plain へ一般化。L20 の三つの入力を下表へ追加。事実の健全性の内部で欄数・At・slots から必要な性質を導いた |
| 軽4 | 束縛あり・観測あり、guard・観測ありの正例と負例を追加。欄を絞るパターンから根を除けない反例を追加 |
| 軽5・再軽1 | 一度累積を返す形に改めたが、任意の prior の内容が特定できず利用先もないため、再レビューに従って guard_context を削除した。必要な guard の取り出しは L20 で作る |

再中1では、除外の入力を Inhabits から根の形だけの RootShape へ替え、閉じた値の型付けからの構成を本番で閉じた。Inhabits と Exhaustive は変更していない。

採った補助の契約は、部分的な観測像 Option.bind termBind?、guard の結果型からの真の条件、後続へ guard の偽を渡さない規則、閉じた結果の行の注釈の保持である。今回の事実の健全性は AltsTy と RootShape、閉じた評価版では WF/Sorted を使う。RootShape は型の根で分岐し、base なら同じ種類の定数、list なら実際の要素列、data なら構成子の宣言と欄数又は At の宣言と欄数を保持する。refined は内側の型を読み、それ以外は True とする。要素や欄へ Inhabits を要求する案、Inhabits に checkedAt を足して Exhaustive の量化範囲を変える案は採らなかった。評価成功を入力とする案は採らなかった。構成子の除外は全欄の構文が wild/var の場合に限り、入れ子の唯一性や型による全域性の解析は採らなかった。これらの理由と捨てた案は signatures.md の決定の記録にある。

## 残り・送り先・計画からのずれ

O056・O138 の Lean の型付け規則について閉じた範囲は、if の真偽、上表の match の事実、guard の結果型からの真の条件、待機する K_Guard である。変数の条件の偽側・標準の比較結果の実表・全遷移の保存を含めて閉じたとはしない。

| 送り先 | 残る言明・依存 | 見込み時間 |
|---|---|---|
| L20 | 任意のパターンの束縛値の型付け・CaptureOk の延長を合成し、一般の E_MatchBody/E_MatchGuard を開始 StateTyE から保存する。capture_plain は任意の δ で使える | 未確定 |
| L20 入力1 | 開始状態から閉じた AltsTy と実際の値の閉じた HasTypeVQ を構成する合成。そこから根の形を作る rootShape_of_typing と除外の真を得る補題は今回閉じた。構成子の欄数は値の型付けと P_Con、At の欄数は shape.Declared、slots の妥当性は AltsTy が根拠 | 未確定 |
| L20 進行の入力 | Exhaustive は Inhabits を読むが、opaque に scoped_forget した checkedAt を Inhabits は覆わない。List の要素・構成子の欄にも同じ不足がある。HasTypeV から Inhabits への全域の含意は現行では偽であり、進行で型付き値全域へ接続する部分は未閉。今回の除外の健全性からはこの依存を外した | 未確定 |
| L20 入力2 | 閉じた観測での Pred.WF 0 と Sorted [] none を捕捉の置換から構成し、matched/excluded_paths_true へ接続する。関数の欄は部分的な観測 none と両立する | 未確定 |
| L20 入力3 | guarded の hgp が持つ hideConts の文脈の Annotation を、GuardBodyTy.mk の本体の文脈の Annotation へ変換する。rv-14bp-t5 は観測の像の sort だけを閉じた | 未確定 |
| L20/L40 | 全状態の保存と進行・canonical forms への合成 | 未確定 |
| L30 / O054 | 開いた Boolean の等号の合同・定数の相異。self=false の宣言を真枝で読む場合、let c の変数の条件の偽側、短絡の偽側。or_elim/not_intro は既に定義と健全性があり、未実装とは数えない | 未確定 |
| L40 | 標準比較組み込みの結果型、実表・応答の事実との接続。O056/O138 の標準ライブラリ側の残り | 未確定 |
| R10b/R50 | Rust でも上表と同じ形から事実を作ることを O138 の義務として照合する（取りまとめの判断） | 未確定 |
| L70 | 主定理と表層への合成、規範の切替 | 未確定 |
| L00b.14c | 今回の事実と観測像、RootShape、GuardBodyTy と Reference/snapshot の契約を照合する。今回起動していない | 未確定 |
| 独立レビュー・取りまとめ・受け入れ | 更新した署名・健全性・正負例・送り先と検査記録を確認する | 担当外のため未確定 |

続き2では PathTest が3から9場合になり、AltsTy/Inhabits から除外の真を導いた。再レビューで、Inhabits が型付けできる checkedAt の全部を覆わないことが判明した。続き3は取りまとめの指示に従い、Inhabits/Exhaustive の定義を保ち、根だけの補助入力へ替えた。主な定理の VQ/CQ の前提と結論は変えていない。全状態の保存へは進んでいない。

## ビルド・公理依存・入力の記録

| 検査 | 結果 |
|---|---|
| 既定の cd formal && lake build | 終了0。722ジョブ、0.703秒 |
| boundary.lean、Lean -M 12288 | 終了0。249宣言、2.456秒 |
| match-boundary.lean、Lean -M 12288 | 終了0。180宣言、1.874秒 |
| 完全署名、Lean -M 12288 | 終了0。171署名。VQ/CQ の10主要署名が前回停止時の出力と一致。0.678秒 |
| 全差分の公理依存、Lean -M 12288 | 終了0。141モジュール・14,785宣言。変更対象17モジュールの包含を台本で確認。12.638秒 |

許した三つ propext・Quot.sound・Classical.choice 以外の依存はなかった。sorryAx への依存もない。[verification.json](verification.json)、[axioms-summary.json](axioms-summary.json)、[primary-api-comparison.json](primary-api-comparison.json) が機械の記録である。verify.py は除外の3署名に RootShape があり Inhabits がないこと、閉じた型付けからの4入口、guard_context の削除も検査する。単独の Lean に -M 12288 を付け、既定 build は lakefile の同じ値を使う。変更した17ソースの禁止語句の検査も成功した。

100,000バイトを超える生の記録は <tmp> に置き、[large-records.md](large-records.md) に大きさと SHA-256 を残した。完全署名は宣言の境界で分割した読み取り用の出力も置いた。入力の文書・独立レビュー・rv-14bp-t1〜t8 のハッシュは reference-inputs.json、formal の最終のソース・設定・検査入力は source-inputs.json、書き込み対象は source-delta.json、成果物は files.json にある。files.json 自身は自己参照を避けてハッシュの対象外とした。verify.py --check-hashes は598件すべての一致を確認した。Inhabits と Exhaustive を含む Patterns.lean は、続き2の入力ハッシュと一致することも確認した。

途中の局所検査の構文・型の不一致は修正し、成功した最終入力を上表の入口で再検査した。失敗の出力は成功の根拠に用いていない。処理系・設計書・plan・独立レビュー報告・rv-* は変更していない。レビュー依頼は更新した。作業末の work は依頼のとおり取りまとめへ残した。Rust の検査と Rust/Lean の全比較は実行していない。L00b.14c に進んでいない。

## 外側の時間

今回の続き3は2026-11-01 05:46:09 JST に開始した。記録完了の時刻と今回の外側の時間は [outer-time.json](outer-time.json) にある。実装・局所検査・既定ビルド・公理依存・文書の記録を含み、能動時間と待ちを分離していない。独立レビュー・取りまとめ・設計者の受け入れの待ちは含まない。4時間の上限内である。前回までの時間の記録も同ファイルへ残した。最終の通知・応答は記録の終わりの後である。RSS は未取得（計画上の非採取）である。

## 作業末の work

取りまとめが実行した。基準は `467575dab0a8b524ba72a0c75e79a2963ef1ebaf`、コマンドは `scripts/check.sh --level work --base <基準>`、選ばれた単位は `formal_build` だけで、終了状態は 0、外側の時間は 73.00 秒である。実行の前に Refinement の生成物を消した。
