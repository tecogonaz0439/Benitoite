# R20.2: 成功値・射影・忘却と合流

## 状態と停止・再開

R20.2b の依頼範囲は完了した。局所解析・計時の探査・比較器の自己検査・設計書をそろえ、作業末の W-R は終了0で成功した。型制約への接続、非 Top の選択、widen、節の添字は本作業の対象外であり、四入口の型は Top のままである。取り込みの前の独立レビューと受け入れは取りまとめが行う。

| 項目 | 値 |
|---|---|
| 作業の枝 | `m013/r20.2`。git の状態を変える操作は行っていない |
| 初回の B_WORK | `09b0c228208acf4dbfadbec14f3c0fbf223f7d63` |
| 再開後の B_WORK | `7f47822970ff5c300876198282764353afdd7a75`（L40.3d の本線取り込み後。今回の W-R の基準） |
| 計時探査の開始版 | `6124775788579e60530f55fb85570f26ef7fa900` |
| 初回の停止 | Lean の `requestLitBound` は各端点だけを検査し、`443..80` の逆転区間も既知にした。Rust の整形式の範囲と入力ごとに一致せず、独立期待値の失敗を残して停止した |
| 再開の前提 | L40.3d（本線 `156acc96`）が `PortRange.WF` を要求する定義へ修正し、定理・例・独立入力・設計書を更新した。[結果](../l40.3d/results.md)と[独立レビュー](../reviews/RV-L40.3d.md)を確認した |
| 今回の対応 | 新しい `requestLitBound` の定義を根拠に、独立期待値の逆転区間の一件を未知へ戻した。Rust の解析結果から作り直していない。`checked_scope::endpoint_pattern` は変更していない |
| 停止条件 | 初回の不一致は上の Lean 修正で解消した。忘却・合流・番号・操作数を Lean と異ならせる必要、型確定後の警告への循環、契約の自動拡大はない |

初回の期待値は、最初は Rust の実行時解析器の拒否から未知とした。その後 Lean の定義との不一致に気付き、既知の逆転区間を独立期待値にして失敗を残した（[当時の再現](lean-bound-mismatch.log)）。今回は L40.3d の `if PortRange.WF then known else unknown` を読み、未知と決め直した。初回の停止と検査失敗を、今回の成功で置き換えて消していない。

## 実装と記録する事実

変更した本番コードは `crates/benitoite/src/typeck/` の五ファイルである。`scope/lower.rs` が局所解析の辿る部分を番号のない命令列へ写し、`scope/local.rs` が局所状態・記録・抽象の引数を作る。`scope/input.rs` は元の構造と定数の共有を保ち、呼び出しの引数と定数の直接参照の形を保存する。`scope/mod.rs` と `typeck/mod.rs` は解析の公開入口と結果の型を再エクスポートする。`scope/local_tests.rs` が通常ソースから独立期待値と照合する。

`ScopeBodyInput::analyze(numbering_operations, limits)` は `numbered()` を一度使う。出現番号を数え直さず、入口の位置の列も重ねて逆順にしない。`contains_rules()` と番号付けの停止を区別する。局所位置は変更しない節点として同じ arena に保存し、各記録は先頭位置を共有する。参照は添字であり、深い位置の列の破棄で再帰しない。忘却では位置と番号を残す。

