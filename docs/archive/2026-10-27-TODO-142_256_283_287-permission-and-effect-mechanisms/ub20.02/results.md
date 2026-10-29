# UB20.02: 表示・交換と由来の境界の点検

## 作業と状態

2026-10-28、`m013/ub20`。B_WORK と HEAD は `3fc9b3f88c039e61bf797b1da574e5275028253d` である。[UB20.01](../ub20.01/results.md) に続けて点検した。現在の型・効果の表示、名前だけの報告と上限の照合、旧版交換の分離を確認した。新規の本番修正依頼は0件である。

`effects.bounds`、由来の新しい任意欄、Rust の新形式の書き出しとその報告読者・manifest の接続は未完である。後続の予定どおりであり、本作業の成功から最終読者の確認済みとはしない。下に R40.3・K10.2 の具体的な確認と UB30 への引き継ぎを記す。本番のコード・設計書・テストは変更していない。`private/`・同所を指すスキル・`docs/todo/` は読んでいない。git の状態を変える操作は行っていない。

## 点検表

表の `types/`・`resolve/`・`typeck/`・`cli/` 等は `crates/benitoite/src/`、`tests/` は `crates/benitoite/` を起点とする。完全なパスと `formal/` はリポジトリの根から示す。記録の読解と、本作業の小入力による確認を分けた。

