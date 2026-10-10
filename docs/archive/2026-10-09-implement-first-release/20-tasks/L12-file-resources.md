# L12 `File` のリソースの関数

- 依存する作業: [L11](L11-file-operations.md)、[R24](R24-resources.md)
- 難易度: 3（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行。テストを含む）
- ブランチ: impl/L12-file-resources

## 目的

ファイルを一定の大きさずつ読む `File.readChunk` と、ファイルを書くためのリソースの型 `File.Writer` の関数の本体を書く。10-15 の部分 33（`file::RESOURCE_DECLS`）である。`File.Writer` の解放は、書いた内容を書き出してから閉じるブロックする解放であり、R24・R26 が作った解放の仕事の受け渡しを初めて使う。

| 項目 | 権限 | エフェクト |
|---|---|---|
| `File.readChunk` | `Io` | `File.Read` |
| `File.openWriter`・`write`・`writeLine`・`writeChunk` | `Io` | `File.Write` |
| `IO.File.closeWriter` | `State` | `State` |

依存の理由: `File.Reader` の `OsResource`（R29）と、ファイルの操作の誤りの対応（L11）を使う。`File.Writer` の解放は、R24 の `request_release` のブロックする解放の分岐と、R26 の解放の仕事の受け渡しを使う。

## 読む設計書の節

- [IO のモジュール](../../2026-10-09-design-first-release/03-interop/03-07-io-modules.md)の「File」の `File.Reader`・`File.Writer` の表と箇条（権限を開くときに一度だけ判定すること、`with` の解放、解放したリソースの使用、`maximumBytes` の範囲）
- [リソース管理](../../2026-10-09-design-first-release/01-spec/01-10-resources.md)の「解放の失敗」「解放したリソースの使用」
- [ランタイム](../../2026-10-09-design-first-release/02-impl/02-09-runtime.md)の「リソースの追跡」（リソースの型ごとの解放）、「組み込みの操作とハンドラ表」
- ADR: [0150](../../2026-10-09-design-first-release/decisions/0150-resource-release-as-state.md)、[0266](../../2026-10-09-design-first-release/decisions/0266-task-and-resource-state-machines.md)、[0067](../../2026-10-09-design-first-release/decisions/0067-with-resource-scope.md)、[0321](../../2026-10-09-design-first-release/decisions/0321-close-functions-return-release-failure.md)

インターフェース:

- [標準ライブラリの追加](../10-interfaces/10-15-stdlib-additions.md)の「IO のモジュール」の表、`IO/File.bnt` に加えた宣言（`WriteMode`・`closeWriter`）、「構成子のタグ」の `FILE_WRITE_MODE_*`
- [組み込みの関数の型付きの形](../10-interfaces/10-11-builtin-interface.md)の `OsResource`・`Lend::Resource`・`IoServices::register_resource`・`StateServices::begin_release`
- [IO とネットワークの追加](../10-interfaces/10-16-io-and-network-additions.md)の「close の関数が解放の失敗を受け取る口」（`StateServices::begin_close`・`CloseStep`）
- [スケジューラと IO 実行器](../10-interfaces/10-10-scheduler-and-io.md)の「リソースの表と状態」「外部の操作の記録と完了」のブロックする解放の仕事の受け渡し
- R24 の作業の文書の `request_release` の種類ごとの表（`FileWriter` はブロックする）、R29 の `File.readLine`・`IO.File.closeReader`

## 作るもの

- `src/builtins/funcs/file.rs` の `RESOURCE_DECLS` の 6 項目の本体と単体テスト
- `File.Writer` の `OsResource` の実装（`file.rs` の中の非公開の型）
- `src/builtins/iface.rs` に、10-16 の `CloseStep`（`StateWait` の後）と `StateServices::begin_close`（`trait StateServices` の末尾）を、10-16 のブロックのとおりに書き足す。既存の型とシグネチャは変えない
- `src/vm/state.rs` の `Stage1StateServices` に、`begin_close` の上書きと、そのテスト
- C01 の `iface.rs` と R25 の `vm/state.rs` を本作業が改めるのは、ADR 0321 の帰結として本作業に割り当てた範囲であり、上の二つに限って、[作業の進め方](../00-common/00-03-workflow.md)の「ほかの作業のファイルを変える必要が生じたら、作業を止めて報告する」に当たらない