| 対象・境界 | 記録・忘却 |
|---|---|
| 標準の直接の `Scope.checkPathIn` / `Http.checkRequestIn` を一度保存した Result | 検査の出現の鍵・対象の種類・読めた条件を保存する。実際に Ok が返ることは仮定しない |
| 局所の Result の単独の選択肢 `Result.Ok(p)` | Result の由来を写し、新しい位置の番号を成功値番号にする |
| Error の腕・ほかのパターン・複数選択肢 | 束縛する位置を未知として追加する。成功値の事実を作らない |
| 同じ成功値への直接の射影 | 呼び出し自身の番号の記録から、局所位置と成功値番号を保った引数として読む。射影の結果に事実を作らない（`projectRule.transfer = none`） |
| 別の検査の成功値 | その検査の鍵・条件を持つ。外側の由来を写さない |
| 引数として受け取った別個体 | 入口の事実はない |
| Result・成功値の別名、再包装、未知の呼び出しの結果 | 新しい位置に事実を作らない。外側の既存の事実は残す |
| `try e` の結果 | 未知。内側の文の記録も作らない |
| lambda・lazy・handle の保護本体と通常の節・失敗の節、Task の action の lambda | 入口で外側の位置を保って事実を消す。引数・辞書・継続の位置を必要な順で追加する。通常の出口は外側の状態へ戻る |
| pipe・binary・list・record・interpolation・conCall・try・resume などの内側 | 文の記録も transfer の結果も置かない。規則の出現は呼び出し一覧に残し、引数は `factFree` 相当で読む |
| 旧 Scope の入口・同名の利用者関数・間接呼び出し・穴 | R20.1 の同定を保ち、新規則を与えない |

合流では外側の状態を復元し、外側の Result と成功値の事実を残す。合流した値を新しい位置へ束縛するときは事実を付けない。`RangeState` 全体と区間解析の合流は使わない。README の確認点 (8)・(11) に従う。

