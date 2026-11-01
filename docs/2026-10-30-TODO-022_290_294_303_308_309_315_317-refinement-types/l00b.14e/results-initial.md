# L00b.14e: 節の引数と resume の代表の結果

2026-11-01。**分類は「一部」である。** 必須の E_Op・E_Resume・E_HRet・E_Drop と、追加の E_ResumeErr の代表を、開始の StateTyE の逆転を含めて閉じた。操作は単相・一引数の呼出し元が pure である代表、再開と返却は任意の捕捉から定数の view を得る代表である。全状態の保存、全ての単相節、多相節、used/drop の全体の完成は主張しない。

CoreAssumptions・ContTy・StateTyE と型付け・遷移の規則は変更していない。新しい公理も追加していない。今回の代表は既存の CoreAssumptions で閉じ、表の条件の不足や D19 の方式を破る反例は得ていない。利用者の書ける形、提供範囲、精密な外部状態、既存の主定理の前提と結論も変更していない。

指定ブランチは `m014/l00b.14e`、B_WORK は `c64c0dc376b85185744303c4752d1f1bb34967af` である。git の照合・切替・作成・コミットを行っていない。処理系、設計書、plan、既存のレビュー、rv-* を変更していない。新規のレビュー依頼だけを指定された場所に作る。work は取りまとめが行うため実行していない。L00b.15 へは進んでいない。

## 閉じた定義と補題

新規5モジュールと集約 import の追加を [source-delta.json](source-delta.json) に記録した。公開は定義1・補題16の17宣言である。実装前の契約と補助の採否は [signatures.md](signatures.md)、暗黙の変数も含む最終の完全署名は [public-api.log](public-api.log)、名前の全一覧は [public-names.json](public-names.json) にある。

| 本番のファイル | 閉じた定義・補題と役割 |
|---|---|
| [HandlerContinuation.lean](../../../formal/Benitoite/Release/Refinement/HandlerContinuation.lean) | HandlerFrameTy、ContTy.nil_inv/resume_append/split_handle。K_Handle の Γ・Φ・ソースの注釈・閉じた契約を保持して切り出し、EndsWithHandle を使って末尾を再接続する |
| [HandlerStore.lean](../../../formal/Benitoite/Release/Refinement/HandlerStore.lean) | StoreOk.allocate_continuation/use_continuation。有限性・WF・Declared・領域・既存セルの型付けを保持して、継続を割り当て、使用時に used へ更新する |
| [HandlerPreservation.lean](../../../formal/Benitoite/Release/Refinement/HandlerPreservation.lean) | ContTy.return_annotation、StateTyE.handler_return_const/drop_used_const/resume_used/resume_const。開始を逆転し、Step と到達の StateTyE を返す |
| [HandlerCalls.lean](../../../formal/Benitoite/Release/Refinement/HandlerCalls.lean) | HasTypeCQ.operation_call、ClosureTy.pure_operation。fn/dependentFn、TelClosure、部分型・正規化・効果拡大の下から宣言の依存列に対する引数の型を得る。pure の捕捉の Φ も閉じた事実で除去する |
| [HandlerOperation.lean](../../../formal/Benitoite/Release/Refinement/HandlerOperation.lean) | ContTy.guard_effect、StateTyE.operation_under_guard_false、ClosureTy.widen_atoms、StateTyE.operation_one。単相節への実引数と継続の場所を CaptureOk.extend/extendCont で追加し、元の宣言の潜在効果を保存する |

本番の追加は1,125行、境界は437行である。既存の検査の削除・変更はない。独立レビューは未実施であり、この自己点検を独立レビュー済みとは扱わない。

## 入力の事実・依存する結果・捕捉・効果

