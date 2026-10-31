# RV-L00b.14b-paths: 再レビュー依頼

2026-11-01。分類は「閉じた（結果に列挙した規則と代表の言明が閉じた）」である。独立レビューの中1・軽1〜5と、再レビューの再中1・再軽1に対応した。B_WORK は `467575dab0a8b524ba72a0c75e79a2963ef1ebaf`、指定ブランチは `m014/l00b.14b-paths`。git の操作は行っていない。独立レビュー本文と補助の rv-14bp-t1〜t8 は変更していない。

[結果と所見ごとの処置](../l00b.14b-paths/results.md)、[完全署名と決定](../l00b.14b-paths/signatures.md)、[公開署名の出力1](../l00b.14b-paths/public-api-1.log)・[2](../l00b.14b-paths/public-api-2.log) を先に確認してほしい。VQ/CQ の5操作ずつの主な10署名は前回停止時の出力と一致した。

## 今回の確認点

1. **再中1・根の形:** excluded_true/excluded_evalClosed_true/excluded_paths_true の入力を Inhabits から RootShape へ替えた。定数の種類、List の根、構成子の宣言と欄数、At の宣言と欄数だけを読み、要素や欄の内部へ Inhabits を要求していないか。
2. **再中1・型付けからの構成:** rootShape_of_typing は HasTypeVQ P B Ψ Q C [] Φ v a だけから RootShape を返す。VQ の29場合と部分型・正規化・篩を扱い、V_CheckedAt → scoped_forget の経路を落としていないか。新たな Builtins の仮定、評価成功、本体や到達の型付けは要求しない。
3. **再中1・除外への入口:** excluded_true_of_typing/excluded_evalClosed_true_of_typing/excluded_paths_true_of_typing は閉じた型付けから根の形を構成する。AltsTy、実際の firstAlt の失敗、観測、閉じた WF/Sorted の契約は維持した。リテラル・範囲・空 List・構成子の否定の意味は変えていない。
4. **再中1・境界:** match-boundary の CheckedAt.list_example/box_example は CheckedWitness と opaque の注釈から閉じた List/構成子を型付ける。実際の firstAlt の失敗と合わせ、[] の後続の非空、Box(_) の後続の構成子の否定を得る。List の正規化を通る root の例もある。除外の評価の結論を仮定していないか。
5. **再中1・進行の残り:** Inhabits/Exhaustive の定義は変更していない。checkedAt_not_inhabits/list_checkedAt_not_inhabits の負例を境界に残した。Exhaustive を型付き値全域の進行へ接続する側は L20 の未閉の入力であり、現行で偽になる HasTypeV → Inhabits 全域の含意を実装済みとしていないか。
6. **再軽1:** guard_context を削除した。必要な guard の取り出しは L20 で開始状態と捕捉に合う形に作ると決定した。利用先はない。

前回追加した事実の種類、9形×本体/後続の18組の正負例、Or・短絡・束縛ありと観測あり・guard と観測ありの境界は維持した。既存の actual_excluded_fact も RootShape の入力へ切り替えた。apart の導出不可、O054 の必須範囲も維持した。

## 維持した契約と保存の範囲

HasTypeArmsQ 自体が Option Term の添字を持ち、C_Match と観測を共有する。値の置換は Option.bind termBind? を使う。観測が失われたときに termBind の既定値へ事実を付けない。弱化と if_legacy/plain_legacy/guarded_legacy/match_legacy で旧導出を読める。

K_Guard は条件前の CaptureOk と開いた本体の導出を GuardBodyTy に保持し、閉じた本体の ClosureTy を評価前に要求しない。if_true/false と guard_true/false は開始 StateTyE から C_Sub/C_Normal/C_Eff と K_Sub を逆転する。match_start/skip と、束縛数0・評価の補助入力を持つ match_body_zero も維持した。到達する State の欄に経路条件は追加していない。

一般の束縛の保存・開始状態から閉じた値や腕の型付けと WF/Sorted を構成する合成・hideConts の Annotation の変換・Exhaustive/Inhabits の checkedAt に関する進行側の不足は L20、O054 は L30、標準比較の実表との接続は L40 へ残す。Rust も同じ形から事実を作ることは R10b/R50 の O138 の義務である。O056/O138 の「Lean の型付け規則が閉じた」という範囲は、結果の事実の一覧に限定した。

## 検査

既定 lake build は722ジョブで終了0。boundary は249宣言、match-boundary は180宣言、合計429宣言である。公理依存は141モジュール・14,785宣言を再実行し、変更対象17モジュールの包含を台本で確かめた。propext・Quot.sound・Classical.choice 以外、sorryAx を含む依存はない。Lean の単独プロセスにも -M 12288 を付けた。公開171署名と主な10署名の一致を検査した。

相互三族14族76場合、VQ29・CQ24・Step76・ContTy10は維持した。PathTest は3から9、PathLiteral は5、GuardBodyTy は1場合である。生の大きな記録は <tmp> に置き、大きさ・SHA-256 を large-records.md に記した。verify.py --check-hashes で全入力と成果物を照合する。

新しい公理、主な VQ/CQ の前提・結論の変更、提供範囲の変更、利用者の記述の制限、精密な外部状態の追加はない。処理系・設計書・plan・独立レビュー報告・rv-* は変更していない。work は取りまとめへ残して実行せず、L00b.14c は起動していない。

## 書き込み対象と新規ファイルの全一覧

[source-delta.json](../l00b.14b-paths/source-delta.json) は17ソース、[files.json](../l00b.14b-paths/files.json) は文書・台本・記録を含む成果物のハッシュの一覧である。git の差分を取得した記録ではない。以下は前回の停止までに追加したものも含む本作業全体の新規ファイルである。本番の MatchFacts と境界の match-boundary は続き2で追加した。今回の続き3で新たに作ったファイルはなく、これらを含む既存の入力・文書・記録を更新した。読み取り専用の独立レビューの補助入力 rv-* は本作業の新規ファイルに数えない。

<!-- generated-file-list -->
- `formal/Benitoite/Release/Refinement/PathConditions.lean`
- `formal/Benitoite/Release/Refinement/PathFacts.lean`
- `formal/Benitoite/Release/Refinement/ClosedCapture.lean`
- `formal/Benitoite/Release/Refinement/MatchPaths.lean`
- `formal/Benitoite/Release/Refinement/MatchFacts.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14b-paths/axioms-summary.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14b-paths/axioms.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14b-paths/axioms.log`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14b-paths/boundary.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14b-paths/boundary.log`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14b-paths/build.log`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14b-paths/case-inventory.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14b-paths/files.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14b-paths/forbidden-tokens.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14b-paths/large-records.md`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14b-paths/match-boundary.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14b-paths/match-boundary.log`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14b-paths/outer-time.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14b-paths/primary-api-baseline.log`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14b-paths/primary-api-comparison.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14b-paths/public-api-1.log`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14b-paths/public-api-2.log`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14b-paths/public-api.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14b-paths/public-api.log`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14b-paths/public-names.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14b-paths/reference-inputs.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14b-paths/results.md`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14b-paths/signatures.md`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14b-paths/source-delta.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14b-paths/source-inputs.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14b-paths/verification.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14b-paths/verify.py`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/reviews/RV-L00b.14b-paths-request.md`
