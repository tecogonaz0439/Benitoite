# L2bの結果（L2bc4）

L2bを完了した。L2bc3で保存したFailの接続を正式なモデルへ取り込み、主な三性質と全読者へ接続した。指定したworkの三単位はすべて成功し、既定のlake buildがsorryなしで通った。

- 基準B: `635877cb2bae6b5384b455d4576cb10389ad3836`。開始時はclean。2026-10-17着手、2026-10-18記録、担当Codex。
- コミット・docs/todo・Rustのソースは変更していない。既存のassert・期待値・ignoreも変更していない。
- R51〜R53のレビュー対応とQの接続は開始版に含まれている。RV2-L2aの全指摘を読み、対応済みの契約に沿って続行した。
- R57を設計者の了承として更新し、`sat_unconstrained` 一つを正式な仮定へ追加した。`Release/Model.lean`もこれを満たす。公理・ほかの組み込みの仮定・主な定理の外側の前提と結論は追加・変更していない。

## 今回できたこと

- OpRef.fail・Val.raise・Clause.fail、Fail節の第七判断、C_Handle_Fail・K_Handle_Fail・E_OpFailとstepを正式に接続した。型束縛はT一つ、値束縛は利用不能の0番とエラーの1番とし、通常節はFailを受けない。
- 七判断のrename/store、Qの単調性、型・値の置換、整形式・範囲・名前、noneの位置の置換不変性を拡張した。
- FailureBase/FailureContで、K1のFailの伝播、Fail用の継続の分割と保存、捕捉する生のエラー型の一致 `E′ = E` と `v : E` を証明した。Releaseに単一Failを課さず、捕捉安全・型の一致を外部の仮定にしていない。
- PresFailureで、空制約の成立からTだけを具体化し、エラー値を置換した節本体に型を付けた。保存継続のcap=`norm (Rest ∪ ec)`、CellOkとストア更新、dropのStateの条件、閉じた状態の保存をつなぎ、preservationE/進行/エフェクト健全性/step_soundへ接続した。
- 表層の性質1と検査器の健全性11件・元のプログラム全体の健全性、網羅性の保証の外側の言明を保ち、既存読者の新構成子の場合分けとwithReturnの相互帰納を補った。
- FailureExamplesで通常のmatch/handleによるfromResult/toResultの四つの有限遷移、二構成子の型付け、両変換本体の型付けを示した。捕捉する例の最終ストアはusedセルを含む。既存の期待を変更した箇所はない。
- 01-12に構文・七判断・捕捉と保存継続の規則を写し、07-04に仮定と証明の対応を反映した。l2a/statementsの仮定の説明もR57に合わせた。

## 計画からのずれと申し送り

R58でL2bc4をL2bの続行として開始版と再開方法を固定し、planにも記した。R59の範囲で、新しい値の分類canonical_fn_or_raiseを加え、従来の補助canonical_fnはraise以外という前提のもとで元の結論を保つ。通常のハンドラだけを扱う反転・分割にはその条件を渡し、種類を問わない末尾の反転は別の補助へ分けた。主な定理の結論を弱めていない。

現行の交換形式にないFail操作・節の書き出しは明示したエラーで拒否する。通常の変換は保ち、新形式の欄と読者・書き出しは計画どおりL4bへ残す。L2cへは表層のFail節・具体化後の単一Fail・最小効果と正負例を引き継ぐ。Rustの処理系への新規則の接続は後のF作業である。

**failure-integration.patchは正式なツリーへ適用済みであり、次回は再適用しない。** q-integration.patchも以前の取り込み済みである。旧反例二つはR57承認前の仮定についての診断記録として保存し、現在の仮定を満たす例とは扱わない。後続作業は今回の正式なツリーから開始でき、退避した実装の残りはない。

## 検査