| 観点 | 見た箇所 | 結果 | 根拠 |
|---|---|---|---|
| 利用者の原子が Top であること | `crates/benitoite/src/types/mod.rs::EffectName::indices_valid`、`typeck/decls.rs::effect_name`・Item::Effect、`resolve/scope.rs::effect_arguments` | 読解と UB20.01 の実入力で確認。利用者操作の効果は `User(BindingId, TOP)` で、非 Top と範囲の変数を許さない | 利用者 Write の範囲引数・型引数は E0513。固定範囲を持つ操作の値引数と、操作自身の原子の範囲とは別である |
| 型と効果の表示 | `types/mod.rs::show_ty`、`types/builtin.rs::RangeIndex::suffix`、`types/scope.rs::Range::suffix` | 読解・実入力で確認。Top は名前だけ、固定範囲は接尾辞で表示する。IO.All の略記が範囲付き原子を消すことはない | 型不一致の E0401 の主ラベルに `/data/reports/**` と `/other/**` の両添字が残る。文字列は `base::literal::quoted`、port は一点または閉区間の表示である。内部の rvar 表示は利用者の構文ではない |
| 処理した利用者名の除去 | `typeck/effects/handle.rs::check`、`ir/desugar/effects.rs::handle`・`handle_effect` | 読解・実入力で確認。名前の全操作の節がそろえばその名前を処理し、節自身の効果を外側へ加える | Report を処理して純粋に再開する main は上限・報告とも空。節で File.Write の関数へ渡す固定引数の例は、外側の報告が File.Write だけになる。Report を宣言上限へ残す入口は E0506 で拒否される |
| 宣言上限と実際の効果 | `cli/inspection.rs::function_contract`、`cli/check_report.rs::main_value` | 読解・実入力で確認。報告の basis は `declaredUpperBound` であり、宣言した上限を示す | 本体が `()` でも `uses File.Write[...]` を宣言すれば File.Write を報告する。範囲の宣言から実 IO の発生を主張しない。処理済み名を本体から再収集する処理はない |
| 名前だけの表示 | `cli/inspection.rs::FunctionContract`・`function_contract`、`cli/check_report.rs::main_value` | 読解・実入力で確認。型表の原子は保持し、報告用の所有データを BuiltinEffectId の名前集合へ射影・重複除去する | File.Write の二範囲と Top を併記した入力の expanded は一つの File.Write。現在の FunctionContract は範囲を保持せず、bounds は未実装である |
| 処理済み名を報告へ戻さないこと | `inspection.rs` の entry contract と file_origins、`check_report.rs` の aggregateEffects、`cli/tools/test_runner/check_report.rs::inspect_value` | 読解・実入力で確認。main・各 test・集約は同じ検査済みの契約から標準名を取り出す | `User` が入口の scheme に残れば内部エラーとする防御があり、その前に型検査の E0506 で拒否する。file_origins の Top の User を飛ばす処理は、処理済み名を許可の一覧へ戻す処理ではない。実入力の通常・test・複数 test の集約に Report は現れなかった |
| 未完了と空集合 | `cli/check_report.rs::value`、`cli/tools/test_runner/check_report.rs` の集約 | 読解・実入力で現在の境界を確認。拒否時の aggregateEffects は null、処理後に純粋な入口は expanded が空配列となる | 未処理 Report の E0506 は `complete=false`・aggregateEffects=null。純粋な処理後は `complete=true`・expanded=[]。今後の bounds の未知・予算停止・未完了の扱いは R40.3 で確認する |
| 権限の照合の単位 | `cli/effect_limit.rs::parse`・`check`、`types/builtin.rs::effect_name` | 読解・実入力で確認。許す集合は原子的な標準エフェクトの番号だけで、名前の全対象の上限として照合する | `--allow-effects=File.Write` は固定範囲の例を受理する。空なら E0512。Report と `File.Write["/data/reports/**"]` は使い方の誤り。処理後に純粋な例は空の許す集合で実行できる |
| 交換の user/prim の分離 | `tests/desugar_export/exchange.rs::op_ref`・`named_operation_tables`、`builtins.rs::named_builtin_tables` | 読解で確認。user は `op:<束縛番号>`・`effect:<束縛番号>`、prim は標準表の完全名を使い、fail も別のタグである | 操作と節の名前を同じタグ・鍵で書く。標準の所有エフェクトと user の表を別に出し、コアの束縛・builtin_ops・scheme の一致も assert する。綴りが同じ利用者名を標準名の文字列へ書き換えない |
| 旧形式の Top と非 Top | `exchange.rs::Surface::eff`・`ty`・`named_operation_tables`、`builtins.rs` | 読解で確認。旧形式は利用者原子を名前だけで書き、意味上は Top である。非 Top の原子・型、未具体化の添字は明示的に断る | `RangeIndex::TOP` との assert がある。固定範囲の利用者操作の値引数も旧形式では書けない。範囲を黙って落として成功する経路ではないが、新形式の接続を確認したことにもならない |
| 新形式の書き出しと読者 | `tests/desugar_export.rs`、同ディレクトリの `exchange.rs`・`builtins.rs`・`check_named.py`・`check_batch3.py`、`formal/Benitoite/Exchange/Version.lean`・`Range.lean` | 未接続。Lean の新版読者は存在するが、現在の Rust 出力・Python の照合・manifest は旧形式である | 通常の namedVersions は corpus14/table6/coverage6。新形式の corpus15/sidecar7 に必要な ix・rkinds・shape・認定表・scopeAcceptance、cover/nonTopRanges の照合はまだない。旧版の Top 補完と新版の必須欄の検査は Lean 側で分けている |
| manifest と比較の対象 | `exchange-manifest.json`・`routing-manifest.json`・`batch3/manifest.json`、`check_named.py::routing_entries`・`check_batch3.py::check` | 読解で確認したのは現在の記載内容と読者の契約までである。今回、全比較は実行していない | named の program/routing は各1,792入力で routing の版は14。batch3 の記録には13/5の互換入力もある。既存の件数・除外・対象外理由を保持する仕組みはあるが、範囲の群の nonTopRanges>0 を要求する接続はまだない |

[exchange-inventory.json](exchange-inventory.json) に、点検した書き出し元・読者・manifest と Lean の版契約の大きさ・SHA-256、manifest の版と件数、今回の新しい欄が Rust 側にないことの検索結果を保存した。これはソースと記載内容の点検であり、manifest と新出力の一致を実行で確認した記録ではない。

