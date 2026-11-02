# L30 群D・Eの結果

2026-11-03。指定ブランチは`m014/l30.d`、基準B_WORKとHEADは`d4593f42acb91e3bbefd0ced45176f0ca02ac439`である。L30.19〜.30の12単位の実装と担当の自己点検を終えた。群Aの[固定署名](../a/signatures.md)と案(ii)checkedAt、群B・Cの[署名](../b/signatures.md)を維持した。独立レビューと設計者の受け入れは取りまとめの担当であり、本記録の完了判定に含めない。

主な十言明の形、新しい公理、独立の信頼条件、書ける形の制限、提供範囲の削減、精密な外部状態の追加はいずれも0である。案(ii)のまま担当の全場合が閉じた。処理系・旧Release・plan・detail・README・レビュー記録・docs/todoの変更、およびgitの状態を変える操作は行っていない。J30-2の型域の切替は今回の対象ではない。U03は決定済みのまま引き継ぎ、数学の係数と上限はIntとし、保存幅128ビット・stepsの別の条件を今回の健全性へ足していない。

## 完了条件の照合

| 単位 | 担当分の判定 | 本番の証拠と既定の読者 |
|---|---|---|
| L30.19 | 完了 | RefutationSoundのnormalize_holds_at/normalize_linear_at。Cのnormalize_sound_at（内部でBのlinearize_sound_atを使う）と列長を要求しないLinear.toPred_sound_atを同じkeys/ν/ηで合成。再線形化と再帰の再実装は0。RefutationExamplesの正規化した矛盾と線形の葉で適用 |
| L30.20 | 完了 | LinearCombinationのlinearCombination/sound。空和・一項・複数項、零乗数、非負性、全係数列の長さと内積の和。BのlinearDot_add/linearDot_zeroとAのlinearDot_scaleを再利用。負乗数・長さ不一致の拒否を具体例で確認 |
| L30.21 | 完了 | CertificateKernel.consume/casesとconsume_sound_at/cases_sound_at。NNF6形を区分し、linear/literalは末尾へ移す。Andは同じ枝、Orは同じ元のfactsから両枝。Orのconsume・片枝だけの成功・兄弟の追記参照を拒否 |
| L30.22 | 完了 | LinearStep.check/soundとderive_sound_at。先行factsの参照、非負乗数、全係数と上限の再計算・expectedとの一致。現在のfactsにない位置、期待式・列長の改竄を拒否。combine_refutes_atとconsumed_refutes_atで同じνの矛盾まで接続 |
| L30.23 | 完了 | roundは正除数・係数の整除・床の上限・出力長を検査し、AのLinear.round_soundを適用。splitは実在する鍵番号にintegerAs_split_atを適用し、別々のfactsの両枝を要求。−3/2=−2、2*x=1の丸めによる反証と、splitで加えた事実を両枝で使う丸めなしの反証。片枝の結合の誤り・片枝欠落と未知鍵を拒否。odd_refutes_atでも丸め2回とcombineを合成 |
| L30.24 | 完了 | close_linear_sound_at/close_atom_sound_at/discard_todo_sound_at/discard_fact_sound_at。全係数0と負の上限、同一原子の正負、弱い前提の反証を同じνで読む。未処理のOrを捨てて既知矛盾で閉じる。facts削除後のindexで再解決し、旧indexと範囲外削除を拒否 |
| L30.25 | 完了 | EqProofSyntaxへ旧4場合を移し、check/soundの名前・型と構造一致を保存。checkRaw/structural_sound/integer_sound_atをmode別に証明。既定の旧Certificate.sound/checkSortedの読者も維持 |
| L30.26 | 完了 | hyp/neg/scaleをinteger modeだけで受理。hypは渡された現在のΦの整数eqだけを照合。負係数−3とnegの合成を任意のνで適用。範囲外とBoolean比較の参照、旧structural入口での使用を拒否 |
| L30.27 | 完了 | 有限の値置換で二変数が同じ欄の実像になる例をtermEq/reflで照合。元の異なる変数は拒否し、snapshotのnoneを値で埋める構造一致も拒否。alias構成子・展開表は追加しない |
| L30.28 | 完了 | field/measureの子はstructural modeに固定。FieldRef全体と同じmeasureの一致を照合。七measureのraw・上層の受理と、measure違い・整数hypによる受け手の同一視・入力sort違いの拒否を確認。Setの正常観測とnoneを区別 |
| L30.29 | 完了 | EqCertificateTypingのTerm.AdmissibleIn/EqProof.AdmissibleIn/checkInとKeyTable.checkIn。全16sort、両端点・transの中間・全子、同じPのVarianceValid、全Φのsort/宣言を検査。具体のBoxの宣言表はVarianceValidも満たす。整数欄の受理と範囲外欄の拒否、Φの二つのeqの不適格と中間項のAdmissibleInの不成立、13形の非整数鍵の拒否を同じ上層の入口で確認 |
| L30.30 | 完了 | rewritePosition/specをAのRewritePositionに対応させ、substitute_sound_atでp.openの前後を任意のν上で合成。substituteIn/sound_atは等号・置換位置・開いた前後のsort/Declaredを合わせて検査。Setの危険な書換えを拒否し、整数射影が等しくても鍵の観測が変わる反例を保持。Term20/Pred14の比較はBのtermEq/predEqをそのまま使用 |