途中は変更に関係するLeanモジュールを直接ビルドした。Failの基礎・捕捉安全・具体化・保存定理・進行・step_sound・表層の脱糖と検査器の健全性、四例と型付けが局所ビルドで成功した。執筆中は、新構成子の未網羅、暗黙引数・閉じた型の恒等式の位置、相互帰納の停止性の指定漏れを修正した。有限遷移の例では既存のE_DropとE_DropRelを区別し、格納済みの未使用継続を解放してusedセルを残す既存の規則へ証明を合わせた。期待する結果はL2aの四例から変更していない。

作業末はplanのwork L2bの三単位だけを一度実行した。Rustのソースを変えていないためlib全件・clippy・fmtは追加しない。check.shの全体・gc-stress・check-formal.shの全比較は実行せず、後の計画の区切りへ残す。

| コマンド（リポジトリの根。公理依存はformal/から） | 終了状態 | 外側の時間・結果 |
|---|---:|---|
| `scripts/check.sh --level work --base 635877cb2bae6b5384b455d4576cb10389ad3836 --only formal_build,spec_examples,spec_tally --dry-run` | 0 | ツール表示で1秒未満。名指しの三単位だけを選択 |
| 上記から`--dry-run`を外した指定 | 0 | monotonic時計で23.791秒。仕様例7件、spec_tallyの自己検査と集計、既定のlake buildとsorryの拒否が成功。l2bc4-work-check.logへ保存 |
| `lake env lean /private/tmp/benitoite-l2bc4-axioms.lean` | 0 | monotonic時計で0.624秒。主な三性質・step_sound・捕捉安全・Failの一歩の保存・Model・性質1・プログラム全体と健全性11件の公理依存はpropext・Classical.choice・Quot.soundだけ。l2bc4-axioms-check.logへ保存 |
| `git diff --check` | 0 | ツール表示で1秒未満。空白の誤りなし |

差分の空白検査は、保存patchにあったRenameの空行の行末空白を検出したため、その空白だけを削除して再確認した。型・定理・証明本体のトークンは変えていない。

公理依存の確認は最初にcheckProgram_soundの名前空間をCheckと誤記して失敗した。実際のCheckTablesへ修正して再検査し、上表の成功を得た。正式なLeanのソースや定理の言明を変えた失敗ではない。

Lean本体・補助（例以外）の差分は追加1001行・削除77行、例（新しいFailureExamplesと既存Model）の差分は追加182行・削除0行である。新規Leanファイルを含む。既存の例は新構成子の場合分けと承認済み仮定の充足を補っただけで、主張や期待値は変えていない。

---

# L2bの結果（L2bc3、空制約の法則について設計者に相談）

設計者に相談。依頼の停止条件であるBuiltins.Assumptionsの追加を要する反例をLeanで確認したため停止した。L2b全体は未完である。正式なモデルは開始版の規則へ戻し、未完のFailの接続はpatchへ保存した。停止理由と推す法則はdecisions.mdのR57に記した。

- 基準B: `6b2c2afd29888978a03e319fc7ee050cf943043b`。開始時はclean。2026-10-17、担当Codex。
- コミット・docs/todo・Rust・既存のテストと期待値は変更していない。公理・Builtins.Assumptions・主な定理の言明も変更していない。
- 前回のQの接続は開始版に含まれる。古いq-integration.patchを再適用しない。

## 正式なツリーに残したもの

`Release/FailureEffects.lean`に `Eff.substAt_singleFail` を証明し、Benitoite.leanから既定ビルドへ含めた。型と行の代入がFail内部の型の代入と一致し、正規化も保持する。新しい構文・型付け・実行規則は正式なツリーへ入れていない。

## 保存した接続と局所の証明

`failure-integration.patch` は、上記の正式なツリーへ適用する18ファイル・68765バイトの未完の差分である。SHA-256は `2bb16e17661ea830df04078adc6041ae75b8db946f0ab2a62b186ed82d3b3c84`。対象は `failure-integration-files.txt` に記した。正式なツリーへ戻した後の `git apply --check` は終了0だった。この差分全体の既定ビルドは未達であり、局所の成功を取り込み済みの保証として引用しない。

