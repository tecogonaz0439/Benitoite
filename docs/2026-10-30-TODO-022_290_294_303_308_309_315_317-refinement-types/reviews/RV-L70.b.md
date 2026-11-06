# RV-L70.b: L70 群 B（L70.09〜.16、主定理）の独立レビュー

2026-11-06。対象はブランチ `m014/l70.b` の未コミットの作業木である。基準は `49f17471442229baf668e7b1f7b6dac8151c6dcf` で、HEAD と一致する。本書の `<repo>` は対象の worktree、`<tmp>` は指定の scratchpad、C は本書を置く改造ディレクトリ、R は `<repo>/formal/Benitoite/Release/Refinement/` を表す。本レビューは群 B の本レビュー一回であり、再レビューは重・中の処置の確認に限って一回とする。

読んだもの:

- 依頼 `<home>/src/Benitoite/work/m014/L70.b-prompt.md`、[担当の報告](../l70/b/results.md)の初回と「再開1」、[修正案](../l70/b/effect-fix.md)、[反例](../l70/b/effect-counterexample.lean)。記録の構成は [RV-L60.g](RV-L60.g.md) の初回部分に倣った。
- `l70/detail.md` の第2.2節・F01・F02、L70.09〜.16 と群 B の完了条件、`l60/stage-results.md` の旧主定理12件との対応と受け口、`l70/a/results.md` の中2の申し送り、RV-L70.a の該当所見。U02 S13 は `u02/decisions.md` と照合した。
- 本体の作業木にある未コミットの最新版の plan.md。「全 L 作業の停止条件」と「計画の変更と取りまとめへの確認点」の先頭にある群 B への判断四点を正とした。エフェクトの健全性の群 K への移管、一段の対象健全性への二前提の追加、L60-H02・L50-H01 の完了判定、既存二モジュールの `private` の削除は承認済みとして扱った。目的と保証の範囲は 00-01 で確認した。
- `git diff 49f17471 -- formal docs/design` の全差分と、新規五モジュール MainProgress・MainStepSound・MainTargets・StartLamNames・MainTheorems の全文。参照先の MainStatements・Ground・Typing・StateTyping・Semantics・Step、保存の入口、閉包の型付けと実引数の逆転、組込みの形・応答・効果・対象の条件、ハンドラの契約と探索、旧主定理・旧開始の補題も照合した。
- `l70/b/verify.py`・axioms.lean・readers.lean と各入力 JSON・audit-summary.json、`<tmp>/l70b/` の build.log・axioms.log・readers.log。記録の照合台本は読み取りだけとし、実行していない。

リポジトリ内で変更したのは本書だけである。git の書き込み操作、`lake build`・cargo・`scripts/check.sh` は実行していない。Lean は `<repo>/formal/` から `lake env lean -M 12288 <file>` で一つずつ実行し、`-o` は使っていない。確認用ファイルとソースの写しは `<tmp>/rv-l70-b/` に置いた。大きな具体値を作る評価はしていない。担当が保存した既定ビルドの成功と、本レビューで実行した単独 Lean・公理監査を区別した。

## 結論

**条件付き可**（重2・中0・軽0・情報1）。

エフェクトの健全性を除く八つの主定理は、群 A の言明と今回承認された前提の範囲で閉じている。状態・実行列・応答を代表例に限定した証明、旧主定理への置換、新しい公理・sorry、型付けや Step の規則への未承認の変更は見つからなかった。L60-H02・L50-H01 の完了理由と `private` の削除も受け入れられる。

