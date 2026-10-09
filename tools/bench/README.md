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

`--benitoite-alloc` を指定したときだけ確保と回収の統計を取り、各ベンチマークを一回実行した値を記録する（確保の回数は実行ごとに変わらない）。あわせて、`tools/bench/programs/depth.bnt`（末尾でない再帰）で、既定の呼び出しの情報の上限（1 GiB）に達する段数を 1% の精度で探して記録する（ADR 0030）。

`run.py` は Benitoite について `run` と `check` の時間を別に測る。`run` の中央値から `check` の中央値を引いた値を、検査とコード生成を除く実行時間の近似として記録する。この差は別々の実行の中央値から求めるため、正確な段別計測ではない。起動から終了までの時間には `main` が `()` を返すだけの Benitoite プログラムを使う。検査時間には、一万個の関数を含む一万行程度の一時ファイルを使う。

`println` と `lines` は `BENITOITE_DEV_IO_MODE=direct` と `request` の両方で測る。ほかのベンチマークは `direct` で測る。測定する入力の大きさは `run.py` の `BENCH_INPUTS` に置いた仮の値であり、本測定時に Benitoite の実行時間が 1 秒から 10 秒程度になるよう調整する。

最大常駐メモリは、各コマンドを 10 回実行して `/usr/bin/time -l`（macOS）または `/usr/bin/time -v`（Linux）の最大 RSS を記録する。`/usr/bin/time` がない環境や、出力を読み取れない環境では、値を記録できなかった理由を記録する。

確保と回収の統計は、`--benitoite-alloc` に渡した `alloc-stats` のビルドで `BENITOITE_DEV_ALLOC_STATS=1` を指定して取得する。初回リリース版の統計行は `alloc-stats: allocations=… allocated_bytes=… peak_heap_bytes=… collections=…` の形であり、確保回数・累積確保量・最大ヒープ使用量・回収回数を記録する。統計行が出なければ記録にその旨を残す。

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

記録は、ファイル名と本文で、測ったリビジョンをコミットの番号で参照する。初回リリース（`0.0.1`）で公開する履歴は、それまでのコミットを一つに集約したものである。このため、2026-10-09 までの記録が参照するコミットの番号とタグの多くは、公開する履歴になく、設計者の手元のリポジトリの開発の履歴にだけ残る。記録は測ったときの事実のまま残し、番号を書き換えない（[ADR 0358](../../docs/design/decisions/0358-release-versions-and-published-history.md) の決定 10）。

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

`bench_run` は、CLI と同じ公開のパイプラインと実行関数を通る開発用の例である。`stage1_bench` と異なり、第 2 段の命令を実行できる。既定のビルドで作り、時間の計測には `alloc-stats`、`heap-verify`、`gc-stress` を有効にしない。

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

R33 用に、別の `bench-pauses: n,n,…` 行へ個々の `HeapStats::pause_nanos` も出す。
`remeasure.py` はこれを保存し、R12 と同じく全実行の標本を合わせた百分位と最大も求める。
既存の `bench-run:` 行と、完了時の測定の「各実行の百分位の中央値」は変えない。

## 初回リリース版の追加の項目

追加のプログラムと項目は、測定時に `--first-release` を指定した場合だけ取る。指定しない測定は、既存の 8 本、10 回の中央値、既存の測る項目のままである。`gate.py` の本測定にはこの道具を使わない。

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

HTTP は Benitoite のサーバと Python 標準ライブラリのクライアントで測る。言語の時計 `Clock.monotonicMilliseconds` はミリ秒までしか測れず、ループバックの応答時間には粗い。そのため、2026-10-08 の設計者の判断に従い、run.py が処理系の外で `time.perf_counter_ns` を使う（[ADR 0332](../../docs/design/decisions/0332-http-latency-measured-by-bench-client.md)）。処理系の src は変更しない。

サーバは `Http.listen("127.0.0.1", 0)` で待ち受け、`Http.listenerPort` の値を標準出力の最初の一行に書く。run.py は `bench_run` でサーバを起動し、ポートを読んでから指定数の GET 要求を送る。サーバは要求ごとに応答タスクを起動し、全応答の完了を待って終了する。計算ありの場合は、終了の印を読むまで整数の更新を続ける別のタスクを動かす。計算は呼び出しの予算によってほかのタスクへ切り替わる。

