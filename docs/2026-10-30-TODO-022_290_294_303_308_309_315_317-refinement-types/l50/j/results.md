# L50 群 J の結果

担当の実装と自己点検の記録である。独立レビューと受け入れは取りまとめ・設計者が行う。

- 指定ブランチ: `m014/l50.j`。git の操作は行わない。
- B_WORK: `eeddee69d81fc78552c2bcb61ae6f236d8563973`。
- 対象: L50.46〜.50。external 三条件と通常資源の release_exists は各モデルとも L60 に残す。
- 最大常駐量: 未取得（計画上の非採取）。

## 単位の時刻

日本時間。能動時間と待ちは分離せず、外側の時間として記録する。開始前の指定資料の読解は含まない。

| 単位 | 開始 | 終了 | 判定 |
|---|---|---|---|
| L50.46 | 2026-11-05T01:24:14+09:00 | 2026-11-05T01:25:18+09:00 | 完了：七行と八保存則、局所 Lean 終了0 |
| L50.47 | 2026-11-05T01:25:18+09:00 | 2026-11-05T01:26:02+09:00 | 完了：同じ有限宣言と表12欄、局所 Lean 終了0 |
| L50.48 | 2026-11-05T01:26:02+09:00 | 2026-11-05T01:26:47+09:00 | 完了：純粋三行の全入力・同じ実 δ・Ground・Adequate・篩、局所 Lean 終了0 |
| L50.49 | 2026-11-05T01:26:47+09:00 | 2026-11-05T01:27:51+09:00 | 完了：全送信応答・存在・同じ端点、要求なしと不一致の否定、局所 Lean 終了0 |
| L50.50 | 2026-11-05T01:27:51+09:00 | 2026-11-05T01:39:39+09:00 | 完了：75欄・既定ビルド・公理監査・work・記録照合が終了0 |

## 実装前の固定

7行は参照2・checkRequestIn・requestInValue・sendIn・widenRequestIn・内部発行とする。同じ有限宣言、固定 Val.reqTarget、同じ clientRequestTy、共通 ModelConstraints.sat を使う。既存 ModelHttp の射影と埋め込みを保ち、循環 import を避ける追加モジュール ModelHttpConditions に同じ名前空間の表と条件を置く。公開入口は群Aの F09Http の形を保つ。

検査例の作成時の関門: この表から前提を供給する接続、同じ要求と端点、要求なしと端点不一致の拒否を所有する。default 要求への置換、別端点の観測、表の登録漏れへの退行を検出する。前群の共通表の例は ModelHttp の部分表の接続を扱わないため、この境界だけを加える。型付け規則・差し込み口・実行時フラグを足さない。75欄の判定は全称の実定理で行う。

## 完了条件の照合

具体例と全称証明を区別し、全場合・全入力を量化した本番の定理で担当の条件を判定する。群末の検査・公理監査・記録照合と、実表の適用例の最終照合を L50.50 の内数に含める。

| 単位 | 全場合・全入力の証拠 |
|---|---|
| L50.46 | ModelHttp.entries は参照2・純粋3・送信1・発行1の実7行。sig_cases は全成功 lookup を名前と署名の等号へ戻す。substitutionAssumptions は任意 P の八保存則を同じ骨格に適用し、非空制約・型/行像の値依存・型改名・閉じた型像・Fail の縮約を除外しない |
| L50.47 | sig_scoped/sourceTelRows は HasHttp P の同じ有限宣言から全七署名の形成と行支持を得る。12欄は下表に全て実定理を記した。HasHttp P は Result=2・Pair=2・ClientRequest=0・RequestCheckError=0 と全 lookup を検査する。ModelHttpApplications は5欄の要求、Pair の true の篩、一般の WF 1 の篩の groundTy、Pair arity 0 の拒否を既定内で読む |
| L50.48 | pure_response/delta_typed は全 BuiltinArgs で checkRequestIn/requestInValue/widenRequestIn の同じ実 δ・存在・非 exit・型・Ground・AdequateResult を返す。pure_outcome は同じ決定的 δ の全実結果、normal_facts は同じ正常値の toTerm? と篩を結ぶ。固定 Val.reqTarget、同じ req と内容型を保ち、任意 parse や default の成功を使わない |
| L50.49 | send_response/io_typed/io_kind/io_exists は全 BuiltinArgs と全実応答の型・適格性・非 exit・存在を同じ関係で扱う。sent_request は同じ req/groundVal/reqTarget/保持対象/観測を返す。send_without_request と send_mismatch は両保持形を全型/行引数・全応答で排除する。send_held は全 Reply の受理側である。発行の八欄・同じ効果表の所属・全 IO 排除と型付きの空呼出し・専用二遷移も既定内で読む |
| L50.50 | ScopeModels.conditions は同じ P の三つのモデルの25欄ずつを構成する。conditions.md の75行と conditions.json、contracts.lean の完全な型を持つ75定理が各欄を読む。独立の未完は0欄。external3＋release1はモデルごとに handoffs.md の12行へ残し、全 Core の無条件の充足と区別する |

