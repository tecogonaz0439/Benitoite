# L00b.14d: Lazy の代表の結果（レビュー処置後）

2026-11-01。**分類は「一部」である。** RV-L00b.14d の中1と軽1〜5を処置した。現在のセルを限定しない E_Update と、エラー・終了で更新枠を降ろす2規則の保存を本番へ閉じた。done のセルへの外側の書戻しは解消済みであり、L20 へ送る残件と2〜4時間の見込みを撤回した。残るのは任意の ret の view の closeVal の型保存と、捕捉を持つ force の呼出し元であり、どちらも L20 の全保存の既存の枠の内数として一度だけ数える。D19 を破る反例は得ていない。全状態の保存の完成は主張しない。

指定ブランチは `m014/l00b.14d`、B_WORK は `66c302eaec9d442d32073515772a0f036fd66762`。git による照合・切替・作成・コミットは行っていない。初回の共通依頼文と、今回のレビュー末尾・plan 先頭の承認を適用した。処理系・設計書・plan・既存のレビュー報告・rv-* は変更していない。レビュー依頼は今回の指定どおり更新した。work は取りまとめに残し、L00b.14e へは進んでいない。

## 変更の新旧と承認の範囲

| 対象 | 変更前 | 変更後 |
|---|---|---|
| ContTy.K_Update | 格納場所の lookup と末尾の型付け | 加えて Ty.Annotation P [] [] a を保持する |
| ContTy.update_inv | R=none、場所、包含、末尾を返す | 格納型の Annotation も返す |
| force_thunk_transition | lookup と末尾だけを K_Update へ渡す | thunk の本体の annotation から格納型の注釈を渡す |
| lazy_update_transition | m と現在のセルが thunk である hlcell を要求 | lazy_update_any_cell へ置き換え、m/hlcell を除く |
| lazy_update_const_transition | 同じセルの限定を持つ | セルの限定を除き、任意の捕捉の定数の view を扱う |
| ClosureTy.return_const | CoreAssumptions を要求する重複の補題 | 削除し、既存のより弱い ret_const を使う。専用の private isRet も削除 |
| エラー・終了での update の破棄 | 本番の代表と件数にない | lazy_update_pop_error/lazy_update_pop_exit を追加 |
| StoreShape.force | kind の追加条件なし | 変更なし。抽象の B で閉じた保存へ条件の追加が不要なので、揃えるためだけの強化は行わない |

K_Update の前提の追加は承認済みである。StateTyE が量化する ContTy は形式上強くなる。空のストアの開始には update 枠がなく、force が枠を積む時点では thunk の本体から追加の注釈が得られる。新しい公理、利用者の書ける形、提供範囲、精密な外部状態は変更していない。既存の主定理の結論も変更していない。この定義の変更は L00b 末の再提示に含め、01-12 の K-Update の写しは L00b.15 で反映する。

今回、既存の本番で変更したのは StateTyping・ReferenceStore・LazyStore・LazyPreservation の4ファイルである。初回からの差分全体は、集約 import 1行、新規3モジュール、既存 StateTyping/ReferenceStore の2モジュールである。[source-delta.json](source-delta.json) はこの6ファイルを含む。

## 閉じた定義と補題

本番は [LazyInversion.lean](../../../formal/Benitoite/Release/Refinement/LazyInversion.lean)・[LazyStore.lean](../../../formal/Benitoite/Release/Refinement/LazyStore.lean)・[LazyPreservation.lean](../../../formal/Benitoite/Release/Refinement/LazyPreservation.lean) に置く。公開宣言は定義1・補題19の20件であり、完全署名は [signatures.md](signatures.md) と [public-api.log](public-api.log) にある。

