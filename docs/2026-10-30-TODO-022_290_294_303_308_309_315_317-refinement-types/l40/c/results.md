# L40 群 C の実装結果

2026-11-03、再開1。**L40.12〜.15の担当分を完了した。** canonical formsと全開始の供給側を実装し、B15の22行を一行ずつ閉じた。76葉の開始・既存の保存葉の行先へ入力を接続した。全σ・応答の存在、進行/保存等の主な十言明、独立レビュー・受け入れは完了に含めない。

基準は `4d27a9306e76b51f0686d04338a574053755dd4d`、指定ブランチは `m014/l40.c`。切替・作成・コミットその他のgit操作は行っていない。対象と禁止事項は初回の依頼のままであり、再開1で承認されたE_Lamの前提と実行関数の対応だけを変更した。planの先頭の判断と [独立調査](../../reviews/RV-L40.c-obstruction.md)を読んで、その推奨案を採った。

[初回の結果](initial-results.md)は変更前の停止・時刻・検査の履歴である。同記録の「未完」「no_step」「最終」は初回時点を指す。現在のB15は [start-inputs.md](start-inputs.md)、76葉は [leaves.md](leaves.md)、担当の義務64行は [obligations.md](obligations.md)を正とする。初回の監査・入力一覧・宣言一覧は `initial-` を付けて保持した。

## 再開1：承認された適用規則と全開始の供給

開始時刻（UTC）: 2026-11-03T10:28:04.223479+00:00。E_Lamの前提と実行関数の対応だけを承認範囲として変更し、L40.15を再開する。

| 単位 | 開始（UTC） | 終了 | 判定 |
|---|---|---|---|
| 適用規則と保存の葉の追随 | 2026-11-03T10:28:04.223537+00:00 | 2026-11-03T10:38:15.710872+00:00 | 既定ビルド終了0。適用規則・保存・具体例・実行関数の一致 |
| L40.15の全開始の供給 | 2026-11-03T10:38:15.710934+00:00 | 2026-11-03T10:54:36.082944+00:00 | 供給側完了。全22行・16計算/4状態・76葉の読者と既定ビルド終了0 |

### 規則・実行関数・保存

`Step.E_Lam` は次の三前提で同じ本体の適用先へ進む。構成子の追加は0、全76葉の数は同じである。

```lean
q.view = .app f ws
closeVal Capture.empty f = .closure signature body
ws.length = signature.arity
```

到達先は `run (body.apply ws) (markPush k) μ`、事象はnoneである。`step` のclosure・lam・dependentLamの三枝もこの空捕捉による閉じ方を使う。`step_lambda` は同じ前提から、実行関数の計算結果とStepを同時に返す。closureを空捕捉で閉じる結果は同じclosureなので、従来のclosureの実行結果・到達先は変わらない。この場合も既定ビルドの適用例で確認した。

E_Lamを名指しするSemantics・CapturedFacts・ClosureStateLeaves・DependentBetaを追随した。新しい `HasTypeVQ.close_empty_typed` は既存の `close_value_typed`・`CaptureOk.empty` と閉じた注釈を使う。`StateTyE.lambda_beta_all` は同じ元状態から広げた規則の行先の型付けを構成する。従来の `dependent_beta_all` の署名は維持し、その読者にした。`LeafInputs.lambda_inputs` は、実際の型付き呼出しから元の実引数列とRuntimeShapeを逆転し、個数の一致も導く。通常・依存lambdaと既存closureの三つの具体の読者を置いた。

StateTy・StateTyE・型付け・CoreAssumptionsと主な十言明の言明は変更0。旧Releaseの `step_sound` と証明も変更0である。Refinement全体のstep_soundはL70の未完の主定理なので今回新たに閉じず、変更した実行関数の枝の健全性はstep_lambdaが示す。これ以外のStep規則・型付け規則の変更は0である。群Aで固定し群Bで改めたF01〜F03等の後続署名の変更、前提削除の差は0。

### 反例の解消とδの経路

新しい既定importの [LambdaApplicationExamples](../../../../formal/Benitoite/Release/Refinement/LambdaApplicationExamples.lean)に次を置いた。

