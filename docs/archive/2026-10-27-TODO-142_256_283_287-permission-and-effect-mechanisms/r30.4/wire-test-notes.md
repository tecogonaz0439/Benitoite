# 実通信と worker の検査

## 検査の境界

`l32_http_client.rs` の既存のループバックの受け手と通常の解析・コンパイル・VM の実行入口を使った。新しい送信を試すための本番の引数、公開範囲、差し込み口は加えていない。実通信は `ExecMode::Direct` と `ExecMode::Request` の双方を使い、既存の `HeapConfig { stress: true, .. }` と小さい VM の call budget を保った。外部の名前の解決や外部への通信は行っていない。`localhost` は OS のローカル名の解決を使う。

テストの作成時の関門では、新しい操作の非追従・一対象・引数と完了の保持を独立した契約とした。既存の旧 `send` の追従試験や純粋な要求検査だけでは、新しい操作の設定の渡し忘れ、保持した値と送信内容の取り違え、別 worker の完了への取り違えを捕まえない。このため、非追従と送信内容は既存の実通信の境界で、失敗表の引き渡しは既存の `network_faults` の表の追加行で、並行する二対象は既存の `io_modes` の順序を与える実行境界で確かめた。

## 実通信の表

| 対象 | 実ソースと観測 | 結果 |
|---|---|---|
| 非追従の 3xx | 301・302・303・307・308、Location のない 302、304 を返す相手へ POST する。Location の相手は別のポートで待ち受け、送信後に非ブロックの accept で調べる | 各回の本来の受け手には要求ちょうど1件。Location の相手には0件。3xx の status と本体を返し、304 の本体は HTTP の意味に従って空である |
| 同じ要求の五欄 | `ClientRequest` を検査してから、`bind` で射影し、その射影から method・url・body を変えた別のレコードを作る。保持した元の値には文字列の確保を挟んで `sendIn` を呼ぶ | wire は元の POST、`/original?q=%2F`、二つの `X-Probe`、本体 `posted猫` である。別レコードの DELETE・別ポート・空の本体へ取り替わらない。fragment は送信されない |
| 時間上限 | 元のレコードの timeoutMilliseconds を100にして、応答しないローカルの待ち受けへ送信する | `NetworkErrorKind.TimedOut`。保持した timeout を送信時に捨てて既定値へ戻す退行を捕まえる |
| URI と実効 endpoint | IPv4、`LoCaLhOsT` と小文字パターン、展開した IPv6 の `0:0:0:0:0:0:0:1` と正規形パターンを使い、URI の port には先頭0を付ける | 各回1要求だけを意図したローカルの相手が受け取り、パス `/endpoint` を保つ |
| 明示 Host の一致 | 上の三種で Host を IPv4、`LOCALHOST`、`[::1]` と同じ数値 port にする | 受理する。wire の Host は入力の欄の値を保ち、接続先は URI と同じ実効 endpoint である |
| 明示 Host の不一致・不正 | 別ポートの IPv4、`other.invalid`、不正な `[invalid` を使う。URI の相手と別ポートの相手を両方待ち受ける | `NetworkErrorKind.InvalidInput`。両方の待ち受けの accept は WouldBlock であり、通信を開始していない |
| IPv4 射影の IPv6 | 既存の `checked_requests_reject_mapped_ipv6_before_loopback_send` を新旧の両送信経路へ広げた。3パターンと4字面の計12入力、通常の IPv4・IPv6 の対照を使う | 射影の12入力は検査で `Scope.InvalidTarget`。通常の二対象だけに各経路1件ずつ送信する。既存の拒否方針を維持した |
| proxy | テストの子プロセスだけへ `HTTP_PROXY/http_proxy/HTTPS_PROXY/https_proxy/ALL_PROXY/all_proxy` を別のローカルの待ち受けとして与え、`NO_PROXY/no_proxy` は空にする | 本来の相手が両方式で1件ずつ受け取り、proxy の accept は WouldBlock。環境変数は親と他のテストへ変更しない |
| 送信準備の通常の失敗 | URL と所属の検査が成功する、GET の非空の本体と未対応の PURGE を送る | `NetworkErrorKind.InvalidInput`。`RequestCheckError` へ混ぜない |
| 引数の実行時エラー | URL と所属の検査が成功する、不正なヘッダ名 `Bad Header` と timeoutMilliseconds=0 を送る | 既存の `send` と同じ実行時の引数のエラーで停止する。診断に `Benitoite.Network.Http.sendIn` の名前が含まれる。これを NetworkError と報告しない |
| 実際の接続失敗 | 取得して閉じたローカルの port へ送る | `NetworkErrorKind.ConnectionRefused`。失敗表だけの検査とは別に実際の接続の失敗を通す |
| 失敗表の対象の引き渡し | 既存の4種類の失敗と IPv6、名前の大小の行に `sendIn` を追加。run_program と CLI、両 IO 方式を通す | 全て対応する NetworkError。worker が実行されないことも既存の観測で照合した |
| 二つの worker と完了の順序 | 別の二つのローカルの port へ Task.all で要求し、正順・逆順・実時計、両 IO 方式の計6実行を行う。各要求には確保を挟む | 相手ごとのパス `/A`・`/B` を保ち、結果は常に `[Ok("A"), Ok("B")]`。二つの本物の受け手は各6要求を確認する |