| 群 | 閉じたものと役割 |
|---|---|
| 共変な結果型の逆転 | Ty.lazyCore・lazyCore_norm、LeQ.lazyCore/lazyCore_right、HasTypeVQ.canonical_lazy。格納型から呼出しの結果型への LeQ を返し、Reference の不変な内容型の等号と区別する |
| セル | StoreOk.allocate_lazy/write_done。有限性・WF・Declared・領域・既存セルの移送を保つ。write_done は現在のセルの値を読まず、同じ格納契約に従う値へ上書きする |
| 更新枠 | 注釈を返す ContTy.update_inv と、注釈を保持する ContTy.store。StateTyping.end_normal の場合分けも追随した。.. で受ける他の逆転も既定ビルドで閉じ直した |
| Lazy 作成 | ClosureTy.lazy_body と StateTyE.lazy_transition。任意の捕捉の開始を逆転し、実際の本体と局所参照の解決を照合して格納する |
| force | BuiltinArgs.force と force_done_transition/force_thunk_transition。呼出し元は pure、格納された thunk の捕捉と継続末尾、最終の型と Eb は任意である |
| セルを限定しない書戻し | lazy_update_any_cell。開始の StateTyE と closeVal の一致から Step と保存を返す。K_Update の注釈で返り値を格納型へ合わせ、normal_return_tail は返り値の元の型で呼ぶ。格納型の Normal や Sorted の別入力を要求しない |
| 捕捉した定数の書戻し | lazy_update_const_transition。既存の ClosureTy.ret_const hA.substitutions を使い、任意の捕捉を閉じる。現在のセルの lookup は要求しない |
| 更新枠を降ろす保存 | lazy_update_pop_error/lazy_update_pop_exit。開始の error/exit の型付けだけを入力とし、実ストアとセルを変えずに枠を一つ降ろす |
| 観測 | lazy_no_sort/no_observation/no_observed_fact。Lazy を述語の項にせず、data の根と隣の不変な欄の観測を保つ |

補助の normal_return_tail は、K_Sub の下の非正規形の mark を返り値の正規形の型で構成し直す。書込み先の型 x は Annotation だけを持てばよく、Normal を追加していない。既存の ret_const の前提は SubstitutionAssumptions であり、CoreAssumptions から射影して使う。組み込みの表や主な補題の前提の追加は不要であった。

## 場合の数

| 対象 | 初回 | レビュー処置後 |
|---|---|---|
| Lazy の実際の遷移 | 4種類。書戻し先を thunk に限定 | E_Lazy・E_ForceDone・E_Force・E_Update・E_ErrPopUpdate・E_ExitPopUpdate の6種類。書戻し先の限定なし |
| 公開宣言 | 定義1・補題18の19件 | return_const を1件削除、更新枠を降ろす2件を追加した20件。update は any_cell へ改名 |
| LeQ・値・計算 | 13・29・24構成子 | 同じ。初回の LeQ=14 は誤数であり13が正しい |
| ContTy・Cell | 10・6構成子 | 同じ。K_Update の前提を一つ加えた |
| 相互三族・Step | 76・76 | 同じ。新しい遷移の構成子は追加しない |
| 元の let の実行 | 8遷移 | 同じ列を新しい判断で再確認した |
| 境界の公理依存 | 174宣言 | 186宣言 |

## 所見ごとの処置

| 所見 | 処置と証拠 |
|---|---|
| 中1 | 承認済みの K_Update の注釈を実装。update_inv と全利用先を追随し、hlcell/hS なしの lazy_update_any_cell を閉じた。boundary の UpdateCases.overwrite_done は実際に done(3) を done(4) へ上書きする入口を使う。rv-14d-t3 は変更せず本番の新署名で終了0 |
| 軽1 | return_const と private isRet を削除。定数の入口は既存の ret_const へ変更。公開署名の一覧から重複を除いた |
| 軽2 | E_ErrPopUpdate・E_ExitPopUpdate の Step と保存を本番に追加。UpdateCases.error_pop/exit_pop と pops_keep_thunk を境界で確認し、件数を6種類へ修正 |
| 軽3 | 次節で01-12と02-08を引き、抽象状態の量化とソースからの到達を区別した。VM の「評価の途中」、同じタスクの不具合、別タスクの待機との対応を L30 の入力へ追加 |
| 軽4 | .force の kind 条件は足さない。force は新しい組み込み呼出しを合成せず、既存の型付き入力と表の条件で抽象の B の定理が閉じるためである。signatures の採否に明記 |
| 軽5 | done への書戻しの残件と2〜4時間を削除。任意の ret と捕捉を持つ force の二つは、L20 の全保存の既存枠で一度だけ数え、個別の追加時間を削除 |

## 境界で確かめたもの

[boundary.lean](boundary.lean) の正例は結論を仮定しない。追加の UpdateCases は、今回変えた入口を使う。