| 確認した性質 | 証明と境界 |
|---|---|
| 節の引数の篩を本体で読む | operation_one は開始の呼出しを逆転して宣言の入力型の hval を得て、CaptureOk.extend で捕捉へ加える。境界の clause_reads_input は、入力の x<8 を Γ.facts から読み、同じ値を resume の結果契約へ渡す |
| 閉じた事実を D19 で導く | three_small/three_returned は閉じた評価の成功から導く。Snapshot.captured は addEvaluated（内部で addEntailed を使用）で捕捉を作り、after_use は close_entails で閉じた導出を返す。StateTyE に Φ の欄は足していない |
| resume の引数は宣言の結果型 | 操作の結果は Integer{self = input ∧ self < 8} である。operation_one は実引数 v による substTyValues (openValue v) y を格納の継続の入力にする。補助 close_one は、元の hcap が非空でも、この像と (hcap.extend v).closeTy y が等しいことを示す |
| 継続側の依存する結果との一致 | resume_closed と resume_inv が、捕捉した継続変数を場所に置換し、格納の入力の正規形で定数を型付ける。結果型・潜在効果・R の正規化後の照合を開始から取り出し、resume_raw_return で生の R に戻す |
| hcap と継続内の CaptureOk | split_handle は同じ捕捉・節の導出を HandlerFrameTy に保持する。割当て時は既存の StoreTy の拡張と CaptureOk/ClosureTy/ContTy/CellOk の移送を使う。使用時は Ψ を変えず μ のセルだけを used にする。Snapshot.after_use は、実ストアの変更後も捕捉の閉じた事実が残ることを確かめる |
| 潜在効果 | 切り出した継続の結果行は K_Handle の ec と一致する。resume_append は caller の行による ec の被覆を接続する。節の実行は widen_atoms で Fail を保ち原子だけを et に広げ、StateTyE が要求する Sub を作る。Covers を Sub と同一視していない |
| 一度だけの使用 | resume_const がセルを used にする。used_after_resume と resume_twice は、その同じセルで二度目の再開が E_ResumeErr になることを確かめる。再開回数を静的な線形性の保証へ読み替えていない |
| GuardBodyTy と K_Update | split_handle/resume_append の全10構成子の帰納で、pending の GuardBodyTy、K_Update の lookup と Annotation を保持する。guard_effect は guard 評価の行が空であることを返し、operation_under_guard_false は宣言の操作の効果原子がその空行に被覆されないことを示す |

E_Op の代表は、宣言の Annotation と Normal、節の本体の空の型置換の固定点、呼出しの値の closeVal の固定点を明示する。到達の ClosureTy/StateTyE、本体の新しい型付け、閉じた事実の Entails を入力に仮定しない。hcap・切り出しの k1・継続末尾の k2・最終の型と Eb は任意である。resume/HRet/drop の代表は呼出し元の捕捉を空に限定しない。

## 場合の数の予定と実際

| 族 | 予定 | 実際 |
|---|---|---|
| 必須の Step の代表 | E_Op/E_Resume/E_HRet/E_Drop の4種 | 4種とも Step と保存を本番へ置いた |
| 追加候補 | E_OpFail/E_OpPrim/E_ResumeErr/E_DropRel の4種 | E_ResumeErr の1種を追加。残る3種は下表へ送る |
| ContTy | 全10構成子 | 切り出し・接続とも全10構成子。K_Sub と二種の handler を落とさない |
| CellOk | 既存6形の移送 | allocate_continuation が CellOk.store を再利用し、builder/val/thunk/done/cont/used を保持する |
| GuardBodyTy | 既存1構成子 | 証拠を保持して移送する。判断の変更なし |
| 逆転 | 値29・計算24構成子 | 各形の適用可能な葉と、形の不一致で除く全場合を列挙した。構成子の増減なし |
| 相互三族・Step の総数 | 76・76 | A-L の環境検査で76・76を確認した。今回の代表5種とは別の数である |
| 公開宣言 | 署名の確定時に集計 | 定義1・補題16の17件。初稿の handler_input_evaluated は重複のため新設しなかった |
| 境界 | 実際の遷移列と契約を外す負例 | 5遷移全ての Step と各到達の StateTyE、二度目の再開、4負例、捕捉の store 変更。公理監査の宣言は100件 |

## 補助の契約で決めたこと

1. K_Handle の前提を HandlerFrameTy にまとめ、閉じた型だけに潰さない。
2. saved の EndsWithHandle を使って末尾を接続し、末尾の行を caller の行による Covers で照合する。
3. 宣言とコードの正規化を代表の条件に明記し、コード型置換の一般保存を仮定しない。
4. resume は捕捉したソースから置換で閉じ、格納された入力型の正規形で受け取る。ストアに Sorted を追加しない。
5. 節の実行では Fail を保って原子だけを広げ、既存の StateTyE の Sub を構成する。
6. 重複する handler_input_evaluated は新設せず、既存の addEvaluated/addEntailed を使う。

採った理由と捨てた案は signatures の決定の記録にある。CoreAssumptions の表の条件を足す変更と、ContTy/StateTyE の定義を強める変更は行っていない。

## 残りと送り先

以下の L20 の残件は、すべて計画の全ストア・閉包・継続の保存と型/行/範囲/値の置換の枠の内数である。Lazy・Reference・return と重なる閉包の一般化を別々に加算しない。今回の代表を全状態の保存に繰り上げない。

