---
name: benchmark
description: Benitoite の処理系の性能を測るときに使う。tools/bench/ のベンチマークを比較対象の言語（CPython・Ruby・Lua・OCaml・Rust）とあわせて実行し、測定記録（Markdown）とグラフ付きの HTML を tools/bench/results/ に作り、CPU プロファイルを取って所見を書くまでの手順を定める。性能の測定、ベンチマークの実行、最適化の効果の確認を頼まれたときに使う。
---

# ベンチマークの実施

処理系の性能を、設計書 07-02（性能）の方針に従って測り、記録する手順である。測定の道具は `tools/bench/` にある。

- `programs/`: 8 本のベンチマーク（fib、loop、list、tree、eval、string、println、lines）の Benitoite の版（`*.bnt`）と、比較対象の版（`python/`、`ruby/`、`lua/`、`ocaml/`、`rust/`）。`depth.bnt` は呼び出しの深さの上限を測るためのもの。
- `run.py`: 出力の照合（`--verify`）と測定。測定の後に `results/<日付>-<コミット>.md` と、同じ名前の `.html`（グラフ付き）を書く。
- `report_html.py`: 測定記録（`.md`）からグラフ付きの `.html` を作る（`run.py` が呼ぶ。単独でも使える）。一つの記録だけを示し、別の記録との比較は示さない。
- `profile_summary.py`: samply のプロファイルを関数ごとに集計する。
- `README.md`: 道具の詳しい説明。

## 始める前に確かめること

1. **計算機を静かにする。** 測定の結果は、ほかの負荷で大きくぶれる。ユーザーに、電源につなぐことと、ターミナル（とエディタ）以外のアプリケーションを閉じることを頼み、了承を得てから始める。測定の間は、Codex やサブエージェントなど、ほかの作業を動かさない。
2. **比較対象の処理系を確かめる。** `run.py` は見つからない処理系を飛ばし、飛ばしたことを記録に書く。処理系の導入はユーザーの環境を変えるので、ユーザーに頼むか、了承を得てから行う。CPython は macOS に付属の版を使う取り決めである（入れ替えない）。
3. **所要時間を伝える。** 本測定は 7 種類の比較対象で 20〜25 分ほどかかる（Apple M4 での実績）。

## 手順

リポジトリの根で行う。`cargo` が PATH にないときは `export PATH=$HOME/.cargo/bin:$PATH` とする。

### 1. ビルド

```sh
cargo build --release -p benitoite
cargo build --release -p benitoite --examples
cargo build --release -p benitoite --features alloc-stats --target-dir target/alloc-stats
cargo build --release --manifest-path tools/bench/programs/rust/Cargo.toml
```

実行時間は既定のビルドで測り、確保と解放の回数は `alloc-stats` のビルドで別に数える（計数の費用を実行時間に混ぜないため）。OCaml の版は `run.py` が測定の前にビルドする。

### 2. 出力の照合

```sh
python3 tools/bench/run.py --benitoite target/release/benitoite --verify
```

8 本すべてで、Benitoite の出力と各比較対象の出力が一致することを確かめる。一致しないものがあれば測定に進まず、ベンチマークの版を直す。

### 3. 本測定

```sh
python3 tools/bench/run.py --benitoite target/release/benitoite \
  --benitoite-alloc target/alloc-stats/release/benitoite \
  --bytecode-stats target/release/examples/bytecode_stats
```

時間がかかるので、バックグラウンドで実行して終わりを待つ。同じ日付とコミットの記録が既にあると、`run.py` は上書きせずに止まる。その場合は、既存の記録を残すか消すかをユーザーに確かめる。

### 4. CPU プロファイル

本測定とは別に、samply でベンチマークを一つずつ記録する（macOS で許可のダイアログは出ない。lldb などのデバッガは許可のダイアログが出るので使わない）。

```sh
P=tools/bench/results/profiles/<日付>-<コミット>
mkdir -p $P
BENITOITE_DEV_IO_MODE=direct samply record --save-only --unstable-presymbolicate \
  -o $P/<名前>.json.gz -- target/release/benitoite run tools/bench/programs/<名前>.bnt <入力>
python3 tools/bench/profile_summary.py $P/<名前>.json.gz 10
```

`<入力>` は `run.py` の `BENCH_INPUTS` の値である。lines は `python3 tools/bench/programs/gen_lines.py --lines <行数> <ファイル>` で作った入力のファイルを渡し、終わったらそのファイルを消す。

### 5. 所見を書く

測定記録（`.md`）の末尾に、「CPU プロファイルの要約」と「所見」の節を書き足す。所見は 07-02「測定の結果の使い方」の三つの観点で並べる。

1. 比較対象に対する、ベンチマークごとの相対の位置
2. 遅い部分の原因の内訳と、それを処理系の設計で直せるか
3. 言語処理系を学ぶという目的への影響

原因は、直して測り直すまでは見立てとして書く（断定しない）。所見を書き足したら、`python3 tools/bench/report_html.py <記録の .md>` で HTML を作り直す（HTML は所見を載せないが、記録の表を読み直す）。

### 6. 報告とコミット

- ユーザーには、ベンチマークごとの Benitoite と比較対象の時間、比較対象に対する位置、プロファイルから見た主な費用、次の最適化の候補を報告する。HTML のページの場所も伝える。
- 記録（`.md`、`.html`、`profiles/`）は、スキル `git-workflow` に従ってコミットする（ユーザーがコミットを任せている場合）。

## 読み方の注意（記録と報告に書く）

- **println:** Lua・Rust・OCaml の版は一行ごとに出力を送り出していると見られ、Benitoite（64 KiB のバッファ）より大きく遅く出る。比較の条件が揃っていないので、この比較から結論を出さない。
- **string と lines:** 分割と検索を、Benitoite では Rust で書いた組み込みの関数が行い、OCaml のバイトコードでは OCaml で書いた標準ライブラリを VM が 1 文字ずつ実行する。VM の速さの比較としては読まない。string の入力は List の要素数の上限（16,777,216）で抑えられ、1 秒に届かない。
- **list:** Benitoite と OCaml の版は連結リスト、CPython・Ruby・Lua・Rust の版は各言語の配列を使う。
- **CPython:** macOS に付属の版は JIT を持たない。
- **確保と解放の回数:** 解放の回数は、文字列の解放を数えない。確保と解放の回数の差は漏れを意味しない。
- **グラフ:** 実行時間のグラフは線形目盛で描く。対数目盛にすると、桁の差が小さく見えて誤解を招く（ユーザーの指摘）。

## 入力の大きさと比較対象を変えるとき

- 入力の大きさは `run.py` の `BENCH_INPUTS` にある。Benitoite での実行時間が 1〜3 秒になるように合わせ、変えた理由をその場所のコメントに書く。
- ベンチマークや比較対象を加えるときは、全言語の版を同じ計算・同じ形で書き、`--verify` で出力の一致を確かめる。比較対象を変えたら、設計書 07-02「比較対象」を改め、変えた理由を同じ節に書く。
