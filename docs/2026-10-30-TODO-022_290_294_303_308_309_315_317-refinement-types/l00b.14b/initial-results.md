# L00b.14b: 捕捉した Φ の結果

2026-11-01。**分類は「閉じた」**である。[完全署名](initial-signatures.md)に記した捕捉 Φ と一引数の `.closure` 呼出しの代表を閉じた。状態の定理は、開始の `StateTyE` を逆転しない同時構成である。捕捉・本体・実引数・継続の同じ入力から開始と到達を作るもので、全状態の保存の完成ではない。

指定ブランチは `m014/l00b.14b`、B_WORK は `b32ef9c93b89e43131a1c96831a4eadfb6fa9512`。Git の操作は行っていないため、指定された基準の内容との独立した照合はしていない。今回の開始時の入力のハッシュと現在の差は [source-delta.json](first-source-delta.json) に記録した。処理系・設計書・plan・既存のレビュー記録・rv-* は変えていない。work・Rust/Lean の全比較・独立レビュー・受け入れは実行していない。L00b.14c には進んでいない。

## 閉じた本番の補題

新規の本番ファイルは [CapturedFacts.lean](../../../formal/Benitoite/Release/Refinement/CapturedFacts.lean)（166行）である。既存の `formal/Benitoite.lean` には import を1行追加した。それ以外の既存の本番ファイルは変更していない。新しい定義・判断・遷移・Lean の公理は0で、公開補題6本を追加した。暗黙引数を展開した型は [public-api.log](first-public-api.log) にある。

| 補題（共通接頭辞は Benitoite.Release.Refinement） | 閉じた内容 |
|---|---|
| CaptureOk.evaluated_fact | 型付き像で閉じた述語の WellFormed を導き、真偽は evalClosed の成功と Entails.ground から導く |
| CaptureOk.addEvaluated | 評価に成功した条件を Φ に加え、Γ.facts・新条件・古い Φ の各閉じた導出を構成する |
| CaptureOk.close_entails | 元の Γ.facts ++ Φ の有限導出を bind と cut で閉じ、仮定なしの導出を得る |
| HasTypeTelArgsQ.captured_one | 一引数の逐次具体化と cap.extend v による結果・効果の具体化を一致させる |
| StateTyE.captured_beta_one | 捕捉した Γ/Φ を持つ実行時の .closure の E_Lam と、その両側の StateTyE を同時に構成する |
| StateTy.captured_beta_one | 同じ σ.Valid と固定 Eb の証人で両側を StateTy に戻す |

`evaluated_fact` が型付き像から得るのは、述語の番号・sort・宣言照合である。任意の Φ の真偽を型付き像から得る仮定は置いていない。`addEvaluated` が使う新条件の真偽は、閉じた式の評価の成功である。既存の Φ は元の CaptureOk の導出を再利用する。

状態の到達では、前段の `closure_one`・`hideConts_any` を使う。閉じた Annotation と Normal は捕捉の型付き置換と正規化から得るため、ソースの列を正規形に限らない。捕捉を本体の hideConts Γ と return の型に合わせてから `CaptureOk.extend` を使う。新しい Γ.facts の再構成は、その内部の `facts_extend` が受け持つ。Ψ・μ・σ・b・ε・Eb は両状態で同じ証人を使う。

代表に残る限定は、一引数、型・行・範囲の実引数なし、本体の局所参照が空、呼出し元が Closure.pure、実引数の Ground と `closeVal Capture.empty v = v` である。捕捉 Γ/Φ、呼出し元の R、継続、ストアは任意である。閉性・適格性・R の整形式の証拠は既存の StateTyE が読む条件として受け取る。開始の V_Closure/V_Sub/TelClosure の一般逆転を行ったとは主張しない。

## 実際の遷移と非空の facts

[boundary.lean](boundary.lean)（326行）は、本番の型付け・評価器・Step・StateTy を使う補助入力である。捕捉する Γ は一つの `Integer`、その値は7、Φ は「捕捉した値 < 8」である。`captured` は、型付き像だけを持つ `images_only` に `addEvaluated` を適用する。必要な `phi_evaluates` は、実際の `evalClosed` の計算で閉じており、Entails や CaptureOk の結論を入力に取らない。

