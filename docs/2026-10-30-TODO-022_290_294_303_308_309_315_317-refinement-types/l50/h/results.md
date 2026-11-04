# L50 群 H の結果

担当の実装と自己点検の記録である。独立レビューと受け入れは取りまとめ・設計者が行う。

- 指定ブランチ: `m014/l50.h`。git の操作は行わない。
- B_WORK: `3ff35eddad3937c3e4ba44144884117af7dc91fe`。
- 対象: L50.36〜.40。external 三条件と通常資源の release_exists は L60 に残す。
- 最大常駐量: 未取得（計画上の非採取）。

## 単位の時刻

日本時間。能動時間と待ちは分離せず、外側の時間として記録する。

| 単位 | 開始 | 終了 | 判定 |
|---|---|---|---|
| L50.36 | 2026-11-04T23:56:33+09:00 | 2026-11-04T23:58:16+09:00 | 完了：三行と八保存則、局所 Lean 終了0 |
| L50.37 | 2026-11-04T23:58:16+09:00 | 2026-11-04T23:58:53+09:00 | 完了：任意 P の形成と表の12欄、局所 Lean 終了0 |
| L50.38 | 2026-11-04T23:58:53+09:00 | 2026-11-05T00:00:31+09:00 | 完了：応答4条件、局所 Lean 終了0 |
| L50.39 | 2026-11-05T00:00:31+09:00 | 2026-11-05T00:06:36+09:00 | 完了：空呼出し・専用二遷移・同じ σ の At 全分岐と Ready、局所 Lean 終了0 |
| L50.40 | 2026-11-05T00:06:36+09:00 | 2026-11-05T00:21:52+09:00 | 完了：25欄、既定ビルド・監査・work・記録照合が終了0 |

## 実装前の固定

Model.builtins は Reference.get・Reference.set・既存の内部 PathBases 発行名の三行だけを持つ。参照の原署名と発行の原署名は ScopeSignatures と同じ値を使う。sat は共通の有限宣言の ModelConstraints.sat を使い、型パラメータの制約を読む。admits はこの三署名の既存の個数検査を使う。八保存則は Model.substitutionAssumptions (P : Program) : Builtins.SubstitutionAssumptions P Model.builtins、最終出力は Model.scopeConditions (P : Program) : ModelScopeConditions P Model.builtins とする。新しい主定理の入力は追加しない。

検査例の作成時の関門: 同じ三行の lookup と型付き引数・専用の発行 Step・同じ σ の snapshot を所有する境界とする。空の sig 表、sat=True、発行を IO として扱う変更、別の snapshot への置換を検出する。前群の共通表の例は Model の部分表を使わないため、Model の読者をここで置く。一般証明は再利用し、検査用の差し込み口は加えない。

## 完了条件の照合

技術的な条件は全場合・全入力を量化した本番の定理で判定する。具体例は実表から前提を供給できることの証拠であり、全称の証明の代わりにしない。群末の検査・監査・記録照合を L50.40 の内数とする。

| 単位 | 全場合・全入力の証拠 |
|---|---|
| L50.36 | Model.sig_cases が成功する全 lookup を名前も含む三場合へ戻す。Model.substitutionAssumptions は任意 P の八欄を構成する。sat の四欄は共通の非空制約を含む全称の骨格の証明、admits の四欄は同じ原署名の個数検査を保存する。値依存の型・行像と型像の衝突を除かない |
| L50.37 | sig_scoped は全三行・任意 P。ref_get/ref_set・state_effect・store_shape/store_admits・pathBases_shape/io_op/opEff_io/effect_ops と sat_unconstrained/admits_sat を同じ Model.builtins で証明する。三署名はデータ宣言を要求しない |
| L50.38 | delta_typed は lookup の全三場合で pure を排除し、io_typed/io_exists は同じ lookup と kind の不一致で排除する。io_kind は空の同じ IO 関係を使う。四欄は元の全 BuiltinArgs・全 out/obs の形を保ち、responseAssumptions に集約する。未定義の δ を応答存在の根拠にしない |
| L50.39 | ModelTargetsExamples.call_arguments/call_typed は任意 P/Ψ に空の全入力の前提を供給する。issue は任意 q/k/μ の専用二遷移・同じ σ の Environment 事象・効果表の membership。issue_to_at は任意の At の全引数を持つ let の実行列、issued_current は全準備成功の同じ snapshot、issued_at は任意 σ と全 At 入力の準備失敗/検査成功/検査失敗。required_base は全5起点と任意のパターンで Reachable と Required を構成する |
| L50.40 | Model.scopeConditions は任意 P について下の二十五欄を同じ表で構成する。targetAgreement は全三行の IO 不在から証明する。既存の ModelScopeConditions.core の適用例は external と release の入力を別に残す。群末の検査結果は後掲 |

