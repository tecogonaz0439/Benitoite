# L30 段末の照合と受け入れ資料

2026-11-03。群A〜Kの取り込み済みの成果と、群L/M/Nの担当の結果を集約する。これは担当の自己点検である。**RV-L30.lの条件付き可を受領し、再開1で所見へ応答した。取りまとめの処置の再確認・正式RSS・planへの転記・設計者の受け入れは未実施**であり、段全体を受け入れ済みとしない。L20は同日の設計者の受け入れを継承する。

今回の指定基準B_WORKは `c30b5b3424f6d98295b26cac96fe9a8b35a2eb27`、指定ブランチは `m014/l30.l`。いずれも起動依頼で受領した値である。担当はgitの操作を行っていない。基準に今回の未コミット差分と新規入力を加えた関係状態を、[入力の記録](l/inputs.json)で識別する。

## 方式の関門とJ30

| 関門・判断 | 本番の証拠と判定 | 残り |
|---|---|---|
| A1・J30-2 型域と意味 | Ty.carrierFacts、Ty.assume/Ctx.facts、ValueMeaning.mkの第三条件、Const.NumericRepresented.carrierFacts。H/Iの16読者・33場合・全捕捉の処分。主な十移送の形を維持。RV-L30.hが三つの約束を可とした | 判断の定義の変更はD02/D21として取りまとめが採択済みであり、設計者の見直しの対象という扱いを維持する |
| A2・J30-5 checkedAt | B/Cのlinearize_sound_at/normalize_sound_at→D/F/Gの全有限規則→implication_sound_at→Entails.checkedAt。weaken/cut/sound/bindの四帰納。公開Entails.bindを維持。Aの案(ii)の採択を引き継ぐ | 主定理・表層・交換の全合成はL70。c'の再生成を義務に戻さない |
| A3 整数 | LinearStepのcombine/round、正除数・全係数の整除・負の床・2*x=1の矛盾、splitの両枝の全被覆。D再開1の分枝事実を使う正負対照 | R20の探索順・有限上限・不完全性、R70の不要な≠の測定 |
| A4 限定合同 | EqProof9構成子、structural/integer、RewritePosition、FieldRef.Declaredと同じPのVarianceValid。Setのsnapshotの反例を拒否 | ソース別名の実像はL70/R10b、RustのinterningはR20。別名の反射の代表を意味上の異なる構造の同定と呼ばない |
| A5 葉の受渡し | PreparedLeafの四欄、checkIn/entailsIn/bind_entails/checked_refinement、本番HasTypeVQ.represented・観測・正常算術・有限鍵からの供給。Kの同じListの長さから網羅性への合成 | 実標準表・δ・標準本体はL40、対象と全σはL50、三モデルはL60 |
| J30-1 保存幅 | CoefficientRepresented bits、CoefficientModelの成功の対応、保存幅128、一時積とDecimal比較を別の正確な計算へ分離 | R20の保存時の検査、32ビット構成の変換・全実作業の照合 |
| J30-3 粒度・版・予約 | StepAccountingの一byte/一節点・辺・要素/固定幅一演算、proof-steps-v1、生成時の個別予約、destroy_once/rollback_all、used+reserved≤limit | R20の所有・共有handle・明示スタック・rollbackの全実装 |
| J30-4 計上の範囲 | runActions_used/input_certificate_expansion/within_limit、I/C/Pと仕事列の対応、停止した接頭辞を保持するexecute、三種の停止 | 操作列が全実作業と一致することはR20の実装レビュー。CPU時間・証明書byte数だけへの線形時間は未証明であり主張しない |

規範はU03の決定(2)の数え方とStepAccountingの状態遷移の契約である。AccountingWorkの列はこれに従う例示であり、Rustの実際の操作列を定めない。再開1でbyteの二重計上と、係数検査の失敗後の未実行の操作を除いた。checkAccountedは与えられた操作列の失敗時に再生へ進まないが、Acceptedは上限0・空列も許す二条件の関係であり、全実作業との一致は別に照合する。

U03（J30-1/3/4）は設計者の決定どおりに契約にできた。追加の選択・新しい公理・独立の信頼条件・利用者の形を狭める変更・精密な外部状態の新設は不要だった。J30-2の判断の定義の変更と、主な言明の量化・結論の変更を区別する。

