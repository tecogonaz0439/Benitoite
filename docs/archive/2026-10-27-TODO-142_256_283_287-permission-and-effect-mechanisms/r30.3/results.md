# R30.3: RequestIn の実通信への引き渡しの照合

## 作業と状態

B_WORK と開始時・終了時の HEAD は `42d22f72f0e1719f39d26abb9fa75c95d1b1f2ab`、ブランチは `m013/r30.3` である。R30.3 の開始時の差分は空だった。R30.3b は同じ HEAD・ブランチで、前担当の設計書3章の未コミット差分と結果を引き継いだ。git の状態を変える操作、本線のディレクトリへの書き込み、`private/`・そこを指すスキル・`docs/todo/` の読取りは行っていない。共通依頼文が引き継ぐ依存・ツールチェーンを更新しない判断を保った。

要求の検査・射影・拡大から送信準備・worker・完了までの経路、URL と実効 endpoint の境界、交換の内容の型、V-Checked の限界を照合した。同じ要求と endpoint を保持する既存の実装に修正は要らなかった。変更は現行設計書3章と本ディレクトリの記録だけである。送信準備の共用条件を下表に固定し、未実装の `sendIn` を接続済みとはしない。独立レビュー [RV-R30.3](../reviews/RV-R30.3.md) は R30.4 へ進んでよいと結論し、R30.3b は取り込み前の文書修正と R30.4 への契約の追記を完了した。R30.4 の実装・実通信、設計者の判断待ちの事項、R30.5 の段の照合、K10 の全比較と設計者の受け入れは本枝の完了に含めない。

指定された plan の R30 の冒頭・R30.3〜.5・W-R/H/H-full・義務の対応表・停止条件、R20 の段と各指定枝の結果、指定レビュー、README の2026-10-29の決定、用語集を読んだ。Lean の定義は読取りだけとし、規則・主定理・Assumptions を変更していない。

## 要求の引き渡しの経路

以下のソースの位置は `crates/benitoite/` からの相対パスである。「既存」は本枝の B_WORK の実装、「R30.4」は後続への契約を表す。

| 段階 | 関数・型・保持の欄 | 照合した内容と境界 |
|---|---|---|
| 元の要求（既存） | `src/prelude/stdlib/Network/Http.bnt` の `ClientRequest`、`http_client.rs:117` の `request_fields` | 宣言順は0 method: String、1 url: String、2 headers: List[Pair[String,String]]、3 body: Bytes、4 timeoutMilliseconds: Integer。query と fragment は元の url 内に保つ |
| URL の抽出（既存） | `http_client/checked_request.rs:122` の `request_url`、`:26` の `endpoint` | Ctor/RECORD の五欄を要求し、同じレコードの欄1だけから URL と実効 endpoint を得る。別の要求を受け取る引数や環境はない |
| 検査と構築（既存） | 同 `check`・`check_request_in`、`:244` の `alloc_fields` | 動的な host/port 条件と静的 R の双方への所属を検査し、成功時だけ三欄 `[同じ ClientRequest Value, 正規化 host String, 実効 port Integer]` と Result.Ok を作る。Top でも動的検査を省かない |
| 保持・回収（既存） | `ValueCtx`、Ctor の既存の子の走査、VM の結果レジスタ | 回収しない区間で三欄と Result を確保する。以後は Result→RequestIn→同じ元レコード→五欄を辿る。ホスト側の寿命を外した Value や新しい根を追加していない |
| 射影（既存） | 同 `request_in_value:274` | 三欄の形と欄0の五欄レコードを確認し、欄0の同じ Value を直接返す。host/port を作り直さない。射影後の別レコードへの更新は、保持したレコードや endpoint を変えない |
| 拡大（既存） | 同 `widen_request_in:290` | 列 `[R,S]`、種類 endpoint、`S.covers(R)` を検査し、射影の形の確認後に入力と同じ RequestIn Value を返す。表の許容は `Covers { outer: 1, inner: 0 }`。host と port は一つの endpoint の添字であり、列の二要素は元と行き先である |
| 読取り（既存） | `http_client.rs:137` の `read_request`、`:135` の `PreparedRequest = Result<(Request<Vec<u8>>, Duration), Failure>` | 五欄から method、解析した同じ URL、headers の全 pair、本体のコピー、時間上限を読む。欠けた欄を既定値で埋めたり別レコードへ切り替えたりしない。元の url の再解析は wire 用であり、保持レコードを書き換えない。旧 send は RequestIn の host/port を受け取らない |
| 送信準備（既存） | 同 `validate_request:281`、`send` | method・header・body の規約を検査する。Content-Length の検査用 Call を作るが、成功時は元の parts と body から Request を返す。時間上限は1以上を要求し、既存の上限2^40 msへ丸める。endpoint 検査だけの成功は、この送信準備の成功を含意しない |
| worker（既存） | `WorkerWait::new(Lend::Nothing, move |_| execute(...), send_done)`、`execute:246` | 渡すのは Rust が所有する `Request<Vec<u8>>`、`Duration`、CPU 機能不足の列だけ。言語の Value を worker へ移さない。旧 `make_agent:65` は proxy(None)・max_redirects(10) であり、非追従用には使えない |
| 完了（既存） | `send_done:487`→`complete:494` | 応答の status/headers/body または NetworkError を言語の値にする。`send_done` は保持引数を使って別の要求を構築・再送信しない。VM の `dispatch/tasks/io.rs::complete` と参照実行器 `refinterp/convert.rs` は呼出しの範囲の列を完了文脈にも渡す |
| 範囲付きの送信（R30.4） | 引数 `Http.RequestIn[H,P]` の三欄、既存の `read_request` の五欄読取り | 欄0の同じレコードと欄1・2の実効 endpoint を一緒に読む。欄0を別のレコードへ替えず、欄1・2を捨てて再解析した別対象を信用しない。読取り・非追従の設定・観測の実接続は未実装であり、次節の条件を満たして接続する |