| 入口・読者 | 核で確かめた範囲 |
|---|---|
| captured_and_direct | obstructionと同じ型付き捕捉変数から読む生lambdaと、直接書いた同じlambdaの閉じたclosureの適用が、同じ到達先へStepを持つ |
| executableの適用例 | 同じ反例の状態でstepもそのStepと同じ結果を返す |
| StateTyと進行の対照 | 任意のP・B、Validなσで同じStateTyを持ち、普遍的な「Stepがない」という否定が成り立たない |
| two_steps | 閉じた型付きの開始で、捕捉内に生lambdaを持つclosureを適用すると一歩で旧反例相当の状態に至り、広げたE_Lamでもう一歩進む |
| delta_return_path | δが同じclosureを返すという実応答の等号とpure種別を前提に、E_Prim→E_Return→E_Lam→E_Lamの四歩を構成する。最後の生lambdaも進む |
| lambda_beta_allの読者 | 同じ実開始・型付き捕捉・既存CoreAssumptionsから、反例の生lambdaの到達先のStateTyEも構成する |

[obstruction.lean](obstruction.lean)は変更せず残した。旧規則で証明したno_stepは、新規則では成り立たない。ファイル全体を現在の規則で再検査したとの主張はしない。新しい同状態のStepとno_stepの否定は既定ビルドで検査する。旧入力のhashは監査要約のhistorical_inputsに保持する。

具体のδの表・CoreAssumptionsの全欄の充足例は今回作っていない。delta_return_pathは同じ実応答の等号から先の経路の証明である。現行CoreAssumptionsの正常応答は型・Ground・Adequate等を要求するが、捕捉内の生lambdaを構文だけで排除する条件はない。二歩例のnestedには型付けを構成しており、旧停止を「δでは起こらない」とする根拠はない。この表の充足と存在はL60の実表の担当へ残す。

### 全開始・22行・76葉

[ComputationInputs](../../../../formal/Benitoite/Release/Refinement/ComputationInputs.lean)は下書きの12逆転を本番へ置き、既存ret/let/app/if/escapeと合わせてCompの全16形を `HasTypeCQ.inputs` の読者へ接続した。handleの通常/Fail、resumeの変数/場所×生/正規形を選言のまま保つ。matchの照合値・obs=None/someの条件とsort・HasTypeArmsQ・Exhaustiveを落とさない。

[LeafInputs](../../../../formal/Benitoite/Release/Refinement/LeafInputs.lean)は宣言/実装の同じ元本体、捕捉と局所参照、全四状態からの入力を返す。関数七形の各contract_inputsは群Bのprimitive_contract_inputsと同様に、同じ実開始から元の署名へ実引数を戻し、元注釈・結果LeQ・効果Coversを返す。元捕捉のCaptureWFから完全なCtx.WFを推測せず、CaptureContextRegularを保持したまま、実呼出しを閉じた空Γへ移す。

B15-Def・Impl・Capture、Fn-fnRef/op/lam/dependentLam/closure/raise/externalRef、Ret・Let・If・Match・Lazy・Escape・Use・Handle・Resume・Guard・Meth・BuilderLetの**全22行の供給側を閉じた**。未完のB15行を後段へ渡すものは0。B15-Capture/Fn-lamの初回停止は、承認された規則で解消した。各行の保持した証拠と後段の担当はstart-inputsの同じ一行に示す。

76葉への供給はleavesの76行を正とする。既存の60 Step葉と16到達葉を作り直さず、各保存葉の同じ開始・行先へ入力の読者を置いた。StoreReplyInputsの分配は既存store_replyの全構成子を継承し、共通の読者で開始・行先を受ける。ifは元の型付き開始からBooleanの実形を導く。match/guardの選択本体、letの返却先、handlerの通常/失敗節、Lazyのthunk、resume/専用builderの本体にも同じ接続を置いた。guard先頭の元操作列には空行Coversを供給し、その効果の原子が存在しないという読者も置いた。一般の操作の効果との照合と標準factsはL40.20、escapeの標準本体は.35である。

