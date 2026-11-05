# RV-L70.a: L70 群 A（L70.03〜.08、方式の確認と骨格）の独立レビュー

2026-11-06。対象はブランチ `m014/l70.a` の未コミットの作業木である。基準は `243e4237b6775b9677676fcbc6ed5de216a5662a` で、HEAD と一致する。本書の `<repo>` はレビュー対象の worktree、`<tmp>` は指定の scratchpad、C は本書を置く改造ディレクトリ、R は `<repo>/formal/Benitoite/Release/Refinement/` を表す。本レビューは群 A の本レビュー一回であり、再レビューは重・中の処置の確認に限って一回とする。

読んだもの:

- 依頼 `<home>/src/Benitoite/work/m014/L70.a-prompt.md`、[担当の報告](../l70/a/results.md)と[棚卸し](../l70/a/inventory.md)、inventory.json・inventory.py・graph.lean。
- `l70/detail.md` の F01〜F09、L70.03〜.08、群 A の完了条件、第7節、[collection.md](../l70/collection.md) の29欄の対応表と完成した表の全14欄の確認表、completion-trial.lean、[RV-L70-plan](RV-L70-plan.md) の初回・再レビュー・3回目と取りまとめの追記。記録の形式は [RV-L70.u](RV-L70.u.md) の初回部分に倣った。
- 本体の作業木にある未コミットの最新版の plan.md。「全 L 作業の停止条件」と「計画の変更と取りまとめへの確認点」の先頭の判断を正とし、群 A の報告に対する四点を確認した。旧 Surface の構文だけの保持、主定理の前提の追加、F05・F06 の群 D・E への割り当て、旧 Release の役割の二分と削除方針は判断済みとして扱った。
- 00-01 の目的と保証の範囲、U02 の決定と関連する宣言の候補、L60 の旧主定理12件との対応と後段の受け口。旧 Release の主定理・開始の補題、外部応答、型付け・宣言・変性・網羅性・開始準備の定義も照合した。
- `git diff 243e4237 -- formal docs/design` の全差分、新規8モジュールの全文、At の変更箇所と読者。旧 Surface の構文、交換の既存の版と入口、残す旧 Release の中の削除予定先を使う宣言も読んだ。
- `l70/a/verify.py`・names.py・axioms.lean・audit-modules.json・required-names.json・audit-summary.json、名前の対応に使う L60 の台帳と差分、指定の一時領域に残る graph.log・build.log・axioms.log。

本書以外のリポジトリ内のファイルは変更していない。git の書き込み操作、`lake build`・cargo・`scripts/check.sh` は実行していない。Lean は `<repo>/formal/` から `lake env lean -M 12288 <file>` で一つずつ実行し、`-o` は使っていない。確認ファイルと新規ソースの写しは `<tmp>/rv-l70-a/` に置いた。大きな具体値を作る評価はしていない。記録を書き換える verify.py・inventory.py・names.py などは実行せず、読んで判定した。担当の既定ビルド・全宣言の公理監査の保存記録と、本レビューの独立検査を区別した。

## 結論

**条件付き可**（重1・中2・軽0・情報0）。

F03 の本番の契約は、先行レビューの構成子追加と effKind 上書きの反例を断り、29欄を漏れなく組み立てる形になっている。動的な pattern の追加も、承認された型付けの拡張とその読者の追随に収まり、Step の規則は変えていない。表層の構文の構成子の脱落、新しい公理・sorry、未承認の提供範囲の削減は見つからなかった。主定理の言明と後段へ渡す契約を置く群としての構成は維持できる。

