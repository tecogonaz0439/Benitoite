# L11 `File` のファイルとディレクトリの操作

- 依存する作業: [L00](L00-u3-interfaces.md)、[L03](L03-bytes.md)、[R29](R29-runtime-builtins.md)
- 難易度: 3（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行。テストを含む）
- ブランチ: impl/L11-file-operations

## 目的

`Benitoite.IO.File` のパスを受け取る操作のうち、U2 が作らなかった 13 の本体を書き、ソースの関数 `File.copy` を確かめる。10-15 の部分 32（`file::PATH_DECLS`）である。どれも作業用のスレッドで行う。あわせて、03-07「IOErrorKind と関数の対応」の表を満たすように、R29 が置いた OS の誤りから `IOErrorKind` への対応を広げる。

| 項目 | エフェクト |
|---|---|
| `File.readBytes`・`readLines`・`exists`・`info`・`listDirectory`・`walk`・`canonicalize` | `File.Read` |
| `File.writeBytes`・`appendBytes`・`createDirectory`・`remove`・`removeTree`・`rename` | `File.Write` |
| `File.copy`（ソース。`readBytes` と `writeBytes` を呼ぶ） | `File.Read`、`File.Write` |

依存の理由: `readBytes`・`writeBytes`・`appendBytes` は `Bytes` の値を読み書きする（L03）。作業用のスレッドの仕事と `IOError` の作り方は R29 のものを使う。`File.Info` の `modified` は `Time.Instant` のレコードであり、本作業はレコードを直接作る（`Time` の関数を呼ばない）ので、L24 を待たない。

## 読む設計書の節

- [IO のモジュール](../../design/03-interop/03-07-io-modules.md)の「共通の規則」（パスの解決、行の分け方、ディレクトリの中の名前の順）、「File」（本作業の関数の行、`File.Info`・`File.EntryKind` と箇条）、「IOErrorKind と関数の対応」
- [エラー処理](../../design/01-spec/01-09-errors.md)の「IO の失敗の種類」
- [ランタイム](../../design/02-impl/02-09-runtime.md)の「組み込みの操作とハンドラ表」、「一つの操作で作る値の大きさの上限」（行やディレクトリの項目を並べる操作のリストの長さ）
- ADR: [0144](../../design/decisions/0144-ioerrorkind-constructors.md)、[0012](../../design/decisions/0012-invalid-utf8-input.md)、[0165](../../design/decisions/0165-exit-and-stdio-in-embedded-runs.md)

インターフェース:

- [標準ライブラリの追加](../10-interfaces/10-15-stdlib-additions.md)の「IO のモジュール」の表、`IO/File.bnt` に加えた宣言（`File.copy`・`Info`・`EntryKind`）、「構成子のタグ」の `FILE_ENTRY_KIND_*`、「レコードの値の作り方」、「部分と番号」の `File.copy` の箇条
- [IO とネットワークの追加](../10-interfaces/10-16-io-and-network-additions.md)の「作業用のスレッドで行う操作」
- R29 の作業の文書（`std::io::ErrorKind` から `IOErrorKind` への対応の表）

## 作るもの

- `src/builtins/funcs/file.rs` の `PATH_DECLS` の 13 項目の本体と単体テスト
- OS の誤りから `IOErrorKind` への対応の広げたもの（R29 のものを一つにして使う。二つ目を作らない）
- `File.copy` を確かめるスクリプトのテスト

## 手順の要点