## 全有限場合と旧読者

[全場合の表](l/case-completion.md)を正とする。線形化Term20、NNF28、LinearStep2、Refutation9、EqProof9、Certificate7、旧六構成子、BuiltinLemma12種類100分岐、16sort、7measure、正常算術21組と符号付き負号4組、鍵の成功11形と対象外3形を別々に数えた。補助の場合を重ねて合計しない。未実装の規則を常にfalseで拒否したまま完成とした場合は0。

旧の構造等号のEqProof.check/sound、PreparedLeafの閉じた二種、Certificateの旧六規則の成功保存、旧Releaseの既定importを保持する。B08の16分岐は同じ項のq→q、参照形はuseであり、論理を強めない。観測成功はKの型付き値と実観測の別の証拠に基づく。旧Release全域や全旧型との同値を結論しない。

H/Iの変更後のCaptureOkの全読者は、既存ImageOk・HasTypeVQ.assume・Capture.facts_extend等から型域を供給する。J/Kは開いたΓの型域の真と、算術の像の型域を元の経路から供給する例を置く。型付けの76場合や主要十移送へ新しい前提を足さない。

## 義務35行の照合

detailのplan担当27行、L20段末15行の差集合3行（O046/O079/O138）、O143の1行を合わせて31行であり、共通4行を加えて35行である。O056はL00b.14b-paths/L20/L70の行であり二重に追加しない。planは既にO046/O079/O138/O143のL30担当を持つ。今回担当はplanを変更していない。

以下の「完了」は**L30の担当の技術作業**に限る。**31行の技術作業、2行の共通記録を完了し、共通2行は一部**である。全体閉鎖・段末受け入れ済みは0行である。O054は計画上の単独担当L30の有限論理まで技術作業が完了したが、段末のレビューと受け入れを待つ。

