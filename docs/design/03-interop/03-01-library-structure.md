# ライブラリの構成

- 状態: 確定
- 関連ADR: [0003](../decisions/0003-license.md), [0077](../decisions/0077-abolish-go-layer.md), [0128](../decisions/0128-prelude-and-benitoite-namespace.md), [0130](../decisions/0130-builtin-effect-names-and-placement.md), [0137](../decisions/0137-first-release-library-scope.md), [0138](../decisions/0138-crates-and-licenses-for-stdlib.md), [0139](../decisions/0139-external-functions-via-wasm.md), [0140](../decisions/0140-network-separated-from-local-io.md), [0143](../decisions/0143-http-and-tls-crates.md), [0149](../decisions/0149-http-exchange-release-failure.md), [0153](../decisions/0153-taskgroup-open-only-in-with.md), [0157](../decisions/0157-stdlib-sources-as-modules-with-builtin-attribute.md), [0162](../decisions/0162-event-loop-and-worker-threads-for-io.md), [0177](../decisions/0177-server-mode-after-first-release.md), [0286](../decisions/0286-unofficial-modules-imported-under-unofficial.md), [0336](../decisions/0336-command-substitute-library-policy.md)
- 未決事項: [OPEN-049](../open-issues.md#open-049), [OPEN-051](../open-issues.md#open-051), [OPEN-079](../open-issues.md#open-079), [OPEN-080](../open-issues.md#open-080), [OPEN-081](../open-issues.md#open-081), [OPEN-082](../open-issues.md#open-082), [OPEN-094](../open-issues.md#open-094)
- 移行元: [設計メモ](../sources/fp-language-design.md) 10

## 目的と範囲

標準ライブラリをどう作るかを定める。対象は、標準ライブラリの関数の実装の方法の区分、prelude と import を要するモジュールの分担、外部に作用する関数が守る規則、実装に使う Rust のクレートとそのライセンスである。あわせて、初回リリース版の後にコマンドを代替する機能を加えるときの作り方を定める。各モジュールの関数は、[標準ライブラリ](03-06-stdlib.md)、[IO のモジュール](03-07-io-modules.md)、[テキストとデータの処理](03-08-text-and-data.md)、[ネットワークのモジュール](03-09-network.md)で定める。

設計メモの 3 層の構成（core・std・go.*）のうち、go.* の層は廃止した（[ADR 0077](../decisions/0077-abolish-go-layer.md)）。本章は、残る二つの層を一つの標準ライブラリとして扱う。

## 前提

標準ライブラリは、処理系と一緒に配るモジュールの全体であり、名前空間 `Benitoite` の下に置く（[ADR 0128](../decisions/0128-prelude-and-benitoite-namespace.md)）。初回リリース版には、パッケージ管理と外部の関数の層を含めない（[ロードマップ](../00-overview/00-03-roadmap.md)、[ADR 0137](../decisions/0137-first-release-library-scope.md)）。したがって、利用者が使える機能は、標準ライブラリと、外部コマンドの起動（[IO のモジュール](03-07-io-modules.md)）に限られる。

## 仕様

### 実装の方法

【決定】標準ライブラリの関数は、次の四つの方法のどれかで作る（[ADR 0137](../decisions/0137-first-release-library-scope.md)）。どの方法で作るかは、利用者からは見えず、prelude に入るかどうかとも関係しない。

| 方法 | 対象 | 例 |
|---|---|---|
| 標準ライブラリのソース（言語で書き、処理系に埋め込む） | 関数を引数にとる関数、標準の型クラスの実装など、言語で書ける関数 | `List.map`・`Option.map`、`Benitoite.Trait` の実装、`Http.serve` |
| 自作の組み込みの関数（Rust） | 言語の中核（永続コレクション、基本型の演算、`Decimal`）と、小さな機能 | `List`・`Map`・`Set` の操作、16 進数の変換、乱数の生成器、HTTP サーバの接続の層（解析はクレート） |
| Rust の標準ライブラリで作る組み込みの関数 | OS の機能を使う関数 | ファイル、ディレクトリ、プロセス、環境変数、標準入力、パス、時刻の読み取り |
| Rust のクレートを包む組み込みの関数 | 既存の OSS の実装を使う機能 | 正規表現、JSON、CSV、時刻の書式、Base64、SHA-256、HTTP のクライアントと TLS |

標準ライブラリのソースの書き方は[標準ライブラリ](03-06-stdlib.md)の「標準ライブラリのソースの書き方」で、組み込みの関数と標準ライブラリのソースを名前解決で結ぶ方法は[名前解決とモジュール読込](../02-impl/02-04-resolver.md)で定める。

【方針】言語の中核（型システム・エフェクト・コレクション）に当たる関数は自作し、それ以外の機能は既存の OSS を使う（[目的と設計原則](../00-overview/00-01-goals.md)の「目的の衝突」）。

### prelude と import を要するモジュール

【決定】prelude には、基本型、コレクション、`Option`・`Result` など、ほとんどのスクリプトが使うモジュールを入れる。IO を行うモジュール（`Benitoite.IO` の下）、ネットワークの操作を行うモジュール（`Benitoite.Network` の下。[ADR 0140](../decisions/0140-network-separated-from-local-io.md)）、標準の型クラス（`Benitoite.Trait`）、テキストとデータを扱う純粋なモジュール（`Benitoite.Path`・`Benitoite.Json` など）は、import を要する（[ADR 0128](../decisions/0128-prelude-and-benitoite-namespace.md)、[ADR 0137](../decisions/0137-first-release-library-scope.md)）。一覧は[標準ライブラリ](03-06-stdlib.md)の「名前空間と prelude（初回リリース版）」で定める。

【決定】初回リリース版では、prelude のモジュールと `Benitoite.Trait` を標準のモジュールとし、IO・ネットワーク・テキストとデータのモジュールを非公式のモジュールとする。非公式のモジュールは `Benitoite.Unofficial` の下の名前で取り込み、設計者が吟味を終えたら標準に移す（[ADR 0286](../decisions/0286-unofficial-modules-imported-under-unofficial.md)、[標準ライブラリ](03-06-stdlib.md)の「標準のモジュールと非公式のモジュール（初回リリース版）」）。本章は、非公式のモジュールも標準に加えた後の名前で書く。

### 外部に作用する関数の規則

【決定】初回リリース版では、外部に作用する経路は標準ライブラリの IO とネットワークの関数だけである（[ADR 0137](../decisions/0137-first-release-library-scope.md)、[ADR 0140](../decisions/0140-network-separated-from-local-io.md)）。これらの関数は、次の規則を守る。

- 外部に作用する操作は、すべて IO 実行器を通す（[ランタイム](../02-impl/02-09-runtime.md)の「IO 実行器」）。操作を処理する言語のハンドラは VM が探し、どのハンドラも処理しなかった操作だけを IO 実行器が受け取って行う。サーバモードとあわせて加える実行時の権限制御の判定も、IO 実行器が操作を行う前に行う（[ランタイム](../02-impl/02-09-runtime.md)の「操作の振り分け」、[ADR 0177](../decisions/0177-server-mode-after-first-release.md)）。
- 関数の型は、行う操作の組み込みのエフェクトを持つ（[エフェクト](../01-spec/01-07-effects.md)、[ADR 0130](../decisions/0130-builtin-effect-names-and-placement.md)）。
- クレートを包む組み込みの関数のうち外部に作用するものも、同じ規則に従う。クレートが OS の資源に直接触れる場合は、その呼び出しを IO 実行器の中で行う。

これらの規則により、実行時の権限制御が保証として成り立つ条件（[セキュリティモデル](../07-quality/07-01-security-model.md)の「保証が成り立つ条件」）のうち、外部に作用するすべての経路が同じ制御を通ることを、処理系の作りで保つ。後の版で加える外部の関数（[外部の関数](../04-extensions/04-01-external-functions.md)）は、WASM のモジュールに処理系が与えるホストの関数だけを通して外部に作用する（[ADR 0139](../decisions/0139-external-functions-via-wasm.md)）。

### 使う Rust のクレート

【決定】標準ライブラリの実装に、次のクレートを使う（[ADR 0138](../decisions/0138-crates-and-licenses-for-stdlib.md)）。

| 用途 | クレート | リポジトリ | ライセンス |
|---|---|---|---|
| 正規表現 | `regex` | https://github.com/rust-lang/regex | MIT OR Apache-2.0 |
| JSON | `serde_json` | https://github.com/serde-rs/json | MIT OR Apache-2.0 |
| CSV | `csv-core` | https://github.com/BurntSushi/rust-csv | Unlicense OR MIT |
| 時刻の計算と書式 | `jiff` | https://github.com/BurntSushi/jiff | Unlicense OR MIT |
| Base64 | `base64` | https://github.com/marshallpierce/rust-base64 | MIT OR Apache-2.0 |
| SHA-256 | `sha2` | https://github.com/RustCrypto/hashes | MIT OR Apache-2.0 |
| OS の乱数（乱数の種） | `getrandom` | https://github.com/rust-random/getrandom | MIT OR Apache-2.0 |

- `jiff` は、タイムゾーンのデータを同梱する機能を切って使う。
- 16 進数の変換と乱数の生成器は自作する。
- HTTP と TLS には、次のクレートを使う（[ADR 0143](../decisions/0143-http-and-tls-crates.md)）。HTTP サーバは、`httparse` と `mio` の上に接続の層を自作する。`mio` は、HTTP に限らず、IO 実行器のイベントループ（`Clock.sleep` の時間の経過を待つことを含む）に使う（[ADR 0162](../decisions/0162-event-loop-and-worker-threads-for-io.md)）。TLS の暗号の provider は `rustls-graviola` を第一候補とし、対象の環境で使えないときや不具合が分かったときは `aws-lc-rs` に替える。ルート証明書は OS のものを使い、`webpki-roots` は使わない。

  | 用途 | クレート | リポジトリ | ライセンス |
  |---|---|---|---|
  | HTTP の解析 | `httparse` | https://github.com/seanmonstar/httparse | MIT OR Apache-2.0 |
  | イベントループ（接続の待ち受けと読み書き、時間の経過を待つこと） | `mio` | https://github.com/tokio-rs/mio | MIT |
  | HTTP のクライアント | `ureq` | https://github.com/algesten/ureq | MIT OR Apache-2.0 |
  | TLS | `rustls` | https://github.com/rustls/rustls | Apache-2.0 OR ISC OR MIT |
  | TLS の暗号 | `rustls-graviola`・`graviola` | https://github.com/ctz/graviola | Apache-2.0 OR ISC OR MIT-0 |
  | ルート証明書の検証 | `rustls-platform-verifier` | https://github.com/rustls/rustls-platform-verifier | MIT OR Apache-2.0 |

### 依存のライセンス

【決定】依存のクレートのライセンスとして、MIT・Apache-2.0・BSD-2-Clause・BSD-3-Clause・ISC・Zlib・0BSD・Unicode-3.0 を許可する。Unlicense は、MIT と選べる形のときに限り許可する。GPL・LGPL・MPL などのコピーレフトのライセンスは許可しない（[ADR 0138](../decisions/0138-crates-and-licenses-for-stdlib.md)）。

- `graviola` のライセンス（`Apache-2.0 OR ISC OR MIT-0`）のように、許可の一覧にないライセンス（MIT-0）が OR の選択肢の一つとして含まれるときは、許可の一覧のライセンスを選んで使う（[ADR 0143](../decisions/0143-http-and-tls-crates.md)）。
- 依存を加えるときは、`cargo deny` のライセンスの検査で確かめ、許可の一覧のうち実際に要るものだけを `deny.toml` に加える。
- 配布物には、依存のクレートの著作権とライセンスの表示をまとめたファイルを同梱する。ファイルの作り方は[配布形態](../05-platform/05-01-distribution.md)で定める。

### C のコードを含むクレートの扱い（初回リリース版の後）

初回リリース版の依存のクレート（前述の「使う Rust のクレート」）は、どれも C のコードを含まず、ビルドに Rust のツールチェーンだけを要する。この性質は [ADR 0138](../decisions/0138-crates-and-licenses-for-stdlib.md)・[ADR 0143](../decisions/0143-http-and-tls-crates.md) でクレートを選んだ結果として成り立っており、一般の方針として決めた ADR はない。初回リリース版の後に検討している機能には、C のライブラリやシステムの共有ライブラリに依存するクレートを要しうるもの（FIDO2 の物理キー、OS のキーストアなど）がある（[サーバモード](../06-tooling/06-07-server.md)の「認証と承認」）。

【未決】依存の基準（ビルドは Rust のツールチェーンだけ、実行時は OS の部品以外の共有ライブラリを読まない）を一般の方針とするか、するなら例外をどう認めるかは、[OPEN-094](../open-issues.md#open-094) で決める。

### 処理系が特別に扱う型と関数

【方針】処理系は、標準ライブラリの一部の型・関数・エフェクトを、言語の規則の中で特別に扱う。

- 構文や型の規則が参照する型: `List`（リストのリテラル）、`Option`・`Result`（`try`。[エラー処理](../01-spec/01-09-errors.md)）、`Pair`・`Triple`、`Map`・`Set`（定数式。[構文](../01-spec/01-02-syntax.md)）。
- ソースに宣言を置かず、処理系の表で与えるもの: 中身を見せない組み込みの型（基本型、`List`・`Map`・`Set`・`Bytes`・`Reference`・`Lazy`・`Task`・`TaskGroup`・`IOError`・`NetworkError`、リソースの型、`Regex.Pattern`・`Regex.Match`・`Random.Generator`）、操作を持たないエフェクト `State`、まとめたエフェクト `IO.All`（[ADR 0157](../decisions/0157-stdlib-sources-as-modules-with-builtin-attribute.md)）。
- 組み込みのエフェクト（[エフェクト](../01-spec/01-07-effects.md)）と、テストの実行器がハンドラとして処理する `Assert.Check`（[利用者プログラムのテスト](../06-tooling/06-04-test-runner.md)）。
- 書ける位置が限られる関数: `TaskGroup.open`（`with` の束縛の式としてだけ書ける。[ADR 0153](../decisions/0153-taskgroup-open-only-in-with.md)）。
- 専用の命令で実装する関数: `Reference.update`・`Lazy.force`（受け取った関数を呼ぶため。[ランタイム](../02-impl/02-09-runtime.md)）。
- 解放の失敗を実行時エラーにしないリソースの型: `Http.Exchange`（[リソース管理](../01-spec/01-10-resources.md)の「解放の失敗」、[ADR 0149](../decisions/0149-http-exchange-release-failure.md)）。

処理系は、これらを綴りではなく `Benitoite` の名前空間のどの名前かで照合する（[ADR 0128](../decisions/0128-prelude-and-benitoite-namespace.md)）。非公式のモジュールの型と関数（`Http.Exchange` など）も、取り込みの名前ではなく、標準に加えた後の名前（`Benitoite.Network.Http.Exchange`）で照合する（[ADR 0286](../decisions/0286-unofficial-modules-imported-under-unofficial.md)）。

【方針】ソースに宣言を置かない組み込みの型は、次のモジュールのトップレベルの型とする。名前解決は、組み込みの型の表のこの対応から束縛を作る（[名前解決とモジュール読込](../02-impl/02-04-resolver.md)の「標準ライブラリのソースの持ち方」）。

| 型 | 属するモジュール |
|---|---|
| `Unit` | 同じ名前のモジュールを持たないので、`State` と同じく名前空間の根 `Benitoite` の直下の prelude の名前とする（`Benitoite.Unit`） |
| そのほかの基本型、`List`・`Map`・`Set`・`Bytes`・`Reference`・`Lazy`・`Task`・`TaskGroup`・`IOError`・`NetworkError` | 同じ名前の prelude のモジュール（`Benitoite.Integer` の型 `Integer`、`Benitoite.IOError` の型 `IOError` など）。名前 `X` は、型を書く位置では型を、修飾の段ではモジュールを指す |
| リソースの型と、IO・ネットワーク・テキストとデータのモジュールの中身を見せない型 | その型を定める章のモジュール（`Benitoite.IO.File` の `Reader`・`Writer`、`Benitoite.IO.Random` の `Generator`、`Benitoite.Regex` の `Pattern`・`Match`、`Benitoite.Network.Http` の `Listener`・`Exchange` など。[IO のモジュール](03-07-io-modules.md)、[テキストとデータの処理](03-08-text-and-data.md)、[ネットワークのモジュール](03-09-network.md)） |

標準ライブラリを読み込む前に処理系が必要とする情報（組み込みの関数の表）は、[名前解決とモジュール読込](../02-impl/02-04-resolver.md)で定める。

### コマンドを代替するライブラリの作り方（初回リリース版の後）

コーディングエージェントがシェルで行う作業（ファイルの複写、検索、置換、git の操作など）を `Process.run` で外部コマンドに任せると、エフェクトは `Process.Run` の一つになり、コマンドが中で行う操作は処理系の検査の外にある（[IO のモジュール](03-07-io-modules.md)の「外部コマンドの起動とシェル」）。同じ操作をライブラリの関数で書けば、エフェクトと権限の対象（パスなど）が型と権限の表示に現れる。初回リリース版の後に、こうしたコマンドを代替する機能を加えるときの作り方を定める。

【決定】コマンドを代替する機能は、次の方針で作る（[ADR 0336](../decisions/0336-command-substitute-library-policy.md)）。

1. 既設の関数を組み合わせて書ける操作には、コマンドに当たる関数を新しく作らない。
2. コマンドの操作をそのまま再現しない。コマンドの名前・オプション・出力の形式（`grep -rn` の出力の行、`sed` の式、`find` の述語など）をなぞる関数は作らない。加えるのは、既設の関数を組み合わせても書けない機能か、書けても安全や性能の面で処理系が持つべき機能に限る。
3. 言語の作りに合った形で作る。結果は文字列の出力ではなく、レコードやリストなどの型の付いた値で返す。外部の資源はリソースとして `with` で開き、後始末を言語に任せる。権限の対象（パス、コマンドなど）が型と権限の確認に現れる形にする。失敗は `Result` と `IOError` で返す。

外部のコマンドを包むライブラリ（git のラッパーなど）も同じ方針で作り、コマンドの引数を組み立てる薄い層にせず、操作を型の付いた関数とエフェクトとして表す。

【未決】どの機能をどの順で加えるかは [OPEN-079](../open-issues.md#open-079)、標準ライブラリの関数・コマンドを包むライブラリ・`Process.run` の選び方をエージェントにどう示すかは [OPEN-080](../open-issues.md#open-080)、外部のライブラリが宣言するエフェクトを権限の表示にどう出すかは [OPEN-081](../open-issues.md#open-081)、git の提供のしかたとエフェクトの分け方は [OPEN-082](../open-issues.md#open-082) で決める。

## 未決事項

- [OPEN-049](../open-issues.md#open-049): パッケージの名前空間と取り込み方
- [OPEN-051](../open-issues.md#open-051): 外部の関数（WASM）の詳細
- [OPEN-079](../open-issues.md#open-079): コマンドを代替する機能の範囲と優先度
- [OPEN-080](../open-issues.md#open-080): 外部コマンドを使う操作の選び方と、エージェントへの示し方
- [OPEN-081](../open-issues.md#open-081): 外部のライブラリのエフェクトを、権限の表示にどう出すか
- [OPEN-082](../open-issues.md#open-082): git の提供のしかたと、エフェクトの分け方
- [OPEN-094](../open-issues.md#open-094): 依存のクレートの基準を一般の方針とするか
