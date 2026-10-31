# L00b.14b: RV-L00b.14b の対応結果

2026-11-01。**分類は「閉じた」**である。[完全署名](signatures.md)に記した捕捉 Φ と一引数の `.closure` 呼出しの代表を閉じた。状態の定理は、開始の `StateTyE` を逆転しない同時構成である。現行の規則は Φ を増やさないので、この代表の Φ は実プログラムから生じない。実行が条件を真にする接続は未検査である。規則の追加は `L00b.14b-paths` で行う。全状態の保存の完成ではない。今回の対応後の独立した再確認と受け入れは未実施である。初回の結果と署名は [initial-results.md](initial-results.md) と [initial-signatures.md](initial-signatures.md) に残した。

指定ブランチは `m014/l00b.14b`、B_WORK は `b32ef9c93b89e43131a1c96831a4eadfb6fa9512`。Git の操作は行っていないため、指定された基準の内容との独立した照合はしていない。初回の開始との差は [source-delta.json](source-delta.json)、今回のレビュー対応の開始との差は [review-source-delta.json](review-source-delta.json) に記録した。処理系・設計書・plan・既存のレビュー記録・rv-* は変えていない。work・Rust/Lean の全比較・独立レビュー・受け入れは実行していない。L00b.14c には進んでいない。

## 閉じた本番の補題

新規の本番ファイルは [CapturedFacts.lean](../../../formal/Benitoite/Release/Refinement/CapturedFacts.lean)（173行）である。既存の `formal/Benitoite.lean` には import を1行追加した。初回からそれ以外の既存の本番ファイルは変更していない。今回の本番の変更は CapturedFacts だけであり、集約の import は初回から変えていない。新しい定義・判断・遷移・Lean の公理は0で、公開補題7本を追加した。暗黙引数を展開した型は [public-api.log](public-api.log) にある。

| 補題（共通接頭辞は Benitoite.Release.Refinement） | 閉じた内容 |
|---|---|
| CaptureOk.evaluated_fact | hc・hp とそれに伴う暗黙引数を外し、evalClosed の成功だけから閉じた導出を得る |
| CaptureOk.addEntailed | 閉じた導出を受け取り、元の条件の整形式と合わせて Φ に加える |
| CaptureOk.addEvaluated | 署名は保ち、evaluated_fact と addEntailed の系にする |
| CaptureOk.close_entails | 元の Γ.facts ++ Φ の有限導出を bind と cut で閉じ、仮定なしの導出を得る |
| HasTypeTelArgsQ.captured_one | 一引数の逐次具体化と cap.extend v による結果・効果の具体化を一致させる |
| StateTyE.captured_beta_one | 捕捉した Γ/Φ を持つ実行時の .closure の E_Lam と、その両側の StateTyE を同時に構成する |
| StateTy.captured_beta_one | 同じ σ.Valid と固定 Eb の証人で両側を StateTy に戻す |

`evaluated_fact` は、評価器自身の WF と Sorted の検査の成功を取り出し、評価成功だけから Entails.closed を構成する。旧の hc・hp は不要なので外した。`addEntailed` は新しい条件の閉じた導出を受け取り、CaptureOk の8欄を再構成する。`addEvaluated` は `hc.addEntailed hp (CaptureOk.evaluated_fact he)` という系である。hp は元の Φ の整形式の欄のために残る。型付き像だけから任意の Φ の真偽を導く仮定は加えていない。評価に成功する条件は同じ入口で作れる。導出だけがある条件は addEntailed を使う。

状態の到達では、前段の `closure_one`・`hideConts_any` を使う。閉じた Annotation と Normal は捕捉の型付き置換と正規化から得るため、ソースの列を正規形に限らない。捕捉を本体の hideConts Γ と return の型に合わせてから `CaptureOk.extend` を使う。新しい Γ.facts の再構成は、その内部の `facts_extend` が受け持つ。Ψ・μ・σ・b・ε・Eb は両状態で同じ証人を使う。

代表に残る限定は、一引数、型・行・範囲の実引数なし、本体の局所参照が空、呼出し元が Closure.pure、実引数の Ground と `closeVal Capture.empty v = v` である。捕捉 Γ/Φ、呼出し元の R、継続、ストアは任意である。閉性・適格性・R の整形式の証拠は既存の StateTyE が読む条件として受け取る。開始の V_Closure/V_Sub/TelClosure の一般逆転を行ったとは主張しない。