## 表示・引数・照合の単位

| 対象 | 単位と現在の意味 | 広げていない保証 |
|---|---|---|
| 型／効果の表示とソースの範囲引数 | 標準の名前と閉じた範囲を型表で保持する。利用者の原子は Top。利用者操作の値引数には標準の固定範囲の型を書ける | 利用者のエフェクト自身の範囲の束縛・型引数・全称の節を提供することにはならない |
| effects.expanded と allow-effects | 原子的な標準エフェクトの名前である。同名の複数範囲は一つの名前にまとめ、その種類の全対象を上限として読む | 処理済みの利用者名の追跡・許可、実行中の操作ごとの強制、パスの実体の隔離を表さない |
| 後続の effects.bounds | 宣言上限の各標準原子の name/scope を保持し、Top は all として表す予定である。現在は未実装である | host/port の端点を scheme を持つ origin と同一視しない。未知・未完了を空集合にしない |
| 後の由来の説明 | 処理した操作や成功した検査との関係を説明する任意の情報として追加位置を点検した | 由来に現れた利用者名を expanded・bounds・allow-effects の許可項目へ合併しない。由来だけから範囲や権限を決めない |

## 後の由来の任意欄を置く位置

内部で情報を取り出す位置は `inspection::function_contract` である。ここでは CheckedProgram の型表、解決済みの束縛、宣言の位置、effective_effects の由来をまだ参照できる。その後の FunctionContract は名前の一覧とファイル宣言の位置だけを持ち、AST と型表を破棄するので、後から名前だけを見て個々の範囲とその由来を復元できない。R40.2 が bounds のために原子を保持する際には、この境界も照合する必要がある。

報告側の追加位置の候補は、main と各 test 関数の報告に属する説明用の任意欄である。現在の挿入点は `check_report::main_value` と `test_runner::check_report::inspect_value` であり、集約には対象ごとの対応とソース識別を保つ必要がある。`sources` の内容ハッシュ、sourceSets、targetId と、元の宣言・出現の位置の対応を使えるかを後続で確認する。`file_origins` はファイル上限の診断用の位置であり、検査成功値や処理した操作全体の由来の欄としては足りない。

この任意の説明を読み飛ばす既存の受け手も、expanded の保守的な名前の上限を得られる境界を保つ。処理した利用者名を説明へ含める場合も、許可の集合への挿入とは分ける。ここでは欄名・型・意味の新しい仕様を確定していない。R40.3 はこの分離と任意欄を無視する場合を点検する担当であり、由来の新機能を実装する依頼ではない。

## 実入力

[probe.py](probe.py)・[inputs](inputs/)・[probes.json](probes.json) に11通りのコマンドと全出力を保存した。最終は期待どおり11件であり、終了0が7件、期待した拒否の終了2が4件、内部エラーは0件である。各入力・CLI の SHA-256 も保存した。

| 入力・入口 | 確認した結果 |
|---|---|
| UB20.01 の固定引数の例、通常 check | 宣言上限の expanded は `[File.Write]`。Report はない |
| Report の処理後に純粋な main、通常 check | expanded は空、complete は true。空の allow-effects でも実行が成功する |
| File.Write の二範囲と Top の宣言 | expanded は一つの File.Write。現在の報告に bounds はない |
| 同じ固定引数の例を @test にした非実行の検査 | 各 test と aggregateEffects は File.Write だけ。Report はない |
| 固定引数の test と純粋な処理後の test を二パスで集約 | 各関数の上限を保ち、集約は File.Write だけ。どの契約にも Report はない |
| 未処理 Report | E0506、complete=false、aggregateEffects=null。空の純粋契約として報告しない |
| File.Write の名前の上限、空の上限、不正な利用者名と範囲付きオプション | File.Write は受理、空は E0512、Report と範囲付きオプションは使い方の誤り |