条件は、群 K に渡す案 D に S13 を満たす処置を具体化すること（重1）と、noLamNames の接続を申し送りどおり全閉包・捕捉・入れ子へ広げること（重2）である。エフェクトの健全性の未了は取りまとめが群 K へ移した事項として情報1に分ける。現在の成果を、detail.md の「五つの主定理と noLamNames を閉じた」という群 B 全体の完了条件の充足とは判定しない。

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 重1 | 重 | `l70/b/effect-fix.md` 第2節17・38行、第5節75行。本体の最新版 plan.md の群 B への判断(1)。関係する本番は `R/Semantics.lean` 95・313行、`R/Step.lean` の pathBases 分岐 | `handled` だけを変える案 D は、反例の空効果での受理を断れるが、S13 の「発行を Environment の操作にしない」を満たさない。Process.Environment を外へ残した型付きの handler は引き続き書け、発行の適用は `E_OpPrim` で節へ移る。担当は残る問題を明記しているが、取りまとめの「実行の規則は変えず、案 D が S13 と健全性を同時に満たす」という受け入れ条件との不整合が未処置である | 群 K の受け入れ対象を、効果の非除去と発行の適用の扱いの両方へ具体化し、取りまとめへ規則の差を戻す。例えば、発行の節を契約で断るか、発行の適用をハンドラ探索の対象から外す。後者では `E_OpPrim` から pathBases を除くだけでなく、`E_PathBasesApply` の `NoHandler`、`step` の探索、進行・保存・実行関数の健全性を一緒に合わせる。S13 を満たす形と、承認が要る変更を明記する | 読めば確定。検査3で案 D の非所属、効果を残す C_Handle の前提、型付きの呼出しと handler、実際の `E_OpPrim` を確認 |
| 重2 | 重 | `R/StartLamNames.lean` 24・31・38・59・297行、`l70/b/results.md`「主な言明の結果」「計画からのずれ」、07-04 の追加段落。要求元は `l70/a/results.md`「中2: L70.14・.15 への申し送り」 | 接続は `Closure.pure m` に限られ、`ClosedNoLamNames` は At・実行時閉包・保持要求の内部で元の `ClosedAt` に戻る。従って、それらの内部の名前は型付けから供給する証明の対象にならず、前提の中に残る。全閉包・捕捉・入れ子について同じ開始条件へ接続するという群 A の申し送りを満たしていない。「接続は閉じた」という完了判定は広すぎる | 名前だけを除いた閉じ方を必要な内部まで定め、型付けから元の閉じ方を得る証明を閉じる。既存の `CaptureOk` の Ground や要求の groundVal から閉性を得られる部分はその証拠を使い、名前を別の信頼条件にしない。任意の型付き開始閉包へ接続する入口を置く。現定義を補助として残すなら、全体の名前なしの条件から現条件への接続を型付けの下で別に証明する。報告と写しを実際の到達範囲に合わせる | 範囲の不足は読めば確定。検査3で実行時閉包の内部の `NamesWF` を現前提から射影できることを確認。型付きプログラムが実際に除外される反例や、現補題の偽を示した所見ではない |
| 情報1 | 情報 | `R/MainStatements.lean` 87行の `EffectSoundnessStatement`、`l70/b/effect-counterexample.lean`、results.md「再開1」 | 現言明は実際に偽であり、担当の停止と群 K への移管は妥当である。八定理の成功と noLamNames の部分的な接続から、エフェクトの健全性まで証明済みとは扱えない | 群 K で、同じ言明を全事象・全継続について閉じ、noLamNames の完全な接続と合成する。反例の入力を単に Source 制限で排除したり、pathBases の事象を結論から除いたりして完了にしない | 検査1・3で `¬ EffectSoundnessStatement program Model.builtins σFull` を確認。移管済みの事項であり、新しい停止の要求ではない |

## 観点ごとの根拠

### 1. 八つの主定理と全場合の量化

MainTheorems の定理はすべて、MainStatements の命題そのものを結論とする。P・B・σ は任意であり、内部の状態・遷移・事象・実行列・実引数・観測も全称のままである。具体のモデルを使う三つの適用例は前提の充足の証人であり、全称定理の代用になっていない。