- OpRef.fail・Val.raise・Clause.fail、T一つの型代入、値束縛二つのrename/subst、型の範囲の走査、七判断の型付け、K_Handle_FailとE_OpFail、stepの対応する場合を追加した。
- 七判断についてrename/store、Qの単調性、値置換、型置換、外側の型束縛、noneの位置の置換不変性、名前と型の範囲・WFを接続し、該当モジュールの局所ビルドを通した。通常節のFail禁止はopSigから導く（R56）。
- FailureBaseで、Fail節の形、resumeに予約した0番の置換不変性、通常節とhandledのFail不在、保存上限 `captureEff Rest ec`、空の末尾とFail枠、dropのState条件を証明した。
- FailureContで、Failを捕捉しない継続全体の所属伝播、選ばれた枠の手前K1の伝播、Fail用の分割と保存継続、raiseの反転、`failure_clause_selected_typed` の `E′ = E ∧ v : E` を証明した。型の比較・捕捉安全・Releaseの単一Failを前提に加えていない。
- ContLemmasのstore・name_end・resume_append・framesOkにFailの場合を追加し、通常節のsplitは中間のFail枠も復元するようにした。値・escape・停止を外へ返す共通の反転も証明した。

残りは、具体化したFail節の本体の型付け、保存継続のCellOkとストア更新の実際の遷移への接続、PresMain/Progress/EffectSound/StepSound等、全読者、fromResult/toResultの四例、01-12・07-04の写しである。Canonical・StoreLemmasなどの新しいraiseの場合と、通常節の反転に追加した条件の呼び出し側も未接続である。L2cの表層のFail節・単一Fail・最小効果はR52どおり後に残る。

## 停止の根拠と判断後の再開手順

`failure-constraint-obstruction.lean` は開始版の規則でも読める反例である。既存のBuiltins.Assumptionsを満たす組み込みのモデル、整形式・型付き・効果の整合した通常関数f、開いたTでの `f[T]` の型付け、任意の閉じた具体型での `f[具体型]` の型付けの不可能性を証明する。`failure-preservation-obstruction.lean` は保存差分のモデルを必要とし、型付きの閉じたFailの状態がE_OpFailの一歩で型を失うところまで証明する。後者は未適用の正式なツリーでは検査対象にしない。局所の検査記録は `l2bc3-local-check.log` である。どちらもsorryを含まず、後者のpreservation_counterexampleの公理はpropext・Classical.choice・Quot.soundだけである。

推す追加は `sat_unconstrained : ∀ t, Ty.WF 0 t → B.sat [] t ({} : TParam)` である。未了承なので実装していない。反例の解釈は `B.sat C t p := p.key = true ∨ p ∈ C` であり、既存のsat_substは空制約が成立することを導けない。これは実際のRustの空制約判定の失敗ではなく、抽象的な仮定の不足である。

1. まずR57の法則を加えるかの設計者の判断を得る。判断前に仮定・規則・主な定理を変更しない。
2. 承認された場合、`git apply --check` でfailure-integration.patchを確認してから適用する。FailureEffectsは正式なツリーに既にあるので作り直さない。
3. 承認された法則を仮定と具体的なモデルの両方へ接続し、閉じたTのWFから `SatAll B [] [T] [{}]` を導く。HasFailureClauseの本体へTだけを代入し、noneの0番には型付きの継続を与えず値置換する。
4. 上記の残りを終え、主な三性質・性質1・健全性11件・全読者を含む既定のビルドを通す。現行設計には正式に取り込んだ規則だけを写す。

## 検査

途中は関係するLeanモジュールだけをビルドした。最後の差分の局所検査はFailureCont・TySubstMain・Namesが終了0、1.084秒、保存の反例の検査は終了0、0.404秒だった。前者は七判断の基礎と捕捉安全までの確認であり、保存の主要定理の成功ではない。執筆中には新構成子の未網羅、帰納法の引数順、noneの位置を持つ環境の等式、リストのdropの補題の選び違いを修正した。