| 入口 | 内容 |
|---|---|
| lazy_covariant・reference_invariant | Lazy の結果型を弱めて渡す正例と、Reference の不変性の負例。後者は任意の Γ/Φ を量化する |
| lazy_pair・force_pair・update_pair・force_again_pair | 格納契約は Integer{self < 8}、最初の force の型引数は Integer、後の force は元の篩。書戻しは新しい any_cell の入口を使う |
| contract_removed・force_without_contract・done_rejects_nine | Lazy[Integer] だけを持つ場所を篩の結果型で force できず、違反する9を篩の done として格納できない |
| program_typed・program_start・execution | let t = lazy(...); force(t); force(t) のソースの型付け、開始状態と8個の実際の Step |
| Snapshot.allocated・body_needs_fact | 空でない捕捉と x<8 の Φ から Lazy を作る。Φ を除くと同じ本体は型付かない |
| Snapshot.set_pair・captured_after_set・force_pair・update_pair・later_pair | 待機する thunk のストアにある参照を9へ set した後も、捕捉した3と事実を使って force・定数の書戻し・後の force を行う。定数の書戻しも hlcell を持たない新しい署名を使う |
| UpdateCases.overwrite_done | 既に done(3) であるセルに4を返す開始を型付け、any_cell から実際の上書きと保存を得る |
| UpdateCases.old_and_new_contracts | 上書き後の StoreOk、先に保持した3の篩の型と閉じた事実、新しく保存された4を同時に確認する。事実が実ストアに依存しないことを確かめる |
| UpdateCases.error_pop・exit_pop・pops_keep_thunk | 実際の2遷移を閉じ、セルが thunk のままであることを確認する |
| Reentry.first・second・same_thunk | 型付きの抽象状態で同じ thunk に入り、ストアを変えず update を二つ積む。ソースからの到達を主張しない |
| LazyField と lazy_var_no_sort | Lazy 欄を欠く同じ型付き data から、部分的な像、RootShape、実際の firstAlt と根の構成子の事実を得る。欠落欄を整数で埋めず、述語の欄の宣言は拒否する |

元の let の全途中状態の保存を合成したとはしない。特に s4・s7 の force は捕捉を持つ呼出し元で、現在の pure の force 代表の外にある。Snapshot も、各開始を具体に型付けて実際の遷移の入口を使うものであり、全保存の主定理による合成ではない。

## 再入・到達不能・VM の対応