| 言明 | 証明と前提の読み方 | 判定 |
|---|---|---|
| `ProgressStatement` | `R.progress` → `StateTyE.progress`。WF・WT・EffectsOk・Core と StateTy が持つ有効 σ・BuiltinOnly を読む | 全状態について閉じている |
| `PreservationStatement`・`StepsPreservationStatement` | `R.preservation`・`steps_preservation` → 前段の `step_preserved`・`steps_preserved`。WF・WT・EffectsOk・Core を同じ形で渡す | 同じ σ・同じ Eb を保持する。前段の76遷移を再定義していない |
| `StepSoundStatement` | `R.step_sound` → `StateTyE.step_sound`。WF・WT・Core・StepSelection の四条件を読む | 選択条件を満たす任意の実行関数の、計算から関係への向きを保つ |
| `InitialTypingStatement` | `R.initial_typing`。任意の q・a・ε の ClosureTy と StartCondition から空ストア・空継続の StateTyE を構成する | 任意の ε で閉じている。命題が持つ WF・WT・Core はこの証明では使わず、追加の信頼条件もない |
| `StepTargetStatement` | `R.step_target_sound` → `StateTyE.io_target_sound`。WF・WT・EffectsOk・Core・TargetAgreement と状態の型付けを読む | 再開1で承認された WF・WT の追加だけで閉じている。命題の σ.Valid は証明では使わない |
| `ReachableTargetStatement`・`ReachableTargetEventStatement` | `R.reachable_target_sound`・`reachable_target_sound_event`。開始から同じ ε のまま列の保存を使い、一段の対象健全性へ渡す | 初期の効果と同じ σ で観測を許す結論を保つ |

進行は State の四構成子を場合分けし、run では Comp の全構成子、app では `canonical_function` の八形を読む。型の付かない残りの頭の値は正準形の定理で除かれる。ret・escape・error・exit は継続の枠をすべて分け、解放は正常応答だけを要求せず、解放の関係に応答が存在する条件を使う。照合の途中は網羅性と MatchPrefix から未確認の腕の存在を得ており、matchRun を終端へ加えていない。At は型付きの準備と at_step を読み、発行は σ.Valid を使う。未処理の利用者の操作と Fail は BuiltinOnly と継続の効果から矛盾させる。

実行関数の健全性は、実際の stepRun・stepMatch と error・exit の全分岐を読んでいる。IO・外部・解放の応答は、型付きの実引数と Core から応答の存在を得て StepSelection で実際の選択へ戻す。新しい場所は有限な StoreOk と fresh 条件を使う。恒等な選択だけ、空の外部宣言だけ、正常応答だけへの制限はない。逆向きの完全性は主張していない。

一段の対象健全性は、IO の正常・失敗・終了の三規則をすべて処理する。閉じた view の BuiltinArgs、保持値の適格性、同じ応答の obs を TargetAgreement へ渡し、NoHandler と EffectsOk から継続の末尾へ同じ許可を移す。到達の証明は StartCondition.prepared から σ.Valid を得ており、Ready を全状態へ追加していない。事象形は IO の場合をその定理に戻し、release・pathBases は Event.targets が空であることを使う。空の観測については定義どおり自明であり、非空の IO 観測も同じ定理で覆う。

旧主定理12件との対応は群 A の整理を保つ。旧 effect_soundness と noLamNames は一つの効果の言明と開始の接続、旧 reachable_target_sound と `_of_assumptions` は Core と TargetAgreement を分けた同じ到達の言明、旧三モデルの assumptions 三件は群 C の L70.19 の担当である。一段の対象健全性の二前提の追加は取りまとめが明示的に認めた変更であり、黙った署名変更ではない。error・exit を消す保証や正常応答の存在を結論へ足していない。

### 2. エフェクトの反例と案 D の範囲

