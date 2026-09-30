# 標準ライブラリの追加

本章は、U3（標準ライブラリ）が加える標準ライブラリのソースと、組み込みの関数の表に加える部分と項目、構成子のタグを定める。[組み込みの関数の表](10-12-builtin-table.md)と[標準ライブラリのソース](10-14-prelude-and-stdlib-sources.md)を広げる章であり、名前の付け方・番号の振り方・仮の本体・ソースの書き方の方針は、両章の定めをそのまま使う。関数の意味は、[標準ライブラリ](../../design/03-interop/03-06-stdlib.md)・[IO のモジュール](../../design/03-interop/03-07-io-modules.md)・[テキストとデータの処理](../../design/03-interop/03-08-text-and-data.md)・[ネットワークのモジュール](../../design/03-interop/03-09-network.md)で定める。IO とネットワークの組み込みの関数が使うランタイムの口と、使うクレートは[IO とネットワークの追加](10-16-io-and-network-additions.md)で定める。

- 置く作業: L00

コードブロックの見出しの読み方は [README](../README.md) の「インターフェースの読み方」に従う。本章は、10-14 が C02 で置いたファイルに、`append=` の見出しで書き足す（README の「U3・U4 で決めたこと」の 2）。パスは処理系のクレート `crates/benitoite/` からの相対パスである。

## 置く作業と既存のファイル

L00 は、本章と 10-16 のブロックを `tools/extract_interfaces.py place crates/benitoite --task L00` で置く。置き方は次のとおりである。

| ファイル | 扱い | 見出し |
|---|---|---|
| `src/prelude/mod.rs` | `STDLIB` の末尾に、U3 のモジュールの項目を加える | `rust append=src/prelude/mod.rs::STDLIB` |
| `src/builtins/table.rs` | 10-12 の `tags` の末尾に、U3 の型の構成子のタグを加える | `rust append=src/builtins/table.rs::tags` |
| 10-14 の `.bnt` のうち、U3 が関数を加えるもの（`Character`・`String`・`Map`・`Set`・`Trait`、`IO/Console`・`IO/File`・`IO/Process`・`IO/Clock`） | 末尾に宣言を加えるか、エフェクトの宣言の中に操作を加えるか、先頭の import に加える | `text append=<パス>`（末尾）、`text append=<パス>::<エフェクト>`、`text append=<パス>::imports` |
| U3 が加えるモジュールの `.bnt`（本章の「新しいモジュール」） | 新しく置く | `text file=` |
| `src/builtins/funcs/` の子のモジュール | 本章の見出しでは置かない。L00 が、本章の「項目の一覧」のすべての項目を仮の本体で宣言する（10-12「まだ書かない項目の仮の本体」と同じ） | — |

`STDLIB` と `tags` と 10-14 のソースを直接書き換えず、道具で書き足すのは、C02 が置いた内容を変えずに U3 の分を重ねるためである（10-12・10-14 は項目を末尾にだけ加える）。U4 の D00 も、`STDLIB` の末尾に `Assert` の項目を加える（10-18）。L00 と D00 のどちらを先に置いても、それぞれのブロックは互いを参照しないので、置いた後のクレートはコンパイルできる。`STDLIB` の中の順は、先に置いた作業の項目が前になる。表の順が決めるのは prelude のモジュールの ID と束縛の番号だけであり、どちらもファイルに保存しないので、順が違っても振る舞いは変わらない（10-14「ファイルとモジュールの名前」）。

本章のソースは、処理系の実装を始める前に書いたものである。10-14 と同じく、L00 より後の作業が本章のソースに誤り（構文の誤り、型の誤り、設計書との食い違い）を見つけたときは、ソースを直さずに作業を止めて報告する（10-14「置く作業と既存のファイル」）。

## 取り込みの名前と状態

U3 が加えるモジュールの状態は、[ADR 0286](../../design/decisions/0286-unofficial-modules-imported-under-unofficial.md) と README の「U3・U4 で決めたこと」の 1 のとおりである。`STDLIB` の `unofficial` はこの表で決める。

| 状態 | モジュール | `prelude` | `unofficial` | 取り込み |
|---|---|---|---|---|
| 標準 | `Benitoite.Bytes`・`Benitoite.ByteOrder`・`Benitoite.NetworkError`・`Benitoite.NetworkErrorKind` | 真 | 偽 | import なし |
| 非公式 | `Benitoite.Time`・`Benitoite.IO.Random`・`Benitoite.Path`・`Benitoite.Json`・`Benitoite.Regex`・`Benitoite.Csv`・`Benitoite.Encoding`・`Benitoite.Hash`・`Benitoite.Network.Http` | 偽 | 真 | `import Benitoite.Unofficial.Json` など |

- 10-14 のモジュールに加える関数は、そのモジュールの状態に従う。`Character`・`String`・`Map`・`Set` と `Benitoite.Trait` の関数は標準、`IO.Console`・`IO.File`・`IO.Process`・`IO.Clock` の関数は非公式である。
- 表の名前（10-12「名前の付け方」）、ソースの置き場所、本章の本文は、標準に加えた後の名前（`Benitoite.Json`、`Json.parse`）で書く。
- 非公式のモジュールがほかの非公式のモジュールを取り込むときも、取り込みの名前で書く（`import Benitoite.Unofficial.Time`）。標準に移すときに、この import の行も書き換える（ADR 0286 の決定 7）。

## 組み込みの関数の表に加える部分

### 部分と番号

U3 の部分は、10-12 の 21 の部分の後（`PARTS` の 22 番から）に、次の順で加える。既存の型のモジュールに関数を加えるときは、10-12「番号の振り方」のとおり、同じファイルに別の定数（`UNICODE_DECLS` など）を作って新しい部分とする。部分を `PARTS` に加えるのは L00 である。L00 は、表のすべての項目を仮の本体（10-12「まだ書かない項目の仮の本体」）で宣言し、以後の作業は項目の本体を書くだけで、番号を変えない。

| 順 | 部分（`funcs` の子のモジュールと定数） | 項目の数 | 番号（参考） | 作業 |
|---|---|---|---|---|
| 22 | `character::UNICODE_DECLS` | 7 | 164〜170 | L01 |
| 23 | `string::UNICODE_DECLS` | 2 | 171〜172 | L01 |
| 24 | `map::MORE_DECLS` | 7 | 173〜179 | L02 |
| 25 | `set::MORE_DECLS` | 7 | 180〜186 | L02 |
| 26 | `string::UTF8_DECLS` | 2 | 187〜188 | L03 |
| 27 | `bytes::DECLS` | 16 | 189〜204 | L03 |
| 28 | `network_error::DECLS` | 2 | 205〜206 | L30 |
| 29 | `console::MORE_DECLS` | 2 | 207〜208 | L10 |
| 30 | `process::ENVIRONMENT_DECLS` | 3 | 209〜211 | L10 |
| 31 | `clock::MORE_DECLS` | 2 | 212〜213 | L10 |
| 32 | `file::PATH_DECLS` | 13 | 214〜226 | L11 |
| 33 | `file::RESOURCE_DECLS` | 6 | 227〜232 | L12 |
| 34 | `process::RUN_DECLS` | 3 | 233〜235 | L13 |
| 35 | `random::DECLS` | 9 | 236〜244 | L14 |
| 36 | `path::DECLS` | 10 | 245〜254 | L20 |
| 37 | `json::DECLS` | 3 | 255〜257 | L21 |
| 38 | `regex::DECLS` | 12 | 258〜269 | L22 |
| 39 | `csv::DECLS` | 5 | 270〜274 | L23 |
| 40 | `time::DECLS` | 11 | 275〜285 | L24 |
| 41 | `encoding::DECLS` | 4 | 286〜289 | L25 |
| 42 | `hash::DECLS` | 1 | 290 | L25 |
| 43 | `http_server::DECLS` | 7 | 291〜297 | L30 |
| 44 | `http_util::DECLS` | 1 | 298 | L31 |
| 45 | `http_client::DECLS` | 1 | 299 | L32 |

U3 の項目は合わせて 136 であり、表の全体は 300 項目になる。番号の欄は、L00 が D00 より先に部分を加えたときの値である。D00 が先なら、D00 の部分の数だけ後ろにずれる。番号はコードに書かない（10-12「番号の振り方」）。

U3 が作る 162 の関数のうち、組み込みの関数は上の 136 であり、残りの 26 は標準ライブラリのソースで書く（本章の「新しいモジュール」と「既存のモジュールへの追加」）。

| 区分 | 組み込み | ソース |
|---|---|---|
| prelude | 43（`Character` 7、`String` 4、`Map` 7、`Set` 7、`Bytes` 16、`NetworkError` 2） | 8（`Map`・`Set` の関数を引数にとる関数） |
| IO | 38（`Console` 2、`File` 19、`Process` 6、`Clock` 2、`Random` 9） | 2（`Process.command`・`File.copy`） |
| テキストとデータ | 46（`Path` 10、`Json` 3、`Regex` 12、`Csv` 5、`Time` 11、`Encoding` 4、`Hash` 1） | 9（`Json` の 8、`Regex.replaceAllWith`） |
| ネットワーク | 9（サーバの 7、`Http.pathSegments`、`Http.send`） | 7（`Http.serve`・`text`・`html`・`json`・`header`・`get`・`clientRequest`） |

- `File.copy` の型は、03-07 のとおり `uses File.Read, File.Write` である。操作の宣言には `uses` を書けず、一つの操作は一つのエフェクトにしか属さない（01-02「エフェクトの宣言とハンドラ（初回リリース版）」）ので、`File.copy` を操作にすると、この型を与えられない。そこで、`File.readBytes` と `File.writeBytes` を呼ぶソースの関数とした。内容を一度 `Bytes` の値に読むので、写せるファイルの大きさは `Bytes` の上限（2^30 バイト。02-09「一つの操作で作る値の大きさの上限」）までである。上限を超えるファイルでは、`File.readBytes` と同じく資源の不足として停止する。この扱いと上限は、設計者が決め、03-07「File」に書いた（ADR 0291）。
- `Process.command`・`Http.clientRequest` はレコードを作るだけ、`Http.text`・`Http.html`・`Http.json`・`Http.header`・`Http.get` はほかの関数を組み合わせるだけなので、ソースで書く。`Json.get` などの 8 は `Json.Value` のパターンの照合だけで書ける。
- `Map`・`Set` の関数を引数にとる関数は、`toList` で並べたリストに `List` の関数を当て、`fromList` で作り直す。10-14 の `List` の関数と同じく O(n log n) である。03-06 の表の計算量 O(n) にする内部の組み込みの関数は、README の「U3・U4 で決めたこと」の 8 のとおり、測定で費用が目立つときだけ加える。