同時クライアント数は `--http-clients 1 8`（既定）で指定する。クライアントのスレッドを揃えて開始し、各接続で一要求を送る。応答が状態コード 200・本体 `ok` でなければ失敗する。応答時間は接続の開始から本体の読み終わりまで、要求/秒は最初の送信から最後の応答までと要求数から求める。Python 側の接続・スレッド・読み出しの費用も含む。計算なしの形では、1 要求あたりの費用が Python のクライアントの費用と同じ程度であり（8 クライアントも GIL のもとのスレッドである）、クライアントの側が要求/秒を律速しうる。この値は処理系を変えた前後の比較だけに使う。サーバの起動・検査と終了処理は要求/秒の区間に含まれず、別の「実行 (秒)」は bench_run の run_nanos である。

HTTP の表と線形目盛のグラフは、計算タスク有無・クライアント数・呼び出し予算の組ごとに示す。「応答最大」は各実行で求めた最大の応答時間の、10 回の中央値であり、全実行を合わせた最大値ではない。時間切れ（起動から終了まで既定 30 秒）や失敗ではサーバを止めて終了を待ち、誤りを報告する。HTTP には比較対象の言語の版を置かない。

L41 で置いた仮の入力は Map 200,000 鍵、HTTP 1,000 要求である。Map 10,000 鍵の実行時間 0.063 秒から、20 倍を約 1.26 秒と見積もった。HTTP 100 要求・1 クライアントは計算なし 0.022 秒、計算あり 0.256 秒であり、1,000 要求を約 0.22 秒・2.56 秒と見積もった。これらは L41 時点の単純な比例の見積もりであり、木の高さ、回収、並行数、予算の影響は含まない。2026-10-09 の短い試行で、入力を調整した（下記「R33 の短い試行と測り直し」）。

## R33 の短い試行と測り直し

`remeasure.py` は既定で各入力を一回だけ実行する。R12 の入力と期待値の計算、
`run.py` の HTTP クライアントと統計の読み出し、`bench_run` を使う。
`--plan` は `label`・`name`・`args` を持つ配列の JSON である。
`options` に `bench_run` の設定、HTTP の行には `clients` も指定できる。
`@lines:N` の引数は作業ディレクトリ内に生成した N 行のファイルへ置き換える。
比較対象がある負荷は独立した Rust 版と全出力を照合し、それ以外は式から期待値を求める。
HTTP は各応答の状態・本体と応答数を照合する。

```sh
python3 tools/bench/remeasure.py --plan <入力の JSON> --output target/r33-trial/record.md
```

Markdown、線形目盛の HTML、個々の停止標本とソース・実行ファイルの SHA-256 を含む JSON を作る。
既存の出力は上書きしない。`--measure` を明示した場合だけ各入力を 10 回実行する。
短い試行からメモリの管理の方式を確定する案は出さず、本測定と CPU プロファイルの後に所見を書く。

handler の単一の操作数を増やすと、1 秒になる前に既定の呼び出し情報の上限へ達した。
初回リリース版の入力は深さ 100,000 を 100 回繰り返す形に調整した。
`stage1/returns.bnt` も第二引数に独立した実行の回数を受け取り、省略時は従来の一回となる。
R12 と比べるときは省略時の入力を使い、長さを調整する実行とは別に記録する。

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
`remeasure.py` はこの方式を使う。通常の `run.py` は環境変数がなければ従来の OS の道具を使う。

`/usr/bin/true` の試行では 1,048,576 bytes を報告した。
過去の OS の道具との値の一致は、この制限のある環境では確認できていない。
小さい RSS の変化は、パイプラインや標準ライブラリの変更も含むため、GC 単独の影響と扱わない。
タスク一個あたりの近似には同じ方式での 0 タスクとの差を使う。
ラッパーの起動時間は `bench_run` の `run_nanos` に含まれず、CLI の通常の時間測定にもラッパーを入れない。

## SECB6 の変更の有無の比較

`secb6.py` は、開始時に保存した `bench_run` と変更後の `bench_run` を交互に実行する。`remeasure.sample` と `run.http_sample` を使い、fib（34）・loop（20,000,000）は各 7 回の最小値、計算なしの HTTP は 1 クライアント・20,000/80,000 要求を各 3 回の最小値と中央値で比べる。全出力と HTTP の全応答を照合し、Markdown・線形目盛の HTML・全標本と SHA-256 の JSON を保存する。既存の出力は上書きしない。

```sh
python3 tools/bench/secb6.py --before target/secb6/bench_run-before \
  --after target/secb6/bench_run-after \
  --output tools/bench/results/2026-10-09-secb6-resource-table.md
```

二つの `bench_run` と、独立した出力の照合に使う Rust 版の fib・loop を、測定前に release でビルドしておく。測定中はビルドやテストを動かさない。比較用の実行ファイルの保存と作成はこの道具では行わない。