反例は現在の言明の前提をすべて同時に満たす。宣言を持たない program と Model.builtins について WF・WT・EffectsOk・Core を構成し、すべての起点と secrets を束縛する σFull は有効であり、開始の閉包は Adequate・ClosedAt・InitialPrepared を満たす。唯一の Process.Environment の節がそろうため、現 handled はその名前を含む。C_Handle で空の効果を得た後、E_Handle・E_Let の二段から E_IssuePathBases の事象へ進む。`not_effect_soundness` はその事象を全称の禁止へ直接渡して False を得る。型の付かない生の実行だけを反例にしたものではない。

案 D は、この反例の効果を消す理由を取り除く。検査3では effect-fix.md と同じ issuesIn と handled の候補を別名で定義し、Model の Process.Environment の原子が処理済み集合に入らないことを Lean で確かめた。一般の場合も、Core の pathBases_shape が発行の所属する B.effects と署名を与え、EffectsOk が P.effects による同名の上書きを禁じるため、発行のラベルの非所属を示す材料はある。IO は NoHandler による非所属、解放は State の非除去、利用者の操作と Fail は各効果の末尾への移送を使うという証明案に、今回別の反例は見つからなかった。これは案 D の下で全体の健全性を証明済みという判定ではない。

しかし、効果を外へ残すことは、適用が節へ移らないことを保証しない。検査3では issuePathBases を直接書く代わりに通常の空引数の発行の呼出しを置き、その callBody と handler が Process.Environment を残したまま型付くこと、発行の適用が E_OpPrim で節へ移ることを確認した。案 D 後の C_Handle の効果の前提も、任意の処理済み集合について次の包含で満たせる。

```text
Eff.Sub ε (Eff.union ε (handledD P B cs))
```

他の型付けの前提と Step は案 D で変わらない。このため、反例を断る検査と S13 を満たす検査は分けなければならない。重1は、案 D の下でも空効果から事象が起こる新しい反例を見つけた、という指摘ではない。

群 K で実行時の探索を直す場合は、E_OpPrim と E_PathBasesApply が対になっていることにも注意を要する。前者から pathBases だけを除いて後者の NoHandler を残すと、型付きの呼出しが handler の下で進めなくなる。Step・step・進行・保存・step_sound と、ClauseSig・opSig の公開範囲を合わせて判断する必要がある。effect-fix.md はこの追加変更を別件として挙げるが、現状の申し送りだけでは「実行の規則は変えず S13 も満たす」という取りまとめの条件を実装できない。

### 3. noLamNames と開始の条件

現補題が扱う範囲の証明は正しい。表層の lam に対して HasTypeVQ.closed_noLamNames は V_Lam の NamesWF を用い、本体へ帰納する。通常のリスト・構成子・辞書・腕・節・依存ラムダも相互帰納で辿る。StartCondition.of_noLamNames はこの結果を純粋な閉包へ包み、保持値の適格性と開始の準備を受け取る。名前だけの新しい Core の欄は設けていない。

ただし、再帰する範囲は申し送りより狭い。Val.closure は Closure.ClosedAt をそのまま前提に取り、checkedRequest と checkedAt の要求も元の ClosedAt を要求する。checkAt は計算全体を元の ClosedAt で読む。従って、それらの内部では名前を既に含む条件を受け取り、その条件をそのまま返す。例えば、検査3で次の射影が成立した。

```lean
example {t ns ps body}
    (h : (Val.closure t (Closure.pure (.ret (.lam ns ps body)))).ClosedNoLamNames 0 0) :
    NamesWF ns ps := h.2.2.1
```

開始の補題の結論も、任意の q ではなく Closure.pure m に固定される。任意の捕捉の型付けには CaptureOk の Ground、保持要求には groundVal と型付き要求、実行時閉包には DependentClosureTy があり、それらから名前を得る経路を構成する余地はある。しかし、その接続は今回の相互定理と開始の補題に含まれていない。At の関数の欄を通る帰納がカーネルを通らなかったという担当の説明は、未了の理由にはなるが、全場合の完了の根拠にはならない。