条件は、削除後の閉鎖を満たさない棚卸しを直し、契約の欄数と noLamNames 統合の説明を実物に合わせることである。特に「旧 Release を59モジュール削除し、残す50モジュールでは import の行だけを除く」という判断は、現在の削除集合では実行できない。重1を処置せず、この集合を群 G の確定した削除指定として使ってはならない。主定理や収集の未実装の証明を、このレビューで完成済みと判定したものではない。

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 重1 | 重 | `l70/a/inventory.py` 234〜302行、inventory.md 第3・6節、results.md「削除の集合」「残す旧 Release」。本体の最新版 plan.md の群 A への判断(4) | 必要な**宣言**の閉包から所属モジュール50個を選んだ後、そのモジュール内の残りの宣言を閉包へ加えていない。残す `Release.EffectCover` の `Eff.Covers.substRho` は削除する `Release.SubstEnv` を使い、残す `Release.ModelHttp` の `Examples.httpCons` は削除する `Release.ModelTargets.okDecl/errDecl` を使う。import だけを除いても宣言本体の参照が残る。また逆戻りの検査は直接の41名への参照だけで、`R.CurrentSignatureRows.target_entries_rows → Release.TargetTable.entries_scoped → Release.Model.assumptions → Release.HasTypeV` を検出しない。三モデルの3行だけを除く指定ではこの経路が残る | モジュールを丸ごと残すなら、その中の全宣言から削除先への依存が無くなるまで閉包を取り直す。宣言単位で整理するなら、残すモジュール内で除く宣言・依存する読者・生成宣言も一覧化し、import だけを変えるという現在の制約との差を取りまとめへ戻す。三モデルの直接の3行に加え target_entries_rows の処置を明示し、埋め込みを経ない旧判断への依存を推移閉包で照合する。旧主定理を残すことで帳尻を合わせない | 読めば確定。保存された宣言グラフの独立走査でも確認。削除後のビルドは実行していない |
| 中1 | 中 | `R/StandardModelCompletion.lean` 11〜12・20行、`l70/a/results.md` 86・160行、07-04「篩を含むコア計算の形式化」の今回の追加段落 | `RowConditions` を17欄、`TableConditions` を11欄、`Completion` を10欄とするが、実際は順に16・10・9欄である。29欄の組立てに漏れはなく、説明上の分け方と構造体の欄数が混ざっている | 「RowConditions は16欄（Core の15＋Target の1）、ReleaseOn は1条件、TableConditions は構造体の10欄（external を3欄へ展開すると12条件）、合計16＋1＋12＝29」と揃える。Completion は9欄とする。説明・報告・写しを直し、数を合わせるために契約の欄を足さない | 読めば確定。Lean の構造体情報からも16・10・9を確認 |
| 中2 | 中 | `R/MainStatements.lean` 85〜87行、`l70/a/results.md` 52行、07-04 の MainStatements の今回の追加段落。参照先は `R/Ground.lean` 18〜27・74行 | noLamNames 版を統合した理由を「Closure.ClosedAt がラムダ名を読まない」とするが、Closure.ClosedAt は Comp.ClosedAt・Val.ClosedAt を辿り、lam の場合に `NamesWF ns ps` を要求する。開始の条件から名前の前提が消えたという説明は事実と異なる | 名前の条件は閉じ方にも含まれると訂正し、型付けから名前の整形式を供給して旧 noLamNames 版も同じ開始条件へ接続する、という説明にする。全閉包・捕捉・入れ子の導出についてその接続を示す義務を L70.14・.15 に明記し、群 B で確認する。名前の条件を新しい独立の信頼条件として渡さない | 読めば確定。単独の Lean でも ClosedAt から NamesWF を射影できることを確認。主定理の不成立や、型付きプログラムが実際に除外される反例を示した所見ではない |

## 観点ごとの根拠

### 1. 主定理の言明、終端と開始の条件

MainStatements の九つの命題は、進行、一段・列の保存、実行関数の健全性、開始の型付け、効果の健全性、一段・到達・事象形の対象健全性である。P・B・σ を固定した各命題の内側で、状態・遷移・実行列・事象・実引数・観測を全称量化している。全状態を特定の有限コーパスに制限する前提はない。到達の対象健全性は初期の ε を保ち、到達状態の末尾の効果を別の存在量化したものへ取り替えていない。