## 手順の要点

- `File.readChunk(reader, maximumBytes)`: `maximumBytes` が 1 未満なら実行時エラー（`ArgumentOutOfDomain`。引数の位置は 1）とする（03-07 の箇条）。`Lend::Resource` で `File.Reader` を借り、最大 `maximumBytes` バイト（ただし `Bytes` の上限を超えない）を読む。一度の read で短く返っても終えず、上限かファイルの終わりに達するまで読む（`take(n).read_to_end` の形）。`maximumBytes` の分の領域を先に確保しない（巨大な値でメモリを使い尽くさないため）。一バイトも読めずにファイルの終わりなら `Option.None`。`File.readLine` と同じリーダーの読みかけの内容（`BufReader` のバッファ）から続けて読む。
- `File.openWriter(path, mode)`: `mode` のタグで、`Replace` なら作るか空にし、`Append` なら末尾に加える形で開く。作業用のスレッドで開き、完了の処理で `register_resource(ResourceKind::FileWriter, 資源, site)` で表に加える。
- `File.Writer` の `OsResource`: `BufWriter<File>` を持つ。`release` は、書き出し（`flush`）の後に `sync_all` を行わずに閉じ、書き出しの失敗を理由の文字列で返す。`sync_all` を行わないのは、03-07 が「書いた内容を書き出してから閉じる」とだけ定め、ディスクへの同期を求めていないからである。この判断を `///` のコメントに書く。
- `File.write`・`writeLine`・`writeChunk`: `Lend::Resource` で借りて書く。書きの失敗は `IOError` の `Result.Error`。`writeLine` は `text` と LF を書く。
- `IO.File.closeWriter`（`State`）: `StateServices::begin_close`（10-16、ADR 0321）で解放を始める。`CloseStep::Wait` なら `StateReply::Wait` を返す。解放の完了の後にもう一度呼ばれたときに `begin_close` が返す `CloseStep::Done(Some(理由))` を、`IOErrorKind.Other` と理由の文字列の `IOError` の `Result.Error` にして返す（ADR 0321 の決定 3）。`CloseStep::Done(None)` なら `Result.Ok(())`。解放済みのリソースに呼んだときは `Result.Ok(())`（01-10「解放の失敗」）。
- `begin_close` の VM の側の上書き（`src/vm/state.rs` の `Stage1StateServices`）: 既存の `begin_release` と同じく `check_release` と `request_release` を使い、`ReleaseStart::Done(Err(理由))` なら `Done(Some(理由))`、`AlreadyReleased` なら `take_release_failure` の値を `Done` で返し、ブロックする場合は `Wait(StateWait::Resource(..))` を返す。リソースの型による分岐（`HttpExchange` の失敗を捨てる分岐）は置かない。close の関数を呼んだときは、どの型でも失敗を返すからである（03-09 の `Http.closeExchange`）。`begin_release` は変えない。
- 理由を一度取り出したリソースは解放済みであり、その後の `with` の解放は失敗なしで終わる（01-10「close が `Result.Error` を返しても解放済み」、ADR 0321 の決定 2）。`take_release_failure` が一度だけ取り出すことで成り立つので、解放の枠は変えない。
- 参照インタプリタ（`src/refinterp/resources.rs`）は既定の本体のままでよい。本作業が差分テスト（`tests/golden.rs` の参照インタプリタとの比較）に解放の失敗のケースを加えるときは、参照インタプリタにも `begin_close` の上書きを書く（作るものに加え、完了の報告に書く）。
- R29 の `IO.File.closeReader` は `begin_release` のままでよい（`File.Reader` の解放は失敗しない）。
- `with` で束縛した `File.Writer` を抜けるときの解放は、R24 の解放の枠が行う。書き出しの失敗は、`closeWriter` を呼ばない場合、解放の失敗として実行時エラーになる（01-10、02-09「リソースの追跡」）。本作業は、この経路をスクリプトのテストで確かめるだけで、解放の枠を変えない。