今回の証明は群D・Eの局所規則である。Refutation9構成子を合わせる帰納は群Gの.37で一度行う。Refutation.builtinは構文を置き、現在はfalseで拒否する。登録補題のrawな規則は群F、その接続は群Gである。Certificateは6構成子と構造一致のsubstituteを保つ。7構成子化、refutation_entails、checkedAtと四帰納は群G、LeQと実際の葉への接続は群Kの担当である。

## 群Dの規則と同じνの上の意味

`NNF.HoldsAt keys ν η q`は`predBind ν (q.toPred keys)`の真である。`BranchHoldsAt`はtodoとfactsの全要素についてこの条件を要求し、`BranchRefutedAt`はそこからFalseが従うことを表す。literalにもνを適用する。鍵のmapだけで置き換えない。

| 規則 | 検査と意味の接続 | 受理・拒否の対照 |
|---|---|---|
| combine | 現在のfactsの各線形の葉、非負乗数、同じ列長、再計算した全係数と上限 | 空和・一項・複数項・零乗数／負乗数、未知の位置、列長・期待式の不一致 |
| round | d>0、元係数=出力係数のd倍、出力bound=元bound/d、出力長=鍵数 | [2],−3→[1],−2／零・負の除数、非整除、−1への丸め、未知の参照 |
| consume/cases | truth/falsity/linear/literal/And/Orを区分し、Orは両枝を元のfactsから検査 | Or(falsity,falsity)／Or(falsity,truth)、consumeによるOr、兄弟だけにあるfacts |
| split | 実在する鍵のνの像の整数射影でx≤cut又はcut+1≤x。左右は別の追記列 | 2*x=1を、左右それぞれで分枝により加えた事実とcombineから反証／右の結合を左と同じにした証拠、片枝の成功と未知鍵 |
| closeLinear | 全係数0かつ負のbound | 0≤−1／0≤0、非零係数 |
| closeAtom | 構造が同じ原子の正負を現在のfactsから読む | memberとFloat分類の正負／異なる原子、同じ符号、正負の位置の入れ替え |
| discardTodo/discardFact | 捨てた後の弱い前提でも矛盾することを子から得る | Orを展開せず捨てる、削除後index0／旧index1、範囲外の削除 |

空和や矛盾の符号化の健全性には列長を要求しない。combine/roundが出力を整える検査と、`Linear.toPred_sound_at`の意味の前提を分ける。`LinearStep.sound`に渡す環境は常に`keyEnv η (keys.map (termBind ν))`である。splitの対象はNatの鍵番号を保ち、一般の線形式へ作り替えていない。

## EqProof9構成子と16sort

| 構成子 | structural | integer | 途中の適格性 |
|---|---|---|---|
| refl | 実端点の構造比較 | 同じ比較から整数射影の等値 | 両端点のsortと宣言 |
| symm | 逆向きの子 | 逆向きの子 | 同じsort/mode |
| trans | 明示したmiddleへの二つの子 | 同左 | middleも同じsortと宣言 |
| add | 構造の合同 | 整数射影の加算 | 子は整数sort |
| neg | 拒否 | 負号の合同 | 子はinteger mode・整数sort |
| scale | 拒否 | 同じ数学Intの係数による合同 | 係数を両端点で照合し、子はinteger mode・整数sort |
| hyp | 拒否 | 現在のΦの整数eq | 全Φのsort・宣言を上層で検査 |
| field | 同じFieldRefとstructuralの子 | 同じ構造一致から射影の等値 | 子はdata sort。両端点のDeclaredが同じPで受け手・名目型・constructor・型引数・欄位置・結果sortを照合 |
| measure | 同じmeasureとstructuralの子 | 同じ構造一致から射影の等値 | 七measureそれぞれの入力sort |

16行は`EqCertificateExamples.sortCases`の同じ`EqProof.checkIn`に対する受理として確認した。integer modeは整数sortに限り、structural modeは次の全sortを受ける。