## Model の実表と八保存則

| 実名 | 引数 | 結果と効果 | 種類と許容 |
|---|---|---|---|
| Reference.get | reference:Reference[T0] | T0、State | refGet。値 kind の型引数一つ、空制約。型引数の個数を検査 |
| Reference.set | reference:Reference[T0]、value:T0 | Unit、State | refSet。同じ型引数と制約 |
| Example.pathBases（既存の内部名） | 型・行・範囲・値の引数なし | PathBases、Process.Environment | pathBases。型引数は空列だけを許す |

効果表は State → some [] と Process.Environment → some [Example.pathBases]、それ以外は none である。IO の関係は空である。sat は ScopeDeclarations.http の有限宣言から作った要約と ModelConstraints.sat を使う。共通表と同じ carrier/satB であり、非空の鍵制約を持つ tvar は束縛位置の制約を読む。既定ビルド内の対照は、同じ tvar 0 を鍵制約のある文脈では受け入れ、空制約の文脈では拒否する。

八つの保存則は、値の改名・値の代入・型パラメータの改名・閉じた型像による型代入それぞれの sat/admits である。Model の SubstitutionAssumptions は全ての注釈・型付き値像・TypeParamRenaming・SatAll を元の欄の量化のまま受ける。型付き値像は Model の同じ B に依存するので、別の B の型付き値像へ読み替えない。sat_values は B に依存しない ModelConstraints.sat_values を直接使う。admits_values は同じ三署名の個数の保存を使う。

## 二十五欄の実定理

以下の名前は Benitoite.Release.Refinement 内である。八保存則の式は、実際に構成した Model.substitutionAssumptions の各射影を指す。[conditions.json](conditions.json) は同じ25行の機械可読の対応である。

| 欄 | 実際の定理又はその射影 | 判定 |
|---|---|---|
| sat_rename | (Model.substitutionAssumptions P).sat_rename | 証明済み |
| admits_rename | (Model.substitutionAssumptions P).admits_rename | 証明済み |
| sat_values | (Model.substitutionAssumptions P).sat_values | 証明済み |
| admits_values | (Model.substitutionAssumptions P).admits_values | 証明済み |
| sat_renameTypes | (Model.substitutionAssumptions P).sat_renameTypes | 証明済み |
| admits_renameTypes | (Model.substitutionAssumptions P).admits_renameTypes | 証明済み |
| sat_subst | (Model.substitutionAssumptions P).sat_subst | 証明済み |
| admits_subst | (Model.substitutionAssumptions P).admits_subst | 証明済み |
| delta_typed | Model.delta_typed | 証明済み |
| io_typed | Model.io_typed | 証明済み |
| io_kind | Model.io_kind | 証明済み |
| io_exists | Model.io_exists | 証明済み |
| sig_scoped | Model.sig_scoped | 証明済み |
| sat_unconstrained | Model.sat_unconstrained | 証明済み |
| admits_sat | Model.admits_sat | 証明済み |
| pathBases_shape | Model.pathBases_shape | 証明済み |
| io_op | Model.io_op | 証明済み |
| opEff_io | Model.opEff_io | 証明済み |
| effect_ops | Model.effect_ops | 証明済み |
| state_effect | Model.state_effect | 証明済み |
| ref_get | Model.ref_get | 証明済み |
| ref_set | Model.ref_set | 証明済み |
| store_shape | Model.store_shape | 証明済み |
| store_admits | Model.store_admits | 証明済み |
| io_target | (Model.targetAgreement P).io_target | 証明済み |

同じ P/B の新しい Core 全体の無条件の充足は主張しない。L60 に残る欄は external_typed・external_exists・external_no_targets と通常資源の release_exists の4欄である。既存の ModelScopeConditions.core へ、同じ P/B の ExternalAssumptions と release_exists を渡す署名を保つ。群 I/J の二モデル、三モデル合計75欄の集約、通常標準表の収集は本群の完了に含めない。

## 発行と Ready の読者

call_arguments は SignatureInstance・PrimitiveAdmissible・RangeAdmissible・依存引数列・Ground・正規形の各欄を供給し、call_typed が実表の空呼出しを型付ける。issue は NoHandler と σ.Valid から E_PathBasesApply/E_IssuePathBases の二遷移を構成する。発行を δ 又は IO 応答で実行しない。Environment の事象は同じ pathBases.eff が覆い、同じ B.effects のリストに内部発行名が属する。