## 七行の実表と八保存則

名前は Benitoite.Release.Refinement 内である。七行の名前以外の署名 lookup は none であり、sig_cases は成功する lookup の全域を扱う。

| 実名 | 署名 | 種類・形・効果 | 同じ表の証拠 |
|---|---|---|---|
| Reference.get | ScopeSignatures.refGet | refGet・対象なし・State | ModelHttp.ref_get/store_shape/store_admits |
| Reference.set | ScopeSignatures.refSet | refSet・対象なし・State | ModelHttp.ref_set/store_shape/store_admits |
| Http.checkRequestIn | ScopeSignatures.checkRequestIn | pure・endpoint の範囲1・空効果 | ModelHttp.pure_response → RequestDelta.response |
| Http.requestInValue | ScopeSignatures.requestInValue | pure・endpoint の範囲1・空効果 | ModelHttp.pure_response → RequestDelta.requestInValue_response |
| Http.sendIn | ScopeSignatures.sendIn | io・single endpoint 0・Http.Connect の同じ範囲 | ModelHttp.send_response/io_op/sent_request |
| Http.widenRequestIn | ScopeSignatures.widenRequestIn | pure・endpoint の範囲2・空効果 | ModelHttp.pure_response → RequestDelta.widenRequestIn_response |
| Example.pathBases | ScopeSignatures.pathBases | pathBases・空引数・Process.Environment | ModelHttp.pathBases_shape/pathBases_no_io と ModelHttpApplications の専用二遷移 |

同じ effects は State → some []、Http.Connect → [Http.sendIn]、Process.Environment → [Example.pathBases] であり、それ以外は none である。effect_ops は全分岐の全所属を扱う。発行は専用の種類を持ち、IO 関係には含めない。公開名は U02 の判断を先取りしない。

ModelHttp.substitutionAssumptions P は sat_rename・admits_rename・sat_values・admits_values・sat_renameTypes・admits_renameTypes・sat_subst・admits_subst の八欄を構成する。sat は共通 ScopeSignatures.builtins の有限宣言の要約・StandardKeyTyping.carrier・ModelConstraints.sat のままである。値の四保存則と型の四保存則を同じ七行へ適用する。P を読まない欄へ HasHttp P を増やしていない。開いた tvar 0 の非空の鍵制約を、束縛位置の制約があるときに受理し、空制約だけでは拒否する両側を既定内で確かめる。

## 宣言・純粋 δ・送信と発行

HasHttp P は同じ P の Result と ScopeError、Pair、Http.ClientRequest、Http.RequestCheckError の全構成子 lookup と DataArity を検査する。ClientRequest の五欄は String・String・List[Pair[String,String]]・Bytes・Integer の順である。Pair と Result は arity 2、要求と RequestCheckError は arity 0。RequestCheckError.InvalidUrl は String、RequestCheckError.Scope は同じ ScopeError の型を持つ。Result.Ok と Error の型引数位置は0と1である。具体の有限 P は前群の ScopeDeclarations.program/program_hasHttp/program_wellFormed を継承し、再定義しない。

純粋三行は、同じ要求全体と固定 Val.reqTarget を使う既存の具体 δ に接続した。純粋応答の適格性は同じ入力 req 又は同じ保持値から得る。成功結果だけに量化を縮めず、Error と実行時エラー、全実結果の非 exit と Ground を扱う。型付けが排除する default の枝を、応答存在の証拠へ使わない。

send_response は HasFile P を必要とし、同じ Result の宣言を読む。要求の分類・内容型と不透明な Http.Response/NetworkError の定数分類は同じ B の定義から供給する。全応答は Result.Ok・Result.Error・err であり、存在の証人は Error でよい。正常成功・外部 IO の成功・副通信の隔離を前提にしない。sent_request は両保持形の同じ req と endpoint、観測 [endpoint] を返す。targetAgreement と obs_allowed は同じ実応答・同じ全引数・同じ σ を使い、未構成の Core を要求しない。F04/F05 の承認済み NamesWF は sig_scoped.namesWF から得る。