### 項目の種類と権限

10-12「項目の種類」のとおり、`@builtin` を付けた関数は `Declared`、組み込みのエフェクトの操作は `EffectOp`（権限 `Io`）である。U3 の `Declared` の項目の権限は、次の四つを `State`、ほかを `Pure` とする。

| 項目 | 権限を `State` にする理由 |
|---|---|
| `IO.File.closeWriter`・`Network.Http.closeListener`・`Network.Http.closeExchange` | リソースを解放する関数であり、型に `State` を持つ（[ADR 0150](../../design/decisions/0150-resource-release-as-state.md)）。`IO.File.closeReader` と同じく、`StateServices::begin_release` で解放を始める |
| `Network.Http.requestOf` | 型は純粋な関数（03-09）だが、受け付けた要求をリソースの表から読む。`Pure` の文脈はリソースの表に触れられないので、`Task.all` と同じく、型に `State` を書かない `State` の項目とする。読み方は 10-16「受け付けた要求の保存」で定める |

`State` の項目はハンドラ表と送り出しの列を通らないので、`Http.requestOf` をハンドラで処理することはできない。これは 03-09 の「純粋な関数である」と矛盾しない。純粋な関数も、操作ではないのでハンドラで処理できないからである。

## 項目の一覧

各部分の項目を、部分の中の順に示す。「引数」は `BuiltinDecl::arity`、「型」は宣言の型であり、本章のソースを写したものである（食い違うときはソースを正とする）。関数の意味と実行時エラーは、「意味」の欄の設計書の箇所で定める。

### prelude の基本型（`character`・`string`）

どれも権限が `Pure`、種類が `Declared` である。

| 部分 | 名前 | 引数 | 型 | 意味 | 作業 |
|---|---|---|---|---|---|
| 22 | `Character.isAlphabetic`・`Character.isNumeric`・`Character.isWhitespace`・`Character.isUppercase`・`Character.isLowercase` | 1 | `function(Character) -> Boolean` | 03-06「Character」 | L01 |
| 22 | `Character.toUppercase`・`Character.toLowercase` | 1 | `function(Character) -> String` | 同上 | L01 |
| 23 | `String.toUppercase`・`String.toLowercase` | 1 | `function(String) -> String` | 03-06「String」 | L01 |
| 26 | `String.toUTF8` | 1 | `function(String) -> Bytes` | 03-06「Bytes と ByteOrder（初回リリース版）」 | L03 |
| 26 | `String.fromUTF8` | 1 | `function(Bytes) -> Option[String]` | 同上 | L03 |

### マップと集合（`map`・`set`）

どれも権限が `Pure`、種類が `Declared` である。表現は R37 の `runtime::map` の関数だけで扱う（10-08「マップと集合」）。

| 部分 | 名前 | 引数 | 型 | 意味 | 作業 |
|---|---|---|---|---|---|
| 24 | `Map.get` | 2 | `function[K: key, V](Map[K, V], K) -> Option[V]` | 03-06「Map と Set（初回リリース版）」 | L02 |
| 24 | `Map.set` | 3 | `function[K: key, V](Map[K, V], K, V) -> Map[K, V]` | 同上 | L02 |
| 24 | `Map.remove` | 2 | `function[K: key, V](Map[K, V], K) -> Map[K, V]` | 同上 | L02 |
| 24 | `Map.contains` | 2 | `function[K: key, V](Map[K, V], K) -> Boolean` | 同上 | L02 |
| 24 | `Map.size` | 1 | `function[K: key, V](Map[K, V]) -> Integer` | 同上 | L02 |
| 24 | `Map.keys` | 1 | `function[K: key, V](Map[K, V]) -> List[K]` | 同上 | L02 |
| 24 | `Map.values` | 1 | `function[K: key, V](Map[K, V]) -> List[V]` | 同上 | L02 |
| 25 | `Set.contains` | 2 | `function[T: key](Set[T], T) -> Boolean` | 同上 | L02 |
| 25 | `Set.add`・`Set.remove` | 2 | `function[T: key](Set[T], T) -> Set[T]` | 同上 | L02 |
| 25 | `Set.size` | 1 | `function[T: key](Set[T]) -> Integer` | 同上 | L02 |
| 25 | `Set.union`・`Set.intersection`・`Set.difference` | 2 | `function[T: key](Set[T], Set[T]) -> Set[T]` | 同上 | L02 |

### `Bytes`（`bytes`）

どれも権限が `Pure`、種類が `Declared` であり、意味は 03-06「Bytes と ByteOrder（初回リリース版）」で定める。値の表現は 10-08 の `ObjKind::Bytes`（`alloc_bytes`・`alloc_bytes_with`・`bytes`）である。03-06 の「`Bytes.slice` は同じ領域を共有する」の表現を 10-08 の対象が持たないときは、写して作ってよい。共有する表現に改めるかは、測定の後に決める。

| 名前 | 引数 | 型 | 作業 |
|---|---|---|---|
| `Bytes.empty` | 0 | `function() -> Bytes` | L03 |
| `Bytes.fromList` | 1 | `function(List[Byte]) -> Bytes` | L03 |
| `Bytes.fromIntegers` | 1 | `function(List[Integer]) -> Option[Bytes]` | L03 |
| `Bytes.fromHex`・`Bytes.fromBinary` | 1 | `function(String) -> Option[Bytes]` | L03 |
| `Bytes.toList` | 1 | `function(Bytes) -> List[Byte]` | L03 |
| `Bytes.toHex`・`Bytes.toBinary` | 1 | `function(Bytes) -> String` | L03 |
| `Bytes.length` | 1 | `function(Bytes) -> Integer` | L03 |
| `Bytes.get` | 2 | `function(Bytes, Integer) -> Option[Byte]` | L03 |
| `Bytes.slice` | 3 | `function(Bytes, Integer, Integer) -> Option[Bytes]` | L03 |
| `Bytes.concatenate` | 2 | `function(Bytes, Bytes) -> Bytes` | L03 |
| `Bytes.readUnsigned`・`Bytes.readSigned` | 4 | `function(Bytes, Integer, Integer, ByteOrder) -> Option[Integer]` | L03 |
| `Bytes.fromUnsigned`・`Bytes.fromSigned` | 3 | `function(Integer, Integer, ByteOrder) -> Option[Bytes]` | L03 |

### ネットワークの失敗（`network_error`）

| 名前 | 権限 | 引数 | 型 | 意味 | 作業 |
|---|---|---|---|---|---|
| `NetworkError.kind` | `Pure` | 1 | `function(NetworkError) -> NetworkErrorKind` | 01-09「ネットワークの失敗の種類（初回リリース版）」 | L30 |
| `NetworkError.message` | `Pure` | 1 | `function(NetworkError) -> String` | 同上 | L30 |

`NetworkError` の値は 10-08 の `FieldsKind::NetworkError` の対象であり、`tag` は `NetworkErrorKind` のタグ（本章の「構成子のタグ」）、並びは理由の文字列一つである。`NetworkError.kind` は `IOError.kind` と同じく、`tag` を `Value::Tag(CtorTag(tag))` にして返す。

### IO のモジュール（`console`・`process`・`clock`・`file`・`random`）

`IO.File.closeWriter` と `IO.Random` の四つの純粋な関数のほかは、組み込みのエフェクトの操作であり、権限が `Io`、種類が `EffectOp` である。操作を行う場所（VM のスレッド、作業用のスレッド）は 02-09「組み込みの操作とハンドラ表」の表と、10-16 に従う。