保存状態のworkの結果は、下表へ記録する。これもL2b全体の完了を示さない。

| コマンド（リポジトリの根。Leanの反例だけformal/から実行） | 終了状態 | 外側の時間・結果 |
|---|---:|---|
| `scripts/check.sh --level work --base 6b2c2afd29888978a03e319fc7ee050cf943043b --only formal_build,spec_examples,spec_tally --dry-run` | 0 | ツール表示で1秒未満。名指しの三単位だけを選択 |
| 上記から `--dry-run` を外した指定 | 0 | monotonic時計で25.943秒。仕様例7件、spec_tallyの自己検査と集計、既定のlake buildとsorryの拒否が成功。l2bc3-work-check.logへ保存 |
| `rtk proxy lake env lean ../docs/2026-10-17-TODO-063_087_189_191_249_255-check-policy-and-syntax-batch2/l2b/failure-constraint-obstruction.lean` | 0 | 保存状態のモデルで0.547秒。既存の仮定を満たす反例のモデルと通常の関数の証明。l2bc3-constraint-check.logへ保存 |
| `git apply --check` とfailure-integration.patchのパス | 0 | ツール表示で1秒未満。保存状態への再適用が可能 |
| `git diff --check` | 0 | ツール表示で1秒未満。空白の誤りなし |

Rustを変えていないのでlib全件・clippy・fmtは追加しない。gc-stress・check.shの全体・check-formal.shの全比較は実行しない。

## 診断用の具体例の作成時の関門

1. 守る契約は、空制約を持つTの具体化で型が保たれるために、抽象的な組み込みの仮定が十分かである。
2. 既存のsat_substだけで閉じた空制約の成立を導けると誤認して、証明の前提を隠す退行を捕まえる。
3. 既存のModelはsatを常にTrueとするため、この不足を検出できない。今回の反例は既存の仮定をすべて満たす別のモデルと、具体的な一歩を使う。
4. 診断は既存の型付けと実行規則だけを呼ぶ。テスト専用の差し込み口や本番コードの分岐を加えず、既存のassert・期待値は変更しない。test-auditの原則に従い、この反例のために本番の仮定を無断で足さない。

---

# L2bの結果（L2bc2でQの接続まで、未完）

区切りで止めて報告する。今回の続行ではQをRelease・表層・脱糖・検査器へ接続した。残りの文脈では、Failの七判断・継続・ストアの一まとまりの変更を既定ビルドが通るところまで収められないため、この正式な状態で保存する。L2b全体の完了は主張しない。

- 基準B: `6ccab143d78171757ac1fd840a5cf0dcd00a3479`。開始時の作業ツリーはclean。
- 日付: 2026-10-17。担当: Codex。コミット・docs/todo・Rustの変更はしていない。
- 判断: decisions.mdのR55。planに独立したL2bc2節がないため確認を出し、回答がない間は申し送りのL2bの続行手順を採った。R51〜R53のレビュー対応は開始版に含まれている。
- **以前のq-integration.patchは今回の正式なツリーへ適用済みである。次回は再適用しない。** 未完の差分をpatchへ退避する変更は今回はない。

## 今回できたこと

