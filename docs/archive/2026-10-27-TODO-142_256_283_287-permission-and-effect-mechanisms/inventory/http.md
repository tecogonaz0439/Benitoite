# IF20.02: Http の入口と出口の棚卸し

IF20.07 で RV-IF20 への対応を反映した。修正の基準 B_WORK は `d94d970baca8b21c2d33a62f3380c3562fb0cc57`、変更点と再集計は [IF20.07 の結果](../if20.07/results.md)に記す。以下の枝ごとの HEAD と B_WORK は当初の調査時点を示す。

## 対象と数え方

本書は現行の Http の宣言・組み込み・IO 実行器を読んだ記録である。欄の定義と操作の数え方は [file.md「表の欄と数え方」](file.md#表の欄と数え方)に従う。公開の明示的な関数は一件ずつ数え、組み込みの登録を重ねて加算しない。要求・応答の各欄と通信の段階は、その操作に属する経路として別表に分ける。非公開の `serveLoop`、レコードの構成子・アクセサ、誤りの射影、暗黙の解放は補助経路であり、公開操作の件数へ加えない。

記録対象の HEAD と B_WORK は、ともに `a522a3bbc1bfd217adc4d30dea2010a2e955f410` である。0.0.14 の扱いは全て候補であり、[decisions の IFC-D3・D4・D6・D8](../decisions.md#情報フロー制御の設計者への問い)の回答を待つ。現行の型・エフェクトの検査を、情報フロー制御（information-flow control）や非干渉性の保証として扱わない。

入力は [README](../README.md)、[decisions の表記・判断 8・19・21](../decisions.md)、[plan の IF20](../plan.md#本番を変えない並行作業)、[questions の D3・D4・D6・D8](../study/questions.md)、[synthesis の設計の判断](../study/synthesis.md#0013-で決めて文書にする情報フロー制御の設計の判断)、[information-flow の §1・§2](../study/information-flow.md)、[usage-and-flow の §5](../study/usage-and-flow.md)、[IF20.01 の申し送り](../if20.01/results.md#ずれと申し送り)である。版の割り振りと訳語は README の後の決定にそろえた。

設計書は [03-09「ネットワーク」](../../../design/03-interop/03-09-network.md)、[03-07「共通の規則」](../../../design/03-interop/03-07-io-modules.md#共通の規則)、[01-07「組み込みのエフェクト」「IO の失敗」](../../../design/01-spec/01-07-effects.md)、[07-01「各機構が保証すること」](../../../design/07-quality/07-01-security-model.md#各機構が保証すること)を照合した。Http を直接定める章は 03-07 ではなく 03-09 である。

## ソースの略記

| 略記 | 位置と役割 |
|---|---|
| H | [prelude/stdlib/Network/Http.bnt](../../../../crates/benitoite/src/prelude/stdlib/Network/Http.bnt)。全公開宣言と通常の関数の本体 |
| C | [builtins/funcs/http_client.rs](../../../../crates/benitoite/src/builtins/funcs/http_client.rs)。`send`、`read_request`、`validate_request`、`make_agent`、`NetworkResolver::resolve`、`execute`、`classify`、`complete` |
| D | [builtins/funcs/http_client/redirect_body.rs](../../../../crates/benitoite/src/builtins/funcs/http_client/redirect_body.rs)。`CheckedConnector`・`CheckedTransport`、追従前の 3xx の本文の検査 |
| S | [builtins/funcs/http_server.rs](../../../../crates/benitoite/src/builtins/funcs/http_server.rs)。サーバ操作、要求の取り出し、明示の解放、完了値への変換 |
| R | [runtime/io/http.rs](../../../../crates/benitoite/src/runtime/io/http.rs)。`listen`・`accept`・`RequestReader::advance`・`response_bytes`・`Exchange::release`・`stop_exchange` |
| U | [builtins/funcs/http_util.rs](../../../../crates/benitoite/src/builtins/funcs/http_util.rs)。`path_segments` |
| E | [builtins/funcs/network_error.rs](../../../../crates/benitoite/src/builtins/funcs/network_error.rs)、[NetworkError.bnt](../../../../crates/benitoite/src/prelude/stdlib/NetworkError.bnt)、[Trait.bnt の Show](../../../../crates/benitoite/src/prelude/stdlib/Trait.bnt)。誤りの種類・文言と表示 |
| O | [runtime/io/ops.rs](../../../../crates/benitoite/src/runtime/io/ops.rs)の `execute_job`・`accept_completion`、[vm/dispatch/tasks/io.rs](../../../../crates/benitoite/src/vm/dispatch/tasks/io.rs)の `submit`・`reflect_cancellation`・`complete`。仕事・完了・取り消し |
| T | [runtime/io/resources.rs](../../../../crates/benitoite/src/runtime/io/resources.rs)の `request_release`・`finish_release`・`take_release_failure`、[vm/state.rs](../../../../crates/benitoite/src/vm/state.rs)の解放処理。資源と解放の失敗 |
| UC | 固定依存 `ureq 3.4.2` の `src/config.rs`、`Config::default`。追従と認証ヘッダーの既定値 |
| UR | 同じ版の `src/run.rs`、`run`・`call_run`・`add_headers`・`handle_redirect`。追従ループ、本文の除去、応答の拡張 |
| PR | 固定依存 `ureq-proto 0.6.4` の `src/client/redirect.rs`、`Call<Redirect>::as_new_call`。追従先・メソッド・ヘッダーの変更 |
| PE | 同じ版の `src/ext.rs` の `need_request_body`・`is_redirect_retaining_status`、`src/client/amended.rs` の `take_request`・`new_uri_from_location`・Host の処理 |

依存の版は [Cargo.toml](../../../../crates/benitoite/Cargo.toml) と [Cargo.lock](../../../../Cargo.lock)で確認し、手元の Cargo registry の同版のソースを読んだ。外部一次資料の所在は [ureq の run.rs](https://docs.rs/crate/ureq/3.4.2/source/src/run.rs)、[config.rs](https://docs.rs/crate/ureq/3.4.2/source/src/config.rs)、[ureq-proto の redirect.rs](https://docs.rs/crate/ureq-proto/0.6.4/source/src/client/redirect.rs)、[ext.rs](https://docs.rs/crate/ureq-proto/0.6.4/source/src/ext.rs)である。これらの Web 取得は失敗したため、Web の内容を確認済みとはしない。読んだローカルソースの版・相対位置・SHA-256 は [dependency-sources.json](../if20.02/dependency-sources.json)に残す。依存の一般的な現行仕様へ結論を広げない。

## 候補の共通条件と範囲付き送信

判断 8 の `Http.sendIn` は候補名であり、型契約は `Http.RequestIn[H,P] -> Result[Http.Response, NetworkError] uses Http.Connect[H,P]` である。判断 7 では、検査した同じ要求と実効 host/port を保持し、新送信は追従せず 3xx を返す。現行 H・C の宣言・登録には、この新操作も `RequestIn` もない。旧 `send`・`get` の `Http.Connect` は、判断 8・15 では Top のまま残す対象である。

host/port の範囲だけから、固定した HTTPS origin・パス・メソッド・認証の欄・本文の用途を認定しない（判断 14）。以下の「契約を設ける」は、これらと要求の有無・pc・結果の分類を定める候補である。認証を送る許可から応答全体の非機密化（declassification）を導かず、固定した操作の公開できる値・成否・用途だけを選ぶ。許した要求に由来する依存だけを緩め、他の本文・捕捉値・条件の秘密を残す必要がある。

入口の機密性は、認定した入力契約がなければ保守的に秘密の結びとする候補である。応答の完全性は未信頼に保ち、HTTPS の証明書検証や host の一致だけでエンドースメント（endorsement。信頼の付与、または完全性レベルの引き上げ）を行ったとしない。API が秘密を応答へ反映しないことは、IFC-D3 の信頼条件として別に承認する必要がある。

成否は値とは別に確認する。`Result.Ok` / `Error` や状態コードで分岐して表示する、成功時だけ次の要求を送る、失敗時に `die` する場合にも依存が残る。物理的な所要時間の保証とは区別し、時間切れが言語の `TimedOut` になる経路を落とさない。

## 公開の全操作

この表の候補は操作全体への候補である。C01 以下の各欄に契約候補があっても、現行の自動追従まで許す意味にはならない。旧 `send`・`get` は、全追従先への照合の接続がないため、最初の保護対象では拒否する候補とした。非追従の新操作へ引き継ぐ各欄は次表に残す。サーバ側は、資源と暗黙の応答の契約が未設計であることを拒否候補の理由とし、七操作の外という理由だけで分類していない。

| ID・操作 | 宣言・実装の位置 | 方向 | 流れる値・成否と暗黙の流れ | エフェクト | 範囲付き IO との関係 | 0.0.14 の扱いの候補 | 根拠 |
|---|---|---|---|---|---|---|---|
| H01 `Http.listen` | H:11、S `listen` → R `listen` → S `listen_done` | 両方 | host/port・待ち受ける条件→OS、名前解決・bind の成否・Listener・誤り→内 | `Http.Listen` | 対応なし、旧操作は Top | 未対応で拒否 | 待ち受けの選択と資源へ保存する分類を、後の accept・解放へつなぐ契約が要るためである。 |
| H02 `Http.listenerPort` | H:13、S `listener_port` → R `listener_port` | 入口 | OS の `local_addr().port()`→Integer。port 0 の OS の選択を含み、取得失敗は `Stop::Internal` | `Http.Listen` | 対応なし | 未対応で拒否 | Listener の取得元と OS が選んだ番号の分類を引き継ぐ契約が未定であるためである。 |
| H03 `Http.accept` | H:15、S `accept` → R `accept`・`Connection::advance` | 両方 | 要求・Exchange・成否→内。自動の 100／拒否応答、資源不足の stderr 警告→外 | `Http.Listen` | 対応なし | 未対応で拒否 | 要求を値にする前にも自動応答と警告があり、資源・暗黙の出口の契約を要するためである。 |
| H04 `Http.respond` | H:19、S `respond` → R `response_bytes`・`respond`・`resume` | 両方 | 状態・ヘッダー・本文・応答する条件→接続、書き込みの成否・誤り→内。部分送信は取り消さない | `Http.Listen` | 対応なし | 未対応で拒否 | Exchange の受け手と内容・pc・部分送信の依存を保持する接続が未設計であるためである。 |
| H05 `Http.send` | H:25、C `send` → `read_request` → O → C `execute`・`send_done`・`complete` | 両方 | 要求の全五欄と有無→外、応答三欄・誤り・成否→内。追従先にも通信する | `Http.Connect` | `sendIn`（候補名）の元処理。旧操作は Top | 未対応で拒否 | 現行は各追従先と全欄を方針へ照合せず、最初の宛先だけの契約では出口を限定できないためである。 |
| H06 `Http.requestOf` | H:55、S `request_of`、T の attachments | 内部の派生 | accept が保存した要求五欄を複製して値にする。閉じ始めた後の使用は停止する | なし。Rust の本体は `state fn` | 対応なし | 契約を設ける | 新しい通信はせず、既に受け取った要求と Exchange の分類を保つ契約が要るためである。 |
| H07 `Http.closeListener` | H:59、S `close_listener` → `close` → T、R `Listener::release` | 両方 | 閉じる対象と条件→OS、登録解除の成否・誤り→内 | `State` | 対応なし | 未対応で拒否 | 待ち受けをやめる有無と失敗は、State だけを理由に情報フロー制御から外せないためである。 |
| H08 `Http.closeExchange` | H:64、S `close_exchange` → `close` → T、R `Exchange::release` | 両方 | 未送信なら 500、途中なら切断、閉じる条件→外、解放の成否・誤り→内 | `State` | 対応なし | 未対応で拒否 | 応答履歴・pc・解放時の自動送信を資源に保持する契約が要るためである。 |
| H09 `Http.pathSegments` | H:68、U `path_segments`・`decode_segment` | 内部の派生 | path→要素・件数。復号不能の要素は元の文字列のまま | なし | 対応なし | 契約を設ける | 分割・復号で元の文字列の機密性と完全性を消さない契約にするためである。 |
| H10 `Http.serve` | H:72 → 非公開 `serveLoop` H:79 | 両方 | host/port・handler・要求・応答・成否。要求ごとの Task、解放、再帰を含む | `Http.Listen, State, E` | 対応なし | 未対応で拒否 | 任意の handler と Task・資源の依存を結ぶ契約が未接続であるためである。 |
| H11 `Http.text` | H:90、`String.toUTF8` と Response の構築 | 内部の派生 | status・文字列→状態・固定 content-type・本文 | なし | 対応なし | 契約を設ける | UTF-8 化や固定のヘッダーで入力の分類を消さず、送信は H04 の出口で別に照合するためである。 |
| H12 `Http.html` | H:95、`String.toUTF8` と Response の構築 | 内部の派生 | status・文字列→状態・固定 content-type・本文 | なし | 対応なし | 契約を設ける | 応答を作るだけの純粋性を、公開や信頼済みの根拠にしないためである。 |
| H13 `Http.json` | H:100、`Json.stringify`・`String.toUTF8` | 内部の派生 | status・Json.Value→状態・固定 content-type・本文 | なし | 対応なし | 契約を設ける | JSON への変換でも値の分類を保つ必要があり、変換内部の照合は IF20.04 へ渡すためである。 |
| H14 `Http.header` | H:105、`List.find` と名前の小文字化 | 内部の派生 | headers・name→最初の値の Some／見つからない None | なし | 対応なし | 契約を設ける | ヘッダーの内容・探索名・有無の依存を保ち、検索を非機密化と扱わないためである。 |
| H15 `Http.clientRequest` | H:114、ClientRequest の構築 | 内部の派生 | method・url と、空の headers/body・30000 ms→要求 | なし | 新 RequestIn の検査より前の通常の値 | 契約を設ける | 構築後のレコード更新を含め、五欄と構築条件の分類を送信まで保つ必要があるためである。 |
| H16 `Http.get` | H:119 → H15 → H05 | 両方 | URL→GET、空の要求本文・ヘッダーと既定 timeout。応答・成否→内 | `Http.Connect` | 新操作への自動変換なし、旧操作は Top | 未対応で拒否 | ラッパーも現行 send の自動追従を使い、応答を公開とする入力契約もないためである。 |

H02 はポートを読む入口であり、この関数自体は要求送信や待ち受けの変更をしない。H06 は純粋な公開宣言でも Rust の登録は State である。前者の読み取り、後者の既存データの取り出しを、通信や分類の除去と取り違えない。

## クライアントの各欄と通信の段階

この表は H05・H16 から分けた経路であり、公開操作を追加した件数ではない。C01〜C21 は、判断 8 の非追従の `sendIn`（候補名）にも契約・分類を引き継ぐ対象である。現行のエフェクトは H05・H16 を通る `Http.Connect`、新操作の予定は `Http.Connect[H,P]` である。範囲の照合だけで各欄の内容や結果の分類は決まらない。

| ID・操作 | 宣言・実装の位置 | 方向 | 流れる値・成否と暗黙の流れ | エフェクト | 範囲付き IO との関係 | 0.0.14 の扱いの候補 | 根拠 |
|---|---|---|---|---|---|---|---|
| C01 要求 method | H ClientRequest、C `read_request`・`validate_request` | 出口 | メソッドと選ぶ条件→要求。標準外や GET/HEAD/CONNECT の非空本文は InvalidInput | `Http.Connect` | 新送信でも要求契約へ | 契約を設ける | 定数の本文でもメソッドの選択で秘密を表せるため、内容・pc と用途を照合する候補である。 |
| C02 要求 url | H、C `read_request`・`execute` | 出口 | scheme・host・実効 port・path・query を含む URL と選択→接続先と要求。無効なら InvalidInput | 同上 | H,P だけでは URL 全体を限定しない | 契約を設ける | 宛先だけでなく path/query に入れた秘密と scheme の条件が必要だからである。 |
| C03 要求 headers の名前 | H、C `read_pairs`・`valid_header` | 出口 | 名前・件数・有無→ヘッダー。無効な名前は通信前に停止 | 同上 | 新送信でも保持する要求の欄 | 契約を設ける | 秘密によって選んだ名前や欄の有無も出口だからである。 |
| C04 要求 headers の値 | 同上、C Request builder | 出口 | Authorization・Cookie・独自ヘッダー等の値→相手。制御文字は通信前に停止 | 同上 | 認証の用途・欄は H,P と別契約 | 契約を設ける | 認証を許した分類を他の欄へ送る許可へ広げず、全欄を照合する必要があるためである。 |
| C05 要求 body | H、C `read_request`・`validate_request`・`execute` | 出口 | Bytes と長さ・空かどうか→送信。途中の失敗で送信済みの内容は戻らない | 同上 | 機密ファイルの固定 API 送信に接続 | 契約を設ける | 本文・宛先・pc の分類と用途を同時に確認し、File の入力分類も残す必要があるためである。 |
| C06 要求 timeoutMilliseconds | H、C `read_request`・`make_agent` | 出口 | 上限→ホストの期限設定。1 未満は停止、2^40 ms で頭打ち。HTTP の欄として送る値ではない | 同上 | 新送信でも同じ要求の一欄 | 契約を設ける | 期限の選択で送信・受信の完了や成否が変わるため、秘密依存の設定を無視できないためである。 |
| C07 要求の有無と順序 | C `send`、O `submit`・`execute_job` | 出口 | 呼ぶ条件・pc→要求するか、どの順で要求するか | 同上 | 新送信の呼び出し条件も対象 | 契約を設ける | 公開の定数を送るだけでも秘密で送信を選べるためである。 |
| C08 応答 status | C `ResponseData`・`execute`・`complete` | 入口 | 状態コード→Integer。4xx/5xx も Ok。最終応答の値と分岐 | 同上 | 新送信では非追従の 3xx も値へ | 保守的（秘密の結びとする） | 認証の可否や API の状態を表し、本文を捨てても公開の根拠がないためである。 |
| C09 応答 headers の名前 | C `execute`・`complete` | 入口 | 名前・件数・有無→List の Pair。最終応答を変換 | 同上 | 応答型は共通 | 保守的（秘密の結びとする） | ヘッダーの有無・個数でも秘密や外部状態を区別しうるためである。 |
| C10 応答 headers の値 | 同上 | 入口 | 値→String。非 UTF-8 は InvalidHTTPData。Location・Set-Cookie 等も特別に伏せない | 同上 | Location を返すことと追従は別 | 保守的（秘密の結びとする） | トークン等の反映と UTF-8 の成否を含み、契約なしに公開へ落とせないためである。 |
| C11 応答 body | C `read_limited`・`complete` | 入口 | Bytes・長さ・読み終わるか→値または失敗／停止。本文を文字列へは自動変換しない | 同上 | 固定 API の値・用途の契約を要する | 保守的（秘密の結びとする） | 認証付き応答から公開できる件数等は IFC-D3 の限定契約を要するためである。 |
| C12 誤り kind | C `classify`・`protocol_kind`・`complete`、E `kind` | 入口 | DNS・接続・時間切れ・解析・TLS 等→NetworkErrorKind | 同上 | 新送信も NetworkError を返す | 保守的（秘密の結びとする） | 種類の違いだけでも相手や入力・認証に依存する後続を選べるためである。 |
| C13 誤り message | C `classify`・`request_protocol_failure`・`tls_failure`、E | 入口 | OS・依存の `to_string()`、固定の文言、CPU の不足機能名→String と Show | 同上 | RequestCheckError は将来の別経路 | 保守的（秘密の結びとする） | 専用 URL 欄はなくても文言への混入を否定できず、全文も未確認だからである。 |
| C14 Ok／Error の成否 | C `complete` | 入口 | 応答が得られたか→Result の構成子。捨てても try/match や次の送信の有無に影響 | 同上 | 固定 API の成否契約に接続 | 保守的（秘密の結びとする） | 値の非機密化を成否全体へ拡張しない必要があるためである。 |
| C15 名前解決 | C `NetworkResolver::resolve`、UR 接続前の resolve | 両方 | host→OS の解決器、解決先・失敗→接続と成否。解決器の Io は HostNotFound、時間切れは別 | 同上 | H,P と実対象の信頼対応を要する | 契約を設ける | DNS への名前の出力と外部状態の入力があり、解決の成功を公開と仮定できないためである。 |
| C16 接続の確立・送受信 | C `make_agent`・`execute`・`classify`、UR | 両方 | 接続先・実行条件→OS、接続拒否・reset 等→誤りと後続の有無。proxy は明示的に None | 同上 | 新送信では検査した同じ実効対象へ | 契約を設ける | 接続の試みも出口であり、失敗でも送信済みの内容を取り消せないためである。 |
| C17 TLS の成否 | C `missing_cpu_features`・`tls_failure`・`make_agent`・`classify` | 両方 | https の対象→TLS、証明書検証・CPU 条件等→成功または Other と文言 | 同上 | scheme の精度は H,P とは別 | 契約を設ける | 接続の選択と成否を追い、TLS 成功だけで入力の完全性を引き上げないためである。 |
| C18 時間切れ | C `make_agent`・`classify`、D `await_input` | 入口 | 解決・接続・本文等の完了と期限→TimedOut、後続の分岐。物理的な時刻そのものの戻り値はない | 同上 | 新送信の成否も同じ対象 | 保守的（秘密の結びとする） | TimedOut は観測可能な値であり、物理時間の保証の外という理由で除外できないためである。 |
| C19 通信前の要求検査と停止 | C `read_request`・`valid_header`・`validate_request`・`domain` | 内部の派生 | 引数の分類→InvalidInput または ArgumentOutOfDomain、送信しないことと診断 | 同上 | 新純粋検査の失敗とは区別する | 契約を設ける | 秘密依存の検査失敗で要求や後続が消えるため、値だけの契約では足りないためである。 |
| C20 入力上限と確保の失敗 | C `read_limited`・`complete`、`CheckedLen` | 入口 | 応答の長さ・ヘッダー数等→InputTooLarge 等の停止。Result.Error と別経路 | 同上 | 新送信にも残る | 保守的（秘密の結びとする） | 受信した内容の量が診断・終了へ影響し、成功値の分類だけでは追えないためである。 |
| C21 自動のヘッダー等 | C `validate_request`、UR `add_headers`、PE Host の処理 | 出口 | 本文の長さ等→Content-Length／区切り、URL→既定 Host、依存の既定 User-Agent・Accept 等 | 同上 | 新送信でも派生する出口を照合 | 契約を設ける | 自動生成した欄にも URL・本文の依存があり、利用者が書いた欄だけでは漏れるためである。 |

## リダイレクトの経路

現行 C は `max_redirects(10)` と総時間の上限を指定する。UC の既定は `redirect_auth_headers = Never`、追従回数を超えたときは誤り、履歴の保存は無効である。UR は各段の応答を消費して次の要求へ進む。D は追従前の 3xx の頭・本文の終端と大きさを検査するが、要求の送信先と秘密欄を方針へ再照合する処理ではない。

| ID・操作 | 宣言・実装の位置 | 方向 | 流れる値・成否と暗黙の流れ | エフェクト | 範囲付き IO との関係 | 0.0.14 の扱いの候補 | 根拠 |
|---|---|---|---|---|---|---|---|
| R01 追従先の取得 | PR `as_new_call`、UR `handle_redirect` | 入口 | 3xx の Location と状態→次の URI・方法、欠落／不正→誤り。途中の Location を独立の言語値にはしない | `Http.Connect` | 新送信は追従せずヘッダーとして返す | 保守的（秘密の結びとする） | 値に戻らない段階でも未信頼の外部入力が次の出口を選ぶためである。 |
| R02 追従先の URL と追加通信 | PR・PE `new_uri_from_location`、UR のループ | 出口 | 前の URI と Location→新 URI、追加の名前解決・接続・要求。最大 10 回 | 同上 | 新送信ではこの経路を起動しない | 未対応で拒否 | 最初の host/port と送信先が変わりうるので、各段の対象・秘密欄の契約が要るためである。 |
| R03 方法の再送 | PR `as_new_call`、PE の方法判定 | 出口 | 307/308 は POST/PUT/PATCH と DELETE なら追従不可、他は方法を保持。他の追従では GET/HEAD を保持し他を GET にする | 同上 | 新送信では再送なし | 未対応で拒否 | 方法の変更と追加要求の有無が、最初の一要求とは異なる出口になるためである。 |
| R04 ヘッダーの再送 | PR `as_new_call`、UC、UR `add_headers` | 出口 | Authorization は Never のため除去、Cookie・Content-Length も除去。他の元ヘッダーは一律には除去せず、次の要求へ残る | 同上 | 新送信では再送なし | 未対応で拒否 | 独自の認証欄等を含む全秘密が除かれる保証はなく、認証ヘッダー一つの除去だけでは足りないためである。 |
| R05 本文を再送するかの判定 | PR、UR `run` | 内部の派生 | 307/308 の POST/PUT/PATCH は RedirectFailed、他の追従は GET/HEAD 等となり `body.remove()`。この経路で元の非空本文を再送する分岐は確認されない | 同上 | 新送信では判定自体が不要 | 未対応で拒否 | 本文を除去しても追加要求の欄・有無の流れが残り、再送の安全性を一般化できないためである。 |
| R06 追従をまたぐ期限 | C `timeout_global`、UR `timings.new_call` | 内部の派生 | 元の上限と各段の進行→次段へ進めるか、TimedOut。要求ごとの言語引数は返らない | 同上 | 新送信では一要求の期限 | 契約を設ける | 追従を許す後の契約でも期限と成否の依存を引き継ぐ必要があるためである。 |
| R07 読み捨てる 3xx 本文・頭 | D `check_input`・`await_input`、UR | 入口 | 途中の内容は値へ返らず、欠けた終端・過大な頭等は InvalidHTTPData、大きすぎる本文等は Other、回数超過も Other | 同上 | 非追従の応答本文との違いを再照合 | 保守的（秘密の結びとする） | 最終本文の値に含まれなくても失敗と後続の条件へ反映するためである。 |
| R08 最終 URL・追従履歴の取り出し | UR `ResponseUri`・`RedirectHistory`、C `ResponseData`・`complete` | 内部の派生 | 依存は最終 URI を拡張に入れるが C は読まない。言語の Response に最終 URL／履歴欄はない | 同上 | 新送信も URL 専用欄の追加は判断 8 にない | 契約を設ける | URL の専用戻り値がなくても最終ヘッダー・本文・誤りへの反映を消したことにならないためである。 |

R04 は「全ヘッダーをそのまま再送する」という記述でも「秘密の欄は全て除去する」という記述でもない。PE では明示的に指定した Host も元の要求に属する。自動の Host と利用者の Host、送信先の実効 host は同一視せず、厳密な線上のバイト列は未確認の表へ残す。

## サーバの各欄と暗黙の出口

以下は H01〜H04・H07・H08・H10 と H06 の補助経路である。サーバを最初の保護対象で拒否する候補でも、外部要求や自動応答を棚卸しから除かない。

| ID・操作 | 宣言・実装の位置 | 方向 | 流れる値・成否と暗黙の流れ | エフェクト | 範囲付き IO との関係 | 0.0.14 の扱いの候補 | 根拠 |
|---|---|---|---|---|---|---|---|
| S01 待ち受け host | S `listen`、R `listen` | 出口 | 名前・アドレス→OS の名前解決と bind、呼ぶ条件 | `Http.Listen` | 対応なし | 未対応で拒否 | 名前の公開と待ち受けの選択の契約を要するためである。 |
| S02 待ち受け port | 同上 | 出口 | port→bind、0 は OS に選択を委ねる。範囲外は通信前に停止 | 同上 | 対応なし | 未対応で拒否 | 公開ポートと呼ぶ条件も秘密依存になりうるためである。 |
| S03 Listener と開始の成否 | S `listen_done`、R `listen` | 入口 | OS の解決・bind・登録の結果→資源または NetworkError | 同上 | 対応なし | 未対応で拒否 | 作った資源と成否の分類を後続へ残す契約が要るためである。 |
| S04 割り当てた port | S/R `listener_port` | 入口 | OS の待ち受けポート→Integer、取得不能は内部停止 | 同上 | 対応なし | 未対応で拒否 | 外部状態と取得元の分類を資源から読み直す契約が要るためである。 |
| S05 受信 method | R `RequestReader::advance`、S `request_of` | 入口 | 相手の method→Request.method、後の応答の本文抑制にも使う | `Http.Listen`、取り出しはなし | 対応なし | 未対応で拒否 | 未信頼の入力を資源へ保持し応答へつなぐ契約が要るためである。 |
| S06 受信 path | 同上、R `origin_target` | 入口 | 要求対象から得た path→Request.path。絶対形からの取り出しを含む | 同上 | 対応なし | 未対応で拒否 | path への変換を信頼の付与とせず取得元を保つ必要があるためである。 |
| S07 受信 query | R `parse_query`、S `request_of` | 入口 | 復号した名前・値・順序・件数→Request.query、失敗は自動拒否へ | 同上 | 対応なし | 未対応で拒否 | 値と解析成否を両方つなぐ契約が要るためである。 |
| S08 受信 headers の名前 | R `RequestReader::advance`、S `request_of` | 入口 | 小文字化した名前・順序・有無・件数→Request.headers | 同上 | 対応なし | 未対応で拒否 | 名前の正規化でも外部入力の分類は消せないためである。 |
| S09 受信 headers の値 | 同上 | 入口 | UTF-8 の値→Request.headers、Host・長さ等の検査に依存した拒否 | 同上 | 対応なし | 未対応で拒否 | 内容と自動応答の分類を保持する契約が要るためである。 |
| S10 受信 body | R `RequestReader::advance`、S `request_of` | 入口 | 固定長／chunked の本文→Bytes、16 MiB の上限や解析成否→自動拒否 | 同上 | 対応なし | 未対応で拒否 | 内容・長さ・終端と資源の分類を結ぶ必要があるためである。 |
| S11 accept の成否 | R `accept`、S `accept` | 入口 | Exchange／NetworkError／待ち。接続だけの失敗は捨て、資源不足は再試行し、継続不能なら Error | `Http.Listen` | 対応なし | 未対応で拒否 | 値を返すか再試行するかも外部状態へ依存するためである。 |
| S12 送信 status | S `respond`、R `response_bytes` | 出口 | 200〜599 の状態→接続、範囲外は停止 | 同上 | 対応なし | 未対応で拒否 | 状態だけでも handler の秘密依存を出力できるためである。 |
| S13 送信 headers の名前 | 同上 | 出口 | 名前・有無→接続。区切り等の欄と Connection 指定の欄は除き再構成 | 同上 | 対応なし | 未対応で拒否 | 除去後の実際の欄と元の検査失敗も追う必要があるためである。 |
| S14 送信 headers の値 | 同上 | 出口 | 値→接続。無効な欄は置換対象でも送信前に停止 | 同上 | 対応なし | 未対応で拒否 | 本文を隠してもヘッダーの値と検査成否が出口に残るためである。 |
| S15 送信 body と派生長 | R `ResponseFraming::body_and_length`・`response_bytes` | 出口 | 本文→接続。HEAD では本文なしでも長さを返しうる。204/205/304・CONNECT の 2xx でも抑制・長さの規則がある | 同上 | 対応なし | 未対応で拒否 | 本文が線上に出ない場合も長さや状態の依存を消せないためである。 |
| S16 respond の成否 | R `advance_response`、S `respond` | 入口 | 全送信／部分送信・切断・登録失敗→Ok／NetworkError。二度目は ResponseSentTwice の停止 | 同上 | 対応なし | 未対応で拒否 | 成否と停止・部分送信を Exchange の履歴へ結ぶ契約が要るためである。 |
| S17 自動の 100・拒否応答 | R `Connection::advance`・`RequestReader::advance`・`error_response` | 出口 | 受信の段階・Expect 等→100、解析不能→400、過大な本文→413、頭や欄の上限→431。通常の handler を経ない | `Http.Listen` 内 | 対応なし | 未対応で拒否 | 言語の respond だけに検査を置くとこの出口を見落とすためである。 |
| S18 資源不足の警告 | R `Listener::retry`、S `accept` の stderr 出力 | 両方 | OS の不足理由→文字列→stderr。一連の不足の初回に一度、出力余地がなければ捨てる | `Http.Listen` 内、Console.Write は宣言にない | 対応なし | 未対応で拒否 | 本文を返さない失敗も公開の出力を起こすためである。 |
| S19 Listener の明示の解放 | S `close`、R `Listener::release`、T | 両方 | 選択・閉じる条件→登録解除と close、失敗→Other と文言 | `State` | 対応なし | 未対応で拒否 | State の解放にも出口と成否があり資源の依存が要るためである。 |
| S20 Exchange の明示の解放 | S `close`、R `Exchange::release`・`write_release_response` | 両方 | 応答未送信なら 500 を総時間 3 秒まで送信、送信途中なら切断。成否→Result、失敗の kind は Other | `State` | 対応なし | 未対応で拒否 | 暗黙の 500 の有無は既存の応答履歴に依存し、明示の解放では結果も読めるためである。 |
| S21 with の解放と停止中の close | R `Exchange::release`・`stop_exchange`、T と VM の解放 | 両方 | 通常の解放は S19/S20、停止中の Exchange は 500 を送らず切断。暗黙の Exchange 解放失敗は報告せず、Listener は解放失敗の停止へ | `State` | 対応なし | 未対応で拒否 | with を抜ける条件と停止の違いも外部からの観測へつながり、State を例外にできないためである。 |

## 補助経路

| 経路 | 宣言・実装と依存 | 方向 | 0.0.14 の扱いの候補と接続先 |
|---|---|---|---|
| 非公開 `serveLoop` | H:79。accept → TaskGroup.spawn → requestOf → 任意の handler → respond、with の解放 | 両方 | 未対応で拒否。H10 の内訳であり、公開の一操作へ加算しない。IF20.06 が Task とハンドラの接続を追う |
| レコードの構成子・アクセサ・更新 | H の Request 5 欄・Response 3 欄・ClientRequest 5 欄。S/C のレコード構築と通常の言語の射影 | 内部の派生 | 契約を設ける。各欄・選択条件の分類を保ち、生成アクセサの一般の実装との照合は IF20.04・.06 へ渡す |
| `NetworkError.kind` / `message` / Show | E は保存した種類／文言を返す。Trait.Show は message をそのまま返す | 内部の派生 | 契約を設ける。C12/C13/S16/S19/S20 の分類を保って表示・JSON・ログへ渡す。IF20.04・.05 が最終出口まで追う |
| IO の待ち・取り消し・完了の破棄 | O はワーカへ所有する要求を渡す。`reflect_cancellation` は完了の受け手を外し、`accept_completion` は破棄も扱う | 両方 | 未対応で拒否。言語の受け手の取り消しだけから、既に始まった通信を取り消したと導かない。Task の一般の接続は IF20.06 へ渡す |

## 未確認の表

以下は未確認事項であり、公開操作を発見できなかった件数や、全候補の未採択を表す件数ではない。

| ID | 未確認の点 | 確認できた範囲と足りない根拠 | 行き先 |
|---|---|---|---|
| U-H01 | 応答の値・成否・用途を限定する契約と入力分類 | 現行は任意要求の応答を返し、固定 API の非機密化契約はない。公開する件数と状態・誤り・認証失敗をどこまで選ぶか、信頼条件の所有者は未決である | IFC-D3・D4・D6・D8、IF10.02/.03/.05/.07、IF30 |
| U-H02 | `sendIn`・RequestIn・非追従と実 IO の接続 | 判断 7・8 の決定と C との差を確認しただけであり、本 HEAD に新宣言・登録はない。実効 host/port、IP の解析差、proxy を含む対象一致、3xx の扱いは R30 後に照合する | R30 の HTTP 接続レビュー、plan の LR-U5、取りまとめ |
| U-H03 | 実際に送る各バイトと OS・ネットワークの挙動 | 固定版の追従時の方法・欄の除去・本文の除去をソースで確認した。明示 Host と URI、特殊な URL、TLS/DNS の全実装、各 OS の送信・解決先を実行確認していない | R30、IF20.06。最初の候補では自動追従を拒否し、必要な実装時に再現する |
| U-H04 | 誤り文言への秘密・URL・ヘッダー等の混入 | C と R が多くの箇所で `to_string()` を保存し、E/Show がそのまま返すことを確認した。依存・OS・証明書・Location の異常ごとの全文とロケール差は未確認である。IF20.07 でも保存・転送の境界を再読した。確認箇所と全文を未確認に残す範囲は [ソース読解の補足](../if20.07/source-findings.md)に記す。 | IF20.04・.05。伏字だけで成否まで公開とせず、実装時に再現する |
| U-H05 | DNS・TLS・接続・時間切れの観測者と完全性 | C の解決器・proxy None・PlatformVerifier・CPU の検査と成否分類を確認した。DNS の応答差・接続先の変更、どの受け手がどの事象を見るか、外部環境の二つの実行（公開の入力をそろえ、秘密などの違いによる観測の差を調べる比較対象）の関係条件は未設計である | IFC-D3・D4、IF10・IF20.06・IF30。物理時間の保証と Result の時間切れを分ける |
| U-H06 | サーバ資源・Task・自動応答・解放の印 | H/S/R/T の保持・自動応答・警告・明示と暗黙の解放は確認した。資源・待ち・継続・応答履歴への印の保持と二つの実行の接続はない | IF20.05・.06、接続を閉じる改造。拒否候補を実装済みの拒否と書かない |
| U-H07 | すべての表示・変換・ハンドラ・停止への接続 | Response/Request の構築、NetworkError の射影・Show、上限・引数・二重応答・解放後使用の停止まで追った。生成アクセサの一般実装、JSON・ログ、die・診断・終了状態、任意のハンドラの非再開までは閉じていない | IF20.04〜.06。受信内容や成否を伏せても要求・表示の有無に依存が残ることを渡す |
| U-H08 | 構成・プラットフォーム別の確認 | Cargo の固定依存と既定ソースを読んだ。機能を外した構成、32 ビット、異なる CPU/OS、ネットワーク障害の実行確認は行っていない | 判断 21、R30/V10。構成で変えるのは使える集合だけとする |

## 件数と申し送り

公開の明示的な関数は 16 件である。エフェクトの操作は Listen 4 件・Connect 1 件、通常の State の組み込みは 2 件、公開宣言で効果を持たない組み込みは 2 件、言語内の通常の関数は 7 件である。Http の組み込み登録は S 7 件・C 1 件・U 1 件の計 9 件で、対応する公開宣言と不一致は見つからなかった。非公開の `serveLoop` を含む H の関数宣言全体は 17 件である。

| 集計の母集団 | 方向 | 0.0.14 の扱いの候補 |
|---|---|---|
| 公開操作 H01〜H16、16 件 | 入口だけ 1、出口だけ 0、両方 8、内部の派生 7。入口を含む 9、出口を含む 8 | 契約を設ける 7、保守的（秘密の結びとする）0、未対応で拒否 9、未確認 0 |
| 各欄と通信 C01〜C21・R01〜R08・S01〜S21、50 行 | 入口だけ 21、出口だけ 18、両方 7、内部の派生 4。入口を含む 28、出口を含む 25 | 契約を設ける 14、保守的（秘密の結びとする）11、未対応で拒否 25、未確認 0 |
| 未確認事項 | U-H01〜U-H08、8 件 | 候補の採否と、実装・実行による確認の残りを上表に分けた |

各欄の行は公開操作と重ねて合算しない。新しい `sendIn`（候補名）も現行の 16 件へ加算しない。機密性と完全性の契約がない一般の応答を保守的に扱う C08〜C14/C18/C20/R01/R07 の候補と、現行の自動追従の拒否候補は併記した。

IF20.03 は環境変数と外部コマンド経由の HTTP を別の入口・出口として数える。C の proxy None は環境全体を読まない保証ではない。IF20.04 は応答・要求の各欄、header の Some/None、pathSegments・JSON・NetworkError の派生から表示・ログへつなぐ。IF20.05 は通信の成否・TimedOut・入力上限・無効な引数・二重応答・解放後使用と、stderr の自動警告・die・診断・終了状態を照合する。IF20.06 は Task の取り消し後の通信、サーバ資源と暗黙の解放、ハンドラの非再開、外部コマンド/WASM の先と典型例を照合する。

固定 API へのファイル送信では [File の候補](file.md)の保守的な分類を勝手に緩めない。トークンによる取得後の件数表示では、応答本文だけでなく成否・状態・誤りと呼び出し条件も IFC-D3 の契約に含める。IF10/IF30 と取りまとめは回答後に候補を整理し、R30 後に新送信の同一要求・非追従・対象一致を再照合する。今回の棚卸しを本番接続の完了や、現行設計書へ未実装の規則を書く根拠にはしない。