| 部分 | 名前 | 権限 | 引数 | 型 | 意味 | 作業 |
|---|---|---|---|---|---|---|
| 29 | `Benitoite.IO.Console.readAllLines` | `Io` | 0 | `function() -> Result[List[String], IOError] uses Console.Read` | 03-07「Console」 | L10 |
| 29 | `Benitoite.IO.Console.readAllBytes` | `Io` | 0 | `function() -> Result[Bytes, IOError] uses Console.Read` | 同上 | L10 |
| 30 | `Benitoite.IO.Process.scriptDirectory` | `Io` | 0 | `function() -> String uses Process.Environment` | 03-07「Process」 | L10 |
| 30 | `Benitoite.IO.Process.environmentVariable` | `Io` | 1 | `function(String) -> Result[Option[String], IOError] uses Process.Environment` | 同上 | L10 |
| 30 | `Benitoite.IO.Process.workingDirectory` | `Io` | 0 | `function() -> Result[String, IOError] uses Process.Environment` | 同上 | L10 |
| 31 | `Benitoite.IO.Clock.now` | `Io` | 0 | `function() -> Time.Instant uses Clock.Time` | 03-07「Clock」 | L10 |
| 31 | `Benitoite.IO.Clock.localOffsetMinutes` | `Io` | 0 | `function() -> Integer uses Clock.Time` | 同上 | L10 |
| 32 | `Benitoite.IO.File.readBytes` | `Io` | 1 | `function(String) -> Result[Bytes, IOError] uses File.Read` | 03-07「File」 | L11 |
| 32 | `Benitoite.IO.File.readLines` | `Io` | 1 | `function(String) -> Result[List[String], IOError] uses File.Read` | 同上 | L11 |
| 32 | `Benitoite.IO.File.exists` | `Io` | 1 | `function(String) -> Result[Boolean, IOError] uses File.Read` | 同上 | L11 |
| 32 | `Benitoite.IO.File.info` | `Io` | 1 | `function(String) -> Result[File.Info, IOError] uses File.Read` | 同上 | L11 |
| 32 | `Benitoite.IO.File.listDirectory`・`Benitoite.IO.File.walk` | `Io` | 1 | `function(String) -> Result[List[String], IOError] uses File.Read` | 同上 | L11 |
| 32 | `Benitoite.IO.File.canonicalize` | `Io` | 1 | `function(String) -> Result[String, IOError] uses File.Read` | 同上 | L11 |
| 32 | `Benitoite.IO.File.writeBytes`・`Benitoite.IO.File.appendBytes` | `Io` | 2 | `function(String, Bytes) -> Result[Unit, IOError] uses File.Write` | 同上 | L11 |
| 32 | `Benitoite.IO.File.createDirectory`・`Benitoite.IO.File.remove`・`Benitoite.IO.File.removeTree` | `Io` | 1 | `function(String) -> Result[Unit, IOError] uses File.Write` | 同上 | L11 |
| 32 | `Benitoite.IO.File.rename` | `Io` | 2 | `function(String, String) -> Result[Unit, IOError] uses File.Write` | 同上 | L11 |
| 33 | `Benitoite.IO.File.readChunk` | `Io` | 2 | `function(File.Reader, Integer) -> Result[Option[Bytes], IOError] uses File.Read` | 同上 | L12 |
| 33 | `Benitoite.IO.File.openWriter` | `Io` | 2 | `function(String, File.WriteMode) -> Result[File.Writer, IOError] uses File.Write` | 同上 | L12 |
| 33 | `Benitoite.IO.File.write`・`Benitoite.IO.File.writeLine` | `Io` | 2 | `function(File.Writer, String) -> Result[Unit, IOError] uses File.Write` | 同上 | L12 |
| 33 | `Benitoite.IO.File.writeChunk` | `Io` | 2 | `function(File.Writer, Bytes) -> Result[Unit, IOError] uses File.Write` | 同上 | L12 |
| 33 | `IO.File.closeWriter` | `State` | 1 | `function(File.Writer) -> Result[Unit, IOError] uses State` | 同上 | L12 |
| 34 | `Benitoite.IO.Process.run` | `Io` | 1 | `function(Process.Command) -> Result[Process.Output, IOError] uses Process.Run` | 03-07「Process」「外部コマンドの起動とシェル」 | L13 |
| 34 | `Benitoite.IO.Process.runAttached` | `Io` | 1 | `function(Process.Command) -> Result[Integer, IOError] uses Process.Run` | 同上 | L13 |
| 34 | `Benitoite.IO.Process.shell` | `Io` | 1 | `function(String) -> Result[Process.Output, IOError] uses Process.Run` | 同上 | L13 |
| 35 | `Benitoite.IO.Random.integer` | `Io` | 2 | `function(Integer, Integer) -> Integer uses Random.Generate` | 03-07「Random」 | L14 |
| 35 | `Benitoite.IO.Random.float` | `Io` | 0 | `function() -> Float uses Random.Generate` | 同上 | L14 |
| 35 | `Benitoite.IO.Random.boolean` | `Io` | 0 | `function() -> Boolean uses Random.Generate` | 同上 | L14 |
| 35 | `Benitoite.IO.Random.shuffle` | `Io` | 1 | `function[T](List[T]) -> List[T] uses Random.Generate` | 同上 | L14 |
| 35 | `Benitoite.IO.Random.choose` | `Io` | 1 | `function[T](List[T]) -> Option[T] uses Random.Generate` | 同上 | L14 |
| 35 | `IO.Random.fromSeed` | `Pure` | 1 | `function(Integer) -> Random.Generator` | 同上 | L14 |
| 35 | `IO.Random.nextInteger` | `Pure` | 3 | `function(Random.Generator, Integer, Integer) -> Pair[Integer, Random.Generator]` | 同上 | L14 |
| 35 | `IO.Random.nextFloat` | `Pure` | 1 | `function(Random.Generator) -> Pair[Float, Random.Generator]` | 同上 | L14 |
| 35 | `IO.Random.shuffleWith` | `Pure` | 2 | `function[T](Random.Generator, List[T]) -> Pair[List[T], Random.Generator]` | 同上 | L14 |

- 部分 29〜31 の項目は、10-12 の `console`・`process`・`clock` と同じ子のモジュールに、別の定数で置く。部分 32・33 は `file`、部分 34 は `process` の別の定数である。
- `Random.Generator` の値は、10-08 の `ObjKind::Opaque` の対象（`alloc_opaque`。中身は xoshiro256** の状態）である。生成器の関数は、引数の生成器を変えずに新しい生成器を作って返す。

### テキストとデータ（`path`・`json`・`regex`・`csv`・`time`・`encoding`・`hash`）

どれも権限が `Pure`、種類が `Declared` である。意味は 03-08 の各節で定める。

| 部分 | 名前 | 引数 | 型 | 作業 |
|---|---|---|---|---|
| 36 | `Path.join` | 2 | `function(String, String) -> String` | L20 |
| 36 | `Path.joinAll` | 1 | `function(List[String]) -> String` | L20 |
| 36 | `Path.parent`・`Path.fileName`・`Path.stem`・`Path.extension` | 1 | `function(String) -> Option[String]` | L20 |
| 36 | `Path.withExtension` | 2 | `function(String, String) -> String` | L20 |
| 36 | `Path.isAbsolute` | 1 | `function(String) -> Boolean` | L20 |
| 36 | `Path.components` | 1 | `function(String) -> List[String]` | L20 |
| 36 | `Path.normalize` | 1 | `function(String) -> String` | L20 |
| 37 | `Json.parse` | 1 | `function(String) -> Result[Json.Value, Json.ParseError]` | L21 |
| 37 | `Json.stringify`・`Json.stringifyPretty` | 1 | `function(Json.Value) -> String` | L21 |
| 38 | `Regex.compile` | 1 | `function(String) -> Result[Regex.Pattern, String]` | L22 |
| 38 | `Regex.isMatch` | 2 | `function(Regex.Pattern, String) -> Boolean` | L22 |
| 38 | `Regex.find` | 2 | `function(Regex.Pattern, String) -> Option[Regex.Match]` | L22 |
| 38 | `Regex.findAll` | 2 | `function(Regex.Pattern, String) -> List[Regex.Match]` | L22 |
| 38 | `Regex.matchText` | 1 | `function(Regex.Match) -> String` | L22 |
| 38 | `Regex.matchByteStart`・`Regex.matchByteEnd` | 1 | `function(Regex.Match) -> Integer` | L22 |
| 38 | `Regex.group` | 2 | `function(Regex.Match, Integer) -> Option[String]` | L22 |
| 38 | `Regex.namedGroup` | 2 | `function(Regex.Match, String) -> Option[String]` | L22 |
| 38 | `Regex.replaceFirst`・`Regex.replaceAll` | 3 | `function(Regex.Pattern, String, String) -> String` | L22 |
| 38 | `Regex.split` | 2 | `function(Regex.Pattern, String) -> List[String]` | L22 |
| 39 | `Csv.parse` | 1 | `function(String) -> Result[List[List[String]], Csv.ParseError]` | L23 |
| 39 | `Csv.parseWith` | 2 | `function(String, Character) -> Result[List[List[String]], Csv.ParseError]` | L23 |
| 39 | `Csv.parseWithHeader` | 1 | `function(String) -> Result[List[Map[String, String]], Csv.ParseError]` | L23 |
| 39 | `Csv.format` | 1 | `function(List[List[String]]) -> String` | L23 |
| 39 | `Csv.formatWith` | 2 | `function(List[List[String]], Character) -> String` | L23 |
| 40 | `Time.fromUnixSeconds`・`Time.fromUnixMilliseconds` | 1 | `function(Integer) -> Time.Instant` | L24 |
| 40 | `Time.toUnixSeconds`・`Time.toUnixMilliseconds` | 1 | `function(Time.Instant) -> Integer` | L24 |
| 40 | `Time.addMilliseconds` | 2 | `function(Time.Instant, Integer) -> Time.Instant` | L24 |
| 40 | `Time.differenceMilliseconds` | 2 | `function(Time.Instant, Time.Instant) -> Integer` | L24 |
| 40 | `Time.toDateTime` | 2 | `function(Time.Instant, Integer) -> Time.DateTime` | L24 |
| 40 | `Time.fromDateTime` | 1 | `function(Time.DateTime) -> Result[Time.Instant, String]` | L24 |
| 40 | `Time.formatISO8601` | 2 | `function(Time.Instant, Integer) -> String` | L24 |
| 40 | `Time.parseISO8601` | 1 | `function(String) -> Result[Time.Instant, String]` | L24 |
| 40 | `Time.format` | 3 | `function(Time.Instant, Integer, String) -> Result[String, String]` | L24 |
| 41 | `Encoding.base64Encode`・`Encoding.base64UrlEncode` | 1 | `function(Bytes) -> String` | L25 |
| 41 | `Encoding.base64Decode`・`Encoding.base64UrlDecode` | 1 | `function(String) -> Result[Bytes, String]` | L25 |
| 42 | `Hash.sha256` | 1 | `function(Bytes) -> Bytes` | L25 |

- 部分 41 の中の順は、`base64Encode`・`base64Decode`・`base64UrlEncode`・`base64UrlDecode` である。部分 40 の中の順は、03-08 の表の順（`fromUnixSeconds` から `format` まで）である。
- `Regex.Pattern` と `Regex.Match` の値は `ObjKind::Opaque` の対象である（[ADR 0168](../../design/decisions/0168-regex-match-and-stdlib-opaque-values.md)）。`Regex.Match` は、照合した文字列と、一致の全体と捕獲グループのバイト位置を持つ。照合した文字列は言語の値でなく Rust の `String` として写して持つ（`OpaqueData` は言語の値を含めない。10-08）。
- 失敗の理由の文字列（`Regex.compile`・`Time.fromDateTime`・`Encoding.base64Decode` などの `Result.Error`）は、クレートの誤りの表示をそのまま使ってよい。文面は定めない（03-08「共通の規則」）。処理系が自分で書く理由の文は、各モジュールの `text` の子のモジュールに定数として置く（00-02「文言」）。

### ネットワーク（`http_server`・`http_util`・`http_client`）

