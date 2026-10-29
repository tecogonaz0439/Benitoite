# R30.1: 旧 Scope の IP/CIDR・正規化と既知の不良の追加検査（R30.1b 対応を含む）

## 作業と状態

B_WORK と作業開始時の HEAD は `ddadf40d6d85b752717252c315cabe3f662c1cf8`、作業先は `m013/r30.1` である。R30.1 の開始時の差分はなかった。R30.1b は同じ HEAD・ブランチ上で、R30.1 の未コミットの差分と結果を引き継いだ。コミット・ブランチなど git の状態を変える操作は行っていない。`private/` と、そこを指すスキル、`docs/todo/` は読んでいない。

旧 Scope の IP/CIDR、成功時に保存するパターンの正規化、旧・新の検査入口の既知の不良の追加拒否、交換での除外の確認、指定六章の更新を完了した。W-R は初回のテスト失敗を修正し、成功分と続行分を合わせて割り当てを満たした。H も終了0だった。独立レビュー RV-R30.1 は重大0・中0・軽5で「取り込んでよい」と結論した。軽1〜軽5への R30.1b の対応を終え、末尾に記録したとおり、最終状態で一度実行した W-R も終了0だった。六 File 操作・HTTP の実通信・Lean と Rust の全比較と、取りまとめによる受け入れは本枝では行わない。

## 変更と接続

| 対象 | 変更 |
|---|---|
| `src/builtins/checked_scope.rs` | 旧 host/endpoint を `HostPattern`・`HostTarget` に接続した。既知部分だけの判定と失敗順を保ち、成功時に共通の IP formatter による正規形を返す |
| `src/builtins/funcs/scope.rs` | 共通判定が返した正規形を旧成功値へ保存する。IPv4 を拒否するとした旧英文を共通判定側で修正した |
| `src/typeck/checked_args.rs` | 新しい検査二入口を追加し、公開引数の位置を共通判定の契約順へ対応付けた |
| `src/typeck/scope/local_tests.rs` | 既知の不良を含む既存入力に追加診断五件を明示し、先行する局所解析の独立期待値を保った |
| `tests/fixtures/checked-scope.json`・`tests/runtime_builtins.rs` | IP/CIDR の独立表と、射影した保存内容の再検査を既存の主テストへ加えた |
| `tests/checked_args.rs` | k1〜k5 の通常ソースと、部分既知・const・引数順・位置・間接呼び出しの表を一つのテストへ加えた |
| `tests/scoped_calls.rs` | リテラルの逆転の追加拒否と、bind を介した未知の条件の従来の必須受理を分け、既存テストを追随させた |
| `tests/desugar_export.rs` | 旧・新の E0459〜E0462 を同じ交換の入口へ渡し、除外コードと空の定義を確認する |
| 設計書 01-06・02-05・02-10・03-06・03-09・07-04 | 受理する IP の領域、保存の正規化、追加検査の対象・順序・診断と形式化の範囲をそろえた |

本表のソースのパスは `crates/benitoite/` からの相対パスである。`cargo run -p benitoite --example gen_skill` は終了0であり、R30.1 の生成では差分がなかった（[ログ](gen-skill.log)）。R30.1b では文書コメントを直し、生成した二つの標準ライブラリ文書も更新した。公開の型・関数の構造と標準宣言の署名、依存、scripts、Lean は変えていない。

## IP/CIDR の独立期待値と正規化

共有 fixture は98例であり、成功32例を含む。既存の IPv4 対象一例を InvalidTarget/E0460 から OutsideScope/E0462 へ変え、31例を追加した。期待値は共通判定から生成せず、fixture に書いた。

| 入力の例・境界 | 独立期待値 |
|---|---|
| `192.168.1.0/24` と `192.168.1.20` / `192.168.2.20` | 成功 / OutsideScope |
| `2001:db8::/32` と `2001:db8::a` / `2001:db9::a` | 成功 / OutsideScope |
| IPv4 の `/0` と IPv6、IPv6 の `/0` と IPv4 | OutsideScope |
| IPv4 の `/24` と `::ffff:192.168.1.20` | OutsideScope。mapped は IPv6 のままである |
| `::ffff:192.168.1.0/120` と mapped / IPv4 の対象 | 成功 / OutsideScope |
| IP パターンとホスト名、名前パターンと IP | OutsideScope。DNS による相互変換はない |
| `192.168.1.5/24`、`2001:db8::1/32` | host bits があるため InvalidPattern/E0459 |
| `/32`・`/128` と完全一致、mapped の `/128` | 同じ対象で成功し、最大 prefix を省いた完全一致のパターンを保存する |
| `001.2.3.4`、大文字・余分な0を含む非正規 IPv6 | パターンなら E0459、対象なら E0460 |
| `127.1`、`0177.1`、`127.0x.0.1` | 旧 Scope の直接入力では名前として一致する。四つの全数字ラベルの除外と、HTTP URL の数値風ホストの拒否とは区別する |
| IP の endpoint と閉区間の端、区間外の port | 端を含む成功 / PortOutsideScope。host の不所属は port の不所属より先である |