issue_to_at は同じ発行値を let で At の bases の var 0 に束縛する。トレースには pathBasesName と同じ σ の事象が一つある。At の準備成功時は issued_current から同じ σ を得て、issued_at が E_AtOk/E_AtError に渡す。準備失敗は E_AtPrepareError に渡す。これらは任意の At 引数を量化し、成功する具体例だけから全体を推測しない。空ストア・空継続はこの let の具体的な読者の範囲であり、issue 自体は任意 q/k/μ を量化する。

AtPrepared.of_path_bases は分類・解析・閉じた bases・有効な σ・固定上限の形成を受ける補助定理である。既存の準備関数を変えず、内部の prepareCore/finishPreparation を展開して証明する。任意の有効な σ で cwd の相対入力 "." が準備と検査に成功する例を ModelTargetsExamples に置いた。既存の private 関数を別モジュールから直接展開する代わりに、定義元へこの補助定理を追加した。

required_base は実際の At 状態から、閉包→計算→固定上限の範囲を辿る有限の Reachable を構成する。Ready の Required.base の束縛と resolve_required を同じ到達に適用する。全起点と some [] の secrets を持つ環境は全ての必要束縛を満たす。必要な work が none の状態は Ready ではない。Ready を実行中の全状態に新しく仮定せず、通常資源の release もこの発行の証明へ混ぜない。

## 義務・差・後続への申し送り

[obligations.md](obligations.md) で33義務・31申し送りを一行ずつ判定する。本群の担当に独立した未完を残さず、L50 全体や主定理の閉鎖へ繰り上げない。主な十言明、前段の実署名、型付け規則、公理、精密外部状態、利用者の書ける形、提供範囲の変更はない。承認済みの NamesWF と F06.current の型を継承し、U02 の公開名・完全署名・観測形を選択しない。

計画内の配置として、Model と ModelTargetsExamples の2モジュールを新設し、AtPrepare に補助定理を1本加えた。01-12 と 07-04 は実物どおりの前提と性質を写す。旧 Release、処理系、plan/detail/u02-options/README/レビュー、l40 と群 A〜G の記録は変更しない。git の操作は行わない。新たに取りまとめの判断を求める点はない。

途中の局所検査では、別の B に依存する TypedValueImages を共通表のものへ渡せなかったため、上記の一般の sat_values と個数保存を使う形へ修正した。型の推論のため、共通表の δ/IO の空関係も明示した。実行列のイベント引数と Steps.cons/nil、捕捉の適格性、Required のパターンの証人の保持、未使用の simp 引数を直した。At の成功の適用例では private 関数の直接参照ができず、定義元の補助へ移した。これらは署名の反例ではなく証明の記法と内部配置の修正である。重複した対象を含む一度の apply_patch は適用前に失敗し、ファイル変更はなかった。失敗した局所入力を成功の根拠に数えない。

## 群末の検査

既定ビルド・公理監査・選択確認・一度の work・記録照合の確定値をここへ追記する。固定 Lean は formal/lean-toolchain、単独 Lean は formal/ から lake env lean -M 12288、既定ビルドは同じ場所から対象なしの lake build である。正式 RSS は未取得（計画上の非採取）。

固定版は leanprover/lean4:v4.34.1（arm64-apple-darwin24.6.0、commit 5045d0056413266e57c625dcd7c365b10e377c52、Release）。既定 lakefile の上限も12288である。直接の既定ビルドと work 内の既定ビルドは別の実行であり、指定された work 自体は一度だけである。