| 部分 | 名前 | 権限 | 引数 | 型 | 意味 | 作業 |
|---|---|---|---|---|---|---|
| 43 | `Benitoite.Network.Http.listen` | `Io` | 2 | `function(String, Integer) -> Result[Http.Listener, NetworkError] uses Http.Listen` | 03-09「サーバ」 | L30 |
| 43 | `Benitoite.Network.Http.listenerPort` | `Io` | 1 | `function(Http.Listener) -> Integer uses Http.Listen` | 同上 | L30 |
| 43 | `Benitoite.Network.Http.accept` | `Io` | 1 | `function(Http.Listener) -> Result[Http.Exchange, NetworkError] uses Http.Listen` | 同上、「失敗の種類」 | L30 |
| 43 | `Benitoite.Network.Http.respond` | `Io` | 2 | `function(Http.Exchange, Http.Response) -> Result[Unit, NetworkError] uses Http.Listen` | 同上 | L30 |
| 43 | `Network.Http.requestOf` | `State` | 1 | `function(Http.Exchange) -> Http.Request` | 同上 | L30 |
| 43 | `Network.Http.closeListener` | `State` | 1 | `function(Http.Listener) -> Result[Unit, NetworkError] uses State` | 同上 | L30 |
| 43 | `Network.Http.closeExchange` | `State` | 1 | `function(Http.Exchange) -> Result[Unit, NetworkError] uses State` | 同上、[ADR 0149](../../design/decisions/0149-http-exchange-release-failure.md) | L30 |
| 44 | `Network.Http.pathSegments` | `Pure` | 1 | `function(String) -> List[String]` | 03-09「応答を作る関数と、要求を調べる関数」 | L31 |
| 45 | `Benitoite.Network.Http.send` | `Io` | 1 | `function(Http.ClientRequest) -> Result[Http.Response, NetworkError] uses Http.Connect` | 03-09「クライアント」 | L32 |

`Http.pathSegments` は、パーセント符号化を戻した結果が正しい UTF-8 かを要素ごとに確かめる必要があり、ソースで書くと長くなるので、組み込みの関数にした。

## 構成子のタグ

組み込みの関数が作る・読む U3 の型の構成子のタグを、10-12 の `tags` の末尾に加える。タグは本章のソースの構成子の宣言の順で決まり、F06 のテスト（10-12「確かめること」の「ソースと表の照合」）が、U3 のソースを含めて一致を確かめる。L00 は、このテストの対象に本章の定数を加える。

```rust append=src/builtins/table.rs::tags
    /// レコードの構成子（レコードは構成子が一つの型であり、タグは 0。10-06「脱糖」のレコードの構築）
    pub const RECORD: u32 = 0;
    /// `ByteOrder` の構成子（03-06「Bytes と ByteOrder（初回リリース版）」の順）
    pub const BYTE_ORDER_BIG_ENDIAN: u32 = 0;
    pub const BYTE_ORDER_LITTLE_ENDIAN: u32 = 1;
    /// `NetworkErrorKind` の構成子（01-09「ネットワークの失敗の種類（初回リリース版）」の順）
    pub const NETWORK_ERROR_KIND_HOST_NOT_FOUND: u32 = 0;
    pub const NETWORK_ERROR_KIND_CONNECTION_REFUSED: u32 = 1;
    pub const NETWORK_ERROR_KIND_CONNECTION_RESET: u32 = 2;
    pub const NETWORK_ERROR_KIND_TIMED_OUT: u32 = 3;
    pub const NETWORK_ERROR_KIND_ADDRESS_IN_USE: u32 = 4;
    pub const NETWORK_ERROR_KIND_INVALID_HTTP_DATA: u32 = 5;
    pub const NETWORK_ERROR_KIND_INVALID_INPUT: u32 = 6;
    pub const NETWORK_ERROR_KIND_PERMISSION_DENIED: u32 = 7;
    pub const NETWORK_ERROR_KIND_OTHER: u32 = 8;
    /// `File.EntryKind` の構成子（03-07「File」の順）
    pub const FILE_ENTRY_KIND_REGULAR_FILE: u32 = 0;
    pub const FILE_ENTRY_KIND_DIRECTORY: u32 = 1;
    pub const FILE_ENTRY_KIND_SYMBOLIC_LINK: u32 = 2;
    pub const FILE_ENTRY_KIND_OTHER: u32 = 3;
    /// `File.WriteMode` の構成子（03-07「File」の順）
    pub const FILE_WRITE_MODE_REPLACE: u32 = 0;
    pub const FILE_WRITE_MODE_APPEND: u32 = 1;
    /// `Json.Value` の構成子（03-08「Json」の順）
    pub const JSON_VALUE_NULL: u32 = 0;
    pub const JSON_VALUE_BOOLEAN: u32 = 1;
    pub const JSON_VALUE_INTEGER: u32 = 2;
    pub const JSON_VALUE_FLOAT: u32 = 3;
    pub const JSON_VALUE_STRING: u32 = 4;
    pub const JSON_VALUE_ARRAY: u32 = 5;
    pub const JSON_VALUE_OBJECT: u32 = 6;
```

### レコードの値の作り方

組み込みの関数が作る・読むレコード（`File.Info`・`Process.Command`・`Process.Output`・`Json.ParseError`・`Csv.ParseError`・`Time.Instant`・`Time.DateTime`・`Http.Request`・`Http.Response`・`Http.ClientRequest`）の値は、`alloc_fields(FieldsKind::Ctor, tags::RECORD, …)` の対象であり、値の並びはフィールドを宣言の順に並べたものである（10-06「脱糖」のレコードの構築）。組み込みの関数は、フィールドの位置を本章のソースの宣言の順で読み書きする。位置を数値のまま散らさず、レコードごとに位置の定数を、そのレコードを扱う子のモジュールの中に置く（非公開でよい）。F06 の照合のテストは、フィールドの並びを確かめない。フィールドの並びは、そのレコードを作る作業の単体テスト（作った値をソースのフィールドを読む関数で読むスクリプトのテスト）で確かめる。

## モジュールの一覧の表への追加

```rust append=src/prelude/mod.rs::STDLIB
    StdlibModuleSource {
        path: &["Bytes"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/Bytes.bnt"),
    },
    StdlibModuleSource {
        path: &["ByteOrder"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/ByteOrder.bnt"),
    },
    StdlibModuleSource {
        path: &["NetworkError"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/NetworkError.bnt"),
    },
    StdlibModuleSource {
        path: &["NetworkErrorKind"],
        prelude: true,
        unofficial: false,
        text: include_str!("stdlib/NetworkErrorKind.bnt"),
    },
    StdlibModuleSource {
        path: &["Time"],
        prelude: false,
        unofficial: true,
        text: include_str!("stdlib/Time.bnt"),
    },
    StdlibModuleSource {
        path: &["IO", "Random"],
        prelude: false,
        unofficial: true,
        text: include_str!("stdlib/IO/Random.bnt"),
    },
    StdlibModuleSource {
        path: &["Path"],
        prelude: false,
        unofficial: true,
        text: include_str!("stdlib/Path.bnt"),
    },
    StdlibModuleSource {
        path: &["Json"],
        prelude: false,
        unofficial: true,
        text: include_str!("stdlib/Json.bnt"),
    },
    StdlibModuleSource {
        path: &["Regex"],
        prelude: false,
        unofficial: true,
        text: include_str!("stdlib/Regex.bnt"),
    },
    StdlibModuleSource {
        path: &["Csv"],
        prelude: false,
        unofficial: true,
        text: include_str!("stdlib/Csv.bnt"),
    },
    StdlibModuleSource {
        path: &["Encoding"],
        prelude: false,
        unofficial: true,
        text: include_str!("stdlib/Encoding.bnt"),
    },
    StdlibModuleSource {
        path: &["Hash"],
        prelude: false,
        unofficial: true,
        text: include_str!("stdlib/Hash.bnt"),
    },
    StdlibModuleSource {
        path: &["Network", "Http"],
        prelude: false,
        unofficial: true,
        text: include_str!("stdlib/Network/Http.bnt"),
    },
```

`Benitoite.Time` は、`Benitoite.IO.Clock`（`Clock.now` の型）と `Benitoite.IO.File`（`File.Info` の型）が取り込む。`Benitoite.IO.Clock` は prelude の `Benitoite.Task` が取り込むので、`Benitoite.Time` もどの検査でも読まれる。prelude のモジュールへの import の辺は加えないので、循環は起きない（10-14「prelude と `Benitoite` の名前空間」）。

## 既存のモジュールへの追加

### `Character` と `String`

```text append=src/prelude/stdlib/Character.bnt
/// Returns whether `c` has the Unicode Alphabetic property.
@builtin("Character.isAlphabetic")
public function isAlphabetic(c: Character) -> Boolean

/// Returns whether the Unicode general category of `c` is Nd, Nl, or No.
@builtin("Character.isNumeric")
public function isNumeric(c: Character) -> Boolean

/// Returns whether `c` has the Unicode White_Space property.
@builtin("Character.isWhitespace")
public function isWhitespace(c: Character) -> Boolean

/// Returns whether `c` has the Unicode Uppercase property.
@builtin("Character.isUppercase")
public function isUppercase(c: Character) -> Boolean

/// Returns whether `c` has the Unicode Lowercase property.
@builtin("Character.isLowercase")
public function isLowercase(c: Character) -> Boolean

/// Returns `c` in uppercase. One character may become several, as 'ß' becomes "SS".
@builtin("Character.toUppercase")
public function toUppercase(c: Character) -> String

/// Returns `c` in lowercase. One character may become several.
@builtin("Character.toLowercase")
public function toLowercase(c: Character) -> String
```

```text append=src/prelude/stdlib/String.bnt
/// Returns `s` with each character changed by `Character.toUppercase`.
@builtin("String.toUppercase")
public function toUppercase(s: String) -> String

/// Returns `s` in lowercase. A capital sigma at the end of a word becomes the final form.
@builtin("String.toLowercase")
public function toLowercase(s: String) -> String

/// Returns the UTF-8 encoding of `s`.
@builtin("String.toUTF8")
public function toUTF8(s: String) -> Bytes

/// Reads `b` as UTF-8. Returns `Option.None` when `b` is not valid UTF-8. A leading BOM is kept.
@builtin("String.fromUTF8")
public function fromUTF8(b: Bytes) -> Option[String]
```

### `Map` と `Set`

関数を引数にとる関数は、`toList` で鍵の順に並べたリストに `List` の関数を当てる。受け取った関数は鍵の順に一度ずつ呼ばれる（03-06「関数を引数にとる関数の共通の規則」）。`Map.map` と `Map.filter` が作り直すマップの鍵は、元のマップの鍵そのものなので、`fromList` で鍵が重なることはない。

