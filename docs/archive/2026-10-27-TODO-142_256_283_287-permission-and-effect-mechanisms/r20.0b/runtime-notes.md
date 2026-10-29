# 要求の実行本体と局所検査の記録

純粋な `Http.checkRequestIn` と `Http.requestInValue`、`Http.RequestCheckError` を同時に登録した。`builtins/table.rs` の範囲変数の経路へ二入口を加え、既存の三つの読者に接続した。裸の `Http.RequestIn` の注釈の追加は、標準宣言二箇所だけである。`Http.bnt` の `checkRequestIn` の戻り値と `requestInValue` の引数がそれに当たる。新しいテストの裸の注釈は0箇所である。R20.3 は標準宣言二箇所と通常の利用側の範囲の具体化を改訂する。

`http_client/checked_request.rs` を追加した。既存の `Ctor` の三欄に、検査した同じ `ClientRequest` の値・正規化した実効ホストの文字列・ポートの整数を保持する。要求の五欄を作り直さず、射影は元の値を返す。既存の `ValueCtx` の区間内で確保する。安全点・根・障壁・GC の不変条件は変えていない。新しい組み込み番号は `funcs::PARTS` の末尾に加え、以前の番号を保つ。

URL の解析には既存の送信と同じ固定依存の `ureq::http::Uri` を使う。省略・空の port は80/443である。`Authority::port()` は不正な port にも `None` を返すため、生の authority の host の後の部分を別に読み、全数字と `u16` の変換成功を要求する。条件の整数には R10 の `Port::from_int` と `PortRange::new` を使う。host のパターンと条件の読み取りは `checked_scope::endpoint_pattern` に置いた。後続の静的判定もこの入口を使う。

生の非ASCII・URIの文字でない字面・不正な `%`・userinfo・非対応scheme・authority/host空・不正portは `InvalidUrl` とする。fragmentは受理し、元のURLを保持するがendpointに含めない。取得したhostをR10の領域で読めない場合、非正規IPv4、短縮数値（`127.1`・`123`・`0x7f000001` 等）、末尾dotの名前は `Scope.InvalidTarget` とする。IPv6は標準の数値解析で読み、R10の数値へ移す。mappedはIPv6のまま保持する。Scopeの直接入力と既存sendの受理集合は変えていない。URIの一次資料と固定依存の調査は取りまとめが担当する。

## テストの作成時の関門

`runtime_builtins::http_request_in_checks_endpoints_and_retains_the_same_request` は、通常ソースの検査→同じOkの保存→安全点→射影→五欄の参照と、成功9行・失敗29行の独立した表を守る。静的Topを理由とする検査の省略、既定portの取り違え、IPv6の正規化忘れ、整数の切り詰め、同じ要求の保持の消失で失敗する。既存sendのテストは新しい純粋入口を通らない。両IO方式と既存のVM/参照実行器をつなぎ、差し込み口を加えていない。射影したレコードの更新は元のRequestInを変えず、変更したURLの再検査で失敗することも確かめる。

`runtime_builtins::http_request_in_projection_returns_the_original_record_object` は、公開の組み込みの本番の表と `same_object` でレコードの同一性を守る。言語の構造的等値では同値のレコードの再構築を区別できないため、この契約だけを別に確かめる。新しい本番の差し込み口は加えていない。

既存の `resolve::tests::stdlib_source_and_table_contracts` に六タグを足し、宣言の構成子名・タグと本体の定数を照合する。既存の `builtins::table::tests::table_names_parts_capabilities_and_schemes_are_consistent` の件数も入口+2（514入口、純粋439）へ追随した。

## 局所検査と初回の失敗

| コマンド | 結果 |
|---|---|
| `cargo test --test runtime_builtins scope_path_in_checks_dynamic_inputs_and_preserves_the_same_ok --no-run` | 終了0。コンパイル6.62秒 |
| `cargo test --test runtime_builtins http_request_in -- --nocapture`（初回） | 終了101。表の最大整数の型がRustの既定i32になり溢れた。i64接尾辞を加えた |
| 同上（2回目） | 終了101。same_objectは成功。通常ソースのレコード更新を存在しない `with` の形で書いたため構文診断になった。既存構文 `Http.ClientRequest(..projected, url: ...)` に直した |
| 同上（3回目） | 終了0。2成功、失敗0、無視0、除外24。コンパイル2.89秒、テスト0.54秒 |
| `cargo test --lib table_names_parts_capabilities_and_schemes_are_consistent -- --nocapture` | 終了0。1成功、失敗0、無視0、除外1379。コンパイル14.82秒、テスト0.01秒 |
| `cargo test --lib stdlib_source_and_table_contracts -- --nocapture`（初回） | 終了101。追加したタグの名前に標準モジュールの `Network.` を落とした。`Network.Http.RequestCheckError.*` に直した |
| 同上（2回目） | 終了0。1成功、失敗0、無視0、除外1379。コンパイル3.94秒、テスト0.15秒 |
| `cargo fmt --all` | 終了0 |
| `git diff --check` | 終了0 |

上の秒数はCargoの出力であり、外側の計時ではない。局所検査のRSSは計測していない。端末に返った出力から保存できた部分を [runtime-local.log](runtime-local.log) に残した。最初の構文診断の全量をファイルへ捕捉しておらず、その旨をログに記した。W-R/Hの生ログ・外側の時間・RSSと最終の検査は取りまとめの担当である。

標準宣言の `RequestCheckError` の最初の記述も、構成子の引数を `message: String`・`error: ...` と書いて構文エラーになった。交換担当の局所検査が捕捉し、既存構文の `InvalidUrl(String)`・`Scope(Scope.ScopeError)` に直した。ログは交換担当が保存した `export-unused.log` である。

`rtk cargo ...` は警告だけを返してCargoを実行しなかったので、その後はCargoを直接実行した。追加の `CARGO_TARGET_DIR` や `target/` 外の一時ビルドは作っていない。状態を変えるgit操作も行っていない。後続の送信側は、保持した三欄の要求とendpointをそのまま使い、URL解析のやり直しで対象を取り替えない必要がある。