旧12件の対応は、旧 Release の9件のうち effect_soundness と noLamNames の二形、reachable_target_sound と `_of_assumptions` の二形をそれぞれ統合し、旧三モデル3件は L70.19 の適用例として残す、という構成である。新たな列の保存と開始の型付けを加えて九つになる。`_of_assumptions` は新判断の CoreAssumptions と TargetAgreement を別に受ける同じ到達の命題に当たり、モデルの条件を新しい主定理へ紛れ込ませていない。noLamNames の統合の説明には中2がある。型付きの lam の名前の条件は既存の inv_lam_wf から得られるが、本レビューでは任意の閉包全体について名前を補う帰納を実装していない。

`State.Final` は詳細の F02 と同じである。ret の視点を持つ閉包と空の継続、継続が空の error・exit だけを終端とし、matchRun を終端へ加えていない。StartCondition は保持値の適格性・閉じ方・InitialPrepared の三条件である。InitialPrepared が含む σ.Valid と起点の束縛は開始に限られ、全状態の不変条件へ Ready を足していない。StepSelection も IO・外部・解放・新しい場所の四条件で、応答があるときその一つを選ぶという旧条件を保つ。正常応答の存在や、Step の逆方向の完全性は要求していない。

追加された P.WellFormed と P.WellTyped B は、最新版の plan.md が認めた範囲にある。実際の ExternalAssumptions.external_exists は P.ExternalWF と ExternalArgs を読み、既存の StateTyE.external_response_step は P.WellFormed・P.WellTyped B からそれらを得る。外部宣言を空にする制限や新しい応答公理で置き換えていない。StandardModel.statement_premises は任意の externals とその ExternalWF の下で形成・型付け・core・targets を供給する。EffectsOk や StartCondition までその適用例で証明済みとはしていない。

保存の二つの命題は、前段の step_preserved・steps_preserved から同じ σ・Eb のまま包装できることを独立に証明した。これにより、少なくとも保存の公開形で、前段の実署名を黙って替えたり必要な束縛を落としたりしていないことを確認した。進行・効果・対象等の全場合の証明は群 B に残る。

### 2. Program.Extends と追加宣言の義務

Program.Extends は10欄で、既存の lookup の保存に consClosed と dataInfoOld を加えている。Program.DataArity は構成子の存在と同じ data の全構成子の arity を読むため、同じ data への新しい構成子を逆向きに制限する条件が必要である。本番の extensionAdded_not_extends は RV-L70-plan の D.A／D.B の反例を断る。別の data 型 E の構成子を加える例は受けるので、宣言を一切追加できない条件ではない。

dataInfoOld は既存 data の変性の宣言を None も含めて保つ。DataArity・ParamOccursInFields・VarianceValid の全称の読み方と、Ty.Declared・型付けの正の lookup を分けた担当の表は、実定義に対応する。externals の等号は、任意の外部宣言表を先に StandardModel.program externals に渡してから同じ表を利用者の P で使う関係であり、利用者の P から外部宣言を除く条件ではない。

Additions は11欄で、追加した defs・impls の型付けと形成、cons の DataArity と形成、ops・classes、metadata、変性の二条件、効果の三条件を P' の上で受ける。元の P が検査を通ったことだけで追加宣言も型付く、とする旧案には戻っていない。metadata は P' 全体について受け、追加された構成子と既存 metadata の整合も対象にする。

ExtendsTypingStatement は宣言済みの文脈を、ExtendsExhaustiveStatement は宣言済みの対象型と P.WellFormed を前提に取る。Inhabits の逆向き、特に atError から必要となる公開宣言の閉鎖は、担当も L70.17 の未証明の義務として明記している。本レビューは、この移送を証明済みとは判定していない。閉じなければ停止するという契約を保つ必要がある。

StandardModel.builtins は外部応答を P の型付けから作るため、externals が等しいだけで表全体の等号を主張していない。型付けが読む七射影の一致と既存の of_fields を使う受け口になっており、この補題と適用例は単独の Lean でも通った。

### 3. 完成した表の全14欄と29条件

完成した表の全欄は、単なる Option.or による上書きを避ける構成になっている。各欄の確認は次のとおりである。