重2は証明対象の漏れを指す。現定理のカーネル検査は成功しており、その偽や、型付き入力の実際の除外を示したものではない。完全な名前なしの条件から現条件への橋を型付けの下で証明する方法でも処置できる。効果の定理を群 K へ移した判断は、この開始の接続の範囲を縮める承認を含んでいない。

### 4. L60-H02・L50-H01 の判定

L60-H02 の externalRef_contract_inputs は、進行の外部参照の適用では不要である。app_progress は関数の正準形を使い、外部参照の場合は E_ExternalApply で直接 externalCall へ移す。この規則は宣言や契約の入力を追加で要求せず、適用先の型付けは保存の external_apply_all の担当である。実際の外部応答の存在と型付けを全く読まなくしたのではなく、externalCall の次の段階で external_response_step を読む。保存された読者の記録でも、progress の閉包に externalRef_contract_inputs はない。

L50-H01 では、app_inputs が引き続き進行の入力を供給する。適用の頭は関数型の値なので canonical_function が該当する全形を返す。保持値の形を返す canonical_held をその位置で読む必要はない。対象の健全性では保持値の情報が必要となり、保存された reachable_target_sound の閉包には canonical_held がある。葉の名前を読ませるための不要な包装を足さず、この二行を読者を要しない完了とした取りまとめの判断は妥当である。

### 5. 既存の変更、公理、読者、設計書の写し

Step の stepRun・stepMatch と、BuilderStateLeaves の四補題は、private の文字列を除いた本文が基準と一致する。MainStatements の変更は、承認された StepTargetStatement の二前提と理由の docstring だけである。旧 Release・前段の実署名・型付けの規則・Step の規則を変えていない。根の import の追加五行は既存の import を保ち、新規五モジュールをすべて既定環境へ入れる。

新規五モジュールには sorry・新しい axiom・native_decide・#eval・#reduce・maxHeartbeats・maxRecDepth がない。手で書かれた private の補助は証明又は適用例から読まれる。例えば EffectAtom.bind は略した `.bind` の形でも読まれ、宣言名の完全な文字列の出現回数だけで未使用とは判定できない。

公理監査は担当の台本を読み、記録を書き換えないことを確認してから写しを単独実行した。対象は新五モジュールと変更三モジュールの702宣言で、private と生成宣言も含む。対象702件と公理出力702件は一対一に対応し、保存された対象集合とも一致した。公理なし160、propext のみ281、propext と Quot.sound が7、許可三公理が254であり、sorryAx と許可外の公理は0である。これは群の追加・変更宣言の依存監査であり、全プロジェクトの全宣言を今回再監査したものではない。

07-04 の追加は、八つの閉じた言明と各証明の読み方、二前提の追加理由、noLamNames の現実の限定範囲を写している。本文との不一致は見つからず、差分も今回の箇所に限る。ただし、重2の処置で接続の範囲を広げたら、その範囲に合わせて同じ段落を直す必要がある。01-12 の規則の写しは今回変えておらず、本番の型付け・Step の規則も変えていない。案 D と S13 の規則の変更は群 K の本番と写しの同時変更に残る。

記録10ファイルは合計72,561バイト、最大30,103バイトで、各100 KB以下である。audit-summary.json の本番八ファイルの SHA-256 はすべて現在のソースと一致した。保存された build.log は45,720バイトで記録の SHA-256 と一致し、終了0である。保存された axioms.log は290,909バイトで記録の SHA-256 と一致した。verify.py は結果を書き換えるので実行していない。その成功の報告を、S13 の整合や noLamNames の全場合の完了の証拠には用いなかった。

## 実行した検査

Lean はすべて `<repo>/formal/` で、`lake env lean -M 12288 <file>` により順次実行した。既定のビルド出力は上書きしていない。