```text append=src/prelude/stdlib/Map.bnt
/// Returns the value for `k`, or `Option.None` when the map does not have it.
@builtin("Map.get")
public function get[K: key, V](m: Map[K, V], k: K) -> Option[V]

/// Returns the map with the value for `k` set to `value`. An existing key keeps its original form.
@builtin("Map.set")
public function set[K: key, V](m: Map[K, V], k: K, value: V) -> Map[K, V]

/// Returns the map without `k`.
@builtin("Map.remove")
public function remove[K: key, V](m: Map[K, V], k: K) -> Map[K, V]

/// Returns whether the map has `k`.
@builtin("Map.contains")
public function contains[K: key, V](m: Map[K, V], k: K) -> Boolean

/// Returns the number of pairs.
@builtin("Map.size")
public function size[K: key, V](m: Map[K, V]) -> Integer

/// Returns the keys in order.
@builtin("Map.keys")
public function keys[K: key, V](m: Map[K, V]) -> List[K]

/// Returns the values in the order of their keys.
@builtin("Map.values")
public function values[K: key, V](m: Map[K, V]) -> List[V]

/// Returns the map whose values are `f` applied to each key and value. The keys stay the same.
public function map[K: key, V, U, effect E](m: Map[K, V], f: function(K, V) -> U uses E) -> Map[K, U] uses E
  return fromList(List.map(toList(m), lambda(pair) return Pair(Pair.first(pair), f(Pair.first(pair), Pair.second(pair))) end lambda))
end function

/// Returns the pairs for which `p` returns `true`.
public function filter[K: key, V, effect E](m: Map[K, V], p: function(K, V) -> Boolean uses E) -> Map[K, V] uses E
  return fromList(List.filter(toList(m), lambda(pair) return p(Pair.first(pair), Pair.second(pair)) end lambda))
end function

/// Combines the pairs in the order of their keys with `f`, starting from `initial`.
public function fold[K: key, V, A, effect E](m: Map[K, V], initial: A, f: function(A, K, V) -> A uses E) -> A uses E
  return List.fold(toList(m), initial, lambda(acc, pair) return f(acc, Pair.first(pair), Pair.second(pair)) end lambda)
end function

/// Calls `f` with each key and value in the order of the keys.
public function forEach[K: key, V, effect E](m: Map[K, V], f: function(K, V) -> Unit uses E) -> Unit uses E
  return List.forEach(toList(m), lambda(pair) return f(Pair.first(pair), Pair.second(pair)) end lambda)
end function
```

```text append=src/prelude/stdlib/Set.bnt
/// Returns whether the set has `x`.
@builtin("Set.contains")
public function contains[T: key](s: Set[T], x: T) -> Boolean

/// Returns the set with `x` added. An existing element keeps its original form.
@builtin("Set.add")
public function add[T: key](s: Set[T], x: T) -> Set[T]

/// Returns the set without `x`.
@builtin("Set.remove")
public function remove[T: key](s: Set[T], x: T) -> Set[T]

/// Returns the number of elements.
@builtin("Set.size")
public function size[T: key](s: Set[T]) -> Integer

/// Returns the elements in `a` or `b`.
@builtin("Set.union")
public function union[T: key](a: Set[T], b: Set[T]) -> Set[T]

/// Returns the elements in both `a` and `b`.
@builtin("Set.intersection")
public function intersection[T: key](a: Set[T], b: Set[T]) -> Set[T]

/// Returns the elements in `a` and not in `b`.
@builtin("Set.difference")
public function difference[T: key](a: Set[T], b: Set[T]) -> Set[T]

/// Returns the set of `f` applied to each element. Equal results become one element.
public function map[T: key, U: key, effect E](s: Set[T], f: function(T) -> U uses E) -> Set[U] uses E
  return fromList(List.map(toList(s), f))
end function

/// Returns the elements for which `p` returns `true`.
public function filter[T: key, effect E](s: Set[T], p: function(T) -> Boolean uses E) -> Set[T] uses E
  return fromList(List.filter(toList(s), p))
end function

/// Combines the elements in order with `f`, starting from `initial`.
public function fold[T: key, A, effect E](s: Set[T], initial: A, f: function(A, T) -> A uses E) -> A uses E
  return List.fold(toList(s), initial, f)
end function

/// Calls `f` with each element in order.
public function forEach[T: key, effect E](s: Set[T], f: function(T) -> Unit uses E) -> Unit uses E
  return List.forEach(toList(s), f)
end function
```

### 標準の型クラスの `Map`・`Set` の実装

03-06「標準の型クラス（初回リリース版）」の表のうち、`Map`・`Set` の `Show`・`Semigroup`・`Monoid` の実装である。`Show` は `Map.fromList([Pair(1, "a")])` と `Set.fromList([1, 2])` の形で、要素を鍵の順に並べて表す。`Semigroup.combine` の `Map` は、`x` の組の後に `y` の組を並べて `Map.fromList` に渡すので、同じ鍵は `y` の値になり、鍵は `x` のものが残る（03-06「Map と Set（初回リリース版）」の、元の鍵を保つ規則）。

```text append=src/prelude/stdlib/Trait.bnt
// Show, Semigroup, and Monoid for Map and Set

implement[K: key & Show, V: Show] Show[Map[K, V]]
  function show(x: Map[K, V]) -> String
    bind items <- List.map(Map.toList(x), lambda(p) return Show.show(p) end lambda)
    return "Map.fromList([" + String.join(items, ", ") + "])"
  end function
end implement

implement[T: key & Show] Show[Set[T]]
  function show(x: Set[T]) -> String
    bind items <- List.map(Set.toList(x), lambda(e) return Show.show(e) end lambda)
    return "Set.fromList([" + String.join(items, ", ") + "])"
  end function
end implement

implement[K: key, V] Semigroup[Map[K, V]]
  function combine(x: Map[K, V], y: Map[K, V]) -> Map[K, V]
    return Map.fromList(List.concatenate(Map.toList(x), Map.toList(y)))
  end function
end implement

implement[K: key, V] Monoid[Map[K, V]]
  function empty() -> Map[K, V]
    return Map.empty()
  end function
end implement

implement[T: key] Semigroup[Set[T]]
  function combine(x: Set[T], y: Set[T]) -> Set[T]
    return Set.union(x, y)
  end function
end implement

implement[T: key] Monoid[Set[T]]
  function empty() -> Set[T]
    return Set.empty()
  end function
end implement
```

### `IO.Console`

```text append=src/prelude/stdlib/IO/Console.bnt::Read
  /// Reads the rest of the input and splits it into lines.
  function readAllLines() -> Result[List[String], IOError]
  /// Reads the rest of the input as bytes.
  function readAllBytes() -> Result[Bytes, IOError]
```

### `IO.File`

`File.Info` の `modified` は `Time.Instant` なので、`Benitoite.Time` を取り込む。`File.copy` は、前述の「部分と番号」のとおりソースで書く。

```text append=src/prelude/stdlib/IO/File.bnt::imports
import Benitoite.Unofficial.Time
```

```text append=src/prelude/stdlib/IO/File.bnt::Read
  /// Reads the whole file as bytes.
  function readBytes(path: String) -> Result[Bytes, IOError]
  /// Reads the whole file as text and splits it into lines.
  function readLines(path: String) -> Result[List[String], IOError]
  /// Returns whether something exists at the path. Fails when it cannot be checked.
  function exists(path: String) -> Result[Boolean, IOError]
  /// Returns information about the file. A symbolic link itself is described, not its target.
  function info(path: String) -> Result[Info, IOError]
  /// Returns the names in the directory, ordered by their UTF-8 bytes.
  function listDirectory(path: String) -> Result[List[String], IOError]
  /// Returns every file and directory under the directory as relative paths, ordered by their UTF-8 bytes.
  function walk(path: String) -> Result[List[String], IOError]
  /// Returns the absolute path with symbolic links resolved.
  function canonicalize(path: String) -> Result[String, IOError]
  /// Reads at most `maximumBytes` bytes. Returns `Option.None` at the end of the file.
  function readChunk(reader: Reader, maximumBytes: Integer) -> Result[Option[Bytes], IOError]
```

```text append=src/prelude/stdlib/IO/File.bnt::Write
  /// Creates or replaces the file with `content`.
  function writeBytes(path: String, content: Bytes) -> Result[Unit, IOError]
  /// Adds `content` to the end of the file, creating it when missing.
  function appendBytes(path: String, content: Bytes) -> Result[Unit, IOError]
  /// Creates the directory and any missing parents. Does nothing when the directory exists.
  function createDirectory(path: String) -> Result[Unit, IOError]
  /// Removes a file, a symbolic link, or an empty directory.
  function remove(path: String) -> Result[Unit, IOError]
  /// Removes the directory and everything under it. Symbolic links are removed, not followed.
  function removeTree(path: String) -> Result[Unit, IOError]
  /// Moves `from` to `to`.
  function rename(from: String, to: String) -> Result[Unit, IOError]
  /// Opens the file for writing. `WriteMode.Replace` creates or empties it; `WriteMode.Append` adds to its end.
  function openWriter(path: String, mode: WriteMode) -> Result[Writer, IOError]
  /// Writes `text`.
  function write(writer: Writer, text: String) -> Result[Unit, IOError]
  /// Writes `text` and a line feed.
  function writeLine(writer: Writer, text: String) -> Result[Unit, IOError]
  /// Writes `content`.
  function writeChunk(writer: Writer, content: Bytes) -> Result[Unit, IOError]
```

```text append=src/prelude/stdlib/IO/File.bnt
/// Copies the content of the regular file `from` to `to`, replacing `to` when it exists.
public function copy(from: String, to: String) -> Result[Unit, IOError] uses Read, Write
  bind content <- try readBytes(from)
  return writeBytes(to, content)
end function

/// Writes out what was written and closes the writer. A `with` binding closes it in the same way.
@builtin("IO.File.closeWriter")
public function closeWriter(writer: Writer) -> Result[Unit, IOError] uses State

/// Information about a file, returned by `File.info`.
public record Info
  kind: EntryKind
  size: Integer
  modified: Time.Instant
end record

/// What a path points to.
public data EntryKind
  RegularFile
  Directory
  SymbolicLink
  Other
end data

/// How `File.openWriter` opens a file.
public data WriteMode
  /// Create the file or empty it.
  Replace
  /// Add to the end of the file, creating it when missing.
  Append
end data
```

### `IO.Process`

```text append=src/prelude/stdlib/IO/Process.bnt::Environment
  /// Returns the absolute path of the directory of the script that started the run.
  function scriptDirectory() -> String
  /// Returns the value of the environment variable, or `Option.None` when it is not defined.
  function environmentVariable(name: String) -> Result[Option[String], IOError]
  /// Returns the absolute path of the working directory.
  function workingDirectory() -> Result[String, IOError]
```