| sort | 具体の文脈の型 | sort | 具体の文脈の型 |
|---|---|---|---|
| integer | Integer8 | character | Character |
| float64 | Float | float32 | Float32 |
| decimal | Decimal | boolean | Boolean |
| unit | Unit | string | String |
| list | List Unit | bytes | Bytes |
| map | Map Integer Unit | set | Set Integer |
| data | Box（同じPのBox.Make） | target path | 範囲TopのPath |
| target host | 範囲TopのHost | target endpoint | 範囲TopのEndpoint |

上層の宣言の判断と`P.VarianceValid`は非計算的な決定可能性でBoolへ写す。これは既存の上層と同じ区分である。実行可能なraw核、termEq/predEq、rewritePositionの計算と混同しない。公理の監査はこの上層も含めた。rawの意味の健全性は、これらの宣言条件を未検査の仮定として使わない。

`FieldRef`が同じで、structuralの子から受け手の項そのものが等しいため、両端点では同じ型引数の宣言の証人を使える。欄のsortの検査と`VarianceValid`は別に要求する。任意の数の等値からfield/measureの合同を作らない。Floatの数の等号をビットの一致と扱う規則も追加していない。

throughBooleanが参照するΦの二つのeqは、整数とBooleanを比較しており、eqの両辺の整数sortの条件を満たさない。上層はこのΦの不適格と中間項のAdmissibleInの不成立の両方で拒否する。各条件の不成立は別々の例でも確認した。この例を中間項の検査だけが拒否する例とはしない。整形式のΦで中間項の検査が単独で拒否する入力の有無は、本作業では証明していない。

## 主な署名と追加した宣言

[signatures.md](signatures.md)に全署名を保存した。群Aの固定署名からの変更は0である。既存の内部補助の変更は、Bの`linearDot_zero`をprivateから公開へ移した一点で、型と本体は同じである。同じ零係数の帰納を複製しないために使う。数学の幅を固定する変更はない。

主な健全性の入力と結論は次のとおりである。

```lean
theorem LinearStep.sound {n : Nat} {facts : List NNF} {step : LinearStep}
  (h : step.check n facts = true) (ρ : Nat → Int)
  (hf : ∀ q ∈ facts, ∀ a, q = .linear a → a.Holds ρ) : step.result.Holds ρ

theorem EqProof.integer_sound_at {Φ : List Pred} {t u : Term} {c : EqProof}
  (h : EqProof.checkRaw Φ .integer t u c = true)
  (ν : ObservationEnv) (η : ObservationEnvModel)
  (facts : ∀ p ∈ Φ, (predBind ν p).interpret η = true) :
  integerAs η (termBind ν t) = integerAs η (termBind ν u)

theorem EqProof.substitute_sound_at {Φ : List Pred} {mode : EqualityMode}
  {t u : Term} {c : EqProof} (h : c.checkRaw Φ mode t u = true)
  {p : Pred} (hp : rewritePosition p mode = true)
  (ν : ObservationEnv) (η : ObservationEnvModel)
  (facts : ∀ q ∈ Φ, (predBind ν q).interpret η = true) :
  (predBind ν (p.open t)).interpret η = (predBind ν (p.open u)).interpret η
```

各枝の局所規則は`CertificateKernel.*_sound_at`である。例えばderiveは、検査したstepと子の検査成功を受け、子の任意のtodo/factsに対する`BranchRefutedAt`から親の同じ条件を返す。casesとsplitには左右の子の健全性を別々に渡す。群Gではtodo/facts/keysを一般化した一回の帰納の帰納仮定を、これらの引数へ渡せる。

| 新規モジュール | 主な宣言 | 既定の読者 |
|---|---|---|
| LinearCombination | LinearStep、NNF.linear?、linearCombination/sound、LinearStep.result/check/sound | refuteのderive、derive_sound_at、RefutationExamples |
| PreparedLeafSyntax | BuiltinLemma12種類、PreparedLeafの4欄 | Certificate、Refutationのbuiltinの構文。登録規則本体はF/K |
| RefutationSyntax | Refutation9、CertificateKernelのconsume/cases/split/close/discard/refute | 各局所soundとRefutationExamples |
| RefutationSound | NNF.HoldsAt、normalize_holds_at/normalize_linear_at、BranchHoldsAt/BranchRefutedAt、8つの局所健全性 | RefutationExamplesの正規化・consume・combine・round2回・cases・split・close/discardの合成 |
| RefutationExamples | namedなcombine_refutes_at/odd_refutes_at/consumed_refutes_at/normalized_refutes_atと受理・拒否の適用例 | formal/Benitoite.lean |
| EqProofSyntax | EqProof9、checkRaw/structural_sound/integer_sound_at、check/soundの移動 | EqCertificate、EqCertificateTyping、Certificate |
| EqCertificateTyping | Term.AdmissibleIn、KeyTable.checkIn/sound、EqProof.AdmissibleIn/checkIn/checkIn_sound/integer_sound/substituteIn/substituteIn_sound_at | EqCertificateExamples |
| EqCertificateExamples | 9構成子、別名の実像、16sort、七measure、非整数鍵・途中sort・宣言・Setの対照 | formal/Benitoite.lean |