| 番号 | 内容・入力 | 結果 |
|---|---|---|
| 1 | 新規五モジュール、変更した MainStatements・Step・BuilderStateLeaves、担当の反例を `<tmp>/rv-l70-b/` にそのまま写して単独 Lean 検査 | 全9本終了0。MainStatements 0.76秒、Step 1.07秒、BuilderStateLeaves 2.16秒、MainProgress 2.36秒、MainStepSound 3.23秒、MainTargets 0.74秒、StartLamNames 3.92秒、MainTheorems 0.83秒、反例1.04秒。Step の既存の simp 引数の警告以外は出力・警告なし |
| 2 | `<tmp>/rv-l70-b/Axioms.lean`。担当の axioms.lean の写しを読み、追加・変更八モジュールの全宣言と依存公理を検査 | 終了0、12.52秒。702件の対象・公理出力が対応し、許可三公理の外0。保存された対象集合と一致 |
| 3 | `<tmp>/rv-l70-b/DChecks.lean`。担当の反例に、案 D の候補、発行の通常の呼出しと handler の型付け、D 後の C_Handle の効果の包含、E_OpPrim の遷移、実行時閉包の名前の射影、反例の `#print axioms` を加えた | 最終稿は終了0、0.86秒。D は処理済み集合から発行の原子を除く。効果を残す handler の型付けと実行時の節への移動は残る。反例の公理は propext・Classical.choice・Quot.sound |
| 4 | `<tmp>/rv-l70-b/InspectNames.lean`。インポートされた ClosedNoLamNames と checkAt の場合の等式を表示 | 終了0、0.86秒。checkAt の場合が元の ClosedAt であることを確認 |
| 5 | 読み取り専用の git 照会と Python 集計。基準HEAD、既存二本の private 削除以外の同一性、八入力のハッシュ、保存ビルドと監査のハッシュ、監査対象・公理出力、記録サイズ、読者の保存出力、禁止の構文、`git diff --check 49f17471` を照合 | 上述の一致を確認。差分の空白のエラーなし。前段の記録・処理系・既存の規則への変更なし |

検査3の途中稿は三回終了1となった。最初の二回は確認用に追加した checkAt の名前の射影が、記号的な引数についてカーネルの型一致を通らなかった。その射影を最終稿から除き、At の範囲の判定はソースと検査4の等式に基づけた。三回目は確認用ファイルの追加の名前空間で ScopeSignatures を開き忘れたためであり、修正後に終了0を得た。いずれも、本番の九本が失敗したという記録ではない。

DChecks.lean は11,072バイト（SHA-256 `93c75016aee11205b130c2a837f13dbc2aa5e36590b3d4ae1c01070a88a839ff`）、Axioms.lean は3,371バイト（SHA-256 `7fd2e5a39aa0bc297fd72e0ee36d3e5ef53692d8574472d34e21eb3908ad5cdf`）である。今回、案 D を本番へ適用した全体の再ビルド、S13 の修正、完全な noLamNames の帰納、Rust と Lean の全比較は実施していない。

## 再レビュー（2026-11-06）

**結論: 可。** 重1・重2の処置を受け入れる。新しい重の所見はない。本節は設計者が指定した二所見の処置の確認だけを扱う、群 B の最後のレビューである。中・軽の所見は扱わず、取りまとめが群 K で案 D と実行の規則の変更を合わせて行うとした判断自体は再検討していない。