| 欄 | 本番の構成と保持の条件 |
|---|---|
| sig | 合成済みを先に選び、仮定側は assumed の名前だけを選ぶ。composedAll が合成表の全署名の脱落を防ぐ |
| delta | 合成済みの名前では合成表の関数をそのまま使う |
| ioResponse | 合成済みの名前では合成表の関係をそのまま使う |
| releaseResponse | 資源分類による抽象応答と A の応答の和。合成側の応答を含むことは complete_release_composed、型付きの合成側の資源へ A が新しい応答を加えないことは Completion.releaseComposed が受け持つ |
| isResource | 仮定側の資源名だけを A から取り、他は合成表。WF.resources が File.Handle 等の既存の資源を仮定側へ置くことを断る |
| effects | 合成表の操作列の後ろへ assumedOps を追加する。State の空列は Completion.stateFree と complete_state_effect で保つ |
| sat | 合成表のまま |
| refGet・refSet | 二欄とも合成表のまま |
| effKind | composedEffects の中は None も含めて合成表の値とする。WF.effects が合成表の全成功ラベルを覆う |
| valKind | 合成表のまま |
| admitsR | 合成表のまま |
| valContent | 合成表のまま |
| externalResponse | 同じ P と完成した base から ExternalModel.builtins が構成する。既存の external_assumptions を適用できる |

表の releaseResponse の保持は型付きの値についての契約であり、型付けを問わない全 Val 上の関係の等号を示すものではない。この範囲は主定理が使う条件と合う。

complete_effKind_composed・complete_shapeOk_composed・complete_agree・complete_state_effect は本番で証明されている。先行レビューの reviewA は Completion.effKindComposed で拒否され、構成そのものも Console.Write の None を保つ。NameLists.WF の追加条件は署名の脱落・区分の重なり・形式化外の名前の混入を防ぐもので、標準の nameLists はその条件を満たす。完成後の全署名の保持、outside の署名なし、State の空列、既存資源の保持、全 ShapeOk、外部の三条件を、任意の L・P・A について独立の確認命題でもまとめた。

core_of_parts は、署名を持つ全名前を二つの述語で、資源の全種類を二つの述語で覆う。各欄を構造体の構築で明示するため、CoreAssumptions の28条件と TargetAgreement の1条件の欠落はない。実際の内訳は中1のとおり RowConditions の16、ReleaseOn の1、TableConditions の展開後12である。completion_core_of は、一般化した合成行・合成側の解放・表全体の条件から、この組立てへ接続する。仮定側の rows と release を無名の追加公理に替えてはいない。

合成済みの377は、台帳490行と別の集合を数えている。L60 の群 F1・F2 の差分を重ねた独立集計では合成490・仮定150となり、合成行の対応から Primitive の全377件と Body の全130件を覆うことを確認した。報告の lookup 出現数392・160・1は重複を含む数であり、署名や本体の異なる鍵の件数ではない。仮定側の80・47・16・7の各リストは、台帳の名前と順序まで一致した。Task の7名を除くのは承認済みの J70-8 である。

C06 の一般化の対象も区別されている。pure・IO・対象・解放は任意の B の型付けを読む形へ述べ直す必要があり、固定の表の結論だけを完成した表へ移すことにはしていない。admits と sat の移送、sig_scoped の P の拡張、ShapeOk の効果表の所属・effKind・valKind が別に挙げられる。これらの一般化、実際に仮定側の全行を供給すること、主定理の利用者への系は群 C の仕事である。Additions・Completion・StartCondition の正常な証人を未確認として「保留」にした記録は、骨格の群で完成を過大に主張しない扱いとして妥当である。

### 4. 動的な pattern と型付けの全読者

parseAtPattern の追加枝は文字列を解析した後、解析済みの scopePattern と同じ FitsKind・WF・Canonical を検査する。parseAtPattern_formed と parseAtPattern_string は特定の正常文字列だけでなく、成功する全入力を量化する。絶対形のパスとホストの解析が旧 API と同じ定義であることは rfl の等式で示されている。基準・secrets・相対形は新しいパス解析の枝にあり、端点の文字列は受けない。形式不良と未束縛の基準は準備又は検査の既存の誤りになる。

