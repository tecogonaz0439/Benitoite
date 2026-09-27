# ベンチマーク

測定の手順（静かな計算機の準備から所見の書き方まで）は、スキル `benchmark`（`.claude/skills/benchmark/SKILL.md`）にまとめてある。

`programs/` に Benitoite と比較対象の同等の処理を書いた 8 本のスクリプトを置く。`run.py` は出力の照合と性能測定を行う。測定結果は `results/` に保存する。測定そのものは最小実行版の完了後に行う。

## 前提と準備

測定には Python 3 の標準ライブラリを使う。Benitoite は、実行時間を測る既定の release ビルドと、確保と解放を数える `alloc-stats` のビルドを分けて作る。計数の費用を実行時間に混ぜないためである。バイトコードの大きさは、開発用の例 `bytecode_stats` で数える。

```sh
cargo build --release -p benitoite --examples
cargo build --release -p benitoite --features alloc-stats --target-dir target/alloc-stats
cargo build --release --manifest-path tools/bench/programs/rust/Cargo.toml
```

OCaml の比較には `ocamlc`、`ocamlopt`、`ocamlrun` が PATH に必要である。`ocamlfind` は使わず、標準ライブラリだけで動かす。導入を確認するには次を実行する。

```sh
ocamlc -version
ocamlopt -version
ocamlrun -version
```

OCaml 版を手動でビルドする場合は、リポジトリのルートで次を実行する。バイトコードとネイティブコードは `tools/bench/programs/ocaml/_build/` にできる。このディレクトリは Git の追跡対象外である。

```sh
build_dir=tools/bench/programs/ocaml/_build
mkdir -p "$build_dir"
for name in fib loop list tree eval string println lines; do
  cp "tools/bench/programs/ocaml/$name.ml" "$build_dir/$name.ml"
  (cd "$build_dir" && ocamlc -o "$name.byte" "$name.ml")
  (cd "$build_dir" && ocamlopt -o "$name.native" "$name.ml")
done
```

`run.py` も比較対象を検出したときに両形式を `_build/` へビルドする。ビルドは起動時間とベンチマークの実行時間に含めない。三つのコマンドのいずれかが PATH にない場合は、OCaml の二つの比較対象を飛ばして理由を記録する。

初回の出力確認は小さな入力で行う。

```sh
python3 tools/bench/run.py --benitoite target/release/benitoite --verify
```

`--verify` は、各 `.args.small` の引数で Benitoite と見つかった比較対象を実行し、標準出力のバイト列が一致するかを調べる。終了状態が 0 でない場合、または出力が一致しない場合は失敗する。見つからない Ruby、Lua、Rust、OCaml の実行器は飛ばし、その理由を表示する。

`lines.args.small` は `tools/bench/programs/lines-small.txt` を指す。T25 の差分テストは `TestIo` に空のファイル表を渡すため、このプログラムの `File.readText` は `Err` を返す。そのため差分テストで確かめるのは `Err` の分岐であり、実ファイルの読み込みは `run.py --verify` が Benitoite CLI と比較対象を別プロセスで起動して確かめる。

`list` は Benitoite と OCaml では連結リストを使う。Python・Ruby・Lua・Rust の版では各言語の標準の配列または `Vec` を使う。データ構造は異なるが、range で値を作り、map・filter・fold の順に同じ計算を行う。

`loop` は Benitoite と OCaml では末尾再帰で状態を更新する。Python・Ruby・Lua・Rust の版では同じ更新式と累積値を反復構文で計算する。

比較対象の Rust バイナリは独立した Cargo プロジェクトの `target/release/` にできる。release バイナリがまだない場合、`run.py` は Rust を飛ばす。Ruby と Lua も、`ruby` と `lua` 系のコマンドが PATH にない場合は飛ばす。

比較対象を測らず Benitoite の記録だけを作るには、次のように実行する。

```sh
python3 tools/bench/run.py --benitoite target/release/benitoite --skip-comparators
```

## 測定

通常の測定は、8 本のスクリプトを 10 回ずつ実行し、実時間の中央値を記録する。

```sh
python3 tools/bench/run.py --benitoite target/release/benitoite \
  --benitoite-alloc target/alloc-stats/release/benitoite \
  --bytecode-stats target/release/examples/bytecode_stats
```