## 実際の遷移と非空の facts

[boundary.lean](boundary.lean)（370行）は、本番の型付け・評価器・Step・StateTy を使う補助入力である。捕捉する Γ は一つの `Integer`、その値は7、Φ は「捕捉した値 < 8」である。`captured` は、型付き像だけを持つ `images_only` に `addEvaluated` を適用する。必要な `phi_evaluates` は、実際の `evalClosed` の計算で閉じており、Entails や CaptureOk の結論を入力に取らない。

渡す実引数は3で、型は `Integer{0 ≤ self}` である。`argument_facts_nonempty` は延長後の Γ.facts に `0 ≤ var 0` が含まれることを示す。`extended_facts` は実際の `facts_extend` を適用し、新しい引数の事実 `0 ≤ 3` と、移動した Φ を閉じた `7 < 8` の両方を得る。`extended_ok` は同じ実引数で `CaptureOk.extend` を使い、`closed_body_fact` はその捕捉から `close_entails` を使う。

本体は `if c then return x else return 0` である。両枝の結果型は、引数の非負性と、外側の捕捉値が8未満という条件を持つ。`return_argument` と `return_zero` は、追加する篩の導出で Φ を仮定として実際に読む。`body_requires_phi` は、同じ Γ の引数 facts だけではこの結果型を導けないことを証明する。したがって Φ がなくても通る例ではない。

`execution c` は、c=true と c=false のそれぞれについて、`.closure` の値を呼ぶ E_Lam、続く E_IfT/F、その三状態の StateTy を構成する。`selected_view` が示す実際の返り値は3または0である。`returned_typed` は同じ本体の導出を捕捉した環境で置換し、その値に閉じた結果型を与える。これは StateTy の逆転ではない。結果型の具体形は `Integer{0 ≤ self ∧ 7 < 8}` で、`result_is_closed` と `returned_facts` で照合する。

現行の型付けの全規則は Φ を保つか束縛に合わせて移動するだけで、空から非空の Φ を作らない。C_If も枝に新しい Φ を追加しない。この境界は、評価成功から先に構成した Φ を、実際の分岐の後も保持して読めることを示す。規則の追加は L00b.14b-paths、標準の組み込みの事実と O054 の合同を使う一般の接続は L30/L40 に残る。存在しない述語評価の Step を作ったり、Boolean の結果だけから任意の述語を得たりはしていない。

軽3に対して、rv-14b-t2 の追加部分を境界へ移した。`return_capture` は `return (var 1)` に `Integer{self < 8}` を与え、篩の導入で Φ だけを使う。`returned_capture_typed` はその導出を同じ捕捉環境で閉じ、実際の値7に同じ型を与える。`returned_capture_fact` はその型から事実を読む。主な証拠は値の型付けを含むこの組であり、型付けなしにも導ける数値の比較だけを接続の根拠としない。`closed_gamma_fact` は別の入口として、Γ.facts 側の仮定 `0 ≤ var 0` を close_entails へ渡し、`0 ≤ 3` を得る。今回の境界の追加10宣言は全て公理監査に含めた。初回の境界は87宣言、現在は97宣言である。

## 環境を捨てる反例と負例

主な反例は `environment_counterexample` と `environment_cannot_be_forgotten` である。本番の定義の上で、7を持つ cap と8を持つ otherCap に、同じ Γ と空の Φ の CaptureOk を与える。両者とも型付き像と閉性を満たす。一方、Φ を「捕捉値 < 8」とした CaptureOk は7の環境で成り立ち、8の環境では成り立たない。否定は条件の導出を Entails.sound に渡し、偽の閉じた比較へ帰着させる。環境の長さ違反を理由とする反例ではない。

`open_phi_is_not_closed_fact` は、捕捉で閉じずに元の Φ を仮定なしの事実とする案を否定する。`discarded_capture_changes_view` は、同じ `return (var 0)` から環境を捨てると、実行が読む値も7から既定の Unit に変わることを示す。この既定値による閉じ方では、元の Φ の評価は成功せず、`discarded_capture_evaluation_fails` は none を返すことを計算する。