AtCallAdmissible.text は mk と同じ八つの前提を持ち、pattern の型だけを String に替える。結果の宣言条件、入力の型と valContent、固定添字の形成を外していない。論理和の前提を一つの構成子に入れる代案を、相互帰納の判断の別構成子で実装したもので、承認された J70-2 の範囲である。

読者は名前で読む20ファイルに、C_CheckAt を介して分解する6ファイルを加えた26ファイルである。名前だけで検索した集合では後六つを落とすので、担当の列挙を差分と照合した。値と型の置換、shift、narrowing、文脈、局所参照、合同、表の射影の移送は text の場合を同じ既存の移送で閉じる。宣言・添字・結果の像・内容型の取り出しも両構成子を扱う。ScopePublicTyping は閉じた文字列の canonical forms を使い、pattern と input の公開形を供給する。

Step・実行関数・StoreReplyInputs の規則のファイルは基準から変更されていない。解析結果を読む既存の At の三遷移が文字列にも適用されるのであり、新しい Step の構成子や追加の実行前提で読者を通していない。担当の既定ビルドの保存記録は全読者を含み、変更32モジュールのソースハッシュも現物と一致する。Rust の解析との一致は R50 の比較に残り、今回の rfl の等式は Lean の旧 API との一致である。

### 5. 表層と交換の骨格

旧と新の表層の式の相互帰納型は、Expr 53、Exprs 2、HoleArgs 3、Arms 2、Clauses 2、Block 10で一致する。宣言を読んだ照合でも、既存の呼出し・部分適用・record 更新・try/die・ハンドラ・構築器・補間等の脱落はない。Literal 14・Pattern 12を合わせた旧98構成子を写す構成である。

関数の宣言は TypeCtx、篩付きの引数と結果、範囲パラメータの種類の列、proofSteps を持つ。別名は値引数と範囲パラメータ、record は前の欄を参照する型の列、宣言表は aliases・records・testers を持つ。欄の依存は表層から record 全体の篩へ写す方針であり、核の ConDecl を変えていない。判断の型は七つの式・列等の判断と辞書の判断を置き、七つには値の文脈の直後に Φ を加える。辞書の判断は従来の別の引数列である。これらは判断の型であって型付け規則の実装ではなく、別名の展開・record の依存・判定関数の規則を今回証明したとは扱わない。

Exchange.Refined は篩・依存関数・外部型・範囲添字・起点と pattern の型、および宣言の追加欄を運ぶ型を置く。readVersion は corpus 16、その他の付随表8と一致する場合だけ版の判定を通す。解析した版が期待値と異なる任意の JSON 入力を拒否することも、記号の版番号を使った命題で確認した。旧入口と旧 Version の読み分けは今回残り、群 G で切り替えるという骨格である。

証明書の欄はこのモジュールにまだない。担当はこれを計画との差として明記しており、detail.md 第7.2節もその具体形を U05・R20 の詳細化に残している。群 A のコードから証明書を運べるとは結論しない。完成した新形式の reader・未知の欄の拒否・書き出しとの照合は L70.40a 以降の受け口で確認する必要がある。F05・F06 の未配置は最新版の plan.md の判断(3)に従うため、今回の未処置の所見には数えない。

### 6. 棚卸しと削除後の閉鎖

7入口の経路の割り当ては、実際の入口が読む CheckAccept・Check・CheckInput・Builtins・CheckTables・CoverageShow・Observe・区間の層を含む。surfaceCheckAll の Validation が noRules を使うことも隠していない。層を移植・継承・削除へ分け、受持単位を割り当てた点は先行レビューの重3に対応する。旧 Surface の構文だけを区間解析の入力として残す判断は、旧判断・検査・定理を残す許可ではない。非構文の読者の移植と、新表層からの変換は引き続き群 G の義務である。