全有効σ・所属・対象はL50、δ/IO/外部/解放の実応答と実表の存在はL60、全開始の分配と進行・保存・step_sound等の主定理はL70へ残す。これらをB15の未完行として置き換えたり、主定理の仮定へ追加したりしていない。旧同種残件のlocと計算9目的の供給側を閉じ、N_V=0/N_C=0/N_g=0とする。

L40.15の見込み50〜100分は22行を含む枠である。単位の表は開始/終了の時点で記録した外側の時刻であり、読取り・待ち・検査を精密に分離した能動時間ではない。今回の短い外側時間をそのまま未経験群へ外挿しない。群の2時間15分〜4時間25分、上限8時間50分と段の15〜35時間は変更しない。c_V/c_CとRSSは未取得のままである。

### canonical forms・写し・処理系との接続

L40.12〜.14は初回の実装を維持した。scalarの各tag・Boolean・List・data、関数八構文、Map/Set/Bytes/Dict、保持値三形、外部参照/handle、PathBases/ScopePattern、場所のref/lazy二規則、val/thunk/done/cont/used/builderの六セルを扱う。空篩はInhabitsから排除し、atErrorはResultShape.DeclaredとerrorTypeの芯を返す専用逆転へ分ける。構文は型付けの導出から得て、意味だけから推測しない。ContTyの保存した全七枠の証拠をそのまま返し、型付き捕捉を全位置の完全な文脈形成へ強めない。

[01-12](../../../design/01-spec/01-12-core-calculus.md)のLeanの写しにE_Lamの三前提、実行関数と入力の追加を反映し、[07-04](../../../design/07-quality/07-04-formal-semantics.md)の保存の範囲とモジュール表を同じ変更で更新した。規範のE-Lam（λへの適用）は変更0。新しい術語・利用者の構文の制限・精密な外部状態は加えていない。

`scripts/check-formal.sh` は読取りだけを行い、実行していない。同スクリプトが比較に使うdesugarDiff・builtinCheck・coverageDiff・coverageProgramDiff・surfaceCheck・surfaceCheckAll・intervalDiffは、いずれもRefinementを直接にも推移的にもimportしない。入口のimportはBenitoite.Exchange.*・Benitoite.Interval.Exchange・Benitoite.Release.CoverageShow・SurfaceCheck.Validation等であり、Exchange・Interval・Surface配下にもRefinementへの参照はない。今回のRefinementの変更を同スクリプトで検査する箇所は先頭の既定lake buildであり、再開1の既定ビルドとworkで通っている。Rustの実行時Value/FieldsKind（`crates/benitoite/src/runtime/heap/value.rs`）は関数をclosureで表し、生のlambdaの構文値を持たない。全比較の実行・引用と接続の検査はplanのF-REG（L70末）・F-CONN（R50末）・F-CLOSE（K10）・F-FINAL（V10）が担う。Refinementの進行・保存をRustの実行へ対応付ける読者を加える際は、生lambdaを頭に持つE_Lamも接続の入力に含める。ここでの読取り評価を、全比較の成功やRustとの一般の対応の証拠にはしない。

### 宣言・検査・完了条件

新しい既定モジュールはCanonicalValues・CanonicalCells・ComputationInputs・LeafInputs・LambdaApplicationExamplesの5本で、環境の宣言は合計267件。手書きの名前付き公開60、private40、その他の生成宣言167である。さらに既存モジュールへ公開3入口（close_empty_typed・lambda_beta_all・step_lambda）を追加した。匿名の具体例は新5モジュール107件とStepの1件であり、環境に保持される宣言の件数とは別に数える。全て既定ビルドの中で検査し、名前付き公開入口には同ビルド内の読者を置く。全名と件数は [declarations.json](declarations.json)をverify.pyで再生成する。

公理監査は [audit.py](audit.py)・[axioms.lean](axioms.lean)で全既定importのprivate/生成宣言を環境から列挙し、対象一覧と#print axiomsの一対一一致を照合した。変更前の反例と下書きは履歴のhashを保持し、既に偽になったno_stepを現行環境の定理として混ぜない。初回の監査はinitial-audit-summary、現行の監査は [audit-summary.json](audit-summary.json)である。