ModelHttpApplications は、Pair[String{true},String] をヘッダーに含む要求を同じ有限 P で型付けし、任意 Ψ と σ、非 Top/Top、checkedRequest/checkedAt の両形で全 BuiltinArgs と空でない観測の許容を実際に供給する。同じ送信関係の受理に対して、要求なし・端点不一致の拒否を対にした。発行は空引数の全 BuiltinArgs と呼出しの型を構成し、let・専用二遷移・return から同じ σ を At の bases に束縛する。

## 三モデルの七十五欄と後段

[conditions.md](conditions.md) に75欄を一行ずつ、実際の定理・同じ出力の欄・判定と対応させた。[conditions.json](conditions.json) は同じ機械可読の75行、[contracts.lean](contracts.lean) は各欄の完全な全称の型を明記した75定理である。Model.scopeConditions P、ModelTargets.scopeConditions P hp、ModelHttp.scopeConditions P hp を別々に読み、ScopeModels.conditions P hp が同じ P の三つの出力を同時に構成する。

一モデルの内訳は値の保存4＋型の保存4＋応答4＋表12＋対象1＝25であり、三モデル75欄の独立の未完は0である。[obligations.md](obligations.md) では33義務と31申し送りを一行ずつ判定した。義務全体の閉鎖は0行であり、群 K/L の全実行読者・段末照合、L60/L70 の既存の担当を保つ。

L60 の12欄は [handoffs.md](handoffs.md) のモデルごとの external_typed/exists/no_targets/release_exists である。具体の入口は同じ P/B の Builtins.ExternalAssumptions の三射影と、ModelScopeConditions.core の release 引数である。ScopeModels の既定内の適用例は、外部三条件と release をモデルごとに別々に受け取る。

群 H・I の申し送りを集約した。Model の release は isResource=false のため前提が偽で空疎、ModelTargets は File.Handle の型付き値で前提を満たせる一方、releaseResponse が r=none の関係なので結論が ⟨none,rfl⟩ で自明である。ModelHttp も isResource=false で前提が偽である。三モデルとも externalResponse は空の関係のままなので、外部宣言・ExternalWF・ExternalArgs を満たす P では external_exists が成り立たない。これらを証明済み75欄へ加算せず、通常資源の実応答と外部応答の関係を L60 が照合する。ここで閉じたと書かない。

## 追加宣言と公理への依存

| モジュール | 追加宣言（private・生成を含む） | 内容 |
|---|---:|---|
| ModelHttpConditions | 49 | 実7行、八保存則、表12欄、純粋3行、送信の全応答・存在・対象と拒否、25欄の出力 |
| ScopeModels | 1 | 同じ P の三モデル75欄の出力 |
| ModelHttpApplications | 37 | 実引数の型付け・全入力、篩付き Pair、非 Top/Top、両保持形、受理/拒否、純粋操作・発行の読者 |

本番の追加は計87宣言で、内訳は {"theorem": 68, "definition": 19}。private の完全名は44件、宣言位置0の生成宣言は32件であり、分類は重複する。契約台本の78宣言を含む公理監査は全165宣言、固定点2巡である。許す公理は propext・Quot.sound・Classical.choice だけであり、新公理・sorryAx・独立の信頼条件は0である。既存の前群の定理も、新宣言の依存を通して同じ公理の部分集合であることを確かめた。全既定環境の段末監査とは区別する。

台本は [audit.py](audit.py)・[audit-tail.lean](audit-tail.lean)、対象モジュールは [modules.json](modules.json)・[new-modules.json](new-modules.json) から再生成できる。private と生成宣言も対象とする。宣言の唯一の群末の写しは [declarations-part-01.json](declarations-part-01.json)。主要44入口と残す四欄の完全な実型は [actual-signatures.md](actual-signatures.md) に保存した。

- 監査生出力: 83,246 bytes、SHA-256 `e59cf1afd14dcac1c5e0b890038ded46648c24f057629ff4cc388751bdcbb85e`。
- 監査入力: 65,127 bytes、SHA-256 `e15b5571e48cd167b29a476c7fc1fd230b90709d8cc7ebb43d6f84fc12aade92`。
- 全対象一覧: 10,804 bytes、SHA-256 `3d5fbd659c65dfbbf5d86cf319805352f0972c07882f03a2d456d6a0b7d71397`。
- 本番の追加一覧: 7,625 bytes、SHA-256 `f5ea792afa38c1ffc3e9602e2ad96ea443197da84b7be10056dc78bf6cae6b52`。

生の出力と途中の入力は一時領域へ置き、改造には要約・大きさ・SHA-256 だけを残す。各ファイル100 KB以下、群全体を数 MB以内に保つ。

## 群末の検査