| 義務 | L30担当分の判定と段別の本番証拠 | L30の後に残る段・判定 |
|---|---|---|
| O015 | 完了。B/E/F/Kの全sort、B04/B06/B07、Val.toTerm_observed/typed_observationと16行 | L40標準葉、L50の所属・全有効σと具体化 |
| O017 | 完了。LのOperation/stepAction/runActions、版・個別予約、処理別のR20受渡し表。操作列への契約 | R20が全実作業との一致と実装の使用数をレビュー、R50/R60報告 |
| O019 | 完了。D/E/F/G/Kの2/9/9/7構成子と全sound、12種の不正証拠、AllKeysChecked/refute_keys_same | R20の独立検査器、R50の有限比較 |
| O020 | 完了。DのdiscardTodo/discardFactと既知矛盾、Or展開前の反証。Lの停止理由 | R20探索順、R70の不要な≠を含む実測 |
| O021 | 完了。Aの重複控除後79単位・47時間5分〜91時間55分を照合し、全群の記録と今回の外側の時間を分離 | L40/R20と取りまとめの見込み更新。能動時間が未分離の群から中心112を80へ変えない |
| O022 | 完了。E/F/H/I/J/Kの本番の三条件・葉・型域・閉じた有限鍵。不変欄と反射の別名代表の境界を明記 | L40の実標準本体・δ、L50の対象/σ、L60の実モデル |
| O023 | 完了。Mの同じProofReplayExamples.rowsの22行を核内decideと実行時の再生で別々に確認 | R50の交換再生と時間の比較 |
| O026 | 完了。J/Kの実観測と数値候補の区分、LのProofResult/ProofStop。負のlengthを実反例にしない | R20の元の値への実現確認、R60の診断/JSON |
| O034 | 完了。Jのmeasure_machine_exact/stable、正常算術、Kの型付き観測とNormalResultLeaves、KeyShapeからの鍵 | L40の全契約、L50/L60の実表、R50 |
| O043 | 完了。Kのchecked_refinementが本番Ty.LeQ.refineを読み、open_refinement_bindが四つの像を含む既存Transportを使用 | L40の全部分型・正常δ、L70の合成 |
| O050 | 完了。Eの限定したinteger合同と危険なsnapshot書換えの拒否、Jの観測交換とNoneの保持 | L40の標準葉。L20の一般置換を再実装しない |
| O054 | 完了。既存or_elim/not_introを継承しF/KのB04→apart/false_side、And/Or/Notと限定合同を証明 | L30段末の処置確認・受け入れ。標準比較はL40、ソース構成はL70/R10bの別担当 |
| O071 | 完了。B/C/D/Gの有限規則、負床・奇数等式・全分枝、検査成功だけからの健全性、Lのunknown境界 | R20探索実装・unknown、D10の不完全性の説明 |
| O072 | 完了。B/E/Jの有限な実項の鍵・宣言した欄連鎖・同じmeasure・構文の一致。一般UFへ拡張なし | R10bのソース別名、R20のinterning/探索 |
| O127 | 完了。FのcharactersSubsetとKの型付きString・実charactersInの受理/拒否。Hは既存篩を保持 | L40→R10b/R40/R50→V10。一般regexなし |
| O130 | 完了。Jの実「é」の2byte/1文字、二measureの正常観測、Kの上層と置換 | L40標準契約→R10b/R40/R50→V10 |
| O131 | 完了。JのNoneを含むList長、Kの同じListのlen=n/0<n→非空とpattern_length_relationの合成 | L40のmap/reverse/append/filter本体→R段/V10 |
| O132 | 完了。JのBytes正常長と不正byteのnone、Byteの別の型域 | L40標準契約→R10b/R40/R50→V10 |
| O133 | 完了。JのKeyShape/コード・Map縮約・元の鍵と後の値。satBとの橋を仮定しない | L40の型付き鍵からKeyShape/ClosedSlots、鍵不変・値共変・実本体→R段/V10 |
| O134 | 完了。JのSet縮約・鍵の構造・正常sizeとNoneの区分 | L40の型付き鍵からKeyShape/ClosedSlotsと不変/実本体→R段/V10 |
| O135 | 完了。E/J/Kの同じPのVarianceValid、FieldRef.Declared、不変欄連鎖・stable | L40/R40のdata/decode/record全体条件→R50/V10 |
| O136 | 完了。D/Gの線形関係とKの依存端点・開いた型域・四つの像を同じLeQで移送 | L40契約/L70→R10b/R20/R50→V10 |
| O137 | 完了。H/Iの七整数型・Byte/Decimal型域、J/Kの七幅21正常演算・四幅負号・正常葉とStopの区分 | L40の全実δ/標準契約/H04→R20/R10b/R40/R50→V10 |
| O144 | 完了。B〜Kの全有限規則、構造等号/空篩/trueを継承、Lの停止境界。B08は同一項の含意に限定 | L40の型/標準葉、L50対象→R20/R10b/R40/R50→V10 |
| O158 | 完了。Lの三種の停止とU08=Aの照合。独立の深さ/枝数/入力/証明書量unknownなし | R20/R70の実装と設定、V10のmalformedとの実CLI区分 |
| O161 | 完了。CoefficientRepresented bits、部分演算の成功、一時域別引数、保存幅128、表現外とstepsの別結果 | R20適用、R60診断/JSON、V10のstepsが残る表現外とsteps超過の別入力 |
| O167 | 完了。B/E/F/J/K/Lの非観測・限定合同・不正な観測/入力・未知鍵/停止を対応する受理と対照 | L40/L70→各R段/V10。比較連鎖/区間略記の構文拒否はL70/R60 |
| O046 | 完了。F/G/J/Kの有限論理と正常葉をL20の既存if/guard/matchの一般葉へ供給 | L40の算術/length/δ、L70の全合成 |
| O079 | 完了。Kの長さの証明書とnonempty_from_length・既存網羅性、別Listの拒否 | L70/R10bの静的scrutinee強化、R50比較 |
| O138 | 完了。F/KのBooleanの真偽と非空の有限証明書。経路条件の実型付けを完成としない | L40標準facts、L70/R10bの静的合成→R50/V10 |
| O143 | 完了。Kの同じlengthの証明書→非空→網羅性→pattern_length_relation。任意の別Listの実API契約を含めない | L40標準契約、L70/R10b/R40/R50/V10 |
| O016 | 一部。既定の新旧全モジュール・全名・private/生成宣言・旧主定理/十移送をA-Lで監査。許可三公理のみ | RV-L30.l所見処置の再確認（.79）、L70全合成/Rust開始条件 |
| O084 | 共通記録完了。篩/σ/external、証明/実装/比較/受入を区分し、J30と全行の証拠を本書へ集約 | 段末の処置確認・全L/R/K/Vの受け入れ |
| O027 | 一部。-M12288、終了・時間・生出力識別を記録。担当は正式RSSを採取しない | 取りまとめが段末の同じ最後のworkへ正式RSSを付け、本体/計測器/原単位/機械を保存 |
| O118 | 共通記録完了。新本番コメント/写しは現行の定義に対応。工程ID/絶対パスを追加せず、既定importを維持 | L70/R50/R60/D10/V10の全体照合。既存コメントの残件は既存の担当へ |