誤った Φ を「捕捉値 < 7」とした場合は `some false` となる。`no_wrong_phi` は、その条件を同じ cap に登録した CaptureOk を否定する。`wrong_return_untyped c` は、実際の返り値に `Integer{0 ≤ self ∧ 7 < 7}` を与えられないことを facts と Entails.sound で示す。`wrong_phi_wf` と `wrong_result_ann` により、元の述語と型は整形式であり、別の構文違反で拒んだ負例ではない。

## 場合の数と補助契約の選択

| 対象 | 予定 | 実際 |
|---|---:|---:|
| 本番の公開補題 | 初回6、レビュー対応後7 | 7（私有・生成の追加宣言0） |
| CaptureOk の再構成 | mk の8欄、新しい facts の3場合 | 8欄、Γ.facts・新条件・古い Φ の3場合 |
| 呼出しの遷移 | E_Lam 1場合 | 1場合 |
| 分岐の遷移 | E_IfT/F 2場合 | 2場合。execution は Bool の両値を量化 |
| 新しい判断・遷移の構成子 | 0 | 0 |
| 既存の計算・ContTy・Frame・Step | 24・10・7・76 | 同じ |
| 既存の相互三族 | 76 | 同じ |

補助契約で採った案は次の四つである。主な定理の前提と結論、新しい公理、提供範囲、利用者の書ける形、精密な外部状態は変えていない。いずれも補助の導出の入口の選択であり、主定理が扱う導出を制限しない。

| 論点 | 採った案と理由 | 捨てた案 |
|---|---|---|
| Φ の構成 | 一条件の WellFormed と閉じた導出から addEntailed で cons し、評価成功はその系にする。評価不能でも導出を持つ条件を除かない | 型付き像だけから任意の Φ を真とする案、評価失敗を成功へ変える案 |
| 状態定理 | 既存 closure_one・hideConts_any・extend・facts_extend を使う同時構成 | 一般の開始の逆転を未証明で使う案、状態に別の Φ を足す案 |
| 分岐 | 本番の E_IfT/F の前後で、同じ捕捉環境と契約を使う | 現行の C_If や Step にない述語評価の規則を追加する案 |
| 反例 | 本番の CaptureOk と Entails に、同じ型付き Γ と異なる二つの実環境を与える | 小模型だけで環境保持の必要性を説明する案 |

## 捕捉 Φ の残りと送り先

規則の追加と K_Guard の変更は L00b.14b-paths で、L20 の相互補題へ進む前に扱う。paths の二行の見込みは、計画の同作業の3〜8時間の枠を共有し、個別の配分は未見積もりである。それ以外は既存の L20/L40 の枠の内数である。全状態の保存は既存の枠のまま、この表の外である。以下の和を O008 全体の残りとしない。

| 残る言明 | 依存 | 能動時間の見込み | 送り先 |
|---|---|---:|---|
| 開始の StateTyE と V_Closure/V_Sub/TelClosure から同じ契約の捕捉と本体を取り出す | closure の逆転、部分型と列の変性 | 3〜6時間 | L40 |
| 多引数・零引数と多相の閉包に、捕捉 Φ の閉じ方を合成する | extendTel、型/行/範囲/値の交換、宣言の WellTyped | 3〜6時間 | L20 |
| 任意の closeVal 実引数について型付けと具体化契約を一致させ、hcv を外す | closeVal の型保存、観測の一致と bind の合同 | 1〜3時間 | L20 |
| 局所参照を持つ本体の捕捉 Φ と CaptureLocals を β・分岐へ接続する | capture_resolved、局所解決とストア拡張 | 2〜4時間 | L20 |
| if・短絡・match の型付けで Φ を増やす規則を追加し、移動・置換・狭めの全場合を閉じる | O056/O138、既存三族と source/annotation の整合 | 不明（paths の詳細化で見積もる） | L00b.14b-paths |
| K_Guard が条件の前の本体の導出を保持し、E_GuardT で条件を足して ClosureTy を作る形へ改める。E_GuardF 後の腕が ¬guard を読むかも決める | guard の規則、x=9 の再現、ContTy の既存の読み手 | 不明（paths の詳細化で見積もる） | L00b.14b-paths |
| 規則追加後の if・短絡・match の経路条件を、実際の観測と遷移へ接続する | 各観測の canonical forms、閉じた評価または値の型の facts、O054 の合同 | 3〜6時間 | L40 |
| guard の評価結果の型の事実から本体の条件を導き、E_GuardT/F の状態へ接続する | paths の K_Guard と規則の変更、addEntailed、guard の純粋性 | 不明（paths の代表の後に見積もる） | L20/L40 |
| 呼出し元の捕捉を持つ q.view と、.lam を閉じて .closure を作る側の型保存を接続する | closeVal の型保存、Γ/Φ/CaptureOk の V_Closure への接続 | 2〜4時間 | L20 |
| ContTy の各捕捉枠（let/handle/fail）を取り出す遷移で同じ Φ を再構成する | 各枠の逆転、節/return/resume、捕捉した契約の一致 | 3〜6時間 | L20 |