固定 Lean は formal/lean-toolchain の leanprover/lean4:v4.34.1、既定ビルドの moreLeanArgs は -M 12288。単独の Lean も formal/ から lake env lean -M 12288 を用いた。正式 RSS は未取得（計画上の非採取）。

| 検査 | コマンド・中身 | 結果・外側の所要 | 記録 |
|---|---|---|---|
| build | formal/ から対象なしの lake build。全1,290ジョブ | 終了0、4.431092秒 | [build-check.json](build-check.json) |
| dry-run | scripts/check.sh --level work --base B_WORK --dry-run。選択の確認 | 終了0、0.133383秒 | [dry-run-check.json](dry-run-check.json) |
| work | scripts/check.sh --level work --base B_WORK。only なしで一度。仕様対応表の自己検査・集計、仕様例7成功/0失敗/0ignored、既定 Lean ビルドと sorry 拒否 | 終了0、11.990259秒 | [work-check.json](work-check.json) |
| 公理監査・全称契約 | audit.py --tmp <tmp>。全165宣言・75欄の全称契約・F07 の全入力 | 終了0、12.037015秒 | [audit-summary.json](audit-summary.json) |
| 記録照合 | verify.py --tmp <tmp>。開始入力との差、全追加 import、75欄と12申し送り欄、33義務/31申し送り、全宣言とハッシュ、実行回数、リンク、容量 | 最終の成否は記録を正とする | [verification.json](verification.json) |

単独の既定ビルドと work 内の既定ビルドは別の実行であり、指定された work 自体は一度だけである。今回の既定ビルドは増分ビルドであり、前群の生成物を消したビルドの約9分とは区別する。新設三モジュールの局所検査と最終監査に警告はない。既定ビルドは変更していないモジュールとリンカの警告を再表示した。Rust の全 lib・clippy・全比較・性能測定・LLM 評価は追加していない。

## 局所の修正・計画との差

最初の編集入力は作業ディレクトリを重ねた相対パスのため、読み取り時点で終了しファイルを書かなかった。根から編集し、formal/ から単独の Lean を実行する形に直した。局所の Lean では、送信の否定の証明で置換後に消える変数の参照、scoped_forget の暗黙引数と三つの自明な形成欄、同じ要求の Ground の明示、checkedAt の snapshotなしの絶対範囲の証拠を修正した。Pair の一般の篩の groundTy は既存の定義どおり WF 1 を使い、任意の述語が閉じているとは述べない。これらは公開した全称言明の反例や型付けの規則の変更ではない。

公理監査の初回は、75欄の契約を def で置いたため Lean の defProp 警告が出て、警告を拒否する台本が停止した。theorem の型は証明から推論できないため、実環境から取得した完全な型を明記して各欄を theorem として書き直した。使われないプログラム変数の表記は _P とし、警告を隠す linter の設定は加えなかった。最終の全称契約・監査は終了0であり、途中の失敗を成功の根拠へ含めない。本番の証明や署名は変えていない。

配置は ModelHttpConditions・ModelHttpApplications・ScopeModels の3モジュールとした。既存 ModelHttp の読者が ScopedIOResponse の import 経路にあるため、同じ名前空間の追加モジュールに条件を置いて循環を避けた。既存の射影・埋め込みと旧 Release を変えていない。01-12 と07-04 は新モジュールの実物の定義・前提・性質を同じ変更で写し、全3モジュールを既定 import に入れた。

主な十言明、F01〜F10、前段の実署名、新公理、独立の信頼条件、型付けの規則、利用者の書ける形、提供範囲、精密な外部状態の変更は0件。使わない前提を取り除く署名変更も0件である。承認済み NamesWF を sig_scoped から供給し、U02 の公開形は選択していない。処理系、旧 Release、plan/detail/u02-options/README/レビュー、l40・群 A〜I の記録を編集していない。git の操作は行っていない。

大きな具体値の作成・評価、表の性質の decide +kernel、#eval は行っていない。本番の証明に maxHeartbeats/maxRecDepth の設定を加えていない。公理監査用の一時入力のメタプログラムの上限は、前群の監査台本を継承したものであり本番の証明の設定ではない。

取りまとめへ新しく判断を求める点はない。独立レビュー・所見の処置と設計者の受け入れは未実施であり、担当の自己点検と区別する。L60 の四欄、群 K/L と L70 の既存の担当は保つ。

## 最終照合と単位ごとの所要

verify は開始1,039入力と最終1,042入力を比較し、追加3モジュール、変更3ファイル（根の import と二つの写し）、削除0を確認した。既定 import の閉包1,029モジュールに全追加モジュールが入る。全165監査宣言と主要44実署名、75欄と L60 の12欄、33義務・31申し送り、各検査の一回分の実行記録とハッシュ、相対リンクと各ファイル100 KB以下を照合した。群の記録は約0.5 MBである。終了時刻と本節の追記後にも同じ入力と記録を照合する。

