# ライブラリの構成

## 目的と範囲

標準ライブラリをどう作るかを定める。対象は、標準ライブラリの関数の実装の方法の区分、prelude と import を要するモジュールの分担、外部に作用する関数が守る規則、実装に使う Rust のクレートとそのライセンス、処理系が特別に扱う型と関数である。各モジュールの関数は、[標準ライブラリ](03-06-stdlib.md)、[IO のモジュール](03-07-io-modules.md)、[テキストとデータの処理](03-08-text-and-data.md)、[ネットワークのモジュール](03-09-network.md)で定める。

## 前提

標準ライブラリは、処理系と一緒に配るモジュールの全体であり、名前空間 `Benitoite` の下に置く。初回リリース版は、パッケージ管理、外部の関数の層、標準ライブラリと別に配る公式のライブラリを持たない（[ロードマップ](../00-overview/00-03-roadmap.md)）。その範囲でスクリプトに要る機能（正規表現、JSON、CSV、パス、時刻、HTTP など）は標準ライブラリにそろえる。その後、実験的として手元の[パッケージ](../06-tooling/06-09-packages.md)の取り込みと、WASM のコンポーネントから本体を与える[外部の関数](03-10-external-functions.md)を加えた。

## 仕様

### 実装の方法

【決定】標準ライブラリの関数は、次の四つの方法のどれかで作る。どの方法で作るかは、利用者からは見えず、prelude に入るかどうかとも関係しない。

| 方法 | 対象 | 例 |
|---|---|---|
| 標準ライブラリのソース（言語で書き、処理系に埋め込む） | 関数を引数にとる関数（タスクを起動する関数と `Reference.update` を除く）、標準の型クラスの実装など、言語で書ける関数 | `List.map`・`Option.map`、`Benitoite.Trait` の実装、`Http.serve` |
| 自作の組み込みの関数（Rust） | 言語の中核（永続コレクション、基本型の演算、`Decimal`）と、小さな機能 | `List`・`Map`・`Set` の操作、16 進数の変換、乱数の生成器、HTTP サーバの接続の層（解析はクレート） |
| Rust の標準ライブラリで作る組み込みの関数 | OS の機能を使う関数 | ファイル、ディレクトリ（木の操作の `File.walk`・`File.removeTree` は `rustix` を使う）、プロセス、環境変数、標準入力、パス、時刻の読み取り |
| Rust のクレートを包む組み込みの関数 | 既存の OSS の実装を使う機能 | 正規表現、JSON、CSV、時刻の書式、Base64、SHA-256、HTTP のクライアントと TLS |

標準ライブラリのソースの書き方は[標準ライブラリ](03-06-stdlib.md)の「標準ライブラリのソースの書き方」で、組み込みの関数と標準ライブラリのソースを名前解決で結ぶ方法は[名前解決とモジュール読込](../02-impl/02-04-resolver.md)で定める。

【方針】言語の中核（型システム・エフェクト・コレクション）に当たる関数は自作し、それ以外の機能は既存の OSS を使う（[目的と設計原則](../00-overview/00-01-goals.md)の「目的の衝突」）。

### prelude と import を要するモジュール

【決定】幅付きの数の七モジュール `Integer8`・`Integer16`・`Integer32`・`UnsignedInteger16`・`UnsignedInteger32`・`UnsignedInteger64`・`Float32` と、`Integer64`・`Float64`・`UnsignedInteger8`・`UnsignedInteger` も prelude の標準モジュールとする。型名とモジュールの修飾名を import なしで使え、`Unofficial` を挟まない。既存の標準モジュールの順序を保ち、これらを一覧の末尾に加える。

`Integer64`・`Float64`・`UnsignedInteger8` の公開の関数は、それぞれ既存の `Integer`・`Float`・`Byte` の関数へ転送する言語の関数である。`UnsignedInteger` も `UnsignedInteger64` の関数へ転送する。型の別名だけではモジュールの関数名の別名にはならないので、型の同一性と関数の転送を分けて扱う。Rust の本体と組み込みの関数の番号、型クラスの実装を複製しない。理由: 幅付きの名前を型と関数にそろえて使えるようにし、既存の関数の振る舞いと診断の名前を保つためである。

【決定】prelude には、基本型、コレクション、`Option`・`Result` など、ほとんどのスクリプトが使うモジュールを入れる。IO を行うモジュール（`Benitoite.IO` の下）、ネットワークの操作を行うモジュール（`Benitoite.Network` の下）、標準の型クラス（`Benitoite.Trait`）、テキストとデータを扱う純粋なモジュール（`Benitoite.Path`・`Benitoite.Json` など）は、import を要する。一覧は[標準ライブラリ](03-06-stdlib.md)の「名前空間と prelude（初回リリース版）」で定める。