ホスト名のパターンと対象は ASCII 小文字にそろえ、IP/CIDR は共通の formatter で保存する。パスは正規形だけを受理するため、入力の字面を保存する。`//**` などの不良を補正しない。成功32例は既存の VM・参照実行器の主テストで、各射影から保存したパターン・対象・ポートを取り出して同じ検査へ再度渡す。

L40.1 申し送り2は、Lean の `makeHost` が正規化しない入力パターンを保存し、Rust が正規形を保存する差を、`makeHost_normalize_success_iff` による正規化前後の成否の同値と保存後の再利用の検査で対応付けると判断して閉じた。

言語ヒープの保存欄・確保順・根・障壁・安全点は変えていない。`CheckedPair` の `Cow` はホスト側の Rust 文字列を所有するだけで、言語の値を安全点の外へ保存しない。静的検査も共通の判定を使う。正規形の保存内容の変更を含むため、R30.1 で H を追加実行し、成功した。

## 既知の不良の対象と診断

| 入口 | 静的に検査する既知の入力 | 診断 |
|---|---|---|
| 旧 `Scope.checkHost` | pattern・host | E0459・E0460・E0462 |
| 旧 `Scope.checkPath` | pattern・path | E0459・E0460・E0462 |
| 旧 `Scope.checkEndpoint` | hostPattern・host・minimumPort・maximumPort・port | E0459〜E0462 |
| 新 `Scope.checkPathIn` | pattern・path | E0459・E0460・E0462 |
| 新 `Scope.pathInValue` | 条件の文字列・ポートの入力なし | 追加対象なし |
| 新 `Http.checkRequestIn` | hostPattern・minimumPort・maximumPort | E0459・E0461 |
| 新 `Http.requestInValue` | 条件の文字列・ポートの入力なし | 追加対象なし |

E0459 はパターンの形式、E0460 は対象の形式、E0461 はポートの範囲外・両端の逆転、E0462 は所属の不良である。番号と英文は既存の `diag::codes` を使い、新しい番号・文言を加えていない。02-10 に分類と対象入力の表を加えた。

対象は通常の直接呼び出しで、リテラルと既存の定数取得で分かる const の直接参照である。未知を仮の値で埋めず、既知の部分だけで不良と分かる場合を報告する。取得の予算・const の由来の上限・間接呼び出しの扱いは既存のままである。HTTP 要求レコード内部の URL は、この検査で新たに解析せず実行時へ残す。旧三入口の文字列・ポートの検査と同じ対象にそろえたものである。

k1 は E0459、k2・k3 は E0461、k4 は従来どおり E0459、k5 は E0460 となる。名前付き引数の順を変えた場合と const の由来の一次・補助位置も通常の入口で確認した。詳細は [担当メモ](known-checks.md) と [局所検査ログ](known-all.log) に残す。

追加検査は本体の後の `checked_args` に置いた。型制約前の Scope の局所解析、全本体の必須の受理、規則の選ぶ範囲の列と理由を変更していない。意図して不良を含めた局所解析のテストでも、既知不良の五診断だけを追加期待し、範囲の独立期待値は変更していない。

テストの作成時の関門では、公開の通常検査・実行・交換の三つの境界に分けた。通常検査は新入口の登録漏れと HTTP の引数位置の取り違えを、既存の runtime 主テストは保存した条件を再利用できない退行を、交換のテストは追加拒否を型付け比較へ誤って送る退行を捕まえる。テスト専用の本番 API・フラグは加えていない。テストは削除していない。本番の Rust は70行追加・52行削除（純増18行）、テストの Rust は400行追加・17行削除（純増383行）、共有 JSON は265行追加・2行削除である。

## 全比較での扱いと根拠