[01-12「ストア：可変のセルと明示遅延」](../../design/01-spec/01-12-core-calculus.md)は、ソースから始まる thunk の実行中に同じ場所を force することはないと定める。作成時に本体がその場所を持たず、純粋な本体が参照セル経由で取り出す経路もないことを理由としている。[02-08「明示遅延」](../../design/02-impl/02-08-vm.md#明示遅延)は、同じタスクの再入が起きたときは処理系の不具合とする。

今回の型付き抽象状態の補題は、ソースからの到達可能性を前提にしない。その量化には、Reentry の循環セルや、既に done となった場所に外側の update が戻る形も含まれる。これらの例は到達不能の記述と矛盾せず、ソースの受理範囲を広げる主張ではない。

VM は「評価の途中」に評価するタスクと待つタスクを持ち、別のタスクの FORCE を待たせる。形式の thunk/done はこの状態と待機を直接表さない。L30 は、01-12 の到達不能、同じタスクの不具合、別タスクの待機、評価成功時の done と待機解除、取消・終了時の「評価の前」への戻し方を同じ入力群で照合する。今回はVMを変更・検査していない。

## 残りと送り先

下表の L20 の二項目は、新しい追加枠ではなく、計画の全ストア・閉包・継続の保存の枠で一度だけ数える。今回閉じた done への書戻しを残件へ戻さず、独立した2〜4時間や、二項目それぞれの1〜3時間を加算しない。

| 送り先 | 残る内容と扱い | 追加の見込み時間 |
|---|---|---|
| L20 | 任意の ret の view の closeVal の型保存。E_Return・E_Mark・E_HRet・E_Drop と同じ補題群として一度だけ扱う | 追加計上なし。既存枠の内数 |
| L20 | 捕捉を持つ force の呼出し元。特に s4/s7 は Reference の既存残件と同じ閉じ方の補題群に統合する | 追加計上なし。既存枠の内数 |
| L20/L40 | 全状態の保存・進行への合成 | 不明（既存の全保存・進行の枠） |
| L40 | canonical_lazy と StoreOk の領域条件から force のセルが thunk/done であることを導いて進行へつなぐ | 不明（既存の割当て） |
| L30 | 実表・Rust の結果型の共変性と篩の格納・観測。加えて前節の VM の「評価の途中」と到達不能の対応 | 不明（既存の照合の枠） |
| L00b.15／取りまとめ | K_Update の注釈を01-12へ写し、StateTyE に触れる承認済み変更として L00b 末に再提示する | 不明（担当外） |
| 独立レビュー・取りまとめ・受け入れ | 定義・言明・仮定の再確認、work、取り込みと受け入れ | 不明（担当外） |

O051 の Lazy の6種類の代表は閉じた。O051 全体と全状態の保存は完了にしない。O046 は捕捉の事実を set 後の force・書戻し・後の読出しへ接続した。O160 の「一部」の分類と残る一般化は取りまとめが再提示する。

L00b.14e への申し送り: K_Update の入力は lookup・Annotation・末尾の3つである。update_inv は R=none と x/R'、lookup・LeQ・Annotation・末尾を返す。CellOk.store と ContTy.store は新しい形でビルド済みである。done への書戻しと error/exit の破棄は今回解消済みなので、L00b.14e や L20 に未処理の修正として送らない。全保存に共通する二つの一般化だけを区別して使う。

## 計画との差と補助の判断

初回は K_Update に注釈がないため done の書戻しを残件にした。レビューが示した不足は、格納型の Sorted を更新枠で保持することで解消できた。今回、承認に従って定義を強め、初回の残件と見込みを撤回した。これは新しい公理による穴埋めではない。force の表の条件は強めず、定数の逆転は既存の補題を再利用した。その他の採否は [signatures.md](signatures.md) に記した。

## ビルド・公理依存・入力の照合

[verify.py](verify.py) を実行した。現在の入力の結果は [verification.json](verification.json)、公理依存の集計は [axioms-summary.json](axioms-summary.json) にある。既定ビルドの設定と単独の Lean の両方で -M 12288 を適用した。

| 検査 | 終了 | 件数 | 外側の時間 | 記録 |
|---|---:|---|---:|---|
| build | 0 | 既定728ジョブ | 0.811秒 | [build.log](build.log) |
| boundary | 0 | 186宣言 | 1.334秒 | [boundary.log](boundary.log) |
| public-api | 0 | 公開20宣言と K_Update の署名 | 0.311秒 | [public-api.log](public-api.log) |
| review-t3 | 0 | 指定された補助入力、1宣言 | 0.292秒 | [review-t3.log](review-t3.log) |
| axioms | 0 | 147モジュール・15,277宣言 | 13.132秒 | [集計](axioms-summary.json)・[生出力の大きさとハッシュ](large-records.md) |

現在の全差分と境界について、propext・Quot.sound・Classical.choice 以外の公理依存も sorryAx の依存もない。本番の変更に sorry/admit/axiom の追加はない。全宣言の監査には新規3モジュールに加え、変更した StateTyping・ReferenceStore と集約 import を含めた。既存のモデルの仮定充足と旧 Release の主定理も監査入力に残した。

既定ビルドには既存の lint とリンカの環境の警告があるが、終了は0である。今回の局所ビルドと境界の確認、一括の確認で検査の失敗はなかった。初回の作業時の2件の検査入力の失敗の履歴は verification-first/second.json と対応するログに残し、今回の成功の根拠には使わない。

[source-delta.json](source-delta.json) は初回からの本番の6ファイル、[source-inputs.json](source-inputs.json) は関係する全入力と設定、[boundary-inputs.json](boundary-inputs.json) は現在の境界・署名出力・台本のハッシュである。[resume-before.json](resume-before.json) は再開前の本番4ファイルのハッシュと開始時刻を持つ。末尾が initial の JSON は再開前の検査と入力の履歴であり、現在の証拠と区別する。

[protected-inputs.json](protected-inputs.json) は rv-14d-t1〜t3、rv-14d-k-update.patch、RV-L00b.14d.md の5本を記録する。verify.py が作業前後のハッシュ一致を確認した。t1/t2 とパッチは旧署名の検討入力として参照し、変更せずに保存した。新しい本番の any_cell を表示する t3 は変更せず実行した。大きな生出力は改造に置かず、初回分と今回分の大きさ・SHA-256 を [large-records.md](large-records.md) に区別して残した。

再開の外側の時間は、2026-10-31 22:49:53 UTC から本書作成時点 2026-10-31 22:58:13 UTC まで約8.3分である。読み取り・修正・局所検査・一括確認・文書化を含み、能動時間と待ちを分離していない。今回の上限4時間の範囲内である。初回の文書作成時点の外側の時間は約23分であり、再開分とは分ける。最大常駐量は未取得（計画上の非採取）。Rust の検査、差分実行、性能測定、別機、LLM の追加起動、work は実行していない。

## 作業末の work

取りまとめが実行した。基準は `66c302eaec9d442d32073515772a0f036fd66762`、コマンドは `scripts/check.sh --level work --base <基準>`、選ばれた単位は `formal_build` だけで、終了状態は 0、外側の時間は 81.60 秒である。実行の前に Refinement の生成物を消した。取りまとめはレビューのパッチの絶対パスを `<repo>` に置き換え、`protected-inputs.json` の大きさとハッシュを直した。