実行した二つの成功例は、本体が `()` の main または純粋な利用者操作の処理だけであり、File/HTTP の IO は実行していない。File.Write を宣言した関数を節で呼ぶ例で、標準エフェクトだけが外側へ残る静的な境界を確認した。範囲を持つ新しい標準 IO の実本体と観測まで確認した扱いにはしない。

初回の集約の試行は、単一パスだけを受ける `check` へ二つのパスを渡したため usageError となった。[初回台本](probe-first.py.txt)と[初回出力](probes-first.json)を残した。既存の複数パスの集約入口である `test --check --report=json` に直し、二つの @test の入力で再確認した。本番の不具合ではない。

## 見つかった問題と修正の依頼

新規の本番修正依頼は0件である。次の未接続は計画に割り当て済みであり、現在の枝の不具合や、新たな機能追加の依頼として数えない。

| 返す枝 | 重さ・区分 | 未接続の箇所 | 依頼 |
|---|---|---|---|
| R40.2、閉じる位置は R40.3 | 計画済みの未完（不具合の重さは付けない） | FunctionContract は名前だけを保持し、通常・test・集約に bounds がない | 原子の保持と DET-06 の name/scope、basis、Top、未知・未完了を全接点で閉じる。処理済み名の復活と、任意の説明から許可の集合への混入を防ぐ |
| R10.7・K10.1、読者と manifest は K10.2 | 計画済みの未完（不具合の重さは付けない） | 旧交換は非 Top の型・原子を断り、Python の読者は旧版の欄と結果だけを照合する | 新版を生成・検証し、利用者原子の明示 Top、固定範囲の値引数、認定表と具体化列、cover/nonTopRanges と件数を照合する。Top への丸めや比較対象の削減で合わせない |
| R40 | 軽（既存 RV-R10.2b 軽3） | `RangeIndex::suffix` の内部の rvar 表示の断片が関数内にある | 表示をそろえる際に既存の文言規約に従って整理する。利用者の新しい範囲の変数の構文にしない |

UB20.01 の R10.6 宛ての既存の軽い依頼も引き継ぐ。これらを本作業で修正していない。

## 後の枝へ残す点

| 担当・閉じる位置 | 具体的な照合と受け渡す証拠 |
|---|---|
| R40.3（実装は R40.1/.2） | R30 の実 `File.writeTextIn` 等を用いる固定引数の利用者操作の例を、通常・集約・test で確認する。宣言上限の expanded は File.Write、bounds は同じ宣言範囲だけで、Report を含めない。純粋な処理後は空、Top は all、拒否・解析未完了を空にしない。二つの範囲と Top の同名併存、旧受け手が bounds を無視する場合、名前だけの allow-effects、範囲付きオプションの拒否も確認する。由来の任意欄の分離を最終の所有データと報告読者で照合し、例・報告・独立期待値を K10.2 と UB30 へ渡す |
| K10.2（書き出しは R10.7/K10.1） | `desugarDiff`・`builtinCheck`・`surfaceCheck`・`surfaceCheckAll`・`coverageDiff`・`coverageProgramDiff` の六入口を保つ。user の原子は明示 Top、固定範囲の値引数は保持、user/prim/fail の参照と節は別々のまま、と独立入力で確認する。同綴りの利用者関数・別名・成功／拒否・旧全 Top／非 Top・別対象の節を含める。署名だけの rvar、プログラムの閉性、effKinds/valKinds/admitsR/valContents と実際の標準表の対応、scopeAcceptance と実ソース位置を確認する |
| K10.2 の報告・manifest | surfaceCheck の result.cover、surfaceCheckAll の拒否文と nonTopRanges、desugarDiff の nonTopRanges を読む。範囲の比較群ごとに非0を要求し、全 Top の既存群と分ける。既存の件数・除外・対象外理由を保ち、利用者の固定引数を含む群を新出力と manifest に載せる。必須判定の四理由の直接比較と、効果上限の atomicCoverOnly に対する E0519／Lean の型付け拒否の比較を分ける。実 IO の観測と observationAllowed も接続し、長い全比較は K10.3、最終関係状態は V10 に残す |
| UB30.01（境界文書と転記案） | 名前だけの表示、標準の範囲引数、権限の照合の単位、後の任意の由来を上の表どおり分ける。範囲引数の追加だけでは処理済みの利用者名が main の型へ残らないことを記す。許可を利用者エフェクト単位へ広げることを将来の確定機能にしない。TODO-302/054 への転記案はこの改造内に置き、取りまとめが転記する |
| UB30.02（独立レビュー） | 本書と UB20.01、R20.6・R30.5・R40.3・K10.2 の追記済みの結果を照合する。後続の証拠がない項目は未確認とし、全比較済み・実行時の許可・実体の隔離・情報フロー制御を保証した文言がないか確認する。新 API 後の再確認は当該 R/K の予算とレビューで受け持ち、UB20 の時間を再計上しない |

