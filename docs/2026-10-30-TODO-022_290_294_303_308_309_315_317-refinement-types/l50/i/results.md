# L50 群 I の結果

担当の実装と自己点検の記録である。独立レビューと受け入れは取りまとめ・設計者が行う。

- 指定ブランチ: `m014/l50.i`。git の操作は行わない。
- B_WORK: `62974229140883a157b79199d7626f3efb59fe55`。
- 対象: L50.41〜.45。external 三条件と通常資源の release_exists は L60 に残す。
- 最大常駐量: 未取得（計画上の非採取）。

## 単位の時刻

日本時間。能動時間と待ちは分離せず、外側の時間として記録する。

| 単位 | 開始 | 終了 | 判定 |
|---|---|---|---|
| L50.41 | 2026-11-05T00:43:16+09:00 | 2026-11-05T00:45:24+09:00 | 完了：全15行と八保存則、局所 Lean 終了0 |
| L50.42 | 2026-11-05T00:45:24+09:00 | 2026-11-05T00:46:16+09:00 | 完了：全15行の形成・sourceTelRows・三形・表12欄、局所 Lean 終了0 |
| L50.43 | 2026-11-05T00:46:16+09:00 | 2026-11-05T00:47:39+09:00 | 完了：純粋3行の全入力・実結果・Ground・Adequate・篩、局所 Lean 終了0 |
| L50.44 | 2026-11-05T00:47:39+09:00 | 2026-11-05T00:49:16+09:00 | 完了：範囲 IO 6行・旧3行の型・存在・種類、局所 Lean 終了0 |
| L50.45 | 2026-11-05T00:49:16+09:00 | 2026-11-05T01:02:27+09:00 | 完了：25欄・全応答の対象・既定ビルド・監査・work・記録照合が終了0 |

## 実装前の固定

同じ15行の原署名を entries に登録する。ScopeSignatures の参照2行、純粋3行、範囲 IO 6行、内部発行1行と、旧 print・exit・File.readText の3行を使う。旧 readText の shape は topTargeted path、File.Handle は通常資源に分類する。sat は共通の ModelConstraints.sat と同じ有限宣言を使う。出力は ModelTargets.scopeConditions (P) (hP : ScopeDeclarations.HasFile P) : ModelScopeConditions P ModelTargets.builtins とする。L60 の external と release を別に残す。

検査例の作成時の関門: ModelTargets の実表から呼出しの前提と応答を供給する境界を所有する。行の脱落、readText の single 化、exit の正常返却、sat=True への退行を検出する。共通表と Model の例は ModelTargets の追加3行と資源分類を読まないため、その境界だけを加える。新しい差し込み口は設けない。

## 完了条件の照合

技術的な条件は全場合・全入力を量化した本番の定理で判定する。具体例は実表から前提を供給できることの証拠であり、全称の証明の代わりにしない。群末のビルド・公理監査・work・記録照合を L50.45 の内数とする。

| 単位 | 全場合・全入力の証拠 |
|---|---|
| L50.41 | ModelTargets.entries と sig_cases は旧7＋追加8の全15署名を名前と署名の等号へ戻す。substitutionAssumptions は任意 P で八保存則を構成する。型・行像の値依存、TypeParamRenaming、型像の衝突や Fail の縮約を除かない |
| L50.42 | sig_scoped/sourceTelRows は HasFile P の同じ Result/ScopeError の全 arity と lookup から、全15署名の形成・kind・宣言・SourceScoped・行支持を供給する。io_op は untargeted/topTargeted/single の三形、pathBases_shape は発行の八欄、effect_ops は同じ表の登録全件を扱う。File.Handle は通常資源に残す |
| L50.43 | pure_response/delta_typed は全 BuiltinArgs から純粋3行の同じ実 δ・結果の型・Ground・AdequateResult・非 exit を供給する。pure_outcome は決定性で全実結果へ渡し、normal_facts は同じ正常値の篩の事実を返す。ScopeDelta.run_safe の全範囲/全値列、run_absolute/input_errors、pathInValue_response/widenPathIn_response を使う |
| L50.44 | io_typed/io_kind/io_exists は全15 lookup のうち六範囲 IO と旧 readText/print/exit の九行を全入力・全応答で扱う。範囲 IO は群 G の任意 P/B の入口を同じ B へ適用する。旧 readText は String と Top の契約を保ち、exit は終了応答を持ち val を返さない。未定義 δ から存在を導かない |
| L50.45 | targetAgreement は三形の全応答の ShapeTargets、obs_allowed は同じ実表の io_op と sig_scoped.namesWF から F05 を適用する。任意 Ψ・全適格 σ・全実引数/全観測を同じ実効果の上限へ接続する。scopeConditions は25欄を実定理から構成し、external3/release1 を別に残す。群末検査と記録照合は後掲 |