## 受け入れテスト

- 項目ごとの単体テスト: `readChunk` の 1・ファイルの長さより大きい値・0 と負の値（実行時エラー）。`readLine` と `readChunk` を混ぜた読み。`openWriter` の二つのモードで作る・空にする・加える。`write`・`writeLine`・`writeChunk` の後に `closeWriter` で閉じ、`File.readText` で内容を確かめる。閉じた後の `write` が解放したリソースの使用（`ReleasedResourceUsed`）。二度目の `closeWriter` が `Result.Ok(())`。
- 解放の失敗: `release` が失敗を返す偽の `OsResource` を、テストの中で `ResourceKind::FileWriter` として登録する（macOS には `/dev/full` がないので、書き込めない出力先には頼らない）。次を確かめる。
  - `closeWriter` が、`IOErrorKind.Other` と偽の資源の理由の文字列の `Result.Error` を返す（ブロックする解放の待ちを経た後の二度目の呼び出しで返ること）。
  - `closeWriter` が `Result.Error` を返したリソースを束縛した `with` を抜けるときの解放が、失敗なしで終わる（実行時エラーにならない）。
  - `closeWriter` を呼ばずに `with` を抜けるときの解放では、解放の失敗の実行時エラー（`ReleaseFailed`）になる。
  - `begin_close` の VM の側の上書きの単体テスト（すぐに終わる解放の失敗、待った後の失敗、失敗のない解放、解放済みの項目）。`FileWriter` の解放は必ずブロックする解放になるので、すぐに終わる場合は `FileWriter` 以外の種類（`FileReader` など）で登録した偽の資源で確かめる。既定の本体が `begin_release` の結果を `CloseStep` に写すこと。
- スクリプトのテストで U3 の非公式のモジュールを取り込むときは、非公式の名前（`import Benitoite.Unofficial.Json` など。ADR 0286 の決定 3）で書く。03-08 などの設計書の例の `import Benitoite.Json` の形を写すと、E0321 になる。
- プログラムでの確かめ（R25 のテスト用の部品と、両方の IO の方式で実行する）: `with w = try File.openWriter(path, File.WriteMode.Replace) |> Result.mapError(_, IOError.message) do … end with`（`testdata/io/c12-*.bnt` と 01-10 の例の形） で、書いた内容が抜けた後に読める。`with` の中で 0 の除算を起こしても解放され、それまでに書いた内容が書き出される。書いているタスクを、`File.write` の仕事を作業用のスレッドへ出して `File.Writer` を貸した後、作業用のスレッドが仕事を終える前に（`ScriptedWorkers` の `hold_resources` で完了を止める）`Task.race` で取り消し、その後に仕事を終えさせると、`File.Writer` が表に戻ってから解放される（ADR 0266 の決定 4・5）。要求の方式で作業用のスレッドへ出す前に取り消した場合は、仕事が呼ばれず、`File.Writer` が貸されないまま解放されることを別に確かめる（既存の `outstanding_request_cancelled_by_race_is_never_invoked` と同じ形）。

## 完了条件

- `scripts/check.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- 10-15 の項目の名前・権限・引数の数と位置を変えていない
- 解放の仕事の受け渡し（R24・R26）を変えていない。変える必要が生じたら作業を止めて報告している

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「組み込みの関数」と「スケジューラと IO」の行。とくに、貸し出しと返却、解放の開始を、個々の関数の中に書いていないか。
- ブロックする解放を VM のスレッドで行っていないか。

## 難易度の理由

関数そのものは短いが、ブロックする解放を持つ初めてのリソースの型であり、解放の仕事の受け渡し、解放の失敗の報告、取り消しとの競合を、R24〜R26 の仕組みに正しく乗せる必要がある。