| 条件 | 判定 |
|---|---|
| L40.12 scalar/List/data、空篩、atError | 担当分完了。専用の逆転と元導出の読者 |
| L40.13 保持値・外部・PathBases等 | 担当分完了。同じ要求/endpoint/名目ID/snapshot |
| L40.14 場所・六セル・七枠 | 担当分完了。同じσ/Ψ、refの正規形等号とLazyのLeQを区別 |
| L40.15 全16計算/4状態とB15全22行 | 供給側完了。未完B15の後段送り0 |
| 76葉の開始・選択後の入力 | 供給側完了。全76行を一行ずつ照合。応答と主定理は既存後段 |
| 広げたE_Lamとstep・保存・旧closure | 既定ビルドと具体例で確認。構成子追加0 |
| 反例の保存・型付き二歩・δ経路 | 旧ファイルを保持。二歩は具体証明、δは同じ実応答の等号を前提とする四歩 |
| 主な十言明・StateTy/型付け/CoreAssumptions | 変更0。主定理の閉鎖0 |
| 固定署名 | 変更0、使わない前提の削除の差0 |
| sorry/新公理/既定importの除外/旧Release/Rust変更 | いずれも0。監査とverifyで照合 |
| plan/detail/README/レビュー/群A・Bの記録 | 担当による変更0。plan・detailの注は取りまとめによる変更 |
| 01-12・07-04の同時反映 | 完了。規範のE-Lamは変更0 |
| 単位の開始・終了の時刻 | 初回と再開1を別に各時点で記録 |
| 記録各100KB以下・全新モジュールの既定import | verify.pyで全入力・22行/76葉/64義務も照合 |
| check-formal.sh | 指示どおり実行0。上記読取り評価だけ |
| 独立レビュー・受け入れ | 再開1完了時点では未実施。再開2でRV-L40.cの判定「可」と所見を確認し処置する。設計者の受け入れは別途 |

計画からの差は、初回の反例停止と、今回承認されたE_Lamの前提変更・対応するstep/保存/具体例の追加である。ほかの規則や保証の範囲の変更はない。取りまとめには、全開始入力の十分性と76葉の対応、E_Lamの閉じ方と保存、空行guard/δ経路の証明の範囲を独立レビューし、後段のL40.20/.35・L50/L60/L70との境界を確認することを求める。担当から取りまとめへ追加の仕様判断・規則変更の承認を求める未処置点はない。E_Lamの前提の変更は、planの「計画の変更と取りまとめへの確認点」の先頭の項のとおり、設計者の見直しの対象として残る。

検査の本体終了・外側秒・開始/終了・生出力のbytes/SHA-256は [checks.json](checks.json)を正とする。生出力は `<tmp>/l40-c-resume1/` に置く。途中の相互帰納の証明と暗黙引数等の局所失敗は修正し、最終の局所Lean・既定ビルド・全監査で終了0を確認した。固定Leanはleanprover/lean4:v4.34.1、単独検査は `lake env lean -M 12288` である。

| 最終の検査 | 終了 | 外側秒 | 確認した中身 |
|---|---:|---:|---|
| r1-lambda-inputs-checked | 0 | 0.857 | 元の型付き列からlambdaの個数を導く三構文の読者を含むLeafInputsの単独Lean |
| r1-build-final | 0 | 1.791 | formal/から対象指定なしのlake build。新5モジュールを含む966ジョブ |
| r1-axioms | 0 | 38.744 | 全既定705モジュール、68,912宣言の公理依存と全対象名の一対一照合 |
| r1-work-selection | 0 | 0.113 | B_WORKの差分からspec_tally/spec_examples/formal_buildを選択確認 |
| r1-work | 0 | 3.732 | 指定のworkを再開1の作業末に一度。仕様対応の自己検査/集計、仕様例7件（失敗0・ignore0）、既定全Leanとsorry拒否 |

