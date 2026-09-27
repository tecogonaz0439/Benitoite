# Fuzzing

このクレートは、任意の入力に対して検査段が panic や処理系の不具合を起こさないこと、診断の span がソースの範囲内にあること、検査を通ったスクリプトを脱糖・コード生成できることを cargo-fuzz で確かめる。実行時（VM とランタイム）は対象にしない。

## 導入

fuzzing には nightly の Rust と cargo-fuzz が要る。nightly の版は固定しない。導入するコマンドは次のとおりである。

```sh
rustup toolchain install nightly
cargo install cargo-fuzz --version 0.13.2 --locked
```

ルートの Cargo ワークスペースは `fuzz/` を除外する。通常の検査は `rust-toolchain.toml` の stable 版で行い、fuzzing だけ `cargo +nightly fuzz` を使う。

`libfuzzer-sys` は `0.4.13` に固定している。ライセンスは `(MIT OR Apache-2.0) AND NCSA` であり、NCSA はこの fuzzing 用クレートに限って認める（ADR 0003、実装プラン 00-02「依存するクレート」）。処理系のクレートはパス依存として参照する。

## 短時間の実行

`fuzz-seed.sh` は `crates/benitoite/testdata/` のテスト用 `.bnt` スクリプトを、`check_mutated` と `compile_ok` の corpus にコピーする。次に `fuzz-short.sh` を実行すると、三つの対象を各 60 秒動かす。

```sh
./scripts/fuzz-seed.sh
./scripts/fuzz-short.sh
```

## 長時間の実行

長時間の実行は対象ごとに時間を秒で指定する。次の例は `check_bytes` を 3600 秒動かす。

```sh
cargo +nightly fuzz run check_bytes -- -max_total_time=3600
```

ほかの対象も同様に `check_mutated` または `compile_ok` を指定する。対象を一つずつ実行して、見つかった入力を `fuzz/artifacts/<対象>/` で確認する。

## 対象

| 対象 | 入力と性質 |
|---|---|
| `check_bytes` | 任意のバイト列を `pipeline::check_text` に渡す。panic、処理系の不具合の報告、診断 span の不整合を見つける。 |
| `check_mutated` | 既存のテスト用スクリプトを変形したバイト列に対し、`check_bytes` と同じ性質を確かめる。 |
| `compile_ok` | 検査に誤りがなければ `desugar_checked` が成功し、`ir::check::check_program` が空を返し、`compile` が成功または処理系の制限を返すことを確かめる。 |

不具合を見つけた入力は、処理系の該当する作業に報告する。修正後の退行テストは、その段の単体テストまたはゴールデンテストに置く。