| 単位 | 開始（日本時間） | 終了 | 外側の所要 |
|---|---|---|---:|
| L50.46 | 2026-11-05T01:24:14+09:00 | 2026-11-05T01:25:18+09:00 | 1分04秒 |
| L50.47 | 2026-11-05T01:25:18+09:00 | 2026-11-05T01:26:02+09:00 | 0分44秒 |
| L50.48 | 2026-11-05T01:26:02+09:00 | 2026-11-05T01:26:47+09:00 | 0分45秒 |
| L50.49 | 2026-11-05T01:26:47+09:00 | 2026-11-05T01:27:51+09:00 | 1分04秒 |
| L50.50 | 2026-11-05T01:27:51+09:00 | 2026-11-05T01:39:39+09:00 | 11分48秒 |

単位区間の合計は15分25秒。開始前の指定資料の読解を含まず、群末のビルド・監査・work・記録照合と実表の読者の最終照合を L50.50 の内数とする。能動時間と待ちは分離していない。共通の全称証明と有限宣言を再利用できたため、見込み3時間15分〜6時間を下回った。4時間の途中報告と12時間の上限には達していない。この外側の時間を能動時間の係数へ換算せず、後続の旧見込みを保つ。

担当分の L50.46〜.50 は完了し、群 J に独立の未完はない。取りまとめへ新しく判断を求める点はない。独立レビュー・所見の処置と設計者の受け入れへ渡す。外部応答と通常資源の解放、全 Core、主定理、Rust/Lean の一致の完了は含めない。

| 残る手順 | 内容・担当 | 見込み |
|---|---|---|
| 群 J の独立レビュー・所見の処置・受け入れ | 取りまとめ・設計者。七署名・同じ要求/端点・全75欄と12欄の区別・監査を照合 | 不明 |
| 群 K | 全位置・全実行読者と義務/申し送りの事前照合、検査、レビュー | 計画の2時間50分〜5時間15分。検査・レビュー待ちは別 |
| 群 L | 写しと全場合・後段の受渡し、全環境の公理監査、段末検査、独立レビューと受け入れ | 計画の2時間40分〜5時間。検査・レビュー待ちは別 |
| L60/L70 と後段 | 外部三条件と通常資源・全 Core、主定理・表層・交換の接続と受け入れ | 各既存計画。待ちは不明 |

## L60 への申し送り（取りまとめ、RV-L50.j の情報9）

- 三モデルの L60 に残す12欄の注意（Model と ModelHttp の `release_exists` は `isResource` が常に false なので前提が偽で空疎、ModelTargets の `release_exists` は `r = none` で結論が自明、三表とも `externalResponse` が既定の空の関係なので外部関数を宣言する P では `external_exists` が成り立たない）は、handoffs.md のとおり L60 へ申し送る。

## 取りまとめによる修正（RV-L50.j の軽1〜3・情報10）

- `ModelHttpApplications.lean` から、読者のない private の定義 `otherEndpoint` を消した。本番の追加宣言は86件（ModelHttpApplications 36件）になる。
- 同ファイルの篩付き Pair の例の docstring を、述語が WF 1 のとき groundTy が受理するという中身に合わせた。
- 同ファイルの純粋の正常応答の例は、`ModelHttpConditions` の例と言明も証明も同じなので消した。
- 07-04 の send_held の文を、全応答について両保持形の受理を示す定理として直した。
- 言明・証明の中身は変えていない。本群の verification.json・audit-summary.json・final-manifest のハッシュと宣言の件数は修正の前の作業木のものである。修正の後の状態は、次の節の work（既定の lake build を含む）で確かめた。単独の検査は ModelHttpApplications・ScopeModels とも終了0。

## 群 J の作業末の work の検査（取りまとめ）

- 基準: `eeddee69d81fc78552c2bcb61ae6f236d8563973`。作業木は、取りまとめが RV-L50.j の軽1〜3・情報10 を直した後の状態。
- 前処理: `formal/.lake/build/lib/lean/Benitoite/Release/Refinement` と `formal/.lake/build/ir/Benitoite/Release/Refinement` を消し、篩の部分を再ビルドさせた。
- コマンド: `/usr/bin/time -l scripts/check.sh --level work --base eeddee69d81fc78552c2bcb61ae6f236d8563973`。
- 結果: 終了0。外側 560.87秒、最大常駐量 2,935,767,040 バイト。仕様例7件が通り、形式化のビルドに sorry はない。