既存のEqCertificateへ、二つの決定可能性のinstance、rewritePosition/spec、EqProof.substitute_sound_atを追加した。既存のCertificateからEqProofと葉の構文を下層へ移し、importで保った。Linearizationは共有補助の公開だけ、formal/Benitoite.leanは新しい二つの適用例のimportだけを変更した。01-12と07-04は実物の定義・規則・前提を写し、経緯を追加していない。

## 検査・公理依存・入力の識別（初回）

基準・未コミットの対象ファイル・入力と設定のSHA-256は[initial-inputs.json](initial-inputs.json)、workの終了・時間・生記録の識別は[initial-work-summary.json](initial-work-summary.json)、公理依存は[initial-audit-summary.json](initial-audit-summary.json)に保存した。`formal/lean-toolchain`はLean 4.34.1、実機のLeanはarm64-apple-darwin24.6.0、commit `5045d0056413266e57c625dcd7c365b10e377c52`である。既定と局所のメモリ上限はいずれも12288 MiB。正式RSSは未取得（計画上の非採取）である。

作業末は`--only`を使わず、次を一度実行した。先に同じ指定の`--dry-run`で選択内容を確認した。

```text
scripts/check.sh --level work --base d4593f42acb91e3bbefd0ced45176f0ca02ac439
```

終了0、外側9.307秒。選択された中身は仕様参照の自己検査・集計（spec_tally）、仕様の例（spec_examples、7件成功）、既定全ターゲットの`lake build`とsorry警告の拒否（formal_build）である。増分ビルドであり、clean buildとは記していない。formal_buildの成功出力はcheck.sh自身が内部に捕捉して表示しないため、ビルドだけの秒数・job数は未取得である。同じ入口の成功と、後述の既定importからの監査を根拠にする。仕様参照のない節の一覧は集計の情報表示であり、不合格ではない。Rustの実装の変更は0で、全libやclippyを追加実行していない。

公理監査の再生成は次の台本を使う。対象名を手書きせず、既定モジュールをimportした環境のmodule indexから25モジュールの全宣言を列挙する。privateと生成宣言を含め、旧Releaseの主定理・モデルと新しい主要十移送を追加する。

```text
python3 docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l30/d/audit.py --tmp <tmp>
```

終了0、外側2.841秒、対象1,489宣言。公理なし635、propextのみ653、propextとQuot.soundの二つ28、許可三公理173である。依存の和集合はpropext・Quot.sound・Classical.choiceのみ。sorryAxと新しい公理は0である。主な局所健全性とinteger_sound_at/substitute_sound_atは既存の意味の定義を通じ許可三公理に依存し、EqProof.soundはpropextだけに依存する。新規8モジュールだけでなく、変更した旧Certificateと群A〜Cの宣言も監査した。

| 生の記録（保存先は`<tmp>`） | バイト | SHA-256 |
|---|---:|---|
| work.log | 5757 | `4095451dbe32572306467ac979d33d7beafaf407e2adc86c662499d935f37fa5` |
| axioms.log | 290795 | `baf5098bda30d73c4bab5ce41d5e54fd4a7aacad5e603eb427ca558af9790d19` |
| audit-targets.txt | 108711 | `990c98bcf6e29bcf66371061f909a28b4d020b64d4a8699f820c4d0b6549f187` |

対象名一覧と監査出力は100 KBを超えるので改造へ写していない。台本・件数・SHA-256から再生成・照合できる。初回のworkから初回報告まではLean・設計書・設定・仕様の例を変えていない。記録と署名の文書の整理だけを行った。同じ状態の本番の検査を追加反復していない。交換器・manifest・入力コーパスの変更や全比較は0であり、形式化の局所規則の成功をRust接続やL70/R50の全比較の成功とはしていない。担当の判定日は2026-11-03である。