```text append=src/prelude/stdlib/IO/Process.bnt
/// Starting other programs.
public effect Run
  /// Starts the command without a shell, waits for it, and returns its exit code and output.
  function run(command: Command) -> Result[Output, IOError]
  /// Starts the command with the standard streams of the script, waits for it, and returns its exit code.
  function runAttached(command: Command) -> Result[Integer, IOError]
  /// Runs `commandLine` with `/bin/sh -c` and returns the result as `run` does. Write only POSIX sh.
  function shell(commandLine: String) -> Result[Output, IOError]
end effect

/// A command to start, made with `Process.command` and changed with record update.
public record Command
  program: String
  arguments: List[String]
  workingDirectory: Option[String]
  environment: Map[String, String]
  input: Option[String]
end record

/// The result of a finished command.
public record Output
  exitCode: Integer
  standardOutput: String
  standardError: String
end record

/// Returns a command that uses the base directory, adds no environment variables, and gives no input.
public function command(program: String, arguments: List[String]) -> Command
  return Command(program: program, arguments: arguments, workingDirectory: Option.None, environment: Map.empty(), input: Option.None)
end function
```

### `IO.Clock`

`Benitoite.IO.Clock` はエフェクト `Time` を宣言するので、`Benitoite.Time` を修飾の名前 `Time` のまま取り込むと、型と同じ名前空間の二つの名前（エフェクトと import で付けた名前）が重なり、E0305 の誤りになる（01-03「トップレベルの名前空間」、02-10「診断コード」、[ADR 0129](../../design/decisions/0129-effects-declared-in-modules.md)）。そこで、`as` で別の名前を付けて取り込む。利用者から見える型は `Time.Instant` のままである（型の同一性は宣言したモジュールで決まる）。

```text append=src/prelude/stdlib/IO/Clock.bnt::imports
// The effect of this module is named Time, so the module Benitoite.Time is imported under another name.
import Benitoite.Unofficial.Time as TimeValue
```

```text append=src/prelude/stdlib/IO/Clock.bnt::Time
  /// Returns the current time.
  function now() -> TimeValue.Instant
  /// Returns the difference of local time from UTC in minutes, east positive. Returns 0 when it is unknown.
  function localOffsetMinutes() -> Integer
```

## 新しいモジュール

### prelude の `Bytes`・`ByteOrder`・`NetworkError`・`NetworkErrorKind`

```text file=src/prelude/stdlib/Bytes.bnt
//! Functions on `Bytes`, an immutable sequence of `Byte` values. The type `Bytes` is built in.

/// Returns the empty byte sequence.
@builtin("Bytes.empty")
public function empty() -> Bytes

/// Returns the bytes of `bs` in order.
@builtin("Bytes.fromList")
public function fromList(bs: List[Byte]) -> Bytes

/// Returns the bytes of `ns`, or `Option.None` when a value is not between 0 and 255.
@builtin("Bytes.fromIntegers")
public function fromIntegers(ns: List[Integer]) -> Option[Bytes]

/// Reads two hexadecimal digits per byte. `_` and spaces are skipped.
@builtin("Bytes.fromHex")
public function fromHex(s: String) -> Option[Bytes]

/// Reads eight binary digits per byte. `_` and spaces are skipped.
@builtin("Bytes.fromBinary")
public function fromBinary(s: String) -> Option[Bytes]

/// Returns the bytes as a list.
@builtin("Bytes.toList")
public function toList(b: Bytes) -> List[Byte]

/// Returns two lowercase hexadecimal digits per byte, without separators.
@builtin("Bytes.toHex")
public function toHex(b: Bytes) -> String

/// Returns eight binary digits per byte, without separators.
@builtin("Bytes.toBinary")
public function toBinary(b: Bytes) -> String

/// Returns the number of bytes.
@builtin("Bytes.length")
public function length(b: Bytes) -> Integer

/// Returns the byte at position `i`, or `Option.None` when `i` is out of range.
@builtin("Bytes.get")
public function get(b: Bytes, i: Integer) -> Option[Byte]

/// Returns the bytes from position `start` up to `stop`, or `Option.None` when the positions are not valid.
@builtin("Bytes.slice")
public function slice(b: Bytes, start: Integer, stop: Integer) -> Option[Bytes]

/// Returns the bytes of `a` followed by the bytes of `b`.
@builtin("Bytes.concatenate")
public function concatenate(a: Bytes, b: Bytes) -> Bytes

/// Reads `count` bytes from `offset` as an unsigned integer in the order `order`.
@builtin("Bytes.readUnsigned")
public function readUnsigned(b: Bytes, offset: Integer, count: Integer, order: ByteOrder) -> Option[Integer]

/// Reads `count` bytes from `offset` as a two's complement signed integer in the order `order`.
@builtin("Bytes.readSigned")
public function readSigned(b: Bytes, offset: Integer, count: Integer, order: ByteOrder) -> Option[Integer]

/// Returns `n` as `count` unsigned bytes, or `Option.None` when it does not fit.
@builtin("Bytes.fromUnsigned")
public function fromUnsigned(n: Integer, count: Integer, order: ByteOrder) -> Option[Bytes]

/// Returns `n` as `count` two's complement bytes, or `Option.None` when it does not fit.
@builtin("Bytes.fromSigned")
public function fromSigned(n: Integer, count: Integer, order: ByteOrder) -> Option[Bytes]
```

```text file=src/prelude/stdlib/ByteOrder.bnt
//! Byte orders for reading and writing integers in `Bytes`.

/// The order of the bytes of an integer.
public data ByteOrder
  /// The most significant byte first.
  BigEndian
  /// The least significant byte first.
  LittleEndian
end data
```

```text file=src/prelude/stdlib/NetworkError.bnt
//! Failures of network operations. The type `NetworkError` is built in.

/// Returns the kind of the failure.
@builtin("NetworkError.kind")
public function kind(e: NetworkError) -> NetworkErrorKind

/// Returns a human-readable description of the failure. The wording may change between versions.
@builtin("NetworkError.message")
public function message(e: NetworkError) -> String
```

```text file=src/prelude/stdlib/NetworkErrorKind.bnt
//! Kinds of network failures.

/// The kind of a network failure, returned by `NetworkError.kind`.
public data NetworkErrorKind
  /// The name cannot be resolved.
  HostNotFound
  /// The connection was refused.
  ConnectionRefused
  /// The connection was cut in the middle.
  ConnectionReset
  /// The time ran out.
  TimedOut
  /// The address and port to listen on are in use.
  AddressInUse
  /// What was received is not valid HTTP.
  InvalidHTTPData
  /// A URL or an address is not in a valid form.
  InvalidInput
  /// The operating system refused the operation.
  PermissionDenied
  /// None of the above, including a failed TLS certificate check.
  Other
end data
```

### `IO.Random`

```text file=src/prelude/stdlib/IO/Random.bnt
//! Random numbers. The type `Generator` is built in.

/// Operations that use the hidden generator, seeded from the operating system at the start of a run.
public effect Generate
  /// Returns an integer from `low` up to, but not including, `high`. Stops the program when `high` is not greater than `low`.
  function integer(low: Integer, high: Integer) -> Integer
  /// Returns a number from 0.0 up to, but not including, 1.0.
  function float() -> Float
  /// Returns `true` or `false`.
  function boolean() -> Boolean
  /// Returns the elements in a random order.
  function shuffle[T](xs: List[T]) -> List[T]
  /// Returns a random element, or `Option.None` when the list is empty.
  function choose[T](xs: List[T]) -> Option[T]
end effect

/// Returns a generator made from `seed`. The same seed gives the same values in every version.
@builtin("IO.Random.fromSeed")
public function fromSeed(seed: Integer) -> Generator

/// Returns an integer from `low` up to, but not including, `high`, and the next generator.
@builtin("IO.Random.nextInteger")
public function nextInteger(generator: Generator, low: Integer, high: Integer) -> Pair[Integer, Generator]

/// Returns a number from 0.0 up to, but not including, 1.0, and the next generator.
@builtin("IO.Random.nextFloat")
public function nextFloat(generator: Generator) -> Pair[Float, Generator]

/// Returns the elements in a random order and the next generator.
@builtin("IO.Random.shuffleWith")
public function shuffleWith[T](generator: Generator, xs: List[T]) -> Pair[List[T], Generator]
```

### `Path`

```text file=src/prelude/stdlib/Path.bnt
//! Joining and splitting paths as strings. Nothing here reads the file system.

/// Returns `child` after `base` with a separator between, or `child` when it is absolute.
@builtin("Path.join")
public function join(base: String, child: String) -> String

/// Joins `parts` from the first with `Path.join`. Returns "" for an empty list.
@builtin("Path.joinAll")
public function joinAll(parts: List[String]) -> String

/// Returns the path without its last component, or `Option.None` for a root or an empty path.
@builtin("Path.parent")
public function parent(p: String) -> Option[String]

/// Returns the last component, or `Option.None` when it is `..`, a root, or empty.
@builtin("Path.fileName")
public function fileName(p: String) -> Option[String]

/// Returns the file name without its last extension.
@builtin("Path.stem")
public function stem(p: String) -> Option[String]

/// Returns the extension of the file name without the dot.
@builtin("Path.extension")
public function extension(p: String) -> Option[String]

/// Returns the path with its extension changed to `extension`. An empty `extension` removes it.
@builtin("Path.withExtension")
public function withExtension(p: String, extension: String) -> String

/// Returns whether the path is absolute.
@builtin("Path.isAbsolute")
public function isAbsolute(p: String) -> Boolean

/// Returns the components, with the root first for an absolute path.
@builtin("Path.components")
public function components(p: String) -> List[String]

/// Removes `.` and cancels `..` with the component before it, without reading the file system.
@builtin("Path.normalize")
public function normalize(p: String) -> String
```

### `Json`