読んだものは、[results.md「RV-L70.b の処置」](../l70/b/results.md#rv-l70b-の処置)、[effect-fix.md](../l70/b/effect-fix.md)、`R/StartLamNames.lean`・`R/MainTheorems.lean` の現行ソース、07-04 の修正段落である。本体の作業木の plan.md「計画の変更と取りまとめへの確認点」の先頭の判断とも照合した。根拠を確認するため、元の閉じ方、閉包・捕捉・保持要求の型付け、発行の二規則と実行関数、`handled` の現行定義と基準版との差分、読者の照合台本と監査の要約も読んだ。

| 所見 | 判定 | 処置を受け入れる根拠 |
|---|---|---|
| 重1（案 D と S13） | 処置済み | effect-fix.md 第2・3節は、`handled` から発行を含むラベルを除く変更と、`E_OpPrim` の種類を io・exit に限り、`E_PathBasesApply` の `NoHandler` を除き、`stepRun` で探索の前に発行へ進める変更を併記している。二規則を同時に変えなければ進行を失う点、進行・保存・実行関数の健全性への波及、発行の節を使う既存例と01-12・07-04の写しの処置も具体化されている。第4・5節は、節への移動を実行の変更で防ぎ、発行の事象に対応する効果を案 D で継続の末尾へ残す役割を区別している。第7・8節は、発行の節は型が付くが実行では選ばれないことと、ラベルを消せなくなる影響を明示している。群 K への申し送りとして、承認された形を記述している |
| 重2（noLamNames の接続の範囲） | 処置済み | `Comp.ClosedNoLamNames` の At は起点・パターン・入力の値を再帰し、`Val.closure` は `Closure.ClosedNoLamNames` を通して本体を再帰する。捕捉値は `CaptureOk.closed`、入力の望遠鏡は `runtime_wf`、保持要求は `CheckedWitness.request_closed`・`groundVal_ground` から閉性を得るため、元の `ClosedAt` を名前の独立した前提として残していない。相互の `*_resolved` は At の型付けの関数の欄と入れ子の閉包を含み、任意の局所参照の解決後に元の閉じ方を与える。`ClosureTy.closed_noLamNames` と `StartCondition.of_typed_noLamNames` は任意の型付き閉包 q を扱い、純粋な閉包への限定を解消した。`MainTheorems` の到達先の対象健全性の証人もこの入口を使い、results.md と07-04の説明はその到達範囲に一致する |

群 B で規則を変えていないことも確認した。基準 `49f17471442229baf668e7b1f7b6dac8151c6dcf` と比較すると、`R/Semantics.lean`・`R/HandlerContracts.lean`・`R/Typing.lean`・`R/Ground.lean` は同一である。`R/Step.lean` は `stepRun`・`stepMatch` の `private` の削除だけで、実行の分岐は同一である。従って、重1の規則と定義の変更は今回の処置に紛れ込んでいない。新しい noLamNames の証明も、これらの既存の規則を使って接続を広げている。

再レビューでは Lean・cargo・`scripts/check.sh` を実行せず、git の書き込みも行っていない。`verify.py` は audit-summary.json を書き換えるため実行せず、台本を読んだ。読み取りだけの Python 照会で、監査の要約にある本番八ファイルの SHA-256 が現行ソースと一致することと、上記の基準版との同一性を確認した。results.md にある既定ビルド・公理監査・読者照合の成功は担当の検査記録であり、今回独立に再実行した結果とは扱わない。変更したのは本節の追記だけである。

この「可」は重1・重2の処置に対する判定である。`EffectSoundnessStatement` とその noLamNames 版の合成は、申し送りどおり群 K に残る。群 K の規則の変更や効果の健全性の証明まで完了したとの判定は含まない。

## 取りまとめの追記

2026-11-06。群 B は Claude の実装担当が実装し、独立レビューは Codex が本レビューと処置の確認の再レビューの二回行った。重2（noLamNames の接続の範囲）は再開2で全閉包・捕捉・入れ子へ広げて閉じた。重1は、取りまとめが案 D に加えて PathBases の発行の適用をハンドラの探索から外す実行の規則の変更を群 K で行うと判断し（plan.md、設計者の見直しの対象）、`effect-fix.md` をその形に書き直した。再レビューは可であった。エフェクトの健全性は群 K の後に閉じる。処置の後に取りまとめが `scripts/check.sh --level work --base 49f17471442229baf668e7b1f7b6dac8151c6dcf` を実行し、終了0（876.03秒）であった。
