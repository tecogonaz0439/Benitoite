# sendIn の実行と保持の照合

## 登録と同じ要求の読取り

`Benitoite.Network.Http.sendIn` を Connect の新しい操作として登録した。既存の組み込み番号を変えず、`funcs::PARTS` の末尾へ `http_client::SCOPED_DECLS` を追加する。登録表では対象位置0を `RequestIn[rvar 0]`、形を `Single { kind: Endpoint, position: 0 }` とし、同じ範囲変数を `Connect[rvar 0]` に入れる。旧 send は `TopTargeted(Endpoint)` のままである。これは `Release/TargetTable.lean` の `sendIn`・`ioIn` の入力・効果・種類・位置に一致する。`widenRequestIn` の列 `[R,S]` と `Covers { outer: 1, inner: 0 }` は変えていない。

`checked_request::request_value` は射影と送信が共有する読者である。Ctor/RECORD と三欄を確かめ、欄0の五欄の ClientRequest を返す。`retained_request` は同じ欄0に加えて、欄1の正規化 host と欄2の port を読む。`read_request` にはその欄0の同じ Value を渡し、method・url・headers・body・timeoutMilliseconds を読む。要求の作り直し、別のレコードの選択、保持 endpoint の置換は行わない。

送信準備で URI の endpoint を純粋な検査と同じ `endpoint` の解析から求め、保持 endpoint と構造等号で照合する。非追従の resolver も OS の解決へ渡す前にこの照合を通す。保持値の内部不整合は通常の BNT から作れないため Internal とする。入力から生じる Host の不正・不一致は NetworkErrorKind.InvalidInput として返す。`RequestCheckError` には IO の失敗を加えていない。

## 非追従・proxy・Host

旧 send は最大10回の追従を保つ。sendIn の agent は最大0回、状態コードをエラーへ変えない設定であり、3xx の応答を返す。環境の proxy を既定値から取り込まないよう、両入口とも明示的な `proxy(None)` を保つ。

sendIn の明示 Host は一個だけを認める。全体を `http::uri::Authority` として解析した後、URI と同じ scheme の実効 host/port を共通の endpoint 解析で求め、保持 endpoint と照合する。`Authority::create_authority` は入力全体の消費を要求し、`/`・`?`・`#` 以後を無視して通さない。userinfo は共通の endpoint 解析が拒否する。名前の大小・IPv6 の字面・省略時の port・先頭0付き port を、字面の等号だけで比べない。Host の省略時は送信器の補完を使う。旧 send の Host の扱いは変えていない。

`redirect_body::CheckedTransport` の予備解析は追従時の読み捨てる本体を検査する処理である。最大0回ではこの予備解析を使わず、3xx の本体も通常の `read_limited` に渡す。この分岐により、非追従の本体の上限超過を追従時の読み捨て用の Other へ変えない。旧 send の予備解析は従来どおり働く。

対象の単位は保持した endpoint（DNS と OS の変換前の名前または IP と port）である。DefaultResolver は URI の authority と既定 port から名前解決を行い、複数のアドレスを返しうる。TCP 接続器も複数の解決先を試みうる。ソケットの族や試行回数を一対象の観測数と比べない。対象入口に既にある IPv4 射影の IPv6 の拒否を保ち、本枝で範囲代数を変えていない。

## worker と VM の根

worker のクロージャが所有するものは `Request<Vec<u8>>`、`Duration`、`Vec<&'static str>`、`Option<Endpoint>`、関数名の `&'static str` だけである。応答も status・所有するヘッダ文字列・本体の Vec、または Failure と関数名だけである。`Value`・`ValueCtx`・VM・IoCtx を捕捉しない。`iface.rs` の `WorkerWait::new` は仕事と結果に `Send + 'static` を要求し、完了は環境を捕捉しない `CompleteFn` の関数ポインタである。待ちの指定は既存の `Lend::Nothing` を使う。

VM の `dispatch/tasks/io.rs::publish` は呼び出し命令を保存して park する。引数は待っているタスクのレジスタに残り、`args` が保存した命令の引数位置から読み直す。`submit` は仕事とホスト側の指定を worker へ渡し、タスクと命令の参照を OpRecord に記録する。完了時も同じ引数と範囲の列を読み、完了関数へ渡してから `write_result` が結果を置き、命令位置を進める。

根の経路は `RunState::trace` → TaskTable/TaskObj → TaskStack → Segment のレジスタ → RequestIn の既存の Ctor 三欄 → 同じ ClientRequest の Ctor 五欄である。既存の `TaskObj::trace`・`Segment::trace` はレジスタを走査する。送信本体はこの経路も、根・障壁・安全点・GC の不変条件も変えていない。参照実行器の組み込み呼び出し一般も既存の `call_builtin_scoped` を使い、同じ epoch の中で worker を完了させ、同じ引数と範囲の列を完了へ渡す。ただし、参照側は意図的に VM の `runtime_view` を公開しないため、HTTP の実通信自体は旧 send も新 sendIn もこの実行の対象外である（[調査の根拠](type-handler-notes.md)）。

H の適用について、差分だけを根拠にすれば既存の表現・保存経路を使うため新しい保持機構の変更はない。一方、今回は新しい IO がこの経路で待つ接続を加えるので、取りまとめは H の doc・局所 heap-verify・gc-stress を実行する。H-full の条件となる確保の規則・根・障壁・GC の不変条件の変更はない。H の成功を本書の読解だけで代用しない。

## 依存の一次資料と局所確認

固定した registry のソースを読み、ネットワークから資料を取得していない。ファイルの相対識別子・SHA-256 と照合箇所は [runtime-sources.json](runtime-sources.json) に残した。`ureq 3.4.2` の config.rs の `max_redirects_do_error` と run.rs の分岐は、最大0回で追従も TooManyRedirects も起こさず応答を返すことを示す。config.rs の `proxy` の setter は None を保存し、run.rs の解決先の分岐がこれを使う。DefaultResolver と TCP 接続器の読解の限界は前節のとおりである。

局所確認は `cargo test -p benitoite --lib builtins::funcs::http_client::tests -- --nocapture` を一度実行し、初回から終了0であった。7件成功、失敗・無視0件、フィルタ除外1,407件である。[ログ](runtime-http.log)・[計時](runtime-http.json)・[time -p](runtime-http-time.log) を残した。check_exit_code=0、外側26.41676075秒、補助 RSS は3,278,127,104 bytes（3,126.265625 MiB）である。既存の直接呼び出しは共用処理へ渡す関数名と、resolver の任意 endpoint の None を追加して追随した。新しい単体テストは加えず、実通信と型の契約はそれぞれの持ち主の通常入口で確認する。

git の状態を変える操作、Lean・依存・scripts の変更、target 外の一時ビルド、新しい CARGO_TARGET_DIR は行っていない。