- Releaseの六判断をQ付きにし、V_Fun・V_Prim・C_MethにAdmissible等を接続した。値と型の置換、Qの単調性、閉じた値の一般化、既存の進行・保存・エフェクト健全性・step_sound・Modelまで証明を移した。これは前回のpatchと今回の呼び出し側の接続を一緒に正式な状態へ残したものである。
- Surfaceの七判断もQをパラメータにした。関数・辞書付きの関数・組み込み・メソッドの値化で具体化の条件を渡し、通常の呼び出し・部分適用・パイプ・辞書・文字列補間・try/dieを含む全構文の脱糖と、プログラム全体の型保存を証明した。辞書引数を加えても署名のQが等しいことをNoFailSignatureで示した。
- AdmissibleCheckで、失敗型の内部までの行の範囲、型と行の像の整形式・個数、NoFailの移送を計算し、判定の成功から通常関数・組み込み・メソッドの条件を導いた。
- 検査器の内部入力のnoFailRowsに同じQを保持した。checkDefは元の宣言から、実装メソッドは型クラスの元の署名からQを計算する。従来の式の入口は空Qに設定する。Input.SoundへNoFailの仮定を追加せず、健全性11件・元のcheckProgram_sound/emptyの外側の言明を保った。
- 公開するcheckExpr/checkDefの例で、印付きの行へのFailの拒否、通常の行多相の受理、宣言のQの本体への受け渡し、外から指定したQを式の入口で破棄すること、不足するQを本体から増やさない拒否の経路を確かめた。既存の例は同じ言明を強めた規則から導くように証明だけを更新した。既存のassert・期待値・ignoreを弱めていない。
- 01-12と07-04の写しを、実装済みのQ・Admissibleと検査器の接続に合わせた。未実装のFail捕捉規則は写していない。

形式化の本体と補助は追加2362行・削除1663行、例は追加54行・削除6行である（git diffの行数と未追跡の新規Leanファイルを集計）。例の削除6行は既存の証明の置換であり、例自体の削除ではない。新しい例の作成時の四問は末尾に保存している。

## 残りと次回の続行手順

1. 今回の正式なツリーを開始版にする。Qのpatchを適用する工程は完了した。`l2a/statements.md`の「Fail操作・一つの型束縛・ハンドラ」以降から再開する。
2. OpRef.fail・Val.raise・Clause.fail、HasFailureClause、C_Handle_Fail・K_Handle_Fail・E_OpFailを追加する。Releaseの六判断の補助を第七判断と新しい場合へ広げる。型の代入はT一つだけ、値の環境の0番は予約したnoneとし、任意のnoneの位置の置換不変性を新判断へ広げる。
3. 選んだFail枠の手前K1でのFailの所属伝播と、捕捉したE′=E・v:Eを導く。継続の分割・保存継続・CellOk・解放・resume禁止を接続し、既存の主な三性質とstep_soundを新しいFailの場合について証明する。捕捉安全・E′=E・Releaseの単一Failを仮定にしない。
4. 通常のmatch/handleによるfromResult/toResultの四つの有限遷移と型付けを加え、01-12・07-04の写しをそろえる。L2cに残すFail節・単一Fail・最小効果の検査との分担はR52どおりである。
5. 主な定理の前提か結論、新公理、Builtins.Assumptions、既存の定理の結論の弱化を要する場合は、依頼文の停止条件に従って設計者へ相談する。今回その変更を要する問題は見つかっていない。

## 今回の検査

途中は変更したLeanモジュールだけを対象にした。`Surface.Theorems`、`Surface.CheckSound`（健全性11件）、`Surface.CheckProgramSound`、`Surface.Examples`、`Surface.CheckExamples`、`Surface.CheckCounterexamples`、`Benitoite`のライブラリ全体が成功した。最後の公開入口の例と宣言の整形の後にはCheckExamplesの依存を再検査した。途中の局所ビルドでは外側の時間を採取しておらず、別状態への結果の引用には使わない。

途中の失敗は、Qの新引数と構成子の引数数の接続漏れ、具体例の空Qの等号、定義のQを計算する入口の証拠不足、既存のInputの位置引数の不足を修正した。CheckExamplesの新しい入力の構造体更新の構文を直し、Exceptの等号の例は既存の例と同じrflで証明した。期待する受理・拒否と経路は変えていない。誤ってリポジトリの根からlakeを起動した2回は`Operation not permitted`で終了し、その後はformalを作業ディレクトリに固定した。

検査の指定はplanのwork L2bと同じ名指しを、今回の開始版Bへ固定した。以下はQの接続までの保存状態の検査であり、L2b全体の完了を示さない。