workに--onlyは付けていない。Rustのソース・テストは変更していないため、Rust全lib/clippy等の追加実行はしていない。公理依存はpropext・Quot.sound・Classical.choiceの部分集合だけで、新公理/sorryAx/ofReduceBool/監査errorは0。再開1の最終の既定ビルド・公理監査・workの後から再開2の開始まで、本番のLeanソースは変更していない。基準4d27a9306e76b51f0686d04338a574053755dd4dからの既存Leanファイルの変更は、Benitoite.leanとSemantics/Step/CapturedFacts/ClosureStateLeaves/DependentBeta/ExternalStateLeavesの7本である。初回の終わりに記録したLean713ファイルのhashからは、このうちExternalStateLeavesを除く6本が変わった。型付け・StateTy・CoreAssumptions・旧Releaseは同じであった。

| 生出力 | bytes | SHA-256 |
|---|---:|---|
| 公理依存 | 12,070,243 | `57e3cd08e03ad3ad5805526df22cf46e6d3e65debaf28eefeb908fbcaf0c51d0` |
| 全対象名の一覧 | 4,185,315 | `a450b8420db1804676c38ba3ed29df3976279acfa3921328d8a92b1f39b89b47` |
| 監査入力 | 3,279 | `ce1a2bced83cd8f501b91df9f70719cdd5f851e55dad8644e141b13110153559` |
| 既定ビルド | 43,382 | `f575d60dcfb647782ade24180f305c169ec01ba616a4e35e19bbe45976d062db` |
| work | 5,847 | `0287bac3132a0e090697e35d3822cce1bd88118dd3aae8a00a5c7cebe038cd4c` |

最終の入力・記録・100KB上限・全新モジュールの既定import・22/76/64行の照合はverify.pyで再生成する。初回の報告前と同様、この報告前にも担当の完了条件を一行ずつ照合した。独立レビューと設計者の受け入れは別途である。

## 再開2：RV-L40.cの軽1〜4・情報1〜4

開始（UTC）: 2026-11-03T11:13:18.020393+00:00。レビュー所見の読取りと処置を開始した。

| 単位 | 開始（UTC） | 終了（UTC） | 外側秒 | 判定 |
|---|---|---|---:|---|
| 軽1〜4・情報1〜4の処置と検査 | 2026-11-03T11:13:18.020444+00:00 | 2026-11-03T11:17:21.486204+00:00 | 243.466 | 処置済み。既定ビルド・work・verify終了0 |

[RV-L40.c](../../reviews/RV-L40.c.md)は「可」（軽4・情報4）である。今回の担当は軽の四件を修正し、情報の四件を後段への申し送りとして記録する。定義・規則・署名・証明・importは変更せず、Lean本番はコメントとdocstringだけを変更した。公理監査は再実行せず、再開1と独立レビューの監査結果を保持する。

| 所見 | 処置 | 判定 |
|---|---|---|
| 軽1 | 01-12・07-04のE_Lamの写しとStep/LambdaApplicationExamplesのコメントを、空捕捉で閉じたclosureの値・生lambdaのStep・型付き二歩の現在の性質として書いた | 処置済み |
| 軽2 | ComputationInputsの写しをret（到達型での値の型付け）、if（各Booleanの経路条件の下の本体の型付け）、他の14構文（元前提・LeQ・Covers）に分けた | 処置済み |
| 軽3 | 基準から7本/初回末から6本、plan/detailの担当による変更0、E_Lamの設計者による見直しを明記。O118を新5モジュールと変更した既存の規則・葉へ更新 | 処置済み |
| 軽4 | 比較実行ファイルの直接・推移importにRefinementがないことと、接続の検査を担うF-REG/F-CONN/F-CLOSE/F-FINALを記録 | 処置済み |

### 情報1〜4の申し送り