## ModelTargets の実表

全15行は同じ ModelTargets.entries の lookup を使う。範囲の位置のある署名は群 E の ScopeSignatures と同じ値である。Result の構成子は同じ P の Result.Ok/Result.Error、ScopeError は同じ data Scope.ScopeError [] である。起点発行の Example.pathBases は既存の内部名であり、U02 の公開名を選んでいない。

| 実名 | 由来 | 種類・形 | 引数 → 結果 | 効果 |
|---|---|---|---|---|
| Reference.get | 旧 | refGet | Reference[T0] → T0 | State |
| Reference.set | 旧 | refSet | Reference[T0], T0 → Unit | State |
| print | 旧 | io・untargeted | String → Unit | Console.Write |
| exit | 旧 | exit・untargeted | Integer → Unit（終了応答） | Process.Exit |
| File.readText | 旧 | io・topTargeted path | String → Result[String, IOError] | File.Read[Top] |
| Scope.checkPathIn | 旧 | pure | String, String → Result[PathIn[R0], ScopeError] | 空 |
| Scope.pathInValue | 追加 | pure | PathIn[R0] → String | 空 |
| Scope.widenPathIn | 追加 | pure | PathIn[R0] → PathIn[R1] | 空。R1 が R0 を覆う |
| File.readTextIn | 追加 | io・single path 0 | PathIn[R0] → Result[String, IOError] | File.Read[R0] |
| File.readBytesIn | 追加 | io・single path 0 | PathIn[R0] → Result[Bytes, IOError] | File.Read[R0] |
| File.writeTextIn | 旧 | io・single path 0 | PathIn[R0], String → Result[Unit, IOError] | File.Write[R0] |
| File.writeBytesIn | 追加 | io・single path 0 | PathIn[R0], Bytes → Result[Unit, IOError] | File.Write[R0] |
| File.appendTextIn | 追加 | io・single path 0 | PathIn[R0], String → Result[Unit, IOError] | File.Write[R0] |
| File.appendBytesIn | 追加 | io・single path 0 | PathIn[R0], Bytes → Result[Unit, IOError] | File.Write[R0] |
| Example.pathBases | 追加 | pathBases | 引数なし → PathBases | Process.Environment |

効果表は State → some []、Console.Write → [print]、Process.Exit → [exit]、File.Read → [File.readText, File.readTextIn, File.readBytesIn]、File.Write → [File.writeTextIn, File.writeBytesIn, File.appendTextIn, File.appendBytesIn]、Process.Environment → [Example.pathBases] であり、ほかは none である。effect_ops はこの全分岐の membership を証明する。発行は専用の種類であり IO 関係に入らない。

## 八保存則と宣言の形成

sat は ScopeSignatures.builtins と同じ、ScopeDeclarations.http の有限宣言の要約・StandardKeyTyping.carrier・ModelConstraints.sat を使う。型パラメータの非空制約を読む。開いた tvar 0 の鍵制約を、束縛位置の鍵制約がある場合には受理し、空制約だけの場合には拒否する対照を既定ビルドに置いた。

substitutionAssumptions は sat_rename/admits_rename、sat_values/admits_values、sat_renameTypes/admits_renameTypes、sat_subst/admits_subst の八欄を元の完全な量化で満たす。sat の三欄は共通表の射影、sat_values は同じ B に依存する型付き値像を取り違えないよう ModelConstraints.sat_values を直接使う。admits の四欄は全15署名についての個数検査と列長の保存を使う。参照の型パラメータは空制約一つなので、同じ判定の sat_unconstrained から SatAll を供給する。sat=True へ置き換えていない。

sig_scoped は HasFile P を読み、Result arity 2・ScopeError arity 0 の同じ P から全署名を形成する。sourceTelRows は同じ依存列の source の射影である。P に依存しない八保存則・sat_unconstrained/admits_sat・表の形には HasFile P を足していない。具体の P は前群の ScopeDeclarations.program と program_hasHttp.file を再利用し、同じ有限宣言を重複定義しない。

## 純粋 δ と IO の実応答