既存の E0459〜E0462 と同じ扱いを採る。`tests/desugar_export.rs` の `export` は、通常の検査が program を返さない入力について、診断のコードを `excluded` に保存し、`definitions` を空にする。現在の書式は `Some(E0459)` のような文字列である。`CorpusStream::push` はこの入力を「検査の誤りによる除外」に数える。新しい専用の印を加えず、既存の形式を保つ。

この経路へ旧・新各四例を渡し、E0459〜E0462 の八件が診断コード付きで除外され、定義と coverage が渡されないことを確認した。[交換の出力](exchange/known-scope-failures.json) と [ログ](exchange.log) が根拠である。これにより、Rust の追加拒否を Lean の必須の受理の拒否や受理の不一致と混同しない。除外は成功例にも数えない。

`exchange/known-scope-failures.json` は最後の `tests/desugar_export.rs` の編集より前の出力であり、最終のテスト内容は R30.1 の W-R での desugar_export 44件の成功で確認した（出力は再生成していない）。

Lean の `ScopeState` は解析済みの範囲を得る parser を引数として受け、`ScopeAccept.acceptRange` は未知なら Top だけを受理する。`ModelHttp.checkRun` は動的な条件・端点・静的範囲の所属を検査し、不良なら通常の Error を返す。今回の本体後の E0459〜E0462 はこれらの規則に追加する受理ではなく、Rust 側の追加拒否である。規則・主定理・Assumptions・保証の変更は不要だった。

K10 では既存の除外件数・診断を確認し、非 Top の比較入力と独立期待値を維持する。本枝の八例の成功を全比較の成功として引用しない。`check-formal.sh`・`lake build` は実行していない。

## 計時の探査

比較器の README「自己検査」を一度実行し、39件成功・終了0、外側99.008秒だった。コマンドは `PYTHONPYCACHEPREFIX=target/bench/pycache python3 -m unittest discover -s tools/bench/compare -p 'test_*.py'` である。[ログ](compare-selftest.log)・[計時](compare-selftest.json) に残す。

自己検査は開始版 `6124775788579e60530f55fb85570f26ef7fa900` と B_WORK の両方について、共通の builder により探査のバイナリとハッシュを照合し、独立 IR とグラフの入力を実行した。開始版と B_WORK の probe ハッシュはそれぞれ `d83b67613fe82713118dfa308bfc5cfaa1e6b9bb9169a7cc26c7761cd42129bc`・`8096dbfc77e82d9529dbdae85ff54ace6e1979ffbcf007296c68c87fdf2daf40` であり、[ビルドの根拠](probe-build-evidence.json) にコマンド・API の判別・キャッシュの再利用を含めて保存した。両方とも既存のビルドを再利用した。今回変えた `CheckedPair` は crate 内だけの型で、探査の使う公開構造に変更はなく、`timing_probe.rs` の追随修正は不要だった。short の性能比較は実行していない。

## 検査

計時の実行器は [run_logged.py](run_logged.py) である。`/usr/bin/time -p` へ検査スクリプトを直接渡し、パイプや後続コマンドで終了状態を置き換えない。time の終了状態は検査スクリプトの終了状態を伝える。外側時間は Python の monotonic 時計でも採取し、最大常駐量は `getrusage(RUSAGE_CHILDREN).ru_maxrss` の補助値を記録する。macOS の原値は bytes、MiB は 2^20 bytes である。並行する子プロセスの RSS の和や、作業全体の合計ではない。

W-R の初回は `scripts/check.sh --level work --base ddadf40d6d85b752717252c315cabe3f662c1cf8 --dry-run` で選択を確かめ、同じ実行を `/usr/bin/time -p` で包んだ。fmt、examples を含む clippy、既定 lib 全件、全統合、規約、生成物、仕様集計が選ばれた。[dry-run](work-dry.log)・[初回のログ](work.log)・[計時](work.json) に残す。lib は1,391成功・22 ignored である。統合33対象の実行中、scoped_calls の一件の失敗で終了1となり、後の九統合対象と規約・生成物・集計は未実行だった。

初回後の変更は `tests/scoped_calls.rs` の追随だけであり、本番・lib の入力は変わらないため lib 全件と成功した32統合対象を重ねなかった。失敗した対象と未実行の九対象を含め、次の名指しで続行した。

