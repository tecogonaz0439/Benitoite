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

- [IO のモジュール](../../design/03-interop/03-07-io-modules.md)の「File」の `File.Reader`・`File.Writer` の表と箇条（権限を開くときに一度だけ判定すること、`with` の解放、解放したリソースの使用、`maximumBytes` の範囲）
- [リソース管理](../../design/01-spec/01-10-resources.md)の「解放の失敗」「解放したリソースの使用」
- [ランタイム](../../design/02-impl/02-09-runtime.md)の「リソースの追跡」（リソースの型ごとの解放）、「組み込みの操作とハンドラ表」
- ADR: [0150](../../design/decisions/0150-resource-release-as-state.md)、[0266](../../design/decisions/0266-task-and-resource-state-machines.md)、[0067](../../design/decisions/0067-with-resource-scope.md)

インターフェース:

- [標準ライブラリの追加](../10-interfaces/10-15-stdlib-additions.md)の「IO のモジュール」の表、`IO/File.bnt` に加えた宣言（`WriteMode`・`closeWriter`）、「構成子のタグ」の `FILE_WRITE_MODE_*`
- [組み込みの関数の型付きの形](../10-interfaces/10-11-builtin-interface.md)の `OsResource`・`Lend::Resource`・`IoServices::register_resource`・`StateServices::begin_release`
- [スケジューラと IO 実行器](../10-interfaces/10-10-scheduler-and-io.md)の「リソースの表と状態」「外部の操作の記録と完了」のブロックする解放の仕事の受け渡し
- R24 の作業の文書の `request_release` の種類ごとの表（`FileWriter` はブロックする）、R29 の `File.readLine`・`IO.File.closeReader`

## 作るもの

- `src/builtins/funcs/file.rs` の `RESOURCE_DECLS` の 6 項目の本体と単体テスト
- `File.Writer` の `OsResource` の実装（`file.rs` の中の非公開の型）

## 手順の要点

- `File.readChunk(reader, maximumBytes)`: `maximumBytes` が 1 未満なら実行時エラー（`ArgumentOutOfDomain`。引数の位置は 1）とする（03-07 の箇条）。`Lend::Resource` で `File.Reader` を借り、最大 `maximumBytes` バイト（ただし `Bytes` の上限を超えない）を読む。ファイルの終わりなら `Option.None`。`File.readLine` と同じリーダーの読みかけの内容（`BufReader` のバッファ）から続けて読む。
- `File.openWriter(path, mode)`: `mode` のタグで、`Replace` なら作るか空にし、`Append` なら末尾に加える形で開く。作業用のスレッドで開き、完了の処理で `register_resource(ResourceKind::FileWriter, 資源, site)` で表に加える。
- `File.Writer` の `OsResource`: `BufWriter<File>` を持つ。`release` は、書き出し（`flush`）の後に `sync_all` を行わずに閉じ、書き出しの失敗を理由の文字列で返す。`sync_all` を行わないのは、03-07 が「書いた内容を書き出してから閉じる」とだけ定め、ディスクへの同期を求めていないからである。この判断を `///` のコメントに書く。
- `File.write`・`writeLine`・`writeChunk`: `Lend::Resource` で借りて書く。書きの失敗は `IOError` の `Result.Error`。`writeLine` は `text` と LF を書く。
- `IO.File.closeWriter`（`State`）: `IO.File.closeReader`（R29）と同じく `StateServices::begin_release` で解放を始める。ブロックする解放なので `StateReply::Wait` を返し、解放の完了の後にもう一度呼ばれたときに、記録した解放の失敗を `Result.Error` にして返す。解放済みのリソースに呼んだときは `Result.Ok(())`（01-10「解放の失敗」）。
- `with` で束縛した `File.Writer` を抜けるときの解放は、R24 の解放の枠が行う。書き出しの失敗は、`closeWriter` を呼ばない場合、解放の失敗として実行時エラーになる（01-10、02-09「リソースの追跡」）。本作業は、この経路をスクリプトのテストで確かめるだけで、解放の枠を変えない。

## 受け入れテスト

- 項目ごとの単体テスト: `readChunk` の 1・ファイルの長さより大きい値・0 と負の値（実行時エラー）。`readLine` と `readChunk` を混ぜた読み。`openWriter` の二つのモードで作る・空にする・加える。`write`・`writeLine`・`writeChunk` の後に `closeWriter` で閉じ、`File.readText` で内容を確かめる。閉じた後の `write` が解放したリソースの使用（`ReleasedResourceUsed`）。二度目の `closeWriter` が `Result.Ok(())`。
- 解放の失敗: 書き出しに失敗する `OsResource`（テストの中の偽の資源、または書き込めない出力先。Linux では `/dev/full` を使ってよい）で、`closeWriter` が `Result.Error` を返す。`with` を抜けるときの解放では、解放の失敗の実行時エラー（`ReleaseFailed`）になる。
- プログラムでの確かめ（R25 のテスト用の部品と、両方の IO の方式で実行する）: `with w = File.openWriter(path, File.WriteMode.Replace) do … end with` で、書いた内容が抜けた後に読める。`with` の中で 0 の除算を起こしても解放され、それまでに書いた内容が書き出される。書いているタスク（`File.write` の仕事をまだ実行していない）を `Task.race` で取り消し、その後に仕事を実行すると、`File.Writer` が表に戻ってから解放される（ADR 0266 の決定 4・5）。

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