一つの `sendIn` の観測の単位は保持した endpoint（DNS と OS の変換前の名前または IP と port）である。複数のテスト入力や並行する二操作を、一つの操作の追加対象へ数えない。`localhost` の解決されたアドレスへの接続試行の回数やソケットの族を、型の endpoint と同一視しない。プロセスとソケットの実装の全挙動や、外部のネットワーク環境を確認済みとはしない。

## 局所検査

各コマンドはリポジトリの根で実行した。`run-record.py` は `/usr/bin/time -p` の内側で子を待ち、検査自身の終了を `check_exit_code` へ記録する。RSS は macOS の `getrusage(RUSAGE_CHILDREN)` のバイト値を MiB へ換算した補助値であり、並行した全プロセスの合計ではない。

| 記録 | コマンド | 終了・外側秒・成功数 | RSS MiB |
|---|---|---|---:|
| [構文修正後](wire-http-after-syntax.log)・[計時](wire-http-after-syntax.json) | `cargo test -p benitoite --test l32_http_client send_in_ -- --nocapture` | 101・3.632901167秒・4成功1失敗（参照実通信の制限、下記） | 640.859375 |
| [最終HTTP](wire-http-final.log)・[計時](wire-http-final.json) | `cargo test -p benitoite --test l32_http_client send_in_ -- --nocapture` | 0・3.654898666秒・4成功 | 640.390625 |
| [mapped](wire-mapped.log)・[計時](wire-mapped.json) | `cargo test -p benitoite --test l32_http_client checked_requests_reject_mapped_ipv6_before_loopback_send -- --exact --nocapture` | 0・0.720673秒・1成功 | 74.5625 |
| [失敗表](wire-faults.log)・[計時](wire-faults.json) | `cargo test -p benitoite --test network_faults get_send_and_send_in_expose_all_four_fault_kinds_through_run_and_cli -- --exact --nocapture` | 0・2.1723165秒・1成功 | 643.8125 |
| [並行](wire-concurrent.log)・[計時](wire-concurrent.json) | `cargo test -p benitoite --test io_modes concurrent_send_in_operations_keep_each_endpoint_and_result -- --exact --nocapture` | 0・2.440506834秒・1成功 | 636.8125 |

作業末の W-R と H は取りまとめが同じ最終状態で実行する。この局所検査だけを作業末の全件の成功としない。旧 `send` の実通信の追従試験は変更しておらず、W-R の全統合に含める。

## 初回の失敗と修正・参照実行器の限界

最初の新5件の実行は1成功4失敗だった。三つはテストソースの `lambda(_)` が E0210 で拒否され、残り一つは下記の参照実通信の失敗である。`_error` へ変えた次の単独実行も、`Result.mapError` が引数名 `error` を要求するため E0454 で失敗した。`lambda(error)` へ直した。これら最初の二回はツールの出力だけで、生ログ・計時の保存は欠けている。保存した出力であるかのように扱わない。4成功1失敗の状態からは上表の記録を残した。

新しい実通信を既存の差分比較へ渡す案は、VM の送信の後に参照側が `HTTP runtime unavailable` で止まった。調査により、`refinterp/resources.rs` の `Io` は意図的に `runtime_view` を転送せず、同ファイルの `reference_and_fixed_services_do_not_expose_vm_runtime_views` が None を契約として検査していることを確認した。旧 `send` も同じ実通信の制限を持つ。本番の参照実行器の契約へ今回の検査の都合で VM のランタイムを足さず、実通信の差分比較の新テストは取り除いた。初回の失敗は [構文修正後のログ](wire-http-after-syntax.log)に残る。RequestIn の純粋な保持・射影・拡大の参照実行器での検査は既存の範囲を保ち、今回の実通信は VM の両方式で確認したと限定する。

また、304 の本体を他の 3xx と同じ `redirect` と期待する初案を、HTTP の意味に従う空へ直した。不正なヘッダ名と0の timeout を NetworkError と期待する初案も、既存の `read_request` の契約を読み、実行時の引数のエラーと `sendIn` の診断名の確認へ変えた。この二点は失敗前の自己確認で修正した。

## 保持・片付け・時間

テストでは本物の worker の本体を実行し、IO の完了順だけを既存の `OrderedWorkers` で変えた。新しい言語の値の根や GC の障壁、本番の保持の表現を追加していない。送信される endpoint の入力は操作ごとに一つであり、並行する相手をまとめて一つの対象とする仕組みも加えていない。

新しい `CARGO_TARGET_DIR`、target 外の一時ビルド、基準版の展開は作っていない。proxy の検査はテストバイナリ自身を子として実行し、ファイルへ展開しない。既存の `io_modes` の一時ディレクトリは `Directory` の Drop で削除する。今回の担当に追加の削除対象はない。

担当の局所実装・読解・検査は2026-10-29の07時台 UTCに行い、完了は07:17頃 UTCである。能動時間は概算15分で、検査の待ちと一部重なるため厳密な分離計時ではない。追加の独立レビュー・受け入れ・W-R/H は取りまとめの担当であり、この記録で完了としない。