```sh
/usr/bin/time -p scripts/check.sh --level work --base ddadf40d6d85b752717252c315cabe3f662c1cf8 --only fmt,lint_default,tests_related,source_rules,skill_generated,spec_tally --test scoped_calls --test skill_docs --test skill_examples --test spec_examples --test stdlib_doc_examples --test test_command --test verify --test vm_handlers --test vm_lazy --test vm_reference_cells
```

同じ指定に `--dry-run` を加えて選択を確かめた。[続行の dry-run](work-resume-dry.log)・[続行のログ](work-resume.log)・[計時](work-resume.json) を残す。続行は終了0、外側114.489秒だった。初回の成功分・失敗対象の修正後の再検査・未実行分を合わせ、全42統合対象の455成功・失敗0・ignored 10を確認した（[対象ごとの集計](integration-counts.json)）。fmt・examples を含む clippy・規約・生成物・仕様集計も通った。部分選択の終了0だけで水準全体を完了とせず、初回の割り当てのすべてがそろったことを確認した。

H は次の指定を一度実行し、終了0だった。同じ指定に `--dry-run` を加え、doc と局所 heap-verify/gc-stress の選択を確認した。[dry-run](heap-dry.log)・[ログ](heap.log)・[計時](heap.json) に残す。

```sh
/usr/bin/time -p scripts/check.sh --level work --base ddadf40d6d85b752717252c315cabe3f662c1cf8 --only doc_default,heap_local,stress_local --test runtime_builtins --test vm_handlers --test io_modes --test l32_http_client
```

H の実行中に `tests/scoped_calls.rs` を編集したが、同ファイルは H の四統合対象に含まれず、本番・doc・保持の入力も変えていないため、H の結果は有効である。

doc は通常例17成功・1 ignored と compile_fail 17成功である。heap-verify と gc-stress はそれぞれ io_modes 11・l32_http_client 9・runtime_builtins 28・vm_handlers 5 の計53成功である。

| 検査 | 終了 | 外側秒（monotonic / time real） | 補助最大常駐量の原値 bytes / MiB |
|---|---:|---:|---:|
| W-R 初回 | 1 | 363.483 / 363.47 | 2,271,674,368 / 2,166.4375 |
| W-R 修正後の続行 | 0 | 114.489 / 114.48 | 264,880,128 / 252.609375 |
| H | 0 | 139.761 / 139.75 | 3,805,659,136 / 3,629.359375 |
| 比較器の自己検査 | 0 | 99.008 / 計測なし | 2,990,702,592 / 2,852.15625 |
| 旧・新の交換八例の局所検査 | 0 | 4.517 / 計測なし | 698,269,696 / 665.921875 |

W-R と H の記録した終了は、time から直接返された check.sh 自体の終了状態である。最大常駐量は前述の補助値であり、同時使用の合計や各検査プロセスごとの詳細を表さない。比較器の自己検査は標本採取と性能の合否判定を行っていない。

## 初回の失敗と修正

- runtime の主テストは、修正前には IPv4 対象を InvalidTarget とした既存の判定で失敗し、共通代数への接続後に成功した。保存後の再検査を追加して再度成功した。ログは [修正前](runtime-before.log)・[修正後](runtime-after.log)・[再利用](runtime-reuse.log) に残す。これらの局所シェルはログ保存処理で終わるため、Cargo 自体の終了状態を別に採取していない。最終 W-R の直接終了状態とは区別する。
- 新入口の通常テストは、修正前に k1 の E0459 が出ないため失敗し、登録と引数対応の実装後に成功した。[修正前](known-before.log)・[修正後](known-after.log) を残す。
- 交換の最初の確認では、期待を `E0459` としたが、既存形式は `Some(E0459)` であり失敗した。出力の既存形式に期待を直し、旧・新の八例を通した。交換形式の実装は変えていない。[初回ログ](exchange-old.log) に残す。
- W-R 初回は363.483秒で終了1となった。`scoped_calls` の逆転ポートのテストが、狭い注釈に対して E0519 を期待していたが、追加検査が E0461 を先に報告した。既存の `typeck/scoped_calls.rs` の `accept_program` はエラーのある入力では後段の必須受理の診断を省くため、二診断は併存しない。本番のガードを変えず、リテラルの逆転は両注釈とも E0461、局所 bind に置いた未知の条件は狭い注釈なら E0519・Top なら受理、という四通りの確認へ既存テストを追随させた。先行する局所解析の独立期待値も維持した。[初回ログ](work.log) と、追随途中の併存という誤った期待の[失敗ログ](known-scoped-first.log) を残し、失敗した対象と未実行の対象だけを続行して成功した。
- 検査中のプロセス確認に使った `ps` は sandbox に拒否された。検査自体の実行には影響せず、時間と終了の記録には検査を直接待つ実行器を使った。