【決定】初回リリース版では、prelude のモジュールと `Benitoite.Trait` を標準のモジュールとし、IO・ネットワーク・テキストとデータのモジュールを非公式のモジュールとする。非公式のモジュールは `Benitoite.Unofficial` の下の名前で取り込む（[標準ライブラリ](03-06-stdlib.md)の「標準のモジュールと非公式のモジュール（初回リリース版）」）。本章は、非公式のモジュールも `Unofficial` を挟まない名前（モジュールの同一性に使う名前。`Benitoite.IO.Console` など）で書く。

### 外部に作用する関数の規則

【決定】初回リリース版では、外部に作用する経路は標準ライブラリの IO とネットワークの関数だけである。これらの関数は、次の規則を守る。

- 外部に作用する操作は、すべて IO 実行器を通す（[ランタイム](../02-impl/02-09-runtime.md)の「IO 実行器」）。操作を処理する言語のハンドラは VM が探し、どのハンドラも処理しなかった操作だけを IO 実行器が受け取って行う（[ランタイム](../02-impl/02-09-runtime.md)の「操作の振り分け」）。
- 関数の型は、行う操作の組み込みのエフェクトを持つ（[エフェクト](../01-spec/01-07-effects.md)）。
- クレートを包む組み込みの関数のうち外部に作用するものも、同じ規則に従う。クレートが OS の資源に直接触れる場合は、その呼び出しを IO 実行器の中で行う。

これらの規則により、外部に作用するすべての経路が、エフェクトの型に現れ、ハンドラで処理できる操作になる。

### 使う Rust のクレート

【決定】標準ライブラリと外部の関数の検査に、次のクレートを使う。

| 用途 | クレート | リポジトリ | ライセンス |
|---|---|---|---|
| WASM のコンポーネントの検査と実行系 | `wasmtime` | https://github.com/bytecodealliance/wasmtime | Apache-2.0 WITH LLVM-exception |
| 正規表現 | `regex` | https://github.com/rust-lang/regex | MIT OR Apache-2.0 |
| JSON | `serde_json` | https://github.com/serde-rs/json | MIT OR Apache-2.0 |
| JSON の値の組み立て（`serde_json` が呼ぶ読み手の trait） | `serde_core` | https://github.com/serde-rs/serde | MIT OR Apache-2.0 |
| CSV | `csv-core` | https://github.com/BurntSushi/rust-csv | Unlicense OR MIT |
| 時刻の計算と書式 | `jiff` | https://github.com/BurntSushi/jiff | Unlicense OR MIT |
| Base64 | `base64` | https://github.com/marshallpierce/rust-base64 | MIT OR Apache-2.0 |
| SHA-256 | `sha2` | https://github.com/RustCrypto/hashes | MIT OR Apache-2.0 |
| OS の乱数（乱数の種） | `getrandom` | https://github.com/rust-random/getrandom | MIT OR Apache-2.0 |
| ディレクトリの木の操作（`File.walk`・`File.removeTree`） | `rustix` | https://github.com/bytecodealliance/rustix | Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT |
| 表示の幅の計算 | `unicode-width` | https://github.com/unicode-rs/unicode-width/tree/v0.2.2 | MIT OR Apache-2.0 |

