# Fuzzing

このクレートは、任意の入力に対して検査段が panic や処理系の不具合を起こさないこと、診断の span がソースの範囲内にあること、検査を通ったスクリプトを脱糖・コード生成できること、フォーマッタが不具合を起こさず冪等で検査の診断を変えないことを cargo-fuzz で確かめる。実行時（VM とランタイム）は対象にしない。

## 導入

fuzzing には nightly の Rust と cargo-fuzz が要る。nightly の版は固定しない。導入するコマンドは次のとおりである。

```sh
rustup toolchain install nightly
cargo install cargo-fuzz --version 0.13.2 --locked
```

ルートの Cargo ワークスペースは `fuzz/` を除外する。通常の検査は `rust-toolchain.toml` の stable 版で行い、fuzzing だけ `cargo +nightly fuzz` を使う。

`libfuzzer-sys` は `0.4.13` に固定している。ライセンスは `(MIT OR Apache-2.0) AND NCSA` であり、NCSA はこの fuzzing 用クレートに限って認める（[ロードマップ](../docs/design/00-overview/00-03-roadmap.md)の「利用する既存の OSS のライセンス」、実装プラン 00-02「依存するクレート」）。処理系のクレートはパス依存として参照する。

## 短時間の実行

`fuzz-seed.sh` は `crates/benitoite/testdata/` のテスト用 `.bnt` スクリプト（`fmt` の区分を含む。`*.files/` と `*.formatted/` の中を除く）を、`check_mutated`・`compile_ok`・`format` の corpus にコピーする。`main.bnt` を持つディレクトリのテストは、後述の固定のパスだけからなるものを `check_modules` の corpus にコピーし、対応できずに飛ばした数も示す。バイト 0x00 を含むスクリプトは区切りと区別できないので、ディレクトリの種には使わない。種の生成には Python 3 を使う。

`fuzz-short.sh` は五つの対象を各 60 秒動かす。一つの対象が不具合を見つけても残りを実行し、最後に失敗した対象の一覧を示して終了状態 1 を返す。途中で不具合を見つけた対象は、その時点で実行を終える。

```sh
./scripts/fuzz-seed.sh
./scripts/fuzz-short.sh
```

## 長時間の実行

長時間の実行は対象ごとに時間を秒で指定する。次の例は `check_bytes` を 3600 秒動かす。

```sh
cargo +nightly fuzz run check_bytes -- -max_total_time=3600
```

ほかの対象も同様に `check_mutated`、`compile_ok`、`check_modules` または `format` を指定する。対象を一つずつ実行して、見つかった入力を `fuzz/artifacts/<対象>/` で確認する。

## 対象

| 対象 | 入力と性質 |
|---|---|
| `check_bytes` | 任意のバイト列を `pipeline::check_text` に渡す。panic、処理系の不具合の報告、診断 span の不整合を見つける。 |
| `check_mutated` | 既存のテスト用スクリプトを変形したバイト列に対し、`check_bytes` と同じ性質を確かめる。 |
| `compile_ok` | 検査に誤りがなければ `desugar_checked` が成功し、`ir::check::check_program` が空を返し、`compile` が成功または処理系の制限を返すことを確かめる。 |
| `check_modules` | 複数のファイルを `pipeline::check_files` に渡し、`compile_ok` と同じ三つの性質を確かめる。 |
| `format` | 入力を一つのファイルとして `format_source`（利用者のソース）で整形する。panic と整形後の検証の失敗が起きないこと、構文の誤りがなければ、整形の結果を整形しても変わらないことと、整形の前後で `check_text` の診断のコードと文言の並びが同じことを確かめる（07-03「fuzzing」）。 |

すべての対象で `require_main = true`、`deny_warnings = false` とする。`format` を除く対象では、診断の主な位置と補助の位置について、ソースの表にファイルがあり、`start <= end <= 内容の長さ` であることを確かめる。

## `check_modules` の入力

入力をバイト 0x00 で区切り、先頭の最大六つの断片を、次の順で各ファイルの内容にする。七つ目以降の断片は捨てる。

| 断片の順 | パス |
|---|---|
| 1 | `main.bnt` |
| 2 | `Lib/Text.bnt` |
| 3 | `Lib/Geometry/Shape.bnt` |
| 4 | `Util.bnt` |
| 5 | `Lib/Deep/Inner.bnt` |
| 6 | `util.bnt` |

最初の断片は実行を始めるファイルであり、空でも置く。それ以外の空の断片はファイルを置かない。途中のファイルを省くときは、空の断片を入れて位置を合わせる。たとえば `main.bnt` と `Util.bnt` だけを置く入力は、`main.bnt` の内容、三つの 0x00、`Util.bnt` の内容を順につなぐ。

手で作った入力は、`cargo +nightly fuzz run check_modules <入力のファイル>` で一件ずつ実行できる。メモリ上のファイルシステムに渡すので、`Util.bnt` と `util.bnt` も別のファイルとして入力できる。

不具合を見つけた入力は、処理系の該当する作業に報告する。修正後の退行テストは、その段の単体テストまたはゴールデンテストに置く。