## 計画との差と申し送り

設計者の RV-R20 中3 の決定に従い、新しい検査二入口にも追加拒否を付けた。新四入口のうち射影二入口は追加対象の入力を持たないことを表で明示した。交換での扱いは旧の診断付き除外と同じと決め、専用の除外理由や Lean の変更を加えていない。RV-R20 中1 の受理位置も指定の 01-06 の該当段落へ反映した。

R30.2 へは、旧 Scope の正規形と新しい本体後の拒否が接続済みであることを渡す。狭い型の射影・拡大は文の始まりと bind の右辺の直接呼び出しで事実を読むという既存の制限を保つ。ハンドラの引数の扱い、六 File 操作、同じ対象の実 IO は後続の担当範囲であり、本枝で完了としない。K10 へは上の除外方針と八件の交換出力を渡す。公開契約・保証・Lean の受理を変える停止条件には該当していない。

V10 への申し送り（RV-R30.1 軽1）: `docs/reference/benitoite.md` の2510行付近と `docs/ja/reference/benitoite.md` の2374行付近は、IPv6 を拒否し、全数字の四ラベルを値の範囲によらず IPv4 の形として拒否すると記しており、IP/CIDR を受け付ける現在の旧 `checkHost`・`checkEndpoint` と食い違う。V10 で両方のホストとパターンの説明を現行実装に合わせる。本枝では両ファイルを変更していない。

比較器の基準版の展開・ビルドは既存の `target/bench/builds/` の中であり、新しい `CARGO_TARGET_DIR` は作っていない。target 外の一時ログは伏せたうえで本ディレクトリへ転記し、元を削除した。比較器の自己検査の一時ディレクトリはコンテキストの終了時に削除された。target 外に基準版の展開やビルドは残していない。

## 時間

最初の採取時計は 2026-10-29 03:58:38 UTC であり、それ以前に指定文書の読み始めがある。結果の最終確認は04:17 UTC（13:17 JST）であり、時計間は約18.4分、読み始めを含む外側所要は約20分である。親担当の能動時間は約12分という概算である。実装・文書を分担し、検査待ちと記録の執筆も重なるため、単純な差し引きでは求めていない。

主要な検査・自己検査の外側時間は W-R 363.483秒、続行114.489秒、H 139.761秒、比較器99.008秒で、合計716.741秒（約11.9分）である。これらの間にも文書と結果の確認を進めた。独立レビュー・設計者の回答待ち・性能測定の待ちはない。1〜3時間の見込みの上端の2倍には達しておらず、停止条件にも該当しない。

## R30.1b: RV-R30.1 軽1〜軽5への対応

2026-10-29。R30.1 の差分を引き継ぎ、文書コメント・設計書・テストコメント・記録だけを修正した。既存の受理・実行・保持のコード、テストの入力と期待値は変えていない。

| 指摘 | 対応と完了の根拠 |
|---|---|
| 軽1 | 「計画との差と申し送り」に V10 の修正先を英語版2510行付近・日本語版2374行付近として明記した。両リファレンスは変更していない |
| 軽2 | 02-05 の検査順6に、誤りの診断があればプログラム全体の必須の受理を行わないことを追記した。追加検査が範囲の列と理由を変えないことも同じ項目に記し、既存の accept_program と一致させた |
| 軽3 | Scope.bnt の CheckedHost・checkHost にホスト名・IP/CIDR と正規形の保存を記し、checkPathIn と Http.checkRequestIn に既知の不良を実行前に拒否する説明を加えた。無制限という記述が静的な範囲を指すことを明記した。gen_skill を実行し、Scope.md・Network.Http.md を再生成した |
| 軽4 | checked_args.rs のレビューの探査番号を引くコメントを、新旧の入口で検査する既知の不良の内容の説明へ改めた |
| 軽5 | L40.1 申し送り2の閉じ方、交換出力と最終テストの前後関係、H 実行中の scoped_calls.rs 編集が H の対象外であることを、それぞれ該当節に一行ずつ追記した |