ただし削除集合の算出には重1がある。宣言の閉包が所属モジュール50個を必要とすることと、その50個のファイルを本文の変更なしで残せることは別である。保存されたグラフから、残す50モジュールの**全宣言**を根にして削除先を調べると、11モジュールで削除予定モジュール又は削除予定の旧主定理への直接依存が見つかった。少なくとも EffectCover の SubstEnv への参照、ModelHttp.Examples.httpCons の ModelTargets の宣言への参照、TargetTable.entries_scoped の Model.assumptions への参照はソースでも確定する。生成宣言の所属の数え方だけで起きた問題ではない。

逆戻りの照合も、直接の41名への参照が0であることだけでは F09 の推移閉包の条件を示さない。target_entries_rows は旧主定理を直接呼ばないが、TargetTable.entries_scoped を介して Model.assumptions と旧 HasTypeV に依存する。担当が削除又は置換を申し送った model_rows・model_targets_rows・model_http_rows の三つを除いても、この第四の経路が残る。埋め込みの境界で止めた推移閉包と、残すソースの全宣言についての削除先検査が必要である。

本レビューは削除を実施していない。従って、削除後のビルドが失敗したという実行結果ではなく、確定した参照と削除集合が両立しないという静的な所見である。旧 Release の本文を変えない判断と、宣言単位で削る判断のどちらを採る場合も、同じ一覧から実施可能な削除指定を作り直す必要がある。

### 7. 公理・写し・検査の範囲

実差分は新規8、既存の変更24モジュール、根の import、01-12・07-04である。追加8モジュールは既定 import に入り、既存の import を外していない。旧 Release・旧 Surface・Core・処理系の変更はない。追加ソースと差分に、新しい公理・sorry・native_decide・#eval・不要な maxHeartbeats/maxRecDepth の追加はない。今回足した読者のない private 定義も見つからなかった。

保存された公理監査は32モジュール・4,465宣言で、private・生成宣言を含む。対象と公理出力は一対一で、依存の組は、なし2,211、propext 579、propext と Quot.sound 111、propext と Classical.choice 1、許可した三公理1,563である。未知の公理と sorryAx は0で、ソースハッシュ32件は全件一致した。新規8モジュールの宣言1,906件、監査全体の private 888件という記録にも食い違いはない。

01-12 の AtCallAdmissible の写しは、本番の二構成子と前提に一致する。07-04 は言明や判断の型だけを置いた部分を、その主定理や表層規則の証明済みとはしていない。ただし中1の欄数と中2の閉じ方の説明は、写しにも直す必要がある。変更は今回の At の拡張と新しいモジュールの説明に限られ、過去の設計書の範囲を一括して書き換えていない。

## 実行した検査

すべて読み取り又は指定の一時領域への出力であり、既定のビルド出力を上書きしていない。