pure_response の全15 lookup の場合分けは、pure でない12行を kind で除き、checkPathIn → ScopeDelta.response、pathInValue → ScopeDelta.pathInValue_response、widenPathIn → ScopeDelta.widenPathIn_response の三行へ接続する。実 δ は共通の ScopeResponse.delta と同じである。δ が返す結果の決定性から pure_outcome が全実結果の型・適格性・非 exit・Ground を返す。normal_facts は型付けの facts を同じ toTerm? の観測へ渡す。

| 場合 | 実証拠とモデルへの接続 |
|---|---|
| 絶対形 | ScopeDelta.run_absolute の全入力。動的検査と静的上限の双方が成功すると同じ checked target を返す。ModelTargetsApplications の全称の適用例がモデルの δ へ渡す |
| 相対形・home 形 | ScopeDelta.input_errors の全範囲。明示の InvalidTarget を持つ Result.Error であり、Top でも暗黙に解決しない。モデルの δ で全称の適用例を置く |
| 非 Top と Top | ScopeDelta.run_safe は任意の RangeExpr と全値列を扱う。絶対範囲では MemK の成否を分け、Top も含む。based/secrets は純粋な入口で解決せず静的拒否にする。範囲 IO の具体の BuiltinArgs でも同じパスを非 Top/Top の両側に渡す |
| 射影と拡大 | 射影は保持した絶対対象を String へ写す。拡大は同じ値を返し、許容した被覆を型付けの証拠にする。任意の r/s/snapshot/Word の実 δ の等式を適用例に置く |

範囲 IO 六行は、ScopedIOResponse の同じ具体関係の Ok/Error/err と同じ保持パスの観測をそのまま使う。存在の証人は Error でよく、実 IO の成功や正常応答の存在を前提にしない。旧 File.readText は String 引数、範囲引数なし、Top の File.Read、topTargeted path を保つ。readObs は絶対形として解析できたパス一つ、その他は空列であり、成功・Error・err のいずれも同じ観測を持つ。print は Unit と空観測、exit は exitCode ws の終了と空観測である。io_kind が全応答について IO の非 exit と exit の非 val を別々に証明する。

targetAgreement は六範囲 IO を ScopedIOResponse.targets へ、旧 readText を readObs_kind へ、print/exit を空観測へ渡す。obs_allowed は実表の io_op、sig_scoped.namesWF、同じ BuiltinArgs・全実引数の同じ σ への Adequate、同じ実応答から F05 を適用する。未構成の Core は前提にしない。

ModelTargetsApplications は実表で File.readTextIn の非 Top と Top の全前提を任意 Ψ/σ に供給し、F04 の同じ対象所属と F05 の許容を同時に読む。旧三操作にも実定数引数から全 BuiltinArgs を構成し、応答存在・型・適格性・種類・同じ σ の上限を同時に読む。旧 readText の root の空でない観測と任意 String の Ok、全型付き exit 応答の非 val を既定内で確かめた。

## 二十五欄の実定理

以下の名前は Benitoite.Release.Refinement 内である。射影は実際に構成した同じ表の証明の欄を指す。[conditions.json](conditions.json) は同じ25行の対応である。

| 欄 | 実際の定理又は射影 | 判定 |
|---|---|---|
| sat_rename | (ModelTargets.substitutionAssumptions P).sat_rename | 証明済み |
| admits_rename | (ModelTargets.substitutionAssumptions P).admits_rename | 証明済み |
| sat_values | (ModelTargets.substitutionAssumptions P).sat_values | 証明済み |
| admits_values | (ModelTargets.substitutionAssumptions P).admits_values | 証明済み |
| sat_renameTypes | (ModelTargets.substitutionAssumptions P).sat_renameTypes | 証明済み |
| admits_renameTypes | (ModelTargets.substitutionAssumptions P).admits_renameTypes | 証明済み |
| sat_subst | (ModelTargets.substitutionAssumptions P).sat_subst | 証明済み |
| admits_subst | (ModelTargets.substitutionAssumptions P).admits_subst | 証明済み |
| delta_typed | ModelTargets.delta_typed | 証明済み |
| io_typed | ModelTargets.io_typed | 証明済み |
| io_kind | ModelTargets.io_kind | 証明済み |
| io_exists | ModelTargets.io_exists | 証明済み |
| sig_scoped | ModelTargets.sig_scoped | 証明済み |
| sat_unconstrained | ModelTargets.sat_unconstrained | 証明済み |
| admits_sat | ModelTargets.admits_sat | 証明済み |
| pathBases_shape | ModelTargets.pathBases_shape | 証明済み |
| io_op | ModelTargets.io_op | 証明済み |
| opEff_io | ModelTargets.opEff_io | 証明済み |
| effect_ops | ModelTargets.effect_ops | 証明済み |
| state_effect | ModelTargets.state_effect | 証明済み |
| ref_get | ModelTargets.ref_get | 証明済み |
| ref_set | ModelTargets.ref_set | 証明済み |
| store_shape | ModelTargets.store_shape | 証明済み |
| store_admits | ModelTargets.store_admits | 証明済み |
| io_target | (ModelTargets.targetAgreement P).io_target | 証明済み |