- `unicode-width` は、通常の直接依存として `version = "=0.2.2"`・`default-features = false`・`features = ["cjk"]` を指定する。表示の幅の Unicode の版は 17.0.0 に固定し、Character の分類の版と区別する。通常構成で必須の依存を持たず、`no_std` で使える（出典: [0.2.2 の Cargo.toml](https://github.com/unicode-rs/unicode-width/blob/v0.2.2/Cargo.toml)、[API 文書](https://docs.rs/unicode-width/0.2.2/unicode_width/)、[生成済み表の UNICODE_VERSION](https://github.com/unicode-rs/unicode-width/blob/v0.2.2/src/tables.rs)）。共通の本体は `base::display_width` に置き、VM・言語の値・Host・Wasmtime に依存させない。依存の更新による幅の変更は互換性の変更として記録する。理由: OS や構成によらず同じ幅を計算し、文字列全体の例外を含む算法を基盤の OSS に委ねるためである。String の純粋な関数の集合を構成によって変えないため、組込み向けの構成でもこの依存を共通に含め、Cargo の機能では外さない。
- `jiff` は、タイムゾーンのデータを同梱する機能を切って使う。jiff 0.2.37 は、プロセスで一つ持つ二つの内部の大域の状態を使う。システムのタイムゾーンを 5 分保持するキャッシュ（出典: jiff 0.2.37 の `src/tz/system/mod.rs` の `TTL`・`CACHE`）と、プロセスで一つだけ作る zoneinfo のデータベース（出典: 同 `src/tz/db/mod.rs` の `DB`）である。データベースは、読んだゾーンのデータと名前の一覧を 5 分ごとに読み直す（出典: 同 `src/tz/db/zoneinfo/enabled.rs` の `DEFAULT_TTL`）。処理系は `crates/benitoite/src/runtime/sched/parts.rs` の `TimeZone::try_system()` でこれらを使う。同じプロセスの中では、システムのタイムゾーンの変更が最大 5 分遅れて `Clock.localOffsetMinutes` に現れ、テストの実行器の複数の実行もこのキャッシュを共有する。
- `serde_json` は、機能 `float_roundtrip` を付け、機能 `arbitrary_precision` を付けずに使う。JSON の値は、`serde_core` の読み手の trait を実装して直接組み立て、数が整数か浮動小数点数かは元の字面で決める（[テキストとデータの処理](03-08-text-and-data.md)の「Json」）。理由: `arbitrary_precision` は数を特別な鍵のオブジェクトとして渡すので、同じ鍵を持つ入力のオブジェクトを数と取り違えるからである。
- 16 進数の変換と乱数の生成器は自作する。乱数の生成器は、アルゴリズムを仕様で定め、同じ種から同じ列を作る（[IO のモジュール](03-07-io-modules.md)の「Random」）。
- HTTP と TLS には、次のクレートを使う。HTTP サーバは、`httparse` と `mio` の上に接続の層を自作する。`mio` は、HTTP に限らず、IO 実行器のイベントループ（`Clock.sleep` の時間の経過を待つことを含む）に使う。TLS の暗号の provider には `rustls-graviola` を使う。理由: 本番に使える TLS の暗号の実装のうち `ring` と `aws-lc-rs` はビルドに C コンパイラを要するが、`graviola` は Rust のコンパイラだけでビルドできる。ルート証明書は OS のものを使い、`webpki-roots` は使わない。

  | 用途 | クレート | リポジトリ | ライセンス |
  |---|---|---|---|
  | HTTP の解析 | `httparse` | https://github.com/seanmonstar/httparse | MIT OR Apache-2.0 |
  | イベントループ（接続の待ち受けと読み書き、時間の経過を待つこと） | `mio` | https://github.com/tokio-rs/mio | MIT |
  | HTTP のクライアント | `ureq` | https://github.com/algesten/ureq | MIT OR Apache-2.0 |
  | HTTP のクライアントの要求と応答の処理 | `ureq-proto` | https://github.com/algesten/ureq-proto | MIT OR Apache-2.0 |
  | TLS | `rustls` | https://github.com/rustls/rustls | Apache-2.0 OR ISC OR MIT |
  | TLS の暗号 | `rustls-graviola`・`graviola` | https://github.com/ctz/graviola | Apache-2.0 OR ISC OR MIT-0 |
  | ルート証明書の検証 | `rustls-platform-verifier` | https://github.com/rustls/rustls-platform-verifier | MIT OR Apache-2.0 |

- Wasmtime 49.0.2 の機能 `runtime` は、Unix で小さな C のファイル `helpers.c` を C コンパイラでビルドする（出典: [Wasmtime の build.rs](https://github.com/bytecodealliance/wasmtime/blob/v49.0.2/crates/wasmtime/build.rs) の `build_c_helpers`）。これを C コンパイラを要する依存の唯一の例外とする。ほかの依存は C のコードを含まず、Rust のツールチェーンだけでビルドできる。この性質は、上の表のクレートを選んだ結果として成り立っている。

Wasmtime 49.0.2 は、機能 `runtime`・`component-model`・`std`・`cranelift` だけを有効にし、事前にコンパイルしたコードの読み込みを使わない。検査と実行ごとに `Engine` を作る。`benitoite test` はテストの関数ごとに実行を作るので、外部の関数を呼ぶテストごとにエンジンを作り、コンポーネントをコンパイルする。Wasmtime 内部の次の状態は共有される。

- プロセス全体のコードの登録表 `GLOBAL_CODE`（`src/runtime/module/registry.rs`）。コンパイルしたコードの位置からトラップの情報を引く。
- スレッドごとの活性化の記録 `TLS`（`src/runtime/vm/sys/std_tls.rs`）。
- プロセス全体のページの大きさの記録（`src/runtime/vm.rs`）と `Store` の番号の計数器（`src/runtime/store/data.rs`）。
- Linux では、プロセス全体の `sigaction` の処理器を SIGSEGV・SIGILL に登録し、x86_64 と s390x では SIGFPE にも登録する。Wasm のトラップでなければ前の処理器へ委ねる。SIGBUS の登録は Apple と FreeBSD の条件に限られ、Linux では行わない。Wasm に入るスレッドの代替シグナルスタック `sigaltstack` は、既存のものが無効か 256 KiB より小さい場合に付け替える（出典: [signals.rs の `foreach_handler`](https://github.com/bytecodealliance/wasmtime/blob/v49.0.2/crates/wasmtime/src/runtime/vm/sys/unix/signals.rs#L72)、[`trap_handler`](https://github.com/bytecodealliance/wasmtime/blob/v49.0.2/crates/wasmtime/src/runtime/vm/sys/unix/signals.rs#L131)、[`lazy_per_thread_init`](https://github.com/bytecodealliance/wasmtime/blob/v49.0.2/crates/wasmtime/src/runtime/vm/sys/unix/signals.rs#L459)）。
- macOS では、既定の Mach ports の経路を使う。プロセスの寿命の例外処理のスレッドを一つ起こし、`pthread_atfork` の子の処理器を登録する。fork した子で Wasm に入ると panic する。Wasm に入るスレッドごとに `thread_set_exception_ports` で例外ポートを設定し、この経路では `sigaltstack` を付け替えない。別に、ホストのファイバのスタックあふれを検出する SIGBUS の処理器を登録し、該当しないシグナルは前の処理器へ委ねる（出典: [config.rs の既定値](https://github.com/bytecodealliance/wasmtime/blob/v49.0.2/crates/wasmtime/src/config.rs#L312)、[machports.rs の `TrapHandler::new`](https://github.com/bytecodealliance/wasmtime/blob/v49.0.2/crates/wasmtime/src/runtime/vm/sys/unix/machports.rs#L75)、[`sigbus_handler`](https://github.com/bytecodealliance/wasmtime/blob/v49.0.2/crates/wasmtime/src/runtime/vm/sys/unix/machports.rs#L133)、[`lazy_per_thread_init`](https://github.com/bytecodealliance/wasmtime/blob/v49.0.2/crates/wasmtime/src/runtime/vm/sys/unix/machports.rs#L496)）。

トラップの処理と Spectre の緩和の設定は、Wasmtime の既定のままとする。

出典: [Wasmtime 49.0.2 のソース](https://github.com/bytecodealliance/wasmtime/tree/v49.0.2/crates/wasmtime/src)。これらは依存の内部の状態であり、処理系のコードに大域の可変状態を加えない。

### 依存のライセンス

【決定】依存のクレートのライセンスとして、MIT・Apache-2.0・Apache-2.0 WITH LLVM-exception・BSD-2-Clause・BSD-3-Clause・ISC・Zlib・0BSD・Unicode-3.0 を許可する。Unlicense は、MIT と選べる形のときに限り許可する。GPL・LGPL・MPL などのコピーレフトのライセンスは許可しない。理由: LLVM の例外は Apache-2.0 の条件を緩めるものであり、コピーレフトではない（出典: [Wasmtime のライセンス](https://github.com/bytecodealliance/wasmtime/blob/v49.0.2/LICENSE)）。

- `graviola` のライセンス（`Apache-2.0 OR ISC OR MIT-0`）や `rustix` のライセンス（`Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT`）のように、許可の一覧にないライセンス（MIT-0）が OR の選択肢の一つとして含まれるときは、許可の一覧のライセンスを選んで使う。
- 依存を加えるときは、`cargo deny` のライセンスの検査で確かめ、許可の一覧のうち実際に要るものだけを `deny.toml` に加える。
- 配布物には、依存のクレートの著作権とライセンスの表示をまとめたファイルを同梱する。ファイルの作り方は[配布形態](../05-platform/05-01-distribution.md)で定める。

### 処理系が特別に扱う型と関数

【方針】処理系は、標準ライブラリの一部の型・関数・エフェクトを、言語の規則の中で特別に扱う。

- 構文や型の規則が参照する型: `List`（リストのリテラル）、`Option`・`Result`（`try`。[エラー処理](../01-spec/01-09-errors.md)。`Result` は `main` の戻り値の型 `Result[Unit, String]` の判定にも使う）、`Pair`・`Triple`、`Map`・`Set`（定数式。[構文](../01-spec/01-02-syntax.md)）。
- ソースに宣言を置かず、処理系の表で与えるもの: 組み込みの型（基本型、`List`・`Map`・`Set`・`Bytes`・`Reference`・`Lazy`・`Task`・`TaskGroup`・`IOError`・`NetworkError`、リソースの型、`Regex.Pattern`・`Regex.Match`・`Random.Generator`）、操作を持たないエフェクト `State`、まとめたエフェクト `IO.All`。
- 組み込みのエフェクト（[エフェクト](../01-spec/01-07-effects.md)）と、テストの実行器がハンドラとして処理する `Assert.Check`（[利用者プログラムのテスト](../06-tooling/06-04-test-runner.md)）。
- 書ける位置が限られる関数: `TaskGroup.open`（`with` の束縛の式としてだけ書ける）。
- 定数式に書ける関数: `Map.fromList`・`Set.fromList`・`Map.empty`・`Set.empty`（[構文](../01-spec/01-02-syntax.md)の「定数（初回リリース版）」）。
- 算術の確実な誤りを調べるために定数の評価器が評価する関数: `Integer.absolute`・`Integer.floorDivide`・`Integer.floorModulo`（[型検査器](../02-impl/02-05-typechecker.md)の「警告」）。
- 専用の命令で実装する関数: `Reference.update`・`Lazy.force`（受け取った関数を呼ぶため。[ランタイム](../02-impl/02-09-runtime.md)）。
- 解放の失敗を実行時エラーにしないリソースの型: `Http.Exchange`（[リソース管理](../01-spec/01-10-resources.md)の「解放の失敗」、[ネットワークのモジュール](03-09-network.md)の「サーバ」）。

処理系は、これらを綴りではなく `Benitoite` の名前空間のどの名前かで照合する。理由: 利用者の宣言や取り込みが prelude と同じ名前を持っても、組み込みの型やエフェクトを取り違えないためである。非公式のモジュールの型と関数（`Http.Exchange` など）も、取り込みの名前ではなく、`Unofficial` を挟まない名前（`Benitoite.Network.Http.Exchange`）で照合する。

【方針】ソースに宣言を置かない組み込みの型は、次のモジュールのトップレベルの型とする。名前解決は、組み込みの型の表のこの対応から束縛を作る（[名前解決とモジュール読込](../02-impl/02-04-resolver.md)の「標準ライブラリのソースの持ち方」）。

| 型 | 属するモジュール |
|---|---|
| `Unit` | 同じ名前のモジュールを持たないので、`State` と同じく名前空間の根 `Benitoite` の直下の prelude の名前とする（`Benitoite.Unit`） |
| そのほかの基本型、`List`・`Map`・`Set`・`Bytes`・`Reference`・`Lazy`・`Task`・`TaskGroup`・`IOError`・`NetworkError` | 同じ名前の prelude のモジュール（`Benitoite.Integer` の型 `Integer`、`Benitoite.IOError` の型 `IOError` など）。名前 `X` は、型を書く位置では型を、修飾の段ではモジュールを指す |
| リソースの型と、IO・ネットワーク・テキストとデータのモジュールの不透明型 | その型を定める章のモジュール（`Benitoite.IO.File` の `Reader`・`Writer`、`Benitoite.IO.Random` の `Generator`、`Benitoite.Regex` の `Pattern`・`Match`、`Benitoite.Network.Http` の `Listener`・`Exchange` など。[IO のモジュール](03-07-io-modules.md)、[テキストとデータの処理](03-08-text-and-data.md)、[ネットワークのモジュール](03-09-network.md)） |

数の正の名前・別名・表示名は、型の定義と別の内部の表で対応付ける（[名前解決とモジュール読込](../02-impl/02-04-resolver.md)の「標準ライブラリのソースの持ち方」）。新しい七種は同名のモジュールに属し、既存の `Integer`・`Float`・`Byte` の定義の所属は保つ。幅付きの名前と別名の各モジュールでも、同名の型の束縛と標準ライブラリの索引が同じ型の番号を指す。例えば `Integer64` モジュール内の型 `Integer64` は、`Integer` モジュール内の型 `Integer` と同一である。`Show`・`Order` の実装は各型に一つずつ置き、別名のモジュールには追加しない。

標準ライブラリを読み込む前に処理系が必要とする情報（組み込みの関数の表）は、[名前解決とモジュール読込](../02-impl/02-04-resolver.md)で定める。