| 番号 | 検査 | 実行と結果 |
|---|---|---|
| 1 | 基準・差分・保存された監査の独立照合 | HEAD と基準の一致、追跡差分と未追跡の範囲、根の import を確認した。32ソースの SHA-256 は全件一致。対象・公理出力は4,465件ずつで一対一、未知の公理と sorryAx は0。結果の一部を `<tmp>/rv-l70-a/independent-audit.json` に保存した |
| 2 | 既定ビルドと公理監査の生出力の同一性 | 担当の build.log は75,166バイト・SHA-256 `79869a41e495c8428c6d6fae5408d247fbec0a87fefea7dc55bcc65d11311512`、axioms.log は1,464,135バイト・SHA-256 `a0a1c9820360a35623bc4ee3b4a6383a556cd1b38d166eb6f7a7e20b96cb0fe7` で保存記録と一致した。既定ビルド自体は再実行していない |
| 3 | 新規8モジュールのソース検査 | 現物と同じ内容を `<tmp>/rv-l70-a/source/` へ写し、MainStatements・ProgramExtension・StandardModelCompletion・StandardModelNameLists・Surface/Syntax・Surface/Typing・AtPatternText・Exchange/Refined を、`formal/` から `lake env lean -M 12288 <file>` で一つずつ確認した。8件全て終了0。依存には担当の既定ビルドの olean を使った |
| 4 | 契約の実際の欄数と表層の構成子数 | `<tmp>/rv-l70-a/Counts.lean` を同じコマンドで確認し、終了0。構造体情報から RowConditions 16、TableConditions 10、Extends 10、Additions 11、NameLists.WF 7、Completion 9を得た。旧・新の表層の相互6型は53・2・3・2・2・10で一致、AtCallAdmissible は2構成子 |
| 5 | 任意の表・状態についての接続 | `<tmp>/rv-l70-a/Checks.lean` で、一段・列の保存の包装、全署名の保持と outside の署名なし、State・資源・ShapeOk の保持、外部条件、text の呼出し、任意の異なる版の拒否を確認した。最終は終了0。途中は確認ファイルの stateEff の名前修飾不足と Except/Bool の展開手順の不足で終了1となり、確認ファイルを直した。本番の反例ではない。四つの確認定理の #print axioms は許可した三公理の範囲。最終出力には補助証明の if_pos の非推奨警告が一つある |
| 6 | 閉じ方とラムダ名 | `<tmp>/rv-l70-a/Names.lean` で、任意の ns・ps・body の `Closure.pure (.ret (.lam ns ps body))` の ClosedAt から NamesWF を得る射影と、型付きの lam から同じ条件を得る逆転を確認した。終了0、公理は許可した三公理の範囲。全閉包についての noLamNames の接続の証明ではない |
| 7 | 台帳と署名の全件照合 | 書き換え台本を実行せず、独立の Python の読み取りで台帳と F1・F2 の保存差分を重ねた。合成490・仮定150、Primitive 全377・Body 全130の対応に漏れなし。仮定側の80・47・16・7は名前と順序まで本番の一覧と一致 |
| 8 | 削除集合と推移依存の独立照合 | graph.log は115,387,755バイト・SHA-256 `0ff5d444161b479edfeaa5e7913d2e4f2b782b7e94aa89a7579282a3383d8500` で記録と一致した。独立の走査で、残すモジュール内の全宣言から削除先への依存と、埋め込みを経ない旧判断への推移依存を抽出した。結果は `<tmp>/rv-l70-a/deletion-edges.json`・backflow.json。重1の参照は現物のソースとも照合した |

本レビューは、群 B〜G の証明、削除の実施、F-REG、Rust の実装との一致、L70 の段末の受け入れを代行していない。条件付き可は、上記三所見の処置を確認した後に群 A を受け入れるための判定である。

## 再レビュー（2026-11-06）

**結論: 不可。** 重1は処置未完、中1・中2は処置済みである。取りまとめが採った「旧 Release を74モジュール残し、35モジュールと残す側の37宣言を削除する」という判断を前提とし、その判断の是非は検討していない。再レビューの対象は初回の三所見の処置に限り、追加の指摘は削除集合の閉包に関わる重の残件だけとした。

| 初回の所見 | 判定 | 根拠 |
|---|---|---|
| 重1 | 不可（処置未完） | 保存グラフ上では、不動点5回、旧 Release の残す74・削除35、残す側の削除37宣言、import の切断11辺が独立集計と一致した。37宣言を除いた後のグラフに、未処置の旧 Release の削除先への依存はない。しかし、同グラフに現れない匿名の `example` と、宣言本体以外の `open` に削除対象への参照が残る。下表の再重1により、ソース全体としての削除指定は閉じていない |
| 中1 | 可（処置済み） | `R/StandardModelCompletion.lean` の構造体の欄をソースから独立に数え、`RowConditions` 16・`TableConditions` 10・`Completion` 9を確認した。コメント、results.md、07-04の修正段落は、Core の15＋Target の1、解放の1条件、外部の欄を展開した12条件、合計16＋1＋12＝29という説明に揃っている。数を合わせるための契約の欄の追加はない |
| 中2 | 可（処置済み） | `R/MainStatements.lean`、results.md、07-04は、`Closure.ClosedAt` が lam の `NamesWF` を含むと訂正している。results.md「中2: L70.14・.15 への申し送り」は、全閉包・捕捉・入れ子について型付けから名前の整形式を供給し、旧 noLamNames 版を同じ開始条件へ接続する義務を明記した。独立の信頼条件にしないことも明記されている。その接続の証明自体は群 B の確認事項である |