25欄は ModelTargets.scopeConditions (P) (hp : HasFile P) が同じ P/B で構成する。新しい Core 全体の無条件の充足とは区別する。L60 に残す欄は external_typed・external_exists・external_no_targets と通常資源の release_exists の4欄である。ModelScopeConditions.core に同じ P/B の ExternalAssumptions と release を渡す型の適用例を本番と [contracts.lean](contracts.lean) に置いた。

ModelTargets は File.Handle を資源に分類し、その Top の不透明定数に型が付くため、release_exists の前提は充足可能である。Model の isResource=false による空疎な場合と区別し、ここでは release_exists を証明して閉じたと扱わない。releaseResponse は既存の共通表の関係を保つ。externalResponse は既定の空の関係なので、外部宣言を持つ任意 P の external_exists を空の関係から得たとは扱わない。L60 は同じ P/B の条件を構成し、必要な対象の範囲を照合する。

[obligations.md](obligations.md) では33義務・31申し送りを一行ずつ判定した。群 I の担当部分に独立した未完を残さず、群 J の75欄の集約、群 K/L の全実行読者・段末照合、L60 の四欄と L70 の主定理・表層、U02 後の公開写しの既存の担当は保つ。義務全体の閉鎖は0行である。

## 宣言と公理への依存

| モジュール | 追加宣言（private・生成を含む） | 内容 |
|---|---:|---|
| ModelTargets | 88 | 実15行と表の定義、八保存則、全宣言の形成と表12欄、純粋3行と IO/exit 九行、対象条件と25欄の出力 |
| ModelTargetsApplications | 72 | 非 Top/Top の全前提、旧三操作の全 BuiltinArgs、Top の空でない観測と exit の非 val、純粋操作と発行の読者。非公開の三操作の型と生成宣言を含む |
| 本番の計 | 160 | 定理101・定義54・帰納型1・構成子3・再帰子1。private の完全名103、宣言位置0の生成宣言93を含む。分類は重複する |

2モジュールを既定 import に入れ、01-12 と 07-04 に実物の定義・前提と結論を写した。既存の本番 Lean の変更は根の import 2行だけである。本番の公開した入口には同じ既定ビルドの読者又は適用例を置いた。主な十言明・型付け規則・前段の実署名の変更は0件である。

公理監査の対象は本番の全160宣言と契約台本の3宣言の計163宣言であり、private・生成宣言を固定点2巡まで列挙した。すべて propext・Quot.sound・Classical.choice の部分集合だけに依存し、新公理・sorryAx・独立の信頼条件は0である。全既定環境を扱う段末の監査とは区別する。対象の一覧は [audit.py](audit.py)・[audit-tail.lean](audit-tail.lean) と [modules.json](modules.json) から再生成できる。宣言の唯一の写しは [declarations-part-01.json](declarations-part-01.json)、主要32入口の全実署名は [actual-signatures.md](actual-signatures.md) に置いた。

- 監査生出力: 90,984 bytes、SHA-256 `8ad9e3abcef6160bd051978f3c6acdc77649419fabac53444e4b3fe5c786d88d`。
- 監査入力: 7,244 bytes、SHA-256 `08184d8ca119789fdfc938f28aa0097c8acf223373853b75e6f61e7a9b8aae81`。
- 全対象一覧: 16,552 bytes、SHA-256 `63feb3d96b9c20e6901451f5edc4d9543eac7db9cb5e05b016705c6a10932d57`。
- 本番の追加160宣言の一覧: 16,471 bytes、SHA-256 `93d3ae3cc15a18dea62e34acca5f07d75cfe42691ecc487f5609bc3f641e798a`。

生の出力は一時領域に置き、改造には台本・件数・大きさ・SHA-256 を保存する。宣言の写しは群末一回分だけである。

## 群末の検査

