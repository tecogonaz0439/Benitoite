# 0138. 標準ライブラリの実装に使う Rust のクレートと、許可するライセンスを定める

- 状態: 採択（決定 5 の HTTP と TLS のクレートは [0143](0143-http-and-tls-crates.md) で定めた。乱数の範囲の中の値への変換の手順を [0172](0172-random-conversion-procedure.md) で定めた）
- 日付: 2026-09-28
- 関連章: [ライブラリの構成](../03-interop/03-01-library-structure.md), [ロードマップ](../00-overview/00-03-roadmap.md), [配布形態](../05-platform/05-01-distribution.md), [他の言語の調査記録](../08-appendix/08-03-language-surveys.md)
- 関連する未決事項: [OPEN-045](../open-issues.md#open-045), [OPEN-021](../open-issues.md#open-021)

## 背景

初回リリース版の標準ライブラリに、正規表現、JSON、CSV、時刻の書式、Base64、SHA-256 を入れる（[ADR 0137](0137-first-release-library-scope.md)）。言語の中核（型システム・エフェクト・コレクション）と処理系の主要部（解析器・中間表現・バイトコード・VM）は自作し、それ以外の基盤は既存の OSS を使う（[目的と設計原則](../00-overview/00-01-goals.md)）。

処理系と標準ライブラリのライセンスは `MIT OR Apache-2.0` である（[ADR 0003](0003-license.md)）。リポジトリの `deny.toml` は、依存のライセンスとして MIT と Apache-2.0 だけを許している。

crates.io の登録情報（2026-09-28）を調べた結果は次のとおりである。

- 多くのクレートが、`Unlicense OR MIT` のクレート（`memchr` など）に依存する。手続きマクロを使うクレートは、`unicode-ident`（`(MIT OR Apache-2.0) AND Unicode-3.0`）に依存する。
- TLS の暗号の実装（`ring`、`aws-lc-sys`）は C とアセンブリを含み、ビルドに C コンパイラが要る。証明書の一覧（`webpki-roots`）は CDLA-Permissive-2.0 である。
- `rand` の `StdRng` は、ソースのコメントで「non-portable」「any future library version may replace the algorithm」とされ、種を固定しても版をまたいで同じ列になる保証がない。

## 決定

1. 標準ライブラリの実装に、次のクレートを使う。

   | 用途 | クレート | リポジトリ | ライセンス |
   |---|---|---|---|
   | 正規表現 | `regex` | https://github.com/rust-lang/regex | MIT OR Apache-2.0 |
   | JSON | `serde_json` | https://github.com/serde-rs/json | MIT OR Apache-2.0 |
   | CSV | `csv-core` | https://github.com/BurntSushi/rust-csv | Unlicense OR MIT |
   | 時刻の計算と書式 | `jiff` | https://github.com/BurntSushi/jiff | Unlicense OR MIT |
   | Base64 | `base64` | https://github.com/marshallpierce/rust-base64 | MIT OR Apache-2.0 |
   | SHA-256 | `sha2` | https://github.com/RustCrypto/hashes | MIT OR Apache-2.0 |
   | OS の乱数（乱数の種） | `getrandom` | https://github.com/rust-random/getrandom | MIT OR Apache-2.0 |

   `jiff` は、タイムゾーンのデータを同梱する機能を切って使う。
2. 16 進数と乱数の生成器は自作する。乱数の生成器は、アルゴリズムを仕様で定め、同じ種から同じ列を作る。
3. 依存のライセンスとして、MIT・Apache-2.0・BSD-2-Clause・BSD-3-Clause・ISC・Zlib・0BSD・Unicode-3.0 を許可する。Unlicense は、MIT と選べる形のときに限り許可する。GPL・LGPL・MPL などのコピーレフトのライセンスは許可しない。
4. 依存を加えるときは、`cargo deny` のライセンスの検査で確かめ、許可の一覧のうち実際に要るものだけを `deny.toml` に加える。配布物には、依存のクレートのライセンスの表示をまとめたファイルを同梱する。
5. HTTP と TLS のクレートは、[OPEN-045](../open-issues.md#open-045) で HTTP の範囲とあわせて決める。

## 検討した代替案

- **`rand` を使う**: 生成器を自作せずに済む。しかし、種を固定しても版をまたいで同じ列になる保証がなく、テストで結果を再現する用途（[OPEN-046](../open-issues.md#open-046)）に向かない。
- **`csv` を使う**: 行の組み立てを自作せずに済む。しかし、`serde` に依存する。`csv-core` は依存を持たない。
- **`hex` を使う**: 2021 年から更新されていない。16 進数の変換は数行で書ける。
- **JSON の解析器を自作する**: 依存が減る。しかし、JSON の解析器は言語の中核でも処理系の主要部でもないので、既存の OSS を使う区分に当たる。
- **許可するライセンスを MIT と Apache-2.0 に限ったままにする**: 表示の手間は小さい。しかし、`memchr` など広く使われるクレートの依存を除けない。

## 帰結

- 使うクレートは、どれも C のコードを含まない。HTTP で TLS を使う場合は、C のコードを含むクレートを使うかを OPEN-045 で判断する。
- Unicode-3.0 と BSD 系のライセンスは、配布物に著作権とライセンスの表示を含めることを求める。ライセンスの表示のファイルの作り方は、配布形態を書くときに定める。
- クレートの版を上げるときも、ライセンスの検査を通す。