前段の `.closure` の状態への接続という残件は、今回の一引数・空の局所参照の代表について閉じた。前段の残件表の全範囲が完成したとは扱わない。

| 義務 | 今回の段別の判定と証拠 | 残る段 |
|---|---|---|
| O008 | 捕捉を持つ .closure の状態代表と、環境を捨てる反例を閉じた。CapturedFacts と execution/environment_counterexample | L20/L40 の全 StoreTy/ContTy・開始の逆転と一般化 |
| O051 | 捕捉 Φ の閉じた導出、非空の引数 facts、βの代表と、分岐の前の Φ が分岐の後も残ることを閉じた。実行が条件を真にする接続は未検査 | L00b.14b-paths の規則と遷移の代表、L00b.14c〜.14e の Reference・Lazy・節/resume の代表、L20/L40 の全体 |
| O016 | 今回の全本番・境界・既定 import のビルドと公理依存を確認 | 後の L 段、L70 の合成とレビュー |
| O160 | 分類・同時構成・実プログラムから Φ が生じない限定と paths の追加を本書へ記録した | L00b 末の取りまとめ、独立レビューと設計者への再提示 |

## ビルド・公理依存・入力の照合

今回の本番・境界・署名・検証台本を変更したため、初回の成功を引用せず、更新した verify.py で既定ビルドと境界・公理依存・公開署名・実行版を確認し直した。既定ビルドは717 jobsの増分ビルド、終了0、sorryなしである。新しい本番と境界の警告は0件で、既存の lint とリンカの探索先の警告は残る。Lean の全プロセスは -M 12288 を使う。work と Rust/Lean の全比較は実行しない。RSS は未取得（計画上の非採取）である。

初回の検査出力と入力の照合は first-*、集計・実行の時刻と状態は initial-verification.json と initial-axioms-summary.json に保管した。rv-14b-t1 は本番へ移した addEntailed と同名の宣言を持つため、入力を変更したり重複宣言の台本をそのまま再実行したりせず、本番と更新した境界を監査する。rv-14b-t2 の追加部分は境界へ移し、元のファイルは読み取り専用のまま保つ。

| 検査 | コマンド（formal 内。…は本ディレクトリ） | 終了 | 外側の時間 | 記録 |
|---|---|---:|---:|---|
| 既定の全ターゲット | `lake build` | 0 | 0.153444秒 | [build.log](build.log) |
| 境界と97宣言の監査 | `lake env lean -M 12288 …/boundary.lean` | 0 | 1.279476秒 | [boundary.log](boundary.log) |
| 全Refinement・集約・旧主定理の公理依存 | `lake env lean -M 12288 …/axioms.lean` | 0 | 12.102909秒 | [axioms.log](axioms.log) |
| 公開7補題の完全署名 | `lake env lean -M 12288 …/public-api.lean` | 0 | 0.320534秒 | [public-api.log](public-api.log) |
| Leanの実行版 | `lake env lean -M 12288 --version` | 0 | 0.076292秒 | [lean-version.log](lean-version.log) |

五検査の外側の時間の合計は13.932655秒である。完全なコマンド・開始時刻・終了状態・出力のSHA-256は [verification.json](verification.json)、入力は [inputs-sha256.json](inputs-sha256.json)、環境は [environment.json](environment.json) にある。Lean は4.34.1、arm64-apple-darwin24.6.0である。

公理依存は14,012宣言を確認した。新しい本番7補題、Refinement全135モジュールと集約の計136モジュール、旧モデルの仮定充足・限定同値・旧主定理12宣言、境界97宣言を含む。依存は propext・Quot.sound・Classical.choice だけで、sorryAx・未承認公理・未監査モジュールは0である。[集計](axioms-summary.json)と[構成子数](case-inventory.txt)に記録した。計算24・ContTy10・Frame7・相互三族76・Step76は変わらない。