| コマンド（リポジトリの根） | 終了状態 | 外側の時間・結果 |
|---|---:|---|
| `scripts/check.sh --level work --base 6ccab143d78171757ac1fd840a5cf0dcd00a3479 --only formal_build,spec_examples,spec_tally --dry-run` | 0 | ツール表示で1秒未満。三単位だけを名指し |
| 上記から`--dry-run`を外した指定 | 0 | Pythonのmonotonic時計で22.066秒。仕様例7件、spec_tallyの自己検査と集計、既定のlake buildとsorryの拒否が成功。l2bc2-work-check.logへ保存 |
| `git diff --check` | 0 | ツール表示で1秒未満。空白の誤りなし |

Rustの変更がないためlib全件・clippy・fmtを追加していない。gc-stress・check.shの全体・check-formal.shの全比較も実行していない。既定のlake buildは上表のformal_buildが担当する。

---

# 前回のL2bの結果（履歴。以下の再適用手順は今回の続行で実施済み）

区切りで止めて報告する。L2b全体は未完である。文脈の残量により、Qの接続を差分へ保存し、正式なツリーは既定のlake buildをsorryなしで通せる前提の補助までに戻した。Failの捕捉安全を仮定に移して完了したことにはしていない。

- 基準B: `aa6f061e013d00cd08b66c74f3c4ec6cc0761b39`。開始時の作業ツリーはclean。
- 日付: 2026-10-17。担当: Codex。コミット・docs/todoの変更はしていない。
- 判断: decisions.mdのR51〜R54。RV2-L2aの全指摘を先に反映した。

## 正式なツリーへ残したもの

- `BuiltinOnly` に了承済みの `ε.fails = []` を加え、旧来の名前の所属の利用は第二射影へ直した。空効果の証拠と01-12・07-04の写しを合わせた。effect_soundnessの前提と結論、Builtins.Assumptionsは変えていない。
- `Release/NoFail.lean`: 署名全体を辿るQsig、NoFail、RowTransport。署名の範囲、正規化・型移動との一致、任意cutoffの代入保存、範囲付きの列のmapと一般の代入の合成、Fail上限とCanonicalからの生のエラー型一致を証明した。
- `Release/Admissible.lean`: 型引数の制約・範囲・行数とNoFailの像を合わせた全具体化の条件。通常関数・組み込み・メソッドの条件、Qの単調性、行パラメータがない場合の証拠を置いた。正式な型付け判断がこの条件を消費する変更はpatchにある。
- `Release/Lemmas/Irrelevant.lean`: 型のある環境の位置で二つの値置換が一致すれば、その項への置換結果が等しいことを既存の六判断の相互帰納で示した。任意のnoneの位置の置換不変性を導いた。新しいHasFailureClauseの第七の場合は未実装である。
- `Surface/NoFailCheck.lean`: 宣言の行数個のBoolからなるQ、NoFailと行の像の計算。支持と範囲の条件から宣言的な条件との一致を証明した。既存のcheckExpr等への呼び出しはpatchにもまだ含まない。
- `Surface/NoFailCheckExamples.lean`: 署名の引数・結果・Fail内部の走査、異型Fail・未供給の像・未承認の行の拒否、Stateと承認済みの行と通常の行多相の受理を確認した。
- `Benitoite.lean` から上記をimportし、既定のビルドに含めた。補助の意味だけを現行の写しへ追記し、未実装の捕捉規則は写していない。

新規のLeanの補助は711行、具体例は54行である。既存のテスト・assert・期待値・ignoreは削除も緩和もしていない。Rustは変更していない。

## 保存したQの接続

`q-integration.patch` は上記の正式なツリーに適用する未完の差分である。37ファイル・4707行、SHA-256は `8d4917e67b31df319039bf73ce849b55cdf1c99bf0f065ee76cddd953ec87835`。対象の一覧は `q-integration-files.txt` にある。