途中は関係するLeanを`lake env lean -M 12288`、そのimport元を対象指定の`lake build`で検査した。局所の初回失敗は、Boolの補題名、Bool/Propの括弧、matchの展開、暗黙引数の型、証明項の組の括弧、非計算的なObservationの等号の具体計算をsimpで示す箇所である。修正後は同じ局所モジュールの検査を通した。最終workと公理監査に失敗はない。新しいソースの警告0。局所ビルドではTypeSubst/RangeSubstの既存unusedSimpArgs警告を再表示したが、その二ファイルは変更していない。

適用例にはtest-auditの作成時の関門を適用した。守る境界は有限証明書の検査結果と、その同じ入力の意味である。負乗数、改竄した係数と上限、負の床の零方向への丸め、片枝だけの受理、兄弟の参照、削除後の旧index、Setの鍵への整数書換えが退行したときに失敗する。throughBooleanはΦの不適格と中間項の条件違反が重なるため、中間項の検査の省略だけを検出する例とは数えない。群Aは方式の意味の補題、群B・Cは線形化とNNFまでであり、今回の検査結果の契約を覆わない。実際の定義を使い、差し込み口とRustのテストを増やしていない。全16sortと七measureは同じ入口の表として扱う。

## 計画との差と取りまとめへの受渡し

固定された公開署名・方式からのずれは0。内部の配置は、構文をEqProofSyntax/PreparedLeafSyntax/RefutationSyntax、上層のsort・宣言をEqCertificateTypingへ分けた。旧Certificateの公開の名前はimportで維持する。新しい内部補助の全署名はsignatures.mdに記した。

Dの8規則は子の検査器とその健全性を引数にする局所の補題として閉じた。Refutation全体の帰納を先取りして後で重複させていない。Gでは現在のrefuteの式を展開し、同じ子に対する帰納仮定を各局所補題へ渡す。FはPreparedLeafSyntaxの固定済みの12種類と4欄を使い、builtinの本体を接続する。GはCertificate7構成子・整数modeのsubstituteとEqProof.substitute_sound_at、同じνの上の全健全性を接続する。上層はKeyTable.checkInを使って鍵のsort・宣言を検査する。これがRV-L30.b軽1のE担当分である。

取りまとめの新しい設計判断を要する点は0。必要な残りは独立レビューとその所見の処置、群F・Gへの依存順の受渡しである。依存の勧告は共通依頼文の2026-10-30の照合と「組み込まない」の判断を継承し、更新を相乗りしていない。今回の短い外側の時間から他群の能動時間を一律に外挿していない。

## 単位ごとの外側の時間

時計の値は[times.json](times.json)へ各区切りで順に保存した。同じ区間を複数の単位へ配っていない。最初の時計取得前の依頼文・既存資料の読取りは未採取であり、下表に含まない。各区間は局所ビルド・検査待ちを含む外側の時間で、能動時間を分離した値ではない。.24の区間に群Dの初回の対照例、.30の区間に群Dの丸めの意味の合成の追記・群Eの全対照例・写しの更新を含めた。個別の単価として他の単位へ掛けない。

<!-- 単位の時間表と義務表は下に記す。 -->

| 単位 | 開始〜終了（+0900） | 外側の時間 |
|---|---|---:|
| L30.19 | 08:13:05〜08:13:19 | 14.043秒 |
| L30.20 | 08:13:19〜08:14:01 | 41.945秒 |
| L30.21 | 08:14:01〜08:14:23 | 21.426秒 |
| L30.22 | 08:14:23〜08:14:55 | 32.076秒 |
| L30.23 | 08:14:55〜08:15:25 | 30.782秒 |
| L30.24 | 08:15:25〜08:16:37 | 71.886秒 |
| L30.25 | 08:16:37〜08:17:14 | 36.915秒 |
| L30.26 | 08:17:14〜08:17:36 | 21.645秒 |
| L30.27 | 08:17:36〜08:17:46 | 10.599秒 |
| L30.28 | 08:17:46〜08:18:54 | 67.678秒 |
| L30.29 | 08:18:54〜08:20:23 | 88.804秒 |
| L30.30 | 08:20:23〜08:24:37 | 254.063秒 |

観測した実装の区間はDが212.157秒、Eが479.704秒、計691.861秒である。上記の読取り未採取分を含む担当全体の確定値ではない。群末の検査と結果文書は08:24:37以後であり、単位別の区間へ二重計上しない。workと監査の待ちは上記の9.307秒と2.841秒である。独立レビュー・設計者の受け入れ待ちは今回の区間へ含めない。見込みの上端の2倍と4時間の途中報告条件には達していない。

## 義務の一行ずつの判定

管理対象の35行を照合した。完了はD/Eに割り当てられた部分だけであり、義務行全体の閉鎖は0である。