渡す実引数は3で、型は `Integer{0 ≤ self}` である。`argument_facts_nonempty` は延長後の Γ.facts に `0 ≤ var 0` が含まれることを示す。`extended_facts` は実際の `facts_extend` を適用し、新しい引数の事実 `0 ≤ 3` と、移動した Φ を閉じた `7 < 8` の両方を得る。`extended_ok` は同じ実引数で `CaptureOk.extend` を使い、`closed_body_fact` はその捕捉から `close_entails` を使う。

本体は `if c then return x else return 0` である。両枝の結果型は、引数の非負性と、外側の捕捉値が8未満という条件を持つ。`return_argument` と `return_zero` は、追加する篩の導出で Φ を仮定として実際に読む。`body_requires_phi` は、同じ Γ の引数 facts だけではこの結果型を導けないことを証明する。したがって Φ がなくても通る例ではない。

`execution c` は、c=true と c=false のそれぞれについて、`.closure` の値を呼ぶ E_Lam、続く E_IfT/F、その三状態の StateTy を構成する。`selected_view` が示す実際の返り値は3または0である。`returned_typed` は同じ本体の導出を捕捉した環境で置換し、その値に閉じた結果型を与える。これは StateTy の逆転ではない。結果型の具体形は `Integer{0 ≤ self ∧ 7 < 8}` で、`result_is_closed` と `returned_facts` で照合する。

現行の C_If は枝に新しい Φ を追加しない。この境界は、評価成功から先に構成した Φ を、実際の分岐の後も保持して読めることを示す。比較の評価から分岐条件を一般に生成する接続は後の L40 に残る。存在しない述語評価の Step を作ったり、Boolean の結果だけから任意の述語を得たりはしていない。

## 環境を捨てる反例と負例

主な反例は `environment_counterexample` と `environment_cannot_be_forgotten` である。本番の定義の上で、7を持つ cap と8を持つ otherCap に、同じ Γ と空の Φ の CaptureOk を与える。両者とも型付き像と閉性を満たす。一方、Φ を「捕捉値 < 8」とした CaptureOk は7の環境で成り立ち、8の環境では成り立たない。否定は条件の導出を Entails.sound に渡し、偽の閉じた比較へ帰着させる。環境の長さ違反を理由とする反例ではない。

`open_phi_is_not_closed_fact` は、捕捉で閉じずに元の Φ を仮定なしの事実とする案を否定する。`discarded_capture_changes_view` は、同じ `return (var 0)` から環境を捨てると、実行が読む値も7から既定の Unit に変わることを示す。この既定値による閉じ方では、元の Φ の評価は成功せず、`discarded_capture_evaluation_fails` は none を返すことを計算する。

誤った Φ を「捕捉値 < 7」とした場合は `some false` となる。`no_wrong_phi` は、その条件を同じ cap に登録した CaptureOk を否定する。`wrong_return_untyped c` は、実際の返り値に `Integer{0 ≤ self ∧ 7 < 7}` を与えられないことを facts と Entails.sound で示す。`wrong_phi_wf` と `wrong_result_ann` により、元の述語と型は整形式であり、別の構文違反で拒んだ負例ではない。

## 場合の数と補助契約の選択

| 対象 | 予定 | 実際 |
|---|---:|---:|
| 本番の公開補題 | 6 | 6（私有・生成の追加宣言0） |
| CaptureOk の再構成 | mk の8欄、新しい facts の3場合 | 8欄、Γ.facts・新条件・古い Φ の3場合 |
| 呼出しの遷移 | E_Lam 1場合 | 1場合 |
| 分岐の遷移 | E_IfT/F 2場合 | 2場合。execution は Bool の両値を量化 |
| 新しい判断・遷移の構成子 | 0 | 0 |
| 既存の計算・ContTy・Frame・Step | 24・10・7・76 | 同じ |
| 既存の相互三族 | 76 | 同じ |

補助契約で採った案は次の四つである。主な定理の前提と結論、新しい公理、提供範囲、利用者の書ける形、精密な外部状態は変えていない。いずれも補助の導出の入口の選択であり、主定理が扱う導出を制限しない。