今回の保護対象は、レビュー対応の開始の573入力から、変更を指示された本番のCapturedFactsと本依頼文を除いた571入力で、変更0である（[照合](protected-inputs.json)）。plan・レビュー本文・rv-*・型付け規則・StateTyping・主定理・信頼条件を含む。指定の plan とレビュー追記の再読時の照合差も0である（[参照文書の照合](review-reference-updates.json)）。最終の検査入力480件の変更は0である（[安定性](input-stability.json)）。

100 KBを超える公理の生出力と対象名一覧は tmp に置き、[large-records.md](large-records.md)に大きさとSHA-256を記録した。文書・台本に手元の絶対パスを残していない。最終の検査後に本番・境界・署名・検証台本・監査入力は変えていない。

途中の局所検査では、レビューの評価成功の証明を移した箇所の if_pos に非推奨の警告が出たため、同じ条件を標準の simp で処理する形へ直した。更新した本番・境界の局所検査は終了0である。署名と参照照合の入力を確定する前の確認も成功したが、最終の証拠には上表の再確認の記録を使う。

## 計画との差・時間・次の担当への申し送り

RV-L00b.14b は条件付き可（重なし・中3・軽4）であった。今回の処置は次のとおりである。

| 所見 | 処置 |
|---|---|
| 中1 | 分類と O051/O160 に、現行の規則は Φ を増やさず、この代表の Φ は実プログラムから生じないと明記した。規則追加と遷移の接続を残件表で分けた |
| 中2 | guard を「同じ Φ を再構成する」行から外した。K_Guard の変更と x=9 の再現は paths に送り、今回は規則を変更していない |
| 中3 | addEntailed を本番へ追加し、addEvaluated をその系にした。「任意の Φ は同じ入口で作れる」という記述を直した |
| 軽1 | evaluated_fact を評価成功だけを受け取る形へ短くした |
| 軽2 | 呼出し元の捕捉と、.lam を閉じて .closure を作る側の型保存の行を残件表に加えた |
| 軽3 | T2 の返り値自身に篩を与える例と Γ.facts 側の close_entails の例を境界へ移した |
| 軽4 | snapshot の Φ の set 後の保持と Reference の欄の欠落観測を、14c への確認として signatures に申し送った。今回未実施 |

本番は173行（初回から7行増）、境界は370行（44行増）である。追加の境界の持ち主は本番の HasTypeC/V と CaptureOk であり、初回にはなかった「返り値自身の self の篩」と Γ.facts 側の close_entails の入口を検査する。テスト用の差し込み口や型付け規則は加えていない。

今回の開始は2026-10-31 17:58:08 UTC、上限はその時点から2時間である。能動時間と待ちは分離していない。今回の外側の時間は作業末に記録する。

L00b.14b-paths への詳しい申し送りは signatures の末尾にある。rv-14b-t1 の ClosureTy.branch・boolCond_of_view と本番の addEntailed を入口に使える。K_Guard は guard が真と分かる前に本体の ClosureTy を要求するため、規則追加と同じ段で扱う。x=9 の guard が E_GuardF へ進む途中の状態の再現は、次の作業で規則を足した後に行う。今回その振る舞いを実行済みとはしない。標準の組み込みの事実と O054 の合同は L30/L40 に残る。

| 残る手順 | 担当・内容 | 見込み |
|---|---|---|
| 所見への対応の再確認 | 取りまとめ。更新した補題・境界・文書を確認 | 不明 |
| work・基準版との照合・取り込み・受け入れ | 取りまとめと設計者。担当は実行しない | 不明 |
| L00b.14b-paths | 別途起動。規則追加・K_Guard・実際の遷移との接続の代表 | 計画の3〜8時間 |

今回の文書と最終照合の終了は 2026-10-31 18:04:05 UTC。開始から5分57秒で、2時間の上限に達していない。能動時間と待ちは分離していない。

## 作業末の work

取りまとめが sandbox の外で実行した。基準は `b32ef9c93b89e43131a1c96831a4eadfb6fa9512`。Refinement の生成物を消してから `/usr/bin/time -l scripts/check.sh --level work --base b32ef9c93b89e43131a1c96831a4eadfb6fa9512` を実行した。選ばれたのは `formal_build` だけで、終了0、外側の時間 66.88 秒、最大常駐量 1166000128 B である。