固定 Lean は formal/lean-toolchain の leanprover/lean4:v4.34.1（arm64-apple-darwin24.6.0、commit 5045d0056413266e57c625dcd7c365b10e377c52、Release）。lakefile の moreLeanArgs は -M 12288、単独の Lean も formal/ から lake env lean -M 12288 で検査した。正式 RSS は未取得（計画上の非採取）。

| 検査 | コマンドと中身 | 結果・外側の所要 | 記録 |
|---|---|---|---|
| 既定ビルド | formal/ から対象なしの lake build。全1,287ジョブ | 終了0、5.672173秒 | [build-check.json](build-check.json) |
| 公理監査と全称契約 | audit.py --tmp <tmp>。固定 F09File と F07Pure/Ground/IO、Core への別入力の契約、全163宣言 | 終了0、12.115938秒、新公理・sorryAx 0 | [audit-summary.json](audit-summary.json) |
| 選択確認 | scripts/check.sh --level work --base 62974229140883a157b79199d7626f3efb59fe55 --dry-run | 終了0、0.307024秒 | [dry-run-check.json](dry-run-check.json) |
| 作業末 work | scripts/check.sh --level work --base 62974229140883a157b79199d7626f3efb59fe55。only なしで一度。仕様対応表の自己検査と集計、仕様例7成功/0失敗/0ignored、既定 Lean ビルドと sorry 拒否 | 終了0、11.080994秒 | [work-check.json](work-check.json) |
| 記録照合 | verify.py --tmp <tmp>。開始入力との差、全追加モジュールの既定 import、全宣言と公理、25欄・33義務・31申し送り、ハッシュ、実行回数、リンクと容量 | 最終の成否と所要は記録を正とする | [verification.json](verification.json) |

直接の既定ビルドと work 内の既定ビルドは別の実行であり、指定された work 自体は一度だけである。新設2モジュールの最終局所 Lean と公理監査に警告はない。既定ビルドは変更していないモジュールの警告を再表示した。Rust の全 lib・clippy・全比較・性能測定・LLM 評価を追加していない。仕様例7件は入口が選んだ既存の検査である。

## 途中の修正・計画との差

局所の Lean では pathInput の入力が Val、出力が Word であることに合わせて readObs を直した。旧三操作の依存列の具体化では Top の効果原子を記号のまま保存する等式と明示の型引数を供給し、文字列名の等号の排除、範囲の WF、Result の arity、値代入後の終端の型を整理した。不要な simp 引数を除いた。これらは全称命題の反例ではなく証明の記法・型注釈・正規化の修正である。一度の編集入力は作業ディレクトリを重ねた相対パスのため書込み前に失敗し、正しい場所で反映した。失敗した局所入力を成功の根拠へ数えない。

記録の最初の verify は、詳細表から写した U02 の相対リンクを一階層直し忘れて終了1になった。obligations.md のリンクを ../u02-options.md へ直した次の照合は終了0である。この修正は記録だけであり、本番・写し・既定ビルド・公理監査・work の入力や結果を変えていない。

配置は ModelTargets と実引数の読者 ModelTargetsApplications の2モジュールに分けた。有限の具体 P は前群の program を再利用した。計画内の配置の具体化であり、主な十言明、新公理、独立の信頼条件、前段の実署名、型付け規則、書ける形、提供範囲、精密外部状態の変更はない。承認済み NamesWF を sig_scoped から供給し、U02 の公開形は選択しない。通常資源の release を Model の空疎な場合と取り違えず、L60 に残す。

処理系、旧 Release、plan/detail/u02-options/README/レビュー、l40・群 A〜H の記録を編集していない。git の操作は行わない。単独 Lean の -o で今回の ModelTargets の生成物を一度更新し、実引数の読者を局所検査した。最終の証拠は全既定ビルド・公理監査・指定 work と記録照合である。大きな具体値の作成・評価、15行全体の decide +kernel、#eval は行っていない。

取りまとめへ新しく判断を求める点はない。独立レビューと設計者の受け入れは未実施であり、この自己点検と区別する。

## 最終照合と単位ごとの所要

verify は開始1,037入力と最終1,039入力を比較し、追加2モジュール・変更3ファイル（根の import と二つの写し）・削除0を確認した。既定 import の閉包1,026モジュールに全追加モジュールが含まれる。全163監査宣言・本番の追加160宣言・主要32実署名、25欄・33義務・31申し送り、各検査の一回分の実行と生出力のハッシュ・相対リンク・各ファイル100 KB 以下を照合した。群の記録は約0.4 MBである。終了時刻と本節の追記後にも同じ入力を照合する。