## 検査・時間

通常 CLI の表示と上限照合は、リポジトリの根で `python3 docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/ub20.02/probe.py` を実行した。各コマンドの正確な引数・終了・外側時間は [probes.json](probes.json) にある。ビルドは UB20.01 の一回だけで、同じ SHA-256 の CLI を使った。再ビルド・Rust のテスト・Lean・形式化との全比較・stage・short は実行していない。

作業末は、指定された W-D の dry-run を UB20.01/.02 共通で一度だけ実行した。本番の変更はなく、点検の記録と補助入力だけの変更である。独立レビュー・受け入れ・取り込みは取りまとめに残る。

### 作業末の確定値

リポジトリの根で次の指定を `/usr/bin/time -p` で包み、一度実行した。

```sh
scripts/check.sh --level work --base 3fc9b3f88c039e61bf797b1da574e5275028253d --dry-run
```

終了0、外側0.232727秒で、`nothing to check: only documents changed` と報告した。dry-run 時点の53ファイルを文書と分類し、検査の選択はない。[生ログ](work-check-dry-run.log)と[正確なコマンド・終了・計時](work-check-dry-run.json)を保存した。これを実際の Rust の検査・形式化との比較の成功とは数えない。以後の変更は結果の確定値と最終確認の記録だけである。

最大常駐量の補助値は10,993,664 bytes（10.484375 MiB、約0.01024 GiB）である。この dry-run だけを待った Python の macOS `getrusage(RUSAGE_CHILDREN).ru_maxrss` であり、同時の全プロセスの合計ではない。`time -p` 自体は RSS を採取しない。専用 target でのビルドの96.136秒と約3.5755 GiBは UB20.01 の別の実行であり、合計しない。

記録の仕上げで、日本語の追記を含む一時的な Python コマンドが stdin の UTF-8 の構文エラーで実行前に停止した。ファイルへの変更はなく、同じ追記を apply_patch で反映した。小入力や検査の失敗ではない。

最初の時計13:04:49 UTCから、仕上げ中の時計13:22:24 UTCまで17分35秒であり、時計の前の規約の読解と最後の確認を含む全体の外側は約20分という概算である。UB20.01/.02 の枝ごとの厳密な能動時間は分離せず、全体の能動時間は約18分という概算である。ビルド待ち96.136秒の間にも文書を点検したため、能動時間と待ちを単純に足さない。最終の小入力の所要は各 probes.json に記す。性能測定・回答待ち・独立レビューの待ちはない。見込み計1〜2時間の上端の2倍（4時間）には達していない。

最後に、HEAD・ブランチ、追跡済みの差分と index の差分がないこと、未追跡の成果物が許可された二ディレクトリだけにあること、相対リンクの実在、絶対パスと禁止されたリンクの不在、最終の小入力28通りの期待との一致を確認した。[最終確認](final-state.json)に保存する。本番の修正はなく、新しい保証・API・交換形式を定めていない。独立レビュー・設計者の受け入れ・取り込みは取りまとめが受け持つ。