| 検査 | コマンドと中身 | 結果・外側の所要 | 記録 |
|---|---|---|---|
| 既定ビルド | formal/ から対象なしの lake build。全1,285ジョブ | 終了0、391.530632秒 | [build-check.json](build-check.json) |
| 公理監査と固定 F09 の全称契約 | audit.py --tmp <tmp>。lake env lean -M 12288。全3モジュールの225宣言、private と生成宣言を含み固定点2巡。主要31実署名 | 終了0、11.496606秒、新公理・sorryAx 0 | [audit-summary.json](audit-summary.json)、[actual-signatures.md](actual-signatures.md)、[contracts.lean](contracts.lean) |
| 選択確認 | scripts/check.sh --level work --base 3ff35eddad3937c3e4ba44144884117af7dc91fe --dry-run。仕様対応表・仕様例・形式化を選択 | 終了0、0.344375秒 | [dry-run-check.json](dry-run-check.json) |
| 作業末 work | scripts/check.sh --level work --base 3ff35eddad3937c3e4ba44144884117af7dc91fe。only なしで一度。仕様対応表の自己検査と集計、仕様例7成功/0失敗/0ignored、既定 Lean と sorry 拒否 | 終了0、11.407182秒 | [work-check.json](work-check.json) |
| 追加件数の照合 | baseline.py --tmp <tmp>。開始時のハッシュと一致する元の AtPrepare を復元し、同じモジュール名で単独 Lean を実行 | 終了0、1.211383秒 | [baseline-check.json](baseline-check.json) |
| 最終記録照合 | verify.py --tmp <tmp>。開始入力との差・全追加モジュールの既定 import・全宣言と公理・25欄・33義務/31申し送り・ハッシュ・実行回数・容量を照合 | 確定値は記録を正とする | [verification.json](verification.json) |

既定ビルドは、AtPrepare の補助定理に依存する共通の型付け・標準本体を再構築したため約6分32秒であった。事前の約7〜8分の範囲内である。変更していないモジュールの警告は再表示されたが、今回の3モジュールの最終局所検査と公理監査には警告がない。Rust の全 lib・clippy・全比較・性能測定を追加していない。選ばれた仕様例は入口の既存の7件である。

## 宣言と公理への依存

| モジュール | 追加した宣言 | 内容 |
|---|---:|---|
| Model（新設） | 33 | entries/effects/builtins、全 lookup の場合分け、八保存則、表12欄と応答4欄、対象一致と二十五条件の出力。private・生成宣言を含む |
| ModelTargetsExamples（新設） | 9 | 空呼出しの全 BuiltinArgs/型付け、専用発行二遷移、let から At、同じ snapshot、必要起点の到達、At 全入力の Step。private の注釈と具体化の補助を含む |
| AtPrepare（既存） | 15 | 手で書いた AtPrepared.of_path_bases 1本と、その証明で必要になった既存定義の等式・分岐の生成宣言14件 |
| 計 | 57 | 定理52・定義5。private の完全名18、行番号0の生成宣言21を含む。分類は重複する |

AtPrepare の元の168宣言と現在の183宣言を、開始時のソースのハッシュと一致する復元入力で照合した。補助の1本だけを宣言の追加総数とせず、生成宣言14件も加えた。baseline.py の最初の復元検査は Command の import 不足で終了1となった。監査の末尾に必要な Lean.Elab.Command の import を復元入力へ加えた最終検査は終了0である。本番の入力・既定ビルド・work・225宣言の公理監査に変更や再実行はない。

公理監査は新設42宣言だけに限らず、変更した AtPrepare の既存・追加を含む183宣言も全て扱う。計225宣言は private の完全名114、行番号0の生成宣言150を含む。各宣言の依存は propext・Quot.sound・Classical.choice の部分集合だけである。新公理・sorryAx・独立の信頼条件は0。全既定環境の段末監査とは区別する。宣言の完全な写しは [declarations-part-01.json](declarations-part-01.json) の群末一回分だけである。

対象一覧は [audit.py](audit.py)・[audit-tail.lean](audit-tail.lean) と [modules.json](modules.json) から再生成できる。private や生成宣言を名前の接頭辞で落とさず、所属モジュールとローカルの宣言を固定点まで列挙する。追加件数は [baseline.py](baseline.py) でも再生成できる。生出力と大きな入力一覧は一時領域に置き、改造には台本・件数・大きさ・SHA-256 を保存する。

- 監査生出力: 98,826 bytes、SHA-256 `4673db730ce1c4f502d9443b07ffa4f73d353317de451a8d6c83c543bada0624`。
- 全対象一覧: 17,319 bytes、SHA-256 `98e881e0393a97f730365779051c5a76c5e13b3880d3d27a64418558481a117f`。
- 追加57宣言の一覧: 3,815 bytes、SHA-256 `f8dc01f057bdd1b9c384abfb01554a0264070ba9464175b9f5f24994a3bd39b7`。
- 宣言の唯一の写し: 43,090 bytes、SHA-256 `5d58b82f68b542b5dbaa9c0471c4d11a82ca2a5c5e9777d54d801aecaf440bcc`。

## 取りまとめへの受け渡し

新しく判断を求める点はない。全25欄は Model.scopeConditions、発行の実読者は ModelTargetsExamples の各入口を使える。L60 は同じ P/B の external 三欄と release_exists を構成して既存の core へ渡す。群 I/J は自分の実表の条件を構成し、群 K/L は実行葉・義務・全環境監査を集約する。本群の自己点検を独立レビュー済み又は設計者の受け入れ済みと記録しない。