| 情報 | 担当・時期と申し送り |
|---|---|
| 情報1 | L60の実表・R50以後の接続へ渡す。δ・IO・外部の引数やセル内容には生lambdaとclosureの二つの表し方が残る。Rustの関数値との対応では、同じ関数値の表し方によってδ等の応答が変わらないことを、表の条件又は比較の入力で扱う必要があるかを確認する。生lambdaを頭に持つE_Lamも接続の入力に含める |
| 情報2 | L70の全分配では、名前付きのStateTyE.inputs/lambda_inputs/if_inputs/match_inputs/guard_op_inputsと各contract_inputsを直接使う。76葉への供給を確認するLeafInputsの78適用例は匿名で、環境に宣言を残さない |
| 情報3 | 保管時の取りまとめへ渡す。obstruction.leanは変更前の規則での反例の記録であり、現在の規則ではno_stepが偽なのでファイル全体は型検査を通らない。historical_inputsのhashを保持する。先頭に履歴の注を足すかは取りまとめが判断し、今回の担当は同ファイルを変更しない |
| 情報4 | 見込み更新の取りまとめへ渡す。規則/葉の追随約10分・供給約16分は外側の時刻であり、能動時間と待ちを分離できない。L40.15の50〜100分や群/段の枠を短縮せず、未経験の群へ一律に外挿しない |

検査はformal/から対象を指定しない既定lake buildと、指定B_WORKのworkを一度行い、いずれも終了0となった。workの内容はdry-runで確認した。check-formal.shの全比較と公理監査は再実行しない。RSSは未取得（計画上の非採取）である。今回の検査の生出力は `<tmp>/l40-c-resume2/`、コマンド・本体終了・外側時間・bytes/SHA-256はchecks.jsonへ記録する。

### 再開2の検査結果

Lean2本のコメントを除いた本文のSHA-256が編集前後で一致することを確認し、[r2-comment-check.json](r2-comment-check.json)に本文と現行ソースのhashを保存した。比較の七入口からimportを推移的に読み、いずれにもRefinementがないことを確認した。定義・規則・証明の変更は0である。

| 検査 | 終了 | 外側秒 | 内容 | 生出力bytes | SHA-256 |
|---|---:|---:|---|---:|---|
| r2-build | 0 | 2.335 | formal/から対象指定なしのlake build。966ジョブ | 43,318 | `4bb72f4202a0e341af2316ba7197a438610404cd04bca308aa1021a72cfdf66c` |
| r2-work-selection | 0 | 0.114 | 指定B_WORKでspec_tally/spec_examples/formal_buildを選択 | 759 | `e489f9b3ef1358a71dce966186478692922595e9bd6b35958fe41043c478f731` |
| r2-work | 0 | 3.738 | --onlyなしで一度。仕様対応の自己検査/集計、仕様例7件（失敗0・ignore0）、既定全Leanとsorry拒否 | 5,847 | `d9319daff87bd3a7e5a0dc4ecf186f0bcfdec1436776226c60dae0e7d3b8d5f3` |

公理監査の再実行は0回である。コメントとdocstringだけの変更なので、再開1と独立レビューが一致を確認した705モジュール・68,912宣言の監査を保持する。作業末のwork以後に本番のLeanと設計書は変更していない。記録の照合はverify.pyで再生成し、全新モジュールの既定importと22/76/64行、各記録100KB以下を確認する。今回の処置は担当の自己点検であり、独立レビューの所見の閉鎖とE_Lamの設計者による見直し・受け入れは取りまとめ・設計者が扱う。

記録照合r2-verifyは終了0、外側0.092秒。生出力4,762 bytes、SHA-256 `880d0c8964a3403498cdb954f30f80b8421d48504f438cfe1068f230519b6c03`。再開2の外側の時間は上表の243.466秒であり、読取り/編集/検査の能動時間と待ちは分離していない。

## 作業末の work

取りまとめが、RV-L40.c（可）と再開2の後に、Refinement の生成物を消してから、sandbox の外で macOS の `/usr/bin/time -l` を付けて一度実行した。

| コマンド | 終了状態 | 外側の時間 | 最大常駐量 |
|---|---|---:|---:|
| `scripts/check.sh --level work --base 4d27a9306e76b51f0686d04338a574053755dd4d` | 0 | 169.97秒 | 1,840,775,168 バイト |

選ばれた検査は、仕様対応の自己検査・集計、仕様例（7件成功・失敗0・無視0）、既定の Lean ビルドと `sorry` の拒否である。機械は Apple M4・メモリ 32 GiB、OS は macOS 27.2。最大常駐量は `/usr/bin/time` が報告した、`check.sh` とその子のプロセスのうち最大のものの値であり、計測器自身の分と分けていない。