`http_util.rs` は `pathSegments` の純粋な分割・復号だけを登録する。クライアントの URL の読取り・送信・保持の経路から呼ばれず、そこで要求や endpoint を置き換える箇所はない。`redirect_body.rs` は旧 send の追従応答の本体の検査であり、新しい endpoint の所属検査を行う処理ではない。旧 send が追従先へ移ることと、RequestIn の三欄が不変であることを混同しない。

元レコードの全欄の保持と HTTP メッセージへの変換も区別する。送信準備は `http::Request` へ変換するため、ヘッダ名の表記や格納順の正規化、fragment の除去、既定の Host・長さの補完などがありうる。元の五欄をバイト列として wire へそのまま送るという契約ではない。重複ヘッダ・query・本体・時間上限が意図した要求として渡ることは、R30.4 の制御した相手で照合する。

## URL と実効 endpoint の境界（LR-U5）

既存の [URL 境界の記録](../r20.0b/url-boundary.md) と固定依存のソースを読み直した。今回の一次資料の再確認は [RFC 9110 §4.2](https://www.rfc-editor.org/rfc/rfc9110.html#section-4.2) と手元の Cargo registry の `http 1.5.0`・`ureq 3.4.2`・`ureq-proto 0.6.0` である。docs.rs の固定版への取得はツールが失敗したため、取得したとせず、固定したローカルソースの読解を根拠にする。[依存の照合記録](url-sources.json)に相対識別子・SHA-256 と確認した関数を保存する。URL parser や純粋 API は再実装していない。

| 境界 | 現在の検査と送信側の読み方 |
|---|---|
| scheme・authority・字句 | ASCII の絶対 http/https URL、非空 host、有効な二桁の `%` を要求する。userinfo・非対応 scheme・URL の字句不良などで host/port を得られなければ InvalidUrl。http::Uri の authority と同じ入力を読む |
| 既定・明示 port | 省略と空の port は http=80/https=443。明示 port は生の authority の suffix から ASCII 数字と u16 の幅を検査する。`Authority::port()` が不正な明示 port にも None を返すため、None を無条件に既定 port として成功させない。受理済みの URL は `DefaultResolver::host_and_port` の `port_u16().or_else(default_port)` と同じ数値になる |
| 名前と IP | 名前は ASCII ラベルの共通代数で小文字化する。IPv4 は正規形だけ、角括弧の IPv6 は std の数値解析後に共通 formatter で正規化する。IPv4 射影の IPv6 は V6 のまま扱い、IPv4 へ型の範囲を移さない。ただし、これを許すパターンでは OS を通して IPv4 の宛先へ届くことがある。レビューでは `::ffff:127.0.0.1` を許す要求が IPv4 の受け手へ届いた（下記の契約8）。扱いは設計者の判断待ちである |
| 数値風 host | 全ラベルが数字で始まり `[0-9a-fA-FxX]` だけの場合を名前として通さない。`127.1`・十六進・先頭0・`127.0x.0.1`・zone ID・IPvFuture・末尾ドット等の endpoint 形式の不良は Scope.InvalidTarget。既存の受理・拒否表を今回も通常入口で通した |
| 保持と通信 | URL の元の字面は元レコードに残す。Uri から fragment が落ちても保持内容を再構築しない。`ureq::DefaultResolver` は URI の authority と既定 port から OS の ToSocketAddrs へ渡す。型の対象は名前または IP と port であり、DNS の解決先・OS の全挙動・通信の成功を保証しない |
| Host と URI | `read_pairs` は要求の headers を読み、送信 builder に渡す。固定した ureq-proto の Host の検査は個数と文字列の形式を調べるが、任意の Host 値と URI の一致を保証するものではない。接続先を得る ureq の `run.rs` と resolver は URI を使う。レビューでは利用者指定の Host が wire の Host だけを変え、接続先は検査した endpoint のままだった。R30.4 で wire の Host と URI・実効対象を別々に確かめ、利用者の Host を許すか・拒否するか・記録するかを決める（下記の契約9） |
| 追従・proxy | 旧 agent は proxy(None) で環境 proxy を使わないが、最大10回追従する。RequestIn の保持だけでは、この旧経路の追加対象を防げない。非追従・一対象の観測は R30.4 の設定と実通信で閉じる |

endpoint の範囲に scheme は含まれない。同じ host/port は http と https の両方を覆い、固定 origin・認証情報・通信内容の流れや実行時の権限を制限しない。

## R30.4 への契約

1. `TargetTable.sendIn` と同じ `request: Http.RequestIn[H,P] -> Result[Http.Response, NetworkError] uses Http.Connect[H,P]` を登録する。範囲の列は endpoint 一つで、`IoShape::Single { kind: Endpoint, position: 0 }` の対象入力型から潜在効果と同じ列を得る。裸の型は Top。旧の前置きによる分類より明示の Single を優先する。
2. RequestIn は既存の三欄、ClientRequest は既存の五欄を使う。三欄を検査する読者を R30.4 で追加する場合も、射影と同じ Ctor/RECORD と欄数の検査を共有し、欄0の同じレコードを既存の `read_request` へ渡す。既存の `endpoint` は子モジュール内の非公開関数であり、新 IO 用の読者はまだない。必要な可視性や共通化は後続で行い、URL の規則を複製しない。
3. 送信用 URI の実効 host/port と保持した host/port は共通の代数で同じ対象と照合する。保持 endpoint を読み捨てて再解析の結果へ無条件に置き換える処理を置かない。名前の大小、IPv6 の字面・mapped IPv6、省略・空・ゼロ・先頭0付きの port は、字面の等号ではなく受理済みの実効対象として確認する。
4. `read_request`・`validate_request` の五欄の読取りと `PreparedRequest`、worker の Rust 所有データ、`send_done`→`complete` の応答処理を共用できる。旧 `make_agent` の max_redirects(10) をそのまま使わず、sendIn は3xxの応答を返して追従しない。proxy へ自動接続しない。追加対象を隠さず、契約8の単位で観測が検査した endpoint 一つであることを制御した相手で確認する。共用時は、誤りの報告に使う関数名を引数で渡す。現在の `http_client.rs` の `domain()` と `complete` は `send::DECL.name` を埋め込んでいるため、`sendIn` の読取り・応答処理からは `sendIn` の名前を渡し、送信準備・完了時の誤りを旧 `send` の名前で報告しない。
5. 検査時の RequestCheckError と、送信準備・通信時の NetworkError／既存の実行時エラー・資源停止を分ける。method・header・body・timeout の不良を checkRequestIn に移さず、保持の契約を変えない。
6. `Single` の直接呼出し、期待入力型を持つ関数値、期待型のない Top、PendingIo の実ソースを Http の本番署名で確認する。File の成功や R20.3b のテスト専用署名で代用しない。
7. 例・テスト・Skill の射影と拡大は `bind` の右辺へ置く。型の注釈だけから所属は得られない。狭い節の引数も入口に局所事実がないため、bind へ出すだけでは射影・拡大できないという File の結果を HTTP の実ソースで照合する。同じ狭い型での転送と、広い不変の型への転送は区別する。注釈のない検査が Top に決まった後の widen で狭められるとは説明しない。

8. 観測の単位は保持した endpoint（名前または IP と port。DNS と OS が変換する前の値）とし、ソケットの相手のアドレスの族や接続の試みの回数とは比べない。固定依存 ureq 3.4.2 の TCP 接続器（`src/unversioned/transport/tcp.rs` の `try_connect_with`）は、名前の解決で得た複数のアドレスへ順に接続を試みうる。レビューの実測では `LocalHost:18081` は IPv6 の受け手に接続し、`http://[::ffff:127.0.0.1]:18081/` はパターン `::ffff:127.0.0.1` で受理されて OS を通して IPv4 の受け手へ届いた。同じ URL はパターン `127.0.0.1` では拒否された。このため、`::ffff:0:0/96` や `::/0` のように IPv4 射影の IPv6 を許すパターンでも、IPv4 の宛先へ届きうる。根拠は変更していない [再現の台本](rv-probes/probe.bnt)・[受け手](rv-probes/server.py)・[実測出力](rv-probes/probe.out)・[受け手の出力](rv-probes/server.log)と [RV-R30.3 中2](../reviews/RV-R30.3.md#指摘)である。R30.4 の試験と 07-01 の保証の範囲へこの事実を申し送る。許すか・拒否するか・説明だけにするかは設計者に問うており、設計者の判断待ちである。本枝では決めない。
9. Host 欄と URI を独立の契約の項目とする。レビューの実測では `http://127.0.0.1:18081/` に利用者が `Host: evil.example` または `Host: 127.0.0.1:18082` を付けても、接続先は検査した `127.0.0.1:18081` のままで、wire の Host だけが指定値へ変わった（上記の実測出力・受け手の出力、[RV-R30.3 軽2](../reviews/RV-R30.3.md#指摘)）。R30.4 は URI と保持した endpoint の一致に加え、wire の Host と接続先を別々に照合し、`sendIn` で利用者の Host を許すか・拒否するか・記録するかを決める。本枝ではその扱いを確定しない。

## valContent と V-Checked の保証

Lean の `TargetTable.clientRequestTy` は `.data "Http.ClientRequest" []`、`valContent "Http.RequestIn"` はその型である。`ModelHttp.clientRequestDecl` の五欄と Rust の宣言順が一致し、`requestUrl`→`urlTarget parse` が欄1から `reqTarget` を得る。`checkRun` は閉じた要求を、動的な範囲 q・静的な範囲 r・対象の種類を検査したときだけ `.checkedRequest t req` として保持する。`valueRun` はその req を返す。`check_send_preserves` は、この成功値の保持・射影・応答関係の観測 `[t]` を示す。URL parser、実通信、Rust の全入力に対する保持の証明ではない。

交換の `valContents` は `RequestIn` の名前 `33:[]` から、ClientRequest の実データ型 `data:N` への対応を持つ。検査の第4引数、射影の戻り、dataDecls の五欄と型が同じ名前を指すことを、既存の `scope_tables::exports_request_content_as_the_same_record_type_in_declarations_and_signatures` で確認した。今回も1件成功した。これを Lean の本番全比較の成功とはしない。scopeAcceptance/limits の未接続と、Lean 読者が内容の宣言・二署名との一致まで検査するかの判断は K10.1、レコード構築・更新・欄参照と実対象の独立入力は K10.2/.3 に残す。

一般の V-Checked は `.checked t` に `Http.RequestIn` の型を付けうる。`valContent` の型があるだけではこの経路を排除しない。`ModelHttp.valueRun` は要求を持たない値に defaultRequest を返し、`firstTarget` は入力の target を読むため、形式化全体は「到達した RequestIn が全て要求を持つ」とは証明していない。

Rust の通常の型検査済みプログラムでこれを作らない保証は、利用者に構成子を公開しない型の登録、成功時に三欄を埋める唯一の `checked_request::check`、同じレコードを返す射影、同じ不透明値を返す widen、既存の構成子の追跡と VM／参照実行器の変換の組合せにある。射影の形の検査単独で真正性を保証するものでも、raw 呼出しへ任意の Ctor を渡す不正なホストを防ぐものでもない。Rust の対象保持を Lean の主定理や新しい Assumptions の欄へ移していない。

## H の引用と関係状態

本枝は Rust・標準宣言・Skill の生成元/生成物・入力・期待値・設定を一切変更していない。保持・確保順・根・障壁・安全点も変えないため、新しい H/H-full の実行条件に当たらない。07-03「結果の保存と引用」に従い、参照実行器の更新後に同じ四ターゲットを通した R30.1 の H を主な引用元とする。R20.0b/.3 は要求の保持と widen の初回の証拠として位置付ける。H の引用は HTTP の要求保持に関する範囲に限り、現行の File の追加や全テストに対する成功へ読み替えない。

| 引用の欄 | 保存した根拠と限界 |
|---|---|
| 主な引用元の状態 | R30.1 の基準/HEAD は `ddadf40d6d85b752717252c315cabe3f662c1cf8`。未コミット実装で H を実行し、保持の入力に影響しない R30.1b の文書・コメント更新を経て、実装は `c8d271825e600bfdb2c3a64ea3433a9b43759982` に取り込まれた。[R30.1 の結果](../r30.1/results.md#検査)と [R30.1b の引用判断](../r30.1/results.md#r301b-rv-r301-軽1軽5への対応)を用いる |
| 主な引用元のコマンド・結果 | `/usr/bin/time -p scripts/check.sh --level work --base ddadf40d6d85b752717252c315cabe3f662c1cf8 --only doc_default,heap_local,stress_local --test runtime_builtins --test vm_handlers --test io_modes --test l32_http_client`。[ログ](../r30.1/heap.log)・[計時](../r30.1/heap.json)は2026-10-29、終了0、外側139.761202333秒（time real 139.75秒）。通常doc17成功/失敗0/既存無視1、compile_fail17成功/失敗0。heap-verify/gc-stress は各53成功/失敗0/無視0/フィルタ除外0（io_modes11、l32_http_client9、runtime_builtins28、vm_handlers5）。部分選択を work 全体の成功としない |
| 主な引用元の環境・RSS | macOS arm64、Rust/Cargo 1.98.1。getrusage(RUSAGE_CHILDREN) の補助値は3,805,659,136 bytes（3,629.359375 MiB）。各子孫の最大値であり、同時常駐量の合計ではない。現行の環境は [environment.json](environment.json) |
| 主な引用元からの関係状態 | [R30.1b の照合](../r30.1/r30.1b-integrity.json)は署名・式・保持の入力を変えていない。実装コミットから B_WORK までの HTTP の保持・読取り、heap、参照実行器 `refinterp/convert.rs`、VM の IO 完了、l32_http_client・vm_handlers、manifest・二lock・固定版・check 道具の33ファイルと、保持・同一性・widen往復の3テストの一致を [関係状態の比較](r30.3b-h-comparison.json)に記録した。後続の File の追加で runtime_builtins・io_modes 全体は変わるため、H の全入力一致とはしない |
| 初回の状態 | R20.0b の基準/HEAD は `7220e886b6e1f8d15cb8e8855f1940d0af904de4`、R20.3 は `d8a640adad54aa13ff0baaebebab91b6cad59f85`。ともに未コミット実装で検査している。元の差分・未追跡入力は各枝の `implementation.patch`・`changed-files.json`・`final-state.json` 等に保存。R20.0b 後の数値風 host の修正は R20.0b2、widen と範囲の実行は R20.3 の記録で更新する |
| 初回のコマンド | 両枝とも `/usr/bin/time -p scripts/check.sh --level work --base <上記の各基準> --only doc_default,heap_local,stress_local --test runtime_builtins --test vm_handlers --test io_modes --test l32_http_client`。既定 doc と compile_fail、heap-verify/gc-stress の四ターゲット。フィルタなし。部分選択を work 全体の成功とは呼ばない |
| 初回の結果 | [R20.0b H](../r20.0b/heap.log)・[計時](../r20.0b/heap.json)は終了0、114.264280秒、doc34成功/失敗0/既存無視1、各特殊構成51成功/失敗0/無視0/フィルタ除外0。[R20.3 H](../r20.3/h.log)・[計時](../r20.3/h.json)は終了0、148.672640秒、doc34成功/失敗0/既存無視1、heap/stress 各53成功/失敗0/無視0/フィルタ除外0。各53の内訳は io_modes11、l32_http_client9、runtime_builtins28、vm_handlers5 |
| 初回の環境・RSS | macOS arm64、Rust/Cargo 1.98.1。元の環境は [R20.3 environment](../r20.3/environment.json)、現行は [environment.json](environment.json)。元 H の getrusage の補助 RSS は R20.0b=2,265,841,664 bytes（2,160.875 MiB）、R20.3=4,450,238,464 bytes（4,244.078125 MiB）。各子孫の最大値で、同時常駐量の合計ではない |
| 入力・道具 | 現行のソース・標準ソース・テスト/入力/期待値・生成元/生成物・交換器・manifest・二lockのうちルートlock・固定版・check 道具・設計書の一覧と SHA-256 は [inputs.json](inputs.json.gz)。元の変更ファイル63件との現行比較は [r20.3-input-comparison.json](r20.3-input-comparison.json)。元の63件と実装コミット `ecdb9e9d5ad1cb7de53b891b166bfeea86ec9a2e` の比較も [記録](r20.3-commit-comparison.json)にあり、49件一致/14件不一致である。全入力一致とはしない |
| 保持に影響しない理由 | `checked_request.rs` 全体は元の保存値 `bff1162ab4ca2526090d715f99babc758346d3fdff98401b54a6bc415d112544` と現行が一致する。実装コミットから HEAD の `runtime/heap`・`http_client.rs`・`http_client/`・`http_util.rs`・Cargo manifest/lock・固定版・check.sh/check-heap.sh の差分は空。要求の保持・同一性・widen往復の3関数は、元に保存されたテストファイルと一致する実装コミットの同じ関数に全て一致する（[関数別SHA-256](retention-tests-comparison.json)）。後の型推論・診断・File 登録・棚卸し・文書の変更を HTTP の保持表現の変更として扱わない |
| 橋渡しの補足 | 元の保存 patch に対し実装コミットの参照実行器は worker 完了へも同じ範囲の列を渡す更新を含む。要求の変換・構成子の保持・根・障壁を変える更新ではない。R20.6 の保持の再照合、上記の主な引用元である R30.1 の H、RV-R30.2 の不変条件の確認を併せて読む。今回の局所検査でも現行の両実行器の要求/widen往復を通した。古い H の全入力が同じだという根拠にはしない |
| 対象状態と判断 | 今回の基準/HEAD は冒頭の B_WORK、未コミット差分は設計書3章、R30.3b 開始時の未追跡は本ディレクトリの記録と RV-R30.3。R30.3 の差分・記録の SHA-256 は `state.json`・`record-files.json` に残し、R30.3b の開始状態は [r30.3b-before.json](r30.3b-before.json)、追補後の状態は [r30.3b-final.json](r30.3b-final.json)に分ける。判断者は R30.3b 担当 Codex、判断日は2026-10-29。HTTP の既存保持の証拠に限って引用し、新 IO の保持の変更を先取りして免除しない |

元の初回失敗と修正は各 results の記録を保つ。R20.0b は新規入力の構文等を直した後の H 初回が成功、R20.3 は raw 同一性テストの Value 比較等を修正した後の H が成功した。W-R の複数の失敗を H の失敗へ混ぜず、成功値だけで修正履歴を消さない。R30.4 で保持や安全点を越える保存を変えれば H、根等を変えれば H-full を同枝で再実行する。

## 探査・生成物・設計書

公開構造・公開 API・Program/IR/値型の表現を変えていないため、開始版 `6124775788579e60530f55fb85570f26ef7fa900` と B_WORK の計時探査のビルド・比較器の自己検査を新たに行う条件はない。`timing_probe.rs` と compare 配下も変更していない。過去の39件成功を本枝で実行した結果として数えない。short の性能比較は実行していない。

Skill の生成元となる構文・標準ソース・診断表を変更していないので、gen_skill は実行していない。R30.3 の保持・同一性・往復・交換の照合には既存テストを用い、テストを追加・変更しなかった。RV-R30.3 が指摘した観測の単位と Host/URI の契約の不足は R30.3b で上記の契約8・9に追記し、実装と試験は R30.4 へ渡した。公開の test-audit の作成時の関門を読み、重複テストやテスト専用の口を増やさないと判断した。

| 設計書 | 反映 |
|---|---|
| 03-09「クライアント」 | 純粋な URL/所属検査と送信時の method/header/body/timeout 検査の分担、旧 send へ射影しても一対象を保証しないこと |
| 02-09「メモリの管理」 | widen の同じ値、旧 send の五欄読取りと保持 endpoint を受け取らない境界、worker の所有値と応答だけの完了 |
| 07-04 | 保持レコードと valContent の現状、PathIn と RequestIn の古い「Top へ具体化」を呼び出しごとの確定した範囲（型の制約と規則で決まらなければ Top）へ修正、V-Checked を作らない保証の所在、実通信未接続の限界。該当段落の古い L40.3c という作業 ID も状態の記述へ置換 |

02-08 の三欄・五欄・widen と参照実行器の説明、07-01 の endpoint と保証の範囲は現在の実装に合うため変更していない。設計書に新しい作業 ID、未来の公開 API、改造ディレクトリへのリンクを加えていない。既存の他の作業 ID の整理は R30.5 の割り当てを保つ。

## 検査

[run_logged.py](run_logged.py) は `/usr/bin/time -p` の内側で対象を実行し、直後の `command_exit` をログに書いて同じ終了を返す。各 JSON の command が正確な引数列であり、外側の時間は実行器の monotonic 時計、RSS は macOS の getrusage(RUSAGE_CHILDREN) の補助値である。time -l は使わない。

| 実行と記録 | 成功/失敗/無視/フィルタ除外 | 終了 | 外側秒 | RSS 原値 bytes / MiB |
|---|---|---:|---:|---:|
| [局所HTTP](local-http.log)・[計時](local-http.json): `cargo test -p benitoite --test runtime_builtins http_request_in_ -- --nocapture` | 2/0/0/27 | 0 | 6.182279 | 1,455,013,888 / 1,387.609375 |
| [局所widen](local-widen.log)・[計時](local-widen.json): `cargo test -p benitoite --test runtime_builtins scoped_widen_calls_round_trip_through_both_evaluators -- --exact` | 1/0/0/28 | 0 | 0.509488 | 78,004,224 / 74.390625 |
| [局所交換](local-exchange.log)・[計時](local-exchange.json): `cargo test -p benitoite --test desugar_export exports_request_content_as_the_same_record_type_in_declarations_and_signatures` | 1/0/0/44 | 0 | 2.378279 | 699,924,480 / 667.5 |
| [W-R dry-run](work-dry-run.log)・[計時](work-dry-run.json) | 文書のみ、検査選択なし | 0 | 0.109984 | 11,845,632 / 11.296875 |
| [W-R](work.log)・[計時](work.json) | 文書のみ、検査選択なし | 0 | 0.104781 | 11,730,944 / 11.1875 |

作業末の指定は次のとおりであり、dry-run の後、実行は一度だけ行った。

```sh
/usr/bin/time -p scripts/check.sh --level work --base 42d22f72f0e1719f39d26abb9fa75c95d1b1f2ab --dry-run
/usr/bin/time -p scripts/check.sh --level work --base 42d22f72f0e1719f39d26abb9fa75c95d1b1f2ab
```

dry-run は9変更ファイル、実行は追加した記録を含む13変更ファイルを認識し、ともに `nothing to check: only documents changed` とした。基準と指定は同じで、テスト・clippy・fmt の全件を走らせたとは報告しない。W-R の time の real/user/sys は0.10/0.03/0.17秒、check.sh 自身の `command_exit=0` である。局所widenと交換の実行は work の後になったが、途中・以後とも実装・入力・期待値を変更しておらず、work の判定を古くしていない。

最大常駐量は上表の各実行の子孫の最大値であり、並行プロセスの合計ではない。W-R はビルドしなかったため小さく、コンパイラの常駐量としては扱わない。今回実際に動かした検査の最大の補助値は局所HTTPの約1.355 GiBである。既存テストの内部で両 IO 方式と VM/参照実行器を比較したことを、別の Rust テスト件数へ数え直していない。lake build・check-formal.sh・Miri・性能比較は実行していない。

## 初回の失敗と修正

局所テストと作業末の check.sh は全て初回成功だった。文書更新用の最初の Python stdin は文字コード宣言がなく SyntaxError（終了1）となり、変更前に停止した。apply_patch と UTF-8 宣言を付けた入力で修正した。探索の一部も存在しない候補パスと zsh の未一致 glob で失敗したため、実在する `tests/desugar_export/`・`vm/dispatch/tasks/io.rs` を読み直した。これらをテストの成功や比較の成功に数えない。docs.rs の取得失敗は URL 節のとおりである。

## 計画との差・停止条件・申し送り

保持の変更がなく、純粋 API と URL parser を再実装しなかった。文書だけの自動選択になったこと、局所確認2件が work 後になったこと以外に検査の割り当ての変更はない。同じ要求/endpoint の保持不能、Lean と違える受理、主定理・Assumptions・保証の変更、依頼範囲外の編集を要する停止条件には該当しない。

| 後続 | 残す作業と条件 |
|---|---|
| R30.4 | 上の九項目を使い、三欄/五欄と実効対象の読者・Single の本番署名・非追従・proxy・Host/URI・mapped IPv6・PendingIo・完全/部分ハンドラを接続し、制御した相手で実通信を閉じる。保持を変えたら H を省かない |
| R30.5 | R20S が加えた bind の形、狭い節引数、七操作の形・件数・全ハンドラ・予算・IF/LR-U5/U7/U8 を再照合する。今回の対象保持を固定 origin や情報フロー制御の証拠にしない。01-06 の位置の規則は R30.1 で追随済みで、07-04 の残る作業 ID は同枝の担当を保つ |
| K10.1/.2/.3 | valContents と dataDecls/二署名の照合の判断、scopeAcceptance/limits、URL/endpoint の独立入力、レコードの構築・更新・欄参照、Rust/Lean の全比較を閉じる。V-Checked の形式化の限界と reqTarget/parser の信頼境界を残す |
| 取りまとめ | 要求の引渡しの独立レビューを R30.4 の前に閉じる。本枝の自己確認と既存レビューの参照を、その独立レビューや設計者の受け入れの代わりにしない |

外した構成・32ビット・OS 全挙動・外部ハンドラ件数を確認済みとしない。実装と依存方向を変えていない。一時ビルドや基準版の展開を target の外へ作らず、新しい CARGO_TARGET_DIR も作っていないため、今回の削除対象はない。記録のログは保存前に `<wt>`・`<home>` へ伏せた。

## 時間

開始は2026-10-29 05:27:07 UTC（14:27:07 JST）。終了は同日05:37頃 UTC（14:37頃 JST）、外側の所要は約10分である。最終の時刻と自己確認は [state.json](state.json) に記録した。能動時間は読解・照合・文書と証拠の整理で約10分の概算であり、厳密に個別計時していない。検査実行は計約9.3秒で、一部は読解と重なる。能動時間・外側とも2時間の停止条件に達していない。


## R30.3b: RV-R30.3 への対応

2026-10-29。RV-R30.3 の「対応（取りまとめ）」で割り当てられた文書修正と後続への契約追記を行った。実装・テスト・依存・Lean・生成物は変更していない。

| 指摘 | 対応 |
|---|---|
| 中1 | 07-04 の PathIn の段落を、呼び出しごとの確定した範囲へ具体化し、型の制約と局所解析の規則で決まらなければ Top とする説明へ修正した。RequestIn の段落、03-06・03-09 と整合する。同章の Top と具体化を併記する他の段落も点検し、一律 Top とする古い説明はほかになかった |
| 軽3 | 02-09 の旧 `Http.send` の説明を「渡されたレコードの五欄を」へ修正した |
| 軽4 | 07-04 を「Rust の処理系は、保持した endpoint を受け取る送信の操作を持たない」という現状の説明へ修正した |
| 中2 | 契約8に観測の単位、名前の複数のアドレスへの接続試行、IPv4 射影の IPv6 の実測と設計者の判断待ちを記した。R30.4 の試験と 07-01 の保証の範囲へ申し送った |
| 軽1 | 契約4に、共用する読取り・完了処理の誤りの報告へ関数名を引数で渡す条件を加えた。現在の `domain()` と `complete` の埋込みは変更していない |
| 軽2 | 契約9に Host 欄と URI の照合、wire の Host だけが変わった実測と、利用者の Host の扱いを R30.4 で決める条件を記した |
| 軽5 | H の主な引用元を R30.1 へ変え、R20.0b/.3 は保持の初回の証拠とした |

R30.3 の state.json・record-files.json・implementation.patch は元の照合時の証拠として保ち、R30.3b の記録は接頭辞 `r30.3b-` で追加する。レビュー記録と再現の台本・出力は変更しない。

### R30.3b の検査と完了

指定の `scripts/check.sh --level work --base 42d22f72f0e1719f39d26abb9fa75c95d1b1f2ab --dry-run` を、既存の run_logged.py から `/usr/bin/time -p` で包んで一度実行した。[ログ](r30.3b-work-dry-run.log)・[計時](r30.3b-work-dry-run.json)は終了0、外側0.107927875秒、time の real/user/sys は0.10/0.03/0.18秒である。文書だけの31変更ファイルを認識し、`nothing to check: only documents changed` として検査を選ばなかった。追加の Rust の実検査は行っていない。補助 RSS は macOS の getrusage(RUSAGE_CHILDREN) の11,747,328 bytes（11.203125 MiB）であり、ビルド時の常駐量を表さない。

相対リンクと見出しへの参照を [照合記録](r30.3b-links.json)で確かめた。設計書3章の見出しは HEAD と同じである。`git diff --check` も終了0だった。レビュー記録と再現の台本・出力の5ファイル、HEAD・ブランチ・index の開始時からの不変性、追補後の差分と記録の SHA-256 は [最終記録](r30.3b-final.json)に残す。既存の03-09の差分もそのまま保った。

補助確認の初回では、H の比較用にテスト関数の次の属性までを切り出したため、後続の追加箇所も含めて一致判定が失敗した。トップレベルの関数の閉じ括弧までへ切出しを直し、3関数とも一致した。最初のリンク確認ではインラインコードをリンクと誤認し、作成前の最終記録も未存在と報告したため、コードを除外し、記録を置いて再確認した。探索に存在しない `work/` を含めた際の終了2も、対象を明示して調べ直した。いずれも処理系の変更や検査の失敗ではない。

R30.3b の割当ては完了した。IPv4 射影の IPv6 の扱いは設計者の判断待ち、利用者の Host の扱いは R30.4 の判断事項として残した。lake build・check-formal.sh・short は実行していない。target 外の一時ビルド・基準版の展開、新しい CARGO_TARGET_DIR は作らず、削除対象もない。停止条件には該当しない。

R30.3b の開始は2026-10-29 05:47:22 UTC（14:47:22 JST）、完了記録は05:52:00 UTCで、外側所要は約4.6分、能動時間も約5分の概算である。指定 dry-run の待ちは約0.11秒で、追加の測定・独立レビュー・設計者の回答待ちはない。1時間の停止条件には達していない。R30.3 の時間と検査は前の節に残した。