| 残る手順 | 内容・担当 | 見込み |
|---|---|---|
| 群 H の独立レビューと受け入れ | 取りまとめ・設計者。実三行・全二十五欄・発行/Ready/At・生成宣言を含む監査を照合 | 不明 |
| 群 I/J | ModelTargets/ModelHttp の実表と、三モデル75欄への集約 | 計画の各群の見込み。検査・レビュー待ちは不明 |
| 群 K/L | 全実行読者、33義務・31申し送り、全環境監査と段末検査、独立レビューと受け入れ | 計画の2時間50分〜5時間15分、2時間40分〜5時間。待ちは別 |
| L60/L70 | external/release、全 Core、主定理と表層への合成 | 各既存計画。待ちは不明 |


## 最終照合と単位ごとの所要

最初の verify は、詳細から写した申し送りの U02 の相対リンクを一階層直し忘れて終了1となった。h からのリンクを ../u02-options.md に直した次の照合は終了0、0.139658秒であった。終了時刻とこの最終記録の追記後にも同じ入力の照合を行う。本番・写し・公理監査・既定ビルド・work の入力や結果の変更はない。work は一度だけである。

開始1,035入力から追加2モジュール・変更4ファイル・削除0を確認した。変更は AtPrepare の補助定理の挿入、根の import と二つの写しだけである。AtPrepare の追加部分を除くと開始時のソースの SHA-256 に一致する。既定 import の閉包1,024モジュールに全新設モジュールと変更モジュールが含まれる。全225監査宣言、追加57宣言、主要31実署名、二十五欄、33義務・31申し送り、相対リンクとハッシュを照合した。群の記録は約0.4 MB、各ファイル100 KB以下である。

| 単位 | 開始（日本時間） | 終了 | 外側の所要 |
|---|---|---|---:|
| L50.36 | 2026-11-04T23:56:33+09:00 | 2026-11-04T23:58:16+09:00 | 1分43秒 |
| L50.37 | 2026-11-04T23:58:16+09:00 | 2026-11-04T23:58:53+09:00 | 0分37秒 |
| L50.38 | 2026-11-04T23:58:53+09:00 | 2026-11-05T00:00:31+09:00 | 1分38秒 |
| L50.39 | 2026-11-05T00:00:31+09:00 | 2026-11-05T00:06:36+09:00 | 6分05秒 |
| L50.40 | 2026-11-05T00:06:36+09:00 | 2026-11-05T00:21:52+09:00 | 15分16秒 |

単位区間の合計は25分19秒である。能動時間と待ちは分離していない。開始前の指定資料の読み取りを含まず、群末のビルド・監査・work・記録照合は L50.40 の内数である。見込み2時間55分〜5時間20分と上限10時間40分には達していない。既存の八保存則と準備・実行の定義を再利用できたため、見込みを下回った。外側の時間を能動時間の係数へ換算せず、後続の旧見込みを保つ。

担当分の L50.36〜.40 は完了し、群 H に独立の未完はない。独立レビューと設計者の受け入れは未実施であり、取りまとめ・設計者へ渡す。新しい判断を要する点はない。

## L60 への申し送り（取りまとめ、RV-L50.h の情報5）

- Model では `isResource` が常に false なので、`release_exists` は前提が偽になり空疎に成り立つ。通常の資源の条件の実質は ModelTargets などの表にある。
- Model の `externalResponse` は既定の空の関係なので、`external_typed`・`external_no_targets` は空疎に成り立つが、`external_exists` は外部関数を宣言して `ExternalArgs` を満たす P では成り立たない。L60 は P を制限するか、Model の外部応答を定める。

## 群 H の作業末の work の検査（取りまとめ）

- 基準: `3ff35eddad3937c3e4ba44144884117af7dc91fe`。作業木は、取りまとめが RV-L50.h の軽1・軽2 を直した後の状態。
- 前処理: `formal/.lake/build/lib/lean/Benitoite/Release/Refinement` と `formal/.lake/build/ir/Benitoite/Release/Refinement` を消し、篩の部分を再ビルドさせた。
- コマンド: `/usr/bin/time -l scripts/check.sh --level work --base 3ff35eddad3937c3e4ba44144884117af7dc91fe`。
- 結果: 終了0。外側 475.89秒、最大常駐量 2,944,581,632 バイト。仕様例7件が通り、形式化のビルドに sorry はない。