テストの作成時の関門については、今回はコメントの一行だけの修正であり、既存の公開検査の契約・退行の検出範囲・入力・期待値を維持した。テストの追加・削除、本番 API の変更はない。R30.1b 単独の Rust の行数差は、本番0行、テストコメント1行追加・1行削除である。標準宣言二ファイルの文書コメントは計5行追加・4行削除、生成文書二ファイルも計5行追加・4行削除である。

H は R30.1 の [heap.log](heap.log)・[heap.json](heap.json) を引用する。基準は同じ B_WORK、実行日は2026-10-29、終了0、外側139.761秒で、通常の doc と compile_fail、および heap-verify/gc-stress 各53件の成功が元の結果である。R30.1b は文書コメント・生成文書・設計書・結果記録と、H の対象外である checked_args.rs のコメントだけの変更である。標準宣言は文書コメントを除いた内容が HEAD と同一であり、署名・式・保持の入力に変更はない。H の対象・道具・設定・期待値は前回のままであるため、担当が同日に引用可能と判断した。新しい H/H-full は実行していない。

レビュー記録・rv-probes の全ファイル・英語と日本語のリファレンス・HEAD・ブランチ・index を開始時のハッシュ等と照合し、変更がないことを確認した（[開始時の記録](r30.1b-protected-before.json)・[照合](r30.1b-integrity.json)）。private/ と docs/todo/ は読んでいない。新しい CARGO_TARGET_DIR、target 外の一時ビルド・展開・一時ログは作っていないため、削除対象はない。lake build・check-formal.sh・short は実行しておらず、停止条件に該当する変更もない。

### R30.1b の再検査と完了

`scripts/check.sh --level work --base ddadf40d6d85b752717252c315cabe3f662c1cf8 --dry-run` で選択と理由を確認した後、次の W-R を一度実行した。既存の run_logged.py から /usr/bin/time にスクリプトを直接渡し、check.sh 自体の終了状態を記録した。time -l は使っていない。

```sh
/usr/bin/time -p scripts/check.sh --level work --base ddadf40d6d85b752717252c315cabe3f662c1cf8
```

| 検査 | 終了 | 外側秒（monotonic / time real） | 補助最大常駐量 bytes / MiB | 根拠 |
|---|---:|---:|---:|---|
| gen_skill の再生成 | 0 | 4.516 / 計測なし | 10,928,128 / 10.421875 | [ログ](r30.1b-gen-skill.log)・[計時](r30.1b-gen-skill.json) |
| W-R の選択確認 | 0 | 0.106 / 計測なし | 補助値は計時に記録 | [dry-run](r30.1b-work-dry.log)・[計時](r30.1b-work-dry.json) |
| W-R 最終状態の全実行 | 0 | 463.869 / 463.86 | 2,448,130,048 / 2334.718750 | [ログ](r30.1b-work.log)・[計時](r30.1b-work.json) |

lib は1,391成功・失敗0・22 ignored、全42統合対象は455成功・失敗0・10 ignoredである。desugar_export の44成功・1 ignoredを含み、前回の最終的な[対象ごとの集計](integration-counts.json)と全対象・件数が一致した（[今回の集計](r30.1b-integration-counts.json)）。fmt、examples を含む clippy、規約、生成物、仕様集計も成功し、ログ末尾は selected checks passed である。途中の追加テスト実行と W-R の再実行はない。ログは記録前に手元の絶対パスを <wt>・<home> へ伏せた。最大常駐量は既存の実行器が採取した getrusage の補助値である。

完了記録を作る補助コマンドの初回は、Python の fromisoformat が末尾 Z の日時を受け付けず、ファイルに書く前に終了1となった。+00:00 に直して記録した。処理系・テスト・検査結果への影響はない。

軽1〜軽5の対応と指定の再検査は完了した。V10 の両リファレンスの修正、既存の R30.2・K10 への申し送りは残るが、R30.1b の未完作業はない。独立レビューの結論は既存の RV-R30.1 を参照し、今回の自己確認を追加の独立レビューや取りまとめの受け入れの代わりにはしない。

R30.1b の開始は2026-10-29 04:26:40 UTC、完了記録は04:37:16 UTCで、外側所要は約10.6分である。能動時間は文書・差分・記録の確認を合わせて約3分の概算、W-R の外側時間は463.869秒（約7.73分）であり、一部の記録作業と重なる。見込み30分〜1時間と2時間の停止条件には達していない。R30.1 の時間は前の「時間」節に残した。
