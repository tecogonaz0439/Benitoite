# IF20.07: ソース読解の補足

読解対象の HEAD は `d94d970baca8b21c2d33a62f3380c3562fb0cc57` である。処理系のソースは変えていない。以下は実行による再現ではなく、分岐と値の受け渡しを読んで確かめた結果である。

## F24 closeReader の待ちと完了値

通常の待ちから復帰する経路でも、完了値は即時と同じ `Result.Ok(())` になる。根拠は次の受け渡しである。

| 段階 | 読んだ位置と結果 |
|---|---|
| 待ちの開始 | [file.rs](../../../../crates/benitoite/src/builtins/funcs/file.rs) の `close_reader` は `begin_release` が返した待ちをそのまま返す。[vm/state.rs](../../../../crates/benitoite/src/vm/state.rs) の `begin_release` は `AfterReturn`・`InProgress` で `StateWait::Resource` を返す。通常の Reader に Writer と同じブロック解放の仕事を作る分岐はない |
| 命令の保存 | [vm/dispatch/tasks.rs](../../../../crates/benitoite/src/vm/dispatch/tasks.rs) の `dispatch` は `cursor.locals.save` 後に `WaitReason::Release` で `park` する。`park` は `Control::Return` を返す。[vm/dispatch.rs](../../../../crates/benitoite/src/vm/dispatch.rs) のループは `Control::Next` の場合だけ次の命令へ進めるため、待った命令位置が残る |
| 貸出しからの返却 | [runtime/io/resources.rs](../../../../crates/benitoite/src/runtime/io/resources.rs) の `give_back` は資源を返して `Open` にし、解放要求があったかを返す。[ops.rs](../../../../crates/benitoite/src/runtime/io/ops.rs) の `accept_completion` が `Accepted::StartRelease` に変換する |
| 解放と起床 | [tasks/io.rs](../../../../crates/benitoite/src/vm/dispatch/tasks/io.rs) の `boundary` は `StartRelease` で `request_release` を呼び、完了を `finish_release` に記録して `wake_all(WaitReason::Release(id))` する。Reader の `FileReader::release` は drop 後に `Ok(())` を返し、OS close の失敗を値へ変換しない |
| 通常の復帰 | `tasks.rs` の `restore` が枠を戻す。同じ命令の再実行で `begin_release` は `AlreadyReleased` を処理して `None` を返す。`close_reader` の `None` の分岐が `Result.Ok(())` を構築する。待ちそのものが `Unit` を結果へ書く経路ではない |
| 残る未確認 | [tasks/cancel.rs](../../../../crates/benitoite/src/vm/dispatch/tasks/cancel.rs) の `request` は解放待ちを直ちに起こさず、`restore` 後の `begin` が取り消しを処理する。停止・取り消しが競合する場合の実際の順序や、OS・特殊ファイルごとの振る舞いは実行していない。U-F04・U-F07・U-R03 を維持する |

したがって F24 の方向「出口」と候補「未対応で拒否」は維持した。これは資源と制御依存の契約が未接続であるための候補であり、通常の完了値が未知だから拒否する意味ではない。

## 誤りの文言の全文

五つの未確認事項は閉じない。今回再読したのは、処理系が文言を作る箇所と、外部由来の文字列を保存・転送する境界である。OS・依存・入力条件ごとの全文を列挙できたという結果ではない。

| 行 | 再読して確かめた範囲 | 未確認として残す範囲 |
|---|---|---|
| U-F02 | [file.rs](../../../../crates/benitoite/src/builtins/funcs/file.rs) の `IoFailure::from` は `io::Error::kind()` と `error.to_string()` を保存する。[io_error.rs](../../../../crates/benitoite/src/builtins/funcs/io_error.rs) の `message` は保存した文字列を返す。専用のパス欄はない | OS ごとの文言、ロケール、失敗条件、特殊ファイルによる全文とパス等の混入 |
| U-H04 | [http_client.rs](../../../../crates/benitoite/src/builtins/funcs/http_client.rs) の `classify` と送受信の誤りの分岐は依存の `to_string()` を保存する。[network_error.rs](../../../../crates/benitoite/src/builtins/funcs/network_error.rs) の `message` は保存した文言を返す | DNS・TLS・証明書・接続・Location 等の異常ごとの全文、URL・ヘッダー等の混入と OS 差 |
| U-CP04 | [process.rs](../../../../crates/benitoite/src/builtins/funcs/process.rs) の `execute`・`join_pipe`・完了処理は File と共通の `IoFailure` を使う。事前検査の固定文と禁止する環境変数名の文言は OS の文言と別である | 起動・wait・パイプ・出力の失敗の全種類と、パス・環境等の混入 |
| U-D02 | [json.rs](../../../../crates/benitoite/src/builtins/funcs/json.rs) の `parse` と [time.rs](../../../../crates/benitoite/src/builtins/funcs/time.rs) の `parse_i_s_o8601` は依存の `to_string()` を言語の誤りへ渡す。IOError/NetworkError の表示は保存した文言を使う | 依存の全失敗条件で入力・URL・文字の断片が混ざるか、各入力での実出力 |
| U-FE03 | [runtime/panic.rs](../../../../crates/benitoite/src/runtime/panic.rs) の `record` は文字列 payload を保持し、非文字列なら固定表示とする。位置と採取できた backtrace も保持する。`catch` が記録を取り出す。ホスト報告へ渡す文言を、機密情報を含まない定数とは扱えない | panic payload・trap・OS の理由・backtrace の全内容、全 API と全失敗条件での混入。捕捉外の終了の全文も H09・U-FE06 に残す |

全文が未確認であることを、文言が公開である根拠にしない。実行を伴う再現は 0.0.14 または接続を閉じる改造の実装・レビュー担当へ渡す。

## Assert・表示・ログ・構築器の照合

[runtime/assert.rs](../../../../crates/benitoite/src/runtime/assert.rs) の `evaluate` は equal/notEqual の成立時と isTrue の true 時に `AssertVerdict::Passed` を返す。個別の成功行を出す処理はなく、テスト単位の報告は IF20.05/T10 に対応する。A01・A03 に加え、同じように読める A02 もこの粒度へそろえた。

[string.rs](../../../../crates/benitoite/src/builtins/funcs/string.rs) の `to_uppercase`・`to_lowercase` と四つの `display_width_pad_*` を読んで、変換と補充する位置を分けた。[log.rs](../../../../crates/benitoite/src/builtins/funcs/log.rs) の既定 `emit` は Debug を破棄し、他の水準を整形して LF とともに stderr へ書く。[Log.bnt](../../../../crates/benitoite/src/prelude/stdlib/Log.bnt) の各ラッパーは、外側の emit・Console の stderr・各 sink の別を表に反映した。[resolve/builders.rs](../../../../crates/benitoite/src/resolve/builders.rs) には `STRING_OPERATIONS` に加え `LIST_OPERATIONS`・`BYTES_OPERATIONS` があるため、G03 の位置へ追記した。