| 義務 | D/E担当分の判定と証拠 | 残る担当・時期 |
|---|---|---|
| O015 | 完了。EのcheckInによる全16sortと途中のsort・宣言の照合 | F/Kの原子の有限規則、L40/L50 |
| O017 | 今回の実装対象なし。U03を継承 | Lの計上、R20/R50/R60 |
| O019 | 完了。Dの8規則、EqProof9構成子のraw健全性・限定合同と拒否 | F/G/Kの全Certificate/Refutationと登録規則、R20/R50 |
| O020 | 完了。discardTodo/discardFact、Orを展開せず既知矛盾で閉じる具体例 | Gの全反証、Lの計上、R20/R70 |
| O021 | 今回の実装対象なし。時間の区間を記録し、見込みの変更は行わない | 担当の単位は.06/.48/.72/.80。取りまとめ、L40/R20 |
| O022 | 完了。等号9規則・全sortと欄/measureの有限照合。宣言条件は同じPで検査 | F/H/I/J/Kの本番の事実、L40/L50/L60 |
| O023 | 今回の実装対象なし。by decideの検査は全Certificateの実行再生とはしない | G.42/M.74、R50 |
| O026 | 今回の実装対象なし。数のモデルを実値の反例と呼ばない | J/L、R20/R60 |
| O034 | 今回の実装対象なし。正常算術の三条件を構成したとはしない | J/K、L40/L50/L60/R50 |
| O043 | 今回の実装対象なし。Ty.LeQへ新しいCertificateを接続したとはしない | G/K、L40/L70 |
| O050 | 完了。structural/integerの分離、途中のsort/宣言、Set鍵と非整数鍵の拒否 | G/Jの接続と観測、L40の標準葉 |
| O054 | 今回の実装対象なし。Booleanの相異の登録補題を追加していない | F/G/K、L40/L70/R10b |
| O071 | 完了。非負結合、負の床と整除、2*x=1、全被覆のsplit、両枝とdiscardの局所健全性 | F/G/L、R20/D10 |
| O072 | 完了。実像のrefl、同じ欄・measureのstructural子。一般UFを追加しない | Jの観測、R10b/R20 |
| O127 | 今回の実装対象なし。文字区間包含の有限規則は未実装 | F/I/J/K、L40/R段/V10 |
| O130 | 今回の実装対象なし。String二長の意味の一致は今回の担当外 | F/J/K、L40/R段/V10 |
| O131 | 今回の実装対象なし。Listの非負と非空の葉は未実装 | F/G/J/K、L40/R段/V10 |
| O132 | 今回の実装対象なし。Bytesの正常結果を機械幅へ結んでいない | F/J/K、L40/R段/V10 |
| O133 | 今回の実装対象なし。Mapの鍵の言語上の等値を追加証明していない | J/K、L40/R段/V10 |
| O134 | 今回の実装対象なし。Setの危険な書換えの反例は保持 | J/K、L40/R段/V10 |
| O135 | 完了。具体の同じPのVarianceValidとFieldRef.Declared、不変欄の構造合同・実像の照合 | J/K、L40/R40/R50/V10 |
| O136 | 担当の.19分完了。同じ鍵列・νで線形化とNNFの意味を合成。依存端点のLeQ接続は未実装 | G.39/K.64、L40/L70/R段/V10 |
| O137 | 今回の実装対象なし。数学Intの証明を機械整数の正常δとはしない | I/J/K、L40/R段/V10 |
| O144 | 完了。Dの整数/論理の局所規則とEのEqProof・限定合同・適格性。探索完全性を仮定しない | F〜Kの残る規則と全接続、L40/L50/R段/V10 |
| O158 | 今回の実装対象なし。独立の深さ/枝数/証明書量の上限を追加しない | L、R20/R70/V10 |
| O161 | 今回の実装対象なし。数学の係数と上限はIntのまま | Lの幅の数学対応、R20/R60/V10 |
| O167 | 完了。raw/上層の非整数鍵13形、危険なSet書換え、欄の不一致と途中のsortの対照。E.29の鍵のcheckInを実装 | G.38で上層の全証明書へ接続、F〜K/Lの残り、L40/L70/R段/V10 |
| O046 | 今回の実装対象なし。捕捉した条件の本番の葉を再証明しない | F/G/J/K、L40/L70 |
| O079 | 今回の実装対象なし | Kの非空Listのactual Certificate、L70/R10b/R50 |
| O138 | 今回の実装対象なし。Booleanの有限葉と短絡の合成は未実装 | F/G/K、L40/L70/R段/V10 |
| O143 | 今回の実装対象なし | Kのlengthの証明書、L40/L70/R段/V10 |
| O016 | 担当分完了。既定importの25モジュール・private/生成宣言・旧主定理と主要十移送の1,489宣言を監査し許可三公理だけ | 独立レビュー、Nの全段A-L、L70 |
| O084 | 担当分完了。実装・自己点検・独立レビュー・全体の受け入れを分け、今回の範囲と残りを記録 | M/Nと全L/R/K/V |
| O027 | 担当分完了。既定/局所の-M12288、workと監査の終了と時間、RSSは未取得（計画上の非採取） | Nの最後の同じworkへ取りまとめが正式採取 |
| O118 | 担当分完了。01-12/07-04の実際の定義・規則・前提の写し。本番へ作業IDや絶対パスを追加しない | N、L70/R50/R60/D10/V10 |