| 論点 | 採った案と理由 | 捨てた案 |
|---|---|---|
| Φ の構成 | 一条件の WellFormed と評価成功から既存 CaptureOk に cons する。古い facts と新しい事実の根拠を区別できる | 型付き像だけから任意の Φ を真とする案、評価失敗を成功へ変える案 |
| 状態定理 | 既存 closure_one・hideConts_any・extend・facts_extend を使う同時構成 | 一般の開始の逆転を未証明で使う案、状態に別の Φ を足す案 |
| 分岐 | 本番の E_IfT/F の前後で、同じ捕捉環境と契約を使う | 現行の C_If や Step にない述語評価の規則を追加する案 |
| 反例 | 本番の CaptureOk と Entails に、同じ型付き Γ と異なる二つの実環境を与える | 小模型だけで環境保持の必要性を説明する案 |

## 捕捉 Φ の残りと送り先

以下は既存の L20/L40 の枠の内数で、全状態の保存はその既存枠のまま表の外である。表の和を O008 全体の残りとしない。[signatures.md](initial-signatures.md)と同じ配分である。

| 残る言明 | 依存 | 能動時間の見込み | 送り先 |
|---|---|---:|---|
| 開始の StateTyE と V_Closure/V_Sub/TelClosure から同じ契約の捕捉と本体を取り出す | closure の逆転、部分型と列の変性 | 3〜6時間 | L40 |
| 多引数・零引数と多相の閉包に、捕捉 Φ の閉じ方を合成する | extendTel、型/行/範囲/値の交換、宣言の WellTyped | 3〜6時間 | L20 |
| 任意の closeVal 実引数について型付けと具体化契約を一致させ、hcv を外す | closeVal の型保存、観測の一致と bind の合同 | 1〜3時間 | L20 |
| 局所参照を持つ本体の捕捉 Φ と CaptureLocals を β・分岐へ接続する | capture_resolved、局所解決とストア拡張 | 2〜4時間 | L20 |
| 分岐・guard/match の動的な観測と経路条件の生成を全入力で接続する | 各観測の canonical forms と閉じた評価の成功、guard の純粋性 | 3〜6時間 | L40 |
| ContTy の各捕捉枠（let/handle/fail/guard）を取り出す遷移で同じ Φ を再構成する | 各枠の逆転、節/return/resume、捕捉した契約の一致 | 3〜6時間 | L20 |

前段の `.closure` の状態への接続という残件は、今回の一引数・空の局所参照の代表について閉じた。前段の残件表の全範囲が完成したとは扱わない。

| 義務 | 今回の段別の判定と証拠 | 残る段 |
|---|---|---|
| O008 | 捕捉を持つ .closure の状態代表と、環境を捨てる反例を閉じた。CapturedFacts と execution/environment_counterexample | L20/L40 の全 StoreTy/ContTy・開始の逆転と一般化 |
| O051 | 捕捉 Φ の評価成功からの導出、非空の引数 facts、β・分岐後の本体への適用を閉じた | L00b.14c〜.14e の Reference・Lazy・節/resume の代表、L20/L40 の全体 |
| O016 | 今回の全本番・境界・既定 import のビルドと公理依存を確認 | 後の L 段、L70 の合成とレビュー |
| O160 | 分類と同時構成の範囲を本書へ記録した | L00b 末の取りまとめ、独立レビューと設計者への再提示 |

## ビルド・公理依存・入力の照合

[verify.py](verify.py)で以下の五検査を実行した。既定の `cd formal && lake build` は717 jobsの増分ビルド、終了0、sorry なしである。lakefile の moreLeanArgs と単独の Lean の両方に `-M 12288` を保った。Lean は4.34.1、arm64-apple-darwin24.6.0。新しい本番と境界の警告は0件で、既存モジュールの lint とリンカの探索先の警告は残る。