| 単位 | 開始（日本時間） | 終了 | 外側の所要 |
|---|---|---|---:|
| L50.41 | 2026-11-05T00:43:16+09:00 | 2026-11-05T00:45:24+09:00 | 2分08秒 |
| L50.42 | 2026-11-05T00:45:24+09:00 | 2026-11-05T00:46:16+09:00 | 0分52秒 |
| L50.43 | 2026-11-05T00:46:16+09:00 | 2026-11-05T00:47:39+09:00 | 1分23秒 |
| L50.44 | 2026-11-05T00:47:39+09:00 | 2026-11-05T00:49:16+09:00 | 1分37秒 |
| L50.45 | 2026-11-05T00:49:16+09:00 | 2026-11-05T01:02:27+09:00 | 13分11秒 |

単位区間の合計は19分11秒である。開始前の指定資料の読み取りを含まず、群末のビルド・監査・work・記録照合を L50.45 の内数とする。能動時間と待ちは分離していない。共通の全称証明を再利用できたため、見込み3時間15分〜6時間10分を下回った。4時間の途中報告と12時間20分の上限には達していない。外側の時間を能動時間の係数へ換算せず、後続の旧見込みを保つ。

担当分の L50.41〜.45 は完了し、群 I に独立の未完はない。取りまとめに新しい判断を求める点はない。独立レビュー・所見の処置・受け入れは取りまとめ・設計者に渡す。外部応答と通常資源の解放、全 Core、主定理、Rust/Lean の一致の完了をこの群へ含めない。

| 残る手順 | 内容・担当 | 見込み |
|---|---|---|
| 群 I の独立レビュー・所見の処置・受け入れ | 取りまとめ・設計者。15行・三形・全25欄・全入力・通常資源の区別と監査を照合 | 不明 |
| 群 J | ModelHttp の実表と同じ要求・端点、三モデル75欄の集約 | 計画の3時間15分〜6時間。検査・レビュー待ちは不明 |
| 群 K/L | 全実行読者と33義務・31申し送りの照合、全環境監査・段末検査、独立レビューと受け入れ | 計画の2時間50分〜5時間15分、2時間40分〜5時間。検査・レビュー待ちは別 |
| L60/L70 と後段 | external/release、全 Core、主定理・表層・交換の接続と受け入れ | 各既存計画。待ちは不明 |

## L60 への申し送り（取りまとめ、RV-L50.i の情報7）

- ModelTargets の `releaseResponse` は共通表の `r = none` なので、`release_exists` は `⟨none, rfl⟩` で直ちに成り立つ。前提は File.Handle の型付き値で充足できるが、結論はどの値でも自明に満たせる。L60 は、通常の資源の解放の応答をこの自明な形のまま使うかを判断する。
- `externalResponse` は既定の空の関係のままである。群 H の Model と同じく、外部関数を宣言して `ExternalArgs` を満たす P では `external_exists` が成り立たない。

## 取りまとめによる修正（RV-L50.i の軽1〜4）

- `ModelTargets.lean` から `set_option maxRecDepth 4000` と `set_option maxHeartbeats 2000000` を外した。単独の検査は終了0、実時間2.15秒。
- `readObs`・`io_typed` と一つの定義の docstring を中身に合わせ、「旧読取り」「旧操作」を File.readText・print・exit と名指しした。
- 01-12・07-04 に、File.readText が引数を絶対形として解析できたときだけそのパス一つを観測し、相対形・home 形・解析の失敗では観測が空であることを加えた。07-04 の「旧三操作」「旧読取り」を名指しに改めた。
- 宣言・言明・証明は変えていない。本群の verification.json・audit-summary.json・final-manifest のハッシュは修正の前の作業木のものである。修正の後の状態は、次の節の work（既定の lake build を含む）で確かめた。

## 群 I の作業末の work の検査（取りまとめ）

- 基準: `62974229140883a157b79199d7626f3efb59fe55`。作業木は、取りまとめが RV-L50.i の軽1〜4 を直した後の状態。
- 前処理: `formal/.lake/build/lib/lean/Benitoite/Release/Refinement` と `formal/.lake/build/ir/Benitoite/Release/Refinement` を消し、篩の部分を再ビルドさせた。
- コマンド: `/usr/bin/time -l scripts/check.sh --level work --base 62974229140883a157b79199d7626f3efb59fe55`。
- 結果: 終了0。外側 518.84秒、最大常駐量 2,891,890,688 バイト。仕様例7件が通り、形式化のビルドに sorry はない。