## 再開1: RV-L30.dの軽1〜5の処置

2026-11-03。独立レビューRV-L30.d（可、重0・中0・軽5、情報4）と再開の指定に従い、5所見を処置した。ブランチとB_WORKは初回と同じである。公開の主定理・健全性の言明、係数の数学Int、案(ii)checkedAtを変えていない。追加の公理・sorry・信頼条件・提供範囲の削減は0。gitの状態を変える操作、処理系・旧Release・plan・detail・README・レビュー記録の変更はない。

| 所見 | 処置 | 確認 |
|---|---|---|
| 軽1 | RefutationExamplesにsplitOddLeft/splitOddRightと受理・拒否を追加。factsは2x≤1と−2x≤−1。左は2·(x≤0)+(−2x≤−1)、右は2·(−x≤−1)+(2x≤1)で、それぞれ分枝が位置2へ加えた事実を読む。丸めを使わず0≤−1を導く。右に左と同じ結合を渡す証拠は拒否。closeAtomの正負の位置を入れ替えた拒否も同じ表に追加 | by decideによる検査結果と、split_sound_at/derive_sound_at/close_linear_sound_atを合成する任意のν上の具体読者を確認 |
| 軽2 | throughBooleanのコメント、L30.29・対照例の主張、07-04を修正。Φの二つのeqは整数とBooleanを比較するため不適格であり、中間項のAdmissibleInも満たさない。Φの不適格とAdmissibleInの否定を別々の例で示した | rawの受理と上層の拒否は維持。この例を、中間項の検査だけが拒否する例として扱わない。整形式のΦで単独に効く例の存在・不存在は未証明であり、断定しない |
| 軽3 | PreparedLeafのarguments/referencesの既定値を削除し、signatures.mdも修正 | 既定値を使う構成はなく、利用者の追随変更は不要。二つの欄を必ず明示する群Aの固定署名に一致 |
| 軽4 | Certificate.leanのEqCertificateTypingのimportをEqProofSyntaxへ変更。読者の表から「Certificate経由の上層の入口」を削除 | Certificateが使うEqProof.check/soundはEqProofSyntaxから供給。EqCertificateTypingの読者はEqCertificateExamples |
| 軽5 | 01-12と07-04に、LinearStep.soundの前提を「現在のfactsのすべての線形の葉のHolds」と明記 | 本番のhfの量化の範囲と一致。証明と署名の変更なし |

適用例の作成時の関門は、splitが加える係数・上限、左右の結合、closeAtomの位置の意味を有限検査の入口で確かめるものとして通した。初回のsplit例は既知の矛盾だけで閉じるため、新たな係数・上限の誤りを検出しなかった。追加例は両枝の追記事実を使うので、この退行で検査結果が変わる。既存の未知鍵・範囲外参照の例は別の拒否条件を守るため保持し、同じ意味の受理例の重複は置かない。以前の既知矛盾によるsplitの意味の適用例は、追記事実を使う例に差し替えた。本番の差し込み口とRustのテストは追加していない。

### 群F・Gへの申し送り

- 情報1（群G）: Refutationの一回の帰納でderive_sound_atを使うときは、単一化のため`step`と`(next := fun ts fs => refute keys ts fs c)`を明示する。他の局所補題と同じ帰納仮定を渡せる。署名を変えたり、全反証の帰納をここで増やしたりしていない。
- 情報4（群F・G）: builtinのraw検査を接続するときは、RefutationSyntaxに必要な論理のimportを加えるか、refuteの定義をCertificateKernel側へ移して依存を整える。同じ変更で01-12の「組込みの葉を指定するbuiltinは拒否する」と07-04の「builtinは拒否し」を実装どおりに更新する。

