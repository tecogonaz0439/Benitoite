# L33 ネットワークのテストと、OPEN-062 の R14・R04 の HTTP の分

- 依存する作業: [L31](L31-http-serve-and-helpers.md)、[L32](L32-http-client.md)、[C10](C10-golden-runner.md)、[R30](R30-open-062-reproduction.md)
- 難易度: 3（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行）
- ブランチ: impl/L33-network-tests

## 目的

ネットワークのモジュールのテストを三つの形で書く。

1. `network` の区分のゴールデンテスト: 一つのスクリプトがループバックで待ち受け、同じスクリプトからクライアントとして接続する（[ADR 0222](../../2026-10-09-design-first-release/decisions/0222-http-tests-over-loopback.md)、07-03「HTTP のテスト（初回リリース版）」）。
2. ネットワークの失敗の注入のテスト: ループバックでは起こしにくい失敗（名前の解決の失敗、接続の拒否、接続のリセット、時間切れ）を、Rust のテストから、テスト用のハンドラ表（10-16 の `NetworkFaults`）を入れた差し替えの部品（`RuntimeParts`）を `CliEnv::parts`・`RunEnv::parts` で渡して起こす（[ADR 0287](../../2026-10-09-design-first-release/decisions/0287-stdlib-details-decided-in-u3-plan.md) の決定 3）。ゴールデンテストの形式は広げない。
3. OPEN-062 の再現テスト: R14（HTTP のクエリとヘッダが UTF-8 でないときの扱い）と、R30 が U3 の後に回した R04 の HTTP の受け付けの確かめ（[R30](R30-open-062-reproduction.md) の表の R04 の行）。R30 と同じ手順で書き、再現したら直さずに報告する（ADR 0270 の決定 2、README の「U3・U4 で決めたこと」の 10）。

依存の理由（R30）: R04 の HTTP の分は、R30 が `tests/open_062.rs` に置いた補助（標準出力を止める助けのスレッドなど）と同じ形で書く。

注記（オーケストレータへ）: 本作業のテストはループバックで待ち受けと接続を行うので、Codex はネットワーク（ループバックのソケット）を使える設定で起動する。

## 読む設計書の節