`--benitoite-alloc` を指定したときだけ確保と解放を数え、各ベンチマークを一回実行した値を記録する（確保の回数は実行ごとに変わらない）。`--bytecode-stats` を指定したときだけ、各ベンチマークの原型・命令・定数の数を記録する。あわせて、`tools/bench/programs/depth.bnt`（末尾でない再帰）で、既定の呼び出しの情報の上限（1 GiB）に達する段数を 1% の精度で探して記録する（ADR 0030）。

`run.py` は Benitoite について `run` と `check` の時間を別に測る。`run` の中央値から `check` の中央値を引いた値を、検査とコード生成を除く実行時間の近似として記録する。この差は別々の実行の中央値から求めるため、正確な段別計測ではない。起動から終了までの時間には `main` が `()` を返すだけの Benitoite プログラムを使う。検査時間には、一万個の関数を含む一万行程度の一時ファイルを使う。

`println` と `lines` は `BENITOITE_DEV_IO_MODE=direct` と `request` の両方で測る。ほかのベンチマークは `direct` で測る。測定する入力の大きさは `run.py` の `BENCH_INPUTS` に置いた仮の値であり、本測定時に Benitoite の実行時間が 1 秒から 10 秒程度になるよう調整する。

最大常駐メモリは、各コマンドを 10 回実行して `/usr/bin/time -l`（macOS）または `/usr/bin/time -v`（Linux）の最大 RSS を記録する。`/usr/bin/time` がない環境や、出力を読み取れない環境では、値を記録できなかった理由を記録する。

確保と解放の統計は、`--benitoite-alloc` に渡した `alloc-stats` のビルドで `BENITOITE_DEV_ALLOC_STATS=1` を指定して取得する。統計行が出なければ記録にその旨を残す。

## CPU プロファイル

`--profile` を付けると、各 Benitoite ベンチマークを samply で一度ずつ実行し、出力先を測定記録に記す。

```sh
python3 tools/bench/run.py --benitoite target/release/benitoite --profile
```

【要検証】samply はこの作業環境に導入されていないため、`cargo install samply --locked` による導入、`samply record --save-only --output <file> -- <command>` の引数、生成される JSON の形式と閲覧方法を確かめていない。samply を使う測定の前に、利用する samply の版でこれらを確認する。

## 比較対象の JIT

`run.py` は CPython の `sys._jit.is_available()` を調べ、利用可能なビルドでは `PYTHON_JIT=0` と `PYTHON_JIT=1` を指定した処理系を分けて測る。JIT 有効版は、起動後に `sys._jit.is_enabled()` が真になった場合だけ測定対象に加える。

【要検証】この作業環境では JIT を有効にした CPython を用意していないため、CPython のビルド設定、環境変数による有効化、利用する版での一次資料との照合を行っていない。CPython の JIT を比較するときは、選んだ版の公式資料でビルド設定と環境変数を確認する。

Ruby の通常版と YJIT 版は、`ruby` が見つかった場合に `ruby --version` と `ruby --yjit` の起動確認を行い、YJIT が有効になったと報告する版だけを測る。

【要検証】この作業環境には Ruby MRI がないため、利用する版の導入方法、`--yjit` による有効化、版表示を確認していない。Ruby の YJIT を比較するときは、選んだ版の公式資料で確認する。

## 記録

`run.py` は `results/YYYY-MM-DD-<コミット短縮名>.md` を新しく作る。既存ファイルは上書きしない。記録には測定日、CPU・メモリ・OS、`rustc --version`、Benitoite と比較対象の版、入力の大きさ、実行時間、起動時間、検査時間、最大 RSS、確保と解放の統計、プロファイルの有無を含める。形式のひな形は [TEMPLATE.md](results/TEMPLATE.md) にある。

プロファイルは `results/profiles/<日付>-<コミット短縮名>/` に置く。測定前後の条件を揃え、記録には実行環境とコマンドの変更を追記する。

## グラフ付きの記録

`run.py` は、測定記録（`results/<日付>-<コミット>.md`）を書いた後に、`report_html.py` で同じ名前の `.html`（グラフ付き）を作る。既存の記録から作り直すときは、`python3 tools/bench/report_html.py <記録の .md>` を実行する。ページは一つの記録だけを示し、別の記録との比較は示さない。実行時間のグラフは線形目盛で描く。