差分は、Qを判断のパラメータにする内部版と空Qの別名、V_Fun/V_Prim/C_MethのAdmissible、署名のQでのDef/Implの検査を含む。rename/store/hide、WF・反転・名前、外側の型束縛、値置換、型置換をQ付きにした。閉じた値は空Qから任意のQへ単調性で移す。型代入の呼び出し側・メソッド側のNoFailは、範囲付きの行の合成で保存する。Releaseの既存の進行・保存・エフェクト健全性とstep_sound、Model/Examplesまで局所ビルドが通った。

脱糖の補助では、Q付きのCompTypesとCallHead.HasType、sequence・引数の配置・辞書の値化を接続し、対応する局所ビルドが通った。Surfaceの七判断・CallHead以降の脱糖の接続・checkerは残る。保存したpatch全体の既定ビルドは通ると主張しない。正式なツリーへReleaseだけを取り込まないR52の条件を守るため、この差分は未適用である。

## 残りと次に続ける手順

1. リポジトリの根で `git apply --check docs/2026-10-17-TODO-063_087_189_191_249_255-check-policy-and-syntax-batch2/l2b/q-integration.patch` を確かめ、同じ引数から `--check` を外して適用する。現在の保存状態についてcheckが成功することは確認済みである。
2. `l2a/statements.md` とR51〜R54を読み、Surfaceの七判断をQのパラメータ付きへ一般化する。通常関数・組み込み・メソッドの呼び出しと値化にAdmissibleを渡し、CallHead等の補助へ接続する。Def/Implの入口は元の署名のQとし、型クラスの対象を具体化してQを取り直さない。
3. checkerの内部版へ計算用Qを渡し、宣言の入口でsignatureQを計算する。既存の公開する式の入口は空Qのwrapperとし、健全性11件・元のcheckProgram_sound/empty・脱糖の型保存の外側の言明を保つ。q.Soundへ未検査のNoFailを追加せず、今回の判定の証明を使う。型と行の範囲は既存のWF/VarsIn・Scopedから導く。
4. Fail専用のOpRef/Val/Clause、HasFailureClause、C_Handle_Fail/K_Handle_Fail、E_OpFailを追加する。既存の六判断の補助へ新しい場合と第七判断を加える。Tだけの型代入、予約したnoneの0番、capのRestとecの両方の包含を保つ。
5. 選んだ枠の手前K1でのFailの所属伝播、E′=Eとv:E、分割・保存継続・CellOk・解放、resume禁止、Failの進行・保存・エフェクト健全性・step_soundを証明する。今回のfailure_upper_boundは上限の補助だけであり、failure_clause_selected_typedは未証明である。
6. 通常のmatch/handleによるfromResult/toResultの四つの有限遷移と型付け、01-12・07-04の写しをそろえる。L2cのFail節・単一Fail・最小効果・正負例との分担はR52どおりとする。正式な取り込みは既定のlake buildをsorryなしで通す単位にする。

主な定理の前提・結論、公理、Builtins.Assumptionsの変更を要する問題は、今回の続きでは見つかっていない。R51以外の変更を要するときは依頼文の停止条件に従う。

## 検査と失敗の修正

途中は対象のLeanモジュールだけをビルドした。新しい構成子の引数数とQemptyの別名の混同、型代入のRowTransportの不足、行パラメータのない組み込みを組み立てる証拠の不足を修正した。Qを接続した状態で次が成功した。

- `cd formal && rtk proxy lake build Benitoite.Release.NoFail`
- `cd formal && rtk proxy lake build Benitoite.Release.Admissible Benitoite.Surface.NoFailCheck`
- `cd formal && rtk proxy lake build Benitoite.Release.Lemmas.Irrelevant`
- `cd formal && rtk proxy lake build Benitoite.Release.Lemmas.Canonical`
- `cd formal && rtk proxy lake build Benitoite.Release.Theorems`
- `cd formal && rtk proxy lake build Benitoite.Release.Model` と `Benitoite.Release.Examples`
- `cd formal && rtk proxy lake build Benitoite.Surface.NoFailCheckExamples`
- `cd formal && rtk proxy lake build Benitoite.Surface.Lemmas.Calls` と `Benitoite.Surface.Lemmas.DictSupport`