## レビューの処置と次段の実署名

[一件ずつの処分表](l/review-handoffs.md)は63行（済52・後段へ転記11）。L40へのKeyShapeの供給・前提を読む長さのTy.LeQ・Booleanから枝の型付け、L50の全σとAt、L60の三モデル、L70の主定理/表層/ソース合成、各R段の実装比較を理由付きで分けた。

L40の四入口の完全署名は [j/signatures.md](j/signatures.md#preparedleaf) と [signature-check.lean](l/signature-check.lean) で照合する。いずれも名前空間はBenitoite.Release.Refinementである。

```lean
def PreparedLeaf.checkIn (P : Program) (C : TypeCtx) (Γ : Ctx)
  (Φ : List Pred) (l : PreparedLeaf) : Bool
theorem PreparedLeaf.entailsIn {P : Program} {C : TypeCtx} {Γ : Ctx}
  {Φ : List Pred} {l : PreparedLeaf} (h : l.checkIn P C Γ Φ = true) :
  Entails (Γ.facts ++ Φ) l.predicate
theorem PreparedLeaf.bind_entails {P : Program} {C : TypeCtx} {Γ : Ctx}
  {Φ : List Pred} {l : PreparedLeaf} (h : l.checkIn P C Γ Φ = true) (ν : ObservationEnv) :
  Entails ((Γ.facts ++ Φ).map (predBind ν)) (predBind ν l.predicate)
theorem checked_refinement {P : Program} {Γ : Ctx} {Φ : List Pred}
  {a b : Ty} {p q : Pred} {c : Certificate}
  (hab : Ty.LeQ P Γ Φ a b) (hp : p.Sorted Γ (some a)) (hq : q.Sorted Γ (some b))
  (hc : CertificateKernel.check (Pred.ofConjuncts (p :: assumptions Γ Φ a)) q c = true) :
  Ty.LeQ P Γ Φ (.refined a p) (.refined b q)
```

L40はこれに実measure・正常算術・型付き値から供給する三条件を接続する。NumericContracts/NormalResultLeavesの実正常応答と、Keyの有限構造の完全署名もj/signatures.mdを正とする。型保存だけから任意の抽象B.deltaと算術の一致を仮定しない。

R20には [r20-contract.md](l/r20-contract.md) の全処理の表と [l/signatures.md](l/signatures.md) の実署名を渡す。保存幅・版・基本操作・予約と三停止を、Rustの使用数・探索順・u64既定値・設定元の実装と分ける。操作列が全実作業を覆うことを未検査のまま健全性の前提へ足さない。

## 見込みと全群の実績

detail第6節の79行をrecords.pyで再集計し、下端2,825分・上端5,515分（47時間5分〜91時間55分）に一致した。.73を含めず、.79/.80の旧計画はまだ見込みの内数である。短い外側の実績を未知の帰納やRustの実装へ一律に掛けない。

| 群・単位 | 再集計した能動時間の旧見込み | 台帳の担当の外側の時間（初回＋再開） | 証拠と精度 |
|---|---:|---:|---|
| A・6 | 3時間40分〜7時間15分 | 約59分（39＋20） | a/results.mdとeffort-ledger204/206行。入口の未採取・待ちの未分離を保持 |
| B/C・12 | 5時間45分〜11時間30分 | 約28分（23＋5） | b/results.md、台帳209/211行。単位の共通枠を合算しない |
| D/E・12 | 5時間55分〜11時間50分 | 約27分（22＋5） | d/results.md、台帳213/215行 |
| F/G・12 | 7時間20分〜14時間40分 | 約64分（58＋6） | f/results.md、台帳217/219行 |
| H/I・12 | 10時間45分〜20時間10分 | 約62分（53＋9） | h/results.md、台帳221/223行。切替と33場合を独立の新実装件数へ足さない |
| J/K・12 | 7時間〜13時間40分 | 約64分（49＋15） | j/results.md、台帳225/227行。型付き鍵からの構造の供給はL40 |
| L・6 | 3〜6時間 | 初回L/M/Nの共通枠は台帳230行の約30分。本再開はl/results.md末尾 | M/Nで後から補った記録も含み、専有した能動時間は分離不能 |
| M・3 | 1時間35分〜2時間55分 | 同上 | 実行再生・署名・監査の待ちと分離不能 |
| N・4 | 2時間5分〜3時間55分 | 同上。.79は未実施 | 正式RSS・独立レビュー・受け入れは別 |

[estimates.json](l/estimates.json)には選択した台帳の全行名・元の行番号・所要の字面を保存した。既存A〜Kの担当12行は合計約5時間4分である。群の独立レビュー8行は約1時間5分10秒、取りまとめの群末work6行は921.30秒、詳細化の計画2行は約1時間12分、計画レビュー2行は約19分30秒であり、担当の実績へ混ぜない。L/M/Nの初回は台帳230行へ約30分、RV-L30.lは231行へ約10分と転記済みであり、A〜Kの約5時間4分と群のレビュー8行には混ぜていない。本再開の担当分は台帳未転記であり、末尾の時間を正とする。取りまとめの台帳の更新と能動時間の見込みの更新は別の作業である。

## 独立レビュー応答の受け口と受け入れ

[review-response.md](l/review-response.md)にRV-L30.lを受領した後の再開1の処置を記した。所見の修正と影響範囲の検査は担当の応答であり、独立の再確認と受け入れを代用しない。.80の資料はこの状態で提出する。

| 残る手順 | 検査・レビュー・受け入れを含む内容 | 見込み |
|---|---|---:|
| 所見処置の確認 | 取りまとめが中1・軽1〜6・情報の処置を確認し、必要な再レビューを依頼 | 不明 |
| L30.79の応答 | 再開1の担当の処置・検査を末尾に記録。新たな所見があれば影響した検査を更新 | 新たな所見への応答の見込みは不明 |
| 正式RSSと転記 | 取りまとめが同じ最後のworkに計測を付け、planと起動依頼へ担当/残り/実署名を転記 | 不明 |
| 設計者の受け入れ | 段別の証明と全体の残りを確認 | 不明 |

検査・監査の件数・時間・出力の識別と、見込み/実績の最終集計は末尾の生成した表および [l/results.md](l/results.md) に記す。Rust/Leanの全比較は今回の作業に含めず、L70/R50へ残す。

<!-- 検査と時間の生成した記録 -->

## 初回の最終検査と生出力の識別（再開1は末尾）

workの入口は指定どおり一回であり、onlyも個別testも指定しなかった。既定の8対象・-M12288を維持する。正式RSSは未取得（取りまとめの採取待ち）。

| 検査 | 終了 | 外側の時間 | 確認した内容 |
|---|---:|---:|---|
| 既定lake build | 0 | 2.006秒 | 既定8対象・949 jobs、sorryなし |
| 実行による再生 | 0 | 0.332秒 | 同じ17行が全てtrue、件数不一致/falseは失敗 |
| 固定署名の照合 | 0 | 0.695秒 | 固定8署名の適用、旧5主定理/十移送等36宣言の実型 |
| 段末の公理監査 | 0 | 38.114秒 | 688モジュール・67,881宣言、許可三公理だけ |
| workのdry-run | 0 | 0.113秒 | 仕様対応の自己検査/集計・仕様例・既定Leanを選択 |
| 作業末のwork | 0 | 7.668秒 | 仕様例7成功・失敗/無視0、仕様対応の自己検査/集計、既定Leanとsorry拒否 |

workの実コマンドは `scripts/check.sh --level work --base c30b5b3424f6d98295b26cac96fe9a8b35a2eb27`。全コマンドと構成はverification.json、全入力はinputs.jsonに保存した。先の成功した既定ビルドはrows_checkedの核内検査を含む。実行再生と核内検査の時間の差からCPU性能の一般則を推論しない。

| 公理の依存集合 | 宣言数 |
|---|---:|
| none | 30,538 |
| Classical.choice | 1 |
| Classical.choice + Quot.sound + propext | 17,943 |
| Classical.choice + propext | 2 |
| Quot.sound | 9 |
| Quot.sound + propext | 3,555 |
| propext | 15,833 |

新しい公理・未承認依存・sorryAxは0。匿名exampleはこの定数の件数には含まれない。監査は `python3 docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l30/audit.py --tmp <tmp>` で再生成する。`--inventory-only`は同じ所属モジュールから全名だけを再生成し、監査済みと誤称しない別の要約へ保存する。

| 生出力（全て<tmp>） | bytes | SHA-256 |
|---|---:|---|
| local-build-4.log | 43,387 | `d0cfe7ffac53fe1bf0b9a77fce176b4a08ca667cb85d073558ed874d16d6d242` |
| replay.log | 293 | `b96efbd4909de6efca54a34cb3d99195fe0c088612599810e6453b92a349e638` |
| signatures.log | 18,346 | `b45393bf92551c3e225ac5dd39d9d0b642039ba1b9366d1e8dd065d30d8a1da7` |
| dry-run.log | 759 | `cfd6acc4c6554453671bd0bc9e684dbfafef3ba1e5e63b1cfab5dca16fa94420` |
| work.log | 5,802 | `09cae81f86004d7114456abbeee778a18a822d8aba6c82508f0f60443f417389` |
| axioms.log | 11,839,332 | `02b8f047e1bf00b382aff45615429c75cf803b95271bf0973aed2a8aae6317ee` |
| audit-targets.txt | 4,098,180 | `4ea79ab2e74200c2f43086a07710226fb6748e5bbc66f082e3760dcfd2301e5a` |
| formal-sources.json | 114,054 | `6762e77b63b7329d00e677c80bd0c5932078ec9c5478e61262dc3150fd05e0f8` |

ソース・設定・写しのSHA-256はwork前後の同じ関係状態を指す。後の更新は結果・受け入れ資料・台本の記録だけで、本番Lean/仕様例/既定import/設定の変更はない。Rust/Lean全比較や実CLIを実施済みとはしない。

## 初回の単位ごとの外側の観測枠

最初の時計は2026-11-03T12:32:40+09:00、最後の記録の照合は2026-11-03T12:59:09+09:00。観測できた全枠は1588.873秒（約26.5分）である。時計以前の読取りは未採取。能動時間と待ちは分離不能。重なる枠を合算しない。

| 単位 | 観測した外側の時間 | 精度・範囲 |
|---|---:|---|
| L30.67 | 449.945秒 | Lの共通観測枠。定義・証明・具体読者を共有し個別分離不能。合算しない |
| L30.68 | 449.945秒 | Lの共通観測枠。定義・証明・具体読者を共有し個別分離不能。合算しない |
| L30.69 | 449.945秒 | Lの共通観測枠。定義・証明・具体読者を共有し個別分離不能。合算しない |
| L30.70 | 449.945秒 | Lの共通観測枠。定義・証明・具体読者を共有し個別分離不能。合算しない |
| L30.71 | 449.945秒 | Lの共通観測枠。定義・証明・具体読者を共有し個別分離不能。合算しない |
| L30.72 | 855.594秒 | Lの共通観測枠。定義・証明・具体読者を共有し個別分離不能。合算しない。.72の終点は受渡し文書の保存時刻であり、独立に計時した終了ではない |
| L30.74 | 98.625秒 | 同じ17行の実行再生と核内証明。01-12/07-04の更新を含む。後から補った記録はNの枠に含む |
| L30.75 | 248.375秒 | 旧14行と六レビュー49行を一件ずつ処分。公理監査の実行待ちは並行し分離不能。後から補った記録はNの枠に含む |
| L30.76 | 269.132秒 | 35義務・署名・R20実作業表。全場合の処理と並行で分離不能。後から補った記録はNの枠に含む |
| L30.77 | 265.028秒 | 全場合・35義務・リンク・禁止構文・記録上限を照合。後から補った記録はNの枠に含む |
| L30.78 | 257.768秒 | Nの最終照合・work・受入資料の共通枠。公理監査自体の38.114秒はMの記録と並行して先に実行。合算しない |
| L30.79 | 未実施 | 未実施。レビュー未依頼、受け口のみ準備 |
| L30.80 | 257.768秒 | Nの最終照合・work・受入資料の共通枠。公理監査自体の38.114秒はMの記録と並行して先に実行。合算しない |

開始・終了の観測値と精度はtimes.jsonに残した。.72の終点だけは受渡し文書の保存時刻を使い、独立に計時した終了と区別した。L30.73は詳細どおり独立の作業なし。.79は取りまとめの依頼後、.80の受け入れ自体は設計者の判断後であり、今回の時間へ足していない。

## 再開1: RV-L30.l の処置

2026-11-03。RV-L30.l（条件付き可、重0・中1・軽6・情報3）への担当の処置を完了した。中1はplan先頭の取りまとめの判断に従った。修正後の処置の再確認、正式RSS、planへの転記、設計者の受け入れは未実施である。初回の検査・定数数・時間は初回の入力を指し、現行の検査は本節末尾とl/verification-resume1.jsonを正とする。

| 所見 | 処置と段末の証拠 |
|---|---|
| 中1 | 規範は決定(2)の粒度と状態遷移、AccountingWorkは例示とr20-contract・01-12・07-04へ明記。byteの二重計上と表現外後の操作を除去。既定のaccounting_prefixesで実際の接頭辞を照合 |
| 軽1 | 工程IDのコメント3件を除去し01-12を根拠にした。records.pyの検出を段ID・単位ID一般へ拡張。初回のO118の根拠の欠けを訂正 |
| 軽2 | 負の除数のユークリッド除算と(−3)/(−2)=2を明記し、既定の具体例と実行再生へ追加 |
| 軽3 | checkAccountedは操作列の失敗時に再生へ進まず、成功時だけreplayProofを呼ぶ。証明済みからAcceptedを得る。空列も許す二条件の関係であり、全実作業の計上の証明とはしない |
| 軽4 | I/C/Pは与えた列の増分、rowsは核内の検査、一時域の表現可能性は前提と文言を限定 |
| 軽5 | 数学Int/Natと幅引数によるホストの幅から独立したモデルまで。32ビットのi128・usize変換の実行照合は未実施でR20へ残す |
| 軽6 | J軽3をL40へ転記に訂正。63行＝済52・転記11。35義務は技術31・共通記録2・一部2、全体閉鎖0のまま |
| 情報1 | StepState/stepAction/runActionsと対応する補題へ改名し全読者を更新。旧名の別名なし。群A〜Kの固定署名・主な十移送は不変 |
| 情報2 | rollback_allだけでは上限内を結論しない。rollback_within_limitのValidと予約の一意性をR20の実装が守る必要を申し送る |
| 情報3 | 既定importの閉包の外にある旧LegacyCheckと、証明を含まないlean_exeの根は監査の対象外。今回importの変更・除外なし |

詳細と内部署名の変更一覧は[l/results.md](l/results.md)、所見別の応答は[l/review-response.md](l/review-response.md)、実署名は[l/signatures.md](l/signatures.md)。一般の列長の定理から、Rustの全実作業と記録の一致を結論しない。核内と実行時の同じ22行、固定8署名と主要42宣言、段末の全定数の監査、指定workをこの再開の最終状態へ更新する。

<!-- 再開1の検査の生成した記録 -->

### 再開1の検査・監査と外側の時間

この再開のworkは一回であり、--only・個別testの指定なし。既定のlake buildは8対象を保持し、単独Leanも含め-M12288とした。正式RSSは未取得（取りまとめの採取待ち）。

| 検査 | 終了 | 外側の時間 | 内容 |
|---|---:|---:|---|
| 既定lake build | 0 | 1.681秒 | 新規の読者と改名後の全既定対象、sorryなし |
| 同じ列の実行再生 | 0 | 0.363秒 | 22行全てtrue、false又は件数不一致は失敗 |
| 固定署名と実型 | 0 | 0.673秒 | 固定8署名と主要42宣言、旧名の別名を追加しない |
| 段末の公理監査 | 0 | 38.015秒 | 688モジュール・67,907宣言 |
| workのdry-run | 0 | 0.116秒 | 仕様対応の自己検査/集計、仕様例、既定Leanを確認 |
| 作業末のwork | 0 | 3.724秒 | 仕様例7成功・失敗/無視0、自己検査/集計、既定Leanとsorry拒否 |

workの実コマンドは `scripts/check.sh --level work --base c30b5b3424f6d98295b26cac96fe9a8b35a2eb27`。既定ビルド・再生・署名・dry-runの完全な引数と生出力の識別はverification-resume1.jsonに保存した。

| 公理の依存集合 | 宣言数 |
|---|---:|
| none | 30,549 |
| Classical.choice | 1 |
| Classical.choice + Quot.sound + propext | 17,949 |
| Classical.choice + propext | 2 |
| Quot.sound | 9 |
| Quot.sound + propext | 3,555 |
| propext | 15,842 |

許可三公理以外、新しい公理、sorryAxは0。既定のimportの閉包を保持し、旧主定理・三モデル・十移送・private/生成宣言を含む。

| 新規6モジュールの現行の全定数 | 件数 |
|---|---:|
| AccountingWork | 98 |
| CoefficientModel | 47 |
| ProofContract | 68 |
| ProofContractExamples | 18 |
| ProofReplayExamples | 9 |
| StepAccounting | 285 |
| 合計 | 525 |

名前付きの手書き宣言の現行件数は94（def36・instance1・theorem46・inductive7・abbrev1・structure3）。匿名exampleは全定数の件数に含めず、既定ビルドと禁止構文の点検で確認する。

| 生出力（全て<tmp>） | bytes | SHA-256 |
|---|---:|---|
| default-build.log | 43,308 | `d906d5f5433410c9bc0c81d0dd55dd07023db362cbdbf7a266891f8871f89775` |
| replay.log | 411 | `25a79f13ead7bbdb43753514b1dbd82f19db3a7c24dd4799dbe6ffffbfc7f74b` |
| signatures.log | 19,515 | `b98f567a366df095d3b5c80f3c3fdbdaf3fc9a3ee5930b1fc16a1c5777db4cd3` |
| dry-run.log | 759 | `7dc4b1fc0f8b4593e1ded75ce22dd988fdc719cbe66b07d03dfe8c6b46ca9b42` |
| work.log | 5,802 | `f5ba6d3c94f30bf1b2e5ec2068d6acba5a1f2e534537b96296bc7b43644308b1` |
| axioms.log | 11,845,117 | `409704dbdc5b3d3d2dc8d0eaa6b3553f4fb7861a7e6a8728e716d584c4fad8ea` |
| audit-targets.txt | 4,100,402 | `fd6e993934582195154ed0166efc34924a106c0975d931ab16af91e6747a9209` |
| formal-sources.json | 114,055 | `9d0e05d989f59570d999704dacdbd9f93f07adb695ce48ad399eaa9368edc58f` |
| before-sources.json | 85,089 | `2134b0fb1f0aa153c8922952e9521541c1d6d5c20de4b75179b97fb15d4e0057` |

再開1の観測枠は2026-11-03T13:12:53+09:00〜2026-11-03T13:33:08+09:00、1215.146秒（約20.3分）。所見の共通の定義・証明・読者・一部の文書までの枠は686.636秒、後の文書の照合・検査・記録の枠は528.511秒である。所見別の時間へ分配せず、能動時間と待ちは分離不能とした。時計取得前の読取りは未採取であり、初回の観測枠へ混ぜない。

今回の変更は本番6ファイルと対応する写し・入力・記録であり、他の既存Leanと旧Release・主な十移送・型付け規則・既定importを変更していない。work後の本番・写し・設定の変更はなく、記録のみ更新した。Rust/Lean全比較・32ビットでの実行照合・正式RSSを成功に含めない。

## 段末の work と取りまとめの転記

- 段末の work は終了0、外側159.00秒、最大常駐量 1,704,460,288 バイト（[群 L・M・N の結果](l/results.md)「作業末の work（段末）」）。O027 の正式 RSS はこれで採った。
- RV-L30.l の再レビュー（再開1）は可。O016 の段末の独立レビューはこれで済んだ。
- 取りまとめは 2026-11-03 に、本節の上の35行の処分を plan.md の「義務の対応表」の各行の状態欄へ「L30: …」として写した。全体を閉鎖した行はない。L30 の段末の受け入れは設計者が行う。
- 2026-11-03 に設計者が L30 の段末を受け入れた（README「設計者の決定」）。