R20.1 の[再確認の末尾](../reviews/RV-R20.1.md#r201b-の再確認2026-10-29取りまとめの依頼)の申し送りは、今回の修正で満たした。`lower.rs` は元からパイプの中を辿らず、パイプの右辺の保存を未知にする。一方、初回の `local.rs` は最後の呼び出し一覧で無記録の出現にも transfer を作っていた。これを、その番号に記録がある出現だけに限った。パイプの両辺と、パイプの結果を保存して Ok を照合する例を既存テストへ加え、修正前の失敗と修正後の成功を残した。無記録の出現に外側の文の状態を代用しない。

`factFree` は局所の事実を持たない状態である。リテラル条件は読み取れるので、パイプ左辺の通常の検査まで一律 Top とはしない。パイプ右辺の `PipeLeft` は未知であり、Lean の `acceptCall … []` に対応する Top 要求を R20.3 で接続する。今回の `ScopeCallFacts.result = None` は transfer がないことを表し、受理の index が常に未知であるという意味ではない。

局所解析の上限は `ScopeLimits` の本体・全体、操作数・保持数として明示する。採用値・既定値は置かない。`stepCost`・`Budget.admit`・`Run.enter/leave`・`rejoin` に合わせ、超過では候補の状態を採用せず、位置を保って事実を忘れる。番号付けが停止した場合は接頭辞から局所の事実を作らない。局所テストは Result 保存3操作・Ok2操作・射影結果保存3操作・別名1操作と保持数0/1/2を独立に指定する。長い入力の Q と採用値の測定は R20.5 が担当する。

再開時の点検では、`direct_head` が組み込みの操作を除外しており、保存した `File.readText(path: path)` の費用を数えない差を再現した。登録済みの操作は交換器で `primName` に写り、Lean の `directHead = true` となる。`resolved.builtin_ops` の登録がある頭を計上対象へ加えた。利用者の操作（`opName`）は除外したままである。Result 保存3と直接呼び出しの同定1・局所読取り1に対し、上限4で組み込みだけが超過し、利用者の操作では外側の事実を保つことを通常ソースで確認した。Lean の規則や計上単位は変更していない。

## 定数・Lean との対応・L40.3d の5項目

条件の読み取りは文字列・Integer のリテラル、負の Integer のリテラル、既存 const の直接参照の鎖だけである。括弧、一般の局所の定数伝播、定数の算術や連結、任意の純粋関数の評価、保存した射影結果の再利用は加えない。整数は `ScopeArgument::Integer(i64)` として保持し、U+0000 の文字列へ符号化しない。パスは `PathPattern::parse`、ホストとポートは R10 の代数を使う `checked_scope::endpoint_pattern` で読む。

| L40.3d の申し送り | 今回の確認と後続 |
|---|---|
| 1. 逆転したリテラルは未知 | `checks_read_only_literals_and_direct_const_chains_with_typed_integers` の `443,80` の独立期待値を、新しい `requestLitBound` の `PortRange.WF` 分岐から未知に戻した。Rust の解析結果から再生成していない |
| 2. 等しい組・正しい順は既知、それ以外は未知 | 表へ `443,443` と `80,443` を加え、既存の `0,65535` とともに既知を確認した。負の端点・65536・非リテラルの局所値・演算した const は未知。文字列ポートは通常の型検査が拒否し、収集済み入力でも文字列のまま未知にすることを同じテストで確かめた |
| 3. 狭い契約の拒否は `unknownSource` | 逆転区間の通常ソースは現在の型検査を通り、局所結果は未知である。旧 Scope に対する E0461 を新入口へ先に出してはいない。狭い契約の受理・拒否の実装と理由の照合は R20.3・K10 が担当する。今回の成功をその接続の検査とはしない |
| 4. 交換へ逆転区間を書かない | 静的に既知となる範囲は共通の整形式の代数から得る。逆転した範囲を作る処理や交換への出力を追加していない。範囲の列と `scopeAcceptance` の本番の書き出し・全比較は R20.3・K10 で閉じる |
| 5. 実行時の δ の失敗との対応 | 実行時の `endpoint_pattern` と失敗の分類は変更していない。Lean の抽象の `Err(scopeFailure)` と Rust の `InvalidBounds` 等の対応は K10 が担当する |

独立期待値の出どころは、`ScopeLower.lean` の `constArg?`・`argForm`・`rhsStep`・`armEntry`・`analyzeExpr`・`analyzeBlock`・`analyzeArms`・`analyzeClauses`・`rejoin` と、`ScopeState.lean` の `pathCheck`・新しい `requestLitBound`・`projectRule`・`absStep`・`stepCost`・`Run.enter/leave` である。番号 `[0,4,6,11,14]`、成功値の位置 `[2,1,0]`、射影の由来の有無の列、条件の表示、予算の境界は規則から手で定めた。期待値を対象の実装で再生成していない。

L50.4 の「R 段が合わせるべき点」4と R20.1 の申し送りも照合した。意味のソースを読んだ範囲の局所照合であり、Lean の実行・Rust と Lean の全比較は行っていない。U+0000 の文字列を整数にする表現上の差は本番へ持ち込まない。

## 計時の探査と設計書

計時の探査は開始版・新 B_WORK・作業版の3状態でビルドできた（[コマンド・API 判定・ハッシュ](r20.2b-probes.json)）。既存の `build.py::probe_api` の `--cfg` の方式で対応でき、`tools/bench/compare/` の変更は不要だった。開始版は既存の release ライブラリを使い、新 B_WORK は一時の `git archive` のソースから既存の `target/` を指定して lib をビルドした。作業版は現ソースを再コンパイルした。実際の性能比較は行っていない。

最初の作業版の lib ビルドは約0.163秒で終了し、基準版とライブラリのハッシュが同じだった。共有 target の既存成果物の再利用が残ったため、この最初の成功を作業版の証拠から外した（[除外した記録](r20.2b-probe-initial-current-rejected.json)）。一時の基準ソースを削除した後、`cargo rustc … -- --emit=dep-info,metadata,link` で作業版を再コンパイルした。さらに新しい `ScopeAnalysis` の公開型を参照する小さいクレートをリンクし、作業版の API が使えることを確認してから計時探査をビルドし直した。最終 JSON の current はこの再確認の結果である。

| 探査 | 終了 | 外側の時間 | 記録 |
|---|---:|---:|---|
| 開始版の計時探査 | 0 | 2.461秒 | [ログ](r20.2b-probe-start.log) |
| 新 B_WORK の lib / 計時探査 | 0 / 0 | 33.180 / 2.207秒 | [lib](r20.2b-probe-base-library.log)・[探査](r20.2b-probe-base.log) |
| 作業版の lib / API 参照 / 計時探査 | 0 / 0 / 0 | 28.243 / 0.508 / 1.470秒 | [lib](r20.2b-probe-current-library.log)・[API](r20.2b-probe-current-api.log)・[探査](r20.2b-probe-current.log) |
| 比較器 README の自己検査 | 0、39件成功 | 95.236秒 | [ログ](r20.2b-compare-selftest.log)・[計時](r20.2b-compare-selftest.json) |

自己検査のコマンドは README と同じ `PYTHONPYCACHEPREFIX=target/bench/pycache python3 -m unittest discover -s tools/bench/compare -p 'test_*.py'` である。自己検査は実際の基準版のビルドも内部で行った。自己検査の模擬入力の実行を short の性能比較と数えない。

設計書は次の4章だけを更新した。見出し・`text` のコードブロック・Lean の規範は変えていない。

- 01-06: 検査条件と成功値の由来にかかわらず、現在の四入口の型は Top であることを明確にした。
- 02-05: 解析入口、記録する事実・忘却・合流・const・型付き整数・パイプ・予算・番号停止を反映した。
- 01-12: 局所解析の表層からの対応に、実装済みの Rust の範囲を反映した。
- 07-04: ScopeState・ScopeLower の対応表を更新した。型への接続と全比較は未完という限定を保った。

## 初回の失敗と検査（再開前）

以下は旧 B_WORK での記録であり、今回の最終状態の成功の根拠にはしない。初回の完全なコンパイル失敗ログは残せておらず、`NodeMap` の `FromIterator` 不在と未使用の再エクスポートで失敗した事実だけを残す。疎な表を `BTreeMap` にし、公開入口へ再エクスポートして直した。

| 記録 | 結果 |
|---|---|
| [local-compile.json](local-compile.json) | `typeck::scope::tests --no-run`、終了0、29.546秒 |
| [local-01.json](local-01.json) | 局所フィルタ、終了101、18.103秒、1成功・3失敗。テストの名前付き引数不足と再包装 Result の Error 腕不足 |
| [local-02.json](local-02.json) | 終了101、13.811秒、6成功・1失敗。Failure の import 不足 |
| [local-03.json](local-03.json) | 終了0、13.779秒、8成功。この時点の逆転区間の期待値は Lean と独立に一致していなかった |
| [local-04.json](local-04.json) | Scope 全体、終了0、19.960秒、16成功。同じ期待値の問題が残った |
| [lean-bound-mismatch.json](lean-bound-mismatch.json) | 逆転区間の独立期待値で終了101、9.740秒。停止の根拠 |
| [work.json](work.json) | 旧基準の W-R。check.sh 自身の終了1、real 16.46秒、user 34.15秒、sys 11.22秒。fmt 成功後に clippy が新テストのワイルドカード match を拒否した。後続は未実行 |
| [lint-retry.json](lint-retry.json) | 明示列挙へ直し、同じ既定 clippy を直接再実行。終了0、8.647秒 |

旧 W-R の直接の終了は [work-command.status](work-command.status)、dry-run は [work-dry-run.log](work-dry-run.log) にある。基準は `09b0c228208acf4dbfadbec14f3c0fbf223f7d63` だった。RSS の補助値は 2,473,918,464バイト = 2,359.3125 MiB、clippy 再検査は 2,483,191,808バイト = 2,368.15625 MiB である。

## 再開後の検査

テストの作成時の関門に従い、通常ソースを読み込み・名前解決・型検査した後の公開の `ScopeBodyInput::analyze` の結果を確かめた。守る契約は事実・忘却・記録位置・操作数である。パイプ等への無記録 transfer、別名・合流値への由来の伝播、境界の捕捉、組み込み操作の計上漏れを捕まえる。番号だけを検査する R20.1 や、合流規則の異なる区間解析のテストでは捕まらない。既存の表とテストを広げ、操作数の区別だけ一件を追加した。テストのための本番の差し込み口と、本番の lint 免除は追加していない。既存テストの削除はない。

| 記録 | 対象・結果 |
|---|---|
| [r20.2b-pipe-before.json](r20.2b-pipe-before.json) | `cargo test -p benitoite --lib typeck::scope::local_tests::try_direct_match_wrapping_and_unvisited_expressions_do_not_gain_facts -- --nocapture`。終了101、15.334秒。無記録の呼び出しに transfer が残る失敗を再現 |
| [r20.2b-local.json](r20.2b-local.json) | `cargo test -p benitoite --lib typeck::scope:: -- --nocapture`。修正後に終了0、29.435秒、16件成功。逆転・等しい組・正しい順を含む |
| [r20.2b-string-port.json](r20.2b-string-port.json) | 定数と型付き整数のテスト。文字列ポートの例を追加後、終了0、12.176秒 |
| [r20.2b-operation-before.json](r20.2b-operation-before.json) | 操作数の追加テストの初回、終了101、13.660秒。テストの import の位置とモジュール名を誤った |
| [r20.2b-operation-before-02.json](r20.2b-operation-before-02.json) | 終了101、5.362秒。効果名を import 後の `File.Read` とする必要があった |
| [r20.2b-operation-before-03.json](r20.2b-operation-before-03.json) | 通常ソースを直した後、終了101、5.532秒。組み込みの直接呼び出しの操作数が不足して上限4で止まらない差を再現 |
| [r20.2b-operation-after.json](r20.2b-operation-after.json) | 登録済み操作を計上した後、終了0、10.657秒。組み込みと利用者の操作の区別を確認 |

作業末の選択は、指定された同じ基準の dry-run で確認した。終了0、外側0.150秒（[選択](r20.2b-work-dry-run.log)）。fmt、examples を含む既定 clippy、既定 lib 全件、全統合ターゲット、ソース規約、Skill 生成物の照合、仕様被覆の自己検査と集計が選ばれた。仕様例は全統合に含まれる。Lean ビルドは選ばれていない。

```sh
scripts/check.sh --level work --base 7f47822970ff5c300876198282764353afdd7a75 --dry-run
/usr/bin/time -p /bin/sh -c 'scripts/check.sh --level work --base 7f47822970ff5c300876198282764353afdd7a75; check_status=$?; printf "%s\n" "$check_status" > docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/r20.2/r20.2b-work-command.status; exit "$check_status"'
```

W-R は一度実行し、**check.sh 自身の終了0、外側の real 484.25秒（約8分4秒）**だった。user 1514.40秒、sys 59.11秒。Python の外側の補助計時は484.260秒である（[check.sh の直接の終了](r20.2b-work-command.status)・[全ログ](r20.2b-work.log)・[計時](r20.2b-work.json)）。fmt、既定 clippy、既定 lib、全統合、ソース規約、Skill 生成物、仕様被覆の全選択が成功した。lib は1,377件成功・21件 ignored、統合は41ターゲット・427件成功・10件 ignored。失敗は0件で、ignore・除外・時間制限を変更していない。仕様例の7件も成功した。被覆集計の参照のない節の一覧は情報表示であり、完了条件の未記入は none だった。

最大常駐量の補助値は **4,473,536,512バイト = 4,266.296875 MiB = 約4.1663 GiB** である。初回の失敗した W-R と混ぜず、今回の実行の値として記録した。

最大常駐量は macOS の Python `resource.getrusage(RUSAGE_CHILDREN).ru_maxrss` の補助値である。子孫のうち最大の一プロセスの値であり、同時常駐量の合計ではない。`/usr/bin/time -p` が出した RSS とは称さない。`time -l` は使っていない。ログと JSON の手元の絶対パスは記録前に伏せた。

## 計画との差と R20.3 への申し送り

計画との差は、初回の Lean との意味の不一致による停止と、L40.3d を受けた今回の再開である。再開時にはパイプの無記録 transfer と既存組み込み操作の計上漏れも直した。いずれも Lean の現行規則へ合わせる修正であり、保証・計上単位を変えていない。最終状態のファイルと SHA-256 は [r20.2b-state.json](r20.2b-state.json) に残した。本番のコードは1,058行追加・10行削除、テストは700行追加・削除なしである。R20.2 の未コミット差分全体の量であり、今回の再開だけの増減ではない。

| 後続 | 申し送り |
|---|---|
| R20.3 | `contains_rules()` で対象の本体を選び、番号付けの上限を必ず渡して本体ごとに一度解析する。`ScopeAnalysis.stopped`・`input.stopped` を規則なしと読み替えない |
| R20.3 | 番号付けが停止すると `input.calls` は接頭辞となり、最後の引数番号も欠け得る。`ScopeAnalysis.calls` も完全一覧ではない。番号に依存しない全規則呼び出し一覧を用意し、予算停止では後続を含む全件へ Top を要求して `budgetExceeded` とする（RV-R20.1 末尾の中の問題）。深さ・MissingInput 等も停止理由に応じて処理し、黙って受理しない |
| R20.3 | パイプの中は transfer なし・記録なし。受理の index は `factFree` で計算し、`ScopeCallFacts.result` で代用しない。パイプ右辺の `PipeLeft` は Lean の `acceptCall … []` に当たる Top 要求とする |
| R20.3 | 四入口の型制約と非 Top の選択、二つの widen、範囲の列と実際の受理を接続する。逆転区間は未知からの狭い契約の拒否で `unknownSource` とし、旧 Scope の E0461 と混同しない。期待型の注釈だけから由来を作らない |
| R20.3 | 新テストの裸の `Scope.PathIn` / `Http.RequestIn` は `local_tests.rs` の `other` 引数各1箇所。いずれも別個体が未知であることを検査する目的であり、非 Top の接続時に型を見直す |
| R20.5 | 明示的な局所・全体上限の値と番号付けの暫定10万操作を、Q の測定で確定する。今回の小さい境界検査を採用値の測定としない |
| K10 | U+0000 の整数表現の差、整形式の範囲だけの書き出し、実行時の抽象の失敗との対応、非 Top を含む交換の全比較を閉じる |
| 取りまとめ | R20.2 の独立レビューと受け入れ、必要な追随、段末の検査と実装取り込み後の short を行う。本記録の自己確認を独立レビューの代わりにしない |

ヒープの確保器・根・障壁・安全点・言語の値の保持は変更していない。H/H-full を追加する変更ではない。Lean・scripts・依存は変更していない。本線へ書かず、private とそこを指すスキル、docs/todo は読んでいない。`lake build`・`check-formal.sh`・short の性能比較は実行していない。新しい `CARGO_TARGET_DIR` は設定していない。

一時の探査ソース・API 確認用クレート・探査バイナリと基準ソースの展開先 `target/r20.2b-probe/` は削除した。自己検査が今回作った `target/bench/builds/7f47822970ff5c300876198282764353afdd7a75-default/` も削除した。開始時からあった比較器のキャッシュは保った。target 外の一時の探査台本も削除した。コマンドの記録用の補助台本 `run.py` も削除した。再現に要るコマンド・引数・結果は JSON と本書に残した。手元の絶対パスがないこと、`git diff --check` の成功、index が空であることを最終点検した。

## 所要時間

初回は 2026-10-29 04:31〜04:52 JST 頃、外側約21分、能動時間の概算17〜19分だった。再開は 2026-10-29 05:15 JST 頃である。今回の外側の時間には W-R を含む。局所検査・探査・自己検査の待ちと記録の作成は一部並行したため、各ログの時間の和を所要時間とはしない。

再開後の終了は05:31 JST 頃、外側の所要は約16分である。能動時間は精密には測っておらず概算10〜12分。W-R の待ちは484.25秒、ほかの検査と探査の時間は上の各記録に分けた。回答待ちはなく、見込み上端の2倍（4時間）には達していない。初回を含めた外側の作業時間は、停止していた期間を除き約37分である。