`Benitoite.Surface.Theorems` の局所ビルドは、Qの接続途中のCallsでC_Methの追加前提を作れず停止した。その箇所はCallsのQ付きの一般化で直し、Callsの局所ビルドを通した。CallHead以降とcheckerは未接続のままである。上記の執筆中の局所ビルドでは、外側の全経過時間を採取していない。取り込み済みの結果としての引用には使わない。

保存状態の検査は、計画のwork L2bと同じ基準・指定でdry-runを確認した後、一度だけ実行した。記録は `work-check.log`。この結果は正式なツリーの保存状態の検査であり、未適用patchやL2b全体の完了を示さない。

| コマンド（リポジトリの根） | 終了状態 | 外側の時間・結果 |
|---|---:|---|
| `scripts/check.sh --level work --base aa6f061e013d00cd08b66c74f3c4ec6cc0761b39 --only formal_build,spec_examples,spec_tally --dry-run` | 0 | ツール表示で1秒未満。名指しの三単位だけを選択 |
| 上記から `--dry-run` を外した指定 | 0 | Pythonのmonotonic時計で89.816秒。spec_tallyの自己検査と集計、仕様例7件、既定のlake buildとsorryの拒否が成功 |
| `git apply --check` と前掲のpatchのパス | 0 | ツール表示で1秒未満。未適用の正式なツリーへの適用可能性だけを確認 |
| `git diff --check` | 0 | ツール表示で1秒未満。空白の誤りなし |

Rustの変更がないためlib全件・clippy・fmtを追加していない。gc-stress・check.shの全体・check-formal.shの全比較も実行していない。planのL2bの完了条件であるE′=Eとv:Eの導出、Failの実行例は未完である。

## 具体例を加える前のtest-audit

1. 守る契約は、署名の字面から得るQと、行の像がcallerのNoFail条件を満たすかという判定の境界である。
2. 型の内部の走査漏れ、通常の行の過剰拒否、未供給の像・未承認の行の受理を退行として捕まえる。
3. 既存のFailの例は正規化・型代入・比較を対象とし、この新しいNoFailの判定を呼んでいない。一般の一致定理に加え、手で選んだ受理・拒否例で計算できることを確認する。
4. 本番用の判定を直接呼び、新しい差し込み口やテスト用のフラグは加えない。既存の準備・期待値は変えていない。

## L2bc2続行中: 公開する検査入口の具体例を加える前の関門

1. 契約は、署名だけから得たQが定義本体へ渡り、呼び出しの具体化で検査されることである。公開するcheckExprは空Qを使い、checkDefは宣言のQだけを使う。
2. 捕まえる退行は、呼び出しでNoFail検査を呼び忘れること、定義のQを本体へ渡し忘れること、本体からQを増やすこと、通常の行多相の過剰拒否である。
3. 既存のNoFailCheckExamplesは計算用の判定だけを呼んでおり、検査器の名前参照・定義の入口の接続を通らない。CheckExamplesの表で、印付きと通常の署名、および呼び出し先と呼び出し側の印の組合せを確かめる。
4. 新しい差し込み口は作らず、既存のCheck.Input・checkExpr・checkDefを使う。既存例の言明・assert・期待値は弱めない。


## L2bc4: 有限遷移の四例を加える前の関門

1. 守る契約は、通常のmatch/handleによるResultの成功・失敗の変換と、Fail捕捉後のdropによるusedセルである。型付けも同じ構成子宣言に対して確認する。
2. raiseの引数と予約した継続の位置の取り違え、Fail節の型束縛数の取り違え、最内節の選択やdropを省く退行を検出する。
3. 既存の例には新構成子raise/Fail節がなく、QとNoFailだけの判定例では実際の有限遷移と最終ストアを検査できない。四例はL2aでレビューした契約そのものを使う。
4. 公開するStep/StepsとHasTypeCを使い、専用の実行規則・本番の差し込み口は追加しない。既存のassert・期待値は保つ。
