# ベンチマーク

測定の手順（静かな計算機の準備から所見の書き方まで）は、スキル `benchmark`（`.claude/skills/benchmark/SKILL.md`）にまとめてある。

`programs/` に、既存の 8 本と初回リリース版で加えた 7 本の Benitoite のスクリプトを置く。比較対象を持つものには、各言語で同じ計算をする版も置く。Benitoite の既存のスクリプトと、呼び出しの上限を調べる `depth.bnt` は、C05 で初回リリース版の構文と名前に移した。`run.py` は出力の照合と性能測定を行う。測定結果は `results/` に保存する。

## 前提と準備

測定には Python 3 の標準ライブラリを使う。Benitoite は、実行時間を測る既定の release ビルドと、確保と回収の統計を取る `alloc-stats` のビルドを分けて作る。計数の費用を実行時間に混ぜないためである。

`--bytecode-stats` に開発用の例 `bytecode_stats` の実行ファイルを指定すると、各ベンチマークの原型・命令・定数の数を記録する。利用者のコードには、関数・メソッド・ラムダ・ハンドラの本体と節・遅延計算の本体を含める。標準ライブラリと、値として使う組み込みの関数の原型は、全体の数にだけ含める。

```sh
cargo build --release -p benitoite
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
python3 tools/bench/run.py --benitoite target/release/benitoite \
  --bench-run target/release/examples/bench_run --verify
```

`--verify` は、各 `.args.small` の引数で Benitoite と見つかった比較対象を実行し、標準出力のバイト列が一致するかを調べる。終了状態が 0 でない場合、または出力が一致しない場合は失敗する。見つからない Ruby、Lua、Rust、OCaml の実行器は飛ばし、その理由を表示する。

`lines.args.small` は `tools/bench/programs/lines-small.txt` を指す。C10 の差分テストはこのファイルを VM と参照インタプリタの双方から読み、成功する分岐の出力と終わり方を比較する。`run.py --verify` は Benitoite CLI と比較対象を別プロセスで起動して出力を照合する。

現在の `list` は Benitoite では永続ベクタ、OCaml では連結リストを使う。Python・Ruby・Lua・Rust の版では各言語の標準の配列または `Vec` を使う。データ構造は異なるが、range で値を作り、map・filter・fold の順に同じ計算を行う。最小実行版の記録では Benitoite も連結リストであった。

`loop` は Benitoite と OCaml では末尾再帰で状態を更新する。Python・Ruby・Lua・Rust の版では同じ更新式と累積値を反復構文で計算する。

比較対象の Rust バイナリは独立した Cargo プロジェクトの `target/release/` にできる。`CARGO_TARGET_DIR` を指定した場合は、そのディレクトリの `release/` を使う。例えば `CARGO_TARGET_DIR=target cargo build --release --manifest-path tools/bench/programs/rust/Cargo.toml` でリポジトリの既定の target にまとめ、`run.py` にも `CARGO_TARGET_DIR=target` を渡せる。必要な release バイナリがない場合、`run.py` は Rust を飛ばす。`--verify` と `--first-release` では追加分（trait・listget・map）も確かめるため、古いバイナリだけが残っている場合も、未ビルドの追加分を呼ばずに飛ばす。Ruby と Lua も、`ruby` と `lua` 系のコマンドが PATH にない場合は飛ばす。

比較対象を測らず Benitoite の記録だけを作るには、次のように実行する。

```sh
python3 tools/bench/run.py --benitoite target/release/benitoite --skip-comparators
```

## 測定

通常の測定は、8 本のスクリプトを 10 回ずつ実行し、実時間の中央値を記録する。

```sh
python3 tools/bench/run.py --benitoite target/release/benitoite \
  --benitoite-alloc target/alloc-stats/release/benitoite
```

`--benitoite-alloc` を指定したときだけ確保と回収の統計を取り、各ベンチマークを一回実行した値を記録する（確保の回数は実行ごとに変わらない）。あわせて、`tools/bench/programs/depth.bnt`（末尾でない再帰）で、既定の呼び出しの情報の上限（1 GiB）に達する段数を 1% の精度で探して記録する（[07-02「測る項目」](../../docs/design/07-quality/07-02-performance.md)）。

`run.py` は Benitoite について `run` と `check` の時間を別に測る。`run` の中央値から `check` の中央値を引いた値を、検査とコード生成を除く実行時間の近似として記録する。この差は別々の実行の中央値から求めるため、正確な段別計測ではない。起動から終了までの時間には `main` が `()` を返すだけの Benitoite プログラムを使う。検査時間には、一万個の関数を含む一万行程度の一時ファイルを使う。

`println` と `lines` は `BENITOITE_DEV_IO_MODE=direct` と `request` の両方で測る。ほかのベンチマークは `direct` で測る。測定する入力の大きさは `run.py` の `BENCH_INPUTS` に置いた仮の値であり、本測定時に Benitoite の実行時間が 1 秒から 10 秒程度になるよう調整する。

最大常駐メモリは、各コマンドを 10 回実行して `/usr/bin/time -l`（macOS）または `/usr/bin/time -v`（Linux）の最大 RSS を記録する。`/usr/bin/time` がない環境や、出力を読み取れない環境では、値を記録できなかった理由を記録する。

確保と回収の統計は、`--benitoite-alloc` に渡した `alloc-stats` のビルドで `BENITOITE_DEV_ALLOC_STATS=1` を指定して取得する。初回リリース版の統計行は `alloc-stats: allocations=… allocated_bytes=… peak_heap_bytes=… collections=…` の形であり、確保回数・累積確保量・最大ヒープ使用量・回収回数を記録する。統計行が出なければ記録にその旨を残す。

## 性能の関門（gate.py）

`gate.py` は fib(35) と loop（1,500 万回）を、比べる版ごとに交互に実行する。各版の `bench_run` を release でビルドして保存し、`--version LABEL=PATH/bench_run` で指定する。回収の係数は 100、IO は direct、ほかは `bench_run` の既定の設定を使う。測定の前に各組を一度ずつ実行して温め、毎回、標準出力を期待値と照合する。

```sh
cargo build --release -p benitoite --example bench_run
python3 tools/bench/gate.py --version before=target/gate-before/bench_run \
  --version head=target/release/examples/bench_run \
  --iterations 10 --output target/gate.json
```

変更の前の実行ファイルは、変更後のビルドが上書きする前に `target/gate-before/bench_run` などへ保存する。`--iterations` の既定は 10 で、正の整数を指定する。短い測定では回数を減らす。

最小実行版の VM と比べる場合は、その版の CLI とスクリプトを別に用意する。次の `LEGACY_SRC` と `LEGACY_BUILD` は実際の作業用ディレクトリに置き換える。展開先を先に作り、リポジトリの根で実行する。

```sh
mkdir -p LEGACY_SRC
git archive 'd4668a9^' | tar -x -C LEGACY_SRC
cargo build --release -p benitoite --manifest-path LEGACY_SRC/Cargo.toml \
  --target-dir LEGACY_BUILD
python3 tools/bench/gate.py --version head=target/release/examples/bench_run \
  --legacy LEGACY_BUILD/release/benitoite \
  --legacy-programs LEGACY_SRC/tools/bench/programs \
  --iterations 10 --output target/gate-legacy.json
```