### 削除集合の閉包に残る重の所見

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 再重1（重1の残件） | 重 | `l70/a/graph.lean` 8〜15行、`inventory.py` 337〜384行、inventory.md 第6節。実際の読者は `formal/Benitoite/Release/Model.lean` 150〜153・310〜316・350〜366行と `formal/Benitoite/Release/ModelHttp.lean` 44行 | 環境に残る定数の型・値のグラフだけでは、残すソースの全読者を覆わない。残す `Model` の匿名の `example` 3件は37宣言の削除指定に含まれず、150行と310行の例は削除する `Release.Theorems` の `effect_soundness` と削除する `Model.assumptions` を、350行の例は `Model.assumptions` を読む。また `ModelHttp` の選択的な `open Benitoite.Release.ModelTargets (...)` は、削除する `ref_scoped_get`・`ref_scoped_set` を名前で指定したままである。74・35・37の指定と11辺の import の削除だけでは、これらのソース参照が残る | 74・35のモジュール集合を保ったまま、少なくとも `Model` の当該匿名例3件の削除と、`ModelHttp` の `open` から当該2名を除く編集をL70.44の指定へ加える。残すソースの匿名例・名前を指定するコマンド・証明中の参照も照合し、環境の宣言グラフに現れない読者を削除指定へ含める。旧主定理を戻して解消しない | 読めば確定する削除対象へのソース参照である。削除後のビルドの実行結果を主張するものではない。Lean は実行していない |

### 読み取りで確認した範囲

保存された graph.log は115,387,755バイト、SHA-256 `0ff5d444161b479edfeaa5e7913d2e4f2b782b7e94aa89a7579282a3383d8500` で、inventory.json の入力記録と一致した。独立の読み取り用 Python で86,150宣言を走査し、削除する主定理の全推移読者を先に求める別の順序でも、残す74モジュールと除く37宣言が一致した。旧 Release の残す集合と削除集合は重複なく109モジュールを覆い、C05の必要モジュールは全て残る。Core の削除16、旧 Surface の削除94と構文の保持3も一致した。

private・生成宣言と、名前が Benitoite で始まらない生成定数も除外せず、残すモジュールの全グラフ節点から削除先への直接辺を照合した。明示された旧 Surface の読者の移植を別にすると、37宣言を除いたグラフに残件はなかった。移植先の辺も `fixpoint.port_edges` と一致した。埋め込みで止める逆向きの推移到達では、`target_entries_rows` を含む既報の4件だけが検出され、4件とも削除37宣言に含まれる。この結果は宣言グラフに対する処置の正しさを示すが、再重1のソース上の読者を含まない。

`inventory.py` その他の記録を書き換える台本、Lean、cargo、`scripts/check.sh` は実行していない。git の書き込み操作も行っていない。変更は本節の追記だけである。これを群 A の最後の再レビューとし、群 B の証明、L70.44での削除の実施と削除後の検査の完了は判定していない。

## 取りまとめの追記

2026-11-06。群 A は Claude の実装担当が実装し、独立レビューは Codex が本レビューと処置の確認の再レビューの二回行った（設計者の決定のレビューの回数）。再レビューで残った再重1（宣言のグラフに現れない匿名の example と open の参照）は、再開2で残す935モジュールのソースを走査して example 4件・open 4件を見つけ、L70.44 の削除の指定に加えた。三回目のレビューは起こさず、取りまとめが、旧主定理の名前を含む旧 Release の7ファイルのうち残す側は Model と ModelHttp の2つだけであり、その中の参照が削除の指定に入り、残る5つ（例のファイルと Theorems）は削除側にあることを照合した。群 A の判断(4)は成り立たず、取り直した削除の集合で L70.44 を確定した（plan.md）。処置の後に取りまとめが `scripts/check.sh --level work --base 243e4237b6775b9677676fcbc6ed5de216a5662a` を実行し、終了0（820.54秒）であった。