| 送り先 | 残る言明・依存・担当 | 見込み |
|---|---|---|
| L20 | 多相節の型引数の具体化とコードの型置換。HasTypeClausesQ の型/行置換と捕捉の移送を全保存へ接続する。担当はL20の実装担当 | 追加計上なし。既存枠の内数。個別の能動時間は未測定 |
| L20 | 単相の複数引数の依存列と、生の非正規形の宣言・空の型置換でコードが変わる節。extendTel と依存列の交換・正規化を一般化する | 同上 |
| L20 | pure でない操作の呼出し元、任意の再開値と ret の closeVal の型保存。Reference/Lazy の捕捉を持つ呼出し元・任意の ret と同じ補題群で一度だけ扱う | 同上 |
| L20 | E_OpPrim。範囲付きの ClauseSig と呼出しの具体化を照合する。今回の一階の入力の方式が偽であるという反例は得ていない | 同上 |
| L20 | E_OpFail。失敗節の型の束縛と値なしの継続の位置を extendHidden で具体化し、同じ開始の逆転から保存を合成する | 同上 |
| L20 | E_DropRel と escape/error/exit の全 drop。releases(saved) の型付け・閉性・Adequate・State 原子の到達を、used の保存と合成する。今回は解放の効果の全伝播の補題を未実装 | 同上 |
| L20 | 全状態の保存への合成。今回閉じた代表の条件を主定理の新しい前提に残さない | 不明（既存の全保存の枠） |
| L30 | Rust の実際の節の引数の篩・結果の依存、継続の切り出し・再開、使用済みの拒否、解放を含む破棄との照合 | 不明（既存の照合の枠） |
| L40 | 全 canonical forms と進行、単相/多相/組み込み/失敗節の全入口。guard の空行と操作の不可能性も合成する | 不明（既存の進行の枠） |
| L00b.15・取りまとめ | 今回の規則を変えず、実際に置いた17宣言と代表の限定を写し・分類の取りまとめへ反映する | 不明（担当外） |
| 独立レビュー・work・受け入れ | 取りまとめがレビュー・work・取り込みを行い、設計者が受け入れる | 不明（担当外） |

O008 は、開始を逆転する5代表を、以前の同時構成と区別して記録した。O051 の節/resume の一引数・定数の代表は閉じたが、O051 全体は完了にしない。D19 の方式は今回の遷移列で成立し、行き詰まりには当たらない。

## 計画からのずれ

E_Op は、単相全体ではなく一引数・正規形の宣言・空のコード型置換の固定点の代表に限定した。複数引数とコードの一般の正規化を L20 に残すため「一部」と分類する。E_ResumeErr は同じ開始から短く閉じたので追加した。任意の ret の closeVal を先取りせず、.14d と共通の定数の view を使った。主な定理の契約や言語の規則を変更していない。

## ビルドと公理依存

[verify.py](verify.py) を実行した。既定ビルドは [lakefile](../../../formal/lakefile.toml) の moreLeanArgs にある -M 12288、単独の Lean も明示の -M 12288 を使った。道具の固定版は leanprover/lean4:v4.34.1 である。結果は [verification.json](verification.json) にある。

| 検査 | 終了 | 件数 | 外側の時間 | 記録 |
|---|---:|---|---:|---|
| 既定の lake build | 0 | 733ジョブ | 1.465秒 | [build.log](build.log) |
| 境界 | 0 | 全100宣言の公理依存 | 1.326秒 | [boundary.log](boundary.log) |
| 完全署名 | 0 | 公開17宣言 | 0.333秒 | [public-api.log](public-api.log) |
| A-L | 0 | 152モジュール・15,418宣言 | 13.700秒 | [集計](axioms-summary.json)・[生出力の大きさとSHA-256](large-records.md) |

全差分と境界の依存公理は propext・Quot.sound・Classical.choice だけで、sorryAx の依存はない。新しい5モジュール、集約 import、既存の全 Refinement、モデルの仮定充足と旧 Release の主定理を監査対象に含めた。新しい本番ソースと境界に sorry/admit/axiom/native_decide/unsafe/implemented_by はない。

最初の一括確認は、ビルドが成功した後、境界の宣言を列挙する補助が getMainModule の module index を取得できず終了1になった。証明の失敗ではなく、直接読み込む入力の監査方法の誤りである。[verification-first.json](verification-first.json) と [boundary-first.log](boundary-first.log) に残した。列挙を既存の境界と同じ名前による列挙へ直し、全100宣言を再確認した。この修正は境界末尾だけで、形式化の本番ソースと設定は変わっていない。

再確認の verify.py --reuse-build は、[verified-build.json](verified-build.json) の全形式化ソース・設定とビルド出力のハッシュを照合して、成功した同じビルドを引用した。検査のためだけのビルドを重ねていない。[source-inputs.json](source-inputs.json) は全 Refinement と設定、[boundary-inputs.json](boundary-inputs.json) は境界・公開署名・A-L・台本を記録する。大きい生出力は改造に置いていない。

既定ビルドには既存の lint とリンク時の環境の警告がある。Rust の検査、Rust/Lean の全比較、性能測定、別機、LLM の追加起動、作業末の work は行っていない。最大常駐量は未取得（計画上の非採取）である。

外側の時間は、2026-10-31 23:01:37 UTC から 2026-10-31 23:26:45 UTC まで約25.1分である。読み取り・署名・実装・局所検査・一括確認・文書化を含み、能動時間と待ちを分離していない。見込みの上限4時間の範囲内である。