上層のcheckIn等が非計算的でrawの実行比較と区別される点（情報2）は本文の区分を維持する。公理監査が読むのは名前のある定数であり、anonymousなexample自体は対象名一覧に入らない（情報3）。追加したanonymousな対照例は、既定ビルドのLeanの核とsorry拒否で検査する。監査ではその例が使う定義・補題、privateのsplitOddLeft/splitOddRightと生成宣言を含める。

### 再開1の検査と入力

初回の監査・work・入力のJSONをinitial-*.jsonへ保持した。audit-summary.json・work-summary.json・inputs.jsonは再開1の最終状態を表す。単独Leanの上限と既定lakefileの上限はいずれも12288 MiB。正式RSSは未取得（計画上の非採取）。検査の数値・生出力の識別と外側の時間は以下に記す。

| 検査 | コマンドと対象 | 結果 |
|---|---|---|
| 局所Lean | 二つの適用例をそれぞれlake env lean -M 12288で検査 | 終了0、警告なし |
| 既定ビルド | formalでlake build。既定targetsすべて、増分 | 終了0、920ジョブ、外側2.101秒 |
| 公理監査 | audit.py --tmp <tmp>。既定importの25モジュール・旧主定理・主要十移送、private/生成宣言 | 終了0、1,489宣言、外側2.788秒 |
| 作業末work | scripts/check.sh --level work --base d4593f42acb91e3bbefd0ced45176f0ca02ac439を、--onlyなしで一度実行 | 終了0、外側3.701秒。仕様参照の自己検査・集計、仕様の例7件、既定ビルドとsorry拒否 |

workは先に同じ指定のdry-runを確認した。上記の独立した既定ビルドとwork内の既定ビルドは、再開の依頼が両方を指定したため実行した。workの反復は0。既定ビルドは変更していないモジュールの既存のLean警告と、実行ファイルのリンク時の既存のライブラリ探索パス警告を再表示した。今回の変更モジュールの新しい警告とsorryは0。再開1の検査で失敗はない。

公理依存の内訳は、なし635、propextのみ653、propext＋Quot.soundが28、許可三公理173である。sorryAx・独自公理は0。既定値の生成宣言2件が減り、splitの左右の証拠のprivate定義2件が増えたため、総数は初回と同じ1,489だが対象名一覧のSHA-256は変わった。

| 生の記録（保存先は`<tmp>`） | バイト | SHA-256 |
|---|---:|---|
| lake-build.log | 43678 | `9146a8673fdad9f4a81563ec5ed56f12c68c052a9678760d7eccb2a9358354e8` |
| axioms.log | 291031 | `cf035f722876c8a5d2350d76e6921d6d625dc6b79d9f746220bf7263cc22a016` |
| audit-targets.txt | 108829 | `1fd0e3daefd2bf67eb6d31ab6fb77497dafbb7bfe0117389644f09d91747d7b7` |
| work.log | 5757 | `7826d2f47446360f483549b36ece9020ae192a284cf470938d7373632542a689` |

計時開始は08:41:19、結果の数値を記録した時刻は08:44:26（+0900）、この区間の外側の時間は187.212秒である。最初の資料読取りの後に時計を取得したため、その前の読取りは未採取。局所検査・既定ビルド・監査・workの待ちを含み、能動時間へ読み替えない。最終の記録照合と報告の時間はこの後である。計時と行数差分は[resume1-summary.json](resume1-summary.json)に保存した。

本番の2ファイルはimportの置換と既定値の削除で行数の増減0。適用例の行数差分は次のとおりである。テストの契約を削除した件数0。既知矛盾で閉じるsplitの意味の例を差し替え、他の拒否例を保持した。

| 適用例 | 行数の増減 |
|---|---:|
| RefutationExamples.lean | +21 |
| EqCertificateExamples.lean | +11 |

検査後のLean・設計書・設定・仕様の例の変更は0。以後は検査の記録の追記と入力のハッシュの照合だけを行う。軽1〜5の担当の処置はすべて完了。レビュー自体は再レビュー不要とした。取りまとめによる処置の確認と受け入れは未実施であり、担当の自己点検で代用していない。新しい判断を求める点はない。

## 作業末の work

取りまとめが、RV-L30.d（可。所見は軽だけで、レビューは再レビューを要しないとした）の処置の後に、Refinement の生成物を消してから一度実行した。

| コマンド | 終了状態 | 外側の時間 | 最大常駐量 |
|---|---|---:|---:|
| `scripts/check.sh --level work --base d4593f42acb91e3bbefd0ced45176f0ca02ac439` | 0 | 150.35秒 | 1,690,943,488 バイト |

選ばれた検査は、仕様対応の自己検査・集計、仕様例（7件成功・失敗0・無視0）、既定の Lean ビルドと `sorry` の拒否である。