```text file=src/prelude/stdlib/Json.bnt
//! JSON values, parsing, and writing.

/// A JSON value. Object members are kept in the order of their keys.
public data Value
  Null
  Boolean(Boolean)
  Integer(Integer)
  Float(Float)
  String(String)
  Array(List[Value])
  Object(Map[String, Value])
end data

/// Where and why parsing failed. `line` and `column` count from 1; `column` counts characters.
public record ParseError
  line: Integer
  column: Integer
  message: String
end record

/// Reads `text` as JSON. Spaces before and after the value are allowed.
@builtin("Json.parse")
public function parse(text: String) -> Result[Value, ParseError]

/// Writes the value without spaces. Members are written in the order of their keys.
@builtin("Json.stringify")
public function stringify(value: Value) -> String

/// Writes the value with line breaks and two spaces of indentation per level.
@builtin("Json.stringifyPretty")
public function stringifyPretty(value: Value) -> String

/// Returns the member `k` of an object, or `Option.None` for other values and missing members.
public function get(value: Value, k: String) -> Option[Value]
  return match value with
    case Value.Object(members) -> Map.get(members, k)
    case _ -> Option.None
  end match
end function

/// Returns the element at `index` of an array, or `Option.None` for other values and positions out of range.
public function at(value: Value, index: Integer) -> Option[Value]
  return match value with
    case Value.Array(items) -> List.get(items, index)
    case _ -> Option.None
  end match
end function

/// Returns the content of `Value.String`.
public function asString(value: Value) -> Option[String]
  return match value with
    case Value.String(s) -> Option.Some(s)
    case _ -> Option.None
  end match
end function

/// Returns the content of `Value.Integer`.
public function asInteger(value: Value) -> Option[Integer]
  return match value with
    case Value.Integer(n) -> Option.Some(n)
    case _ -> Option.None
  end match
end function

/// Returns the content of `Value.Float`, or the content of `Value.Integer` converted to `Float`.
public function asFloat(value: Value) -> Option[Float]
  return match value with
    case Value.Float(x) -> Option.Some(x)
    case Value.Integer(n) -> Option.Some(Integer.toFloat(n))
    case _ -> Option.None
  end match
end function

/// Returns the content of `Value.Boolean`.
public function asBoolean(value: Value) -> Option[Boolean]
  return match value with
    case Value.Boolean(b) -> Option.Some(b)
    case _ -> Option.None
  end match
end function

/// Returns the content of `Value.Array`.
public function asArray(value: Value) -> Option[List[Value]]
  return match value with
    case Value.Array(items) -> Option.Some(items)
    case _ -> Option.None
  end match
end function

/// Returns the content of `Value.Object`.
public function asObject(value: Value) -> Option[Map[String, Value]]
  return match value with
    case Value.Object(members) -> Option.Some(members)
    case _ -> Option.None
  end match
end function
```

### `Regex`

`Regex.replaceAllWith` は、受け取った関数を呼ぶのでソースで書く（03-08「Regex」）。一致を左から順に `f` に渡し、一致の前の部分と `f` の値を交互につなぐ。

```text file=src/prelude/stdlib/Regex.bnt
//! Regular expressions with matching time linear in the input. The types `Pattern` and `Match` are built in.

/// Builds a regular expression. Returns the reason as `Result.Error` when the syntax is wrong.
@builtin("Regex.compile")
public function compile(source: String) -> Result[Pattern, String]

/// Returns whether some part of `text` matches.
@builtin("Regex.isMatch")
public function isMatch(pattern: Pattern, text: String) -> Boolean

/// Returns the leftmost match.
@builtin("Regex.find")
public function find(pattern: Pattern, text: String) -> Option[Match]

/// Returns the non-overlapping matches from the left.
@builtin("Regex.findAll")
public function findAll(pattern: Pattern, text: String) -> List[Match]

/// Returns the matched text.
@builtin("Regex.matchText")
public function matchText(m: Match) -> String

/// Returns the byte position where the match starts.
@builtin("Regex.matchByteStart")
public function matchByteStart(m: Match) -> Integer

/// Returns the byte position where the match ends. The match is from the start up to, but not including, the end.
@builtin("Regex.matchByteEnd")
public function matchByteEnd(m: Match) -> Integer

/// Returns the text of capture group `index`, where 0 is the whole match.
@builtin("Regex.group")
public function group(m: Match, index: Integer) -> Option[String]

/// Returns the text of the capture group named `name`.
@builtin("Regex.namedGroup")
public function namedGroup(m: Match, name: String) -> Option[String]

/// Replaces the first match with `replacement`, taken literally.
@builtin("Regex.replaceFirst")
public function replaceFirst(pattern: Pattern, text: String, replacement: String) -> String

/// Replaces every match with `replacement`, taken literally.
@builtin("Regex.replaceAll")
public function replaceAll(pattern: Pattern, text: String, replacement: String) -> String

/// Splits `text` at each match.
@builtin("Regex.split")
public function split(pattern: Pattern, text: String) -> List[String]

/// Replaces every match with `f` applied to it. `f` is called for each match from the left.
public function replaceAllWith[effect E](pattern: Pattern, text: String, f: function(Match) -> String uses E) -> String uses E
  return replaceFrom(text, findAll(pattern, text), f, 0, 0, [])
end function

function replaceFrom[effect E](text: String, matches: List[Match], f: function(Match) -> String uses E, i: Integer, position: Integer, parts: List[String]) -> String uses E
  return match List.get(matches, i) with
    case Option.None -> String.join(List.append(parts, sliceOrEmpty(text, position, String.byteLength(text))), "")
    case Option.Some(m) ->
      bind replaced <- f(m)
      bind before <- sliceOrEmpty(text, position, matchByteStart(m))
      replaceFrom(text, matches, f, i + 1, matchByteEnd(m), List.append(List.append(parts, before), replaced))
  end match
end function

function sliceOrEmpty(text: String, start: Integer, stop: Integer) -> String
  return Option.unwrapOr(String.byteSlice(text, start, stop), "")
end function
```

一致の位置は常に文字の境目にあるので、`sliceOrEmpty` が空文字列を返すのは、処理系の不具合のときだけである。

### `Csv`・`Time`・`Encoding`・`Hash`

```text file=src/prelude/stdlib/Csv.bnt
//! Reading and writing CSV as in RFC 4180. Every field is a `String`.

/// Why parsing failed. `line` is the line where the error was found, counting from 1.
public record ParseError
  line: Integer
  message: String
end record

/// Reads `text` as rows of fields separated by commas.
@builtin("Csv.parse")
public function parse(text: String) -> Result[List[List[String]], ParseError]

/// Reads `text` as rows of fields separated by `delimiter`.
@builtin("Csv.parseWith")
public function parseWith(text: String, delimiter: Character) -> Result[List[List[String]], ParseError]

/// Reads the first row as the header and each other row as a map from header names to fields.
@builtin("Csv.parseWithHeader")
public function parseWithHeader(text: String) -> Result[List[Map[String, String]], ParseError]

/// Writes the rows as CSV, ending each row with a line feed.
@builtin("Csv.format")
public function format(rows: List[List[String]]) -> String

/// Writes the rows as CSV with `delimiter` between fields.
@builtin("Csv.formatWith")
public function formatWith(rows: List[List[String]], delimiter: Character) -> String
```

```text file=src/prelude/stdlib/Time.bnt
//! Points in time and calendar dates with a fixed offset from UTC. Time zone names are not used.

/// A point in time, as nanoseconds since 1970-01-01T00:00:00Z.
public record Instant
  unixNanoseconds: Integer
end record

/// A calendar date and time seen with an offset of `offsetMinutes` from UTC.
public record DateTime
  year: Integer
  month: Integer
  day: Integer
  hour: Integer
  minute: Integer
  second: Integer
  nanosecond: Integer
  offsetMinutes: Integer
end record

/// Returns the time `seconds` seconds after 1970-01-01T00:00:00Z.
@builtin("Time.fromUnixSeconds")
public function fromUnixSeconds(seconds: Integer) -> Instant

/// Returns the time `milliseconds` milliseconds after 1970-01-01T00:00:00Z.
@builtin("Time.fromUnixMilliseconds")
public function fromUnixMilliseconds(milliseconds: Integer) -> Instant

/// Returns the seconds since 1970-01-01T00:00:00Z, rounded toward negative infinity.
@builtin("Time.toUnixSeconds")
public function toUnixSeconds(t: Instant) -> Integer

/// Returns the milliseconds since 1970-01-01T00:00:00Z, rounded toward negative infinity.
@builtin("Time.toUnixMilliseconds")
public function toUnixMilliseconds(t: Instant) -> Integer

/// Returns the time `milliseconds` milliseconds after `t`.
@builtin("Time.addMilliseconds")
public function addMilliseconds(t: Instant, milliseconds: Integer) -> Instant

/// Returns `a` minus `b` in milliseconds, rounded toward negative infinity.
@builtin("Time.differenceMilliseconds")
public function differenceMilliseconds(a: Instant, b: Instant) -> Integer

/// Returns the date and time of `t` seen with an offset of `offsetMinutes` from UTC.
@builtin("Time.toDateTime")
public function toDateTime(t: Instant, offsetMinutes: Integer) -> DateTime

/// Returns the time that `dt` stands for, or the reason when the date does not exist or is out of range.
@builtin("Time.fromDateTime")
public function fromDateTime(dt: DateTime) -> Result[Instant, String]

/// Writes `t` in ISO 8601 form, such as 2026-09-28T12:34:56.789+09:00.
@builtin("Time.formatISO8601")
public function formatISO8601(t: Instant, offsetMinutes: Integer) -> String

/// Reads ISO 8601 text that has an offset or `Z`.
@builtin("Time.parseISO8601")
public function parseISO8601(text: String) -> Result[Instant, String]

/// Writes `t` by `pattern` with strftime specifiers such as %Y and %m. Unknown specifiers give `Result.Error`.
@builtin("Time.format")
public function format(t: Instant, offsetMinutes: Integer, pattern: String) -> Result[String, String]
```

```text file=src/prelude/stdlib/Encoding.bnt
//! Base64 encoding of bytes.

/// Encodes `b` with the standard alphabet and `=` padding.
@builtin("Encoding.base64Encode")
public function base64Encode(b: Bytes) -> String

/// Decodes standard Base64 with `=` padding. Spaces and line breaks are errors.
@builtin("Encoding.base64Decode")
public function base64Decode(text: String) -> Result[Bytes, String]

/// Encodes `b` with the URL and file name safe alphabet, without padding.
@builtin("Encoding.base64UrlEncode")
public function base64UrlEncode(b: Bytes) -> String

/// Decodes URL and file name safe Base64 without padding.
@builtin("Encoding.base64UrlDecode")
public function base64UrlDecode(text: String) -> Result[Bytes, String]
```

```text file=src/prelude/stdlib/Hash.bnt
//! Hash values of bytes.

/// Returns the SHA-256 hash of `b` (32 bytes).
@builtin("Hash.sha256")
public function sha256(b: Bytes) -> Bytes
```

### `Network.Http`

`Http.serve` は、03-09「サーバ」の書き方のとおりである。同じモジュールの関数と型は修飾せずに書く（10-14「書き方の方針」）。