JSON の `inputs` に入力、`versions` と `legacy` に比べた実行ファイルのパス、`revision` に測定を走らせたリポジトリのコミット、`system` に計算機の情報、`samples` に `LABEL/fib`・`LABEL/loop` ごとのナノ秒の標本を記録する。`wall` はプロセスの起動から終了まで、`run` は標準エラーの `bench-run:` 行の `run_nanos` である。統計行が欠けていたり、必要な項目を読めなかったりした版は失敗とする。最小実行版の `legacy` には `wall` だけを記録し、`run` の配列は空にする。

`summaries` に各組の `wall`・`run` の中央値（`median`）と最小値（`min`）をナノ秒で記録し（`legacy` の組は `wall` だけ）、同じ値を秒で表示する。[07-02「性能の関門」](../../docs/design/07-quality/07-02-performance.md#性能の関門)に従い、本測定では実行の段の中央値を、変更ごとの短い測定では最小値を変更の前の版と比べる。本測定で fib または loop が基準より 5% を超えて遅くなった場合は、理由を記録し、設計者の合意を得る。経過時間と実行の段の時間は、それぞれ同じ項目どうしで比較する。

## CPU プロファイル

`--profile` を付けると、各 Benitoite ベンチマークを samply で一度ずつ実行し、出力先を測定記録に記す。

`profile_summary.py` は、葉が `__psynch_cvwait` などの待機関数である標本を分子・分母から除き、待機を除いた標本に対する self/total の割合を示す。

```sh
python3 tools/bench/run.py --benitoite target/release/benitoite --profile
```

【要検証】samply はこの作業環境に導入されていないため、`cargo install samply --locked` による導入、`samply record --save-only --output <file> -- <command>` の引数、生成される JSON の形式と閲覧方法を確かめていない。samply を使う測定の前に、利用する samply の版でこれらを確認する。

## 比較対象の JIT

`run.py` は CPython の `sys._jit.is_available()` を調べ、利用可能なビルドでは `PYTHON_JIT=0` と `PYTHON_JIT=1` を指定した処理系を分けて測る。JIT 有効版は、起動後に `sys._jit.is_enabled()` が真になった場合だけ測定対象に加える。

【要検証】この作業環境では JIT を有効にした CPython を用意していないため、CPython のビルド設定、環境変数による有効化、利用する版での一次資料との照合を行っていない。CPython の JIT を比較するときは、選んだ版の公式資料でビルド設定と環境変数を確認する。

Ruby の通常版と YJIT 版は、`ruby` が見つかった場合に `ruby --version` と `ruby --yjit` の起動確認を行い、YJIT が有効になったと報告する版だけを測る。

この作業では、利用可能な Ruby の通常版と YJIT 版で `run.py --verify` による起動と小さな入力の出力一致を確かめた。【要検証】導入方法と、`--yjit` による有効化・版表示の公式仕様は一次資料と照合していない。Ruby の YJIT を本測定で比較するときは、選んだ版の公式資料で確認する。

## 記録

`run.py` は `results/YYYY-MM-DD-<コミット短縮名>.md` を新しく作る。既存ファイルは上書きしない。記録には測定日、CPU・メモリ・OS、`rustc --version`、Benitoite と比較対象の版、入力の大きさ、実行時間、起動時間、検査時間、最大 RSS、確保と回収の統計、プロファイルの有無を含める。形式のひな形は [TEMPLATE.md](results/TEMPLATE.md) にある。

プロファイルは `results/profiles/<日付>-<コミット短縮名>/` に置く。測定前後の条件を揃え、記録には実行環境とコマンドの変更を追記する。

記録は、ファイル名と本文で、測ったリビジョンをコミットの番号で参照する。初回リリース（`0.0.1`）で公開する履歴は、それまでのコミットを一つに集約したものである。このため、2026-10-09 までの記録が参照するコミットの番号とタグの多くは、公開する履歴になく、設計者の手元のリポジトリの開発の履歴にだけ残る。記録は測ったときの事実のまま残し、番号を書き換えない（[05-01「リリースの形と公開するリポジトリ」](../../docs/design/05-platform/05-01-distribution.md)）。同じく、`results/` の記録に残る ADR・OPEN の番号は初回リリース版の設計書の写し（`docs/archive/2026-10-09-design-first-release/` の `decisions/` と `open-issues.md`）を、作業の ID は初回リリース版の実装プラン（`docs/archive/2026-10-09-implement-first-release/`）を指す。

## グラフ付きの記録

`run.py` は、測定記録（`results/<日付>-<コミット>.md`）を書いた後に、`report_html.py` で同じ名前の `.html`（グラフ付き）を作る。既存の記録から作り直すときは、`python3 tools/bench/report_html.py <記録の .md>` を実行する。ページは一つの記録だけを示し、別の記録との比較は示さない。実行時間のグラフは線形目盛で描く。

## 初回リリース版のベンチマーク

`--verify` は追加した七つのスクリプトも検査し、小さな入力で実行する。`trait`・`listget`・`map` は、見つかった比較対象すべてと標準出力を照合する。`handler` は `tail` と `saved` の出力も照合する。既存の C10 の差分テストは `.args.small` を見つけて追加のスクリプトを VM と参照インタプリタで比較する。`map.args.small` は 32 鍵である。`http` には `.args.small` を置かず、check.sh の中ではサーバを動かさない。`--verify` は `http.bnt` の check と、計算タスク有無・クライアント数 1 と 8 の各組で 16 要求の応答を確認する。`--verify` にもビルド済みの `bench_run` が要る。`tasks` は参照インタプリタが `TaskGroup.spawn` を扱わないので `Excluded` になる。

| 名前 | 引数 | 処理 |
|---|---|---|
| trait | 反復数 | 制約 `Step` を持つ多相の関数から、メソッドを繰り返し呼ぶ |
| handler | 操作数、`tail` または `saved`、独立した実行の回数（省略時 1） | 同じ整数の更新をエフェクトの操作で行う。`tail` は末尾で再開し、`saved` は `resume` の戻りの後に加算を行う。各実行の結果を加算する |
| tasks | タスク数、各タスクの反復数 | `TaskGroup` にタスクを起動し、計算結果をすべて待って加算する |
| cycle | 循環の数 | セルから構成子を経て同じセルを参照する循環を作り、手放す |
| listget | リストの長さ、参照回数 | `0` から長さ未満の整数を並べ、決まった種の疑似乱数で添字を選び、取得した値を加算する |
| map | 鍵の数 | 決まった種の鍵列を Map と Set に挿入し、全鍵を探索し、鍵列の偶数番目（0 起点）を削除する |
| http | 要求数、計算タスク (0/1) | ループバックで指定数の要求に応答し、終了するサーバ。クライアントは run.py が動かす |

`handler` の `saved` は末尾でない再開である。継続を言語の値として持ち出す形ではなく、節の中で直接 `resume` を呼ぶ。二つの形は記録では `handler-tail` と `handler-saved` の別の行にする。`handler`・`tasks`・`cycle` の比較対象の欄は空にし、処理系を変えた前後の比較に使う。`http` も比較対象を置かず、処理系を変えた前後の比較に使う。

`trait` の更新式は `(value * 17 + 11) mod 65521`、初期値は `1` である。比較対象の Python はオブジェクトのメソッドをダックタイピングで呼び、Ruby は普通のメソッド、Lua はテーブルのメソッド、OCaml は関数を持つレコードを使う。Rust は `&dyn Step` による動的な呼び出しを使い、`black_box` を通した受け手と `inline(never)` の反復関数で、呼び出しの直接化を抑える。各言語で同じ更新を行うが、多相の実装方式は異なるため、辞書渡しの費用だけの比較とは扱わない。

`listget` の種は `1` から始め、`seed = (seed * 48271 + 11) mod 2147483647`、`index = seed mod length` の順で更新する。各段で剰余を取り、掛け算の結果を Integer の範囲に保つ。すべての比較対象で同じ式と位置の並びを使う。Benitoite のリストは永続ベクタであり、比較対象は配列（Rust は `Vec`、Lua は整数を鍵にしたテーブル）を使う。OCaml も添字で引ける配列を使う。

`tasks` は計算の前にゲートのタスクの完了を待つ。親は入力した数のタスクを起動してからゲートを開くので、計算を終えてしまったタスクだけを数えることを避けられる。ゲートのタスクはセルを読みながら末尾再帰で待つ。入力した数に加えて、`main` とゲートのタスクが存在し、ゲートの待ちの処理と結果を保存するリストも費用に含まれる。

## 段別の時間と回収統計を取る例

`bench_run` は、CLI と同じ公開のパイプラインと実行関数を通る開発用の例である。既定のビルドで作り、時間の計測には `alloc-stats`、`heap-verify`、`gc-stress` を有効にしない。

```sh
cargo build --release -p benitoite --example bench_run
target/release/examples/bench_run --call-budget=2500 --trigger-factor=100 \
  --io-mode=direct --repeat-check=1 tools/bench/programs/cycle.bnt 100
```

選択肢はスクリプトのパスの前に置き、パスの後はすべてスクリプトの引数にする。パスの直前の `--` も使える。`--call-budget` は正の整数、`--trigger-factor` は百分率の非負整数、`--repeat-check` は正の整数である。省略すると処理系の既定の予算と回収の係数、`direct`、検査 1 回を使う。`--io-mode=request` で要求と応答の方式を選ぶ。`--trigger-factor=0` にしても、確保量の下限（既定 4 MiB）は残る。

スクリプトの標準出力はそのまま流し、標準エラー出力に `bench-run: key=value …` を一行で書く。時間の単位はナノ秒である。

| 鍵 | 内容 |
|---|---|
| `check_nanos` | `check_path` の時間。検査を繰り返した場合は中央値（偶数個では中央の二つの平均） |
| `desugar_nanos`、`compile_nanos`、`run_nanos` | 脱糖、コード生成、実行の時間 |
| `total_nanos` | 例の中で検査を始めてから実行を終えるまで。繰り返したすべての検査と、実行入力の準備も含む |
| `repeat_check`、`call_budget`、`trigger_factor_percent` | 実際に渡した設定 |
| `allocations`、`allocated_bytes`、`live_bytes`、`peak_heap_bytes` | 確保回数、累積確保量、最後の回収で数えた生きている量、最大ヒープ量 |
| `collections`、`roots_traced`、`frees` | 回収回数、辿った根の合計、解放した対象の数 |
| `pause_count`、`pause_p50_nanos`、`pause_p95_nanos`、`pause_p99_nanos`、`pause_max_nanos`、`pause_total_nanos` | 停止の標本数、百分位、最大、合計 |

百分位は nearest-rank（小さい順に並べた標本の `ceil(標本数 × 百分率 / 100)` 番目）で求める。小さな入力などで回収が一度もなければ、停止の標本数と時間はすべて `0` になる。

別の `bench-pauses: n,n,…` 行へ個々の `HeapStats::pause_nanos` も出す。
既存の `bench-run:` 行と、完了時の測定の「各実行の百分位の中央値」は変えない。

## 初回リリース版の追加の項目

追加のプログラムと項目は、測定時に `--first-release` を指定した場合だけ取る。指定しない測定は、既存の 8 本、10 回の中央値、既存の測る項目のままである。`gate.py` は `bench_run` を直接使う。

```sh
python3 tools/bench/run.py --benitoite target/release/benitoite \
  --benitoite-alloc target/alloc-stats/release/benitoite \
  --first-release --bench-run target/release/examples/bench_run
```

追加の測定でも標本数は 10 とする。回収の費用、タスク数による RSS、予算による実行時間、リストの長さによる添字の時間、起動と検査の内訳を Markdown の表と HTML の線形目盛のグラフに記録する。設定の値と、回収の停止の標本数も記録する。`BENCH_INPUTS` の追加の値は仮の値であり、本測定の前に 1〜10 秒になるよう調整する。

| 項目 | 計算と読み方 |
|---|---|
| 回収の費用 | `cycle`・`list`・`tree`・`eval` で、一回の実行ごとに停止の百分位・最大・合計を求め、それぞれの 10 回の中央値を記録する。回収回数、停止の標本数、最大ヒープ量も中央値、RSS は 10 回の最大である |
| タスク一つあたりのメモリ | 1,000・10,000・100,000 個を起動する。`(最大 RSS − 0 タスクでの最大 RSS) / タスク数` の近似を記録する。固定費のほかにリストなどの費用も含み、計算機や確保器の状態にも左右される |
| 呼び出しの回数の予算 | `bench_run` が報告した既定の予算の 1/4・1/2・1・2・4 倍で `tasks` と `http` を実行する。実行の段の時間の中央値を記録し、http では要求/秒と応答時間も記録する |
| HTTP の要求の処理の量と待ち時間 | 計算タスク有無・同時クライアント数・予算の組ごとに、要求/秒と全要求の応答時間の中央値・最大を求める。それぞれ 10 回の値の中央値を記録する |
| 添字一回あたりの時間 | 長さ 10³・10⁴・10⁵・10⁶・10⁷ に対し、`(実行時間の中央値 − 同じ長さで参照 0 回の実行時間の中央値) / 参照回数` を記録する。リストの構築を差し引いた近似であり、疑似乱数、剰余、呼び出し、加算の費用も含む |
| 標準ライブラリの検査時間 | `main` が `()` を返すだけのスクリプトの `check_nanos` を近似とする。大きなスクリプトの `check_nanos` との差を、それ以外の分の近似とする。読み込み・解析・名前解決なども含み、標準ライブラリの型検査だけの時間ではない |

差で求める近似は、負になっても 0 に丸めず記録する。`bench_run` 内の `total_nanos` は、OS によるプロセスの起動と終了を含まない。起動から終了までの時間は、既存の CLI の外から測る表で確認する。

RSS を取れなければ `—` とし、記録に理由を書く。macOS のサンドボックスで `/usr/bin/time` の統計が拒まれる場合には、`bench_run` を単独で実行し直して段別の統計だけを取る。中間表現の最適化の有無と、musl・glibc の比較は、C16 の範囲ではなく、すべての作業を終えた後に行う。

## 本測定を行わず道具を確かめる

`--quick` は小さな入力と 1 回の標本で全処理を通すための選択肢である。既存の 8 本と追加の 7 本を小さな入力で実行し、タスク数を 10・20・40、リストの長さを 100・1,000 に減らし、大きな検査用スクリプトは 100 関数にする。深さの上限の探索と CPU プロファイルは行わない。HTTP は各組で 16 要求に減らし、Map は 32 鍵とする。Markdown と HTML に動作確認と表示し、性能の判断には使わない。

試しの記録を `results/` に残さないため、`--quick` は `--first-release` と `--output` を必要とする。`--output` は拡張子が `.md` のパスを受け取り、通常の測定でも使える。指定した Markdown または同じ名前の HTML が既にある場合は、上書きせずに停止する。例えば、作業ディレクトリ内の一時ディレクトリで次のように確かめる。

```sh
scratch_dir=$(mktemp -d tools/bench/smoke-XXXXXX)
python3 tools/bench/run.py --benitoite target/release/benitoite \
  --first-release --bench-run target/release/examples/bench_run \
  --quick --output "$scratch_dir/record.md"
python3 tools/bench/report_html.py "$scratch_dir/record.md"
rm -r "$scratch_dir"
```


## Map と Set の比較

`map` の種は 1 から始め、`seed = (seed * 48271 + 11) mod 2147483647` で更新する。全言語で同じ鍵列を一度作り、Map と Set のそれぞれに N 回挿入、N 回探索、ceil(N/2) 回削除を行う。削除するのは鍵列の 0・2・4…番目である。標準出力の四行は、最後の Map の要素数、Set の要素数、Map の探索で見つかった回数、Set の探索で見つかった回数の順である。重複した鍵があれば要素数は N より少なくなり、探索回数では重複も数える。

Benitoite と OCaml は永続の順序付き Map・Set、Rust は可変の BTreeMap・BTreeSet を使う。Python は dict と set、Ruby は二つの Hash、Lua は二つの表を使う。順序付きの Map・Set は鍵の順序で整列する。標準の辞書・表を使う版には鍵をソートする処理を置かず、この測定では順序を利用しない。平衡木とハッシュ表、永続と可変の違いを含む比較であり、VM の速さだけを示すものではない。鍵列の構築と、最後に要素数を数える処理も含む（Lua は表を走査する）。

## HTTP の測り方

HTTP は Benitoite のサーバと Python 標準ライブラリのクライアントで測る。言語の時計 `Clock.monotonicMilliseconds` はミリ秒までしか測れず、ループバックの応答時間には粗い。そのため、2026-10-08 の設計者の判断に従い、run.py が処理系の外で `time.perf_counter_ns` を使う（[07-02「初回リリース版の完了時の測定」](../../docs/design/07-quality/07-02-performance.md)）。処理系の src は変更しない。

サーバは `Http.listen("127.0.0.1", 0)` で待ち受け、`Http.listenerPort` の値を標準出力の最初の一行に書く。run.py は `bench_run` でサーバを起動し、ポートを読んでから指定数の GET 要求を送る。サーバは要求ごとに応答タスクを起動し、全応答の完了を待って終了する。計算ありの場合は、終了の印を読むまで整数の更新を続ける別のタスクを動かす。計算は呼び出しの予算によってほかのタスクへ切り替わる。

同時クライアント数は `--http-clients 1 8`（既定）で指定する。クライアントのスレッドを揃えて開始し、各接続で一要求を送る。応答が状態コード 200・本体 `ok` でなければ失敗する。応答時間は接続の開始から本体の読み終わりまで、要求/秒は最初の送信から最後の応答までと要求数から求める。Python 側の接続・スレッド・読み出しの費用も含む。計算なしの形では、1 要求あたりの費用が Python のクライアントの費用と同じ程度であり（8 クライアントも GIL のもとのスレッドである）、クライアントの側が要求/秒を律速しうる。この値は処理系を変えた前後の比較だけに使う。サーバの起動・検査と終了処理は要求/秒の区間に含まれず、別の「実行 (秒)」は bench_run の run_nanos である。

HTTP の表と線形目盛のグラフは、計算タスク有無・クライアント数・呼び出し予算の組ごとに示す。「応答最大」は各実行で求めた最大の応答時間の、10 回の中央値であり、全実行を合わせた最大値ではない。時間切れ（起動から終了まで既定 30 秒）や失敗ではサーバを止めて終了を待ち、誤りを報告する。HTTP には比較対象の言語の版を置かない。

L41 で置いた仮の入力は Map 200,000 鍵、HTTP 1,000 要求である。Map 10,000 鍵の実行時間 0.063 秒から、20 倍を約 1.26 秒と見積もった。HTTP 100 要求・1 クライアントは計算なし 0.022 秒、計算あり 0.256 秒であり、1,000 要求を約 0.22 秒・2.56 秒と見積もった。これらは L41 時点の単純な比例の見積もりであり、木の高さ、回収、並行数、予算の影響は含まない。2026-10-09 の短い試行で、入力を調整した（下記「入力の調整」）。

## 入力の調整

handler の単一の操作数を増やすと、1 秒になる前に既定の呼び出し情報の上限へ達した。
初回リリース版の入力は深さ 100,000 を 100 回繰り返す形に調整した。

`--task-memory-work N` は、タスク数による RSS の測定だけで各タスクの計算量を変える。
省略すると `BENCH_INPUTS` の計算量を使う。予算による時間の測定には影響しない。
ゲートは全タスクが起動するまで開かないため、N が小さくても指定数の未完了タスクを保持する。

`--http-inputs PATH` は `{"0/1/2500": 20000, …}` のように
`計算タスク/クライアント数/予算` を鍵、要求数を値にした JSON を受け取る。
省略した条件には `BENCH_INPUTS["http"]` を使う。`--quick` は常に 16 要求を使う。
共通の要求数では全条件を 1〜10 秒にできなかったため、条件別の要求数を渡せるようにした。
要求数を変えると保持する量と回収も変わりうる。予算だけの影響は、共通の要求数での別の実行と合わせて読む。

## RSS の取得が制限される環境

`/usr/bin/time -l` が RSS を出せない macOS の実行環境では、
`BENITOITE_BENCH_RSS=resource` を指定すると `rss.py` を使う。
このラッパーは対象を一個だけ子プロセスとして実行し、終了後の
`resource.getrusage(RUSAGE_CHILDREN).ru_maxrss` を `bench-rss:` 行へ出す。
測定対象の標準出力はそのまま渡す。HTTP でも同じラッパーを使い、失敗時にはプロセス群を終了する。
通常の `run.py` は環境変数がなければ従来の OS の道具を使う。

`/usr/bin/true` の試行では 1,048,576 bytes を報告した。
過去の OS の道具との値の一致は、この制限のある環境では確認できていない。
小さい RSS の変化は、パイプラインや標準ライブラリの変更も含むため、GC 単独の影響と扱わない。
タスク一個あたりの近似には同じ方式での 0 タスクとの差を使う。
ラッパーの起動時間は `bench_run` の `run_nanos` に含まれず、CLI の通常の時間測定にもラッパーを入れない。

## WASM の比較（docs/todo の TODO-212・TODO-232）

リポジトリの根で実行する。`wasm_bench.py` は、組み込み版 A、Benitoite で書いた Json の B、WASM の C を比較する。プログラムは `wasm/` に置き、検証用のパッケージを `testdata/packages/libraries.files/` から読み込む。既存の `run.py` の課題の一覧とゴールデンの探索には加えない。

### 入力の生成と短い動作確認

JSON は固定の種から生成する。レコードの配列に、整数・小数・真偽値・null・エスケープと非 ASCII を含む文字列・入れ子の配列を含める。指定のバイト数に足りない末尾は JSON の空白で埋める。表示する節点数は、越え方 2 の WIT の表に合わせて鍵も数える。生成物は一時ディレクトリに置く。

```sh
python3 tools/bench/wasm_bench.py gen-json --bytes 100000 --seed 212 target/benitoite-input.json
cargo build --release -p benitoite --bin benitoite --example wasm_cost
python3 tools/bench/wasm_bench.py --quick
```

`--quick` は、JSON 1 KB、Hash 0 B と 1 KB、短い Regex と少数の反復、Rust の例の燃料 10,000 と合成コンポーネント約 1 KB だけで道具を確認する。本測定の数字として使わない。正規数の二の冪 2,046 個、固定の非正規化数の標本、負のゼロを A・B・C で比較し、1,000 段の値の compact の書き出しと、オブジェクトの 127 段の解析の成功も比較する。深い値の書き出しを作業列で行うことの確認は `--quick` だけに置き、本測定やゴールデンでは繰り返さない。この二つの確認をここに置くのは、gc-stress と参照インタプリタでも走るゴールデンを 10 秒以内に保つためである。

計時の前に、JSON の解析と書き出しの往復について、A・B・C の compact の出力の SHA-256 を比較する。さらに各課題を一回ずつ実行して出力を比較し、一致した実装だけを反復する。各課題は別プロセスで起動する。Hash と Regex も、一回の出力の一致を確かめてから反復する。一致しない場合は終了状態 1 を返す。浮動小数点数の追加の標本は、差異の入力と A・B・C の出力を記録し、残りの動作確認を終えてから失敗を返す。

`2^-24` の中点の補正を直した後、二の冪と非正規化数など 2,185 個の標本は A・B で一致した。B は十進の中点を偶数側へ補正する際に、その候補を読み戻して元の Float と一致することも確かめる。

ゲストの線形メモリは既定で 64 MiB に制限される。Json の越え方 1（整形）、2（節点の表）、3（文書の保持）と、Regex の `find-all` は、大きな入力では材料の木・結果の表・出力や保持する文書によって上限に達し、C がトラップしうる。Json の `validate` は木を作らずに検証するが、入力自体はゲストへ写す。状態を持つインスタンスの上限は寿命の合計である。`--wasm-memory`・`--wasm-fuel`・`--wasm-transfer` で CLI に渡す上限を変えられる。大きさの単位と範囲は CLI と同じである。各組の計時の前の一回だけの検証には `--wasm-stats` を付け、指定した上限と消費量の JSON を組の要約へ写す。要約の `wasm_stats` は、反復数 1 の確かめの実行の値である。統計がなければ、組の名前を示して停止する。較正と計時の標本には付けず、統計の計数の費用を時間に含めない。上限を指定しなければ既定値を使う。較正は計時の前に済ませ、同じ実装・課題・入力の組では反復数を固定する。要約には反復数も残す。

2026-10-13 に release の処理系で、既定の入力を一回ずつ短く試した。本測定の時間としては使わない。

| 入力 | C の結果（既定の上限） |
|---|---|
| 生成した JSON 1 KB・100 KB（種 212） | parse・stringify・read・pretty・validate は成功 |
| 生成した JSON 10 MB（28,920 レコード、607,321 節点） | stringify・read・validate は成功。parse と pretty は線形メモリの R0905 |
| 10 MB の数だけの配列（5,000,000 要素） | validate は成功。pretty・parse・document は線形メモリの R0905 |
| Hash 1 MB・6 MB（Bytes と List[Byte]） | 成功 |
| Hash 32 MiB（Bytes） | 成功 |
| Regex の count（既定の 150,000 行、2,550,000 バイト） | resource と純粋な形は成功 |

入力の大きさは維持し、通らない Json の課題は失敗と診断を記録する。比較できた実装の結果と、C が上限に達した課題を区別する。

### 本測定と記録

本測定は、スキル `benchmark` に従って計算機を静かにし、設計者の了承を得てから行う。`--output` は新しい JSON の記録を排他的に作り、既存のファイルを上書きしない。失敗した場合も、途中までの結果と理由を記録する。`--benitoite` と `--wasm-cost` で実行ファイル、`--samples` で各組のプロセスの標本数（既定 5、`--quick` は 1）、`--rounds` で反復数の明示の指定、`--timeout` で一プロセスの期限（既定 1,800 秒）を指定できる。B の 10 MB は長くかかりうるので、期限に達した場合は `limit = "timeout"` としてその課題と期限を記録し、残りを続け、最後にまとめて終了状態 1 を返す。

```sh
python3 tools/bench/wasm_bench.py --quick --output target/benitoite-wasm-quick.json
python3 tools/bench/wasm_bench.py --output tools/bench/results/YYYY-MM-DD-wasm.json
```

記録はコマンド、入力の種・バイト数・節点数・ハッシュ、コンポーネントのバイト数とハッシュ、実行ファイルのバイト数、計算機の CPU・論理 CPU 数・メモリ・OS、Python と `rustc` の版、コミットと未コミットの変更の有無、ビルドの機能（`--build-features` で指定）、終了状態、標準出力・診断を含む。`--benitoite` を変えたら `--build-features` も指定する。所見と CPU プロファイルは、スキルに従って別にまとめる。

| 課題 | 入力と比較対象 | 計時する処理 |
|---|---|---|
| JSON parse | 1 KB・100 KB・10 MB、A・B・C の越え方 2 | 解析。C は節点の表からの木の組み直しも含む |
| JSON stringify | 同上 | 共通の A で作った木の書き出し。C は平らな表への変換も含む |
| JSON read | 同上、C は越え方 3 | 解析して最初のレコードの id・label・nested を読む |
| JSON pretty / validate | 同上、C は越え方 1 | A・B は解析して整形、または解析の成否。C はゲストで整形、または検証 |
| Hash | 1 KB・1 MB・6 MB、A・C の Bytes・C の List[Byte]。32 MiB は A・C の Bytes | SHA-256。List[Byte] への入力の変換は計時の外 |
| 空の Hash | 0 B、同じ三者 | 境界を含む呼び出しの費用。A と C の差を読む |
| Regex | 短い入力と同じパターン、A・C の resource・C の純粋な形 | 照合。resource のコンパイルは一度だけ、プロセス全体の時間に含む |
| Regex count | 数 MB、同じ三者 | 一致の数。A は findAll のリストを作り、C はリストを返さない count を使う。仕事の違いを含む比較 |
| Regex find-all | 1,000 行、同じ三者 | 全一致のリストを返して長さを数える。C は findAll と findAllOnce を使い、A と同じ仕事を比較 |

各 Benitoite プログラムは単調なミリ秒の時計で `first_ms`（最初の一回）と `rest_ms`（残りの合計）、`rounds` を出す。出力のハッシュは計時の外で計算する。純粋な C の最初の呼び出しの実行系のコンパイルは `first_ms` に入り、実行前の静的検査でのコンパイルと、resource の作成はプロセス全体の時間で確認する。道具の `process_seconds` は検査、実行、ハッシュ、プロセスの起動を含むので、`first_ms` と同じ範囲の数字ではない。ミリ秒未満の課題は 0 ms になりうる。

最大 RSS は既存の `rss.py` を介して、一プロセスずつ取得する。macOS ではバイト、Linux では KiB の `ru_maxrss` をバイトに揃える。合成コンポーネントの生成は別のプロセスで行うため、コンパイルの最大 RSS に WAT の生成と符号化の作業領域は含めない。読み込み、エンジンの作成、コンポーネントの保持も含むプロセス全体の最大であり、コンパイラだけのメモリ使用量とは解釈しない。

### 燃料とコンポーネントの大きさ

Rust の例 `wasm_cost` は処理系と同じ `engine_config()` と、線形メモリ 64 MiB・受け渡し 256 MiB の設定で実行する。新しい依存のクレートは使わない。

```sh
target/release/examples/wasm_cost --quick
target/release/examples/wasm_cost calls
target/release/examples/wasm_cost fuel
target/release/examples/wasm_cost fuzzy
python3 tools/bench/rss.py target/release/examples/wasm_cost compile \
  crates/benitoite/testdata/packages/libraries.files/wasm-json/wasm/json.wasm
target/release/examples/wasm_cost synthesize 1048576 code target/wasm-code.wasm
python3 tools/bench/rss.py target/release/examples/wasm_cost compile target/wasm-code.wasm
target/release/examples/wasm_cost synthesize 1048576 data target/wasm-data.wasm
python3 tools/bench/rss.py target/release/examples/wasm_cost compile target/wasm-data.wasm
```

`calls` は `func() -> s64` と `func(s64) -> s64` を各 10,000 回呼ぶ。インスタンスの作成だけ、保持したインスタンスの型付きの呼び出し、保持したインスタンスの動的な値の呼び出し、新しいインスタンスを毎回作る動的な値の呼び出しを分ける。保持したインスタンスの値は、resource を持つインスタンスと同じ寿命で呼ぶ費用を見積もるための対照である。resource の handle の変換と受け渡しの費用は、この空に近い関数の対照には含まれない。

`fuel` は燃料 10^10 を無限ループで使い切り、`OutOfFuel` で終わったことを確認する。`fuzzy` は 100・1,000・3,000 文字の距離と燃料の消費量を読む。どちらもナノ秒、消費した燃料、ナノ秒を燃料で割った値を出す。`--quick` を付けると、呼び出しは 20 回、燃料は 10,000、Fuzzy は 10・30 文字になる。

`compile PATH` は読み込みとエンジンの作成を除いて `Component::from_binary` を計時する。`synthesize BYTES code|data|nop PATH` は新しい `.wasm` を書く。`code` は局所変数の読み書き、`i64` の算術、比較・分岐、関数の呼び出しを含む本体を増やし、`data` はデータの区画、`nop` は対照の空の命令を増やす。生成のプロセスを終えてから別の `compile PATH` のプロセスを起こし、コンパイルの最大 RSS に生成の作業領域を混ぜない。符号化の区切りのため指定の大きさには端数が生じるので、実際のバイト数も出す。本測定の道具は Hash・Json・Regex・Fuzzy と合成の約 1・4・16・64 MiB をそれぞれ別プロセスで呼ぶ。約 256 MiB は `--include-256-mib` で明示したときだけ加える。

### 上限に達する課題

既定の上限では Hash の 100 MB は測れない。引数の写しだけで、ゲストの線形メモリ 64 MiB に達するためである。32 MiB も、ゲストの確保の増え方によっては上限に達しうる。動的な値の経路の Hash は一要素を約 40 バイトとして数えるので、6 MB までとする。

越え方 2 の JSON は、節点一つにつき動的な値二つ分と場合の名前などを受け渡しの予算に数える。数ばかりの 10 MB は節点数が大きく、256 MiB に達しうる。生成する入力では十分な長さの文字列も含めるが、10 MB で `R0905` に達した場合は、その診断と失敗した課題を記録し、成功した実装の比較を続ける。全実装の一致を確認できたという結果にはしない。10 MB の document も較正した回数で反復する。状態を持つインスタンスでは、回収の時期によってメモリの消費量が変わり、上限に達した課題は失敗として記録する。

反復数は課題・大きさ・実装ごとに較正する。50 ms 以上の反復区間から一回あたりの時間を見積もり、1.2 秒を目安に回数を決める。計時の前の較正で反復区間が 1 秒以上になるまで回数を調整し、計時の段では変えない。`first_ms` は初回だけ、`per_iteration_ms` は `rest_ms / (rounds - 1)` である。`--quick` と `--rounds` の明示の指定はこの較正を省く。各組を `--samples` 回起動し、回ごとに実装の先頭をずらし、巡回ごとに順を逆転する。JSON の `summary` に固定した反復数と初回、一回あたり、プロセス全体の時間、最大 RSS の中央値と最小値を残す。コンパイルも各大きさで同じ標本数を取り、`compile_nanos` の中央値と最小値を残す。

`wasm_cost` は処理系と同じ `engine_config()` と既定の上限値を使う。ただし `StoreLimits` はメモリ一つごとに上限を当て、処理系の制限器は Store 全体の成長の合計を数えるので、上限の数え方は異なる。呼び出しの費用を測る関数はメモリを成長させない。`instantiate` の計時には `Store` の作成を含む。`fuel` のナノ秒/燃料は無限ループの命令列の値、`fuzzy` の値は距離計算の命令列と文字列の受け渡しを含む値であり、同じ換算率として読まない。

V8 の Markdown の表には次の欄を使い、同じ表の横に設定した上限、呼び出し回数、燃料・線形メモリ・引数と戻り値の受け渡しの最大と合計、達した上限を書く。

| 課題 | 入力のバイト数・節点数 | 実装 | 反復数 | 標本数 | 初回 ms（中央値/最小） | 一回 ms（中央値/最小） | プロセス秒（中央値/最小） | RSS bytes（中央値/最小） | 終了・上限 |
|---|---|---|---|---|---|---|---|---|---|

本測定は、較正と検証、各組 5 回の 1 秒以上の区間だけでも数分を要する。以前の短い試行で B の 100 KB の parse は一回 97 ms だった。10 MB を単純に 100 倍と見積もると一回約 10 秒になり、B の五つの課題の較正・検証・5 標本で十数分以上になる。この改造での `--quick` の動作確認は約 22 秒だった。その起動の固定費と、64 MiB までの実際のコードのコンパイルの 5 標本も加え、30〜60 分を見込む。大きさへの比例は未確認なので、実際の時間は期限や課題によって変わる。約 256 MiB を含める場合は別に見積もる。

`--probe` は本測定の前の短い上限の確認であり、10 MB の生成 JSON（種は `--seed`）の C の verify・parse・stringify・read・pretty・validate を一回ずつ実行する。既定の上限と、線形メモリ 1 GiB・受け渡し 1 GiB の二組を比べ、成功か R0905/R0904 かを表に出す。燃料は既定値か `--wasm-fuel` の指定を両組で使う。反復や中央値の測定は行わない。

```sh
python3 tools/bench/wasm_bench.py --probe --output target/benitoite-wasm-probe.json
python3 tools/bench/wasm_bench.py --wasm-memory=1GiB --wasm-transfer=1GiB \
  --output tools/bench/results/YYYY-MM-DD-wasm-raised.json
```

## WIT の受け渡しの比較入力

[`wit-transfer/manifest.json`](wit-transfer/manifest.json) に、数、flags、map、record、tuple、variant、基本値、入れ子のリスト、UTF-16 の九種類の契約を置く。各契約には空・小・大の設定と、同じ実行内で三回呼ぶ設定がある。別に、短い数だけを渡す `short-numbers.bnt` と、Bytes だけを渡す `large-bytes.bnt` を比較用に置く。処理系の経路を強制するオプションは使わない。短い数と Bytes には、`-typed.bnt` と `-adapter.bnt` の別々のスクリプトも置く。測定道具は manifest の `cli_variants` を読み、各プロセスでは一つの宣言だけを呼ぶ。元の二宣言を含むスクリプトは独立例の型の読み込みと従来の結果検証に使う。

入力は `.bnt` のスクリプトが二つの引数から作る。第一引数は入力の大きさ、第二引数は同じ実行内の反復数である。入力と期待値を反復の前に用意し、反復ごとに実際の結果を照合する。正しい結果なら `ok` を一行出力して終了状態 0、不一致なら `failed` と実行失敗を報告する。固定した大きさの契約では、第一引数は欄の整数値を変える。転送の要素数が増えるものとは区別する。

| 契約・比較 | 空 | 小 | 大 | 第一引数の意味 |
|---|---:|---:|---:|---|
| numbers | 0 | 3 | 4,096 | 各幅のリストの要素数。スカラーの境界値は毎回呼ぶ |
| flags | 0 | 1 | 32 | 各幅の先頭から選ぶ項目数。幅を超える指定はその幅の全選択 |
| maps | 0 | 3 | 4,096 | 入力の組の数。重複した三組を返す呼び出しも毎回行う |
| records | 0 | 35 | 1,000,000 | 固定した欄の整数値。混合幅の欄の検査は既知の値を使う |
| tuples | 0 | 1 | 1,000,000 | 固定した 1・4・17 要素の組の整数値 |
| variants | 0 | 3 | 1,000,000 | 固定した欄の整数値。空と数の合流の各場合も毎回呼ぶ |
| primitives | 0 | 3 | 1,048,576 | Bytes のバイト数。文字列は `A日😀` を最大 4,096 回繰り返す |
| nested | 0 | 3 | 4,096 | 外側のリストの要素数。子は二要素・空・一要素の順 |
| utf16 | 0 | 1 | 4,096 | `A日😀` の反復数。一単位は UTF-8 で 8 バイト、UTF-16 で 4 符号単位 |
| short-numbers | 0 | 42 | 1,000,000 | 一個の数の値。各宣言が渡す数は 8 バイト |
| large-bytes | 0 | 3 | 1,048,576 | Bytes のバイト数 |

### ゲストの再生成

手書きゲストの元ソース、元の版、比較用に変えた点、保存したソースとバイナリの SHA-256 は manifest の `guests` に記録する。比較用の `.wat` は独立したソースであり、再生成時に処理系のテストの内部コードを読み込まない。可変長の入力を持つゲストの確保処理は、整列・メモリの拡張・古い内容の保存を行う。

再生成には、既存のテストの準備データと同じ `wat 1.261.0` を使う。独立したクレートの Cargo.lock で依存を固定する。リポジトリの根で次を実行する。既に取得した依存を使い、生成物を `target/` に置く。

```sh
cargo run -q --offline --locked \
  --manifest-path tools/bench/wit-transfer/regenerate/Cargo.toml \
  --target-dir target/wit-transfer-fixtures
cargo run -q --offline --locked \
  --manifest-path tools/bench/wit-transfer/regenerate/Cargo.toml \
  --target-dir target/wit-transfer-fixtures -- --check
```

ソースを意図して変えたときは、再生成後に manifest の SHA-256 も更新する。`--check` はソースを解析した結果と保存したバイナリを照合し、不一致なら失敗する。

### 小さい入力の確認と測定への引き継ぎ

```sh
cargo build -p benitoite --bin benitoite
python3 tools/bench/wit-transfer/verify.py
python3 tools/bench/wit-transfer/verify.py --sample zero --sample small --sample repeat
python3 tools/bench/wit-transfer/verify.py --case large-bytes --sample repeat
```

`verify.py` は manifest の CLI コマンドを読み、独立した期待値を使うスクリプトの標準出力・終了状態と、`--wasm-stats` の宣言ごとの経路・呼び出し数を照合する。一回の起動の制限時間は 10 秒である。`--benitoite` で使う実行ファイルを指定できる。大きい入力の実行と計時は最後の本測定に残す。

数の `Integer` と `Float`、文字列と一引数の Bytes は typed を選ぶ。新しい数・Byte・Boolean・Character・複合値は adapter を選ぶ。Bytes と UTF-16 の文字列には、Boolean を追加して adapter を選ぶ宣言も用意する。短い数の比較は `s64` と `u64` の異なる契約なので、幅だけで経路の性能差を説明しない。宣言ごとの型と経路は manifest の `declarations` を正とする。

CLI が dynamic を選ぶ宣言はこの入力群にはない。動的な呼び出しとの比較には、同じゲストを Wasmtime から直接呼ぶ測定用の例 `wit_transfer_cost` を使う。小さい入力の引数と期待値を、[WIT の値の JSON](wit-transfer/expected/small-values.json) としても保存する。整数は正確な JSON 整数、Float32 は丸めた値を Float64 へ正確に拡大した数、variant は WIT の場合の名前とペイロードで表す。Bytes と `list<u8>`、一つの組と複数引数の構成子は、同じ WIT の値でも言語の構築量が異なるため、宣言を区別して記録する。

`wit_transfer_bench.py` は manifest の入力・期待値・ゲストを使って、CLI 全体の実時間・最大 RSS・統計と、独立した関数の段別の時間を記録する。CLI の反復用コマンドは、一つの Benitoite の実行でキャッシュを再利用する。同じ実行の反復と、別プロセスの初回を区別する。スクリプトの実時間には結果の照合も含まれるので、外部呼び出しだけの時間として扱わない。

### 計時・RSS・統計の記録

道具の確認だけを行う場合は、次を実行する。`--quick` は最終版だけを既定の機能の debug 構成でビルドし、十一入力それぞれについて、別プロセスの試行を二回、同一実行内の反復を三回行う。入力は小さい設定を使う。標準出力・終了状態・経路・呼び出し数と、段別計時の JSON の形式を検査する。保存版の manifest も読まず、中間版を実行・再ビルドせず、strip も行わない。既存の出力ファイルは上書きしない。

```sh
python3 tools/bench/wit_transfer_bench.py --help
python3 tools/bench/wit_transfer_bench.py --quick --output target/p3a-transfer-quick.json
PYTHONPYCACHEPREFIX=target/pycache python3 -m py_compile tools/bench/wit_transfer_bench.py
```

本測定は、benchmark スキルに従って機械の状態を設計者が確認した後に行う。次のコマンドは、最終版を既定の機能の release 構成でビルドし、CLI には大きい設定、段別計時には独立した小さい入力を使う。試行回数と同一実行内の反復数は変更できる。`--case` は対象を限定し、複数指定できる。`--sample zero|small|large` は CLI の入力を選ぶ。

```sh
python3 tools/bench/wit_transfer_bench.py --iterations 5 --rounds 20 \
  --output tools/bench/results/YYYY-MM-DD-wit-transfer.json
```

保存した版は `target/p3a-versions/start/manifest.json`、`target/p3a-versions/numbers/manifest.json` と `target/p3a-versions/adapter/manifest.json` から読む。開始前の start 版は短い数と Bytes の typed 用スクリプトだけを実行する。これらは旧い型と構文だけで書き、補助用の宣言は含まない。版・HEAD・差分の記録・機能・バイナリの位置・strip 前後の大きさと SHA-256 を JSON に残し、保存済みの各バイナリの大きさと SHA-256 を実体と照合する。中間版を `target/release/` から復元しない。`--versions-dir` で保存先を変えられる。初期の numbers 版が対応しない WIT の契約は、その版の静的検査の E1008・E1009・E1010 を `unavailable` に記録する。静的検査のほかの失敗は測定を止める。保存版の実行失敗は `measurements` に `status: failed`、`failure_kind`（資源上限・時間切れ・内部エラー・その他の実行失敗）、終了状態、標準出力・標準エラー、診断と取得できた統計を残し、次の試行へ進む。P36a の adapter 版がインスタンス数の上限で失敗しても、残る契約の記録は続ける。成功したが結果・経路が違う場合と、最終版の失敗は検証エラーとする。集計には成功・失敗の試行数を残し、時間・RSS の中央値は成功だけから計算する。全試行が失敗した集計の中央値は `null` とする。numbers 版で実行できる補助対象の宣言は dynamic として照合する。

開始前の実行ファイルがない場合は、次をリポジトリの根で一度だけ実行する。既存の `start/` を上書きしない。git worktree を作らず、アーカイブのソースとビルド生成物を `target/p3a-versions/` の中に置く。保存後の測定はこのバイナリを直接読み、再ビルドしない。

```sh
mkdir target/p3a-versions/start
mkdir -p target/p3a-versions/start-src
git archive a85be5fb | tar -x -C target/p3a-versions/start-src
(cd target/p3a-versions/start-src && cargo build --release -p benitoite --target-dir ../start-target)
python3 - <<'PY_START'
from pathlib import Path
import hashlib, json, platform, shutil, subprocess
folder = Path("target/p3a-versions/start")
binary = folder / "benitoite"
shutil.copy2("target/p3a-versions/start-target/release/benitoite", binary)
stripped = folder / "benitoite.stripped"
shutil.copy2(binary, stripped)
subprocess.run(["strip", str(stripped)], check=True)
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
data = {
    "version": "start", "head": subprocess.check_output(["git", "rev-parse", "a85be5fb"], text=True).strip(),
    "dirty": False, "profile": "release", "default_features": True, "features": ["gc-mark-sweep"],
    "source_command": "git archive a85be5fb | tar -x -C target/p3a-versions/start-src",
    "build_command": "cargo build --release -p benitoite --target-dir ../start-target (cwd: target/p3a-versions/start-src)",
    "rustc": subprocess.check_output(["rustc", "-Vv"], text=True).strip(),
    "cargo": subprocess.check_output(["cargo", "-V"], text=True).strip(), "platform": platform.platform(),
    "artifacts": {"benitoite": {
        "path": str(binary), "size_bytes": binary.stat().st_size, "sha256": digest(binary),
        "stripped_path": str(stripped), "stripped_size_bytes": stripped.stat().st_size,
        "stripped_sha256": digest(stripped), "strip_command": ["strip", str(stripped)]}}
}
with (folder / "manifest.json").open("x") as stream:
    json.dump(data, stream, indent=2)
    stream.write("\n")
PY_START
```

本測定では、最終版のバイナリの一時コピーにも strip を行い、前後の大きさと SHA-256 を記録する。最終版を別に用意した場合は、`--benitoite PATH --cost-example PATH` で両方指定する。既定の機能を使う構成で揃え、指定した版と構成が一致することは実行者が確認する。道具は指定されたバイナリを再ビルドしない。

段別計時の例は、例えば次のコマンドで単独でも使える。

```sh
cargo build --release -p benitoite --example wit_transfer_cost
target/release/examples/wit_transfer_cost \
  tools/bench/wit-transfer/large-bytes.bnt large-bytes 20
target/release/benitoite run --wasm-stats \
  tools/bench/wit-transfer/large-bytes.bnt 1048576 20
```

上の例の第一コマンドは小さい JSON 入力を二十回呼び、第二コマンドは 1 MiB の Bytes を同じ Benitoite の実行内で二十回呼ぶ。短い数と Bytes の CLI 記録・集計は `cli_route` と `script` で経路を区別する。typed と adapter を同じプロセスで呼ばず、それぞれの時間と RSS を記録する。JSON のスキーマは第 2 版である。例は生成器・配置表・復号器を含む既存の処理系ソースを例のクレート内に読み込み、内部の `ComponentGroup`・`CodecPlan`・報告関数の接続を使う。測定専用の公開 API は増やさない。宣言の検査と Benitoite のコンパイルは段別計時の外で行い、照合済みの型から生成をやり直して時刻を取る。

| JSON の欄 | 時刻を取る範囲 |
|---|---|
| `prepare_nanos` | `ComponentGroup::prepare_with_budget`。共有の鍵と生成用の型の準備 |
| `generation_nanos` | `ComponentGroup::generate_with_budget`。型から補助を生成・合成 |
| `compile_nanos` | `Component::from_binary`。各関数・経路につき初回だけ |
| `instantiate_nanos` | 準備済みの Linker による `instantiate` の前後。Linker の作成と報告関数の接続は計時の外 |
| `call_nanos` | TypedFunc または動的 Func の `call` の前後。canonical ABI の変換と post-return を含む |
| `host_pack_nanos` | 補助の `CodecPlan::encode` の前後。型付き・動的は未測定の `null` |
| `host_decode_nanos` | 補助の `CodecPlan::decode` の前後。型付き・動的は未測定の `null` |

例はコンパイル済み Component を同一プロセス内で保持し、各呼び出しには新しい Store とインスタンスを作る。各関数・経路の最初の呼び出しを `cold`、続く呼び出しを `same-session` として保存する。型付きと動的の `call` の比較では同じゲストの同じ書き出しを使う。型付き・動的の引数と戻り値の準備には例固有の変換を使い、処理系の変換時間を測っていないため、ホスト変換の時間は補助との比較に使わない。この制約を例の `host_conversion_scope` と測定記録の `limits` に明記する。JSON の読み込みと期待値の準備も計時の外で行う。補助の生成を反復ごとにやり直さず、時間を既存 stats の合計から推測しない。

RSS は POSIX の `wait4` が返す子プロセスの最大使用量から取得してバイトに揃える。CLI の記録には、`--wasm-stats` の経路・燃料・転送量・構築量・メモリをそのまま残す。保存した numbers 版の統計には経路と構築量がないため、`unreported_stats` に欠けた欄を記録し、経路と構築量を推測して補わない。呼び出し数と結果はその版でも検査する。例は呼び出しごとの燃料と、補助の転送バッファ全長・構築量を直接記録する。型付き・動的の転送量・構築量は例では `null` とし、CLI の統計と区別する。

段別計時は最終版の小さい入力の費用であり、CLI 全体の時間の内訳でも、大きい入力の型付き・動的の性能比較でもない。最大 RSS はプロセス全体の値であり、関数ごとの使用量ではない。例の純粋な関数は既定の燃料・転送予算と StoreLimits のメモリ上限を使うが、本番の Store 全体の合計を数える制限器は使わない。資源上限の検証には処理系のテストを使う。`--quick` の時間を性能の評価に使わない。