- [処理系のテスト戦略](../../2026-10-09-design-first-release/07-quality/07-03-compiler-testing.md)の「ゴールデンテスト」（区分 `network`、`concurrency` と `network` のスクリプトの書き方）、「HTTP のテスト（初回リリース版）」、「順序を与えるスケジューラと仮想の時間（初回リリース版）」、「テストの設計の原則」
- [ネットワークのモジュール](../../2026-10-09-design-first-release/03-interop/03-09-network.md)の全体
- [未決・要検証事項](../../2026-10-09-design-first-release/open-issues.md#open-062)の OPEN-062（R04・R14 の行と、2026-09-30 の段落）
- [ランタイム](../../2026-10-09-design-first-release/02-impl/02-09-runtime.md)の「組み込みの操作とハンドラ表」（テスト用のハンドラ表）
- ADR: [0222](../../2026-10-09-design-first-release/decisions/0222-http-tests-over-loopback.md)、[0224](../../2026-10-09-design-first-release/decisions/0224-golden-test-format-for-first-release.md)、[0270](../../2026-10-09-design-first-release/decisions/0270-open-062-items-in-runtime-rebuild.md)、[0274](../../2026-10-09-design-first-release/decisions/0274-deterministic-scheduler-and-virtual-time-for-tests.md)、[0287](../../2026-10-09-design-first-release/decisions/0287-stdlib-details-decided-in-u3-plan.md)、[0291](../../2026-10-09-design-first-release/decisions/0291-file-copy-limit-and-http-server-details.md)、[0322](../../2026-10-09-design-first-release/decisions/0322-stdlib-details-from-u3-preflight.md) の決定 4、[0330](../../2026-10-09-design-first-release/decisions/0330-http-details-from-u3-preflight.md) の決定 1（クエリの細部）、[0331](../../2026-10-09-design-first-release/decisions/0331-invalid-http-header-characters-stop.md)（ヘッダの正しくない文字）

インターフェース:

- [IO とネットワークの追加](../10-interfaces/10-16-io-and-network-additions.md)の「テスト用のハンドラ表のネットワークの失敗」、「HTTP のサーバの接続の層」の「実装プランで決める値」（文字列にできない要求）
- [パイプラインと CLI](../10-interfaces/10-13-pipeline-and-cli.md)の `CliEnv`・`RunEnv`（`parts`）、「テストの実行器とゴールデンテストの実行器が使う口」
- [スケジューラと IO 実行器](../10-interfaces/10-10-scheduler-and-io.md)の「テストで差し替える部品」と R25 の `sched::testing`
- R30 の作業の文書（書き方、再現したとき、再現しなかったとき）

## 作るもの

- `crates/benitoite/testdata/network/` のゴールデンテスト（C10 の実行器の形式。ADR 0224）
- `tests/network_faults.rs`: 失敗の注入のテスト
- `tests/open_062_http.rs`: R14 と R04 の HTTP の分の再現テスト（R30 の `tests/open_062.rs` と同じ書き方）

処理系のコード（`src/`）は変えない。変える必要が生じたら、それは再現した項目の直しか、U3 の作業の不具合であり、本作業の範囲の外である（完了の報告に書いて止める）。

## 手順の要点

### ゴールデンテスト

- スクリプトは `Http.listen("127.0.0.1", 0)` で待ち受け、`Http.listenerPort` でポートを知り、サーバをタスクで動かして、同じスクリプトから `Http.get`・`Http.send` で接続する（07-03）。ループバックのアドレスにだけ接続する。
- 出力の順序がタスクを切り替える時機によらないように書く（`Task.all` の結果を受け取ってから書くなど。07-03「ゴールデンテスト」）。
- 扱う場合: `Http.serve` の形のサーバと経路の振り分け、`Http.text`・`html`・`json`、`Http.header`・`pathSegments`、`POST` の本体、4xx・5xx の応答が `Result.Ok` になること、`with` の `Exchange` を応答せずに抜けたときの 500、`respond` の二度目の実行時エラー、`status` の範囲の実行時エラー、リダイレクト、使われているポートの `AddressInUse`。
- スクリプトの中だけでは `Http.serve` が待ち受けるポートを知れない（`Http.serve` は待ち受けの値を返さない）ので、ゴールデンテストのサーバは、`Http.listen` と `Http.listenerPort` で待ち受けてポートを知り、`Http.accept` と経路の振り分けで `Http.serve` と同じ形のループを自分で書く。`AddressInUse` の場合だけは、先に `Http.listen` で取ったポートに `Http.serve` を呼べば `Result.Error` が返るので、`Http.serve` のまま書ける。
- `Http.serve` に固有の場合（`handler` の実行時エラーで全体が止まること、引き継いだハンドラの節の誤り）は、ゴールデンテストに入れない。L31 の Rust のテスト（`tests/l31_http_serve_and_helpers.rs` の `handler_runtime_error_and_non_tail_inherited_clause_stop_every_task`。末尾で再開する引き継ぎの節は `serve_inherits_tail_resuming_handler`）が確かめている。
- ヘッダの名前が token の文字以外を含むときと、値が制御文字（水平タブを除く 0x00〜0x1F と 0x7F）を含むときの実行時エラー（`Http.respond` の応答と `Http.send` の要求。ADR 0331 の決定 1、ADR 0333 の決定 3）も、ゴールデンテストの候補である（必須ではない）。
- 時間切れのように実時間に依存する場合はゴールデンテストに入れず、失敗の注入のテストで扱う。
- スクリプトでは、非公式のモジュールを取り込みの名前で取り込む（`import Benitoite.Unofficial.Network.Http`・`import Benitoite.Unofficial.Json`。[ADR 0286](../../2026-10-09-design-first-release/decisions/0286-unofficial-modules-imported-under-unofficial.md) の決定 3）。03-09 の例の `import Benitoite.Network.Http` の形をそのまま写すと、E0321 になる。
- 期待する結果は設計書から決め、実際の結果と比べる（C11・C12 と同じ規則）。実際の結果が設計書と食い違うときは、期待値を実際の結果に合わせない（書き直しの指定 `BENITOITE_BLESS` で作った期待値は、設計書と照らしてから残す）。食い違ったテストは `testdata/` に置かず、スクリプトと、設計書から決めた期待値と、実際の結果と、設計書の節を、完了の報告に添える。`tests/golden.rs` の CLI の外の検査（`run` のケースの VM と参照インタプリタの比較、直接呼び出しと要求と応答の比較など）だけで落ちるケースも、処理系の不具合として同じく `testdata/` に置かずに報告する。ただし、`testdata/network/` の下の `run` のケースは、VM と参照インタプリタの比較から外す（本作業に限り許す。オーケストレータの判断）。参照インタプリタは実行時の状態の窓（`runtime_view`）を持たないので、`Http.listen` が `Stop::Internal` になり、比較が必ず落ちる。また、02-06「参照インタプリタの範囲」はタスクを使うプログラムを差分テストの対象の外とし、ネットワークのスクリプトはどれもサーバをタスクで動かす。外し方は、既存の `stdin` などの除外と同じにする。`tests/golden.rs` の `run` のケースの比較の前で理由を選ぶ箇所（`case.stdin.is_some()` なら `"stdin"`、`NONDETERMINISTIC_CASES` なら `"clock/random"`、`EXPENSIVE_REFERENCE_CASES` なら `"reference list conversion cost"` を選ぶ `if` の連なり）に、名前（`testdata/network/….bnt` の形の相対パス）が `testdata/network/` で始まるときに理由 `"network (tasks and runtime view)"` を選ぶ枝を一つ足す。理由を選んだケースは、既存の除外と同じく `validate_core(program, Comparison::Excluded(reason.into()))` で脱糖とコア IR の検査だけを行い、`Summary::record` が理由ごとに数え、最後に `differential excluded: <理由>: <数>` の行で示す。CLI の二つの IO の方式の検査と期待値との比較は、そのまま行う。これ以外の除外の表や理由を `tests/golden.rs` に足さない。`NONDETERMINISTIC_CASES` に名前を足すことも、本作業では行わない（足してよいのは L40 だけである）。結果が揺れるケースは、揺れないように書き直す。

### 失敗の注入のテスト

- 失敗を当てる場合は、R25 の `sched::testing` の部品（`ScheduleHandle::parts`）を作り、`network_faults` に名前と失敗の組を入れる。失敗を当てる関数は作業用のスレッドへ仕事を出さないので、筋書きなしに決まった結果になる（10-16）。
- 失敗を当てない接続（ループバックのサーバに実際に届くもの）は、テスト用の部品にはイベントループがなく準備の待ちを扱えない（L30 の登録が `Stop::Internal` になる）ので、本物の部品を `RuntimeParts::real_with_poll(network_faults)`（L30 が加えた。10-16「本物の部品とイベントループを使うテストの口」）で作って動かす。
- 部品は `RunEnv::parts`（`run_program` を直接呼ぶ）か `CliEnv::parts`（`cli::execute` を呼ぶ）で渡す。両方の口を少なくとも一度ずつ使う。
- 四つの種類それぞれについて、`Http.get` と `Http.send` が、その種類の `NetworkError` の `Result.Error` を返し、`NetworkError.kind` で種類を読める。大文字と小文字の違う名前にも当たる。
- `Http.listen`（と `Http.serve`）に `HostNotFound` を当てると、待ち受けを始めずに `Result.Error` を返す。
- 失敗を当てない名前への接続は、本番と同じく実際に行われる（ループバックのサーバに届く）。この場合は `real_with_poll` の部品を使う。

### OPEN-062 の再現テスト

R30 の「書き方」「再現したとき」「再現しなかったとき」をそのまま使う。項目ごとに一つのテストの関数を置き、名前に項目の番号を入れ、先頭のコメントに OPEN-062 の反例の文と、成り立つべき性質を書く。IO の二つの方式で実行する。

| 項目 | テストの内容 | 成り立つべき性質（OPEN-062 の「再現したときの修正の候補」から） |
|---|---|---|
| R14（クエリ） | ループバックのサーバに、`?q=%FF`（戻すと正しい UTF-8 にならない）と `?q=%G0`（`%` の後が 16 進でない）のクエリを持つ要求を、テストの中の `TcpStream` で送る | `?q=%FF` の要求に処理系が状態コード 400 を返し、同じ `Http.accept` が次の要求を受け付け続ける（03-09「サーバの接続と要求の読み方」、ADR 0291。OPEN-062 の R14 のクエリの項目はこの規則で決着した。ADR 0322 の決定 4）。`?q=%G0` の要求は 400 にならず、ハンドラに `query` が `[Pair("q", "%G0")]` として届く（戻せない符号化は受け取った字面のまま残す。03-09「要求と応答の型」の `query` の箇条、ADR 0330 の決定 1） |
| R14（受信のヘッダ、サーバ） | UTF-8 でないバイトを値に含むヘッダを持つ要求を送る | 処理系が状態コード 400 を返す |
| R14（受信のヘッダ、クライアント） | テストの中の `TcpListener` が、UTF-8 でないヘッダの値を持つ応答を返し、スクリプトが `Http.get` で受け取る | `Http.get` が `NetworkErrorKind.InvalidHTTPData` の `Result.Error` を返す |
| R04（HTTP の受け付け） | 標準出力を止めておける出力先（R30 の R04 と同じ形）にし、あるタスクが容量の上限を超えて書き続けて止まっている間に、ほかのタスクが `Http.accept` で待つ。テストの中の `TcpStream` から要求を送る | 標準出力が詰まっている間も、要求が受け付けられ、応答が返る |

- R14 のサーバの行と R04 は、本物の部品を `RuntimeParts::real_with_poll(NetworkFaults::default())` で作り、`RunEnv::parts` に入れて動かす。筋書きの部品（`ScheduleHandle::parts`）には `mio::Registry` を持つ起こし口がないので、`Http.accept` の準備の待ちの登録が `Stop::Internal` になる（10-16「準備の知らせを届ける経路」の手順 5）。
- R04 では、R30 の R04 のテスト（`tests/open_062.rs` の `open_062_r04_blocked_stdout_does_not_block_timers_stderr_or_interrupts`）と同じく、助けのスレッドが標準出力の `OutputTarget::Capture` の `Mutex` を握って書き込みを止める。そのため、スクリプトはポートを標準出力に書けない。ポートは標準エラー出力（別の `Capture`）に書き、テストはそこからポートを読んでから `TcpStream` で接続する。
- 観測には、R30 の補助のうち、停止の検出だけに上限の時間を使う `bounded` と、`Mutex` を握る助けのスレッドの形（R04 のテストの中の `gate`）を使う。本物の部品では仮想の時間が進まないので、R30 の R04 のような仮想の時間の筋書き（`ScheduleStep::Advance` など）には頼らない。

- L30 は、UTF-8 でない要求（パーセント符号化を戻すと正しい UTF-8 にならないクエリを含む）を HTTP として正しくない要求として 400 を返す（03-09「サーバの接続と要求の読み方」の【方針】、ADR 0291）。L32 は、UTF-8 でないヘッダの値を持つ応答を HTTP として読めないものとして扱う（10-16「実装プランで決める値」、L32 の作業の文書）。R14 のクエリの行は、OPEN-062 の当初の修正の候補（受け取ったままにする）ではなく、ADR 0322 の決定 4 で決めた 400 を成り立つべき性質とする。したがって、L30 の規則どおりなら R14 の三つの行はどれも通り、統合用のブランチの `scripts/check.sh` は R14 のために落ちない。通らなければ、再現した項目として扱う（下の箇条）。
- 再現した項目のテストに `#[ignore]` を付けない。表明を反転しない。期待値を今の振る舞いに合わせない（R30 と同じ）。
- 再現しなかった項目は、理由（どの規則がどの順序で防いだか）を完了の報告に書き、回帰のテストとして残す。オーケストレータが OPEN-062 に記録する。

## 受け入れテスト

- 上のゴールデンテストの各場合がある。C10 の実行器で、回収の強制で通る。
- 失敗の注入の四つの種類と、`RunEnv::parts`・`CliEnv::parts` の両方の口のテストがある。
- R14 の三つの行と R04 の HTTP の行のテストがあり、IO の二つの方式で実行する。

## 完了条件

- 再現した項目がなければ、`scripts/check.sh` が通る
- 再現した項目があれば、そのテストだけが失敗し、完了の報告にその項目・観測した結果・OPEN-062 の修正の候補が書かれている
- `src/` を変えていない
- ゴールデンテストの形式（ADR 0224）を広げていない
- `tests/golden.rs` の変更が、`testdata/network/` の下を理由 `"network (tasks and runtime view)"` で差分検査から外す枝の追加だけである

## 確認の観点

- 各再現テストが、OPEN-062 の反例の文をそのまま形にしているか。反例より弱い形に変えていないか。
- 再現した項目を、テストを弱めて通していないか。
- ゴールデンテストの出力が、タスクの切り替えの時機によらないか。外部のネットワークに出ていないか。
- 失敗の注入のテストが、実際の失敗（本当の名前の解決の失敗など）に頼っていないか。

## 難易度の理由

仕組みはすべて揃っており、書くのはテストだけであるが、ループバックの通信をタスクの切り替えの時機によらない形で書くこと、再現テストを OPEN-062 の文に正確に合わせることが要る。