- パスは基準のディレクトリから解決する（`IoServices::working_directory`。03-07「共通の規則」）。解決は VM のスレッドで行い、仕事には `PathBuf` だけを渡す。
- `readBytes`・`readLines` は、R29 の `readText` と同じく上限より 1 バイト多い分まで読み、上限を超えたら資源の不足（`InputTooLarge`）。`readLines` は行に分け、UTF-8 でなければ `InvalidUTF8`、行の数がリストの上限を超えたら資源の不足。
- `exists`: ないときだけ `Result.Ok(false)`、調べられないとき（途中の構成要素の権限がないなど）は `Result.Error`（03-07）。`std::fs::symlink_metadata` の `NotFound` を `false` にし、ほかの誤りを `Result.Error` にする。壊れたシンボリックリンクは「ある」とする（リンクそのものがあるので）。この判断を `///` のコメントに書く。
- `info`: `symlink_metadata` で、最後の構成要素がシンボリックリンクならリンクそのものの情報を返す。`kind` は `EntryKind` のタグ、`size` はバイト数、`modified` は最後に内容を変えた時刻をナノ秒の `Time.Instant` にしたもの。時刻が `Integer` のナノ秒に収まらないときは `Other` の `Result.Error` とし、理由の文を `text` に置く。
- `listDirectory`: `.` と `..` を含まない名前を、UTF-8 のバイト列の辞書式の順に並べる。名前が UTF-8 でなければ `InvalidUTF8`。
- `walk`: ディレクトリの下のすべてのファイルとディレクトリを、`path` からの相対パスで、UTF-8 のバイト列の辞書式の順に並べる。ディレクトリを指すシンボリックリンクの先は辿らない（リンクそのものは並べる）。辿り方は明示の積み重ね（`Vec`）で書き、Rust の再帰を使わない（00-02「再帰の深さ」）。リストの長さの上限を超えたら資源の不足。
- `canonicalize`: `std::fs::canonicalize`。UTF-8 でなければ `InvalidUTF8`。
- `createDirectory`: 途中のディレクトリも作る（`create_dir_all`）。既にディレクトリがあれば何もしない。パスに普通のファイルがあれば `AlreadyExists`（03-07 の箇条）。`create_dir_all` がこの場合に返す誤りの種類を確かめ、`AlreadyExists` にならなければ、判定を加える。
- `remove`: ファイル、シンボリックリンク、空のディレクトリを削除する。`symlink_metadata` で種類を見て、ディレクトリなら `remove_dir`、そうでなければ `remove_file`。空でないディレクトリは `DirectoryNotEmpty`。
- `removeTree`: ディレクトリとその下を削除し、シンボリックリンクの先は削除しない。`std::fs::remove_dir_all` は使わず、明示の積み重ね（`Vec`）で自作する（std の実装は内部で再帰し、深さごとにファイル記述子を開いたままにしうるので、受け入れテストの深い入れ子と規約 00-02「再帰の深さ」に合わない）。項目の種類は `symlink_metadata` で調べ、リンクはリンクそのものを消す。ファイル記述子を開いたまま潜らず、パスで辿る。引数がディレクトリでない場合（ファイル・リンク）の結果は 03-07 の表に従い、表が定めなければ実装担当が決めて完了の報告に書く。
- `rename`: `std::fs::rename`。`from` がファイルで `to` がディレクトリのときは `IsDirectory`（03-07 の表）。OS がこの場合に返す誤りを確かめ、表と合わなければ判定を加える。
- `IOErrorKind` への対応: 03-07「IOErrorKind と関数の対応」の各行を、少なくとも一つのテストで起こす。R29 の対応（`runtime` の `IoFailure::from`）を使い、`std::io::ErrorKind` の値だけでは表と合わない場合（`createDirectory` がファイルに当たる場合、`rename` がディレクトリに当たる場合など）だけ、判定を加える。
- `File.copy` はソースの関数であり、`readBytes` の後に `writeBytes` を呼ぶ（10-15「部分と番号」）。ソースを変えない。内容を一度 `Bytes` にするので、写せるのは 2^30 バイト（1 GiB）までであり、超えるファイルでは `readBytes` と同じく資源の不足として停止する（03-07「File」、ADR 0291）。この制限をテストで確かめ、完了の報告に書く。テストで 1 GiB を超える確保をしないために、`readBytes` は読む前にメタデータの大きさを見て、上限を超えていれば読まずに同じ停止を返す（読む途中で増えたファイルに備えて、R29 の `read_all_limited` の上限はそのまま使う）。テストは `File::set_len` で作った疎なファイル（2^30 + 1 バイト）で `readBytes` と `File.copy` の両方を確かめる。

## 受け入れテスト

一時ディレクトリ（`std::env::temp_dir` の下にテストが作る）で行う。

- 項目ごとの単体テスト: 仕事を `run` して完了の処理を呼ぶところまで（R29 と同じ）。各関数の成功の場合と、03-07「IOErrorKind と関数の対応」の各行（`NotFound`・`AlreadyExists`・`IsDirectory`・`NotDirectory`・`DirectoryNotEmpty`・`InvalidUTF8`・`InvalidInput`（パスに NUL））。`PermissionDenied` は、権限を外したディレクトリで起こせる環境でだけ確かめる（root で動く環境では起きないので、その場合は飛ばした理由をテストの中に書く）。
- 順序: `listDirectory` と `walk` が、作った順によらず UTF-8 のバイト列の順に並ぶ（`"B"` が `"a"` より前、`"é"` が `"z"` より後）。
- シンボリックリンク: `info` がリンクそのものの `SymbolicLink` を返す。`walk` がディレクトリを指すリンクの先を辿らない。`removeTree` がリンクの先を消さない。
- 深い入れ子: 深さ 1000 以上のディレクトリを `walk` と `removeTree` で扱える（Rust の再帰を使わないことの確かめ。作れない環境ではパスの長さの上限の手前までにする）。
- 作業文書と 03-07 が定めない細部（`info.modified` が 1970 年より前のときの値、`canonicalize` のテストで macOS の一時ディレクトリが `/private` 付きに解決されることへの対処など）は、実装担当が決めて完了の報告に書く。
- スクリプト: `File.copy` で内容が写り、`to` があれば置き換わる。`from` がディレクトリなら `IsDirectory`。`File.Info.modified` の値を、レコードの欄の関数 `Time.Instant.unixNanoseconds`（`import Benitoite.Unofficial.Time`）で読める。`Time` の組み込みの関数（L24）は使わない。
- スクリプトのテストで U3 の非公式のモジュールを取り込むときは、非公式の名前（`import Benitoite.Unofficial.Json` など。ADR 0286 の決定 3）で書く。03-08 などの設計書の例の `import Benitoite.Json` の形を写すと、E0321 になる。

## 完了条件

- `scripts/check.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- 10-15 の項目の名前・権限・引数の数と位置、L00 が置いたソースを変えていない
- OS の誤りの対応で判断したこと（`raw_os_error` を使ったか、判定を加えたか）と、`File.copy` の大きさの制限を、完了の報告に書いている

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「組み込みの関数」の行。とくに、作業用のスレッドに渡すものに言語の値を含めていないか、読んだ内容の大きさを値を作る前に確かめているか。
- 並べる順を OS の返す順に頼っていないか。
- ディレクトリを辿る処理が、Rust の再帰を使っていないか。

## 難易度の理由

関数ごとの処理は短いが、OS の誤りの種類の区別、シンボリックリンクの扱い、並べる順、深いディレクトリの辿り方など、プラットフォームの細部を正しく扱う必要がある。