```text file=src/prelude/stdlib/Network/Http.bnt
//! HTTP/1.1 servers without TLS and clients for http and https URLs.
//! The resource types `Listener` and `Exchange` are built in.

import Benitoite.Unofficial.Json

/// Listening for connections, accepting requests, and responding.
public effect Listen
  /// Starts listening on `port` of `host`. Port 0 lets the operating system choose a free port.
  function listen(host: String, port: Integer) -> Result[Listener, NetworkError]
  /// Returns the port the listener listens on.
  function listenerPort(listener: Listener) -> Integer
  /// Waits for the next request and accepts it. Other tasks run while it waits.
  function accept(listener: Listener) -> Result[Exchange, NetworkError]
  /// Sends the response. Stops the program when called twice for one exchange.
  function respond(exchange: Exchange, response: Response) -> Result[Unit, NetworkError]
end effect

/// Connecting to HTTP servers and sending requests.
public effect Connect
  /// Sends the request and returns the response, including 4xx and 5xx responses.
  function send(request: ClientRequest) -> Result[Response, NetworkError]
end effect

/// A request received by a server. Header names are in lowercase, in the order received.
public record Request
  method: String
  path: String
  query: List[Pair[String, String]]
  headers: List[Pair[String, String]]
  body: Bytes
end record

/// A response sent by a server or received by a client.
public record Response
  status: Integer
  headers: List[Pair[String, String]]
  body: Bytes
end record

/// A request sent by a client, made with `Http.clientRequest` and changed with record update.
public record ClientRequest
  method: String
  url: String
  headers: List[Pair[String, String]]
  body: Bytes
  timeoutMilliseconds: Integer
end record

/// Returns the request that was accepted. It can be used after the exchange is closed.
@builtin("Network.Http.requestOf")
public function requestOf(exchange: Exchange) -> Request

/// Stops listening. A `with` binding closes the listener in the same way.
@builtin("Network.Http.closeListener")
public function closeListener(listener: Listener) -> Result[Unit, NetworkError] uses State

/// Sends status 500 when no response was sent, then closes the connection.
/// A `with` binding closes the exchange in the same way, ignoring failures.
@builtin("Network.Http.closeExchange")
public function closeExchange(exchange: Exchange) -> Result[Unit, NetworkError] uses State

/// Splits `path` at `/`, drops empty parts, and decodes percent-encoding where the result is valid UTF-8.
@builtin("Network.Http.pathSegments")
public function pathSegments(path: String) -> List[String]

/// Listens on `port` of `host` and runs `handler` in a new task for each request.
/// Returns `Result.Error` when listening cannot start or accepting fails.
public function serve[effect E](host: String, port: Integer, handler: function(Request) -> Response uses E) -> Result[Unit, NetworkError] uses Listen, State, E
  with listener = try listen(host, port),
       group = TaskGroup.open() do
    return serveLoop(listener, group, handler)
  end with
end function

function serveLoop[effect E](listener: Listener, group: TaskGroup, handler: function(Request) -> Response uses E) -> Result[Unit, NetworkError] uses Listen, State, E
  bind exchange <- try accept(listener)
  bind _ <- TaskGroup.spawn(group, lambda()
    with current = exchange do
      return respond(current, handler(requestOf(current)))
    end with
  end lambda)
  return serveLoop(listener, group, handler)
end function

/// Returns a response whose body is `s` as plain text.
public function text(status: Integer, s: String) -> Response
  return Response(status: status, headers: [Pair("content-type", "text/plain; charset=utf-8")], body: String.toUTF8(s))
end function

/// Returns a response whose body is `s` as HTML.
public function html(status: Integer, s: String) -> Response
  return Response(status: status, headers: [Pair("content-type", "text/html; charset=utf-8")], body: String.toUTF8(s))
end function

/// Returns a response whose body is `value` written by `Json.stringify`.
public function json(status: Integer, value: Json.Value) -> Response
  return Response(status: status, headers: [Pair("content-type", "application/json")], body: String.toUTF8(Json.stringify(value)))
end function

/// Returns the value of the first header whose name equals `name`, ignoring case.
public function header(headers: List[Pair[String, String]], name: String) -> Option[String]
  bind wanted <- String.toLowercase(name)
  return match List.find(headers, lambda(h) return String.toLowercase(Pair.first(h)) = wanted end lambda) with
    case Option.Some(h) -> Option.Some(Pair.second(h))
    case Option.None -> Option.None
  end match
end function

/// Returns a request with no headers, an empty body, and a timeout of 30000 milliseconds.
public function clientRequest(method: String, url: String) -> ClientRequest
  return ClientRequest(method: method, url: url, headers: [], body: Bytes.empty(), timeoutMilliseconds: 30000)
end function

/// Sends a GET request to `url`, as `Http.send(Http.clientRequest("GET", url))`.
public function get(url: String) -> Result[Response, NetworkError] uses Connect
  return send(clientRequest("GET", url))
end function
```

## 文法の確かめ

本章のソース（`text file=` と `text append=` の全文）は、10-14「文法の確かめ」と同じく、[tools/grammar-check](../../../tools/grammar-check/README.md) の字句解析器と照合器で、01-02「初回リリース版の文法の全体」に、`@builtin` を付けた本体のない関数の宣言（02-03「標準ライブラリのソースの構文」）を加えた文法で読めることを確かめた（2026-09-30）。エフェクトの宣言の中に加える操作と、先頭に加える import は、10-14 のソースに差し込んだ後のファイルの全体で確かめた。局所の束縛の規則（`scope_check.py`）も確かめた。名前解決と型検査の誤りは確かめていない。L00 が、本章のソースを処理系で読んで確かめる（後述の「確かめること」）。

## 確かめること

| テスト | 書く作業 | 内容 |
|---|---|---|
| 表の形 | L00 | 10-12「確かめること」の表の形のテストを、U3 の部分を含めて通す。部分の数と各部分の項目の数が、10-12 と本章の「部分と番号」を合わせたものと一致する |
| ソースと表の照合 | L00 | 10-12 の照合のテスト（F06 が書いたもの）が、本章のソースを含めて通る。本章の `tags` の定数を照合の対象に加える |
| 標準ライブラリのソースの検査 | L00 | `STDLIB` のすべてのモジュールを、利用者のモジュールと同じく名前解決と型検査に通し、誤りがないことを確かめる（10-14「作業の割り当て」の F07〜F10 のテストを、U3 のモジュールを含めて通す）。非公式のモジュールは、`import Benitoite.Unofficial.…` と書いたスクリプトから読ませる |
| 取り込みの名前 | L00 | U3 の非公式のモジュールを `import Benitoite.Json` と書くと E0321、標準のモジュール（`Bytes` など prelude のもの）は import なしで使える |
| 項目ごとの単体テスト | 本体を書く作業（L01〜L32） | 10-12「確かめること」と同じ。項目ごとに本体の関数を直接呼び、設計書の意味どおりの値と実行時エラーを確かめる |
| ソースの関数のテスト | ソースの関数を受け持つ作業 | ソースの関数（`Map.map`、`File.copy`、`Json.get`、`Regex.replaceAllWith`、`Http.serve` など）を、スクリプトのテストで確かめる。組み込みの関数と違い差分テストの対象になりうるが、IO を行うものとタスクを使うものは差分テストに入らないので、スクリプトのテストで確かめる |

## 作業ごとの項目の数

| 作業 | `Pure` | `State` | `Io` | 組み込みの計 | ソースの関数 | 関数の計 |
|---|---|---|---|---|---|---|
| L01 | 9 | 0 | 0 | 9 | 0 | 9 |
| L02 | 14 | 0 | 0 | 14 | 8 | 22 |
| L03 | 18 | 0 | 0 | 18 | 0 | 18 |
| L10 | 0 | 0 | 7 | 7 | 1 | 8 |
| L11 | 0 | 0 | 13 | 13 | 1 | 14 |
| L12 | 0 | 1 | 5 | 6 | 0 | 6 |
| L13 | 0 | 0 | 3 | 3 | 0 | 3 |
| L14 | 4 | 0 | 5 | 9 | 0 | 9 |
| L20 | 10 | 0 | 0 | 10 | 0 | 10 |
| L21 | 3 | 0 | 0 | 3 | 8 | 11 |
| L22 | 12 | 0 | 0 | 12 | 1 | 13 |
| L23 | 5 | 0 | 0 | 5 | 0 | 5 |
| L24 | 11 | 0 | 0 | 11 | 0 | 11 |
| L25 | 5 | 0 | 0 | 5 | 0 | 5 |
| L30 | 2 | 3 | 4 | 9 | 0 | 9 |
| L31 | 1 | 0 | 0 | 1 | 5 | 6 |
| L32 | 0 | 0 | 1 | 1 | 2 | 3 |
| 計 | 94 | 4 | 38 | 136 | 26 | 162 |

ソースの関数は、L00 が本章の全文を置くので、本体を書く作業はない。「ソースの関数」の欄の作業は、その関数のテストを書き、ソースの誤りを見つけたら報告する。

## 作業の割り当て

| 作業 | 本章で受け持つもの |
|---|---|
| L00 | 本章のすべてのブロックを置く（`place --task L00`）。`funcs/mod.rs` の `PARTS` に部分 22〜45 を加え、すべての項目を仮の本体で宣言する。表の形・照合・ソースの検査・取り込みの名前のテスト |
| L01 | 部分 22・23 の本体と単体テスト |
| L02 | 部分 24・25 の本体と単体テスト、`Map`・`Set` のソースの関数と `Trait` の実装のテスト、操作の列のモデルとの比較の拡張 |
| L03 | 部分 26・27 の本体と単体テスト |
| L10 | 部分 29〜31 の本体と単体テスト、`Process.command` のテスト |
| L11 | 部分 32 の本体と単体テスト、`File.copy` のテスト |
| L12 | 部分 33 の本体と単体テスト |
| L13 | 部分 34 の本体と単体テスト |
| L14 | 部分 35 の本体と単体テスト |
| L20〜L25 | 部分 36〜42 の本体と単体テスト、`Json`・`Regex` のソースの関数のテスト |
| L30 | 部分 28・43 の本体と単体テスト |
| L31 | 部分 44 の本体と単体テスト、`Http.serve` と応答を作る関数のテスト |
| L32 | 部分 45 の本体と単体テスト、`Http.get`・`Http.clientRequest` のテスト |