| 内容 | コマンド（formal 内。補助入力の … は本ディレクトリ） | 終了 | 外側の時間 | 記録 |
|---|---|---:|---:|---|
| 既定の全ターゲット | `lake build` | 0 | 0.808114秒 | [build.log](first-build.log) |
| β・両分岐・非空の facts・環境保持の反例 | `lake env lean -M 12288 …/boundary.lean` | 0 | 1.212092秒 | [boundary.log](first-boundary.log) |
| 全 Refinement・集約・旧モデル/主定理の公理依存 | `lake env lean -M 12288 …/axioms.lean` | 0 | 12.109391秒 | [axioms.log](first-axioms.log) |
| 新しい公開6補題の完全署名 | `lake env lean -M 12288 …/public-api.lean` | 0 | 0.320675秒 | [public-api.log](first-public-api.log) |
| Lean の実行版 | `lake env lean -M 12288 --version` | 0 | 0.078234秒 | [lean-version.log](first-lean-version.log) |

完全なコマンド、開始時刻、終了状態、出力の大きさと SHA-256 は [verification.json](initial-verification.json) にある。五検査の外側の時間の合計は14.528506秒である。実際の入力と構成は [inputs-sha256.json](first-inputs-sha256.json) と [environment.json](first-environment.json) に置いた。RSS は未取得（計画上の非採取）である。

公理依存は14,001宣言を確認した。Refinement の135モジュールと集約の計136モジュール、旧モデルの仮定充足・限定同値・旧主定理12宣言、境界の87宣言を含む。新規の本番6宣言も全て対象である。依存は propext・Quot.sound・Classical.choice だけで、sorryAx・未承認公理・未監査モジュールは0。[集計](initial-axioms-summary.json)と[場合の数](case-inventory.txt)に残した。100 KB を超える公理の生出力と対象名一覧は tmp に置き、[large-records.md](first-large-records.md) に大きさと SHA-256 を記した。手元の絶対パスは文書と台本に残していない。

[保護対象](first-protected-inputs.json)は、開始時の既存の本番・設定・plan・レビュー・rv-* 等567入力の変更0を記録する。集約の import の追加だけを保護対象から外している。[入力の安定性](first-input-stability.json)は、五検査で読む476入力の検査中の変更0を記録する。本番・境界・署名・監査入力は最終検査後に変更していない。

途中の局所検査では、任意の return 型の暗黙引数の推論、具体化した型・効果と生の式の書換え、空のストアの hide の関数等号、局所置換の行き先の空文脈を明示する箇所で失敗した。これらを型引数と既存の等式の明示で直した。主定理の変更、新公理、未証明の前提で解決していない。初期の局所出力はツールの実行記録にあり、今回のファイルには再構成していない。最終の成功の記録は上表のとおりである。

## 計画との差・時間・次の担当への申し送り

実装の範囲・完全署名・場合の数は予定どおりである。代表の反例と状態の入口を補助入力に置き、本番の規則は変えていない。新しいテストの作成時の関門は signatures に記録した。前段の空の Φ と篩のない引数では検出できない退行を、非空の facts と Φ を必要とする本体で検査している。本番は166行と import 1行、境界は326行の追加で、既存のテストの削除はない。

開始は2026-10-31 17:33:22 UTC、最終の五検査は17:43:08 UTCに終了した。そこまでの外側の時間は9分46秒である。能動時間と局所検査の待ちは分離していないため、能動時間の実測とは扱わない。2〜5時間の見込みの上端にも、10時間の停止条件にも達していない。文書と最終照合までの外側の時間は末尾に記録する。

L00b.14c では、今回の `CaptureOk.addEvaluated`・`close_entails` を、閉じた評価に成功した経路条件の入口として使える。Φ とセル内容の述語を混ぜず、set/update 後のストアと get 後の snapshot の条件は区別する。今回閉じたのは捕捉した不変な値の事実であり、Reference の現内容を述語で読む一般化はしていない。既存 CellOk.val の読み書きと正規化の契約は前段のままである。

| 残る手順 | 担当・内容 | 見込み |
|---|---|---|
| 独立レビュー | 取りまとめ。新しい補題・境界・分類・残件を確認 | 不明 |
| work・基準版との照合・取り込み・受け入れ | 取りまとめと設計者。担当は実行しない | 不明 |
| L00b.14c | 別途起動。Reference/StoreOk の代表を扱う | 計画の2〜5時間 |

文書と最終照合の終了は 2026-10-31 17:47:34 UTC。開始からの外側の時間は14分12秒である。能動時間と待ちは分離していない。最終検査後の本番・境界・署名・監査入力の変更は0である。
